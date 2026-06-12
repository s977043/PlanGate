#!/bin/sh
# apply-task-0128-approve.sh — TASK-0128
# bin/plangate に `approve` サブコマンド（人間ワンアクション C-3 承認）を追加する。
#
# bin/plangate は Hardening Override 対象のため AI は直接編集できない。本スクリプトを
# AI が用意し、Human が dry-run で差分確認のうえ適用する（責務4分類: HO 実適用は Human）。
#
# 追加内容:
#   - _plangate_presence_gate(): L1-L4 Human-presence 検証（副作用フリー / maintenance 不変 / R-005）
#   - cmd_approve(): plan_hash 自動算出・approved_by 解決・三値 schema 準拠 c3.json 生成（R-003/R-004/R-006/R-008）
#   - dispatch `approve)` + help 行
#
# 使い方:
#   sh scripts/apply-task-0128-approve.sh --dry-run   # 差分プレビュー
#   sh scripts/apply-task-0128-approve.sh             # 実適用（Human が実行）
#
# 冪等: cmd_approve が既にあれば何もしない。
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/bin/plangate"
DRY_RUN=0
if [ $# -gt 0 ]; then
  if [ "$1" = "--dry-run" ] && [ $# -eq 1 ]; then
    DRY_RUN=1
  else
    echo "ERROR: 不正な引数です。Usage: $0 [--dry-run]" >&2
    exit 1
  fi
fi

[ -f "$TARGET" ] || { echo "ERROR: $TARGET が見つかりません"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

if grep -q 'cmd_approve()' "$TARGET"; then
  echo "SKIP: cmd_approve は既に適用済み"
  exit 0
fi

# アンカー検証（構造変更検知）
for anchor in '# ── dispatch ──' 'maintenance) cmd_maintenance "$@" ;;'; do
  grep -qF "$anchor" "$TARGET" || { echo "ERROR: アンカー '$anchor' が見つかりません（構造変更の可能性）"; exit 1; }
done

python3 - "$TARGET" "$DRY_RUN" <<'PY'
import sys, re, difflib

target, dry = sys.argv[1], sys.argv[2] == "1"
src = open(target).read()

FUNC = r'''
# ── presence gate (TASK-0128 / shared Human-presence L1-L4, side-effect free) ──
# maintenance の L1-L4 と同等の best-effort 防御。_maintenance 生成や
# maintenance 固有 audit を起こさない（R-005）。引数: $1=context label。
# 監査は docs/working/_audit/hook-events.log に context 付きで記録。
_plangate_presence_gate() {
  _pg_ctx="${1:-approve}"
  _pg_log="$plangate_root/docs/working/_audit/hook-events.log"
  mkdir -p "$plangate_root/docs/working/_audit"
  _pg_audit() {
    printf '{"ts":"%s","event":"%s_presence_attempt","verdict":"%s","ppid":%s,"isatty_stdin":%s,"detail":%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_pg_ctx" "$1" "${PPID:-0}" \
      "$([ -t 0 ] && printf true || printf false)" \
      "$(printf '%s' "$2" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
      >> "$_pg_log" 2>/dev/null || true
  }
  # L1: isatty
  if ! [ -t 0 ]; then
    _pg_audit reject_L1 "non-interactive stdin"
    printf 'error: L1 interactive TTY required (stdin not a tty)\n' >&2
    return 1
  fi
  # L2: env barrier
  for _evname in CI CLAUDE_AGENT CURSOR_AGENT PLANGATE_BYPASS_HOOK; do
    _evval=$(eval "printf '%s' \"\${$_evname:-}\"")
    if [ -n "$_evval" ]; then
      _pg_audit reject_L2 "env $_evname set"
      printf 'error: L2 agent env detected (%s set)\n' "$_evname" >&2
      return 1
    fi
  done
  # L3: parent process heuristic
  _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
  if [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
  if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then
    _pg_audit reject_L3 "ppid comm=$_pcomm"
    printf 'error: L3 AI agent lineage detected (ppid comm: %s)\n' "$_pcomm" >&2
    return 1
  fi
  # L4: interactive nonce
  _nonce=$(python3 -c 'import secrets; print(secrets.token_hex(4))')
  printf 'L4 nonce challenge: type the 8-hex string to confirm human operation:\n  %s\n' "$_nonce"
  printf 'PLANGATE_APPROVE_ACK> '
  read _ack || _ack=""
  if [ "$_ack" != "$_nonce" ]; then
    _pg_audit reject_L4 "nonce mismatch"
    printf 'error: L4 nonce mismatch\n' >&2
    return 1
  fi
  _pg_audit accept "presence confirmed"
  return 0
}

# ── approve (TASK-0128 / human one-action C-3 approval) ──
# 人間の承認「判断」だけで c3.json を schema 準拠で生成（JSON 手書き不要）。
# AI 自己承認は _plangate_presence_gate(L1-L4) で物理的に封じる。
cmd_approve() {
  _ap_status="APPROVED"; _ap_reason=""; _ap_conditions=""; _ap_force="false"; _ap_task=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --reject)      _ap_status="REJECTED"; shift ;;
      --conditional) _ap_status="CONDITIONAL"; shift ;;
      --reason)      _ap_reason="$2"; shift 2 ;;
      --conditions)  _ap_conditions="$2"; shift 2 ;;
      --force)       _ap_force="true"; shift ;;
      -*)            printf 'error: unknown arg: %s\n' "$1" >&2; return 2 ;;
      *)             _ap_task="$1"; shift ;;
    esac
  done
  [ -n "$_ap_task" ] || { printf 'Usage: plangate approve <TASK-XXXX> [--reject --reason <t>|--conditional --conditions <t>]\n' >&2; return 2; }
  # 排他
  if [ "$_ap_status" = "REJECTED" ] && [ -n "$_ap_conditions" ]; then printf 'error: --conditions is for --conditional\n' >&2; return 2; fi
  plangate_validate_task_id "$_ap_task"
  _ap_dir="$plangate_working_dir/$_ap_task"
  _ap_plan="$_ap_dir/plan.md"
  [ -f "$_ap_plan" ] || { printf 'error: plan.md not found: %s\n' "$_ap_plan" >&2; return 1; }

  # 三値 schema 必須フィールド（R-004）: REJECTED→reason / CONDITIONAL→conditions
  if [ "$_ap_status" = "REJECTED" ] && [ -z "$_ap_reason" ]; then
    if [ -t 0 ]; then printf 'rejection reason> '; read _ap_reason || _ap_reason=""; fi
    [ -n "$_ap_reason" ] || { printf 'error: --reason required for --reject (schema)\n' >&2; return 2; }
  fi
  if [ "$_ap_status" = "CONDITIONAL" ] && [ -z "$_ap_conditions" ]; then
    if [ -t 0 ]; then printf 'conditions> '; read _ap_conditions || _ap_conditions=""; fi
    [ -n "$_ap_conditions" ] || { printf 'error: --conditions required for --conditional (schema)\n' >&2; return 2; }
  fi

  # 既存 c3.json
  _ap_c3="$_ap_dir/approvals/c3.json"
  if [ -f "$_ap_c3" ] && [ "$_ap_force" = "false" ]; then
    printf 'note: existing c3.json found; re-approval will overwrite (use --force to skip this note)\n' >&2
  fi

  # Human-presence 検証（自己承認不可）
  _plangate_presence_gate approve || { printf 'error: approval aborted (presence gate failed)\n' >&2; return 1; }

  # 自動算出
  _ap_hash="sha256:$(plangate_sha256 "$_ap_plan")"
  _ap_by="$(git -C "$plangate_root" config user.email 2>/dev/null || true)"
  [ -n "$_ap_by" ] || _ap_by="$(git -C "$plangate_root" config user.name 2>/dev/null || true)"
  [ -n "$_ap_by" ] || _ap_by="${USER:-unknown}"
  _ap_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$_ap_dir/approvals"
  # schema 準拠 c3.json 生成（identity 限界は _ 注釈で明示 / R-006）
  python3 - "$_ap_c3" "$_ap_task" "$_ap_status" "$_ap_by" "$_ap_at" "$_ap_hash" "$_ap_reason" "$_ap_conditions" <<'PYC'
import json, sys
c3, task, status, by, at, phash, reason, conditions = sys.argv[1:9]
d = {
    "task_id": task,
    "phase": "C-3",
    "c3_status": status,
    "approved_by": by,
    "approved_at": at,
    "plan_hash": phash,
    "_approved_by_source": "git-config",
    "_approver_identity_unverified": True,
    "_note": "Generated by `plangate approve` (TASK-0128). Human presence verified via L1-L4; identity (approved_by) is git-config derived and NOT cryptographically verified.",
}
if status == "REJECTED":
    d["rejection_reason"] = reason
if status == "CONDITIONAL":
    d["conditions"] = conditions
with open(c3, "w") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write("\n")
PYC
  printf 'c3.json written: %s (c3_status=%s)\n' "$_ap_c3" "$_ap_status"

  # schema 検証（R-008・既存 validate-schemas.py / jsonschema 任意）
  _ap_vs="$plangate_root/scripts/validate-schemas.py"
  if [ -f "$_ap_vs" ]; then
    if python3 "$_ap_vs" "$_ap_c3" >/dev/null 2>&1; then
      printf '  [PASS] schema valid (c3-approval.schema.json)\n'
    else
      _ap_vrc=$?
      if [ "$_ap_vrc" = "2" ]; then
        printf '  [WARN] schema validation skipped (jsonschema not installed)\n'
      else
        printf '  [FAIL] schema validation failed (rc=%s)\n' "$_ap_vrc" >&2
        return 1
      fi
    fi
  fi

  # 最終確認の分離（R-003）: APPROVED のみ validate、他は status 表示のみ
  if [ "$_ap_status" = "APPROVED" ]; then
    printf '  Running validate (APPROVED only)...\n'
    cmd_validate "$_ap_task" || { printf '  [FAIL] validate did not pass\n' >&2; return 1; }
  else
    printf '  [INFO] %s: validate skipped (only APPROVED unblocks exec). plan_hash recorded: %s\n' "$_ap_status" "$_ap_hash"
  fi
  return 0
}
'''

DISPATCH_OLD = '  maintenance) cmd_maintenance "$@" ;;'
DISPATCH_NEW = DISPATCH_OLD + '\n  approve)     cmd_approve "$@" ;;'

HELP_OLD = '    "  maintenance <start|stop> ...   In-session edit window (Human-only, L1-L4 defense) (TASK-0106)" \\'
HELP_NEW = '    "  approve <TASK-XXXX> [--reject|--conditional]  Human one-action C-3 approval (L1-L4, schema-valid c3.json) (TASK-0128)" \\\n' + HELP_OLD

DISPATCH_MARK = '# ── dispatch ──'

new = src
# 関数を dispatch セクションの直前に挿入
idx = new.index(DISPATCH_MARK)
new = new[:idx] + FUNC.lstrip('\n') + '\n' + new[idx:]
# dispatch case 追加
assert DISPATCH_OLD in new, "dispatch anchor lost"
new = new.replace(DISPATCH_OLD, DISPATCH_NEW, 1)
# help 追加
if HELP_OLD in new:
    new = new.replace(HELP_OLD, HELP_NEW, 1)
else:
    sys.stderr.write("WARN: help anchor not found; skipping help line\n")

if dry:
    diff = difflib.unified_diff(src.splitlines(True), new.splitlines(True),
                                fromfile="bin/plangate", tofile="bin/plangate (after)")
    sys.stdout.write("".join(diff))
    sys.stderr.write("\n[dry-run] 上記差分。適用するには --dry-run なしで実行。\n")
else:
    open(target, "w").write(new)
    sys.stderr.write("[applied] cmd_approve を bin/plangate に追加しました。\n")
PY
