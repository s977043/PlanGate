---
task_id: TASK-0086
artifact_type: test-cases
schema_version: 1
status: draft
---
# TC — TASK-0086
| AC | TC |
|----|----|
|AC-1|TC-1|
|AC-2|TC-2|
|AC-3|TC-3|
|AC-4|TC-4|
|AC-5|TC-5|
|AC-6|TC-6|
|AC-7|TC-7|
- TC-1: `bin/plangate eval --dogfood <fixture TASK>` 動作・5項目 PASS/FAIL/PARTIAL 判定
- TC-2: `docs/working/<TASK>/eval-dogfood.md` が rationale 付き markdown で生成
- TC-3: fixture 3件（sample-task 系）で eval-dogfood サンプルが残る
- TC-4: judge ロジックに作者 repo specific パス前提が無い（汎用 TASK ディレクトリ走査）
- TC-5: judge-prompt が #228 run-outcome-review 5項目と整合（doc 突合）
- TC-6: #229 timeline JSON を入力として読む経路あり / #230 gate-event-normalization 参照
- TC-7: 既存 `eval <TASK>`（8-aspect）出力不変・hook 78/0・CLI 64/0
## Edge
- E1: handoff/events 欠落 TASK → 該当項目 FAIL + rationale に欠落明記（落とさない）
- E2: #230 未マージ環境でも --dogfood 自体は動作（正規化参照は doc・降格しない）
