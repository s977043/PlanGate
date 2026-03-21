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
export CODEX_HOME="$repo_root/.codex"
exec codex "$@"
