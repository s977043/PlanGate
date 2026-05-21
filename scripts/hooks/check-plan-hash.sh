#!/bin/sh
# check-plan-hash.sh — Hook EH-3: plan_hash 改竄検知
#
# approvals/c3.json の plan_hash と現 plan.md の SHA-256 を突合。
# 不一致なら C-3 承認後に plan が改変されたことを示す → 違反。
#
# Usage:
#   sh scripts/hooks/check-plan-hash.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-plan-hash.sh
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0056

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# bypass
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-3] BYPASS\n'
  exit 0
fi

# TASK / 対象ファイル resolution
# codebase 慣行（check-forbidden-files.sh）に合わせ env → 位置引数の順。
task_id=${PLANGATE_HOOK_TASK:-${1:-}}
target_file=${PLANGATE_HOOK_FILE:-${2:-}}

# PreToolUse hook では Claude Code が stdin に JSON（tool_input.file_path）を
# 渡す。env / 引数で未指定なら stdin JSON から対象パスを補完する（最終手段）。
if [ -z "$target_file" ] && [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
  if [ -n "$_stdin" ]; then
    # V-3/Gemini 指摘: sed の貪欲マッチは「最後の "file_path"」を拾い、
    # 偽プロパティ注入で plan.md 判定を回避され得る。jq で正規パス
    # (.tool_input.file_path) を優先抽出し、無ければ「最初に出現する」
    # file_path を grep -o（非貪欲・出現順）で取得する。
    if command -v jq >/dev/null 2>&1; then
      target_file=$(printf '%s' "$_stdin" \
        | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \
        | head -1)
    fi
    if [ -z "$target_file" ]; then
      target_file=$(printf '%s' "$_stdin" \
        | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 \
        | sed 's/.*"\([^"]*\)"$/\1/')
    fi
  fi
fi

# P4(d) ファイルパス感応型ガード（TASK-0070 / C-3 F1-b 採用 / Gemini レビュー）:
#   - TASK 文脈なし & 対象が plan.md → BLOCK（C-3 承認後の plan 改変を
#     TASK 文脈を消して通す攻撃を阻止。Gemini 相談 Case 1）
#   - TASK 文脈なし & plan.md 以外 → SKIP（汎用 Edit/Write を許可。
#     check-forbidden-files.sh と同じ「no task→skip」慣行。Case 2）
#   - PLANGATE_HOOK_STRICT=1 は従来どおり no-task を一律 block（後方互換）
if [ -z "$task_id" ]; then
  # 正規化（V-3/Gemini 指摘）: 末尾空白除去 + 小文字化で plan.md 判定回避を防ぐ
  #   - macOS は既定で大文字小文字非区別 → PLAN.md で OS 上は plan.md 改変可能
  #   - "plan.md "（末尾空白）等の表記揺れも plan.md として扱う
  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
  case "$_tf_lc" in
    */plan.md|plan.md)
      reason="plan.md edited without TASK context (EH-3 bypass guard): $target_file"
      log_event "VIOLATION" "$reason"
      printf '[Hook EH-3] BLOCK: plan.md edited without TASK context.\n' >&2
      printf '  target: %s\n' "$target_file" >&2
      printf '  Set PLANGATE_HOOK_TASK=TASK-XXXX to allow plan.md edits.\n' >&2
      exit 2
      ;;
  esac
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    printf 'Usage: %s <TASK-XXXX>  (or set PLANGATE_HOOK_TASK)\n' "$0" >&2
    exit 2
  fi

  # ===== TASK-0106: メンテモード v2（承認ファイル方式 + 多層 + Override 物理先頭）=====
  # 判定順序 (R-020):
  #   (i)   target_file 正規化（./ 除去等・R-028）
  #   (ii)  Hardening Override 物理先頭判定（R-003/R-015、10 パターン、maintenance より上）
  #   (iii) maintenance ファイル valid 判定（v1=30分窓、v2=allowed_paths/one_shot/consumed_at）
  #   (iv)  allowed_paths スコープ判定（指定なし=Override 対象以外を許可、後方互換）
  #   (v)   flock(LOCK_EX|LOCK_NB) → 再 open(path) で inode 比較 → consumed_at 未消費なら os.replace（R-002/R-017/R-027/R-031）
  # 優先順 BYPASS(上記) > Override(block) > maintenance(SKIP) > 通常(SKIP_REASON)。
  # env では maintenance 有効化しない（承認ファイルのみ=AI自己付与不可・R-011）。
  #
  # (i) target_file 正規化
  _norm_target="${target_file:-}"
  case "$_norm_target" in
    ./*) _norm_target="${_norm_target#./}" ;;
  esac
  case "$_norm_target" in
    "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
  esac

  # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
  _override=0
  case "$_norm_target" in
    .claude/rules/*.md) _override=1 ;;
    .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
    .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
    .claude/agents/*.md|.claude/agents/*/*.md) _override=1 ;;
    scripts/hooks/*.sh) _override=1 ;;
    bin/plangate) _override=1 ;;
    schemas/*.schema.json) _override=1 ;;
    .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
    AGENTS.md|CLAUDE.md) _override=1 ;;
  esac
  if [ "$_override" = "1" ]; then
    reason="HARDENING_OVERRIDE: ${_norm_target} は maintenance 窓内でも常時 block (R-003/R-015)"
    log_event "HARDENING_OVERRIDE" "$reason"
    printf '[Hook EH-3] %s\n' "$reason" >&2
    exit 2
  fi

  # (iii)-(v) maintenance valid + scope + one-shot atomic consume
  _maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"
  if [ -f "$_maint" ]; then
    _mresult=$(MAINT_FILE="$_maint" NORM_TARGET="$_norm_target" python3 - <<'PYM' 2>/dev/null || true
import json, os, sys, time, fnmatch
import fcntl
maint_path = os.environ["MAINT_FILE"]
norm_target = os.environ["NORM_TARGET"]
try:
    with open(maint_path, "r") as f:
        d = json.load(f)
    ga = int(d["until"]); gat = int(d["granted_at"]); now = int(time.time())
    base_ok = (str(d.get("approved_by","")).strip()!="" and
               str(d.get("reason","")).strip()!="" and
               gat<=now and ga>now and 0<ga-gat<=1800)
    if not base_ok:
        print("INVALID|base validation failed"); sys.exit(0)
    allowed = d.get("allowed_paths")
    if allowed is not None:
        if not isinstance(allowed, list):
            print("INVALID|allowed_paths not array"); sys.exit(0)
        matched = any(fnmatch.fnmatch(norm_target, pat) for pat in allowed)
        if not matched:
            print(f"OUT_OF_SCOPE|target={norm_target} not in allowed_paths={allowed}")
            sys.exit(0)
    one_shot = bool(d.get("one_shot", False))
    if not one_shot:
        print(f"VALID|legacy 30min window (one_shot=false), target={norm_target}")
        sys.exit(0)
    if d.get("consumed_at") is not None:
        print(f"CONSUMED|one_shot already consumed at {d.get('consumed_at')}")
        sys.exit(0)
    try:
        with open(maint_path, "r+") as lock_fp:
            try:
                fcntl.flock(lock_fp.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print("RACE_LOCK|flock LOCK_NB failed (concurrent hook), fail-closed")
                sys.exit(0)
            try:
                lock_ino = os.fstat(lock_fp.fileno()).st_ino
                path_ino = os.stat(maint_path).st_ino
            except FileNotFoundError:
                print("RACE_DELETE|target removed during lock, fail-closed")
                sys.exit(0)
            if lock_ino != path_ino:
                print(f"RACE_INODE|fd ino={lock_ino} != path ino={path_ino}, fail-closed (R-031)")
                sys.exit(0)
            lock_fp.seek(0)
            d2 = json.load(lock_fp)
            if d2.get("consumed_at") is not None:
                print(f"RACE_CONSUMED|re-read after lock: already consumed by other")
                sys.exit(0)
            d2["consumed_at"] = now
            tmp = maint_path + ".tmp"
            with open(tmp, "w") as wf:
                json.dump(d2, wf, ensure_ascii=False, indent=2)
            os.replace(tmp, maint_path)
            print(f"VALID|one_shot consumed (consumed_at={now}), target={norm_target}")
            sys.exit(0)
    except Exception as e:
        print(f"ERROR|{e}")
        sys.exit(0)
except Exception as e:
    print(f"INVALID|{e}")
PYM
)
    case "$_mresult" in
      VALID*)
        reason="MAINTENANCE_SKIP: non-plan ${_norm_target:-unknown} ($_mresult)"
        log_event "MAINTENANCE_SKIP" "$reason"
        printf '[Hook EH-3 SKIP] %s\n' "$reason"
        exit 0
        ;;
      *)
        log_event "MAINTENANCE_BLOCK" "fail-closed: $_mresult"
        ;;
    esac
  fi

  # ===== SKIP_REASON 例外申請（空/空白のみなら SKIP せず停止）=====
  # 本ブロックは no-task 経路（task_id 空）。SKIP_REASON 源は env のみ
  # （todo.md は TASK 文脈前提＝ここでは解決不能。V-3 MJ-2: 死に分岐を除去）。
  # V-3 MJ-1: 前後空白を除去し「空白のみ」を実質空として拒否。
  _skipr=$(printf '%s' "${PLANGATE_SKIP_REASON:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -z "$_skipr" ]; then
    log_event "SKIP_BLOCKED" "no task_id non-plan SKIP but SKIP_REASON empty — refusing to skip (set PLANGATE_SKIP_REASON)"
    printf '[Hook EH-3] SKIP 拒否: SKIP_REASON 未設定。\n' >&2
    printf '  PLANGATE_SKIP_REASON=... を設定するか、メンテ承認ファイルを人間が発行してください。\n' >&2
    exit 2
  fi
  # decision-log.jsonl に reason を append（人間が後で acknowledged_by 追記→CI が未追記を fail）
  _dlog="$WORKING_DIR/_audit/skip-decision-log.jsonl"
  mkdir -p "$(dirname "$_dlog")"
  _ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  _esc_r=$(printf '%s' "$_skipr" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t')
  _esc_f=$(printf '%s' "${target_file:-unknown}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t')
  printf '{"ts":"%s","event":"EH-3_SKIP","target":"%s","skip_reason":"%s","acknowledged_by":null,"acknowledged_at":null}\n' "$_ts" "$_esc_f" "$_esc_r" >>"$_dlog"
  reason="no task_id; non-plan target (${target_file:-unknown}) — skipped (SKIP_REASON 記録済・要人間追認)"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

case "$task_id" in
  TASK-*) ;;
  *)
    printf 'error: invalid task_id: %s\n' "$task_id" >&2
    exit 2
    ;;
esac

plan_file="$WORKING_DIR/$task_id/plan.md"
c3_file="$WORKING_DIR/$task_id/approvals/c3.json"

if [ ! -f "$plan_file" ]; then
  reason="plan.md not found: $plan_file"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

if [ ! -f "$c3_file" ]; then
  reason="c3.json not found: $c3_file (no approval to compare against)"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

# c3.json から plan_hash を抽出（strict JSON / #282 TASK-0105）。
# 寛容 sed 抽出は不正 JSON の c3.json でも plan_hash を拾い承認判定の
# 入力健全性を損なうため、scripts/plan_hash_util.recorded_plan_hash と
# 意味一致の strict 解析へ。不正/欠落/非 object/prefix 不一致は空（=SKIP）。
# python3 は本フック :108 で既出依存（新規依存追加なし）。
recorded_hash=$(python3 - "$c3_file" <<'PHX' 2>/dev/null || echo ""
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(""); raise SystemExit(0)
if not isinstance(d, dict):
    print(""); raise SystemExit(0)
v = d.get("plan_hash", "")
print(v[7:] if isinstance(v, str) and v.startswith("sha256:") else "")
PHX
)

if [ -z "$recorded_hash" ]; then
  reason="plan_hash not found in c3.json"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

current_hash=$(sha256_of "$plan_file")

if [ "$recorded_hash" = "$current_hash" ]; then
  log_event "PASS" "plan_hash matches"
  printf '[Hook EH-3 PASS] plan_hash matches current plan.md\n'
  exit 0
fi

reason="plan_hash mismatch: recorded=$recorded_hash, current=$current_hash"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-3 BLOCK] plan.md was modified after C-3 approval.\n' >&2
  printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
  printf '  Current : sha256:%s\n' "$current_hash" >&2
  printf '  Action  : Re-approval required (update c3.json plan_hash) or revert plan.md.\n' >&2
  exit 1
fi

printf '[Hook EH-3 WARNING] plan_hash mismatch (plan.md modified post-C-3)\n' >&2
printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
printf '  Current : sha256:%s\n' "$current_hash" >&2
exit 0
