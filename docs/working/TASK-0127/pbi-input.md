# PBI INPUT PACKAGE: TASK-0127

## Context / Why

C-3 人間レビューは現状 `docs/working/TASK-XXXX/` 配下の複数 Markdown（`pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md` / `handoff.md`）をエディタで個別に開いて確認する運用になっている。

利用者から以下の声があり、レビュー体験を改善したい:

- MD ファイルは（生 Markdown のため）確認しづらい
- ファイルが多くて全体を把握しづらい
- ブラウザ上で確認したい

C-3 レビュー対象アーティファクトを 1 枚の自己完結 HTML に集約し、ブラウザで横断把握できる出力オプションを提供する。

## What

### In scope

- `bin/plangate render <TASK-XXXX> [--html]` サブコマンドの追加
  - `bin/plangate` 本体は **Hardening Override 対象パス**のため、AI は直接編集せず `scripts/apply-*.sh` パッチを作成 → **人間が適用**する（責務 4 分類: Human-owned 適用）
- レンダリング本体 `scripts/render_review.py`（HO 対象外 = AI 実装可、Python 標準ライブラリ中心 / 外部 pip 依存を増やさない）
- 出力: `docs/working/<TASK-XXXX>/c3-review.html`（単一・自己完結 = CSS/JS 埋め込み、外部 CDN 依存なし）
- レンダリング内容:
  - C-3 対象 7 種 MD を 1 ページに集約（存在するファイルのみ）
  - 先頭に目次（各セクションへのアンカーリンク）
  - GFM 表 / チェックボックス（`- [ ]` / `- [x]`）/ コードブロック / 見出し / 相対リンクのレンダリング
- ドキュメント追記（`docs/` 配下に render コマンドの使い方を明記）

### Out of scope（V2 候補）

- ローカル HTTP サーバ / ライブリロード（`serve` サブコマンド）
- PDF 出力
- mermaid 等の図表描画
- 外部 Markdown ライブラリ（markdown + pygments 等）の採用（依存追加を伴うため versioning-stability-policy 適合確認が別途必要）
- C-3 承認操作そのもの（`c3.json` 発行）の HTML UI 化（承認境界は Human-owned のまま不変）

## 受入基準

| AC | 内容 |
|----|------|
| AC-01 | `bin/plangate render TASK-XXXX --html` で `docs/working/TASK-XXXX/c3-review.html` が生成される |
| AC-02 | 存在する C-3 対象 MD（最大 7 種）がすべて 1 ページに集約され、欠落ファイルはスキップされる（エラーにしない） |
| AC-03 | 先頭の目次から各 MD セクションへアンカー遷移できる |
| AC-04 | GFM 表・チェックボックス・コードブロック・見出しが HTML としてレンダリングされる |
| AC-05 | 生成 HTML は自己完結（外部 CDN / 外部ファイル参照なし）で、オフライン・ブラウザ直開きで表示できる |
| AC-06 | `scripts/render_review.py` は Python 標準ライブラリのみで動作し、新規 pip 依存を追加しない |
| AC-07 | `bin/plangate` への変更は apply-script として提示され、AI は直接編集しない（適用は人間）|
| AC-08 | 対象 TASK ディレクトリが存在しない場合は明示エラーを返す |

## Notes from Refinement

- 出力形態は「単一自己完結 HTML（静的ファイル）」を採用（ローカルサーバ案は V2）
- 実装手段は「標準ツール内製（依存最小）」を採用（既存 MD ライブラリ案は依存追加のため V2）
- C-3 承認境界・5 レビュー観点は変更しない（閲覧体験の改善のみ）

## Estimation Evidence

### Risks / Unknowns

- Python 標準ライブラリのみで GFM 表 / チェックボックスを十分な品質でレンダリングできるか（簡易パーサの実装範囲）
- `bin/plangate` が HO 対象のため apply-script + 人間適用フローが必要（AI 単独完結不可）
- Mode = high-risk（承認境界周辺 = `bin/plangate` に touch）→ `lite_eligible=false` / Standard C-3 同期固定

### Assumptions

- 既存 `scripts/*.py`（`scripts/_*.py` 含む）のパターンに沿って `render_review.py` を実装
- 既存 `scripts/apply-*.sh` のパターンに沿って bin/plangate パッチ用 apply-script を作成
- レンダリング対象は working-context.md 定義の C-3 アーティファクト 7 種を基準とする
