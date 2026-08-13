#!/bin/sh
# apply-eh3-ho-always.sh — #1089 / TASK-1089 の HO 適用スクリプト（非 HO）
#
# 目的:
#   EH-3 (`scripts/hooks/check-plan-hash.sh`) の Hardening Override 判定が
#   `if [ -z "$task_id" ]` 分岐の内側にあり、`PLANGATE_HOOK_TASK` 設定時に
#   9 カテゴリすべてで発火しない問題（#1089）を是正する。
#
# 本スクリプトは 1 オペレーションで次の 3 つを行う（部分適用を避ける）:
#   (1) scripts/hooks/check-plan-hash.sh    HO 判定を task_id 分岐の前へ移動【HO パス】
#   (2) .claude/rules/mode-classification.md 行番号アンカー L124-134 → 記号アンカー【HO パス】
#   (3) tests/fixtures/eh3-known-gap-1089.flag  KNOWN-GAP 宣言を削除【非 HO】
#
#   (3) を同時に行わないと `tests/extras/ta-65-eh3-ho-task-context.sh` が
#   「stale KNOWN-GAP 宣言」として FAIL する（黙って緑にならない設計）。
#
# 責務: docs/ai/ho-change-workflow.md「標準フロー」に従う。
#   AI は本スクリプトの**作成と --dry-run のみ**。`--apply` の実行は **Human-owned**。
#
# Usage:
#   sh scripts/apply-eh3-ho-always.sh              # dry-run（既定・書き込みなし）
#   sh scripts/apply-eh3-ho-always.sh --dry-run    # 同上（明示）
#   sh scripts/apply-eh3-ho-always.sh --apply      # 実適用（Human-owned）
#
# Exit codes:
#   0 = 成功（適用 / dry-run / 既適用 skip）
#   1 = 引数エラー / アンカー未検出 / 対象ファイル不在（＝何も書き込まない）
#
# Refs: #1089 / docs/working/TASK-1089/

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HOOK="$REPO_ROOT/scripts/hooks/check-plan-hash.sh"
RULES="$REPO_ROOT/.claude/rules/mode-classification.md"
FLAG="$REPO_ROOT/tests/fixtures/eh3-known-gap-1089.flag"

# ── 引数 strict 検証（未知引数は即 exit 1）─────────────────────────
MODE=dry-run
case "${1:-}" in
  "") MODE=dry-run ;;
  --dry-run) MODE=dry-run ;;
  --apply) MODE=apply ;;
  *)
    printf 'error: unknown argument: %s\n' "$1" >&2
    printf 'usage: sh scripts/apply-eh3-ho-always.sh [--dry-run|--apply]\n' >&2
    exit 1
    ;;
esac
if [ "$#" -gt 1 ]; then
  printf 'error: too many arguments (%s)\n' "$#" >&2
  exit 1
fi

for f in "$HOOK" "$RULES"; do
  if [ ! -f "$f" ]; then
    printf 'error: target not found: %s\n' "$f" >&2
    exit 1
  fi
done

MODE="$MODE" HOOK="$HOOK" RULES="$RULES" FLAG="$FLAG" REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import difflib
import os
import sys

mode = os.environ["MODE"]
hook_path = os.environ["HOOK"]
rules_path = os.environ["RULES"]
flag_path = os.environ["FLAG"]
repo_root = os.environ["REPO_ROOT"]


def fail(msg):
    sys.stderr.write("error: %s\n" % msg)
    sys.exit(1)


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def atomic_write(path, text):
    # 元ファイルの mode を保存して復元する（os.replace は新しい inode を作るため、
    # 復元しないと実行ビットが落ちる = check-plan-hash.sh の 100755 → 100644）
    mode = os.stat(path).st_mode
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, mode & 0o7777)
    os.replace(tmp, path)


def show_diff(path, before, after):
    rel = os.path.relpath(path, repo_root)
    d = difflib.unified_diff(
        before.splitlines(keepends=True),
        after.splitlines(keepends=True),
        fromfile="a/" + rel,
        tofile="b/" + rel,
        n=3,
    )
    sys.stdout.write("".join(d))


# ---- (1) check-plan-hash.sh: HO 判定を task_id 分岐の前へ移動 --------------
HOOK_ANCHOR_INSERT = "# P4(d) ファイルパス感応型ガード"
HOOK_TASK_BRANCH = 'if [ -z "$task_id" ]; then'

MOVED_BLOCK = '''# ===== Hardening Override 判定（#1089 / TASK-1089）=====
# TASK 文脈（PLANGATE_HOOK_TASK / $1）の有無に依存せず評価する。TASK-0106 では
# 本判定が no-task 分岐の内側にあったため、TASK 設定時は plan_hash 検証パスへ
# 抜けて 9 カテゴリすべてが一度も評価されなかった（#1089）。
# 判定内容・9 カテゴリ・「maintenance 窓内でも常時 block」は不変（R-003/R-015）。
# 優先順は BYPASS > Override > (no-task: maintenance/doc-light/SKIP_REASON,
# task: plan_hash 検証)。
# (i) target_file 正規化（R-028）
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
  printf '[Hook EH-3] %s\\n' "$reason" >&2
  exit 2
fi

'''

OLD_INBRANCH = '''  # 判定順序 (R-020):
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
    printf '[Hook EH-3] %s\\n' "$reason" >&2
    exit 2
  fi

'''

NEW_INBRANCH = '''  # 判定順序 (R-020):
  #   (i)   target_file 正規化（./ 除去等・R-028）        ← #1089 で task_id 分岐の前へ移動
  #   (ii)  Hardening Override 物理先頭判定（R-003/R-015） ← #1089 で task_id 分岐の前へ移動
  #   (iii) maintenance ファイル valid 判定（v1=30分窓、v2=allowed_paths/one_shot/consumed_at）
  #   (iv)  allowed_paths スコープ判定（指定なし=Override 対象以外を許可、後方互換）
  #   (v)   flock(LOCK_EX|LOCK_NB) → 再 open(path) で inode 比較 → consumed_at 未消費なら os.replace（R-002/R-017/R-027/R-031）
  # 優先順 BYPASS(上記) > Override(block) > maintenance(SKIP) > 通常(SKIP_REASON)。
  # env では maintenance 有効化しない（承認ファイルのみ=AI自己付与不可・R-011）。
  # (i)(ii) は本分岐に入る前に評価済み（#1089）。_norm_target はそこで確定する。
'''

hook_before = read(hook_path)

# 冪等判定: HO 判定（_override=0）が task_id 分岐より前なら適用済み
i_override = hook_before.find("_override=0")
i_branch = hook_before.find(HOOK_TASK_BRANCH)
if i_override == -1:
    fail("anchor not found in %s: _override=0" % hook_path)
if i_branch == -1:
    fail("anchor not found in %s: %s" % (hook_path, HOOK_TASK_BRANCH))
hook_applied = i_override < i_branch

hook_after = hook_before
if not hook_applied:
    if hook_before.count(OLD_INBRANCH) != 1:
        fail(
            "anchor validation failed in %s: expected exactly 1 occurrence of the "
            "in-branch Hardening Override block, found %d (has the file drifted from "
            "the base commit?)" % (hook_path, hook_before.count(OLD_INBRANCH))
        )
    if hook_before.count(HOOK_ANCHOR_INSERT) != 1:
        fail("anchor not found (or ambiguous) in %s: %s" % (hook_path, HOOK_ANCHOR_INSERT))
    hook_after = hook_before.replace(OLD_INBRANCH, NEW_INBRANCH, 1)
    idx = hook_after.find(HOOK_ANCHOR_INSERT)
    hook_after = hook_after[:idx] + MOVED_BLOCK + hook_after[idx:]

# ---- (2) mode-classification.md: 行番号アンカー → 記号アンカー -------------
RULES_OLD = (
    "  - 対象パス (Hardening Override 対象と完全一致 / "
    "[`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) "
    "L124-134 case 文 = **9 カテゴリ** 正本):"
)
RULES_NEW = (
    "  - 対象パス (Hardening Override 対象と完全一致 / "
    "[`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) "
    "の **`_override=0` 直後の `case` ブロック**（`esac` まで）= **9 カテゴリ** 正本。"
    "行番号で参照しないこと — 行番号アンカーは実装の移動で黙って別ブロックを指す / #1089):"
)

rules_before = read(rules_path)
rules_applied = RULES_OLD not in rules_before
if not rules_applied and rules_before.count(RULES_OLD) != 1:
    fail("anchor validation failed in %s: expected exactly 1 line-number anchor" % rules_path)
rules_after = rules_before if rules_applied else rules_before.replace(RULES_OLD, RULES_NEW, 1)

# ---- (3) KNOWN-GAP flag の削除 --------------------------------------------
flag_present = os.path.exists(flag_path)

# ---- 出力 -----------------------------------------------------------------
nothing_to_do = hook_applied and rules_applied and not flag_present
if nothing_to_do:
    print("[apply-eh3-ho-always] already applied — nothing to do (idempotent)")
    sys.exit(0)

print("[apply-eh3-ho-always] mode=%s" % mode)
print("  (1) check-plan-hash.sh        : %s" % ("already applied" if hook_applied else "WILL CHANGE"))
print("  (2) mode-classification.md    : %s" % ("already applied" if rules_applied else "WILL CHANGE"))
print("  (3) eh3-known-gap-1089.flag   : %s" % ("WILL DELETE" if flag_present else "already removed"))

if mode == "dry-run":
    print("")
    if not hook_applied:
        show_diff(hook_path, hook_before, hook_after)
    if not rules_applied:
        show_diff(rules_path, rules_before, rules_after)
    if flag_present:
        print("--- a/tests/fixtures/eh3-known-gap-1089.flag")
        print("+++ /dev/null   (KNOWN-GAP 宣言の削除)")
    print("")
    print("[apply-eh3-ho-always] dry-run — 何も書き込んでいない。適用は --apply（Human-owned）")
    sys.exit(0)

if not hook_applied:
    atomic_write(hook_path, hook_after)
    print("  applied: %s" % hook_path)
if not rules_applied:
    atomic_write(rules_path, rules_after)
    print("  applied: %s" % rules_path)
if flag_present:
    os.remove(flag_path)
    print("  removed: %s" % flag_path)
print("[apply-eh3-ho-always] done. 次に検証すること:")
print("  sh tests/extras/ta-65-eh3-ho-task-context.sh </dev/null   # mode=fixed で PASS")
print("  sh tests/run-tests.sh")
PY
