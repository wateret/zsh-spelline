#!/usr/bin/env zsh
# Test: spinner visibility during LLM call
set -uo pipefail

SPELLINE_REPO_DIR="${0:A:h}/../.."
source "${0:A:h}/../lib/harness.sh"
source "${0:A:h}/../lib/tmux_helpers.sh"

MOCK_SLOW="${0:A:h}/../mocks/mock_slow.sh"
MOCK_SLOW="${MOCK_SLOW:A}"
SESSION="test_spinner_$$"

trap 'tmux_test_cleanup' EXIT

tmux_session_start "$SESSION"
tmux_session_source_plugin "$SESSION" "zsh ${MOCK_SLOW}"
sleep 0.5

# ── Test: spinner appears during wait ─────────────────────────────────────────
test_begin "spinner appears during wait"
tmux_session_send "$SESSION" "slow request"
sleep 0.3
tmux_session_send_key "$SESSION" C-g

if tmux_session_wait_for "$SESSION" "Asking" 5; then
  local capture=$(tmux_session_capture "$SESSION")
  assert_contains "$capture" "Asking" "spinner text visible"
else
  _harness_not_ok "spinner text visible" \
    "spinner never appeared within 5s" \
    "capture: $(tmux_session_capture "$SESSION" | tail -3)"
fi

# ── Test: spinner animates (character changes between captures) ───────────────
test_begin "spinner animates"
local cap1=$(tmux_session_capture "$SESSION")
sleep 0.5
local cap2=$(tmux_session_capture "$SESSION")
# at least one of the captures should differ (spinner frame changed)
if [[ "$cap1" != "$cap2" ]]; then
  _harness_ok "spinner frames differ between captures"
else
  _harness_not_ok "spinner frames differ between captures" \
    "captures were identical"
fi

# cleanup: cancel the slow mock
tmux_session_send_key "$SESSION" C-c
sleep 0.5

tmux_session_destroy "$SESSION"

test_summary
