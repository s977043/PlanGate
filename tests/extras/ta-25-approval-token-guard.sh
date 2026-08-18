# tests/extras/ta-25-approval-token-guard.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0123: EH-token-guard + HMAC schema tests（legacy TC-01〜07 保持）
# TASK-1023 (#1023): 二重無効化（exit 1 / env 時 stdin bypass / parse fail-open）封鎖の
#   RED/GREEN coverage（T1023-TC-*）+ mutation 7 種 + standalone rc 伝播。
#   - PG_T25_GUARD は env override 可能（mutation kill 判定用 / R-029）
#   - 全 non-bypass assertion は command-scoped PLANGATE_SKIP_TOKEN_GUARD=0（TC-14c）
#   - stdin を redirect しない guard 起動を残さない（端末実行ハング防止 / R-027 / TC-24）
#   - legacy TC-03/04 は exit 1→2 へ migration（回帰目的 = token path block は維持）
#   - legacy TC-05 は valid normal payload の supply へ migration（回帰目的 = normal 許可は維持）

printf '\n=== TA-25: TASK-0123/TASK-1023 approval-token-guard ===\n'

# 単体実行 fallback（#861 / #877 F3 / ta-26 と同方式）: run-tests.sh から source されず
# 直接実行された場合、FIXTURES_DIR / pass / fail / register_cleanup を自前定義する。
# 判別は PG_HARNESS_SOURCED=1 と FIXTURES_DIR の AND（片方でも欠ければ standalone 側 = 安全側）。
if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  PG_T25_STANDALONE=1
  # 呼び出し元 env の漏れ防止（run-tests.sh 冒頭の unset 集合と同一 + 本ガード固有の 1 env）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  unset PLANGATE_SKIP_TOKEN_GUARD 2>/dev/null || true
  FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
  pass=0
  fail=0
  _PG_T25_CLEANUP_PATHS=""
  register_cleanup() {
    for _pg_cp in "$@"; do
      if [ -n "$_pg_cp" ]; then
        _PG_T25_CLEANUP_PATHS="${_PG_T25_CLEANUP_PATHS}${_pg_cp}
"
      fi
    done
  }
else
  PG_T25_STANDALONE=0
fi

PG_T25_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
# R-029: mutation kill 判定は PG_T25_GUARD を mutant へ override して「実 TC が FAIL する」
# ことで行う。ハードコードだと mutation はインライン assert しか壊せず検出力が実証されない。
PG_T25_GUARD="${PG_T25_GUARD:-$PG_T25_ROOT/scripts/check-approval-token-write.sh}"
PG_T25_SCHEMA="$PG_T25_ROOT/schemas/maintenance.schema.json"
PG_T25_PATCH="$PG_T25_ROOT/scripts/apply-task-0123-patches.sh"
PG_T25_SELF="$PG_T25_ROOT/tests/extras/ta-25-approval-token-guard.sh"

# focused mode: mutation 子プロセス（PG_T25_MUTATION_CHILD=1）は kill 対象 TC のみ実行
PG_T25_FOCUSED="${PG_T25_MUTATION_CHILD:-0}"

t25_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t25_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# ── 共通ヘルパー ─────────────────────────────────────────────
# t25_guard <stdin-file> [args...]
#   env: T25_ENV_FILE が set なら PLANGATE_HOOK_FILE として渡す（空文字も「set」扱い）。
#        unset なら env から除去して起動する。
#   出力: _t25_rc（exit code）/ $T25_ERR（stderr）
#   TC-14c: すべて command-scoped PLANGATE_SKIP_TOKEN_GUARD=0 で起動（親 env=1 でも無効化されない）
T25_TMP=$(mktemp -d "${TMPDIR:-/tmp}/pg-t25.XXXXXX")
register_cleanup "$T25_TMP"
T25_ERR="$T25_TMP/stderr.out"
t25_guard() {
  _t25_in="$1"; shift
  _t25_rc=0
  if [ "${T25_ENV_FILE+x}" = "x" ]; then
    env PLANGATE_SKIP_TOKEN_GUARD=0 PLANGATE_HOOK_FILE="$T25_ENV_FILE" sh "$PG_T25_GUARD" "$@" < "$_t25_in" 2>"$T25_ERR" || _t25_rc=$?
  else
    env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 sh "$PG_T25_GUARD" "$@" < "$_t25_in" 2>"$T25_ERR" || _t25_rc=$?
  fi
}

# 固定 payload（テスト専用の架空 path。実 approvals には一切触れない）
T25_TOKEN="docs/working/TASK-0001/approvals/c3.json"
T25_MAINT="docs/working/_maintenance/maintenance.json"

t25_mk() { printf '%s' "$2" > "$T25_TMP/$1"; }

t25_mk p_normal_write '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"src/index.ts","content":"x"}}'
t25_mk p_edit_token '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"docs/working/TASK-0001/approvals/c3.json","old_string":"a","new_string":"b"}}'
t25_mk p_toplevel_token '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"old_string":"a","new_string":"b"},"file_path":"docs/working/TASK-0001/approvals/c3.json"}'
t25_mk p_bash_token_write '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x > docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_bash_tee_maint '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo start\n  printf x | tee \"docs/working/_maintenance/maintenance.json\"\necho done"}}'
t25_mk p_bash_token_read '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_bash_mixed '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json && echo hi > /tmp/other.txt"}}'
t25_mk p_bash_normal_write '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x > src/out.txt"}}'
t25_mk p_escaped_token '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"docs\/working\/TASK-0001\/approvals\/c3.json","content":"x"}}'
t25_mk p_multiedit_normal '{"hook_event_name":"PreToolUse","tool_name":"MultiEdit","tool_input":{"file_path":"src/index.ts","edits":[{"old_string":"a","new_string":"b"}]}}'
t25_mk p_multiedit_token '{"hook_event_name":"PreToolUse","tool_name":"MultiEdit","tool_input":{"file_path":"docs/working/TASK-0001/approvals/c3.json","edits":[{"old_string":"a","new_string":"b"}]}}'
t25_mk p_multiedit_token_in_body '{"hook_event_name":"PreToolUse","tool_name":"MultiEdit","tool_input":{"file_path":"docs/working/TASK-1023/plan.md","edits":[{"old_string":"a","new_string":"see docs/working/TASK-1023/approvals/c3.json"}]}}'
t25_mk p_edit_token_in_body '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"docs/working/TASK-1023/plan.md","old_string":"a","new_string":"see docs/working/TASK-1023/approvals/c3.json"}}'
t25_mk p_bash_env_bypass_string '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"PLANGATE_SKIP_TOKEN_GUARD=1 printf x > docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_malformed 'this is not json'
t25_mk p_truncated '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_pa'
t25_mk p_empty ''
t25_mk p_empty_obj '{}'
t25_mk p_no_tool_input '{"hook_event_name":"PreToolUse","tool_name":"Write"}'
t25_mk p_null_fp '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":null}}'
t25_mk p_array_fp '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":["a"]}}'
t25_mk p_number_fp '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":5}}'
t25_mk p_unknown_tool '{"hook_event_name":"PreToolUse","tool_name":"NotebookEdit","tool_input":{"file_path":"src/index.ts"}}'
t25_mk p_wrong_event '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"src/index.ts"}}'

# ── TASK-1045 (#1045) fixtures: 読み取り専用コマンドの誤 block 解消 / 退行防止 ──
# 誤検知側（fd 複製・fd クローズ・/dev/null 破棄を伴う read-only）
t25_mk p_t1045_read_2devnull '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"grep -c docs/working/TASK-0001/approvals/c3.json .gitignore 2>/dev/null"}}'
t25_mk p_t1045_read_2and1 '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json 2>&1"}}'
t25_mk p_t1045_read_gt2 '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json >&2"}}'
t25_mk p_t1045_read_fdclose '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json 3>&-"}}'
# 退行防止側（真のファイル宛リダイレクト）
t25_mk p_t1045_w_gt '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1045_w_append '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x >> docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1045_w_fd1 '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x 1> docs/working/TASK-0001/approvals/c3.json"}}'

# ── TASK-1110 (#1110) fixtures: リダイレクト先とトークンパスの相関 ──────────
# 負の対照（トークン名は出るがリダイレクト先はトークンパスでない = 誤検知側）
t25_mk p_t1110_n_msg_redirect '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m '"'"'docs: docs/working/TASK-0001/approvals/c3.json'"'"' > /tmp/log.txt"}}'
t25_mk p_t1110_n_msg_only '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m '"'"'docs: docs/working/TASK-0001/approvals/c3.json handling'"'"'"}}'
t25_mk p_t1110_n_no_token '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m '"'"'docs: approval token'"'"' > /tmp/log.txt"}}'
t25_mk p_t1110_n_read '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_n_write_other '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo '"'"'docs/working/TASK-0001/approvals/c3.json'"'"' > /tmp/note.txt"}}'
# 先の「後ろ」に引用符が来る形。引用検査を語ではなくレコード全体へ広げると
# この正当な rc=0 が block に化ける（V-3 R-001 推奨案 2 を採らなかった理由の回帰ガード）。
t25_mk p_t1110_n_quote_after '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > /tmp/log.txt && git commit -m '"'"'docs: docs/working/TASK-0001/approvals/c3.json'"'"'"}}'
# 退行防止側（先が実際にトークンパスへ解決される = 真の陽性）
t25_mk p_t1110_w_dotslash '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > ./docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_w_quoted '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > \"docs/working/TASK-0001/approvals/c3.json\""}}'
t25_mk p_t1110_w_spaces '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x >   docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_w_dotdot '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/../TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_w_second '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi > /tmp/a.txt; echo x > docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_w_heredoc '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat > docs/working/TASK-0001/approvals/c3.json <<EOF\n{}\nEOF"}}'
t25_mk p_t1110_w_maint '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/_maintenance/maintenance.json"}}'
# fail-closed 側（先が静的に解決できない）
t25_mk p_t1110_fc_cmdsub '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > $(cat /tmp/p) # docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_fc_var '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > $OUT # docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_fc_glob '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > /tmp/*.json # docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1110_fc_empty '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x >   # docs/working/TASK-0001/approvals/c3.json"}}'
# 切り詰めクラス（V-3 R-001 / critical）: 終端文字を含むトークンパスを引用 /
# バックスラッシュ退避で書いた先。語の切り詰めで非トークンの前半分に化けて
# 通過してはならない。TASK セグメントに終端文字を 1 つ埋めてある。
t25_mk p_t1110_tr_sq_space '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK 0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_dq_space '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > \"docs/working/TASK 0001/approvals/c3.json\""}}'
t25_mk p_t1110_tr_tab '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK\t0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_semi '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK;0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_amp '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK&0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_pipe '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK|0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_lparen '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK(0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_rparen '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK)0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_lt '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK<0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_hash_q '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > '"'"'docs/working/TASK#0001/approvals/c3.json'"'"'"}}'
t25_mk p_t1110_tr_backslash '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK\\\\ 0001/approvals/c3.json"}}'
# `#` は語頭のみコメント開始で語中は通常文字 = 退避不要。終端に含めると取りこぼす。
t25_mk p_t1110_tr_hash_bare '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK#0001/approvals/c3.json"}}'
# レーン非対称の是正（V-3 R-001）: 同一の空白入りパスへ tee / cp / > のどれでも block
t25_mk p_t1110_lane_tee '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x | tee \"/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/c3.json\""}}'
t25_mk p_t1110_lane_cp '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cp /tmp/x \"/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/c3.json\""}}'
t25_mk p_t1110_lane_redirect '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > \"/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/c3.json\""}}'
t25_mk p_t1110_lane_write '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/c3.json","content":"x"}}'
# 改行畳み込み（R-005 / M-D）: heredoc 本文がトークンパスを含み、書き込み先は /tmp。
# 畳み込みが無いと本文行が「先」として評価され誤 block になる。
t25_mk p_t1110_nl_heredoc '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat <<EOF > /tmp/log.txt\ndocs/working/TASK-0001/approvals/c3.json\nEOF"}}'
# focused 群から使う copy-like fixture（通常群の p_t1045_m_cp と同内容 / 定義順の都合で別名）
t25_mk p_t1045_m_cp_early '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cp docs/working/TASK-0001/approvals/c3.json /tmp/x"}}'

# ── TASK-1115 (#1115): glob bypass fixtures ─────────────────────────────
# 保護対象のファイル名リテラルを glob で崩すと `_is_token_path` の文字列照合が
# 外れて外側ゲートごと素通りしていた。展開は shell が行うため実害あり
# （引数レーンは POSIX 必須の pathname expansion で shell 非依存に成立）。
# 正側: redirect レーン（(A)+(B) 双方が該当するもの / (A) のみのもの）
t25_mk p_t1115_g_redirect_star '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/approvals/c3.jso*"}}'
t25_mk p_t1115_g_redirect_q '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/approvals/c3.js?n"}}'
t25_mk p_t1115_g_redirect_brk '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/approvals/c[3].jso*"}}'
# approvals 配下だが保護 basename には一致しない = ルール (A) のみが拾う語
t25_mk p_t1115_g_redirect_other '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/approvals/x9.jso*"}}'
# 正側: 非 redirect レーン（cp / tee / sed -i）。maintenance は approvals 外 = ルール (B) のみ
t25_mk p_t1115_g_cp '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cp /tmp/x docs/working/TASK-0001/approvals/c3.jso*"}}'
t25_mk p_t1115_g_tee '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x | tee docs/working/TASK-0001/approvals/c3.jso*"}}'
t25_mk p_t1115_g_sed '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"sed -i.bak -e s/a/b/ docs/working/TASK-0001/approvals/c3.jso*"}}'
t25_mk p_t1115_g_maint '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/_maintenance/maintenance.jso*"}}'
t25_mk p_t1115_g_parent '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x | tee docs/working/TASK-0001/approvals/parent-integration.js?n"}}'
# 負側: 日常 glob コマンド（block を広げる方向の変異 M-10 の kill 対象）
t25_mk p_t1115_n_cp_schemas '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cp schemas/*.json /tmp/"}}'
t25_mk p_t1115_n_cp_docs '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cp docs/*.md /tmp/"}}'
t25_mk p_t1115_n_sed_status '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"sed -i.bak -e s/a/b/ docs/working/*/status.md"}}'
t25_mk p_t1115_n_sed_apnotes '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"sed -i.bak -e s/a/b/ docs/working/*/approvals-notes.md"}}'
t25_mk p_t1115_n_cp_apnotes '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cp /tmp/x docs/working/*/approvals/notes.md"}}'
# 負側: #1110 の誤検知解消が戻っていないこと（glob 語 + 無関係な redirect でも通る）
t25_mk p_t1115_n_msg_glob '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m '"'"'docs: docs/working/TASK-0001/approvals/c3.jso* handling'"'"' > /tmp/log.txt"}}'
# 負側: 読み取りは block しない（_has_write_intent との AND が保たれている）
t25_mk p_t1115_n_read_glob '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/*/approvals/*.json"}}'
t25_mk p_t1115_n_ls_glob '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls docs/working/*/approvals/"}}'
# 回帰: ディレクトリ側 glob は是正前から block（挙動不変であること）
t25_mk p_t1115_r_dirglob '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/*/approvals/c3.json"}}'
t25_mk p_t1115_r_starjson '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/approvals/*.json"}}'
t25_mk p_t1115_r_brk '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > docs/working/TASK-0001/approvals/c[3].json"}}'

# ── focused kill TC 群（mutation 子プロセスでも常に実行）───────────────────

# T1023-TC-01: env target = maintenance.json → BLOCK rc=2（AC-01）
T25_ENV_FILE="$T25_MAINT"
t25_guard "$T25_TMP/p_normal_write"
if [ "$_t25_rc" = "2" ] && grep -q 'BLOCK' "$T25_ERR" && grep -q 'target=' "$T25_ERR"; then
  t25_pass "T1023-TC-01 env=maintenance.json blocked (exit 2)"
else
  t25_fail "T1023-TC-01 env=maintenance.json not blocked with exit 2 (exit $_t25_rc)"
fi
unset T25_ENV_FILE

# T1023-TC-02b: top-level .file_path のみ（legacy fallback）→ BLOCK rc=2（AC-01）
# 検出 detail（file_path=）まで assert する: fallback 除去 mutation では parse-unknown に
# 化けて rc は 2 のままになるため、rc だけでは変異 7 を kill できない。
t25_guard "$T25_TMP/p_toplevel_token"
if [ "$_t25_rc" = "2" ] && grep -q 'file_path=' "$T25_ERR" && ! grep -q 'parse-unknown' "$T25_ERR"; then
  t25_pass "T1023-TC-02b top-level legacy file_path token blocked as protected-write (exit 2)"
else
  t25_fail "T1023-TC-02b top-level legacy file_path not blocked as protected-write (exit $_t25_rc)"
fi

# T1023-TC-03: env=normal + stdin Bash token write → BLOCK rc=2（AC-02 / defect #2 封鎖）
T25_ENV_FILE="src/index.ts"
t25_guard "$T25_TMP/p_bash_token_write"
if [ "$_t25_rc" = "2" ] && grep -q 'BLOCK' "$T25_ERR"; then
  t25_pass "T1023-TC-03 env-normal + stdin Bash token write blocked (exit 2)"
else
  t25_fail "T1023-TC-03 env-normal + stdin Bash token write not blocked (exit $_t25_rc)"
fi
unset T25_ENV_FILE

# T1023-TC-05: jq 不在 PATH → parse-unknown rc=2（AC-03）
_t25_nojq="$T25_TMP/nojq-bin"
mkdir -p "$_t25_nojq"
for _t25_c in cat grep sh; do
  _t25_src=$(command -v "$_t25_c" 2>/dev/null || true)
  [ -n "$_t25_src" ] && ln -s "$_t25_src" "$_t25_nojq/$_t25_c" 2>/dev/null || true
done
_t25_rc=0
env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 PATH="$_t25_nojq" /bin/sh "$PG_T25_GUARD" < "$T25_TMP/p_normal_write" 2>"$T25_ERR" || _t25_rc=$?
if [ "$_t25_rc" = "2" ] && grep -q 'parse-unknown' "$T25_ERR"; then
  t25_pass "T1023-TC-05 no-jq PATH fails closed (parse-unknown, exit 2)"
else
  t25_fail "T1023-TC-05 no-jq PATH did not fail closed (exit $_t25_rc)"
fi

# T1023-TC-13c-file: env=normal + $1=token + stdin file_path=token → stdin 独立評価で rc=2（AC-06）
T25_ENV_FILE="src/index.ts"
t25_guard "$T25_TMP/p_edit_token" "$T25_TOKEN"
if [ "$_t25_rc" = "2" ] && grep -q 'file_path=' "$T25_ERR"; then
  t25_pass "T1023-TC-13c-file stdin file_path evaluated independently of env target (exit 2)"
else
  t25_fail "T1023-TC-13c-file stdin file_path not evaluated independently (exit $_t25_rc)"
fi
unset T25_ENV_FILE

# T1023-TC-22a: MultiEdit + 通常 file → rc=0（AC-04 / 誤 block しない）
t25_guard "$T25_TMP/p_multiedit_normal"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1023-TC-22a MultiEdit normal file passes (exit 0)"
else
  t25_fail "T1023-TC-22a MultiEdit normal file incorrectly blocked (exit $_t25_rc)"
fi

# T1023-TC-23: TTY stdin は read せず即 rc=2（非ハング）（AC-03 / R-027）
# `script` で疑似端末を与え、watchdog（10 秒）で非ハングを assert する。
# 注意: この 1 箇所だけは stdin redirect を意図的に付けない（TTY を与えるため）— TC-24 で除外。
_t25_tty_run() {
  # $1: PLANGATE_HOOK_FILE value ("" = unset), $2: rc 出力 file
  _t25_tty_rc_file="$2"
  rm -f "$_t25_tty_rc_file"
  cat > "$T25_TMP/tty-runner.sh" <<'EOF_T25_RUNNER'
#!/bin/sh
rc=0
if [ -n "${T25_TTY_ENVFILE:-}" ]; then
  env PLANGATE_SKIP_TOKEN_GUARD=0 PLANGATE_HOOK_FILE="$T25_TTY_ENVFILE" sh "$T25_TTY_GUARD" 2>"$T25_TTY_ERR" || rc=$?  # t25:tty-ok
else
  env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 sh "$T25_TTY_GUARD" 2>"$T25_TTY_ERR" || rc=$?  # t25:tty-ok
fi
printf '%s' "$rc" > "$T25_TTY_RC"
EOF_T25_RUNNER
  if script --version 2>/dev/null | grep -q util-linux; then
    env T25_TTY_GUARD="$PG_T25_GUARD" T25_TTY_ENVFILE="$1" T25_TTY_ERR="$T25_TMP/tty-err.out" T25_TTY_RC="$_t25_tty_rc_file" \
      script -q -e -c "sh $T25_TMP/tty-runner.sh" /dev/null >/dev/null 2>&1 &
  else
    env T25_TTY_GUARD="$PG_T25_GUARD" T25_TTY_ENVFILE="$1" T25_TTY_ERR="$T25_TMP/tty-err.out" T25_TTY_RC="$_t25_tty_rc_file" \
      script -q /dev/null sh "$T25_TMP/tty-runner.sh" >/dev/null 2>&1 &
  fi
  _t25_tty_pid=$!
  _t25_i=0
  _t25_tty_timeout=0
  while [ "$_t25_i" -lt 50 ]; do
    kill -0 "$_t25_tty_pid" 2>/dev/null || break
    sleep 0.2
    _t25_i=$((_t25_i + 1))
  done
  if kill -0 "$_t25_tty_pid" 2>/dev/null; then
    kill "$_t25_tty_pid" 2>/dev/null || true
    _t25_tty_timeout=1
  fi
  wait "$_t25_tty_pid" 2>/dev/null || true
}
if command -v script >/dev/null 2>&1; then
  _t25_tty_run "" "$T25_TMP/tty-rc-normal"
  _t25_rc_a=$(cat "$T25_TMP/tty-rc-normal" 2>/dev/null || printf 'none')
  _t25_to_a="$_t25_tty_timeout"
  _t25_tty_run "$T25_TOKEN" "$T25_TMP/tty-rc-token"
  _t25_rc_b=$(cat "$T25_TMP/tty-rc-token" 2>/dev/null || printf 'none')
  _t25_to_b="$_t25_tty_timeout"
  if [ "$_t25_rc_a" = "2" ] && [ "$_t25_rc_b" = "2" ] && [ "$_t25_to_a" = "0" ] && [ "$_t25_to_b" = "0" ]; then
    t25_pass "T1023-TC-23 TTY stdin fails closed without hanging (exit 2 / exit 2)"
  else
    t25_fail "T1023-TC-23 TTY stdin not fail-closed or hung (rc_normal=$_t25_rc_a rc_token=$_t25_rc_b timeout=$_t25_to_a/$_t25_to_b)"
  fi
else
  t25_fail "T1023-TC-23 'script' command unavailable — TTY non-hang cannot be verified"
fi

# ── TASK-1045: 誤検知の解消（focused 群 / plan GC-4-A）──────────────────
# T1045-TC-01: read-only + 2>/dev/null → rc=0（AC-01）。mutation (a) の kill 対象
t25_guard "$T25_TMP/p_t1045_read_2devnull"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1045-TC-01 read-only with 2>/dev/null passes (exit 0)"
else
  t25_fail "T1045-TC-01 read-only with 2>/dev/null falsely blocked (exit $_t25_rc)"
fi

# T1045-TC-02: read-only + 2>&1 → rc=0（AC-02）
t25_guard "$T25_TMP/p_t1045_read_2and1"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1045-TC-02 read-only with 2>&1 passes (exit 0)"
else
  t25_fail "T1045-TC-02 read-only with 2>&1 falsely blocked (exit $_t25_rc)"
fi

# T1045-TC-03: read-only + >&2（fd 複製）→ rc=0（AC-03）
t25_guard "$T25_TMP/p_t1045_read_gt2"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1045-TC-03 read-only with >&2 fd duplication passes (exit 0)"
else
  t25_fail "T1045-TC-03 read-only with >&2 falsely blocked (exit $_t25_rc)"
fi

# T1045-TC-20: read-only + 3>&-（fd クローズ）→ rc=0（AC-03 適用範囲宣言）
t25_guard "$T25_TMP/p_t1045_read_fdclose"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1045-TC-20 read-only with 3>&- fd close passes (exit 0)"
else
  t25_fail "T1045-TC-20 read-only with 3>&- falsely blocked (exit $_t25_rc)"
fi

# ── TASK-1045: 退行防止 — 真の書き込みは block 維持（focused 群 / plan GC-1）──
# T1045-TC-04: `> <TOKEN>` → rc=2（AC-04）。mutation (b) の kill 対象
t25_guard "$T25_TMP/p_t1045_w_gt"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1045-TC-04 file redirect > token blocked (exit 2)"
else
  t25_fail "T1045-TC-04 file redirect > token not blocked (exit $_t25_rc)"
fi

# T1045-TC-05: `>> <TOKEN>` → rc=2（AC-05）
t25_guard "$T25_TMP/p_t1045_w_append"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1045-TC-05 append redirect >> token blocked (exit 2)"
else
  t25_fail "T1045-TC-05 append redirect >> token not blocked (exit $_t25_rc)"
fi

# T1045-TC-06: `1> <TOKEN>`（fd 番号付き）→ rc=2（AC-06）
t25_guard "$T25_TMP/p_t1045_w_fd1"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1045-TC-06 numbered fd redirect 1> token blocked (exit 2)"
else
  t25_fail "T1045-TC-06 numbered fd redirect 1> token not blocked (exit $_t25_rc)"
fi

# ── TASK-1110 (#1110): リダイレクト先 ↔ トークンパス 相関（focused 群）──────
# T1110-TC-01: 誤検知解消（AC-1）。mutation M-1 の kill 対象。
#   「トークン名を含む文言」と「無関係なリダイレクト」が同居しても block しない。
_t25_ok=1
for _t25_p in p_t1110_n_msg_redirect p_t1110_n_msg_only p_t1110_n_no_token p_t1110_n_read \
              p_t1110_n_quote_after; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "0" ]; then
    _t25_ok=0
    printf '    (T1110-TC-01 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1110-TC-01 token literal + unrelated redirect passes (exit 0)"
else
  t25_fail "T1110-TC-01 token literal + unrelated redirect still falsely blocked"
fi

# T1110-TC-02: トークンパス文字列を「内容として」別ファイルへ書くのは block しない（AC-1）
t25_guard "$T25_TMP/p_t1110_n_write_other"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1110-TC-02 writing the token path as content to another file passes (exit 0)"
else
  t25_fail "T1110-TC-02 writing token path as content falsely blocked (exit $_t25_rc)"
fi

# T1110-TC-03: 真の陽性は block 維持（AC-2）。mutation M-2 の補強。
#   ./ 前置 / 引用 / 空白 / .. 混在 / 複文後段 / heredoc / maintenance を網羅。
_t25_ok=1
for _t25_p in p_t1110_w_dotslash p_t1110_w_quoted p_t1110_w_spaces p_t1110_w_dotdot \
              p_t1110_w_second p_t1110_w_heredoc p_t1110_w_maint; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1110-TC-03 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1110-TC-03 redirect targets resolving to a token path remain blocked (exit 2)"
else
  t25_fail "T1110-TC-03 some real token-path redirect not blocked"
fi

# T1110-TC-04: リダイレクト先が静的に解決できない場合は block 側（AC-3 / fail-closed）
#   コマンド置換 / 変数展開 / glob / 先が空。いずれも「安全側に倒す」ことの機械担保。
_t25_ok=1
for _t25_p in p_t1110_fc_cmdsub p_t1110_fc_var p_t1110_fc_glob p_t1110_fc_empty; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1110-TC-04 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1110-TC-04 unresolvable redirect targets fail closed (exit 2)"
else
  t25_fail "T1110-TC-04 an unresolvable redirect target was not blocked"
fi

# T1110-TC-05: block メッセージが一致したリダイレクト先を示す（AC-4）
t25_guard "$T25_TMP/p_t1045_w_gt"
if [ "$_t25_rc" = "2" ] && grep -q 'rule=file-redirect' "$T25_ERR" \
   && grep -q 'redirect_target=docs/working/TASK-0001/approvals/c3.json' "$T25_ERR"; then
  t25_pass "T1110-TC-05 block detail carries the matched redirect_target"
else
  t25_fail "T1110-TC-05 block detail missing matched redirect_target (exit $_t25_rc)"
fi

# T1110-TC-06: 切り詰めクラスは block（V-3 R-001 / critical）。mutation M-3 の kill 対象。
#   終端文字（空白 / TAB / ; & | ( ) <）を含むトークンパスを引用・退避して書いた先が、
#   語の切り詰めで非トークンの前半分に化けて通過してはならない。
_t25_ok=1
for _t25_p in p_t1110_tr_sq_space p_t1110_tr_dq_space p_t1110_tr_tab p_t1110_tr_semi \
              p_t1110_tr_amp p_t1110_tr_pipe p_t1110_tr_lparen p_t1110_tr_rparen \
              p_t1110_tr_lt p_t1110_tr_hash_q p_t1110_tr_backslash; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1110-TC-06 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1110-TC-06 quoted/escaped token paths containing terminator chars stay blocked (exit 2)"
else
  t25_fail "T1110-TC-06 a truncated redirect target slipped through"
fi

# T1110-TC-07: 語中の `#` は終端でない（V-3 R-001）。mutation M-4 の kill 対象。
#   `#` を終端に含めると、退避不要で書ける `dir#1/<TOKEN>` 形を取りこぼす。
t25_guard "$T25_TMP/p_t1110_tr_hash_bare"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1110-TC-07 bare mid-word '#' in a token path target stays blocked (exit 2)"
else
  t25_fail "T1110-TC-07 mid-word '#' truncated the target and lost the block (exit $_t25_rc)"
fi

# T1110-TC-08: レーン非対称の解消（V-3 R-001）。同一の空白入りトークンパスへ
#   tee / cp / `>` / Write のいずれの経路でも block されること。
_t25_ok=1
for _t25_p in p_t1110_lane_tee p_t1110_lane_cp p_t1110_lane_redirect p_t1110_lane_write; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1110-TC-08 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1110-TC-08 all lanes block the same spaced token path (exit 2)"
else
  t25_fail "T1110-TC-08 lane asymmetry remains for a spaced token path"
fi

# T1110-TC-09: 改行畳み込みの負の対照（R-005 / M-D の kill 対象）。
#   heredoc 本文がトークンパスを含むが書き込み先は /tmp なので通す。
t25_guard "$T25_TMP/p_t1110_nl_heredoc"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1110-TC-09 heredoc body mentioning a token path writes elsewhere (exit 0)"
else
  t25_fail "T1110-TC-09 heredoc body falsely treated as a redirect target (exit $_t25_rc)"
fi

# T1110-TC-10: redirect レーン不成立時に診断値を持ち越さない（R-005 / M-5 の kill 対象）。
#   sed が必ず失敗するシムを与えると相関判定は fail-closed で診断値を立てるが、
#   `>` が無いコマンドでは redirect レーンは不成立。後続の copy-like で block する際に
#   無関係な redirect_target が添えられてはならない。
_t1110_shim="$T25_TMP/t1110-shimsed"
mkdir -p "$_t1110_shim"
for _t1110_c in cat grep sh jq tr; do
  _t1110_src=$(command -v "$_t1110_c" 2>/dev/null || true)
  [ -n "$_t1110_src" ] && ln -sf "$_t1110_src" "$_t1110_shim/$_t1110_c" 2>/dev/null || true
done
printf '#!/bin/sh\nexit 1\n' > "$_t1110_shim/sed"
chmod +x "$_t1110_shim/sed"
_t25_rc=0
env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 PATH="$_t1110_shim" /bin/sh "$PG_T25_GUARD" < "$T25_TMP/p_t1045_m_cp_early" 2>"$T25_ERR" || _t25_rc=$?
if [ "$_t25_rc" = "2" ] && grep -q 'rule=copy-like' "$T25_ERR" && ! grep -q 'redirect_target=' "$T25_ERR"; then
  t25_pass "T1110-TC-10 non-redirect block carries no stale redirect_target (exit 2)"
else
  t25_fail "T1110-TC-10 stale redirect_target leaked into a non-redirect block (exit $_t25_rc)"
fi

# ── TASK-1115 (#1115): glob bypass の封鎖 ────────────────────────────────

# T1115-TC-01: リダイレクト先のファイル名 glob 崩しを block（AC-1）。
#   M-7（レーン全体）/ M-8（ルール (A)）の kill 対象。
_t25_ok=1
for _t25_p in p_t1115_g_redirect_star p_t1115_g_redirect_q p_t1115_g_redirect_brk \
              p_t1115_g_redirect_other; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1115-TC-01 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1115-TC-01 glob-broken token filenames in redirect targets are blocked (exit 2)"
else
  t25_fail "T1115-TC-01 a glob-broken redirect target slipped through"
fi

# T1115-TC-02: 非 redirect レーン（cp / tee / sed -i）も同型に block（AC-2）。
#   M-7（レーン全体）/ M-9（ルール (B)）/ M-11（basename 抽出）の kill 対象。
_t25_ok=1
for _t25_p in p_t1115_g_cp p_t1115_g_tee p_t1115_g_sed p_t1115_g_maint p_t1115_g_parent; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1115-TC-02 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1115-TC-02 argument lanes (cp/tee/sed -i) block glob-broken token filenames (exit 2)"
else
  t25_fail "T1115-TC-02 an argument-lane glob bypass remains"
fi

# T1115-TC-03: 日常 glob コマンドを誤 block しない（AC-5 / 負側）。
#   **block を広げる方向の変異 M-10 は負側 TC でしか殺せない**。
_t25_ok=1
for _t25_p in p_t1115_n_cp_schemas p_t1115_n_cp_docs p_t1115_n_sed_status \
              p_t1115_n_sed_apnotes p_t1115_n_cp_apnotes; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "0" ]; then
    _t25_ok=0
    printf '    (T1115-TC-03 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1115-TC-03 everyday glob commands stay unblocked (exit 0)"
else
  t25_fail "T1115-TC-03 the glob gate widened blocking into everyday commands"
fi

# T1115-TC-04: #1110 の誤検知解消が戻っていない（AC-4 / 負側）。
#   glob 語を含んでも書き込み意図との AND は維持される。
t25_guard "$T25_TMP/p_t1115_n_msg_glob"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1115-TC-04 glob-bearing message + unrelated redirect passes (exit 0)"
else
  t25_fail "T1115-TC-04 #1110 false positive returned via the glob gate (exit $_t25_rc)"
fi

# T1115-TC-05: 読み取りは block しない（AC-3 / 負側）
_t25_ok=1
for _t25_p in p_t1115_n_read_glob p_t1115_n_ls_glob; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "0" ]; then
    _t25_ok=0
    printf '    (T1115-TC-05 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1115-TC-05 glob reads under approvals stay unblocked (exit 0)"
else
  t25_fail "T1115-TC-05 a read-only glob command was blocked"
fi

# T1115-TC-06: block 詳細に glob 候補語が出る
t25_guard "$T25_TMP/p_t1115_g_cp"
if [ "$_t25_rc" = "2" ] && grep -q 'glob_candidate=' "$T25_ERR"; then
  t25_pass "T1115-TC-06 block detail carries the matched glob_candidate"
else
  t25_fail "T1115-TC-06 block detail missing glob_candidate (exit $_t25_rc)"
fi

# T1115-TC-07: ディレクトリ側 glob の既存挙動が不変（回帰 / 是正前も rc=2）
_t25_ok=1
for _t25_p in p_t1115_r_dirglob p_t1115_r_starjson p_t1115_r_brk; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1115-TC-07 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1115-TC-07 directory-side globs remain blocked (exit 2)"
else
  t25_fail "T1115-TC-07 a previously-blocked directory-side glob regressed"
fi

# ── ここから通常モード限定（mutation 子プロセスでは skip）───────────────────
if [ "$PG_T25_FOCUSED" = "0" ]; then

# ── legacy TC-01〜07（TASK-0123。回帰目的を保持、TC-03/04/05 は migration 済み）──

# TC-01: check-approval-token-write.sh が存在・実行可能
if [ -f "$PG_T25_GUARD" ] && [ -x "$PG_T25_GUARD" ]; then
  t25_pass "TC-01 check-approval-token-write.sh exists and is executable"
else
  t25_fail "TC-01 check-approval-token-write.sh missing or not executable"
fi

# TC-02: syntax check
if [ -f "$PG_T25_GUARD" ] && sh -n "$PG_T25_GUARD" 2>/dev/null; then
  t25_pass "TC-02 check-approval-token-write.sh syntax ok"
else
  t25_fail "TC-02 check-approval-token-write.sh missing or syntax error"
fi

# TC-03: maintenance.json パスへの write を検知して block
# migration（TASK-1023 / R-027）: 期待 rc 1→2、stdin は < /dev/null を明示
_tc03_exit=0
env PLANGATE_SKIP_TOKEN_GUARD=0 PLANGATE_HOOK_FILE="docs/working/_maintenance/maintenance.json" sh "$PG_T25_GUARD" < /dev/null 2>/dev/null || _tc03_exit=$?
if [ "$_tc03_exit" = "2" ]; then
  t25_pass "TC-03 maintenance.json path blocked (exit 2)"
else
  t25_fail "TC-03 maintenance.json path not blocked with exit 2 (exit $_tc03_exit)"
fi

# TC-04: approvals/c3.json パスへの write を検知して block（migration: rc 1→2、< /dev/null）
_tc04_exit=0
env PLANGATE_SKIP_TOKEN_GUARD=0 PLANGATE_HOOK_FILE="docs/working/TASK-0001/approvals/c3.json" sh "$PG_T25_GUARD" < /dev/null 2>/dev/null || _tc04_exit=$?
if [ "$_tc04_exit" = "2" ]; then
  t25_pass "TC-04 approvals/c3.json path blocked (exit 2)"
else
  t25_fail "TC-04 approvals/c3.json not blocked with exit 2 (exit $_tc04_exit)"
fi

# TC-05: 通常ファイルは通過（exit 0）
# migration（TASK-1023）: empty stdin 許可は安全側契約と両立しないため、valid normal
# PreToolUse payload を supply する形へ変更（normal file を許可する回帰目的は維持）
_tc05_exit=0
env PLANGATE_SKIP_TOKEN_GUARD=0 PLANGATE_HOOK_FILE="src/index.ts" sh "$PG_T25_GUARD" < "$T25_TMP/p_normal_write" 2>/dev/null || _tc05_exit=$?
if [ "$_tc05_exit" = "0" ]; then
  t25_pass "TC-05 normal file passes (exit 0)"
else
  t25_fail "TC-05 normal file incorrectly blocked (exit $_tc05_exit)"
fi

# TC-06: schemas/maintenance.schema.json に hmac_signature フィールド存在
_tc06_result=$(python3 -c "
import json, sys
try:
    d = json.load(open('$PG_T25_SCHEMA'))
    if 'hmac_signature' in d.get('properties', {}):
        print('present')
    else:
        print('missing')
except Exception as e:
    print('error:' + str(e))
" 2>/dev/null || echo "error")
if [ "$_tc06_result" = "present" ]; then
  t25_pass "TC-06 hmac_signature field present in maintenance.schema.json"
elif [ "$_tc06_result" = "missing" ]; then
  pass=$((pass + 1)); printf '  [SKIP] TC-06 hmac_signature not yet in schema (HO patch unapplied — SKIP)\n'
else
  t25_fail "TC-06 maintenance.schema.json read error: $_tc06_result"
fi

# TC-07: apply-task-0123-patches.sh が存在・syntax check
if [ -f "$PG_T25_PATCH" ] && sh -n "$PG_T25_PATCH" 2>/dev/null; then
  t25_pass "TC-07 apply-task-0123-patches.sh exists and syntax ok"
else
  t25_fail "TC-07 apply-task-0123-patches.sh missing or syntax error"
fi

# ── T1023 追加 TC（通常モード）───────────────────────────────

# T1023-TC-02a: stdin .tool_input.file_path=token のみ → rc=2（AC-01）
t25_guard "$T25_TMP/p_edit_token"
if [ "$_t25_rc" = "2" ] && grep -q 'file_path=' "$T25_ERR"; then
  t25_pass "T1023-TC-02a tool_input.file_path token blocked (exit 2)"
else
  t25_fail "T1023-TC-02a tool_input.file_path token not blocked (exit $_t25_rc)"
fi

# T1023-TC-04: env=normal + 複数行/quote 混じり tee maintenance.json → rc=2（AC-02,05）
T25_ENV_FILE="docs/notes/readme.md"
t25_guard "$T25_TMP/p_bash_tee_maint"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1023-TC-04 multiline tee maintenance.json blocked (exit 2)"
else
  t25_fail "T1023-TC-04 multiline tee maintenance.json not blocked (exit $_t25_rc)"
fi
unset T25_ENV_FILE

# T1023-TC-06a: malformed / truncated / empty stdin → 各 parse-unknown rc=2（AC-03）
_t25_ok=1
for _t25_p in p_malformed p_truncated p_empty; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ] || ! grep -q 'parse-unknown' "$T25_ERR"; then
    _t25_ok=0
    printf '    (TC-06a detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-06a malformed/truncated/empty stdin fail closed (exit 2)"
else
  t25_fail "T1023-TC-06a malformed/truncated/empty stdin not fail-closed"
fi

# T1023-TC-06b: stdin read error → rc=2（AC-03）
# 刺激はディレクトリを stdin にする（cat が決定論的に read error / EISDIR になる）。
# `0<&-`（fd close）は closed fd0 が後続 open に再割当されて guard がハングする
# 環境があるため使わない（本 worktree で実測ハング）。
_t25_rc=0
env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 sh "$PG_T25_GUARD" < "$T25_TMP" 2>"$T25_ERR" || _t25_rc=$?
if [ "$_t25_rc" = "2" ] && grep -q 'parse-unknown' "$T25_ERR"; then
  t25_pass "T1023-TC-06b unreadable stdin (directory) fails closed (exit 2)"
else
  t25_fail "T1023-TC-06b unreadable stdin not fail-closed (exit $_t25_rc)"
fi

# T1023-TC-07: JSON escaped slash payload → decode 後の実 path で判定 rc=2（AC-03）
t25_guard "$T25_TMP/p_escaped_token"
if [ "$_t25_rc" = "2" ] && grep -q 'file_path=' "$T25_ERR"; then
  t25_pass "T1023-TC-07 escaped-slash token path decoded and blocked (exit 2)"
else
  t25_fail "T1023-TC-07 escaped-slash token path not blocked (exit $_t25_rc)"
fi

# T1023-TC-07b: {} / tool_input 欠落 / null / array / number / 未知 tool / 別 event → 各 rc=2（AC-03）
_t25_ok=1
for _t25_p in p_empty_obj p_no_tool_input p_null_fp p_array_fp p_number_fp p_unknown_tool p_wrong_event; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ] || ! grep -q 'parse-unknown' "$T25_ERR"; then
    _t25_ok=0
    printf '    (TC-07b detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-07b structurally invalid payloads fail closed (exit 2)"
else
  t25_fail "T1023-TC-07b structurally invalid payloads not fail-closed"
fi

# T1023-TC-08: token path の read-only cat → rc=0（AC-04）
t25_guard "$T25_TMP/p_bash_token_read"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1023-TC-08 read-only cat of token path passes (exit 0)"
else
  t25_fail "T1023-TC-08 read-only cat of token path incorrectly blocked (exit $_t25_rc)"
fi

# T1023-TC-09: token read + 別 file write の混在 → rc=0
# 期待値変更（TASK-1110 / #1110）: 旧仕様は「相関解析しない」ため rc=2 だったが、
# これは本 issue が是正した誤検知クラスそのもの（トークン名は読み取りに出るだけで、
# リダイレクト先は /tmp/other.txt）。トークンパス宛の書き込みは
# T1110-TC-03 / T1045-TC-04〜06 が引き続き block を担保する。
# ⚠️ 本 TC は TASK-1023 pbi-input AC-04「token path と別 write を混在させた command は
# 安全側 block を仕様とする」を redirect レーンに限り上書きする。V-3 R-003 の指摘どおり
# 当初 plan では宣言漏れだったため、TASK-1110 の pbi-input / plan / test-cases へ
# 明示的に追加し、**AC 上書きの可否そのものを Human C-3 の判断事項**として立てている。
t25_guard "$T25_TMP/p_bash_mixed"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1023-TC-09 mixed token-read + unrelated-file-write passes (exit 0, #1110)"
else
  t25_fail "T1023-TC-09 mixed token-read + unrelated-file-write falsely blocked (exit $_t25_rc)"
fi

# T1023-TC-10: normal file への Edit / Write / Bash write → 各 rc=0（AC-04）
_t25_ok=1
for _t25_p in p_normal_write p_bash_normal_write; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "0" ]; then
    _t25_ok=0
    printf '    (TC-10 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-10 normal writes pass (exit 0)"
else
  t25_fail "T1023-TC-10 normal writes incorrectly blocked"
fi

# T1023-TC-11: 非 TTY での bin/plangate approve / maintenance start は CLI 側で拒否（AC-04）
# sandbox（mktemp）へ bin と最小 TASK を複製して実行し、実 repo の audit artifact 不変を確認
_t25_sbx=$(mktemp -d "${TMPDIR:-/tmp}/pg-t25-sbx.XXXXXX")
register_cleanup "$_t25_sbx"
mkdir -p "$_t25_sbx/bin" "$_t25_sbx/docs/working/TASK-0001"
cp "$PG_T25_ROOT/bin/plangate" "$_t25_sbx/bin/plangate"
chmod +x "$_t25_sbx/bin/plangate"
printf '# minimal plan\n' > "$_t25_sbx/docs/working/TASK-0001/plan.md"
_t25_audit_before=$(find "$PG_T25_ROOT/docs/working/_audit" -type f -exec cat {} + 2>/dev/null | cksum)
_t25_rc_ap=0
( cd "$_t25_sbx" && env -u PLANGATE_BYPASS_HOOK sh bin/plangate approve TASK-0001 < /dev/null ) >/dev/null 2>&1 || _t25_rc_ap=$?
_t25_rc_mt=0
( cd "$_t25_sbx" && env -u PLANGATE_BYPASS_HOOK sh bin/plangate maintenance start --reason t --paths x --minutes 5 < /dev/null ) >/dev/null 2>&1 || _t25_rc_mt=$?
_t25_audit_after=$(find "$PG_T25_ROOT/docs/working/_audit" -type f -exec cat {} + 2>/dev/null | cksum)
if [ "$_t25_rc_ap" != "0" ] && [ "$_t25_rc_mt" != "0" ] \
  && [ ! -f "$_t25_sbx/docs/working/TASK-0001/approvals/c3.json" ] \
  && [ ! -f "$_t25_sbx/docs/working/_maintenance/maintenance.json" ] \
  && [ "$_t25_audit_before" = "$_t25_audit_after" ]; then
  t25_pass "T1023-TC-11 non-TTY approve/maintenance rejected by CLI, no artifact, real audit unchanged"
else
  t25_fail "T1023-TC-11 non-TTY CLI check failed (approve=$_t25_rc_ap maint=$_t25_rc_mt)"
fi

# T1023-TC-12: 代表 write surface（apply_patch / patch / node / perl / ruby）→ 各 rc=2（AC-05）
t25_mk p_sf_apply_patch '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"apply_patch <<PATCH\n*** Update File: docs/working/TASK-0001/approvals/c3.json\n+{}\nPATCH"}}'
t25_mk p_sf_patch '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"patch docs/working/TASK-0001/approvals/c3.json <<EOF\n@@\nEOF"}}'
t25_mk p_sf_node '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"node -e \"require('\''fs'\'').writeFileSync('\''docs/working/TASK-0001/approvals/c3.json'\'','\''{}'\'')\""}}'
t25_mk p_sf_perl_open '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"perl -e \"open(F, '\''>'\'', '\''docs/working/TASK-0001/approvals/c3.json'\''); print F 1;\""}}'
t25_mk p_sf_perl_pi '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"perl -pi -e \"s/REJECTED/APPROVED/\" docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_sf_ruby '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ruby -e \"File.write('\''docs/working/TASK-0001/approvals/c3.json'\'', '\''{}'\'')\""}}'
_t25_ok=1
for _t25_p in p_sf_apply_patch p_sf_patch p_sf_node p_sf_perl_open p_sf_perl_pi p_sf_ruby; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (TC-12 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-12 representative write surfaces blocked per-surface (exit 2)"
else
  t25_fail "T1023-TC-12 some representative write surface not blocked"
fi

# T1023-TC-25: ed / ex 経由の token 書込 → 各 rc=2（V-3 実測 bypass の封鎖）
t25_mk p_v3_ed '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf \",s/REJECTED/APPROVED/\\nw\\nq\\n\" | ed -s docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_v3_ex '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ex -sc \"%s/REJECTED/APPROVED/|wq\" docs/working/TASK-0001/approvals/c3.json"}}'
_t25_ok=1
for _t25_p in p_v3_ed p_v3_ex; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (TC-25 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-25 ed/ex token writes blocked (exit 2)"
else
  t25_fail "T1023-TC-25 some ed/ex token write not blocked"
fi

# T1023-TC-26: git checkout/restore/checkout-index/update-index 経由の token 復元 → 各 rc=2
# （V-3 実測 bypass の封鎖。-C 等の中間オプションも捕捉）
t25_mk p_v3_git_co '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout HEAD~1 -- docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_v3_git_restore '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git restore --source=HEAD~1 -- docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_v3_git_coidx '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout-index -f -- docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_v3_git_upidx '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git update-index --cacheinfo 100644,deadbeef,docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_v3_git_c_opt '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git -C . checkout HEAD~1 -- docs/working/TASK-0001/approvals/c3.json"}}'
_t25_ok=1
for _t25_p in p_v3_git_co p_v3_git_restore p_v3_git_coidx p_v3_git_upidx p_v3_git_c_opt; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (TC-26 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-26 git checkout/restore/checkout-index/update-index token writes blocked (exit 2)"
else
  t25_fail "T1023-TC-26 some git token-restore path not blocked"
fi

# T1023-TC-27: 負ケース — token パス非参照の ed / git は誤 block しない（各 rc=0）
t25_mk p_v3_neg_git_main '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout main"}}'
t25_mk p_v3_neg_git_file '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git restore -- src/index.ts"}}'
t25_mk p_v3_neg_ed_file '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf \"w\\nq\\n\" | ed -s src/index.ts"}}'
t25_mk p_v3_neg_git_log '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git log --oneline -- docs/working/TASK-0001/approvals/c3.json"}}'
_t25_ok=1
for _t25_p in p_v3_neg_git_main p_v3_neg_git_file p_v3_neg_ed_file p_v3_neg_git_log; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "0" ]; then
    _t25_ok=0
    printf '    (TC-27 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-27 non-token ed/git commands pass; token-path read-only git log passes (exit 0)"
else
  t25_fail "T1023-TC-27 negative ed/git cases incorrectly blocked"
fi

# T1023-TC-13a: env 空 + $1=token + parsed-safe normal stdin → fallback target で rc=2（AC-06）
T25_ENV_FILE=""
t25_guard "$T25_TMP/p_normal_write" "$T25_TOKEN"
if [ "$_t25_rc" = "2" ] && grep -q 'target=' "$T25_ERR"; then
  t25_pass "T1023-TC-13a empty env + \$1 token blocked via fallback (exit 2)"
else
  t25_fail "T1023-TC-13a \$1 fallback target not blocked (exit $_t25_rc)"
fi
unset T25_ENV_FILE

# T1023-TC-13b: env=normal + $1=token + normal stdin → env 優先で rc=0（AC-06）
T25_ENV_FILE="src/index.ts"
t25_guard "$T25_TMP/p_normal_write" "$T25_TOKEN"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1023-TC-13b env target takes precedence over \$1 (exit 0)"
else
  t25_fail "T1023-TC-13b env precedence broken (exit $_t25_rc)"
fi
unset T25_ENV_FILE

# T1023-TC-13c-cmd: env=normal + $1=token + stdin Bash token write → rc=2（AC-06 / Bash レーン独立評価）
T25_ENV_FILE="src/index.ts"
t25_guard "$T25_TMP/p_bash_token_write" "$T25_TOKEN"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1023-TC-13c-cmd stdin Bash command evaluated independently (exit 2)"
else
  t25_fail "T1023-TC-13c-cmd stdin Bash command not evaluated independently (exit $_t25_rc)"
fi
unset T25_ENV_FILE

# T1023-TC-14a: hook process への bypass=1 継承 → rc=0 + secret 非表示の診断（AC-06）
_t25_rc=0
env PLANGATE_SKIP_TOKEN_GUARD=1 PLANGATE_HOOK_FILE="$T25_TOKEN" sh "$PG_T25_GUARD" < "$T25_TMP/p_edit_token" 2>"$T25_ERR" || _t25_rc=$?
if [ "$_t25_rc" = "0" ] && grep -q 'bypass' "$T25_ERR" && ! grep -q "$T25_TOKEN" "$T25_ERR"; then
  t25_pass "T1023-TC-14a inherited bypass allows with diagnostic, no secret echo (exit 0)"
else
  t25_fail "T1023-TC-14a bypass diagnostic contract broken (exit $_t25_rc)"
fi

# T1023-TC-14b: command 文字列内の bypass 代入は無効（hook env は 0）→ rc=2（AC-06）
t25_guard "$T25_TMP/p_bash_env_bypass_string"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1023-TC-14b in-command bypass string does not bypass (exit 2)"
else
  t25_fail "T1023-TC-14b in-command bypass string bypassed the guard (exit $_t25_rc)"
fi

# T1023-TC-14c: 親 env に bypass=1 が漏れていても command-scoped =0 の assertion は無効化されない
_t25_rc=0
(
  PLANGATE_SKIP_TOKEN_GUARD=1
  export PLANGATE_SKIP_TOKEN_GUARD
  env PLANGATE_SKIP_TOKEN_GUARD=0 PLANGATE_HOOK_FILE="$T25_MAINT" sh "$PG_T25_GUARD" < /dev/null 2>/dev/null
) || _t25_rc=$?
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1023-TC-14c command-scoped SKIP=0 overrides inherited bypass (exit 2)"
else
  t25_fail "T1023-TC-14c inherited bypass leaked into assertion (exit $_t25_rc)"
fi

# T1023-TC-22b: MultiEdit + token file_path → rc=2（AC-01）
t25_guard "$T25_TMP/p_multiedit_token"
if [ "$_t25_rc" = "2" ] && grep -q 'file_path=' "$T25_ERR"; then
  t25_pass "T1023-TC-22b MultiEdit token file_path blocked (exit 2)"
else
  t25_fail "T1023-TC-22b MultiEdit token file_path not blocked (exit $_t25_rc)"
fi

# T1023-TC-22c: 本文に token path 文字列を含む通常ファイル編集（MultiEdit / Edit）→ 各 rc=0（AC-04 / M-3）
_t25_ok=1
for _t25_p in p_multiedit_token_in_body p_edit_token_in_body; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "0" ]; then
    _t25_ok=0
    printf '    (TC-22c detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1023-TC-22c token-path string in body does not block normal-file edits (exit 0)"
else
  t25_fail "T1023-TC-22c content-based false positive detected"
fi

# T1023-TC-24: stdin を redirect しない guard 起動が残っていない（AC-10 / R-027 静的検査）
# 対象 = このファイル内の `sh "$PG_T25_GUARD"` 起動行。TTY TC（# t25:tty-ok）だけを除外。
_t25_viol=$(grep -n 'sh "\$PG_T25_GUARD"' "$PG_T25_SELF" | grep -v 't25:tty-ok' | grep -v 't25:stdin-ok' | grep -v '< ' || true)
if [ -z "$_t25_viol" ]; then
  t25_pass "T1023-TC-24 no guard invocation without stdin redirect"
else
  t25_fail "T1023-TC-24 unredirected guard invocations remain: $_t25_viol"
fi

# T1023-TC-20: legacy 保持 + standalone rc 伝播（AC-10）
_t25_ok=1
for _t25_id in "TC-01 " "TC-02 " "TC-03 " "TC-04 " "TC-05 " "TC-06 " "TC-07 "; do
  grep -q "$_t25_id" "$PG_T25_SELF" || _t25_ok=0
done
if [ "${PG_T25_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] T1023-TC-20 standalone-rc 子プロセス（再帰防止モードでは省略）\n'
  pass=$((pass + 1))
else
  _t25_child_out="$T25_TMP/tc20-child.out"
  _t25_child_rc=0
  env -u PG_HARNESS_SOURCED -u FIXTURES_DIR PG_T25_MUTATION_CHILD=1 PG_T25_NO_RECURSE=1 \
    PG_T25_GUARD="$T25_TMP/nonexistent-guard.sh" sh "$PG_T25_SELF" > "$_t25_child_out" 2>&1 || _t25_child_rc=$?
  if [ "$_t25_ok" = "1" ] && [ "$_t25_child_rc" != "0" ] && grep -q 'TA-25 standalone:' "$_t25_child_out"; then
    t25_pass "T1023-TC-20 legacy TCs retained + standalone failure propagates non-zero rc"
  else
    t25_fail "T1023-TC-20 legacy retention or standalone rc propagation broken (child rc=$_t25_child_rc legacy=$_t25_ok)"
  fi
fi

# ── TASK-1045: 除外条件の細工・境界（通常群 / plan R-3・R-4・U-1・U-2・GC-2）──
# 除外は「fd 複製 / クローズ」と「/dev/null 破棄（語境界つき）」の列挙のみ。
# 下記はいずれも除外に該当せず block 維持でなければならない（GC-1 の機械担保）。
t25_mk p_t1045_b_devstdout '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json > /dev/stdout"}}'
t25_mk p_t1045_b_devstderr '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json > /dev/stderr"}}'
t25_mk p_t1045_b_devfd3 '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json > /dev/fd/3"}}'
t25_mk p_t1045_b_nullx '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json 2>/dev/nullX"}}'
t25_mk p_t1045_b_nullpath '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json > /dev/null/../docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1045_b_amp_file '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json &> /tmp/o"}}'
t25_mk p_t1045_b_amp_append '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json &>> /tmp/o"}}'
t25_mk p_t1045_b_amp_null '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json &> /dev/null"}}'
t25_mk p_t1045_b_gtamp_file '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/TASK-0001/approvals/c3.json >& /tmp/o"}}'
t25_mk p_t1045_b_literal '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo (a > b) docs/working/TASK-0001/approvals/c3.json"}}'

# T1045-TC-11: /dev/stdout / /dev/stderr / /dev/fd/N は除外しない（AC-06 / U-1）
_t25_ok=1
for _t25_p in p_t1045_b_devstdout p_t1045_b_devstderr p_t1045_b_devfd3; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1045-TC-11 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1045-TC-11 pseudo-device redirects remain blocked (exit 2)"
else
  t25_fail "T1045-TC-11 pseudo-device redirect not blocked"
fi

# T1045-TC-12: /dev/nullX（語境界を満たさない類似名）→ rc=2（AC-04 / R-3）
t25_guard "$T25_TMP/p_t1045_b_nullx"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1045-TC-12 /dev/nullX lookalike remains blocked (exit 2)"
else
  t25_fail "T1045-TC-12 /dev/nullX lookalike not blocked (exit $_t25_rc)"
fi

# T1045-TC-13: /dev/null/../<TOKEN>（パス細工）→ rc=2（AC-04 / R-3）
t25_guard "$T25_TMP/p_t1045_b_nullpath"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1045-TC-13 /dev/null path-traversal trick remains blocked (exit 2)"
else
  t25_fail "T1045-TC-13 /dev/null path-traversal trick not blocked (exit $_t25_rc)"
fi

# T1045-TC-14: &> / &>> は /dev/null 宛でも block 維持（AC-04 / U-2 の確定）
# (3) の &> /dev/null は「残存誤検知」を意図的に固定するケース（handoff の既知課題）
_t25_ok=1
for _t25_p in p_t1045_b_amp_file p_t1045_b_amp_append p_t1045_b_amp_null; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1045-TC-14 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1045-TC-14 &> / &>> remain blocked incl. /dev/null target (exit 2)"
else
  t25_fail "T1045-TC-14 some &> form not blocked"
fi

# T1045-TC-15: `>&` の直後がファイル名なら除外しない（AC-04 / R-4）
t25_guard "$T25_TMP/p_t1045_b_gtamp_file"
if [ "$_t25_rc" = "2" ]; then
  t25_pass "T1045-TC-15 >& <file> remains blocked (exit 2)"
else
  t25_fail "T1045-TC-15 >& <file> not blocked (exit $_t25_rc)"
fi

# T1045-TC-19: 文字列リテラル中の `>` → rc=0
# 期待値変更（TASK-1110 / #1110）: 旧仕様は保守的 block（GC-2 の取りこぼしを
# 明示固定）だったが、`echo (a > b) <TOKEN>` はリダイレクト先が `b` であり
# トークンパスに解決されない = 本 issue の是正対象クラス（ケース A と同型）。
# 解決不能な先（$ / glob / 空）は引き続き block されることを T1110-TC-04 が担保する。
# TASK-1045 handoff K-2 が本ケースを「minor（残存誤検知）」と自己分類しており、
# 反転は意図的仕様の無断変更ではない（TASK-1110 pbi-input / plan / test-cases で事前宣言）。
# なお TASK-1045 plan SC-6（TC-11〜15 / TC-19 が rc=0 になったら critical 停止）は
# **TASK-1045 exec 中の停止条件**であって後続 PBI を縛らない。#1110 は同じ真の陽性を
# 「先がトークンパスに解決されるか」という別経路で維持しており、TC-11〜15 は本 PR でも
# rc=2 のまま（V-3 実測 / T1045-TC-11〜15 が継続 PASS）。V-3 R-004 反映。
t25_guard "$T25_TMP/p_t1045_b_literal"
if [ "$_t25_rc" = "0" ]; then
  t25_pass "T1045-TC-19 '>' inside a string literal no longer over-blocks (exit 0, #1110)"
else
  t25_fail "T1045-TC-19 literal '>' still over-blocked (exit $_t25_rc)"
fi

# ── TASK-1045: 併記による回避の非成立（通常群 / plan N-5 / AC-07）──
# (2)(3)(4) は `>` を含まないため copy-like ルールが単独で捕捉していることを示す
t25_mk p_t1045_m_nullthen_cp '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls > /dev/null ; cp docs/working/TASK-0001/approvals/c3.json /tmp/x"}}'
t25_mk p_t1045_m_cp '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cp docs/working/TASK-0001/approvals/c3.json /tmp/x"}}'
t25_mk p_t1045_m_tee '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x | tee docs/working/TASK-0001/approvals/c3.json"}}'
t25_mk p_t1045_m_mv '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"mv /tmp/x docs/working/TASK-0001/approvals/c3.json"}}'
_t25_ok=1
for _t25_p in p_t1045_m_nullthen_cp p_t1045_m_cp p_t1045_m_tee p_t1045_m_mv; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ]; then
    _t25_ok=0
    printf '    (T1045-TC-07 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1045-TC-07 multi-defense: /dev/null discard does not enable copy-like evasion (exit 2)"
else
  t25_fail "T1045-TC-07 multi-defense broken — a copy-like evasion passed"
fi

# ── TASK-1045: AC-12 起点の read-only 監査コマンドが通過する（通常群）──
t25_mk p_t1045_ro_find '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"find docs/working -name c3.json -type f 2>/dev/null"}}'
t25_mk p_t1045_ro_grep '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"grep -l c3_status docs/working/TASK-0001/approvals/c3.json 2>/dev/null"}}'
t25_mk p_t1045_ro_jq '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"jq -r .c3_status docs/working/TASK-0001/approvals/c3.json 2>/dev/null"}}'
t25_mk p_t1045_ro_gitlog '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git log --oneline -- docs/working/TASK-0001/approvals/c3.json 2>/dev/null"}}'
t25_mk p_t1045_ro_maint '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat docs/working/_maintenance/maintenance.json 2>/dev/null"}}'
_t25_ok=1
for _t25_p in p_t1045_ro_find p_t1045_ro_grep p_t1045_ro_jq p_t1045_ro_gitlog p_t1045_ro_maint; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "0" ]; then
    _t25_ok=0
    printf '    (T1045-TC-17 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1045-TC-17 read-only audit commands with 2>/dev/null pass (exit 0)"
else
  t25_fail "T1045-TC-17 some read-only audit command still falsely blocked"
fi

# T1045-TC-08: block メッセージのルール識別子（AC-10）
# 読み取りコマンドは AC-01〜03 で通過するため block ケースで assert する。
_t25_ok=1
t25_guard "$T25_TMP/p_t1045_w_gt"
if [ "$_t25_rc" != "2" ] || ! grep -q 'rule=file-redirect' "$T25_ERR" || ! grep -q 'BLOCK' "$T25_ERR"; then
  _t25_ok=0
  printf '    (T1045-TC-08 detail: file-redirect exit=%s)\n' "$_t25_rc" >&2
fi
for _t25_p in p_t1045_m_cp p_t1045_m_tee p_t1045_m_mv; do
  t25_guard "$T25_TMP/$_t25_p"
  if [ "$_t25_rc" != "2" ] || ! grep -q 'rule=copy-like' "$T25_ERR"; then
    _t25_ok=0
    printf '    (T1045-TC-08 detail: %s exit=%s)\n' "$_t25_p" "$_t25_rc" >&2
  fi
done
if [ "$_t25_ok" = "1" ]; then
  t25_pass "T1045-TC-08 block detail carries rule=<id> (file-redirect / copy-like)"
else
  t25_fail "T1045-TC-08 block detail missing or wrong rule=<id>"
fi

# T1045-TC-18: guard の syntax / 実行可能属性（AC-13）
if [ -x "$PG_T25_GUARD" ] && sh -n "$PG_T25_GUARD" 2>/dev/null; then
  t25_pass "T1045-TC-18 guard is executable and syntax-clean"
else
  t25_fail "T1045-TC-18 guard not executable or has syntax error"
fi

# T1045-TC-16: 既存スイート突合（AC-11）
# (a) 退行検出のため既存 TC ラベルの存在を静的に確認
# (b) 原本 guard で通常群フル実行（PG_T25_NO_RECURSE=1 の子）が 0 failed であること
_t25_ok=1
for _t25_id in "T1023-TC-08 " "T1023-TC-09 " "T1023-TC-12 " "T1023-TC-25 " "T1023-TC-26 " "T1023-TC-27 " "T1023-TC-15pre " "T1023-TC-17post "; do
  grep -q "$_t25_id" "$PG_T25_SELF" || _t25_ok=0
done
if [ "${PG_T25_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] T1045-TC-16 suite cross-check（再帰防止モードでは省略）\n'
  pass=$((pass + 1))
else
  _t1045_s16_out="$T25_TMP/t1045-tc16-child.out"
  _t1045_s16_rc=0
  env -u PG_HARNESS_SOURCED -u FIXTURES_DIR PG_T25_NO_RECURSE=1 \
    PG_T25_GUARD="$PG_T25_ROOT/scripts/check-approval-token-write.sh" sh "$PG_T25_SELF" > "$_t1045_s16_out" 2>&1 || _t1045_s16_rc=$?
  if [ "$_t25_ok" = "1" ] && [ "$_t1045_s16_rc" = "0" ] && ! grep -q '\[FAIL\]' "$_t1045_s16_out"; then
    t25_pass "T1045-TC-16 existing suite labels retained and full non-mutation run is 0 failed"
  else
    t25_fail "T1045-TC-16 suite cross-check failed (labels=$_t25_ok child rc=$_t1045_s16_rc)"
  fi
fi

# ── TASK-1045: 正規化ヘルパの fail-closed（通常群 / plan GC-8 / R-002・R-009・R-013）──
# 1 要件 1 TC: TC-22 は (ii) command -v sed のみ、TC-22b は (i) fail-closed フォールバックのみを撃つ。
# (i) が欠けた build では TC-22 は rc=2 で PASS してしまうため、TC-22b が (i) の唯一の担保。
_t1045_mkpath() {
  # $1: 作成先 dir。cat/grep/sh/jq のみを symlink する（sed は入れない）
  mkdir -p "$1"
  for _t1045_c in cat grep sh jq; do
    _t1045_src=$(command -v "$_t1045_c" 2>/dev/null || true)
    [ -n "$_t1045_src" ] && ln -s "$_t1045_src" "$1/$_t1045_c" 2>/dev/null || true
  done
}

# T1045-TC-22: sed 不在 PATH → parse-unknown "sed not available" rc=2（要件 (ii)）
_t1045_nosed="$T25_TMP/nosed-bin"
_t1045_mkpath "$_t1045_nosed"
_t25_rc=0
env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 PATH="$_t1045_nosed" /bin/sh "$PG_T25_GUARD" < "$T25_TMP/p_bash_token_write" 2>"$T25_ERR" || _t25_rc=$?
if [ "$_t25_rc" = "2" ] && grep -q 'sed not available' "$T25_ERR"; then
  t25_pass "T1045-TC-22 no-sed PATH fails closed with 'sed not available' (exit 2)"
else
  t25_fail "T1045-TC-22 no-sed PATH did not fail closed with expected reason (exit $_t25_rc)"
fi

# T1045-TC-22b: sed は存在するが必ず失敗するシム → 元文字列で判定して通常 block rc=2（要件 (i)）
# フォールバックは設計上サイレントなので sed 起因の reason は出ない（R-013）。
# parse-unknown を含まないことまで assert しないと、別経路の rc=2 で偽 PASS になる（ta-25:118 と同型）。
_t1045_shimsed="$T25_TMP/shimsed-bin"
_t1045_mkpath "$_t1045_shimsed"
printf '#!/bin/sh\nexit 1\n' > "$_t1045_shimsed/sed"
chmod +x "$_t1045_shimsed/sed"
_t25_rc=0
env -u PLANGATE_HOOK_FILE PLANGATE_SKIP_TOKEN_GUARD=0 PATH="$_t1045_shimsed" /bin/sh "$PG_T25_GUARD" < "$T25_TMP/p_bash_token_write" 2>"$T25_ERR" || _t25_rc=$?
if [ "$_t25_rc" = "2" ] && grep -q 'Bash command writes token path' "$T25_ERR" && ! grep -q 'parse-unknown' "$T25_ERR"; then
  t25_pass "T1045-TC-22b failing-sed shim falls back to raw string and blocks (exit 2, no parse-unknown)"
else
  t25_fail "T1045-TC-22b failing-sed shim did not fail closed via normal block (exit $_t25_rc)"
fi

# ── T1023-TC-15〜17e: mutation 7 種（AC-07 / R-029: 実 TC の FAIL で kill を判定）──
if [ "${PG_T25_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] T1023-TC-15..17e mutation（再帰防止モードでは省略・親で実行）\n'
  pass=$((pass + 1))
else
  _t25_mut_dir=$(mktemp -d "${TMPDIR:-/tmp}/pg-t25-mut.XXXXXX")
  register_cleanup "$_t25_mut_dir"
  # baseline: 原本 guard で focused kill TC 群が全 PASS すること（復元 PASS も同一原本で担保）
  _t25_base_out="$_t25_mut_dir/baseline.out"
  _t25_base_rc=0
  env -u PG_HARNESS_SOURCED -u FIXTURES_DIR PG_T25_MUTATION_CHILD=1 PG_T25_NO_RECURSE=1 \
    PG_T25_GUARD="$PG_T25_ROOT/scripts/check-approval-token-write.sh" sh "$PG_T25_SELF" > "$_t25_base_out" 2>&1 || _t25_base_rc=$?
  if [ "$_t25_base_rc" = "0" ] && ! grep -q '\[FAIL\]' "$_t25_base_out"; then
    t25_pass "T1023-TC-15pre mutation baseline (original guard) all focused TCs PASS"
  else
    t25_fail "T1023-TC-15pre mutation baseline failed (rc=$_t25_base_rc) — mutation kill判定は無効"
  fi
  # _t25_mutate <tc-id> <sed-expr> <anchor-grep> <kill-tc-label> [label-prefix]
  # TASK-1045 GC-4-B (a): 出力ラベルの prefix を第 5 引数で切替可能にする。
  # 既存 7 呼び出しは 4 引数のまま `${5:-T1023}` にフォールバックし互換を保つ。
  _t25_mutate() {
    _t25_mid="$1"; _t25_sed="$2"; _t25_anchor="$3"; _t25_kill="$4"; _t25_pfx="${5:-T1023}"
    _t25_mut="$_t25_mut_dir/mutant-$_t25_mid.sh"
    cp "$PG_T25_ROOT/scripts/check-approval-token-write.sh" "$_t25_mut"
    chmod +x "$_t25_mut"
    _t25_before=$(grep -c "$_t25_anchor" "$_t25_mut" || true)
    sed "$_t25_sed" "$_t25_mut" > "$_t25_mut.new" && mv "$_t25_mut.new" "$_t25_mut"
    chmod +x "$_t25_mut"
    _t25_changed=0
    cmp -s "$_t25_mut" "$PG_T25_ROOT/scripts/check-approval-token-write.sh" 2>/dev/null || _t25_changed=$?
    if [ "$_t25_before" != "1" ]; then
      t25_fail "$_t25_pfx-$_t25_mid mutation anchor not unique (count=$_t25_before)"
      return 0
    fi
    if [ "$_t25_changed" = "0" ]; then
      t25_fail "$_t25_pfx-$_t25_mid mutation produced no change (sed miss)"
      return 0
    fi
    if ! sh -n "$_t25_mut" 2>/dev/null; then
      t25_fail "$_t25_pfx-$_t25_mid mutant has syntax error"
      return 0
    fi
    _t25_mo="$_t25_mut_dir/out-$_t25_mid.txt"
    _t25_mrc=0
    env -u PG_HARNESS_SOURCED -u FIXTURES_DIR PG_T25_MUTATION_CHILD=1 PG_T25_NO_RECURSE=1 \
      PG_T25_GUARD="$_t25_mut" sh "$PG_T25_SELF" > "$_t25_mo" 2>&1 || _t25_mrc=$?
    if grep -q "\[FAIL\] $_t25_kill" "$_t25_mo" && [ "$_t25_mrc" != "0" ]; then
      t25_pass "$_t25_pfx-$_t25_mid mutant killed by real TC ($_t25_kill FAILs)"
    else
      t25_fail "$_t25_pfx-$_t25_mid mutant NOT killed by $_t25_kill (child rc=$_t25_mrc)"
    fi
  }
  # 変異 1: block の exit 2 → exit 1（kill: T1023-TC-01）
  _t25_mutate "TC-15" 's/  exit 2 # t1023-block-exit/  exit 1 # t1023-block-exit/' 't1023-block-exit' 'T1023-TC-01'
  # 変異 2: stdin 常時 capture → env-present 時 skip（kill: T1023-TC-03）
  _t25_mutate "TC-16" 's/if true; then # t1023-stdin-always/if [ -z "$TARGET" ]; then # t1023-stdin-always/' 't1023-stdin-always' 'T1023-TC-03'
  # 変異 3: parse-unknown block 撤去（exit 2 → exit 0）（kill: T1023-TC-05）
  _t25_mutate "TC-17" 's/  exit 2 # t1023-parse-unknown-exit/  exit 0 # t1023-parse-unknown-exit/' 't1023-parse-unknown-exit' 'T1023-TC-05'
  # 変異 4: TTY 時に stdin 評価を skip（exit 0）（kill: T1023-TC-23）
  _t25_mutate "TC-17b" 's/if \[ -t 0 \]; then _parse_unknown "stdin is a TTY (no hook payload)"; fi # t1023-tty-check/if [ -t 0 ]; then exit 0; fi # t1023-tty-check/' 't1023-tty-check' 'T1023-TC-23'
  # 変異 5: stdin file_path 抽出を env-gated に戻す（kill: T1023-TC-13c-file）
  _t25_mutate "TC-17c" 's/if true; then # t1023-file-lane/if [ -z "$TARGET" ]; then # t1023-file-lane/' 't1023-file-lane' 'T1023-TC-13c-file'
  # 変異 6: parsed-safe tool 集合から MultiEdit を除去（kill: T1023-TC-22a）
  _t25_mutate "TC-17d" 's/ or \.tool_name=="MultiEdit"//' 'or \.tool_name=="MultiEdit"' 'T1023-TC-22a'
  # 変異 7: top-level .file_path legacy fallback を除去（kill: T1023-TC-02b）
  _t25_mutate "TC-17e" 's/^.*# t1023-legacy-fallback$/        : # t1023-legacy-fallback/' 't1023-legacy-fallback' 'T1023-TC-02b'

  # ── TASK-1045 変異 2 方向（出力ラベル prefix = T1045 / plan GC-4-B (a)）──
  # T1045-TC-09 / 変異 (a): 正規化を no-op 化して修正前（生の `>` 判定）へ戻す
  #   → 誤検知解消 TC（T1045-TC-01）が FAIL することで「修正を本当に検出している」ことを示す
  _t25_mutate "TC-09" 's@^.*# t1045-redirect-normalize$@  _wc_n="$_wc" # t1045-redirect-normalize@' \
    't1045-redirect-normalize' 'T1045-TC-01' 'T1045'
  # T1045-TC-10 / 変異 (b): 残存 `>` 判定を常に false 化してガードを弱める
  #   → 退行防止 TC（T1045-TC-04）が FAIL することで「弱体化が機械検出される」ことを示す（GC-1 の担保）
  _t25_mutate "TC-10" 's@^.*# t1045-file-redirect$@  false # t1045-file-redirect@' \
    't1045-file-redirect' 'T1045-TC-04' 'T1045'

  # ── TASK-1110 変異 2 方向（出力ラベル prefix = T1110 / #1110）──
  # 変異は **call site**（`# t1110-redirect-correlate` の行）を壊す。判定関数の本体
  # だけを壊す変異は「呼び出し側が結果を使っているか」を検証できないため使わない。
  # M-1 / 変異 (a): 相関判定の結果を握り潰して常に真（= 修正前の OR 判定へ回帰）
  #   → 誤検知解消 TC（T1110-TC-01）が FAIL することで「相関を本当に見ている」ことを示す
  _t25_mutate "M-1" 's@^.*# t1110-redirect-correlate$@  _redirect_tok=1 # t1110-redirect-correlate@' \
    't1110-redirect-correlate' 'T1110-TC-01' 'T1110'
  # M-2 / 変異 (b): 相関判定の結果を常に偽（= 真の陽性を取りこぼす方向へ緩和）
  #   → 退行防止 TC（T1045-TC-04 = `> <TOKEN>` の block）が FAIL することで
  #     「誤検知削減に倒しすぎた場合に機械検出できる」ことを示す
  _t25_mutate "M-2" 's@^.*# t1110-redirect-correlate$@  _redirect_tok=0 # t1110-redirect-correlate@' \
    't1110-redirect-correlate' 'T1045-TC-04' 'T1110'

  # ── TASK-1110 V-3 是正: **レーン内部の分類**を壊す変異（R-002 / R-005）──
  # M-1 / M-2 は相関レーン全体を落とす変異なので、レーン内部の分類ミス
  # （解決不能 → 解決済み非トークン）は原理的に検出できない。V-3 R-001 の穴は
  # まさにそれだった。以下はレーンを生かしたまま分類だけを誤らせる変異である。
  # M-3 / 変異 (c): 引用・退避の検出を無効化（= V-3 R-001 の穴を再現）
  #   → 切り詰めクラス TC（T1110-TC-06）が FAIL する
  _t25_mutate "M-3" 's@^.*# t1110-quote-escape$@    case "$_rw_t" in *ZZZNEVERMATCHZZZ*) : ;; esac # t1110-quote-escape@' \
    't1110-quote-escape' 'T1110-TC-06' 'T1110'
  # M-4 / 変異 (d): 終端文字クラスへ `#` を戻す（語中の `#` で切り詰めてしまう）
  #   → 語中 `#` TC（T1110-TC-07）が FAIL する
  _t25_mutate "M-4" "s@^.*# t1110-terminator-class\$@  _rw_term='[[:space:];\&|()<#]' # t1110-terminator-class@" \
    't1110-terminator-class' 'T1110-TC-07' 'T1110'
  # M-5 / 変異 (e): 診断値リセットの削除（R-005 M-C 相当）
  #   → T1110-TC-10 が FAIL する
  _t25_mutate "M-5" 's@^  _wi_redirect_target="" # t1110-reset-diag$@  : # t1110-reset-diag@' \
    't1110-reset-diag' 'T1110-TC-10' 'T1110'
  # M-6 / 変異 (f): 改行畳み込みの無効化（R-005 M-D 相当）
  #   → T1110-TC-09 が FAIL する
  _t25_mutate "M-6" 's@^.*# t1110-flatten$@  _rw_flat="$_rw_s" # t1110-flatten@' \
    't1110-flatten' 'T1110-TC-09' 'T1110'

  # ── TASK-1115 (#1115) mutation ───────────────────────────────────────
  # M-7 はレーン全体を落とす変異なので、レーン内部の分類ミスは原理的に検出できない。
  # M-8〜M-11 はゲートを生かしたまま **分類だけ** を誤らせる変異である
  # （diff-audit Phase 6 item 6）。変異はすべて **call site** を壊す。
  # M-7 / レーン全体: 外側ゲートを修正前の `_is_token_path` に戻す
  #   → glob 崩しの正側 TC（T1115-TC-01）が FAIL する
  _t25_mutate "M-7" 's@^.*# t1115-glob-gate$@    if _is_token_path "$_cmd" \&\& _has_write_intent "$_cmd"; then # t1115-glob-gate@' \
    't1115-glob-gate' 'T1115-TC-01' 'T1115'
  # M-8 / レーン内部: ルール (A) approvals-dir だけを never-match にする
  #   → 保護 basename に一致しない `approvals/x9.jso*` を含む T1115-TC-01 が FAIL。
  #     `c3.jso*` はルール (B) が拾うので TC-02 は生き残る = 分類の切り分けを実証
  _t25_mutate "M-8" 's@^.*# t1115-approvals-dir$@        *ZZZNEVERMATCHZZZ*) return 0 ;; # t1115-approvals-dir@' \
    't1115-approvals-dir' 'T1115-TC-01' 'T1115'
  # M-9 / レーン内部: ルール (B) の保護 basename リストを空振りにする
  #   → approvals 外の `_maintenance/maintenance.jso*` を含む T1115-TC-02 が FAIL
  _t25_mutate "M-9" 's@^.*# t1115-protected-basenames$@  for _gm_lit in ZZZNEVERMATCHZZZ; do # t1115-protected-basenames@' \
    't1115-protected-basenames' 'T1115-TC-02' 'T1115'
  # M-10 / レーン内部・**誤検出方向**: 先頭 glob ガードを外す（`*.json` も照合対象に）
  #   → 負側 TC（T1115-TC-03 の `cp schemas/*.json /tmp/`）が FAIL する。
  #     正側 TC だけでは原理的に検出できない変異である
  _t25_mutate "M-10" 's@^.*# t1115-leading-glob$@    ZZZNEVERMATCHZZZ) return 1 ;; # t1115-leading-glob@' \
    't1115-leading-glob' 'T1115-TC-03' 'T1115'
  # M-11 / レーン内部: basename 抽出を語全体に変える（`${w##*/}` を剥がす）
  #   → ルール (B) がパス付き語で照合できなくなり T1115-TC-02 が FAIL
  _t25_mutate "M-11" 's@^.*# t1115-basename-extract$@  _gm_base="$_gm_w" # t1115-basename-extract@' \
    't1115-basename-extract' 'T1115-TC-02' 'T1115'

  # T1045-TC-21: _t25_mutate 後方互換 — 既存 7 呼び出しは 4 引数のままで出力ラベルが T1023- のこと
  _t1045_c21=$(grep -c '_t25_mutate "TC-1[567]' "$PG_T25_SELF" || true)
  _t1045_c21b=$(grep -c "_t25_pfx=\"\${5:-T1023}\"" "$PG_T25_SELF" || true)
  if [ "$_t1045_c21" = "7" ] && [ "$_t1045_c21b" = "1" ]; then
    t25_pass "T1045-TC-21 legacy _t25_mutate calls unchanged (7 x 4-arg) with T1023 prefix fallback"
  else
    t25_fail "T1045-TC-21 _t25_mutate backward compatibility broken (legacy=$_t1045_c21 fallback=$_t1045_c21b)"
  fi

  # 復元 PASS: mutation 群の後に原本 guard で再度 focused kill TC 群が全 PASS すること
  _t25_rest_out="$_t25_mut_dir/restore.out"
  _t25_rest_rc=0
  env -u PG_HARNESS_SOURCED -u FIXTURES_DIR PG_T25_MUTATION_CHILD=1 PG_T25_NO_RECURSE=1 \
    PG_T25_GUARD="$PG_T25_ROOT/scripts/check-approval-token-write.sh" sh "$PG_T25_SELF" > "$_t25_rest_out" 2>&1 || _t25_rest_rc=$?
  if [ "$_t25_rest_rc" = "0" ] && ! grep -q '\[FAIL\]' "$_t25_rest_out"; then
    t25_pass "T1023-TC-17post restore (original guard) all focused TCs PASS"
  else
    t25_fail "T1023-TC-17post restore run failed (rc=$_t25_rest_rc)"
  fi
fi

fi # PG_T25_FOCUSED

# 単体実行時のみ: cleanup drain + サマリ + exit code（source 時は run-tests.sh が担う）
if [ "$PG_T25_STANDALONE" = "1" ]; then
  printf '%s' "$_PG_T25_CLEANUP_PATHS" | while IFS= read -r _pg_cp; do
    if [ -n "$_pg_cp" ]; then
      rm -rf "$_pg_cp" 2>/dev/null || true
    fi
  done
  printf '\nTA-25 standalone: %s passed, %s failed\n' "$pass" "$fail"
  if [ "$fail" != "0" ]; then
    exit 1
  fi
fi
