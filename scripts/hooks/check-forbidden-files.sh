#!/bin/sh
# check-forbidden-files.sh — Hook EH-6: scope 外ファイル編集検知
#
# Claude Code PreToolUse hook（Edit / Write の前に呼ばれる想定）または CLI。
#
# 入力:
#   PLANGATE_HOOK_TASK   対象 TASK ID（例: TASK-0057）
#   PLANGATE_HOOK_FILE   編集対象ファイルの相対 path（リポジトリルート起点）
#
# 検査:
#   1. 親 PBI を docs/working/PBI-*/children/ から逆引き
#      （子 PBI YAML で id == PLANGATE_HOOK_TASK のものを探す）
#   2. 該当 child YAML の forbidden_files / allowed_files を抽出
#   3. PLANGATE_HOOK_FILE が forbidden_files glob にマッチしたら違反
#   4. allowed_files が定義されていてマッチしない場合も WARN（informational）
#
# Modes:
#   default                       warning（continue:true）
#   PLANGATE_HOOK_STRICT=1        違反時 continue:false（block）
#   PLANGATE_BYPASS_HOOK=1        常時 continue:true
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0057

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

emit_judgment() {
  decision=$1
  reason=${2:-}
  if [ "$decision" = "block" ]; then
    printf '{"continue":false,"stopReason":"%s"}\n' "$reason"
  else
    printf '{"continue":true}\n'
  fi
}

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-forbidden-files\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

# bypass
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  emit_judgment "allow"
  exit 0
fi

task_id=${PLANGATE_HOOK_TASK:-${1:-}}
target_file=${PLANGATE_HOOK_FILE:-${2:-}}

# task_id 未明示時は SKIP（false-positive guard）
if [ -z "$task_id" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_TASK / arg 1, skipping"
  emit_judgment "allow"
  exit 0
fi

# target file 未明示時は SKIP（PreToolUse hook の event JSON は別途 stdin で受領
# する仕様だが、本実装は環境変数経由で明示的に指定する設計）
if [ -z "$target_file" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_FILE / arg 2, skipping"
  emit_judgment "allow"
  exit 0
fi

case "$task_id" in
  TASK-*) ;;
  *)
    log_event "SKIP" "invalid task_id: $task_id"
    emit_judgment "allow"
    exit 0
    ;;
esac

# 親 PBI の child YAML を探す（PBI-*/children/ 配下を grep）
yaml_path=$(grep -rl "^[[:space:]]*id:[[:space:]]*$task_id\$" "$WORKING_DIR"/PBI-*/children/ 2>/dev/null | head -1 || true)

if [ -z "$yaml_path" ]; then
  log_event "SKIP" "no child PBI YAML for $task_id (standalone PBI)"
  emit_judgment "allow"
  exit 0
fi

# python3 で YAML を parse して forbidden_files / allowed_files を抽出 + glob 突合
result=$(PLANGATE_TARGET_FILE="$target_file" PLANGATE_YAML_PATH="$yaml_path" python3 - <<'PYEOF'
import os
import re
import fnmatch
import sys

yaml_path = os.environ["PLANGATE_YAML_PATH"]
target = os.environ["PLANGATE_TARGET_FILE"]


def extract_list(content: str, key: str) -> list[str]:
    """very small YAML extractor for `key:` followed by `- item` lines"""
    lines = content.splitlines()
    result: list[str] = []
    in_block = False
    base_indent = -1
    for raw in lines:
        m = re.match(r"^(\s*)" + re.escape(key) + r":\s*$", raw)
        if m:
            in_block = True
            base_indent = len(m.group(1))
            continue
        if in_block:
            stripped = raw.rstrip()
            if not stripped:
                continue
            indent = len(stripped) - len(stripped.lstrip())
            if indent <= base_indent:
                in_block = False
                continue
            mm = re.match(r"\s*-\s+(.+?)(\s+#.*)?$", raw)
            if mm:
                result.append(mm.group(1).strip())
    return result


with open(yaml_path) as f:
    content = f.read()

forbidden = extract_list(content, "forbidden_files")
allowed = extract_list(content, "allowed_files")


def matches_any(path: str, patterns: list[str]) -> str | None:
    for p in patterns:
        # `**/x` パターンを fnmatch 用に簡易変換: ** は * 一個より広い意味だが
        # fnmatch では `*` だけで複数階層をまたがない。代替として `*` に変換。
        normalized = p.replace("**/", "*/")
        if fnmatch.fnmatchcase(path, normalized) or fnmatch.fnmatchcase(path, p):
            return p
        # path 先頭一致（dir prefix）も拾う
        if normalized.endswith("/*") or normalized.endswith("/**"):
            prefix = normalized.rstrip("/*").rstrip("/")
            if path.startswith(prefix + "/"):
                return p
    return None


hit_forbidden = matches_any(target, forbidden) if forbidden else None
hit_allowed = matches_any(target, allowed) if allowed else None

if hit_forbidden:
    print(f"FORBIDDEN\t{hit_forbidden}")
elif allowed and not hit_allowed:
    print(f"OUTSIDE_ALLOWED\t{','.join(allowed[:3])}")
else:
    print("OK")
PYEOF
)

verdict=$(printf '%s' "$result" | awk -F'\t' '{print $1}')
detail=$(printf '%s' "$result" | awk -F'\t' '{print $2}')

case "$verdict" in
  OK)
    log_event "PASS" "$target_file ↔ $yaml_path"
    emit_judgment "allow"
    exit 0
    ;;
  FORBIDDEN)
    reason="$target_file matches forbidden_files pattern '$detail' for $task_id"
    log_event "VIOLATION" "$reason"
    if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
      emit_judgment "block" "$reason"
      exit 0
    fi
    printf '[Hook EH-6 WARNING] %s\n' "$reason" >&2
    emit_judgment "allow"
    exit 0
    ;;
  OUTSIDE_ALLOWED)
    # informational warning only (default to allow)
    reason="$target_file is outside allowed_files (e.g. $detail) for $task_id"
    log_event "WARN" "$reason"
    printf '[Hook EH-6 INFO] %s\n' "$reason" >&2
    emit_judgment "allow"
    exit 0
    ;;
  *)
    log_event "ERROR" "unexpected verdict: $verdict"
    emit_judgment "allow"
    exit 0
    ;;
esac
