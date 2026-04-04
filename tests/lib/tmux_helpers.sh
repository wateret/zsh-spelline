#!/usr/bin/env zsh
# tmux session helpers for functional testing
zmodload zsh/datetime 2>/dev/null

_TMUX_TEST_PROMPT='T>'
_TMUX_TEST_SOCKDIR="${TMPDIR:-/tmp}/spelline_test_$$"

tmux_session_start() {
  local name="$1"
  mkdir -p "$_TMUX_TEST_SOCKDIR"
  local sock="${_TMUX_TEST_SOCKDIR}/${name}.sock"

  # start a minimal zsh with no rc files
  tmux -S "$sock" new-session -d -s "$name" -x 120 -y 24 \
    "TERM=xterm HISTSIZE=0 PS1='${_TMUX_TEST_PROMPT}' zsh -f -i" 2>/dev/null

  # wait for prompt
  local i=0
  while (( i < 50 )); do
    local pane=$(tmux -S "$sock" capture-pane -t "$name" -p 2>/dev/null)
    if [[ "$pane" == *"${_TMUX_TEST_PROMPT}"* ]]; then
      return 0
    fi
    sleep 0.1
    i=$(( i + 1 ))
  done
  echo "# WARNING: tmux session '$name' did not show prompt within 5s" >&2
  return 1
}

tmux_session_send() {
  local name="$1" text="$2"
  local sock="${_TMUX_TEST_SOCKDIR}/${name}.sock"
  tmux -S "$sock" send-keys -t "$name" "$text"
}

tmux_session_send_key() {
  local name="$1" key="$2"
  local sock="${_TMUX_TEST_SOCKDIR}/${name}.sock"
  tmux -S "$sock" send-keys -t "$name" "$key"
}

tmux_session_capture() {
  local name="$1"
  local sock="${_TMUX_TEST_SOCKDIR}/${name}.sock"
  tmux -S "$sock" capture-pane -t "$name" -p 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}

# extract the current ZLE buffer content (last prompt line, after the prompt prefix)
tmux_session_buffer() {
  local name="$1"
  local capture=$(tmux_session_capture "$name")
  # find the last line containing the prompt, extract text after it
  echo "$capture" | grep "${_TMUX_TEST_PROMPT}" | tail -1 \
    | sed "s/.*${_TMUX_TEST_PROMPT}//" | sed 's/[[:space:]]*$//'
}

: ${SPELLINE_REPO_DIR:="${0:A:h:h:h}"}

tmux_session_source_plugin() {
  local name="$1" cmd_override="$2"
  local plugin_path="${SPELLINE_REPO_DIR}/spelline.zsh"

  if [[ -n "$cmd_override" ]]; then
    tmux_session_send "$name" "ZSH_SPELLINE_CMD='${cmd_override}'"
    tmux_session_send_key "$name" Enter
    sleep 1
  fi
  tmux_session_send "$name" "source '${plugin_path}'"
  tmux_session_send_key "$name" Enter

  # wait for source to complete (prompt returns)
  local i=0
  while (( i < 30 )); do
    local buf=$(tmux_session_buffer "$name")
    if [[ -z "$buf" ]]; then
      return 0
    fi
    sleep 0.1
    i=$(( i + 1 ))
  done
  return 0
}

tmux_session_destroy() {
  local name="$1"
  local sock="${_TMUX_TEST_SOCKDIR}/${name}.sock"
  tmux -S "$sock" kill-session -t "$name" 2>/dev/null
  rm -f "$sock"
}

# wait for buffer to contain a specific string (polling)
tmux_session_wait_for() {
  local name="$1" needle="$2" timeout="${3:-5}"
  local deadline=$(( EPOCHREALTIME + timeout ))
  while (( EPOCHREALTIME < deadline )); do
    local capture=$(tmux_session_capture "$name")
    if [[ "$capture" == *"$needle"* ]]; then
      return 0
    fi
    sleep 0.3
  done
  return 1
}

# wait for buffer to NOT contain a specific string (polling)
tmux_session_wait_until_gone() {
  local name="$1" needle="$2" timeout="${3:-5}"
  local deadline=$(( EPOCHREALTIME + timeout ))
  while (( EPOCHREALTIME < deadline )); do
    local capture=$(tmux_session_capture "$name")
    if [[ "$capture" != *"$needle"* ]]; then
      return 0
    fi
    sleep 0.3
  done
  return 1
}

# cleanup all test sockets
tmux_test_cleanup() {
  if [[ -d "$_TMUX_TEST_SOCKDIR" ]]; then
    for sock in "$_TMUX_TEST_SOCKDIR"/*.sock(N); do
      local sess=${sock:t:r}
      tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
    done
    rm -rf "$_TMUX_TEST_SOCKDIR"
  fi
}
