#!/bin/sh
# apply-conductor-dynamic-phase.sh — workflow-conductor.md に「plan 再実行ガード」を
# 動的フェーズ表示で追加する（issue #676）。
#
# 背景: Growth-Teams-Agent リポジトリの PR #247 レビュー中、River Review が
# 「plan 再実行ガードのメッセージが『C-2 review 実行中』にハードコードされており、
# D/V-1 など他フェーズ実行中に誤った状況説明を出す」問題を指摘した。plangate は
# プラグイン配布のため利用側リポジトリから直接修正しない方針であり、本 issue で
# plangate 側に正しい実装（status.md の `## Current Phase` を動的参照）を導入する。
# ハードコード版は plangate には一度も存在しないため、本スクリプトは
# 「ハードコード文字列の置換」ではなく「動的参照版セクションの新規挿入」を行う。
#
# 対象は HO（Hardening Override）パス（.claude/agents/*.md）のため、
# **AI はこのスクリプトの作成と --dry-run 実行までしか行わない。
# --apply（実適用）は Human が実行する**（.claude/rules/mode-classification.md
# 承認境界周辺の変更、.claude/rules/responsibility-classes.md 責務4分類 参照）。
#
# plugin/plangate/agents/workflow-conductor.md は本来 CI（sync-plugin-plangate.sh）が
# .claude/agents/ から自動同期するが、両ファイルの drift を避けるため本スクリプトは
# 両方に同一の挿入を行う（--apply 後は sh scripts/sync-plugin-plangate.sh --dry-run で
# 差分がないことを確認することを推奨）。
#
# 使い方: sh scripts/apply-conductor-dynamic-phase.sh [--dry-run|--apply]

set -eu
MODE="${1:---dry-run}"
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

FILES="$ROOT/.claude/agents/workflow-conductor.md $ROOT/plugin/plangate/agents/workflow-conductor.md"

MARKER='#### plan 再実行ガード（ScheduleWakeup ポーリング中の誤再投入防止）'

_label_for() {
  case "$1" in
    *".claude/agents/workflow-conductor.md") echo ".claude/agents/workflow-conductor.md" ;;
    *) echo "plugin/plangate/agents/workflow-conductor.md" ;;
  esac
}

_dry_run_file() {
  _f="$1"
  _label="$(_label_for "$_f")"
  if [ ! -f "$_f" ]; then
    echo "ERROR: ファイルが見つかりません: $_label" >&2
    return 1
  fi
  if grep -qF "$MARKER" "$_f"; then
    echo "SKIP (already applied): $_label"
    return 0
  fi
  _preview="$(python3 - "$_f" <<'PY'
import sys
f = sys.argv[1]
anchor = '''   - REJECT → planからやり直し（稀）
```

### 役割2: 並列タスク実行判断'''
with open(f, encoding="utf-8") as fp:
    s = fp.read()
if s.count(anchor) != 1:
    print("ANCHOR_NOT_FOUND")
    sys.exit(1)
print("ANCHOR_OK")
PY
)" || { echo "ERROR: アンカーが見つかりません（想定外の既存内容の可能性）: $_label" >&2; return 1; }
  echo "[dry-run] $_label: $_preview"
  echo "--- 挿入前後の差分（アンカー直後に挿入） ---"
  echo "- ### 役割2: 並列タスク実行判断"
  echo "+ #### plan 再実行ガード（ScheduleWakeup ポーリング中の誤再投入防止）"
  echo "+ ... (dynamic phase guard text) ..."
  echo "+ ### 役割2: 並列タスク実行判断"
  echo "----------------------------------------------"
  return 0
}

_apply_file() {
  _f="$1"
  _label="$(_label_for "$_f")"
  if [ ! -f "$_f" ]; then
    echo "ERROR: ファイルが見つかりません: $_label" >&2
    return 1
  fi
  if grep -qF "$MARKER" "$_f"; then
    echo "SKIP (already applied): $_label"
    return 0
  fi
  python3 - "$_f" <<'PY'
import sys
f = sys.argv[1]
anchor = '''   - REJECT → planからやり直し（稀）
```

### 役割2: 並列タスク実行判断'''
insert = '''   - REJECT → planからやり直し（稀）
```

#### plan 再実行ガード（ScheduleWakeup ポーリング中の誤再投入防止）

C-2 以降のフェーズ（D / L-0 / V-1〜V-4 / PR作成 / C-4 のいずれかを実行中を含む）で
`/ai-dev-workflow plan` が再度呼び出された場合、plan.md / todo.md を上書きしない。
フェーズ名をハードコードせず、`status.md` から動的に取得する（issue #676）。

```text
1. status.md の `## Current Phase` を確認する
2. plan フェーズ完了済み（C-2 以降のフェーズが記録されている）場合:
   a. status.md から現在フェーズ名を取得する
      - 取得不能（該当セクションなし等）の場合は「バックグラウンド処理」を用いる
   b. status.md 自体が存在しない場合も同様に「バックグラウンド処理」をフォールバックとして用いる
   c. 以下のメッセージを出力し、plan.md / todo.md を上書きしない:

      plan フェーズは完了済みです。
      現在 {status.md の Current Phase} をバックグラウンドで実行中です。
      完了後、自動で次のゲートへ進みます。しばらくお待ちください。
```

### 役割2: 並列タスク実行判断'''
with open(f, encoding="utf-8") as fp:
    s = fp.read()
assert s.count(anchor) == 1, f"anchor occurrence != 1 in {f}"
s = s.replace(anchor, insert, 1)
with open(f, "w", encoding="utf-8") as fp:
    fp.write(s)
PY
  echo "APPLIED: $_label"
  return 0
}

case "$MODE" in
  --dry-run)
    _status=0
    for _f in $FILES; do
      _dry_run_file "$_f" || _status=1
    done
    echo "---"
    echo "NOTE: .claude/agents/*.md は HO 対象のため --apply は Human が実行してください。"
    exit "$_status"
    ;;
  --apply)
    echo "警告: このコマンドは HO 対象ファイル（.claude/agents/workflow-conductor.md）を" >&2
    echo "直接書き換えます。AI は本モードを実行してはいけません。Human が実行してください。" >&2
    for _f in $FILES; do
      _apply_file "$_f"
    done
    echo "適用完了。sh scripts/sync-plugin-plangate.sh --dry-run で plugin 側の drift がないことを確認してください。"
    ;;
  *)
    echo "usage: $0 [--dry-run|--apply]"
    exit 1
    ;;
esac
