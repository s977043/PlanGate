# PBI INPUT PACKAGE — TASK-0133 (#567)

## Context / Why
agent-skills 取り込み検討の軽微ギャップ。brainstorming skill は 3案提示→比較→推奨を実装済だが、「不採用2案それぞれの rejection 理由」を構造化記録できない。decision-log には `alternatives:string[]`（検討案一覧）と `reason`（採用理由）はあるが、各不採用案の個別理由を持たない。現状 pbi-input.md Notes に手動記録。

## What (Scope)
### In scope（Codex 助言）
- decision-log スキーマに `alternatives_rejected:[{option,rationale}]` を **additive 追加**（後方互換・任意フィールド）
- brainstorming skill に「採用案決定時の不採用理由記録」規約を追記（必須は high-risk/critical/human decision のみ）
- pbi-input.md Notes を「decision-log に記録済み」参照・要約に縮退する旨を規約化

### Out of scope
- `alternatives` の破壊的変更（object[] 化しない）
- `schemas/` への JSON schema 実体新設（正本は markdown のまま）
- 全 mode 必須化（儀式化回避）
- #565 / #566

## 受入基準
- AC-01: decision-log-schema.md に `alternatives_rejected:[{option,rationale}]` が任意フィールドとして追加され、既存フィールドは不変
- AC-02: brainstorming skill に不採用理由の記録規約（タイミング・必須条件）が追記されている
- AC-03: pbi-input Notes と decision-log の正本関係（decision-log が正本）が明記されている
- AC-04: 既存 decision-log エントリ（alternatives_rejected 無し）が引き続き valid（後方互換）

## Estimation Evidence
- Risks: schema は additive で非破壊。承認境界外（templates/ + .claude/skills/ = HO 対象外・AI 編集可）。
- Unknowns: rationale の粒度（自由文 vs 構造）→ 初回は自由文。
- Mode 見込み: **standard**（変更2-3ファイル・additive）。ただし「スキーマ変更」のため安全側で **autonomous APPROVE 不可・人間 C-3** とする。
