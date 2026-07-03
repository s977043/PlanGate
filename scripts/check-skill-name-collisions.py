#!/usr/bin/env python3
"""
check-skill-name-collisions.py — plugin / repo-local 間のスキル名多重定義の検出

Issue #692.

複数 plugin（plangate / growth-core / river-review 等）と repo-local
`.claude/skills/` を併用する環境では、同名・同目的の skill / command /
agent が多重定義されうる。エージェントのスキル選択が曖昧になり、どの定義が
使われたか利用者にも追跡できない（interactive-ocean 実例: self-review が
repo-local / growth-core / plangate の 3 重定義、setup-team が 4 重定義）。

本スクリプトは複数の定義ルート（既定: `.claude/skills`, `.claude/commands`,
`.claude/agents` と `plugin/*/skills`, `plugin/*/commands`, `plugin/*/agents`）
を走査し、同一 name が複数ルートに定義される衝突を検出する。

対象:
    - skills: `<root>/<skill-name>/SKILL.md` の frontmatter `name:`
    - commands: `<root>/*.md` の frontmatter `name:`（無ければファイル名）
    - agents: `<root>/*.md` の frontmatter `name:`（無ければファイル名）

配線について: 本スクリプトはスタンドアロンの静的解析であり、
doctor（bin/plangate）への統合は Hardening Override 対象のため別 PBI の
follow-up とする（docs/ai/skill-collision-detection.md 参照）。

Usage:
    python3 scripts/check-skill-name-collisions.py
    python3 scripts/check-skill-name-collisions.py --extra-root <path>
    python3 scripts/check-skill-name-collisions.py --selftest

Exit codes:
    0 — 衝突なし
    1 — 衝突あり
    2 — 引数エラー
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# frontmatter `key: value` 抽出（先頭 `---` ブロック内のみ対象）
FRONTMATTER_KV_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$")

DESCRIPTION_PREVIEW_LEN = 80


@dataclass
class Definition:
    name: str
    kind: str  # "skill" | "command" | "agent"
    root_label: str  # 例: "repo-local" / "plugin:plangate"
    path: Path
    description: str = ""


@dataclass
class Collision:
    name: str
    kind: str
    definitions: list[Definition] = field(default_factory=list)

    @property
    def description_differs(self) -> bool:
        descs = {_normalize_description(d.description) for d in self.definitions}
        return len(descs) > 1


def _normalize_description(desc: str) -> str:
    return " ".join(desc.split()).strip()


def parse_frontmatter(path: Path) -> dict[str, str]:
    """Markdown ファイル先頭の YAML-ish frontmatter を素朴にパースする。

    フル YAML パーサは使わず、`key: value` 行のみを拾う軽量実装
    （本リポジトリの SKILL.md / agent.md は単純な frontmatter のみ使用）。
    """
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}

    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    result: dict[str, str] = {}
    for line in lines[1:]:
        stripped = line.strip()
        if stripped == "---":
            break
        match = FRONTMATTER_KV_RE.match(line)
        if not match:
            continue
        key, value = match.group(1), match.group(2).strip()
        # クォート除去（"..." / '...')
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        result[key] = value
    return result


def root_label(root: Path) -> str:
    """root パスから表示用ラベルを作る（repo-local / plugin:<name>）。

    構造的に判定する（`<base>/.claude/<kind>` または
    `<base>/plugin/<plugin-name>/<kind>`）。REPO_ROOT 配下でない一時
    ディレクトリ（selftest 等）でも正しく判定できるよう、絶対パス /
    相対パスに依存しない。
    """
    if root.parent.name == ".claude":
        return "repo-local"
    if root.parent.parent.name == "plugin":
        return f"plugin:{root.parent.name}"
    return "repo-local"


def discover_skill_roots(base_roots: list[Path]) -> list[Path]:
    """`.claude/skills` と `plugin/*/skills` を列挙する。"""
    roots: list[Path] = []
    for base in base_roots:
        skills_dir = base / ".claude" / "skills"
        if skills_dir.is_dir():
            roots.append(skills_dir)
        plugin_dir = base / "plugin"
        if plugin_dir.is_dir():
            for child in sorted(plugin_dir.iterdir()):
                candidate = child / "skills"
                if candidate.is_dir():
                    roots.append(candidate)
    return roots


def discover_flat_roots(base_roots: list[Path], subdir: str) -> list[Path]:
    """`.claude/<subdir>` と `plugin/*/<subdir>` を列挙する（commands / agents 用）。"""
    roots: list[Path] = []
    for base in base_roots:
        direct = base / ".claude" / subdir
        if direct.is_dir():
            roots.append(direct)
        plugin_dir = base / "plugin"
        if plugin_dir.is_dir():
            for child in sorted(plugin_dir.iterdir()):
                candidate = child / subdir
                if candidate.is_dir():
                    roots.append(candidate)
    return roots


def collect_skill_definitions(skill_roots: list[Path]) -> list[Definition]:
    definitions: list[Definition] = []
    for root in skill_roots:
        label = root_label(root)
        for skill_md in sorted(root.glob("*/SKILL.md")):
            fm = parse_frontmatter(skill_md)
            name = fm.get("name", skill_md.parent.name)
            description = fm.get("description", "")
            definitions.append(
                Definition(name=name, kind="skill", root_label=label, path=skill_md, description=description)
            )
    return definitions


def collect_flat_definitions(roots: list[Path], kind: str) -> list[Definition]:
    definitions: list[Definition] = []
    for root in roots:
        label = root_label(root)
        for md_path in sorted(root.glob("*.md")):
            if md_path.name.upper() == "README.MD":
                continue
            fm = parse_frontmatter(md_path)
            name = fm.get("name", md_path.stem)
            description = fm.get("description", "")
            definitions.append(
                Definition(name=name, kind=kind, root_label=label, path=md_path, description=description)
            )
    return definitions


def find_collisions(definitions: list[Definition]) -> list[Collision]:
    """同一 (kind, name) が複数の異なる root_label に定義されている場合を衝突とする。"""
    grouped: dict[tuple[str, str], list[Definition]] = {}
    for d in definitions:
        grouped.setdefault((d.kind, d.name), []).append(d)

    collisions: list[Collision] = []
    for (kind, name), defs in sorted(grouped.items()):
        distinct_roots = {d.root_label for d in defs}
        if len(distinct_roots) > 1:
            collisions.append(Collision(name=name, kind=kind, definitions=defs))
    return collisions


def format_report(collisions: list[Collision]) -> str:
    if not collisions:
        return "OK: 衝突なし"

    lines = [f"合計 {len(collisions)} 件の name 多重定義を検出", ""]
    lines.append("| kind | name | 定義元 | description 差分 |")
    lines.append("|------|------|--------|------------------|")
    for c in collisions:
        origins = ", ".join(
            f"{d.root_label}({d.path.relative_to(REPO_ROOT) if _is_relative(d.path) else d.path})"
            for d in c.definitions
        )
        diff_label = "あり" if c.description_differs else "なし"
        lines.append(f"| {c.kind} | {c.name} | {origins} | {diff_label} |")
        for d in c.definitions:
            preview = _normalize_description(d.description)[:DESCRIPTION_PREVIEW_LEN]
            lines.append(f"    - {d.root_label}: {preview}")
    return "\n".join(lines)


def _is_relative(path: Path) -> bool:
    try:
        path.relative_to(REPO_ROOT)
        return True
    except ValueError:
        return False


def run_scan(extra_roots: list[str]) -> int:
    base_roots = [REPO_ROOT] + [Path(r).resolve() for r in extra_roots]

    skill_roots = discover_skill_roots(base_roots)
    command_roots = discover_flat_roots(base_roots, "commands")
    agent_roots = discover_flat_roots(base_roots, "agents")

    definitions: list[Definition] = []
    definitions += collect_skill_definitions(skill_roots)
    definitions += collect_flat_definitions(command_roots, "command")
    definitions += collect_flat_definitions(agent_roots, "agent")

    collisions = find_collisions(definitions)

    print(format_report(collisions))

    if collisions:
        return 1
    return 0


# =========================================================
# selftest
# =========================================================


def run_selftest() -> int:
    import tempfile

    failures: list[str] = []

    def check(name: str, condition: bool) -> None:
        if not condition:
            failures.append(name)

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        repo_local = tmp_path / "repo-local"
        plugin_a = tmp_path / "plugin" / "plugin-a"

        # Case 1: 同名 2 定義（description 同一）→ 衝突検出、差分なし
        (repo_local / ".claude" / "skills" / "self-review").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "self-review" / "SKILL.md").write_text(
            "---\nname: self-review\ndescription: セルフレビューを実施する\n---\n# self-review\n",
            encoding="utf-8",
        )
        (plugin_a / "skills" / "self-review").mkdir(parents=True)
        (plugin_a / "skills" / "self-review" / "SKILL.md").write_text(
            "---\nname: self-review\ndescription: セルフレビューを実施する\n---\n# self-review\n",
            encoding="utf-8",
        )

        # Case 2: 単一定義（衝突しない）
        (repo_local / ".claude" / "skills" / "only-here").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "only-here" / "SKILL.md").write_text(
            "---\nname: only-here\ndescription: 単独定義\n---\n# only-here\n",
            encoding="utf-8",
        )

        # Case 3: 同名 2 定義（description 差分あり）
        (repo_local / ".claude" / "skills" / "setup-team").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "setup-team" / "SKILL.md").write_text(
            "---\nname: setup-team\ndescription: リポジトリ固有のチーム編成\n---\n# setup-team\n",
            encoding="utf-8",
        )
        (plugin_a / "skills" / "setup-team").mkdir(parents=True)
        (plugin_a / "skills" / "setup-team" / "SKILL.md").write_text(
            "---\nname: setup-team\ndescription: 汎用チーム編成\n---\n# setup-team\n",
            encoding="utf-8",
        )

        # Case 4: commands の name 衝突（frontmatter 無し → ファイル名ベース）
        (repo_local / ".claude" / "commands").mkdir(parents=True)
        (repo_local / ".claude" / "commands" / "review.md").write_text(
            "# /review\n\nrepo-local review command\n", encoding="utf-8"
        )
        (plugin_a / "commands").mkdir(parents=True)
        (plugin_a / "commands" / "review.md").write_text(
            "# /review\n\nplugin review command\n", encoding="utf-8"
        )

        # discover_* は「.claude/ と plugin/ を配下に持つベースディレクトリ」を
        # 受け取る想定なので、plugin 側は plugin_a の親 (tmp_path) を渡す
        skill_roots = discover_skill_roots([repo_local, tmp_path])
        check("discover_skill_roots finds 2 roots", len(skill_roots) == 2)

        command_roots = discover_flat_roots([repo_local, tmp_path], "commands")
        check("discover_flat_roots finds 2 command roots", len(command_roots) == 2)

        definitions = collect_skill_definitions(skill_roots)
        definitions += collect_flat_definitions(command_roots, "command")

        collisions = find_collisions(definitions)
        collision_names = {(c.kind, c.name) for c in collisions}

        check("self-review collision detected", ("skill", "self-review") in collision_names)
        check("only-here not a collision", ("skill", "only-here") not in collision_names)
        check("setup-team collision detected", ("skill", "setup-team") in collision_names)
        check("review command collision detected", ("command", "review") in collision_names)

        self_review_collision = next(c for c in collisions if c.name == "self-review" and c.kind == "skill")
        check("self-review description identical -> no diff", not self_review_collision.description_differs)

        setup_team_collision = next(c for c in collisions if c.name == "setup-team" and c.kind == "skill")
        check("setup-team description differs -> diff detected", setup_team_collision.description_differs)

        review_collision = next(c for c in collisions if c.name == "review" and c.kind == "command")
        check("review command has 2 definitions", len(review_collision.definitions) == 2)

        # frontmatter parser: 値なしファイル(frontmatter無し)はファイル名から name を採る
        no_fm = collect_flat_definitions(command_roots, "command")
        review_defs = [d for d in no_fm if d.name == "review"]
        check("no-frontmatter command falls back to filename", len(review_defs) == 2)

        report = format_report(collisions)
        check("report is non-empty on collisions", len(report) > 0)

        empty_report = format_report([])
        check("empty report says no collisions", empty_report.startswith("OK"))

    if failures:
        print("SELFTEST FAIL:")
        for name in failures:
            print(f"  - {name}")
        return 1

    total_checks = 13
    print(f"SELFTEST PASS ({total_checks} checks)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--extra-root",
        action="append",
        default=[],
        dest="extra_roots",
        help="追加で走査するベースディレクトリ（.claude/ と plugin/ を配下に持つパス）。複数指定可",
    )
    parser.add_argument(
        "--selftest",
        action="store_true",
        help="内蔵ケースで衝突検出ロジックを自己テストする",
    )
    args = parser.parse_args(argv)

    if args.selftest:
        return run_selftest()

    try:
        return run_scan(args.extra_roots)
    except Exception as exc:  # noqa: BLE001 - CLI 境界での明示的エラー化
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
