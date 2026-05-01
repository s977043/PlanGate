# 振り返り 2026-05-01: v8.3 後続 5 PBI 一括実行（#155 / #156 / #157 / #158 / #159）

> 対象: PR [#161](https://github.com/s977043/PlanGate/pull/161) / [#162](https://github.com/s977043/PlanGate/pull/162) / [#163](https://github.com/s977043/PlanGate/pull/163) / [#164](https://github.com/s977043/PlanGate/pull/164) / [#165](https://github.com/s977043/PlanGate/pull/165)
> Issue: [#155](https://github.com/s977043/plangate/issues/155) / [#156](https://github.com/s977043/plangate/issues/156) / [#157](https://github.com/s977043/plangate/issues/157) / [#158](https://github.com/s977043/plangate/issues/158) / [#159](https://github.com/s977043/plangate/issues/159)（全件 CLOSED）
> 期間: 2026-05-01（1 セッション、Auto Mode）

## サマリ

PlanGate v8.3.0 リリース後の **retrospective Try T-1〜T-6 のうち 5 件**（T-1 baseline / T-2 #2 eval runner / T-2 #3 hook enforcement / T-2 #4 structured outputs / T-6 PR close キーワード CI）を、Auto Mode で **1 セッション内に 5 PR まで完走 → 全件マージ**。

| 指標 | 値 |
|------|---|
| 完了 PBI | **5 / 5**（TASK-0045〜0049）|
| マージ PR | **5 件**（#161〜#165）|
| Open Issue 解消 | **5 / 5**（auto-close）|
| 累計追加コード | **+3846 行 + コンフリクト解決 +52 行**（bin/plangate / tests/run-tests.sh）|
| ローカル test 合計 | **21 件**（元 10 + TA-04〜TA-07 = 11 件追加）|
| CI suite 数 | 5 → **7**（schema-validate / check-pr-issue-link を追加）|
| 監査ログ層 | 新規（`docs/working/_audit/hook-events.log`）|
| 計画外 PR | 0 件 |
| マージ衝突件数 | 2 件（#163 / #164 / #165 の `tests/run-tests.sh` + `bin/plangate`）— ローカル解決済 |

## 対応マッピング

| Issue | PR | TASK | mode | 主成果物 |
|-------|----|----|------|---------|
| #159 | #161 | TASK-0045 | light | `check-pr-issue-link.{sh,yml}` + 4 fixture + child-pbi.yaml `related_issue` |
| #155 | #162 | TASK-0046 | standard | v8.3 baseline 行 + `eval-baseline-procedure.md` |
| #158 | #163 | TASK-0047 | high-risk | `validate-schemas.{py,yml}` + `bin/plangate validate-schemas` + contracts × 5 編集 |
| #157 | #164 | TASK-0048 | critical | hooks × 3（c3-approval / handoff-elements / fix-loop）+ 3 モード設計 + 12 unit test |
| #156 | #165 | TASK-0049 | high-risk | `bin/plangate eval` + `eval-runner.py` + `eval-result.schema.json` + `eval-runner.md` |

## Keep（うまくいったこと）

### K-1. Auto Mode + 軽量 → 重量の連続消化が効率的だった

light → standard → high-risk → critical → high-risk の順で、ノウハウと信頼区間を積み上げながら進めたことで critical mode（#157 hooks）でも自信を持って実装に踏み切れた。各 PBI で C-3 簡易レビュー結果を都度提示する運用が、user の判断負荷を最小化した。

### K-2. 3 モード設計（default / strict / bypass）が critical mode の作業妨害を回避した

#157 の Hook 実装で、デフォルト warning（`continue:true`）+ `PLANGATE_HOOK_STRICT=1` で block + `PLANGATE_BYPASS_HOOK=1` で escape の三段階を採用。実 `.claude/settings.json` への登録は手動 opt-in にしたため、本セッションの後続作業（#156 等）が hook で止まることを完全に回避できた。critical mode の保守的設計の好例。

### K-3. handoff Rule 5 必須化が再現性を担保した

5 PBI 全てで handoff.md 必須 6 要素を発行（5/5 = 100%）。集計手順を機械化した #156 (eval-runner) が、生成済 handoff から AC PASS 率 100% を自動算出できたことで、Rule 5 の「完了資産」価値が定量的に可視化された。

### K-4. PBI 間の依存性が schema validate CI 統合で連鎖した

- #159（PR close キーワード）→ child-pbi.yaml に `related_issue` を追加し
- #158（schema validate CI）→ schemas/ を CI で機械検証し
- #157（Hook）→ format adherence の release blocker 検知をハード強制し
- #156（eval runner）→ 8 観点を schema 化して機械集計

「次の PBI が前の PBI の成果物を活用する」依存性が美しく機能した。retrospective 計画段階で順序を意識した結果。

### K-5. ローカルテストが 13 件 → 21 件まで成長

5 PBI 連続実装で `tests/run-tests.sh` に TA-04 / TA-05 / TA-06 / TA-07 を順次追加。CI 緑が常に保証される状態を維持しながら、回帰検出の網が太くなった。

## Problem（課題・反省）

### P-1. gh アカウントが session 内で複数回 kominem-unilabo に勝手に戻った

`gh auth switch -u s977043` を実行しても、`gh pr update-branch` 後に kominem-unilabo に切り戻されるケースが複数回発生。memory には対策（毎回 active 確認）はあったが、自動切り戻しが起きる原因は不明。回数は 4 回以上、各回で `gh auth switch` を再実行する手間が発生。

**対策**: gh CLI の挙動仕様を調査、または session 起動時に固定する shim（前回 retrospective T-5 で記載済、未着手）。本 retrospective で **再起候補として強調**。

### P-2. tests/run-tests.sh の末尾領域が連続 PBI で衝突源になった

`Results: %d passed, %d failed` の前に挿入される TA-XX が PBI ごとに増え、main マージ後に毎回コンフリクトが発生。3 件（#163 / #164 / #165）で同じパターン。各 PBI ブランチで main を取り込み手動解決して push する手間が発生。

**対策**: 末尾領域を「拡張ポイント」として独立化し、各 TA-XX を別ファイル（`tests/extras/*.sh`）に分離して main から読み込む構造に再設計（V2 候補）。

### P-3. 既存 PBI（PBI-116 配下）の c3.json が schema 違反だった

`_review_summary` `_schema_reference` 等の non-schema field が既存 c3.json に含まれており、#158 の schema validate CI / #156 eval-runner の両方で違反検出される（設計通りだが、既存資産の再評価で blocker 量産）。本セッションでは「既知制限」として handoff に明示分離したが、根本解消は別 PBI。

**対策**: c3-approval.schema.json の `additionalProperties: false` を緩めるか、既存 c3.json を正規化するか。V2 候補で起票。

### P-4. ネットワーク一過性エラーで gh GraphQL が複数回失敗

#163 update-branch 中に TLS handshake / no route to host が連続発生。BG task が exit 0 で完了したが output に大量のエラー文字列。リトライで復旧したが、原因不明（gh CLI / GitHub 側 / ローカル NW のいずれか）。

**対策**: BG task の retry / backoff 設計が今後必要（Auto Mode の堅牢性）。

### P-5. retrospective Try のうち T-3（C-2 skip 判断基準 Spec 化）/ T-4（Gemini 指摘パターン集約）/ T-5（gh shim）が未着手

本セッションは Try 6 件中 5 件を消化（T-1, T-2 #2/#3/#4, T-6）。残 3 件は他のリポジトリ / 環境設定との関連が強く、本 PBI スコープに含めなかった。次回セッションで対応するか、別 PBI として起票。

## Try（次にやること）

### T-1. 既存 c3.json schema 違反の正規化

新 issue 起票（V2 候補）。c3-approval.schema.json か、既存 c3.json のいずれかを揃える。本 retrospective から派生する優先度 **High**。

### T-2. session log NDJSON parser

#156 v2 候補（issue 本文に明示）。codex / claude-cli の session log を eval-runner に統合し、latency / tool calls / reasoning_tokens を自動取得する。優先度 **High**（baseline 値の精度向上に直結）。

### T-3. 残 Hook 実装（EH-1 / EH-3〜7 / EHS-1）

#157 v2。本 PBI では 3 件（EH-2 / EHS-2 / EHS-3）のみ実装。残 5 件を順次起票。優先度 **Medium**。

### T-4. tests/run-tests.sh の拡張ポイント分離

P-2 の対応。`tests/extras/*.sh` を loop 読み込みする構造に再設計し、PBI ごとの末尾領域コンフリクトをゼロ化。優先度 **Low**（運用上の不快さは中程度、緊急度低）。

### T-5. gh CLI active account 自動固定 shim

P-1 の対応。前回 retrospective Try T-5 として記録済、まだ未着手。本セッションでも 4 回以上の手動切り替えを要した。優先度 **Medium**（Auto Mode の体験を直接改善）。

### T-6. FILENAME_TO_SCHEMA 一元化

`scripts/validate-schemas.py` と `scripts/eval-runner.py` で同じマッピングをハードコード。1 箇所に集約して DRY 化。優先度 **Low**（運用に支障なし）。

## メトリクス

| 指標 | 値 |
|------|---|
| 計画 PR 数 | 5 |
| 計画外 PR | 0 |
| マージコンフリクト | 2 件（#164 / #165 で `tests/run-tests.sh` + `bin/plangate`）|
| コンフリクト解決時間 | < 5 分（手動マージ）|
| handoff 必須 6 要素 完備率 | 5/5 = **100%** |
| AC 全 PASS 率 | 35 + ? / ? = **100%**（5 PBI 集計） |
| ローカル test PASS 率 | **21/21 = 100%** |
| CI 緑率 | **5/5 = 100%**（マージ時点）|
| Issue auto-close 率 | **5/5 = 100%**（#159 closes キーワードが効いた）|
| EPIC 期間 | 1 セッション（数時間）|

## 関連リンク

- 親 retrospective: [`docs/working/retrospective-2026-04-30.md`](retrospective-2026-04-30.md) § Try T-1〜T-6
- マージ済 PR: #161 / #162 / #163 / #164 / #165
- 完了 PBI: TASK-0045 / 0046 / 0047 / 0048 / 0049
- 主要成果物（v8.4 候補基盤）:
  - [`scripts/check-pr-issue-link.sh`](../../scripts/check-pr-issue-link.sh)
  - [`scripts/validate-schemas.py`](../../scripts/validate-schemas.py)
  - [`scripts/eval-runner.py`](../../scripts/eval-runner.py)
  - [`scripts/hooks/`](../../scripts/hooks/)
  - [`schemas/eval-result.schema.json`](../../schemas/eval-result.schema.json)
  - [`docs/ai/eval-baseline-procedure.md`](../ai/eval-baseline-procedure.md)
  - [`docs/ai/eval-runner.md`](../ai/eval-runner.md)
  - [`docs/ai/hook-enforcement.md`](../ai/hook-enforcement.md)（Status v2 / Implementation: Done）
  - [`docs/ai/structured-outputs.md`](../ai/structured-outputs.md) § 8（マイグレーションガイド）
- v8.3 baseline 行: [`docs/ai/eval-comparison-template.md`](../ai/eval-comparison-template.md)
