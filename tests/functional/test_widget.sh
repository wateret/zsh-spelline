#!/usr/bin/env zsh
# Test: core widget behavior (trigger, empty buffer)
set -uo pipefail

SPELLINE_REPO_DIR="${0:A:h}/../.."
source "${0:A:h}/../lib/harness.sh"
source "${0:A:h}/../lib/tmux_helpers.sh"

MOCK="${0:A:h}/../mocks/mock_single.sh"
MOCK="${MOCK:A}"
SESSION="test_widget_$$"

trap 'tmux_test_cleanup' EXIT

tmux_session_start "$SESSION"
tmux_session_source_plugin "$SESSION" "zsh ${MOCK}"
sleep 0.5

# ── Test: widget places mock result in buffer ─────────────────────────────────
test_begin "widget places mock result in buffer"
tmux_session_send "$SESSION" "list files in tmp"
sleep 0.3
tmux_session_send_key "$SESSION" C-g

if tmux_session_wait_for "$SESSION" "ls -la /tmp" 10; then
  local buf=$(tmux_session_buffer "$SESSION")
  assert_equals "ls -la /tmp" "$buf" "buffer contains mock result"
else
  _harness_not_ok "buffer contains mock result" \
    "timed out waiting for mock result" \
    "capture: $(tmux_session_capture "$SESSION" | tail -3)"
fi

# clear buffer for next test: Ctrl+C then Ctrl+U
tmux_session_send_key "$SESSION" C-c
sleep 0.3
tmux_session_send_key "$SESSION" C-u
sleep 0.3

# ── Test: empty buffer Ctrl+G is no-op ───────────────────────────────────────
test_begin "empty buffer Ctrl+G is no-op"
tmux_session_send_key "$SESSION" C-g
sleep 1

local buf=$(tmux_session_buffer "$SESSION")
assert_equals "" "$buf" "buffer stays empty"

local capture=$(tmux_session_capture "$SESSION")
assert_not_contains "$capture" "Asking" "no spinner appeared"

tmux_session_destroy "$SESSION"

test_summary
