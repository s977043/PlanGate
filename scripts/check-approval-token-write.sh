#!/bin/sh
# check-approval-token-write.sh — 承認トークン系ファイルへの AI 直接書き込みを block（EH-13）
# TASK-0123 (#420) + TASK-0128 R-002 (Bash matcher) + #546 Codex review
# + TASK-1023 (#1023) 二重無効化の封鎖:
#   - block を exit 1 → exit 2 へ（PreToolUse の block 契約。exit 1 は非 block）
#   - stdin を env target の有無に関係なく常時・独立に評価（env 供給時の stdin bypass 封鎖）
#   - jq 不在 / malformed / empty / TTY / read error は parse-unknown として fail-closed
#     （G-7=(a) Human 裁定: stdin 未供給の手実行が exit 2 になる副作用を許容。
#      診断/手実行の escape hatch は PLANGATE_SKIP_TOKEN_GUARD=1 = Human-owned）
#   - target は env → $1 fallback（現行 settings 呼出は引数なしのため $1 経路は実行時
#     dead code。契約 drift は #928 に残存）
#   - parsed-safe tool 集合は Edit / Write / MultiEdit / Bash の固定 4 種（G-8=(a)）。
#     MultiEdit は tool_input.file_path のみ評価（edits[] は評価しない / M-3）
#   - 採番: EH-13（G-6=(b)。EH-10/11 は #760/#762 予約済、EH-12 は check-git-destructive.sh）
# hook として .claude/settings.json に登録する（Human-owned）
# 配置: scripts/ ルート（HO 外）
#
# 対応 matcher:
#   Edit|Write|MultiEdit … PLANGATE_HOOK_FILE env / $1 / stdin JSON .tool_input.file_path
#                （legacy 互換のみ top-level .file_path fallback）
#   Bash       … stdin JSON .tool_input.command 中の token path + 「書き込み意図」を検出
#                （TASK-1110 / #1110: リダイレクト（>）は先が token path に解決される
#                  場合のみ block。解決不能な先は block 側 = fail-closed）
#                （> / cp/mv/ln/install/dd/tee/truncate/patch/apply_patch /
#                  ed/ex / git checkout|restore|checkout-index|update-index /
#                  sed -i / perl -i / python write_text・open(...,"w") /
#                  node writeFileSync / ruby File.write 等）
#                読み取り（cat / open(...).read 等）は block しない。

set -eu

# PLANGATE_SKIP_TOKEN_GUARD=1 で全スキップ（Human-owned emergency/test-only）
# 診断は出すが env の値や対象 path 等は echo しない（secret 非表示）
if [ "${PLANGATE_SKIP_TOKEN_GUARD:-0}" = "1" ]; then
  printf '[EH-13 token-guard] bypass active: PLANGATE_SKIP_TOKEN_GUARD (Human-owned emergency/test-only)\n' >&2
  exit 0
fi

_is_token_path() {
  case "$1" in
    *maintenance.json*|*/approvals/*.json|*c3.json*|*parent-c3.json*|*parent-integration.json*) return 0 ;;
    *) return 1 ;;
  esac
}

# 非書き込みリダイレクト記法だけを列挙的に除去する（TASK-1045 / #1045）。
# 方針（plan GC-2）: 完全なシェル構文解析は行わない。これは allowlist 的な除去であり
# `>` 判定の一般的な緩和ではない。除去対象は次の 2 種のみ:
#   (1) fd 複製 / fd クローズ: N>&M / >&M / N>&-（`>&` の直後が数字列 or `-` のときのみ）
#   (2) /dev/null への破棄: N> / N>> の直後（空白許容）が /dev/null かつ後続が語境界
# `&>` / `&>>`（bash 拡張の全出力リダイレクト）は block 維持（plan U-2）。
# POSIX BRE のみを使用し GNU 拡張（\| / \+ / \b）は使わない（plan GC-6）。
# LC_ALL=C 固定: UTF-8 locale では不正バイト列で sed が rc=1 になる（plan GC-6 / R-007 実測）。
_strip_nonwrite_redirects() {
  # (0) `&>` を保護（後段の /dev/null 規則に巻き込ませない）。`>` は残すので block 維持。
  printf '%s' "$1" | LC_ALL=C sed \
    -e 's|&>|\&>#|g' \
    -e 's|[0-9]*>&[0-9][0-9]*||g' \
    -e 's|[0-9]*>&-||g' \
    -e 's|[0-9]*>>*[[:space:]]*/dev/null$||' \
    -e 's|[0-9]*>>*[[:space:]]*/dev/null\([^A-Za-z0-9_./-]\)|\1|g'
}

# リダイレクト先とトークンパスの相関判定（TASK-1110 / #1110）。
# 入力は _strip_nonwrite_redirects 適用後の文字列（fd 複製 / fd クローズ /
# /dev/null 破棄は除去済み）。残存する各リダイレクト先を静的に抽出し、
# 「トークンパスに解決される先」が 1 つでもあれば真（= block）を返す。
# 修正前は「コマンド文字列のどこかにトークン名がある」×「どこかに `>` がある」の
# AND だけで block していたため、`git commit -m '...c3.json...' > /tmp/log.txt` の
# ように無関係なリダイレクトを伴うだけで誤 block された（#1110）。
#
# fail-closed（判定不能は必ず block 側 / 誤検知削減のために真の陽性を落とさない）:
#   - `&>` / `&>>`（全出力リダイレクト）を含む … TASK-1045 U-2 の block 維持
#   - 抽出パイプラインの失敗（sed 失敗等）      … 真
#   - 先が空 / `$` / バッククォート / glob を含む … 真（静的に解決不能）
#   - 先が /dev/*（正規化後に残った擬似デバイス）… 真（呼出側で token file へ
#     再束縛されうる。既存 T1045-TC-11/12/13 の block を維持する）
# 完全なシェル構文解析は行わない（TASK-1045 GC-2 の方針を継承）。POSIX BRE のみ・
# sed の RHS `\n` は使わない（分割は tr で行う / GNU・BSD 差異回避）。LC_ALL=C 固定。
_wi_redirect_target=""
_redirect_writes_token() {
  _rw_s="$1"
  _wi_redirect_target=""
  # `&>` は正規化で `&>#` へ退避される。原文・退避形のどちらでも同じく block 維持。
  case "$_rw_s" in
    *'&>'*) _wi_redirect_target='&>(all-output-redirect)'; return 0 ;;
  esac
  # 改行を空白へ畳む（heredoc 等の複数行コマンドで語抽出が崩れないように）。
  _rw_flat=$(printf '%s' "$_rw_s" | tr '\n' ' ') || { _wi_redirect_target='(flatten-failed)'; return 0; }
  # `>|`（noclobber 上書き）を `>` へ、`>>` 以上の連続を `>` へ畳む。
  _rw_norm=$(printf '%s' "$_rw_flat" | LC_ALL=C sed -e 's%>|%>%g' -e 's%>>*%>%g') \
    || { _wi_redirect_target='(normalize-failed)'; return 0; }
  # `>` で分割し、先頭（最初の `>` より前）を捨てた各レコードの先頭語を先とみなす。
  # 語の終端: 空白 / ; & | ( ) < #。前後の引用符は剥がす。空語は @EMPTY@ で残す。
  _rw_list=$(printf '%s' "$_rw_norm" | tr '>' '\n' \
    | LC_ALL=C sed -e '1d' -e 's%^[[:space:]]*%%' -e 's%[[:space:];&|()<#].*$%%' \
        -e "s%^['\"]%%" -e "s%['\"]\$%%" -e 's%^$%@EMPTY@%') \
    || { _wi_redirect_target='(extract-failed)'; return 0; }
  [ -n "$_rw_list" ] || return 1
  _rw_hit=1
  _rw_ifs="$IFS"
  IFS='
'
  set -f # glob 展開を止めて生の語のまま評価する
  for _rw_t in $_rw_list; do
    case "$_rw_t" in
      '@EMPTY@'|*'$'*|*'`'*|*'*'*|*'?'*|*'['*)
        _wi_redirect_target="$_rw_t"; _rw_hit=0; break ;;
      /dev/*)
        _wi_redirect_target="$_rw_t"; _rw_hit=0; break ;;
    esac
    if _is_token_path "$_rw_t"; then
      _wi_redirect_target="$_rw_t"; _rw_hit=0; break
    fi
  done
  set +f
  IFS="$_rw_ifs"
  return "$_rw_hit"
}

# Bash コマンド文字列に「書き込み意図」があるか（読み取りは false を返す）
# 一致したルールの識別子（TASK-1045 AC-10）。真を返す直前に必ず設定する。
_wi_rule=""
_has_write_intent() {
  _wc="$1"
  _wi_rule=""
  _wi_redirect_target=""
  # リダイレクト > / >>: 非書き込み記法を除去してから残存 `>` を見る。
  # 正規化に失敗したら元文字列で判定する = fail-closed（block 維持 / plan GC-8 (i)）。
  _wc_n=$(_strip_nonwrite_redirects "$_wc") || _wc_n="$_wc" # t1045-redirect-normalize
  # 残存 `>` があるだけでは block しない。先がトークンパスに解決されるか
  # （または解決不能か）まで突き合わせる（#1110）。
  _redirect_tok=0
  _redirect_writes_token "$_wc_n" && _redirect_tok=1 # t1110-redirect-correlate
  printf '%s' "$_wc_n" | grep -q '>' && [ "$_redirect_tok" = "1" ] && { _wi_rule=file-redirect; return 0; } # t1045-file-redirect
  # ここへ来た時点で redirect レーンは不成立。以降のルールで block する場合に
  # redirect_target が誤って添えられないよう捨てる（正規化失敗時の診断値対策）。
  _wi_redirect_target=""
  # 書き込み系コマンドが語境界で出現（行頭・; & | ( 直後・空白区切り）
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])(cp|mv|ln|install|dd|tee|truncate|patch|apply_patch)([[:space:]]|$)' && { _wi_rule=copy-like; return 0; }
  # ed / ex（stdin スクリプトの w コマンドで書込可能。語境界で検出 / TASK-1023 V-3 実測 bypass）
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])(ed|ex)([[:space:]]|$)' && { _wi_rule=line-editor; return 0; }
  # git の作業ツリー復元系（checkout / restore / checkout-index / update-index。
  # ref から token path を復元・上書きできる / TASK-1023 V-3 実測 bypass。
  # git と subcommand の間の -C <dir> 等のオプションも許容）
  # git と subcommand の間は「- で始まるオプション（引数 1 個まで随伴可: -C <dir> 等）」のみ許容。
  # 非オプション語（log 等）が先に来る場合は subcommand と見なさない（読取系の誤 block 防止）
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+(checkout|restore|checkout-index|update-index)([[:space:]]|$)' && { _wi_rule=git-restore; return 0; }
  # sed -i / perl -i（in-place 書き込み。perl -pi / -0pi 等も -[A-Za-z]*i で捕捉）
  printf '%s' "$_wc" | grep -qE '(^|[;&|(]|[[:space:]])(sed|perl)([[:space:]]+-[A-Za-z]*i|[[:space:]]+--in-place)' && { _wi_rule=inplace-edit; return 0; }
  # python / ruby の書き込み: write_text / write_bytes / .write( （ruby File.write( を含む）
  printf '%s' "$_wc" | grep -qE 'write_text|write_bytes|\.write\(' && { _wi_rule=lang-write; return 0; }
  # node の書き込み: fs.writeFileSync / writeFile( / appendFile
  printf '%s' "$_wc" | grep -qE 'writeFileSync|writeFile\(|appendFile' && { _wi_rule=lang-write; return 0; }
  printf '%s' "$_wc" | grep -qE "open\([^)]*,[^)]*['\"][^'\"]*[wax+]" && { _wi_rule=lang-write; return 0; }
  return 1
}

_block() {
  printf '[EH-13 token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。\n' >&2
  printf '  検出: %s\n' "$1" >&2
  printf '  正規操作: bin/plangate approve <TASK>（Human TTY / TASK-0128）または bin/plangate maintenance start\n' >&2
  exit 2 # t1023-block-exit
}

_parse_unknown() {
  printf '[EH-13 token-guard] BLOCK (parse-unknown): %s\n' "$1" >&2
  printf '  fail-closed 方針（TASK-1023 G-7）: PreToolUse JSON を stdin へ供給してください。\n' >&2
  printf '  診断/手実行時の escape hatch は PLANGATE_SKIP_TOKEN_GUARD=1（Human-owned）。\n' >&2
  exit 2 # t1023-parse-unknown-exit
}

# 外部依存の存在検査（jq と同契約 / plan GC-8 (ii)）。
# 配置は _parse_unknown() 定義の後・target 判定の前でなければならない
# （関数定義より前だと command not found → rc=127 = 非 block になる / R-010）。
command -v sed >/dev/null 2>&1 || _parse_unknown "sed not available"

# --- 1) target: env 優先、無ければ $1 fallback ---
# 注意: 現行 settings（.claude/settings.example.json）は引数なしで呼び出すため
# $1 経路は実行時 dead code（契約 docs/ai/settings-wiring-contract.md との drift は #928）。
TARGET="${PLANGATE_HOOK_FILE:-${1:-}}"
if [ -n "$TARGET" ] && _is_token_path "$TARGET"; then
  _block "target=$TARGET"
fi

# --- 2) stdin: env target の有無に関係なく常時・独立に評価（TASK-1023 defect #2 封鎖）---
if true; then # t1023-stdin-always
  # TTY は read せず即 fail-closed（read すると hook が TTY でハングする / R-027）
  if [ -t 0 ]; then _parse_unknown "stdin is a TTY (no hook payload)"; fi # t1023-tty-check
  if ! _stdin=$(cat); then _parse_unknown "stdin read failure"; fi
  if [ -z "$_stdin" ]; then _parse_unknown "empty stdin"; fi
  command -v jq >/dev/null 2>&1 || _parse_unknown "jq not available"

  # 3 値判定: protected-write / parsed-safe / parse-unknown。
  # parsed-safe の条件: hook_event_name=PreToolUse、tool_name が固定 4 種（G-8=(a)）、
  # tool_input が object、Edit/Write/MultiEdit は非空 string の file_path
  # （tool_input.file_path、legacy 互換のみ top-level .file_path）、Bash は string command。
  # 欠落・null・配列・数値・未知 tool は parse-unknown（R-026）。
  _kind=$(printf '%s' "$_stdin" | jq -r '
    if .hook_event_name != "PreToolUse" then "unknown"
    elif (.tool_input|type) != "object" then "unknown"
    elif .tool_name == "Bash" then
      (if (.tool_input.command|type) == "string" then "cmd" else "unknown" end)
    elif (.tool_name=="Edit" or .tool_name=="Write" or .tool_name=="MultiEdit") then
      (if ((.tool_input.file_path|type)=="string" and .tool_input.file_path != "")
          or ((.file_path|type)=="string" and .file_path != "") then "file" else "unknown" end)
    else "unknown" end
  ' 2>/dev/null) || _kind=""
  case "$_kind" in
    file|cmd) : ;;
    *) _parse_unknown "malformed or unsupported PreToolUse payload" ;;
  esac

  if [ "$_kind" = "file" ]; then
    if true; then # t1023-file-lane
      # MultiEdit も file_path のみで判定（edits[] やファイル内容は判定に使わない / M-3。
      # token path 文字列を本文に含む通常ファイルの編集を誤 block しないため）
      _fp=$(printf '%s' "$_stdin" | jq -r '.tool_input.file_path | if type=="string" and . != "" then . else empty end' 2>/dev/null) || _fp=""
      if [ -z "$_fp" ]; then
        _fp=$(printf '%s' "$_stdin" | jq -r '.file_path | if type=="string" and . != "" then . else empty end' 2>/dev/null) || _fp="" # t1023-legacy-fallback
      fi
      if [ -z "$_fp" ]; then _parse_unknown "no usable file_path in payload"; fi
      if _is_token_path "$_fp"; then
        _block "file_path=$_fp"
      fi
    fi
  else
    _cmd=$(printf '%s' "$_stdin" | jq -r '.tool_input.command' 2>/dev/null) || _cmd=""
    if [ -z "$_cmd" ]; then _parse_unknown "empty command"; fi
    # redirect レーンは「先がトークンパスに解決される（または解決不能）」ときのみ
    # block する（TASK-1110 / #1110）。copy-like 等の他ルールは従来どおり
    # 相関解析せず安全側 block のまま。
    if _is_token_path "$_cmd" && _has_write_intent "$_cmd"; then
      # rule=<id> で一致ルールの根拠を機械可読に示す（TASK-1045 AC-10）。
      # redirect レーンでは一致した先も併記する（TASK-1110 AC-4）。
      # 既存の可読性を壊さないよう "writes token path" は残す。
      _block "Bash command writes token path (rule=${_wi_rule:-unknown}${_wi_redirect_target:+, redirect_target=$_wi_redirect_target}): $_cmd"
    fi
  fi
fi

exit 0
