#!/bin/sh
# install-plangate-skills.sh — plugin/plangate/skills/ を .codex/skills/ に展開
# Usage: sh install-plangate-skills.sh [--target DIR] [--force] [--json]
# Default target: $(git rev-parse --show-toplevel)/.codex/skills

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="${PLANGATE_SKILLS_DIR:-$PLUGIN_DIR/skills}"
ASSETS_SRC="$PLUGIN_DIR/assets"

# Parse args
TARGET=""
FORCE=0
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --source) SKILLS_SRC="$2"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    --json)   JSON=1; shift ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# Default target: repo root .codex/skills
if [ -z "$TARGET" ]; then
  _repo_root=""
  if command -v git >/dev/null 2>&1; then
    _repo_root="$(git -C "$PLUGIN_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [ -z "$_repo_root" ]; then
    printf '[install] ERROR: cannot resolve repo root. Use --target DIR\n' >&2
    exit 1
  fi
  TARGET="$_repo_root/.codex/skills"
fi

_log() { [ "$JSON" = "1" ] || printf '[install] %s\n' "$1"; }

# Counters
installed=0
skipped=0
errors=0
installed_names=""

for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || { _log "SKIP (no SKILL.md): $name"; skipped=$((skipped+1)); continue; }

  dst="$TARGET/$name"
  dst_md="$dst/SKILL.md"

  # Skip if already up-to-date (unless --force)
  if [ "$FORCE" = "0" ] && [ -f "$dst_md" ] && cmp -s "$skill_md" "$dst_md"; then
    _log "SKIP (up-to-date): $name"
    skipped=$((skipped+1))
    continue
  fi

  # Copy SKILL.md
  mkdir -p "$dst"
  if ! cp "$skill_md" "$dst_md"; then
    _log "ERROR copying SKILL.md for $name"
    errors=$((errors+1))
    continue
  fi

  # Extract display_name and short_description from SKILL.md frontmatter
  display_name="$name"
  short_desc=""
  in_fm=0
  while IFS= read -r line; do
    case "$line" in
      ---) if [ "$in_fm" = "0" ]; then in_fm=1; else break; fi ;;
      name:*)
        if [ "$in_fm" = "1" ]; then
          display_name="$(printf '%s' "$line" | sed 's/^name:[[:space:]]*//' | tr -d '"')"
        fi ;;
      description:*)
        if [ "$in_fm" = "1" ]; then
          short_desc="$(printf '%s' "$line" | sed 's/^description:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')"
        fi ;;
    esac
  done < "$skill_md"

  if [ -z "$short_desc" ]; then
    short_desc="Use the $name skill."
  fi

  # Copy assets
  mkdir -p "$dst/assets"
  if [ -f "$ASSETS_SRC/plangate-small.svg" ]; then
    cp "$ASSETS_SRC/plangate-small.svg" "$dst/assets/plangate-small.svg"
  fi
  # Remove stale placeholder if present
  [ -f "$dst/assets/plangate.png.placeholder" ] && rm "$dst/assets/plangate.png.placeholder"

  # Generate openai.yaml
  mkdir -p "$dst/agents"
  cat > "$dst/agents/openai.yaml" << YAML
interface:
  display_name: "$display_name"
  short_description: "$short_desc"
  icon_small: "./assets/plangate-small.svg"
  icon_large: "./assets/plangate-small.svg"
  default_prompt: "Use $name to assist with this project."
YAML

  _log "INSTALL: $name"
  installed=$((installed+1))
  installed_names="${installed_names}${name} "
done

if [ "$JSON" = "1" ]; then
  # Build JSON output
  names_json=""
  for n in $installed_names; do
    names_json="${names_json}\"$n\","
  done
  names_json="[${names_json%,}]"
  printf '{"installed":%d,"skipped":%d,"errors":%d,"names":%s}\n' \
    "$installed" "$skipped" "$errors" "$names_json"
else
  _log "Done — installed: $installed, skipped: $skipped, errors: $errors"
fi

[ "$errors" = "0" ] || exit 1
