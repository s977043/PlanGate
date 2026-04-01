---
name: plan-review-gate
description: "AI駆動開発フローの C-1 / C-2 / C-3 ゲートを確認し、exec 開始可否を判定する。Use when: plan レビュー通過済みか確認したい時。"
---

# Plan Review Gate

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.codex/manual-cloud-task.md`
4. `docs/working/STRATEGY-XXXX/review-self.md`
5. `docs/working/STRATEGY-XXXX/review-external.md`（存在すれば）
6. `docs/working/STRATEGY-XXXX/status.md`

## Checks

- `.codex/manual-cloud-task.md` に C-3 承認済みの内容が反映されているか
- `review-self.md` に FAIL が残っていないか
- `review-external.md` に critical な懸念が残っていないか
- `status.md` に C-3 承認済みの記録があるか
- `plan.md` `todo.md` `test-cases.md` が最新か

## Decision

- 1つでも未充足なら exec を始めない
- 不明点があれば status.md に追記候補を示す
- exec 可の場合のみ `manual-cloud-task` に進み、`.codex/manual-cloud-task.md` を更新する
