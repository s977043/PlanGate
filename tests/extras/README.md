# tests/extras/

`tests/run-tests.sh` から source される拡張テストブロック群。

## 命名規約

`ta-NN-<short-name>.sh` 形式。`ta-` プレフィクス + 連番 + 1 行説明。

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
4. **`tests/run-tests.sh` の本体には触れない**（loader が `tests/extras/*.sh` を自動発見する）

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
