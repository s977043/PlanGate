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

| こう思ったら                           | 現実                                                                               |
| -------------------------------------- | ---------------------------------------------------------------------------------- |
| 「テストが通ったからレビュー不要」     | テスト通過はロジック正確性の一部に過ぎない。セキュリティ・仕様準拠は別途確認が必要 |
| 「小さな変更だから critical は出ない」 | 規模に関わらず 6 観点でチェックせよ。1 行の変更でも脆弱性は混入する                |
| 「外部レビューを受けたから大丈夫」     | review type の EvidenceItem として記録せよ。記録なき承認は存在しない               |

## 手順

### ステップ 1: `/pg-check` を実行して finding を収集する

```bash
# 差分レビューを実行して severity 付き finding を取得する
/pg-check <対象ブランチ or PR番号>
```

### ステップ 2: 6 観点で finding を分類・severity を付与する

`/pg-check` の Findings を以下の 6 観点に分類する:

| #   | 観点               | チェック内容                                 |
| --- | ------------------ | -------------------------------------------- |
| 1   | **仕様準拠**       | 受入基準・設計書との一致                     |
| 2   | **コード品質**     | 可読性・命名・構造の明確さ                   |
| 3   | **セキュリティ**   | 入力バリデーション・認証・認可・機密情報     |
| 4   | **パフォーマンス** | N+1 クエリ・ループ内 I/O・不要データ取得     |
| 5   | **テスト不足**     | カバレッジ・エッジケース・重要パスの未テスト |
| 6   | **破壊的変更**     | 後方互換性・API 変更・スキーマ変更           |

### ステップ 2.5: secret/config finding の policy-grounding チェック（#731）

> **背景**: 独立した複数レビューエージェント（security / backend / adversarial
> 等）が「Secrets Manager 注入が正規運用」という**同一の前提を共有**すると、
> adversarial のはずが合意形成で誤りを補強し、false-Critical を生む
> （#731 観測: `.env.production` の内部 proxy 用リテラル API キーを 3 エージェント
> 全員が Critical 判定 → 実際は env 管理が意図的なチーム方針だった）。
> secret/config のリテラル値は絶対的なアンチパターンではなく**プロジェクトの
> 管理方針に依存する**。以下は「セキュリティ」観点で secret/config のリテラル値を
> Critical/Major と判定する**前**に必ず行う。

セキュリティ観点の finding が secret/config リテラル値（API キー・トークン・
接続文字列等）に関するものである場合:

1. **policy-grounding チェック**: severity を確定する前に、以下いずれかで
   プロジェクトの実際の管理方針を検証する。検証せずに一般論（「リテラル値は
   常にアンチパターン」）で Critical/Major を付けない。
   - `docs/ai/secret-management-policy.md`（存在すれば、§3 allowlist・§5 判定
     手順を正本として参照する）
   - 同一ファイル内の他キーの記法（他キーもリテラルか、プレースホルダ
     `${VAR}` か）
   - taskdef / terraform の `valueFrom`、buildspec の `.env` コピー処理、CI の
     secrets 取り扱いなど実装側の注入方針
   - 検証できなければ finding に「〜方針を仮定・要確認」と明示した上で
     severity を確定する（黙って Critical にしない）。severity を一段階
     下げるのは env 管理慣習の傍証（同ファイル内の他キーもリテラル等）が
     ある場合に限る。傍証ゼロで下げない
   - **例外（downgrade 禁止）**: 明白に外部サービスのライブ認証情報と
     推定されるもの（cloud provider キー・既知の secret scanner 検出
     パターン一致等）は、方針が検証できなくても Critical を維持する
2. **前提の自己反証**: 「この指摘は前提（例: Secrets Manager 注入が方針）に
   依存していないか」「前提が逆（env 管理が方針）なら severity はどう変わるか」
   を finding に 1 行で書く。逆転させても severity が変わらないなら判定は
   頑健、逆転で下がるなら「前提依存の指摘」であることを明記する。
3. 手順・allowlist の詳細は
   [`docs/ai/secret-management-policy.md`](../../../docs/ai/secret-management-policy.md)
   を正本とする（本 Skill は判定手順の呼び出しのみを担い、allowlist データは
   持たない）。

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

| 観点           | Finding                    | Severity     | 対応         |
| -------------- | -------------------------- | ------------ | ------------ |
| 仕様準拠       | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| コード品質     | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| セキュリティ   | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| パフォーマンス | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| テスト不足     | \<finding または「なし」\> | \<severity\> | \<対応内容\> |
| 破壊的変更     | \<finding または「なし」\> | \<severity\> | \<対応内容\> |

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

## Plan Alignment レビュー（#581 要素4）

> 5 観点・Severity・判定基準（`.claude/rules/review-principles.md` §2-4）は**不変**。本ブロックは Plan 正本との突合観点を補う追加レーン（観点数を増やさず C-2 設計妥当性レーン §7-bis と整合）。

### Plan Alignment

- plan.md の Task 要件を満たしているか
- design.md の設計判断から逸脱していないか（逸脱なら理由明示）
- Target Files 外を変更していないか
- Out of Scope に抵触していないか
- 余計な機能を追加していないか（scope creep）

### Evidence Alignment

- test-cases.md と Evidence Ledger が対応しているか
- TDD 必須 mode で RED/GREEN 証跡があるか（#584 の tdd_red/green phase。証跡なしは **major**）

### Production Readiness

- エラー処理の具体性 / 後方互換 / セキュリティ・データ損失 / ドキュメント更新

## 関連

- Rule: `review-gate.md`（正本 - ブロック条件・Mode 別適用条件）
- Command: `/pg-check`（差分レビュー・finding 収集）
- Skill: `evidence-ledger`（EvidenceItem 記録手順）
- Rule: `review-principles.md`（レビューの姿勢・禁止事項・False-positive ガード）
- Doc: `docs/ai/secret-management-policy.md`（secret/config policy-grounding の allowlist・判定手順正本 / #731）
