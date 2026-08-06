#!/usr/bin/env bash
# version-bump.sh — Check for version updates in workstation repo
# Usage: ./scripts/version-bump.sh [check|report|interactive]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$REPO_ROOT/.version-bump-state.json"
CACHE_TTL=3600  # 1 hour cache

# GitHub API helper (respects rate limits)
gh_latest_release() {
    local repo="$1"
    local url="https://api.github.com/repos/$repo/releases/latest"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" 2>/dev/null | jq -r '.tag_name // empty'
    else
        echo "ERROR: curl not found" >&2
        return 1
    fi
}

# EGO API helper for GNOME extensions
ego_latest_version() {
    local uuid="$1"
    local shell_version="$2"
    local url="https://extensions.gnome.org/extension-info/?uuid=$uuid"
    
    curl -fsSL "$url" 2>/dev/null | jq -r ".shell_version_map.\"$shell_version\".version // empty"
}

# Apt repo helper for deb packages
apt_latest_version() {
    local package="$1"
    
    if command -v apt-cache >/dev/null 2>&1; then
        apt-cache madison "$package" 2>/dev/null | head -1 | awk '{print $3}'
    else
        echo ""
    fi
}

# Extract current version from file
get_current_version() {
    local file="$1"
    local var="$2"
    
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
        echo "FILE_NOT_FOUND"
        return 1
    fi
    
    grep -m1 "^$var:" "$REPO_ROOT/$file" | awk '{print $2}' | tr -d '"'
}

# Compare semantic versions (naive: just string compare for now)
is_outdated() {
    local current="$1"
    local latest="$2"
    
    [[ "$current" != "$latest" ]] && [[ -n "$latest" ]]
}

# Main check function
check_versions() {
    echo "# Version Bump Report — $(date +%Y-%m-%d)"
    echo
    echo "Checking pinned versions across the repo..."
    echo
    
    local outdated_count=0
    local uptodate_count=0
    
    # Define tools to check (name, file, var, repo, check_method)
    declare -a TOOLS=(
        "neovim|group_vars/all.yml|neovim_version|neovim/neovim|github"
        "starship|roles/starship/defaults/main.yml|starship_version|starship/starship|github"
        "obsidian|roles/obsidian/defaults/main.yml|obsidian_version|obsidianmd/obsidian-releases|github"
        "nvm|group_vars/all.yml|nvm_version|nvm-sh/nvm|github"
        "nerd-fonts|group_vars/all.yml|nerd_font_version|ryanoasis/nerd-fonts|github"
        "docker-ce|roles/docker/defaults/main.yml|docker_version||apt"
        "containerd|roles/docker/defaults/main.yml|containerd_version||apt"
        "nvidia-toolkit|roles/docker/defaults/main.yml|nvidia_toolkit_version||apt"
    )
    
    echo "## Checking Updates"
    echo
    
    declare -a OUTDATED=()
    declare -a UPTODATE=()
    
    for tool_spec in "${TOOLS[@]}"; do
        IFS='|' read -r name file var repo method <<< "$tool_spec"
        
        current=$(get_current_version "$file" "$var")
        if [[ "$current" == "FILE_NOT_FOUND" ]]; then
            echo "⚠️  $name: file not found ($file)"
            continue
        fi
        
        if [[ "$method" == "github" ]]; then
            latest=$(gh_latest_release "$repo" 2>/dev/null || echo "")
        elif [[ "$method" == "apt" ]]; then
            # Extract package name from tool name
            local pkg_name="$name"
            [[ "$name" == "nvidia-toolkit" ]] && pkg_name="nvidia-container-toolkit"
            latest=$(apt_latest_version "$pkg_name" 2>/dev/null || echo "")
        else
            latest=""
        fi
        
        if [[ -z "$latest" ]]; then
            echo "❓ $name: unable to check (API error or rate limit)"
            continue
        fi
        
        if is_outdated "$current" "$latest"; then
            echo "🔄 $name: $current → $latest (update available)"
            OUTDATED+=("$name|$current|$latest|$file|$var")
            ((outdated_count++))
        else
            echo "✅ $name: $current (up to date)"
            UPTODATE+=("$name|$current")
            ((uptodate_count++))
        fi
    done
    
    echo
    echo "## Summary"
    echo "- Outdated: $outdated_count"
    echo "- Up to date: $uptodate_count"
    echo
    
    if [[ ${#OUTDATED[@]} -gt 0 ]]; then
        echo "## Outdated Tools"
        echo
        for entry in "${OUTDATED[@]}"; do
            IFS='|' read -r name current latest file var <<< "$entry"
            echo "### $name: $current → $latest"
            echo
            echo "**File:** $file"
            echo "**Variable:** $var"
            echo
            echo "To bump:"
            echo '```bash'
            echo "# Edit $file and change $var to $latest"
            echo "# Then verify:"
            echo "./bootstrap.sh --only ${name//[- ]/_} --check"
            echo '```'
            echo
        done
    fi
}

# Interactive bump workflow
interactive_bump() {
    echo "# Interactive Version Bump Workflow"
    echo
    
    # Re-run check to get latest state
    check_versions > /tmp/version-check.txt
    
    # Parse outdated tools
    local outdated_tools=$(grep "^🔄" /tmp/version-check.txt | wc -l)
    
    if [[ $outdated_tools -eq 0 ]]; then
        echo "✅ All tools are up to date!"
        return 0
    fi
    
    echo "Found $outdated_tools outdated tool(s)."
    echo
    echo "Would you like to review and approve bumps? [y/N]"
    # Placeholder — actual interactive logic would go here
    # For now, just show what would be done
    
    echo
    echo "Interactive mode placeholder — use 'check' command and manually apply bumps for now."
}

# Main CLI
case "${1:-check}" in
    check)
        check_versions
        ;;
    report)
        check_versions
        ;;
    interactive)
        interactive_bump
        ;;
    *)
        echo "Usage: $0 [check|report|interactive]"
        exit 1
        ;;
esac
