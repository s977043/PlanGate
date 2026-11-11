---
task_id: TASK-1408
artifact_type: handoff
schema_version: 1
status: draft
issued_at: TODO
issued_at_commit: TODO（転記後の発行時点の commit SHA）
author: qa-reviewer（下書き: 作成者 context）
v1_release: ""
---

# TASK-1408 Handoff（下書き）

> **C-4 に渡す条件**: status.md「記録欄」の TODO がすべてレビュアーの手で埋まり、T-10（独立再実行）の結果が `evidence/independent-rerun.txt` にあること。TODO が残る間は C-4 に渡さない。
> 本 handoff は充足を宣言しない（§7「I4 の充足記録」）。

## メタ情報

```yaml
task: TASK-1408
related_issue: https://github.com/s977043/plangate/issues/1408, https://github.com/s977043/plangate/issues/1329
split_issue: https://github.com/s977043/plangate/issues/1643
author: qa-reviewer
issued_at: TODO
issued_at_commit: TODO
base: 9445df175e93fab31493274915bb35ab01cad4f1
canon_sha: TODO（転記後）
evidence_head: TODO（転記後。レビュアーが記録）
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
| --- | --- | --- |
| 1408-AC-1 | PASS | TC-01（gh の oid と §7 が完全一致） |
| 1408-AC-2 / 1329-AC-1 | PASS | TC-02、TC-E03（3 時点の実測。親が負の対照） |
| 1408-AC-3 / 1329-AC-2 | PASS | TC-03 |
| 1408-AC-4 | PASS | TC-03、TC-05 |
| 1408-AC-5 | PASS | TC-04 |
| 1408-AC-6 | WARN | TC-07 は PASS。TC-08 は書き換え忘れの検出に縮小した（R-109）。独立レビューの記録と T-10 の独立再実行は未実施。記録欄は TODO |
| 1408-AC-7 | 未判定 | Human merge（TC-10。手動） |
| 1329-AC-3 | PASS | TC-05 |
| 1329-AC-4 | PASS | TC-09（CI 緑は未確認） |
| 1329-AC-5 | PASS | TC-06（H-00 の承認は plan に記録） |

**総合**: WARN（全 12 基準のうち 10 PASS / 1 WARN / 1 未判定。I4 の機械証跡は未充足）

**WARN の扱い**: T-10 と記録欄の記入はレビュアーが行う。完了するまで C-4 に渡さない。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
| --- | --- | --- | --- |
| evidence 層は改ざんを検出できない（自己参照、R-106） | major | accepted（再現手順へ格下げ。残存脅威モデルに記載） | Yes |
| `sh tests/run-tests.sh` が TA-100（`output parent path must not traverse symlinks`）で rc=2 となり、以降は未評価 | minor | open（環境依存。本変更に起因しない）。継承した TMPDIR（`/var/folders/...`）は `/private/var` への symlink を含み、Python の `tempfile` がそこを使うと unit が落ちる。TMPDIR を実パスにすると unit は通るが、TA-100 の手順 3（`tests/extras/ta-100-…sh` L44）が引数なしの `mktemp -d` を使っている。macOS の `mktemp -d` はテンプレートなしでは TMPDIR を見ずに `/var/folders` に作るので、TMPDIR の設定に関係なく落ちる（実測: probe）。未変更の `9445df17` でも同じ箇所で同じ失敗 | No（別 issue 候補） |
| `tests/extras/ta-49-bias-export.sh` L73 / L81 / L87 が固定パス `/tmp/ta49_err` / `/tmp/ta49_err2` を使う | minor | open（本変更に起因しない）。run-tests を並行実行すると互いのファイルを消し合う。head と対照を並行で走らせた shim 版の結果（head: TA-49 TC-04 FAIL、対照: 同じ箇所で rc=1 終了）は汚染されているので、参考値として扱う | No（別 issue 候補） |
| head の単独・直列 run-tests で、ta-61 TC-12 の stage-1 が 4 本タイムアウト（ta-62 / ta-65 / ta-70 / ta-71、180s） | minor | open。**負荷に帰属（確定）**。4 本を個別に standalone で再実行すると、head ではすべて rc=0 だった。未変更の対照でも、ta-62 は負荷が上がったとき（load1 12→28）に同じ型のタイムアウトで rc=1 になった。ta-62 は 174〜180s で、上限 180s に近い | No（ta-62 の上限余裕は別 issue 候補） |
| CI の markdownlint v25 での結果が未確認（ローカルは 0.18.1 で 0 error） | minor | open | No |
| 失効後 4 commit の扱いは未裁定 | — | #1643 で Human 裁定 | No |

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
| --- | --- | --- | --- |
| canon 変更時に I4 証跡を CI で強制する | 本 PR は PR テンプレートの自己申告にとどまる（plan 案 B を不採用） | Medium | #1329 |
| evidence の信頼の起点を repo 外で機械化する（署名や外部記録） | repo 内の照合は改ざんを検出できない | Medium | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
| --- | --- | --- |
| §7 / §8 への追記とテンプレート 1 行 | CI gate（案 B）、extras テスト（案 C） | workflow は HO。CI は過去 SHA を持たない |
| evidence を「再現手順」と位置づける | repo 内での改ざん検出を続ける | X-R2〜X-R5 で毎ラウンド新しいクラスが出て、同じ層では収束しなかった |

## 5. 引き継ぎ文書

- canon の変更は追記のみ（削除 0）。他の canon 6 本は変更なし
- 転記手順は status.md にある。canon を commit → `regen.sh` → evidence を commit → レビュアーが記録欄を埋めて check.sh（4 引数）を実行
- exec レビューの記録は `review-external-exec.md`。既存 `review-external.md` の末尾へ追記する
- merge 後の #1329 / #1374 へのコメント（Q-5）は Human の名指し承認が要る（H-02）

## 6. テスト結果サマリ

| 検査 | 結果 |
| --- | --- |
| check.sh（REPRO-CHECK + TC-01〜09、11、E01〜E03） | rc=0（下書き clone の最終 evidence head で、ピン留めした check.sh を 4 引数で実行。転記後に再実行が要る） |
| `sh tests/run-tests.sh`（継承 TMPDIR） | rc=2。TA-100 unit で停止。対照 `9445df17` も同じ失敗（PASS 86、186 行で一致）。ログ: `evidence/test-runs/` |
| 同（TMPDIR を実パスに） | head・対照とも rc=2。TA-100 unit は PASS し、TA-100 手順 3（L44 の `mktemp -d`）で停止（PASS 87、139 行で一致） |
| 同（実パス TMPDIR + scratch の mktemp shim、**並行実行**） | **参考値**（ta-49 の固定 `/tmp` パスで干渉）。TA-100 は head・対照とも通過 |
| 同（単独・直列。対照 → head の順） | 対照 `9445df17`: rc=0、1556 passed / 0 failed。head `c571a65c`: rc=1、1548 passed / 4 failed（ta-61 TC-12 のタイムアウト 4 件）。4 本を個別に standalone で再実行すると head はすべて rc=0、対照は ta-62 のみ負荷によるタイムアウトで rc=1（`evidence/test-runs/standalone-4.txt`）。負荷に帰属すると確定した。並行実行時の TA-49 TC-04 FAIL は、単独実行では head・対照とも再現しなかった（干渉と確定）。ログ: `evidence/test-runs/*-shim-serial.txt`。shim: `evidence/test-runs/mktemp-shim.sh.txt` |
| markdownlint-cli2 0.18.1 | 0 error（変更した .md） |
| 独立再実行（T-10） | 未実施 |
