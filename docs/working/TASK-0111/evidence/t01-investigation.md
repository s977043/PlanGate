# TASK-0111 T-01 投資結果 (read-only 調査)

> 実施: 2026-05-26 / Mode: read-only / C-3 前可
> 目的: pages → docs/pages 移設の影響範囲を実数で確定 (#351 事前メトリクス検証の先行適用)

## 1. root pages/ 構造

```text
pages/index.md
pages/guides/product-demo-script.md
pages/guides/governance/documentation-management.md
pages/reference/product-faq.md
pages/explanation/product/overview.md
pages/explanation/product/value-proposition-canvas.md
pages/explanation/product/positioning.md
pages/explanation/product/pm-po-elevator-pitch.md
pages/explanation/product/before-after.md
```

合計: 9 file (md のみ、画像なし)

## 2. docs/**/*.md で pages/ 参照する file (T-03 置換対象)

| ファイル | 参照行数 | 内容 |
|---------|---------|------|
| docs/changelog.md | 2 | PR #205 言及 (歴史的記述、本 PBI で書換不要) |
| docs/index.md | 5 | 公開トップ、4 link 全てが Liquid (#293 で動的化済) |
| docs/ai/metrics-privacy.md | 1 | 相対 link |
| docs/ai/issue-governance.md | 3 | 相対 link |

合計: 4 file / 11 行

## 3. pages/ 自己言及

35 行 (主に `pages/guides/governance/documentation-management.md`)。
内容: doc 配置ルールの説明として `pages/explanation/` 等を例示。

判断: 移設後は docs/pages/ に書き換える (Place 名と Rule 名の整合)。

## 4. GitHub blob URL ハードコード (s977043/main pattern)

```
pages/ 参照で s977043/main hardcode: 0 件
```

#293 暫定対応で Liquid `{{ site.github.repository_url }}/blob/{{ site.github.build_revision }}` で動的化済。
git mv 後、Liquid 参照を相対 link に切り替えるだけで完了。

## 5. Sidebars.js (Docusaurus)

```text
sidebars.js 存在 (root)
Docusaurus 本体パッケージ不在 → dormant/legacy
```

sidebars.js 内に 9 件すべての pages/ 配下 file 参照あり。Docusaurus 不在のため実害なしだが、本 PBI で docs/pages/ に移設するなら sidebars.js も更新 (or 廃止) 推奨。

## 6. .github/workflows/ pages/ 参照

0 件 → CI workflow 影響なし。

## 7. Cloudflare Pages / 他 secondary deploy

`.cloudflare`, `wrangler.toml`, `_redirects` いずれも不在 → secondary deploy 影響なし。

## 8. 規模メトリクス vs plan 見積もり (#351 先行適用)

| 項目 | plan 見積もり | 実数 | 比率 |
|------|--------------|------|------|
| 変更ファイル数 | 10-20 | 14 (pages 9 + docs 4 + sidebars.js 1) | 0.7〜1.4 倍 |
| 受入基準数 | 7 | 7 | 1.0 倍 |
| Mode | standard | standard 維持で妥当 | — |

TASK-0117 (#351) 判定基準「1〜3 倍範囲」→ 採用、Mode 降格不要。

## 9. T-01 結論

### 確定事項

1. 移設対象は pages/ 配下 9 file (md のみ)
2. T-03 docs/**/*.md 置換は **3 file 9 行** (changelog.md 除く)
3. 自己言及 35 行 (主に documentation-management.md) は書換対象
4. s977043/main hardcode 不在 (Liquid 動的化済)
5. **sidebars.js も書換対象** (plan に補足)
6. CI / Cloudflare / secondary deploy 影響なし

### plan 補足事項 (T-02 以降で対応)

- 新規 touch file: `sidebars.js`
- `docs/changelog.md` は書換しない (歴史的記述、現在 ABCD 構造を説明)
- `docs/index.md` の Liquid 参照を `./pages/...` 相対 link に切り替え

### 残作業 (c3.json 発行後)

T-02 git mv → T-03 link 置換 → T-04 _config.yml 確認 → T-05 reference 健全性 → T-06 Human Jekyll local build (mandatory pre-C-3 gate) → T-07 handoff

## 10. Jekyll local build (T-06 mandatory pre-C-3 gate) 準備状況

- Gemfile 不在 → Human 側で事前準備が必要
- 推奨コマンド: `cd docs && bundle init && bundle add jekyll && bundle exec jekyll serve --baseurl /PlanGate`
- または `jekyll serve --source docs --baseurl /PlanGate` (system-wide jekyll が install されている場合)
