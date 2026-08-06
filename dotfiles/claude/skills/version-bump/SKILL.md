# Version Bump Management

Automated version checking and bump workflow for pinned tools in the workstation Ansible repo.

## Trigger

Use this skill when:
- User asks to "check for updates", "bump versions", "update dependencies"
- Periodic maintenance (e.g., monthly version audit)
- Before a fresh machine deployment to ensure latest stable versions

## Workflow

### 1. Discovery Phase
Scan the repo for all pinned versions:

**Files to check:**
- `group_vars/all.yml` — neovim, nvm, nerd_font versions
- `roles/*/defaults/main.yml` — role-specific pins (starship, obsidian, nvidia_toolkit, gnome extensions)

**Extract pattern:**
```bash
# Find all _version variables
grep -rh "_version:" group_vars/ roles/*/defaults/ | grep -v "^#"
```

### 2. Current State Inventory

Build a structured list:
```yaml
pinned_versions:
  - name: neovim
    current: v0.12.4
    file: group_vars/all.yml
    var: neovim_version
    upstream: https://github.com/neovim/neovim/releases
    check_method: github_releases
  
  - name: starship
    current: v1.26.0
    file: roles/starship/defaults/main.yml
    var: starship_version
    upstream: https://github.com/starship/starship/releases
    check_method: github_releases
  
  - name: obsidian
    current: 1.12.7
    file: roles/obsidian/defaults/main.yml
    var: obsidian_version
    upstream: https://github.com/obsidianmd/obsidian-releases/releases
    check_method: github_releases
  
  - name: nvm
    current: v0.40.1
    file: group_vars/all.yml
    var: nvm_version
    upstream: https://github.com/nvm-sh/nvm/releases
    check_method: github_releases
  
  - name: 0xProto Nerd Font
    current: v3.2.1
    file: group_vars/all.yml
    var: nerd_font_version
    upstream: https://github.com/ryanoasis/nerd-fonts/releases
    check_method: github_releases
  
  - name: nvidia-container-toolkit
    current: 1.19.1-1
    file: roles/docker/defaults/main.yml
    var: nvidia_toolkit_version
    upstream: https://nvidia.github.io/libnvidia-container/
    check_method: apt_repo
  
  - name: docker-ce
    current: "5:29.6.2-1~ubuntu.24.04~noble"
    file: roles/docker/defaults/main.yml
    var: docker_version
    upstream: https://download.docker.com/linux/ubuntu
    check_method: apt_repo
  
  - name: containerd.io
    current: "2.2.6-1~ubuntu.24.04~noble"
    file: roles/docker/defaults/main.yml
    var: containerd_version
    upstream: https://download.docker.com/linux/ubuntu
    check_method: apt_repo
  
  - name: Vitals GNOME Extension
    current: 80
    file: roles/gnome/defaults/main.yml
    var: gnome_extensions_from_ego[0].version
    upstream: https://extensions.gnome.org/extension/1460/vitals/
    check_method: ego_api
```

### 3. Upstream Check Methods

**GitHub Releases (most tools):**
```bash
# Fetch latest release tag
curl -fsSL "https://api.github.com/repos/<org>/<repo>/releases/latest" | jq -r '.tag_name'

# Example for neovim:
curl -fsSL "https://api.github.com/repos/neovim/neovim/releases/latest" | jq -r '.tag_name'
```

**GNOME Extensions (EGO API):**
```bash
# Fetch extension info
curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=<UUID>" | jq -r '.shell_version_map."<shell_version>".version'

# Example for Vitals on GNOME 46:
curl -fsSL 'https://extensions.gnome.org/extension-info/?uuid=Vitals@CoreCoding.com' | jq -r '.shell_version_map."46".version'
```

**Apt repo (nvidia-container-toolkit):**
```bash
# Query available versions
apt-cache madison nvidia-container-toolkit | head -5
# Or check GitHub releases for libnvidia-container
curl -fsSL "https://api.github.com/repos/NVIDIA/libnvidia-container/releases/latest" | jq -r '.tag_name'
```

### 4. Report Generation

Create a markdown report:

```markdown
# Version Bump Report — 2026-08-05

## Outdated (Action Recommended)

| Tool | Current | Latest | Upstream | Notes |
|------|---------|--------|----------|-------|
| neovim | v0.12.4 | v0.13.0 | [releases](https://github.com/neovim/neovim/releases) | Breaking changes in 0.13.0, review migration guide |
| obsidian | 1.12.7 | 1.15.2 | [releases](https://github.com/obsidianmd/obsidian-releases/releases) | 3 patch releases behind |

## Up to Date

| Tool | Version | Last Checked |
|------|---------|--------------|
| starship | v1.26.0 | 2026-08-05 |
| nvm | v0.40.1 | 2026-08-05 |
| 0xProto Nerd Font | v3.2.1 | 2026-08-05 |

## Errors / Unable to Check

| Tool | Reason |
|------|--------|
| nvidia-container-toolkit | Rate limit on apt repo check |
```

### 5. Interactive Bump Workflow

For each outdated tool:

```markdown
## Bump: neovim v0.12.4 → v0.13.0

**Release notes:** [link]
**Changelog highlights:**
- New LSP features
- Breaking: deprecated vim.lsp.buf.formatting()

**Files to update:**
- group_vars/all.yml:47 — neovim_version: v0.13.0
- (optional) neovim-config/lazy-lock.json if plugins need updates

**Verification after bump:**
```bash
./bootstrap.sh --only neovim --check
nvim --version  # should show v0.13.0
```

**Approve this bump? [y/N]:**
```

If approved:
1. Update the version var in the file
2. Run `--check` to preview changes
3. Optionally test on a disposable VM/container
4. Commit with message: `bump: neovim v0.12.4 → v0.13.0`

### 6. Batch Operations

Allow batch approval for low-risk bumps:
```bash
# Approve all patch-level bumps (e.g., 1.12.7 → 1.12.9)
approve: patch-only

# Approve specific tools
approve: starship, nerd-font

# Approve all
approve: all
```

## Usage Examples

```bash
# Check all versions
/version-bump check

# Check specific tool
/version-bump check neovim

# Bump after approval
/version-bump apply neovim v0.13.0

# Interactive bump workflow
/version-bump interactive
```

## Implementation Notes

- **Rate limits:** GitHub API is 60 req/hour unauthenticated; cache results for 1 hour
- **Concurrency:** Check all tools in parallel (use `&` + `wait` or `xargs -P`)
- **Dry run:** Always show what would change before writing files
- **Rollback:** Keep a `.version-bump-backup/` with original values for quick revert
- **CI integration:** Could be triggered as a scheduled GitHub Action weekly

## Edge Cases

- **Locked versions:** Some tools (e.g., `neovim_config_version: main`) float by design — skip or note
- **Pre-releases:** Filter out beta/rc tags unless explicitly requested
- **Breaking changes:** Parse release notes for "BREAKING" keyword and flag prominently
- **Transitive deps:** Neovim pin may require plugin lockfile update — note in report

## Error Handling

- GitHub API rate limit → cache last check, suggest retry later
- Release URL 404 → mark as "unable to check", log for manual review
- Malformed version string → skip, log warning
- Network timeout → retry once with backoff

## Safety Guardrails

- Never auto-apply major version bumps (e.g., v1.x → v2.x) without user confirmation
- For pinned apt packages (nvidia-toolkit), verify the new version is available in the configured repo
- For GNOME extensions, ensure the new version supports the installed GNOME Shell version

## Maintenance Metadata

Store last check timestamp and results in `.version-bump-state.json`:
```json
{
  "last_check": "2026-08-05T14:30:00Z",
  "results": {
    "neovim": {
      "current": "v0.12.4",
      "latest": "v0.13.0",
      "status": "outdated"
    }
  }
}
```

This allows:
- Skip re-checking tools that were current within the last 7 days
- Show "last checked" in reports
- Track bump history
