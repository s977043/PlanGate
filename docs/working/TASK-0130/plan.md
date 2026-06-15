# EXECUTION PLAN — TASK-0130 (#544 Phase1: AEE 条項欄の plan 正本追加)

## Goal

plan 正本(ai-driven-development.md Prompt1 + working-context.md)に承認済み実行境界(AEE)の
条項欄を追加し、C-1 に充足検出を足す。Phase1=明文化(ソフト強制)に限定。

## Constraints / Non-goals

- 強制(承認不可化)はしない(Phase2/#543)。実行層実装もしない(#527)。
- working-context.md(HO)はAIが直接編集せず、仕様提示+apply-scriptを生成(適用は人間)。

## Approach Overview

rev.3 §3 のスキーマを条項欄として正本へ転記。非HOファイルはAIがTDD的に編集、
HOファイル(working-context.md)はpatch/apply-script提示に留める。

## Work Breakdown

| Step | Output | Owner | HO | Risk | 🚩 |
|------|--------|-------|-----|------|----|
| S1 | ai-driven-development.md Prompt1 に条項6欄追加 + Verification Automation 強化 + honest framing | agent | × | 中 | 条項がrev.3 §3と一致するか |
| S2 | working-context.md 必須要素リスト追記の **apply-script + patch 提示**(AI編集しない) | agent | ✅ | 高 | HO適用は人間 🚩 |
| S3 | plan-quality-check SKILL + review-self.md に C-1 検出2項目追加 | agent | × | 低 | 二重定義回避 |
| S4 | ai-dev-plan SKILL の参照行が正本変更に追従するか確認(再定義しない/Rule1) | agent | × | 低 | — |

## Files / Components to Touch

- docs/ai-driven-development.md (S1)
- .claude/rules/working-context.md (S2・HO・apply-scriptのみ)
- .claude/skills/plan-quality-check/SKILL.md (S3)
- docs/working/templates/review-self.md (S3)
- .agents/skills/ai-dev-plan/SKILL.md (S4・参照確認のみ)

## Testing Strategy

### Verification Automation

- markdownlint(変更md)
- bin/plangate doctor が PASS 維持
- 条項欄が rev.3 §3 と項目一致することの目視/grep 確認

## Loop Scope

本PBIのexec内Loop = 条項転記の検証失敗→修正の反復。単一PBI内に限定(複数PBI予算は#487)。

## Stop Condition

- AC-01〜07 を満たす
- markdownlint 0 error / doctor PASS
- 変更が In scope 内
- working-context.md(HO)は apply-script 提示に留まり AI が直接編集していない
- 残課題が handoff に明示

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本plan に追記し Replan 判定を通す。

## Replan Triggers (機械値・rev.3 §2.3)

- 変更ファイル数 > max(想定×2, 想定+5)  ※想定=5 → 10超で発火
- 同一検証コマンド連続失敗 3回
- 同一ファイル修正反復 3回
- plan外ディレクトリ波及 1件
- AC/Verificationコマンド変更 検知時

> 本Phaseでは hard gate でなく「Replan必須表示/C-1失敗」として作用(強制はPhase2)。
> 本Replan Ruleは自己設置Gate非緩和原則と接続し /goal・autonomy で自動解除しない。

## Revert Policy

停止時、Scope外へ波及した変更**のみ**を対象パス限定で git restore する。
ブランケットな git stash は使わない(破棄前チェックリスト準拠)。

## Loop Attempts

(exec中に追記)

- attempt:
- changed:
- verification:
- result:
- next decision: continue / replan / stop

## Risks & Mitigations

- R1: working-context.md(HO)直接編集不可 → S2はapply-script方式([[HO適用スクリプトAI実行禁止]]: AIはdry-runのみ、実行は人間)
- R2: C-1拡張の二重定義 → plan-quality-checkを正本、review-self.mdは参照に統一

## Questions / Unknowns

- C-1検出の正本は plan-quality-check か review-self.md か(S3で確定)

## Mode判定

**モード**: high-risk
判定根拠: working-context.md(HO)を変更対象に含む → mode-classification「承認境界周辺→最低high」。
lite_eligible=false / Standard同期C-3固定 / autonomous APPROVE不可。
