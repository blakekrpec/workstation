# workstation

Ansible-managed Ubuntu workstation. One playbook, one repo: Neovim, Node,
Claude Code and its augments, fonts, shell, Starship, Ghostty, GNOME, Docker,
Chrome, Obsidian — everything needed for a reproducible dev environment.

Ubuntu is first class. Windows is a deliberate bolt-on: it gets Neovim and
Claude Code from [`neovim-config`](https://github.com/blakekrpec/neovim-config)'s
`scripts/setup.ps1` and nothing from this repo.

---

## Getting started

```bash
git clone https://github.com/blakekrpec/workstation.git ~/workstation
~/workstation/bootstrap.sh
```

That's the whole install. `bootstrap.sh` installs `ansible-core`, pulls the
Galaxy collections, and runs `site.yml`. It prompts once for your sudo password.

**Do not run it with `sudo`.** The playbook runs as you and escalates per task.
Under `sudo`, `HOME` is `/root`, so `workstation_repo` resolves under `/root` and
`site.yml`'s own assert stops the run — and it would not save a prompt anyway,
since you would type the password at `sudo` instead.

The checkout path matters — dotfiles are symlinked out of it, and `site.yml`
refuses to run if the repo isn't where `group_vars/all.yml` says it is.

After it finishes, open a new shell (or `exec bash`) so the `~/.bashrc.d`
fragments load.

---

## Running it

```bash
./bootstrap.sh                       # everything (profile: full, default)
./bootstrap.sh --profile dev         # work layer (visual/editor setup)
./bootstrap.sh --only claude         # exactly one role, ignoring the profile
./bootstrap.sh --only ghostty,neovim,gnome  # multiple roles (comma-separated)
./bootstrap.sh --only ghostty --only neovim # or repeated --only flags
./bootstrap.sh --list                # show the profiles
./bootstrap.sh --check --diff        # dry run
```

Unrecognised flags pass straight through to `ansible-playbook`, so `--tags`,
`-e key=value`, `-v` and friends all work.

A second consecutive run must report `changed=0`. If it doesn't, that's a bug
in a role, not normal drift.

### Profiles

This repo uses a **two-profile model** designed for the work/personal machine split:

| Profile | Use Case | Roles |
|---|---|---|
| `dev` | **Work machine** — layer your visual/editor/desktop setup on top of work's own ansible (which provides opencode, docker, internal tools). | base, shell, git, fonts, node, neovim, starship, chrome, obsidian, ghostty, gnome, nvidia |
| `full` *(default)* | **Personal machine** — everything. `dev` plus the tools work provides its own way. | `dev` + claude, llm_augments, docker |

Profiles are defined in `group_vars/all.yml`. `--tags` selects *within* the active profile; `--only` ignores the profile entirely and runs the role(s) you name (comma-separated or repeated flags).

**At work:**
```bash
./bootstrap.sh --profile dev                # full visual/editor layer
./bootstrap.sh --only ghostty,gnome         # just desktop bits
```

**On your personal machine:**
```bash
./bootstrap.sh                              # everything (default: full)
```

See `AGENTS.md` for the "which profile?" decision tree when adding new roles.

---

## What's managed

| Role | What it does |
|---|---|
| `base` | apt packages: build tools, ripgrep, fd, jq, clipboard, python3-venv |
| `shell` | `~/.bashrc.d/` fragments + the one managed loader block in `~/.bashrc` |
| `git` | `~/.gitconfig` + untracked `~/.gitconfig.local` for machine-specific overrides |
| `fonts` | 0xProto Nerd Font, per-user, no sudo |
| `node` | nvm + Node LTS (Claude Code needs v22+ and must be nvm-managed to self-update) |
| `neovim` | pinned Neovim release + clones `neovim-config` to `~/.config/nvim` |
| `starship` | Starship cross-shell prompt, pinned release, Rose Pine theme |
| `claude` | Claude Code CLI + symlinks `CLAUDE.md`, `graphify.md`, `skills/`, `agents/`, `commands/`; merges managed keys into `settings.json` |
| `llm_augments` | rtk, beads, graphify, caveman |
| `chrome` | Google Chrome stable via official deb822 apt source |
| `obsidian` | Obsidian from GitHub releases (.deb), pinned version |
| `docker` | Docker CE + nvidia-container-toolkit with runtime configured |
| `ghostty` | Ghostty terminal via snap (classic), Rose Pine theme with transparency |
| `gnome` | GNOME extensions (Vitals from extensions.gnome.org), dconf settings, keybinds, favorite apps |

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

Marketplaces and enabled plugins reproduce on the next machine because they live
in `dotfiles/claude/settings.managed.json`, which the role merges into
`~/.claude/settings.json`. That file is deliberately **not** symlinked: Claude
Code persists runtime preferences by writing it — `model` from `/model`, `theme`
from `/config` — so a symlink turned every model switch into a diff in this repo.
Only the managed keys are tracked; everything else stays machine-local.

After editing `settings.managed.json`, run `./bootstrap.sh --only claude` to
apply it. Merging is additive: removing a key from that file does not remove it
from machines that already have it — set it to `false` instead, or prune by hand.

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
`defaults/main.yml`: `CLAUDE.md`, `graphify.md`, `skills/`, `agents/`,
`commands/` — plus `settings.json`, which is merged rather than linked. Never
link the directory itself. `.gitignore` denies the state paths as a second line
of defence.

Tool integrations like rtk and graphify use an **import-based pattern**:
`CLAUDE.md` contains `@RTK.md` and `@graphify.md` import lines; the tool-specific
content lives in separate files that get overwritten (not appended) on updates.
This prevents duplicate content when running the playbook on a second machine
where the committed files already carry the imports.

---

## Layout

```
site.yml                  role order, tags, profile gating
ansible.cfg               inventory path, roles path, output format
bootstrap.sh              the only shell script here
group_vars/all.yml        profiles, pinned versions, paths
host_vars/<hostname>.yml  per-machine overrides, loaded by real hostname
dotfiles/                 symlink sources, mirroring $HOME
roles/                    base shell git fonts node neovim claude llm_augments
                          chrome obsidian docker ghostty gnome (+ link helper)
```

## Related repos

- [`neovim-config`](https://github.com/blakekrpec/neovim-config) — the Neovim
  config, cloned to `~/.config/nvim` by `roles/neovim`. Owns the Windows
  installer. Machine setup does not belong there.
