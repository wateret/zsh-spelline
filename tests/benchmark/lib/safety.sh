#!/usr/bin/env zsh
# Safety filter — blocks dangerous commands before execution

_BENCH_BLOCKED_PATTERNS=(
  # destructive system commands
  'rm[[:space:]]+-rf[[:space:]]+/'
  'rm[[:space:]]+-rf[[:space:]]+/\*'
  'rm[[:space:]]+-rf[[:space:]]+~'
  'rm[[:space:]]+-rf[[:space:]]+\$HOME'
  'mkfs[[:space:]]'
  'dd[[:space:]].*of=/dev/'
  ':\(\)\{.*\|.*&\}\;'
  '\bshutdown\b'
  '\breboot\b'
  '\bhalt\b'
  '\bpoweroff\b'
  '\binit[[:space:]]+[06]\b'
  'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'
  'chown[[:space:]]+-R[[:space:]].*[[:space:]]+/'
  '>[[:space:]]*/dev/[sh]d'
  'wget.*\|[[:space:]]*sh'
  'curl.*\|[[:space:]]*sh'
  'curl.*\|[[:space:]]*bash'
  'wget.*\|[[:space:]]*bash'
  'nc[[:space:]]+-e'
  '/dev/tcp/'
  'iptables[[:space:]]+-F'
  # sandbox escape — parent/absolute/home paths
  '\.\.'
  '^/'
  '(^|[[:space:]])~/'
  '(cd|rm|mv|cp|chmod|chown|mkdir|rmdir|ln|cat >|>)[[:space:]].*\$HOME'
)

# Returns 0 if safe, 1 if dangerous
bench_safety_check() {
  local cmd="$1"
  for pattern in "${_BENCH_BLOCKED_PATTERNS[@]}"; do
    if [[ "$cmd" =~ $pattern ]]; then
      return 1
    fi
  done
  return 0
}
