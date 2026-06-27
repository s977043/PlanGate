#!/usr/bin/env python3
# scripts/_apply_task_0147_patches.py
# TASK-0147 / #527 follow-up: validation_bias の conductor export 配線
#   bin/plangate verify / handoff --verify が --profile <key> を受理し、
#   model-profiles.yaml の validation_bias を解決して PLANGATE_VALIDATION_BIAS
#   を内部 export する（EHS-1/2/3 の発火条件を実 run で供給）。
#   env で既に明示注入済みなら尊重（上書きしない）。normal/lenient は非発火。
#   workflow-conductor.md には profile→bias 運用の非強制の補足を追記する。
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


# shared: --profile から bias を解決し PLANGATE_VALIDATION_BIAS を export する block
def _export_block(profile_var):
    return (
        "  # validation_bias export (TASK-0147 / #527): --profile 指定時に解決し export。\n"
        "  # env で既に明示注入済みなら尊重（上書きしない）。normal/lenient は非発火。\n"
        f"  if [ -z \"${{PLANGATE_VALIDATION_BIAS:-}}\" ] && [ -n \"${profile_var}\" ]; then\n"
        f"    PLANGATE_VALIDATION_BIAS=$(python3 \"$plangate_root/scripts/_resolve_validation_bias.py\" \"${profile_var}\" \"$plangate_root/docs/ai/model-profiles.yaml\")\n"
        "    export PLANGATE_VALIDATION_BIAS\n"
        "  fi\n"
    )


# ======================================================================
# Patch 1: cmd_verify の --mode ループに --profile を追加し、直後で bias export
# ======================================================================
V_OLD = (
    "  mode_flag=\"\"\n"
    "  for arg in \"$@\"; do\n"
    "    case \"$arg\" in\n"
    "      --mode=*) mode_flag=\"${arg#--mode=}\" ;;\n"
    "    esac\n"
    "  done\n"
)
V_NEW = (
    "  mode_flag=\"\"\n"
    "  profile_flag=\"\"\n"
    "  for arg in \"$@\"; do\n"
    "    case \"$arg\" in\n"
    "      --mode=*) mode_flag=\"${arg#--mode=}\" ;;\n"
    "      --profile=*) profile_flag=\"${arg#--profile=}\" ;;\n"
    "    esac\n"
    "  done\n"
    + _export_block("profile_flag")
)
patch_file("bin/plangate", V_OLD, V_NEW, label="TASK-0147 cmd_verify --profile bias export")

# ======================================================================
# Patch 2: cmd_handoff の --verify ループに --profile を追加し、直後で bias export
# ======================================================================
H_OLD = (
    "  _handoff_verify=0\n"
    "  for _harg in \"$@\"; do\n"
    "    case \"$_harg\" in --verify) _handoff_verify=1 ;; esac\n"
    "  done\n"
)
H_NEW = (
    "  _handoff_verify=0\n"
    "  _handoff_profile=\"\"\n"
    "  for _harg in \"$@\"; do\n"
    "    case \"$_harg\" in\n"
    "      --verify) _handoff_verify=1 ;;\n"
    "      --profile=*) _handoff_profile=\"${_harg#--profile=}\" ;;\n"
    "    esac\n"
    "  done\n"
    + _export_block("_handoff_profile")
)
patch_file("bin/plangate", H_OLD, H_NEW, label="TASK-0147 cmd_handoff --profile bias export")

# ======================================================================
# Patch 3: workflow-conductor.md に profile→bias 運用の非強制の補足を追記
# ======================================================================
C_OLD = (
    "- **working-context.md** — ディレクトリ構造・ファイル定義\n"
)
C_NEW = (
    "- **working-context.md** — ディレクトリ構造・ファイル定義\n"
    "\n"
    "---\n"
    "\n"
    "## validation_bias の供給（TASK-0147 / #527・非強制の補足）\n"
    "\n"
    "strict profile（`model-profiles.yaml` の `validation_bias: strict`）で EHS-1/2/3 を\n"
    "実 run 発火させたい場合、conductor は V フェーズの CLI 呼び出しに `--profile <key>` を\n"
    "渡す（例: `bin/plangate verify <TASK> --mode <m> --profile gpt-5_5_pro`）。CLI が\n"
    "`model-profiles.yaml` から `validation_bias` を解決し `PLANGATE_VALIDATION_BIAS` を\n"
    "内部 export する。env で明示注入済みならそれを尊重する。normal/lenient profile では\n"
    "従来どおり非発火（既存挙動不変）。**強制は CLI 側（`bin/plangate`）に閉じており、\n"
    "本補足は運用ガイドであって強制力を持たない**。\n"
)
patch_file(".claude/agents/workflow-conductor.md", C_OLD, C_NEW,
           label="TASK-0147 workflow-conductor profile->bias note (non-enforcing)")

sys.exit(1 if errors else 0)
