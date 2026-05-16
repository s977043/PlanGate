---
task_id: TASK-0072
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0072

## 受入基準 → TC

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2, TC-3 |
| AC-3 | TC-4 |
| AC-4 | TC-5 |
| AC-5 | TC-6 |
| AC-6 | TC-7 |
| AC-7 | TC-8 |

## テストケース

- **TC-1**: exec 系定義に「委譲ケイパビリティ判定」明示ステップが存在（grep/構造検証）
- **TC-2**: 委譲不可シナリオで定義をトレースし、直接実行フォールバックが人間介入なしで到達することを確認（文書シナリオ検証）
- **TC-3**: フォールバック経路が「既定の正規フロー」として記述（“最適化”でなく既定）
- **TC-4**: 全 exec 系定義から「conductor 委譲が前提」表現が消えていること（grep で 0 件）
- **TC-5**: core-contract に「exec は任意環境で完遂可能」不変条件 + 「2段委譲必須定義禁止」が存在
- **TC-6**: error taxonomy に `delegation_unavailable` と recovery=「直接実行へ自動降格（人間不要）」が定義
- **TC-7**: workflow-conductor agent 定義に「環境制約時の降格は原則不変・委譲不能時のみ」が整合記述
- **TC-8**: 既存ドキュメント整合性チェック + hook テスト 60 件が全 green（回帰なし）

## エッジケース

- E1: ケイパビリティ判定自体が失敗 → 安全側（直接実行）へ倒す記述があること
- E2: 委譲可能環境では従来どおり conductor 委譲が選択される（後方互換）
- E3: conductor の Iron Law は委譲可能環境では不変（降格は委譲不能時限定）
- E4: critical インシデント時の緊急例外（core-contract の既存例外条項）と矛盾しない
