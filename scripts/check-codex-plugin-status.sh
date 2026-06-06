#!/bin/sh
# check-codex-plugin-status.sh — Codex Plugin の登録・version・skill 数をローカル検査（#451）
#
# ネットワーク不要のローカル状態確認。`codex plugin marketplace list` が存在しない
# 現行 CLI でも動くよう、marketplace cache を直接検査する。
#
# cache path は Codex CLI 実装依存:
#   $CODEX_HOME/.tmp/marketplaces/plangate/  （CODEX_HOME 既定: ~/.codex）
# 実装変更で path が変わり得るため、未検出でも fatal にせず「未登録」案内に留める。
# TODO: `codex plugin marketplace list` 等の公式 status API が提供されたら、
#       cache 直接検査からそのコマンド出力ベースへ移行する（内部 layout 依存を解消）。
#
# Usage: sh scripts/check-codex-plugin-status.sh [--online]
#   --online: GitHub 最新リリースとの version 比較（opt-in、ネットワーク使用）
# Exit: 常に 0（doctor の非 fatal セクション想定。検査結果は stdout に出す）

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ONLINE=0
[ "${1:-}" = "--online" ] && ONLINE=1

CODEX_HOME="${CODEX_HOME:-${HOME:-}/.codex}"
MP_CACHE="$CODEX_HOME/.tmp/marketplaces/plangate"
REPO_PLUGIN_JSON="$REPO_ROOT/plugin/plangate/.claude-plugin/plugin.json"
REPO_SKILLS_DIR="$REPO_ROOT/plugin/plangate/skills"

command -v python3 >/dev/null 2>&1 || { printf '[codex-plugin] python3 required\n' >&2; exit 0; }

# --- リポジトリ側 manifest（常にローカルにある正）---
_repo_ver=$(python3 - "$REPO_PLUGIN_JSON" << 'PYV' 2>/dev/null || printf ''
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding='utf-8')).get('version', ''))
except Exception:
    print('')
PYV
)
# skill 数は POSIX 準拠のシェルループでカウント（find -mindepth/-maxdepth は非 POSIX）
_repo_skills=0
if [ -d "$REPO_SKILLS_DIR" ]; then
  for _sk in "$REPO_SKILLS_DIR"/*/; do
    [ -d "$_sk" ] && _repo_skills=$((_repo_skills + 1))
  done
fi
printf '[codex-plugin] repo manifest: version=%s skills=%s\n' "${_repo_ver:-?}" "$_repo_skills"

# --- Codex marketplace cache 検査（登録状態）---
if [ -d "$MP_CACHE" ]; then
  printf '[codex-plugin] registered: YES (cache: %s)\n' "$MP_CACHE"
  _cache_mp="$MP_CACHE/.claude-plugin/marketplace.json"
  if [ -f "$_cache_mp" ]; then
    _cache_ver=$(python3 - "$_cache_mp" << 'PYC' 2>/dev/null || printf ''
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
    for plug in d.get('plugins', []):
        if plug.get('name') == 'plangate':
            print(plug.get('version', '')); break
except Exception:
    print('')
PYC
)
    printf '[codex-plugin] cache version: %s\n' "${_cache_ver:-?}"
    if [ -n "${_cache_ver:-}" ] && [ -n "${_repo_ver:-}" ] && [ "$_cache_ver" != "$_repo_ver" ]; then
      printf '[codex-plugin] NOTE: cache(%s) != repo(%s) — 更新: codex plugin marketplace upgrade plangate\n' "$_cache_ver" "$_repo_ver"
    fi
  fi
else
  printf '[codex-plugin] registered: NO\n'
  printf '[codex-plugin] 導入: codex plugin marketplace add s977043/PlanGate && sh install.sh --codex\n'
fi

# --- online 比較（opt-in）---
if [ "$ONLINE" = "1" ]; then
  if command -v gh >/dev/null 2>&1; then
    _latest=$(gh release view --repo s977043/plangate --json tagName --jq '.tagName' 2>/dev/null | sed 's/^v//' || printf '')
    if [ -n "$_latest" ]; then
      printf '[codex-plugin] latest release: v%s\n' "$_latest"
      [ "$_latest" != "${_repo_ver:-}" ] && printf '[codex-plugin] NOTE: repo(%s) != latest(%s)\n' "${_repo_ver:-?}" "$_latest"
    else
      printf '[codex-plugin] online: 最新リリース取得失敗（スキップ）\n'
    fi
  else
    printf '[codex-plugin] online: gh CLI 不在のためスキップ\n'
  fi
fi

exit 0
