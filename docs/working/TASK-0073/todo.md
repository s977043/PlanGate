---
task_id: TASK-0073
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0073

## 👤 Human
- [ ] C-3: plan/review-self + S2(境界表現・検出主体) + mode 確定で三値判定
- [ ] C-4: PR レビュー

## 🤖 Agent — 準備
- [ ] T1: S1 現状調査（委譲規約/既存git hook/認証三点/F1プリフライト）
- [ ] T2: S2 境界表現+検出主体 design note → C-3 上申

## 🤖 Agent — 実装
- [ ] T3: S3 委譲境界宣言仕様 🚩
- [ ] T4: S4 違反検出実装 🚩
- [ ] T5: S5 exec前プリフライト統合（git主体+認証三点）🚩
- [ ] T6: S6 core-contract/execute.md 追記 🚩

## 🤖 Agent — 検証
- [ ] T7: S7 決定論性 + 回帰 + F1整合
- [ ] T8: V-1（AC-1〜7）
- [ ] T9: V-3（Codex+Gemini）, critical 時 V-4

## 🤖 Agent — 完了
- [ ] T10: handoff（settings 手動要否を明記）
- [ ] T11: PR 作成

## ⚠️ 依存関係
- F1（TASK-0072 / PR #245）と整合。可能なら #245 マージ後が望ましい（プリフライト統合先が確定）
- S2 design note の C-3 追加承認後に S4 着手
- 関連 issue: #239（問題2/3）クローズ参照
