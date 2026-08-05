#!/usr/bin/env bash
# bootstrap.sh — the only shell script in this repo.
#
# Installs Ansible, pulls the required collections, then runs the single
# playbook. Everything else about this machine is described by roles, not bash.
#
#   git clone https://github.com/blakekrpec/workstation.git ~/src/workstation
#   ~/src/workstation/bootstrap.sh
#
# Flags:
#   --profile <name>   which set of roles to converge (default: full)
#   --only <role>      converge exactly one role, ignoring the profile
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
ONLY=""

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)
            [ $# -ge 2 ] || die "--profile needs a name (try --list)"
            PROFILE="$2"; shift 2 ;;
        --profile=*)
            PROFILE="${1#*=}"; shift ;;
        --only)
            [ $# -ge 2 ] || die "--only needs a role name"
            ONLY="$2"; shift 2 ;;
        --only=*)
            ONLY="${1#*=}"; shift ;;
        --list)
            # Profiles are defined once, in group_vars — parsed, never duplicated.
            sed -n '/^profiles:/,/^$/p' group_vars/all.yml
            exit 0 ;;
        *)
            PASSTHRU+=("$1"); shift ;;
    esac
done

# --only pins the profile to `full` so the role is guaranteed to be in
# active_roles, then narrows execution with a tag.
if [ -n "$ONLY" ]; then
    [ -z "$PROFILE" ] || die "--only and --profile are mutually exclusive"
    PASSTHRU+=(-e "profile=full" --tags "$ONLY")
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

info "running site.yml (sudo password prompt follows)"
exec ansible-playbook site.yml --ask-become-pass "${PASSTHRU[@]}"
