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
#   **作成と --dry-run のみ**。`--apply` の実行は **Human-owned**。
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
#   sh scripts/apply-ci-lint-wiring.sh --apply      # 実適用（Human-owned）
#   sh scripts/apply-ci-lint-wiring.sh --target FILE  # 適用先の上書き（sandbox 検証用）
#
#   注記: --target は「実 ci.yml を触らずに適用結果を検証する」ための seam。
#         AI は --apply を実行しない（--target 付きであっても同じ）。
#
# Exit codes:
#   0 = 成功（適用 / dry-run / 既適用 skip）
#   1 = 引数エラー / アンカー未検出 / 対象ファイル不在（＝何も書き込まない）

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
