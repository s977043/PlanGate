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
| AC-5 | 変異注入計画 M-1〜M-12（M-2b / M-6b / M-8b を含む） |
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

TC-06 の後、同じ下書き（**同じ日付・同じ task_id**）で append を再実行。期待: exit 5、seeds のバイト列は 1 回目の後と一致。日付違いの重複は TC-19c (b) で扱う（R-022）。

### TC-19b: 大文字小文字違いの task_id（R-014）

seeds に見出し `## <date> — task-9999` が既にある状態で、`TASK-9999` の confirm 済み下書きを append。期待: exit 5、seeds 不変。

### TC-19c: 空白・日付違いの task_id（R-014）

seeds に (a) 見出し末尾に空白を付けた `## <date> — TASK-9999 `、(b) 日付だけが違う `## <別の date> — TASK-9999` がある状態で append。期待: いずれも exit 5、seeds 不変。fence 内にだけ `## <date> — TASK-9999` がある seeds では重複扱いしない（L2 の見出し照合と同じくマスク後で比較する）。

### TC-20: seeds 側の状態（R-015）

(a) 末尾に改行が無い seeds（L2 は通る）に confirm 済み下書きを append → exit 0、追記後の全文が `read_declared_seeds` を通り件数が +1、既存部分はバイト一致し、その直後に改行が 1 つだけ補われる。
(b) 追記前から `read_declared_seeds` を通らない seeds（既存エントリの confirmed_by が空）→ exit 6、seeds 不変。
(c) python から生成器の append 関数を import し、読み込み後・置き換え前に seeds を 1 バイト変える差し込み（テスト用に置き換え直前の読み直し関数を差し替える）で実行 → exit 7、seeds は差し込み後のバイト列のまま、一時ファイルが残らない。
(d) seeds が実ファイルを指す symlink（R-020）→ exit 0、symlink 自体は symlink のまま残り（`os.path.islink` が真）、リンク先の実ファイルに 1 エントリ追記されている（リンクだけ置き換えて本番不変のまま exit 0 になる誤 PASS を検出する）。
(e) mode 0644 の seeds（R-020）→ exit 0、追記後の実体の mode が 0644 のまま（0600 にならない）。
(f) CRLF 改行の seeds（R-021）→ 既存部分のバイト列が CRLF のまま保たれる。終了コードは L2 の判定に従い 0 または 6 の完全一致（fixture 作成時に L2 を流して期待値を決める）で、8 にはならない。
(g) python から append 関数を import し、追記後の全文を組み立てる関数を先頭 1 バイトを変えるものに差し替えて実行 → exit 8、seeds 不変（R-021）。

### TC-21: 承認トークンの文脈流用（R-013）

(a) c3.json の `task_id` が `TASK-0001`（task-dir は `TASK-9999`、他は正常）→ draft exit 3・stdout 空、append exit 3、seeds 不変。
(b) c3.json に `task_id` キーが無い → draft exit 3、append exit 3。
前提（R-024）: 本番宛ての判定は `realpath(__file__)` の 2 階層上を root とするため、(c)〜(h)・(j) の sandbox git repo には生成器と `improvement_seed_delta.py` を `scripts/` 配下にコピーし、そのコピーを実行する。
(c) sandbox git repo の `docs/working/improvement-seeds.md`（追跡済み）を `--seeds` にし、task-dir を repo の外に置く → append exit 3、seeds 不変。
(d) (c) の repo の `docs/working/TASK-9999/` に task-dir を置き、c3.json だけ未追跡 → append exit 3、seeds 不変。
(e) (d) で pbi-input.md / plan.md / c3.json を `git add` して commit した状態 → append exit 0（陽性対照）。
(f) (e) の後、追跡済み c3.json を作業ツリー上だけで `c3_status: "CONDITIONAL"` に書き換える → append exit 3、seeds 不変（作業ツリーと `HEAD` の blob が食い違う。pbi-input.md / plan.md を作業ツリーだけで 1 バイト変えた場合も同じく exit 3）。
(f2) `HEAD` の c3.json を CONDITIONAL で commit し、作業ツリーだけ APPROVED に書き換える → append exit 3、seeds 不変（blob の不一致とゲート 2 の不成立の両方。R-018）。作業ツリーを `HEAD` と一致させた（CONDITIONAL のまま）状態でも exit 3（ゲート 2 は `HEAD` の blob で判定）。
(g) (d) で c3.json を `git add` しただけ（staged のみ・未 commit）→ append exit 3、seeds 不変（R-018。R1 の (e) はこの状態を陽性対照にしていたため、是正後の挙動に合わせて (e) を commit 済みに改めた）。
(h) **macOS のみ**（大文字小文字を区別しない FS で実行。区別する FS では SKIP と明記して出力する）: `--seeds` に `<repo>/Docs/Working/Improvement-Seeds.md`、task-dir を repo の外に置く → append exit 3、seeds 不変（R-019。パス文字列の比較なら本番宛てでないと判定してゲート 5 を飛ばす）。
(i) 一時コピー経路の陽性対照: (c) の seeds を repo 外の一時ディレクトリにコピーして `--seeds` に渡し、task-dir は repo 外の sandbox（作業ツリーの c3.json）→ append exit 0、本番 seeds は不変。本番宛てでないことは root との `samefile` で決まり、git の成否には依存しない（R-024。plan-draft ゲート 5 と一致）。
(j) env による判定の反転（R-024）: (d) の状態（c3.json だけ未追跡）で、`GIT_CEILING_DIRECTORIES=<repo の親>` を付けて append → exit 3、seeds 不変。同じく `GIT_DIR=<存在しないパス>`、`GIT_DIR=<別の sandbox repo の .git>` を付けた場合も exit 3。陽性対照として (e) の状態に `GIT_DIR=<存在しないパス>` を付けて append → exit 0（git は `GIT_*` を除いた env で呼ばれる）。
(k) 本番宛てと判定した後の git 失敗（R-024）: (e) の状態で sandbox repo の `.git` を一時的に読めなくする（`HEAD` を壊す）→ append exit 3、seeds 不変（「本番以外」に倒して exit 0 にならない）。

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
| M-7 | task_id 一致の検査（ゲート 4）と本番 seeds 宛ての所在・commit 済み検査（ゲート 5）を除去する | TC-21 (a)〜(d), (f), (f2), (g), (h) |
| M-8 | ゲート 5 の commit 済み判定を `git ls-files --error-unmatch` に戻し、ゲート 1〜4 を作業ツリーで判定する（原則 P の除去） | TC-21 (f2)（exit 0 になり FAIL）, (g)（exit 0 になり FAIL）。R-018 |
| M-8b | ゲート 5 の作業ツリーと `HEAD` の blob の一致検査を除去する | TC-21 (f)（exit 0 になり FAIL） |
| M-9 | 本番 seeds 宛て・task-dir 位置の判定を `samefile` からパス文字列（`realpath` 後の `==`）に戻す（原則 I の除去） | TC-21 (h)（macOS。exit 0 になり FAIL）。R-019 |
| M-10 | 書き込みを `realpath` でなく `--seeds` のパスへの `os.replace` にし、mode を引き継がない | TC-20 (d)（symlink が通常ファイルに置き換わり FAIL）, (e)（mode 0600 で FAIL）。R-020 |
| M-11 | 前方一致の不一致で exit 8 ではなく exit 6 を返す / `read_bytes` をテキストモードの読み込みに戻す | TC-20 (g)（exit 6 で FAIL）, (f)（CRLF が失われ FAIL）。R-021 |
| M-12 | 本番宛ての判定を `git rev-parse --show-toplevel`（呼び出し元の env のまま）に戻し、git 失敗時は本番以外として扱う | TC-21 (j)（exit 0 になり FAIL）, (k)（exit 0 になり FAIL）。R-024 |

また、生成器が無い状態（Task 1 の RED）で TA-118 が FAIL することも記録する。

## 自動化可否

全 TC 自動化可。

## 検証結果（V-1 で記入）

（未実施）
