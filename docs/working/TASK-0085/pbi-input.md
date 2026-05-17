---
task_id: TASK-0085
artifact_type: pbi-input
schema_version: 1
status: draft
---
# PBI INPUT PACKAGE — TASK-0085
> #230 PBI-HI-014: Gate Event Normalization（v8.8.0 / light）

## Context / Why
#229 で導入した gate_id/phase の語彙が未定義だと #231 Dogfooding Eval の
judge が gate を識別できない。C-3/V-1/C-4/handoff の status 表現が揺れ横断
分析不可。既存 vocabulary は壊さず正規化ルールを docs に明文化する。

## What — Scope
### In scope
- `docs/ai/gate-event-normalization.md` 新規（正本）:
  - Gate event / 非 Gate event の判定ルール
  - gate_id 命名規則（C-3/C-4/V-1〜V-4/L-0/handoff/EH-1〜9/EHS-x）
  - phase 許容値 ↔ WF/Gate 対応表（schema 1.1 と一致）
  - status 正規化マップ（verdict/hook_result/c3_status → pass/fail/conditional/
    skipped/bypassed）
- privacy-safe sample/fixture 追加（forbidden field 不混入・#202 準拠）
- 既存 Metrics v1 event の後方互換維持（schema 変更は最小・additive のみ）

### Out of scope
- Hook での Gate 強制実装 / Orchestrator 不変条件の実行強制
- multi-judge / distributed tracing 準拠
- #231 Dogfooding Eval 本体（本正規化を judge 入力に使う・別 PBI）

## Acceptance Criteria
- [ ] AC-1: `docs/ai/gate-event-normalization.md` に gate_id/phase/status 正規化ルールが明文化
- [ ] AC-2: schema 1.1 の gate 関連 field（gate_id pattern / phase enum / verdict / hook_result）と一致
- [ ] AC-3: status 正規化マップ（既存 verdict/hook_result → pass/fail/conditional/skipped/bypassed）が定義
- [ ] AC-4: privacy-safe fixture が追加され #202 forbidden field 不混入（EH-8 整合）
- [ ] AC-5: 既存 Metrics v1 event 後方互換（schema 破壊なし・regression テスト合格）
- [ ] AC-6: #229 Trace Timeline / #228 評価項目 と矛盾しない（整合）
- [ ] AC-7: 既存 hook/CLI テスト回帰なし

## Notes from Refinement
- gate_id pattern は #229 で `^[A-Za-z0-9._:-]{1,64}$` 確定済→命名規則を明文化
- status 正規化は既存 enum を壊さず「正規化ビュー」を定義（mapping table）

## Estimation Evidence
**Risks**: 正規化が既存 enum と矛盾→mapping で吸収・schema は不変。
**Unknowns**: なし（語彙は schema 1.1 で確定）。Mode=light
