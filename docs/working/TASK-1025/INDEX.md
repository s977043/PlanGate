# TASK-1025 INDEX

> Issue: [#1025](https://github.com/s977043/PlanGate/issues/1025) / Epic [#870](https://github.com/s977043/PlanGate/issues/870)
> 基点: `origin/main` = `48f69713f2b651e6788bf075d64628630c74fad4`（2026-08-12 merge 済み）
> Mode: **critical**（`lite_eligible=false` / ai-loop判定基盤carve-out）
> 現在フェーズ: **BLOCKED ON C-2 ROUND 9**。base drift（#1046 / #1042）由来の R-135〜R-137 を 1 回確定反映し C-1 Round 9 PASS。**C-2 Round 8 APPROVE は plan hash 変更で supersede**。production変更は0ファイル。

| ファイル | 状態 |
|---|---|
| [pbi-input.md](./pbi-input.md) | ✅ Issue #1025 AC-01〜AC-10 |
| [plan.md](./plan.md) | ✅ SHA-256 `8b0a5018aa…49c55`（旧 `c864c06ab1…9d516`） |
| [todo.md](./todo.md) | ✅ T-01〜T-26 / H-01〜H-02 |
| [test-cases.md](./test-cases.md) | ✅ TC-01〜TC-46（Round 1〜4 findings + R-135 反映） |
| [review-self.md](./review-self.md) | ✅ C-1 Round 9 PASS（Round 8 は Historical） |
| [review-external.md](./review-external.md) | ⏳ Round 2〜8 保存 + C-4 base drift review（R-135〜R-137）。**Round 9 未実施＝live `C2-VERDICT:` 不在（fail-closed）** |
| [decision-log.jsonl](./decision-log.jsonl) | ✅ B-1〜B-3 / C-2 reject履歴 / R5〜R8 refinement / latest main reconciliation / C-1 Round 8 PASS / C-2 Round 8 APPROVE |
| [current-state.md](./current-state.md) | ✅ 現在状態 |
| [status.md](./status.md) | ✅ フェーズ履歴 |
| `approvals/c3.json` | ⏳ Human C-3待ち（AI生成禁止） |
