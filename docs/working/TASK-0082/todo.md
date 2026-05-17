---
task_id: TASK-0082
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0082

## 👤 Human
- [ ] C-3: 設計確定済(3点)。SKIP_REASON 追認マーク形式の最終確認
- [ ] C-4: PR レビュー（critical: 複数レビュア推奨）

## 🤖 Agent — 準備
- [ ] T1: S1 現状調査（分岐順/decision-log/CI/schemas）

## 🤖 Agent — 実装
- [ ] T2: S2 maintenance.json schema+検証 🚩
- [ ] T3: S3 check-plan-hash.sh メンテ分岐（plan.md BLOCK後・優先順・fail-closed・監査）🚩
- [ ] T4: S4 SKIP_REASON 必須化（空→停止・decision-log append）🚩
- [ ] T5: S5 CI SKIP_REASON 未追認 required check 🚩

## 🤖 Agent — 検証
- [ ] T6: S6 回帰（不在時従来動作・P4d不変・hook 78/0）
- [ ] T7: V-1（AC-1〜9）
- [ ] T8: V-3（Codex+Gemini）+ V-4（critical）

## 🤖 Agent — 完了
- [ ] T9: handoff + TASK-0071 INDEX（S3完了→D-1全完了）更新
- [ ] T10: PR 作成

## ⚠️ 依存関係
- 設計: TASK-0071 s3a-design-note（C-2反映・C-3 3点確定）。S1+S2/S4 完了済
- 関連: TASK-0071 最終スライス
