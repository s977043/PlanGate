# TASK-0917 INDEX

> Issue: [#917](https://github.com/s977043/plangate/issues/917)（P0 / enhancement / ai-loop）/ EPIC [#870](https://github.com/s977043/plangate/issues/870)（close blocker）
> 由来: [#873](https://github.com/s977043/plangate/issues/873) / TASK-0873 の V2 送り分（実 PR 収束系）
> 基点: `origin/main` = `b45ab17`
> Mode: **critical**（`lite_eligible=false` / 人間 C-3 詳細レビュー必須 / V-4 実行対象）
> 現在フェーズ: **C-3 APPROVED（再承認済み・2026-07-30T23:26:43Z）** — PR 作成直前の River Review = FAIL を `R-034` / `R-035` で反映後、`plan_hash` = `sha256:f72077a3…86cc29` で再発行し現 `plan.md` と一致 → PR 作成 → C-4 → exec

| ファイル | 状態 |
|----------|------|
| [pbi-input.md](./pbi-input.md) | ✅（2026-07-30・`R-001`〜`R-016` 反映済み） |
| [review-external.md](./review-external.md) | ✅ pbi 段階（`R-001`〜`R-016`）+ C-2 plan 段階（`R-017`〜`R-033`・2 レーン）+ **PR 直前 River Review（`RR-01`〜`RR-08` / `R-034`・`R-035`）** 集約・全件処理済 |
| [plan.md](./plan.md) | ✅ B-3 生成（2026-07-31） |
| [todo.md](./todo.md) | ✅ B-3 生成 |
| [test-cases.md](./test-cases.md) | ✅ B-3 生成 |
| [decision-log.jsonl](./decision-log.jsonl) | ✅ 初期化済み（B-1 / B-2） |
| [review-self.md](./review-self.md) | ✅ C-1 25 項目（FAIL major 1 → `F-1`〜`F-5` 是正で **PASS**） |
| [current-state.md](./current-state.md) | ✅（2026-07-31 07:45 時点のスナップショット） |
| [approvals/c3.json](./approvals/c3.json) | ✅ **C-3 APPROVED**（Human・`plangate approve --force` で再発行。`R-034` / `R-035` 反映後の `plan_hash` と一致。Questions / Unknowns は **10 件**） |
| status.md | ⏳ exec 以降 |
| handoff.md | ⏳ WF-05 |
| evidence/e2e/ | ⏳ AC-4（実 PR 手動実走の証跡） |
