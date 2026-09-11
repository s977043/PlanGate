#!/bin/sh
# check-git-destructive.sh — Hook EH-12: protected branch 上の破壊的 git 操作 block
#
# Claude Code PreToolUse hook（Bash の前）。**current branch が protected
# (main / master) のとき**に限り、`git reset --hard` / `git push --force`
# 系（`-f` / `--force-with-lease` 含む）を決定論的に block する。
#
# 出自: 2026-08-02 の実害。オーケストレータが
#   git checkout -q <b> 2>/dev/null || git checkout -q -b <b> origin/<b>
#   git reset --hard -q origin/<b>
# を実行し、`||` の両側が失敗（同名ブランチ既存で `-b` が fatal）したにも
# かかわらず `||` 連結ゆえ `set -e` が発火せず、**main 上で reset --hard が
# 走って他セッションの未コミット変更を破棄**した（dangling blob から復旧）。
# 同型の学びは AGENT_LEARNINGS.md に 2026-07-12 から存在したが防げなかった
# ため、規範層（ドキュメント）ではなく**技術層で止める**のが本 hook の目的。
#
# 責務分界: 規範層 = .claude/rules/responsibility-classes.md「Bash 連結
# コマンド時の error guard」/ 技術層 = 本 hook（PreToolUse）+ pre-push hook
# （TASK-0114、main への直接 push を block）。本 hook は push だけでなく
# **ローカルで完結し pre-push が発火しない `reset --hard`** を覆う点が新規。
#
# 信頼境界: PreToolUse では **stdin JSON tool_input.command を正本** とする。
# env PLANGATE_HOOK_CMD は CLI テスト専用（stdin 不在 / 空のときのみ）。
#
# Modes:
#   default                 protected branch 上の破壊的操作は block
#   PLANGATE_BYPASS_HOOK=1  常時 allow（既存 hook 共通の bypass 慣行）
# protected 以外のブランチ / branch 判定不能（非 git・detached HEAD）:
#   常に allow（誤検出ゼロを優先）
#
# 既知制約:
#   - ユーザー定義 git alias（例: `git nuke`）は解決不能
#   - `git -C <other-repo> reset --hard` は cwd の branch で判定する
#     （他リポジトリの branch は見ない）。安全側（過剰 block）に倒れる
#
# 監査: docs/working/_audit/hook-events.log（command 全文は記録せず class+hash）
#
# 配置: scripts/ ルート（HO 外）。`.claude/settings*.json` からこのパスを
# **直接**参照する（`scripts/hooks/` へ複製しない＝単一ソース）。同じ方式の
# 先例: scripts/check-approval-token-write.sh / scripts/gh-pin-account.sh。
# `scripts/hooks/` は tracked のため、そこへ cp すると同一内容の tracked
# ファイルが 2 つ並び、drift を検出する CI も無い（#956 と同一構造）。
#
# 正本: docs/ai/hook-enforcement.md § EH-12

set -eu

# 本 hook の正規配置は scripts/ ルートの 1 箇所のみ。REPO_ROOT はそこからの
# 相対で一意に決まる（tests/extras のサンドボックス複製も <tmp>/scripts/ に
# 置くため同じ解決で通る）。REPO_ROOT の用途は監査ログのパスだけで、
# log_event は全経路 `|| true` ガード済み＝解決を誤っても allow/block の
# 判定には一切影響しない（fail-open にならない）。
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
AUDIT_LOG="$REPO_ROOT/docs/working/_audit/hook-events.log"

# protected branch 一覧（空白区切り）
PROTECTED_BRANCHES="main master"

json_escape() {
  # " \ と制御文字を最小エスケープ
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t'
}

emit_judgment() {
  decision=$1
  reason=$(json_escape "${2:-}")
  if [ "$decision" = "block" ]; then
    printf '{"continue":false,"stopReason":"%s"}\n' "$reason"
  else
    printf '{"continue":true}\n'
  fi
}

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-git-destructive\t%s\t%s\n' \
    "$ts" "$level" "${PLANGATE_HOOK_TASK:--}" "$msg" >>"$AUDIT_LOG" 2>/dev/null || true
}

# bypass（既存慣行: bypass > 通常）
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  emit_judgment "allow"
  exit 0
fi

# 対象コマンド解決: stdin JSON を正本、env は CLI テスト fallback
#
# **`head -1` を使ってはならない**。Bash tool の command は複数行になりうる
# （実害の原文がまさに改行 2 行だった）。jq -r は JSON の \n を実改行へ展開
# して出力するため、head -1 を挟むと 2 行目以降＝破壊的操作そのものが捨てられ
# allow に化ける（2026-08-02 のレビューで検出）。
cmd=""
if [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
  if [ -n "$_stdin" ]; then
    if command -v jq >/dev/null 2>&1; then
      # 複数行をそのまま受け取る（$() が末尾改行だけを落とす）
      cmd=$(printf '%s' "$_stdin" | jq -r '.tool_input.command // .command // empty' 2>/dev/null)
    fi
    if [ -z "$cmd" ]; then
      # jq 非搭載時の fallback。JSON 文字列内で改行は必ず `\n`（2 文字）へ
      # エスケープされる＝値は 1 物理行に収まるため、ここでの head -1 は
      # 「最初の "command" マッチを選ぶ」意味であって値の切り詰めではない。
      # `([^"\\]|\\.)*` でエスケープ済み `\"` を跨いで値全体を取る。
      # 取り出した値は `\n` を literal のまま含むので、後段の正規化で潰す。
      cmd=$(printf '%s' "$_stdin" \
        | grep -oE '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
        | head -1 \
        | sed -e 's/^"command"[[:space:]]*:[[:space:]]*"//' -e 's/"$//')
    fi
  fi
fi
if [ -z "$cmd" ]; then
  cmd=${PLANGATE_HOOK_CMD:-}
fi

if [ -z "$cmd" ]; then
  emit_judgment "allow"
  exit 0
fi

# --- 正規化: 複数行コマンドを 1 論理行へ平坦化する ---
# 全ての空白類（実改行 / CR / tab）を空白 1 文字へ落とし、さらに jq 非搭載
# 経路で残る **literal な `\n` / `\r` / `\t`（バックスラッシュ + 文字）** も
# 空白へ落とす。これで「; 区切りは検出できるが改行区切りは素通り」という
# 非対称が消え、以降の空白アンカー（`" reset "` 等）が行をまたいで効く。
# 併せてクォートを除去（EH-9 と同じ緩い吸収）。
# 副次的に `\` 行継続・行頭インデント・`$'\n'` 形式も同じ経路で吸収される。
# (#1326) **物理改行は ` ; ` へ**変換する。空白へ潰すと「改行区切りの複数
# コマンド」が 1 コマンドへ融合し、後段の `reset --hard` / force push を
# 取りこぼす（2026-08-02 インシデントの形。実測で退行を確認した）。
# `\` 行継続は 1 コマンドなので連結する。
norm=$(printf '%s' "$cmd" \
  | awk '{ if (sub(/\\$/, "")) { printf "%s", $0 } else { printf "%s ; ", $0 } }' \
  | tr '\r\t' '  ' \
  | sed -e 's/\\n/ ; /g' -e 's/\\r/ ; /g' -e 's/\\t/ /g' \
        -e "s/'//g; s/\"//g")

# --- 破壊的操作の検出（決定論。git サブコマンド + フラグの同時成立を要求）---
# 誤検出を避けるため「git トークンが存在」かつ「reset+--hard」または
# 「push+force 系」の**両方**が揃ったときだけ destructive と見なす。
#
# (#1326) 「両方が揃った」の判定を **同一コマンドのトークン列**に限定する。
# 以前は最初の `git` 以降の文字列全体を 1 塊として見ていたため、
#   - `&&` / `;` / `|` / `&` で区切られた **後続コマンド**の `--force`
#   - `echo "... git push --force ..."` のような **データとして現れる文字列**
#     （`norm` はクォートを除去済みなので、実コマンドと見分けがつかない）
#   - refspec ではない ` +`（例: `echo a + b`）
# を拾って、破壊的でないコマンドを block していた（実測 6 クラス）。
#
# **既定は fail-closed。** セグメントの先頭語が `git` そのもののときだけ
# 精密解析へ入り、それ以外（`if` / `for` / `{` / `time` / `sh -c` / 解釈不能）は
# **すべて従来の部分文字列判定へ落とす**。ホワイトリスト方式にすると
# リスト漏れがそのまま穴になる（敵対レビューで実証された）。
#
# block 対象は一切緩めない（--force / --force-with-lease[=<ref>] /
# --force-if-includes / -f / refspec 先頭 `+` / reset --hard）。

# セグメント内を部分文字列で判定する（fail-closed 側の経路 = 従来の挙動）。
_eh12_loose() {
  case "$1" in
    *" git "*|*"/git "*)
      _l_after=" ${1#*git} "
      case "$_l_after" in
        *" reset "*)
          case "$_l_after" in *" --hard"*) printf 'git-reset-hard\n'; return 0 ;; esac
          ;;
      esac
      case "$_l_after" in
        *" push "*)
          case "$_l_after" in
            *" --force"*|*" -f "*) printf 'git-push-force\n'; return 0 ;;
            *" +"*) printf 'git-push-force-refspec\n'; return 0 ;;
          esac
          ;;
      esac
      ;;
  esac
  return 1
}

_eh12_classify() {
  _n=" $1 "
  # 区切り: || && ; | &（`||` `&&` を先に潰してから単体を処理する）
  _segs=$(printf '%s' "$_n" \
    | sed -e 's/||/\n/g' -e 's/&&/\n/g' -e 's/;/\n/g' -e 's/|/\n/g' -e 's/&/\n/g')

  printf '%s\n' "$_segs" | while IFS= read -r _s; do
    [ -n "$_s" ] || continue
    _seg=" $_s "

    # 先頭語を取る（env 代入 / command / builtin / exec / 前置スペースを剥がす）。
    # `git -c user.name=x push` の `-c user.name=x` を env 代入と誤認しないよう、
    # 代入の剥がしは「先頭語が NAME=... の形」に限定する。
    _rest=$_s
    while :; do
      _rest=$(printf '%s' "$_rest" | sed -e 's/^[[:space:]]*//')
      _w0=${_rest%% *}
      case "$_w0" in
        command)  _rest=${_rest#command } ; continue ;;
        builtin)  _rest=${_rest#builtin } ; continue ;;
        exec)     _rest=${_rest#exec } ; continue ;;
      esac
      case "$_w0" in
        *=*)
          case "$_w0" in
            [A-Za-z_]*)
              case "${_w0%%=*}" in
                *[!A-Za-z0-9_]*) break ;;
                *) _rest=${_rest#* } ; continue ;;
              esac
              ;;
            *) break ;;
          esac
          ;;
      esac
      break
    done
    _word=${_rest%% *}
    _base=${_word##*/}

    if [ "$_base" != "git" ]; then
      # **git を起動しえない**組み込みコマンドだけは素通しする。ここは
      # ホワイトリストだが、**漏れは誤検知（安全側）にしかならない**方向なので
      # fail-closed と矛盾しない。逆に「間接起動語のリスト」で fail-closed を
      # 実装すると漏れが穴になる（v1 の誤り）。
      case "$_base" in
        echo|printf|:|true|false) continue ;;
      esac
      # **fail-closed**: git 起動と断定できないセグメントは従来判定へ落とす
      _eh12_loose "$_seg" && return 0
      continue
    fi

    # ここから精密解析（先頭語が git そのもの）
    _args=${_rest#"$_word"}
    _sub=""
    set -f            # glob 展開を止める（cwd 依存の誤検知を防ぐ / #1326 O-1）
    # shellcheck disable=SC2086  # 意図的な word splitting（トークン列を得る）
    set -- $_args
    set +f
    while [ $# -gt 0 ]; do
      case "$1" in
        -C|-c) shift 2; continue ;;
        --git-dir=*|--work-tree=*|--namespace=*|-c*|--no-pager|--paginate|-P|--literal-pathspecs|--exec-path=*)
          shift; continue ;;
        --git-dir|--work-tree|--namespace|--exec-path) shift 2; continue ;;
        -*) shift; continue ;;
        *) _sub=$1; shift; break ;;
      esac
    done
    _flags=" $* "
    case "$_sub" in
      reset)
        case "$_flags" in *" --hard"*) printf 'git-reset-hard\n'; return 0 ;; esac
        ;;
      push)
        case "$_flags" in
          *" --force"*|*" -f "*) printf 'git-push-force\n'; return 0 ;;
        esac
        case "$_flags" in
          *" +"*) printf 'git-push-force-refspec\n'; return 0 ;;
        esac
        ;;
    esac
  done | head -1
}

destructive=$(_eh12_classify "$norm")

if [ -z "$destructive" ]; then
  emit_judgment "allow"
  exit 0
fi

# --- current branch 判定 ---
# symbolic-ref は commit ゼロの新規リポジトリでも branch 名を返す。
# detached HEAD / 非 git ディレクトリでは空 → 判定不能として allow。
branch=""
if command -v git >/dev/null 2>&1; then
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
fi

if [ -z "$branch" ]; then
  log_event "SKIP" "branch undetermined (non-git or detached HEAD); class=$destructive"
  emit_judgment "allow"
  exit 0
fi

protected=0
for _b in $PROTECTED_BRANCHES; do
  if [ "$branch" = "$_b" ]; then
    protected=1
    break
  fi
done

if [ "$protected" = "0" ]; then
  emit_judgment "allow"
  exit 0
fi

cmd_hash=$(printf '%s' "$cmd" | { command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256; } | awk '{print $1}')
log_event "VIOLATION" "destructive git op on protected branch; branch=$branch class=$destructive hash=${cmd_hash%% *}"
# 注: 変数の直後に全角文字が続くと識別子の一部として解釈されるため
# （`$destructive）` は unbound variable になる）、必ず ${...} で囲む。
emit_judgment "block" "[Hook EH-12] protected branch (${branch}) 上の破壊的 git 操作 (${destructive}) は禁止です。作業ブランチへ切り替えてから実行してください（切替コマンドの失敗を || で握り潰していないか確認）。"
exit 0
