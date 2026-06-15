# TEST CASES: TASK-0129

| AC | TC |
|----|----|
| AC-01 | TC-01,02,03,04 |
| AC-02 | TC-05 |
| AC-03 | TC-06 |
| AC-04 | TC-07 |
| AC-05 | TC-08 |
| AC-06 | TC-09 |

## テストケース
### TC-01〜04: Decision→c3_status mapping
- go→APPROVED / revise_plan→CONDITIONAL / human_approval_required→人間C-3強制 / no_go→REJECTED の各単体 / 種別: unit
### TC-05: Risk=high で autonomous APPROVE 無効化
- Risk=high 入力 → mode 最低 high・autonomous 不可 / 種別: unit
### TC-06: C-1 充足チェック
- Stop Condition / Replan Triggers 未記入 plan → C-1 が WARN/FAIL / 種別: unit
### TC-07: Stop-Work↔機械トリガー対応
- Stop-Work Conditions 各項が #544/#551 機械トリガーに対応づく / 種別: doc 検証
### TC-08: schema は apply-script 経由
- apply-task-0129-schema.sh --dry-run で差分・本体未変更・AI 適用しない / 種別: verification
### TC-09: 承認境界整合（後方互換）
- 拡張後 schema で既存 APPROVED/CONDITIONAL/REJECTED c3.json が valid / lite_eligible=false 強制 / 種別: unit+verification

## エッジケース
- review_decision 欠落の c3.json → 後方互換で valid（additive・required に追加しない）
- 未知 Decision 値 → 安全側（人間 C-3 強制）
