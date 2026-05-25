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
| TC-02 | docs/index.md に `../pages/` または GitHub blob URL なし、`./pages/` のみ | `grep -nE '\\.\\./pages/\\|github\\.com/.*/blob/.*/pages' docs/index.md` | no match (exit 1) |
| TC-03 | _config.yml で docs/pages/ が collections / relative_links 経由で配信される設定 | `cat docs/_config.yml` で確認 + Jekyll build 想定 | 設定 OK |
| TC-04 | 公開サイト https://s977043.github.io/PlanGate/ から docs/pages/ リンクが 200 OK | manual (Human) | 全 link 200 OK |
| TC-05 | docs/index.md の link が main hardcode を含まない (相対パスのみ) | `grep -nE 's977043/main\\|s977043/PlanGate/blob' docs/index.md` | no match |
| TC-06 | README.md, staged-adoption-guide.md 等の旧 `pages/` 参照が docs/pages/ に置換済 | T-01 で特定した全 docs を grep | 全置換 確認 |
| TC-07 | markdownlint + reference 健全性 CI PASS | `npx markdownlint-cli '**/*.md' && sh scripts/check-reference-health.sh` (or 同等) | exit 0 |

## エッジケース

- pages/ 配下に隠しファイル (.gitignore 等) がある場合: git mv で全件移設
- 旧 pages/ 参照を含む issue / comment: redirect frontmatter で薄 stub 残置 (T-01 結果次第)
- Jekyll permalink 衝突: T-04 で _config.yml microadjustment
