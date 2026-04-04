#!/usr/bin/env zsh
# Execution-based LLM command benchmark
set -o pipefail
zmodload zsh/datetime 2>/dev/null

BENCH_DIR="${0:A:h}"
REPO_DIR="${BENCH_DIR:h:h}"
RESULTS_DIR="${BENCH_DIR}/results"
CASES_FILE="${BENCH_DIR}/cases.jsonl"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${RESULTS_DIR}/bench_${TIMESTAMP}.json"

source "${REPO_DIR}/spelline.zsh"
source "${BENCH_DIR}/lib/verify.sh"
source "${BENCH_DIR}/lib/safety.sh"

: ${BENCH_TIMEOUT:=30}
: ${BENCH_LLM_TIMEOUT:=60}

# macOS ships without timeout; use gtimeout (brew install coreutils) if available
if (( $+commands[timeout] )); then
  _bench_timeout=timeout
elif (( $+commands[gtimeout] )); then
  _bench_timeout=gtimeout
else
  echo "error: timeout or gtimeout (brew install coreutils) is required" >&2
  exit 1
fi
: ${BENCH_DELAY:=5}            # seconds to wait between LLM calls (rate limit)

# ── parse args ────────────────────────────────────────────────────────────────
local -a filter_ids=()
local filter_tag="" dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)       IFS=',' read -rA filter_ids <<< "$2"; shift 2 ;;
    --tag)      filter_tag="$2"; shift 2 ;;
    --dry-run)  dry_run=1; shift ;;
    --delay)    BENCH_DELAY="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--id ID[,ID,...]] [--tag TAG] [--dry-run] [--delay SECS]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── counters ──────────────────────────────────────────────────────────────────
typeset -i _bench_total=0 _bench_passed=0 _bench_failed=0 _bench_errors=0 _bench_skipped=0
typeset -a _bench_results_json=()
typeset -A _bench_tag_total _bench_tag_passed

_bench_record() {
  local id="$1" result_status="$2" command="${3:-}" reason="${4:-}" elapsed_llm="${5:-0}" elapsed_exec="${6:-0}" tags_json="$7"

  _bench_total=$(( _bench_total + 1 ))
  case "$result_status" in
    pass)    _bench_passed=$(( _bench_passed + 1 )) ;;
    fail)    _bench_failed=$(( _bench_failed + 1 )) ;;
    error)   _bench_errors=$(( _bench_errors + 1 )) ;;
    skipped) _bench_skipped=$(( _bench_skipped + 1 )) ;;
  esac

  # TAP output
  if [[ "$result_status" == "pass" ]]; then
    echo "ok ${_bench_total} - ${id}"
  else
    echo "not ok ${_bench_total} - ${id}"
    [[ -n "$command" ]] && echo "# command: ${command}"
    [[ -n "$reason" ]] && echo "# reason: ${reason}"
  fi

  # tag tracking
  local tag
  for tag in $(echo "$tags_json" | jq -r '.[]' 2>/dev/null); do
    _bench_tag_total[$tag]=$(( ${_bench_tag_total[$tag]:-0} + 1 ))
    if [[ "$result_status" == "pass" ]]; then
      _bench_tag_passed[$tag]=$(( ${_bench_tag_passed[$tag]:-0} + 1 ))
    fi
  done

  # JSON result entry
  local cmd_escaped=$(echo "$command" | jq -Rs '.')
  local reason_escaped=$(echo "$reason" | jq -Rs '.')
  _bench_results_json+=("{\"id\":\"${id}\",\"status\":\"${result_status}\",\"command\":${cmd_escaped},\"reason\":${reason_escaped},\"elapsed_llm_s\":${elapsed_llm},\"elapsed_exec_s\":${elapsed_exec},\"tags\":${tags_json}}")
}

# ── main loop ─────────────────────────────────────────────────────────────────
# suppress history and tmux context to keep benchmark prompts clean
_spelline_history() { : }
_spelline_tmux_context() { : }

echo "TAP version 13"

local total_cases=$(wc -l < "$CASES_FILE" | tr -d ' ')

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  local id=$(echo "$line" | jq -r '.id')
  local request=$(echo "$line" | jq -r '.request')
  local tags_json=$(echo "$line" | jq -c '.tags')
  local verify_json=$(echo "$line" | jq -c '.verify')

  # ── filter ──────────────────────────────────────────────────────────────
  if (( ${#filter_ids[@]} > 0 )) && ! (( ${filter_ids[(Ie)$id]} )); then
    continue
  fi
  if [[ -n "$filter_tag" ]]; then
    if ! echo "$tags_json" | jq -e "index(\"$filter_tag\")" &>/dev/null; then
      continue
    fi
  fi

  # ── sandbox ─────────────────────────────────────────────────────────────
  local sandbox="/tmp/bench_${id}_$$"
  mkdir -p "$sandbox"

  # ── setup ───────────────────────────────────────────────────────────────
  local setup_ok=1
  local setup_count=$(echo "$line" | jq '.setup | length')
  local si=0
  while (( si < setup_count )); do
    local scmd=$(echo "$line" | jq -r ".setup[$si]")
    si=$(( si + 1 ))
    [[ -z "$scmd" ]] && continue
    if ! (cd "$sandbox" && eval "$scmd") 2>/dev/null; then
      setup_ok=0
      break
    fi
  done

  if (( ! setup_ok )); then
    _bench_record "$id" "error" "" "setup_failed" "0" "0" "$tags_json"
    rm -rf "$sandbox"
    continue
  fi

  # ── dry run: skip LLM call, just verify setup works ─────────────────────
  if (( dry_run )); then
    _bench_record "$id" "skipped" "" "dry_run" "0" "0" "$tags_json"
    rm -rf "$sandbox"
    continue
  fi

  # ── rate limit delay ────────────────────────────────────────────────────
  (( _bench_total > 0 && BENCH_DELAY > 0 )) && sleep "$BENCH_DELAY"

  # ── build prompt + call LLM ─────────────────────────────────────────────
  local prompt=$(cd "$sandbox" && _spelline_build_prompt "$request")
  local llm_out_file="/tmp/bench_llm_${id}_$$"
  local llm_in_file="/tmp/bench_llm_in_${id}_$$"
  printf '%s' "$prompt" > "$llm_in_file"

  local llm_start=$EPOCHREALTIME
  $_bench_timeout "$BENCH_LLM_TIMEOUT" ${=ZSH_SPELLINE_CMD} < "$llm_in_file" > "$llm_out_file" 2>/dev/null
  local llm_exit=$?
  local llm_elapsed=$(printf '%.2f' $(( EPOCHREALTIME - llm_start )))
  rm -f "$llm_in_file"

  if (( llm_exit != 0 )); then
    _bench_record "$id" "error" "" "llm_failed (exit=$llm_exit)" "$llm_elapsed" "0" "$tags_json"
    rm -f "$llm_out_file"
    rm -rf "$sandbox"
    continue
  fi

  local llm_output=$(<"$llm_out_file")
  rm -f "$llm_out_file"

  # ── parse response ──────────────────────────────────────────────────────
  _spelline_parse_result "$llm_output"
  local command="${_spelline_candidates[1]:-}"

  if [[ -z "$command" ]]; then
    _bench_record "$id" "fail" "" "no_command_generated" "$llm_elapsed" "0" "$tags_json"
    rm -rf "$sandbox"
    continue
  fi

  # ── safety check ────────────────────────────────────────────────────────
  if ! bench_safety_check "$command"; then
    _bench_record "$id" "skipped" "$command" "safety_blocked" "$llm_elapsed" "0" "$tags_json"
    rm -rf "$sandbox"
    continue
  fi

  # ── execute ─────────────────────────────────────────────────────────────
  local exec_stdout="/tmp/bench_exec_out_${id}_$$"
  local exec_stderr="/tmp/bench_exec_err_${id}_$$"

  local exec_start=$EPOCHREALTIME
  (cd "$sandbox" && HOME="$sandbox" $_bench_timeout $BENCH_TIMEOUT zsh -c "$command") > "$exec_stdout" 2>"$exec_stderr" </dev/null
  local exec_exit=$?
  local exec_elapsed=$(printf '%.2f' $(( EPOCHREALTIME - exec_start )))

  # ── verify ──────────────────────────────────────────────────────────────
  _VERIFY_MSG=""
  if bench_verify "$verify_json" "$exec_stdout" "$exec_exit" "$sandbox"; then
    _bench_record "$id" "pass" "$command" "" "$llm_elapsed" "$exec_elapsed" "$tags_json"
  else
    _bench_record "$id" "fail" "$command" "$_VERIFY_MSG" "$llm_elapsed" "$exec_elapsed" "$tags_json"
  fi

  rm -f "$exec_stdout" "$exec_stderr"
  rm -rf "$sandbox"

done < "$CASES_FILE"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "1..${_bench_total}"
echo "# pass: ${_bench_passed}"
echo "# fail: ${_bench_failed}"
echo "# error: ${_bench_errors}"
echo "# skipped: ${_bench_skipped}"

if (( _bench_total > 0 )); then
  local pass_rate=$(printf '%.0f' $(( _bench_passed * 100.0 / _bench_total )))
  echo "# pass_rate: ${pass_rate}%"
fi

# ── write JSON results ────────────────────────────────────────────────────────
mkdir -p "$RESULTS_DIR"

local by_tag_json="{"
local first_tag=1
for tag in ${(k)_bench_tag_total}; do
  local t_total=${_bench_tag_total[$tag]}
  local t_passed=${_bench_tag_passed[$tag]:-0}
  local t_rate=$(printf '%.2f' $(( t_passed * 1.0 / t_total )))
  (( first_tag )) || by_tag_json+=","
  by_tag_json+="\"${tag}\":{\"total\":${t_total},\"passed\":${t_passed},\"pass_rate\":${t_rate}}"
  first_tag=0
done
by_tag_json+="}"

local cases_json=$(printf '%s\n' "${_bench_results_json[@]}" | paste -sd',' -)

cat > "$RESULT_FILE" <<ENDJSON
{
  "timestamp": "$(date -Iseconds)",
  "llm_cmd": "${ZSH_SPELLINE_CMD}",
  "total": ${_bench_total},
  "passed": ${_bench_passed},
  "failed": ${_bench_failed},
  "errors": ${_bench_errors},
  "skipped": ${_bench_skipped},
  "pass_rate": $(printf '%.2f' $(( _bench_passed * 1.0 / (_bench_total > 0 ? _bench_total : 1) ))),
  "by_tag": ${by_tag_json},
  "cases": [${cases_json}]
}
ENDJSON

echo "# results: ${RESULT_FILE}"

(( _bench_failed > 0 || _bench_errors > 0 )) && exit 1
exit 0
