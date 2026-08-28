# tests/extras/ta-78-settings-wiring-eh13.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# scripts/check-settings-wiring.sh の checks 表・severity レーン・strict モードの
# 回帰テスト（#1259 R6 / F3-1）。
#
# 背景（実測）: #1259 が本検査器に足した EH-13 の 3 エントリ・`tool()` の厳密
# matcher 判定・WARN レーン・`PLANGATE_STRICT_WIRING` を撃つテストが repo 内に
# 1 本も無かった。本検査器に触れる既存 extras は ta-59 だけだが、それは
# `apply-claude-settings.sh` のマージ結果を確かめるために本検査器を **道具として
# rc で使う** もので、checks 表の内容も `tool()` の厳密判定も検証していない。
# その結果、EH-13 の 3 エントリ・`tool()`・WARN レーン・strict を丸ごと削っても
# CI（`--target example`）は PASS を出し続けた。
#
# 検査方式: **変異注入**。settings を mktemp サンドボックスへ複製し、1 か所ずつ
# 壊して「本検査器が期待どおり FAIL / WARN / PASS を返すか」を確かめる。
# 無変更で PASS することだけを見る（＝空振りしうる）テストにしない。
#
#   TC-01: 無変更 → example / user / user+strict すべて PASS(rc=0)・WARN 0 件
#   TC-02: EH-13 の `Bash` ブロック削除 → example FAIL(1) / user WARN(0) / strict FAIL(1)
#   TC-03: EH-13 の `Edit|Write` ブロック削除 → 同上
#   TC-04: `Edit|Write` → `Edit` へ縮小 → 同上（`tool()` の厳密判定が撃つ穴）
#   TC-05: EH-13 を `matcher:"*"` へ集約 → 3 レーンとも PASS（全ツール発火の同一視）
#          ※ この PASS は **wiring 検査としての PASS** であり、`*` 配線が安全である
#            ことを意味しない（TC-05 直前の「反証」コメントを必ず読むこと）
#   TC-06: 既存 6 check（EH-1/2/6/3/EH-3 引数/EH-9）を 1 つずつ削除 → すべて example FAIL(1)
#   TC-07: WARN 経路が **その label を名指しで** 出す（rc=0 の握り潰しでない）
#   TC-08: 検出力の帰属 — 検査器から EH-13 の checks 表 **と** REQUIRED_CHECK_IDS を
#          両方削ると TC-02 の変異が example で PASS になる。TC-02〜04 の FAIL が
#          EH-13 checks に由来することの実証（＝本 TA が空振りでないこと）
#   TC-09: 片側編集（checks 表だけ削る）は検査器の自己健全性チェックが FAIL にする
#
# vacuous PASS 対策: 各変異は「適用後にファイルが実際に変化したこと」を
# `_t78_mutate` が非 0 で落として保証する（no-op 変異での見かけ上の緑を排除）。
#
# 隔離（tests/extras/README.md §隔離・後始末の規約）:
#   `.claude/settings*.json` は self-mod ガード対象（HO）のため **一切書かない**。
#   mktemp サンドボックスへ scripts/ と .claude/ を複製し、検査器の ROOT 解決
#   （scripts/ → ..）がサンドボックスを指す性質を使う。trap は張らず
#   register_cleanup + 末尾の明示 rm -rf の二重で回収する。
#   sandbox の `settings.json`（user レーン）は開発者の実 untracked ファイルに
#   依存しないよう **settings.example.json の複製** を種にする（決定論）。

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-78-settings-wiring-eh13 standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi
# 呼び出し元 env が strict を立てていると全レーンの期待値が変わるため必ず落とす
unset PLANGATE_STRICT_WIRING 2>/dev/null || true

printf '\n=== TA-78: check-settings-wiring EH-13 checks / severity lanes (#1259) ===\n'

t78_pass() {
  pass=$((pass + 1))
  printf '  [PASS] %s\n' "$1"
}
t78_fail() {
  fail=$((fail + 1))
  printf '  [FAIL] %s\n' "$1" >&2
}

_T78_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T78_WIRING="$_T78_ROOT/scripts/check-settings-wiring.sh"
_T78_EXAMPLE="$_T78_ROOT/.claude/settings.example.json"
_T78_SBXS=""

# 変異注入器。ファイルを $2 の指定どおり壊し、**変化しなければ非 0** で落ちる。
_t78_mutate() {
  python3 - "$1" "$2" <<'PY'
import json, sys
path, op = sys.argv[1], sys.argv[2]
EH13 = "check-approval-token-write.sh"
DROP = dict(
    [("drop-EH-1", "check-plan-exists.sh"),
     ("drop-EH-2", "check-c3-approval.sh"),
     ("drop-EH-6", "check-forbidden-files.sh"),
     ("drop-EH-3", "check-plan-hash.sh"),
     ("drop-EH-9", "check-delegation-commit-boundary.sh")])
with open(path) as fh:
    doc = json.load(fh)
before = json.dumps(doc, sort_keys=True)
pre = doc.get("hooks", dict()).get("PreToolUse", [])


def cmds(blk):
    return [h.get("command", "") for h in (blk.get("hooks") or [])
            if isinstance(h, dict)]


def has(blk, tok):
    return any(tok in c for c in cmds(blk))


def tools(blk):
    return [t.strip() for t in (blk.get("matcher") or "").split("|")]


if op == "eh13-drop-bash":
    pre[:] = [b for b in pre if not (has(b, EH13) and "Bash" in tools(b))]
elif op == "eh13-drop-editwrite":
    pre[:] = [b for b in pre
              if not (has(b, EH13) and ("Edit" in tools(b) or "Write" in tools(b)))]
elif op == "eh13-narrow-edit":
    for b in pre:
        if has(b, EH13) and "Write" in tools(b):
            b["matcher"] = "Edit"
elif op == "eh13-collapse-star":
    kept = [b for b in pre if has(b, EH13)]
    pre[:] = [b for b in pre if not has(b, EH13)]
    if kept:
        pre.append(dict(matcher="*", hooks=kept[0]["hooks"]))
elif op == "drop-EH-3-FILE-ARG":
    for b in pre:
        for h in (b.get("hooks") or []):
            if isinstance(h, dict) and "check-plan-hash.sh" in h.get("command", ""):
                h["command"] = h["command"].replace(" ${PLANGATE_HOOK_FILE:-}", "")
elif op in DROP:
    pre[:] = [b for b in pre if not has(b, DROP[op])]
else:
    print("unknown mutation: " + op, file=sys.stderr)
    sys.exit(2)

if json.dumps(doc, sort_keys=True) == before:
    print("mutation was a no-op: " + op + " on " + path, file=sys.stderr)
    sys.exit(3)
with open(path, "w") as fh:
    json.dump(doc, fh, indent=2, ensure_ascii=False)
PY
}

# サンドボックス生成。$1 = 変異名（空なら無変更）。生成失敗時は非 0。
_t78_mksbx() {
  _t78_sbx=$(mktemp -d) || return 1
  register_cleanup "$_t78_sbx"
  _T78_SBXS="$_T78_SBXS $_t78_sbx"
  mkdir -p "$_t78_sbx/scripts" "$_t78_sbx/.claude" || return 1
  cp "$_T78_WIRING" "$_t78_sbx/scripts/check-settings-wiring.sh" || return 1
  cp "$_T78_EXAMPLE" "$_t78_sbx/.claude/settings.example.json" || return 1
  cp "$_T78_EXAMPLE" "$_t78_sbx/.claude/settings.json" || return 1
  if [ -n "$1" ]; then
    _t78_mutate "$_t78_sbx/.claude/settings.example.json" "$1" >&2 || return 1
    _t78_mutate "$_t78_sbx/.claude/settings.json" "$1" >&2 || return 1
  fi
  return 0
}

# 実行器。$1=sbx $2=target $3=strict(0|1)。_t78_rc / _t78_out を設定する。
_t78_run() {
  _t78_rc=0
  if [ "$3" = "1" ]; then
    _t78_out=$(PLANGATE_STRICT_WIRING=1 sh "$1/scripts/check-settings-wiring.sh" \
      --target "$2" 2>&1) || _t78_rc=$?
  else
    _t78_out=$(sh "$1/scripts/check-settings-wiring.sh" --target "$2" 2>&1) || _t78_rc=$?
  fi
}

# EH-13 変異 1 件を 3 レーンで撃つ共通アサーション。$1=変異名 $2=TC ラベル
_t78_assert_eh13() {
  _t78_mut="$1"
  _t78_label="$2"
  if ! _t78_mksbx "$_t78_mut"; then
    t78_fail "$_t78_label サンドボックス生成/変異注入に失敗（変異が no-op の可能性）"
    return 0
  fi
  _t78_s="$_t78_sbx"
  _t78_run "$_t78_s" example 0
  _t78_rc_e=$_t78_rc
  _t78_out_e=$_t78_out
  _t78_run "$_t78_s" user 0
  _t78_rc_u=$_t78_rc
  _t78_out_u=$_t78_out
  _t78_run "$_t78_s" user 1
  _t78_rc_s=$_t78_rc
  _t78_out_s=$_t78_out
  if [ "$_t78_rc_e" -eq 1 ] \
    && printf '%s' "$_t78_out_e" | grep -q 'EH-13 approval-token-write' \
    && [ "$_t78_rc_u" -eq 0 ] \
    && printf '%s' "$_t78_out_u" | grep -q 'WARN: 不足: EH-13 approval-token-write' \
    && [ "$_t78_rc_s" -eq 1 ] \
    && printf '%s' "$_t78_out_s" | grep -q 'strict'; then
    t78_pass "${_t78_label}（example FAIL(1) / user WARN(0) / user+strict FAIL(1)）"
  else
    t78_fail "$_t78_label 期待レーン不一致 (example rc=$_t78_rc_e / user rc=$_t78_rc_u / strict rc=$_t78_rc_s) example=[$_t78_out_e] user=[$_t78_out_u] strict=[$_t78_out_s]"
  fi
}

if [ ! -f "$_T78_WIRING" ] || [ ! -f "$_T78_EXAMPLE" ]; then
  t78_fail "TA-78 前提ファイル不在（check-settings-wiring.sh / settings.example.json）"
else

# === TC-01: 無変更 → 3 レーンとも PASS・WARN 0 件 ===
if _t78_mksbx ""; then
  _t78_s1="$_t78_sbx"
  _t78_run "$_t78_s1" example 0
  _t78_rc_e=$_t78_rc
  _t78_out_e=$_t78_out
  _t78_run "$_t78_s1" user 0
  _t78_rc_u=$_t78_rc
  _t78_out_u=$_t78_out
  _t78_run "$_t78_s1" user 1
  _t78_rc_s=$_t78_rc
  _t78_out_s=$_t78_out
  if [ "$_t78_rc_e" -eq 0 ] && [ "$_t78_rc_u" -eq 0 ] && [ "$_t78_rc_s" -eq 0 ] \
    && ! printf '%s%s%s' "$_t78_out_e" "$_t78_out_u" "$_t78_out_s" | grep -q 'WARN'; then
    t78_pass "TC-01 無変更の settings は example / user / user+strict すべて PASS(0)・WARN 0 件"
  else
    t78_fail "TC-01 baseline が PASS でない (example=$_t78_rc_e user=$_t78_rc_u strict=$_t78_rc_s): $_t78_out_e | $_t78_out_u | $_t78_out_s"
  fi
else
  t78_fail "TC-01 サンドボックス生成に失敗"
fi

# === TC-02〜04: EH-13 の 3 変異 ===
_t78_assert_eh13 eh13-drop-bash      "TC-02 EH-13 の Bash ブロック削除を検出"
_t78_assert_eh13 eh13-drop-editwrite "TC-03 EH-13 の Edit|Write ブロック削除を検出"
_t78_assert_eh13 eh13-narrow-edit    "TC-04 EH-13 の Edit|Write → Edit 縮小を検出（tool() 厳密判定）"

# === TC-05: matcher:"*" への集約は 3 レーンとも PASS（全ツール発火の同一視）===
#
# 【反証 — この PASS を「`*` 配線でよい」と読んではならない】
# 本 TC が固定しているのは検査器の**配線判定**（`*` は全ツールに発火するので
# Edit / Write / Bash を包含する）だけであり、**runtime の挙動は逆向き**である。
#
# 実測（2026-08-28 / origin/main = 3f0cadd。payload はファイル経由で hook に流し rc を採取）:
#   scripts/check-approval-token-write.sh（EH-13）
#     Read / Glob / Grep / WebFetch / Task / NotebookEdit → **すべて rc=2**
#     （`[EH-13 token-guard] BLOCK (parse-unknown)`。未知 tool_name を
#       `_parse_unknown` → exit 2 にする **唯一の hook**）
#   対照 5 hook（check-plan-exists / check-c3-approval / check-forbidden-files /
#     check-delegation-commit-boundary / check-plan-hash）
#     同じ 6 payload → **すべて rc=0**
#
# したがって EH-13 を `matcher:"*"` で配線した settings は **Read すら通らない**
# （#1267 と同型の全停止クラス）。本検査器の `has()` はそれを「準拠」と判定し、
# 本 TC がその判定を正しい挙動として固定している——という構造が現に存在する。
#
# 本 PR で検査器側を EH-13 だけ厳密判定へ倒さなかった理由:
# apply-claude-settings.sh 側の包含判定（`*` = 全ツール集合）とずれ、apply が
# 「配線済み」と見なしたものを本検査が「不足」と言い続ける **非収束**（#928 MJ-1）
# を EH-13 に対して再導入するため。是正の本筋は EH-13 hook 本体が未知 tool_name を
# allow することであり、それは本 PR の scope 外（別 PBI で対応中）。
if _t78_mksbx eh13-collapse-star; then
  _t78_s5="$_t78_sbx"
  _t78_run "$_t78_s5" example 0
  _t78_rc_e=$_t78_rc
  _t78_out_e=$_t78_out
  _t78_run "$_t78_s5" user 0
  _t78_rc_u=$_t78_rc
  _t78_run "$_t78_s5" user 1
  _t78_rc_s=$_t78_rc
  _t78_out_s=$_t78_out
  if [ "$_t78_rc_e" -eq 0 ] && [ "$_t78_rc_u" -eq 0 ] && [ "$_t78_rc_s" -eq 0 ] \
    && ! printf '%s%s' "$_t78_out_e" "$_t78_out_s" | grep -q 'WARN'; then
    t78_pass "TC-05 EH-13 を matcher:\"*\" に集約しても 3 レーンとも PASS（* は全ツール発火）"
  else
    t78_fail "TC-05 matcher:\"*\" 集約が誤検出された (example=$_t78_rc_e user=$_t78_rc_u strict=$_t78_rc_s): $_t78_out_e"
  fi
else
  t78_fail "TC-05 サンドボックス生成/変異注入に失敗"
fi

# === TC-06: 既存 6 check を 1 つずつ削除 → すべて example FAIL(1) ===
_t78_bad=""
for _t78_op in drop-EH-1 drop-EH-2 drop-EH-6 drop-EH-3 drop-EH-3-FILE-ARG drop-EH-9; do
  if ! _t78_mksbx "$_t78_op"; then
    _t78_bad="$_t78_bad $_t78_op(sbx)"
    continue
  fi
  _t78_run "$_t78_sbx" example 0
  [ "$_t78_rc" -eq 1 ] || _t78_bad="$_t78_bad $_t78_op(rc=$_t78_rc)"
done
if [ -z "$_t78_bad" ]; then
  t78_pass "TC-06 既存 6 check（EH-1/2/6/3/EH-3 引数/EH-9）の個別削除をすべて example FAIL(1) で検出"
else
  t78_fail "TC-06 既存 check の削除を検出できない:$_t78_bad"
fi

# === TC-07: WARN 経路が label を名指しし、昇格手段まで案内する ===
if _t78_mksbx eh13-drop-bash; then
  _t78_run "$_t78_sbx" user 0
  if [ "$_t78_rc" -eq 0 ] \
    && printf '%s' "$_t78_out" | grep -q 'WARN: 不足: EH-13 approval-token-write (matcher: Bash)' \
    && printf '%s' "$_t78_out" | grep -q 'PLANGATE_STRICT_WIRING=1' \
    && printf '%s' "$_t78_out" | grep -q '※WARN 1 件'; then
    t78_pass "TC-07 user レーンの WARN は label を名指しし、strict への昇格手段と件数を出す"
  else
    t78_fail "TC-07 WARN 出力が不十分 (rc=$_t78_rc): $_t78_out"
  fi
else
  t78_fail "TC-07 サンドボックス生成/変異注入に失敗"
fi

# === TC-08: 検出力の帰属（本 TA が空振りでないことの実証）===
# 検査器から EH-13 の checks 表と REQUIRED_CHECK_IDS を **両方** 削ると、
# TC-02 の変異（EH-13 Bash 欠落）が example で PASS になる。
# TC-02〜04 の FAIL が EH-13 checks に由来することの直接証明。
if _t78_mksbx eh13-drop-bash; then
  _t78_s8="$_t78_sbx"
  if python3 - "$_t78_s8/scripts/check-settings-wiring.sh" both <<'PY'
import re
import sys
path, mode = sys.argv[1], sys.argv[2]
src = open(path).read()
new = re.sub(r'\n    \("EH-13-[A-Z]+",.*?TRACKED_FAIL\),', '', src, flags=re.S)
if new == src:
    print("checks 表の EH-13 エントリを除去できなかった", file=sys.stderr)
    sys.exit(3)
if mode == "both":
    n2 = new.replace('    "EH-13-EDIT", "EH-13-WRITE", "EH-13-BASH",\n', '')
    if n2 == new:
        print("REQUIRED_CHECK_IDS の EH-13 行を除去できなかった", file=sys.stderr)
        sys.exit(3)
    new = n2
open(path, "w").write(new)
PY
  then
    _t78_run "$_t78_s8" example 0
    if [ "$_t78_rc" -eq 0 ]; then
      t78_pass "TC-08 検査器から EH-13 checks を抜くと TC-02 の変異が PASS になる（TC-02〜04 の FAIL は EH-13 checks 由来）"
    else
      t78_fail "TC-08 EH-13 checks を抜いても FAIL のまま (rc=$_t78_rc) — TC-02〜04 の FAIL が別要因の可能性: $_t78_out"
    fi
  else
    t78_fail "TC-08 検査器の変異注入に失敗（checks 表 / REQUIRED_CHECK_IDS の形が変わった可能性）"
  fi
else
  t78_fail "TC-08 サンドボックス生成/変異注入に失敗"
fi

# === TC-09: 片側編集（checks 表だけ削る）は自己健全性チェックが FAIL にする ===
if _t78_mksbx ""; then
  _t78_s9="$_t78_sbx"
  if python3 - "$_t78_s9/scripts/check-settings-wiring.sh" <<'PY'
import re
import sys
path = sys.argv[1]
src = open(path).read()
new = re.sub(r'\n    \("EH-13-[A-Z]+",.*?TRACKED_FAIL\),', '', src, flags=re.S)
if new == src:
    print("checks 表の EH-13 エントリを除去できなかった", file=sys.stderr)
    sys.exit(3)
open(path, "w").write(new)
PY
  then
    _t78_run "$_t78_s9" example 0
    if [ "$_t78_rc" -eq 1 ] \
      && printf '%s' "$_t78_out" | grep -q '検査器の自己健全性 NG' \
      && printf '%s' "$_t78_out" | grep -q 'EH-13-BASH'; then
      t78_pass "TC-09 checks 表だけを削る片側編集は自己健全性チェックが FAIL にする"
    else
      t78_fail "TC-09 片側編集を自己健全性チェックが捕捉しない (rc=$_t78_rc): $_t78_out"
    fi
  else
    t78_fail "TC-09 検査器の変異注入に失敗"
  fi
else
  t78_fail "TC-09 サンドボックス生成に失敗"
fi

# === TC-10: サンドボックス後片付け（明示 rm -rf の実効確認）===
# shellcheck disable=SC2086
rm -rf $_T78_SBXS
_t78_left=0
for _t78_d in $_T78_SBXS; do
  if [ -d "$_t78_d" ]; then
    _t78_left=$((_t78_left + 1))
  fi
done
if [ "$_t78_left" -eq 0 ]; then
  t78_pass "TC-10 サンドボックスを明示削除（実 .claude/ には一切書き込まない）"
else
  t78_fail "TC-10 サンドボックスが $_t78_left 件残存"
fi

fi

# 後始末は register_cleanup 済み（README 規約 3）。最終行は finalize 単独とし、
# 直前に他コマンドを挟まない（README 実行契約 checklist 3）。
pg_extra_contract_finalize
