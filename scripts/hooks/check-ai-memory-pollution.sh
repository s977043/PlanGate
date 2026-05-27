#!/bin/sh
# check-ai-memory-pollution.sh — git pre-commit hook for claude-mem 自動挿入検知
#
# TASK-0113 (#355) / INC P-1 系列
#
# 検知対象:
#   - AGENTS.md / CLAUDE.md 等 SSoT に AI memory ツール (claude-mem 等) が
#     自動挿入する <claude-mem-context> 等のブロック
#
# 設計原則 (TASK-0113 C-2 R-001..R-010 反映):
#   - R-002: --auto-revert は unstaged diff 検出時 block
#   - R-003: YAML は python3 sub-process で読む、不在時は埋め込み JSON で fallback
#   - R-004: allowlist marker は pattern id 単位 + ファイル単位
#   - R-005: 巨大 file / binary / rename / deleted は skip
#   - R-009: git pre-commit 専用 (PreToolUse 経路 scope 外)
#   - R-010: schema 命名 plangate-pollution-patterns.schema.json
#
# 使用例:
#   .git/hooks/pre-commit 経由で自動起動 (install: sh scripts/install-pre-commit.sh)
#   PLANGATE_POLLUTION_AUTO_REVERT=1 sh scripts/hooks/check-ai-memory-pollution.sh

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
CONFIG_FILE="$REPO_ROOT/.plangate-pollution-patterns.yaml"

# 既定 (config 不在時 fallback、R-003)
DEFAULT_PATTERN='<claude-mem-context>'
DEFAULT_PATTERN_ID='claude-mem-context'
DEFAULT_TARGET_FILES='AGENTS.md'

# Mode
AUTO_REVERT="${PLANGATE_POLLUTION_AUTO_REVERT:-0}"

# === 設定 load (R-003: python3 で YAML 読み、不在時は埋め込み既定) ===
if [ -f "$CONFIG_FILE" ] && command -v python3 >/dev/null 2>&1; then
  # YAML を python3 で parse
  config_json=$(python3 - "$CONFIG_FILE" <<'PY' 2>/dev/null || echo "{}"
import sys
try:
    import yaml
    with open(sys.argv[1]) as f:
        d = yaml.safe_load(f) or {}
    import json
    print(json.dumps(d))
except ImportError:
    # PyYAML 不在時は JSON-like YAML 簡易 fallback (config が JSON 互換なら通る)
    with open(sys.argv[1]) as f:
        content = f.read()
    print(content)
except Exception:
    print("{}")
PY
)
  PATTERNS=$(echo "$config_json" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    patterns = d.get('patterns', [])
    for p in patterns:
        pid = p.get('id', '')
        regex = p.get('regex', '')
        if pid and regex:
            print(f'{pid}::{regex}')
except Exception:
    pass
" 2>/dev/null || echo "")
  TARGET_FILES=$(echo "$config_json" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    for f in d.get('target_files', []):
        print(f)
except Exception:
    pass
" 2>/dev/null || echo "")
else
  PATTERNS="${DEFAULT_PATTERN_ID}::${DEFAULT_PATTERN}"
  TARGET_FILES="$DEFAULT_TARGET_FILES"
fi

# Fallback if empty
[ -z "$PATTERNS" ] && PATTERNS="${DEFAULT_PATTERN_ID}::${DEFAULT_PATTERN}"
[ -z "$TARGET_FILES" ] && TARGET_FILES="$DEFAULT_TARGET_FILES"

# === staged diff 取得 ===
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  exit 0  # 空 diff → 何もしない
fi

VIOLATIONS=""

for file in $STAGED_FILES; do
  # R-005: rename / deleted は skip (diff-filter=ACMR で R 含むが target 名で評価)
  # R-005: 対象 file かどうか check
  is_target=0
  for tf in $TARGET_FILES; do
    case "$file" in
      $tf) is_target=1; break ;;
    esac
  done
  [ "$is_target" = "0" ] && continue

  # R-005: 巨大 file (>1MB) skip
  if [ -f "$REPO_ROOT/$file" ]; then
    size=$(wc -c < "$REPO_ROOT/$file" 2>/dev/null || echo 0)
    if [ "$size" -gt 1048576 ]; then
      printf '[ai-mem-guard] skip large file (>1MB): %s\n' "$file" >&2
      continue
    fi
    # R-005: binary detection (NUL byte in first 512 bytes)
    if head -c 512 "$REPO_ROOT/$file" 2>/dev/null | LC_ALL=C grep -q $'\0' 2>/dev/null; then
      printf '[ai-mem-guard] skip binary: %s\n' "$file" >&2
      continue
    fi
  fi

  # staged content + 各 pattern を check
  staged_content=$(git show ":$file" 2>/dev/null || true)
  for pattern_entry in $PATTERNS; do
    pattern_id="${pattern_entry%%::*}"
    pattern="${pattern_entry#*::}"

    # R-004: allowlist marker check (pattern id 単位 + ファイル単位)
    allowlist_marker="<!-- plangate-pollution-allowlist:${pattern_id} -->"
    if printf '%s' "$staged_content" | grep -qF "$allowlist_marker"; then
      printf '[ai-mem-guard] allowlist marker found, skipping pattern "%s" in %s\n' "$pattern_id" "$file" >&2
      continue
    fi

    # pattern match check
    if printf '%s' "$staged_content" | grep -qE "$pattern" 2>/dev/null || \
       printf '%s' "$staged_content" | grep -qF "$pattern" 2>/dev/null; then
      VIOLATIONS="$VIOLATIONS$file::$pattern_id|"
    fi
  done
done

if [ -z "$VIOLATIONS" ]; then
  exit 0
fi

# === Violations 検出 ===
printf '\n[ai-mem-guard] ⚠️ AI memory pollution 検出:\n' >&2
echo "$VIOLATIONS" | tr '|' '\n' | while IFS='::' read -r vfile vid; do
  [ -z "$vfile" ] && continue
  printf '  %s: pattern_id=%s\n' "$vfile" "$vid" >&2
done

# === Auto-revert mode (R-002: unstaged diff 検出時は block) ===
if [ "$AUTO_REVERT" = "1" ]; then
  # Check unstaged changes on target files
  UNSTAGED_FILES=$(git diff --name-only -- $TARGET_FILES 2>/dev/null || true)
  if [ -n "$UNSTAGED_FILES" ]; then
    printf '\n[ai-mem-guard] R-002: 対象 file に unstaged 変更あり → auto-revert せず block\n' >&2
    printf '  unstaged files: %s\n' "$UNSTAGED_FILES" >&2
    printf '  対処: unstaged 変更を確認 → 必要なら commit or stash → 再実行\n' >&2
    exit 1
  fi
  # Safe to auto-revert
  echo "$VIOLATIONS" | tr '|' '\n' | while IFS='::' read -r vfile _vid; do
    [ -z "$vfile" ] && continue
    git checkout HEAD -- "$vfile" 2>/dev/null && \
      printf '[ai-mem-guard] auto-reverted: %s\n' "$vfile" >&2
  done
  printf '\n[ai-mem-guard] auto-revert 完了。再 stage + commit してください。\n' >&2
  exit 1
fi

# === Default: warning + block ===
printf '\n[ai-mem-guard] 対処:\n' >&2
printf '  1. 検出された pattern を削除:\n' >&2
echo "$VIOLATIONS" | tr '|' '\n' | while IFS='::' read -r vfile _vid; do
  [ -z "$vfile" ] && continue
  printf '     git checkout -- %s  # 該当 file 全体を HEAD に戻す\n' "$vfile" >&2
done
printf '\n  2. allowlist marker で個別許可 (false positive 時):\n' >&2
printf '     <!-- plangate-pollution-allowlist:<pattern-id> --> を該当 file 末尾に追加\n' >&2
printf '\n  3. auto-revert mode (環境変数):\n' >&2
printf '     PLANGATE_POLLUTION_AUTO_REVERT=1 git commit\n' >&2
printf '\n  詳細: docs/ai/ai-memory-pollution-guard.md\n' >&2

exit 1
