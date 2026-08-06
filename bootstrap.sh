#!/usr/bin/env bash
# bootstrap.sh — the only shell script in this repo.
#
# Installs Ansible, pulls the required collections, then runs the single
# playbook. Everything else about this machine is described by roles, not bash.
#
#   git clone https://github.com/blakekrpec/workstation.git ~/workstation
#   ~/workstation/bootstrap.sh
#
# Flags:
#   --profile <name>   which set of roles to converge (default: full)
#   --only <role>      converge exactly one role, ignoring the profile
#                      (may be repeated: --only ghostty --only nvim)
#                      (or comma-separated: --only ghostty,neovim,gnome)
#   --list             show available profiles and exit
#   --check            dry run; show what would change
#
# Anything else is passed straight through to ansible-playbook, so
# `--tags`, `--diff`, `-e key=value` and friends all still work.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

info() { printf '\033[0;36m[bootstrap]\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

PASSTHRU=()
PROFILE=""
ONLY_TAGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)
            [ $# -ge 2 ] || die "--profile needs a name (try --list)"
            PROFILE="$2"; shift 2 ;;
        --profile=*)
            PROFILE="${1#*=}"; shift ;;
        --only)
            [ $# -ge 2 ] || die "--only needs a role name"
            # Allow comma-separated or repeated --only flags
            IFS=',' read -ra TAGS <<< "$2"
            ONLY_TAGS+=("${TAGS[@]}")
            shift 2 ;;
        --only=*)
            IFS=',' read -ra TAGS <<< "${1#*=}"
            ONLY_TAGS+=("${TAGS[@]}")
            shift ;;
        --list)
            # Profiles are defined once, in group_vars — parsed, never duplicated.
            sed -n '/^profiles:/,/^$/p' group_vars/all.yml
            exit 0 ;;
        *)
            PASSTHRU+=("$1"); shift ;;
    esac
done

# --only pins the profile to `full` so all roles are eligible in active_roles,
# then narrows execution with a tag (or comma-joined tags for multiple roles).
if [ ${#ONLY_TAGS[@]} -gt 0 ]; then
    [ -z "$PROFILE" ] || die "--only and --profile are mutually exclusive"
    TAGS_JOINED=$(IFS=,; echo "${ONLY_TAGS[*]}")
    PASSTHRU+=(-e "profile=full" --tags "$TAGS_JOINED")
elif [ -n "$PROFILE" ]; then
    PASSTHRU+=(-e "profile=$PROFILE")
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
    info "installing ansible-core"
    sudo apt-get update -qq
    sudo apt-get install -y ansible-core
else
    info "ansible-core present: $(ansible-playbook --version | head -1)"
fi

info "installing galaxy collections"
ansible-galaxy collection install -r requirements.yml >/dev/null

# Do NOT run this script under `sudo`. The playbook runs as you and escalates
# per task via become. Under sudo, HOME is /root: workstation_repo resolves under
# /root and site.yml's own assert stops the run, every dotfile symlink would land
# in /root, the docker group would get root instead of you, and the gnome role
# would talk to root's dconf rather than your session bus. It would not even save
# a prompt — you would type the password at sudo instead of here.
info "running site.yml (sudo password prompt follows)"
exec ansible-playbook site.yml --ask-become-pass "${PASSTHRU[@]}"
