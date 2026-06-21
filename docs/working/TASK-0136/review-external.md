# C-2 外部レビュー（Codex）— TASK-0136 (#579)

レビュア: Codex (gpt-5.5) / レーン: 設計妥当性 / verdict: CONDITIONAL（critical 0 / major 2）

## 指摘一覧（追記専用）
| R-NNN | severity | 内容 | status | reflected_in | notes |
|-------|----------|------|--------|--------------|-------|
| R-001 | major | Addendum の観点を増やすと design.md テンプレが旧 7 項目のまま残るリスク | reflected | (this branch) | design.md を scope/Files/AC-01/T2/TC-01 に追加（整合維持） |
| R-002 | major | AC-05 の `find` 検証は既存 plugin/plangate/skills/design-gate/ で常にヒット | reflected | (this branch) | TC-05 を `git diff --diff-filter=A`（新規追加のみ）検証へ修正 |

## Codex 補足（採用）
- 新 SKILL/rule を作らず design-ui-addendum 拡張・命名衝突回避・bin/plangate 非改変(HO回避)・DESIGN.md 一律必須化回避・is_ui_task 条件付き は妥当。

## 反映方針
1 回確定反映（本コミット）。簡易 C-1 → 人間 C-3（standard）→ exec。
