# caveman

Claude Code plugin that compresses *output* — terse, fragment-heavy replies
— while byte-preserving code, paths, URLs and technical terms. Doesn't
change what Claude does, only how replies read.

Upstream: https://github.com/JuliusBrussee/caveman

## What's installed, and where

Machine-wide, via `roles/llm_augments/tasks/caveman.yml`, but through
Claude Code's own **plugin marketplace** rather than symlinked from this
repo — that's what lets `claude plugin update` keep working normally
instead of fighting the Ansible-managed files. The role just adds the
marketplace and installs the plugin if not already present.

## Turning it off

It's opinionable enough to warrant an explicit off switch:
- Everywhere: `llm_augment_caveman: false` in `host_vars/<hostname>.yml`,
  then reconverge.
- One machine, without touching Ansible: `claude plugin disable caveman`.
- One session: `/caveman off` or say "stop caveman" / "normal mode".

## How Claude knows to use it

Once the plugin is installed and enabled, it hooks session start and stays
active by default — no per-repo opt-in like beads. Level defaults to
`full`; switch with `/caveman lite|full|ultra|wenyan-lite|wenyan-full|wenyan-ultra|off`.
