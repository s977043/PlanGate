# C-2 外部レビュー（Codex）— TASK-0133 (#567)

レビュア: Codex (gpt-5.5) / レーン: 設計妥当性 / verdict: CONDITIONAL（major 2 / minor 1 / critical 0）

| R-NNN | severity | 内容 | status | reflected_in | notes |
|-------|----------|------|--------|--------------|-------|
| R-001 | major | brainstorming 正本は `.agents/skills/`（AGENTS.md）。`.claude/skills` のみは反映漏れ | reflected | (this branch) | 正本を .agents/skills に変更・他3箇所ミラー同期 |
| R-002 | major | TC が名前 grep のみで `[{option,rationale}]` 構造未検証 | reflected | (this branch) | TC-01 拡張 + TC-06 jq parse 追加 |
| R-003 | minor | pbi-input fallback の検証が todo/test に無い | reflected | (this branch) | T4/TC-04 に fallback 確定条件明記 |

## 反映方針
1 回確定反映。簡易 C-1 → 人間 C-3（standard・スキーマ変更）→ exec。
