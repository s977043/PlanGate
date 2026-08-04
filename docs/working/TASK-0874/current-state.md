# CURRENT STATE — TASK-0874

- **フェーズ**: exec 完了（**T-1 〜 T-41**）→ 残りは T-42 〜 T-44（issue 反映・予約起票）と PR / C-4
- **branch**: `feat/task-0874-exec`（worktree `plangate-wt-0874exec`・base `origin/main` = `a667c0d`）
- **code HEAD**: `52bd791`（R2 敵対レビューの major 2 件 = MJ-3 / MJ-5 を反映）
- **Mode**: critical（C-3 APPROVED 済み・`approvals/c3.json` は未 commit の承認記録）
- **直近の検証**（`52bd791` 実測 / いずれも exit 0）:
  `sh tests/run-tests.sh </dev/null` = **523 passed / 0 failed** /
  `test_run_evidence.py` **80 tests OK** / `test_run_evidence_verify.py` **32 tests OK** /
  `ta-60` pass=9 fail=0 / 不変 7 ファイル + `ai-loop-runs/` + `tests/run-tests.sh` の
  `git diff --stat origin/main` = **0 行** / `git diff --quiet -- plugin/plangate/` clean

## 次にやること

1. **T-38 / T-39 の artifact 配置**: 敵対レビュー R1 / R2 のレポートを
   `docs/working/TASK-0874/evidence/` へ格納し todo のチェックを閉じる
   （レビュー自体は実施済み・R2 指摘は反映済み。**完了判定が artifact の存在**のため未了扱い）
2. **T-42**: issue #874 への DoD コメント（4 link + **close 条件未達**の明記 +
   **routing 実カバレッジ 0** の併記が必須）
3. **T-43**: #870 への evidence link
4. **T-44**: `schemas/` 昇格 PBI の予約起票（起票のみ・HO patch の適用は Human-owned）
5. PR 作成 → **C-4**（merge は Human-owned / NO MERGE BY AI）

## ブロッカー

- なし（T-42 〜 T-44 は `gh` 実行権限を持つ担当者が実施）

## 注意

- `scripts/ai-loop/*.py` または `docs/workflows/ai-loop/*.md` を変更したら
  **`sh scripts/sync-plugin-plangate.sh` の再実行が必須**（CI が drift を検出する）
- `docs/working/TASK-0874/approvals/c3.json` は **commit しない**（`git add -A` 禁止）
- `docs/working/TASK-0874/plan.md` は **編集禁止**（`plan_hash` で c3.json に束縛）
