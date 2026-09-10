#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-86 — EH-12（check-git-destructive.sh）の判定が同一コマンドのトークン列に
# 限定されていることを固定する（#1326）。
#
# 2 レーン構成（ta-79 / ta-80 と同型）。
#
#   サンドボックス（TC-10 以降）: mktemp 複製へ #1326 の patch を当てた hook に対し、
#     **常に是正後の挙動**を assert する。patch の適用有無に依存しない。
#   実 hook（TC-R01 以降）: `scripts/check-git-destructive.sh` の実体に対し、
#     tests/fixtures/eh12-token-scope-pending-1326.flag があれば **gap** を、
#     無ければ **fixed** を assert する。patch 適用時に flag を削除する。
#
# 誤検知の実害: コマンド文字列に `git` と `push` / `--force` / ` +` が同居すると、
# 実行されない文字列（echo の引数・コミットメッセージ）でも block される。

# ---- extras execution contract bootstrap (#921) ----------------------------
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
pg_extra_contract_init ta-86-eh12-token-scope standalone-capable

if pg_extra_contract_is_standalone; then
  # standalone: 外部 env 汚染を無害化（tests/extras/README.md 規約 8）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

# repo root は **契約側の値**から解く。`$0` 相対だと harness 実行時に
# 1 階層上を指す（実測: CI で「hook が無い」になった）。
_T86_FX=""
if [ "$_pg_extra_mode" = harness ]; then
  _T86_FX="${FIXTURES_DIR:-}"
fi
if [ -n "$_T86_FX" ]; then
  _T86_ROOT="$(CDPATH= cd -- "$_T86_FX/../.." && pwd)"
else
  _T86_ROOT="${_pg_extra_dir%/tests/extras}"
fi

# pass / fail は契約 helper が初期化し、standalone のサマリ出力も helper が行う
# （自前で printf すると contract probe の再実行で二重に出る。実測で踏んだ）。
t86_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t86_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T86_HOOK="$_T86_ROOT/scripts/check-git-destructive.sh"
_T86_DOC="$_T86_ROOT/docs/working/_reports/1326-eh12-token-scope-patch.md"
_T86_FIXTURES="${FIXTURES_DIR:-$_T86_ROOT/tests/fixtures}"
_T86_FLAG="$_T86_FIXTURES/eh12-token-scope-pending-1326.flag"

_T86_TMP=$(mktemp -d)
_t86_cleanup() { rm -rf "$_T86_TMP"; }

# --- probe: hook を実 PreToolUse payload で起動して verdict を返す -------------
# パイプの後で $? を取ると hook ではなくパイプの rc になる（既知の罠）。
_t86_probe() { # _t86_probe <hook> <command>
  _p_hook=$1
  _p_cmd=$2
  _p_out=$(
    printf '{"session_id":"ta86","transcript_path":"/tmp/t.jsonl","cwd":"%s",' "$_T86_ROOT"
    printf '"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":'
    printf '%s' "$_p_cmd" | python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read()))'
    printf '}}'
  ) || return 1
  # hook は **自分の cwd** で `git symbolic-ref` を実行して branch を決める。
  # CI では PR ブランチ上で動くため、そのままだと protected でなく全て allow に
  # なって TC が空振りする。main ブランチの捨て repo を cwd にして起動する。
  # `</dev/null` を付けてはいけない。パイプで渡した stdin を上書きして
  # hook が空入力を受け取り、全ケースが allow になる（実測で踏んだ）。
  _p_res=$(cd "$_T86_PROBE_REPO" && printf '%s' "$_p_out" | sh "$_p_hook" 2>&1 || true)
  case "$_p_res" in
    *'"continue":false'*) printf 'BLOCK' ;;
    *'"continue":true'*)  printf 'allow' ;;
    *)                    printf 'UNKNOWN' ;;
  esac
}

_t86_expect() { # _t86_expect <hook> <期待> <label> <command>
  _e_got=$(_t86_probe "$1" "$4")
  if [ "$_e_got" = "$2" ]; then
    t86_pass "$3 ($_e_got)"
  else
    t86_fail "$3 (期待 $2 / 実測 $_e_got)"
  fi
}

# --- 前提 --------------------------------------------------------------------
printf 'TA-86: EH-12 token scope (#1326)\n'

if [ ! -f "$_T86_HOOK" ]; then
  t86_fail "TC-00: hook が無い: $_T86_HOOK"
  _t86_cleanup
  pg_extra_contract_finalize
  if pg_extra_contract_is_standalone; then exit 1; fi
  return 0
fi

# hook が protected branch と判定する cwd を用意する。実 repo の branch に
# 依存させない（CI は PR ブランチ上で動くため、依存させると TC が空振りする）。
_T86_PROBE_REPO="$_T86_TMP/probe-repo"
mkdir -p "$_T86_PROBE_REPO"
(cd "$_T86_PROBE_REPO" && git init -q -b main . >/dev/null 2>&1) || \
  (cd "$_T86_PROBE_REPO" && git init -q . >/dev/null 2>&1 && git symbolic-ref HEAD refs/heads/main)
_t86_probe_branch=$(cd "$_T86_PROBE_REPO" && git symbolic-ref --quiet --short HEAD 2>/dev/null || printf '')
if [ "$_t86_probe_branch" = "main" ]; then
  t86_pass "TC-00: probe 用 repo が main ブランチ（branch=${_t86_probe_branch}）"
else
  t86_fail "TC-00: probe 用 repo の branch が main でない（branch=${_t86_probe_branch}）"
fi

# --- サンドボックス: 是正後(NEW) と 是正前(OLD) の hook を両方作る ------------
# 実 hook が未適用なら fwd apply で NEW を、適用済みなら rev apply で OLD を作る。
# どちらの状態でも 2 本が揃うので、TC の判定は patch の適用有無に依存しない。
_T86_SB="$_T86_TMP/new-hook.sh"
_T86_OLD="$_T86_TMP/old-hook.sh"
_t86_lanes=0

if [ -f "$_T86_DOC" ]; then
  awk 'BEGIN{q=sprintf("%c",96)}
       /^<!-- PG-PATCH-BEGIN -->$/{b=1;next}
       /^<!-- PG-PATCH-END -->$/{exit}
       b && substr($0,1,1)==q{f=!f;next}
       f' "$_T86_DOC" > "$_T86_TMP/p.patch"
fi

if [ -s "${_T86_TMP}/p.patch" ]; then
  mkdir -p "$_T86_TMP/scripts"
  cp "$_T86_HOOK" "$_T86_TMP/scripts/check-git-destructive.sh"
  if (cd "$_T86_TMP" && git apply --unsafe-paths --directory=. p.patch 2>/dev/null); then
    cp "$_T86_TMP/scripts/check-git-destructive.sh" "$_T86_SB"   # NEW = 適用結果
    cp "$_T86_HOOK" "$_T86_OLD"                                   # OLD = 実 hook
    _t86_lanes=1
  else
    cp "$_T86_HOOK" "$_T86_TMP/scripts/check-git-destructive.sh"
    if (cd "$_T86_TMP" && git apply -R --unsafe-paths --directory=. p.patch 2>/dev/null); then
      cp "$_T86_HOOK" "$_T86_SB"                                  # NEW = 実 hook（適用済み）
      cp "$_T86_TMP/scripts/check-git-destructive.sh" "$_T86_OLD" # OLD = rev apply 結果
      _t86_lanes=1
    fi
  fi
fi

if [ "$_t86_lanes" = "1" ]; then
  t86_pass "TC-01: サンドボックスに是正後(NEW)と是正前(OLD)の hook を用意した"
else
  t86_fail "TC-01: patch の fwd / rev どちらも当たらない（patch 文書が stale）"
  cp "$_T86_HOOK" "$_T86_SB"
  cp "$_T86_HOOK" "$_T86_OLD"
fi

if [ ! -s "$_T86_SB" ] || ! sh -n "$_T86_SB" 2>/dev/null; then
  t86_fail "TC-02: サンドボックス hook の構文が壊れている"
else
  t86_pass "TC-02: サンドボックス hook は sh -n rc=0"
fi

# --- 本物の破壊的操作は BLOCK のまま（緩めていないことの証明）-----------------
printf '  -- sandbox / 本物の破壊的操作（BLOCK のまま）--\n'
_t86_expect "$_T86_SB" BLOCK 'TC-03a: --force'              'git push --force origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-03b: --force-with-lease'   'git push --force-with-lease origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-03c: --force-with-lease=<ref>' 'git push --force-with-lease=main:abc origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-03d: --force-if-includes'  'git push --force-if-includes origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-03e: -f'                   'git push -f origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-03f: refspec +'            'git push origin +HEAD:main'
_t86_expect "$_T86_SB" BLOCK 'TC-03g: reset --hard'         'git reset --hard origin/main'
_t86_expect "$_T86_SB" BLOCK 'TC-04a: git -C 経由'          'git -C /path push --force origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-04b: git -c 経由'          'git -c user.name=x push --force origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-04c: env 前置'             'GIT_DIR=/x git push --force origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-04d: command 前置'         'command git push --force origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-04e: 絶対パス'             '/usr/bin/git push --force origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-04f: sh -c 間接起動'       'sh -c "git push --force origin main"'
_t86_expect "$_T86_SB" BLOCK 'TC-04g: && の後段が force'    'git status && git push --force origin main'
_t86_expect "$_T86_SB" BLOCK 'TC-04h: 連続空白'             'git push  --force  origin  main'

# --- 誤検知が解消していること -------------------------------------------------
printf '  -- sandbox / 非破壊（allow）--\n'
_t86_expect "$_T86_SB" allow 'TC-05a: 別コマンドの --force' 'git push -q origin docs/x && git worktree remove --force /tmp/w'
_t86_expect "$_T86_SB" allow 'TC-05b: refspec でない +'      'git push origin HEAD && echo a + b'
_t86_expect "$_T86_SB" allow 'TC-05c: echo の文字列（未実行）' 'echo "use git push --force only on branches"'
_t86_expect "$_T86_SB" allow 'TC-05d: コミットメッセージ'     'git commit -m "do not push --force to main"'
_t86_expect "$_T86_SB" allow 'TC-05e: worktree add -f + push' 'git worktree add -f /tmp/w main && git push origin w'
_t86_expect "$_T86_SB" allow 'TC-05f: 通常の push'            'git push -q origin docs/x'
_t86_expect "$_T86_SB" allow 'TC-05g: worktree remove 単独'   'git worktree remove --force /tmp/w'
_t86_expect "$_T86_SB" allow 'TC-05h: reset --soft'           'git reset --soft HEAD~1'
_t86_expect "$_T86_SB" allow 'TC-05i: grep のパターン'        'grep -n "push --force" README.md'
_t86_expect "$_T86_SB" allow 'TC-05j: git を含まない'         'pwd'

# --- 変異注入: 是正前の実装がこれらを取りこぼすこと ---------------------------
# サンドボックスの hook を「是正前」へ戻し、TC-05a/b/c が FAIL することを確認する。
printf '  -- 変異注入（是正前の実装で誤検知が再現すること）--\n'
_t86_mut=0
for _m in 'git push -q origin docs/x && git worktree remove --force /tmp/w' \
          'git push origin HEAD && echo a + b' \
          'echo "use git push --force only on branches"'; do
  [ "$(_t86_probe "$_T86_OLD" "$_m")" = "BLOCK" ] && _t86_mut=$((_t86_mut + 1))
done
if [ "$_t86_mut" -ge 3 ]; then
  t86_pass "TC-06: 変異注入 — 是正前の実装は 3 ケースすべてを誤 BLOCK する（検出力あり）"
else
  t86_fail "TC-06: 変異注入 — 是正前の実装で誤 BLOCK が $_t86_mut 件（3 件を期待）"
fi

# --- 実 hook レーン -----------------------------------------------------------
if [ -f "$_T86_FLAG" ]; then
  _T86_EXPECT=gap
  printf '  -- real hook (expect: gap / pending flag あり) --\n'
else
  _T86_EXPECT=fixed
  printf '  -- real hook (expect: fixed) --\n'
fi

_t86_real() { # _t86_real <label> <command> <fixed 期待> <gap 期待>
  if [ "$_T86_EXPECT" = "fixed" ]; then
    _t86_expect "$_T86_HOOK" "$3" "$1" "$2"
  else
    _t86_expect "$_T86_HOOK" "$4" "$1" "$2"
  fi
}

_t86_real 'TC-R01: 実 hook / 別コマンドの --force'   'git push -q origin docs/x && git worktree remove --force /tmp/w' allow BLOCK
_t86_real 'TC-R02: 実 hook / refspec でない +'        'git push origin HEAD && echo a + b'                             allow BLOCK
_t86_real 'TC-R03: 実 hook / echo の文字列'           'echo "use git push --force only on branches"'                   allow BLOCK

# 対照（gap / fixed を問わず不変であるべきもの）
_t86_expect "$_T86_HOOK" BLOCK 'TC-R04: 実 hook / 本物の force push（対照）' 'git push --force origin main'
_t86_expect "$_T86_HOOK" BLOCK 'TC-R05: 実 hook / reset --hard（対照）'      'git reset --hard origin/main'
_t86_expect "$_T86_HOOK" allow 'TC-R06: 実 hook / 通常の push（対照）'       'git push -q origin docs/x'

# --- stale flag 検査 ----------------------------------------------------------
if [ -f "$_T86_FLAG" ]; then
  if [ "$(_t86_probe "$_T86_HOOK" 'echo "use git push --force only on branches"')" = "allow" ]; then
    t86_fail "TC-07: pending flag が stale（実 hook は既に是正済み。flag を削除すること）"
  else
    t86_pass "TC-07: pending flag は有効（実 hook は未適用）"
  fi
else
  t86_pass "TC-07: pending flag なし（適用済みレーン）"
fi

_t86_cleanup
if [ -d "$_T86_TMP" ]; then
  t86_fail "TC-08: sandbox が残っている: $_T86_TMP"
else
  t86_pass "TC-08: sandbox removed (no residue outside mktemp)"
fi

pg_extra_contract_finalize
