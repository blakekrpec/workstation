# graphify

**graphify** (`~/.claude/skills/graphify/SKILL.md`) — any input (code, docs, papers, images) to knowledge graph with clustered communities, HTML visualization, and BFS/DFS query tools.

## Trigger

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

## Usage

```bash
graphify <file|dir|url>   # Generate knowledge graph
graphify query <term>     # Query the graph
```

Graphify install is managed by Ansible (`roles/llm_augments/tasks/graphify.yml`). This file is overwritten on reinstalls, not appended.
