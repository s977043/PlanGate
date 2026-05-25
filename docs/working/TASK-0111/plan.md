# TASK-0111 EXECUTION PLAN

> Source: pbi-input.md / GitHub issue #295 / Mode: **standard**
> Generated: 2026-05-25 / Codex 提案順位 A (2026-05-25)

## Goal

`pages/` を `docs/pages/` へ移設し、`docs/index.md` の `../pages/...` GitHub blob URL ハードコードを相対パスに置換することで、フォーク / 他ブランチでも壊れない pages 配信構造を恒久化する。

## Constraints / Non-goals

### Constraints

- GitHub Pages source 設定 (`/docs`) を変更しない (Human-owned 領域)
- Jekyll plugins / `_config.yml` の plugin 構成を破壊しない
- 既存テスト regression なし
- markdownlint + reference 健全性 CI が PASS する範囲で実施

### Non-goals

- root `pages/` の独立配信
- Pages source 変更 (#295 (b))
- 動的 URL 生成戦略の追加 (#295 (c))
- #293 暫定対応自体の roll back (本 PBI で natural に上書き)

## Approach Overview

(1) T-01 影響調査 (root `pages/` 参照箇所 grep, 外部 link grep, Cloudflare 等 secondary deploy 確認)、(2) `pages/` → `docs/pages/` git mv、(3) `docs/index.md` 等の `../pages/...` を `./pages/...` 相対パスに置換、(4) `_config.yml` で配信確認、(5) Jekyll local build で事前検証 (optional)、(6) handoff。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 Checkpoint |
|---|------|--------|-------|------|--------------|
| 1 | **T-01 調査**: root `pages/` 参照箇所全件 grep / Cloudflare 等 secondary deploy 確認 / 旧 URL 外部参照影響評価 | 調査メモ | AI | low | 全参照箇所マップ完成 |
| 2 | **T-02**: `git mv pages/ docs/pages/` | mv 後 file 配置 | AI | low | git mv で history 保持 |
| 3 | **T-03**: `docs/index.md` 等の `../pages/...` GitHub blob URL を `./pages/...` 相対パスに置換 | docs/index.md + 他参照 docs | AI | medium | 全 link が `./pages/...` 形式 + markdownlint pass |
| 4 | **T-04**: `docs/_config.yml` 確認 (relative_links / collections 既存設定で `docs/pages/` も配信されるか) + 必要なら microadjustment | docs/_config.yml | AI | low | Jekyll build で 200 OK 想定 |
| 5 | **T-05 リンク健全性**: 既存 reference 健全性 CI で全 internal link 検証、外部参照は旧 URL を grep で除外 | reference 健全性 PASS | AI | medium | CI PASS |
| 6 | **T-06 ローカル検証 (optional)**: `bundle exec jekyll serve` で事前確認 (CI 無いため AI 不可、Human 推奨) | (Human-only) | Human | low | 200 OK |
| 7 | **T-07**: handoff.md (Rule 5) + V-1 | docs/working/TASK-0111/handoff.md | AI | low | AC-1..7 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `pages/` (root) | 削除 (`git mv` → `docs/pages/`) |
| `docs/pages/` (新規 from mv) | 配置 (内容変更なし) |
| `docs/index.md` | `../pages/...` blob URL → `./pages/...` 相対パスに置換 |
| `docs/_config.yml` | 必要なら microadjustment (collections 等) |
| `README.md` / `README_en.md` / `staged-adoption-guide.md` 等 | 旧 `pages/` 参照箇所があれば置換 (T-01 で特定) |
| `docs/working/TASK-0111/handoff.md` | WF-05 |

## Testing Strategy

- **Reference 健全性 CI**: 既存 `scripts/check-reference-health.sh` 等で internal link 検証
- **markdownlint**: 全変更ファイル
- **Jekyll local build (Human)**: `bundle exec jekyll serve` で `/docs/pages/...` 200 OK 確認 (CI 化は別 PBI)
- **AC-4 公開サイト Human 事後確認**: merge + Pages rebuild 後 200 OK

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| 外部 (issue/blog) の旧 URL 参照が 404 化 | medium | T-01 で grep + 旧位置に redirect frontmatter 薄 stub 残置検討 |
| Jekyll permalink / collection 不整合 | medium | T-04/T-06 で `_config.yml` microadjust + Human local build 検証 |
| git mv で history が失われる (rename 検出不可) | low | git mv コマンド使用 + `git log --follow` で確認 |
| Cloudflare Pages 等 secondary deploy への影響 | low | T-01 で `.github/workflows/` 等 grep |
| reference 健全性 CI が新パスを認識しない | low | scripts/check-reference-health.sh をローカル実行で事前確認 |

## Mode 判定

**standard**

- 変更ファイル数: 移設 +相対パス置換で 10-20 ファイル相当
- 受入基準数: 7 件
- 変更種別: ディレクトリ移設 + リンク置換 (構造変更)
- リスク: 中 (公開サイト構造変更、外部リンク被覆)
- ロールバック: 可能 (git revert で復元)
- 影響範囲: docs/ 配下 + 公開サイト + 外部参照 URL

→ standard で進行。`lite_eligible=false` (構造変更 + 公開サイト影響)
