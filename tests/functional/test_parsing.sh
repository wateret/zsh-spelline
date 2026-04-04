#!/usr/bin/env zsh
# Test: candidate parsing logic (non-interactive, no tmux needed)
# Tests _spelline_parse_result() directly from spelline.zsh
set -uo pipefail

source "${0:A:h}/../lib/harness.sh"
source "${0:A:h}/../../spelline.zsh"

# ── Test: single command ──────────────────────────────────────────────────────
test_begin "single command"
_spelline_parse_result "ls -la /tmp"
assert_equals "1" "${#_spelline_candidates[@]}" "single command: count is 1"
assert_equals "ls -la /tmp" "${_spelline_candidates[1]}" "single command: correct value"

# ── Test: multiple candidates with --- ────────────────────────────────────────
test_begin "multiple candidates"
_spelline_parse_result "find . -type f -size +100M
---
du -sh * | sort -rh
---
ls -lSr | tail -20"
assert_equals "3" "${#_spelline_candidates[@]}" "multi candidates: count is 3"
assert_equals "find . -type f -size +100M" "${_spelline_candidates[1]}" "multi candidates: first"
assert_equals "du -sh * | sort -rh" "${_spelline_candidates[2]}" "multi candidates: second"
assert_equals "ls -lSr | tail -20" "${_spelline_candidates[3]}" "multi candidates: third"

# ── Test: markdown fences stripped ────────────────────────────────────────────
test_begin "markdown fence stripping"
_spelline_parse_result '```bash
ls -la /tmp
```'
assert_equals "1" "${#_spelline_candidates[@]}" "fenced: count is 1"
assert_equals "ls -la /tmp" "${_spelline_candidates[1]}" "fenced: fences stripped"

# ── Test: empty input ─────────────────────────────────────────────────────────
test_begin "empty input"
_spelline_parse_result ""
assert_equals "0" "${#_spelline_candidates[@]}" "empty: no candidates"

# ── Test: whitespace-only candidates filtered ─────────────────────────────────
test_begin "whitespace-only filtered"
_spelline_parse_result "ls -la
---

---
pwd"
assert_equals "2" "${#_spelline_candidates[@]}" "whitespace-only candidates filtered out"
assert_equals "ls -la" "${_spelline_candidates[1]}" "ws filter: first"
assert_equals "pwd" "${_spelline_candidates[2]}" "ws filter: second"

# ── Test: multiline candidate ─────────────────────────────────────────────────
test_begin "multiline candidate"
_spelline_parse_result 'for f in *.log; do
  gzip "$f"
done'
assert_equals "1" "${#_spelline_candidates[@]}" "multiline: count is 1"
assert_contains "${_spelline_candidates[1]}" 'for f in *.log; do' "multiline: contains first line"
assert_contains "${_spelline_candidates[1]}" 'gzip "$f"' "multiline: contains middle"
assert_contains "${_spelline_candidates[1]}" "done" "multiline: contains last line"

# ── Test: mixed fences and delimiters ─────────────────────────────────────────
test_begin "fences with delimiters"
_spelline_parse_result '```
ls -la
```
---
```bash
pwd
```'
assert_equals "2" "${#_spelline_candidates[@]}" "mixed: count is 2"
assert_equals "ls -la" "${_spelline_candidates[1]}" "mixed: first candidate"
assert_equals "pwd" "${_spelline_candidates[2]}" "mixed: second candidate"

test_summary
