# TASK-0111 handoff

> WF-05 Verify & Handoff 完了パッケージ (Rule 5 必須 6 要素)
> Issue: [#295](https://github.com/s977043/plangate/issues/295)

## 概要

公開トップ `docs/index.md` の `../pages/...` GitHub blob URL ハードコード問題 (#293 暫定対応の保守性課題、gemini-code-assist critical 指摘 follow-up) を恒久化。`pages/` を `docs/pages/` へ git mv (history 保持) し、相対パス `./pages/...` で参照するよう全 docs/**/*.md を一括書換。Pages source=/docs の枠内に統合、フォーク/他ブランチでも壊れない構造化。

## 1. 要件適合確認結果 (AC-1..AC-7)

| AC | TC | 結果 | 検証 |
|----|----|------|------|
| AC-1 docs/pages/ 配置 + root pages/ 削除 | TC-01 | ✅ PASS | `find docs/pages -type f \| wc -l` = 9 / `test ! -d pages/` |
| AC-2 全 docs/**/*.md で blob URL なし / ./pages/ のみ | TC-02 | ✅ PASS | `grep -rnE '\.\./pages/\|github.com/.*/blob/.*pages' docs/ \| grep -v docs/working/` = 0 件 |
| AC-3 docs/_config.yml で docs/pages 配信 | TC-03 | ✅ PASS | relative_links + collections 既存設定で配信可 (microadjust 不要) |
| AC-4 公開 URL 200 OK (`/PlanGate/pages/...`) | TC-04 | ✅ pre-C-3 PASS (Human Jekyll local build 全 9 link 200 OK, 2026-05-26) / 公開サイト post-merge 確認は Human |
| AC-5 フォーク / 他ブランチで壊れない | TC-05 | ✅ PASS | 相対パスのみ、main hardcode なし (`grep -nE 's977043/main\|s977043/PlanGate/blob' docs/index.md` = 0 件) |
| AC-6 他 docs の旧 pages/ 参照置換 | TC-06 | ✅ PASS | 残存 0 件 (T-05 機械検証) |
| AC-7 markdownlint + reference 健全性 CI | TC-07 | ✅ pending (PR CI で確認) |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | `docs/changelog.md` L130/L137 に「`pages/` (PR #205)」歴史的記述あり | info | 歴史的事実の記述のため書換不要 (T-01 で out of scope と判断) |
| K-2 | `sidebars.js` (Docusaurus dormant) の id 参照は path 非依存 (`index`, `guides/...` 等) | info | doc-id 形式で path 非依存、touch 不要 |
| K-3 | 公開サイト post-merge での 200 OK 確認は Human 操作 (AC-4 完全 PASS は merge 後) | minor | PR merge 後に Human が公開サイト確認 |

## 3. V2 候補 (今回 scope 外)

| 案 | 内容 |
|----|------|
| V2-A | Jekyll local build を CI 化 (現在 Human オペレーション、`bundle install` + 200 OK 確認) |
| V2-B | sidebars.js を Docusaurus 再導入と共に活用 or 廃止 (現在 dormant) |
| V2-C | `docs/changelog.md` の歴史的 `pages/` 参照を「旧 pages/ (現 docs/pages/)」と注記追加 |

## 4. 妥協点

- T-06 (Jekyll local build) は Human オペレーション固定 (CI 化は別 PBI、V2-A 候補)
- `docs/changelog.md` の歴史的記述は本 PBI で書換しない (out of scope)
- redirect stub は採用しない (root pages/ は完全移設、redirect は GitHub Pages 制御外)

## 5. 引き継ぎ文書 (5 分把握サマリ)

1. `pages/` (9 file) を `docs/pages/` に `git mv` で移設 (history 保持)
2. `docs/index.md` の Liquid `{{ site.github.repository_url }}/blob/{{ site.github.build_revision }}/pages/...` を **相対パス `./pages/...`** に置換 (4 link)
3. `docs/ai/metrics-privacy.md` / `docs/ai/issue-governance.md` の `../../pages/` を `../pages/` に置換 (3 line / 4 箇所)
4. `docs/pages/index.md` + `docs/pages/guides/governance/documentation-management.md` の自己言及 (35+ 行) を `docs/pages/` に書換
5. `docs/_config.yml` 不変 (既存 relative_links + collections で動作)
6. `sidebars.js` 不変 (doc-id 形式で path 非依存)
7. Jekyll local build (Human Pre-C-3 mandatory gate): 全 9 link 200 OK PASS 確認済

公開 URL = `/PlanGate/pages/foo.html` (Pages source=/docs ゆえ `/docs/` prefix なし、Jekyll permalink デフォルト)。

## 6. テスト結果サマリ

| カテゴリ | 結果 |
|---------|------|
| 機械検証 (T-05) | 全 docs/**/*.md で残存 `pages/` 0 件、blob URL 0 件 |
| Jekyll local build (T-06 mandatory pre-C-3) | ✅ PASS 全 9 link 200 OK (Human 報告 2026-05-26) |
| schema validation (c3.json) | ✅ VALID |
| plan_hash 整合 (exec 着手時) | ✅ sha256:77720dc00fcd...0bb50c |
| markdownlint + 既存 CI | PR で確認予定 |

## 7. Refs

- Issue: [#295](https://github.com/s977043/plangate/issues/295)
- C-3 APPROVED: `docs/working/TASK-0111/approvals/c3.json` (PR #369 merged 2026-05-26)
- C-2 reviews: Codex APPROVE_FOR_C3 / Gemini APPROVE (R-001..R-012 反映済)
- T-01 evidence: `docs/working/TASK-0111/evidence/t01-investigation.md` (PR #365/#366 merged)
- TASK-0117 (#351) 先行適用: 規模メトリクス検証 1.0〜1.4 倍で standard 維持
