# Global instructions

Machine setup lives in `~/src/workstation` (Ansible, Ubuntu-first). The Neovim
config is a separate repo cloned to `~/.config/nvim`. Windows is a bolt-on:
`neovim-config/scripts/setup.ps1` only.

## Conventions

- Ubuntu changes go through Ansible, not ad-hoc shell. If a fix required
  running a command by hand, it belongs in a role.
- Shell environment additions go in `~/src/workstation/dotfiles/bash/bashrc.d/`
  as a numbered fragment — never appended to `~/.bashrc`.

@RTK.md
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
