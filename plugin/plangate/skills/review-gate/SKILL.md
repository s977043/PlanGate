---
name: review-gate
description: "Review Gate を実施し、実装の仕様準拠・品質・セキュリティを 6 観点でレビューする。Use when: 実装完了後にレビューをしたい時。「Review Gate を通したい」「コードレビューをして」「実装の品質確認をしたい」「severity を確認したい」。"
---

# Review Gate

実装後に 6 観点でレビューを行い、critical finding を Completion Gate に伝達する。

## Iron Law

`NO MERGE WITHOUT TWO-STAGE REVIEW`

severity=critical の finding がある場合、fix なしに Completion Gate を通過させない。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「テストが通ったからレビュー不要」 | テスト通過はロジック正確性の一部に過ぎない。セキュリティ・仕様準拠は別途確認が必要 |
| 「小さな変更だから critical は出ない」 | 規模に関わらず 6 観点でチェックせよ。1 行の変更でも脆弱性は混入する |
| 「外部レビューを受けたから大丈夫」 | review type の EvidenceItem として記録せよ。記録なき承認は存在しない |

## 手順

### ステップ 1: `/pg-check` を実行して finding を収集する

```bash
# 差分レビューを実行して severity 付き finding を取得する
/pg-check <対象ブランチ or PR番号>
```

### ステップ 2: 6 観点で finding を分類・severity を付与する

`/pg-check` の Findings を以下の 6 観点に分類する:

| # | 観点 | チェック内容 |
|---|------|------------|
| 1 | **仕様準拠** | 受入基準・設計書との一致 |
| 2 | **コード品質** | 可読性・命名・構造の明確さ |
| 3 | **セキュリティ** | 入力バリデーション・認証・認可・機密情報 |
| 4 | **パフォーマンス** | N+1 クエリ・ループ内 I/O・不要データ取得 |
| 5 | **テスト不足** | カバレッジ・エッジケース・重要パスの未テスト |
| 6 | **破壊的変更** | 後方互換性・API 変更・スキーマ変更 |

### ステップ 3: critical finding の有無を判定する

- `severity=critical` が 1 件以上 → Completion Gate をブロック
- `severity=major` が 1 件以上（high-risk / critical Mode）→ 推奨または強制ブロック
- それ以外 → PASS

### ステップ 4: Review Gate レポートを出力する

以下のフォーマットで出力する（「出力フォーマット」セクション参照）。

### ステップ 5: critical finding がある場合は Completion Gate ブロック通知を出力する

```
[REVIEW GATE] BLOCKED
reason: severity=critical の finding が <N> 件あります。fix 後に再レビューが必要です。
```

## 出力フォーマット

### Review Gate レポート

#### Findings（6 観点）

| 観点 | Finding | Severity | 対応 |
|-----|---------|---------|------|
| 仕様準拠 | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| コード品質 | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| セキュリティ | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| パフォーマンス | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| テスト不足 | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| 破壊的変更 | \<finding または「なし」\> | \<severity\> | \<対応内容\> |

#### 総合判定

```
**総合判定**: PASS / BLOCK（critical: N件, major: N件）

→ Completion Gate: PASS / BLOCKED
```

#### EvidenceItem（Evidence Ledger への記録）

```json
{
  "id": "review-gate-001",
  "type": "review",
  "reviewer": "review-gate skill",
  "outputExcerpt": "critical: 0件, major: N件",
  "conclusion": "Review Gate PASS / BLOCKED"
}
```

## 関連

- Rule: `review-gate.md`（正本 - ブロック条件・Mode 別適用条件）
- Command: `/pg-check`（差分レビュー・finding 収集）
- Skill: `evidence-ledger`（EvidenceItem 記録手順）
- Rule: `review-principles.md`（レビューの姿勢・禁止事項・False-positive ガード）
