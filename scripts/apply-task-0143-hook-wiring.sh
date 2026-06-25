#!/bin/sh
# scripts/apply-task-0143-hook-wiring.sh
# TASK-0143 / EPIC #527 子1 — hook 物理配線 6/12→12/12（増分1: 群A = EH-4/5/7）
#
#   群A（フェーズ呼出型）EH-4 / EH-5 / EH-7 を workflow-conductor のフェーズゲート
#   契約として明文配線し、hook-enforcement.md 配線表を更新する。
#
#   群B（EHS-1/2/3, validation_bias:strict 発火型）は increment2 で別 apply-script
#   として配線する（C-3 確定: conductor 単一判定層）。本スクリプトは群A限定。
#
# Human が実行する（HO パス .claude/agents/ ・ docs/ai/ を変更するため）。
#
# 使い方:
#   sh scripts/apply-task-0143-hook-wiring.sh --dry-run  # 差分確認のみ
#   sh scripts/apply-task-0143-hook-wiring.sh            # 実際に適用

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

printf '=== apply-task-0143-hook-wiring.sh (dry_run=%s) — 群A EH-4/5/7 ===\n' "$DRY_RUN"

python3 - "$REPO_ROOT" "$DRY_RUN" << 'PYEOF'
import sys, os

repo_root = sys.argv[1]
dry_run = sys.argv[2] == "1"

CONDUCTOR = ".claude/agents/workflow-conductor.md"
ENFORCE = "docs/ai/hook-enforcement.md"

# --- 1. workflow-conductor.md: Phase-Gate Hook 配線契約セクションを追記 ---
CONDUCTOR_SECTION = """

## Phase-Gate Hook 配線契約（TASK-0143 / #527 群A）

conductor は以下の CLI 型 hook（EH-4/5/7）を各フェーズ遷移の**前**に決定論的に呼び出す。
PreToolUse hook（EH-1/2/3/6/9）と異なり settings.json には載らず、conductor が発火経路となる。

| フェーズ遷移 | 呼出 hook | 呼出タイミング | 既定挙動 |
|-------------|-----------|--------------|---------|
| → V-1（受け入れ検査） | `scripts/hooks/check-test-cases.sh $TASK` | acceptance-tester 起動前 | default=warning / strict 時 block |
| → PR 作成 | `scripts/hooks/check-verification-evidence.sh $TASK` | PR 作成サブエージェント起動前 | default=warning / strict 時 block |
| → マージ | `scripts/hooks/check-merge-approvals.sh $TASK` | C-4 マージ実行前 | default=warning / strict 時 block |

- いずれも非ゼロ exit（strict 時）で当該フェーズ遷移を停止し、不足成果物をユーザーに通知する。
- `PLANGATE_BYPASS_HOOK=1` で緊急 bypass（監査ログに記録）。
- 群B（EHS-1/2/3）は `validation_bias: strict` プロファイル時のみ本 conductor が追加発火する（increment2 で配線）。
"""

conductor_path = os.path.join(repo_root, CONDUCTOR)
with open(conductor_path) as f:
    conductor = f.read()

if "Phase-Gate Hook 配線契約（TASK-0143" in conductor:
    print(f"[skip] {CONDUCTOR} は既に配線済み")
else:
    new_conductor = conductor.rstrip() + "\n" + CONDUCTOR_SECTION
    if dry_run:
        print(f"--- {CONDUCTOR} (append {len(CONDUCTOR_SECTION.splitlines())} lines) ---")
        print(CONDUCTOR_SECTION)
    else:
        with open(conductor_path, "w") as f:
            f.write(new_conductor)
        print(f"[applied] {CONDUCTOR} にフェーズゲート配線契約を追記")

# --- 2. hook-enforcement.md: 配線状態表の群A行を「配線済み」へ更新 ---
enforce_path = os.path.join(repo_root, ENFORCE)
with open(enforce_path) as f:
    enforce = f.read()

OLD = "> | ⏳ 実装済み・未配線（6） | EH-4 / EH-5 / EH-7 | 発火経路なし（#500 で配線予定） |"
NEW = "> | ✅ 配線済み（群A / TASK-0143） | EH-4 / EH-5 / EH-7 | workflow-conductor Phase-Gate（V-1前 / PR前 / merge前） |\n> | ⏳ 実装済み・未配線（3） | EHS-1 / EHS-2 / EHS-3 | validation_bias:strict 発火層（increment2 で配線予定） |"

if OLD in enforce:
    if dry_run:
        print(f"--- {ENFORCE} 配線表更新 ---")
        print("OLD:", OLD)
        print("NEW:", NEW)
    else:
        enforce = enforce.replace(OLD, NEW)
        with open(enforce_path, "w") as f:
            f.write(enforce)
        print(f"[applied] {ENFORCE} 配線表を群A配線済みへ更新（残 EHS 3本）")
else:
    print(f"[skip] {ENFORCE} 配線表の対象行が見つからない（手動確認要）")

print("=== 群A 配線完了。次: sh tests/run-tests.sh で ta-06 群A配線 assert を検証 ===")
PYEOF
