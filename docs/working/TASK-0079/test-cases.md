---
task_id: TASK-0079
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0079

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5 |
| AC-6 | TC-6 |
| AC-7 | TC-7 |
| AC-8 | TC-8 |
| AC-9 | TC-9 |

## テストケース
- **TC-1**: mode-classification に `lite_eligible` 内包定義（判定軸=変更ファイル数/新規設計有無/既存パターン踏襲 + 自動推定 + 人間override）が存在
- **TC-2**: Lite ゲート構成（C-1 + 外部レビュー1本 + C-3）と Standard 差分が明記
- **TC-3**: working-context に C-3 条件付き降格（同期/非同期 opt-in・既定OFF・降格条件=C-1 PASS&C-2 critical/major=0&lite_eligible）が承認境界非撤廃で定義
- **TC-4**: AC-8（判定不能/根拠不足/Plan Health未算出/新規設計曖昧 → 必ず Standard・同期）が不変条件として記載
- **TC-5**: AC-9 reject 巻き戻し対象（ブランチ破棄/PR close/invalidation/監査/派生）が手順化
- **TC-6**: AC-10 Hardening Override（Shadow Config/承認境界/責務4分類/Critical Infra 抵触→Lite/降格無効・Standard/同期強制）が上位優先ルールとして記載
- **TC-7**: AC-11（critical 原則 Lite 不可・例外は人間 C-3 明示承認）/ AC-12（外部1本は critical/major=0 要求・観点固定）が記載
- **TC-8**: opt-in 未指定で既存 full ゲート挙動が不変（既存5mode定義・C-3三値の本文 diff 非破壊）+ hook 78/0
- **TC-9**: 降格適用/override発火/reject の監査記録方式が定義

## エッジケース
- E1: lite_eligible 判定不能 → Standard・同期（AC-8 安全側）
- E2: critical mode → 原則 lite_eligible=false（例外は人間 C-3 明示）
- E3: TASK-0071 領域抵触 → Hardening Override 発火で Lite/降格無効（最優先）
- E4: opt-in 未指定 → 一切発火せず従来 full（後方互換・既存挙動不変）
