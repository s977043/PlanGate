# INDEX — TASK-0907

> ai-loop 適用ドメイン拡張（rollout-policy Phase 1 更新）

| 項目 | 値 |
|------|-----|
| Issue | [#907](https://github.com/s977043/plangate/issues/907) |
| EPIC | [#870](https://github.com/s977043/plangate/issues/870) |
| Mode | critical（lite_eligible=false・同期 C-3 固定） |
| 現在フェーズ | plan 正式化（B 完了 → C-1 へ） |
| base | main `3b987a1` |

## ファイル
- pbi-input.md — A: PBI INPUT PACKAGE（Human 決定 verbatim 済み）
- plan.md — B: EXECUTION PLAN（案 C 採用・Metrics Evidence 4 ファイル）
- todo.md — B: EXECUTION TODO（T1〜T8 + H1〜H3）
- test-cases.md — B: TC-1〜5 + EC-1〜3
- decision-log.jsonl — B〜: 判断履歴（append-only）
- review-self.md — C-1（次）
- review-external.md — C-2（次）

## 次アクション
C-1 セルフレビュー（17 項目）→ C-2 外部レビュー 2 レーン → C-3 Human APPROVED → `bin/plangate approve TASK-0907` → PR → HO patch 適用 → C-4。その後 `/ai-loop-workflow run TASK-0907`（HUMAN_ESCALATED 実証）。
