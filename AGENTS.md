# AGENTS.md — Contributor & Agent Guide

This is a **personal workstation configuration repo** managed by Ansible. It captures my dev environment setup for reproducible deployment on personal machines and selective layering on top of work infrastructure.

---

## Purpose & Work/Personal Boundary

**This repo is for personal machines.** It layers my visual/editor/dev setup on work machines where a corporate Ansible playbook already manages the infrastructure guts (docker, opencode, internal tools, etc.).

**Never capture work-specific items here:**
- Work credentials, secrets, or signing keys
- Work-only tools (e.g., Keeper Security, internal CLIs)
- Work network config (custom DNS, VPN profiles, internal CA certs)
- Work ansible playbook internals or roles

If something is installed by your work's own automation, **don't duplicate it here** — this repo coexists alongside work tooling, not replaces it.

---

## Two Profiles: `dev` and `full`

This repo uses a **two-profile model** designed for the work/personal split:

### `dev` — Work Layer
**Roles:** base, shell, git, fonts, node, neovim, starship, chrome, obsidian, ghostty, gnome

**When to use:** On a work machine where corporate ansible already provides docker, opencode, and infrastructure. Run `./bootstrap.sh --profile dev` to layer your visual/editor/desktop setup on top.

**What's included:**
- Editor stack (neovim + config)
- Shell + prompt (bash fragments, starship)
- Desktop environment (ghostty terminal, gnome settings/keybinds, extensions)
- Browsers & productivity (chrome, obsidian)
- Dev fundamentals (git, fonts, node/nvm)

**What's excluded:** claude, llm_augments (rtk/graphify/beads/caveman), docker — work provides these via opencode + corporate tooling.

### `full` — Personal Machine (default)
**Roles:** `dev` + claude, llm_augments, docker

**When to use:** Your personal machines. Run `./bootstrap.sh` (no flag needed; `full` is the default).

**Additional tools:**
- Claude Code CLI + augments (rtk, graphify, beads, caveman)
- Docker CE + NVIDIA Container Toolkit

---

## How to Decide Which Profile for a New Role

When adding a new tool/app via agent-driven capture or manual extension:

### Add to `dev` if:
- It's a **visual/editor/desktop layer** you want at work on top of corporate ansible
- Examples: a new terminal emulator, IDE, font, gnome extension, shell utility, browser, note-taking app, code formatter
- Test: "Would I want this at work even though work ansible owns docker/llm tooling?" → **dev**

### Add to `full` only if:
- It's a **personal-only infrastructure/LLM tool** that work provides its own way
- Examples: agent tooling (claude/opencode, their augments), container runtimes, databases, cloud CLIs, internal dev services
- Test: "Does work's ansible already install/manage this, or would it conflict with their setup?" → **full only**

### Don't add it at all if:
- It's work-specific (credentials, internal tools, network config)
- It's a one-off manual install not worth automating
- It's already in `base` as an apt package

**When in doubt:** add to `dev`. Most user-facing apps belong there. Only infrastructure guts stay `full`-only.

---

## The `--only` Rule

**Every user-facing app or tool must be its own flat role with a matching tag** so it can be installed individually via `--only`.

This enables:
```bash
./bootstrap.sh --only ghostty,gnome    # Just grab desktop bits at work
./bootstrap.sh --only neovim           # Pull one piece onto a server
```

**How to implement:**
1. New role in `roles/<name>/` with `tasks/main.yml` (+ `defaults/main.yml` if needed).
2. Add to `site.yml` with `tags: [<name>]` and `when: "'<name>' in active_roles"`.
3. Add to the appropriate profile(s) in `group_vars/all.yml`.

Roles stay **flat** — no `meta/main.yml` dependencies that would break `--only` selectability. Ordering in `site.yml` handles install sequence.

---

## Shell Environment: Never Append to `~/.bashrc`

**Rule:** Shell exports, PATH additions, and tool init go in numbered fragments under `dotfiles/bash/bashrc.d/`, **never appended directly to `~/.bashrc`.**

**Why:** The `shell` role symlinks `~/.bashrc.d` to the repo and installs one managed block in `~/.bashrc` that sources all `.sh` files. This lets you add/remove shell config by committing fragments — no grep-guarded appends that pile up and can't be cleanly removed.

**Pattern (see `dotfiles/bash/bashrc.d/40-starship.sh`):**
```bash
# <tool> — one-line description
if command -v <tool> >/dev/null 2>&1; then
    eval "$(<tool> init bash)"  # or export FOO=..., PATH prepend, etc.
fi
```

Number your fragment (`10-`, `20-`, `30-`, `40-`) to control load order. PATH/env setup goes early (10-20), tool init goes later (30-50).

---

## Config, Not Binaries

**Capture configuration, not binary payloads.** Install via:
- Apt package (preferred for anything in Ubuntu repos)
- Pinned GitHub release tarball (for upstream binaries like neovim, starship)
- Official `.deb` download (for third-party apps like chrome, obsidian)
- `gnome-extensions install` from extensions.gnome.org (for GNOME extensions)

**Never vendor:**
- Extension source trees (see the Vitals cleanup — 3.5MB bloat removed)
- Binary blobs, SVGs, generated assets
- Anything that has an upstream package manager or install mechanism

**Do commit:**
- Your config files (`starship.toml`, `ghostty/config`, dconf dumps)
- Dotfiles that you modify (`.gitconfig`, claude `CLAUDE.md`)
- Pin versions in role defaults (`neovim_version`, `starship_version`, `obsidian_version`)

---

## The `~/.claude` Rule

The `~/.claude` directory mixes config (which belongs in git) with credentials and session transcripts (which don't). The `claude` role symlinks **only** the paths listed in `roles/claude/defaults/main.yml`:
- `settings.json`
- `CLAUDE.md`
- `graphify.md`
- `skills/`, `agents/`, `commands/` (directories, not their generated contents)

**Never symlink the `~/.claude` directory itself** — that would expose credentials/session state to git.

### Tool Integration Pattern: `@import` Files, Not Appends

Tools like rtk and graphify want to append content to `CLAUDE.md`. Instead of letting them append (which causes duplication on a second machine when the guard file is absent but the content is already committed), we use an **import-based pattern**:

- `CLAUDE.md` contains `@RTK.md` and `@graphify.md` import lines
- The tool-specific content lives in separate files (`RTK.md`, `graphify.md`) that are **overwritten** (not appended) on each install
- The `llm_augments` role tasks guard the tool's installer with a **grep-before-run check**: only run `rtk init -g` if `@RTK.md` is absent from `CLAUDE.md`

This prevents duplicate imports when the committed `CLAUDE.md` already carries the `@` line on a second machine.

**Pattern for new tool integrations:**
1. Create `dotfiles/claude/<tool>.md` for the tool's content.
2. Add `@<tool>.md` to `CLAUDE.md` manually (committed once).
3. Guard the tool's installer with: `grep -qF '@<tool>.md' ~/.claude/CLAUDE.md || <install command>`.
4. Add `<tool>.md` to `claude_linked_paths` in `roles/claude/defaults/main.yml`.

---

## Idempotency

**A second consecutive run must report `changed=0`.** If it doesn't, that's a bug in the role.

**Patterns for idempotency:**
- Pinned versions: check installed version; reinstall only when the pin isn't present (neovim, starship).
- File presence: `creates:` guards on commands that should run once (curl installs, clones).
- Content-based guards: slurp + grep + conditional for appends that must not duplicate (rtk/graphify `@import` checks, nvidia runtime in `daemon.json`).
- `blockinfile` with unique markers for managed blocks (bashrc loader, PATH exports).
- `stat` before `copy` for "install if absent" .deb downloads.

When porting a tool that appends or patches config, **always add a guard** that checks if the change is already present before running the mutating command.

---

## Machine-Specific Overrides: `~/.gitconfig.local`

Some config legitimately varies per machine (work email, signing keys, SSH config). Use the **`.local` pattern** instead of committing multiple versions:

1. Committed file includes the override at the end (e.g., `.gitconfig` ends with `[include] path = ~/.gitconfig.local`).
2. Role creates the `.local` stub with `force: false` (never clobbers an existing file).
3. Machine-specific values go in the `.local` file (untracked).

See `roles/git` for the canonical example.

For per-machine Ansible vars, use `host_vars/<hostname>.yml` (loaded by real hostname, not inventory name). Example: `docker_daemon_dns` for a specific work network.

---

## Where Things Go

Quick reference for adding new stuff:

| What | Where | Example |
|---|---|---|
| Apt package | `roles/base/tasks/main.yml` | `ripgrep`, `jq`, `fd-find` |
| Shell export / PATH | `dotfiles/bash/bashrc.d/NN-<name>.sh` | `30-opencode.sh` |
| Tool with own install | New role in `roles/<name>/` + tag in `site.yml` + profile | `starship`, `ghostty`, `docker` |
| Config file | `dotfiles/<name>/` symlinked by the role | `starship/starship.toml`, `ghostty/config` |
| Claude skill/agent | `dotfiles/claude/skills/<name>/` or `dotfiles/claude/agents/<name>/` | Custom skills, local agents |
| GNOME extension | `gnome_extensions_from_ego` list in `roles/gnome/defaults/main.yml` | Vitals, installed via EGO API |
| GNOME settings | Dconf dump to `dotfiles/gnome/<tree>.ini`, add path to `gnome_dconf_trees` | `vitals.ini`, `shell.ini` |

---

## Testing & Verification

Before committing:
- Run `./bootstrap.sh --check` (dry run) to preview changes.
- Run the playbook twice; the second run must show `changed=0`.
- Test `--only <role>` for any new role you add (ensures it's independently runnable).
- Verify `./bootstrap.sh --list` renders the profiles cleanly.

On this work machine, **don't run a full converge** (work's ansible owns the guts and may conflict). Use `--profile dev --check` or `--only <role> --check` to validate new roles without actually changing the system.

---

## Bumping Versions

When upstream releases a new version of a pinned tool:
1. Update the version var in the role's `defaults/main.yml` (e.g., `neovim_version: v0.13.0`).
2. Run the playbook; the role will detect the pin mismatch and reinstall.
3. Verify with the tool's `--version`.
4. Commit the new pin + any updated lockfiles (e.g., `neovim-config/lazy-lock.json` if plugins changed).

This ensures two machines converged months apart get the same tooling, while still allowing deliberate upgrades.

### Critical: Docker Version Pinning

**Docker CE, containerd, and nvidia-container-toolkit are pinned** in `roles/docker/defaults/main.yml`. Docker updates can break container runtimes, networking, or GPU passthrough.

```yaml
docker_version: "5:29.6.2-1~ubuntu.24.04~noble"
containerd_version: "2.2.6-1~ubuntu.24.04~noble"
nvidia_toolkit_version: "1.19.1-1"
```

**To bump Docker versions:**
1. Check available versions: `apt-cache madison docker-ce`
2. Update all three pins together (docker-ce, docker-ce-cli, containerd.io)
3. Test on a disposable VM first — Docker breakage is painful
4. Verify containers still work after upgrade: `docker run hello-world`, `docker run --gpus all nvidia/cuda:12.0-base nvidia-smi`

---

## One-Time Cleanup: Stray `.bashrc` Starship Init

If you installed starship via an ad-hoc script before adding this repo, you may have a raw `eval "$(starship init bash)"` line in `~/.bashrc` outside the Ansible-managed block. The new `40-starship.sh` fragment supersedes it.

**To clean up (manual, one-time):**
```bash
# Find the line (typically near the end of ~/.bashrc)
grep -n "starship init bash" ~/.bashrc

# Delete it with your editor, or:
sed -i '/eval.*starship init bash/d' ~/.bashrc
```

Fresh machines won't have this issue — the fragment is the only starship init.
