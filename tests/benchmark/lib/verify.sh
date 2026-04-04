#!/usr/bin/env zsh
# Verification engine — checks execution results against case predicates
# Requires: jq
# Note: avoid 'local path' — zsh ties it to PATH, breaking jq lookups

# Returns 0 on pass, 1 on fail. Sets _VERIFY_MSG on failure.
bench_verify() {
  local verify_json="$1" stdout_file="$2" exit_code="$3" sandbox="$4"

  local vtype=$(echo "$verify_json" | jq -r '.type')

  case "$vtype" in
    exit_code)
      local expected=$(echo "$verify_json" | jq -r '.value // 0')
      if [[ "$exit_code" -eq "$expected" ]]; then return 0
      else _VERIFY_MSG="exit_code: expected $expected, got $exit_code"; return 1; fi
      ;;

    stdout_contains)
      local needle=$(echo "$verify_json" | jq -r '.value')
      if grep -qF -- "$needle" "$stdout_file" 2>/dev/null; then return 0
      else _VERIFY_MSG="stdout_contains \"$needle\" -- not found"; return 1; fi
      ;;

    stdout_not_contains)
      local needle=$(echo "$verify_json" | jq -r '.value')
      if ! grep -qF -- "$needle" "$stdout_file" 2>/dev/null; then return 0
      else _VERIFY_MSG="stdout_not_contains \"$needle\" -- found"; return 1; fi
      ;;

    stdout_match)
      local pattern=$(echo "$verify_json" | jq -r '.pattern')
      local content=$(<"$stdout_file" 2>/dev/null | tr '\n' ' ')
      if [[ "$content" =~ $pattern ]]; then return 0
      else _VERIFY_MSG="stdout_match /$pattern/ -- no match"; return 1; fi
      ;;

    stdout_line_count)
      local op=$(echo "$verify_json" | jq -r '.op')
      local expected=$(echo "$verify_json" | jq -r '.value')
      local actual=$(wc -l < "$stdout_file" 2>/dev/null | tr -d ' ')
      local pass=0
      case "$op" in
        eq) (( actual == expected )) && pass=1 ;;
        ge) (( actual >= expected )) && pass=1 ;;
        le) (( actual <= expected )) && pass=1 ;;
        gt) (( actual >  expected )) && pass=1 ;;
        lt) (( actual <  expected )) && pass=1 ;;
      esac
      if (( pass )); then return 0
      else _VERIFY_MSG="stdout_line_count: $actual $op $expected -- false"; return 1; fi
      ;;

    file_exists)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      if [[ -f "${sandbox}/${_fp}" ]]; then return 0
      else _VERIFY_MSG="file_exists: ${_fp} -- not found"; return 1; fi
      ;;

    file_not_exists)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      if [[ ! -e "${sandbox}/${_fp}" ]]; then return 0
      else _VERIFY_MSG="file_not_exists: ${_fp} -- exists"; return 1; fi
      ;;

    file_contains)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      local needle=$(echo "$verify_json" | jq -r '.value')
      if grep -qF -- "$needle" "${sandbox}/${_fp}" 2>/dev/null; then return 0
      else _VERIFY_MSG="file_contains: ${_fp} missing \"$needle\""; return 1; fi
      ;;

    dir_exists)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      if [[ -d "${sandbox}/${_fp}" ]]; then return 0
      else _VERIFY_MSG="dir_exists: ${_fp} -- not found"; return 1; fi
      ;;

    file_executable)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      if [[ -x "${sandbox}/${_fp}" ]]; then return 0
      else _VERIFY_MSG="file_executable: ${_fp} -- not executable"; return 1; fi
      ;;

    file_not_writable)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      if [[ ! -w "${sandbox}/${_fp}" ]]; then return 0
      else _VERIFY_MSG="file_not_writable: ${_fp} -- still writable"; return 1; fi
      ;;

    file_mode)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      local expected_mode=$(echo "$verify_json" | jq -r '.mode')
      local actual_mode=$(stat -c %a "${sandbox}/${_fp}" 2>/dev/null)
      if [[ "$actual_mode" == "$expected_mode" ]]; then return 0
      else _VERIFY_MSG="file_mode: ${_fp} expected ${expected_mode}, got ${actual_mode}"; return 1; fi
      ;;

    symlink_target)
      local _fp=$(echo "$verify_json" | jq -r '.path')
      local expected_target=$(echo "$verify_json" | jq -r '.target')
      if [[ -L "${sandbox}/${_fp}" ]]; then
        local actual_target=$(readlink "${sandbox}/${_fp}")
        if [[ "$actual_target" == "$expected_target" ]]; then return 0
        else _VERIFY_MSG="symlink_target: ${_fp} -> ${actual_target}, expected -> ${expected_target}"; return 1; fi
      else _VERIFY_MSG="symlink_target: ${_fp} -- not a symlink"; return 1; fi
      ;;

    compound)
      local check_count=$(echo "$verify_json" | jq '.checks | length')
      local ci=0
      while (( ci < check_count )); do
        local check=$(echo "$verify_json" | jq -c ".checks[$ci]")
        ci=$(( ci + 1 ))
        if ! bench_verify "$check" "$stdout_file" "$exit_code" "$sandbox"; then
          return 1
        fi
      done
      return 0
      ;;

    *)
      _VERIFY_MSG="unknown verify type: $vtype"
      return 1
      ;;
  esac
}
