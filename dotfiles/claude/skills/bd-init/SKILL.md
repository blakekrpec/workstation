# bd-init

Onboard a git repo onto [Beads](https://github.com/gastownhall/beads) (`bd`)
issue tracking. `bd` itself is installed machine-wide by the `llm_augments`
Ansible role (`roles/llm_augments/tasks/beads.yml`) — this skill just runs
its one-shot per-repo setup command and reports what changed.

## Trigger

Use this skill when the user asks to:
- "set up beads in this repo" / "add bd tracking here" / "bd init this project"
- onboard a *new* repo (not `~/workstation`, which already has it) onto beads

## Preconditions

1. Must be inside a git repo (`git rev-parse --is-inside-work-tree`).
2. `bd` must be on PATH (`command -v bd`; if missing, tell the user to run
   the `llm_augments` Ansible role — don't install it ad hoc here).
3. Check it isn't already initialized: `bd where` or `test -d .beads`. If
   `.beads/` exists, stop and report status instead of re-running init.

## What `bd init` actually does

One command (`bd init --non-interactive`) does the entire onboarding:
creates `.beads/` (embedded Dolt DB + git hooks + gitignore rules), writes
`AGENTS.md` and a project-root `CLAUDE.md` with the beads workflow block,
registers a Claude Code `SessionStart` hook in `.claude/settings.json` that
runs `bd prime` every session, sets up Codex native hooks too, and **auto-commits
all of that as a single commit** — there is no flag to suppress the commit.

Because of that auto-commit, **always check `git status --short` first**. If
there are unrelated uncommitted changes, stash them (`git stash push -u -m
"wip before bd init"`) before running `bd init`, then `git stash pop`
afterward — otherwise unrelated work rides along in bd's commit.

## Workflow

1. `git status --short` — if dirty, `git stash push -u -m "wip before bd init"`.
2. Tell the user what's about to happen (auto-commit, files created) before
   running — this is a repo-visible action, not a silent one.
3. Run `bd init --non-interactive` (prefix defaults to the repo directory
   name; pass `-p <prefix>` only if the user wants something else).
4. `git stash pop` if step 1 stashed anything.
5. Report: files created, the commit it made, and next steps
   (`bd quickstart`, `bd create "title" -t task -p 2`, `bd ready`).

## Notes

- If the repo already has a root `CLAUDE.md`, `bd init` inserts a managed
  `<!-- BEGIN BEADS INTEGRATION -->` block into it rather than overwriting —
  safe to run on a repo with existing agent docs.
- `bd dolt push`/`pull` (not plain git) syncs the actual issue DB across
  machines, via `refs/dolt/data` on the repo's existing git remote — separate
  from normal code history. Only mention this if the user asks about
  multi-machine sync.
