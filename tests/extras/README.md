# tests/extras/

`tests/run-tests.sh` から source される拡張テストブロック群。

## 命名規約

`ta-NN-<short-name>.sh` 形式。`ta-` プレフィクス + 連番 + 1 行説明。

## 主な拡張テスト

| ファイル | 対象 | 背景 |
|----------|------|------|
| `ta-14-codex-guarded.sh` | `codex-guarded.sh` | Codex CLI 用 guarded entrypoint 検証 (#343) |
| `ta-15-codex-hook-bridge.sh` | `.codex/hooks/eh-bridge.sh` | Codex CLI 物理 hook parity 検証 (#347) |

## 規約

各 `.sh` は **source される前提**:

- `pass` / `fail` カウンタを直接更新する（数値変数）
- `assert_pass` / `assert_fail` 関数が利用可能（run-tests.sh で定義済）
- `PLANGATE_BIN` / `FIXTURES_DIR` 変数が利用可能
- shebang 不要（実行権限も不要）
- `set -eu` は run-tests.sh 側で済ませているので各 extras は前提とする

## 新しいテスト追加方法（Issue #170）

1. 新 PBI で対象機能のテストを書きたいとき:

   ```sh
   # 例: TA-08 を追加する場合
   touch tests/extras/ta-08-<name>.sh
   ```

2. ファイル冒頭に役割コメントを書く（このファイル末尾の例参照）
3. ローカルで `sh tests/run-tests.sh` を走らせ、新ブロックが拾われ全 PASS することを確認
4. **`tests/run-tests.sh` の本体には触れない**（loader が `tests/extras/ta-*.sh` を自動発見する）

これにより PBI 連続実装時の `tests/run-tests.sh` 末尾領域コンフリクトを回避する（Issue #170 / retrospective P-2 対応）。

## 例

```sh
# tests/extras/ta-08-foo.sh

printf '\n=== TA-08: foo subsystem ===\n'

if sh "$PLANGATE_BIN" foo --check >/dev/null 2>&1; then
  printf '[PASS] foo: --check → exit 0\n'
  pass=$((pass + 1))
else
  printf '[FAIL] foo: --check failed\n'
  fail=$((fail + 1))
fi
```

## set -e 互換書法（retrospective 2026-05-01 s3 P-1 対応）

extras は run-tests.sh の `set -eu` 環境下で source される。**コマンド置換の中で非ゼロ終了を許容したい場合**は exit code を明示捕捉する必要がある。

### NG（早期終了する）

```sh
out=$(python3 myscript.py 2>&1)        # ← myscript.py が exit 1 すると set -e で run-tests.sh 全体が止まる
case "$out" in *"OK"*) ... ;; esac
```

### OK（exit code を捕捉）

```sh
out=$(python3 myscript.py 2>&1) && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q OK; then
  printf '[PASS] ...\n'
  pass=$((pass + 1))
else
  printf '[FAIL] ... (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
```

### trap は使わない

EXIT/INT/TERM trap は extras 間で互いに上書きし合い、set -e との組み合わせで予測しにくい挙動になる（s3 retrospective で実害発生）。**fixture の cleanup は trap ではなく直接 `rm -rf` で行う**。

```sh
# OK: trap なし、明示的な前後 cleanup
TMP_DIR="$(...)"
rm -rf "$TMP_DIR"     # 念のため事前削除
mkdir -p "$TMP_DIR"
# ... テスト本体 ...
rm -rf "$TMP_DIR"     # 後片付け（このブロック内で完結）
```

### 関数定義の namespace

extras はすべて同一 shell プロセスで source されるため、関数名の衝突に注意:

- 各 extras 固有のヘルパは `_taN_helper_name()` のように `_taN_` プレフィクスを推奨
- `assert_pass` / `assert_fail` は run-tests.sh 提供で再定義不要

## 関連

- 親 issue: [#170](https://github.com/s977043/plangate/issues/170)
- TASK: `docs/working/TASK-0050/`
- retrospective: `docs/working/retrospective-2026-05-01.md` § P-2 / T-4
- set -e 書法ガイド追加: `docs/working/retrospective-2026-05-01-s3.md` § P-1 / T-2

## 現行テスト一覧

| File | 内容 |
|------|------|
| `ta-04-check-pr-issue-link.sh` | PR ↔ Issue リンク検証 |
| `ta-05-validate-schemas.sh` | JSON schema 検証 |
| `ta-06-hooks.sh` | EH-1〜EH-9 hook 動作検証 |
| `ta-07-eval-runner.sh` | eval-runner 8 観点 |
| `ta-08-codex-log-parser.sh` | Codex log parser |
| `ta-09-metrics.sh` | metrics 収集 |
| `ta-10-doctor-fix.sh` | doctor --fix 検証 |
| `ta-11-plan-hash-contract.sh` | plan_hash 契約 |
| `ta-12-maintenance.sh` | maintenance window |
| `ta-13-plangate-setup.sh` | plangate-setup skill / agent |
| `ta-14-codex-guarded.sh` | `scripts/codex-guarded.sh` 8 観点 (Gap 4 / #336 / PR #343) |
| `ta-15-codex-hook-bridge.sh` | `.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` 7 観点 (Gap 4 / #336 / PR #347) |

## 隔離・後始末の規約（#530 / 2026-06-11 正本化）

source 型の構造上 **trap EXIT は後続 extras に上書きされ、発火が保証されない**
（ta-09 で実害を確認済み）。各 extras は以下を遵守する:

1. **trap に頼らず末尾で明示 cleanup + 開始時の冪等掃除** — fixture（一時 TASK
   ディレクトリ等）はファイル末尾で `rm -rf` し、可能なら「削除されたこと」自体を
   TC として検証する（例: ta-34 TC-06 / ta-37 TC-07）。set -e による途中終了で
   cleanup が走らないケースに備え、**開始時にも前回残骸を `rm -rf` する**（冪等性）
2. **共有 cleanup ユーティリティ `register_cleanup` を使う（推奨 / #530-3）** —
   run-tests.sh が提供する `register_cleanup <path>...` で一時パスを登録すると、
   全 extras の source 完了後にハーネス末尾の `_pg_drain_cleanup` が一括削除する。
   trap を一切張らないため source 連鎖の上書き問題が起きない（実装例: ta-22）。

   ```sh
   PG_TMP=$(mktemp -d)
   register_cleanup "$PG_TMP"   # ハーネス末尾で自動 drain（trap 不要）
   ```

   どうしても trap が必要な場合は**サブシェルに閉じ込める**（ta-28 方式）か、
   自前ガード変数で再実行を no-op 化する（ta-09 方式）。親シェルの trap を
   `trap - EXIT` で消さない（他 extras / ハーネスの cleanup を巻き込むため）
3. **実 docs/working を汚染しない** — tracked パスを使う場合は実行前退避→復元、
   原則は専用の未追跡 TASK 名（`TASK-TA<NN>TMP` 等）+ mktemp サンドボックス
   （正本: PR #511 の隔離パターン、hooks スイートは scripts/hooks のサンドボックス複製）
4. **set -e 下の非ゼロ rc 捕捉**は `rc=0` を初期化してから `out="$(cmd)" || rc=$?`
   で上書きする（`out="$(cmd)"; rc=$?` は非ゼロ時にスイートを途中終了させる）。
   関数内では `local out="$(cmd)" || rc=$?` と書かない — `local` 自体の終了
   ステータスがコマンドの rc を握りつぶすため、宣言と代入を分ける
5. **変数は `_tNN_` プレフィクス**で名前空間を分け、他 extras と衝突させない
6. **依存ゲート** — python ライブラリ等に依存する TC は環境差を吸収する
   （CI には導入済み前提）。実パターン（ta-35 / ta-36 参照）:
   `if ! python3 -c 'import x' >/dev/null 2>&1; then printf '[SKIP] ...'; else 本体 fi`
7. **PLANGATE_* env はスイートが無害化する** — 実 hooks を直接呼ぶ extras
   （ta-11 / ta-12 等）は、呼び出し元 env の `PLANGATE_SKIP_REASON` 等が漏れると
   **実監査ログ（skip-decision-log.jsonl）へ書き込む**（2026-06-11 実害確認）。
   harness 実行では run-tests.sh 冒頭で unset 済み。**standalone 実行ではその
   防御が効かないため、規約 8 に従い各 extras が standalone 分岐で自前 unset
   する**（#914）。テスト内で意図的に設定する場合はコマンド単位の env 前置に
   限定する。**テスト個別の再帰防止シグナル（例: `ta-26` の `PG_T26_NO_RECURSE`）
   は run-tests.sh の unset 集合に足さない**（足すと本規約の包含検査 = `ta-26`
   TC-33 が全 extras に波及する）。代わりに**当該 extras 自身の harness 分岐で
   unset して呼び出し元 env の漏れを無害化する**（#1036。実装例: `ta-26` の
   harness 分岐 else 節。配置は `ta-62` の TC-S が静的検査する）
8. **harness/standalone 判別は `PG_HARNESS_SOURCED` と `FIXTURES_DIR` の AND**
   （#914 / R-204）— 新規 extras は、run-tests.sh が設定する `PG_HARNESS_SOURCED`
   （**非 export**。source された extras だけに見えるシグナル）と `FIXTURES_DIR`
   の **AND** で harness 実行を判別する:

   ```sh
   if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
     : # harness（run-tests.sh から source されている）
   else
     # standalone — 先に外部 env 汚染を無害化してから自前 fallback を定義する
     unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
       PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
       PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
   fi
   ```

   片方でも欠ければ **standalone 側（安全側）へ倒す**。`FIXTURES_DIR` 単独判定は
   外部 env 漏れだけで harness 実行と誤判定する（実害: `PLANGATE_HOOK_TASK` 漏洩下の
   ta-39 standalone が 7 件 FAIL のまま exit 0 で素通り）。standalone 分岐
   （else 節の内側のみ）では `PLANGATE_*` / `PG_HARNESS_SOURCED` =
   **run-tests.sh 冒頭の unset 集合と同一の 7 env** を unset して外部 env 汚染を
   無害化する。単独判定の残存ゼロと unset 集合の包含は `ta-26` の TC-33 が静的検査する。
   **#921 以降の bootstrap（実行契約 helper `_extra-contract.sh` を source する形）では、
   後段「実行契約」節の harness 判定述語＝3 条件 AND（`EXTRAS_DIR` 非空を含む /
   HR-4 = (b)）が本規約の 2 条件 AND より優先する**（本項のコード例は移行前形の
   参考であり、契約移行済みファイルの判定式の正本ではない）。
   **再帰防止シグナルの unset 位置（#1036）**: テスト個別の再帰防止シグナル
   （`PG_T26_NO_RECURSE` 等）は **harness 分岐（else 節）でのみ** unset する。
   **standalone 分岐では意図的に unset しない** — standalone 分岐は TC-13 型の
   子プロセス（シグナルをコマンド単位前置で受け取る側）も通る経路であり、
   そこで unset すると再帰防止ガード自体が壊れて孫 spawn の再入ループになる

9. **共有の実 repo パスに置く一時状態は「射程宣言 → 先頭 prune → register_cleanup」
   の三点セットで扱う（#947 / #1209 / #1210 / 2026-08-25 正本化）** —
   本節冒頭の :130「trap に頼らず末尾で明示 cleanup + 開始時の冪等掃除」と
   :134「共有 cleanup ユーティリティ `register_cleanup` を使う（推奨 / #530-3）」の
   運用形を、機械検査可能な形に固定したもの。回帰テストは
   `tests/extras/ta-76-extras-temp-state-scope.sh`。

   - **射程宣言**: そのファイルが実 repo に作る一時パスを **1 箇所にまとめて**
     宣言する。使用箇所ごとに `rm` を散らさない。宣言には「誰が所有するか」も
     含む — **他の extras が所有するパスを勝手に prune しない**。並走している
     所有者の実行を壊すため、注入した側が注入したものだけを始末する
   - **先頭 prune**: 宣言した全パスの掃除を **body の最初の副作用より前** に
     済ませる。**「冪等に掃除している」だけでは足りず、順序が要件**
     （実害: `ta-42` は `TASK-T999` の掃除が判定 TC-04 より後にあり、中断残骸で
     TC-04 が誤 FAIL していた = #947 問題 1）
   - **register_cleanup 登録**: 同じリストをそのまま登録し、ハーネス末尾の
     drain に委ねる（`trap` は張らない = 本節 :130 / :134）
   - **`${var:?}` は「合成後のパス」ではなく root 変数に付ける**（#1210 / 2026-08-25
     是正）。`_ROOT="$(cd -- "$FIXTURES_DIR/../.." && pwd)"` は `$FIXTURES_DIR`
     が未設定/空なら `/` に解決され、合成後は `//docs/working/...` になる。
     **合成後は非空なので `${var:?}` は発火せず**、`rm` がファイルシステムルート
     直下を指した（stub `rm` サンドボックスでの実測。`ta-12` / `ta-42` が該当）。
     正しい形は `ta-44` / `ta-45` で、root の導出自体を
     `PG_HARNESS_SOURCED` と `FIXTURES_DIR` の AND（規約 8）で守り、
     root が repo でなければ **副作用を出さずに抜ける**:

     ```sh
     _TNN_FX="${FIXTURES_DIR:-}"
     if [ -n "$_TNN_FX" ]; then _TNN_ROOT="$(CDPATH= cd -- "$_TNN_FX/../.." && pwd)"; else _TNN_ROOT=""; fi
     if [ -z "$_TNN_ROOT" ] || [ ! -f "$_TNN_ROOT/bin/plangate" ]; then
       # 非空チェックだけでは `/` を弾けないので実体で確かめる
       printf '  [FAIL] ta-NN: repo root unresolved\n' 1>&2; return 0
     fi
     _TNN_WDIR="${_TNN_ROOT:?ta-NN: repo root unresolved}/docs/working"
     ```

   - **爆風半径は広げない** — `${var:?}` を足すのは防御の追加であって、`rm -f` を
     `rm -rf` に変えたり存在ガードを外したりする理由にはならない。対象が
     ファイル 1 本なら `rm -f` のまま、木を消すなら `[ -e "$p" ]` で守る
   - **ガードを緩めるトークンを作る fixture は TTL を縮める** — 中断残骸が
     有効でいられる時間が、そのまま実害窓になる（実害: `ta-12` の
     `until = now + 600` が中断後 600 秒、非 HO パスへの `MAINTENANCE_SKIP` を
     開けたままにしていた = #1209。Hardening Override はこの窓を貫通しないが、
     非 HO パスは `exit 2` → `exit 0` に反転する）

   ### 契約値（正本はこの表。`ta-76` はこの表を機械検査するだけ）

   | 契約 | 値 | 根拠 |
   |---|---|---|
   | fixture TTL 上限 | **120 秒** | 各 TC の hook 呼出に十分な余裕を残しつつ残骸窓を最小化。現行 `ta-12` は 60 秒 |
   | `until` の組み立て | `_TNN_TTL` 変数経由（正の直書き禁止） | 宣言だけ縮めて heredoc 側に `+600` を直書きすると窓は元に戻る |
   | top-level `trap` を持ってよい extras | `ta-09-metrics.sh`（自前ガード変数方式） / `ta-28-plugin-version.sh`（サブシェル方式） | 本 README の :144-146「どうしても trap が必要な場合は**サブシェルに閉じ込める**（ta-28 方式）か、自前ガード変数で再実行を no-op 化する（ta-09 方式）。」が許容形として名指ししている 2 形。なお :128「（ta-09 で実害を確認済み）」は規約が生まれた経緯の出典表示であって、現在の評価ではない（:145 が同じ ta-09 を許容形として挙げているため、経緯と評価は分けて読む） |
   | top-level `trap` を持つ **既知違反**（新規追加禁止） | `ta-07-eval-runner.sh` / `ta-24-parallel-review.sh` | 本 README の :146「親シェルの trap を `trap - EXIT` で消さない（他 extras / ハーネスの cleanup を巻き込むため）」に真正面から反する（`ta-07:56` / `ta-24:285` がいずれも `trap - EXIT INT TERM`）。実害あり: `ta-24:285` は source 順で先行する `ta-09:23` の `trap cleanup_metrics EXIT INT TERM` を実際に解除する。**是正は別 issue**（本表は「見逃していない」ことの記録） |
   | 上記 4 本の `trap` 行数 | 2 / 1 / 2 / 2 | ファイル粒度の登録だけだと「登録済みファイルへ trap を足し放題」「trap を消しても登録が残る（stale）」の両方向で乖離するため本数まで固定する |

   ### できること / できないこと（2026-08-25 実測で是正）

   - **hook 側は sandbox へ移設できる**。`scripts/hooks/check-plan-hash.sh` の
     `REPO_ROOT` は `$0` 由来（`cd -- "$(dirname -- "$0")/../.."`）なので、
     **規約 3 が正本として挙げるサンドボックス複製**（PR #511 の隔離パターン）で
     複製先を repo root にできる。実測: 複製先へ `PLANGATE_HOOK_FILE=docs/foo.md`
     で実行すると `hook-events.log` / `skip-decision-log.jsonl` は **複製先に**
     生成され、実 repo は不変。`bin/plangate` も `$0` 由来だが、templates /
     schemas / scripts まで揃える必要があり複製コストが高い
   - **無いのは `env` seam であって、隔離手段そのものではない**。`PLANGATE_*`
     で出力先を差し替える口は無く、両者とも Hardening Override 対象で AI が
     編集して seam を足すこともできない。ここから「実現不可能」と結論するのは
     誤りで、正しくは「**hook を直接呼ぶ TC（`ta-12` の EH-3 部分 / `ta-45` の
     TC-01）は複製で逃がせる。`bin/plangate` を叩く TC（`ta-42` / `ta-44` の
     全体、および `ta-12` / `ta-45` の doctor 系）は複製コストが高く現実的で
     ない**」。ファイル単位で完全に逃がすには両方の複製が要る点に注意
   - **`ta-76` が測れていない穴（既知）**: `ta-12` に対する「中断残骸の注入」は
     未実装。`ta-12` が所有する一時パスは承認トークンそのもので、AI がそこへ
     書くのは EH-13 token-guard が block する。現状は注入なしで実走し
     「単体で全 pass すること」「実行後にトークンが残らないこと」までを測る

## PASS 判定の書き方（#1178 / 由来: #1108 / #994 / #1004 / #1169）

> **PASS 判定は rc と一意 reason トークンの対で書く。選言のみの述語を使わない。**

これは観点を増やす規約ではなく、**述語の書き方**の規約である。テストが守りたい
不変条件と述語が非対称だと、**対象の分岐に到達しなくても緑になる**。
実際に 4 件が同じ形で false green になっていた:

| 症状 | 述語 | 何が起きたか |
|---|---|---|
| `ta-45` TC-01 | `grep -qiE 'SKIP\|PASS'` | 検査対象の分岐に**到達すらしていない**のに、別分岐の出力に `SKIP` の 3 文字があるため通っていた（別分岐は `exit 2`）|
| `ta-70` TC-01 | `grep -q "$MARKER"` | marker 文字列があるだけの**未ガードファイル**が緑になり、その結果 TC-04 が実ファイルを `sh` 起動して #1169 を再発させる経路が開いていた |
| `ta-26` TC-33 (1) | `grep -q 'PG_HARNESS_SOURCED' <file>` | 実際に守っていたのは「相方シグナルの**文字列がファイル中に存在すること**」で、「**判別式が AND であること**」ではなかった |
| `ta-26` TC-33 (2) | 抽出規則が README の例示形を通るか未検証 | 規約の正本（例示コードブロック）と検査器の乖離が検出できなかった |

### 規則

1. **rc と一意 reason トークンの対で判定する。**
   矯正パターンは `ta-39-eh3-doc-light.sh:94`:

   ```sh
   if [ "$_t39_rc" = "0" ] && printf '%s' "$_t39_out" | grep -q 'DOC_LIGHT_SKIP'; then
   ```

   rc だけでは「別の理由で同じ rc」を区別できず、メッセージだけでは
   「別分岐が同じ語を含む」を区別できない。**対で見る。**
2. **選言（`A|B`）のみの述語を PASS 条件にしない。** `grep -qiE 'SKIP|PASS'` の
   ように「どちらかが出ていればよい」と書いた時点で、その TC は分岐を
   区別していない。分岐ごとに期待 rc と期待トークンを固定する。
3. **reason トークンは分岐固有にする。** 対象コードに一意な語が無い場合は
   **その分岐でしか出ない文字列**（診断文の全文など）を使う。
   汎用語（`python3` / `SKIP` / `OK`）は判別に使わない — 本 repo では
   `python3 scripts/foo.py` という Usage 定型が広く出現するため、
   `python3` の語は「ガードが効いた」証拠にならない。
4. **対照（negative control）を同じ TC に置く。** 「期待の入力で PASS」だけでは
   述語が恒真に退行しても気づけない。**期待しない入力では落ちること**を
   同じ述語で確かめる（例: `ta-45` TC-01 は `mode=conversation` の rc=0 +
   トークンありと、対照 `mode=cli` の rc=2 + トークンなしを両方見る）。
5. **文字列の存在ではなく構造を見る。** 「ファイルのどこかに X がある」は
   ほぼ常に弱すぎる。位置・ブロック・同一行といった**構造**で書く
   （例: `ta-70` TC-01 は「shebang の次の行が厳密にガード開始行であり、
   閉じ行までのブロック内に `exit 2` がある」）。
6. **ループで集めた違反リストの空判定は、母数の floor と連言にする。**
   `[ -z "$violations" ]` はループが 0 回転でも真になる（vacuous PASS）。
   `[ "$total" -ge "$FLOOR" ]` を必ず添える。**floor であって絶対件数の
   契約値ではない**（`-eq` にしない / #1087 AC-9）。
   ただし母数が **その場に書かれたリテラルのトークン列**（`for x in 'a' 'b' 'c'`）
   のときは 0 回転があり得ないので floor は不要。floor が要るのは母数が
   **glob / ファイル走査由来**で空振りしうるときである。
7. **新規・是正した TC は変異注入で検出力を実証する。** 守りたい不変条件を
   破る変異を入れ、**是正前は SURVIVE し是正後は KILL される**ことを実測で
   示す（#1163 / #1176 で確立した順序）。変異が実際に入ったことを先に
   確認する（`diff` / `grep -c` が 0 行なら変異は空振りしている）。
8. **緩和フォールバックを無制限に置かない。** 「判別できない入力は旧来の
   弱い判定へ落とす」型のフォールバック（`nocond` 等）は、**判別式の *形* を
   変えるだけで検査を素通りできる迂回路**になる。フォールバックを残すなら
   **明示 allowlist に限定し、allowlist 外が落ちてきたら FAIL** にする
   （#1250 F2。`ta-26` TC-33 の `_T26_NOCOND_ALLOW33` が実装例）。
9. **規約の正本が例示コードなら、その例示自身を検査器に通す。** 例示を
   fixture として抽出して検査器へ流し、**抽出形（shape）まで連言で要求**する
   （返り値だけを見ると、例示が緩和フォールバックへ落ちても緑になる /
   #1250 F2。`ta-26` TC-38 が実装例）。

### 本節の残存脅威モデル（機械検証の射程 / #1250 F5）

本節の規則のうち **機械検証を持つのは規則 5・6・8・9 の一部だけ**である。
内訳と、機械化を見送った判断の根拠を残す。

| 規則 | 機械検証 |
|---|---|
| 1〜4（rc + 一意トークン / 選言禁止 / 分岐固有トークン / 対照）| **なし**（レビュー時の目視） |
| 5（文字列でなく構造を見る）| `ta-70` TC-01 + TC-07（3 クラスの対照つき） |
| 6（違反リストの空判定に母数 floor）| **なし（見送り）**。下記参照 |
| 7（変異注入で検出力を実証）| **なし**（PR 記述と実測ログで担保） |
| 8（緩和フォールバックの allowlist 化）| `ta-26` TC-33（allowlist 外の `nocond` は FAIL） |
| 9（規約の例示自身を検査器に通す）| `ta-26` TC-38（shape=`cond` を連言で要求） |

**規則 6 の静的検出を見送った根拠（実測）**: 「`[ -z "$violations" ]` 相当の
判定の周辺に floor 連言が無い TC」を静的に列挙する検出器を 2 案試作し、
`tests/extras/ta-*.sh` 全件に対して実測した。

- 案 A（`if` 条件に `-z "$var"` があり then 節の先頭が `*_pass` で、条件に
  `-ge` が無いものを列挙）→ **21 件ヒット**。うち大半が偽陽性だった:
  単一コマンドの出力空判定（`ta-50` の `_t50_out`）・diff 結果の空判定
  （`ta-57` の `_t57_diff`）・floor を **外側の実走ゲート側**に持っている
  もの（`ta-70` TC-04 の `_t70_badrc`）・母数を `-ge` でなく等値で固定して
  いるもの（`ta-63` の `_t63_elems`）が混在する。
- 案 B（変数がループ内で `VAR="$VAR ..."` の形で追記される場合だけに絞る）
  → **ヒット 1 件のみ**で、しかもそれ（`ta-56` の `_t56_viol`）は母数が
  リテラルのトークン列であり 0 回転があり得ない＝規則 6 の対象外だった。
  一方で `ta-70` の `_t70_missing` / `_t70_late` / `_t70_broken` のような
  **本物の対象は 1 件も検出できなかった**（追記が `cmd || VAR="$VAR ..."`
  の形で行頭代入ではないため）。

「違反リストか否か」「母数が空振りしうるか」「floor が外側のゲートにあるか」は
いずれも **データフローを追わないと決まらない**。行単位の静的検査では案 A の
方向に振れば偽陽性で運用不能、案 B の方向に振れば偽陰性で無意味になる。
したがって **規則 6 は当面レビュー時の目視で担保する**。
これは多層防御の 1 層が欠けている状態であり、規則 6 違反は
**C-4 Human レビューでのみ捕捉される**。

規則 1〜4・7 も同様に機械検証を持たない。**本節は「検査器がある規約」ではなく
「レビュー観点の正本」であり、完全性を主張しない。**

## 実行契約（execution contract / #921 TASK-0921）

### rc 意味レイヤー（standalone 実行時）

| rc | 意味 |
|---:|---|
| **rc=0** | standalone-capable が全件 pass（検査した結果、問題なし） |
| **rc=1** | 内部テスト失敗（`fail > 0`）。**前提未充足でも `fail > 0` なら rc=1 が優先** |
| **rc=2** | 実行方法エラー（harness-only を直接実行した / capability 宣言が不正） |
| **rc=3** | **前提未充足＝検査していない**（prerequisite absent。rc=0 で成功を装ってはならない） |

**rc=2 は harness-only 誤実行専用の値であり、hook の BLOCK（`exit 2`）とは別名前空間**。
extras 自身のトップレベル終了コードと、テスト対象 hook のサブプロセス戻り値を混同しないこと。

### capability marker（inventory の機械正本）

各 `ta-*.sh` は**先頭 20 行以内**に次のコメントを **exactly 1 行**置く:

```sh
# PG_EXTRA_CAPABILITY: standalone-capable
# （または）
# PG_EXTRA_CAPABILITY: harness-only
```

marker は説明ではなく契約回帰テスト（`ta-61-extra-contract.sh`）が読む機械正本。
ファイル名リストを正本にしない。

### 共有 helper `_extra-contract.sh`（唯一の例外）

`tests/extras/_extra-contract.sh` は exit 契約の一元化のためだけに置かれた**唯一の共有ファイル**
（extras 自己完結の慣習に対する意図的な例外 / #914 E-1 の反転）。**exit 契約 helper 以外の
共有ファイルを `tests/extras/` に増やしてはならない**。`_` 接頭辞のため runner の
`ta-*.sh` glob には拾われない。**対話シェルへ source しないこと** — standalone finalize は
`exit` するため、対話シェルごと終了する。

### 新規ファイル checklist

1. 先頭 20 行以内に `PG_EXTRA_CAPABILITY:` marker を exactly 1 行
2. bootstrap（既存の移行済みファイルの `extras execution contract bootstrap` ブロックを複製）
   → `pg_extra_contract_init <basename-id> <capability>` を **body の副作用より前**に呼ぶ
   （test-id は**拡張子なし basename**。番号は `ta-14` が 2 本あるため一意でない）
3. **ファイルの最終行は `pg_extra_contract_finalize` の呼出のみ**とし、直前に他コマンドを
   挟まない（直前行が `$?` を上書きすると original rc が黙って 0 になる）
4. **summary の printf を呼び出し側に書かない** — summary（`TA-<NN> standalone: N passed,
   M failed`）は helper 内部が出力する
5. **`return 0 2>/dev/null || …` を型を問わず使わない** — top-level `return` は POSIX 未定義で
   **dash は終了 / bash は継続**と挙動が逆転する（#1026）。前提未充足の skip は必ず
   `pg_extra_contract_skip <reason>` を経由する（standalone では rc=3 で exit、harness では
   skip の後に素の `return 0` で source 元へ戻る）
6. standalone 実行の検証は必ず `sh tests/extras/ta-NN-*.sh </dev/null` と **stdin を遮断**する
   （ta-50 等の stdin 待ちハング防止）
7. **`ta-` プレフィクスを持つファイルのみが runner にテストとして収集される**
   （`"$EXTRAS_DIR"/ta-*.sh` glob）

### contract probe（test section 限定の test-only seam）

`PG_EXTRA_CONTRACT_PROBE=force-fail` + `PG_EXTRA_CONTRACT_TARGET=<basename-id>` は
契約回帰テストが「各ファイルが finalize に到達し fail を伝播すること」を実行ベースで
検証するための seam。次の 5 点を厳守:

1. **test-only** であり、テスト以外の用途に使わない
2. **失敗を増やすことしかできない**（fail-safe。成功を偽装する経路は無い）
3. **CI 設定・開発シェル・`.env` に設定してはならない**
4. **harness mode では無視される**（run-tests.sh 経由の実行には影響しない）
5. probe 由来の失敗は `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>` という
   **通常の `[FAIL]` と区別可能なメッセージ**で出力される

`PG_EXTRA_CONTRACT_PROBE` を設定して `PG_EXTRA_CONTRACT_TARGET` を未設定にした場合は
fail-closed（診断 + **rc=4** で終了。mis-wired probe を no-op にしない）。probe env は init 時に捕捉・unset され、テスト本体が
起動する子プロセスへは伝播しない。

### 案 D（末尾 explicit finalize）

本契約は trap を張らない（**規約 1–2 に例外を作らない**）。終了経路は各ファイル末尾の
`pg_extra_contract_finalize` に一元化され、finalize は harness では必ず `return 0`、
standalone でのみ `exit` する。finalize 未到達（早期 exit の混入）は契約回帰テストの
force-fail probe が rc≠1 として検出する。

### 契約回帰テスト `ta-61` の実行コストと env knob（#1207 / #1208）

`ta-61-extra-contract.sh` は covered な extras 1 本につき **standalone 子プロセスを
2 起動**する（clean baseline / 汚染 env + 自分自身を target にした force-fail probe）。
extras が 1 本増えると 2 起動増える。**絶対件数は契約値にしない**
（covered 集合は `_pending_migration` の消化で増減する）。

| env | 既定 | 意味 |
| --- | --- | --- |
| `PG_T61_RUN_TIMEOUT_SEC` | `180` | 子プロセス 1 起動の上限秒。**下限 180（R-026）は床で、下げる方向の override は受け付けない**。混雑した機械で rc=124 が出るときに引き上げる。引き上げても timeout は **FAIL のまま**（黙って SKIP / 緑にしない）で、診断に load1 と同名プロセス数が付く |
| `PG_T61_NO_RECURSE` | `0` | nested 実行であることの宣言。nested full-suite / sandbox 子が `1` を渡す。**per-file 実行ループと nested full-suite / sandbox TC を止める**（囲っている run が同一ツリーの同一 covered 集合を実行済みで、再実行は完全な重複） |
| `PG_T61_EXEC_ONLY_PROBES` | `0` | TC-16 の sandbox 子専用。実行ループの対象を**ハードコードされた `ta-*-probe-*.sh` パターン**へ限定する。sandbox の外で立てると対象が 0 本になり TC-25(3) が fail-closed で落ちるため、実 run を黙って縮める用途には使えない |
| `PG_T61_SKIP_SUITE` | `0` | mutation driver 専用。nested full-suite（TC-14 / TC-15 runner）だけを止め、sandbox TC は残す |

いずれも **テスト実行専用**であり、`PG_EXTRA_CONTRACT_PROBE` と同様に
CI 設定・開発シェル・`.env` へ設定してはならない。

なお `ta-61` は covered 集合に比例して長くなるため、下記ウォッチドッグの既定閾値
`PG_EXTRA_WATCHDOG_SEC=300` を正常時でも超えうる。ウォッチドッグは既定で
**警告のみ**（実行意味論を変えない）なので、`ta-61` の警告行は stall ではなく
「このファイルが構造的に長い」ことの表示である。

## 進行マーカー / 所要時間レポート / ウォッチドッグ（失敗の属性化）

`tests/run-tests.sh` は extras を **現在のシェルに直列 source** するため、
1 ファイルが長時間ブロックすると CI の job timeout で run 全体が落ち、
原因ファイルがログから特定できなかった。per-file の `timeout` は **採らない**:
extras は `pass` / `fail` / `register_cleanup` を共有しており、サブプロセス隔離は
集計と cleanup 契約を壊す（全 `ta-*.sh` が共有カウンタを直接更新している）。

代わりに runner が次の 4 つを提供する:

1. source 直前の進行マーカー `[extras] >>> <file> (start t+Ns)` と
   終了行 `[extras] <<< <file> done in Ns (new failures: N)`
   — kill されてもログ末尾のマーカーが原因ファイルを一意に指す
2. 実行後の所要時間レポート（遅い順）と、失敗のファイル単位の属性化
3. 別プロセスのウォッチドッグ（既定は**警告のみ**で実行意味論を変えない）
4. `GITHUB_STEP_SUMMARY` が存在する環境でのみ Markdown サマリを追記

| env | 既定 | 意味 |
| --- | --- | --- |
| `PG_EXTRA_TOP_SLOW` | `10` | 所要時間レポートの表示件数（`0` で無効） |
| `PG_EXTRA_WATCHDOG_SEC` | `300` | 1 ファイルの警告閾値（秒 / `0` で無効） |
| `PG_EXTRA_WATCHDOG_POLL` | `5` | ウォッチドッグのポーリング間隔（秒） |
| `PG_EXTRA_WATCHDOG_ACTION` | `warn` | `kill` にすると閾値超過で run を打ち切る |

回帰テスト: `tests/extras/ta-72-extras-progress.sh`。
