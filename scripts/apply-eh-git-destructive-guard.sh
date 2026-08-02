#!/bin/sh
# apply-eh-git-destructive-guard.sh — Hook EH-12（protected branch 上の破壊的
# git 操作 block）の適用スクリプト。
#
# 適用内容:
#   (a) scripts/check-git-destructive.sh（非 HO の staged source）を
#       scripts/hooks/check-git-destructive.sh へ設置 + 実行権付与
#   (b) .claude/settings.example.json（および存在すれば .claude/settings.json）の
#       hooks.PreToolUse へ matcher="Bash" のエントリを追加
#
# scripts/hooks/ と .claude/settings*.json は Hardening Override (HO) 対象
# （self-mod guard）。**AI は --dry-run 以外で実行してはならない**
# （docs/ai/ho-change-workflow.md 禁止事項。実害例: apply-ho-followups.sh を
# AI が誤実行し ci.yml を破損）。--apply 実行は Human-owned、または計画段階で
# 明示的に y 承認された AI 実行に限る（.claude/rules/responsibility-classes.md）。
#
# 冪等: 設置済み / 配線済みなら各ステップを skip して明示する。
#
# Usage:
#   sh scripts/apply-eh-git-destructive-guard.sh --dry-run   # diff プレビュー（書き込みなし）
#   sh scripts/apply-eh-git-destructive-guard.sh --apply     # 適用（Human 実行のみ）
# （引数は必須。無引数 / 不正引数 / 複数引数は exit 1）
#
# --apply 後の検証:
#   git diff scripts/hooks/check-git-destructive.sh .claude/settings.example.json
#   sh tests/extras/ta-58-git-destructive-guard.sh
#   bin/plangate doctor
#
# 正本: docs/ai/hook-enforcement.md § EH-12

set -eu

export PYTHONUTF8=1

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# --- 引数 strict 検証（誤適用防止）---
if [ "$#" -eq 0 ]; then
  printf 'ERROR: an argument is required. Usage: %s --dry-run|--apply\n' "$0" >&2
  exit 1
fi
if [ "$#" -gt 1 ]; then
  printf 'ERROR: exactly one argument allowed. Usage: %s --dry-run|--apply\n' "$0" >&2
  exit 1
fi
case "$1" in
  --dry-run) MODE="dry-run" ;;
  --apply) MODE="apply" ;;
  *) printf 'ERROR: invalid argument: %s. Usage: %s --dry-run|--apply\n' "$1" "$0" >&2; exit 1 ;;
esac

command -v python3 >/dev/null 2>&1 || { printf 'ERROR: python3 required\n' >&2; exit 1; }

SRC="$REPO_ROOT/scripts/check-git-destructive.sh"
DST="$REPO_ROOT/scripts/hooks/check-git-destructive.sh"

# --- アンカー検証 (1): staged source の存在 ---
if [ ! -f "$SRC" ]; then
  printf 'ERROR: staged source not found: %s\n' "$SRC" >&2
  exit 1
fi

# --- アンカー検証 (2): 配線先 settings の存在と hooks.PreToolUse アンカー ---
# settings.example.json は tracked（必須）。settings.json は各自の環境依存
# （gitignore 対象）なので存在するときだけ対象にする。
SETTINGS_EXAMPLE="$REPO_ROOT/.claude/settings.example.json"
if [ ! -f "$SETTINGS_EXAMPLE" ]; then
  printf 'ERROR: anchor file not found: .claude/settings.example.json\n' >&2
  exit 1
fi

TARGETS=".claude/settings.example.json"
if [ -f "$REPO_ROOT/.claude/settings.json" ]; then
  TARGETS="$TARGETS .claude/settings.json"
else
  printf '  [skip] .claude/settings.json (not present in this checkout; example only)\n'
fi

if [ "$MODE" = "apply" ]; then
  printf 'WARNING: this script writes to Hardening Override (HO) target files\n' >&2
  printf '         (scripts/hooks/ + .claude/settings*.json). AI must not run\n' >&2
  printf '         this with --apply (docs/ai/ho-change-workflow.md). Confirm\n' >&2
  printf '         this execution is by a Human (or session-explicit approved AI run).\n' >&2
fi

# --- (a) hook 本体を scripts/hooks/ へ設置 ---
if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
  printf '  [skip] scripts/hooks/check-git-destructive.sh (already up to date)\n'
elif [ "$MODE" = "dry-run" ]; then
  printf '  [dry-run] scripts/hooks/check-git-destructive.sh would be (re)installed from scripts/%s:\n' "$(basename "$SRC")"
  if [ -f "$DST" ]; then
    diff -u "$DST" "$SRC" | sed 's/^/    /' || true
  else
    printf '    (new file, %s lines)\n' "$(wc -l < "$SRC" | tr -d ' ')"
  fi
else
  mkdir -p "$REPO_ROOT/scripts/hooks"
  cp "$SRC" "$DST"
  chmod +x "$DST"
  printf '  [applied] scripts/hooks/check-git-destructive.sh installed\n'
fi

# --- (b) PreToolUse (matcher: Bash) へ配線 ---
_DRY=0
[ "$MODE" = "dry-run" ] && _DRY=1

python3 - "$REPO_ROOT" "$_DRY" "$TARGETS" <<'PY'
import difflib
import json
import os
import sys

repo, dry, targets = sys.argv[1], sys.argv[2] == "1", sys.argv[3].split()

HOOK_BASENAME = "check-git-destructive.sh"
CMD = "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/" + HOOK_BASENAME
COMMENT = (
    "Hook EH-12: protected branch (main/master) 上の破壊的 git 操作 block。"
    "current branch が main/master のときに限り git reset --hard / "
    "git push --force(-with-lease)/-f を block。それ以外のブランチ・"
    "detached HEAD・非 git では allow（誤検出ゼロ優先）。"
    "PLANGATE_BYPASS_HOOK=1 で常時 pass。"
)
ENTRY = {
    "_comment_": COMMENT,
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": CMD}],
}

changed_any = False
for rel in targets:
    path = os.path.join(repo, rel)
    with open(path, encoding="utf-8") as f:
        orig = f.read()
    d = json.loads(orig)

    hooks = d.get("hooks")
    if not isinstance(hooks, dict) or not isinstance(hooks.get("PreToolUse"), list):
        sys.stderr.write(
            "ERROR: anchor hooks.PreToolUse (array) not found in %s\n" % rel
        )
        sys.exit(1)
    pre = hooks["PreToolUse"]

    already = any(
        HOOK_BASENAME in h.get("command", "")
        for e in pre
        if isinstance(e, dict)
        for h in e.get("hooks", [])
        if isinstance(h, dict)
    )
    if already:
        sys.stderr.write("  [skip] %s (EH-12 already wired)\n" % rel)
        continue

    pre.append(ENTRY)
    new = json.dumps(d, ensure_ascii=False, indent=2) + "\n"
    changed_any = True
    if dry:
        sys.stdout.write(
            "".join(
                difflib.unified_diff(
                    orig.splitlines(True),
                    new.splitlines(True),
                    fromfile=rel,
                    tofile=rel + " (after)",
                )
            )
        )
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)
        sys.stderr.write("  [applied] %s wired with PreToolUse EH-12\n" % rel)

if not changed_any and not dry:
    sys.stderr.write("nothing to do (already wired)\n")
PY

printf '\n'
if [ "$MODE" = "dry-run" ]; then
  printf '=== --dry-run complete. No files were written. ===\n'
  printf 'To apply (Human only): sh scripts/apply-eh-git-destructive-guard.sh --apply\n'
else
  printf '=== apply complete. Verify: ===\n'
  printf '  git diff scripts/hooks/check-git-destructive.sh .claude/settings.example.json\n'
  printf '  sh tests/extras/ta-58-git-destructive-guard.sh\n'
  printf '  bin/plangate doctor\n'
fi
