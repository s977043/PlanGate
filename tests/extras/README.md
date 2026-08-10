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
   限定する
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
   無害化する。単独判定の残存ゼロと unset 集合の包含は `ta-26` の TC-33 が静的検査する

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
fail-closed（診断 + 非ゼロ終了）。probe env は init 時に捕捉・unset され、テスト本体が
起動する子プロセスへは伝播しない。

### 案 D（末尾 explicit finalize）

本契約は trap を張らない（**規約 1–2 に例外を作らない**）。終了経路は各ファイル末尾の
`pg_extra_contract_finalize` に一元化され、finalize は harness では必ず `return 0`、
standalone でのみ `exit` する。finalize 未到達（早期 exit の混入）は契約回帰テストの
force-fail probe が rc≠1 として検出する。
