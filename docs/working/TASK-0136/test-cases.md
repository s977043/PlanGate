# TEST CASES — TASK-0136 (#579)

## AC → TC
### AC-01: 4観点追加
- TC-01: design-ui-addendum.md **および design.md 視覚設計テーブル**に states(default/hover/focus/disabled/loading/error)・design token・component再利用/variant・accessibility の記述がある。種別: 機械（grep 両ファイル）
### AC-02: 提案扱いルール
- TC-02: 「未定義デザイン値は発明せず提案扱い（handoff/別Issue 分離）」が design-ui-addendum.md に明文化。種別: 機械（grep）
### AC-03: is_ui_task 条件付きチェック
- TC-03: review-self.md に `C1-UI-01`（is_ui_task 時のみ・N/A 許容）が存在 + plan.md に is_ui_task 条件付き UI 注記。種別: 機械（grep）
### AC-04: DESIGN.md 参照方針
- TC-04: DESIGN.md は「存在すれば参照・一律必須化しない」旨が記載。種別: レビュー+grep
### AC-05: 重複ゼロ・新SKILL/rule未作成
- TC-05: 既存（visual reference/responsive/視覚受入）と重複しない（直交）。新 design-gate SKILL/rule を作っていない（**`git diff --name-only --diff-filter=A origin/main` に design-gate 関連の新規追加ファイルが無い**こと。既存 plugin/plangate/skills/design-gate/ は baseline 除外 / Refs R-002）。種別: レビュー + 機械（git diff）

## Edge cases
- EC-01: non-UI タスク（is_ui_task=false）では C1-UI-01 は N/A（過検出しない）
- EC-02: DESIGN.md 不在時は既存パターンを正とする（ゲート回避防止）
- EC-03: new token/variant は実装でなく提案として分離（その場で発明しない）
