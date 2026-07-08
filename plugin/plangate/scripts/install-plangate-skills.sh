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
    --help|-h)
      printf 'Usage: %s [--target DIR] [--force] [--json]\n' "$0"
      printf 'Install PlanGate skills into Codex skill directory.\n'
      printf '  --target DIR  Target directory (default: .codex/skills)\n'
      printf '  --force       Overwrite existing skills\n'
      printf '  --json        Output results as JSON\n'
      exit 0 ;;
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

# 一時作業ディレクトリ（bundled resources の差分判定・同期に使用。終了時に必ず掃除）
_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$_TMPDIR"' EXIT INT TERM

# Counters
installed=0
skipped=0
errors=0
installed_names=""

# bundled resources（skill 直下の SKILL.md 以外のサブディレクトリ）判定で
# 特別扱いする名前。"agents" は openai.yaml 生成が dst 側で毎回再構築される
# ため対象外、"assets" は ASSETS_SRC からの共有アイコンコピーで別管理。
_is_managed_subdir() {
  case "$1" in
    agents|assets) return 0 ;;
    *) return 1 ;;
  esac
}

# $1=src_dir と $2=dst_dir の中身が完全一致するか（ファイル数 + 各ファイル cmp）。
# symlink は比較対象から除外（コピー時にスキップされるため一致しなくてよい）。
_dirs_equal() {
  _de_src="$1"
  _de_dst="$2"
  [ -d "$_de_src" ] || return 1
  [ -d "$_de_dst" ] || return 1
  # __pycache__ / *.pyc は比較対象外（展開先でのスクリプト実行が生成する
  # ランタイム産物であり、up-to-date 判定を汚して毎回再展開になるのを防ぐ）
  _de_list_src="$(cd "$_de_src" && find . -type f ! -type l ! -path '*/__pycache__/*' ! -name '*.pyc' | sort)"
  _de_list_dst="$(cd "$_de_dst" && find . -type f ! -type l ! -path '*/__pycache__/*' ! -name '*.pyc' | sort)"
  [ "$_de_list_src" = "$_de_list_dst" ] || return 1
  _de_old_ifs="$IFS"
  IFS='
'
  for _de_rel in $_de_list_src; do
    if ! cmp -s "$_de_src/$_de_rel" "$_de_dst/$_de_rel"; then
      IFS="$_de_old_ifs"
      return 1
    fi
  done
  IFS="$_de_old_ifs"
  return 0
}

# skill の bundled resources サブディレクトリ（references/ scripts/ 等）を
# dst へ再帰同期する。symlink はディレクトリ・ファイルとも安全のためスキップ。
# エラーは呼び出し元スコープの errors カウンタに直接加算する（サブシェル経由
# の pipe|while はカウンタが親シェルへ伝播しないため使用しない）。
_sync_resource_dir() {
  _srd_src="$1"
  _srd_dst="$2"
  if [ -L "$_srd_src" ]; then
    _log "SKIP symlink dir: $_srd_src"
    return 0
  fi
  rm -rf "$_srd_dst"
  mkdir -p "$_srd_dst"

  _srd_dirs_list="$_TMPDIR/resource-dirs.lst"
  _srd_files_list="$_TMPDIR/resource-files.lst"
  (cd "$_srd_src" && find . -type d) > "$_srd_dirs_list"
  (cd "$_srd_src" && find . -type f) > "$_srd_files_list"

  while IFS= read -r _srd_rd; do
    [ "$_srd_rd" = "." ] && continue
    if [ -L "$_srd_src/$_srd_rd" ]; then
      _log "SKIP symlink dir: $_srd_src/$_srd_rd"
      continue
    fi
    mkdir -p "$_srd_dst/$_srd_rd"
  done < "$_srd_dirs_list"

  while IFS= read -r _srd_rf; do
    if [ -L "$_srd_src/$_srd_rf" ]; then
      _log "SKIP symlink: $_srd_src/$_srd_rf"
      continue
    fi
    if ! cp "$_srd_src/$_srd_rf" "$_srd_dst/$_srd_rf"; then
      _log "ERROR copying $_srd_src/$_srd_rf"
      errors=$((errors+1))
    fi
  done < "$_srd_files_list"

  rm -f "$_srd_dirs_list" "$_srd_files_list"
}

for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || { _log "SKIP (no SKILL.md): $name"; skipped=$((skipped+1)); continue; }

  dst="$TARGET/$name"
  dst_md="$dst/SKILL.md"

  # このスキルの bundled resources サブディレクトリ一覧（agents/assets を除く）
  resource_subdirs=""
  for _sub in "$skill_dir"*/; do
    [ -d "$_sub" ] || continue
    _sub_name="$(basename "$_sub")"
    _is_managed_subdir "$_sub_name" && continue
    resource_subdirs="$resource_subdirs $_sub_name"
  done

  # up-to-date 判定（--force なし時）: SKILL.md + 全 bundled resources サブ
  # ディレクトリが一致していれば skip
  up_to_date=0
  if [ "$FORCE" = "0" ] && [ -f "$dst_md" ] && cmp -s "$skill_md" "$dst_md"; then
    up_to_date=1
    for _sub_name in $resource_subdirs; do
      if ! _dirs_equal "$skill_dir$_sub_name" "$dst/$_sub_name"; then
        up_to_date=0
        break
      fi
    done
  fi

  if [ "$up_to_date" = "1" ]; then
    _log "SKIP (up-to-date): $name"
    skipped=$((skipped+1))
    continue
  fi

  # Copy SKILL.md（symlink はセキュリティのためスキップ）
  if [ -L "$skill_md" ]; then
    _log "SKIP symlink: $name"
    skipped=$((skipped+1))
    continue
  fi
  mkdir -p "$dst"
  if ! cp "$skill_md" "$dst_md"; then
    _log "ERROR copying SKILL.md for $name"
    errors=$((errors+1))
    continue
  fi

  # bundled resources サブディレクトリ（references/ scripts/ 等）を再帰同期
  for _sub_name in $resource_subdirs; do
    _sync_resource_dir "$skill_dir$_sub_name" "$dst/$_sub_name"
  done

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

  # short_description を 64 文字以内に安全に切り詰め（UTF-8 マルチバイト対応・UI 表示用）
  if command -v python3 >/dev/null 2>&1; then
    short_desc=$(python3 - "$short_desc" << 'PYTRUNC'
import sys
s = sys.argv[1]
print(s[:61] + '...' if len(s) > 64 else s)
PYTRUNC
)
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
  default_prompt: "Use \$$name to assist with this project."
  brand_color: "#1A56DB"
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
