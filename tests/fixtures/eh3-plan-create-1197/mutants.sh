#!/bin/sh
# 変異注入: patched hook の call site を壊し、対応 TC が FAIL することを確認する
# Usage: sh mutants.sh <patched-hook>   （所要 約 8 分。ta-119 の PG_T119_MUTATION=1 から起動）
# Exit: 0 = 全変異が killed（等価変異 me は分類どおり生存）/ 1 = 生存・分類誤り・ABORT あり
set -u
D=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
H=$1
MD=$(mktemp -d "${TMPDIR:-/tmp}/t119-mut.XXXXXX")
killed=0; survived=0; SURV=""; equiv=0; EQ=""
# 等価変異（多重防御の重複分。D-9）: 生存を期待し、集計は別枠。killed なら分類誤りとして survived 扱い
me() {
  id=$1; filt=$2; expr=$3
  sed "$expr" "$H" >"$MD/$id.sh"
  if sh "$D/cases.sh" "$MD/$id.sh" "$filt" >"$MD/$id.log" 2>&1; then
    printf '  [EQUIV] %s (survives as classified)\n' "$id"; equiv=$((equiv+1)); EQ="$EQ $id"
  elif grep -qF '[ABORT]' "$MD/$id.log"; then
    printf '  [ERROR] %s sandbox ABORT (not counted as kill)\n' "$id"; survived=$((survived+1)); SURV="$SURV $id(abort)"
  else
    printf '  [EQUIV-MISCLASSIFIED] %s killed by:%s\n' "$id" "$(grep -o 'failed:.*' "$MD/$id.log")"; survived=$((survived+1)); SURV="$SURV $id(misclassified)"
  fi
}
m() {
  id=$1; filt=$2; shift 2
  cp "$H" "$MD/$id.sh"
  for e in "$@"; do sed "$e" "$MD/$id.sh" >"$MD/$id.tmp" && mv "$MD/$id.tmp" "$MD/$id.sh"; done
  if cmp -s "$H" "$MD/$id.sh"; then printf '  [NOAPPLY] %s (sed matched nothing)\n' "$id"; survived=$((survived+1)); SURV="$SURV $id(noapply)"; return; fi
  if sh "$D/cases.sh" "$MD/$id.sh" "$filt" >"$MD/$id.log" 2>&1; then
    printf '  [SURVIVED] %s filter=%s\n' "$id" "$filt"; survived=$((survived+1)); SURV="$SURV $id"
  elif grep -qF '[ABORT]' "$MD/$id.log"; then
    printf '  [ERROR] %s sandbox ABORT (not counted as kill)\n' "$id"; survived=$((survived+1)); SURV="$SURV $id(abort)"
  else
    printf '  [KILLED] %s by:%s\n' "$id" "$(grep -o 'failed:.*' "$MD/$id.log")"; killed=$((killed+1))
  fi
}
m M1  'TC-0[57]'  's|    for w in wts:|    for w in [x for x in wts if x != os.path.realpath(wroot)]:|'
m M2  'TC-06'     's|    for w in wts:|    for w in [os.path.realpath(wroot)]:|'
m M3  'TC-02$'    's|    if os.path.lexists(req):|    if False:|'
m M4  'TC-08$'    's|    if r.stdout.strip():|    if False:|'
m M5  'TC-0[34]'  's|2>/dev/null \|\| true)" = "Write" \]|2>/dev/null \|\| true)" != "XX" ]|'
m M6  'TC-1[02]'  's|re.fullmatch(r"docs/working/(TASK-\[A-Za-z0-9\]\[A-Za-z0-9-\]\*)/plan\\.md", rel)|re.search(r"(?i)(TASK-[^/]*)/(.*/)?plan\\.md$", rel)|'
m M7  'TC-13'     's|os.path.lexists(p) and os.path.islink(p)|False|'
m M8  'TC-E03'    's|out("BLOCK\|worktree list failed")|out("ALLOW\|TASK-A\|0")|'
m M9a 'TC-14'     's|"${PLANGATE_HOOK_STRICT:-0}" != "1" \] \\$|"x" != "1" ] \\|'
m M9b 'TC-15'     's|\[ ! -e "$REPO_ROOT/docs/working/_maintenance/maintenance.json" \]|true|'
m M11 'TC-16'     's|>>"$_pc_dlog"; then|>/dev/null; then|'
m M12 'TC-E06'    's|^TIMEOUT = 10$|TIMEOUT = None|'
m M13a 'TC-08[bcde]' 's|"--reflog", "--full-history", |"--reflog", |'
m M13b 'TC-17'    's|:(top,icase)|:(top)|g'
m M13c 'TC-08[de]' 's|"--reflog", "--full-history"|"--full-history"|'
m M14 'TC-E07'    's|            skipped += 1|            pass|'
m M14b 'TC-E07|TC-A1' '/            skipped += 1/{n;s|continue|out("BLOCK\|prunable")|;}'
m M21-G3 'TC-B5'  's|any(c in raw for c in "\\n\\r\\0") or raw != t|False|'
me M21b-G3 'TC-B5' 's|any(c in raw for c in "\\n\\r\\0") or ||'
# 組合せ変異（D-9）: 一致検査 raw != t を外し、残る検査が単独で止めることを実証する
me M22-match-only 'TC-B5|TC-B6|TC-E01' 's| or raw != t:|:|'
m M23-M21b+match 'TC-B5' 's|any(c in raw for c in "\\n\\r\\0") or ||' 's| or raw != t:|:|'
me M24-M19+match 'TC-E01' 's|^_tf_src=""$|_tf_src=stdin_jq|' 's| or raw != t:|:|'
# M24 で残る isinstance 検査まで外すと止まらないことを確認（_tf_src 系の最後の砦の実証）
me M26-M19+match+isinstance 'TC-E01' 's|^_tf_src=""$|_tf_src=stdin_jq|' 's| or raw != t:|:|' 's|if not isinstance(raw, str) or |if |'
m M20-F3 'TC-A4|TC-09a' 's|        out("BLOCK\|relative file_path")|        t = os.path.join(root, t)|'
m M15 'TC-E08'    '/could not be recorded/{n;s|exit 2|:|;}'
m M16 'TC-E09'    's|out("BLOCK\|unreachable worktree " + path)|continue|'
m M17 'TC-08g'    's|r.returncode != 0 or r.stdout.strip() != b"false"|r.returncode != 0|'
m M18 'TC-13'     's|        p = "/".join(parts\[:j\])|        p = os.path.realpath("/".join(parts[:j]))|'
m M25-I1-env 'TC-I1' 's|raw = json.loads(sys.stdin.read())|raw = json.loads(os.environ["PG_STDIN"])|' 's|_pc_res=$(printf .%s. "$_stdin" \| PG_ROOT|_pc_res=$(PG_STDIN="$_stdin" PG_ROOT|'
m M27-lexgate 'TC-F1' '/^  _pc_lex=0$/,/^  esac$/d' 's/^  if \[ "$_pc_lex" = "1" \] \\$/  if true \\/'
me M19-tfsrc 'TC-E01' 's|^_tf_src=""$|_tf_src=stdin_jq|'
printf 'MUT killed=%s survived=%s equivalent=%s%s%s\n' "$killed" "$survived" "$equiv" "${SURV:+ survived:$SURV}" "${EQ:+ equivalent:$EQ}"
rm -rf "$MD"
[ "$survived" = 0 ]
