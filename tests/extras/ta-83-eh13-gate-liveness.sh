# tests/extras/ta-83-eh13-gate-liveness.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# EH-13（承認トークン書き込みガード / scripts/check-approval-token-write.sh）の
# **配線を守っているゲートが、実際に起動されるか**を撃つ（#1259）。
#
# ── なぜ既存の ta-25 / ta-78 では足りないか（実測 / origin/main = d805aba0）──
#
# #1259 が報告した「tracked 配線を全削除しても全ゲートが緑」は **既に是正済み**で、
# 本 TA 作成時点の実測では次のとおり赤くなる:
#
#   | 変異（tracked `.claude/settings.example.json` 側）| check-settings-wiring rc |
#   |---|---|
#   | 無変更 | 0 |
#   | EH-13 の 2 ブロックを全削除 | **1** |
#   | 同上 + untracked `.claude/settings.json` に同じ参照を置く | **1** |
#
# 残っているのは **1 階層上の穴** で、これは repo 内のどのテストも撃っていない:
#
#   1. **ゲートの起動側**。`check-settings-wiring.sh` を実行するのは
#      `.github/workflows/ci.yml` の 1 ステップだけ、extras 一式を実行するのは
#      `test.yml` の `sh tests/run-tests.sh` だけである。この **step を消しても
#      何も赤くならない**（実測: `git grep -l 'check-settings-wiring' tests/` は
#      ta-59 / ta-78 のみで、いずれも検査器を *道具として* 使うだけで
#      「CI がそれを起動しているか」は見ていない）。
#   2. **テストの存在側**。`tests/run-tests.sh` は `"$EXTRAS_DIR"/ta-*.sh` を
#      **glob で発見**する。ta-25 / ta-78 を削除しても glob が 2 つ少なく回るだけで、
#      スイートは緑のままになる（ta-61 の migration allowlist は「移行待ち」
#      一覧であって存在ピンではない）。
#
# ── 設計上の禁止事項（ta-82 の教訓）──────────────────────────────
# ta-82 では「配線文字列が在るか」の**字面ピン**が、no-op 再定義・ラベル分岐の
# 早期 return・変数の付け替えをすべて素通りした。したがって本 TA は
# **字面 grep を陽性 assert の主軸にしない**:
#
#   - CI 起動の判定は YAML を **parse** し、`jobs.<job>.steps[].run` の
#     文字列だけを母集団にする。コメント化された run・`runx:` のような
#     未知キー配下・job の外の散文は母集団に入らない（TC-02b/02c で実証）。
#   - extras 存在の判定は **runner 自身の glob** で発見された集合に対して行う。
#     ディスクに在るだけでファイル名が glob 外（`tb-…`）なら数えない（TC-04b）。
#   - 変異は「関数」ではなく **call site**（配線エントリ / step / ファイル名）を壊す。
#
# ── TC 一覧 ──────────────────────────────────────────────
#   TC-01  CI 起動 liveness: workflows を YAML parse し、`check-settings-wiring.sh`
#          を起動する run step ≥1 と `tests/run-tests.sh` を起動する run step ≥1
#   TC-02a 陽性: wiring step を **コメント化** した合成 workflow → 0 件（grep なら通る）
#   TC-02b 陽性: `run:` → `runx:` へ **キー名だけ** 変えた合成 workflow → 0 件
#   TC-02c 陽性: run-tests step を削除した合成 workflow → 0 件
#   TC-02d 陽性: step の `if:` / `continue-on-error:` による無効化 → 0 件
#   TC-02e 陽性: job 単位の `if:` による無効化 → 0 件
#
# 受理する起動形の限定（レビュー指摘 minor）:
#   本 TA が「起動されている」と数えるのは **`jobs.<job>.steps[].run` への直接記述**
#   だけ。composite action（`uses: ./.github/actions/...`）/ reusable workflow
#   （`jobs.<job>.uses:`）/ 集約スクリプト経由（`run: make ci-settings`）へ移す変更は、
#   **正しいリファクタでも本 TA を赤くする**。その場合は述語を更新すること
#   （誤爆を放置して「検査が壊れている」状態にしない）。
#   現 main では composite / reusable とも 0 件（`.github/actions` 不在を実測）。
#
# PyYAML 依存について:
#   他の extras（ta-64 / ta-45 / ta-71 / ta-74）は README 規約 6 に従い PyYAML 不在で
#   SKIP するが、本 TA は **fail-closed を選ぶ**（liveness ゲートを黙って飛ばすと
#   「検査が走っていない」ことを検査できなくなるため）。TC-01 の FAIL には
#   「PyYAML 不在 / 構文破損」と明記してあり、前提未充足と実際の退行を読み分けられる。
#   TC-03  extras 発見 liveness: runner の glob で発見された extras のうち
#          EH-13 ガード本体を参照するものが ≥1（＝配線退行を撃つテストが実在する）
#   TC-04a 陽性: それらを削除した合成 extras ディレクトリ → 0 件
#   TC-04b 陽性: glob 外の名前（`tb-…`）へ改名しただけ → 0 件（ディスク存在では足りない）
#   TC-05  陰性コントロール: 無変異の settings で検査器 rc=0
#   TC-06  tracked 配線の EH-13 全削除 → rc=1
#   TC-07  同上 + untracked `.claude/settings.json` に正しい参照（#1259 の再現手順）→ rc=1
#   TC-08  EH-13 を未知 event キー（`PreToolUseX`）配下へ退避 → rc=1
#   TC-09  EH-13 を散文フィールド（`_comment_`）へ退避 → rc=1
#   TC-10  逆方向: untracked `.claude/settings.local.json` の複製参照は
#          `--target example` の判定を動かさない（rc=0）
#   TC-11  **検査器の盲点の実測固定**: 相対パス化 / `scripts/hooks/` 複製への
#          付け替えは検査器では rc=0（＝ CI の当該 step では捕まらない）。
#          この 2 クラスを撃っているのは ta-25 T1071-TC-04a/e/f の構造 scan であり、
#          本 TC はその責務分界を「主張」ではなく **実測** として固定する。
#   TC-12  サンドボックス明示削除
#
# 絶対件数は契約値にしない（workflow も extras も運用で増える）。TC-01 / TC-03 は
# いずれも `>= 1`、陽性コントロールは `= 0` のみを要求する。
#
# ── 残存脅威モデル（完全性は主張しない）──────────────────────────
# **守るもの**（本 TA の変異注入で kill を実証済み。値は実測 / origin/main = d805aba0）:
#   - `.github/workflows/**` から wiring ゲートの起動が消える（削除 / コメント化）→ TC-01 赤
#   - `.github/workflows/**` から extras 一式の起動が消える → TC-01 赤
#   - EH-13 配線退行を撃つ extras がすべて消える / glob 外へ改名される → TC-03 赤
#   - tracked 配線から EH-13 が消える（untracked による救済を含む）→ TC-05〜09 赤
#
# **守らないもの**（他層に委ねる / 未検証）:
#   - **loaded**（harness が実際にその hook をロード・発火させたか）。本 TA が見るのは
#     「CI がゲートを起動する構成になっているか」までで、GitHub 上で job が実際に
#     required check として実行されるか（branch protection）は **見ていない**。
#     そこは repo 設定であり Human-owned。
#   - 発見された extras が **有効かどうか**。TC-03 は「実行集合に居るか」しか見ない。
#     テストの検出力そのものは各テストの自己帰属 TC（ta-78 TC-08 / ta-25 の
#     T1071-TC-04b〜h）が担う。両方が同時に骨抜きにされる経路は塞いでいない。
#   - `.codex/hooks.json` / `.cursor/hooks.json` / `.codex/hooks/eh-bridge.sh` 側の
#     EH-13 配線（実測: **いずれも 0 件**）。Codex / Cursor セッションに EH-13 が
#     配線されていないこと自体は本 TA の射程外（別 issue）。
#   - EH-13 hook 本体のロジック（#1243）と Bash レーンの matcher 配線（#1104）。
#   - 検査器が通してしまう 2 クラス（相対パス化 / `scripts/hooks/` 付け替え）。
#     これは ta-25 T1071-TC-04e/f の構造 scan が担う多層防御の別レイヤであり、
#     本 TA は TC-11 でその **責務分界を実測として固定する**だけである。
#
# 隔離（tests/extras/README.md §隔離・後始末の規約）:
#   `.claude/settings*.json` / `.github/workflows/**` は Hardening Override 対象の
#   ため **一切書かない**。すべて mktemp サンドボックスへ複製して変異させ、
#   trap は張らず register_cleanup + 末尾の明示 rm -rf の二重で回収する。

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
pg_extra_contract_init ta-83-eh13-gate-liveness standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi
# 呼び出し元 env が strict を立てていると検査器レーンの期待値が変わるため必ず落とす
unset PLANGATE_STRICT_WIRING 2>/dev/null || true

printf '\n=== TA-83: EH-13 gate liveness — is the guard-of-the-guard actually invoked? (#1259) ===\n'

t83_pass() {
  pass=$((pass + 1))
  printf '  [PASS] %s\n' "$1"
}
t83_fail() {
  fail=$((fail + 1))
  printf '  [FAIL] %s\n' "$1" >&2
}

_T83_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T83_WF="$_T83_ROOT/.github/workflows"
_T83_RUNNER="$_T83_ROOT/tests/run-tests.sh"
_T83_WIRING="$_T83_ROOT/scripts/check-settings-wiring.sh"
_T83_EXAMPLE="$_T83_ROOT/.claude/settings.example.json"
_T83_GUARD_BASE="check-approval-token-write.sh"
# runner の extras 発見 glob。TC-03 はこの glob 経由でしか extras を数えない。
_T83_GLOB='ta-*.sh'
_T83_SBXS=""

# ---------------------------------------------------------------------------
# 述語 1: workflows ディレクトリを YAML parse し
#         "<wiring-step 数> <run-tests-step 数>" を echo する。
#         母集団は jobs.<job>.steps[].run の **文字列だけ**。
#         PyYAML 不在 / parse 不能は **fail-closed**（何も echo せず非 0）。
_t83_ci_runs() {
  python3 - "$1" <<'T83_CI'
import glob
import os
import sys

try:
    import yaml
except ImportError:
    sys.exit(4)

root = sys.argv[1]
paths = sorted(glob.glob(os.path.join(root, "*.yml"))
               + glob.glob(os.path.join(root, "*.yaml")))
runs = []
for path in paths:
    try:
        with open(path, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh)
    except Exception:
        sys.exit(3)
    if not isinstance(doc, dict):
        continue
    jobs = doc.get("jobs")
    if not isinstance(jobs, dict):
        continue
    for job in jobs.values():
        if not isinstance(job, dict):
            continue
        # job 単位で無効化されていれば、その中の step は 1 度も走らない。
        # 「step は在るが起動されない」クラスを通さない（レビュー指摘 major）。
        if job.get("if") is not None:
            continue
        steps = job.get("steps")
        if not isinstance(steps, list):
            continue
        for step in steps:
            if not (isinstance(step, dict) and isinstance(step.get("run"), str)):
                continue
            # step の `if:` は条件次第で走らない。`continue-on-error: true` は
            # 失敗しても job を落とさない = ゲートとして機能しない。
            if step.get("if") is not None:
                continue
            if step.get("continue-on-error") is True:
                continue
            runs.append(step["run"])

wiring = sum(1 for r in runs if "check-settings-wiring.sh" in r)
suite = sum(1 for r in runs if "tests/run-tests.sh" in r)
print("%d %d" % (wiring, suite))
T83_CI
}

# 述語 2: runner の glob で発見された extras のうち EH-13 ガード本体を
#         参照するものの件数を echo する。ディスク存在ではなく **発見集合**。
#
# 自己除外（必須）: 本ファイル自身も `check-approval-token-write.sh` を含むため、
# 素朴に数えると **他をすべて削除しても自分 1 件で TC-03 が緑のまま**になる
# （ta-61 で実害化した自己マッチと同型）。除外はファイル名の直書きではなく
# 下のマーカー行で行う（改名しても効き続ける）。
_T83_SELF_MARKER='PG_T83_SELF_EXCLUDE_MARKER'
_t83_extras_eh13() {
  _t83_ee_dir="$1"
  _t83_ee_n=0
  for _t83_ee_f in "$_t83_ee_dir"/$_T83_GLOB; do
    [ -f "$_t83_ee_f" ] || continue
    grep -q "$_T83_SELF_MARKER" "$_t83_ee_f" 2>/dev/null && continue
    if grep -q "$_T83_GUARD_BASE" "$_t83_ee_f" 2>/dev/null; then
      _t83_ee_n=$((_t83_ee_n + 1))
    fi
  done
  printf '%s' "$_t83_ee_n"
}
# 自己除外マーカーの実体（この行自身が検出される）: PG_T83_SELF_EXCLUDE_MARKER

# 変異注入器（settings）。変化しなければ非 0 で落ちる（no-op 変異の握り潰し防止）。
_t83_mutate() {
  python3 - "$1" "$2" <<'T83_MUT'
import json
import os
import sys

path, op = sys.argv[1], sys.argv[2]
TOK = "check-approval-token-write.sh"
claude = os.path.dirname(path)

with open(path, encoding="utf-8") as fh:
    doc = json.load(fh)
before = json.dumps(doc, sort_keys=True)
pre = doc.get("hooks", {}).get("PreToolUse", [])


def has(blk):
    return any(TOK in h.get("command", "")
               for h in (blk.get("hooks") or []) if isinstance(h, dict))


def write_env(name, command):
    with open(os.path.join(claude, name), "w", encoding="utf-8") as fh:
        json.dump({"hooks": {"PreToolUse": [
            {"matcher": "Edit|Write",
             "hooks": [{"type": "command", "command": command}]}]}},
            fh, indent=2, ensure_ascii=False)


if op == "drop-all":
    pre[:] = [b for b in pre if not has(b)]
elif op == "drop-all-plus-untracked-rescue":
    pre[:] = [b for b in pre if not has(b)]
    write_env("settings.json",
              "sh ${CLAUDE_PROJECT_DIR}/scripts/" + TOK)
elif op == "unknown-event":
    moved = [b for b in pre if has(b)]
    pre[:] = [b for b in pre if not has(b)]
    doc["hooks"]["PreToolUseX"] = moved
elif op == "prose-only":
    pre[:] = [b for b in pre if not has(b)]
    doc["_comment_eh13"] = "wired via ${CLAUDE_PROJECT_DIR}/scripts/" + TOK
elif op == "relativize":
    for b in pre:
        for h in (b.get("hooks") or []):
            if isinstance(h, dict) and TOK in h.get("command", ""):
                h["command"] = "sh scripts/" + TOK
elif op == "repoint-hooks":
    for b in pre:
        for h in (b.get("hooks") or []):
            if isinstance(h, dict) and TOK in h.get("command", ""):
                h["command"] = h["command"].replace(
                    "/scripts/" + TOK, "/scripts/hooks/" + TOK)
elif op == "untracked-noise-only":
    write_env("settings.local.json",
              "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/" + TOK)
else:
    print("unknown mutation: " + op, file=sys.stderr)
    sys.exit(2)

if op != "untracked-noise-only" and json.dumps(doc, sort_keys=True) == before:
    print("mutation was a no-op: " + op, file=sys.stderr)
    sys.exit(3)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=2, ensure_ascii=False)
T83_MUT
}

# settings サンドボックス生成。$1 = 変異名（空なら無変更）。失敗時は非 0。
# 検査器の ROOT 解決（scripts/ → ..）がサンドボックスを指す性質を使う。
_t83_mksbx() {
  _t83_sbx=$(mktemp -d "${TMPDIR:-/tmp}/pg-t83.XXXXXX") || return 1
  register_cleanup "$_t83_sbx"
  _T83_SBXS="$_T83_SBXS $_t83_sbx"
  mkdir -p "$_t83_sbx/scripts" "$_t83_sbx/.claude" || return 1
  cp "$_T83_WIRING" "$_t83_sbx/scripts/check-settings-wiring.sh" || return 1
  cp "$_T83_EXAMPLE" "$_t83_sbx/.claude/settings.example.json" || return 1
  if [ -n "$1" ]; then
    _t83_mutate "$_t83_sbx/.claude/settings.example.json" "$1" >&2 || return 1
  fi
  return 0
}

# 検査器実行。_t83_rc / _t83_out を設定する。
_t83_run() {
  _t83_rc=0
  _t83_out=$(sh "$1/scripts/check-settings-wiring.sh" --target example 2>&1) || _t83_rc=$?
}

# 1 変異 = 1 TC。$1=変異名 $2=期待 rc $3=ラベル
_t83_case() {
  if ! _t83_mksbx "$1"; then
    t83_fail "$3 サンドボックス生成/変異注入に失敗（変異が no-op の可能性）"
    return 0
  fi
  _t83_run "$_t83_sbx"
  if [ "$_t83_rc" -eq "$2" ]; then
    t83_pass "$3 (rc=$_t83_rc)"
  else
    t83_fail "$3 期待 rc=$2 実測 rc=$_t83_rc: $_t83_out"
  fi
}

# ===========================================================================
# TC-01: CI 起動 liveness
# ===========================================================================
if [ ! -d "$_T83_WF" ]; then
  t83_fail "TC-01 .github/workflows/ が無い — CI 起動を検証できない（fail-closed）"
else
  _t83_ci=$(_t83_ci_runs "$_T83_WF") || _t83_ci=""
  if [ -z "$_t83_ci" ]; then
    t83_fail "TC-01 workflows を YAML parse できない（PyYAML 不在 / 構文破損）— fail-closed"
  else
    _t83_wiring_n=${_t83_ci%% *}
    _t83_suite_n=${_t83_ci##* }
    if [ "$_t83_wiring_n" -ge 1 ] && [ "$_t83_suite_n" -ge 1 ]; then
      t83_pass "TC-01 CI が EH-13 配線ゲートを実際に起動している（check-settings-wiring run step=${_t83_wiring_n} / run-tests run step=${_t83_suite_n}、いずれも >=1）"
    else
      t83_fail "TC-01 CI から EH-13 配線ゲートの起動が消えている（check-settings-wiring=${_t83_wiring_n} run-tests=${_t83_suite_n}）— どちらかが 0 なら配線退行が無検出になる"
    fi
  fi
fi

# ===========================================================================
# TC-02a/b/c: TC-01 の陽性コントロール（合成 workflow）
#   grep なら通ってしまう書法を 3 つ用意し、述語が 0 を返すことを実測する。
# ===========================================================================
_t83_mkwf() {
  _t83_wfd=$(mktemp -d "${TMPDIR:-/tmp}/pg-t83-wf.XXXXXX") || return 1
  register_cleanup "$_t83_wfd"
  _T83_SBXS="$_T83_SBXS $_t83_wfd"
  return 0
}

# a: run 行をコメント化（raw grep なら文字列は残っているので通る）
if _t83_mkwf; then
  cat >"$_t83_wfd/ci.yml" <<'T83_WFA'
name: ci
on: [push]
jobs:
  settings:
    runs-on: ubuntu-latest
    steps:
      # - run: sh scripts/check-settings-wiring.sh --target example
      - run: echo noop
  tests:
    runs-on: ubuntu-latest
    steps:
      - run: sh tests/run-tests.sh
T83_WFA
  _t83_ci=$(_t83_ci_runs "$_t83_wfd") || _t83_ci=""
  if [ -n "$_t83_ci" ] && [ "${_t83_ci%% *}" = "0" ] \
    && grep -q 'check-settings-wiring.sh' "$_t83_wfd/ci.yml"; then
    t83_pass "TC-02a コメント化された wiring step は起動として数えない（raw grep なら通る書法）"
  else
    t83_fail "TC-02a コメント化 step を起動と誤認 (predicate=[$_t83_ci])"
  fi
else
  t83_fail "TC-02a サンドボックス生成に失敗"
fi

# b: `run:` → `runx:`（キー名だけ差し替え。文字列も step も残っている）
if _t83_mkwf; then
  cat >"$_t83_wfd/ci.yml" <<'T83_WFB'
name: ci
on: [push]
jobs:
  settings:
    runs-on: ubuntu-latest
    steps:
      - runx: sh scripts/check-settings-wiring.sh --target example
  tests:
    runs-on: ubuntu-latest
    steps:
      - run: sh tests/run-tests.sh
T83_WFB
  _t83_ci=$(_t83_ci_runs "$_t83_wfd") || _t83_ci=""
  if [ -n "$_t83_ci" ] && [ "${_t83_ci%% *}" = "0" ] && [ "${_t83_ci##* }" -ge 1 ]; then
    t83_pass "TC-02b run: → runx: のキー名変更を検出（step も文字列も残っているが起動されない）"
  else
    t83_fail "TC-02b 未知キー配下の step を起動と誤認 (predicate=[$_t83_ci])"
  fi
else
  t83_fail "TC-02b サンドボックス生成に失敗"
fi

# c: run-tests step の削除（extras 一式が CI から外れるクラス）
if _t83_mkwf; then
  cat >"$_t83_wfd/ci.yml" <<'T83_WFC'
name: ci
on: [push]
jobs:
  settings:
    runs-on: ubuntu-latest
    steps:
      - run: sh scripts/check-settings-wiring.sh --target example
T83_WFC
  _t83_ci=$(_t83_ci_runs "$_t83_wfd") || _t83_ci=""
  if [ -n "$_t83_ci" ] && [ "${_t83_ci##* }" = "0" ] && [ "${_t83_ci%% *}" -ge 1 ]; then
    t83_pass "TC-02c run-tests step の削除を検出（extras 一式が CI から外れるクラス）"
  else
    t83_fail "TC-02c run-tests step の欠落を検出できない (predicate=[$_t83_ci])"
  fi
else
  t83_fail "TC-02c サンドボックス生成に失敗"
fi

# d: step / job を **無効化**（step は在るが 1 度も起動されない）
#    レビュー指摘（major）: `if: false` を 1 行足すだけでゲートは走らなくなるのに、
#    `steps[].run` の存在だけを見る述語は緑のまま通していた。
if _t83_mkwf; then
  cat >"$_t83_wfd/ci.yml" <<'T83_WFD'
name: ci
on: [push]
jobs:
  settings:
    runs-on: ubuntu-latest
    steps:
      - if: false
        run: sh scripts/check-settings-wiring.sh --target example
      - run: sh tests/run-tests.sh
        continue-on-error: true
T83_WFD
  _t83_ci=$(_t83_ci_runs "$_t83_wfd") || _t83_ci=""
  if [ "$_t83_ci" = "0 0" ]; then
    t83_pass "TC-02d step の if: / continue-on-error: による無効化を検出（step は在るが起動されない）"
  else
    t83_fail "TC-02d 無効化された step を起動と誤認 (predicate=[$_t83_ci])"
  fi
else
  t83_fail "TC-02d サンドボックス生成に失敗"
fi

# e: job 単位の無効化
if _t83_mkwf; then
  cat >"$_t83_wfd/ci.yml" <<'T83_WFE'
name: ci
on: [push]
jobs:
  settings:
    if: false
    runs-on: ubuntu-latest
    steps:
      - run: sh scripts/check-settings-wiring.sh --target example
      - run: sh tests/run-tests.sh
T83_WFE
  _t83_ci=$(_t83_ci_runs "$_t83_wfd") || _t83_ci=""
  if [ "$_t83_ci" = "0 0" ]; then
    t83_pass "TC-02e job 単位の if: による無効化を検出"
  else
    t83_fail "TC-02e 無効化された job を起動と誤認 (predicate=[$_t83_ci])"
  fi
else
  t83_fail "TC-02e サンドボックス生成に失敗"
fi


# ===========================================================================
# TC-03: extras 発見 liveness
#   まず「本 TA が数える glob が runner の source glob と同一である」ことを
#   確かめる（ta-61 TC-28 と同じ照合）。ここがずれると発見集合 != 実行集合になる。
# ===========================================================================
if [ ! -r "$_T83_RUNNER" ]; then
  t83_fail "TC-03 tests/run-tests.sh を読めない — 発見集合を runner と照合できない（fail-closed）"
elif ! grep -Fq '"$EXTRAS_DIR"/'"$_T83_GLOB" "$_T83_RUNNER"; then
  t83_fail "TC-03 runner の extras source glob が \"\$EXTRAS_DIR\"/$_T83_GLOB でない — 本 TA の発見集合が実行集合と一致しない（$_T83_RUNNER）"
else
  _t83_n=$(_t83_extras_eh13 "$_pg_extra_dir")
  if [ "$_t83_n" -ge 1 ]; then
    t83_pass "TC-03 runner の glob で発見される extras のうち EH-13 ガードを撃つものが $_t83_n 件（>=1）"
  else
    t83_fail "TC-03 EH-13 配線の退行を撃つ extras が発見集合に 1 件も無い — 配線が消えても extras は緑になる"
  fi
fi

# ===========================================================================
# TC-04a/b: TC-03 の陽性コントロール（合成 extras ディレクトリ）
# ===========================================================================
_t83_mkextras() {
  _t83_exd=$(mktemp -d "${TMPDIR:-/tmp}/pg-t83-ex.XXXXXX") || return 1
  register_cleanup "$_t83_exd"
  _T83_SBXS="$_T83_SBXS $_t83_exd"
  printf '# unrelated extra\n' >"$_t83_exd/ta-01-unrelated.sh"
  return 0
}

# a: EH-13 を撃つ extras を 1 本も置かない
if _t83_mkextras; then
  _t83_n=$(_t83_extras_eh13 "$_t83_exd")
  if [ "$_t83_n" = "0" ]; then
    t83_pass "TC-04a EH-13 を撃つ extras を削除した集合では述語が 0 を返す（TC-03 が空振りでない）"
  else
    t83_fail "TC-04a 削除済みの集合で述語が $_t83_n を返した"
  fi
else
  t83_fail "TC-04a サンドボックス生成に失敗"
fi

# b: ディスクには在るが runner の glob 外の名前（改名だけの無効化）
if _t83_mkextras; then
  printf '# references %s\n' "$_T83_GUARD_BASE" >"$_t83_exd/tb-25-renamed.sh"
  _t83_n=$(_t83_extras_eh13 "$_t83_exd")
  if [ "$_t83_n" = "0" ] && [ -f "$_t83_exd/tb-25-renamed.sh" ]; then
    t83_pass "TC-04b glob 外へ改名された extras は数えない（ディスク存在は実行の証拠でない）"
  else
    t83_fail "TC-04b glob 外のファイルを発見集合に数えた ($_t83_n)"
  fi
else
  t83_fail "TC-04b サンドボックス生成に失敗"
fi

# c: 述語が 0 に張り付いていないこと（陽性方向）＋ 自己除外マーカーが実際に効くこと。
#    ここが無いと TC-04a/b の 0 は「常に 0 を返す壊れた述語」と区別できない。
if _t83_mkextras; then
  printf '# exercises %s\n' "$_T83_GUARD_BASE" >"$_t83_exd/ta-99-counts.sh"
  _t83_n1=$(_t83_extras_eh13 "$_t83_exd")
  printf '# %s and %s\n' "$_T83_SELF_MARKER" "$_T83_GUARD_BASE" >"$_t83_exd/ta-98-self.sh"
  _t83_n2=$(_t83_extras_eh13 "$_t83_exd")
  if [ "$_t83_n1" = "1" ] && [ "$_t83_n2" = "1" ]; then
    t83_pass "TC-04c 述語は該当 extras を 1 件として数え、自己除外マーカー付きは加算しない（0 張り付き / 自己マッチの両方を否定）"
  else
    t83_fail "TC-04c 述語が壊れている（guard ref のみ=$_t83_n1 期待 1 / +marker 付き=$_t83_n2 期待 1）"
  fi
else
  t83_fail "TC-04c サンドボックス生成に失敗"
fi

# ===========================================================================
# TC-05〜TC-11: 検査器（CI が起動する当のゲート）に対する call site 変異
# ===========================================================================
if [ ! -f "$_T83_WIRING" ] || [ ! -f "$_T83_EXAMPLE" ]; then
  t83_fail "TC-05〜11 前提ファイル不在（check-settings-wiring.sh / settings.example.json）"
else
  _t83_case "" 0 "TC-05 陰性コントロール: 無変異の tracked 配線は PASS"
  _t83_case drop-all 1 "TC-06 tracked 配線の EH-13 全削除を検出"
  _t83_case drop-all-plus-untracked-rescue 1 \
    "TC-07 untracked settings.json の正しい参照は tracked 欠落を救済しない（#1259 の再現手順）"
  _t83_case unknown-event 1 "TC-08 未知 event キー（PreToolUseX）への退避を検出"
  _t83_case prose-only 1 "TC-09 散文フィールドへの退避を検出"
  _t83_case untracked-noise-only 0 \
    "TC-10 逆方向: untracked settings.local.json の複製参照は repo の判定を動かさない"

  # TC-11: 検査器の盲点の実測固定（責務分界）。
  #
  # ⚠️ この PASS は「相対パス化 / hooks/ 複製への付け替えが安全」という意味では
  #    **ない**。検査器（`has()` 相当のコマンド文字列包含判定）はこの 2 クラスを
  #    通す、という **現状の実測** を固定しているだけである。
  #    この 2 クラスを実際に赤くしているのは ta-25 の T1071-TC-04 の構造 scan
  #    （アンカー必須 = TC-04f / `scripts/hooks/` 複製 = TC-04e）であり、
  #    本 TC が赤くなったら「検査器が強化された」ことを意味するので、
  #    本 TA の残存脅威モデルと ta-25 側の責務記述を更新すること。
  _t83_blind=""
  for _t83_op in relativize repoint-hooks; do
    if ! _t83_mksbx "$_t83_op"; then
      _t83_blind="$_t83_blind $_t83_op(sbx)"
      continue
    fi
    _t83_run "$_t83_sbx"
    [ "$_t83_rc" -eq 0 ] || _t83_blind="$_t83_blind $_t83_op(rc=$_t83_rc)"
  done
  if [ -z "$_t83_blind" ]; then
    t83_pass "TC-11 検査器は相対パス化 / scripts/hooks/ 付け替えを通す（実測固定。この 2 クラスを撃つのは ta-25 T1071-TC-04e/f の構造 scan）"
  else
    t83_fail "TC-11 検査器の挙動が変わった:$_t83_blind — 強化されたなら本 TA と ta-25 の責務記述・残存脅威モデルを更新すること"
  fi
fi

# ===========================================================================
# TC-12: サンドボックス後片付け（明示 rm -rf の実効確認）
# ===========================================================================
# shellcheck disable=SC2086
rm -rf $_T83_SBXS
_t83_left=0
for _t83_d in $_T83_SBXS; do
  if [ -d "$_t83_d" ]; then
    _t83_left=$((_t83_left + 1))
  fi
done
if [ "$_t83_left" -eq 0 ]; then
  t83_pass "TC-12 サンドボックスを明示削除（実 .claude/ / .github/ には一切書き込まない）"
else
  t83_fail "TC-12 サンドボックスが $_t83_left 件残存"
fi

# 後始末は register_cleanup 済み（README 規約 3）。最終行は finalize 単独とし、
# 直前に他コマンドを挟まない（README 実行契約 checklist 3）。
pg_extra_contract_finalize
