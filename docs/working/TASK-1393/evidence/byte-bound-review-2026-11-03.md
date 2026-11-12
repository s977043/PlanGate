# TASK-1393 / #1623 — byte上限の診断とPR再検証（2026-11-03）

## 判定と変更範囲

PR #1635の継続調査。基準mainは `0d8d9468b815ed7068b31b1a5742667d745ad202`、調査開始時のPR HEADは `7af9a48472e50a3466bc886617829d7c76bd752a`。
本ファイルは非権威の診断Evidenceであり、Production実装、C-3/C-4、preflight免除、独立レビュー、Delivery完成を宣言しない。

今回は前回の局所検証を再実行し、#1623の最大byte算出で必要な境界を調べた。新しい診断プログラムは会話添付の検証bundleに保存し、repositoryのruntime・CIには導入していない。承認済みPlan、approval artifact、runtime、canon、workflowは変更していない。

## F-1: ASCIIの文字数とJSONのbyte数を混同しない

現行TASK-1393 plan Revision 2.10 / I-11は、ref・fingerprintをsha256形式に制限する一方、`verifier_id`はASCIIかつ71文字以下としている。IDにref用の形式制約を適用しないというR-092の決定を維持する。

基準mainの `run_event.canonical_bytes` をそのまま読み込み、全ASCII 128 codepointの71文字反復を、別に実装したJSON文字列長の計算と照合した。
serializerは `json.dumps(..., ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")`。

| 値 | 文字数 | canonical JSONのbyte数（引用符込み） |
|---|---:|---:|
| `sha256:` + 小文字hex 64桁 | 71 | 73 |
| 引用符またはbackslashの反復 | 71 | 144 |
| U+0001等、6文字escapeになる制御文字の反復 | 71 | 428 |

さらに、互いに異なるASCII ID 16件（各71文字）の配列を測定した。

| 計算 | byte数 |
|---|---:|
| 各文字1byteと仮定した配列長 | 1,185 |
| serializerによる実測 | 6,845 |
| escapeを数える独立計算 | 6,845 |

「ASCIIならJSONでも各文字1byte」という仮説は明示的なAssertionErrorで棄却された。通常の診断は139個の内部チェックを通過する。139は検査点の数であり、独立した139テストや受入基準の達成数ではない。

**適用範囲:** 上記は文字列・配列コンポーネントの測定であり、合意済みの `decision_made` 全体の最大サイズではない。ref配列の `n × 74` という目安自体を誤りとはしていない。これを一般のASCII IDに流用してはいけないという指摘である。

**推奨:** 許可されたASCII範囲を勝手に狭めず、採用serializerのencoded bytesで計算・検査する。IDの許容文字種を変える場合は契約変更として扱う。

## F-2: envelopeの上限はEvent構造だけでなくowner契約から導く

同じ未変更の暫定 `run_event.py` に2イベントのsynthetic streamを渡し、`validate_stream` 単体が受理する範囲を診断した。結論を入力する診断であり、Decisionを実走したE2Eではない。

| 変更項目 | 入力の大きさ | decision Eventのbyte数 |
|---|---:|---:|
| run_id | 12文字 | 612 |
| run_id | 68文字 | 668 |
| run_id | 4,100文字 | 4,700 |
| revision | 十進数1桁 | 614 |
| revision | 十進数101桁 | 714 |
| revision | 十進数1,001桁 | 1,614 |

この診断が示すのは、暫定Event validator単体から固定の最大envelopeサイズを推定できないことだけである。#1392のModel BにあるRun ID文法、streamから導くrevision/position、#1395のbudget等を消費すれば上限が導ける可能性があり、Productionの脆弱性や正式RunStateの欠陥とは断定しない。

対照として、単体Eventが受理する巨大event_seqを非連続streamへ入れると `validate_stream` は拒否した。単体validatorとstream validatorの受理範囲を同一視しない。event_refの改竄とsha256 refへの一般ASCII混入も拒否された。

## F-3: CIの報告SHAと実際のcheckoutを区別する

調査開始時HEAD `7af9a484...` に紐づくTest / CI / CodeQL / Check PR Issue Linkはsuccess。
Test run `41484672919`、job `125411719401` の実ログまで確認した。

- 実行コマンド: `sh tests/run-tests.sh`
- checkout: PRとmainのsynthetic merge `d6a7e5713dacc02c58126c54d679de3e64c19eee`
- 組合せ: head `7af9a484...` + base `0d8d9468...`
- runner最終集計: `Results: 1556 passed, 0 failed`
- TA-118: 5 tests OK
- TA-87: executable specification / 18 mutation classes killed
- TA-92: 48 tests OK、TA-93: 28 tests OK

上記は取得したActionsの実行結果であり、この会話のコンテナで全suiteを実行した結果ではない。runnerの集計単位を全受入基準数へ変換しない。ログにはSKIP・WARN・既知gapもあり、すべての検証条件が満たされたとは言わない。TA名や成功件数によって暫定fixtureを正式Delivery完成のEvidenceへ昇格しない。

この記録を追加した後のPR HEADは別候補なので、上記の成功をそのまま流用しない。新HEADとそのbaseの組合せについてCIを再確認する。

## 外部レビューの実行結果

既存の `copilot-pull-request-reviewer[bot]` にレビューを依頼したが、review `5743518731` は利用枠不足のためレビューできないという返答だった。

- 対象: `7af9a48472e50a3466bc886617829d7c76bd752a`
- submitted_at: `2026-11-02T21:20:39Z`
- GitHub上のstate: COMMENTED
- 実質的なコード／文書レビュー: **未実行**

COMMENTEDを承認・独立レビュー完了と扱わない。課金設定変更・追加枠購入・制限回避は行わず、同じ依頼を繰り返していない。通常のAgent/Task実行手段とClaude/Codex CLIも利用できず、以下は同一assistantのI0のみ。

## 今回の5ラウンド

| Round | 検証とレビュー | 修正・再検証 |
|---|---|---|
| R1 | 前回bundleの4 source blobを照合し、22コマンドを再実行 | 全期待exit一致。部分snapshotの範囲に限定した記述を維持 |
| R2 | ASCII文字数からJSON上限を見積もる仮説を反例で検査 | 仮説はexit 1。serializer実測とescape別計算が一致する診断へ修正 |
| R3 | 最適化実行、source改竄、誤った長さ計算のmutantを検査 | `assert`依存を明示raiseへ変更し、`python -O`でも偽の仮説を検出。独立した2 mutantをAssertionErrorで検出 |
| R4 | 出力先とsourceの同一指定、sh誤起動、validator層の違いを検査 | source上書き拒否・sh exit 2を確認。暫定Event APIだけの診断と明記して再実行 |
| R5 | source同一性・出力再現性・再実行時の記録を点検 | 実行履歴の累積をやめ、各再実行が12件で始まるrunnerへ修正。時刻以外の診断JSONが一致 |

途中で診断プログラムのPG-SH-GUARD追加時に、`from __future__`より前の第二の文字列が原因となるSyntaxErrorを1回検出した。説明文を定数へ移して修正し、再実行で成功した。この失敗ログもbundleに保存しており、初回から全成功とはしていない。

最終診断セットは12コマンドで期待exitと実測が一致。上記の途中のSyntaxErrorは別記録で、12件から黙って消した成功集計ではない。

| 最終診断 | 期待exit | 実測exit |
|---|---:|---:|
| R2-naive-bound-red | 1 | 1 |
| R2-serializer-measurement-green | 0 | 0 |
| R3-after-explicit-failure-fix | 0 | 0 |
| R3-optimized-red-still-fails | 1 | 1 |
| R3-optimized-green-still-passes | 0 | 0 |
| R3-tampered-source | 1 | 1 |
| R3-naive-oracle-mutant | 1 | 1 |
| R3-incorrect-maximum-mutant | 1 | 1 |
| R4-output-must-not-overwrite-source | 2 | 2 |
| R4-sh-misinvocation-guard | 2 | 2 |
| R4-provenance-and-controls-recheck | 0 | 0 |
| R5-final-candidate | 0 | 0 |

## 再現性と出典

- 取得元: 基準mainの `scripts/ai-loop-v2/run_event.py`
- Git blob SHA1: `540cf472406fb19870059058f52b2e1f40240ea8`
- 検証済みbytesをそのままcompileし、読み直しによる差替えを避けた。
- 最終診断 `byte_bound_probe.py` のSHA256: `eb7571d0660ef0d5906ecd9e22a377836d4f0e48f93f0baffc81cca61f3944f4`
- 最終runner `run_probe_reviews.py` のSHA256: `584d87469f53296d8b3800dedf8f0e8f663d4dd656b56dd0a403af53b3fcc8bf`
- 実行環境: Linux / Python 3.13.5
- Plan参照: TASK-1393 Revision 2.10 / I-11 / R-092、#1623、TASK-1392 Model B

source、全診断コード、結果JSON、生ログ、最初の失敗ログは会話添付のbundleに収録した。これは追加の実行許可を表さず、ProductionやCIへ自動導入しない。

bundle内の再現コマンド:

```sh
python3 previous/run_local_validation.py
python3 run_probe_reviews.py
```

## 次の実装単位と終了条件

| 順序 | 対応 | Owner / 終了条件 |
|---|---|---|
| 1 | C-3実物とPlan・必要preflightを照合 | 実行環境。未確認の承認を発行済み・有効と推測しない |
| 2 | decision Event構造と可変field上限を固定 | #1391/#1392/#1393。構造確定とruntime全体の完成を分離し、相互待ちを解く |
| 3 | 最大byte fixture・serializer境界を実装 | #1623。一般ASCII IDはescape込み、envelopeの数値はowner/budget由来。#1393のC-3を自動流用しない |
| 4 | I-11入力拒否とappend検査・terminal reserveを接続 | #1393/#1391/#1392。定数を置くだけで#1623をcloseしない |
| 5 | 正式ownerの統合と延期検査の有効化 | #1395、#1391 D-12。必要なPlan差分・再C-3を維持 |
| 6 | Path A/B、AC-6の実証 | #1383→#1381。exact candidateのCIと必要な独立レビューを確認 |

合意済み文字種を狭めたり、byte guardを省略したりしてこの診断をgreenにしない。
#1635の独立レビュー・必要なC-4は未完了。Delivery First ReleaseはBLOCKEDで、残タスクゼロではない。

## 追記（2026-11-05 01:58）

本記録の根拠（診断コード・結果JSON・生ログ・失敗ログ）は repo 外の bundle にあり、repo 内では再現不能（bundle は repo 外）。
