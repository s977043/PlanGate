#!/usr/bin/env python3
# scripts/_apply_task_0143_patches.py
# TASK-0143: bin/plangate への CLI 配線パッチ (呼び出し元: apply-task-0143-eh457-wiring.sh)
import sys, os, difflib

if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} <repo_root> <dry_run_flag>", file=sys.stderr)
    sys.exit(1)

repo_root = sys.argv[1]
dry_run = sys.argv[2] == "1"
errors = 0


def patch_file(rel_path, old, new, label=""):
    global errors
    path = os.path.join(repo_root, rel_path)
    with open(path, encoding="utf-8") as f:
        content = f.read()
    if new in content:
        print(f"[SKIP] {label or rel_path}: already applied")
        return
    if old not in content:
        print(f"[ERROR] {label or rel_path}: target string not found", file=sys.stderr)
        errors += 1
        return
    new_content = content.replace(old, new, 1)
    if dry_run:
        old_lines = content.splitlines(keepends=True)
        new_lines = new_content.splitlines(keepends=True)
        diff = difflib.unified_diff(old_lines, new_lines,
                                    fromfile=rel_path, tofile=rel_path + " (patched)")
        lines = list(diff)
        sys.stdout.writelines(lines)
        if not lines:
            print(f"[NO DIFF] {rel_path}")
    else:
        bak = path + ".bak"
        with open(bak, "w", encoding="utf-8") as f:
            f.write(content)
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"[PATCHED] {rel_path}  (backup: {os.path.basename(bak)})")


# ======================================================================
# Patch 1: cmd_verify — EH-4 呼び出し（V-1 前 strict=1）
# ======================================================================
P1_OLD = (
    "  printf '[verify] Running V-1 (validate)...\\n'\n"
    '  if ! "$0" validate "$task_id"; then'
)
P1_NEW = (
    "  printf '[verify] Checking EH-4: test-cases.md present...\\n'\n"
    '  if ! PLANGATE_HOOK_STRICT=1 sh "$plangate_root/scripts/hooks/check-test-cases.sh" "$task_id"; then\n'
    '    printf \'[verify] EH-4 BLOCK -- create docs/working/%s/test-cases.md first\\n\' "$task_id" >&2\n'
    "    return 1\n"
    "  fi\n"
    "  printf '[verify] Running V-1 (validate)...\\n'\n"
    '  if ! "$0" validate "$task_id"; then'
)
patch_file("bin/plangate", P1_OLD, P1_NEW, "Patch 1: cmd_verify EH-4")

# ======================================================================
# Patch 2: cmd_verify — EH-5 呼び出し（V-1 後 warn）
# ======================================================================
P2_OLD = "  printf '[verify] Running settings task-lock check...\\n'"
P2_NEW = (
    "  printf '[verify] Checking EH-5: verification evidence present...\\n'\n"
    '  sh "$plangate_root/scripts/hooks/check-verification-evidence.sh" "$task_id" || true\n'
    "  printf '[verify] Running settings task-lock check...\\n'"
)
patch_file("bin/plangate", P2_OLD, P2_NEW, "Patch 2: cmd_verify EH-5")

# ======================================================================
# Patch 3: cmd_doctor — CLI Hook Wiring セクション追加
# ======================================================================
CLI_SECTION = r"""  printf '=== CLI Hook Wiring (EH-4/5/7) ===\n'
  _cli_hook_failures=0
  for _cli_hook_name in check-test-cases check-verification-evidence check-merge-approvals; do
    _cli_hook_path="$plangate_root/scripts/hooks/${_cli_hook_name}.sh"
    if [ -f "$_cli_hook_path" ] && [ -x "$_cli_hook_path" ]; then
      printf '  [PASS] %s.sh exists and is executable\n' "$_cli_hook_name"
    elif [ -f "$_cli_hook_path" ]; then
      printf '  [WARN] %s.sh exists but is not executable\n' "$_cli_hook_name"
    else
      printf '  [FAIL] %s.sh not found\n' "$_cli_hook_name"
      _cli_hook_failures=$((_cli_hook_failures + 1))
    fi
  done
  if [ "$_cli_hook_failures" -gt 0 ]; then
    failures=$((failures + _cli_hook_failures))
  fi
  if grep -q 'check-test-cases\.sh' "$plangate_root/bin/plangate" 2>/dev/null; then
    printf '  [PASS] EH-4 wired in bin/plangate verify\n'
  else
    printf '  [WARN] EH-4 not wired -- run: sh scripts/apply-task-0143-eh457-wiring.sh --apply\n'
  fi
  if grep -q 'check-verification-evidence\.sh' "$plangate_root/bin/plangate" 2>/dev/null; then
    printf '  [PASS] EH-5 wired in bin/plangate verify\n'
  else
    printf '  [WARN] EH-5 not wired -- run: sh scripts/apply-task-0143-eh457-wiring.sh --apply\n'
  fi
  printf '  [INFO] EH-7: run before merge: sh scripts/hooks/check-merge-approvals.sh <TASK-XXXX>\n'
  printf '\n'

"""
P3_OLD = "  printf '=== Optional Provider CLIs ===\\n'"
P3_NEW = CLI_SECTION + "  printf '=== Optional Provider CLIs ===\\n'"
patch_file("bin/plangate", P3_OLD, P3_NEW, "Patch 3: cmd_doctor CLI Hook Wiring")

if errors:
    print(f"\n=== FAILED: {errors} patch(es) could not be applied ===", file=sys.stderr)
    sys.exit(1)
print("\n=== all patches applied ===" if not dry_run else "\n=== dry-run complete ===")
