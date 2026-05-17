---
task_id: TASK-0083
artifact_type: test-cases
schema_version: 1
status: draft
---
# テストケース — TASK-0083
| AC | TC |
|----|----|
| AC-1 | TC-1 | 
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5 |
| AC-6 | TC-6 |
| AC-7 | TC-7 |
- TC-1: run-outcome-review.md に5必須セクション（目的達成/失敗手戻り/再利用判断/効いたskill-gate-artifact/1人運用負荷）が存在
- TC-2: 実 TASK ベース記入例 ≥1
- TC-3: 冒頭に handoff との責務違い明記
- TC-4: templates/README.md に optional artifact 記載
- TC-5: 必須化文言なし（任意導入・後方互換）
- TC-6: 5項目が retro-phase.md §2 / 06_retro.md と文言一致
- TC-7: hook 78/0・CLI 64/0 不変
## Edge
- E1: handoff.md と重複しない（責務違いで切り分け）
- E2: WF-06 が本テンプレを参照しても循環参照にならない
