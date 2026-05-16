---
task_id: TASK-0079
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0079

## 👤 Human
- [ ] C-3: 承認境界実装の最終確認（設計は TASK-0077 APPROVED 済・実装差分の妥当性）
- [ ] C-4: PR レビュー（critical: 複数レビュア推奨）

## 🤖 Agent — 準備
- [ ] T1: S1 現状調査（mode-classification/working-context C-3節/TASK-0077設計）

## 🤖 Agent — 実装
- [ ] T2: S2 mode-classification lite_eligible 内包 🚩
- [ ] T3: S3 working-context C-3 条件付き降格 🚩
- [ ] T4: S4 AC-9 reject巻戻し + AC-10 Hardening Override 🚩

## 🤖 Agent — 検証
- [ ] T5: S5 既定OFF 挙動不変 + hook 78/0 回帰
- [ ] T6: V-1（AC-1〜9）
- [ ] T7: V-3（Codex+Gemini）+ V-4（critical リリース前）

## 🤖 Agent — 完了
- [ ] T8: handoff（TASK-0071 マージ時の機械接続 follow-up 明記）
- [ ] T9: PR 作成

## ⚠️ 依存関係
- 設計: TASK-0077（#250 マージ済・C-3 APPROVED）
- #213/TASK-0071 連携は概念参照（未実装でも AC-8/概念ルールで安全側成立）
- 関連 issue: #251（実装）/ #234-A/D（起源）
