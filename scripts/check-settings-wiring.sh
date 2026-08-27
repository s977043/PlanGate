#!/bin/sh
# check-settings-wiring.sh — settings wiring 契約 構造検証（TASK-0080 S1b / V-3 CR-2）
#
# 正本: docs/ai/settings-wiring-contract.md
# grep ではなく JSON 構造（.hooks.PreToolUse[].matcher / hooks[].command）を
# python で検証する（_comment_ 誤検出・別 matcher・無効 JSON を排除）。
#
#   sh scripts/check-settings-wiring.sh [--target user|example]
# exit 0=準拠（WARN を含みうる） / 1=逸脱(不足列挙) / 2=対象不在・無効JSON
#
# severity レーン（#1259）:
#   - `--target example` = `.claude/settings.example.json`（**tracked**）。
#     repo 側の配線契約であり、CI（.github/workflows/ci.yml）が実行する。
#     ここでの不足は **FAIL**（exit 1）。
#   - `--target user` = `.claude/settings.json`（**untracked** / .gitignore 対象）。
#     適用は Human-owned（scripts/apply-claude-settings.sh）。tracked 側で担保
#     済みの check をここで hard FAIL にすると、既存インストールの
#     `doctor --check-settings` が一斉に赤くなり settings タスクロックが
#     止まるため、そうした check は **WARN**（exit 0 のまま列挙）とする。
#   - 既存 6 項目（EH-1/2/6/3/EH-3 引数/EH-9）は従来どおり **両レーンとも
#     FAIL**（退行させない）。
#
# 残存脅威モデル（完全性を主張しない / #1259）:
#   守るもの: `.claude/settings*.json` の PreToolUse に、下記 checks の hook が
#     期待 matcher で 1 件以上存在すること（JSON 構造として）。
#   守らないもの: hook が実際に発火するか / block するか（= runtime 検証）、
#     `.claude/settings.local.json` / `.codex/hooks.json` / `.cursor/hooks.json` 側の
#     配線、hook スクリプト本体の中身、本検査器と REQUIRED_CHECK_IDS を
#     同時に書き換える改変。これらは C-4 Human レビュー・ tests/extras 側の
#     ガード・HO（Hardening Override）による編集禁止が担う多層防御の別層。
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target=user
case "${1:-}" in --target) target=${2:-user} ;; --target=*) target=${1#--target=} ;; esac
case "$target" in
  user)    F="$ROOT/.claude/settings.json" ;;
  example) F="$ROOT/.claude/settings.example.json" ;;
  *) printf 'error: --target must be user|example\n' >&2; exit 2 ;;
esac
python3 - "$F" "$target" <<'PY'
import json, sys
F, target = sys.argv[1], sys.argv[2]
try:
    with open(F) as fh:
        doc = json.load(fh)
except FileNotFoundError:
    if target == "user":
        print(f"[check-settings] FAIL: {F} 不在（settings 未適用）", file=sys.stderr)
        print("  → sh scripts/apply-claude-settings.sh を実行してください", file=sys.stderr)
        sys.exit(1)
    print(f"[check-settings] FAIL: {F} 不在", file=sys.stderr); sys.exit(2)
except (json.JSONDecodeError, OSError) as e:
    print(f"[check-settings] FAIL: {F} 無効 JSON: {e}", file=sys.stderr); sys.exit(2)

pre = ((doc or {}).get("hooks", {}) or {}).get("PreToolUse", [])
# PreToolUse 内 hooks[].command（_comment_ は無視）を matcher 別に収集
cmds = []
for blk in pre if isinstance(pre, list) else []:
    if not isinstance(blk, dict):
        continue
    matcher = blk.get("matcher", "")
    for h in blk.get("hooks", []) or []:
        if isinstance(h, dict) and h.get("type") == "command":
            cmds.append((matcher, h.get("command", "")))

def has(substr, matcher_re=None):
    import re
    for m, c in cmds:
        # matcher `""`（省略）/ `"*"` は全ツールに発火するため、任意の
        # matcher_re を満たすものとして扱う。ここを厳密一致にすると
        # apply-claude-settings.sh 側の包含判定（`*` を全ツール集合とみなす）
        # と解釈がずれ、apply が「配線済み」と判断したものを本検証が
        # 「不足」と言い続けて **何度実行しても収束しない**（#928 MJ-1）。
        if substr in c and (matcher_re is None
                            or (m or "").strip() in ("", "*")
                            or re.search(matcher_re, m)):
            return True
    return False

# severity レーン（#1259）。詳細は本ファイル冒頭のコメントを参照。
FAIL_BOTH = {"example": "FAIL", "user": "FAIL"}
TRACKED_FAIL = {"example": "FAIL", "user": "WARN"}

# (check id, command 部分文字列, matcher 正規表現, ラベル, severity レーン)
checks = [
    ("EH-1", "check-plan-exists.sh", "Edit|Write", "EH-1 plan-exists", FAIL_BOTH),
    ("EH-2", "check-c3-approval.sh", "Edit|Write", "EH-2 c3-approval", FAIL_BOTH),
    ("EH-6", "check-forbidden-files.sh", "Edit|Write", "EH-6 forbidden-files", FAIL_BOTH),
    ("EH-3", "check-plan-hash.sh", "Edit|Write", "EH-3 plan-hash", FAIL_BOTH),
    ("EH-3-FILE-ARG", "${PLANGATE_HOOK_FILE:-}", "Edit|Write",
     "EH-3 の PLANGATE_HOOK_FILE 引数(P4(d)/AC-8)", FAIL_BOTH),
    ("EH-9", "check-delegation-commit-boundary.sh", "Bash",
     "EH-9 delegation-commit-boundary(TASK-0073)", FAIL_BOTH),
    # EH-13 承認トークンガード（#1259）。`Edit|Write` と `Bash` の **両方** に
    # 配線されている必要がある（片方だけだと、もう一方の経路から
    # 承認トークンを書けてしまう）ので、matcher 別に 2 エントリで検査する。
    ("EH-13-EDIT-WRITE", "check-approval-token-write.sh", "Edit|Write",
     "EH-13 approval-token-write (matcher: Edit|Write)", TRACKED_FAIL),
    ("EH-13-BASH", "check-approval-token-write.sh", "Bash",
     "EH-13 approval-token-write (matcher: Bash)", TRACKED_FAIL),
]

# 検査器自身の健全性（vacuous PASS 防止 / #1259）。checks 表が削られたまま
# PASS しないよう、必須 check id の **集合の包含** を確かめる。
# 件数は assert しない（将来 check を追加しても無関係な PR が落ちないように）。
REQUIRED_CHECK_IDS = (
    "EH-1", "EH-2", "EH-6", "EH-3", "EH-3-FILE-ARG", "EH-9",
    "EH-13-EDIT-WRITE", "EH-13-BASH",
)
_present = {c[0] for c in checks}
_self_missing = [i for i in REQUIRED_CHECK_IDS if i not in _present]
if _self_missing:
    for i in _self_missing:
        print(f"[check-settings] 検査器の自己健全性 NG: check 定義が不足: {i}",
              file=sys.stderr)
    print("[check-settings] FAIL: 検査器自身が壊れています"
          "（checks 表 / REQUIRED_CHECK_IDS を確認）", file=sys.stderr)
    sys.exit(1)

miss = []
warn = []
for _cid, sub, mre, label, sev in checks:
    if has(sub, mre):
        continue
    if sev.get(target, "FAIL") == "WARN":
        warn.append(label)
    else:
        miss.append(label)

for w in warn:
    print(f"[check-settings] WARN: 不足: {w}", file=sys.stderr)
if warn:
    print(f"  → sh scripts/apply-claude-settings.sh で取り込めます"
          f"（target={target} は untracked のため WARN 扱い / #1259）", file=sys.stderr)

if miss:
    for m in miss:
        print(f"[check-settings] 不足: {m}", file=sys.stderr)
    print(f"[check-settings] FAIL: settings wiring 契約 逸脱(target={target})", file=sys.stderr)
    print("  契約: docs/ai/settings-wiring-contract.md / 適用: scripts/apply-claude-settings.sh", file=sys.stderr)
    sys.exit(1)
print(f"[check-settings] PASS: settings wiring 契約準拠(target={target})"
      + (f" ※WARN {len(warn)} 件" if warn else ""))
sys.exit(0)
PY
