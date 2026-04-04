#!/usr/bin/env zsh
# Test: Ctrl+C cancellation restores original buffer
set -uo pipefail

SPELLINE_REPO_DIR="${0:A:h}/../.."
source "${0:A:h}/../lib/harness.sh"
source "${0:A:h}/../lib/tmux_helpers.sh"

MOCK_SLOW="${0:A:h}/../mocks/mock_slow.sh"
MOCK_SLOW="${MOCK_SLOW:A}"
SESSION="test_cancel_$$"

trap 'tmux_test_cleanup' EXIT

tmux_session_start "$SESSION"
tmux_session_source_plugin "$SESSION" "zsh ${MOCK_SLOW}"
sleep 0.5

# ── Test: Ctrl+C during LLM call restores original buffer ────────────────────
test_begin "Ctrl+C restores original buffer"
tmux_session_send "$SESSION" "my original text"
sleep 0.3
tmux_session_send_key "$SESSION" C-g

# wait for spinner to appear
if tmux_session_wait_for "$SESSION" "Spellining via" 5; then
  # cancel
  tmux_session_send_key "$SESSION" C-c
  sleep 1

  local buf=$(tmux_session_buffer "$SESSION")
  assert_equals "my original text" "$buf" "original buffer restored after cancel"

  # spinner should be gone
  local capture=$(tmux_session_capture "$SESSION")
  assert_not_contains "$capture" "Spellining via" "spinner cleared after cancel"
else
  _harness_not_ok "original buffer restored after cancel" \
    "spinner never appeared" \
    "capture: $(tmux_session_capture "$SESSION" | tail -3)"
  _harness_not_ok "spinner cleared after cancel" "skipped (spinner never appeared)"
fi

tmux_session_destroy "$SESSION"

test_summary
