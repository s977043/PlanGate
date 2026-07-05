#!/bin/sh
# apply-subagent-delegation-wiring.sh — サブエージェント委譲プロトコル
# （docs/ai/subagent-delegation/）への参照導線を Hardening Override (HO)
# 対象ファイルへ追加する Human 適用スクリプト。
#
# 責務4分類（.claude/rules/responsibility-classes.md）: 本スクリプト自体は
# AI が作成する非HOファイルだが、書き込み対象（.claude/rules/orchestrator-mode.md
# / .claude/rules/responsibility-classes.md / CLAUDE.md / AGENTS.md）は
# Hardening Override 対象パスであり、AI は本スクリプトを --dry-run 以外で
# 実行してはならない（docs/ai/ho-change-workflow.md 標準フロー §禁止事項）。
# 実行（適用）は Human、または計画段階で明示的に y 承認を取得した AI 実行に限る。
#
# 各変更は冪等（既適用なら skip。マーカー文字列
# "docs/ai/subagent-delegation" の有無で判定）。--dry-run では書き込みを
# 行わず unified diff のみ表示する。--dry-run 以外の引数は exit 1（誤適用防止）。
# 挿入位置（アンカー）が見つからない場合も exit 1（サイレントスキップしない）。
#
# Usage:
#   sh scripts/apply-subagent-delegation-wiring.sh --dry-run   # 差分確認（書き込みなし）
#   sh scripts/apply-subagent-delegation-wiring.sh             # 適用（Human 実行のみ）
#
# 適用後は以下で検証:
#   git diff .claude/rules/orchestrator-mode.md .claude/rules/responsibility-classes.md CLAUDE.md AGENTS.md
#   npx markdownlint-cli2 .claude/rules/orchestrator-mode.md .claude/rules/responsibility-classes.md CLAUDE.md AGENTS.md
#   bin/plangate doctor

set -eu

# POSIX/C ロケール環境（CI/Docker 等でデフォルトが ASCII になるケース）でも
# python3 の stdout を UTF-8 に固定し、日本語出力による UnicodeEncodeError で
# 異常終了するのを防ぐ（C-2 Gemini high 指摘）。
export PYTHONUTF8=1

# mktemp で作った一時ファイルを、正常終了・エラー・中断（INT/TERM）いずれでも
# 確実に掃除する（C-2 Gemini medium 指摘）。生成のたび TEMP_FILES に登録する。
TEMP_FILES=""
_cleanup_tmp() { [ -n "$TEMP_FILES" ] && rm -f $TEMP_FILES || true; }
trap _cleanup_tmp EXIT INT TERM

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY=0

# --- 引数 strict 検証（--dry-run 以外は exit 1） ---
if [ "$#" -gt 1 ]; then
  printf 'ERROR: 引数は --dry-run のみ許容します（複数引数不可）\n' >&2
  exit 1
fi
if [ "$#" -eq 1 ]; then
  if [ "$1" = "--dry-run" ]; then
    DRY=1
  else
    printf 'ERROR: 不明な引数です: %s（--dry-run のみ許容）\n' "$1" >&2
    exit 1
  fi
fi

command -v python3 >/dev/null 2>&1 || { printf 'python3 required\n' >&2; exit 1; }

if [ "$DRY" = "0" ]; then
  printf '警告: 本スクリプトは Hardening Override (HO) 対象ファイルを書き換えます。\n' >&2
  printf '      AI は self-mod ガード対象のため --dry-run 以外での実行が禁止されています\n' >&2
  printf '      （docs/ai/ho-change-workflow.md）。Human による実行であることを確認してください。\n' >&2
fi

# edit_file <relpath> : stdin の python が new content を stdout に出す。
# marker が既に含まれていれば unchanged（冪等）。anchor が見つからなければ
# python 側が非 0 終了 → 本関数が ERROR を出して exit 1（アンカー検証）。
# DRY なら diff のみ表示、そうでなければ書き込む。
edit_file() {
  _f="$ROOT/$1"
  if [ ! -f "$_f" ]; then
    printf 'ERROR: %s が存在しません（対象パスを確認してください）\n' "$1" >&2
    exit 1
  fi
  _tmp=$(mktemp)
  _err=$(mktemp)
  TEMP_FILES="$TEMP_FILES $_tmp $_err"
  if python3 - "$_f" > "$_tmp" 2>"$_err"; then
    if cmp -s "$_f" "$_tmp"; then
      printf '  [skip] %s（既適用 or 変更なし）\n' "$1"
    elif [ "$DRY" = "1" ]; then
      printf '  [dry-run] %s の差分:\n' "$1"
      diff -u "$_f" "$_tmp" | sed 's/^/    /' || true
    else
      cat "$_tmp" > "$_f"
      printf '  [applied] %s\n' "$1"
    fi
  else
    printf 'ERROR: %s へのアンカー挿入に失敗しました（アンカー未検出、または想定外エラー）:\n' "$1" >&2
    sed 's/^/    /' "$_err" >&2
    rm -f "$_tmp" "$_err"
    exit 1
  fi
  rm -f "$_tmp" "$_err"
}

printf '=== #715/#710: .claude/rules/orchestrator-mode.md に既存ルールとの関係を追記 ===\n'
edit_file .claude/rules/orchestrator-mode.md <<'PYORC'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
marker = 'docs/ai/subagent-delegation'
if marker in s:
    sys.stdout.write(s)
    sys.exit(0)
anchor = (
    "| [`review-principles.md`](./review-principles.md) | "
    "レビュー判定フレームを親 / 子両方に適用 |\n"
)
if anchor not in s:
    sys.stderr.write(
        '既存ルールとの関係 table の最終行（review-principles.md 行）が'
        '見つかりません。orchestrator-mode.md のフォーマットが変更された'
        '可能性があります。\n'
    )
    sys.exit(2)
new_row = (
    "| [`docs/ai/subagent-delegation/README.md`](../../docs/ai/subagent-delegation/README.md) | "
    "サブエージェント派遣プロンプトの契約層（委譲判断基準 / OUTCOME 契約 / "
    "行動規範）を追加する。本ルールの Gate 不変条件（AS-1〜5 / "
    "`ChildExecAllowed` / `ParentDone`）とは直交し、変更しない |\n"
)
s = s.replace(anchor, anchor + new_row, 1)
sys.stdout.write(s)
PYORC

printf '=== #715/#710: .claude/rules/responsibility-classes.md に既存ルール対応を追記 ===\n'
edit_file .claude/rules/responsibility-classes.md <<'PYRESP'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
marker = 'docs/ai/subagent-delegation'
if marker in s:
    sys.stdout.write(s)
    sys.exit(0)
anchor = (
    "| [本正本 「対外公開アーティファクト publish 責務分界」節]"
    "(#対外公開アーティファクト-publish-責務分界) | tag/release publish は "
    "AI が draft/コマンド提示まで、実行は Human-owned"
    "（または計画段階で明示承認を取得した AI 実行）。issue #296 で正本化 |\n"
)
if anchor not in s:
    sys.stderr.write(
        '既存ルール対応 table の最終行（対外公開アーティファクト行）が'
        '見つかりません。responsibility-classes.md のフォーマットが'
        '変更された可能性があります。\n'
    )
    sys.exit(2)
new_row = (
    "| [`docs/ai/subagent-delegation/README.md`](../../docs/ai/subagent-delegation/README.md)"
    "（サブエージェント委譲プロトコル） | AI-owned（派遣プロンプト作成・"
    "完了結果の最低限受け入れ確認）+ Human-owned（P0 要判断事項の承認・"
    "破壊的操作の承認） |\n"
)
s = s.replace(anchor, anchor + new_row, 1)
sys.stdout.write(s)
PYRESP

printf '=== #710（任意/discoverability 補強）: CLAUDE.md に参照を追記 ===\n'
edit_file CLAUDE.md <<'PYCLAUDE'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
marker = 'docs/ai/subagent-delegation'
if marker in s:
    sys.stdout.write(s)
    sys.exit(0)
anchor = (
    "- ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) "
    "/ Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)\n"
)
if anchor not in s:
    sys.stderr.write(
        'Claude Code 固有参照 節のワークフロー詳細行が見つかりません。'
        'CLAUDE.md のフォーマットが変更された可能性があります。\n'
    )
    sys.exit(2)
new_line = (
    "- サブエージェント委譲プロトコル: "
    "[`docs/ai/subagent-delegation/README.md`](docs/ai/subagent-delegation/README.md)"
    "（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範 / PlanGateフロー接続。"
    "既存の C-3/C-4 ゲートおよび orchestrator-mode の Gate 不変条件は変更しない）\n"
)
s = s.replace(anchor, anchor + new_line, 1)
sys.stdout.write(s)
PYCLAUDE

printf '=== #710（任意/Codex parity）: AGENTS.md に参照を追記 ===\n'
edit_file AGENTS.md <<'PYAGENTS'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
marker = 'docs/ai/subagent-delegation'
if marker in s:
    sys.stdout.write(s)
    sys.exit(0)
anchor = (
    "- ワークフロー: `docs/ai-driven-development.md` / "
    "Orchestrator: `docs/orchestrator-mode.md`\n"
)
if anchor not in s:
    sys.stderr.write(
        'Codex 固有参照 節のワークフロー行が見つかりません。'
        'AGENTS.md のフォーマットが変更された可能性があります。\n'
    )
    sys.exit(2)
new_line = (
    "- サブエージェント委譲プロトコル: `docs/ai/subagent-delegation/README.md`"
    "（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範。既存の C-3/C-4 ゲート"
    "および orchestrator-mode の Gate 不変条件は変更しない）\n"
)
s = s.replace(anchor, anchor + new_line, 1)
sys.stdout.write(s)
PYAGENTS

printf '\n'
if [ "$DRY" = "1" ]; then
  printf '=== --dry-run 完了。書き込みは行っていません。 ===\n'
  printf '適用するには（Human のみ）: sh scripts/apply-subagent-delegation-wiring.sh\n'
else
  printf '=== 適用完了。検証してください: ===\n'
  printf '  git diff .claude/rules/orchestrator-mode.md .claude/rules/responsibility-classes.md CLAUDE.md AGENTS.md\n'
  printf '  npx markdownlint-cli2 .claude/rules/orchestrator-mode.md .claude/rules/responsibility-classes.md CLAUDE.md AGENTS.md\n'
  printf '  bin/plangate doctor\n'
fi
