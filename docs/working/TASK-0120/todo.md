# TASK-0120 EXECUTION TODO

> Source: plan.md / Mode: light

## 🤖 Agent タスク

- [ ] **T-01**: SessionStart gh-pin-account hook 実装場所 + 責務確認 (owner=agent / Risk=low / 🚩 責務整理完了)
- [ ] **T-02**: scripts/gh-s977043.sh (auth switch + 冪等) (owner=agent / Risk=low / depends_on=T-01 / 🚩 switch + gh 実行 + 冪等)
- [ ] **T-03**: docs/ai/github-account-pinning.md (owner=agent / Risk=low / depends_on=T-02 / 🚩 運用ガイド + 責務整理)
- [ ] **T-04**: tests/extras/ta-23-gh-account-pin.sh (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-23 全 PASS)
- [ ] **T-05**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..6 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] **H-02**: C-4 ゲート (PR レビュー) + merge

## ⚠️ 依存関係

- T-02..T-05 は H-01 (C-3) 通過後に着手可
- T-01 (read-only 調査) は C-3 前可
- H-02 (merge) は Human-owned 固定
