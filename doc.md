# Documentation

Set these variables in `.zshrc` **before** the plugin is loaded.

## Quick reference

| Variable | Default | Description |
|----------|---------|-------------|
| **`ZSH_SPELLINE_CMD`** | (empty) | LLM CLI command (reads stdin, writes stdout) |
| **`ZSH_SPELLINE_KEYBINDING`** | `^G` (Ctrl+G) | Keybinding to trigger generation |
| **`ZSH_SPELLINE_HISTORY_KEYBINDING`** | `^[g` (Alt+G) | Keybinding for history search |
| `ZSH_SPELLINE_LOG_DIR` | (empty) | Directory for prompt/response logs |
| `ZSH_SPELLINE_MAX_CANDIDATES` | `10` | Max candidates for multi-option responses |
| `ZSH_SPELLINE_SPINNER` | `braille` | Spinner style: `braille`, `ascii` |
| `ZSH_SPELLINE_SPINNER_COLOR` | `animated` | Spinner color: `animated`, `plain`, or a color number |
| `ZSH_SPELLINE_VERBOSE_AFTER` | `15` | Seconds before showing cancel hint (0 = never) |
| `ZSH_SPELLINE_PROMPT_FUNC` | `_spelline_build_prompt` | Custom prompt generator function |
| `ZSH_SPELLINE_HISTORY_FILE` | `~/.zsh_spelline_history` | Request history file (empty = no history) |

## LLM backend (`ZSH_SPELLINE_CMD`)

The plugin calls this command with the prompt on stdin and reads the generated command from stdout. Any CLI that follows this convention will work.

```zsh
# Ollama (local)
export ZSH_SPELLINE_CMD="ollama run qwen2.5-coder"

# Claude
export ZSH_SPELLINE_CMD="claude -p --bare --no-session-persistence"

# OpenAI Codex CLI
export ZSH_SPELLINE_CMD="codex exec -"

# Any command that reads stdin and writes stdout
export ZSH_SPELLINE_CMD="my-custom-llm --flag"
```

The plugin will not work until this variable is set.

## Benchmark Results

| `ZSH_SPELLINE_CMD` | Total | Pass | Fail | Pass Rate |
|----------|------:|-----:|-----:|----------:|
| `ollama run qwen2.5-coder:7b` | 70 | 56 | 14 | 80% |
| `gemini -m gemini-2.5-flash` | 70 | 56 | 14 | 80% |
| `codex -m gpt-5.4 exec -` | 70 | 63 | 7 | 90% |
| `claude -p --bare --no-session-persistence` (Opus 4.6) | 70 | 69 | 1 | 99% |

> Results are a snapshot and will vary — LLM and agent backends are non-deterministic, and model behavior changes with service updates.

## Logging

When `ZSH_SPELLINE_LOG_DIR` is set, each invocation writes a markdown log file containing the config snapshot, prompt, and LLM response.

```zsh
export ZSH_SPELLINE_LOG_DIR=/tmp/zsh-spelline-logs
```

Log filename format: `<PID>_<YYYYMMDD_HHMMSS>_<ms>.log`

## Request history

Previous requests are saved to `ZSH_SPELLINE_HISTORY_FILE` and can be searched with `fzf` via the history keybinding (default: Alt+G).

```zsh
# Default path
ZSH_SPELLINE_HISTORY_FILE=~/.zsh_spelline_history

# Disable history
ZSH_SPELLINE_HISTORY_FILE=''
```

## Custom prompt function

Override `ZSH_SPELLINE_PROMPT_FUNC` to customize the prompt sent to the LLM. The function receives the user's request as `$1` and should print the full prompt to stdout.

```zsh
my_prompt() {
  echo "You are a shell expert. Generate a zsh command for: $1"
}
ZSH_SPELLINE_PROMPT_FUNC=my_prompt
```

## Public API

These functions can be called from scripts or the command line without ZLE.

### `spelline_query`

Synchronous, non-interactive command generation. Builds a prompt, calls the LLM, parses the result, and prints the first candidate to stdout.

```zsh
# Usage
spelline_query "find files larger than 1GB"
# Output: find . -type f -size +1G
```

Returns 1 if `ZSH_SPELLINE_CMD` is not set, the request is empty, or the LLM returns no result.
