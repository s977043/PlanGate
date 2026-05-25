# TASK-0111 TEST CASES

> Source: plan.md / AC-1..AC-7

## 受入基準 → テストケースマッピング

| AC | TC |
|----|-----|
| AC-1: docs/pages/ 存在 + root pages/ 削除 | TC-01 |
| AC-2: ../pages/... blob URL → ./pages/... 相対パス | TC-02 |
| AC-3: _config.yml で docs/pages/ 配信 | TC-03 |
| AC-4: 公開サイト 200 OK | TC-04 (Human) |
| AC-5: フォーク / 他ブランチで壊れない | TC-05 |
| AC-6: 他 docs の旧 pages/ 参照置換 | TC-06 |
| AC-7: markdownlint + reference 健全性 CI PASS | TC-07 |

## テストケース一覧

| ID | 内容 | コマンド/手順 | 期待 |
|----|------|-------------|------|
| TC-01 | docs/pages/ 配下に explanation/guides/reference/index.md / root pages/ 不存在 | `test -d docs/pages/explanation && test ! -d pages/` | exit 0 |
| TC-02 (R-004) | **全 `docs/**/*.md`** に `../pages/` または GitHub blob URL なし | `grep -rnE '\.\./pages/\|github\.com/.*/blob/.*/pages' docs/ | grep -v 'docs/working/'` | no match |
| TC-03 | _config.yml で docs/pages/ が collections / relative_links 経由で配信される設定 | `cat docs/_config.yml` で確認 + Jekyll build 想定 | 設定 OK |
| TC-04 (R-001/R-003) | 公開 URL `/PlanGate/pages/...` (Pages source=/docs ゆえ `/docs/` prefix なし) で 200 OK。pre-C-3: Human が `bundle exec jekyll serve` で local 検証 / post-merge: 公開サイトで再確認 | manual (Human) | 全 link 200 OK |
| TC-05 | docs/index.md の link が main hardcode を含まない (相対パスのみ) | `grep -nE 's977043/main\\|s977043/PlanGate/blob' docs/index.md` | no match |
| TC-06 (R-004/R-005) | 全 `docs/**/*.md` + `documentation-management.md` 自己言及含む全箇所が新パス参照 | `grep -rn 'pages/' docs/ | grep -v 'docs/working/' | grep -v 'docs/pages/' | grep -v './pages/'` | no match |
| TC-07 | markdownlint + reference 健全性 CI PASS | `npx markdownlint-cli '**/*.md' && sh scripts/check-reference-health.sh` (or 同等) | exit 0 |

| **TC-08 (R-006)** | `sidebars.js` 等 Docusaurus 参照ファイルが旧 pages/ を参照していないこと | `grep -n 'pages/' sidebars.js 2>/dev/null || true` | 該当なし or 新パス |
| **TC-09 (R-007)** | git mv 後 history 継続 | `git log --follow docs/pages/index.md | head` | 移設前 commit 表示 |

## エッジケース

- pages/ 配下に隠しファイル (.gitignore 等) がある場合: git mv で全件移設
- 旧 pages/ 参照を含む issue / comment: redirect frontmatter で薄 stub 残置 (T-01 結果次第)
- Jekyll permalink 衝突: T-04 で _config.yml microadjustment
