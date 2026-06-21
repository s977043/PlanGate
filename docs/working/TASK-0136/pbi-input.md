# PBI INPUT PACKAGE: Design Gate — AI UI 実装前のデザインシステム準拠確認 (#579)

> フェーズ A。正本: `.claude/rules/working-context.md`。

## Context / Why
AI に UI を任せると、色・余白・角丸・タイポ・状態設計を曖昧にしたまま「平均的な SaaS UI」に寄りやすい。実装前の Plan 段階でデザインシステム準拠の判断基準を明示したい。researcher 調査で既存 `design-ui-addendum.md`（#236）が真実源と判明したため、**新ゲートを作らず Addendum を拡張**し、不足観点のみ追加する（過剰実装・命名衝突回避）。

## What（Scope）

### In scope
- `docs/ai/design-ui-addendum.md` に**不足 4 観点**を追加:
  1. **states 網羅**: default / hover / focus / disabled / loading / error の必要状態チェック
  2. **design token**: 使用トークンの明示 + 不足トークンの要否確認
  3. **component 再利用**: 再利用候補コンポーネントの列挙 + new variant 要否
  4. **accessibility（UI 前提）**: キーボード / フォーカス / コントラスト等
- **未定義デザイン値の「提案」扱い**（勝手に発明しない / new token・variant は実装でなく提案として handoff・別 Issue へ分離。#578 と整合）を 1 行明文化
- `docs/working/templates/plan.md` / `review-self.md` に **is_ui_task 条件付き**チェック（UI タスク時のみ）を追加
- `docs/working/templates/design.md` の視覚設計テーブルに 4 観点（states / token / component 再利用 / a11y）を反映（Addendum と design.md の整合維持・旧 7 項目のまま残さない / Refs R-001）

### Out of scope
- 新 `design-gate` SKILL / `rules/design-gate.md` 新設（既存 design-gate SKILL は別物・混ぜない）
- `bin/plangate` の pbi-input Addendum 改変（**HO 回避**・Addendum 正本は design-ui-addendum.md 側に書く）
- DESIGN.md の**一律必須化**（存在すれば参照・無ければ既存パターンを正。Figma なし案件のゲート回避防止と矛盾するため）
- River Review `ui-design-system-compliance` / Hermes `frontend-design-system`（別リポジトリ scope）
- gate 機械強制

## 受入基準
- [ ] AC-01: design-ui-addendum.md **および design.md 視覚設計テーブル**に states(6種) / design token / component 再利用+variant / a11y の 4 観点が追加されている（整合維持・Refs R-001）
- [ ] AC-02: 「未定義デザイン値は発明せず提案扱い（handoff/別 Issue へ分離）」が明文化されている
- [ ] AC-03: plan.md / review-self.md に is_ui_task 条件付きチェックが追加されている（non-UI は認知負荷を上げない）
- [ ] AC-04: DESIGN.md は存在時参照・一律必須化しない旨が記載されている
- [ ] AC-05: 既存充足分（visual reference / responsive / 視覚受入）は重複追加せず、新 SKILL/rule を作らない（過剰実装なし）

## Notes from Refinement
researcher 調査（Explore 並列）の結論:
- 既存 design-gate SKILL は "NO CODE WITHOUT APPROVED DESIGN" のアーキ設計ゲートで #579（UI デザインシステム準拠）とは**別物**。名前衝突回避。
- design-ui-addendum.md + bin/plangate pbi-input Addendum + design.md 視覚設計表が真実源。**bin/plangate は HO のため触らず、addendum 側に追記**。

## Estimation Evidence
### Risks
- 既存 Addendum との重複 → researcher マッピング準拠で新規 4 観点に限定
- non-UI タスクへの過検出 → is_ui_task 条件付き
### Unknowns
- DESIGN.md の置き場所（存在しない）→ 一律必須化せず「存在すれば参照」
### Assumptions
- docs/ai/ + templates のみ変更（HO 非該当）→ C-3 後 AI exec 可
