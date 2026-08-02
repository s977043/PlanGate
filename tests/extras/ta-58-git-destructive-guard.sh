# tests/extras/ta-58-git-destructive-guard.sh
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# Hook EH-12: protected branch 上の破壊的 git 操作 block（2026-08-02 実害由来）
#
# 検証対象は hook 本体 `scripts/check-git-destructive.sh`（HO 外・単一ソース）。
# `.claude/settings*.json` はこのパスを直接参照するため `scripts/hooks/` への
# 複製は行わない。したがって本テストは Human の `--apply` 前後どちらでも同じ
# 対象を検証する（複製が無い＝drift も存在しない）。
#
# サンドボックス: hook を <tmp>/scripts/ へ複製し、<tmp> を git init する。
# hook 自身の REPO_ROOT 解決（scripts/ → ..）が <tmp> を指すため、
# **実 docs/working/_audit を汚染しない**（ta-39 / ta-50 パターン）。
# current branch は commit を作らず `git symbolic-ref HEAD refs/heads/<name>` で
# 制御する。
#
# 隔離・後片付け（tests/extras/README.md §隔離・後始末の規約）:
#   trap は張らない（source 連鎖で上書きされ発火が保証されないため）。
#   `register_cleanup` 登録 + 末尾の明示 rm -rf の二重で sandbox を回収する。

printf '\n=== TA-58: EH-12 git destructive guard (protected branch) ===\n'

if [ -n "${FIXTURES_DIR:-}" ]; then
  _T58_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T58_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T58_SRC="$_T58_ROOT/scripts/check-git-destructive.sh"
_T58_APPLY="$_T58_ROOT/scripts/apply-eh-git-destructive-guard.sh"

t58_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t58_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

if [ ! -f "$_T58_SRC" ]; then
  t58_fail "hook 本体 scripts/check-git-destructive.sh が存在しない"
elif ! command -v git >/dev/null 2>&1; then
  printf '  [SKIP] git 不在\n'
else
  _T58_TMP=$(mktemp -d)
  _T58_OUTSIDE=$(mktemp -d)
  if command -v register_cleanup >/dev/null 2>&1; then
    register_cleanup "$_T58_TMP"
    register_cleanup "$_T58_OUTSIDE"
  fi

  mkdir -p "$_T58_TMP/scripts"
  cp "$_T58_SRC" "$_T58_TMP/scripts/check-git-destructive.sh"
  chmod +x "$_T58_TMP/scripts/check-git-destructive.sh"
  _T58_HOOK="$_T58_TMP/scripts/check-git-destructive.sh"
  _T58_LOG="$_T58_TMP/docs/working/_audit/hook-events.log"
  git init -q "$_T58_TMP" >/dev/null 2>&1 || true

  _t58_branch() { git -C "$_T58_TMP" symbolic-ref HEAD "refs/heads/$1" >/dev/null 2>&1; }

  # 与えたコマンドを PreToolUse stdin JSON で hook に渡し、判定を返す。
  # 出力: "block" / "allow" / "rc=<n>"（異常終了）
  _t58_judge() {
    _t58_cmd=$1
    _t58_rc=0
    _t58_out=$(
      cd "$_T58_TMP" 2>/dev/null &&
      printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$_t58_cmd" \
        | sh "$_T58_HOOK" 2>/dev/null
    ) || _t58_rc=$?
    if [ "$_t58_rc" -ne 0 ]; then
      printf 'rc=%s' "$_t58_rc"
      return 0
    fi
    case "$_t58_out" in
      *'"continue":false'*) printf 'block' ;;
      *'"continue":true'*)  printf 'allow' ;;
      *) printf 'unknown(%s)' "$_t58_out" ;;
    esac
  }

  _t58_expect() {
    _t58_label=$1
    _t58_want=$2
    _t58_got=$3
    if [ "$_t58_got" = "$_t58_want" ]; then
      t58_pass "$_t58_label -> $_t58_got"
    else
      t58_fail "$_t58_label -> expected $_t58_want, got $_t58_got"
    fi
  }

  # --- TC-01: main 上の git reset --hard -> block ---
  _t58_branch main
  _t58_expect "TC-01: main + git reset --hard origin/main" "block" \
    "$(_t58_judge 'git reset --hard origin/main')"

  # --- TC-02: feature ブランチ上の git reset --hard -> allow ---
  _t58_branch feat/x
  _t58_expect "TC-02: feat/x + git reset --hard origin/feat/x" "allow" \
    "$(_t58_judge 'git reset --hard origin/feat/x')"

  # --- TC-03: main 上の無害なコマンド -> allow ---
  _t58_branch main
  _t58_expect "TC-03: main + git status --short" "allow" \
    "$(_t58_judge 'git status --short')"
  _t58_expect "TC-03b: main + git reset (--hard なし)" "allow" \
    "$(_t58_judge 'git reset HEAD~1')"
  _t58_expect "TC-03c: main + git push (force なし)" "allow" \
    "$(_t58_judge 'git push origin main')"

  # --- TC-04: bypass -> allow ---
  _t58_rc=0
  _t58_out=$(
    cd "$_T58_TMP" &&
    printf '{"tool_input":{"command":"git reset --hard origin/main"}}' \
      | PLANGATE_BYPASS_HOOK=1 sh "$_T58_HOOK" 2>/dev/null
  ) || _t58_rc=$?
  case "$_t58_out" in
    *'"continue":true'*) t58_pass "TC-04: PLANGATE_BYPASS_HOOK=1 -> allow" ;;
    *) t58_fail "TC-04: bypass should allow (rc=$_t58_rc out=$_t58_out)" ;;
  esac

  # --- TC-05: force push 系の検出（main 上）---
  _t58_expect "TC-05a: main + git push --force-with-lease" "block" \
    "$(_t58_judge 'git push --force-with-lease origin main')"
  _t58_expect "TC-05b: main + git push --force" "block" \
    "$(_t58_judge 'git push --force origin main')"
  _t58_expect "TC-05c: main + git push -f" "block" \
    "$(_t58_judge 'git push -f origin main')"
  _t58_branch feat/x
  _t58_expect "TC-05d: feat/x + git push --force-with-lease" "allow" \
    "$(_t58_judge 'git push --force-with-lease origin feat/x')"

  # --- TC-06: 2026-08-02 実害コマンド列の回帰（|| 連結で main に落ちた形）---
  _t58_branch main
  _t58_expect "TC-06: main + checkout||checkout -b && reset --hard（実害形）" "block" \
    "$(_t58_judge 'git checkout -q b 2>/dev/null || git checkout -q -b b origin/b; git reset --hard -q origin/b')"

  # --- TC-07: 回避形（env 前置 / git -C / sh -c）も main では block ---
  _t58_expect "TC-07a: main + GIT_DIR=x git reset --hard" "block" \
    "$(_t58_judge 'GIT_DIR=x git reset --hard')"
  _t58_expect "TC-07b: main + git -C . reset --hard" "block" \
    "$(_t58_judge 'git -C . reset --hard')"
  _t58_expect "TC-07c: main + sh -c git reset --hard" "block" \
    "$(_t58_judge 'sh -c git reset --hard')"

  # --- TC-08: branch 判定不能（非 git cwd）-> allow（誤検出ゼロ優先）---
  _t58_rc=0
  _t58_out=$(
    cd "$_T58_OUTSIDE" &&
    printf '{"tool_input":{"command":"git reset --hard origin/main"}}' \
      | sh "$_T58_HOOK" 2>/dev/null
  ) || _t58_rc=$?
  case "$_t58_out" in
    *'"continue":true'*) t58_pass "TC-08: 非 git cwd（branch 判定不能）-> allow" ;;
    *) t58_fail "TC-08: 判定不能時は allow のはず (rc=$_t58_rc out=$_t58_out)" ;;
  esac

  # --- TC-09: env fallback（stdin なし時の CLI テスト経路）---
  _t58_branch main
  _t58_rc=0
  _t58_out=$(
    cd "$_T58_TMP" &&
    PLANGATE_HOOK_CMD='git reset --hard origin/main' sh "$_T58_HOOK" </dev/null 2>/dev/null
  ) || _t58_rc=$?
  case "$_t58_out" in
    *'"continue":false'*) t58_pass "TC-09: PLANGATE_HOOK_CMD fallback -> block" ;;
    *) t58_fail "TC-09: env fallback で block されない (rc=$_t58_rc out=$_t58_out)" ;;
  esac

  # --- TC-10: 監査ログに class+hash を記録し、command 全文は残さない ---
  if [ ! -f "$_T58_LOG" ]; then
    t58_fail "TC-10: 監査ログ $_T58_LOG が生成されていない"
  elif ! grep -q 'check-git-destructive' "$_T58_LOG"; then
    t58_fail "TC-10: 監査ログに hook 名の行がない"
  elif ! grep -q 'VIOLATION.*class=git-reset-hard.*hash=' "$_T58_LOG"; then
    t58_fail "TC-10: VIOLATION 行に class= / hash= がない"
  elif grep -q 'origin/main' "$_T58_LOG"; then
    t58_fail "TC-10: 監査ログに command 全文（origin/main）が漏れている"
  else
    t58_pass "TC-10: 監査ログは class+hash のみ（command 全文なし）"
  fi

  # --- TC-11: apply スクリプトの引数 strict 検証 ---
  if [ ! -f "$_T58_APPLY" ]; then
    t58_fail "TC-11: apply スクリプトが存在しない"
  else
    _t58_strict_ok=1
    # 無引数 / 不正引数 / 複数引数 は exit 1
    for _t58_args in "" "--apply --dry-run" "--force" "-n"; do
      _t58_rc=0
      # shellcheck disable=SC2086
      sh "$_T58_APPLY" $_t58_args >/dev/null 2>&1 || _t58_rc=$?
      if [ "$_t58_rc" -ne 1 ]; then
        _t58_strict_ok=0
        printf '    (args="%s": rc=%s, expected 1)\n' "$_t58_args" "$_t58_rc" >&2
      fi
    done
    if [ "$_t58_strict_ok" = "1" ]; then
      t58_pass "TC-11: apply 引数 strict 検証（無引数/複数/不正 -> exit 1）"
    else
      t58_fail "TC-11: apply 引数 strict 検証が効いていない（上記参照）"
    fi
  fi

  # --- TC-12: apply --dry-run は HO（settings）を書き換えない ---
  # 書き込み対象は .claude/settings*.json のみになったので、そのバイト列が
  # dry-run 前後で不変であることを直接確認する。
  _T58_EXAMPLE="$_T58_ROOT/.claude/settings.example.json"
  if [ ! -f "$_T58_APPLY" ] || ! command -v python3 >/dev/null 2>&1; then
    printf '  [SKIP] TC-12: python3 または apply スクリプト不在\n'
  elif [ ! -f "$_T58_EXAMPLE" ]; then
    printf '  [SKIP] TC-12: .claude/settings.example.json 不在\n'
  else
    _t58_before=$(cksum < "$_T58_EXAMPLE")
    _t58_rc=0
    sh "$_T58_APPLY" --dry-run >/dev/null 2>&1 || _t58_rc=$?
    _t58_after=$(cksum < "$_T58_EXAMPLE")
    if [ "$_t58_rc" -eq 0 ] && [ "$_t58_before" = "$_t58_after" ]; then
      t58_pass "TC-12: apply --dry-run は exit 0 かつ settings.example.json を書き換えない"
    else
      t58_fail "TC-12: dry-run rc=$_t58_rc / settings.example.json が変化した"
    fi
  fi

  # --- TC-13: 単一ソース不変条件（scripts/hooks/ に複製を作らない）---
  # 本 hook は scripts/ 直下を settings から直接参照する設計。scripts/hooks/
  # は tracked のため、そこに複製ができると同一内容の tracked ファイルが 2 つ
  # 並び、drift を検出する CI も存在しない（#956 と同一構造）。複製の出現を
  # 回帰として検出する。
  if [ -e "$_T58_ROOT/scripts/hooks/check-git-destructive.sh" ]; then
    t58_fail "TC-13: scripts/hooks/check-git-destructive.sh が存在する（単一ソース違反）"
  else
    t58_pass "TC-13: 単一ソース維持（scripts/hooks/ に複製なし）"
  fi

  # --- TC-13b: settings の配線先が scripts/ 直下を指すこと（配線済みの場合）---
  if [ ! -f "$_T58_EXAMPLE" ]; then
    printf '  [SKIP] TC-13b: .claude/settings.example.json 不在\n'
  elif ! grep -q 'check-git-destructive.sh' "$_T58_EXAMPLE"; then
    printf '  [SKIP] TC-13b: EH-12 未配線（Human の --apply 待ち）\n'
  elif grep -q 'scripts/hooks/check-git-destructive.sh' "$_T58_EXAMPLE"; then
    t58_fail "TC-13b: settings が scripts/hooks/ を参照している（単一ソース違反）"
  else
    t58_pass "TC-13b: settings の配線先が scripts/check-git-destructive.sh"
  fi

  # --- 明示 cleanup（register_cleanup と二重）---
  rm -rf "$_T58_TMP" "$_T58_OUTSIDE"
  if [ -d "$_T58_TMP" ] || [ -d "$_T58_OUTSIDE" ]; then
    t58_fail "TC-14: sandbox の後片付けに失敗"
  else
    t58_pass "TC-14: sandbox 明示 cleanup 完了"
  fi
fi
