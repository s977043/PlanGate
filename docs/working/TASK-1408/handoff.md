---
task_id: TASK-1408
artifact_type: handoff
schema_version: 1
status: issued
issued_at: 2026-11-12 07:57
issued_at_commit: 5dae38c0d3c792684ae05dc30444d4bfbee0c612（PR #1650 作成時の head。本書の実測値はこの SHA 時点のもの。以後の同期 commit で値は変わらない）
author: qa-reviewer（下書き: 作成者 context）
v1_release: ""
---

# TASK-1408 Handoff

> **C-4 に渡す条件**: status.md「記録欄」の TODO がすべてレビュアーの手で埋まり、T-10（独立再実行）の結果が `evidence/independent-rerun.txt` にあること。TODO が残る間は C-4 に渡さない。
> 本 handoff は充足を宣言しない（§7「I4 の充足記録」）。

## メタ情報

```yaml
task: TASK-1408
related_issue: https://github.com/s977043/plangate/issues/1408, https://github.com/s977043/plangate/issues/1329
split_issue: https://github.com/s977043/plangate/issues/1643
author: qa-reviewer
issued_at: 2026-11-12 07:57
issued_at_commit: 5dae38c0d3c792684ae05dc30444d4bfbee0c612  # PR #1650 作成時の head
pr: https://github.com/s977043/plangate/pull/1650  # 2026-11-12T16:49:09Z 作成
base: 9445df175e93fab31493274915bb35ab01cad4f1
canon_sha: e5573cc89b76d5c493aa10d548d22ac7ed7abc2c
evidence_head: 6d1f7a6b5ff52cda320e7ed99fdb9ad0ccf3a311（T-10 独立 worker が記録。check.sh rc=0）
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
| --- | --- | --- |
| 1408-AC-1 | PASS | TC-01（gh の oid と §7 が完全一致） |
| 1408-AC-2 / 1329-AC-1 | PASS | TC-02、TC-E03（3 時点の実測。親が負の対照） |
| 1408-AC-3 / 1329-AC-2 | PASS | TC-03 |
| 1408-AC-4 | PASS | TC-03、TC-05 |
| 1408-AC-5 | PASS | TC-04 |
| 1408-AC-6 | WARN | TC-07 は PASS。TC-08 は書き換え忘れの検出に縮小した（R-109）。T-10 の独立再実行は 2026-11-12 に完了（reviewed_at_sha `6d1f7a6b`、check.sh rc=0、`evidence/independent-rerun.txt`）。記録欄は PR #1650 本文に転記済み。I4 の機械証跡は未充足 |
| 1408-AC-7 | 未判定 | Human merge（TC-10。手動） |
| 1329-AC-3 | PASS | TC-05 |
| 1329-AC-4 | PASS | TC-09（CI: `gh pr checks 1650` で 13 本すべて pass。2026-11-13 07:27 測定、head `cea228cc`） |
| 1329-AC-5 | PASS | TC-06（H-00 の承認は plan に記録） |

**総合**: WARN（全 12 基準のうち 10 PASS / 1 WARN / 1 未判定。T-10 の独立再実行は完了。I4 の充足は本 handoff では宣言しない。判定は Human C-4 による（§7「I4 の充足記録」）。evidence 層は改ざんを検出しない（status.md 残存脅威モデル））

**WARN の扱い**: 残因は AC-6 の I4 充足判定（Human C-4）と AC-7 の Human merge に限る。T-10、記録欄の記入、PR #1650 本文への転記は完了した。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
| --- | --- | --- | --- |
| evidence 層は改ざんを検出できない（自己参照、R-106） | major | accepted（再現手順へ格下げ。残存脅威モデルに記載） | Yes |
| `sh tests/run-tests.sh` が TA-100（`output parent path must not traverse symlinks`）で rc=2 となり、以降は未評価 | minor | open（環境依存。本変更に起因しない）。継承した TMPDIR（`/var/folders/...`）は `/private/var` への symlink を含み、Python の `tempfile` がそこを使うと unit が落ちる。TMPDIR を実パスにすると unit は通るが、TA-100 の手順 3（`tests/extras/ta-100-…sh` L44）が引数なしの `mktemp -d` を使っている。macOS の `mktemp -d` はテンプレートなしでは TMPDIR を見ずに `/var/folders` に作るので、TMPDIR の設定に関係なく落ちる（実測: probe）。未変更の `9445df17` でも同じ箇所で同じ失敗 | No（別 issue 候補） |
| `tests/extras/ta-49-bias-export.sh` L73 / L81 / L87 が固定パス `/tmp/ta49_err` / `/tmp/ta49_err2` を使う | minor | open（本変更に起因しない）。run-tests を並行実行すると互いのファイルを消し合う。head と対照を並行で走らせた shim 版の結果（head: TA-49 TC-04 FAIL、対照: 同じ箇所で rc=1 終了）は汚染されているので、参考値として扱う | No（別 issue 候補） |
| head の単独・直列 run-tests で、ta-61 TC-12 の stage-1 が 4 本タイムアウト（ta-62 / ta-65 / ta-70 / ta-71、180s） | minor | open。**負荷に帰属（確定）**。4 本を個別に standalone で再実行すると、head ではすべて rc=0 だった。未変更の対照でも、ta-62 は負荷が上がったとき（load1 12→28）に同じ型のタイムアウトで rc=1 になった。ta-62 は 174〜180s で、上限 180s に近い | No（ta-62 の上限余裕は別 issue 候補） |
| CI の markdownlint v25 での結果が未確認（ローカルは 0.18.1 で 0 error） | minor | open | No |
| 失効後 4 commit の扱いは未裁定 | — | #1643 で Human 裁定 | No |
| run-tests の head `c571a65c`（§6）が `9c5b3262..5dae38c0` に含まれず、PR 内容に対する結果と確認できない（PR #1650 レビュー指摘 6） | minor | PR head `276f36a4` で取り直した（単独・直列、rc=1、1552 passed / 3 failed）。タイムアウト 2 件は負荷に帰属。TA-10 TC-7 は対照 `9445df17` でも同じ FAIL が出ており、既知 issue #1651（OPEN）として本変更に帰属しない（§6）。`c571a65c` のログは PR 外の SHA で測った参考値として残す。判定は WARN のまま | No |
| PR は `BEHIND`（base `9445df17`）。main 取り込みで `canon..head` の固定が崩れ REPRO-CHECK が FAIL する見込み（未実行。指摘 7） | major | **Human 裁定済み（2026-11-13）**: main を取り込まず、照合点は evidence head `6d1f7a6b` に固定する | No |

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
- exec レビューの記録は `review-external.md` の末尾（R-101〜R-112）
- merge 後の #1329 / #1374 へのコメント（Q-5）は Human の名指し承認が要る（H-02）

## 6. テスト結果サマリ

| 検査 | 結果 |
| --- | --- |
| check.sh（REPRO-CHECK + TC-01〜09、11、E01〜E03） | rc=0（転記後の evidence head `6d1f7a6b` で、T-10 の独立 worker が 4 引数で再実行して満たした。下記「独立再実行（T-10）」） |
| `sh tests/run-tests.sh`（継承 TMPDIR） | rc=2。TA-100 unit で停止。対照 `9445df17` も同じ失敗（PASS 86、186 行で一致）。ログ: `evidence/test-runs/` |
| 同（TMPDIR を実パスに） | head・対照とも rc=2。TA-100 unit は PASS し、TA-100 手順 3（L44 の `mktemp -d`）で停止（PASS 87、139 行で一致） |
| 同（実パス TMPDIR + scratch の mktemp shim、**並行実行**） | **参考値**（ta-49 の固定 `/tmp` パスで干渉）。TA-100 は head・対照とも通過 |
| 同（単独・直列。対照 → head の順） | 対照 `9445df17`: rc=0、1556 passed / 0 failed。head `c571a65c`: rc=1、1548 passed / 4 failed（ta-61 TC-12 のタイムアウト 4 件）。4 本を個別に standalone で再実行すると head はすべて rc=0、対照は ta-62 のみ負荷によるタイムアウトで rc=1（`evidence/test-runs/standalone-4.txt`）。負荷に帰属すると確定した。並行実行時の TA-49 TC-04 FAIL は、単独実行では head・対照とも再現しなかった（干渉と確定）。ログ: `evidence/test-runs/*-shim-serial.txt`。shim: `evidence/test-runs/mktemp-shim.sh.txt`。**head `c571a65c` は PR の履歴にない SHA で測った参考値**（指摘 6） |
| 同（単独・直列、**PR head `276f36a4`**） | rc=1、1552 passed / 3 failed（load1 8.8 → 35.5）。FAIL は TA-10 TC-7（`doctor --json` の default と `--scope v8.6.0` の不一致または hooks scope の検査）、ta-61 TC-12(b) の ta-62 タイムアウト（180s、load1 31）、TA-62 TC-D の driver タイムアウト（180s）。`9445df17..276f36a4` に `bin/` `scripts/` `tests/` の差分はない。タイムアウト 2 件は負荷に帰属。TA-10 TC-7 は standalone で head・対照の両方に同じ FAIL が出ており（`standalone-pr-head-276f36a4.txt` 33 行目・77 行目）、既知 issue #1651（OPEN）として本変更に帰属しない。standalone の rc は FAIL を exit code に反映しない（#921）ので判定に使わない。standalone 手順は cwd の誤りで TC-1/3a/3b/3c/4/5/6/E1/E2 も FAIL しており不完全だった。ログ: `evidence/test-runs/run-tests-pr-head-276f36a4.txt`、`evidence/test-runs/standalone-pr-head-276f36a4.txt` |
| markdownlint-cli2 0.18.1 | 0 error（変更した .md） |
| 独立再実行（T-10） | rc=0。REPRO-CHECK 11 項目と TC 全件が exit=0。陽性対照（古い evidence head）は rc=3。check.sh・measure.sh の digest は作成者の申告値と一致（`evidence/independent-rerun.txt`） |
