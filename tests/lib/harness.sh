#!/usr/bin/env zsh
# Test harness — minimal assert library with TAP output

_harness_pass=0
_harness_fail=0
_harness_total=0
_harness_current_test=""

test_begin() {
  _harness_current_test="$1"
}

_harness_ok() {
  _harness_total=$(( _harness_total + 1 ))
  _harness_pass=$(( _harness_pass + 1 ))
  local msg="${1:-$_harness_current_test}"
  echo "ok ${_harness_total} - ${msg}"
}

_harness_not_ok() {
  _harness_total=$(( _harness_total + 1 ))
  _harness_fail=$(( _harness_fail + 1 ))
  local msg="${1:-$_harness_current_test}"
  echo "not ok ${_harness_total} - ${msg}"
  shift
  for line in "$@"; do
    echo "# ${line}"
  done
}

assert_equals() {
  local expected="$1" actual="$2" msg="${3:-$_harness_current_test}"
  if [[ "$expected" == "$actual" ]]; then
    _harness_ok "$msg"
  else
    _harness_not_ok "$msg" "expected: \"${expected}\"" "actual:   \"${actual}\""
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-$_harness_current_test}"
  if [[ "$haystack" == *"$needle"* ]]; then
    _harness_ok "$msg"
  else
    _harness_not_ok "$msg" "expected to contain: \"${needle}\"" "in: \"${haystack}\""
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-$_harness_current_test}"
  if [[ "$haystack" != *"$needle"* ]]; then
    _harness_ok "$msg"
  else
    _harness_not_ok "$msg" "expected NOT to contain: \"${needle}\"" "in: \"${haystack}\""
  fi
}

assert_match() {
  local string="$1" pattern="$2" msg="${3:-$_harness_current_test}"
  if [[ "$string" =~ $pattern ]]; then
    _harness_ok "$msg"
  else
    _harness_not_ok "$msg" "expected to match: /${pattern}/" "string: \"${string}\""
  fi
}

assert_true() {
  local msg="${1:-$_harness_current_test}"
  shift
  if eval "$@"; then
    _harness_ok "$msg"
  else
    _harness_not_ok "$msg" "condition failed: $*"
  fi
}

assert_file_exists() {
  local path="$1" msg="${2:-$_harness_current_test}"
  if [[ -f "$path" ]]; then
    _harness_ok "$msg"
  else
    _harness_not_ok "$msg" "file not found: ${path}"
  fi
}

test_summary() {
  echo ""
  echo "1..${_harness_total}"
  echo "# pass: ${_harness_pass}"
  echo "# fail: ${_harness_fail}"
  (( _harness_fail > 0 )) && return 1
  return 0
}
