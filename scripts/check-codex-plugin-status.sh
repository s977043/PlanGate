#!/bin/sh
# check-codex-plugin-status.sh — Codex Plugin の登録・version・skill 数をローカル検査（#451）
#
# ネットワーク不要のローカル状態確認。`codex plugin marketplace list` が存在しない
# 現行 CLI でも動くよう、Codex のローカル状態（config.toml + plugin cache）を直接検査する。
#
# #1085: **marketplace を add しただけでは plugin はロードされない**。
#   `codex plugin marketplace add <src>`  → $CODEX_HOME/.tmp/marketplaces/<mp>/ が作られる
#   `codex plugin add <plugin>@<mp>`      → $CODEX_HOME/config.toml に
#                                            [plugins."<plugin>@<mp>"] enabled = true が入り、
#                                            $CODEX_HOME/plugins/cache/<mp>/<plugin>/<ver>/ へ展開される
#   Codex がモデルに見せる skill root は **後者**（plugins/cache/.../skills）。
# 旧実装は前者（marketplace cache ディレクトリ）の存在だけで `registered: YES` を返して
# いたため、plugin が 1 件もロードされていない環境でも doctor が緑になっていた。
# 本スクリプトは 2 つの事実を分離して出力し、`registered:` は **install 済みか**を表す。
#
# cache path は Codex CLI 実装依存（CODEX_HOME 既定: ~/.codex）。
# 実装変更で path が変わり得るため、未検出でも fatal にせず「未導入」案内に留める。
# TODO: `codex plugin list --json` 等の公式 status API が提供されたら、
#       ローカル layout の直接検査からそのコマンド出力ベースへ移行する。
#
# Usage: sh scripts/check-codex-plugin-status.sh [--online]
#   --online: GitHub 最新リリースとの version 比較（opt-in、ネットワーク使用）
# Exit: 常に 0（doctor の非 fatal セクション想定。検査結果は stdout に出す）

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ONLINE=0
[ "${1:-}" = "--online" ] && ONLINE=1

CODEX_HOME="${CODEX_HOME:-${HOME:-}/.codex}"
REPO_SLUG="s977043/plangate"  # GitHub リポジトリ slug（表記ゆれ防止のため 1 箇所に集約）
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

# --- plugin install 検査（#1085: これが「ロードされるか」を決める）---
# config.toml の [plugins."plangate@<mp>"] enabled=true と
# plugins/cache/<mp>/plangate/<ver>/skills の実体、両方が揃って初めて install 済み。
_install_info=$(python3 - "$CODEX_HOME" << 'PYI' 2>/dev/null || printf ''
import os, re, sys
home = sys.argv[1]
cfg = os.path.join(home, 'config.toml')
enabled = []
try:
    section = None
    with open(cfg, encoding='utf-8') as f:
        for line in f:
            s = line.strip()
            m = re.match(r'^\[plugins\."plangate@([^"]+)"\]$', s)
            if m:
                section = m.group(1)
                continue
            if s.startswith('['):
                section = None
                continue
            if section and re.match(r'^enabled\s*=\s*true$', s):
                enabled.append(section)
                section = None
except OSError:
    pass
for mp in enabled:
    base = os.path.join(home, 'plugins', 'cache', mp, 'plangate')
    if not os.path.isdir(base):
        continue
    for ver in sorted(os.listdir(base)):
        skills = os.path.join(base, ver, 'skills')
        if os.path.isdir(skills):
            n = len([d for d in os.listdir(skills)
                     if os.path.isdir(os.path.join(skills, d)) and not d.startswith('.')])
            print('%s\t%s\t%s\t%s' % (mp, ver, os.path.join(base, ver), n))
            break
PYI
)
if [ -n "$_install_info" ]; then
  _inst_mp=$(printf '%s' "$_install_info" | head -1 | cut -f1)
  _inst_ver=$(printf '%s' "$_install_info" | head -1 | cut -f2)
  _inst_root=$(printf '%s' "$_install_info" | head -1 | cut -f3)
  _inst_skills=$(printf '%s' "$_install_info" | head -1 | cut -f4)
  printf '[codex-plugin] registered: YES (installed: plangate@%s v%s skills=%s)\n' \
    "$_inst_mp" "$_inst_ver" "$_inst_skills"
  printf '[codex-plugin] plugin root: %s\n' "$_inst_root"
  if [ -n "${_repo_ver:-}" ] && [ "$_inst_ver" != "$_repo_ver" ]; then
    printf '[codex-plugin] NOTE: installed(%s) != repo(%s) — 更新: codex plugin marketplace upgrade plangate && codex plugin add plangate@%s\n' \
      "$_inst_ver" "$_repo_ver" "$_inst_mp"
  fi
else
  printf '[codex-plugin] registered: NO (plugin が Codex に install されていない)\n'
  printf '[codex-plugin] 導入: codex plugin marketplace add %s && codex plugin add plangate@plangate\n' "$REPO_SLUG"
fi

# --- Codex marketplace cache 検査（marketplace の add 状態 / install とは別事実）---
if [ -d "$MP_CACHE" ]; then
  printf '[codex-plugin] marketplace cache: FOUND (%s)\n' "$MP_CACHE"
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
  printf '[codex-plugin] marketplace cache: NOT FOUND (%s)\n' "$MP_CACHE"
fi

# --- online 比較（opt-in）---
if [ "$ONLINE" = "1" ]; then
  if command -v gh >/dev/null 2>&1; then
    _latest=$(gh release view --repo "$REPO_SLUG" --json tagName --jq '.tagName' 2>/dev/null | sed 's/^v//' || printf '')
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
