# TASK-0018 EXECUTION TODO

> 生成日: 2026-04-19

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定する [Owner: agent]
  - files: [docs/working/TASK-0018/pbi-input.md]
  - depends_on: []
- [ ] 🚩 T-2: 7 skills の現行ディレクトリ構造・ファイル構成・相対参照を調査 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/skills-inventory.md]
  - depends_on: [T-1]
- [ ] 🚩 T-2a: TASK-0017 の `plugin-spec-research.md` を参照し、plugin 経由呼び出しの正式 syntax を確定、7 skills 分の具体表記を記録 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/invocation-syntax.md]
  - depends_on: [T-2]
- [ ] 🚩 T-2b: `.claude/` 非破壊確認の基準 commit SHA を記録 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/base-commit.md]
  - depends_on: [T-1]
- [ ] 🚩 T-3: plugin 側配置パスと参照書き換え方針を確定、plan との差分が無いことを確認 [Owner: agent]
  - files: []
  - depends_on: [T-2, T-2a, T-2b]

### 実装フェーズ（C-3 Gate APPROVE 後のみ開始）

> ⚠️ 実装フェーズの先頭タスク T-4 は human gate **C-3** の承認を prerequisite とする。

- [ ] 🚩 T-4: 7 skills を `.claude/skills/` から `plugin/plangate/skills/` にコピー配置 [Owner: agent]
  - files: [plugin/plangate/skills/working-context/**, plugin/plangate/skills/ai-dev-workflow/**, plugin/plangate/skills/brainstorming/**, plugin/plangate/skills/self-review/**, plugin/plangate/skills/pr-review-response/**, plugin/plangate/skills/pr-code-review/**, plugin/plangate/skills/setup-team/**]
  - depends_on: [T-3, C-3]
  - prerequisite: **C-3 Gate APPROVE**
- [ ] 🚩 T-5: 各 skill 内の相対パス参照を plugin 構造に合わせて修正 [Owner: agent]
  - files: [plugin/plangate/skills/**]
  - depends_on: [T-4]
- [ ] 🚩 T-6: `plugin/plangate/.claude-plugin/plugin.json` の skills エントリに 7 件を追記 [Owner: agent]
  - files: [plugin/plangate/.claude-plugin/plugin.json]
  - depends_on: [T-5]

### セルフレビュー①（実装直後）

- [ ] 🚩 T-7: `/self-review` を実行し、コピー漏れ・参照破損・エントリ不足を確認 [Owner: agent]
  - files: []
  - depends_on: [T-6]
- [ ] 🚩 T-8: 指摘事項があれば実装フェーズに戻って修正 [Owner: agent]
  - files: []
  - depends_on: [T-7]

### 検証フェーズ

- [ ] 🚩 T-9: `ls plugin/plangate/skills/` の結果が 7 件であることを確認 [Owner: agent]
  - files: []
  - depends_on: [T-8]
- [ ] 🚩 T-10: `plugin.json` の skills エントリ件数が 7 であることを確認 [Owner: agent]
  - files: []
  - depends_on: [T-9]
- [ ] 🚩 T-11: `git diff --stat <base-sha> -- .claude/skills/` で既存が無変更であることを確認（base-sha は T-2b の evidence 参照）、結果を `evidence/non-destructive-check.md` に記録 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/non-destructive-check.md]
  - depends_on: [T-10]
- [ ] 🚩 T-12: 受入基準 8 項目の全確認 [Owner: agent]
  - files: []
  - depends_on: [T-11]

### E2E検証

- [ ] 🚩 T-13: T-2a で確定した syntax で plugin 経由 `plangate:working-context` を呼び出し、plugin 側が応答した証跡を evidence に記録 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/skill-invocation-test.md]
  - depends_on: [T-12]
- [ ] 🚩 T-14: 同 syntax で plugin 経由 `plangate:ai-dev-workflow` を呼び出し、plugin 側応答を確認 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/skill-invocation-test.md]
  - depends_on: [T-13]
- [ ] 🚩 T-15: 残り 5 skills を plugin 経由で呼び出し、成功記録 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/skill-invocation-test.md]
  - depends_on: [T-14]
- [ ] 🚩 T-15a: dual-run 検証: legacy `.claude/skills/working-context` も従来どおり呼び出せ、plugin / legacy の応答を識別できることを確認 [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/skill-invocation-test.md]
  - depends_on: [T-15]

### commands 併存境界の記録

- [ ] 🚩 T-16: skill 化対象の command と併存方針を `evidence/command-skill-boundary.md` に記録（TASK-0020 の素材） [Owner: agent]
  - files: [docs/working/TASK-0018/evidence/command-skill-boundary.md]
  - depends_on: [T-15]

### セルフレビュー②（検証後）

- [ ] 🚩 T-17: `/self-review` を再実行し、呼び出し動作・参照整合・境界記録の完備を最終確認 [Owner: agent]
  - files: []
  - depends_on: [T-16]
- [ ] 🚩 T-18: 指摘事項があれば修正 [Owner: agent]
  - files: []
  - depends_on: [T-17]

### コードレビュー

- [ ] 🚩 T-19: サブエージェントで複数観点のレビューを実施 [Owner: agent]
  - files: []
  - depends_on: [T-18]
- [ ] 🚩 T-20: 指摘事項があれば修正 [Owner: agent]
  - files: []
  - depends_on: [T-19]

### 完了フェーズ

- [ ] 🚩 T-21: コミット作成 [Owner: agent]
  - files: []
  - depends_on: [T-20]
- [ ] 🚩 T-22: 未解決Unknowns が 0 か確認 [Owner: agent]
  - files: []
  - depends_on: [T-21]
- [ ] 🚩 T-23: status.md を最終更新 [Owner: agent]
  - files: [docs/working/TASK-0018/status.md]
  - depends_on: [T-22]
- [ ] 🚩 T-24: todo.md の全タスクが完了していることを確認 [Owner: agent]
  - files: [docs/working/TASK-0018/todo.md]
  - depends_on: [T-23]

> 注: L-0〜V-4, PR作成は workflow-conductor が自動制御するため、todo.md には含めない。

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases の人間レビュー（exec 前ゲート） [Owner: human]
- [ ] C-4: PR レビュー・承認（GitHub 上） [Owner: human]

## ⚠️ 依存関係

- **前提 TASK**: TASK-0017 が完了していること（plugin ディレクトリ存在）
- T-1 → T-2 → T-3（準備フェーズ直列）
- T-4 → T-5 → T-6（コピー → 参照修正 → manifest 更新）
- T-13 → T-14 → T-15（E2E は skill ごとに独立実行可能だが直列で安全確認）
- C-3 ゲート後のみ実装フェーズへ
