#!/bin/sh

set -eu

script_dir=$(
  CDPATH= cd -- "$(dirname -- "$0")" && pwd
)
repo_root=$(
  CDPATH= cd -- "$script_dir/.." && pwd
)

if [ ! -d "$repo_root/.codex" ]; then
  echo "Run this from the repository root where .codex/ exists." >&2
  exit 1
fi

if [ "${1:-}" = "--" ]; then
  shift
fi

cd "$repo_root"

# Keep project-local config/runtime under .codex while reusing the existing
# user-level auth file when no project-local auth has been provisioned.
auth_dst="$repo_root/.codex/auth.json"
auth_src="${CODEX_AUTH_SOURCE:-$HOME/.codex/auth.json}"

if [ ! -e "$auth_dst" ] && [ -f "$auth_src" ]; then
  ln -s "$auth_src" "$auth_dst"
fi

export CODEX_HOME="$repo_root/.codex"
exec codex "$@"
