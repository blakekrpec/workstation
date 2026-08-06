# Global instructions

Machine setup lives in `~/workstation` (Ansible, Ubuntu-first). The Neovim
config is a separate repo cloned to `~/.config/nvim`. Windows is a bolt-on:
`neovim-config/scripts/setup.ps1` only.

## Conventions

- Ubuntu changes go through Ansible, not ad-hoc shell. If a fix required
  running a command by hand, it belongs in a role.
- Shell environment additions go in `~/workstation/dotfiles/bash/bashrc.d/`
  as a numbered fragment — never appended to `~/.bashrc`.

## Tool integrations

@RTK.md
@graphify.md
