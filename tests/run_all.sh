#!/usr/bin/env zsh
# Test runner — discovers and runs test files, aggregates results
set -uo pipefail

TESTS_DIR="${0:A:h}"

usage() {
  echo "Usage: $0 [functional|benchmark|all]"
  echo "  functional  Run functional tests (default)"
  echo "  benchmark   Run LLM quality benchmark"
  echo "  all         Run both"
  exit 1
}

run_functional() {
  local total_pass=0 total_fail=0 total_tests=0
  local failed_files=()

  echo "=== Functional Tests ==="
  echo ""

  for test_file in "${TESTS_DIR}"/functional/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    local name="${test_file:t:r}"
    echo "--- ${name} ---"

    local output=''
    output=$(zsh "$test_file" 2>&1)
    local exit_code=$?
    echo "$output"
    echo ""

    # parse TAP summary
    local pass=$(echo "$output" | grep '^# pass:' | awk '{print $3}')
    local fail=$(echo "$output" | grep '^# fail:' | awk '{print $3}')
    total_pass=$(( total_pass + ${pass:-0} ))
    total_fail=$(( total_fail + ${fail:-0} ))

    if (( exit_code != 0 )); then
      failed_files+=("$name")
    fi
  done

  total_tests=$(( total_pass + total_fail ))
  echo "=== Summary ==="
  echo "Total: ${total_tests}  Pass: ${total_pass}  Fail: ${total_fail}"
  if (( ${#failed_files[@]} > 0 )); then
    echo "Failed: ${(j:, :)failed_files}"
  fi
  echo ""

  (( total_fail > 0 )) && return 1
  return 0
}

run_benchmark() {
  local bench_script="${TESTS_DIR}/benchmark/run_benchmark.sh"
  if [[ ! -f "$bench_script" ]]; then
    echo "Benchmark not yet implemented: ${bench_script}"
    return 1
  fi
  zsh "$bench_script"
}

# main
local mode="${1:-functional}"
case "$mode" in
  functional) run_functional ;;
  benchmark)  run_benchmark ;;
  all)        run_functional; run_benchmark ;;
  *)          usage ;;
esac
