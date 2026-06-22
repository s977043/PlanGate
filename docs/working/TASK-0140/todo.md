---
task_id: TASK-0140
artifact_type: todo
schema_version: 1
---

# EXECUTION TODO — TASK-0140

## 🤖 Agent タスク

### 準備フェーズ
- [x] A-1: pbi-input.md 作成（完了）
- [x] A-2: plan/todo/test-cases 生成（完了）
- [ ] A-3: C-1 セルフレビュー実施

### 実装フェーズ
- [ ] I-1: ta-42-cli-subcommands.sh 実装（AC-1〜5）
  - depends_on: A-3
  - rollback: `git checkout tests/extras/ta-42-cli-subcommands.sh`
- [ ] I-2: run-tests.sh へ ta-42 エントリ追記（AC-6）
  - depends_on: I-1
  - rollback: `git checkout tests/run-tests.sh`

### 検証フェーズ
- [ ] V-1: `sh tests/run-tests.sh` 実行・全 PASS 確認
  - depends_on: I-2
- [ ] V-2: metrics 収集 `bin/plangate metrics TASK-0140 --collect`
- [ ] V-3: V-1 受け入れ検査

### 完了フェーズ
- [ ] C-1: PR 作成
- [ ] C-2: handoff.md 作成

## 👤 Human タスク

- [ ] H-1: C-4 PR レビュー・マージ
- [ ] H-2: PR #598/#599/#600 の C-4 マージ（別タスク、並行）

## ⚠️ 依存関係

- I-1, I-2: A-3（C-3 AUTONOMOUS APPROVE）の後
