---
task_id: TASK-0071
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0071

## 👤 Human

- [ ] C-3: plan/review-self 確認、PR 分割方針・S3 設計判断（メンテ有効期限/タグ粒度）を含め三値判定
- [ ] C-4: 各 PR レビュー（critical: 複数レビュア推奨）

## 🤖 Agent — 準備

- [ ] T1: PR 分割確定（C-3 結果反映）。S1+S2 / S3 / S4 を別 plan slice 化
- [ ] T2: settings 構造判定方式（jq）と doctor インタフェース確定

## 🤖 Agent — 実装（TDD・PR 分割前提）

- [ ] T3: S1a/S1b/S1c（パッチ正本 + doctor --check-settings + タスクロック）🚩
- [ ] T4: S2（CI drift check required）🚩
- [ ] T5: S3a 設計 note → C-3 追加判断 → S3b（メンテモード/除外タグ + SKIP_REASON）🚩
- [ ] T6: S4（責務 4 分類 rules 正本）🚩

## 🤖 Agent — 検証

- [ ] T7: 全 hook テスト回帰（60+新規）green
- [ ] T8: V-1 受け入れ検査（AC-1〜8 突合）
- [ ] T9: V-3 外部レビュー（Codex+Gemini）, V-4 リリース前（critical）

## 🤖 Agent — 完了

- [ ] T10: handoff（PBI 単位 + slice 単位）
- [ ] T11: 各 PR 作成

## ⚠️ 依存関係

- 依存: PR #242/#243 先行（EH-3 P4(d) が前提）
- T5 は S3a 設計 note の C-3 追加承認後に S3b 着手
- TDD 順序厳守、critical のため C-2 も実施
