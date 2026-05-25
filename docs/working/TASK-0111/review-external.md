# TASK-0111 review-external (C-2 proactive 外部レビュー集約)

> 追記専用・差分管理用。R-NNN は指摘 ID。

## Sources

- C-2 proactive (2026-05-25): Codex (設計妥当性レーン) + Gemini (コードベース整合レーン)

## 集約 (R-001..R-007)

| ID | Lane | Severity | 内容 | reflected_in | status |
|----|------|----------|------|--------------|--------|
| R-001 (codex#1) | 設計 | major | `docs/pages/` 配置後の公開 URL 期待が不整合 (`/docs/pages/...` と `/pages/...` 混在)。**確定**: Pages source=`/docs` のため公開 URL は `/PlanGate/pages/...` (Jekyll permalink で `/docs/` prefix なし)。AC-4/TC-04 をこの前提に修正 | _本コミット_ | reflected |
| R-002 (codex#2) | 設計 | major | 旧 root `pages/` 互換方針が T-01 結果依存で未確定。**確定方針**: (i) git mv で完全移設、(ii) T-01 で外部参照 (issue/blog/comment) を grep、(iii) GitHub blob URL の旧 `pages/` 参照は #293 で既に `s977043/main` hardcode 済 → **本 PBI で全削除**、(iv) redirect stub は採用しない (Pages source=/docs のため root pages/ への HTTP redirect は GitHub Pages 制御外) | _本コミット_ | reflected |
| R-003 (codex#3) | 設計 | major | Jekyll build を Human optional ではなく **mandatory pre-C-3 gate** に格上げ。`bundle exec jekyll serve` で /docs/pages/ 各 link が 200 OK を確認するまで C-3 ゲート進めない | _本コミット_ | reflected |
| R-004 (codex#4) | 設計 | minor | TC-02 が `docs/index.md` 限定 → 全 `docs/**/*.md` で `../pages/` および blob URL の grep を TC-06 で実施 | _本コミット_ | reflected |
| R-005 (gemini#1) | コードベース | minor | `pages/guides/governance/documentation-management.md` 内の自己言及 (pages/ パス例) も T-03 置換対象 | _本コミット_ | reflected |
| R-006 (gemini#2) | コードベース | minor | `sidebars.js` (Docusaurus 想定) の参照確認を T-01 に追加 | _本コミット_ | reflected |
| R-007 (gemini#3) | コードベース | info | `git mv` 後 `git log --follow docs/pages/index.md` で履歴継続を PR 本文に記載 | _本コミット_ | reflected |

## 判定サマリ

| Reviewer | 判定 | 内訳 |
|----------|------|------|
| Codex (設計妥当性) | CONDITIONAL | major 3 + minor 1 |
| Gemini (コードベース整合) | APPROVE | minor 2 + info 1 |

## 反映方針

`.claude/rules/working-context.md` #234-C に従い、本コミットで pbi-input / plan / todo / test-cases / review-self を **1 回確定反映**。Codex major 3 件が design contract 確定に直結するため最重要。
