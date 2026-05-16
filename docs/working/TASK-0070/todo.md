---
task_id: TASK-0070
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0070

## 👤 Human

- [ ] C-3: plan.md / review-self.md を確認し三値判定（APPROVE/CONDITIONAL/REJECT）
- [ ] C-4: PR レビュー

## 🤖 Agent — 準備

- [ ] T1: check-plan-hash.sh 現状と check-forbidden-files.sh 慣行を再確認（S1）
- [ ] T2: 既存 hook テスト配置を特定し test-cases.md を確定

## 🤖 Agent — 実装（TDD）

- [ ] T3: TC-1〜TC-7 をテストスクリプト化（red を確認）🚩
- [ ] T4: check-plan-hash.sh の TASK resolution を P4(d) ロジックに置換
- [ ] T5: dash -n 構文チェック PASS 🚩

## 🤖 Agent — 検証

- [ ] T6: 全テスト green + 既存回帰なし 🚩
- [ ] T7: 全 AC（AC-1〜7）と test-cases 突合（V-1）
- [ ] T8: V-3 外部レビュー（Codex + Gemini、PR #242 マージ後に Codex 復活）

## 🤖 Agent — 完了

- [ ] T9: handoff.md 生成（必須6要素）
- [ ] T10: PR 作成

## ⚠️ 依存関係

- T3 → T4 → T5 → T6（TDD 順序厳守）
- C-3 APPROVE 後に T3 以降を開始（exec ゲート）
- T8 は PR #242（Codex toml 修正）マージ後が望ましい
