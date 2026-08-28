#!/bin/sh
# apply-1101-ho-normalization.sh — #1101 / TASK-1101 の HO 適用スクリプト（非 HO）
#
# 目的:
#   EH-3 (`scripts/hooks/check-plan-hash.sh`) の Hardening Override 判定を、
#   パス表記の揺れ（`./` 前置 / `//` / `/./` / `..` 往復 / repo root 跨ぎ /
#   大小文字 / 末尾空白 とその複合）で迂回できないようにする。
#
# 本スクリプトが行うこと（1 オペレーション / 部分適用を避ける）:
#   (1) 正規化関数 `_pg_fold_path` を hook へ inline
#       （正本ソース: tests/fixtures/pg-fold-path.sh のマーカー間・byte 一致）
#   (2) HO 判定専用キー `_ho_key` を新設し、HO の `case` を小文字側で受ける
#       ※ `_norm_target` は**据え置き**（下流 3 経路が大小文字に感応 / R-001）
#   (3) `reason` / 監査ログを**生の target_file** へ（攻撃の原文を残す / AC-9）
#
# 責務: docs/ai/ho-change-workflow.md「標準フロー」に従う。
#   `scripts/hooks/check-plan-hash.sh` は Hardening Override 対象パス。
#   AI は本スクリプトの**作成と --dry-run のみ**。`--apply` の実行は **Human-owned**。
#
# Usage:
#   sh scripts/apply-1101-ho-normalization.sh              # dry-run（既定・書き込みなし）
#   sh scripts/apply-1101-ho-normalization.sh --dry-run    # 同上（明示）
#   sh scripts/apply-1101-ho-normalization.sh --apply      # 実適用（Human-owned）
#   sh scripts/apply-1101-ho-normalization.sh --revert     # 適用の取り消し
#   sh scripts/apply-1101-ho-normalization.sh --emit       # 適用後の内容を stdout へ
#
#   PG_1101_HOOK=<path>   検証用に対象 hook を差し替える（sandbox 検証で使用）
#
# `--emit` は**一切書き込まない**。適用後の hook 内容を stdout に出すだけで、
# tests/extras/ta-65 の sandbox 複製先を「patch 済み hook」にするために使う
# （Human 適用を待たずに実測するため / plan Step 3・R-008）。
#
# --apply は書き込み直後に smoke check を実行し、**失敗したら自動で revert** する:
#   - HO 1 件（`bin/../bin/plangate`）が rc=2
#   - 非 HO 1 件（`docs/working/TASK-SMOKE/notes.txt`）が rc≠2
#   - 絶対パス 1 件（`/tmp/...`）が rc≠2（偽陽性の検出）
#   - 20 回実行の所要時間が閾値内（無限ループ = ハングの検出）
#   smoke は mktemp サンドボックス上の複製で行い、実 audit ログを汚さない。
#
# Exit codes:
#   0 = 成功（適用 / dry-run / revert / 既適用 skip）
#   1 = 引数エラー / アンカー未検出 / 対象不在 / smoke 失敗（自動 revert 済）
#
# Refs: #1101 / docs/working/TASK-1101/

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HOOK="${PG_1101_HOOK:-$REPO_ROOT/scripts/hooks/check-plan-hash.sh}"
LIB="$REPO_ROOT/tests/fixtures/pg-fold-path.sh"

MODE=dry-run
case "${1:-}" in
  "") MODE=dry-run ;;
  --dry-run) MODE=dry-run ;;
  --apply) MODE=apply ;;
  --revert) MODE=revert ;;
  --emit) MODE=emit ;;
  *)
    printf 'error: unknown argument: %s\n' "$1" >&2
    printf 'usage: sh scripts/apply-1101-ho-normalization.sh [--dry-run|--apply|--revert|--emit]\n' >&2
    exit 1
    ;;
esac
if [ "$#" -gt 1 ]; then
  printf 'error: too many arguments (%s)\n' "$#" >&2
  exit 1
fi

for f in "$HOOK" "$LIB"; do
  if [ ! -f "$f" ]; then
    printf 'error: target not found: %s\n' "$f" >&2
    exit 1
  fi
done

MODE="$MODE" HOOK="$HOOK" LIB="$LIB" REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import difflib
import os
import shutil
import subprocess
import sys
import tempfile
import time

mode = os.environ["MODE"]
hook_path = os.environ["HOOK"]
lib_path = os.environ["LIB"]
repo_root = os.environ["REPO_ROOT"]

BEGIN = "# >>> PG-FOLD-PATH BEGIN (#1101)"
END = "# <<< PG-FOLD-PATH END (#1101)"


def fail(msg):
    sys.stderr.write("error: %s\n" % msg)
    sys.exit(1)


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def atomic_write(path, text):
    # 元ファイルの mode を保存して復元する（os.replace は新しい inode を作るため、
    # 復元しないと実行ビットが落ちる = check-plan-hash.sh の 100755 → 100644）
    file_mode = os.stat(path).st_mode
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, file_mode & 0o7777)
    os.replace(tmp, path)


def show_diff(path, before, after):
    try:
        rel = os.path.relpath(path, repo_root)
    except ValueError:
        rel = path
    d = difflib.unified_diff(
        before.splitlines(keepends=True),
        after.splitlines(keepends=True),
        fromfile="a/" + rel,
        tofile="b/" + rel,
        n=3,
    )
    sys.stdout.write("".join(d))


# ---- 正本ソースから正規化関数ブロックを抽出 --------------------------------
lib_text = read(lib_path)
if lib_text.count(BEGIN) != 1 or lib_text.count(END) != 1:
    fail("marker not found (or ambiguous) in %s" % lib_path)
i0 = lib_text.index(BEGIN)
i1 = lib_text.index(END) + len(END)
FUNC_BLOCK = lib_text[i0:i1] + "\n"

# ---- アンカー -------------------------------------------------------------
ANCHOR_BYPASS = "# bypass\nif [ \"${PLANGATE_BYPASS_HOOK:-0}\" = \"1\" ]; then"

OLD_HO = '''# (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
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

NEW_HO = '''# (i-b) HO 判定専用キー _ho_key の導出（#1101 / TASK-1101）
# 表記揺れ（./ 前置 / // / /./ / .. 往復 / repo root 跨ぎ / 大小文字 / 末尾空白
# とその複合）で HO を迂回できないようにする。**_norm_target は書き換えない**
# ＝下流 3 経路（maintenance allowed_paths の fnmatchcase / c3.json conversation
# 判定 / doc-light 拡張子）が大小文字に感応して共有しているため（R-001）。
_pg_fold_path "${target_file:-}" "$REPO_ROOT" 1
_ho_key=$_PG_FOLD_OUT
if [ "$_PG_FOLD_RC" != "0" ]; then
  # fail-closed: (a) 畳み込み後に先頭 .. が残る / (b) セグメント数 > 256 /
  # (c) 全体長 > 4096 (PATH_MAX 上限) / (d) セグメント長 > 255 (NAME_MAX)。
  # (a) は cwd 次第で repo 内 HO に到達しうる。(b)(c)(d) は EH-3 に timeout が
  # 無く暴走が block ではなく**ハング**になるため上限で切って block へ倒す。
  # AC-8 は (a)(b) の 2 条件のみを規定しており、(c)(d) は #1101 Step 7 の実測
  # （長い大文字パスで小文字化が非線形に悪化）を受けた**逸脱**。ただし (c)(d)
  # に該当するパスは PATH_MAX / NAME_MAX を超えており FS 上のファイルを
  # 指しえないため、正当な書き込みを止めることはない。
  reason="HARDENING_OVERRIDE: ${target_file:-} は正規化できない (fail-closed: ${_PG_FOLD_REASON})"
  log_event "HARDENING_OVERRIDE" "$reason"
  printf '[Hook EH-3] %s\\n' "$reason" >&2
  exit 2
fi

# (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
# 判定対象は _ho_key（小文字化済み）。したがって case は**小文字側で受ける**。
# ラベル 9 行 / パターン 15 個。9 カテゴリの正本は
# .claude/rules/mode-classification.md の Hardening Override 節（内容は不変）。
_override=0
case "$_ho_key" in
  .claude/rules/*.md) _override=1 ;;
  .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
  .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
  .claude/agents/*.md|.claude/agents/*/*.md) _override=1 ;;
  scripts/hooks/*.sh) _override=1 ;;
  bin/plangate) _override=1 ;;
  schemas/*.schema.json) _override=1 ;;
  .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
  agents.md|claude.md) _override=1 ;;
esac
if [ "$_override" = "1" ]; then
  # AC-9: 監査ログと reason には**生の要求パス**を残す（正規化後の値ではない）。
  reason="HARDENING_OVERRIDE: ${target_file:-} は maintenance 窓内でも常時 block (R-003/R-015)"
  log_event "HARDENING_OVERRIDE" "$reason"
  printf '[Hook EH-3] %s\\n' "$reason" >&2
  exit 2
fi
'''

hook_before = read(hook_path)
applied = ("_ho_key=" in hook_before) and (BEGIN in hook_before)


def build_applied(text):
    if text.count(OLD_HO) != 1:
        fail(
            "anchor validation failed in %s: expected exactly 1 occurrence of the "
            "Hardening Override block, found %d (has the file drifted?)"
            % (hook_path, text.count(OLD_HO))
        )
    if text.count(ANCHOR_BYPASS) != 1:
        fail("anchor not found (or ambiguous) in %s: '# bypass'" % hook_path)
    out = text.replace(OLD_HO, NEW_HO, 1)
    idx = out.index(ANCHOR_BYPASS)
    return out[:idx] + FUNC_BLOCK + "\n" + out[idx:]


def build_reverted(text):
    if text.count(NEW_HO) != 1:
        fail("revert: NEW_HO block not found (or ambiguous) in %s" % hook_path)
    if text.count(BEGIN) != 1 or text.count(END) != 1:
        fail("revert: PG-FOLD-PATH marker not found (or ambiguous) in %s" % hook_path)
    out = text.replace(NEW_HO, OLD_HO, 1)
    a = out.index(BEGIN)
    b = out.index(END) + len(END)
    # マーカー直後の改行 + 挿入時に足した空行も取り除く
    while out[b:b + 1] == "\n":
        b += 1
    return out[:a] + out[b:]


def smoke(applied_text):
    """適用後の hook を mktemp サンドボックスで検査する（実 audit を汚さない）。"""
    tmp = tempfile.mkdtemp(prefix="pg1101-smoke-")
    try:
        os.makedirs(os.path.join(tmp, "scripts", "hooks"))
        os.makedirs(os.path.join(tmp, "docs", "working", "_audit"))
        h = os.path.join(tmp, "scripts", "hooks", "check-plan-hash.sh")
        with open(h, "w", encoding="utf-8") as f:
            f.write(applied_text)

        def run(target, task="TASK-SMOKE"):
            env = dict(os.environ)
            env["PLANGATE_HOOK_TASK"] = task
            env["PLANGATE_HOOK_FILE"] = target
            env.pop("PLANGATE_BYPASS_HOOK", None)
            env.pop("PLANGATE_HOOK_STRICT", None)
            with open(os.devnull, "rb") as devnull:
                p = subprocess.run(
                    ["sh", h],
                    stdin=devnull,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    env=env,
                    timeout=20,
                )
            return p.returncode, p.stdout.decode("utf-8", "replace")

        problems = []
        rc, out = run("bin/../bin/plangate")
        if rc != 2 or "HARDENING_OVERRIDE" not in out:
            problems.append("HO 'bin/../bin/plangate' expected rc=2+HARDENING_OVERRIDE, got rc=%s" % rc)
        rc, out = run("docs/working/TASK-SMOKE/notes.txt")
        if rc == 2:
            problems.append("non-HO 'docs/working/TASK-SMOKE/notes.txt' unexpectedly blocked (rc=2)")
        rc, out = run("/tmp/pg1101-smoke-abs/note.md")
        if rc == 2:
            problems.append("absolute path '/tmp/.../note.md' unexpectedly blocked (rc=2)")
        t0 = time.time()
        for _ in range(20):
            run("bin/../bin/plangate")
        elapsed = time.time() - t0
        if elapsed > 20.0:
            problems.append("20 runs took %.2fs (> 20s threshold) — 無限ループの疑い" % elapsed)
        return problems, elapsed
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ---- モード別 -------------------------------------------------------------
if mode == "revert":
    if not applied:
        print("[apply-1101-ho-normalization] not applied — nothing to revert (idempotent)")
        sys.exit(0)
    hook_after = build_reverted(hook_before)
    atomic_write(hook_path, hook_after)
    print("[apply-1101-ho-normalization] reverted: %s" % hook_path)
    sys.exit(0)

if mode == "emit":
    # 書き込みなし。適用後の内容を stdout へ（sandbox 複製用 / plan Step 3）
    sys.stdout.write(hook_before if applied else build_applied(hook_before))
    sys.exit(0)

if applied:
    print("[apply-1101-ho-normalization] already applied — nothing to do (idempotent)")
    sys.exit(0)

hook_after = build_applied(hook_before)

print("[apply-1101-ho-normalization] mode=%s" % mode)
print("  target : %s" % hook_path)
print("  source : %s (%s 〜 %s)" % (lib_path, BEGIN, END))
print("  change : _pg_fold_path を inline / _ho_key 新設 / case を小文字側へ / log を生パスへ")

if mode == "dry-run":
    print("")
    show_diff(hook_path, hook_before, hook_after)
    print("")
    print("[apply-1101-ho-normalization] dry-run — 何も書き込んでいない。適用は --apply（Human-owned）")
    sys.exit(0)

atomic_write(hook_path, hook_after)
print("  applied: %s" % hook_path)

problems, elapsed = smoke(hook_after)
if problems:
    atomic_write(hook_path, hook_before)
    sys.stderr.write("[apply-1101-ho-normalization] smoke check FAILED — 自動 revert しました\n")
    for p in problems:
        sys.stderr.write("  - %s\n" % p)
    sys.exit(1)

print("  smoke  : OK (20 runs in %.2fs)" % elapsed)

# ---- PENDING-APPLY flag の削除（#1089 の KNOWN-GAP flag と同じ機構）--------
# flag が残ったままだと ta-65 が「stale 宣言」として FAIL する（黙って緑にならない）。
flag_path = os.path.join(repo_root, "tests", "fixtures", "eh3-normalization-pending-1101.flag")
is_real_hook = os.path.realpath(hook_path) == os.path.realpath(
    os.path.join(repo_root, "scripts", "hooks", "check-plan-hash.sh")
)
if is_real_hook and os.path.exists(flag_path):
    removed_via_git = False
    try:
        rel_flag = os.path.relpath(flag_path, repo_root)
        proc = subprocess.run(
            ["git", "-C", repo_root, "rm", "-q", "-f", "--", rel_flag],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        removed_via_git = proc.returncode == 0 and not os.path.exists(flag_path)
    except Exception:
        removed_via_git = False
    if not removed_via_git:
        os.remove(flag_path)
        print("  removed: %s (git 管理外だったため index には反映していない)" % flag_path)
    else:
        print("  removed (git rm): %s" % flag_path)

print("[apply-1101-ho-normalization] done. 次に実行・検証すること:")
print("  sh tests/extras/ta-65-eh3-ho-task-context.sh </dev/null")
print("  sh tests/run-tests.sh")
PY
