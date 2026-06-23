#!/bin/sh
# scripts/apply-task-0141-eh2-strict.sh
# TASK-0141 AC-1/AC-2 HO パッチ適用スクリプト
#   AC-1: EH-2 (check-c3-approval.sh) の c3_status を python3 strict JSON 解析に変更
#   AC-2: EH-1/EH-2 に stdin tool_input.file_path fallback を追加
#
# Human が実行する（HO パス scripts/hooks/ を変更するため）
#
# 使い方:
#   sh scripts/apply-task-0141-eh2-strict.sh --dry-run  # 差分確認のみ
#   sh scripts/apply-task-0141-eh2-strict.sh            # 実際に適用

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

printf '=== apply-task-0141-eh2-strict.sh (dry_run=%s) ===\n' "$DRY_RUN"

python3 - "$REPO_ROOT" "$DRY_RUN" << 'PYEOF'
import sys, os, difflib

repo_root = sys.argv[1]
dry_run = sys.argv[2] == "1"

def patch_file(rel_path, old, new):
    path = os.path.join(repo_root, rel_path)
    with open(path) as f:
        content = f.read()
    if old not in content:
        print(f"ERROR: target string not found in {rel_path}", file=sys.stderr)
        sys.exit(1)
    new_content = content.replace(old, new, 1)
    if dry_run:
        old_lines = content.splitlines(keepends=True)
        new_lines = new_content.splitlines(keepends=True)
        diff = difflib.unified_diff(old_lines, new_lines,
                                    fromfile=rel_path, tofile=rel_path + " (patched)")
        sys.stdout.writelines(diff)
    else:
        bak = path + ".bak"
        with open(bak, "w") as f:
            f.write(content)
        with open(path, "w") as f:
            f.write(new_content)
        print(f"patched: {rel_path}  (backup: {os.path.basename(bak)})")

# ---- stdin fallback snippet (shared) ----
STDIN_FALLBACK_EH2 = """\
# stdin fallback: env/arg なし時に tool_input.file_path から TASK-ID を抽出
if [ -z "$task_id" ] && [ ! -t 0 ]; then
  _eh2_stdin=$(cat 2>/dev/null || true)
  if [ -n "$_eh2_stdin" ]; then
    _eh2_fp=""
    if command -v jq >/dev/null 2>&1; then
      _eh2_fp=$(printf '%s' "$_eh2_stdin" \\
        | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \\
        | head -1 || true)
    fi
    if [ -z "$_eh2_fp" ]; then
      _eh2_fp=$(printf '%s' "$_eh2_stdin" \\
        | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \\
        | head -1 \\
        | sed 's/.*"\\([^"]*\\)"$/\\1/')
    fi
    if [ -n "$_eh2_fp" ]; then
      task_id=$(printf '%s' "$_eh2_fp" \\
        | grep -o 'TASK-[0-9][0-9][0-9][0-9]' \\
        | head -1 || true)
    fi
  fi
fi

if [ -z "$task_id" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_TASK / arg / stdin, skipping"
  emit_judgment "allow"
  exit 0
fi"""

STDIN_FALLBACK_EH1 = """\
# stdin fallback: env/arg なし時に tool_input.file_path から TASK-ID を抽出
if [ -z "$task_id" ] && [ ! -t 0 ]; then
  _eh1_stdin=$(cat 2>/dev/null || true)
  if [ -n "$_eh1_stdin" ]; then
    _eh1_fp=""
    if command -v jq >/dev/null 2>&1; then
      _eh1_fp=$(printf '%s' "$_eh1_stdin" \\
        | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \\
        | head -1 || true)
    fi
    if [ -z "$_eh1_fp" ]; then
      _eh1_fp=$(printf '%s' "$_eh1_stdin" \\
        | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \\
        | head -1 \\
        | sed 's/.*"\\([^"]*\\)"$/\\1/')
    fi
    if [ -n "$_eh1_fp" ]; then
      task_id=$(printf '%s' "$_eh1_fp" \\
        | grep -o 'TASK-[0-9][0-9][0-9][0-9]' \\
        | head -1 || true)
    fi
  fi
fi

if [ -z "$task_id" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_TASK / arg / stdin, skipping (false-positive guard)"
  emit_judgment "allow"
  exit 0
fi"""

# ======================================================================
# Patch 1: EH-2 — task_id 解決部分に stdin fallback 追加
# ======================================================================
EH2_TASK_OLD = """\
if [ -z "$task_id" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_TASK / arg, skipping"
  emit_judgment "allow"
  exit 0
fi"""

patch_file(
    "scripts/hooks/check-c3-approval.sh",
    EH2_TASK_OLD,
    STDIN_FALLBACK_EH2,
)

# ======================================================================
# Patch 2: EH-2 — c3_status を python3 strict JSON 解析に変更
# ======================================================================
EH2_GREP_OLD = """\
c3_status=$(grep '"c3_status"' "$c3_file" 2>/dev/null \\
  | sed 's/.*"c3_status"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/' || echo "")"""

EH2_PYTHON_NEW = """\
c3_status=$(python3 - "$c3_file" <<'PYC3' 2>/dev/null || true
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    if isinstance(data, dict):
        print(data.get("c3_status", ""))
except Exception:
    pass
PYC3
)"""

patch_file(
    "scripts/hooks/check-c3-approval.sh",
    EH2_GREP_OLD,
    EH2_PYTHON_NEW,
)

# ======================================================================
# Patch 3: EH-1 — task_id 解決部分に stdin fallback 追加
# ======================================================================
EH1_TASK_OLD = """\
if [ -z "$task_id" ]; then
  log_event "SKIP" "no PLANGATE_HOOK_TASK / arg, skipping (false-positive guard)"
  emit_judgment "allow"
  exit 0
fi"""

patch_file(
    "scripts/hooks/check-plan-exists.sh",
    EH1_TASK_OLD,
    STDIN_FALLBACK_EH1,
)

print("=== all patches applied ===" if not dry_run else "=== dry-run complete ===")
PYEOF
