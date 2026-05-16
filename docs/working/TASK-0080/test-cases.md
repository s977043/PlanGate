---
task_id: TASK-0080
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0080

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3,TC-4 |
| AC-4 | TC-5 |
| AC-5 | TC-6 |
| AC-6 | TC-7 |
| AC-7 | TC-8 |

## テストケース
- **TC-1**: settings 期待 wiring 正本が docs/ai/ に存在し、必要 wiring（例: check-plan-hash の PLANGATE_HOOK_FILE 等）を定義
- **TC-2**: 適用 script を実行すると settings に wiring が冪等適用される（複数回安全）
- **TC-3**: wiring 適用済み環境で `bin/plangate doctor --check-settings` → exit 0 / PASS
- **TC-4**: wiring 未適用環境で `doctor --check-settings` → 非0 / 未適用箇所を明示
- **TC-5**: doctor --check-settings 未PASS の状態で handoff/V-1 完了を試行 → タスクロックでブロック（理由明示）
- **TC-6**: CI settings drift check が required で、wiring 未適用 PR を fail させる
- **TC-7**: 既存 `bin/plangate doctor`（12項目）・hook テスト 78/0 が不変（非破壊）
- **TC-8**: TASK-0071 INDEX/handoff が S1+S2 完了・S3/S4 残に更新

## エッジケース
- E1: settings ファイル不在/壊れ JSON → doctor は安全側 FAIL（fail-closed）
- E2: PLANGATE_BYPASS_HOOK との整合（既存 hook 慣行：bypass はロックも解除可だが監査記録）
- E3: 適用済みで誤検出ゼロ（AC-6 最重要・正常完了を阻害しない）
- E4: S3/S4 未実装でも S1+S2 単独で機能（スライス独立性）
