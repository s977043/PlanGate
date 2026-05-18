# テストケース — TASK-0104
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | grep '🔵 Open' docs/ai/harness-improvement-roadmap.md = 0 | 構造突合 |
| T2 | AC2 | 完了行に PR #NNN 付記（#264/#266/#263/#259/#267/#268/#269/#270/#260/#262/#261/#271/#272/#273/#274）| 構造突合 |
| T3 | AC3 | Status/Progress に EPIC #193 CLOSED / 全子 12/12 反映 | 構造突合 |
| T4 | AC4 | 本文・Phase 定義不変（git diff は状態列+ヘッダのみ）| diff |
## Edge
- E1: GitHub 実 state 全 CLOSED と一致（#194-204/#213/#193）
