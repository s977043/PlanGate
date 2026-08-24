#!/bin/sh
# apply-workflow-hygiene.sh — .github/workflows/ の衛生是正 apply スクリプト（本体は非 HO）
#
# 目的:
#   origin/main 実測で検出した 3 クラスの workflow 衛生欠落を是正する。
#   対象ファイルは **すべて Hardening Override パス**（.github/workflows/*.yml）の
#   ため、AI は本スクリプトの**作成と --dry-run のみ**。--apply の実行は
#   **Human-owned**（docs/ai/ho-change-workflow.md「標準フロー」）。
#
# 是正内容（3 クラス）:
#   (A) timeout-minutes 欠落 6 job — 暴走 job が課金上限まで走るのを防ぐ。
#       値は gh api .../actions/runs/<id>/jobs の直近 25 run 実測 max の
#       約 4〜8 倍を 5/10 分粒度に丸めた（勘の 10 分固定ではない）。
#         check-pr-issue-link.yml / check     max  12s -> 5
#         codeql.yml              / analyze   max  87s -> 10
#         metrics-privacy.yml     / privacy   max   9s -> 5
#         release-docs-sync.yml   / sync      max  11s -> 10 (push + PR 作成の外部 I/O)
#         schema-validate.yml     / validate  max  16s -> 10 (pip install 変動)
#         slsa-attestation.yml    / provenance max 14s -> 10 (OIDC 署名の外部 I/O)
#   (B) concurrency 欠落 7 workflow — 同一 ref の多重実行で runner を食う。
#       cancel-in-progress は event 別に安全側で決める:
#         PR も走る workflow -> github.event_name == 'pull_request' のときだけ cancel
#         release 起動のみ   -> false (リリース処理を途中で殺さない)
#       注意 (正確な意味論): cancel-in-progress: false が抑止するのは
#       **in-progress run の cancel** だけ。GitHub は同一 group に新しい run が
#       queue されると、それ以前の **pending run を cancel** する。これは
#       cancel-in-progress の値に関わらず起きる。
#       codeql.yml は schedule の github.ref が既定ブランチ = refs/heads/main の
#       ため、**push(main) と schedule が同一 group に入る**。実務上は無害
#       (後勝ちした run が最新の main を解析するので SARIF は最新状態になる) だが、
#       「main push / schedule は必ず全 run が完走する」という主張は成り立たない。
#   (C) check-pr-issue-link.yml の top-level pull-requests: write を job スコープへ
#       (最小権限。codeql.yml が既に採る「top-level contents: read + job で加算」形)
#
# 冪等: 既適用は skip。アンカー未検出は 1 つでもあれば全体を exit 1（部分適用しない）。
#
# Usage:
#   sh scripts/apply-workflow-hygiene.sh              # dry-run（既定・書き込みなし）
#   sh scripts/apply-workflow-hygiene.sh --dry-run    # 同上（明示）
#   PLANGATE_APPLY_CONFIRM=1 sh scripts/apply-workflow-hygiene.sh --apply
#                                                     # 実適用（Human-owned）
#
# Exit codes:
#   0 = 成功（適用 / dry-run / 既適用 skip）
#   1 = 引数エラー / 対象ファイル不在 / アンカー未検出 / 実 HO パスへの --apply で
#       PLANGATE_APPLY_CONFIRM 未設定（いずれも **何も書き込まない**）
#
# 適用順序の依存（重要）:
#   - scripts/apply-pr-issue-link-comment-removal.sh（#1159 系）が同じ
#     check-pr-issue-link.yml の **steps** を差し替える。本スクリプトは同ファイルの
#     **header（on / permissions / jobs 直下）** のみを触るため textual conflict は
#     起きない。
#     **`pull-requests: write` は comment-removal 適用後も必要**（実測: 同スクリプト
#     31 行目が「削除操作に必要なため維持する」と明記し、置換後の step は
#     `gh api -X DELETE repos/$REPO/issues/comments/$id` を呼ぶ）。したがって
#     (C)（top-level -> job スコープへの移動）は **どちらを先に適用しても内容が
#     変わらない**。順序の制約は無い。
#     注意: (C) をスキップしてはならない。write を落とすと cleanup step が 403 で
#     落ちる（＝(C) は「write を消す」変更ではなく「write の適用範囲を job に
#     絞る」変更）。
#   - dependabot PR #1201 が codeql.yml / scorecard.yml の action SHA を更新中。
#     本スクリプトは codeql.yml の header のみ触るため行が重ならないが、
#     **#1201 を先に merge** してから適用するのが安全。
#
# 検証:
#   sh scripts/apply-workflow-hygiene.sh --dry-run
#   # sandbox 適用後: actionlint .github/workflows/*.yml
#
# 環境変数:
#   PLANGATE_WF_DIR — 対象 workflows ディレクトリを差し替える（sandbox 検証専用）
#   PLANGATE_APPLY_CONFIRM — 実 HO パス（<repo>/.github/workflows）へ --apply する
#     際の明示確認（Human-owned）。未設定なら **何も書かずに exit 1**。
#     AI はこの環境変数を設定しない。テストは PLANGATE_WF_DIR で mktemp サンドボックス
#     を指すため確認不要（実 HO パスに触れないので実害ゼロ）。
#     ＝「AI は --apply を実行しない」を規範だけに頼らず **書き込み先で** 守る。
#
# Refs: docs/working/_reports/ci-required-checks-proposal.md

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WF_DIR="${PLANGATE_WF_DIR:-$REPO_ROOT/.github/workflows}"

# ── 引数 strict 検証（未知引数は即 exit 1）─────────────────────────
MODE=dry-run
case "${1:-}" in
  "") MODE=dry-run ;;
  --dry-run) MODE=dry-run ;;
  --apply) MODE=apply ;;
  *)
    printf 'error: unknown argument: %s\n' "$1" >&2
    printf 'usage: sh scripts/apply-workflow-hygiene.sh [--dry-run|--apply]\n' >&2
    exit 1
    ;;
esac
if [ "$#" -gt 1 ]; then
  printf 'error: too many arguments (%s)\n' "$#" >&2
  exit 1
fi

if [ ! -d "$WF_DIR" ]; then
  printf 'error: workflows dir not found: %s\n' "$WF_DIR" >&2
  exit 1
fi

# ── 実 HO パスへの書き込み確認（多層防御）───────────────────────────
# WF_DIR を絶対パスへ正規化してから判定する（相対指定・シンボリックリンクで
# 判定をすり抜けさせない）。
WF_DIR=$(CDPATH= cd -- "$WF_DIR" && pwd)
if [ "$MODE" = apply ] && [ "$WF_DIR" = "$REPO_ROOT/.github/workflows" ]; then
  if [ "${PLANGATE_APPLY_CONFIRM:-0}" != "1" ]; then
    printf 'error: %s は Hardening Override パスです。\n' "$WF_DIR" >&2
    printf '       AI はここへ --apply しません（docs/ai/ho-change-workflow.md）。\n' >&2
    printf '       Human が適用する場合のみ: PLANGATE_APPLY_CONFIRM=1 sh %s --apply\n' "$0" >&2
    printf '       何も書き込んでいません。\n' >&2
    exit 1
  fi
fi

MODE="$MODE" WF_DIR="$WF_DIR" REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import difflib
import os
import sys

mode = os.environ["MODE"]
wf_dir = os.environ["WF_DIR"]
repo_root = os.environ["REPO_ROOT"]

errors = []


def fail_later(msg):
    errors.append(msg)


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def atomic_write(path, text):
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
    sys.stdout.write(
        "".join(
            difflib.unified_diff(
                before.splitlines(keepends=True),
                after.splitlines(keepends=True),
                fromfile="a/" + rel,
                tofile="b/" + rel,
                n=3,
            )
        )
    )


# (file, job_id, minutes, 実測 max 秒)
TIMEOUTS = [
    ("check-pr-issue-link.yml", "check", 5, 12),
    ("codeql.yml", "analyze", 10, 87),
    ("metrics-privacy.yml", "privacy", 5, 9),
    ("release-docs-sync.yml", "sync", 10, 11),
    ("schema-validate.yml", "validate", 10, 16),
    ("slsa-attestation.yml", "provenance", 10, 14),
]

# (file, group slug, cancel-in-progress 式)
PR_CANCEL = "${{ github.event_name == 'pull_request' }}"
CONCURRENCY = [
    ("check-pr-issue-link.yml", "check-pr-issue-link", PR_CANCEL),
    # 注: schedule の github.ref は既定ブランチ (= refs/heads/main) なので
    # push(main) と schedule は同一 group に入る。pending の後勝ちが起きうるが、
    # 後勝ちした run が最新 main を解析するため解析結果としては劣化しない。
    ("codeql.yml", "codeql", PR_CANCEL),
    ("metrics-privacy.yml", "metrics-privacy", PR_CANCEL),
    ("release-docs-sync.yml", "release-docs-sync", "false"),
    ("schema-validate.yml", "schema-validate", PR_CANCEL),
    ("slsa-attestation.yml", "slsa-attestation", "false"),
    ("sync-plugin-plangate.yml", "sync-plugin-plangate", PR_CANCEL),
]

PERM_FILE = "check-pr-issue-link.yml"
PERM_OLD = "permissions:\n  contents: read\n  pull-requests: write\n"
PERM_NEW = "permissions:\n  contents: read\n"
PERM_JOB_OLD = "  check:\n"
PERM_JOB_NEW = (
    "  check:\n"
    "    permissions:\n"
    "      contents: read\n"
    "      pull-requests: write\n"
)


def job_block_range(lines, job_id):
    """job 見出し行の index と job ブロック終端 index(exclusive) を返す。"""
    start = None
    for i, ln in enumerate(lines):
        if ln.rstrip("\n") == "  %s:" % job_id:
            start = i
            break
    if start is None:
        return None, None
    end = len(lines)
    for j in range(start + 1, len(lines)):
        ln = lines[j]
        if not ln.strip() or ln.lstrip(" ").startswith("#"):
            continue
        stripped = ln.lstrip(" ")
        indent = len(ln) - len(stripped)
        if indent <= 2:
            end = j
            break
    return start, end


targets = set(f for f, _a, _b, _c in TIMEOUTS)
targets.update(f for f, _a, _b in CONCURRENCY)
targets.add(PERM_FILE)

files = {}
for name in sorted(targets):
    p = os.path.join(wf_dir, name)
    if not os.path.isfile(p):
        fail_later("target not found: %s" % p)
        continue
    ent = {}
    ent["path"] = p
    ent["before"] = read(p)
    ent["text"] = ent["before"]
    files[name] = ent

if errors:
    for e in errors:
        sys.stderr.write("error: %s\n" % e)
    sys.exit(1)

status = []

# ---- (A) timeout-minutes -------------------------------------------------
for name, job_id, minutes, obs_max in TIMEOUTS:
    ent = files[name]
    lines = ent["text"].splitlines(keepends=True)
    start, end = job_block_range(lines, job_id)
    label = "(A) %-24s %-11s timeout-minutes: %d" % (name, job_id, minutes)
    if start is None:
        fail_later("anchor not found in %s: job '%s'" % (name, job_id))
        continue
    block = lines[start:end]
    if any(ln.lstrip().startswith("timeout-minutes:") for ln in block):
        status.append((label, "already applied"))
        continue
    runs_on = [k for k, ln in enumerate(block) if ln.startswith("    runs-on:")]
    if len(runs_on) != 1:
        fail_later(
            "anchor validation failed in %s job '%s': expected exactly 1 "
            "'    runs-on:' line, found %d" % (name, job_id, len(runs_on))
        )
        continue
    ins = "    timeout-minutes: %d  # 実測 max %ds (直近 25 run)\n" % (minutes, obs_max)
    lines.insert(start + runs_on[0] + 1, ins)
    ent["text"] = "".join(lines)
    status.append((label, "WILL CHANGE"))

# ---- (B) concurrency -----------------------------------------------------
for name, slug, cancel in CONCURRENCY:
    ent = files[name]
    text = ent["text"]
    label = "(B) %-24s concurrency: %s" % (name, slug)
    if "\nconcurrency:\n" in text or text.startswith("concurrency:\n"):
        status.append((label, "already applied"))
        continue
    lines = text.splitlines(keepends=True)
    jobs_idx = [i for i, ln in enumerate(lines) if ln.rstrip("\n") == "jobs:"]
    if len(jobs_idx) != 1:
        fail_later(
            "anchor validation failed in %s: expected exactly 1 top-level 'jobs:' "
            "line, found %d" % (name, len(jobs_idx))
        )
        continue
    block = "concurrency:\n"
    block += "  group: %s-${{ github.workflow }}-${{ github.ref }}\n" % slug
    block += "  cancel-in-progress: %s\n" % cancel
    block += "\n"
    lines.insert(jobs_idx[0], block)
    ent["text"] = "".join(lines)
    status.append((label, "WILL CHANGE"))

# ---- (C) check-pr-issue-link.yml の permissions を job スコープへ ---------
ent = files[PERM_FILE]
label = "(C) %-24s permissions を job スコープへ" % PERM_FILE
if PERM_OLD not in ent["text"]:
    if "      pull-requests: write\n" in ent["text"]:
        status.append((label, "already applied"))
    else:
        fail_later(
            "anchor not found in %s: top-level permissions block "
            "(contents: read / pull-requests: write). ファイルが base から drift した可能性"
            % PERM_FILE
        )
elif ent["text"].count(PERM_OLD) != 1 or ent["text"].count(PERM_JOB_OLD) != 1:
    fail_later("anchor validation failed in %s: permissions / job アンカーが一意でない" % PERM_FILE)
else:
    t = ent["text"].replace(PERM_OLD, PERM_NEW, 1)
    t = t.replace(PERM_JOB_OLD, PERM_JOB_NEW, 1)
    ent["text"] = t
    status.append((label, "WILL CHANGE"))

# ---- 出力 ----------------------------------------------------------------
if errors:
    for e in errors:
        sys.stderr.write("error: %s\n" % e)
    sys.stderr.write("error: アンカー未検出のため何も書き込まずに終了する（部分適用しない）\n")
    sys.exit(1)

changed = [n for n in sorted(files) if files[n]["text"] != files[n]["before"]]

if not changed:
    print("[apply-workflow-hygiene] already applied — nothing to do (idempotent)")
    sys.exit(0)

print("[apply-workflow-hygiene] mode=%s" % mode)
for label, state in status:
    print("  %-58s : %s" % (label, state))
print("")

if mode == "dry-run":
    for name in changed:
        show_diff(files[name]["path"], files[name]["before"], files[name]["text"])
    print("")
    print("[apply-workflow-hygiene] dry-run — 何も書き込んでいない。適用は --apply（Human-owned）")
    sys.exit(0)

for name in changed:
    atomic_write(files[name]["path"], files[name]["text"])
    print("  applied: %s" % files[name]["path"])
print("[apply-workflow-hygiene] done. 次に検証すること:")
print("  actionlint .github/workflows/*.yml")
PY
