# TASK-0917 INDEX

> Issue: [#917](https://github.com/s977043/plangate/issues/917)（P0 / enhancement / ai-loop）/ EPIC [#870](https://github.com/s977043/plangate/issues/870)（close blocker）
> 由来: [#873](https://github.com/s977043/plangate/issues/873) / TASK-0873 の V2 送り分（実 PR 収束系）
> 基点: `origin/main` = `b45ab17`
> Mode: **critical**（`lite_eligible=false` / 人間 C-3 詳細レビュー必須 / V-4 実行対象）
> 現在フェーズ: **exec 完了 / V-1 PASS（FAIL 0）** — T-1〜T-51 実装完了、敵対レビュー R1/R2/R3 の critical 10 / major 15 を全件是正、T-35/T-36 の実 PR 1 周も実施済み。残るは **C-4（PR レビュー・マージ）と検証用 PR #940 の後片付け**（いずれも Human-owned）
> plan 承認: **C-3 APPROVED**（2026-07-30T23:26:43Z・`plan_hash` = `sha256:f72077a3…86cc29`）

| ファイル | 状態 |
|----------|------|
| [pbi-input.md](./pbi-input.md) | ✅（2026-07-30・`R-001`〜`R-016` 反映済み） |
| [review-external.md](./review-external.md) | ✅ pbi 段階（`R-001`〜`R-016`）+ C-2 plan 段階（`R-017`〜`R-033`・2 レーン）+ **PR 直前 River Review（`RR-01`〜`RR-08` / `R-034`・`R-035`）** 集約・全件処理済 |
| [plan.md](./plan.md) | ✅ B-3 生成（2026-07-31） |
| [todo.md](./todo.md) | ✅ B-3 生成 |
| [test-cases.md](./test-cases.md) | ✅ B-3 生成 |
| [review-self.md](./review-self.md) | ✅ C-1 25 項目（FAIL major 1 → `F-1`〜`F-5` 是正で **PASS**） |
| [current-state.md](./current-state.md) | ✅（2026-07-31 07:45 時点のスナップショット） |
| [approvals/c3.json](./approvals/c3.json) | ✅ **C-3 APPROVED**（Human・`plangate approve --force` で再発行。`R-034` / `R-035` 反映後の `plan_hash` と一致。Questions / Unknowns は **10 件**） |
| [decision-log.jsonl](./decision-log.jsonl) | ✅ B-1 / B-2 / B-3 / C-2 / C-1 / C-3 + **exec 期の裁定**（append-only） |
| [status.md](./status.md) | ✅ フェーズ履歴 + **計画からの変更点 9 件** |
| [handoff.md](./handoff.md) | ✅ WF-05 完了資産（必須 6 要素） |
| [evidence/e2e/](./evidence/e2e/) | ✅ AC-4 / TC-11（実 PR #940 への 1 周実走・25 ファイル） |
