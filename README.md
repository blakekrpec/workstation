# workstation

Ansible-managed Ubuntu workstation. One playbook, one repo: Neovim, Node,
Claude Code and its augments, fonts, shell — and, as they land, Ghostty, GNOME
and the rest of the desktop.

Ubuntu is first class. Windows is a deliberate bolt-on: it gets Neovim and
Claude Code from [`neovim-config`](https://github.com/blakekrpec/neovim-config)'s
`scripts/setup.ps1` and nothing from this repo.

---

## Getting started

```bash
git clone https://github.com/blakekrpec/workstation.git ~/src/workstation
~/src/workstation/bootstrap.sh
```

That's the whole install. `bootstrap.sh` installs `ansible-core`, pulls the
Galaxy collections, and runs `site.yml`. It will prompt once for your sudo
password.

The checkout path matters — dotfiles are symlinked out of it, and `site.yml`
refuses to run if the repo isn't where `group_vars/all.yml` says it is.

After it finishes, open a new shell (or `exec bash`) so the `~/.bashrc.d`
fragments load.

---

## Running it

```bash
./bootstrap.sh                       # everything (profile: full)
./bootstrap.sh --profile coding      # a named subset
./bootstrap.sh --only claude         # exactly one role, ignoring the profile
./bootstrap.sh --list                # show the profiles
./bootstrap.sh --check --diff        # dry run
```

Unrecognised flags pass straight through to `ansible-playbook`, so `--tags`,
`-e key=value`, `-v` and friends all work.

A second consecutive run must report `changed=0`. If it doesn't, that's a bug
in a role, not normal drift.

### Profiles

| Profile | Roles |
|---|---|
| `full` *(default)* | base, shell, fonts, node, neovim, claude, llm_augments |
| `coding` | base, shell, node, neovim, claude, llm_augments — no desktop bits; good for servers and WSL |
| `llm` | base, shell, node, claude, llm_augments — agent tooling, no Neovim |
| `editor` | base, shell, fonts, node, neovim — no agent tooling |
| `minimal` | base, shell |

Profiles are defined in one place, `group_vars/all.yml`. Add one there and it
is immediately available to `--profile`.

`--tags` selects *within* the active profile; `--only` ignores the profile
entirely and runs the single role you name.

---

## What's managed

| Role | What it does |
|---|---|
| `base` | apt packages: build tools, ripgrep, fd, jq, clipboard, python3-venv |
| `shell` | `~/.bashrc.d/` fragments + the one managed loader block in `~/.bashrc` |
| `fonts` | 0xProto Nerd Font, per-user, no sudo |
| `node` | nvm + Node LTS (Claude Code needs v22+ and must be nvm-managed to self-update) |
| `neovim` | pinned Neovim release + clones `neovim-config` to `~/.config/nvim` |
| `claude` | Claude Code CLI + symlinks `settings.json`, `CLAUDE.md`, `skills/`, `agents/`, `commands/` |
| `llm_augments` | rtk, beads, graphify, caveman |

`roles/link` is a helper, not a top-level role — it symlinks a path and moves
anything real it displaces to `~/.workstation-backup/` (mirroring its location
under `$HOME`) instead of deleting it.

### LLM augments

| Tool | What it is | Install |
|---|---|---|
| [rtk](https://github.com/rtk-ai/rtk) | Rust CLI proxy; strips noise from `git status`, `cargo test`, `grep` etc. before it reaches the model | binary → `~/.local/bin` |
| [beads](https://github.com/gastownhall/beads) | Git-native issue tracker (`bd`); agent memory that survives compaction | `npm -g @beads/bd` |
| [graphify](https://github.com/Graphify-Labs/graphify) | Turns a repo into a queryable knowledge graph; `/graphify` skill | `pipx install graphifyy` |
| [caveman](https://github.com/JuliusBrussee/caveman) | Compresses *output* by answering tersely; code and paths byte-preserved | Claude Code plugin |

Each is individually switchable — see `roles/llm_augments/defaults/main.yml`:

```yaml
# host_vars/<hostname>.yml
llm_augment_caveman: false
```

**caveman is opinionated**: it changes how every reply reads. Turn it off with
the flag above, or per-machine with `claude plugin disable caveman`.

Because `~/.claude/settings.json` is a symlink into this repo, `claude plugin
install` writes plugin state straight into git — so marketplaces and enabled
plugins reproduce on the next machine with no extra work.

---

## Version pinning

Two things are pinned so two machines converged a month apart get the same
setup, and both are bumped deliberately:

- **Neovim** — `neovim_version` in `group_vars/all.yml`. Not `stable`, which
  moves. Bump the tag, converge, commit.
- **Plugins** — `neovim-config/lazy-lock.json`, tracked in that repo, pinning
  all 35 plugins by commit. The `neovim` role runs `:Lazy! restore` after the
  clone changes. Bump with `:Lazy update` inside nvim, then commit the lockfile.

`nvm` is pinned too; Node deliberately floats at LTS.

---

## Adding things

- **A shell export** → a new numbered file in `dotfiles/bash/bashrc.d/`. That
  directory is symlinked, so it takes effect in the next shell — no run needed.
  Never append to `~/.bashrc`; one managed block owns the loader.
- **A Claude skill / agent / command** → a new subdirectory under
  `dotfiles/claude/{skills,agents,commands}/`. Same story, symlinked wholesale.
- **A package** → `roles/base/tasks/main.yml`.
- **Another LLM augment** → a task file in `roles/llm_augments/tasks/`, a flag
  in that role's `defaults`, and one `import_tasks` line in its `main.yml`.
- **A tool with its own install dance** → its own role, tagged, added to
  `site.yml` and to whichever profiles should get it.

### The `~/.claude` rule

That directory mixes config with credentials and session transcripts
(`.credentials.json`, `projects/`, `sessions/`, `history.jsonl`,
`shell-snapshots/`). `roles/claude` symlinks **only** the paths listed in its
`defaults/main.yml`. Never link the directory itself. `.gitignore` denies the
state paths as a second line of defence.

---

## Layout

```
site.yml                  role order, tags, profile gating
ansible.cfg               inventory path, roles path, output format
bootstrap.sh              the only shell script here
group_vars/all.yml        profiles, pinned versions, paths
host_vars/<hostname>.yml  per-machine overrides, loaded by real hostname
dotfiles/                 symlink sources, mirroring $HOME
roles/                    base shell fonts node neovim claude llm_augments + link
```

## Related repos

- [`neovim-config`](https://github.com/blakekrpec/neovim-config) — the Neovim
  config, cloned to `~/.config/nvim` by `roles/neovim`. Owns the Windows
  installer. Machine setup does not belong there.
