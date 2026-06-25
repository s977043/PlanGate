#!/usr/bin/env python3
"""TASK-0144 apply-script: C-3 approval mode (cli/conversation)
Usage:
  python3 scripts/_apply_task_0144_patches.py <repo_root> <dry_run_flag>
  dry_run_flag: "1" = dry-run, "0" = apply
"""
import sys, os

if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} <repo_root> <dry_run_flag>", file=sys.stderr)
    sys.exit(1)

repo_root = sys.argv[1]
dry_run = sys.argv[2] == "1"
mode_label = "DRY-RUN" if dry_run else "APPLY"
ok = True


def patch_file(rel_path, old, new, description):
    global ok
    path = os.path.join(repo_root, rel_path)
    if not os.path.exists(path):
        print(f"  [ERROR] {rel_path}: file not found")
        ok = False
        return
    with open(path, encoding="utf-8") as f:
        content = f.read()
    if old not in content:
        if new.split('\n')[0] in content or (len(new) > 20 and new[:30] in content):
            print(f"  [SKIP]  {rel_path}: already applied ({description})")
        else:
            print(f"  [ERROR] {rel_path}: anchor not found ({description})")
            ok = False
        return
    new_content = content.replace(old, new, 1)
    if dry_run:
        lines_removed = old.count('\n') + 1
        lines_added = new.count('\n') + 1
        print(f"  [DIFF]  {rel_path}: {description} (-{lines_removed}/+{lines_added} lines)")
    else:
        bak = path + ".bak"
        with open(bak, "w", encoding="utf-8") as f:
            f.write(content)
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"  [DONE]  {rel_path}: {description} (.bak saved)")


def create_file(rel_path, content, description):
    global ok
    path = os.path.join(repo_root, rel_path)
    if os.path.exists(path):
        print(f"  [SKIP]  {rel_path}: already exists ({description})")
        return
    if dry_run:
        print(f"  [CREATE] {rel_path}: {description} ({len(content.splitlines())} lines)")
    else:
        os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  [DONE]  {rel_path}: {description}")


print(f"=== TASK-0144 patches ({mode_label}) ===\n")

# ─── Patch 1: schemas/plangate-config.schema.json (新規) ───────────────────
PLANGATE_CONFIG_SCHEMA = """{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/s977043/plangate/schemas/plangate-config.schema.json",
  "title": "PlanGate Project Config",
  "description": ".plangate.yml プロジェクト設定スキーマ（TASK-0144）",
  "type": "object",
  "properties": {
    "c3_approval": {
      "type": "object",
      "description": "C-3 承認モード設定",
      "properties": {
        "mode": {
          "type": "string",
          "enum": ["cli", "conversation"],
          "description": "C-3 承認モード: cli (デフォルト) または conversation"
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": true
}
"""
create_file("schemas/plangate-config.schema.json", PLANGATE_CONFIG_SCHEMA,
            "plangate-config schema 新規作成")

# ─── Patch 2: schemas/c3-approval.schema.json — source フィールド追加 ────────
C3_OLD = (
    '    "rejection_reason": {\n'
    '      "type": "string",\n'
    '      "description": "Required when c3_status is REJECTED"\n'
    '    },\n'
    '    "gate_checks": {'
)
C3_NEW = (
    '    "rejection_reason": {\n'
    '      "type": "string",\n'
    '      "description": "Required when c3_status is REJECTED"\n'
    '    },\n'
    '    "source": {\n'
    '      "type": "string",\n'
    '      "enum": ["cli", "conversation"],\n'
    '      "description": "承認の発行元: cli (bin/plangate approve) または conversation (AI が会話内 APPROVE 後に生成 / TASK-0144)"\n'
    '    },\n'
    '    "gate_checks": {'
)
patch_file("schemas/c3-approval.schema.json", C3_OLD, C3_NEW,
           "c3-approval.schema.json: source フィールド追加")


# ─── Patch 3: scripts/hooks/check-plan-hash.sh — conversation モード経路 ─────
EH3_OLD = (
    '  # (iii)-(v) maintenance valid + scope + one-shot atomic consume\n'
    '  _maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"'
)

EH3_NEW_LINES = [
    '  # [TASK-0144] C-3 conversation mode: c3.json auto-generate path',
    '  # approvals/c3.json + conversation mode -> SKIP (通す。中身検証は EH-2 と AI 生成コードに委ねる)',
    '  case "$_norm_target" in',
    '    docs/working/TASK-*/approvals/c3.json)',
    '      _cfg_yml="$REPO_ROOT/.plangate.yml"',
    '      _c3mode="cli"',
    '      if [ -f "$_cfg_yml" ]; then',
    "        _c3mode=$(python3 - \"$_cfg_yml\" 2>/dev/null <<'PYC3'",
    'import sys',
    'cfg_path = sys.argv[1]',
    'try:',
    '    import yaml',
    '    with open(cfg_path, "r", encoding="utf-8") as f:',
    '        d = yaml.safe_load(f)',
    '    if not isinstance(d, dict):',
    '        print("cli"); sys.exit(0)',
    '    m = (d.get("c3_approval") or {}).get("mode", "cli")',
    '    print(m if m in ("cli", "conversation") else "cli")',
    'except Exception:',
    '    print("cli")',
    'PYC3',
    ') || _c3mode="cli"',
    '      fi',
    '      if [ "$_c3mode" = "conversation" ]; then',
    '        _dlog_c3="$WORKING_DIR/_audit/skip-decision-log.jsonl"',
    '        mkdir -p "$(dirname "$_dlog_c3")"',
    "        _ts_c3=$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "        _esc_c3=$(printf '%s' \"${_norm_target:-unknown}\" | tr -d '\\\\n\\\\r\\\\t')",
    '        printf \'{"ts":"%s","event":"EH-3_C3_CONVERSATION_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\\n\' "$_ts_c3" "$_esc_c3" >>"$_dlog_c3"',
    '        reason="C3_CONVERSATION_SKIP: c3.json target (${_norm_target:-unknown}) -- conversation mode, auto-allowed"',
    '        log_event "C3_CONVERSATION_SKIP" "$reason"',
    "        printf '[Hook EH-3 C3_CONVERSATION_SKIP] %s\\n' \"$reason\"",
    '        exit 0',
    '      fi',
    '      ;;',
    '  esac',
    '',
    '  # (iii)-(v) maintenance valid + scope + one-shot atomic consume',
    '  _maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"',
]
EH3_NEW = '\n'.join(EH3_NEW_LINES)

patch_file("scripts/hooks/check-plan-hash.sh", EH3_OLD, EH3_NEW,
           "EH-3: conversation モード c3.json SKIP 経路追加")


# ─── Patch 4a: bin/plangate — _read_plangate_config() 追加 ──────────────────
# bin/plangate 内の plangate_yaml_c3_artifacts 関数の PYEOF\n} の直後 (# ── commands ── の前) に追加
import re

def patch_bin_plangate_4a(repo_root, dry_run):
    global ok
    path = os.path.join(repo_root, "bin/plangate")
    if not os.path.exists(path):
        print(f"  [ERROR] bin/plangate: file not found")
        ok = False
        return
    with open(path, encoding="utf-8") as f:
        content = f.read()

    marker_start = '\n# ── commands ──'
    if '_read_plangate_config()' in content:
        print("  [SKIP]  bin/plangate: _read_plangate_config already applied")
        return

    idx = content.find(marker_start)
    if idx == -1:
        print("  [ERROR] bin/plangate: '# ── commands ──' anchor not found")
        ok = False
        return

    func_lines = [
        '',
        "# [TASK-0144] .plangate.yml から設定値を読む（c3_approval.mode 等）",
        "# 使い方: _read_plangate_config <key>  (例: c3_approval.mode)",
        "# .plangate.yml 未存在 -> 'cli' (デフォルト)",
        "# PyYAML 未インストール・不正 YAML・不正 mode 値 -> stderr WARN + 'cli'",
        "_read_plangate_config() {",
        '  _rpc_key="${1:-c3_approval.mode}"',
        '  _rpc_cfg="$plangate_root/.plangate.yml"',
        '  if [ ! -f "$_rpc_cfg" ]; then',
        "    printf 'cli'",
        '    return 0',
        '  fi',
        "  _rpc_val=$(python3 - \"$_rpc_cfg\" \"$_rpc_key\" <<'PYC'",
        'import sys',
        'cfg_path, key = sys.argv[1], sys.argv[2]',
        'try:',
        '    import yaml',
        '    with open(cfg_path, "r", encoding="utf-8") as f:',
        '        d = yaml.safe_load(f)',
        '    if not isinstance(d, dict):',
        '        sys.stderr.write("warn: .plangate.yml is not a YAML mapping\\n")',
        '        print("cli"); sys.exit(0)',
        '    val = d',
        '    for part in key.split("."):',
        '        if not isinstance(val, dict):',
        '            sys.stderr.write("warn: .plangate.yml key path broken: {}\\n".format(key))',
        '            print("cli"); sys.exit(0)',
        '        val = val.get(part)',
        '    if val is None:',
        '        print("cli"); sys.exit(0)',
        '    allowed = {"cli", "conversation"}',
        '    if str(val) not in allowed:',
        '        sys.stderr.write("warn: .plangate.yml {}: invalid value: {}\\n".format(key, val))',
        '        print("cli"); sys.exit(0)',
        '    print(str(val))',
        'except ImportError:',
        '    sys.stderr.write("warn: PyYAML not installed; falling back to cli mode\\n")',
        '    print("cli")',
        'except Exception as e:',
        '    sys.stderr.write("warn: .plangate.yml read error: {}\\n".format(e))',
        '    print("cli")',
        'PYC',
        ') || _rpc_val="cli"',
        '  [ -n "$_rpc_val" ] || _rpc_val="cli"',
        "  printf '%s' \"$_rpc_val\"",
        '}',
        '',
    ]
    func_text = '\n'.join(func_lines)

    new_content = content[:idx] + func_text + content[idx:]
    if dry_run:
        print(f"  [DIFF]  bin/plangate: _read_plangate_config() 追加 (+{len(func_lines)} lines)")
    else:
        bak = path + ".bak"
        with open(bak, "w", encoding="utf-8") as f:
            f.write(content)
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"  [DONE]  bin/plangate: _read_plangate_config() 追加 (.bak saved)")

patch_bin_plangate_4a(repo_root, dry_run)

# ─── Patch 4b: bin/plangate — cmd_approve に source: cli 追加 ────────────────
BIN_4B_OLD = (
    '    "plan_hash": phash,\n'
    '    "_approved_by_source": "git-config",\n'
    '    "_approver_identity_unverified": True,\n'
)
BIN_4B_NEW = (
    '    "plan_hash": phash,\n'
    '    "source": "cli",\n'
    '    "_approved_by_source": "git-config",\n'
    '    "_approver_identity_unverified": True,\n'
)
patch_file("bin/plangate", BIN_4B_OLD, BIN_4B_NEW,
           "bin/plangate: cmd_approve c3.json に source: cli 追加")

# ─── Patch 4c: bin/plangate — doctor に C-3 Approval Mode セクション追加 ──────
BIN_4C_OLD = "  printf '=== Optional Provider CLIs ===\\n'"
BIN_4C_NEW = (
    "  printf '=== C-3 Approval Mode ===\\n'\n"
    "  _c3mode_doctor=$(_read_plangate_config c3_approval.mode 2>/dev/null || echo 'cli')\n"
    "  if [ -f \"$plangate_root/.plangate.yml\" ]; then\n"
    "    printf '  [INFO] .plangate.yml found: c3_approval.mode=%s\\n' \"$_c3mode_doctor\"\n"
    "  else\n"
    "    printf '  [INFO] .plangate.yml not found (default: c3_approval.mode=cli)\\n'\n"
    "  fi\n"
    "  printf '\\n'\n"
    "\n"
    "  printf '=== Optional Provider CLIs ===\\n'"
)
patch_file("bin/plangate", BIN_4C_OLD, BIN_4C_NEW,
           "bin/plangate: doctor に C-3 Approval Mode セクション追加")

print(f"\n=== Done ({mode_label}): {'OK' if ok else 'ERRORS found'} ===")
if not ok:
    sys.exit(1)
