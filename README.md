# 🧙 zsh-spelline

LLM-powered command generator for zsh. Type a natural language request, press a key, and get a shell command.

Works with **any LLM CLI or wrapper** that reads from stdin and writes to stdout.

## Usage

Type a natural language description of what you want, then press **Ctrl+G** (default).

```
$ list files larger than 100MB
  ↓ [Ctrl+G]
$ find . -type f -size +100M
```

Multiple candidates are shown via `fzf` when applicable.

Press **Ctrl+C** or **ESC** to cancel while waiting for the LLM response.

Press **Alt+G** to search previous requests with `fzf`.

## Install

> [!WARNING]
> This plugin can generate dangerous commands. Read the [Disclaimer](#%EF%B8%8F-disclaimer) and make sure you understand the risks before use.

> [!NOTE]
> This plugin does not include an LLM. You need to install an LLM CLI tool (e.g., `claude`, `ollama`) separately and set `ZSH_SPELLINE_CMD` to point to it.

### Oh My Zsh

```bash
git clone https://github.com/wateret/zsh-spelline ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-spelline
```

Add the plugin and CMD to `.zshrc`:

```zsh
ZSH_SPELLINE_CMD="ollama run qwen2.5-coder" # Or any LLM backend
plugins=(... zsh-spelline)
```

### zinit

```zsh
ZSH_SPELLINE_CMD="ollama run qwen2.5-coder" # Or any LLM backend
zinit light wateret/zsh-spelline
```

### Manual

```bash
git clone https://github.com/wateret/zsh-spelline ~/.zsh/zsh-spelline
echo 'source ~/.zsh/zsh-spelline/spelline.zsh' >> ~/.zshrc
echo 'ZSH_SPELLINE_CMD="ollama run qwen2.5-coder"' >> ~/.zshrc  # Or any LLM backend
```

### Set LLM backend

Set `ZSH_SPELLINE_CMD` in your `.zshrc` to tell the plugin which LLM CLI to use:

```zsh
# Ollama (local)
export ZSH_SPELLINE_CMD="ollama run qwen2.5-coder"

# Claude
export ZSH_SPELLINE_CMD="claude -p --bare --no-session-persistence"

# Any command that reads stdin and writes stdout
export ZSH_SPELLINE_CMD="my-custom-llm --flag"
```

The plugin will not work until this variable is set.

## Configuration

Set these variables in `.zshrc` **before** the plugin is loaded:

| Variable | Default | Description |
|----------|---------|-------------|
| `ZSH_SPELLINE_KEYBINDING` | `^G` (Ctrl+G) | Keybinding to trigger generation (empty = no auto-bind) |
| `ZSH_SPELLINE_HISTORY_KEYBINDING` | `^[g` (Alt+G) | Keybinding for history search |
| `ZSH_SPELLINE_CMD` | (empty) | LLM CLI command (reads stdin, writes stdout) |
| `ZSH_SPELLINE_CONTEXT_LINES` | `50` | Tmux scrollback lines to include as context |
| `ZSH_SPELLINE_HISTORY_LINES` | `50` | Recent shell history entries to include |
| `ZSH_SPELLINE_LOG_DIR` | (empty) | Directory for prompt/response logs |
| `ZSH_SPELLINE_MAX_CANDIDATES` | `10` | Max candidates for multi-option responses |
| `ZSH_SPELLINE_SPINNER` | `braille` | Spinner style: `braille`, `ascii` |
| `ZSH_SPELLINE_SPINNER_COLOR` | `animated` | Spinner color: `animated`, `plain`, or a color number |
| `ZSH_SPELLINE_VERBOSE_AFTER` | `15` | Seconds before showing cancel hint (0 = never) |
| `ZSH_SPELLINE_PROMPT_FUNC` | `_spelline_build_prompt` | Custom prompt generator function |
| `ZSH_SPELLINE_HISTORY_FILE` | `~/.zsh_spelline_history` | Request history file (empty = no history) |

### Custom Keybinding

```zsh
ZSH_SPELLINE_KEYBINDING='^[a'  # Alt+A (an example)
```

## Requirements

- **zsh** 5.0+
- An LLM CLI (e.g., `claude`, `openai`, `ollama`)
- **fzf** (optional) — for selecting among multiple candidates and history search
- **tmux** (optional) — for terminal context in prompts

## ⚠️ Disclaimer

**Use at your own risk.** By using this plugin you accept full responsibility for every command you execute.

- **LLM output is unreliable.** Generated commands can be incorrect, incomplete, or destructive (e.g., `rm -rf /`, overwriting files, dropping databases). Always read and understand a command before pressing Enter.
- **No liability.** The authors accept no liability for any damage, data loss, or security incidents caused by commands this plugin produces.
- **Sensitive data exposure.** This plugin sends your working directory, recent shell history, and tmux scrollback to an external LLM service. Tokens, passwords, API keys, or internal hostnames visible in your terminal may be included in the request.
- **Prompt injection.** The LLM prompt is constructed from untrusted terminal content. Malicious output from programs (e.g., `curl`, `cat`, `git log`) could manipulate the prompt to generate harmful commands. Be especially cautious after viewing untrusted content.
- **No execution guard.** Generated commands are placed into the ZLE editing buffer — they are not executed automatically. However, it is still your responsibility to verify the command before pressing Enter.
