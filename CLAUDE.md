# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```zsh
zsh tests/run_all.sh functional          # run all functional tests
zsh tests/functional/test_parsing.sh    # run a single test file
ZSH_SPELLINE_CMD="claude -p --bare --no-session-persistence" zsh tests/run_all.sh benchmark

# Benchmark flags: --id <id>, --tag <tag>, --dry-run, --delay <secs>
```

No build step — pure zsh plugin.

## Architecture

`spelline.zsh` is the entire plugin. `zsh-spelline.plugin.zsh` is just `source spelline.zsh` for Oh My Zsh.

**Widget flow (`_spelline_generate`):** user buffer → `_spelline_build_prompt` (injects CWD, git status, shell history, tmux scrollback) → stdin of `$ZSH_SPELLINE_CMD` background job → `_spelline_parse_result` → `_spelline_candidates[]` → fzf picker (if multiple) → `BUFFER` replaced.

`spelline_query` is the same flow without ZLE, for scripting.

**Parsing:** `_spelline_parse_result` strips markdown fences and splits on `---`-only lines to produce the candidates array.

**Tests:** `tests/lib/harness.sh` is a minimal TAP assert library. Functional tests source it directly alongside `spelline.zsh`. Benchmark cases live in `tests/benchmark/cases.jsonl` (JSONL with `id`, `request`, `setup[]`, `verify`, `tags[]`); each case runs in a `/tmp` sandbox and requires `jq` and `timeout`/`gtimeout`.

**Config:** `ZSH_SPELLINE_CMD` — required; the LLM CLI (reads stdin, writes stdout). `ZSH_SPELLINE_KEYBINDING` and `ZSH_SPELLINE_HISTORY_KEYBINDING` must be set before sourcing; all other `ZSH_SPELLINE_*` vars can be changed at any time.
