#!/usr/bin/env zsh
# Test: Manual installation method

REPO_DIR="${0:A:h}/../.."
fail=0

echo "--- test_manual ---"

# 1. Copy repo to ~/.zsh/zsh-spelline (simulating git clone)
mkdir -p ~/.zsh/zsh-spelline || { echo "not ok - mkdir failed"; exit 1; }
cp -r "${REPO_DIR}"/{spelline.zsh,zsh-spelline.plugin.zsh} ~/.zsh/zsh-spelline/ \
  || { echo "not ok - cp failed"; exit 1; }
[[ -f ~/.zsh/zsh-spelline/spelline.zsh ]] || { echo "not ok - spelline.zsh not found"; exit 1; }

# 2. Source the plugin
source ~/.zsh/zsh-spelline/spelline.zsh || { echo "not ok - source failed"; exit 1; }

# 3. Verify
if (( $+functions[_spelline_generate] )); then
  echo "ok 1 - _spelline_generate defined"
else
  echo "not ok 1 - _spelline_generate defined"
  fail=1
fi

if (( $+functions[_spelline_history_search] )); then
  echo "ok 2 - _spelline_history_search defined"
else
  echo "not ok 2 - _spelline_history_search defined"
  fail=1
fi

if bindkey | grep -q _spelline_generate; then
  echo "ok 3 - keybinding registered"
else
  echo "not ok 3 - keybinding registered"
  fail=1
fi

# 4. Verify end-to-end via spelline_query
ZSH_SPELLINE_CMD="zsh ${REPO_DIR}/tests/mocks/mock_single.sh"
local output=$(spelline_query "list files")
if [[ "$output" == "ls -la /tmp" ]]; then
  echo "ok 4 - spelline_query returns expected result"
else
  echo "not ok 4 - spelline_query returns expected result"
  echo "# got: $output"
  fail=1
fi


echo ""
echo "1..4"

# cleanup
rm -rf ~/.zsh/zsh-spelline

exit $fail
