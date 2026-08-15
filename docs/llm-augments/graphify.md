# graphify

Turns any input — code, docs, PDFs, diagrams, a URL — into a queryable
knowledge graph: clustered communities, an HTML visualization, and
BFS/DFS-style query tools. Useful for "what does this codebase actually
look like" questions an agent can't answer just by grepping.

Upstream: https://github.com/Graphify-Labs/graphify (PyPI package
`graphifyy`, binary `graphify`)

## What's installed, and where

Machine-wide, via `roles/llm_augments/tasks/graphify.yml`:
- the `graphify` binary (pipx)
- the `/graphify` Claude Code skill, registered by running `graphify install`
  itself — the role just calls that installer once
- `dotfiles/claude/graphify.md`, imported into the global `~/.claude/CLAUDE.md`
  via `@graphify.md` — this is what tells Claude the skill exists and when
  to reach for it

This one is **global**, not per-repo like beads — once installed, `/graphify`
and the `graphify` CLI work the same in every repo on the machine.

## How Claude knows to use it

The `@graphify.md` import line in `~/.claude/CLAUDE.md` (your global config,
not a per-repo file) points at the skill. When you type `/graphify`, or when
a question is clearly "how does this codebase fit together," Claude loads
the installed skill before answering.

## Usage

```bash
graphify <file|dir|url>   # build/refresh a graph for this input
graphify query <term>     # ask it a question
```

If a `graphify-out/` directory exists in the repo, treat any structural
question about the codebase as a graphify query first, rather than
re-deriving it by hand.
