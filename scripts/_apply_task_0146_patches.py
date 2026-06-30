#!/usr/bin/env python3
# scripts/_apply_task_0146_patches.py
# TASK-0146 / #527: EHS-2/3 配線パッチ（呼び出し元: apply-task-0146-ehs23-wiring.sh）
#   EHS-3: validation_bias=strict 時に V-1 fix-loop 上限超過を block。
#   EHS-2: `handoff --verify` で handoff.md 6 要素を validation_bias=strict 時に block。
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
    try:
        with open(path, encoding="utf-8") as f:
            content = f.read()
    except OSError as e:
        print(f"[ERROR] {label or rel_path}: cannot read file: {e}", file=sys.stderr)
        errors += 1
        return
    if new in content:
        print(f"[SKIP] {label or rel_path}: already applied")
        return
    if old not in content:
        print(f"[ERROR] {label or rel_path}: target string not found", file=sys.stderr)
        errors += 1
        return
    new_content = content.replace(old, new, 1)
    if dry_run:
        diff = difflib.unified_diff(
            content.splitlines(keepends=True),
            new_content.splitlines(keepends=True),
            fromfile=rel_path, tofile=rel_path + " (patched)")
        lines = list(diff)
        sys.stdout.writelines(lines)
        if not lines:
            print(f"[NO DIFF] {rel_path}")
    else:
        try:
            with open(path + ".bak", "w", encoding="utf-8") as f:
                f.write(content)
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_content)
        except OSError as e:
            print(f"[ERROR] {label or rel_path}: cannot write file: {e}", file=sys.stderr)
            errors += 1
            return
        print(f"[PATCHED] {rel_path}  (backup: {os.path.basename(path)}.bak)")


# ======================================================================
# Patch EHS-3: cmd_verify の V-1 失敗経路に fix-loop increment + strict block を追加
# ======================================================================
P1_OLD = (
    "    printf '[verify] V-1 FAILED — stop\\n' >&2\n"
    "    return 1\n"
    "  fi\n"
    "  printf '[verify] Checking EH-5: verification evidence present...\\n'\n"
)
P1_NEW = (
    "    # EHS-3 (TASK-0146 / #527): fix-loop カウンタ increment + strict 時 block\n"
    "    if [ \"${PLANGATE_VALIDATION_BIAS:-normal}\" = \"strict\" ]; then\n"
    "      # EHS-3 BLOCK\n"
    "      PLANGATE_HOOK_STRICT=1 sh \"$plangate_root/scripts/hooks/check-fix-loop.sh\" \"$task_id\" increment || return 1\n"
    "    else\n"
    "      sh \"$plangate_root/scripts/hooks/check-fix-loop.sh\" \"$task_id\" increment 2>/dev/null || true\n"
    "    fi\n"
    "    printf '[verify] V-1 FAILED — stop\\n' >&2\n"
    "    return 1\n"
    "  fi\n"
    "  printf '[verify] Checking EH-5: verification evidence present...\\n'\n"
)
patch_file("bin/plangate", P1_OLD, P1_NEW, label="EHS-3 cmd_verify fix-loop increment (strict)")

# ======================================================================
# Patch EHS-2: cmd_handoff に --verify フラグ + check-handoff-elements.sh を追加
# ======================================================================
P2_OLD = (
    "  if [ -z \"$task_id\" ]; then\n"
    "    printf 'Usage: plangate handoff <TASK-XXXX>\\n' >&2\n"
    "    return 2\n"
    "  fi\n"
    "  work_dir=\"$plangate_working_dir/$task_id\"\n"
    "  template=\"$plangate_root/docs/working/templates/handoff.md\"\n"
)
P2_NEW = (
    "  if [ -z \"$task_id\" ]; then\n"
    "    printf 'Usage: plangate handoff <TASK-XXXX>\\n' >&2\n"
    "    return 2\n"
    "  fi\n"
    "  # EHS-2 (TASK-0146 / #527): --verify で handoff.md の 6 要素を検査\n"
    "  _handoff_verify=0\n"
    "  for _harg in \"$@\"; do\n"
    "    case \"$_harg\" in --verify) _handoff_verify=1 ;; esac\n"
    "  done\n"
    "  if [ \"$_handoff_verify\" = \"1\" ]; then\n"
    "    if [ \"${PLANGATE_VALIDATION_BIAS:-normal}\" = \"strict\" ]; then\n"
    "      # EHS-2 BLOCK\n"
    "      PLANGATE_HOOK_STRICT=1 sh \"$plangate_root/scripts/hooks/check-handoff-elements.sh\" \"$task_id\" || return 1\n"
    "    else\n"
    "      sh \"$plangate_root/scripts/hooks/check-handoff-elements.sh\" \"$task_id\" 2>/dev/null || true\n"
    "    fi\n"
    "    return 0\n"
    "  fi\n"
    "  work_dir=\"$plangate_working_dir/$task_id\"\n"
    "  template=\"$plangate_root/docs/working/templates/handoff.md\"\n"
)
patch_file("bin/plangate", P2_OLD, P2_NEW, label="EHS-2 cmd_handoff --verify flag (strict)")

sys.exit(1 if errors else 0)
