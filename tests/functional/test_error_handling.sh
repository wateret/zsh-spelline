#!/usr/bin/env zsh
# Test: error handling — LLM failure, empty result, missing fzf fallback
set -uo pipefail

SPELLINE_REPO_DIR="${0:A:h}/../.."
source "${0:A:h}/../lib/harness.sh"
source "${0:A:h}/../lib/tmux_helpers.sh"

MOCKS_DIR="${0:A:h}/../mocks"
SESSION="test_error_$$"

trap 'tmux_test_cleanup' EXIT

# ── Test: LLM exits non-zero → original buffer restored ──────────────────────
test_begin "LLM failure restores buffer"
tmux_session_start "$SESSION"
tmux_session_source_plugin "$SESSION" "zsh ${MOCKS_DIR:A}/mock_fail.sh"
sleep 0.5

tmux_session_send "$SESSION" "should fail"
sleep 0.3
tmux_session_send_key "$SESSION" C-g
sleep 3

local buf=$(tmux_session_buffer "$SESSION")
assert_equals "should fail" "$buf" "buffer restored after LLM failure"

tmux_session_destroy "$SESSION"

# ── Test: LLM returns empty → original buffer restored ───────────────────────
test_begin "empty LLM output restores buffer"
tmux_session_start "$SESSION"
tmux_session_source_plugin "$SESSION" "zsh ${MOCKS_DIR:A}/mock_empty.sh"
sleep 0.5

tmux_session_send "$SESSION" "should be empty"
sleep 0.3
tmux_session_send_key "$SESSION" C-g
sleep 3

buf=$(tmux_session_buffer "$SESSION")
assert_equals "should be empty" "$buf" "buffer restored after empty output"

tmux_session_destroy "$SESSION"

# ── Test: multi candidates without fzf → first candidate selected ────────────
test_begin "no fzf falls back to first candidate"
tmux_session_start "$SESSION"
# override PATH to exclude fzf, then source plugin with multi mock
tmux_session_send "$SESSION" "path_backup=\$PATH; PATH=/usr/bin:/bin"
tmux_session_send_key "$SESSION" Enter
sleep 0.3
tmux_session_source_plugin "$SESSION" "zsh ${MOCKS_DIR:A}/mock_multi.sh"
sleep 0.5

tmux_session_send "$SESSION" "multi without fzf"
sleep 0.3
tmux_session_send_key "$SESSION" C-g

if tmux_session_wait_for "$SESSION" "find" 10; then
  buf=$(tmux_session_buffer "$SESSION")
  assert_equals "find . -type f -size +100M" "$buf" "first candidate selected without fzf"
else
  _harness_not_ok "first candidate selected without fzf" \
    "timed out" \
    "capture: $(tmux_session_capture "$SESSION" | tail -3)"
fi

tmux_session_destroy "$SESSION"

test_summary
