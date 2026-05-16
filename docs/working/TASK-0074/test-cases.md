---
task_id: TASK-0074
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0074

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
- **TC-1**: `bin/plangate init TASK-XXXX` 生成 pbi-input に Design/UI Addendum が含まれ「UIのみ・非UIは削除可」と明記
- **TC-2**: Addendum 先頭が「踏襲元の明示（真似る X / 真似ない Y・理由）」＝最優先項目
- **TC-3**: 配置仕様 / レスポンシブ / 視覚受入基準 / 回帰ガード / 視覚証跡 の各フィールドが存在
- **TC-4**: spec 文書に Figma あり→Figma正 / なし→既存パターン正 / 受入証跡分岐が明記
- **TC-5**: spec に UI タスク判定トリガが定義され、非UIには Addendum 非強制と明記
- **TC-6**: 「参照なし」を明示選択するフィールド/記法が存在（曖昧進行・ゲート回避防止）
- **TC-7**: design.md テンプレに視覚設計セクションがあり Addendum 項目と整合
- **TC-8**: init の既存出力（Why/What/AC/Estimation）が壊れない + doc 整合性回帰なし

## エッジケース
- E1: 非UIタスクで Addendum を残しても害がない（削除可の明示で認知負荷最小）
- E2: Figma あり かつ 既存パターンもある → Figma を正（spec で優先順明記）
- E3: 参照一切なし → 「参照なし」明示で進むが視覚受入基準/回帰ガードは必須
