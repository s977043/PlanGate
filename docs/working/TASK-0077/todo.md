---
task_id: TASK-0077
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0077（計画のみ先行）

## 👤 Human
- [ ] C-3: 設計（A/D）+ 承認境界変更の是非を判断。**APPROVE でも実装は別 phase**
- [ ] （実装 phase の起票可否は C-3 で別途決定）

## 🤖 Agent — 計画策定
- [ ] T1: S1 現状調査（mode-classification/C-3定義/#213/TASK-0071）
- [ ] T2: S2 A 設計（判定軸/自動推定+override/Lite構成/mode関係）🚩
- [ ] T3: S3 D 設計（降格条件/同期非同期opt-in/reject巻戻し/監査）🚩
- [ ] T4: S4 TASK-0071 責務境界表 🚩
- [ ] T5: S5 #213/#226接続+リスク緩和+計画停止条項 🚩

## 🤖 Agent — 検証（計画に対し）
- [ ] T6: C-1 セルフレビュー
- [ ] T7: C-2 外部レビュー（critical のため実施）

## ⚠️ 依存関係・停止条件
- **本 PBI は C-3 提示で停止**。実装は承認境界変更の是非を人間が判断後、別 PBI/phase
- TASK-0076(F5-BC) と独立。TASK-0071 と責務境界を要整理
- 関連 issue: #234(A/D) #213 #226
