# tests/extras/ta-11-plan-hash-contract.sh
# Sourced by tests/run-tests.sh — relies on $pass / $fail / $FIXTURES_DIR
# TASK-0100 (#193 follow-up): scripts/plan_hash_util.py（Python 共有正本）と
# EH-3 shell（scripts/hooks/check-plan-hash.sh の sed 抽出）の plan_hash
# 抽出契約を fixture で固定する。
#
# 契約:
#   - 正常 / 偽プロパティ注入 / plan_hash 無: shell ≡ python（parity 必須）
#   - 不正 JSON（末尾カンマ等）: python は strict に拒否（None）。これは
#     「不正な c3.json を承認記録として信用しない」意図的安全側であり
#     shell(sed 寛容抽出) との差異は **仕様**（バグではない）。

printf '\n=== TA-11: plan_hash util ↔ EH-3 shell 契約 ===\n'

PHC_FIX="$FIXTURES_DIR/plan-hash-contract"
# repo root = tests/fixtures の 2 つ上（run-tests.sh が $FIXTURES_DIR を渡す）
PHC_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"

phc_shell() {
  grep '"plan_hash"' "$1" 2>/dev/null \
    | sed 's/.*"plan_hash"[[:space:]]*:[[:space:]]*"sha256:\([0-9a-f]*\)".*/\1/' \
    || echo ""
}
phc_python() {
  python3 - "$PHC_ROOT/scripts" "$1" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import plan_hash_util as u
print(u.recorded_plan_hash(Path(sys.argv[2])) or "")
PY
}

phc_assert_parity() {
  f="$PHC_FIX/$1"; label=$2
  s=$(phc_shell "$f"); p=$(phc_python "$f")
  if [ "$s" = "$p" ]; then
    printf '[PASS] %s — shell≡python (%s)\n' "$label" "${p:-<empty>}"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s — shell=%s python=%s (parity 破れ)\n' "$label" "$s" "$p"
    fail=$((fail + 1))
  fi
}

phc_assert_strict_divergence() {
  f="$PHC_FIX/$1"; label=$2
  s=$(phc_shell "$f"); p=$(phc_python "$f")
  # python は不正 JSON を None(空) に、shell は寛容抽出（非空）→ 差異が仕様
  if [ -z "$p" ] && [ -n "$s" ]; then
    printf '[PASS] %s — python strict 拒否(空) / shell 寛容(%s) = 意図的安全側\n' "$label" "$s"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s — 期待: python 空 & shell 非空。実際 shell=%s python=%s\n' "$label" "$s" "$p"
    fail=$((fail + 1))
  fi
}

phc_assert_parity valid.json    "正常 c3.json"
phc_assert_parity injected.json "偽プロパティ注入"
phc_assert_parity no-hash.json  "plan_hash 無"
phc_assert_strict_divergence malformed-trailing-comma.json "不正JSON(末尾カンマ)"
