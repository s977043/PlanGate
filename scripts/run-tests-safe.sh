#!/bin/sh
# run-tests-safe.sh — tests/run-tests.sh を stdin 閉鎖 + 実行環境判定つきで起動する
# 使用: sh scripts/run-tests-safe.sh [tests/run-tests.sh へ渡す引数...]
# 例:   sh scripts/run-tests-safe.sh
#
# 目的（実測された 2 つの事故を機械的に潰す）:
#   1. `</dev/null` 忘れによる無限ハング
#      tests/extras/ta-50-precompact-guard.sh は scripts/precompact-memory-guard.sh
#      を stdin を閉じずに呼ぶ。同 hook は `_stdin=$(cat 2>/dev/null || true)` で
#      stdin を読むため、呼び出し元の stdin が開いたパイプ / tty のままだと
#      `cat` が入力待ちで止まり、テスト全体が無限ハングする。
#      本ラッパは `</dev/null` を固定し、利用者が忘れられない形にする。
#   2. PASS 件数 baseline の環境差による「達成不能な指示」
#      PASS 件数は checkout 種別（primary / git worktree）と HEAD が origin/main と
#      同一かで変わる。本ラッパは実行前に環境を判定し、**どの検査がこの環境では
#      実行されないか（＝件数がどれだけ減るか）** を理由つきで表示する。
#
# 出力規約:
#   - 診断出力はすべて stderr。stdout は tests/run-tests.sh の出力をそのまま透過する。
#   - 終了コードは tests/run-tests.sh のものをそのまま返す（exec で置換）。

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
RUNNER="$REPO_ROOT/tests/run-tests.sh"

if [ ! -f "$RUNNER" ]; then
  printf 'ERROR: test runner not found: %s\n' "$RUNNER" >&2
  exit 1
fi

log() { printf '[env] %s\n' "$*" >&2; }

# ── checkout 種別の判定 ────────────────────────────────────────────────
# git の正規判定は --git-dir と --git-common-dir の比較（worktree では前者が
# <common>/worktrees/<name> を指す）。一方 tests/extras/ta-13 の分岐条件は
# `[ -d "$ROOT/.git" ]` という**リテラルな .git の種別**なので、両方を採る。
git_dir=$(git -C "$REPO_ROOT" rev-parse --absolute-git-dir 2>/dev/null || printf '')
# --path-format は git 2.31+。使えない環境では相対パスを REPO_ROOT 基準で解決する。
git_common=$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || printf '')
if [ -z "$git_common" ] && [ -n "$git_dir" ]; then
  git_common_raw=$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null || printf '')
  if [ -n "$git_common_raw" ]; then
    # 相対パスは git を起動した REPO_ROOT 基準なので、同じ位置から解決する
    git_common=$( (CDPATH= cd -- "$REPO_ROOT" && CDPATH= cd -- "$git_common_raw" && pwd) 2>/dev/null || printf '')
  fi
fi

if [ -z "$git_dir" ]; then
  checkout_kind="not-a-git-repo"
elif [ -n "$git_common" ] && [ "$git_dir" != "$git_common" ]; then
  checkout_kind="git worktree"
else
  checkout_kind="primary checkout"
fi

if [ -d "$REPO_ROOT/.git" ]; then
  dot_git_kind="directory"
elif [ -f "$REPO_ROOT/.git" ]; then
  dot_git_kind="file (git worktree / submodule)"
else
  dot_git_kind="absent"
fi

branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '(unknown)')
head_sha=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf '')
origin_main_sha=$(git -C "$REPO_ROOT" rev-parse --verify --quiet origin/main 2>/dev/null || printf '')

if [ -n "$head_sha" ] && [ -n "$origin_main_sha" ] && [ "$head_sha" = "$origin_main_sha" ]; then
  head_vs_origin_main="同一 commit"
elif [ -z "$origin_main_sha" ]; then
  head_vs_origin_main="origin/main が無い checkout"
else
  head_vs_origin_main="異なる commit"
fi

# ── この環境で「実行されない」検査の判定 ──────────────────────────────
skipped=0

# ta-13 TC-17: `[ -d "$PG_T13_ROOT/.git" ]` が偽なら PASS を emit せず SKIP 行のみ
if [ -d "$REPO_ROOT/.git" ]; then
  t13_tc17="実行される"
else
  t13_tc17="実行されない（[SKIP] 出力のみ / PASS 加算なし）"
  skipped=$((skipped + 1))
fi

# ta-57 TC-14: origin/main → main の順に base ref を探し、HEAD と同一 commit の
# ref は「検出力ゼロ」として採用しない。base が 1 つも取れなければ WARN 経路。
t57_base=""
for ref in origin/main main; do
  ref_sha=$(git -C "$REPO_ROOT" rev-parse --verify --quiet "$ref" 2>/dev/null || printf '')
  [ -n "$ref_sha" ] || continue
  [ "$ref_sha" != "$head_sha" ] || continue
  t57_base="$ref"
  break
done
if [ -n "$t57_base" ]; then
  # 全角括弧が直後に来るため ${} で変数名の終端を明示する（bash 3.2 で
  # マルチバイト文字が識別子に取り込まれ unbound variable になる実測あり）
  t57_tc14="実行される（base=${t57_base}）"
else
  t57_tc14="実行されない（[WARN] 出力のみ / PASS 加算なし）"
  skipped=$((skipped + 1))
fi

# ── 診断出力 ──────────────────────────────────────────────────────────
log "runner        : $RUNNER (stdin は </dev/null で閉じて起動)"
log "repo root     : $REPO_ROOT"
log "checkout      : $checkout_kind  (.git = $dot_git_kind)"
log "branch        : $branch"
log "HEAD          : ${head_sha:-(none)}"
log "origin/main   : ${origin_main_sha:-(none)}  → HEAD とは $head_vs_origin_main"
log "ta-13 TC-17   : $t13_tc17"
log "ta-57 TC-14   : $t57_tc14"
log "-----------------------------------------------------------------"
if [ "$skipped" -eq 0 ]; then
  log "この環境では上記 2 検査とも実行される（PASS 件数が最も多くなる条件）。"
else
  log "この環境では上記のうち $skipped 件が実行されないため、"
  log "2 検査とも走る環境と比べて PASS 件数が $skipped 件少なくなる。"
fi
log "PASS 件数は checkout 種別（primary / worktree）と HEAD が origin/main と"
log "同一かで変わる。**同一環境・同一条件で自分が採った値とだけ比較すること**。"
log "別環境で採った件数を baseline として持ち込まない（達成不能な条件になる）。"
log "-----------------------------------------------------------------"

# tests/run-tests.sh の出力と終了コードをそのまま透過する（exec でプロセス置換）
exec sh "$RUNNER" "$@" </dev/null
