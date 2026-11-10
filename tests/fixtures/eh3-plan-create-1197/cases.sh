#!/bin/sh
# #1197 EH-3 plan.md 初回作成許可の TC ドライバ（tests/extras/ta-119 から起動する）
# Usage: sh cases.sh <hook-under-test> [TC-filter-regex]
# Exit: 0 = 全 TC が期待どおり / 1 = 1 件以上不一致 / 3 = sandbox の前提不成立（ABORT）
# 書き込み先は mktemp -d 配下のみ。repo には書かない。
set -u
HOOK_SRC=$1
FILTER=${2:-.}
ORIG_CLONE=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
BASE=$(mktemp -d "${TMPDIR:-/tmp}/t1197.XXXXXX")
unset PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_SKIP_REASON PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT
pass=0; fail=0; FAILED=""

new_sb() {
  S=$(mktemp -d "$BASE/sb.XXXXXX")
  R=$S/repo
  git init -q "$R"
  git -C "$R" config user.email t@example.invalid
  git -C "$R" config user.name t
  mkdir -p "$R/scripts/hooks" "$R/docs/working"
  cp "$HOOK_SRC" "$R/scripts/hooks/check-plan-hash.sh"
  cp "$ORIG_CLONE/scripts/check-skip-acknowledged.sh" "$R/scripts/"
  echo x >"$R/README"
  git -C "$R" add -A
  git -C "$R" commit -qm init
  # 前提 assert: sandbox が成立していなければ以降の TC は素通りしうるので ABORT（PASS にしない）
  if [ ! -f "$R/scripts/hooks/check-plan-hash.sh" ] || ! cmp -s "$HOOK_SRC" "$R/scripts/hooks/check-plan-hash.sh" \
    || ! git -C "$R" rev-parse -q --verify HEAD >/dev/null 2>&1 || [ -n "$(git -C "$R" status --porcelain 2>/dev/null)" ]; then
    printf '  [ABORT] sandbox setup failed: %s\n' "$R"
    printf 'RESULT pass=%s fail=%s ABORTED\n' "$pass" "$((fail+1))"
    chmod -R u+w "$BASE" 2>/dev/null; rm -rf "$BASE"
    exit 3
  fi
}
payload() { printf '{"hook_event_name":"PreToolUse","tool_name":%s,"tool_input":{"file_path":"%s"}}' "$1" "$2"; }
# hk <tool-json> <path> [env assignments...]
hk() {
  _t=$1; _p=$2; shift 2
  OUT=$(payload "$_t" "$_p" | (cd "${HK_CWD:-$R}" && env "$@" sh "$R/scripts/hooks/check-plan-hash.sh" 2>&1))
  RC=$?
}
chk() {
  _n=$1; _want=$2
  case "$_n" in *) printf '%s\n' "$_n" | grep -Eq "$FILTER" || return 0 ;; esac
  _got=other
  if [ "$RC" = 0 ] && printf '%s' "$OUT" | grep -qF PLAN_CREATE_ALLOW; then _got=allow; fi
  if [ "$RC" = 2 ]; then _got=block; fi
  if [ "$_got" = "$_want" ]; then pass=$((pass+1)); printf '  [PASS] %s (%s)\n' "$_n" "$_got"
  else fail=$((fail+1)); FAILED="$FAILED $_n"; printf '  [FAIL] %s want=%s got=%s rc=%s\n    %s\n' "$_n" "$_want" "$_got" "$RC" "$(printf '%s' "$OUT" | head -3 | tr '\n' ' ')"; fi
}
W='"Write"'
P=docs/working/TASK-A/plan.md
want() { printf '%s\n' "$1" | grep -Eq "$FILTER"; }

want TC-01 && { new_sb; hk "$W" "$R/$P"; chk TC-01 allow; }
want TC-02 && { new_sb; mkdir -p "$R/docs/working/TASK-A"; echo p >"$R/$P"; hk "$W" "$R/$P"; chk TC-02 block; }
want TC-03 && { new_sb; mkdir -p "$R/docs/working/TASK-A"; echo p >"$R/$P"; hk '"Edit"' "$R/$P"; chk TC-03 block; }
want TC-04 && { new_sb; hk '"Edit"' "$R/$P"; chk TC-04a block; hk '"MultiEdit"' "$R/$P"; chk TC-04b block; }
want TC-05 && { new_sb; mkdir -p "$R/docs/working/TASK-A/approvals"; echo '{"c3_status":"APPROVED"}' >"$R/docs/working/TASK-A/approvals/c3.json"; hk "$W" "$R/$P"; chk TC-05 block; }
want TC-06 && { new_sb; git -C "$R" worktree add -q "$S/wt" -b wt 2>/dev/null; mkdir -p "$S/wt/docs/working/TASK-A/approvals"; echo '{}' >"$S/wt/docs/working/TASK-A/approvals/c3.json"; hk "$W" "$R/$P"; chk TC-06 block; }
want TC-07 && { new_sb; mkdir -p "$R/docs/working/TASK-A/approvals"; echo '{bad' >"$R/docs/working/TASK-A/approvals/c3.json"; hk "$W" "$R/$P"; chk TC-07a block;
  rm "$R/docs/working/TASK-A/approvals/c3.json"; hk "$W" "$R/$P"; chk TC-07b block; }
want TC-08 && { new_sb; mkdir -p "$R/docs/working/TASK-A"; echo p >"$R/$P"; git -C "$R" add -A; git -C "$R" commit -qm p; git -C "$R" rm -q "$P"; git -C "$R" commit -qm rm; hk "$W" "$R/$P"; chk TC-08 block; }
mkap() { mkdir -p "$R/docs/working/TASK-A/approvals"; echo '{}' >"$R/docs/working/TASK-A/approvals/c3.json"; }
want TC-08b && { new_sb; mkap; git -C "$R" stash push -q -u; hk "$W" "$R/$P"; chk TC-08b block; }
want TC-08c && { new_sb; git -C "$R" checkout -qb side; mkap; git -C "$R" add -A; git -C "$R" commit -qm a; git -C "$R" rm -rq docs/working/TASK-A; git -C "$R" commit -qm d; git -C "$R" checkout -q -; git -C "$R" merge -q --no-ff side -m m; git -C "$R" branch -qD side; hk "$W" "$R/$P"; chk TC-08c block; }
want TC-08d && { new_sb; mkap; git -C "$R" stash push -q -u; echo y >"$R/y"; git -C "$R" stash push -q -u; hk "$W" "$R/$P"; chk TC-08d block; }
want TC-08e && { new_sb; git -C "$R" checkout -qb side; mkap; git -C "$R" add -A; git -C "$R" commit -qm a; git -C "$R" checkout -q -; git -C "$R" branch -qD side; hk "$W" "$R/$P"; chk TC-08e block; }
want TC-08f && { new_sb; mkdir -p "$R/docs/working/TASK-A" "$R/sub"; echo p >"$R/$P"; git -C "$R" add -A; git -C "$R" commit -qm p; git -C "$R" rm -q "$P"; git -C "$R" commit -qm rm; HK_CWD=$R/sub hk "$W" "$R/$P"; chk TC-08f block; }
want TC-08g && { new_sb; mkdir -p "$R/docs/working/TASK-A"; echo p >"$R/$P"; git -C "$R" add -A; git -C "$R" commit -qm p; git -C "$R" rm -q "$P"; git -C "$R" commit -qm rm; echo z >"$R/z"; git -C "$R" add z; git -C "$R" commit -qm z
  O=$R; git clone -q --depth 1 "file://$O" "$S/sh"; R=$S/sh; mkdir -p "$R/scripts/hooks"; cp "$HOOK_SRC" "$R/scripts/hooks/check-plan-hash.sh"; hk "$W" "$R/$P"; chk TC-08g block; }
want TC-09 && { new_sb; hk "$W" ".//docs/working/TASK-A/./plan.md"; chk TC-09a block; hk "$W" "$R//docs/working/TASK-A/./plan.md"; chk TC-09c-abs-dotslash allow; new_sb; mkdir -p "$R/docs/working/TASK-B"; hk "$W" "docs/working/TASK-B/../TASK-A/plan.md"; chk TC-09b block; }
want TC-10 && { new_sb; hk "$W" "$R/docs/plan.md"; chk TC-10a block; hk "$W" "$R/docs/working/PBI-1/plan.md"; chk TC-10b block; hk "$W" "$R/docs/working/TASK-A/x/plan.md"; chk TC-10c block; }
want TC-11 && { new_sb; git -C "$R" worktree add -q "$R/.claude/worktrees/n" -b n 2>/dev/null; hk "$W" "$R/.claude/worktrees/n/$P"; chk TC-11a allow;
  git -C "$R" worktree add -q "$S/wt" -b wt 2>/dev/null; hk "$W" "$S/wt/docs/working/TASK-C/plan.md"; chk TC-11b-outside allow; }
want TC-11b && { new_sb; ln -s "$S" "$BASE/lnk.$$"; L=$BASE/lnk.$$/repo; payload "$W" "$L/$P" | (cd "$L" && sh "$L/scripts/hooks/check-plan-hash.sh") >/dev/null 2>&1; RC=$?; OUT=PLAN_CREATE_ALLOW; [ $RC = 0 ] || OUT=x; chk TC-11b-symlink-ancestor allow; }
want TC-12 && { new_sb; hk "$W" "$R/docs/working/task-a/plan.md"; chk TC-12a block; hk "$W" "$R/docs/working/TASK-A/PLAN.md"; chk TC-12b block; hk "$W" "$R/docs/working/ＴＡＳＫ-A/plan.md"; chk TC-12c block; }
want TC-13 && { new_sb; mkdir -p "$R/docs/working/TASK-A"; ln -s "$R/docs/working/TASK-A/nowhere.md" "$R/$P"; hk "$W" "$R/$P"; chk TC-13a block;
  new_sb; mkdir -p "$R/docs/working/TASK-M"; ln -s TASK-M "$R/docs/working/TASK-L"; hk "$W" "$R/docs/working/TASK-L/plan.md"; chk TC-13b block;
  git -C "$R" worktree add -q "$S/wt" -b wt 2>/dev/null; mkdir -p "$S/wt/docs/working/TASK-M"; ln -s TASK-M "$S/wt/docs/working/TASK-L"; hk "$W" "$S/wt/docs/working/TASK-L/plan.md"; chk TC-13c block; }
want TC-14 && { new_sb; hk "$W" "$R/$P" PLANGATE_HOOK_STRICT=1; chk TC-14 block; }
want TC-15 && { new_sb; mkdir -p "$R/docs/working/_maintenance"; echo '{}' >"$R/docs/working/_maintenance/maintenance.json"; hk "$W" "$R/$P"; chk TC-15 block; }
want TC-16 && { new_sb; hk "$W" "$R/$P"; _a=$(grep -c PLAN_CREATE_ALLOW "$R/docs/working/_audit/hook-events.log" 2>/dev/null); _b=$(grep -c PLAN_CREATE_ALLOW "$R/docs/working/_audit/skip-decision-log.jsonl" 2>/dev/null); sh "$R/scripts/check-skip-acknowledged.sh" >/dev/null 2>&1; _c=$?
  if [ "${_a:-0}" -ge 1 ] && [ "${_b:-0}" -ge 1 ] && [ $_c = 0 ]; then RC=0; OUT=PLAN_CREATE_ALLOW; else RC=9; fi; chk TC-16 allow; }
want TC-17 && { new_sb; mkdir -p "$R/docs/working/TASK-Ab"; echo p >"$R/docs/working/TASK-Ab/plan.md"; git -C "$R" add -A; git -C "$R" commit -qm p; git -C "$R" rm -rq docs/working/TASK-Ab; git -C "$R" commit -qm rm; hk "$W" "$R/docs/working/TASK-aB/plan.md"; chk TC-17 block; }
want TC-E01 && { new_sb; OUT=$(cd "$R" && PLANGATE_HOOK_FILE="$R/$P" sh "$R/scripts/hooks/check-plan-hash.sh" </dev/null 2>&1); RC=$?; chk TC-E01 block
  OUT=$(cd "$R" && _stdin='{"tool_name":"Write"}' PLANGATE_HOOK_FILE="$R/$P" sh "$R/scripts/hooks/check-plan-hash.sh" </dev/null 2>&1); RC=$?; chk TC-E01b-env-stdin block; }
# 最小 PATH（指定コマンドを除外）
mkpath() { _ex=$1; _d=$(mktemp -d "$BASE/bin.XXXXXX"); for c in sh git python3 jq sed tr date mkdir cat head grep awk dirname shasum sha256sum env; do [ "$c" = "$_ex" ] && continue; _w=$(command -v "$c" 2>/dev/null) && ln -s "$_w" "$_d/$c"; done; printf '%s' "$_d"; }
want TC-E02 && { new_sb; _pp=$(mkpath jq); hk "$W" "$R/$P" PATH="$_pp"; chk TC-E02 block; }
want TC-E03 && { new_sb; _pp=$(mkpath git); hk "$W" "$R/$P" PATH="$_pp"; chk TC-E03a-nogit block; rm -rf "$R/.git"; hk "$W" "$R/$P"; chk TC-E03b-nonrepo block; }
want TC-E04 && { new_sb; _pp=$(mkpath python3); hk "$W" "$R/$P" PATH="$_pp"; chk TC-E04 block; }
want TC-E05 && { new_sb; hk '""' "$R/$P"; chk TC-E05a block; hk 'null' "$R/$P"; chk TC-E05b block; hk '1' "$R/$P"; chk TC-E05c block; }
want TC-E06 && { new_sb; _gd=$(mktemp -d "$BASE/g.XXXXXX"); _rg=$(command -v git)
  printf '#!/bin/sh\ncase "$1" in rev-list) sleep 40;; esac\nexec %s "$@"\n' "$_rg" >"$_gd/git"; chmod +x "$_gd/git"
  _t0=$(date +%s); hk "$W" "$R/$P" PATH="$_gd:$PATH" & _bp=$!; ( sleep 25; kill $_bp 2>/dev/null ) & _kp=$!; wait $_bp; _st=$?; kill $_kp 2>/dev/null; _t1=$(date +%s)
  if [ $((_t1-_t0)) -lt 25 ] && [ $_st = 0 ]; then
    # hk ran in subshell; rerun synchronously to capture rc (bounded by the same timeout)
    hk "$W" "$R/$P" PATH="$_gd:$PATH"; else RC=99; OUT=hang; fi; chk TC-E06 block; }
want TC-E07 && { new_sb; git -C "$R" worktree add -q "$S/gone" -b gone 2>/dev/null; rm -rf "$S/gone"; hk "$W" "$R/$P"; chk TC-E07 allow
  if printf '%s' "$OUT" | grep -qF 'git worktree prune'; then RC=9; else RC=0; OUT=PLAN_CREATE_ALLOW; fi; chk TC-E07-no-prune-hint allow
  if grep -q '"prunable_skipped":1' "$R/docs/working/_audit/skip-decision-log.jsonl" 2>/dev/null && grep -q 'prunable_skipped=1' "$R/docs/working/_audit/hook-events.log" 2>/dev/null; then RC=0; OUT=PLAN_CREATE_ALLOW; else RC=9; fi; chk TC-E07-count allow; }
# 列挙はベストエフォート（Human 裁定 R2）: 以下は ALLOW を期待値として挙動を固定する
mkw2() { git -C "$R" worktree add -q "$S/w2" -b w2 2>/dev/null; mkdir -p "$S/w2/docs/working/TASK-A/approvals"; echo '{"c3_status":"APPROVED"}' >"$S/w2/docs/working/TASK-A/approvals/c3.json"; }
want TC-A1 && { new_sb; mkw2; mv "$S/w2" "$S/w2moved"; hk "$W" "$R/$P"; chk TC-A1-moved-worktree-approvals allow; }
want TC-B1 && { new_sb; mkw2; mv "$S/w2" "$S/w2moved"; git -C "$R" worktree prune; hk "$W" "$R/$P"; chk TC-B1-after-prune allow; }
want TC-B2 && { new_sb; mkw2; rm -rf "$R/.git/worktrees/w2"; hk "$W" "$R/$P"; chk TC-B2-gitdir-removed allow; }
want TC-B3 && { new_sb; git clone -q "$R" "$S/cl"; mkdir -p "$S/cl/docs/working/TASK-A/approvals"; echo '{}' >"$S/cl/docs/working/TASK-A/approvals/c3.json"; hk "$W" "$R/$P"; chk TC-B3-separate-clone allow; }
want TC-B5 && { new_sb; hk "$W" "$R/$P\\n"; chk TC-B5c-trailing-newline block; hk "$W" "$R/docs/working/TASK-A\\n/plan.md"; chk TC-B5d-inner-newline block; hk "$W" "$R/$P\\r"; chk TC-B5e-cr block; hk "$W" "$R/$P\\u0000"; chk TC-B5f-nul block; }
want TC-A4 && { new_sb; mkdir -p "$R/sub"; HK_CWD=$R/sub hk "$W" "$P"; chk TC-A4-relative-from-subdir block; hk "$W" "$P"; chk TC-A4b-relative-from-root block; }
want TC-E08 && { new_sb; mkdir -p "$R/docs/working/_audit"; : >"$R/docs/working/_audit/hook-events.log"; chmod 444 "$R/docs/working/_audit/hook-events.log"; hk "$W" "$R/$P"; chk TC-E08a block
  new_sb; mkdir -p "$R/docs/working/_audit"; : >"$R/docs/working/_audit/skip-decision-log.jsonl"; chmod 444 "$R/docs/working/_audit/skip-decision-log.jsonl"; hk "$W" "$R/$P"; chk TC-E08b block; }
want TC-E09 && { new_sb; git -C "$R" worktree add -q "$S/lk" -b lk 2>/dev/null; git -C "$R" worktree lock "$S/lk"; mv "$S/lk" "$S/lk-moved"; hk "$W" "$R/$P"; chk TC-E09 block; }

# 孤立サロゲート: jq は U+FFFD に置換し、python は \ud800 を保持する → 一致検査だけが止める。
# U+FFFD 名の worktree root を実在させ、jq 側の値が正当なパスに一致する状況を作る。
# 実測（jq 1.8.1）: jq は孤立サロゲートを parse error で拒否し、hook は grep/sed の fallback で
# バックスラッシュを含む文字列のまま target_file にする。_tf_src は空なので許可分岐に入らない。
# その結果、origin/main の hook でも OUTSIDE_REPO_SKIP（rc=0）になる＝本 patch 以前からの既存挙動。
# 書き込み主体が実際にどのパスへ書くか（U+FFFD への置換など）は未検証。KNOWN-GAP として計数外で表示する。
want TC-B6 && { new_sb; _fd=$(printf '\357\277\275'); mv "$R" "$S/r$_fd"; R="$S/r$_fd"; hk "$W" "$S/r\\ud800/$P"
  printf '  [KNOWN-GAP] TC-B6-lone-surrogate rc=%s (%s)\n' "$RC" "$(printf '%s' "$OUT" | grep -o 'OUTSIDE_REPO_SKIP\|PLAN_CREATE_ALLOW\|BLOCK' | head -1)"
  hk "$W" "$R/$P"; chk TC-B6-control-fffd-root allow; }
want TC-I1 && { new_sb; _big=$(mktemp "$BASE/big.XXXXXX"); python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":"x"*1228800}}))' "$R/$P" >"$_big"
  OUT=$(cd "$R" && sh "$R/scripts/hooks/check-plan-hash.sh" <"$_big" 2>&1); RC=$?; chk TC-I1-1200KB-payload allow; }
# docstring の記述の固定: task レーンは c3.json が無ければ STRICT でも plan.md 編集を通す（既存挙動）
want TC-P5 && { new_sb; mkdir -p "$R/docs/working/TASK-A"; echo p >"$R/$P"; OUT=$(payload "$W" "$R/$P" | (cd "$R" && PLANGATE_HOOK_TASK=TASK-A PLANGATE_HOOK_STRICT=1 sh "$R/scripts/hooks/check-plan-hash.sh" 2>&1)); RC=$?
  if [ $RC = 0 ]; then OUT=PLAN_CREATE_ALLOW; fi; chk TC-P5-task-lane-strict-no-c3-passes allow; }

printf 'RESULT pass=%s fail=%s%s\n' "$pass" "$fail" "${FAILED:+ failed:$FAILED}"
chmod -R u+w "$BASE" 2>/dev/null; rm -rf "$BASE"
[ "$fail" = 0 ]
