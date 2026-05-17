---
task_id: TASK-0085
artifact_type: test-cases
schema_version: 1
status: draft
---
# TC — TASK-0085
| AC | TC |
|----|----|
|AC-1|TC-1| 
|AC-2|TC-2|
|AC-3|TC-3|
|AC-4|TC-4|
|AC-5|TC-5|
|AC-6|TC-6|
|AC-7|TC-7|
- TC-1: gate-event-normalization.md に gate_id命名/phase対応表/status正規化が存在
- TC-2: phase 対応表が schema 1.1 phase enum と一致 / gate_id 命名が pattern 準拠
- TC-3: status 正規化マップ（APPROVED→pass, CONDITIONAL→conditional, REJECTED→fail,
  BYPASS→bypassed, SKIP→skipped 等）が定義
- TC-4: fixture が schema valid・#202 forbidden field（prompt全文/secret等）不在
- TC-5: 既存 Metrics v1 sample event が schema で valid（後方互換・回帰なし）
- TC-6: #229 timeline / #228 5項目 と矛盾しない（参照整合）
- TC-7: hook 78/0・CLI 64/0
## Edge
- E1: 未知 gate_id は pattern OK でも「未正規化」分類（正規化表で明示）
- E2: status 正規化は元 enum を破壊せず「ビュー」（mapping のみ）
