#!/bin/sh
# scripts/gen-codex-agents.sh — .claude/agents/*.md と .codex/agents/*.toml の同期
# 既存 toml: sandbox_mode / model_reasoning_effort のみ更新（description/developer_instructions は保持）
# 欠落 toml: thin pointer テンプレートを新規生成
# 使い方: sh scripts/gen-codex-agents.sh [--check] [--agent NAME]
# #530 項目4

set -eu

_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
_agents_md="$_root/.claude/agents"
_agents_toml="$_root/.codex/agents"
_check=0; _target=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check) _check=1; shift ;;
    --agent) _target="$2"; shift 2 ;;
    *) printf 'Usage: gen-codex-agents.sh [--check] [--agent NAME]\n' >&2; exit 2 ;;
  esac
done

# model tier → model_reasoning_effort (docs/ai/model-profiles.md §11)
_effort_for() {
  case "$1" in
    explorer-agent|linter-fixer|retrospective-analyst|setup-coordinator|documentation-writer|skill-designer)
      printf 'low' ;;
    *) printf 'medium' ;;
  esac
}

# tools → sandbox_mode (valid: read-only | workspace-write)
_sandbox_for() {
  case "$1" in *Edit*|*Write*) printf 'workspace-write' ;; *) printf 'read-only' ;; esac
}

_updated=0; _created=0; _ok=0

for _md in "$_agents_md"/*.md; do
  [ -f "$_md" ] || continue
  _base="$(basename "$_md" .md)"
  case "$_base" in README) continue ;; esac
  [ -z "$_target" ] || [ "$_base" = "$_target" ] || continue

  _name="$(grep -m1 '^name:' "$_md" | sed 's/^name: *//')"
  _tools="$(grep -m1 '^tools:' "$_md" | sed 's/^tools: *//')"
  _name_snake="$(printf '%s' "$_name" | tr '-' '_')"
  _effort="$(_effort_for "$_name")"
  _sandbox="$(_sandbox_for "$_tools")"
  _toml="$_agents_toml/${_name_snake}.toml"

  if [ -f "$_toml" ]; then
    # 既存 toml: sandbox_mode と model_reasoning_effort のみ更新
    _cur_sandbox="$(grep -m1 'sandbox_mode' "$_toml" | sed 's/.*= *"\(.*\)".*/\1/')"
    _cur_effort="$(grep -m1 'model_reasoning_effort' "$_toml" | sed 's/.*= *"\(.*\)".*/\1/')"
    if [ "$_cur_sandbox" = "$_sandbox" ] && [ "$_cur_effort" = "$_effort" ]; then
      _ok=$((_ok + 1))
      continue
    fi
    if [ "$_check" = "1" ]; then
      printf 'DRIFT %s: sandbox=%s(want %s) effort=%s(want %s)\n' \
        "$_name_snake.toml" "$_cur_sandbox" "$_sandbox" "$_cur_effort" "$_effort"
      _updated=$((_updated + 1))
    else
      sed -i.bak \
        -e "s|^sandbox_mode = .*|sandbox_mode = \"${_sandbox}\"|" \
        -e "s|^model_reasoning_effort = .*|model_reasoning_effort = \"${_effort}\"|" \
        "$_toml" && rm -f "${_toml}.bak"
      printf 'updated %s (sandbox: %s→%s, effort: %s→%s)\n' \
        "$_name_snake.toml" "$_cur_sandbox" "$_sandbox" "$_cur_effort" "$_effort"
      _updated=$((_updated + 1))
    fi
  else
    # 欠落 toml: thin pointer テンプレートを生成
    _desc="$(grep -m1 '^description:' "$_md" | sed 's/^description: *//' | cut -c1-100)"
    if [ "$_check" = "1" ]; then
      printf 'MISSING %s.toml\n' "$_name_snake"
      _created=$((_created + 1))
    else
      cat > "$_toml" <<TOML
#:schema https://developers.openai.com/codex/config-schema.json

name = "${_name_snake}"
description = "${_desc}"

sandbox_mode = "${_sandbox}"
model_reasoning_effort = "${_effort}"

developer_instructions = """
詳細定義: \`.claude/agents/${_base}.md\` を必ず読む。本 TOML は thin pointer であり、実行時規約は markdown 側を正とする。
"""
TOML
      printf 'created %s.toml\n' "$_name_snake"
      _created=$((_created + 1))
    fi
  fi
done

if [ "$_check" = "1" ]; then
  printf 'check: %d drift, %d missing, %d ok\n' "$_updated" "$_created" "$_ok"
  [ "$_updated" -eq 0 ] && [ "$_created" -eq 0 ]
else
  printf 'gen-codex-agents: %d updated, %d created, %d ok\n' "$_updated" "$_created" "$_ok"
fi
