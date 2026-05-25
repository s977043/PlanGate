# TASK-0111 PBI INPUT PACKAGE

> Issue: [#295](https://github.com/s977043/plangate/issues/295)
> 出自: #293 暫定対応 (GitHub blob URL ハードコード) の gemini-code-assist 指摘 follow-up

## Context / Why

#293 で公開トップ `docs/index.md` の `../pages/...` リンク 404 を **GitHub blob URL (`s977043/main` ハードコード) への変更で暫定対応**した。gemini-code-assist が「フォーク・他ブランチで参照が壊れる保守性課題」を critical 指摘。

GitHub Pages source は `/docs` (Jekyll) に設定済のため、リポジトリ root の `pages/` 配下は Pages 配信に含まれない。よって `docs/index.md` から `../pages/...` 相対パスで参照しても 404 になる構造的問題。

## What (Scope)

### Approach (3 候補から (a) を採用)

| 案 | 内容 | 判定 |
|----|------|------|
| (a) | `pages/` を `docs/pages/` へ移設し相対パスで参照 | **採用** (AI 単独で実施可、Pages 設定変更不要) |
| (b) | Pages source を `/docs` → `/` 変更 or GitHub Actions ビルドで pages/ も配信 | 採用しない (Pages 設定変更は Human-owned + リポジトリ全体の rebuild リスク) |
| (c) | Jekyll `site.github.repository_url` で動的 URL 生成 | 採用しない (#293 で既に近い形を実装、依然 main/branch hardcode の variant が残る) |

### In scope

- `pages/` 配下 (`explanation/`, `guides/`, `reference/`, `index.md`) を `docs/pages/` に移設
- 全 internal 参照を `../pages/...` ハードコード GitHub blob URL → 相対パス (`./pages/...`) に書き換え
- `docs/_config.yml` で `pages/` を Pages 配信対象に含める確認 (Jekyll relative_links で配信)
- 既存リダイレクト互換 (旧 `pages/explanation/...` URL からの遷移)
- markdownlint pass + リンク健全性 CI pass

### Out of scope

- #293 暫定対応の差し戻し (暫定対応は維持。本 PBI で恒久版に置き換え後 cleanup)
- root `pages/` 配下の独立配信 (採用しない)
- Pages 設定の `/docs → /` 変更 (Human-owned + 副作用大)

## 受入基準

- AC-1: `docs/pages/` 配下に `explanation/`, `guides/`, `reference/`, `index.md` が存在し、root `pages/` は削除済 (or 旧位置への redirect frontmatter のみ残置)
- AC-2: `docs/index.md` の `../pages/...` 全 GitHub blob URL 参照が `./pages/...` 相対パスに置換 (リンク健全性 CI pass)
- AC-3: `docs/_config.yml` で `docs/pages/` が `relative_links` + `collections` 経由で配信される (markdownlint + Jekyll build 確認)
- AC-4: 公開サイト https://s977043.github.io/PlanGate/ で docs/index.md 経由の pages/ リンクが 200 OK (Human が事後確認)
- AC-5: フォーク / 他ブランチでも参照が壊れない (相対パスベースで `main` hardcode 不要)
- AC-6: 旧 `pages/` 配下を参照していた他 docs (例: README, staged-adoption-guide) が新パスを参照
- AC-7: markdownlint + reference 健全性 CI 全 PASS

## Notes from Refinement

- Approach (a) のみが AI 単独で実施可能 (b/c は Pages 設定変更 or 構造再設計)
- 旧 root `pages/` を完全削除する場合、Cloudflare Pages / 他デプロイ経路の影響を確認する必要あり (調査 T-01)
- 移設後の URL 経路 (`/pages/explanation/...` → `/docs/pages/explanation/...`) が変わるため、外部リンク被覆を grep で確認

## Estimation

### Risks

- 外部からの旧 URL 参照 (issue/comment/blog 等) が 404 化 → mitigation: T-01 で grep 確認、必要なら redirect frontmatter で旧位置に薄 stub 残置
- Jekyll build で collection / permalink 不整合 → mitigation: ローカル `bundle exec jekyll serve` で事前検証

### Unknowns

- Cloudflare Pages 等 secondary deploy がある場合の影響 (T-01 で調査)
- pages/index.md と docs/pages/index.md の URL 経路差 (`/pages/` → `/docs/pages/` or permalink 制御)

### Assumptions

- GitHub Pages source は `/docs` 固定 (本 PBI で変更しない)
- Jekyll plugins (relative_links / github_metadata) は不変
- root `pages/` を参照する build/CI workflow は存在しない (T-01 で確認)
