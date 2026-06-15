# PBI INPUT PACKAGE — TASK-0130 (#544 Phase1)

> 由来: #544 Loop 安全制御 / 承認済み実行境界(AEE)。正本討議: rev.2 (PR#545 merged) + rev.3 §2.8 AEE (PR#560 merged)。
> 位置づけ: #544 の **Phase1 = plan 記述欄の明文化（ソフト強制）**。強制(Gate化)は Phase2 = #543/TASK-0129。

## Context / Why

PlanGate の plan を「承認済み実行境界(Approved Execution Envelope)」として強化する。
PlanGate は既に AEE の「機構」(plan_hash/EH-3/c3/forbidden_files/V-1/CONDITIONAL)を保有しているが、
plan 本体の「条項」(Loop Scope / Stop Condition / Resume Condition / Replan Triggers / Revert Policy /
Loop Attempts)が空白。本 PBI はこの条項欄を plan 正本に追加する。

**重要(honest framing)**: 本 Phase は「制御点の明文化」であって「強制」ではない。
未記入で承認不可にする hard gate は Phase2(#543)。本 PBI で「契約完成」と表現しない。

## What (Scope)

### In scope

- `docs/ai-driven-development.md` Prompt 1 の plan テンプレに条項セクションを追加:

  Loop Scope / Stop Condition / Resume Condition / Replan Triggers(機械値) / Revert Policy / Loop Attempts(最小ログ欄)

- Verification Automation の強化(既存セクション。実行コマンド明示・Stop Condition と連動の旨)
- `.claude/rules/working-context.md` の plan.md 必須要素リストに上記項目を追記
- C-1 セルフレビュー拡張: 「Stop Condition 記入」「Replan Triggers に機械値1つ以上」を検出(未記入で WARN)

  対象: `.claude/skills/plan-quality-check/SKILL.md` / `docs/working/templates/review-self.md`

### Out of scope

- 未記入で承認不可化(strict Gate) → #543/TASK-0129 (Phase2)
- 機械トリガーの実行層実装(codex-guarded.sh / doctor) → #527 配下
- Risk Budget / 自律度 → #487
- Loop Attempts ログの機械処理用スキーマ確定 → Phase3(別issue)

## 受入基準

| AC | 内容 |
|----|------|
| AC-01 | ai-driven-development.md Prompt1 に Loop Scope/Stop/Resume/Replan Triggers/Revert/Loop Attempts の条項欄が追加される |
| AC-02 | Verification Automation が「実行コマンド明示」として強化される(プロジェクト固有値は CLAUDE.md 注入/Rule4) |
| AC-03 | working-context.md の plan.md 必須要素に条項が追記される |
| AC-04 | C-1 に「Stop Condition 記入」「Replan Triggers 機械値1つ以上」の検出項目が追加される(Phase1は Stop/Replan の2点に絞り、残4条項の空欄検出は Phase2/3) |
| AC-05 | 各条項に「Phase1は明文化・強制はPhase2(#543)」の honest framing が併記される |
| AC-06 | Replan Rule が自己設置Gate非緩和原則と接続(/goal等で自動解除しない旨)を明記 |
| AC-07 | 全変更が承認境界整合: working-context.md(HO)含むため mode=high-risk・Standard同期C-3・lite_eligible=false を明記。HO適用は人間(apply-script) |

## Notes from Refinement

- rev.3 §3 の plan 記述スキーマをそのまま条項欄の元にする
- AEE 呼称: 対外は「承認済み実行境界」、「契約」は内部設計用語に留める(rev.3 §2.8)
- Stop-Work/機械トリガーの定義値は rev.3 §2.3 (変更ファイル2倍/+5・連続失敗3回・反復3回・plan外波及・AC変更)

## Estimation Evidence

### Risks / Unknowns

- working-context.md は HO → AI 直接編集不可の可能性([[HO常時block]]/TASK-0119)。仕様提示+apply-script方式が現実的
- C-1 拡張が plan-quality-check と review-self.md で二重定義にならないか

### Assumptions

- exec は人間 C-3 承認後。HO適用は人間。
- rev.2/rev.3 は merge 済正本として参照可能。
