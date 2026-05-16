---
task_id: TASK-0076
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0076

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5 |
| AC-6 | TC-6 |
| AC-7 | TC-7 |
| AC-8 | TC-8 |

## テストケース
- **TC-1**: C-2 責務正本に「設計妥当性」「コードベース整合」2 レーンが定義
- **TC-2**: 設計妥当性=実コード読まない / コードベース整合=1エージェント集約 / 実装詳細=V-3 が明文
- **TC-3**: review-principles の 5 観点・Severity・承認境界が**不変**（diff で変更なし）
- **TC-4**: C-2 指摘を review-external.md 追記専用に集約する運用が定義
- **TC-5**: 計画本体は exec 開始時に 1 回だけ確定反映する運用が定義（plan_hash/EH-3 整合）
- **TC-6**: 「指摘ID→反映コミット」差分追跡 + #200/#230 接続点が定義
- **TC-7**: working-context / 該当 workflow に C 反映フローが反映
- **TC-8**: 既存 hook テスト全 green + doc 整合性回帰なし

## エッジケース
- E1: C-2 でスコープ/受入基準の重大欠落 → 設計妥当性レーンが必ず捕捉（観点は減らさない）
- E2: CONDITIONAL 指摘の反映 → exec 開始時 1 回確定に含め plan_hash 再計算と整合
- E3: 指摘ゼロ → review-external.md は「指摘なし」明示で監査連続性維持
