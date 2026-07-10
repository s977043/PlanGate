---
name: review-gate
description: "Review Gate を実施し、実装の仕様準拠・品質・セキュリティを 6 観点でレビューする（アーキ設計思想・ロジック正確性・アンチパターン・claim-vs-actual の追加観点レーン付き）。Use when: 実装完了後にレビューをしたい時。「Review Gate を通したい」「コードレビューをして」「実装の品質確認をしたい」「severity を確認したい」。"
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

> **観点フレームの正本との対応**: 本表の 6 観点は本 Skill の運用チェックリストであり、
> `review-principles.md` §2 の 5 観点（可読性・拡張性・パフォーマンス・セキュリティ・
> 保守性）を「仕様準拠」「破壊的変更」の突合軸込みで実装レビュー向けに再構成したもの。
> severity 定義・判定基準は同 §3-4 を正本とする（観点フレームを増やす意図はない）。

### ステップ 2.5: secret/config finding の policy-grounding チェック（#731）

> **背景**: 独立した複数レビューエージェント（security / backend / adversarial
> 等）が「Secrets Manager 注入が正規運用」という**同一の前提を共有**すると、
> adversarial のはずが合意形成で誤りを補強し、false-critical を生む
> （#731 観測: `.env.production` の内部 proxy 用リテラル API キーを 3 エージェント
> 全員が critical 判定 → 実際は env 管理が意図的なチーム方針だった）。
> secret/config のリテラル値は絶対的なアンチパターンではなく**プロジェクトの
> 管理方針に依存する**。以下は「セキュリティ」観点で secret/config のリテラル値を
> critical/major と判定する**前**に必ず行う。

セキュリティ観点の finding が secret/config リテラル値（API キー・トークン・
接続文字列等）に関するものである場合:

1. **policy-grounding チェック**: severity を確定する前に、以下いずれかで
   プロジェクトの実際の管理方針を検証する。検証せずに一般論（「リテラル値は
   常にアンチパターン」）で critical/major を付けない。
   - `docs/ai/secret-management-policy.md`（存在すれば、§3 allowlist・§5 判定
     手順を正本として参照する）
   - 同一ファイル内の他キーの記法（他キーもリテラルか、プレースホルダ
     `${VAR}` か）
   - taskdef / terraform の `valueFrom`、buildspec の `.env` コピー処理、CI の
     secrets 取り扱いなど実装側の注入方針
   - 検証できなければ finding に「〜方針を仮定・要確認」と明示した上で
     severity を確定する（黙って critical にしない）。severity を一段階
     下げるのは env 管理慣習の傍証（同ファイル内の他キーもリテラル等）が
     ある場合に限る。傍証ゼロで下げない
   - **例外（downgrade 禁止）**: 明白に外部サービスのライブ認証情報と
     推定されるもの（cloud provider キー・既知の secret scanner 検出
     パターン一致等）は、方針が検証できなくても critical を維持する
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

```text
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

```text
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

## 追加観点レーン（#794 / growth-core 由来）

> 5 観点・severity・判定基準（review-principles.md §2-4）は**不変**。本節は 5 観点を
> 実装レビューで深掘りするための運用チェックリスト（既存の 6 観点表・policy-grounding
> と同じアドオン位置づけ）。各レーンの finding は 6 観点表のいずれかに分類して severity を付す。

### レーン 1: アーキテクチャ設計思想（発火: standard 以上、またはアーキ変更・複数レイヤー変更時）

出典: growth-core `architecture-review`（Specialist モード 4+1 軸）。5 観点マッピング: 責務分離→拡張性 / 変更容易性・観測可能性・YAGNI→保守性 / セキュリティ境界→セキュリティ。

チェックリスト:

- **責務分離**: 関心事が適切に分離されているか。UI 側に業務ロジックが混入していないか。API/サービス層がツールとして独立して機能するか
- **変更容易性**: 機能追加・変更が局所化されるか。変更の波及箇所が多すぎないか
- **観測可能性**: ログ・メトリクス・トレースで動作を追跡できるか
- **セキュリティ境界**: 認証・認可・データ分離が適切か。**UI ガードレールがない前提**で安全か
- **YAGNI / 過剰実装**: 投機的抽象・未使用の拡張点・過度な汎用化がないか
- **MCP / ツール提供設計の場合は追加で**: 入力パラメータの自然言語変換しやすさ / レスポンス構造の AI 解釈しやすさ / ツール粒度の適切さ
- 背景思想 1 行: 「ユーザー → AI（自然言語）→ MCP（ツール定義）→ インフラ」の時代は UI ガードレール無し前提で API/ツール層が単独で安全・自己説明的である必要がある

### レーン 2: ロジック正確性（発火: code 変更のある全モード）

出典: growth-core `reviewer-logic`。5 観点マッピング: 可読性・保守性。§5「故障確率で判断」に直結（finding の 6 観点分類ではコード品質が典型）。

チェックリスト:

- **ロジック正確性**: 条件式の方向・符号・境界値（`<` vs `<=`・off-by-one）/ null・undefined・空配列のハンドリング漏れ / 非同期処理の競合（await 漏れ・Promise 未処理）/ エラーを握り潰す catch
- **データフロー**: 入力値の変換・加工経路の追跡（意図しない変換）/ 状態変更が他コンポーネントへ与える影響 / 戻り値が呼び出し元で正しく扱われるか
- **境界条件**: ゼロ・空・最大値・最小値での挙動 / 型変換によるデータ損失（number→string・float→int）/ ループ終了条件・再帰の基底ケース
- **仕様との整合**: 実装がコメント・仕様書・PR 説明と一致しているか / TODO・FIXME の意図せぬ残存

### レーン 3: AI 生成コード・アンチパターン（発火: code 変更のある全モード）

出典: growth-core `anti-pattern-reviewer`。5 観点マッピング: 可読性・保守性。

チェックリスト:

- **AI 生成コード特有の罠**: 過剰な抽象化・不要なインターフェース層 / **存在しないメソッド・ライブラリ関数の幻覚的参照** / 「動いているように見えるが意図と違う」実装（off-by-one・条件逆転）/ コピーペースト重複（わずかな違いで同じロジックが複数箇所）
- **設計臭**: God Object / God Function / 深いネスト・複雑な条件分岐（早期リターンで解消可能なもの）/ hard-coded 定数・マジックナンバー / 呼び出し元が知りすぎている（Law of Demeter 違反）
- **保守性リスク**: 変更時に複数箇所を同時修正させる重複（DRY 違反）/ テストが書きにくい実装（副作用混在・依存の隠蔽）/ 命名と実態の乖離

### レーン 4: 主張と実態の突合（claim-vs-actual）（発火: code 変更のある全モード。特に「完了」「全置換」「N% 削減」等の主張を含む PR で必須）

出典: growth-core `refactor-claim-audit` + river-review `adversarial-review`（Self-Contradiction / Refactor-Claim Audit / Cross-File Leakage）。5 観点マッピング: 保守性（残骸の有無・既存パターン準拠）。finding の 6 観点分類では仕様準拠が典型。verify-then-report 規範の実装レビュー版。

チェックリスト:

- **完了主張の反証**: 「全置換」「移行完了」「N% 削減」等の主張を grep 実測（旧 API・旧パターンの残存検索）と独立見積りで検証する。主張を鵜呑みにしない
- **Cross-File Leakage**: 宣言された変更スコープ外のファイルに変更が漏れていないか（diff --stat と **PR 記載**の突合。plan の Target Files との突合は Plan Alignment 節が担当 — 突合先が異なる相補チェック）
- **Self-Contradiction**: PR 説明・コミットメッセージ・コメント・docs の間、および同一文書内での自己矛盾
- 不採用・反証の記録は仕様引用または実測コマンド+結果を必須とする（推測のみでの棄却・採用をしない）

## 関連

- Rule: `mode-classification.md`（Mode 別フェーズ適用マトリクス・発火条件の正本）
- Command: `/pg-check`（差分レビュー・finding 収集）
- Skill: `evidence-ledger`（EvidenceItem 記録手順）
- Rule: `review-principles.md`（レビューの姿勢・禁止事項・False-positive ガード）
- Doc: `docs/ai/secret-management-policy.md`（secret/config policy-grounding の allowlist・判定手順正本 / #731）
