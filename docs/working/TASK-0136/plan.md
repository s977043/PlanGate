# EXECUTION PLAN — TASK-0136 (#579)

## Goal
AI UI 実装前のデザインシステム準拠確認を、既存 `design-ui-addendum.md` の拡張で実現する。新ゲート/新 SKILL は作らず、不足 4 観点 + 提案扱いルール + UI 条件付き C-1 を追加。

## Constraints / Non-goals
- `docs/ai/design-ui-addendum.md` + `docs/working/templates/{plan,review-self}.md` のみ編集（HO 非該当）。
- `bin/plangate`（HO）の Addendum は触らない。正本記述は design-ui-addendum.md に置く。
- 新 `design-gate` SKILL/rule を作らない（既存と命名衝突）。DESIGN.md を一律必須化しない。gate 強制しない。River Review/Hermes は別リポジトリ scope。
- #578 / #581 と独立。

## Approach Overview（researcher 重複マッピング反映）
1. **design-ui-addendum.md 拡張**: 既存（visual reference / responsive / 視覚受入）の近くに不足 4 観点（states / design token / component 再利用+variant / a11y）+ 「未定義値は発明せず提案扱い」ルールを追記。
2. **plan.md**: 視覚設計セクション or Verification 近くに is_ui_task 条件付きの UI チェック注記。
3. **review-self.md**: `C1-UI-01`（is_ui_task 時のみ: states/token/component/a11y/提案扱い を確認）を 1 項目追加（条件付き・non-UI は N/A）。件数注記更新。

## Work Breakdown
- **S1** design-ui-addendum.md に 4 観点 + 提案扱いルール + DESIGN.md 参照方針を追記し、**design.md 視覚設計テーブルにも 4 観点を反映**（整合維持 / Refs R-001）/ Owner: agent / Risk: 既存記述との重複・design.md 旧項目残存 / rollback: git checkout -- docs/ai/design-ui-addendum.md docs/working/templates/design.md
- **S2** plan.md に is_ui_task 条件付き UI チェック注記 / Owner: agent / Risk: non-UI 過検出 / rollback: git checkout -- docs/working/templates/plan.md
- **S3** review-self.md に C1-UI-01（条件付き・N/A 許容）+ 件数注記 / Owner: agent / Risk: 既存項目重複 / rollback: git checkout -- docs/working/templates/review-self.md

## Files / Components to Touch
- `docs/ai/design-ui-addendum.md`（AI 可・HO 外）
- `docs/working/templates/plan.md`（AI 可・HO 外）
- `docs/working/templates/review-self.md`（AI 可・HO 外）
- `docs/working/templates/design.md`（AI 可・HO 外・視覚設計テーブルに 4 観点反映 / Refs R-001）
- 参照のみ: `bin/plangate` pbi-input Addendum（HO・触らない）/ `plugin/plangate/skills/design-gate/SKILL.md`（別物・触らない）

## Testing Strategy
- 機械: design-ui-addendum に states/token/component/a11y/提案扱い の grep、review-self に C1-UI-01 grep、新 SKILL/rule を作っていないこと（find）、markdownlint
- レビュー: 既存（visual reference/responsive/視覚受入）と重複ゼロ、is_ui_task 条件付き（non-UI 過検出なし）、DESIGN.md 一律必須化していない

## Risks & Mitigations
- R1 既存 Addendum と重複 / researcher マッピング準拠で新規 4 観点限定 / 重複時は参照化
- R2 design-gate SKILL と命名衝突 / 新 SKILL/rule 作らず Addendum 拡張 / 衝突回避を明記
- R3 non-UI 過検出 / is_ui_task 条件付き + N/A 許容 / 過検出時は条件強化

## Metrics Evidence
- 対象「変更ファイル」: 実数 3（design-ui-addendum + plan + review-self）/ 見積もり 3 / ratio 1.0 → 採用。

## Questions / Unknowns
- DESIGN.md 置き場所 → 存在時参照・無ければ既存パターン正（一律必須化しない）。

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 3（docs/ai + templates）→ standard
- 受入基準数: 5 → standard
- 変更種別: doc/テンプレ追記（既存 Addendum 拡張）
- 影響範囲: UI タスクの Plan/C-1（is_ui_task 条件付き）
- **最終判定**: standard。HO 非該当（design-ui-addendum.md + templates のみ・bin/plangate は触らない）→ exec は AI 可。autonomous APPROVE 可否は C-1 PASS + 影響が plan Files に閉じるかで判定（Security 観点なし）。
