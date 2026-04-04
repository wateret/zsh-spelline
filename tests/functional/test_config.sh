#!/usr/bin/env zsh
# Test: configuration variables
set -uo pipefail

SPELLINE_REPO_DIR="${0:A:h}/../.."
source "${0:A:h}/../lib/harness.sh"
source "${0:A:h}/../lib/tmux_helpers.sh"

MOCKS_DIR="${0:A:h}/../mocks"
MOCK_SINGLE="${MOCKS_DIR:A}/mock_single.sh"
MOCK_SLOW="${MOCKS_DIR:A}/mock_slow.sh"
SESSION="test_config_$$"

trap 'tmux_test_cleanup' EXIT

# ── Test: custom keybinding ───────────────────────────────────────────────────
test_begin "custom keybinding works"
tmux_session_start "$SESSION"
# set custom keybinding before sourcing
tmux_session_send "$SESSION" "ZSH_SPELLINE_KEYBINDING='^X^G'"
tmux_session_send_key "$SESSION" Enter
sleep 2
tmux_session_source_plugin "$SESSION" "zsh ${MOCK_SINGLE}"
sleep 2

tmux_session_send "$SESSION" "test custom key"
sleep 1

# Ctrl+G should NOT trigger the spelline widget (not our keybinding anymore)
tmux_session_send_key "$SESSION" C-g
sleep 2
# verify the mock output did NOT appear (widget was not triggered)
local capture=$(tmux_session_capture "$SESSION")
if [[ "$capture" != *"ls -la /tmp"* ]]; then
  _harness_ok "Ctrl+G does not trigger with custom keybinding"
else
  _harness_not_ok "Ctrl+G does not trigger with custom keybinding" \
    "widget was triggered by Ctrl+G"
fi

# clear buffer for next test
tmux_session_send_key "$SESSION" C-u
sleep 0.5

# Ctrl+X Ctrl+G should trigger
tmux_session_send "$SESSION" "test trigger"
sleep 0.5
tmux_session_send_key "$SESSION" C-x
tmux_session_send_key "$SESSION" C-g

if tmux_session_wait_for "$SESSION" "ls -la /tmp" 10; then
  buf=$(tmux_session_buffer "$SESSION")
  assert_equals "ls -la /tmp" "$buf" "Ctrl+X Ctrl+G triggers with custom keybinding"
else
  _harness_not_ok "Ctrl+X Ctrl+G triggers with custom keybinding" \
    "timed out" \
    "capture: $(tmux_session_capture "$SESSION" | tail -3)"
fi

tmux_session_destroy "$SESSION"

# ── Test: verbose_after shows cancel hint only after threshold ────────────────
test_begin "verbose_after shows cancel hint after threshold"
tmux_session_start "$SESSION"
tmux_session_send "$SESSION" "ZSH_SPELLINE_VERBOSE_AFTER=2"
tmux_session_send_key "$SESSION" Enter
sleep 1
tmux_session_source_plugin "$SESSION" "zsh ${MOCK_SLOW}"
sleep 1

tmux_session_send "$SESSION" "verbose test"
sleep 0.5
tmux_session_send_key "$SESSION" C-g

# before threshold: cancel hint should NOT be visible
sleep 1
local capture_before=$(tmux_session_capture "$SESSION")
assert_not_contains "$capture_before" "to cancel" "cancel hint not shown before threshold"

# after threshold: cancel hint should be visible
if tmux_session_wait_for "$SESSION" "to cancel" 5; then
  local capture_after=$(tmux_session_capture "$SESSION")
  assert_contains "$capture_after" "to cancel" "cancel hint shown after threshold"
else
  _harness_not_ok "cancel hint shown after threshold" \
    "cancel hint never appeared" \
    "capture: $(tmux_session_capture "$SESSION" | tail -3)"
fi

tmux_session_send_key "$SESSION" C-c
sleep 0.5
tmux_session_destroy "$SESSION"

# ── Test: log directory creates log file ──────────────────────────────────────
test_begin "log directory creates log file"
local log_dir="/tmp/spelline_test_logs_$$"
tmux_session_start "$SESSION"
tmux_session_send "$SESSION" "ZSH_SPELLINE_LOG_DIR='${log_dir}'"
tmux_session_send_key "$SESSION" Enter
sleep 1
tmux_session_source_plugin "$SESSION" "zsh ${MOCK_SINGLE}"
sleep 1

tmux_session_send "$SESSION" "log test"
sleep 0.5
tmux_session_send_key "$SESSION" C-g

tmux_session_wait_for "$SESSION" "ls -la /tmp" 10
sleep 1

# check log file was created
local log_count=$(ls "${log_dir}"/*.log 2>/dev/null | wc -l)
if (( log_count > 0 )); then
  _harness_ok "log file created in log directory"
else
  _harness_not_ok "log file created in log directory" \
    "no .log files found in ${log_dir}"
fi

# cleanup
rm -rf "$log_dir"
tmux_session_destroy "$SESSION"

# ── Test: history file records user input ─────────────────────────────────────
test_begin "history file records user input"
local hist_file="/tmp/spelline_test_history_$$"
tmux_session_start "$SESSION"
tmux_session_send "$SESSION" "ZSH_SPELLINE_HISTORY_FILE='${hist_file}'"
tmux_session_send_key "$SESSION" Enter
sleep 1
tmux_session_source_plugin "$SESSION" "zsh ${MOCK_SINGLE}"
sleep 1

tmux_session_send "$SESSION" "history test request"
sleep 0.3
tmux_session_send_key "$SESSION" C-g

tmux_session_wait_for "$SESSION" "ls -la /tmp" 10
sleep 0.5

if [[ -f "$hist_file" ]] && grep -q "history test request" "$hist_file"; then
  _harness_ok "user input saved to history file"
else
  _harness_not_ok "user input saved to history file" \
    "history file missing or does not contain expected input"
fi

# cleanup
rm -f "$hist_file"
tmux_session_destroy "$SESSION"

test_summary
