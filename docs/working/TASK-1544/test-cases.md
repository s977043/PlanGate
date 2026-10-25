# TASK-1544 TEST CASES

すべて `tests/extras/ta-118-retro-seed-draft.sh` で自動実行する。fixture は mktemp の sandbox に作る
（task-dir: `pbi-input.md` / `approvals/c3.json` / `handoff.md`、seeds: 既存エントリ 1 件入りの `improvement-seeds.md`）。
各 TC は終了コードと、seeds の実行前後の sha256 を照合する。

## 受入基準 → テストケース マッピング

| AC | TC |
|----|----|
| AC-1 | TC-01〜TC-03, TC-07, TC-08, TC-E01〜E03 |
| AC-2 | TC-01〜TC-03, TC-09 |
| AC-3 | TC-04, TC-05, TC-10 |
| AC-4 | TC-06, TC-11 |
| AC-5 | 変異注入計画 M-1〜M-4 |

## 組合せ表: retro_enabled × confirmed_by

c3.json は APPROVED に固定する。「draft」は `draft` の結果、「append」は `append` の結果。

| TC | retro_enabled | 下書きの confirmed_by | draft の期待 | append の期待 | seeds |
|----|--------------|---------------------|-------------|--------------|-------|
| TC-01 | false | 空 | exit 3・stdout 空 | exit 3 | 不変 |
| TC-02 | 欠落 | 空 | exit 3・stdout 空 | exit 3 | 不変 |
| TC-03 | true | 空 | exit 0・下書きに `confirmed_by:` 空欄、既知課題の行を含む | （下記 TC-04） | 不変 |
| TC-04 | true | 空 | — | exit 4 | 不変 |
| TC-05 | true | `<human>`（プレースホルダ） | — | exit 4 | 不変 |
| TC-06 | true | 入力済み（`mine_take`） | — | exit 0 | 末尾に 1 エントリ追記・既存部分はバイト一致 |
| TC-12 | false | 入力済み | — | exit 3（confirm 済みでも opt-in 不成立なら追記しない） | 不変 |
| TC-13 | 欠落 | 入力済み | — | exit 3 | 不変 |

## テストケース一覧（組合せ表以外）

### TC-07: C-3 未承認

前提: `retro_enabled: true`、c3.json の `c3_status` が `CONDITIONAL`。期待: draft exit 3・stdout 空、append exit 3、seeds 不変。

### TC-08: c3.json なし

前提: `retro_enabled: true`、approvals/ なし。期待: draft exit 3、seeds 不変。

### TC-09: draft の出力先に seeds を指定

`draft --out <seeds>`。期待: exit 2、seeds 不変。

### TC-10: 生成器が confirmed_by を埋めない

TC-03 の下書きの `confirmed_by:` 行の値が空であること（行末まで空白のみ）。

### TC-11: 追記後の seeds が L2 の検査を通る

TC-06 の後の seeds に `python3 scripts/improvement_seed_delta.py` の検査を実行し、正規形として受理されること（引数は exec 時に同スクリプトの CLI に合わせて確定し、status.md に記録する）。

## Edge Cases

### TC-E01: 値の表記ゆれ

`retro_enabled: "true"` / `retro_enabled: yes` / `retro_enabled: True` は不成立（exit 3）。行頭行末の空白付きの `retro_enabled: true` は成立。

### TC-E02: コメント内の記述

`<!-- retro_enabled: true -->` だけがある pbi-input は不成立（exit 3）。

### TC-E03: 壊れた c3.json

JSON として読めない c3.json は不成立（exit 3）。例外のスタックトレースで落ちない。

### TC-E04: handoff に §2 が無い

draft は exit 2。stdout は空。

## 変異注入計画（AC-5）

各変異を作業ツリーで 1 つずつ注入し、期待どおりの TC が FAIL することを記録して戻す（commit しない）。

| ID | 変異 | FAIL すべき TC |
|----|------|---------------|
| M-1 | ゲート関数を常に True を返すようにする | TC-01, TC-02, TC-07, TC-08, TC-12, TC-13 |
| M-2 | append の confirmed_by 検査を除去する | TC-04, TC-05 |
| M-3 | append を上書き（`"w"`）にする | TC-06 |
| M-4 | append でゲートを呼ばない（draft のゲートだけ残す） | TC-12, TC-13 |

また、生成器が無い状態（Task 1 の RED）で TA-118 が FAIL することも記録する。

## 自動化可否

全 TC 自動化可。

## 検証結果（V-1 で記入）

（未実施）
