# TASK-0019 EXECUTION TODO

> 生成日: 2026-04-19

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定する [Owner: agent]
  - files: [docs/working/TASK-0019/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: 6 agents をスキャンし、プロジェクト固有前提（Laravel/PostgreSQL/ECS/Cloudflare 等）を抽出 [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/agents-scan.md]
  - depends_on: [T-1]
- [ ] 🚩 T-3: rules 3 ファイルと中核スクリプトの依存関係を `dependency-scan.md` に独立して記録 [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/dependency-scan.md]
  - depends_on: [T-2]
- [ ] 🚩 T-3a: plugin 内 agent/rules 参照方式を決定し記録（例: `plangate:implementer` 形式、rules 絶対パス） [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/reference-resolution.md]
  - depends_on: [T-3]
- [ ] 🚩 T-3b: `scripts/` に配置する具体スクリプト一覧を決定し記録 [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/script-inventory.md]
  - depends_on: [T-3]
- [ ] 🚩 T-3c: `.claude/` 非破壊確認の基準 commit SHA を記録 [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/base-commit.md]
  - depends_on: [T-1]
- [ ] 🚩 T-4: 固有前提除去の汎用化ガイドラインを策定、plan との差分が無いことを確認 [Owner: agent]
  - files: []
  - depends_on: [T-3, T-3a, T-3b, T-3c]

### 実装フェーズ（C-3 Gate APPROVE 後のみ開始・full モード）

> ⚠️ 実装フェーズの先頭タスク T-5 は human gate **C-3** の承認を prerequisite とする。full モードのため、C-3 では詳細レビューを実施すること。

- [ ] 🚩 T-5: 6 agents を `.claude/agents/` から `plugin/plangate/agents/` にコピー [Owner: agent]
  - files: [plugin/plangate/agents/workflow-conductor.md, plugin/plangate/agents/spec-writer.md, plugin/plangate/agents/implementer.md, plugin/plangate/agents/linter-fixer.md, plugin/plangate/agents/acceptance-tester.md, plugin/plangate/agents/code-optimizer.md]
  - depends_on: [T-4, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-6: 各 agent から固有前提を除去（汎用表現に置換） [Owner: agent]
  - files: [plugin/plangate/agents/**]
  - depends_on: [T-5]
- [ ] 🚩 T-7: rules 3 ファイルを `plugin/plangate/rules/` に配置 [Owner: agent]
  - files: [plugin/plangate/rules/working-context.md, plugin/plangate/rules/review-principles.md, plugin/plangate/rules/mode-classification.md]
  - depends_on: [T-6]
- [ ] 🚩 T-8: agents 内 rules 参照パスを plugin 内パスへ修正 [Owner: agent]
  - files: [plugin/plangate/agents/**]
  - depends_on: [T-7]
- [ ] 🚩 T-9: T-3b の `script-inventory.md` に列挙された中核スクリプトのみを `plugin/plangate/scripts/` に配置（過剰コピー禁止） [Owner: agent]
  - files: [plugin/plangate/scripts/**]
  - depends_on: [T-8]
- [ ] 🚩 T-10: `plugin.json` に agents / rules エントリを追記 [Owner: agent]
  - files: [plugin/plangate/.claude-plugin/plugin.json]
  - depends_on: [T-9]

### セルフレビュー①（実装直後）

- [ ] 🚩 T-11: `/self-review` を実行し、固有前提残存・参照破損・挙動逸脱を確認 [Owner: agent]
  - files: []
  - depends_on: [T-10]
- [ ] 🚩 T-12: 指摘事項があれば実装フェーズに戻って修正 [Owner: agent]
  - files: []
  - depends_on: [T-11]

### 検証フェーズ

- [ ] 🚩 T-13: `grep -r "Laravel\|PostgreSQL\|ECS\|Cloudflare" plugin/plangate/agents/` で残存確認（0 件想定） [Owner: agent]
  - files: []
  - depends_on: [T-12]
- [ ] 🚩 T-14: plugin.json の agents エントリ 8 件、rules エントリ 3 件を確認 [Owner: agent]
  - files: []
  - depends_on: [T-13]
- [ ] 🚩 T-15: `git diff --stat <base-sha> -- .claude/agents/ .claude/rules/` で既存無変更を確認（base-sha は T-3c の evidence 参照）、結果を `evidence/non-destructive-check.md` に記録 [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/non-destructive-check.md]
  - depends_on: [T-14]
- [ ] 🚩 T-16: 受入基準 9 項目の全確認 [Owner: agent]
  - files: []
  - depends_on: [T-15]

### E2E検証

- [ ] 🚩 T-17: agents 間相互参照（workflow-conductor → 他 7 agents）が plugin 内で解決されるか検証 [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/agent-chain-test.md]
  - depends_on: [T-16]
- [ ] 🚩 T-18: plan → C-1 → exec → L-0 → V-1 → PR フローを plugin 内で 1 周実行し結果を記録 [Owner: agent]
  - files: [docs/working/TASK-0019/evidence/flow-completion-test.md]
  - depends_on: [T-17]
- [ ] 🚩 T-19: フロー結果を受入基準と突合、全項目 PASS を確認 [Owner: agent]
  - files: []
  - depends_on: [T-18]

### セルフレビュー②（検証後）

- [ ] 🚩 T-20: `/self-review` 17項目チェックを再実行（full モード） [Owner: agent]
  - files: []
  - depends_on: [T-19]
- [ ] 🚩 T-21: 指摘事項があれば修正 [Owner: agent]
  - files: []
  - depends_on: [T-20]

### コードレビュー

- [ ] 🚩 T-22: C-2 外部AIレビュー実施（full モード必須） [Owner: agent]
  - files: [docs/working/TASK-0019/review-external.md]
  - depends_on: [T-21]
- [ ] 🚩 T-23: サブエージェントで複数観点レビュー実施 [Owner: agent]
  - files: []
  - depends_on: [T-22]
- [ ] 🚩 T-24: 指摘事項があれば修正 [Owner: agent]
  - files: []
  - depends_on: [T-23]

### 完了フェーズ

- [ ] 🚩 T-25: コミット作成 [Owner: agent]
  - files: []
  - depends_on: [T-24]
- [ ] 🚩 T-26: 未解決Unknowns が 0 か確認 [Owner: agent]
  - files: []
  - depends_on: [T-25]
- [ ] 🚩 T-27: status.md を最終更新 [Owner: agent]
  - files: [docs/working/TASK-0019/status.md]
  - depends_on: [T-26]
- [ ] 🚩 T-28: todo.md の全タスクが完了していることを確認 [Owner: agent]
  - files: [docs/working/TASK-0019/todo.md]
  - depends_on: [T-27]

> 注: L-0〜V-4, PR作成は workflow-conductor が自動制御するため、todo.md には含めない。full モードのため V-2（コード最適化）、V-3（外部モデルレビュー）も conductor 経由で実行される。

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases の人間レビュー（exec 前ゲート、full モードのため詳細レビュー推奨） [Owner: human]
- [ ] C-4: PR レビュー・承認（GitHub 上、full モードのため複数レビュアー推奨） [Owner: human]

## ⚠️ 依存関係

- **前提 TASK**: TASK-0017, TASK-0018 完了
- T-1 → T-2 → T-3 → T-4（準備フェーズ直列）
- T-5 → T-6 → T-7 → T-8 → T-9 → T-10（実装は配置 → 汎用化 → rules → 参照修正 → scripts → manifest の順）
- T-17 → T-18 → T-19（E2E: 参照検証 → フロー検証 → 受入確認）
- C-3 ゲート後のみ実装フェーズへ（full モードでは特に重要）
