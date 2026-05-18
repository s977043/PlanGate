# tests/extras/ta-11-plan-hash-contract.sh
# Sourced by tests/run-tests.sh — relies on $pass / $fail / $FIXTURES_DIR
# TASK-0100 (#193 follow-up) / TASK-0105 (#282): scripts/plan_hash_util.py
# （Python 共有正本）と EH-3 shell（scripts/hooks/check-plan-hash.sh の
# **strict JSON 抽出**）の plan_hash 抽出契約を fixture で固定する。
#
# 契約（#282 後・全 parity）:
#   - 正常 / 偽プロパティ注入 / plan_hash 無 / 不正 JSON（末尾カンマ等）:
#     すべて shell ≡ python（parity 必須）。#282 で check-plan-hash.sh を
#     寛容 sed から strict JSON へ変更したため、不正 c3.json は shell も
#     python も空（承認記録として信用しない安全側）で一致する。

printf '\n=== TA-11: plan_hash util ↔ EH-3 shell 契約 ===\n'

PHC_FIX="$FIXTURES_DIR/plan-hash-contract"
# repo root = tests/fixtures の 2 つ上（run-tests.sh が $FIXTURES_DIR を渡す）
PHC_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"

phc_shell() {
  # #282 後: check-plan-hash.sh と同一の strict JSON 抽出を検証（旧 sed
  # レプリカは廃止。実フックの抽出契約と一致させる）
  python3 - "$1" <<'PHX' 2>/dev/null || echo ""
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(""); raise SystemExit(0)
if not isinstance(d, dict):
    print(""); raise SystemExit(0)
v = d.get("plan_hash", "")
print(v[7:] if isinstance(v, str) and v.startswith("sha256:") else "")
PHX
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


phc_assert_parity valid.json    "正常 c3.json"
phc_assert_parity injected.json "偽プロパティ注入"
phc_assert_parity no-hash.json  "plan_hash 無"
phc_assert_parity malformed-trailing-comma.json "不正JSON(末尾カンマ・#282後 strict parity)"
