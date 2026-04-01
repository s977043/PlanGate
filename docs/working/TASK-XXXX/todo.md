# TASK-XXXX EXECUTION TODO

> 生成日: YYYY-MM-DD

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定する [Owner: agent]
  - files: []
  - depends_on: []
- [ ] 🚩 T-2: 既存コード/仕様を探索し、変更点候補を列挙する [Owner: agent]
  - files: []
  - depends_on: []
- [ ] 🚩 T-3: 実装方針を決定し、Planとの差分がないことを確認する [Owner: agent]
  - files: []
  - depends_on: []

### 実装フェーズ

- [ ] 🚩 T-4: {タスク内容} [Owner: agent]
  - files: [{変更対象ファイルパス}]
  - depends_on: [T-3]

### セルフレビュー①（実装直後）

- [ ] 🚩 T-5: `/self-review`を実行し、ロジック正確性・データフロー・残骸・エッジケースを確認する [Owner: agent]
  - files: []
  - depends_on: [T-4]
- [ ] 🚩 T-6: 指摘事項があれば実装フェーズに戻って修正する [Owner: agent]
  - files: []
  - depends_on: [T-5]

### 検証フェーズ

- [ ] 🚩 T-7: テスト追加/更新 [Owner: agent]
  - files: [{テストファイルパス}]
  - depends_on: [T-6]
- [ ] 🚩 T-8: typecheck/lint/test実行 [Owner: agent]
  - files: []
  - depends_on: [T-7]
- [ ] 🚩 T-9: 受入基準の全確認 [Owner: agent]
  - files: []
  - depends_on: [T-8]

### E2E検証

- [ ] 🚩 T-10: E2E検証（プロジェクトの検証手段に応じて実施） [Owner: agent]
  - files: []
  - depends_on: [T-9]
- [ ] 🚩 T-11: 受入基準に定義された動作が正しく機能することを確認する [Owner: agent]
  - files: []
  - depends_on: [T-10]

### セルフレビュー②（検証後）

- [ ] 🚩 T-12: `/self-review`を再実行し、CI互換性・コミット衛生・テスト網羅性を最終確認する [Owner: agent]
  - files: []
  - depends_on: [T-11]
- [ ] 🚩 T-13: 指摘事項があれば修正する [Owner: agent]
  - files: []
  - depends_on: [T-12]

### コードレビュー

- [ ] 🚩 T-14: 利用可能なサブエージェントで複数観点のコードレビューを実施する [Owner: agent]
  - files: []
  - depends_on: [T-13]
- [ ] 🚩 T-15: 指摘事項があれば修正する [Owner: agent]
  - files: []
  - depends_on: [T-14]

### 完了フェーズ

- [ ] 🚩 T-16: コミット作成 [Owner: agent]
  - files: []
  - depends_on: [T-15]
- [ ] 🚩 T-17: 未解決Unknownsが0か確認 [Owner: agent]
  - files: []
  - depends_on: [T-16]
- [ ] 🚩 T-18: status.mdを最終更新 [Owner: agent]
  - files: [docs/working/TASK-XXXX/status.md]
  - depends_on: [T-17]
- [ ] 🚩 T-19: todo.mdの全タスクが完了していること [Owner: agent]
  - files: [docs/working/TASK-XXXX/todo.md]
  - depends_on: [T-18]

> 注: L-0〜V-4, PR作成はworkflow-conductorが自動制御するため、todo.mdには含めない。

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Casesの人間レビュー（exec前ゲート） [Owner: human]
- [ ] C-4: PRレビュー・承認（GitHub上） [Owner: human]

## ⚠️ 依存関係
