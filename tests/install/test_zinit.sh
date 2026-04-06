#!/usr/bin/env zsh
# Test: zinit installation method

REPO_DIR="${0:A:h}/../.."
fail=0

echo "--- test_zinit ---"

# 1. Install zinit
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)" \
  || { echo "not ok - zinit install failed"; exit 1; }
[[ -f ~/.local/share/zinit/zinit.git/zinit.zsh ]] || { echo "not ok - zinit.zsh not found"; exit 1; }

# 2. Source zinit and load plugin from local path
source ~/.local/share/zinit/zinit.git/zinit.zsh || { echo "not ok - zinit source failed"; exit 1; }
zinit light-mode for "${REPO_DIR}" || { echo "not ok - zinit load failed"; exit 1; }

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

echo ""
echo "1..3"

# cleanup
rm -rf ~/.local/share/zinit

exit $fail
