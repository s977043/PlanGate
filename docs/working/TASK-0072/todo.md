---
task_id: TASK-0072
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0072

## 👤 Human

- [ ] C-3: plan / review-self / S2 ケイパビリティ判定方式を含め三値判定
- [ ] C-4: PR レビュー（critical: 複数レビュア推奨）

## 🤖 Agent — 準備

- [ ] T1: S1 現状調査（exec workflow / core-contract / conductor / error 分類所在）
- [ ] T2: S2 ケイパビリティ判定方式 design note → C-3 上申

## 🤖 Agent — 実装

- [ ] T3: S3 exec フロー定義を分岐+フォールバック既定へ改訂 🚩
- [ ] T4: S4 core-contract 不変条件追加 🚩
- [ ] T5: S5 error taxonomy delegation_unavailable 定義 🚩
- [ ] T6: S6 workflow-conductor agent 整合 🚩

## 🤖 Agent — 検証

- [ ] T7: S7 定義整合 grep + ドキュメント整合性 + hook テスト回帰
- [ ] T8: V-1 受け入れ（AC-1〜7 突合）
- [ ] T9: V-3 外部レビュー（Codex+Gemini）, V-4（critical）

## 🤖 Agent — 完了

- [ ] T10: handoff
- [ ] T11: PR 作成

## ⚠️ 依存関係

- TDD/定義変更順序: S3→S4→S5→S6（contract は影響大のため S4 を中核に）
- C-3 APPROVE 後に T3 以降
- 関連 issue: #237/#238/#239/#234-E をクローズ参照
