#!/usr/bin/env zsh
# Test: Oh My Zsh installation method

REPO_DIR="${0:A:h}/../.."
fail=0

echo "--- test_omz ---"

# 1. Install Oh My Zsh (unattended)
export RUNZSH=no CHSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
  || { echo "not ok - OMZ install failed"; exit 1; }
[[ -d "$HOME/.oh-my-zsh" ]] || { echo "not ok - OMZ directory not found"; exit 1; }

# 2. Copy plugin to ZSH_CUSTOM
export ZSH="${HOME}/.oh-my-zsh"
export ZSH_CUSTOM="${ZSH}/custom"
mkdir -p "${ZSH_CUSTOM}/plugins/zsh-spelline"
cp -r "${REPO_DIR}"/{spelline.zsh,zsh-spelline.plugin.zsh} "${ZSH_CUSTOM}/plugins/zsh-spelline/" \
  || { echo "not ok - plugin copy failed"; exit 1; }

# 3. Configure .zshrc
cat > ~/.zshrc <<'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
plugins=(zsh-spelline)
source "$ZSH/oh-my-zsh.sh"
ZSHRC

# 4. Source (|| true because OMZ may return non-zero in non-interactive)
source ~/.zshrc || true

# 5. Verify
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

# 6. Verify end-to-end via spelline_query
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
rm -rf ~/.oh-my-zsh

exit $fail
