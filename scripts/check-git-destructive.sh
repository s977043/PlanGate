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
# 正本: docs/ai/hook-enforcement.md § EH-12

set -eu

# staged source（scripts/）と適用後（scripts/hooks/）の双方で REPO_ROOT を
# 正しく解決する。サンドボックス複製（tests/extras）でも同様に効く。
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
case "$SCRIPT_DIR" in
  */scripts/hooks) REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd) ;;
  */scripts)       REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd) ;;
  *)               REPO_ROOT=$SCRIPT_DIR ;;
esac
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
cmd=""
if [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
  if [ -n "$_stdin" ]; then
    if command -v jq >/dev/null 2>&1; then
      cmd=$(printf '%s' "$_stdin" | jq -r '.tool_input.command // .command // empty' 2>/dev/null | head -1)
    fi
    if [ -z "$cmd" ]; then
      cmd=$(printf '%s' "$_stdin" \
        | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
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

# 正規化: tab / クォート除去（EH-9 と同じ緩い吸収）
norm=$(printf '%s' "$cmd" | tr '\t' ' ' | sed "s/'//g; s/\"//g")

# --- 破壊的操作の検出（決定論。git サブコマンド + フラグの同時成立を要求）---
# 誤検出を避けるため「git トークンが存在」かつ「reset+--hard」または
# 「push+force 系フラグ」の**両方**が揃ったときだけ destructive と見なす。
destructive=""
case " $norm " in
  *" git "*|*"/git "*)
    after=" ${norm#*git } "
    case "$after" in
      *" reset "*)
        case "$after" in
          *" --hard"*) destructive="git-reset-hard" ;;
        esac
        ;;
    esac
    if [ -z "$destructive" ]; then
      case "$after" in
        *" push "*)
          case "$after" in
            # --force / --force-with-lease / --force-if-includes / -f
            *" --force"*|*" -f "*) destructive="git-push-force" ;;
          esac
          ;;
      esac
    fi
    ;;
esac

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
