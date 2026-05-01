# 振り返り 2026-05-01 (s2): V2 candidate 4 件一括実行（#167 / #170 / #171 / #172）

> 対象 PR: [#173](https://github.com/s977043/PlanGate/pull/173) / [#174](https://github.com/s977043/PlanGate/pull/174) / [#175](https://github.com/s977043/PlanGate/pull/175) / [#176](https://github.com/s977043/PlanGate/pull/176)
> Issue: [#167](https://github.com/s977043/plangate/issues/167) / [#170](https://github.com/s977043/plangate/issues/170) / [#171](https://github.com/s977043/plangate/issues/171) / [#172](https://github.com/s977043/plangate/issues/172)（全件 CLOSED）
> 期間: 2026-05-01（同日 2 セッション目、Auto Mode）

## サマリ

retrospective 2026-05-01 で起票した V2 候補 6 件のうち **軽量 4 件**（#167 / #170 / #171 / #172）を 1 セッションで完走 → 全件マージ。残 2 件（#168 session log parser / #169 残 Hook 実装）は影響範囲が広く別セッションへ。

| 指標 | 値 |
|------|---|
| 完了 PBI | **4 / 4**（TASK-0050〜0053）|
| マージ PR | **4 件**（#173〜#176）|
| Issue auto-close | **4 / 4** |
| 累計追加 | **+667 行 + コンフリクト解決 0**（リファクタ主体）|
| ローカル test | **21/21 PASS**（数値変動なし、構造のみ変化）|
| 直前 retrospective からの V2 消化率 | 4 / 6 = **67%** |

## 対応マッピング

| Issue | PR | TASK | mode | 主成果物 |
|-------|----|----|------|---------|
| #170 | #173 | TASK-0050 | light | tests/extras/ 分離 + 4 ファイル + README |
| #172 | #174 | TASK-0051 | light | scripts/schema_mapping.py（DRY 化）|
| #171 | #175 | TASK-0052 | light | scripts/gh-pin-account.sh + SessionStart hook |
| #167 | #176 | TASK-0053 | light | c3/c4 schema に `patternProperties: ^_` 追加 |

## Keep（うまくいったこと）

### K-1. 軽量 4 件先行戦略が時短に直結

前回 retrospective で「High 優先度」とされた #167 と「Low 優先度」とされた #170 / #172 を **mode 軽量度で並べ替えた** プラン A を採用。tests/extras/ 分離 → schema_mapping DRY → gh shim → c3 schema 緩和の順で進めることで、各タスクの所要時間 15〜30 分で完走。コンフリクト解決時間も最小（直前マージ後の差分が小さい）。

### K-2. retrospective Try → V2 issue → 実装 → 解消の流れが回り始めた

前 retrospective（#166）で生成した issue #167〜#172 が、本セッションで 4 件着手・解消。プロセスとしての **「振り返り → 課題化 → 順次解消」サイクル** が初めて完結した。次回も同じサイクルで残 2 件 + 新規発見を消化できる見込み。

### K-3. tests/extras/ 分離が即効果

#173（#170）のマージ後、後続の #174 / #175 / #176 では `tests/run-tests.sh` のコンフリクトがゼロ。本 retrospective で実証された通り、設計通りの効果。次回以降の連続 PR でも有効。

### K-4. schema 緩和の Option B 選択が最小工数で完結

#167 で当初 standard mode 想定だったが、`patternProperties: { "^_": {} }` 追加で 2 ファイル変更だけで 6 PBI 全件適合化。既存 c3.json は **1 文字も変更せず**、履歴汚染ゼロ。Option A（既存ファイル正規化）と比較して工数は 1/3 以下。

### K-5. gh-pin-account.sh が即運用に乗った

#175 マージ後、本 retrospective 作業中の `gh pr merge` 実行前に `sh scripts/gh-pin-account.sh` を挟むだけで gh active account 切戻問題が解消。実装 → 即適用の好例。

## Problem（課題・反省）

### P-1. gh CLI の active account 切戻が依然継続

#175 で対応スクリプトを実装したが、本セッション中も `gh pr merge` 等の前後で `gh-pin-account.sh` を毎回手動実行する必要があった（4〜5 回）。SessionStart hook を実 `.claude/settings.json` に登録すれば自動化できるが、本 PR では example のみ提供（自己適用なし）。

**対策**: 次セッション開始時に `.claude/settings.json` へ手動登録、効果検証を retrospective へ。

### P-2. Auto Mode 下でも結果的に確認ステップが多い

5 PR 連続のときと比較してコンフリクトはゼロだが、各 PBI で `pbi-input` / `plan` / `todo` / `test-cases` / `handoff` の 5 ファイル + main 実装 + PR 作成と、light mode でもそれなりのオーバーヘッドがある。light mode の handoff を **任意化** または **テンプレ自動生成化** すべきか議論余地。

**対策**: light mode 専用の簡略 handoff テンプレを別 PBI で検討（V2 候補）。

### P-3. retrospective を main 直接 commit できない（ruleset）

直前セッション同様、本 retrospective も main 直接 commit が ruleset で拒否される → 別 PR 化が必要。memory には記録済だが、毎回試して失敗するパターン。

**対策**: retrospective 用ブランチ命名規則（`docs/retrospective-YYYY-MM-DD[-sN]`）を CLAUDE.md に明文化し、最初から PR 経由で進めるよう強制（V2 候補）。

## Try（次にやること）

### T-1. 残 V2 issue（#168 / #169）の着手

| Issue | mode | 推奨タイミング |
|-------|------|------------|
| **#168** session log NDJSON parser | high-risk | 別セッション、3〜4 時間想定 |
| **#169** 残 Hook 実装（EH-1 / EH-3〜7 / EHS-1）| critical | EPIC、1 hook 1 PBI で段階分割 |

### T-2. SessionStart hook の自己適用

`.claude/settings.example.json` の SessionStart hook を本リポジトリ作業者の `.claude/settings.json` に手動登録。1 セッションでの切戻発生回数を測定し、retrospective へ。

### T-3. light mode handoff テンプレ簡略化

P-2 の対応。light mode で handoff.md 必須 6 要素のうち 1〜2（既知課題 / V2 候補）が空欄になりがちな実態を踏まえ、**簡略テンプレ**（5 要素 1 ページ程度）を提供する別 PBI を起票候補。

### T-4. retrospective 命名規則の正本化

P-3 の対応。`docs/retrospective-YYYY-MM-DD[-sN]` 命名 + 必ず PR 経由のルールを CLAUDE.md / `.claude/rules/working-context.md` に追記。

## メトリクス

| 指標 | 値 |
|------|---|
| 計画 PR 数 | 4 |
| 計画外 PR | 0 |
| マージコンフリクト | **0 件**（#170 効果で本セッションは衝突ゼロ）|
| handoff 必須 6 要素完備率 | **4/4 = 100%** |
| ローカル test PASS 率 | **21/21 = 100%**（変動なし）|
| CI 緑率 | **4/4 = 100%** |
| Issue auto-close 率 | **4/4 = 100%** |
| EPIC 期間 | 1 セッション（数時間）|

## 関連リンク

- 親 retrospective: [`docs/working/retrospective-2026-05-01.md`](retrospective-2026-05-01.md) § Try T-1〜T-6
- マージ済 PR: #173 / #174 / #175 / #176
- 完了 PBI: TASK-0050 / 0051 / 0052 / 0053
- 主要成果物:
  - [`tests/extras/`](../../tests/extras/) + [`tests/extras/README.md`](../../tests/extras/README.md)
  - [`scripts/schema_mapping.py`](../../scripts/schema_mapping.py)
  - [`scripts/gh-pin-account.sh`](../../scripts/gh-pin-account.sh)
  - [`schemas/c3-approval.schema.json`](../../schemas/c3-approval.schema.json) `patternProperties`
  - [`schemas/c4-approval.schema.json`](../../schemas/c4-approval.schema.json) `patternProperties`
- 残 V2 issue: [#168](https://github.com/s977043/plangate/issues/168) / [#169](https://github.com/s977043/plangate/issues/169)
