#!/usr/bin/env python3
# scripts/_apply_task_0145_patches.py
# TASK-0145 / #527: EHS-1 配線パッチ（呼び出し元: apply-task-0145-ehs-wiring.sh）
#   EHS-1: validation_bias=strict 時に V-3 外部レビュー合格を必須化（block）。
#   発火条件 validation_bias は env PLANGATE_VALIDATION_BIAS で注入（conductor が
#   model-profiles.yaml の active profile から解決・エクスポートする）。
#   非 strict（既定 normal）では従来どおり warn のみ＝既存挙動不変。
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
# Patch EHS-1: cmd_verify の V-3 を validation_bias=strict 時に必須化（block）
# ======================================================================
P1_OLD = (
    "    standard|high-risk|critical)\n"
    "      printf '[verify] Running V-3 (external review)...\\n'\n"
    "      \"$0\" review \"$task_id\" --phase v3 || printf '[verify] V-3 returned non-zero\\n' >&2\n"
    "      ;;\n"
)
P1_NEW = (
    "    standard|high-risk|critical)\n"
    "      printf '[verify] Running V-3 (external review)...\\n'\n"
    "      if \"$0\" review \"$task_id\" --phase v3; then\n"
    "        :\n"
    "      else\n"
    "        # EHS-1 (TASK-0145 / #527): validation_bias=strict は V-3 合格を必須化\n"
    "        if [ \"${PLANGATE_VALIDATION_BIAS:-normal}\" = \"strict\" ]; then\n"
    "          printf '[verify] EHS-1 BLOCK -- validation_bias=strict requires a passing V-3 external review\\n' >&2\n"
    "          return 1\n"
    "        fi\n"
    "        printf '[verify] V-3 returned non-zero\\n' >&2\n"
    "      fi\n"
    "      ;;\n"
)
patch_file("bin/plangate", P1_OLD, P1_NEW, label="EHS-1 cmd_verify V-3 mandatory (strict)")

sys.exit(1 if errors else 0)
