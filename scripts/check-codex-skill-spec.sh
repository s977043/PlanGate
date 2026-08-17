#!/bin/sh
# check-codex-skill-spec.sh — skill root の openai.yaml 仕様チェック
# 仕様: https://openai.com/academy/codex-plugins-and-skills/
#
# Usage: sh scripts/check-codex-skill-spec.sh [--warn-only] [--target DIR]...
#
# 既定 target は下の DEFAULT_TARGETS 宣言が正本。--target を 1 回でも指定すると
# 既定宣言を置き換える（複数回指定可）。
#
# Exit:
#   0 = violation なし
#   1 = violation あり（--warn-only 指定時は 0 を返す）
#   1 = python3 不在（環境不備。検査自体が走らないため --warn-only でも 1）
#
# 検査内容（#1109）:
#   1. presence（同値照合）— target 直下の「SKILL.md を持つディレクトリ」の集合と
#      「agents/openai.yaml を持つディレクトリ」の集合が一致すること。
#      片側だけに存在するものは violation。**絶対件数は契約値にしない**（skill は増える）。
#   2. field —  short_description(25-64) / default_prompt($name 含む) / icon_small / icon_large
#      ※ icon_* は「値が宣言されていること」のみを見る。値のパス実在は検査しない
#        （配布物 root の `./assets/...` は install 時に materialize される。#1109 R-005）
#   3. 検査対象から外したエントリは「件数と理由」を必ず出力する（silent skip 禁止 / #1109）
#   4. **target の不在は既定・明示を問わず violation**（#1109 R-001 / R-003）。
#      「見に行く先が無い」を緑にしない。既定 root を減らすときは下の宣言を
#      編集すること＝意識的なコード変更を強制する

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# ── 既定 target の宣言（declared default roots / #1109 R-001）──────────────────
# ここに宣言した root は **存在しなければ violation**（fail-closed）。
# 片方が消えても検査母数だけが静かに半減する、という事故を構造的に防ぐ。
#
# `.codex/skills`          … repo 内 Codex skill root
# `plugin/plangate/skills` … 配布物（marketplace 経路がそのまま読む実体）
#
# **#1086 で `.codex/skills` を untrack する場合はこの宣言から該当行を削除すること。**
# 削除しない限り CI が赤くなるため、「気づかないうちに検査範囲が半減する」ことはない。
# 逆に、削除は 1 行の意識的なコード変更として diff / レビューに必ず現れる。
DEFAULT_TARGETS='.codex/skills
plugin/plangate/skills'

WARN_ONLY=0
EXPLICIT_TARGET=0
TARGETS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --warn-only) WARN_ONLY=1; shift ;;
    --target)
      if [ $# -lt 2 ]; then
        printf '[spec-check] ERROR: --target requires a directory argument\n' >&2
        exit 1
      fi
      # 最初の --target で既定 2 root を破棄する（明示指定が既定を置き換える）
      if [ "$EXPLICIT_TARGET" -eq 0 ]; then
        TARGETS=""
        EXPLICIT_TARGET=1
      fi
      TARGETS="$TARGETS$2
"
      shift 2 ;;
    -h|--help)
      printf 'Usage: sh scripts/check-codex-skill-spec.sh [--warn-only] [--target DIR]...\n'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [ "$EXPLICIT_TARGET" -eq 0 ]; then
  # 宣言（相対パス）を REPO_ROOT 起点の絶対パスへ展開する
  _saved_ifs="$IFS"
  IFS='
'
  set -f
  for _d in $DEFAULT_TARGETS; do
    [ -n "$_d" ] || continue
    TARGETS="$TARGETS$REPO_ROOT/$_d
"
  done
  set +f
  IFS="$_saved_ifs"
fi

command -v python3 >/dev/null 2>&1 || { printf '[spec-check] ERROR: python3 is required\n' >&2; exit 1; }

# 改行区切りの TARGETS を位置パラメータへ展開（パスに空白が含まれても壊れない）
_saved_ifs="$IFS"
IFS='
'
set -f
# shellcheck disable=SC2086
set -- $TARGETS
set +f
IFS="$_saved_ifs"

# 検出（python）と rc 方針（shell）を分離する。python は「violation があれば必ず 1」
# だけを担い、--warn-only による rc=0 化は下の 1 箇所だけが行う（契約を二重実装
# しない = 片方を壊しても他方が隠す構造を作らない / #1109 変異検出力）。
_rc=0
python3 - "$REPO_ROOT" "$EXPLICIT_TARGET" "$@" << 'PYEOF' || _rc=$?
import os, re, sys

repo_root = sys.argv[1]
explicit = sys.argv[2] == '1'
targets = sys.argv[3:]
# target がどこから来たかは **メッセージの文言にしか使わない**。
# 「不在なら violation」は既定・明示で共通（#1109 R-001 / R-003）。
origin = 'explicit --target' if explicit else 'declared default target'

violations = []
inspected_targets = 0
total_skills = 0


def check_fields(label, name, yaml_path):
    """openai.yaml の必須フィールドを検査して violation を追加する。"""
    with open(yaml_path, encoding='utf-8') as fh:
        content = fh.read()

    # short_description: 25-64 chars
    m = re.search(r'short_description:\s*"([^"]*)"', content)
    if not m:
        violations.append(f'{label}/{name}: short_description missing')
    else:
        sd = m.group(1)
        if len(sd) < 25:
            violations.append(f'{label}/{name}: short_description too short ({len(sd)} chars, min 25): "{sd}"')
        elif len(sd) > 64:
            violations.append(f'{label}/{name}: short_description too long ({len(sd)} chars, max 64): "{sd}"')

    # default_prompt: must contain $skill-name
    m2 = re.search(r'default_prompt:\s*"([^"]*)"', content)
    if not m2:
        violations.append(f'{label}/{name}: default_prompt missing')
    else:
        dp = m2.group(1)
        if f'${name}' not in dp:
            violations.append(f'{label}/{name}: default_prompt does not contain "${name}": "{dp[:50]}"')

    # icon_small / icon_large
    if 'icon_small' not in content:
        violations.append(f'{label}/{name}: icon_small missing')
    if 'icon_large' not in content:
        violations.append(f'{label}/{name}: icon_large missing')


def root_label(target):
    """violation 行に出す root 識別子。REPO_ROOT 配下なら相対パスにする。

    basename だけだと `.codex/skills` と `plugin/plangate/skills` が
    どちらも `skills` になり、violation 行から root を特定できない（#1109 R-004）。
    """
    norm = os.path.normpath(target)
    root = os.path.normpath(repo_root)
    if norm == root:
        return '.'
    if norm.startswith(root + os.sep):
        return os.path.relpath(norm, root)
    return norm


def inspect(target):
    """1 つの target root を検査する。戻り値: 検査した skill 数（未検査なら None）。"""
    global inspected_targets
    label = root_label(target)
    if not os.path.isdir(target):
        # **既定 / 明示を問わず violation**（#1109 R-001 / R-003）。
        # 「宣言した見に行き先が無い」状態を緑にしない。既定 root を減らすときは
        # DEFAULT_TARGETS の宣言を編集する＝意識的なコード変更を強制する。
        violations.append(f'{label}: target directory not found ({origin})')
        print(f'[spec-check] NOT FOUND: {label} ({origin}) — 0 skills inspected')
        return None

    inspected_targets += 1
    skill_dirs = set()
    yaml_dirs = set()
    ignored = []
    for name in sorted(os.listdir(target)):
        if name.startswith('.'):
            ignored.append((name, 'dotfile / dot-directory'))
            continue
        path = os.path.join(target, name)
        if not os.path.isdir(path):
            ignored.append((name, 'not a directory'))
            continue
        has_skill = os.path.isfile(os.path.join(path, 'SKILL.md'))
        has_yaml = os.path.isfile(os.path.join(path, 'agents', 'openai.yaml'))
        if has_skill:
            skill_dirs.add(name)
        if has_yaml:
            yaml_dirs.add(name)
        if not has_skill and not has_yaml:
            ignored.append((name, 'no SKILL.md and no agents/openai.yaml'))

    # presence の同値照合（集合比較。絶対件数を契約値にしない）
    missing = sorted(skill_dirs - yaml_dirs)
    orphan = sorted(yaml_dirs - skill_dirs)
    for name in missing:
        violations.append(f'{label}/{name}: agents/openai.yaml missing (SKILL.md exists)')
    for name in orphan:
        violations.append(f'{label}/{name}: agents/openai.yaml exists but SKILL.md missing')

    checked = sorted(skill_dirs & yaml_dirs)
    for name in checked:
        check_fields(label, name, os.path.join(target, name, 'agents', 'openai.yaml'))

    print(
        '[spec-check] {t}: SKILL.md dirs={s} openai.yaml dirs={y} '
        'field-checked={c} missing-yaml={m} orphan-yaml={o} ignored={i}'.format(
            t=label, s=len(skill_dirs), y=len(yaml_dirs),
            c=len(checked), m=len(missing), o=len(orphan), i=len(ignored)))
    # skip したものは必ず件数と理由を出す（「見ていない」を緑にしない / #1109）
    for name, reason in ignored:
        print(f'[spec-check]   ignored: {name} — reason: {reason}')
    return len(skill_dirs)


try:
    for target in targets:
        n = inspect(target)
        if n is not None:
            total_skills += n

    if inspected_targets == 0:
        # 1 つも見ていない状態を「All PASS」と言わない（false green の再生産防止）
        violations.append(
            'no target directory was inspected — targets: ' + (', '.join(targets) or '(none)'))
except Exception as exc:  # noqa: BLE001 — 予期せぬ例外も traceback ではなく violation として扱う
    violations.append(f'internal error while inspecting targets: {exc!r}')

print(f'[spec-check] Checked {total_skills} skills across {inspected_targets} target(s)')
if violations:
    print(f'[spec-check] VIOLATIONS ({len(violations)}):')
    for v in violations:
        print(f'  - {v}')
    sys.exit(1)
else:
    print('[spec-check] All skills PASS spec check')
PYEOF

# --warn-only は「違反があっても後続を止めない」契約。violation・target 不在・
# 内部例外のいずれでも 0 を返す（冒頭コメントの契約と実挙動を一致させる / #1109）。
# rc 方針はこの 1 箇所が唯一の実装。
if [ "$WARN_ONLY" -eq 1 ]; then
  if [ "$_rc" -ne 0 ]; then
    printf '[spec-check] --warn-only: continuing despite findings (suppressed rc=%s)\n' "$_rc"
  fi
  exit 0
fi
exit "$_rc"
