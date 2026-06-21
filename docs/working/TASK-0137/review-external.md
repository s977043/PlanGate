# C-2 外部レビュー（Codex）— TASK-0137 (#581 残要素3/4)

レビュア: Codex (gpt-5.5) / レーン: 設計妥当性 / verdict: CONDITIONAL（critical 0 / major 1 / minor 2）

## 指摘一覧（追記専用）
| R-NNN | severity | 内容 | status | reflected_in | notes |
|-------|----------|------|--------|--------------|-------|
| R-001 | major | todo T2 の files が AC-01 の 4 テンプレを完全列挙せず（report/review-package 欠落） | reflected | (this branch) | T2 files に 4 テンプレ全列挙 |
| R-002 | minor | `plugin/plangate/rules/* は未tracked` 表現が誤解招く（tracked ファイルも複数ある） | reflected | (this branch) | 「指定 3 ファイルは本ツリー不在のため対象外・既存 tracked rules も編集しない」へ訂正 |
| R-003 | minor | high-risk 根拠の変更ファイル数が不整合（実際 9・plan は約 7） | reflected | (this branch) | 実数 9 に訂正 |

## Codex 補足（採用）
- HO 回避（review-principles.md/qa-reviewer.md 参照のみ・追加は skill/template 側）は §7-bis「5 観点不変」と整合。dispatch=ブリーフ/進捗・evidence=証跡の責務分離も妥当。high-risk・人間 C-3 必須も妥当。

## 反映方針
1 回確定反映（本コミット）。簡易 C-1 → 人間 C-3（high-risk）→ exec。
