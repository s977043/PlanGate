# C-3 レビュー HTML 出力 `plangate render`（TASK-0127）

> 利用者の声「MD は確認しづらい / ファイルが多くて把握しづらい / ブラウザで見たい」への対応。

## 目的

C-3 レビュー対象の MD を **1 枚の自己完結 HTML** に集約し、ブラウザで横断的に確認できるようにする。

## 使い方

```sh
plangate render TASK-XXXX --html
# → docs/working/TASK-XXXX/TASK-XXXX-c3-review.html

# 出力先を変える
plangate render TASK-XXXX --out /tmp/review.html

# bin/plangate 未適用でも本体は直接呼べる
python3 scripts/render_review.py --task TASK-XXXX
```

ブラウザ自動起動はしない（出力パスを表示するのみ）。生成した HTML をブラウザで開く。

## 仕様

- **対象 7 種**（存在するもののみ・欠落はスキップ）: pbi-input / plan / todo / test-cases / review-self / review-external / handoff
- **自己完結**: CSS インライン・外部 CDN/ファイル参照ゼロ（オフライン・直開き可）
- **レンダリング**: 見出し / GFM 表 / チェックボックス（`- [ ]`/`- [x]`）/ コードブロック / リスト / 引用 / インライン（code/strong/em/link）
- **安全**: HTML 特殊文字をエスケープ（MD 内の `<script>` 等は注入されない）
- **依存**: Python 標準ライブラリのみ（新規 pip 依存なし）

## 責務分界

| 操作 | 担当 |
|------|------|
| `render_review.py` 実装・apply-script 作成 | AI-owned |
| `bin/plangate` への `render` 適用（HO） | Human-owned（apply-script 適用） |

## 関連
- 実装: `scripts/render_review.py` / apply: `scripts/apply-task-0127-render.sh`
- 仕様: [`docs/working/TASK-0127/plan.md`](working/TASK-0127/plan.md)
