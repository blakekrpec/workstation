# beads (`bd`)

Git-native issue tracker built for AI coding agents. Issues live next to
your code instead of in a separate web app, and survive context
compaction — an agent can `bd ready` to recover "what was I doing" even
after losing all conversation history.

Upstream: https://github.com/gastownhall/beads

## What's machine-wide vs. per-repo

- **Machine-wide** (this repo, `roles/llm_augments/tasks/beads.yml`): installs
  the `bd` binary via npm. That's it — installing the binary does not turn
  tracking on anywhere.
- **Per-repo** (opt-in): running `bd init` in a repo is what actually turns
  beads on *for that repo*. Nothing happens automatically just because `bd`
  is on PATH.

Use the [`bd-init`](../../dotfiles/claude/skills/bd-init/SKILL.md) Claude
skill to do the per-repo step — ask Claude to "set up beads in this repo"
and it runs `bd init` with the right guardrails (see that skill file for
what it checks).

## What `bd init` sets up in a repo

One command creates, in the target repo, then commits it all as a single
commit (no flag to suppress that commit):

| Path | Tracked in git? | Purpose |
|---|---|---|
| `.beads/config.yaml`, `.beads/metadata.json`, `.beads/README.md` | yes | static config |
| `.beads/hooks/*` | yes | git hook scripts bd points `core.hooksPath` at |
| `.beads/issues.jsonl` | yes | passive export snapshot, for diffing/interchange — **not** the source of truth |
| `.beads/embeddeddolt/` | **no** (gitignored) | the actual issue database (Dolt) |
| `CLAUDE.md` / `AGENTS.md` | yes | tells any agent to use `bd`, not TODO lists |
| `.claude/settings.json` | yes | registers a `SessionStart` hook: `bd prime` |

## How Claude "knows" to use it

Purely the `SessionStart` hook in `.claude/settings.json`, committed into
the repo. Every new Claude Code session started inside a repo that has run
`bd init` fires `bd prime`, which dumps beads workflow instructions into
context automatically. No global config, no magic — if a repo doesn't have
that hook, Claude won't touch `bd` in it.

## Everyday commands

```bash
bd ready                      # what's unblocked and available
bd create "title" -t task -p 2   # file a new issue
bd update <id> --claim        # claim it
bd close <id>                 # done
bd dolt push                  # sync the DB to the remote (see below)
```

## How the Dolt DB integrates with git (the "partially tracked" part)

Beads issue data lives in **Dolt**, a separate versioned database engine
with its own commit/branch/push/pull model that happens to look like git's.
It is not the same store as your code:

- `.beads/embeddeddolt/` is gitignored outright. `git log`, `git diff`,
  `git clone` never see the actual issues — a fresh clone of the repo has
  the *config* for beads but an empty local database until `bd` creates or
  hydrates one.
- Cross-machine sync happens via `bd dolt push` / `bd dolt pull`, which
  behind the scenes push to the **same remote URL as your git origin**
  (`.beads/config.yaml`: `sync.remote: git+ssh://git@github.com/...`) but
  under a separate ref namespace (`refs/dolt/data`), not `refs/heads/*`.
  So the issue history physically lives in the same GitHub repo as your
  code, over the same SSH transport — but as a parallel history your normal
  `git log`/`git push` never touches, sees, or can conflict with.
  Push it explicitly with `bd dolt push`; nothing does this for you.
- `.beads/issues.jsonl` (committed, plain-text) is a one-way export
  snapshot — good for humans skimming a diff or for interchange with other
  tools, but disabled by default (`export.auto: false` in config.yaml) and
  never read back in as the source of truth. Don't hand-edit it expecting
  `bd` to pick it up.

In short: **scaffolding + hooks travel with `git clone` as normal;
the actual issues do not, and need an explicit `bd dolt push`/`pull` to
move between machines.**

## Gotchas

- `bd init`'s auto-commit does not know about unrelated uncommitted changes
  in your working tree — stash them first (the `bd-init` skill does this).
- `core.hooksPath` gets pointed at `.beads/hooks/` in **local, uncommitted**
  git config (`.git/config`), so a fresh clone needs `bd init` (or at least
  its hook-install step) re-run before those git hooks are live there too.
