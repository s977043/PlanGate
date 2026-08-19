#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""


from __future__ import annotations

__doc__ = """
check-skill-name-collisions.py — plugin / repo-local 間のスキル名多重定義の検出

Issue #692.

複数 plugin（plangate / growth-core / river-review 等）と repo-local
`.claude/skills/` を併用する環境では、同名・同目的の skill / command /
agent が多重定義されうる。エージェントのスキル選択が曖昧になり、どの定義が
使われたか利用者にも追跡できない（interactive-ocean 実例: self-review が
repo-local / growth-core / plangate の 3 重定義、setup-team が 4 重定義）。

本スクリプトは複数の定義ルート（既定: `.claude/skills`, `.claude/commands`,
`.claude/agents` と `plugin/*/skills`, `plugin/*/commands`, `plugin/*/agents`）
を走査し、同一 name が多重定義される衝突を検出する。

配布ミラーの扱い (#1087):
    `plugin/<p>/` は手書きの第 2 定義ではなく `scripts/sync-plugin-plangate.sh`
    が `.claude/` から生成する **export** である。したがって repo-local ⇄
    plugin の同名対は「2 つの独立した定義が名前を取り合っている」のではなく
    「1 つの定義とその配布コピー」であり、多重定義として扱わない
    （`.claude/rules/hybrid-architecture.md` が正常な状態と定めている）。

    ミラーと判定する条件（**すべて**満たすときのみ）:
        ① 定義がちょうど 2 つ
        ② 一方の root_label が `repo-local`
        ③ 他方が `plugin:<p>`（単一）で、**`<p>` が自リポジトリの export 先**
           （既定 `plangate` = `sync-plugin-plangate.sh` の PLUGIN_DIR 名。
           consumer リポジトリでは `--mirror-plugin` で明示指定する）
        ④ **走査ルート内の相対パスが一致**
        ⑤ **内容の同一性が示せる**: description が一致するか、または
           drift が構造的に説明できる kind（skill。plugin 側の正本は
           `.agents/skills` であり `.claude/skills` との差分は export 時の
           意図的な適応として発生しうる）であること。
           agent / command は `sync-plugin-plangate.yml` の `drift-check` が
           内容一致を `exit 1` で担保しているため、description 差分は
           「export ではない別実装」の証拠として扱い衝突にする。

    ③ が無いと **任意の第三者 plugin が無条件でミラーとして受理**され、
    consumer リポジトリの `.claude/skills/x` ⇄ `plugin/<third-party>/skills/x`
    という真の衝突が rc=0 で通る（#1153）。判定不能なら安全側（衝突）に倒す。

    以下は引き続き衝突として rc=1 になる:
        - 3 定義以上（repo-local + plugin-a + plugin-b。#692 の動機ケース）
        - **repo-local ⇄ export 先でない plugin**（#1153。第三者 plugin との
          真の名前衝突。`--mirror-plugin` で明示された plugin のみが除外対象）
        - **agent / command のミラー位置で description が乖離**（#1153。
          drift-check が担保するはずの一致が崩れている＝export ではない）
        - plugin 同士の同名（repo-local 無し）
        - 非ミラー位置での同名（`.claude/skills/foo/` と `plugin/p/skills/bar/`）
        - **同一 root 内の重複**（#1087 で新規に検出可能になったクラス）

    ミラー対の**内容** drift の扱いは非対称（#1153 で agent/command のみ
    本スクリプトの判定条件5 に取り込んだ）。担保の所在:
        - agent / command: `.claude/` → `plugin/plangate/` を
          `sync-plugin-plangate.yml` の `drift-check` job が `exit 1` で担保
        - skill: plugin 側の正本は `.claude/skills` ではなく `.agents/skills`。
          `.claude/skills` ⇄ `.agents/skills` の内容 parity 検査は**存在しない**
          （既知の残存ギャップ。#1087 handoff 参照）

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
    python3 scripts/check-skill-name-collisions.py --mirror-plugin <plugin-name>
    python3 scripts/check-skill-name-collisions.py --selftest

Exit codes:
    0 — 衝突なし
    1 — 衝突あり
    2 — 引数エラー
"""

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# frontmatter `key: value` 抽出（先頭 `---` ブロック内のみ対象）
FRONTMATTER_KV_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$")

DESCRIPTION_PREVIEW_LEN = 80

# 自リポジトリの export 先 plugin（#1153）。
# `scripts/sync-plugin-plangate.sh` の `PLUGIN_DIR="$REPO_ROOT/plugin/plangate"`
# に対応する。ここに載っている plugin だけが「repo-local 定義の配布コピー」で
# あり、それ以外の plugin との同名対は独立した 2 定義＝衝突として扱う。
# consumer リポジトリは `--mirror-plugin` で自分の export 先を明示する。
DEFAULT_MIRROR_PLUGINS = frozenset({"plangate"})

# ミラー対の内容 drift を許容する kind（#1153 条件⑤）。
# skill は plugin 側の正本が `.agents/skills` であり `.claude/skills` との
# description 差分が export 時の適応として正常に起きうる（既知ギャップ）。
# agent / command は sync-plugin-plangate.yml の drift-check が内容一致を
# `exit 1` で担保しているため、差分は「export ではない」ことの証拠になる。
DRIFT_TOLERATED_KINDS = frozenset({"skill"})


@dataclass
class Definition:
    name: str
    kind: str  # "skill" | "command" | "agent"
    root_label: str  # 例: "repo-local" / "plugin:plangate"
    path: Path
    root: Path  # この定義が見つかった走査ルート（例: <base>/.claude/skills）
    description: str = ""

    @property
    def intra_root_path(self) -> tuple[str, ...]:
        """走査ルートからの相対パス。

        `.claude/skills/foo/SKILL.md` と `plugin/p/skills/foo/SKILL.md` は
        どちらも `("foo", "SKILL.md")` になる。REPO_ROOT に依存しないため、
        selftest / doctor サンドボックス（tests/extras/ta-52）の一時ルートでも
        本番と同じ判定が成立する。
        """
        try:
            return self.path.relative_to(self.root).parts
        except ValueError:  # pragma: no cover - 構造上到達しない
            return (self.path.name,)


def _has_exactly_two(defs: list[Definition]) -> bool:
    """条件①: 定義がちょうど 2 つ。"""
    return len(defs) == 2


def _has_repo_local_and_single_plugin(
    defs: list[Definition], mirror_plugins: frozenset[str]
) -> bool:
    """条件②③: 一方が repo-local、他方が **自リポジトリの export 先** plugin。

    #1153: `startswith("plugin:")` だけを見ると、第三者 plugin との真の
    名前衝突（consumer の `.claude/skills/x` ⇄ `plugin/growth-core/skills/x`）
    まで「正常なミラー」として rc=0 で通る。ミラー除外の根拠は
    「`plugin/<p>/` が `sync-plugin-plangate.sh` の生成物であること」なので、
    その前提が成り立つ plugin 名でのみ成立させる。
    """
    labels = [d.root_label for d in defs]
    repo_local = [x for x in labels if x == "repo-local"]
    plugins = [x for x in labels if x.startswith("plugin:")]
    if len(repo_local) != 1 or len(plugins) != 1:
        return False
    plugin_name = plugins[0][len("plugin:") :]
    return plugin_name in mirror_plugins


def _content_is_consistent(collision: "Collision") -> bool:
    """条件⑤: 「1 つの定義とその配布コピー」であることを内容面でも示せるか。

    description が一致していれば copy として整合。一致しない場合、
    drift が構造的に説明できる kind（skill）に限って許容する
    （モジュール docstring「配布ミラーの扱い」の非対称カバレッジ）。
    agent / command の drift は drift-check が担保するはずの一致が崩れた
    状態であり、export ではなく別実装である可能性を示すため衝突にする。
    """
    if not collision.description_differs:
        return True
    return collision.kind in DRIFT_TOLERATED_KINDS


def _same_intra_root_path(defs: list[Definition]) -> bool:
    """条件④: 走査ルート内の相対パスが一致する（= export の同じ枠）。"""
    return len({d.intra_root_path for d in defs}) == 1


@dataclass
class Collision:
    name: str
    kind: str
    definitions: list[Definition] = field(default_factory=list)
    # この判定に使う「自リポジトリの export 先 plugin」集合（#1153）
    mirror_plugins: frozenset[str] = DEFAULT_MIRROR_PLUGINS

    @property
    def description_differs(self) -> bool:
        descs = {_normalize_description(d.description) for d in self.definitions}
        return len(descs) > 1

    @property
    def is_export_mirror(self) -> bool:
        """repo-local の定義とその plugin export コピーの対か。

        `plugin/<p>/` は手書きの第 2 定義ではなく
        `scripts/sync-plugin-plangate.sh` が `.claude/` から生成する export
        である（docs/ai/skill-collision-detection.md）。したがって
        「2 つの独立した定義が名前を取り合っている」のではなく
        「1 つの定義とその配布コピー」であり、多重定義として扱わない。

        ただしそれが言えるのは **その plugin が自リポジトリの export 先で
        ある場合だけ**である（#1153）。第三者 plugin との同名対は
        「1 つの定義とその配布コピー」ではないため衝突のままにする。

        対の**内容** drift のうち skill の description 差分は許容する
        （条件5）。その担保の所在は
        モジュール docstring「配布ミラーの扱い」を参照（agent/command は
        `sync-plugin-plangate.yml` の `drift-check` が担保、skill は未担保）。
        """
        defs = self.definitions
        return (
            _has_exactly_two(defs)
            and _has_repo_local_and_single_plugin(defs, self.mirror_plugins)
            and _same_intra_root_path(defs)
            and _content_is_consistent(self)
        )


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
                Definition(
                    name=name,
                    kind="skill",
                    root_label=label,
                    path=skill_md,
                    root=root,
                    description=description,
                )
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
                Definition(
                    name=name,
                    kind=kind,
                    root_label=label,
                    path=md_path,
                    root=root,
                    description=description,
                )
            )
    return definitions


def find_collisions(
    definitions: list[Definition],
    mirror_plugins: frozenset[str] = DEFAULT_MIRROR_PLUGINS,
) -> list[Collision]:
    """同一 (kind, name) に定義が 2 つ以上ある場合を多重定義候補とする。

    「異なる root_label に跨る場合のみ」ではなく「2 つ以上」で拾う。
    これにより **同一 root 内の重複**（例: `.claude/skills/a/` と
    `.claude/skills/b/` が両方 `name: x` を宣言）も検出対象になる
    （従来は distinct root_label が 1 のため原理的に検出できなかった）。

    ここで返るのは候補であり、`Collision.is_export_mirror` が True のものは
    正常な配布ミラーとして rc に影響させない（`run_scan` 参照）。
    """
    grouped: dict[tuple[str, str], list[Definition]] = {}
    for d in definitions:
        grouped.setdefault((d.kind, d.name), []).append(d)

    collisions: list[Collision] = []
    for (kind, name), defs in sorted(grouped.items()):
        if len(defs) > 1:
            collisions.append(
                Collision(
                    name=name,
                    kind=kind,
                    definitions=defs,
                    mirror_plugins=mirror_plugins,
                )
            )
    return collisions


def _origins(c: Collision) -> str:
    return ", ".join(
        f"{d.root_label}({d.path.relative_to(REPO_ROOT) if _is_relative(d.path) else d.path})"
        for d in c.definitions
    )


def format_report(
    true_collisions: list[Collision],
    mirrors: list[Collision],
    mirror_plugins: frozenset[str] = DEFAULT_MIRROR_PLUGINS,
) -> str:
    """真の多重定義とミラーを **両方** 印字する。

    ミラーを出力から消さないのは意図的である。黙って落とすと
    「検査が何を見なくなったか」が読めなくなり、#1109 と同型の
    false green（緑だが違反は残っている）を新たに作ってしまう。
    """
    lines: list[str] = []

    if true_collisions:
        lines.append(f"合計 {len(true_collisions)} 件の name 多重定義を検出")
        lines.append("")
        lines.append("| kind | name | 定義元 | description 差分 |")
        lines.append("|------|------|--------|------------------|")
        for c in true_collisions:
            diff_label = "あり" if c.description_differs else "なし"
            lines.append(f"| {c.kind} | {c.name} | {_origins(c)} | {diff_label} |")
            for d in c.definitions:
                preview = _normalize_description(d.description)[:DESCRIPTION_PREVIEW_LEN]
                lines.append(f"    - {d.root_label}: {preview}")
    else:
        lines.append("OK: 衝突なし")

    if mirrors:
        lines.append("")
        lines.append(
            f"INFO: {len(mirrors)} 件は repo-local ⇄ plugin export のミラー"
            "（正常。判定は docs/ai/skill-collision-detection.md を参照）"
        )
        lines.append(
            "      ミラー除外の対象 plugin: "
            + ", ".join(sorted(mirror_plugins))
            + "（--mirror-plugin で指定。それ以外の plugin との同名対は衝突）"
        )
        lines.append(
            "      対の内容一致: agent/command は sync-plugin-plangate.yml の"
            " drift-check job が担保。skill は .agents/skills が plugin の正本のため"
            " .claude/skills との parity は未担保（既知ギャップ）"
        )
        for c in mirrors:
            diff_note = "  [description 差分あり]" if c.description_differs else ""
            lines.append(f"    - {c.kind} {c.name}: {_origins(c)}{diff_note}")

    return "\n".join(lines)


def _is_relative(path: Path) -> bool:
    try:
        path.relative_to(REPO_ROOT)
        return True
    except ValueError:
        return False


def run_scan(extra_roots: list[str], mirror_plugins: list[str] | None = None) -> int:
    base_roots = [REPO_ROOT] + [Path(r).resolve() for r in extra_roots]
    # --mirror-plugin 明示時は既定（plangate）を **置換** する。
    # consumer リポジトリの export 先は plangate ではないため、
    # 既定に足し込むと第三者 plugin の除外が残ってしまう。
    mirrors_allowed = frozenset(mirror_plugins) if mirror_plugins else DEFAULT_MIRROR_PLUGINS

    skill_roots = discover_skill_roots(base_roots)
    command_roots = discover_flat_roots(base_roots, "commands")
    agent_roots = discover_flat_roots(base_roots, "agents")

    definitions: list[Definition] = []
    definitions += collect_skill_definitions(skill_roots)
    definitions += collect_flat_definitions(command_roots, "command")
    definitions += collect_flat_definitions(agent_roots, "agent")

    collisions = find_collisions(definitions, mirrors_allowed)

    # call site: ミラー分類。ここが壊れると真の衝突が rc に反映されなくなる
    mirrors = [c for c in collisions if c.is_export_mirror]
    true_collisions = [c for c in collisions if not c.is_export_mirror]

    print(format_report(true_collisions, mirrors, mirrors_allowed))

    if true_collisions:
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
        # #1153: ミラーとして受理されるのは **export 先 plugin** だけなので、
        # ミラーを期待するケースは既定の export 先名（plangate）を使う。
        plugin_a = tmp_path / "plugin" / "plangate"
        plugin_third = tmp_path / "plugin" / "third-party"

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

        check("self-review multi-definition detected", ("skill", "self-review") in collision_names)
        check("only-here not a multi-definition", ("skill", "only-here") not in collision_names)
        check("setup-team multi-definition detected", ("skill", "setup-team") in collision_names)
        check("review command multi-definition detected", ("command", "review") in collision_names)

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

        # --- #1087: ミラー分類 -------------------------------------------
        # Case 1/3/4 はいずれも repo-local ⇄ 単一 plugin の、root 内相対パスが
        # 一致する対 = accepted mirror（description 差分の有無に関わらず）
        check("self-review pair is an export mirror", self_review_collision.is_export_mirror)
        check(
            "setup-team pair is a mirror even with description drift",
            setup_team_collision.is_export_mirror,
        )
        check("review command pair is an export mirror", review_collision.is_export_mirror)

        # Case 5: 非ミラー位置での同名 → 真の衝突
        (repo_local / ".claude" / "skills" / "shifted-src").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "shifted-src" / "SKILL.md").write_text(
            "---\nname: shifted\ndescription: repo side\n---\n# shifted\n", encoding="utf-8"
        )
        (plugin_a / "skills" / "shifted-elsewhere").mkdir(parents=True)
        (plugin_a / "skills" / "shifted-elsewhere" / "SKILL.md").write_text(
            "---\nname: shifted\ndescription: plugin side\n---\n# shifted\n", encoding="utf-8"
        )

        # Case 6: 同一 root 内の重複 → 真の衝突（従来は原理的に検出不能）
        (repo_local / ".claude" / "skills" / "dup-a").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "dup-a" / "SKILL.md").write_text(
            "---\nname: dup\ndescription: A\n---\n# dup\n", encoding="utf-8"
        )
        (repo_local / ".claude" / "skills" / "dup-b").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "dup-b" / "SKILL.md").write_text(
            "---\nname: dup\ndescription: B\n---\n# dup\n", encoding="utf-8"
        )

        # Case 7: 3 定義（repo-local + plugin-a + plugin-b）→ 真の衝突（#692 動機ケース）
        plugin_b = tmp_path / "plugin" / "plugin-b"
        (repo_local / ".claude" / "skills" / "triple").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "triple" / "SKILL.md").write_text(
            "---\nname: triple\ndescription: t\n---\n# triple\n", encoding="utf-8"
        )
        (plugin_a / "skills" / "triple").mkdir(parents=True)
        (plugin_a / "skills" / "triple" / "SKILL.md").write_text(
            "---\nname: triple\ndescription: t\n---\n# triple\n", encoding="utf-8"
        )
        (plugin_b / "skills" / "triple").mkdir(parents=True)
        (plugin_b / "skills" / "triple" / "SKILL.md").write_text(
            "---\nname: triple\ndescription: t\n---\n# triple\n", encoding="utf-8"
        )

        # Case 8: plugin 同士のみの同名（repo-local 無し）→ 真の衝突
        (plugin_a / "skills" / "plugin-only-clash").mkdir(parents=True)
        (plugin_a / "skills" / "plugin-only-clash" / "SKILL.md").write_text(
            "---\nname: pclash\ndescription: a\n---\n# pclash\n", encoding="utf-8"
        )
        (plugin_b / "skills" / "plugin-only-clash").mkdir(parents=True)
        (plugin_b / "skills" / "plugin-only-clash" / "SKILL.md").write_text(
            "---\nname: pclash\ndescription: b\n---\n# pclash\n", encoding="utf-8"
        )

        defs2 = collect_skill_definitions(discover_skill_roots([repo_local, tmp_path]))
        by_name = {}
        for c in find_collisions(defs2):
            by_name[(c.kind, c.name)] = c

        check("shifted: non-mirrored path -> true collision", not by_name[("skill", "shifted")].is_export_mirror)
        check("dup: same-root duplicate is detected at all", ("skill", "dup") in by_name)
        check("dup: same-root duplicate -> true collision", not by_name[("skill", "dup")].is_export_mirror)
        check("triple: 3 definitions -> true collision", not by_name[("skill", "triple")].is_export_mirror)
        check("pclash: plugin-vs-plugin -> true collision", not by_name[("skill", "pclash")].is_export_mirror)
        check("self-review still a mirror after adding cases", by_name[("skill", "self-review")].is_export_mirror)

        mirrors = [c for c in by_name.values() if c.is_export_mirror]
        true_collisions = [c for c in by_name.values() if not c.is_export_mirror]

        report = format_report(true_collisions, mirrors)
        check("report is non-empty on collisions", len(report) > 0)
        check("report lists mirrors as INFO (not silently dropped)", "INFO:" in report)
        for _kind, _name in (("skill", "shifted"), ("skill", "dup"), ("skill", "triple"), ("skill", "pclash")):
            check(f"report mentions true collision: {_name}", _name in report)

        # --- #1153: 第三者 plugin との同名は衝突（ミラーではない）--------
        # Case 9: repo-local ⇄ 非 export plugin（description 一致）
        (repo_local / ".claude" / "skills" / "third-same").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "third-same" / "SKILL.md").write_text(
            "---\nname: third-same\ndescription: 同一テキスト\n---\n# third-same\n",
            encoding="utf-8",
        )
        (plugin_third / "skills" / "third-same").mkdir(parents=True)
        (plugin_third / "skills" / "third-same" / "SKILL.md").write_text(
            "---\nname: third-same\ndescription: 同一テキスト\n---\n# third-same\n",
            encoding="utf-8",
        )

        # Case 10: repo-local ⇄ 非 export plugin（description 差分・issue #1153 の再現）
        (repo_local / ".claude" / "skills" / "third-drift").mkdir(parents=True)
        (repo_local / ".claude" / "skills" / "third-drift" / "SKILL.md").write_text(
            "---\nname: third-drift\ndescription: repo 固有の実装\n---\n# third-drift\n",
            encoding="utf-8",
        )
        (plugin_third / "skills" / "third-drift").mkdir(parents=True)
        (plugin_third / "skills" / "third-drift" / "SKILL.md").write_text(
            "---\nname: third-drift\ndescription: 全く別の実装\n---\n# third-drift\n",
            encoding="utf-8",
        )

        defs3 = collect_skill_definitions(discover_skill_roots([repo_local, tmp_path]))
        by_name3 = {(c.kind, c.name): c for c in find_collisions(defs3)}

        check(
            "third-party plugin pair (same description) -> true collision",
            not by_name3[("skill", "third-same")].is_export_mirror,
        )
        check(
            "third-party plugin pair (description drift) -> true collision",
            not by_name3[("skill", "third-drift")].is_export_mirror,
        )
        check(
            "export-target plugin pair is still a mirror",
            by_name3[("skill", "self-review")].is_export_mirror,
        )

        # --mirror-plugin 相当: export 先として明示すればミラーになる
        by_name3_override = {
            (c.kind, c.name): c
            for c in find_collisions(defs3, frozenset({"third-party"}))
        }
        check(
            "declaring the plugin as an export target makes the pair a mirror",
            by_name3_override[("skill", "third-same")].is_export_mirror,
        )
        check(
            "declaring another export target turns the plangate pair into a collision",
            not by_name3_override[("skill", "self-review")].is_export_mirror,
        )

        # Case 11: agent/command のミラー位置で description が乖離 -> 真の衝突
        (repo_local / ".claude" / "agents").mkdir(parents=True)
        (repo_local / ".claude" / "agents" / "drifted-agent.md").write_text(
            "---\nname: drifted-agent\ndescription: repo 側の責務\n---\n# a\n",
            encoding="utf-8",
        )
        (plugin_a / "agents").mkdir(parents=True)
        (plugin_a / "agents" / "drifted-agent.md").write_text(
            "---\nname: drifted-agent\ndescription: plugin 側の別責務\n---\n# a\n",
            encoding="utf-8",
        )
        (repo_local / ".claude" / "agents" / "synced-agent.md").write_text(
            "---\nname: synced-agent\ndescription: 同一の責務\n---\n# a\n",
            encoding="utf-8",
        )
        (plugin_a / "agents" / "synced-agent.md").write_text(
            "---\nname: synced-agent\ndescription: 同一の責務\n---\n# a\n",
            encoding="utf-8",
        )
        agent_roots = discover_flat_roots([repo_local, tmp_path], "agents")
        agent_defs = collect_flat_definitions(agent_roots, "agent")
        by_agent = {(c.kind, c.name): c for c in find_collisions(agent_defs)}
        check(
            "agent mirror with description drift -> true collision (drift-check would have blocked it)",
            not by_agent[("agent", "drifted-agent")].is_export_mirror,
        )
        check(
            "agent mirror without drift -> mirror",
            by_agent[("agent", "synced-agent")].is_export_mirror,
        )

        empty_report = format_report([], [])
        check("empty report says no collisions", empty_report.startswith("OK"))

    if failures:
        print("SELFTEST FAIL:")
        for name in failures:
            print(f"  - {name}")
        return 1

    total_checks = 13 + 3 + 6 + 2 + 4 + 7  # 末尾 +7 = #1153 の export 先判定 / 内容同一性
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
        "--mirror-plugin",
        action="append",
        default=[],
        dest="mirror_plugins",
        help=(
            "配布ミラーとして除外してよい plugin 名（自リポジトリの export 先）。"
            f"未指定時は {sorted(DEFAULT_MIRROR_PLUGINS)}。指定時は既定を置換する。複数指定可"
        ),
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
        return run_scan(args.extra_roots, args.mirror_plugins)
    except Exception as exc:  # noqa: BLE001 - CLI 境界での明示的エラー化
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
