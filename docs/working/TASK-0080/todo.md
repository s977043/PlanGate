---
task_id: TASK-0080
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0080

## 👤 Human
- [ ] C-3: S1+S2 実装の是非 + タスクロック強制層（hook/doctor/workflow）を判断
- [ ] C-4: PR レビュー（critical: 複数レビュア推奨）

## 🤖 Agent — 準備
- [ ] T1: S1 現状調査（doctor構造/settings期待wiring/CI/hookテスト）

## 🤖 Agent — 実装
- [ ] T2: S2 適用script + settings期待wiring正本 🚩
- [ ] T3: S3 doctor --check-settings 実装 🚩
- [ ] T4: S4 タスクロック機構（強制層はC-3確定）🚩
- [ ] T5: S5 CI settings drift check required 🚩

## 🤖 Agent — 検証
- [ ] T6: S6 非破壊回帰（適用済みPASS/hook78-0/既存doctor12項目不変）
- [ ] T7: V-1（AC-1〜7）
- [ ] T8: V-3（Codex+Gemini）+ V-4（critical）

## 🤖 Agent — 完了
- [ ] T9: handoff + TASK-0071 INDEX/handoff 更新（S1+S2完了・S3/S4残）
- [ ] T10: PR 作成

## ⚠️ 依存関係
- 設計: TASK-0071（#244 マージ済）。依存 #242/#243 マージ済（充足）
- S3/S4 は別スライス（本PBIスコープ外）
- 関連 issue/TASK: TASK-0071 / 本セッション AC-8 摩擦
