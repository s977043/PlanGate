# secret 管理方針宣言テンプレート（正本）

> #731 由来。review-gate / plan-review-gate 等のレビュー Skill が
> secret/config のリテラル値に severity を付与する **前** に参照する
> policy-grounding の正本。関連:
> [`docs/ai/external-reviewer-interface.md`](./external-reviewer-interface.md)
> （C-2/V-3 外部レビューア接続規約）/
> [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md)
> §7 False-positive ガード（観点・Severity・判定基準の正本、本ドキュメントは
> それを補完し再定義しない）。

## 1. 目的と背景

複数の独立レビューエージェント（security / backend / adversarial 等）が
「Secrets Manager 注入が正規運用」という **同一の前提を共有** すると、
adversarial のはずが合意形成で誤りを補強し、false-Critical を生む
（#731 観測事例: `.env.production` の内部 proxy 用リテラル API キーを
3 エージェント全員が Critical 判定 → 実際はそのキーは env 管理が
意図的なチーム方針だった）。

secret/config のリテラル値は **絶対的なアンチパターンではなく、
プロジェクトの管理方針に依存する**。方針を未検証のまま一般論で
Critical を付けると false-block を生む。本ドキュメントは
「このプロジェクトでは何が正規の管理方針か」を **事前宣言** し、
レビュー Skill が severity 判定前に参照できるようにする。

## 2. 使い方

1. 本ファイルをプロジェクトルート（または `docs/ai/`）にコピーし、
   §3〜§5 をプロジェクト固有の実態に合わせて埋める。
2. 埋めていない項目（不明・未検証）は空欄にせず **「未検証」** と明記する
   （空欄は「検証済みで allowlist 対象なし」と誤読されるため）。
3. review-gate 等のレビュー Skill は、secret/config のリテラル値を
   Critical/Major と判定する前に本ファイルの有無・該当項目を確認する
   （手順は本ファイルではなく各 Skill 側に実装する。本ファイルは
   参照される宣言データであり、レビュー手順の正本ではない）。
4. 本ファイルが存在しない場合、レビュー Skill は「プロジェクト固有の
   secret 管理方針は宣言されていない」ことを前提に、
   [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md)
   §7 の一般原則（推測に基づく断定禁止）に従い、finding に
   「〜方針を仮定・要確認」と明示する。severity を下げるのは env 管理
   慣習の傍証（§5 手順 2〜3）がある場合に限り、傍証ゼロで下げない。
5. **本方針は「secret をコミットしてよい」という一般許可ではない**。
   既定は禁止（リテラル secret は Critical/Major 判定の対象）であり、
   §3 の allowlist は根拠を伴う明示的な例外宣言である。

## 3. env 管理が正規運用のキー（allowlist）

> 「このキーはリテラル値で `.env*` / config に置くことがチーム方針として
> 意図されている」ものを列挙する。ここに載っていないキーのリテラル値は
> 通常どおり Critical/Major 判定の対象とする。

| キー名（またはパターン）       | 用途                                    | 根拠（決めた理由・issue/PR 等） | 最終更新       |
| ------------------------------ | --------------------------------------- | ------------------------------- | -------------- |
| `<例: INTERNAL_PROXY_API_KEY>` | `<例: 社内 proxy 認証用、外部公開なし>` | `<例: #123 で env 管理を決定>`  | `<YYYY-MM-DD>` |

未記入の場合: 「未検証（allowlist 未整備）」と明記する。

## 4. Secrets Manager 注入方針（該当する場合）

- 対象: `<例: 本番環境の DB 認証情報、外部 API の顧客向けキー>`
- 注入経路: `<例: ECS taskdef の valueFrom / Terraform の secretsmanager データソース>`
- 検証方法（レビュー時にこれを見れば注入方針か判断できる箇所）:
  - `<例: infra/**/*.tf の \`valueFrom\` / \`secretsmanager_secret\` 参照>`
  - `<例: buildspec.yml の環境変数取得ステップ>`
  - `<例: CI ワークフローの secrets コンテキスト参照>`

未整備の場合: 「未検証（Secrets Manager 運用なし、または未文書化）」と明記する。

## 5. 判定手順（レビュー Skill が参照する要約）

secret/config のリテラル値を検出した場合の判定順序:

1. **allowlist 一致確認**: §3 のキー名・パターンに一致するか確認する。
   一致すれば方針どおりであり、Critical/Major には **しない**（info 相当）。
2. **同ファイル内の他キーとの記法比較**: 同じファイル内の他のキーが
   すべてプレースホルダ（`${VAR}` 等）で、対象キーだけがリテラルなら
   逸脱の疑いが強まる（severity を上げる根拠になり得る）。逆に他キーも
   同様にリテラルなら「このファイルは元々 env 管理」の傍証になる。
3. **実装側の注入方針との突合**: taskdef / terraform の `valueFrom`、
   buildspec の `.env` コピー処理、CI の secrets 取り扱いを実際に確認する
   （§4 が整備されていればそこを見る、なければ探索する）。
4. **検証不能な場合**: allowlist 未整備・実装側証跡が確認できない場合は
   finding のコメントに「〜方針を仮定・要確認」と明示した上で severity を
   確定する（黙って Critical にしない）。severity を一段階下げるのは
   手順 2〜3 で env 管理慣習の傍証が得られた場合に限る。**例外**: 明白に
   外部サービスのライブ認証情報と推定されるもの（cloud provider キー・
   既知の secret scanner 検出パターン一致等）は、方針が検証できなくても
   Critical を維持する（downgrade 禁止）。
5. **前提の自己反証**（review-gate 側の必須ステップ）: 「Secrets Manager
   注入が方針」という前提が逆（env 管理が方針）だった場合に severity が
   どう変わるかを 1 行で書く。逆転させても Critical のままなら判定は
   頑健、逆転で severity が下がるなら「前提依存の指摘」であることを
   finding に明記する。

## 6. 本ドキュメントが対象としないもの

- secret を検出する手段（grep / secret scanner 等の実装）は対象外
  （本ファイルは severity 判定の **前提となる方針データ** のみを扱う）。
- 実際にコミットされてしまった secret のローテーション手順は対象外
  （インシデント対応 runbook 側の責務）。

## 関連

- Issue: [#731](https://github.com/s977043/plangate/issues/731)
  （review-gate/adversarial-review の calibration 改善提案）
- Skill: `review-gate`（policy-grounding チェック / 前提の自己反証の実装先。
  [`plugin/plangate/skills/review-gate/SKILL.md`](../../plugin/plangate/skills/review-gate/SKILL.md)）
- Rule: [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md)
  §7 False-positive ガード（観点・Severity・判定基準の正本）
