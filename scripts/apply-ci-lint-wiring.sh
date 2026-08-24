#!/bin/sh
# apply-ci-lint-wiring.sh — CI に shellcheck / actionlint job を追加する HO 適用スクリプト（非 HO）
#
# 目的:
#   この repo はシェル資産が大半を占めるのに CI に静的解析が 1 つも無かった
#   （測定: git grep -niE "shellcheck|actionlint|ruff" origin/main -- .github/workflows/ が空）。
#   本スクリプトは .github/workflows/ci.yml に 2 つの job を追加する。
#
#     shell-lint     : sh scripts/lint-shell.sh --require-tool（gate = -S error）
#                      + --advisory（-S warning、非 gate の参考情報）
#     workflow-lint  : sh scripts/lint-workflows.sh --require-tool
#
#   ci.yml は **Hardening Override パス**であり AI は直接編集できない。
#   docs/ai/ho-change-workflow.md「標準フロー」に従い、AI は本スクリプトの
#   **作成と --dry-run のみ**。実 HO パスへの `--apply` は **Human-owned**。
#
# 多層防御（実 HO パスへの書き込みだけに追加確認を要求する）:
#   `--apply` の適用先が `<repo>/.github/workflows/` 配下のとき、環境変数
#   `PLANGATE_APPLY_CONFIRM=1` が無ければ **何も書かずに exit 1**。
#   AI はこの環境変数を設定しない。テストは `--target` で mktemp サンドボックスを
#   指すため、この確認を必要とせず（実 HO パスに触れないので実害ゼロ）に
#   適用経路の回帰を検査できる。
#   ＝「AI は --apply を実行しない」を規範だけに頼らず、**書き込み先で** 守る。
#
# 新規 workflow ファイルではなく既存 ci.yml に足した理由:
#   - 新規 workflow ファイルも .github/workflows/*.yml = 同じ HO パスなので
#     「apply スクリプト経由」という手間は変わらない
#   - 現状 required check は "Markdown lint" のみ。ci.yml 内に足せば同じ
#     concurrency group（ci-...-${{ github.ref }} / cancel-in-progress）配下で走り、
#     required checks の追加も 1 ファイルの job 名で完結する
#
# Usage:
#   sh scripts/apply-ci-lint-wiring.sh              # dry-run（既定・書き込みなし）
#   sh scripts/apply-ci-lint-wiring.sh --dry-run    # 同上（明示）
#   PLANGATE_APPLY_CONFIRM=1 sh scripts/apply-ci-lint-wiring.sh --apply
#                                                   # 実適用（Human-owned）
#   sh scripts/apply-ci-lint-wiring.sh --target FILE  # 適用先の上書き（sandbox 検証用）
#
#   注記: --target は「実 ci.yml を触らずに適用結果を検証する」ための seam。
#         **実 HO パス（<repo>/.github/workflows/**）を適用先にする --apply だけ**が
#         PLANGATE_APPLY_CONFIRM=1 を要求する。サンドボックス target への --apply は
#         確認不要（テストが使う経路）。
#
# Env:
#   PLANGATE_APPLY_CONFIRM  実 HO パスへ --apply する際の明示確認（Human-owned）。
#
# Exit codes:
#   0 = 成功（適用 / dry-run / 既適用 skip）
#   1 = 引数エラー / アンカー未検出 / 対象ファイル不在 / 実 HO パスへの --apply で
#       PLANGATE_APPLY_CONFIRM 未設定（いずれも **何も書き込まない**）

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET="$REPO_ROOT/.github/workflows/ci.yml"

MODE=dry-run
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) MODE=dry-run ;;
    --apply) MODE=apply ;;
    --target)
      shift
      if [ "$#" -eq 0 ]; then
        printf 'error: --target requires a path\n' >&2
        exit 1
      fi
      TARGET="$1"
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      printf 'usage: sh scripts/apply-ci-lint-wiring.sh [--dry-run|--apply] [--target FILE]\n' >&2
      exit 1
      ;;
  esac
  shift
done

if [ ! -f "$TARGET" ]; then
  printf 'error: target not found: %s\n' "$TARGET" >&2
  exit 1
fi

# ── 実 HO パスへの書き込み確認（多層防御）───────────────────────────
# TARGET を絶対パスへ正規化してから判定する（相対指定・シンボリックリンクで
# 判定をすり抜けさせない）。
_TARGET_DIR=$(CDPATH= cd -- "$(dirname -- "$TARGET")" && pwd)
TARGET_ABS="$_TARGET_DIR/$(basename -- "$TARGET")"
if [ "$MODE" = apply ]; then
  case "$TARGET_ABS" in
    "$REPO_ROOT"/.github/workflows/*)
      if [ "${PLANGATE_APPLY_CONFIRM:-0}" != "1" ]; then
        printf 'error: %s は Hardening Override パスです。\n' "$TARGET_ABS" >&2
        printf '       AI はここへ --apply しません（docs/ai/ho-change-workflow.md）。\n' >&2
        printf '       Human が適用する場合のみ: PLANGATE_APPLY_CONFIRM=1 sh %s --apply\n' "$0" >&2
        printf '       何も書き込んでいません。\n' >&2
        exit 1
      fi
      ;;
  esac
fi

MODE="$MODE" TARGET="$TARGET" REPO_ROOT="$REPO_ROOT" python3 - <<'PYEOF'
import difflib
import os
import sys

mode = os.environ["MODE"]
target = os.environ["TARGET"]
repo_root = os.environ["REPO_ROOT"]

CHECKOUT = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"
# actionlint は runner にプリインストールされていないため、バージョンと sha256 を
# 固定してリリース tarball を取得する（第三者 action を増やさず監査可能にする）。
ACTIONLINT_VERSION = "1.7.12"
ACTIONLINT_SHA256 = "8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"

MARKER = "  shell-lint:"
ANCHOR = "  markdown:\n    name: Markdown lint\n"


def fail(msg):
    sys.stderr.write("error: %s\n" % msg)
    sys.exit(1)


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


JOBS = """  shell-lint:
    name: shellcheck (shell static analysis)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: %(checkout)s
        with:
          persist-credentials: false

      - name: shellcheck version
        run: shellcheck --version

      - name: Shell lint gate (severity=error)
        run: sh scripts/lint-shell.sh --require-tool

      - name: Shell lint advisory (severity=warning, non-gating)
        run: sh scripts/lint-shell.sh --advisory --require-tool

  workflow-lint:
    name: actionlint (workflow static analysis)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    env:
      ACTIONLINT_VERSION: "%(alv)s"
      ACTIONLINT_SHA256: "%(alsha)s"
    steps:
      - name: Checkout
        uses: %(checkout)s
        with:
          persist-credentials: false

      - name: Install actionlint (pinned version + sha256 verified)
        run: |
          set -eu
          url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
          curl -fsSL -o "${RUNNER_TEMP}/actionlint.tar.gz" "$url"
          printf '%%s  %%s\\n' "$ACTIONLINT_SHA256" "${RUNNER_TEMP}/actionlint.tar.gz" | sha256sum -c -
          tar -xzf "${RUNNER_TEMP}/actionlint.tar.gz" -C "${RUNNER_TEMP}" actionlint
          sudo install -m 0755 "${RUNNER_TEMP}/actionlint" /usr/local/bin/actionlint
          actionlint -version

      - name: Workflow lint gate
        run: sh scripts/lint-workflows.sh --require-tool

""" % {"checkout": CHECKOUT, "alv": ACTIONLINT_VERSION, "alsha": ACTIONLINT_SHA256}

before = read(target)

if MARKER in before:
    print("[apply-ci-lint-wiring] already applied - nothing to do (idempotent)")
    sys.exit(0)

if before.count(ANCHOR) != 1:
    fail(
        "anchor not found (or ambiguous) in %s: expected exactly 1 occurrence of the "
        "markdown job header, found %d" % (target, before.count(ANCHOR))
    )

after = before.replace(ANCHOR, JOBS + ANCHOR, 1)

print("[apply-ci-lint-wiring] mode=%s target=%s" % (mode, target))
print("  add job shell-lint    : WILL CHANGE")
print("  add job workflow-lint : WILL CHANGE")

if mode == "dry-run":
    print("")
    show_diff(target, before, after)
    print("")
    print("[apply-ci-lint-wiring] dry-run - nothing written. Apply with --apply (Human-owned)")
    sys.exit(0)

atomic_write(target, after)
print("  applied: %s" % target)
print("[apply-ci-lint-wiring] done. Next:")
print("  sh scripts/lint-workflows.sh   # the edited ci.yml must still pass actionlint")
print("  sh tests/run-tests.sh")
PYEOF
