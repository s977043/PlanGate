# HANDOFF: TASK-0127 — C-3 レビュー HTML 出力（plangate render）

## 1. 要件適合確認（AC）
| AC | 内容 | 判定 |
|----|------|------|
| AC-01 | render で <TASK>-c3-review.html 生成 | PASS |
| AC-02 | 7種集約・欠落スキップ | PASS（5種/7種で実証） |
| AC-03 | 目次アンカー遷移 | PASS |
| AC-04 | 表/チェックボックス/コード/見出し描画 | PASS |
| AC-05 | 自己完結（外部参照ゼロ） | PASS |
| AC-06 | Python 標準ライブラリのみ | PASS |
| AC-07 | bin/plangate は apply-script 経由 | PASS |
| AC-08 | 存在しない TASK で明示エラー | PASS（exit=1） |

## 2. 既知課題
- 簡易 Markdown パーサのため、ネスト深いリストや複雑な MD は厳密でない（未対応記法は段落フォールバック）。C-3 レビュー閲覧用途には十分。
- 生成 HTML はビルド成果物。コミット要否は運用判断（再生成可能）。

## 3. V2 候補
- ローカルサーバ/ライブリロード（serve）、PDF、mermaid 描画、外部 MD ライブラリ採用

## 4. 妥協点
- 高品質レンダリング（markdown+pygments）より依存ゼロを優先 → 簡易パーサ自前実装

## 5. 引き継ぎ
人間が `sh scripts/apply-task-0127-render.sh`（dry-run→適用）後、`plangate render TASK-XXXX --html` でブラウザ用 HTML を生成できる。適用前でも `python3 scripts/render_review.py --task TASK-XXXX` で同等。

## 6. テスト結果サマリ
正常系/集約/目次/表/チェックボックス/コード/XSS/自己完結/依存ゼロ/エラー処理: 全 PASS。
