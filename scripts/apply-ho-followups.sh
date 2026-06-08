#!/bin/sh
# apply-ho-followups.sh — HO 待ち 4 issue (#451/#454/#463/#452) の Human 適用スクリプト
#
# 責務4分類: AI が本スクリプトを作成し、実行は Human が行う（HO パスへの適用は
# Human-owned）。本スクリプトは bin/plangate / AGENTS.md / .claude/ 配下の
# Hardening Override 対象を編集するため、AI（Claude/Codex）は実行してはならない。
#
# 各変更は冪等（既適用なら skip）。--dry-run で差分のみ表示し書き込まない。
#
# Usage:
#   sh scripts/apply-ho-followups.sh --dry-run   # 差分確認（書き込みなし）
#   sh scripts/apply-ho-followups.sh             # 適用
#
# 適用後は以下で検証:
#   sh scripts/check-committed-memory-pollution.sh   # #452: 汚染除去確認
#   sh tests/run-tests.sh                            # 全体回帰
#   git diff                                         # 変更内容確認

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
command -v python3 >/dev/null 2>&1 || { printf 'python3 required\n' >&2; exit 1; }

# edit_file <relpath> : stdin の python が new content を stdout に出す（冪等）。
# DRY なら diff、そうでなければ書き込む。変更なしなら "unchanged"。
edit_file() {
  _f="$ROOT/$1"
  if [ ! -f "$_f" ]; then printf '  [SKIP] %s が存在しません\n' "$1"; return 0; fi
  # コマンド置換は末尾改行を削るため一時ファイル経由で比較・更新する。
  # 上書きは cat > で行い、既存ファイルのパーミッション（bin/plangate の実行権限
  # 等）と末尾改行を保持する（mv だと mktemp の 0600 で上書きされる）。
  _tmp=$(mktemp)
  if python3 - "$_f" > "$_tmp"; then
    if cmp -s "$_f" "$_tmp"; then
      printf '  [skip] %s（既適用 or 変更なし）\n' "$1"
    elif [ "$DRY" = "1" ]; then
      printf '  [dry-run] %s の差分:\n' "$1"
      diff -u "$_f" "$_tmp" | sed 's/^/    /' || true
    else
      cat "$_tmp" > "$_f"
      printf '  [applied] %s\n' "$1"
    fi
  fi
  rm -f "$_tmp"
}

printf '=== #452: AGENTS.md から claude-mem-context 汚染ブロック除去 ===\n'
edit_file AGENTS.md <<'PY452'
import sys, re
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
s2 = re.sub(r'\n*<claude-mem-context>.*?</claude-mem-context>\n?', '\n', s, flags=re.DOTALL)
sys.stdout.write(s2)
PY452

printf '=== #451: bin/plangate doctor に Codex Plugin (non-fatal) セクションを配線 ===\n'
edit_file bin/plangate <<'PY451'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
if 'check-codex-plugin-status.sh' in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "  printf '=== Required Workflow Files ===\\n'"
block = (
    "  printf '=== Codex Plugin (non-fatal) ===\\n'\n"
    "  if [ -f \"$plangate_root/scripts/check-codex-plugin-status.sh\" ]; then\n"
    "    sh \"$plangate_root/scripts/check-codex-plugin-status.sh\" || true\n"
    "  else\n"
    "    printf '  [INFO] scripts/check-codex-plugin-status.sh not found\\n'\n"
    "  fi\n"
    "  printf '\\n'\n\n"
)
if anchor in s:
    s = s.replace(anchor, block + anchor, 1)
sys.stdout.write(s)
PY451

printf '=== #454a: .claude/commands/plangate-setup.md に前提条件を追記 ===\n'
edit_file .claude/commands/plangate-setup.md <<'PY454A'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
if '## 前提条件' in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "## 引数"
note = (
    "## 前提条件\n\n"
    "`bin/plangate` CLI が必要です。Plugin 単体導入では PATH に含まれないため、"
    "未導入の場合は先に PlanGate リポジトリを clone してください:\n\n"
    "    git clone https://github.com/s977043/plangate.git ~/plangate\n"
    "    export PATH=\"$HOME/plangate/bin:$PATH\"\n\n"
)
if anchor in s:
    s = s.replace(anchor, note + anchor, 1)
sys.stdout.write(s)
PY454A

printf '=== #454b: .claude/agents/setup-coordinator.md に bin/plangate 不在フォールバックを追記 ===\n'
edit_file .claude/agents/setup-coordinator.md <<'PY454B'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
if 'bin/plangate 不在時のフォールバック' in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "## 対話フロー"
note = (
    "## bin/plangate 不在時のフォールバック\n\n"
    "`bin/plangate doctor --json` を実行する前に `command -v bin/plangate` で存在確認する。"
    "不在の場合は doctor をスキップし、PlanGate フルリポジトリの clone が必要である旨と "
    "clone コマンド（`git clone https://github.com/s977043/plangate.git`）を案内して停止する"
    "（command not found でユーザーを放置しない）。\n\n"
)
if anchor in s:
    s = s.replace(anchor, note + anchor, 1)
sys.stdout.write(s)
PY454B

printf '=== #463a: .claude/rules/working-context.md に status 日時必須を追記 ===\n'
edit_file .claude/rules/working-context.md <<'PY463A'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
if 'YYYY-MM-DD HH:mm`（分まで）必須' in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "### status.md（作業ステータス）\n"
note = (
    anchor +
    "\n> **フェーズ履歴の日時は `YYYY-MM-DD HH:mm`（分まで）必須**（#463、テンプレート "
    "`docs/working/templates/status.md` 準拠）。日付のみ・時刻欠落は不可。セッション跨ぎ・"
    "同日複数フェーズ遷移の順序を一意に追跡できるようにする。\n"
)
if anchor in s:
    s = s.replace(anchor, note, 1)
sys.stdout.write(s)
PY463A

printf '=== #463b: .claude/rules/review-principles.md に外部レビュー実行不可記録の参照を追記 ===\n'
edit_file .claude/rules/review-principles.md <<'PY463B'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
if '7-ter' in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "## 8. レビューの優先順位"
note = (
    "## 7-ter. 外部レビュー実行不可時の記録（#463）\n\n"
    "C-2 / V-3 の外部 AI レビューが**実行不可**（CLI 未導入・API 不達・quota 超過等）の"
    "場合の記録規約は [`docs/ai/external-reviewer-interface.md`](../../docs/ai/external-reviewer-interface.md) "
    "§10 を正本とする。「指摘なし」と「実行不可」を区別し、`unavailable` は理由・代替観点・"
    "未充足リスクを必須記録（`verdict` は WARN、空欄は FAIL）。\n\n"
)
if anchor in s:
    s = s.replace(anchor, note + anchor, 1)
sys.stdout.write(s)
PY463B

printf '=== #463c: .claude/agents/workflow-conductor.md に Codex runtime conductor 運用の参照を追記 ===\n'
edit_file .claude/agents/workflow-conductor.md <<'PY463C'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
if 'workflow_conductor.toml' in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "## 関連資産"
note = (
    anchor + "\n\n- Codex runtime での conductor 相当運用: "
    "[`.codex/agents/workflow_conductor.toml`](../../.codex/agents/workflow_conductor.toml)"
    "（Claude Code 以外の runtime では Task ツール非対応のため別エージェント起動不可。"
    "本 conductor 指示を司令塔ロールとして読み込み、フェーズ遷移を代行する）"
)
if anchor in s:
    s = s.replace(anchor, note, 1)
sys.stdout.write(s)
PY463C

printf '=== Phase3: ci.yml の markdownlint glob を docs/pages/ 新パスへ更新（#488）===\n'
printf '    前提: PR #488 マージ後に実行（philosophy/oss-governance が docs/pages/ へ移動済みであること）\n'
edit_file .github/workflows/ci.yml <<'PYCI'
import sys, re
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
# インデント幅・改行コードに依存しない行単位置換。glob 行が見つからない場合は
# 黙ってスキップせず WARN を出す（ci.yml フォーマット変更時の適用漏れを検出）。
for oldp, newp in [
    ('docs/philosophy.md', 'docs/pages/explanation/product/philosophy.md'),
    ('docs/oss-governance.md', 'docs/pages/guides/governance/oss-governance.md'),
]:
    if newp in s:
        continue  # 既適用（冪等）
    pat = re.compile(r'^([ \t]*)' + re.escape(oldp) + r'[ \t]*$', re.M)
    if not pat.search(s):
        sys.stderr.write('WARN: %s の glob 行が見つかりません（既適用 or ci.yml フォーマット変更）\n' % oldp)
        continue
    s = pat.sub(lambda m: m.group(1) + newp, s)
sys.stdout.write(s)
PYCI

printf '\n'
if [ "$DRY" = "1" ]; then
  printf '=== --dry-run 完了。書き込みは行っていません。 ===\n'
  printf '適用するには: sh scripts/apply-ho-followups.sh\n'
else
  printf '=== 適用完了。検証してください: ===\n'
  printf '  sh scripts/check-committed-memory-pollution.sh   # #452 汚染除去確認\n'
  printf '  sh tests/run-tests.sh                            # 全体回帰\n'
  printf '  sh scripts/sync-plugin-plangate.sh               # plugin 側へ反映（#454/#463）\n'
  printf '  git diff                                         # 変更確認\n'
fi
