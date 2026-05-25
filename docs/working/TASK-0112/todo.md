# TASK-0112 EXECUTION TODO

> Source: plan.md / Mode: light

## 🤖 Agent タスク

- [ ] **T-01**: 既存例外ルール構造確認 + Hardening Override 対象パス抽出 (check-plan-hash.sh) (owner=agent / Risk=low / 🚩 パス一覧確定)
- [ ] **T-02**: `.claude/rules/mode-classification.md` 例外ルール追記 (owner=agent / Risk=medium / depends_on=T-01 / 🚩 maintenance window 経由 + markdownlint pass)
- [ ] **T-03**: handoff.md (Rule 5 必須 6 要素) + V-1 (owner=agent / Risk=low / depends_on=T-02 / 🚩 AC-1..6 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] **H-02**: maintenance window 発行 (`bin/plangate maintenance start --paths .claude/rules/mode-classification.md --minutes 5`) — exec 直前
- [ ] **H-03**: C-4 ゲート (PR レビュー) + merge

## ⚠️ 依存関係

- T-02 は H-01 (C-3) + H-02 (maintenance) 両通過後にのみ着手可
- T-01 は C-3 前可

## 完了条件

全 T + handoff 6 要素 + AC-1..6 PASS + CI 全 PASS
