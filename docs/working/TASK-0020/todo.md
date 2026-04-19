# TASK-0020 EXECUTION TODO

> 生成日: 2026-04-19

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定 [Owner: agent]
  - files: [docs/working/TASK-0020/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: 既存 README.md 構成を調査し挿入位置を決定 [Owner: agent]
  - files: [docs/working/TASK-0020/evidence/readme-structure.md]
  - depends_on: [T-1]
- [ ] 🚩 T-2a: TASK-0017 の plugin 仕様・インストール検証成果物から install syntax を引用・固定 [Owner: agent]
  - files: [docs/working/TASK-0020/evidence/install-syntax-reference.md]
  - depends_on: [T-2]
- [ ] 🚩 T-3: TASK-0018 の `evidence/command-skill-boundary.md` を要約し migration note 素材化 [Owner: agent]
  - files: [docs/working/TASK-0020/evidence/boundary-summary.md]
  - depends_on: [T-2]
- [ ] 🚩 T-4: TASK-0019 の実装結果（汎用化された 8 agents、3 rules、bin スクリプト）を参照 [Owner: agent]
  - files: []
  - depends_on: [T-3]

### 実装フェーズ（C-3 Gate APPROVE 後のみ開始）

> ⚠️ 実装フェーズの先頭タスク T-5 は human gate **C-3** の承認を prerequisite とする。また、T-2a の install syntax 確定が全実装タスクの前提。

- [ ] 🚩 T-5: Root `README.md` に plugin 導入セクションを追加（新旧差分表、Codex CLI 対象外明記、migration note 導線、同梱範囲、未同梱 agents の理由・入手方法） [Owner: agent]
  - files: [README.md]
  - depends_on: [T-4, T-2a, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-6: `docs/plangate-plugin-migration.md` を新規作成（背景・同梱範囲・対象外理由・将来計画・移行手順） [Owner: agent]
  - files: [docs/plangate-plugin-migration.md]
  - depends_on: [T-5]
- [ ] 🚩 T-7: `plugin/plangate/README.md` のプレースホルダーを本文で置換（インストール手順は T-2a の install syntax を引用、使い方、一覧、トラブルシュート） [Owner: agent]
  - files: [plugin/plangate/README.md]
  - depends_on: [T-6, T-2a]
- [ ] 🚩 T-8: ドキュメント間の相互参照リンクを設定 [Owner: agent]
  - files: [README.md, docs/plangate-plugin-migration.md, plugin/plangate/README.md]
  - depends_on: [T-7]
- [ ] 🚩 T-8a: 手動リンク確認（Read で辿る、外部ツール非依存）、結果を `evidence/link-verification.md` に記録 [Owner: agent]
  - files: [docs/working/TASK-0020/evidence/link-verification.md]
  - depends_on: [T-8]

### セルフレビュー①（実装直後）

- [ ] 🚩 T-9: `/self-review` を実行し、記述漏れ・リンク切れ・同梱範囲の乖離を確認 [Owner: agent]
  - files: []
  - depends_on: [T-8]
- [ ] 🚩 T-10: 指摘事項があれば実装フェーズに戻って修正 [Owner: agent]
  - files: []
  - depends_on: [T-9]

### 検証フェーズ

- [ ] 🚩 T-11: Root README に plugin 導入セクション存在確認 [Owner: agent]
  - files: []
  - depends_on: [T-10]
- [ ] 🚩 T-12: `docs/plangate-plugin-migration.md` 存在と必須セクション確認 [Owner: agent]
  - files: []
  - depends_on: [T-11]
- [ ] 🚩 T-13: plugin 内 README の本文化（プレースホルダー解消）確認 [Owner: agent]
  - files: []
  - depends_on: [T-12]
- [ ] 🚩 T-14: Codex CLI 対象外の記述確認 [Owner: agent]
  - files: []
  - depends_on: [T-13]
- [ ] 🚩 T-15: 受入基準 9 項目の全確認 [Owner: agent]
  - files: []
  - depends_on: [T-14]

### E2E検証

- [ ] 🚩 T-16: 第三者目線でドキュメントを通読し、plugin 導入手順通りに実施できるか確認 [Owner: agent]
  - files: []
  - depends_on: [T-15]
- [ ] 🚩 T-17: 内部リンクの整合確認（切れが無いか） [Owner: agent]
  - files: []
  - depends_on: [T-16]

### セルフレビュー②（検証後）

- [ ] 🚩 T-18: `/self-review` を再実行し、表現の一貫性・受入条件カバレッジを最終確認 [Owner: agent]
  - files: []
  - depends_on: [T-17]
- [ ] 🚩 T-19: 指摘事項があれば修正 [Owner: agent]
  - files: []
  - depends_on: [T-18]

### コードレビュー

- [ ] 🚩 T-20: サブエージェントで複数観点レビュー実施（ドキュメント品質） [Owner: agent]
  - files: []
  - depends_on: [T-19]
- [ ] 🚩 T-21: 指摘事項があれば修正 [Owner: agent]
  - files: []
  - depends_on: [T-20]

### 完了フェーズ

- [ ] 🚩 T-22: コミット作成 [Owner: agent]
  - files: []
  - depends_on: [T-21]
- [ ] 🚩 T-23: 未解決Unknowns が 0 か確認 [Owner: agent]
  - files: []
  - depends_on: [T-22]
- [ ] 🚩 T-24: status.md を最終更新 [Owner: agent]
  - files: [docs/working/TASK-0020/status.md]
  - depends_on: [T-23]
- [ ] 🚩 T-25: todo.md の全タスク完了確認 [Owner: agent]
  - files: [docs/working/TASK-0020/todo.md]
  - depends_on: [T-24]
- [ ] 🚩 T-26: 親 #16 を Close 可能な状態であることを確認（全子 issue 完了） [Owner: agent]
  - files: []
  - depends_on: [T-25]

> 注: L-0〜V-4, PR作成は workflow-conductor が自動制御するため、todo.md には含めない。

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases の人間レビュー（exec 前ゲート） [Owner: human]
- [ ] C-4: PR レビュー・承認（GitHub 上） [Owner: human]
- [ ] 親 #16 の Close 判断 [Owner: human]

## ⚠️ 依存関係

- **前提 TASK**: TASK-0017, TASK-0018, TASK-0019 全て完了
- T-1 → T-2 → T-3 → T-4（準備フェーズは直列、実装結果参照のため）
- T-5 → T-6 → T-7（Root → migration → plugin の順で整合を取る）
- T-8 → T-9（全文書配置後にリンク設定）
- C-3 ゲート後のみ実装フェーズへ
- 本 TASK 完了で親 #16 Close 可能
