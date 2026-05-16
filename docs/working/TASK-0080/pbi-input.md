---
task_id: TASK-0080
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0080

> TASK-0071 S1+S2 実装スライス（Governance Hardening 第1弾）
> 起源: TASK-0071（#244 マージ済・D-1 で S1+S2/S3/S4 の3分割確定）
> 本セッション通底の AC-8 / Shadow Configuration 摩擦の恒久対処

## Context / Why

TASK-0071（#244）で Governance Hardening を計画・C-1/C-2 済、D-1 で
**S1+S2 / S3 / S4 の3分割**を C-3 決定。本 PBI は第1スライス **S1+S2**:

- **S1 Manual Gate + Shadow Config ロック**: `.claude/settings*.json` は
  Claude 自己改変ガードで AI 編集不可（本セッションで AC-8 wiring が
  繰り返しユーザー手動依存になった根因）。AI が「適用済み」と誤認する
  Shadow Configuration リスク（Gemini critical 指摘）を構造的に解消する
- **S2 settings drift check（CI required）**: settings 正本とリポジトリ実体の
  乖離を機械検出（手動適用依存下では乖離＝脆弱性）

依存（plan 明記「exec着手は #242/#243 マージ後」）は充足済み。

## What — Scope

### In scope（S1+S2 のみ）

- **S1a**: settings パッチ正本を `docs/ai/` 配下に配置 + 適用 script
  （`scripts/apply-claude-settings.sh` 等。ユーザーが実行する手順を script 化）
- **S1b**: `bin/plangate doctor --check-settings`（wiring 適用判定。
  `.claude/settings*.json` が期待 wiring を含むか検証、未適用なら非0 fail）
- **S1c**: タスクロック — doctor --check-settings 未 PASS の場合
  handoff/V-1 完了を不可にする機構（Shadow Config 防止＝AI が適用済みと
  誤認して完了扱いするのを阻止）
- **S2**: CI に settings drift check を **required** で追加
  （wiring 未適用 + 既知 schema 不整合を検出し fail）

### Out of scope

- S3（EH-3 メンテモード / SKIP_REASON）= TASK-0071 第2スライス（S3a の
  C-3 3点確定が前提・別 PBI）
- S4（責務4分類 rules 正本化）= TASK-0071 第3スライス（別 PBI）
- `.claude/settings*.json` 自体への wiring 適用（self-mod ガードで AI 不可・
  本 PBI は「適用 script + 検証 + ロック」を提供。適用はユーザー実行）
- F5-AD（#253 マージ済）/ #213

## Acceptance Criteria

- [ ] AC-1: settings パッチ正本（期待 wiring の定義）が docs/ai/ 配下に配置される
- [ ] AC-2: 適用 script が提供され、ユーザーが 1 コマンドで wiring 適用できる
- [ ] AC-3: `bin/plangate doctor --check-settings` が wiring 適用状態を判定し、未適用なら非0 で明示 fail する
- [ ] AC-4: タスクロック — doctor --check-settings 未 PASS で handoff/V-1 を完了扱いにできない（Shadow Config 防止）機構が定義・実装される
- [ ] AC-5: CI に settings drift check が required で追加され、wiring 未適用/schema 不整合で fail する
- [ ] AC-6: 既存挙動不変（settings 適用済み環境では doctor PASS・既存 hook テスト回帰なし）
- [ ] AC-7: TASK-0071 handoff/INDEX が S1+S2 完了・S3/S4 残として更新される

## Notes from Refinement

- 設計正本: docs/working/TASK-0071/plan.md（S1a〜S2）+ S3a は本 PBI 対象外
- Gemini critical「Shadow Configuration」対策＝S1c タスクロックが中核
- self-mod ガードは恒久制約として受容（適用は script+ユーザー、AI は検証のみ）
- doctor は既存 `bin/plangate doctor`（v8.6.0 で 12 項目検査）への拡張

## Estimation Evidence

**Risks**: ガバナンス強制機構（タスクロック）追加。誤検出で正常完了を阻害
→ 適用済み環境で必ず PASS（AC-6）を回帰保証。doctor 非破壊拡張
**Unknowns**: タスクロックの実装層（hook / doctor / workflow 定義のどれで
強制するか）→ C-3 判断
**Assumptions**: settings 適用はユーザー実行（AI 不可）を前提に「script
提供+検証+ロック」で Shadow Config を構造解消。Mode 想定: critical
（ガバナンス強制・doctor/CI/ロック横断）
