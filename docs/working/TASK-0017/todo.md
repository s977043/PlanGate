# TASK-0017 EXECUTION TODO

> 生成日: 2026-04-19

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定する [Owner: agent]
  - files: [docs/working/TASK-0017/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: Claude Code plugin 仕様を WebFetch/WebSearch で調査し、必須フィールド・エントリ形式を特定する [Owner: agent]
  - files: [docs/working/TASK-0017/evidence/plugin-spec-research.md]
  - depends_on: [T-1]
- [ ] 🚩 T-2a: `plugin.json` を検証する schema / validator 手段を特定する [Owner: agent]
  - files: [docs/working/TASK-0017/evidence/schema-validation-method.md]
  - depends_on: [T-2]
- [ ] 🚩 T-2b: `settings.json` の必須キーと初期値を列挙する [Owner: agent]
  - files: [docs/working/TASK-0017/evidence/settings-defaults.md]
  - depends_on: [T-2]
- [ ] 🚩 T-2c: `.claude/` 非破壊確認の基準 commit SHA を記録 [Owner: agent]
  - files: [docs/working/TASK-0017/evidence/base-commit.md]
  - depends_on: [T-1]
- [ ] 🚩 T-3: plugin 配置場所（`plugin/plangate/`）と manifest 構造を確定し、plan との差分が無いことを確認する [Owner: agent]
  - files: []
  - depends_on: [T-2, T-2a, T-2b, T-2c]

### 実装フェーズ（C-3 Gate APPROVE 後のみ開始）

> ⚠️ 実装フェーズの先頭タスク T-4 は human gate **C-3** の承認を prerequisite とする。

- [ ] 🚩 T-4: `plugin/plangate/` と 5 サブディレクトリ（skills/agents/rules/hooks/**scripts**）+ `.claude-plugin/` を作成、5 `.gitkeep` 配置 [Owner: agent]
  - files: [plugin/plangate/skills/.gitkeep, plugin/plangate/agents/.gitkeep, plugin/plangate/rules/.gitkeep, plugin/plangate/hooks/.gitkeep, plugin/plangate/scripts/.gitkeep]
  - depends_on: [T-3, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-5: `plugin/plangate/.claude-plugin/plugin.json` を作成（metadata: name=`plangate`, version=`0.1.0`, description, author.name） [Owner: agent]
  - files: [plugin/plangate/.claude-plugin/plugin.json]
  - depends_on: [T-4]
- [ ] ~~T-6: settings.json 作成~~ **削除**（plugin 仕様に存在しないため、`evidence/settings-defaults.md` 参照）
- [ ] 🚩 T-7: `plugin/plangate/README.md`（プレースホルダー、TASK-0020 で完成予定の注記付き）を作成 [Owner: agent]
  - files: [plugin/plangate/README.md]
  - depends_on: [T-5]

### セルフレビュー①（実装直後）

- [ ] 🚩 T-8: `/self-review` を実行し、manifest のフィールド漏れ・構造一貫性・既存 `.claude/` 非破壊を確認する [Owner: agent]
  - files: []
  - depends_on: [T-7]
- [ ] 🚩 T-9: 指摘事項があれば実装フェーズに戻って修正する [Owner: agent]
  - files: []
  - depends_on: [T-8]

### 検証フェーズ

- [ ] 🚩 T-10: `plugin.json` の JSON valid 検証 + `schema-validation-method.md` Level 2-3 コマンド実行（必須フィールド + 型 + semver） [Owner: agent]
  - files: []
  - depends_on: [T-9]
- [ ] ~~T-10a: settings.json 必須キー確認~~ **削除**（settings.json 不要のため）
- [ ] 🚩 T-11: `git diff --stat cae1ac649384cbc7ba8f85cbab1b2fc312ddf05d -- .claude/` で既存構成が無変更であることを確認、結果を `evidence/non-destructive-check.md` に記録 [Owner: agent]
  - files: [docs/working/TASK-0017/evidence/non-destructive-check.md]
  - depends_on: [T-10]
- [ ] 🚩 T-12: 受入基準 8 項目の全確認 [Owner: agent]
  - files: []
  - depends_on: [T-11]

### E2E検証

- [ ] 🚩 T-13: Claude Code でのインストール試行を実施、結果を `evidence/install-verification.md` に記録 [Owner: agent]
  - files: [docs/working/TASK-0017/evidence/install-verification.md]
  - depends_on: [T-12]
- [ ] 🚩 T-14: インストール成功 or 想定内 warning のみであることを確認 [Owner: agent]
  - files: []
  - depends_on: [T-13]

### セルフレビュー②（検証後）

- [ ] 🚩 T-15: `/self-review` を再実行し、CI互換性・コミット衛生・検証網羅性を最終確認する [Owner: agent]
  - files: []
  - depends_on: [T-14]
- [ ] 🚩 T-16: 指摘事項があれば修正する [Owner: agent]
  - files: []
  - depends_on: [T-15]

### コードレビュー

- [ ] 🚩 T-17: サブエージェント（claude-code-reviewer 等）で複数観点のレビューを実施 [Owner: agent]
  - files: []
  - depends_on: [T-16]
- [ ] 🚩 T-18: 指摘事項があれば修正する [Owner: agent]
  - files: []
  - depends_on: [T-17]

### 完了フェーズ

- [ ] 🚩 T-19: コミット作成 [Owner: agent]
  - files: []
  - depends_on: [T-18]
- [ ] 🚩 T-20: 未解決Unknowns が 0 か確認 [Owner: agent]
  - files: []
  - depends_on: [T-19]
- [ ] 🚩 T-21: status.md を最終更新 [Owner: agent]
  - files: [docs/working/TASK-0017/status.md]
  - depends_on: [T-20]
- [ ] 🚩 T-22: todo.md の全タスクが完了していることを確認 [Owner: agent]
  - files: [docs/working/TASK-0017/todo.md]
  - depends_on: [T-21]

> 注: L-0〜V-4, PR作成は workflow-conductor が自動制御するため、todo.md には含めない。

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases の人間レビュー（exec 前ゲート） [Owner: human]
- [ ] C-4: PR レビュー・承認（GitHub 上） [Owner: human]

## ⚠️ 依存関係

- T-1 → T-2 → T-3（準備フェーズは直列）
- T-3 → T-4 → T-5 → T-6 → T-7（実装フェーズはファイル依存で直列）
- T-7 → T-8（セルフレビュー①前提）
- T-11 → T-12（受入基準確認前に `.claude/` 差分ゼロを確認）
- T-13 → T-14（E2E 後に結果確認）
- C-3 ゲート後のみ実装フェーズに入る（Human → Agent 依存）
- C-4 ゲートで PR マージ（Agent → Human 依存）
