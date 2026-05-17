---
task_id: TASK-0084
artifact_type: plan
schema_version: 1
status: draft
---
# EXECUTION PLAN — TASK-0084 Trace Timeline v1（#229・standard）

## Goal
events schema を 1.1 additive 拡張 + metrics --timeline --json（experimental）。
1.0 完全後方互換・破壊なし。

## Constraints / Non-goals
- additive のみ（schema_version enum / 既存 props・enum 値 不変・追加のみ）
- additionalProperties:false / Privacy(#202) 維持
- #230/#231/trace_id 等は Non-goal・README/quickstart 非掲載

## Work Breakdown
| Step | 内容 | Output | Risk | 🚩 |
|------|------|--------|------|----|
| S1 | 現状調査: schema/metrics_reporter/timeline既存/schema-validate CI | メモ | low | - |
| S2 | schema: schema_version enum["1.0","1.1"] + gate_id/parent_event_id + phase enum WF/handoff additive | schema差分 | med | 🚩AC-1,2,4 |
| S3 | metrics --timeline --json（phase/gate/ts 正規化出力） | bin/plangate+script | med | 🚩AC-3 |
| S4 | experimental 表記（metrics.md+CLIヘルプ・README非掲載） | docs差分 | low | 🚩AC-5,6 |
| S5 | 後方互換+回帰（1.0 event valid・reporter/schema-validate/hook/CLI） | テスト | med | 🚩AC-7 |
| V | V-1 / V-3（standard Codex+Gemini） | レビュー | med | - |

## Files
- schemas/plangate-event.schema.json / bin/plangate(cmd_metrics) /
  scripts/metrics_timeline.py(新規 or reporter拡張) / docs/ai/metrics.md /
  tests/（後方互換 TC）

## Testing Strategy
- 1.0 sample event を 1.1 schema で validate → valid（後方互換）
- 1.1 event（gate_id/parent_event_id/phase=WF-05）validate → valid
- additionalProperties:false（未知キー reject）/ Privacy forbidden 不混入
- --timeline --json が ts/phase 順で出力 / schema-validate CI green / hook 78 CLI 64
- README/quickstart grep で timeline 非掲載

## Risks & Mitigations
- R1: enum 破壊 → const→enum は 1.0 を含むので後方互換。phase は値追加のみ
- R2: reporter regression → schema 1.1 を読めることをテスト

## Mode判定
**モード**: standard（schema/CLI/docs 跨ぐが additive・破壊 migration なし。V-3 実施/V-4スキップ）
