# TASK-0031 EXECUTION TODO

## 凡例

- `[x]` 完了
- `[ ]` 未着手

---

## 準備フェーズ

- [x] 既存 `ai-dev-workflow.md` を読んでコマンドファイル形式を確認（agent）
- [x] `plugin.json` の現在内容を確認（agent）
- [x] `docs/working/TASK-0031/` ディレクトリ作成（agent）

## 実装フェーズ

- [x] `docs/working/TASK-0031/pbi-input.md` 作成（agent）
- [x] `docs/working/TASK-0031/plan.md` 作成（agent）
- [x] `docs/working/TASK-0031/todo.md` 作成（agent）
- [x] `docs/working/TASK-0031/test-cases.md` 作成（agent）
- [x] `docs/working/TASK-0031/INDEX.md` 作成（agent）
- [x] `docs/working/TASK-0031/current-state.md` 作成（agent）
- [x] `plugin/plangate/commands/pg-think.md` 作成（agent）
- [x] `plugin/plangate/commands/pg-hunt.md` 作成（agent）
- [x] `plugin/plangate/commands/pg-check.md` 作成（agent）
- [x] `plugin/plangate/commands/pg-verify.md` 作成（agent）
- [x] `plugin/plangate/.claude-plugin/plugin.json` version 0.3.0 に更新（agent）

## 検証フェーズ

- [x] 受入基準 5 件の自己突合（agent） 🚩
  - AC-1: 4 コマンドファイルの存在確認
  - AC-2: skill-policy-router との連携記述確認
  - AC-3: EvidenceLedger JSON 出力フォーマット確認
  - AC-4: /pg-hunt の Iron Law 明記確認
  - AC-5: /pg-check の Severity 定義と出力フォーマット確認
- [x] `docs/working/TASK-0031/handoff.md` 作成（agent）

## 完了フェーズ

- [x] `feature/task-0031-pg-commands` ブランチで git commit（agent）

## 👤 Humanタスク

- [ ] C-3: 計画承認（exec 前ゲート）
- [ ] C-4: PR レビュー（GitHub 上）
