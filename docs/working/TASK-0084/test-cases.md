---
task_id: TASK-0084
artifact_type: test-cases
schema_version: 1
status: draft
---
# TC — TASK-0084
| AC | TC |
|----|----|
|AC-1|TC-1|
|AC-2|TC-2|
|AC-3|TC-3|
|AC-4|TC-4,TC-5|
|AC-5|TC-6|
|AC-6|TC-7|
|AC-7|TC-8|
- TC-1: schema_version "1.1" + gate_id/parent_event_id/phase=WF-05 の event が valid
- TC-2: 既存 schema_version "1.0" event（gate_id等なし）が 1.1 schema で valid（後方互換）
- TC-3: `metrics <TASK> --timeline --json` が ts/phase 昇順正規化 JSON 出力
- TC-4: additionalProperties:false（未知キー含む event を reject）
- TC-5: Privacy(#202) forbidden field（prompt 全文等）が schema/sample/output に無い（EH-8）
- TC-6: metrics.md + CLI ヘルプに "experimental"
- TC-7: README/README_en/quickstart に timeline 記載なし（grep 0）
- TC-8: schema-validate CI / metrics_reporter / hook 78 / CLI 64 回帰なし
## Edge
- E1: phase 既存値(A,C-3,V-1...)も引き続き valid（additive）
- E2: schema_version 欠落は従来どおり required で reject
