# EXECUTION PLAN: TASK-0129

#543 Plan Review Gate 判定連携（#544 Phase2）

## Goal
外部レビュー結果（Decision/Risk/Stop-Work）と #544/#551 plan 充足を C-3 判定に接続し、進行可否を「止める・通す」強制層へ昇格する（判定 mapping まで。実行層は #527 配下）。

## Constraints / Non-goals
- **承認境界の中核（c3-approval.schema / working-context.md = HO）を変更** → mode 最低 high・lite_eligible=false・**Standard 同期 C-3 固定・autonomous APPROVE 不可**
- AI は schema/working-context を直接編集せず apply-script を作成 → **人間適用**
- exec 着手は**人間 C-3 承認後**（仕様どおり人間ゲート）
- Non-goal: 機械トリガー実行層（codex-guarded.sh/doctor）実装は別 PBI（#527）/ #487 Risk Budget

## Approach Overview
1. Decision→c3_status mapping を正規化（doc + schema）。go→APPROVED候補 / revise_plan→CONDITIONAL（R-NNN 集約）/ human_approval_required→人間C-3強制 / no_go→REJECTED
2. `c3-approval.schema.json` に判定根拠フィールド（`review_decision` / `review_risk` 等）を additive 追加（後方互換・apply-script）
3. C-1（plan-quality-check / review-self.md）に「Stop Condition / Replan Triggers(機械値) 記入」検出を追加
4. Stop-Work Conditions ↔ #544/#551 機械トリガー対応表を working-context/正本に記載（apply-script）
5. Do Not Touch→forbidden_files(EH-6) / Verification Required→Verification Automation の接続を明記

## Work Breakdown
| Step | 内容 | Output | Owner | 🚩 |
|------|------|--------|-------|----|
| S1 | Decision→c3_status mapping 確定（doc） | docs | agent | |
| S2 | schema 拡張 apply-script（additive・後方互換） | scripts/apply-task-0129-*.sh | agent | 🚩 後方互換 |
| S3 | C-1 充足チェック追加（plan-quality-check / review-self テンプレ） | .claude/skills / docs | agent | 🚩 |
| S4 | Stop-Work↔機械トリガー対応表 apply-script（working-context HO） | scripts/apply-*.sh | agent | 🚩 HO |
| S5 | テスト（schema 後方互換・mapping） | evidence | agent | |
| H1 | **人間 C-3 承認**（承認境界・Standard 同期） | approvals/c3.json | human | 🚩 |
| H2 | apply-script を人間が適用（schema/working-context HO） | 反映 | human | 🚩 |

## Testing Strategy
- schema: 既存 c3.json（APPROVED/CONDITIONAL/REJECTED）が拡張後も valid（後方互換）
- mapping: 各 Decision → 期待 c3_status の単体検証
- C-1: Stop Condition/Replan Triggers 未記入で WARN/FAIL を検出
- 承認境界整合: lite_eligible=false / Standard C-3 が強制されること

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| schema 拡張で既存 c3.json 非互換 | additive のみ・required に追加しない・後方互換テスト必須 |
| 承認境界の自律変更 | exec は人間 C-3 後・HO は apply-script+人間適用（本 plan で固定） |
| 実行層との責務混線 | 本 PBI は判定 mapping まで・実行層は #527 と明確分離 |

## Metrics Evidence
| 指標 | 実数 | 判定 |
|------|------|------|
| touch HO ファイル | c3-approval.schema.json / working-context.md（2・apply-script+人間適用） | 採用 |
| 既存 c3_status enum | 3（APPROVED/CONDITIONAL/REJECTED・schema 実在） | additive 拡張 |

## Mode判定
**モード**: high-risk（承認境界中核 / R-007 と同様 critical 寄り）
**判定根拠**: c3-approval.schema + working-context.md（HO・承認境界）変更 → **最低 high・lite_eligible=false・Standard 同期 C-3 固定・autonomous APPROVE 不可**。exec は人間 C-3 承認後。
