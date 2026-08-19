# テストケース定義 — TASK-1165 (#1165 / PBI-B)

> **原本には書き込まない**。すべての変異は `mktemp -d` 上に複製した sandbox（以下 `$SBX`）で行い、
> 実行後に明示削除する（pbi-input A-04）。`scripts/ai-loop/` / `tests/extras/` /
> `plugin/` の原本は不変。
>
> **変異は関数ではなく呼び出し箇所（call site）を壊す**。関数本体を壊す変異は「その関数が
> 呼ばれているか」しか測れず、契約が実際に評価されているかを実証できないため。
>
> **TC ID は `PBIB-NN`**（被検査スイート `ta-57` の `TC-NN` と**番号衝突しない**体系。
> とくに `TC-14` は本 PBI の主題語であり、同名の独自 TC 番号を作らない）。

## 前提 P-0: 先行依存（順序制約）

本 PBI の全 TC は **#1162 が main にマージ済み**であることを前提とする。
`git log origin/main` と
`git show origin/main:tests/extras/ta-57-pr-convergence.sh | sed -n '620,625p'` で実測確認し、
未マージなら**着手しない**（todo T-01 の前提検査 / 即停止条件）。

> これは**技術的な必須依存ではない**。3 巡目の是正（C-01）で B-3 が凍結対象外 7 箇所へ
> 限定され、`test_delivery.py` へテストを追加しなくなったため `ta-57` TC-15 の
> `-eq 57` / `-ge 57` は本 PBI の成否に影響しない。**両 PBI がともに
> `tests/extras/ta-57-pr-convergence.sh` を改変する**ことによる衝突回避の順序制約である。

## 前提 P-1: 判定規則（**全 Integration TC に適用 / 正本**）

**判定パターンはスイートごとに実物から導出する**。`ta-33` 由来のパターンは `ta-57` では
**永久に一致しない**。実測（本セッション）:

```text
tests/extras/ta-33-agent-model-tier.sh:29   printf '[FAIL] TA-33 TC-01: ...'      ← 行頭・TA-33 あり・stdout
tests/extras/ta-57-pr-convergence.sh:39     printf '  [FAIL] %s\n' "$1" >&2       ← 先頭 2 空白・TA-57 なし・stderr
tests/extras/ta-57-pr-convergence.sh:38     printf '  [PASS] %s\n' "$1"           ← 先頭 2 空白・stdout
```

```sh
printf '  [FAIL] TC-14 / AC-7: x\n' | grep -q  '^\[FAIL\] TA-57 TC-14'   # → rc=1（永久に不一致）
printf '  [FAIL] TC-14 / AC-7: x\n' | grep -qE '^ *\[FAIL\] TC-14'       # → rc=0
```

### `ta-57` のパターン（実物由来）

| 種別 | パターン | 出力先 |
|------|---------|--------|
| FAIL | `^ *\[FAIL\] TC-14` | **stderr** |
| PASS | `^ *\[PASS\] TC-14` | stdout |
| WARN（現行の未検証経路） | `^ *\[WARN\] TC-14` | **stderr** |
| UNVERIFIED（B-2 で追加） | `^ *\[UNVERIFIED\] TC-14` | **stdout** |

### 受理条件（5 つすべてを満たしたときのみ「その TC は PASS した」と記録する）

1. **ログ取得は `> "$log" 2>&1` 必須**（`ta-57` の FAIL / WARN は stderr に出る）
2. 対象 TC の **FAIL パターンが 0 件**
3. **対象 TC の PASS パターンが 1 件以上存在する** — 「FAIL 行が無い」は
   「そこまで到達したか不明」と区別できない
4. **`^ *\[WARN\] TC-14` が 0 件**（TC-14 に限る）— `[WARN]` 経路では `t57_pass` も
   `t57_fail` も呼ばれないため、**FAIL 行も PASS 行も出ないまま「緑」に見える**（恒真 PASS）
5. **対象件数が 0 でない** — 「検査が走ったが対象が空」を PASS と区別する。
   本 PBI で件数が問題になるのは次の 2 つ:

   | 対象 | 件数の取り出し方 | 0 のときに起きること |
   |------|----------------|--------------------|
   | plugin コピーのテスト実行（AC-06 / PBIB-10） | **実行されたモジュール総数** | 1 本も起動しなくても baseline も変更後も空集合となり「FAIL 集合が増えていない」で PASS |
   | `read_json()` への置換（AC-04 / PBIB-07） | **置換した箇所数** | 置換 0 でも対比表が空のまま「挙動同一」が形式的に成立 |

> **rc は判定に使わない**。`ta-57` は `pass` / `fail` を harness 側の変数で加算するだけで
> 自前の exit code を持たない（`grep -c 'PG_HARNESS_SOURCED' tests/extras/ta-57-*.sh` = 0。
> standalone フォールバックは 65 本中 25 本にあるが `ta-57` は含まれない）。

### 起動 harness（sandbox 内に作る。`tests/` 原本には追加しない）

1. `pass=0` / `fail=0` を初期化する
2. **`FIXTURES_DIR="$SBX/tests/fixtures"` を定義**する
   （`ta-57:36` は `PG_T57_ROOT="$(cd -- "$FIXTURES_DIR/../.." && pwd)"`。**`$0` 由来ではない**）
3. **`register_cleanup()` を定義**する（**実呼び出しは `ta-57:45` のみ**。`:32` と `:667` は
   コメント行であり呼び出しではない。未定義だと `:45` で `command not found` となり以降が壊れる）
4. 対象スイートを **`.`（source）**で読み込む
5. **`pass` / `fail` の最終値を 1 行で出力**する
   （例: `printf 'HARNESS_SUMMARY pass=%s fail=%s\n' "$pass" "$fail"`）。
   `ta-57` は集計値を自分では出力しないため、**この出力が「集計値が不変」という
   受理条件（PBIB-03 / PBIB-04）の唯一の観測手段**である
6. 末尾で `[ "$fail" -eq 0 ] || exit 1`（**判定には使わない**）

## 前提 P-2: base ref の fixture（**TC-14 系の全 TC に適用**）

`ta-57:589-599` は `origin/main` → `main` の順に base ref を探し、**HEAD と同一 SHA の ref は
採用しない**（`continue`）。`:600` の `if [ -z "$_t57_base" ]` が真なら `:601-604` の
`[WARN]` 4 行へ落ちる。したがって sandbox の git 状態によって TC-14 の経路が変わる:

| fixture | sandbox の git 状態 | TC-14 の経路 |
|---------|-------------------|-------------|
| **F-1**（既定 / 検証可能） | `main` が **HEAD と異なる commit** を指す | 差分検査が**実行される** |
| **F-2** | `main` が **HEAD と同一 SHA** | `[WARN]` 経路（push-to-main の CI 相当） |
| **F-3** | `origin/main` も `main` も**存在しない** | `[WARN]` 経路（PR 時 CI の `fetch-depth: 1` 相当） |

- **F-1 / F-2 / F-3 は変異ではなく fixture**（環境の再現）であり、変異一覧には載せない
- **正側 TC（PBIB-01）は必ず F-1 で測る**。F-2 / F-3 では TC-14 が実行されず恒真 PASS になる

## 前提 P-3: 時間予算と TIMEOUT の判定式

| 対象 | 予算 | 超過時 |
|------|-----:|--------|
| 個別スイート（`ta-57`） | 300 秒 | `TIMEOUT` として記録し原因を調査 |
| plugin skill コピー単体のテスト実行 | 600 秒 | 同上 |
| フルスイート（`sh tests/run-tests.sh`） | **1,800 秒** | `TIMEOUT`＝**未検証**として記録。**「PASS」と書かない** |

**変更後・baseline のどちらが TIMEOUT（rc=124）でも AC-07 は WARN（未検証）**とし、
個別スイートで代替判定して未検証範囲を `handoff.md` に明示する。

---

## 受入基準 → テストケース マッピング

| AC | 内容 | 正側 TC | 負側 TC |
|----|------|---------|---------|
| AC-01 | TC-14 が `c3_contract.py` への後方互換な関数追加で PASS | **PBIB-01** | — |
| AC-02 | TC-14 が 4 種の変更で FAIL | — | **PBIB-02**（M-1〜M-5 / M-9 / M-10） |
| AC-03 | base ref 不在 / == HEAD で「未検証」が stdout に現れる | PBIB-05 | **PBIB-03**, **PBIB-04** |
| AC-04 | JSON 読込（**凍結対象外 7 箇所**）が `read_json()` へ集約され挙動不変 | PBIB-06, PBIB-07 | **PBIB-08**（M-7） |
| AC-05 | 層契約検査が `read_json` についても発火 | PBIB-09 | **PBIB-09**（M-6） |
| AC-06 | plugin 側の FAIL モジュール集合が baseline から増えない | **PBIB-10** | **PBIB-11**（M-8） |
| AC-07 | `sh tests/run-tests.sh` が baseline 以上で exit 0 | PBIB-12 | **PBIB-13** |

---

## B-1: TC-14 凍結の射程限定

### PBIB-01: 後方互換な関数追加では PASS（正側 / AC-01）

| # | 手順 |
|---|------|
| 1 | `$SBX` へ repo を複製し、**fixture F-1**（`main` を HEAD と異なる commit にする）を適用 |
| 2 | P-1 の harness を用意する |
| 3 | `$SBX/scripts/ai-loop/c3_contract.py` に `read_json(path)` を追加（既存関数・定数は不変・**削除行 0**） |
| 4 | harness 経由で `ta-57` を実行し `> log 2>&1` |
| 5 | 同様に `c3_contract.py` へ docstring / 型注釈のみ追加して再実行 |

**受理条件（すべて）**:

1. `^ *\[FAIL\] TC-14` が **0 件**
2. **`^ *\[PASS\] TC-14` が 1 件以上**
3. **`^ *\[WARN\] TC-14` が 0 件**

- 🚩 **受理条件 2・3 が本 TC の核心**。`[WARN]` 経路では `t57_pass` も `t57_fail` も呼ばれず
  「FAIL 行が無い」状態になるため、**PASS 行の存在と WARN 行の不在**を確認しないと
  恒真 PASS になる（R-08）
- ⚠️ 対照: 置換**前**（現行の「ファイル単位 0 行差分」）では **FAIL する**ことを先に記録する
  （＝これが B-3 を構造的にブロックしている実証。todo T-04 の RED）
- 種別: Integration / 自動化: 可

### PBIB-02: 判定規則の改変では FAIL（負側 / AC-02）

| # | 変異 | 期待 |
|---|------|------|
| 1 | `delivery.py` の `TRANSITIONS` に遷移を 1 本追加 | `^ *\[FAIL\] TC-14` が 1 件以上 |
| 2 | `delivery.py` の `STATES` に状態を 1 つ追加 | 同上 |
| 3 | `delivery.py` の `PRIORITY_ORDER` の順序を入れ替え | 同上 |
| 4 | **`delivery.py` の `assess()` に後方互換な `if` 分岐を 1 本追加**（定数は不変） | 同上 |
| 5 | `c3_contract.py` の**既存行を削除** | 同上（`--numstat` の削除カラムが > 0） |
| 6 | `c3_contract.py` の**既存行を改変**（1 行書き換え） | 同上（書き換えは削除 1 行を伴う） |
| 7 | `c3prime_verify.py` の検証条件を 1 つ緩める（exit code 契約の緩和） | 同上 |

- すべて **fixture F-1** の上で実施する
- 🚩 **4 が最重要**。TASK-0917 R-006（`review-external.md:39`）は「定数単位の差分ゼロでは
  本体に後方互換な分岐を足しても鳴らない」と指摘し、そのためにファイル単位へ強化された。
  **射程を限定した新しい不変条件が 4 を kill できなければ、その案は R-006 の退行**であり
  採用してはならない（todo T-06 の即停止条件）
- 🚩 AC-02 は 4 分類（delivery 定数 / `assess()` 分岐 / c3_contract 既存行 / c3prime_verify）に
  ついて**各 1 件以上**の実証を要求している。上表 1〜7 はその 4 分類を網羅する
  （1〜3 は「delivery 定数」の 3 定数それぞれに対応 = M-1 / M-9 / M-10）
- 種別: Mutation / 自動化: 可

#### 意図した緩和（**検出できないことを正直に記録する**）

| ケース | 現行 | 置換後 | 扱い |
|--------|------|--------|------|
| `c3_contract.py` に**関数を追加** | FAIL | **PASS** | ✅ 緩和の目的（B-3 を通すため） |
| `c3_contract.py` の**既存行を削除・改変** | FAIL | **FAIL** | ✅ 維持 |
| **`c3_contract.py` の既存関数の内部に行を追加**（削除を伴わない） | FAIL | **PASS** | ⚠️ **意図した緩和の副作用として検出できなくなる** |

- 最後の行は `handoff.md` に**残存リスクとして明記**する。「凍結が維持されている」と書かない
- 補償: `c3_contract.py` は契約定数と I/O なし純関数の層であり、振る舞い変更は
  `test_c3_contract.py` の既存テスト群と AC-05 の層契約検査が捕捉する

---

## B-2: `[WARN]` スキップの可視化

### PBIB-03: base ref 不在の環境で「未検証」が stdout に現れる（AC-03）

| # | 手順 |
|---|------|
| 1 | **fixture F-3**（`origin/main` も `main` も存在しない sandbox）を用意 |
| 2 | harness 経由で `ta-57` を実行し stdout / stderr を**分けて**取得 |

**受理条件（すべて）**:

1. **stdout に `^ *\[UNVERIFIED\] TC-14` が 1 件**
2. stderr の既存 `[WARN]` 4 行（`:601-604`）は**維持**されている
3. **harness の `HARNESS_SUMMARY` 行が示す `pass` / `fail` の値**が、変更前後で同一
   （P-1 harness 要件 5。`ta-57` 自身は集計値を出力しないため、この行が唯一の観測手段）

- ⚠️ 本 TC は **stdout / stderr を分けて**取得する（`[UNVERIFIED]` が stdout に出ることが
  AC-03 の要求そのもののため）。他の TC の `2>&1` とは扱いが異なる。
  `HARNESS_SUMMARY` は stdout に出す
- 種別: Integration / 自動化: 可

### PBIB-04: base ref == HEAD の環境で「未検証」が stdout に現れる（AC-03）

| # | 手順 |
|---|------|
| 1 | **fixture F-2**（`main` を HEAD と同一 SHA にする。push-to-main の CI 相当） |
| 2 | harness 経由で `ta-57` を実行し stdout / stderr を分けて取得 |

- 受理条件は PBIB-03 と同じ 3 点（集計値の観測も `HARNESS_SUMMARY` 行で行う）
- 種別: Integration / 自動化: 可

### PBIB-05: 通常環境では `[UNVERIFIED]` が出ない（正側 / AC-03）

| # | 手順 |
|---|------|
| 1 | **fixture F-1**（`main` が HEAD と異なる） |
| 2 | harness 経由で `ta-57` を実行し `> log 2>&1` |

**受理条件（すべて）**:

1. `^ *\[UNVERIFIED\] TC-14` が **0 件**
2. `^ *\[PASS\] TC-14` または `^ *\[FAIL\] TC-14` が **1 件以上**（実行された証拠）

- 意図: `[UNVERIFIED]` が**常時出る**実装（＝区別になっていない）を排除する
- 種別: Integration / 自動化: 可

---

## B-3: JSON 読込の単一定義化（凍結対象外 7 箇所）

### PBIB-06: `read_json()` 単体（AC-04）

| 入力 | 期待 |
|------|------|
| 妥当な JSON ファイル | dict / list を返す |
| 不正 JSON（`{`） | T-02 で確定した例外型（`ValueError` 系）を送出 |
| 不存在パス | `OSError`（または `ValueError` へ包む — T-02 の決定に従う） |
| 読み取り権限なし | 同上 |
| 非 UTF-8 バイト列 | `UnicodeDecodeError`（`ValueError` サブクラス）が fail-closed で扱われる |
| 空ファイル | 不正 JSON と同じ扱い |
| ディレクトリを指すパス | `IsADirectoryError`（`OSError` サブクラス）で fail-closed |

- 種別: Unit（`test_c3_contract.py`）/ 自動化: 可
- 🚩 例外の**型とメッセージ**まで assert する（メッセージが変わると呼び出し側のエラー表示が
  変わり、実質的な振る舞い変更になるため）

### PBIB-07: 呼び出し 7 箇所の挙動不変（AC-04）

集約した**各呼び出し箇所**について、**リファクタ前後で同一入力に対する
(例外型, メッセージ, プロセス rc) の 3 つ組が一致**することを対比表で確認する。

| # | 箇所 | 特記事項 |
|---|------|----------|
| 1 | `run_evidence.py:243` | — |
| 2 | `run_evidence.py:357` | ループ内。1 件失敗時に継続するか停止するかを確認 |
| 3 | `run_evidence.py:411` | 同上 |
| 4 | `run_evidence_verify.py:93` | **schema 読込**。失敗＝受理器が起動不能（fail-closed 必須）。schema 自体は HO 対象のため**編集しない** |
| 5 | `run_evidence_verify.py:285` | `c3.json` 読込 |
| 6 | `run_evidence_verify.py:418` | evidence 読込 |
| 7 | `discovery.py:182+186` | **2 行形式**。`path.is_file()` 事前検査 ＋ `OSError` と `JSONDecodeError` を**別メッセージ**で `ValueError` に包み直す ＋ `isinstance(data, list)` 事後検査。さらに **plugin 非配布 ＋ `sys.path` bootstrap なし**（U-05）。差異が吸収できない、または import 経路の新設が必要なら**据え置く** |

**受理条件（すべて）**:

1. 対比表の**行数（＝実際に置換した箇所数）が 0 でない**（P-1 受理条件 5。
   置換 0 でも「前後の挙動が同一」は空虚に成立するため）
2. 各行で (例外型, メッセージ, rc) の 3 つ組が**前後一致**
3. 据え置いた箇所は**据え置きとして表に残す**（行を消さない。「集約済み」に見せない）

#### 凍結維持のため据え置き（**B-3 のスコープ限定 / D-4**）

| 箇所 | 理由 | 検査 |
|------|------|------|
| `delivery.py:538` / `:540` | **B-1 でファイル単位 0 行差分の凍結を維持すると決めたファイル**。置換は既存行の削除を伴うため、集約した時点で `ta-57` TC-14 が必ず FAIL する（3 巡目 C-01 の是正） | **差分が 0 行であること**を `git diff --stat "$base" -- scripts/ai-loop/delivery.py` で確認 |
| `c3prime_verify.py:56` | 同上 | 同上（`-- scripts/ai-loop/c3prime_verify.py`） |

- 🚩 この 3 箇所は **`handoff.md` に「凍結解除時の後続候補」として記録**する（todo T-14）。
  **「10/10 集約」と書かない**

#### 採用基準外（「見落とし」でないことを記録する）

| 箇所 | 除外理由 | 検査 |
|------|----------|------|
| `arbiter.py:1160-1169` | (1) `open()` + `f.read()`、`--input-path` 未指定時は `sys.stdin.read()` の **CLI/stdin 兼用**。(2) **層契約（#896 AC-6）により arbiter は I/O 層を import / call しない**。`read_json` を呼ぶことは AC-05 の検査自体に違反する | **据え置きであること**（差分が入っていないこと）を `git diff` で確認 |
| `delivery.py:461` | `json.loads(line)` — NDJSON の 1 行。ファイル読込ではない | 同上 |
| `run_evidence.py:639` / `:658` / `:676` | `opts.get(...)` の **CLI 引数文字列**のパース | 同上 |
| `executor.py:448` / `gh_exec.py:670` | `proc.stdout` / `view.stdout` の **subprocess 出力** | 同上 |

- 入力セット（各箇所共通）: 妥当 JSON / 不正 JSON / 不存在 / 権限なし / 非 UTF-8 / 空
- 種別: Unit + Integration / 自動化: 可
- 🚩 「寄せられなかった箇所」は件数と理由を `handoff.md` に明記（隠して「全件集約」と
  書かない）

### PBIB-08: `read_json()` 呼び出し箇所の変異が kill される（負側 / AC-04）

- **call site を壊す**変異のみ（関数本体は壊さない）:

| 変異 | 期待 |
|------|------|
| 呼び出しを `try/except: pass` で囲み例外を握り潰す | 既存テストが **FAIL** |
| 引数のパスを別の実在ファイルへ差し替える | **FAIL** |
| 呼び出しを除去して固定 dict `{}` を返す | **FAIL** |
| `discovery.py` の包み直しメッセージ文字列を変更（据え置かなかった場合のみ） | **FAIL**（メッセージを assert していれば） |

- 🚩 kill されない変異があれば「その挙動は未検証」と正直に記録し、TC 追加か据え置きを判断する
- ⚠️ 変異対象は**集約した 7 箇所のみ**。据え置いた `delivery.py` / `c3prime_verify.py` には
  変異を入れない（原本の凍結対象であり、本 PBI では触らない）
- 種別: Mutation / 自動化: 可

### PBIB-09: 層契約検査が `read_json` についても発火する（AC-05）

| # | 手順 | 期待 |
|---|------|------|
| 1 | `test_c3_contract.py:201 test_arbiter_does_not_touch_io_layer` の assert 対象に `read_json` を追加する | — |
| 2 | **変異 M-6**: `arbiter.py` に `from c3_contract import read_json` と 1 回の呼び出しを追加 | `test_c3_contract.py` が **FAIL**（`AssertionError`） |
| 3 | 変異を復元 | **PASS** に戻る |
| 4 | 変異 M-6 を**追加前の実装**（`sha256_of_file` のみ assert）に対して適用 | **PASS のまま**（＝現行の検査が新関数に効いていないことの実証） |

- 🚩 **手順 4 が本 TC の核心**。assert を追加しただけで「効いている」と書かない。
  **追加前は素通りし、追加後は kill される**ことの対比で実証する
- 実測（本セッション）: 現行は AST の `node.attr` / `node.id` を **`"sha256_of_file"` とだけ**
  比較しており、`read_json` には効かない
- 種別: Unit + Mutation / 自動化: 可

---

## B-3 の配布検証（plugin）

### PBIB-10: skill ディレクトリ全体コピーでのテスト実行（AC-06）

| # | 手順 | 期待 |
|---|------|------|
| 1 | `sh scripts/sync-plugin-plangate.sh --dry-run` → 同期 → 再度 `--dry-run` | **差分 0** |
| 2 | plugin 側 `*.py` の basename 集合 vs `sync-plugin-plangate.sh:428` の `for` 集合 | **一致**（検査自体は既存 `ta-57` TC-E8（`:641-665`）が行うため**再実装しない**） |
| 3 | `plugin/plangate/skills/ai-loop-cycle/` を **skill ディレクトリ全体で** `$SBX` へコピーし、その中で `python3 scripts/test_*.py` を全実行 | **FAIL モジュール集合が T-01 baseline から増えない** |

**受理条件（すべて）**:

1. **実行されたモジュール総数を baseline と変更後の両方で記録**し、
   **baseline の総数が 0 でない**こと（0 なら測り方の誤り＝即停止 / P-1 受理条件 5）
2. 変更後の**実行モジュール総数が baseline と同数以上**であること
   — これがないと「1 本も起動していないので FAIL 集合も空」で PASS する（恒真 PASS）
3. 変更後の **FAIL モジュール集合が baseline の集合から増えていない**こと

- ⚠️ **コピー対象は skill ディレクトリ全体**（`agents/` `references/` `schemas/` `scripts/`
  `SKILL.md`）。`scripts/` のみのコピーでは `test_arbiter.py` が
  `../references/ho-paths.md` を解決できず**追加で FAIL する**（`test_arbiter.py:159,898,903`
  が参照。本セッションで一次照合）
- ⚠️ **baseline と変更後を同一手順で測る**。コピー範囲が違うと FAIL 本数が変わり比較にならない（R-06）
- ⚠️ **「全 PASS」は達成不能**。baseline には repo コンテキスト依存の FAIL が含まれる。
  AC-06 の運用解釈は「**B-3 前後で FAIL モジュール集合が増えないこと**」
- ⚠️ **FAIL モジュールの名指しリストを契約にしない**。**T-01 の実測結果を正**とする
  （名指しは測定時点の値で、無関係な変更で stale になる）
- ⚠️ **配布ファイル件数を契約にしない**（`ls <dir> | wc -l` は `__pycache__` を含む）。
  配布集合の判定は `--dry-run` 差分 0 と `:428` の for 集合一致で行う。
  上記受理条件 1・2 の「実行モジュール総数」は**恒真 PASS 排除のための下限比較**であり、
  絶対件数の契約ではない
- ⚠️ 「`scripts/ai-loop/` で通る」ことは AC-06 の証拠にならない。**plugin 側コピーだけを
  切り出した状態**（repo root なし）で実行し、import / 参照解決の閉じ具合を実測する
- 種別: Integration / 自動化: 可

### PBIB-11: allowlist 欠落の検知（負側 / AC-06）

| 変異 | 期待 |
|------|------|
| **M-8**: `sync-plugin-plangate.sh:428` の `for` 列挙から `c3_contract.py` を 1 本落として同期 → skill 全体コピーでテスト実行 | **FAIL モジュール集合が baseline から増える** ＋ `ta-57` TC-E8 が `^ *\[FAIL\] TC-E8` |
| `$SBX` で新規 `scripts/ai-loop/foo.py` を作り `c3_contract.py` から import させ、**allowlist に足さずに**同期 → skill 全体コピーでテスト実行 | **FAIL**（import エラー） |

- 意図: 「新規ファイルを作らない」という B-3 の設計制約が**実在する制約であること**の実証。
  この TC が FAIL しない（＝新規ファイルを作っても問題ない）なら B-3 の前提を見直す
- 種別: Integration + Mutation / 自動化: 可

---

## 全体回帰

### PBIB-12: フルスイート回帰（正側 / AC-07）

| 検査 | 期待 |
|------|------|
| `timeout 1800 sh tests/run-tests.sh` | exit **0** |
| pass 件数 | T-01 baseline の pass 件数 **以上** |

- ⚠️ 件数は**下限比較**。絶対件数を新たな契約にしない
- ⚠️ 並走がない時点で 1 回だけ実行。baseline は**測定日時・ホスト・HEAD SHA とセット**で記録する
- 種別: Integration / 自動化: 可（ただし手動タイミング制御）

### PBIB-13: TIMEOUT の扱い（負側 / AC-07）

| 検査 | 期待 |
|------|------|
| **変更後**の run の rc が **124** | AC-07 を PASS と記録しない。`TIMEOUT`＝**未検証（WARN）** |
| **baseline 側**の run の rc が **124** | AC-07 を **WARN（未検証）**とする。「変更後だけ完走したから PASS」と書かない |
| `handoff.md` の AC-07 欄 | `WARN`（未検証）＋ 代替判定に使った個別スイート名 ＋ **未検証範囲**が明記されている |
| 「AC-07 PASS」の文字列 | rc=124 の run に対して**存在しない** |

- ⚠️ **本 TC は「両方の run が完走した場合は N/A」**（発火しない）。完走した run に対して
  本 TC を「PASS」と記録してはならない（空虚に真になるため）。`handoff.md` には
  `N/A（両 run とも完走）` と書く
- 種別: 手動レビュー + doc 検査 / 自動化: 文字列検査のみ機械化可

---

## 変異一覧（kill 実証）

> **判定は 2 層である**:
>
> 1. `$SBX` に変異を適用 → **被検査対象（`ta-57` スイート / `test_c3_contract.py` /
>    plugin コピー）の該当検査が FAIL する**
> 2. **その結果として、本 PBI の対応 TC（`PBIB-NN`）が PASS になる**
>    ＝「壊したら鳴る」ことを実証できた
> 3. 変異を復元 → 被検査対象が **PASS に戻る**ことも確認する
>    （変異と無関係に常時 FAIL していた、という誤検出を排除するため）

| ID | 変異（call site） | 被検査対象で FAIL するもの | 実証される本 PBI の TC | 対応 AC |
|----|-------------------|--------------------------|----------------------|---------|
| M-1 | `delivery.py` の `TRANSITIONS` に遷移を 1 本追加 | `ta-57` TC-14 | PBIB-02 | AC-02 |
| M-2 | **`delivery.py` の `assess()` に後方互換な `if` 分岐を 1 本追加**（定数は不変） | `ta-57` TC-14 | PBIB-02 | **AC-02**（R-006 退行の検出 / **最重要**） |
| M-3 | `c3_contract.py` の**既存行を削除** | `ta-57` TC-14 | PBIB-02 | AC-02 |
| M-4 | `c3_contract.py` の**既存行を改変**（削除 1 行を伴う） | `ta-57` TC-14 | PBIB-02 | AC-02 |
| M-5 | `c3prime_verify.py` の検証条件を 1 つ緩める | `ta-57` TC-14 | PBIB-02 | AC-02 |
| M-6 | `arbiter.py` に `read_json` の import と呼び出しを追加 | `test_c3_contract.py` の `test_arbiter_does_not_touch_io_layer` | PBIB-09 | **AC-05** |
| M-7 | `read_json()` の**呼び出しを** `try/except: pass` で囲む | 各モジュールの既存テスト | PBIB-08 | AC-04 |
| M-8 | `sync-plugin-plangate.sh:428` の `for` 列挙から `c3_contract.py` を 1 本落として同期 | plugin コピー単体テスト（FAIL 集合が増える）＋ `ta-57` TC-E8 | PBIB-11 | AC-06 |
| M-9 | `delivery.py` の `STATES` に状態を 1 つ追加 | `ta-57` TC-14 | PBIB-02 | AC-02 |
| M-10 | `delivery.py` の `PRIORITY_ORDER` の順序を入れ替え | `ta-57` TC-14 | PBIB-02 | AC-02 |

> **fixture（変異ではない）**: **F-1 / F-2 / F-3**（sandbox の base ref 状態の作り分け /
> 前提 P-2）は**環境の再現**であり変異ではない。変異表には載せず、各 TC の前提条件に記載する。
> とくに「`main` を HEAD と同一 SHA にする」は AC-03 の**環境 fixture**であって
> 「壊して鳴るか」を測る変異ではない。

### 空振り時の扱い

変異を入れても**被検査対象が FAIL しなかった**場合、「検出できた」と書かない。
「変異 M-x は kill されなかった」を `handoff.md` の既知課題および `decision-log.jsonl` へ
記録し、TC を足すか「その挙動は未検証」と明記するかを人間判断に上げる（R-13）。

**M-2 が kill されない場合は例外扱い**: B-1 の採用案が TASK-0917 R-006 の退行であることを
意味するため、その案を採らず**即停止して人間判断**を仰ぐ（todo T-06 の即停止条件）。

## エッジケース

| ID | ケース | 扱い |
|----|--------|------|
| E-01 | `git diff --numstat` が **`-` を返す**（binary / rename 検出時） | 数値でない場合は **fail-closed で FAIL** とする。T-04（U-03）で出現条件を実測してから実装する |
| E-02 | `c3_contract.py` が **rename** された | `--numstat` の path が変わる。rename は「既存行の削除」相当として **FAIL** させる（追加のみ許可の射程外） |
| E-03 | base ref が `origin/main` と `main` の**両方存在し SHA が異なる** | `ta-57:589-599` は `origin/main` を優先。fixture F-1 では両者を一致させて曖昧さを排除する |
| E-04 | sandbox に `.git` が無い | `git rev-parse HEAD` が失敗し `_t57_head` が空 → base ref 判定が想定外の経路に入る。fixture 作成時に `git init` + 1 commit を必須にする |
| E-05 | ログを `2>&1` なしで取得した | `ta-57` の FAIL / WARN（stderr）を取りこぼし**恒真 PASS**になる。P-1 受理条件 1 で担保。ただし **PBIB-03 / 04 / 05 は stdout / stderr を分けて**取得する |
| E-06 | harness が `register_cleanup` を定義していない | `ta-57:45`（**唯一の実呼び出し**。`:32` / `:667` はコメント）で `command not found` となり以降の TC が壊れる。harness 要件 3 で担保 |
| E-07 | `read_json()` が **BOM 付き UTF-8** を受け取る | 現行 `encoding="utf-8"` の挙動を**変えない**（BOM で失敗するなら失敗のまま）。挙動不変が最優先 |
| E-08 | JSON ファイルが**シンボリックリンク** / ディレクトリ | `read_json()` は `OSError`（`IsADirectoryError` 含む）で fail-closed |
| E-09 | plugin 側に**余分な** `.py` が残る | `sync-plugin-plangate.sh` の `case` 既定枝で削除される。PBIB-11 で確認 |
| E-10 | `discovery.py` を据え置いた | AC-04 は「7 箇所すべて」ではなく「**集約された箇所で挙動同一**」を要求する。**据え置き箇所と理由を `handoff.md` に明記**し「全件集約」と書かない |
| E-11 | `[UNVERIFIED]` 行が `tests/run-tests.sh` のサマリに影響する | 2 値サマリ（`pass` / `fail`）は改変しないため影響しないこと（集計値不変）を PBIB-03 / 04 で `HARNESS_SUMMARY` により確認する |
| E-12 | 凍結維持 2 ファイルに**うっかり差分が入った** | `ta-57` TC-14 が FAIL する。PBIB-07 の据え置き表の検査（`git diff --stat`）で置換ステップごとに検出し、**即停止**する |

## 自動化可否サマリ

| 種別 | TC | 自動化 |
|------|----|--------|
| Unit | PBIB-06, PBIB-09 | 可（`test_c3_contract.py`） |
| Integration | PBIB-01, 03, 04, 05, 07, 10, 12 | 可（sandbox 複製 + **P-1 の harness 経由**でスクリプト実起動 / **P-2 の fixture** を伴う） |
| Mutation | PBIB-02, 08, 11 / M-1〜M-10 | 可（sandbox 上で適用 / 復元。**2 層判定**で確認） |
| doc 検査 | PBIB-13 | 可（存在検査 + 禁止文字列検査） |
