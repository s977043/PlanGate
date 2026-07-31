#!/bin/sh
# apply-claude-md-v8180.sh -- CLAUDE.md「最新リリース」節を v8.18.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.18.0（実 PR 収束の一気通貫 — delivery 判定エンジン + Collector /
# Executor / Reconciler + Plan-first C-3' 束縛）のリリースに伴う
# 「最新リリース」節の同期。
#
# Usage:
#   sh scripts/apply-claude-md-v8180.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8180.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }

OLD_HEAD="## v8.17.1 ai-loop 最新の Plugin 配布反映（最新リリース機能）"
NEW_HEAD="## v8.18.0 実 PR 収束（MERGE_READY）の一気通貫（最新リリース機能）"
NEW_BODY="> 最新リリース: **v8.18.0**（2026-07-31）v8.17.1 タグ以降に main へ蓄積した 46 マージ（+49k 行）を反映。主要変更: MERGE_READY 状態機械 \`delivery.py\`＝決定論判定エンジン（#873/#905）・**実 PR 収束＝GitHub Collector / Action Executor / Reconciler + 実行境界検査器 + gh/git 実行ラッパ（allowlist 方式）**（#917/#941・実 PR 1 周の実走証跡付き）・c3-prime 受理器 + Plan-first 束縛（#872/#889/#895）・rollout-policy §2 本体拡張 + 判定基盤 carve-out（#907/#912）・mass-delete guard の fail-closed 化（#877/#915）。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。v8.17.x で ai-loop Phase 1 移行 + 計測基盤、v8.16.0 で ai-loop 初実運用 + plugin 同梱。リリース履歴の正本は [\`CHANGELOG.md\`](CHANGELOG.md)。"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
grep -qF "$OLD_HEAD" "$F" || { echo "SKIP: 旧見出しが見つからない（適用済み or 形式変更）" >&2; exit 1; }

export OLD_HEAD NEW_HEAD NEW_BODY F
python3 - <<'PY'
import os, re, sys
f = os.environ['F']
s = open(f, encoding='utf-8').read()
old_head = os.environ['OLD_HEAD']; new_head = os.environ['NEW_HEAD']; new_body = os.environ['NEW_BODY']
# 旧節 = 旧見出し行 + 直後の「> 最新リリース:」段落（次の空行まで）を置換
pat = re.compile(re.escape(old_head) + r"\n\n> 最新リリース:[^\n]*\n")
m = pat.search(s)
if not m:
    print("SKIP: 旧本文パターン不一致", file=sys.stderr); sys.exit(1)
new = new_head + "\n\n" + new_body + "\n"
out = s[:m.start()] + new + s[m.end():]
mode = sys.argv[1] if len(sys.argv) > 1 else '--dry-run'
open('/tmp/claude-md-v8180.new', 'w', encoding='utf-8').write(out)
print("--- 置換プレビュー（新見出し + 本文先頭 200 字）---")
print(new[:260])
PY

case "$1" in
  --dry-run)
    echo "[dry-run] 書込なし。差分:"
    diff -u "$F" /tmp/claude-md-v8180.new | head -30 || true
    ;;
  --apply)
    cp /tmp/claude-md-v8180.new "$F"
    echo "[apply] CLAUDE.md を更新しました（Human 実行前提）"
    ;;
  *) echo "usage: $0 --dry-run|--apply" >&2; exit 1 ;;
esac
