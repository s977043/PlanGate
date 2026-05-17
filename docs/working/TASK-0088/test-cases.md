# テストケース — TASK-0088 / #226
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | "Phase 0"〜"Phase 3" 各見出し + モード/エージェント/フック記述 | 構造突合 |
| T2 | AC2 | 各 Phase に "使わなくてよいもの" 行 ×4 | 構造突合 |
| T3 | AC3 | "フック有効化の推奨順序" 表に EH-1 と EHS が出現 | 構造突合 |
| T4 | AC4 | "エージェント最小セット" 表に 0/2/4/〜23 体記述 | 構造突合 |
| T5 | AC5 | plangate.md に staged-adoption-guide リンク | 構造突合 |
## Edge
- E1: 参照する hook 名（check-plan-exists.sh）が hook-enforcement.md に実在
