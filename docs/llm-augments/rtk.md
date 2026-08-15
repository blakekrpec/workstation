# rtk

Rust CLI proxy that sits in front of noisy dev commands (`git status`,
`cargo test`, `grep`, etc.) and strips the noise before the output ever
reaches the model — fewer tokens spent reading boilerplate output.

Upstream: https://github.com/rtk-ai/rtk

## What's installed, and where

Machine-wide, via `roles/llm_augments/tasks/rtk.yml`:
- the `rtk` binary, installed to `~/.local/bin` (already on `PATH` via
  `dotfiles/bash/bashrc.d/10-path.sh`)
- a `PreToolUse` hook in Claude Code's settings that rewrites matching Bash
  commands to go through `rtk` automatically (`rtk init -g`)
- `dotfiles/claude/RTK.md`, imported into `~/.claude/CLAUDE.md` via `@RTK.md`

Global, like graphify — not something you opt a repo into individually.
Set `rtk_install_hook: false` in `roles/llm_augments/defaults/main.yml` (or a
`host_vars` override) to install just the binary and leave the Claude Code
hook alone.

## How Claude knows to use it

It doesn't have to "know" — the `PreToolUse` hook intercepts matching Bash
tool calls transparently and reroutes them through `rtk` before they run.
`@RTK.md` in `CLAUDE.md` exists mainly so Claude understands *why* command
output looks filtered, not to trigger anything.
