# tests/extras/ta-34-cli-min-coverage.sh
# Sourced by tests/run-tests.sh
# Issue #515: 未テストサブコマンド（init/status/handoff/verify/eval）の最小カバレッジ。
# 専用 TASK 名 + 末尾明示削除で実 docs/working を汚染しない（#511 隔離パターン）。

printf '\n=== TA-34: CLI min coverage — init/status/handoff/verify/eval (#515) ===\n'

_t34_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
_t34_task="TASK-TA34TMP"
_t34_dir="$_t34_root/docs/working/$_t34_task"
rm -rf "$_t34_dir"  # 冪等: 前回残骸の除去

# TC-01: init 正常系 — 期待ファイル一式の生成
_t34_out="$(sh "$PLANGATE_BIN" init "$_t34_task" 2>&1)" || true
_t34_missing=""
for _t34_f in INDEX.md pbi-input.md current-state.md approvals evidence; do
  [ -e "$_t34_dir/$_t34_f" ] || _t34_missing="$_t34_missing $_t34_f"
done
if [ -z "$_t34_missing" ]; then
  printf '[PASS] TA-34 TC-01: init が期待ファイル一式を生成\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-34 TC-01: 欠落:%s / out=%s\n' "$_t34_missing" "$_t34_out"; fail=$((fail + 1))
fi

# TC-02: init 異常系 — 引数なしで Usage
_t34_out="$(sh "$PLANGATE_BIN" init 2>&1)" || true
case "$_t34_out" in
  *"Usage: plangate init"*) printf '[PASS] TA-34 TC-02: init 引数なしで Usage 表示\n'; pass=$((pass + 1)) ;;
  *) printf '[FAIL] TA-34 TC-02: Usage が出ない: %s\n' "$_t34_out"; fail=$((fail + 1)) ;;
esac

# TC-03: status 正常系 — exit 0 + Task 行
if _t34_out="$(sh "$PLANGATE_BIN" status "$_t34_task" 2>&1)" \
   && printf '%s' "$_t34_out" | grep -q "Task:.*$_t34_task"; then
  printf '[PASS] TA-34 TC-03: status が exit 0 で Task 情報を表示\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-34 TC-03: status 失敗: %s\n' "$_t34_out"; fail=$((fail + 1))
fi

# TC-04: handoff — handoff.md 生成 + 6 要素ガイダンス
_t34_out="$(sh "$PLANGATE_BIN" handoff "$_t34_task" 2>&1)" || true
if [ -f "$_t34_dir/handoff.md" ] && printf '%s' "$_t34_out" | grep -q "6 required sections"; then
  printf '[PASS] TA-34 TC-04: handoff が handoff.md を生成し 6 要素を案内\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-34 TC-04: handoff 失敗: %s\n' "$_t34_out"; fail=$((fail + 1))
fi

# TC-05: verify / eval 異常系 — 引数なしで Usage
_t34_bad=""
for _t34_cmd in verify eval; do
  _t34_out="$(sh "$PLANGATE_BIN" "$_t34_cmd" 2>&1)" || true
  case "$_t34_out" in
    *"Usage: plangate $_t34_cmd"*) ;;
    *) _t34_bad="$_t34_bad $_t34_cmd" ;;
  esac
done
if [ -z "$_t34_bad" ]; then
  printf '[PASS] TA-34 TC-05: verify/eval 引数なしで Usage 表示\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-34 TC-05: Usage が出ない:%s\n' "$_t34_bad"; fail=$((fail + 1))
fi

# 後始末（trap に頼らず明示実行 — 実 docs/working 汚染防止）
rm -rf "$_t34_dir"
if [ ! -d "$_t34_dir" ]; then
  printf '[PASS] TA-34 TC-06: fixture を完全削除（汚染なし）\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-34 TC-06: fixture 残骸あり\n'; fail=$((fail + 1))
fi
