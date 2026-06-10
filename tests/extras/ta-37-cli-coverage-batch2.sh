# tests/extras/ta-37-cli-coverage-batch2.sh
# Sourced by tests/run-tests.sh
# Issue #515 第二弾: timeline / keep-rate / resume / context / exec / brainstorm の最小カバレッジ。
# 専用 TASK 名 + 末尾明示削除で実 docs/working を汚染しない（#511 隔離パターン）。

printf '\n=== TA-37: CLI coverage batch2 — timeline/keep-rate/resume/context/exec/brainstorm (#515) ===\n'

_t37_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
_t37_task="TASK-TA37TMP"
_t37_dir="$_t37_root/docs/working/$_t37_task"
rm -rf "$_t37_dir"
sh "$PLANGATE_BIN" init "$_t37_task" >/dev/null 2>&1 || true

# TC-01: 引数なしで Usage（5 コマンド）
_t37_bad=""
for _t37_cmd in timeline keep-rate resume context brainstorm; do
  _t37_out="$(sh "$PLANGATE_BIN" "$_t37_cmd" 2>&1)" || true
  case "$_t37_out" in
    *"Usage: plangate $_t37_cmd"*) ;;
    *) _t37_bad="$_t37_bad $_t37_cmd" ;;
  esac
done
if [ -z "$_t37_bad" ]; then
  printf '[PASS] TA-37 TC-01: timeline/keep-rate/resume/context/brainstorm 引数なしで Usage\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-37 TC-01: Usage が出ない:%s\n' "$_t37_bad"; fail=$((fail + 1))
fi

# TC-02: timeline — run.ndjson 不在の縮退ガイダンス
_t37_out="$(sh "$PLANGATE_BIN" timeline "$_t37_task" 2>&1)" || true
case "$_t37_out" in
  *"No run.ndjson found"*) printf '[PASS] TA-37 TC-02: timeline が run.ndjson 不在を案内\n'; pass=$((pass + 1)) ;;
  *) printf '[FAIL] TA-37 TC-02: %s\n' "$_t37_out"; fail=$((fail + 1)) ;;
esac

# TC-03: keep-rate --no-write — 正常終了 + レポート出力 + ファイル非生成（md/json とも）
_t37_rc=0
_t37_out="$(sh "$PLANGATE_BIN" keep-rate "$_t37_task" --no-write 2>&1)" || _t37_rc=$?
if [ "$_t37_rc" -eq 0 ] \
   && printf '%s' "$_t37_out" | grep -q "Keep Rate v1: $_t37_task" \
   && [ ! -f "$_t37_dir/keep-rate-result.md" ] && [ ! -f "$_t37_dir/keep-rate-result.json" ]; then
  printf '[PASS] TA-37 TC-03: keep-rate --no-write がレポートを stdout のみに出力\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-37 TC-03: %s\n' "$_t37_out"; fail=$((fail + 1))
fi

# TC-04: resume — 現在状態を表示
_t37_out="$(sh "$PLANGATE_BIN" resume "$_t37_task" 2>&1)" || true
case "$_t37_out" in
  *"Resume: $_t37_task"*) printf '[PASS] TA-37 TC-04: resume が現在状態を表示\n'; pass=$((pass + 1)) ;;
  *) printf '[FAIL] TA-37 TC-04: %s\n' "$_t37_out"; fail=$((fail + 1)) ;;
esac

# TC-05: context --no-write — 正常終了 + manifest を stdout のみに出力（md/json とも非生成）
_t37_rc=0
_t37_out="$(sh "$PLANGATE_BIN" context "$_t37_task" --phase plan --no-write 2>&1)" || _t37_rc=$?
if [ "$_t37_rc" -eq 0 ] \
   && printf '%s' "$_t37_out" | grep -q "Context Manifest: $_t37_task" \
   && [ ! -f "$_t37_dir/context-manifest.md" ] && [ ! -f "$_t37_dir/context-manifest.json" ]; then
  printf '[PASS] TA-37 TC-05: context --no-write が manifest を stdout のみに出力\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-37 TC-05: %s\n' "$_t37_out"; fail=$((fail + 1))
fi

# TC-06: exec — C-3 未承認でゲート拒否 + 非ゼロ終了（承認境界の機械検証。
# exit 0 で素通りすると CI/CD で検知できないため終了コードまで検証する）
_t37_rc=0
_t37_out="$(sh "$PLANGATE_BIN" exec "$_t37_task" 2>&1)" || _t37_rc=$?
if [ "$_t37_rc" -ne 0 ] && printf '%s' "$_t37_out" | grep -q "C-3 gate not cleared"; then
  printf '[PASS] TA-37 TC-06: exec が C-3 未承認をブロックし非ゼロ終了（rc=%s）\n' "$_t37_rc"; pass=$((pass + 1))
else
  printf '[FAIL] TA-37 TC-06: rc=%s out=%s\n' "$_t37_rc" "$_t37_out"; fail=$((fail + 1))
fi

# 後始末（trap に頼らず明示実行）
rm -rf "$_t37_dir"
if [ ! -d "$_t37_dir" ]; then
  printf '[PASS] TA-37 TC-07: fixture を完全削除（汚染なし）\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-37 TC-07: fixture 残骸あり\n'; fail=$((fail + 1))
fi
