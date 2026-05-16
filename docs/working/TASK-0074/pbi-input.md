---
task_id: TASK-0074
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0074

> F3: UI タスク条件付き Design/UI Addendum（Figma 有無で真実源分岐）
> 起源（field feedback）: #236

## Context / Why

デザイン/UI 改修 PBI を PlanGate で回すと「踏襲元が曖昧 / 配置・余白・
レスポンシブ期待値が言語化されない / 視覚的受入基準・回帰ガードが無い」
ため**追加指示の往復が多発**し、ゲート前段が重くなる。既存テンプレートは
ソフトウェアアーキ向けで UI 変更を構造的に取りこぼす。

真実源（source of truth）が決まっていないのが根因。Figma がある案件は
Figma を正、ない案件は既存パターンを正、と**環境で分岐**して固定すれば
追加指示なしで plan→実装まで確定できる。一律必須化は Figma なし案件で
ゲート回避を生むため、UI タスク条件付き・参照なしの明示逃げ道つきが要件。

## What — Scope

### In scope

- `bin/plangate init` の pbi-input テンプレートに **UI/デザインタスク
  条件付き Design/UI Addendum** セクションを追加（非 UI は削除可と明記）
- Addendum の必須フィールド:
  - 踏襲元の明示（真似る=X / 真似ない=Y・理由つき）★最優先・単独でも効果大
  - 配置仕様（前後要素・余白/間隔・できればデザイントークン名）
  - レスポンシブ・マトリクス（PC/SP・必要なら状態別）
  - 視覚的受入基準（要素有無・リンク先・崩れないこと）
  - 視覚的回帰ガード（変えてはいけない既存表示）
  - 視覚証跡（before/after・ビューポート別スクショ）
- **Figma 有無の分岐仕様**（真実源と受入証跡の取り方を変える）を spec 文書化
- UI タスク判定トリガ（どう「UI タスク」と判定するか）の定義
- design.md テンプレートに視覚設計セクションを追加（Addendum と整合）

### Out of scope

- Figma MCP 連携の実装（参照の必須化のみ。自動取得は別 PBI）
- スクショ自動取得・視覚回帰の自動化（証跡の構造化のみ）
- F1/F2/F4/F5

## Acceptance Criteria

- [ ] AC-1: pbi-input テンプレに UI 条件付き Design/UI Addendum が追加され、非UIは削除可と明記される
- [ ] AC-2: Addendum に踏襲元明示（X/not Y・理由）フィールドが**最優先項目**として存在する
- [ ] AC-3: 配置仕様 / レスポンシブ / 視覚受入基準 / 回帰ガード / 視覚証跡 の各フィールドが定義される
- [ ] AC-4: Figma 有無で真実源（Figma正 / 既存パターン正）と受入証跡が分岐する仕様が文書化される
- [ ] AC-5: UI タスク判定トリガが定義され、非UIタスクには Addendum を強制しない
- [ ] AC-6: 「参照なし」を明示選択できる（曖昧進行もゲート回避も防ぐ）
- [ ] AC-7: design.md テンプレに視覚設計セクションが追加され Addendum と整合する
- [ ] AC-8: 既存テンプレ生成（bin/plangate init）/ doc 整合性に回帰がない

## Notes from Refinement

- #236 で「踏襲元の明示」が単独最優先（似た既存ページ2つで誤踏襲→レイアウト崩壊を起票時1行で防げた事例）
- 一律必須化はゲート回避を生む → UI 条件付き + 参照なし逃げ道が必須
- 真実源分岐: Figma あり→Figma正(pixel/token は Figma 由来)、なし→既存パターン正
- F2 の「曖昧なまま進めない・ゲート回避もさせない」思想と一貫

## Estimation Evidence

**Risks**: テンプレ肥大で非 UI 認知負荷増 → 条件付き表示・削除可明記で緩和
**Unknowns**: UI タスク判定の自動/手動（plan メタ自動推定 vs 人手宣言）→ C-3
**Assumptions**: テンプレ/spec/doc 変更主体で強制 Hook 不要。Mode 想定: standard
