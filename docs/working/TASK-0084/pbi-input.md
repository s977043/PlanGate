---
task_id: TASK-0084
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0084

> #229 PBI-HI-013: Trace Timeline v1（Experimental・schema 1.1 additive / v8.7.0 / standard）

## Context / Why

Run Outcome Review(#228) の補助として観測データを後付け紐付けする基盤。
events.ndjson を schema_version 1.1 へ additive 拡張し TASK 単位 timeline JSON を
experimental で出力。quickstart 非掲載・debug/audit 限定（自己進化を OSS に
押し付けない方針）。

## What — Scope

### In scope

- `schemas/plangate-event.schema.json`: `schema_version` を **enum ["1.0","1.1"]**
  へ（1.0 後方互換維持）。additive 追加（optional top-level）:
  - `gate_id` (string, optional) / `parent_event_id` (string, optional)
  - `phase` は既存（1.1 で WF-01〜06 / handoff を enum に additive 拡張）
  - `additionalProperties: false` と Metrics Privacy(#202) 維持
- `bin/plangate metrics <TASK> --timeline --json`: phase/gate/ts 順に正規化した
  timeline JSON を出力（experimental）
- experimental 表記: `docs/ai/metrics.md` + CLI ヘルプ。README/quickstart **非掲載**
- 既存 schema 1.0 event が 1.1 でも valid（後方互換テスト）+ reporter regression なし
- EH-8 privacy: forbidden field が schema/sample/output に無いこと

### Out of scope

- trace_id / artifact_refs / policy_refs（v8.8.0 判断）
- Gate Event Normalization（#230・v8.8.0）/ Dogfooding Eval（#231）
- Markdown timeline / dashboard / OTel 準拠

## Acceptance Criteria

- [ ] AC-1: schema が schema_version "1.0"/"1.1" を受理し gate_id/parent_event_id が optional top-level・phase enum に WF/handoff additive 追加
- [ ] AC-2: 既存 1.0 event が 1.1 schema で valid（後方互換・回帰なし）
- [ ] AC-3: `bin/plangate metrics <TASK> --timeline --json` が phase/gate/ts 順正規化 JSON 出力
- [ ] AC-4: additionalProperties:false 維持・Privacy(#202) forbidden field 不混入（EH-8）
- [ ] AC-5: metrics.md + CLI ヘルプに **experimental** 表記
- [ ] AC-6: README / README_en / quickstart に非掲載（experimental 隠蔽保持）
- [ ] AC-7: metrics_reporter / schema-validate CI 回帰なし・hook/CLI テスト不変

## Notes from Refinement

- 3 fields のうち phase は既存＝実質追加は gate_id/parent_event_id + phase enum 拡張
- gate_id 命名規則は本 PBI で最小固定（正規化は #230 v8.8.0）
- experimental＝quickstart 非掲載が OSS 利用者への明確メッセージ

## Estimation Evidence

**Risks**: optional 運用増で将来破壊的変更 → 3 fields 厳守・experimental 明記
**Unknowns**: gate_id 命名（最小固定・#230 で正規化）
**Assumptions**: additive のみ・破壊的 migration なし。Mode=standard
