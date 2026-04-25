# Review Gate ルール（正本）

> 正本。Review Gate の定義・観点・Completion Gate ブロック条件はこのファイルのみで管理する。
> 参照元: `review-gate` Skill、`/pg-check` コマンド、`completion-gate.md`

## 目的

実装後に仕様・品質・安全性を確認し、critical finding を Completion Gate に伝達する。
「動くはず」「たぶん大丈夫」を排除し、証拠に基づく品質確認を強制する。

## Review 6 観点

| # | 観点 | チェック内容 |
|---|------|------------|
| 1 | **仕様準拠** | 受入基準・設計書との一致。test-cases.md の期待動作と実装の対応 |
| 2 | **コード品質** | 可読性・命名の適切さ・構造の明確さ。複雑度・重複の有無 |
| 3 | **セキュリティ** | 入力バリデーション・認証・認可・機密情報の扱い。インジェクション対策 |
| 4 | **パフォーマンス** | N+1 クエリ・ループ内 I/O・不要データ取得。リソース効率 |
| 5 | **テスト不足** | カバレッジ・エッジケース。重要パスの未テスト箇所 |
| 6 | **破壊的変更** | 後方互換性・API 変更・スキーマ変更。既存機能への影響 |

## Severity 定義（/pg-check と統一）

| Severity | 定義 | 例 | Completion Gate 影響 |
|----------|------|---|---------------------|
| **critical** | 本番障害・データ不整合・脆弱性 | SQLインジェクション、認可チェック漏れ、データ損失 | ブロック（必須） |
| **major** | ロジック誤り・テスト不足・設計違反 | N+1クエリ、レイヤー間依存違反、重要パス未テスト | ブロック（Mode依存） |
| **minor** | 改善提案・命名・コードスタイル | 変数名改善、early return提案、ドキュメント不備 | 影響なし |
| **info** | FYI・将来課題・好みの問題 | 類似パターンの紹介、リファクター候補、補足情報 | 影響なし |

## Completion Gate ブロック条件

`severity=critical` の finding が 1 件以上ある場合、Completion Gate をブロックする。

### Mode 別ブロック基準

| Mode | critical | major | 判定 |
|------|----------|-------|------|
| ultra-light | ブロック | 影響なし | critical のみブロック |
| light | ブロック | 影響なし | critical のみブロック |
| standard | ブロック | 影響なし | critical のみブロック |
| high-risk | ブロック | 推奨ブロック | major があれば人間確認を強く推奨 |
| critical | ブロック | 強制ブロック | critical + major どちらもブロック |

## 適用条件（Mode 別）

| Mode | Review Gate | 実施方法 |
|------|-------------|---------|
| ultra-light | 省略可 | — |
| light | 省略可 | — |
| standard | 推奨 | `/pg-check` を実行 |
| high-risk | 必須 | `/pg-check` + 6 観点チェック |
| critical | 必須 | `/pg-check` + 6 観点チェック + multi-agent review 推奨 |

## `/pg-check` との連携

`/pg-check` の出力（Findings テーブル）を Review Gate の入力として使用する。

1. `/pg-check` を実行して severity 付き finding を収集する
2. finding を 6 観点に分類する
3. critical finding の有無を判定する
4. Completion Gate へ結果を伝達する

## 関連

- Command: `/pg-check`（差分レビュー・finding 収集）
- Skill: `review-gate`（Review Gate 実施手順）
- Rule: `evidence-ledger.md`（Completion Gate 条件の正本）
- Rule: `review-principles.md`（レビューの姿勢・禁止事項）
- Iron Law: `NO MERGE WITHOUT TWO-STAGE REVIEW`
