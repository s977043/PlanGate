# TASK-0809 TODO

## 🤖 Agent（委託: sonnet / worktree 分離 / TDD）

- [ ] T1: TC-2..11 のテストを先行追加（RED 確認） rollback:不要
- [ ] T2: ho-paths 実行時解決（--ho-paths > CWD docs/ai/ai-loop/ho-paths.md > script 隣接 ../references/ho-paths.md）+ 表パーサ rollback:revert
- [ ] T3: fail-closed ガード（解決不能/0 件 → 全件 HUMAN_ESCALATED） rollback:revert
- [ ] T4: allowed_paths 必須化 + scope 逸脱 escalate（HO 優先順位は不変） rollback:revert
- [ ] T5: POLICY_REF @v1 + decision-table.md の記述追従 rollback:revert
- [ ] T6: .codex 3 配置同一性テストの有無を実測 → 注記 or sync 分岐 rollback:revert
- [ ] T7: 00_concept.md / execution-runbook.md の「未実装 #809」注記を実装済み表現へ + size_ok 順序制約 1 文 rollback:revert
- [ ] T8: plugin sync + 全テスト（test_arbiter + ta-30 + フルスイート）

## 👤 Human

- [ ] #808 スレッド Resolve + マージ（exec 成果の PR 化の前提）
- [ ] C-4: PR レビュー・マージ

## ⚠️ 依存

- T1-8 は feat/807-ai-loop-phase1 起点のブランチで実装可。PR 作成は #808 マージ後（squash 後は rebase --onto で載せ替え）
