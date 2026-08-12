# TEST CASES — TASK-1036

> すべて件数のハードコードなし（同値照合 / 集合照合 / 配置検査のみ）。
> 実測スナップショット（32/15/17/44s 等）は根拠情報であり期待値・契約値にしない。

## Test Cases

| ID | 対応 AC | 前提 / 入力 | 期待結果 | 種別 |
|---|---|---|---|---|
| T1036-TC-D | AC-1, AC-2 | ミニ harness ラッパ（`pass/fail/register_cleanup` + 実 `FIXTURES_DIR` + `PG_HARNESS_SOURCED=1`）で `ta-26` を source。(1) `PG_T26_NO_RECURSE=1` export 下の leak 実行、(2) env なしの clean 実行 | 2 実行の出力が `diff` で完全一致、かつ leak 実行に再帰防止起因の `[SKIP]` 行が 0 | 動的 / `ta-62` 内 |
| T1036-TC-S | AC-2, AC-4 | `ta-26` と `run-tests.sh` の実ファイルを grep 検査 | (1) `ta-26` harness 分岐（`PG_T26_STANDALONE=0` の else 節ブロック）に `unset PG_T26_NO_RECURSE` が存在、(2) preamble 無条件経路 / standalone 分岐に存在しない、(3) `run-tests.sh` の unset 集合に `PG_T26_NO_RECURSE` が混入していない | 静的 / `ta-62` 内 |
| T1036-TC-M1 | AC-2 | tmp 複製の `ta-26` から修正行（harness 分岐の unset）を削除（置換件数=1・mutant `sh -n` PASS） | **T1036-TC-D そのものが FAIL**（leak 実行に `[SKIP]` 出現・diff 不一致）。復元後 PASS | 変異（動的）/ 検証手順 |
| T1036-TC-M2 | AC-2 | tmp 複製で unset を preamble 無条件経路へ移動（案 (c) 型・置換件数=1・`sh -n` PASS）。**動的実行禁止**（孫 spawn 再入ループ） | **T1036-TC-S そのものが FAIL**（配置検査 (1)(2) 不成立）。復元後 PASS | 変異（静的のみ）/ 検証手順 |
| T1036-TC-M3 | AC-2, AC-4 | リポジトリ外 sandbox（`git archive`）の `run-tests.sh` unset 行へ `PG_T26_NO_RECURSE` を追加（案 (a) 型） | sandbox で **既存 TC-33 が FAIL**（unset 欠落検出）+ T1036-TC-S (3) が FAIL。復元後 PASS | 変異（sandbox）/ 検証手順 |
| T1036-TC-R1 | AC-3 | 修正後 tree で `PG_T26_NO_RECURSE=1` をコマンド単位前置し `ta-26` を直接起動（TC-13 の子相当 2 系統 = L298/L301 と同形） | 従来どおりゲート発火（再帰防止 `[SKIP]` が出て gated TC が省略され、0 failed / rc=0）。既存 TC-13 が harness / standalone で PASS のまま（#1012 AC-1 継続） | 回帰 / 実行手順 |
| T1036-TC-R2 | AC-4 | 修正後 tree で 3 系統実行: (i) `sh tests/run-tests.sh`、(ii) `sh tests/extras/ta-26-plugin-sync.sh </dev/null`、(iii) `PG_T26_NO_RECURSE=1` 前置直接起動 | 3 系統すべて `ta-26` が 0 failed。**TC-33 が PASS のまま**。TC-30（README 規約 grep）も PASS のまま | 回帰 / 実行手順 |
| T1036-TC-E1 | AC-1 | `PG_T26_NO_RECURSE=1` を export した `sh tests/run-tests.sh` と env なし実行の 2 回（同一 tree） | `ta-26` セクション（`=== TA-26` 〜 次の `=== TA-` 直前）の切り出しが `diff` で完全一致・`[SKIP]` 0（pbi-input N-7 D-C/D-D 方式） | E2E / 実行手順 |
| T1036-TC-E2 | AC-5 | `tests/extras/README.md` を目視 + grep | 規約 7 に本 env が harness 側で無害化される対象である旨、規約 8 近傍に `ta-26` standalone 分岐で意図的に unset しない旨（理由 = ガード破壊）が読み取れる | 静的 / レビュー |

## エッジケース

| ケース | 扱い |
|---|---|
| leak env の値が `1` 以外（例: `PG_T26_NO_RECURSE=0` / 空文字）で export される | ゲートは `:-0` = `1` 比較のため実害なしだが、案 (d) の unset は値によらず消す（同値照合で自動的に検証される） |
| leak と TC-13 の子が同時（export 済み環境で harness 実行 → 親で unset → TC-13 が子へ前置） | 子は standalone 分岐で前置 env 保持 → ガード発火（T1036-TC-R1 / 既存 TC-13 が担保） |
| ミニ harness ラッパと実 run-tests.sh の環境乖離 | T1036-TC-E1（実 run-tests.sh 2 回実走）が最終判定を担う二重化（plan R-P8） |
| `ta-62` 自身への env 漏れ | `ta-62` は #921 契約 bootstrap + TC-33 静的包含要件の unset 行を持つ。`PG_T62_NO_RECURSE` 型の独自ガードは設けない（同型の穴を新設しない / plan） |

## Traceability

| AC | Test |
|---|---|
| AC-1 | T1036-TC-D, T1036-TC-E1 |
| AC-2 | T1036-TC-D, T1036-TC-S, T1036-TC-M1, T1036-TC-M2, T1036-TC-M3 |
| AC-3 | T1036-TC-R1（+ 既存 TC-13） |
| AC-4 | T1036-TC-R2, T1036-TC-S(3), T1036-TC-M3（+ 既存 TC-33 / TC-30） |
| AC-5 | T1036-TC-E2 |

## Exit Criteria

- AC-1〜5 に未検証がない
- 変異 M-1 / M-2 / M-3 がすべて kill され、kill は**実 TC（T1036-TC-D / T1036-TC-S / 既存 TC-33）の FAIL** で示されている（インライン assert の FAIL は kill と認めない）
- M-2 が一度も動的実行されていない（evidence のコマンドログで確認可能）
- 修正前 tree での RED 証跡（T1036-TC-D / T1036-TC-S の FAIL ログ）が evidence に存在する
- 期待値に絶対件数（32 / 15 / 17 等）がハードコードされていない
- T1036-TC-D の suite 追加時間が実測記録されている（+120 秒超なら停止し人間判断 / plan S-5）
