# TASK-1036 handoff（WF-05 引き継ぎパッケージ）

> Issue: [#1036](https://github.com/s977043/plangate/issues/1036) / Mode: standard / `lite_eligible=false`
> Branch: `fix/1036-exec`（base `origin/main` = `d86eef9`）
> Plan: [`plan.md`](./plan.md)（plan_hash `sha256:638498e9...` — C-3 APPROVED 2026-08-12T09:41:46Z）

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|---|---|---|
| AC-1（leak 下 harness で ta-26 セクションが env なしと一致） | **PASS（TC-D 内蔵で実証）** | TC-D = ミニ harness で leak/clean 2 回 source の出力 diff 完全一致 + leak 側再帰防止 [SKIP] 0（`green.log`）。実 run-tests.sh 2 回実走の ta-26 セクション diff（T1036-TC-E1）はオーガナイザーが別途実行中のフルスイートで確定 |
| AC-2（回帰 TC + 変異注入で FAIL 実証） | **PASS** | RED: `red.log`（TC-D/TC-S とも FAIL・leak 側 [SKIP] 4）。変異 M-1/M-2/M-3 すべて実 TC の FAIL で kill・復元後 PASS（`mutation.log`） |
| AC-3（TC-13 の子ガード継続 / #1012 AC-1 継続） | **PASS** | `t04-child-guard.log`: `PG_T26_NO_RECURSE=1` 前置直接起動で再帰防止 [SKIP] 4・15 passed, 0 failed・rc=0 |
| AC-4（3 系統 0 failed・TC-33 PASS のまま） | **PASS（3 系統実測済み・full suite はオーガナイザー担当）** | (i) harness = ta-62 が harness 分岐で TC-D/TC-S 実行（フルスイート内で PASS・オーガナイザー転記）、(ii) standalone = `ta-62 </dev/null` rc=0 2 passed（`green.log`）、(iii) 子相当前置 = ta-26 15 passed, 0 failed rc=0（`t04-child-guard.log`）。TC-33 非破壊は M-3 で「修正では壊れない・案 (a) 型混入時のみ FAIL」を実証（`mutation.log`） |
| AC-5（README 規約 7/8 追記） | **PASS** | 規約 7 に「再帰防止シグナルは runner の unset 集合に足さず当該 extras の harness 分岐で無害化」、規約 8 に「standalone 分岐では意図的に unset しない（理由 = ガード破壊・孫 spawn）」を追記。TC-30 の grep 対象 4 文言の残存を実測確認 |

## 2. 既知課題一覧

| ID | 内容 | 影響 | 状態 |
|---|---|---|---|
| K-1 | 直接 standalone 起動時（`sh tests/extras/ta-26-plugin-sync.sh`）に `PG_T26_NO_RECURSE` が呼び出し元 env から漏れていると、ta-26 単体の TC が今までどおり黙って skip される | ローカル開発者の誤検知（harness 経路・CI は本修正で保護済み） | 既知の残存（plan Out of scope。案 (b) を採らない限り残る） |
| K-2 | ta-61 が migrated standalone-capable ファイルを suite ごとに最大 3 回 standalone 実走するため、ta-62 の TC-D（ta-26 ×2 実行）は plan 想定（単回 +約90 秒）より増幅される | suite 実行時間 | T-07 の S-5 実測に記録（下記テスト結果サマリ） |

## 3. V2 候補

- **`PG_T61_NO_RECURSE` 同型クラス**（plan P-10）: ta-61 に同じ「呼び出し元 env 漏れ」穴が残る。ta-61 の harness 分岐は契約 helper 経由のため、無害化の挿入点設計は本 PBI と別検討が必要
- 他 extras の env 汚染耐性の一斉点検（plan Out of scope）
- ta-26 の #921 実行契約（`_extra-contract.sh`）への移行（別 PBI。移行時は本修正の unset の挿入点を追従させること — ta-62 TC-S が配置を静的固定しているため移行漏れは CI で検出される）
- TC-D の軽量化（clean 側結果のファイルキャッシュ等）: S-5 実測が閾値超過なら Human 判断（plan R-P7）

## 4. 妥協点（採用しなかった選択肢と理由）

| 選択肢 | 不採用理由 |
|---|---|
| 案 (a) run-tests.sh の unset 集合へ追加 | TC-33 の包含検査が全 extras（実測 18 ファイル）へ波及（M-3 で FAIL を再実証）。carve-out セットは high-risk 化 |
| 案 (b) シグナルの argv 化 | #1012 確定ゲート構造の変更で scope 過大 |
| 案 (c) preamble 無条件 unset | TC-13 の子でもガードが消え孫 spawn 再入ループ（M-2 で TC-S が検出することを実証） |
| ta-62 への独自再帰防止ガード | 本 PBI が塞ぐ穴と同型の穴の新設（plan で禁止） |
| ta-62 を harness-only 宣言（ta-61 増幅の回避） | C-3 承認済み plan が standalone-capable を明記。AI 単独の設計変更をしない（decision-log D-008） |

## 5. 引き継ぎ文書（サマリ）

`PG_T26_NO_RECURSE`（ta-26 の再帰防止シグナル）が呼び出し元 env に export されていると、
harness 実行（`sh tests/run-tests.sh`）でも ta-26 の 4 ゲートが発火し 17 TC（mass-delete
guard 回帰 #877/#914/#970 を含む）が黙って [SKIP] で消えていた。run-tests.sh 冒頭の
unset 集合（7 env）に本シグナルは含まれず、足すと TC-33 の包含検査が全 extras に波及する。

**修正（案 (d)）**: ta-26 の harness 分岐（`PG_T26_STANDALONE=0` の else 節）でのみ
`unset PG_T26_NO_RECURSE` する。TC-13 の子はコマンド単位前置で受け取り standalone 分岐を
通るためガードは継続する。この経路分離は「`PG_HARNESS_SOURCED` は非 export」（README 規約 8 /
TC-30）に依存する。

**回帰テスト（ta-62 / #921 契約準拠）**: TC-D = ミニ harness ドライバで leak/clean の
2 回 source → 出力 diff 完全一致 + leak 側再帰防止 [SKIP] 0 + 非空下限（[PASS]≥1）。
TC-S = unset の配置検査（harness 分岐に有・無条件経路に無・runner に混入無）。
件数ハードコードなし。検出力は変異 3 種の kill で実証済み。

## 6. テスト結果サマリ

実測ログはすべて `evidence/test-runs/` に保存。

| 検証 | 結果 | ログ |
|---|---|---|
| RED（修正前 tree） | ta-62 rc=1（TC-D: leak 側再帰防止 [SKIP] 4・diff 不一致 / TC-S: 配置不成立） | `red.log` |
| GREEN（修正後 tree） | ta-62 rc=0（2 passed, 0 failed）: TC-D PASS・TC-S PASS | `green.log` |
| AC-3 子相当起動（`PG_T26_NO_RECURSE=1` 前置） | ta-26 15 passed, 0 failed / rc=0 / 再帰防止 [SKIP] 4（ガード継続） | `t04-child-guard.log` |
| TC-33 / TC-30 非破壊（修正後 tree） | 両方 PASS（TC-33 = 単独判別残存0 + unset 包含 / TC-30 = README 規約 grep） | `t04-child-guard.log` |
| 変異 M-1（修正行削除 / 動的） | kill = TC-D FAIL（leak 側 [SKIP] 4・diff 不一致）。復元後 PASS | `mutation.log` |
| 変異 M-2（案 (c) 型 / 静的のみ・動的実行 0 回） | kill = TC-S FAIL（配置不成立）。fixtures 除去で mutant source 0 回を証跡化。復元後 PASS | `mutation.log` |
| 変異 M-3（案 (a) 型 / sandbox 実走） | kill = 既存 TC-33 FAIL（18 ファイル unset 欠落）+ TC-S(3) FAIL。復元後 PASS | `mutation.log` |
| フルスイート（`sh tests/run-tests.sh`）Results + T1036-TC-E1（実 run-tests.sh 2 回実走の ta-26 セクション diff）+ S-5 実測 | **オーガナイザーが別途 background 実行し転記**（本ワーカーは再実行しない） | — |

**変異結論**: 3 変異すべて survivor なし。kill はすべて実 TC（T1036-TC-D / T1036-TC-S / 既存 TC-33）の FAIL で示し、インライン assert の FAIL を kill に数えていない（plan T-06 checkpoint 遵守 / #874 既往回避）。plan S-4（M-1 survivor で停止）非該当。
