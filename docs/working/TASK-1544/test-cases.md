# TASK-1544 TEST CASES

すべて `tests/extras/ta-118-retro-seed-draft.sh` で自動実行する。fixture は mktemp の sandbox に作る
（task-dir 名 `TASK-9999`: `pbi-input.md` / `plan.md`（どちらも `retro_enabled: true` 行入り）/ `approvals/c3.json`（`plan_hash` = fixture plan.md の sha256、`task_id` = `TASK-9999`）/ `handoff.md`、seeds: 既存エントリ 1 件入りの `improvement-seeds.md`。sandbox は git 作業ツリーにしない。TC-21 だけは別の sandbox git repo を作る）。
各 TC は終了コードと、seeds の実行前後の sha256 を照合する。**終了コードは期待値と完全一致で照合する**（「非ゼロ」で受けない。R-010）。

## 受入基準 → テストケース マッピング

| AC | TC |
|----|----|
| AC-1 | TC-01〜TC-03, TC-07, TC-08, TC-16〜TC-18, TC-21, TC-E01〜E03, TC-E02b〜TC-E02e |
| AC-2 | TC-01〜TC-03, TC-09, TC-09b |
| AC-3 | TC-04, TC-04b〜TC-04d, TC-05, TC-10 |
| AC-4 | TC-06, TC-11, TC-14, TC-15, TC-20 |
| AC-5 | 変異注入計画 M-1〜M-7（M-2b を含む） |
| AC-6 | TC-19, TC-19b, TC-19c |

## 組合せ表: retro_enabled × confirmed_by

c3.json は APPROVED・plan_hash 一致に固定する。retro_enabled は pbi-input.md と plan.md の両方に同じ値を置く。「draft」は `draft` の結果、「append」は `append` の結果。

| TC | retro_enabled | 下書きの confirmed_by | draft の期待 | append の期待 | seeds |
|----|--------------|---------------------|-------------|--------------|-------|
| TC-01 | false | 空 | exit 3・stdout 空 | exit 3 | 不変 |
| TC-02 | 欠落 | 空 | exit 3・stdout 空 | exit 3 | 不変 |
| TC-03 | true | 空 | exit 0・下書きに `confirmed_by:` 空欄、既知課題の行を含む | （下記 TC-04） | 不変 |
| TC-04 | true | 空 | — | exit 4 | 不変 |
| TC-04b | true | `TBD` | — | exit 4 | 不変 |
| TC-04c | true | `no` | — | exit 4 | 不変 |
| TC-04d | true | ZWSP（U+200B）のみ | — | exit 4 | 不変 |
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

### TC-09b: `--out` の別名経路

`--out` に (a) seeds を指す symlink、(b) `<dir>/../<seeds>` 形式の別名、(c) seeds と無関係の既存ファイル、(d) 存在しないリンク先を指す symlink を指定。期待: いずれも exit 2、指定先と seeds のバイト列は不変。(d) ではリンク先のファイルが作られていないこと（R-016）。

### TC-10: 生成器が confirmed_by を埋めない

TC-03 の下書きの `confirmed_by:` 行の値が空であること（行末まで空白のみ）。

### TC-11: 追記後の seeds が L2 の検査を通る

TC-06 の前後で `improvement_seed_delta.read_declared_seeds` を python から直接呼び、例外なく返ること、件数が追記前 +1 であること、増えた要素が `TASK-9999` を含むことを assert する。

### TC-14: 下書きに見出しが 2 件

confirm 済みの見出しを 2 件持つ下書き。期待: append exit 2、seeds 不変。

### TC-15: 見出しの task_id 不一致 / confirmed_by 行が 2 行

(a) 見出しの task_id が `TASK-0001`（task-dir は `TASK-9999`）、(b) `- confirmed_by:` 行が 2 行。期待: いずれも append exit 2、seeds 不変。

### TC-16: plan.md に opt-in 行が無い

pbi-input.md は `retro_enabled: true`、plan.md には無い（plan_hash は一致させる）。期待: draft exit 3・stdout 空、append exit 3、seeds 不変。

### TC-17: plan_hash 不一致

c3.json 発行後に plan.md を 1 バイト変える。期待: draft exit 3・stdout 空、append exit 3、seeds 不変。

### TC-18: plan_hash 欠落・形式不正 / plan.md 欠落

(a) c3.json に `plan_hash` キーなし、(b) `plan_hash` が `sha256:` 接頭辞なし、(c) plan.md を削除。期待: いずれも draft exit 3、append exit 3、seeds 不変。

### TC-19: 二重 append（冪等）

TC-06 の後、同じ下書きで append を再実行。期待: exit 5、seeds のバイト列は 1 回目の後と一致。

### TC-19b: 大文字小文字違いの task_id（R-014）

seeds に見出し `## <date> — task-9999` が既にある状態で、`TASK-9999` の confirm 済み下書きを append。期待: exit 5、seeds 不変。

### TC-19c: 空白・日付違いの task_id（R-014）

seeds に (a) 見出し末尾に空白を付けた `## <date> — TASK-9999 `、(b) 日付だけが違う `## <別の date> — TASK-9999` がある状態で append。期待: いずれも exit 5、seeds 不変。fence 内にだけ `## <date> — TASK-9999` がある seeds では重複扱いしない（L2 の見出し照合と同じくマスク後で比較する）。

### TC-20: seeds 側の状態（R-015）

(a) 末尾に改行が無い seeds（L2 は通る）に confirm 済み下書きを append → exit 0、追記後の全文が `read_declared_seeds` を通り件数が +1、既存部分はバイト一致し、その直後に改行が 1 つだけ補われる。
(b) 追記前から `read_declared_seeds` を通らない seeds（既存エントリの confirmed_by が空）→ exit 6、seeds 不変。
(c) python から生成器の append 関数を import し、読み込み後・置き換え前に seeds を 1 バイト変える差し込み（テスト用に置き換え直前の読み直し関数を差し替える）で実行 → exit 7、seeds は差し込み後のバイト列のまま、一時ファイルが残らない。

### TC-21: 承認トークンの文脈流用（R-013）

(a) c3.json の `task_id` が `TASK-0001`（task-dir は `TASK-9999`、他は正常）→ draft exit 3・stdout 空、append exit 3、seeds 不変。
(b) c3.json に `task_id` キーが無い → draft exit 3、append exit 3。
(c) sandbox git repo の `docs/working/improvement-seeds.md`（追跡済み）を `--seeds` にし、task-dir を repo の外に置く → append exit 3、seeds 不変。
(d) (c) の repo の `docs/working/TASK-9999/` に task-dir を置き、c3.json だけ未追跡 → append exit 3、seeds 不変。
(e) (d) で c3.json を `git add` した状態 → append exit 0（陽性対照）。

## Edge Cases

### TC-E01: 値の表記ゆれ

`retro_enabled: "true"` / `retro_enabled: yes` / `retro_enabled: True` は不成立（exit 3）。行頭に半角スペース 3 個・行末に空白を付けた `retro_enabled: true` は成立。行頭がタブの `retro_enabled: true` は不成立（exit 3。R-012）。

### TC-E02: コメント内の記述

`<!-- retro_enabled: true -->` だけがある pbi-input は不成立（exit 3）。

### TC-E02b: fence 内の記述

` ``` ` fence の内側にだけ `retro_enabled: true` がある pbi-input（plan.md も同様）は不成立（exit 3）。

### TC-E02c: 複数行 HTML コメント内の記述

`<!--` の次行に `retro_enabled: true`、その次行に `-->` がある pbi-input（plan.md も同様）は不成立（exit 3）。

### TC-E02d: インデントコード内の記述（R-012）

直前に空行を置き、半角スペース 4 個でインデントした `    retro_enabled: true` だけがある pbi-input（plan.md も同様）は不成立（exit 3）。

### TC-E02e: 閉じていない fence（R-012）

` ``` ` を開いたまま閉じない pbi-input（fence の外に `retro_enabled: true` がある）は不成立（exit 3）。スタックトレースで落ちない（stderr に `Traceback` を含まない）。

### TC-E03: 壊れた c3.json

JSON として読めない c3.json は不成立（exit 3）。例外のスタックトレースで落ちない。

### TC-E04: handoff に §2 が無い

draft は exit 2。stdout は空。

## 変異注入計画（AC-5）

各変異を作業ツリーで 1 つずつ注入し、期待どおりの TC が FAIL することを記録して戻す（commit しない）。

| ID | 変異 | FAIL すべき TC |
|----|------|---------------|
| M-1 | ゲート関数を常に True を返すようにする | TC-01, TC-02, TC-07, TC-08, TC-12, TC-13 |
| M-1 の補足 | 「常に True」は call site（draft / append 両方の呼び出し）で注入する | 同上 + TC-16〜TC-18 |
| M-2 | append の confirmed_by 検査を除去する | TC-04, TC-04b, TC-04c, TC-05（L2 全文検査で止まり exit 6 になるため、exit 4 の完全一致で FAIL。R-010）。TC-04d（ZWSP は L2 も空とみなさず exit 0） |
| M-2b | 書式文字の除去を外し、`is_unconfirmed` の代わりに `value.strip() == ""` だけで判定する | TC-04b, TC-04c, TC-05（exit 6 になり FAIL）, TC-04d（exit 0 になり FAIL）。R-011 |
| M-3 | append を上書き（追記前の内容を捨てて下書きだけを書く）にする | TC-06, TC-11 |
| M-4 | append でゲートを呼ばない（draft のゲートだけ残す） | TC-12, TC-13 |
| M-5 | plan_hash 照合を除去する | TC-17, TC-18 |
| M-6 | 重複 task_id の検査を除去する | TC-19（重複検査が消えると L2 の duplicate 検出で exit 6 になり、exit 5 の完全一致で FAIL）, TC-19b, TC-19c |
| M-6b | task_id の比較から `casefold` / `strip` を外す | TC-19b, TC-19c (a) |
| M-7 | task_id 一致の検査（ゲート 4）と本番 seeds 宛ての所在・追跡検査（ゲート 5）を除去する | TC-21 (a)〜(d) |

また、生成器が無い状態（Task 1 の RED）で TA-118 が FAIL することも記録する。

## 自動化可否

全 TC 自動化可。

## 検証結果（V-1 で記入）

（未実施）
