# TASK-0108 review-external (C-2 proactive 外部レビュー集約)

> 追記専用・差分管理用。R-NNN は指摘 ID。reflected_in = 確定反映コミット。

## Sources

- C-2 proactive (2026-05-24): Codex (設計妥当性レーン) + Gemini (コードベース整合レーン)
- 経緯: TASK-0108 C-3 直前に Codex 推奨優先順 (本セッション) で proactive 外部レビュー実施

## 集約 (R-001..R-006)

| ID | Lane | Severity | 内容 | reflected_in | status |
|----|------|----------|------|--------------|--------|
| R-001 | 設計妥当性 (Codex) | major | AC-1 検証対象から docs/index.md (公開トップ) が抜けている。TC-01/02 も README + staged-adoption のみで 3 箇所統一 AC で誤判定リスク | _本コミット_ | reflected |
| R-002 | 設計妥当性 (Codex) | major | TC-08 外部レビュー判定プロトコル弱い。「同一プロンプト / 対象ファイル / APPROVE-CONDITIONAL-REJECT / major 0 + 未解決 conditional 0」まで固定 | _本コミット_ | reflected |
| R-003 | 設計妥当性 (Codex) | minor | #7 呼称統合: 既存 `docs/workflows/README.md` 対応表との重複解消が曖昧。glossary.md 正本 + workflows/README.md 参照切替を明記 | _本コミット_ | reflected |
| R-004 | コードベース (Gemini) | major | #7 呼称統合で `docs/plangate.md` `A`/`B`/`C`/`D` アンカー ID 維持必須。見出しは「`## A: PBI INPUT (WF-01/02)`」併記に留める | _本コミット_ | reflected |
| R-005 | コードベース (Gemini) | major | T-04 README 警告 box の markdownlint MD028 違反対策必須 (空行にも `> ` 含める) | _本コミット_ | reflected |
| R-006 | コードベース (Gemini) | minor | docs/index.md 「最初に読む 3 ページ」純度維持 — #5 When NOT to use / #6 Glossary は別セクション (`## Reference`) へ配置 | _本コミット_ (plan で方針確定、exec 時実装) | reflected |

## info / 採用しなかった指摘

- (Gemini) docs/staged-adoption-guide.md へのアンカーリンク具体化 → R-001 と統合
- (Codex) info: docs/ai/project-rules.md 改修は AC-5 で扱う (本 plan で out of scope 化しない)

## 反映方針

`.claude/rules/working-context.md` の review-external 差分管理 (#234-C) に従い、本コミットで pbi-input / plan / todo / test-cases / review-self を **1 回確定反映**。簡易 C-1 v2 を review-self.md に記録、blocker 0 で C-3 提出可。
