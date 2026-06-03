#!/bin/sh
# install-plangate-skills-to-codex.sh — PlanGate スキルを .codex/skills/ に同期
#
# Usage:
#   sh scripts/install-plangate-skills-to-codex.sh [OPTIONS]
#
# Options:
#   --force        既存スキルも強制上書き（デフォルト: 差分時のみ更新）
#   --json         インストール結果を JSON で stdout に出力
#   --source DIR   ソースディレクトリを上書き（デフォルト: .agents/skills/）
#
# Environment:
#   PLANGATE_SKILLS_DIR  ソースディレクトリを上書き（--source より優先度低）

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CODEX_SKILLS_DIR="$ROOT_DIR/.codex/skills"
SYSTEM_SKILLS_DIR="$CODEX_SKILLS_DIR/.system"
ASSETS_SRC="$ROOT_DIR/plugin/plangate/assets"

# --- オプション解析 ---
FORCE=0
JSON_OUTPUT=0
SOURCE_DIR="${PLANGATE_SKILLS_DIR:-$ROOT_DIR/.agents/skills}"

while [ $# -gt 0 ]; do
  case "$1" in
    --force)  FORCE=1; shift ;;
    --json)   JSON_OUTPUT=1; shift ;;
    --source) SOURCE_DIR="$2"; shift 2 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

installed_count=0
skipped_count=0
installed_names=""
skipped_names=""

yaml_quote() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# フロントマター値を抽出。見つからない場合は空文字を返す（set -e で止まらない）
extract_frontmatter_value() {
  key="$1"
  file="$2"
  awk -v target="$key" '
    NR == 1 { if ($0 != "---") { exit 0 } next }
    $0 == "---" { exit 0 }
    index($0, target ":") == 1 {
      value = substr($0, length(target) + 2)
      # CRLF 除去
      gsub(/\r/, "", value)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      # ダブルクォート除去
      if (value ~ /^".*"$/) {
        value = substr(value, 2, length(value) - 2)
      }
      # シングルクォート除去
      else if (value ~ /^'"'"'.*'"'"'$/) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit 0
    }
  ' "$file"
}

# ファイルハッシュ（md5 or sha256）
file_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    md5 -q "$1" 2>/dev/null || md5sum "$1" | awk '{print $1}'
  fi
}

# スキルが更新が必要かを判定（FORCE=1 なら常に true）
needs_update() {
  src="$1"
  dst="$2"
  [ "$FORCE" -eq 1 ] && return 0
  [ ! -f "$dst" ] && return 0
  src_hash=$(file_hash "$src")
  dst_hash=$(file_hash "$dst")
  [ "$src_hash" != "$dst_hash" ]
}

mkdir -p "$CODEX_SKILLS_DIR"

for skill_file in "$SOURCE_DIR"/*/SKILL.md; do
  [ -f "$skill_file" ] || continue

  skill_dir=$(dirname -- "$skill_file")
  skill_name=$(basename -- "$skill_dir")

  # システムスキルはスキップ
  if [ -d "$SYSTEM_SKILLS_DIR/$skill_name" ]; then
    skipped_count=$((skipped_count + 1))
    skipped_names="${skipped_names}${skill_name}(system)
"
    printf 'skip(system): %s\n' "$skill_name"
    continue
  fi

  target_dir="$CODEX_SKILLS_DIR/$skill_name"
  target_skill_file="$target_dir/SKILL.md"
  target_agents_dir="$target_dir/agents"
  target_openai_yaml="$target_agents_dir/openai.yaml"

  # 差分チェック（--force なし時）
  if [ "$FORCE" -eq 0 ] && [ -f "$target_skill_file" ] && [ -f "$target_openai_yaml" ]; then
    if ! needs_update "$skill_file" "$target_skill_file"; then
      skipped_count=$((skipped_count + 1))
      skipped_names="${skipped_names}${skill_name}(no-change)
"
      printf 'skip(no-change): %s\n' "$skill_name"
      continue
    fi
  fi

  # フロントマター値を取得（見つからない場合はフォールバック値を使用）
  frontmatter_name=$(extract_frontmatter_value name "$skill_file")
  frontmatter_description=$(extract_frontmatter_value description "$skill_file")
  frontmatter_icon_small=$(extract_frontmatter_value icon_small "$skill_file")
  frontmatter_icon_large=$(extract_frontmatter_value icon_large "$skill_file")
  frontmatter_default_prompt=$(extract_frontmatter_value default_prompt "$skill_file")

  # フォールバック値
  [ -z "$frontmatter_name" ] && frontmatter_name="$skill_name"
  [ -z "$frontmatter_description" ] && frontmatter_description="PlanGate skill: $skill_name"
  # short_description を 64 文字以内に安全に切り詰め（UTF-8 マルチバイト対応）
  if command -v python3 >/dev/null 2>&1; then
    frontmatter_description=$(python3 - "$frontmatter_description" << 'PYTRUNC'
import sys
s = sys.argv[1]
print(s[:61] + '...' if len(s) > 64 else s)
PYTRUNC
)
  fi
  [ -z "$frontmatter_icon_small" ] && frontmatter_icon_small="./assets/plangate-small.svg"
  [ -z "$frontmatter_icon_large" ] && frontmatter_icon_large="./assets/plangate.png"
  if [ -z "$frontmatter_default_prompt" ]; then
    frontmatter_default_prompt="Use \$$skill_name to assist with this project."
  fi

  # symlink はセキュリティのためスキップ
  if [ -L "$skill_file" ]; then
    skipped_count=$((skipped_count + 1))
    printf 'skip(symlink): %s\n' "$skill_name"
    continue
  fi

  mkdir -p "$target_agents_dir"

  # SKILL.md をコピー
  cp "$skill_file" "$target_skill_file"

  # assets をコピー（存在する場合）
  if [ -d "$ASSETS_SRC" ]; then
    target_assets_dir="$target_dir/assets"
    mkdir -p "$target_assets_dir"
    for _a in "$ASSETS_SRC"/*; do
      case "$_a" in *.placeholder) continue ;; esac
      [ -f "$_a" ] && [ ! -L "$_a" ] && cp "$_a" "$target_assets_dir/" 2>/dev/null || true
    done
  fi

  # openai.yaml を生成
  display_name=$(yaml_quote "$frontmatter_name")
  short_description=$(yaml_quote "$frontmatter_description")
  icon_small=$(yaml_quote "$frontmatter_icon_small")
  icon_large=$(yaml_quote "$frontmatter_icon_large")
  default_prompt=$(yaml_quote "$frontmatter_default_prompt")

  {
    printf 'interface:\n'
    printf '  display_name: "%s"\n' "$display_name"
    printf '  short_description: "%s"\n' "$short_description"
    printf '  icon_small: "%s"\n' "$icon_small"
    printf '  icon_large: "%s"\n' "$icon_large"
    printf '  default_prompt: "%s"\n' "$default_prompt"
    printf '  brand_color: "#1A56DB"\n'
  } > "$target_openai_yaml"

  installed_count=$((installed_count + 1))
  installed_names="${installed_names}${skill_name}
"
  printf 'installed: %s\n' "$skill_name"
done

total=$((installed_count + skipped_count))

if [ "$JSON_OUTPUT" -eq 1 ]; then
  # JSON 出力（CI 向け）
  names_json=""
  for n in $installed_names; do
    names_json="${names_json}\"${n}\","
  done
  names_json="[${names_json%,}]"

  printf '{"installed_count":%d,"skipped_count":%d,"total_processed":%d,"installed_names":%s}\n' \
    "$installed_count" "$skipped_count" "$total" "$names_json"
else
  printf '\n--- Summary ---\n'
  printf 'installed_count=%s\n' "$installed_count"
  printf 'skipped_count=%s\n' "$skipped_count"
  printf 'total_processed=%s\n' "$total"
  printf 'installed_names:\n%s' "$installed_names"
fi
