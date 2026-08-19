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
check-skill-frontmatter.py — SKILL.md frontmatter の YAML パース健全性検査

背景:
    `plangate-setup/SKILL.md` の `description` が **クォートされていない** まま
    `Use when:` を含んでいたため、YAML パーサが行途中で新しいマッピングキーと
    解釈し frontmatter 全体が壊れていた（`mapping values are not allowed here`）。
    この状態のスキルは **strict な YAML パーサ（Codex ランタイム / `claude plugin
    validate --strict` 等）が frontmatter を読めない**。
    なお **Claude Code の寛容パーサでは description が保持される**（#1078 の
    レビューで、always-on トークン数と description 文字数の相関を全 24 skill に
    ついて測定し線形・本 skill も回帰線上であることが確認されている）。
    「runtime で全フィールドが silently drop される」は validator の文言であって
    観測された挙動ではないため、本スクリプトはその表現を採らない。

    既存の skill 系検査（`check-skill-name-collisions.py` /
    `check-stale-skill-refs.py` / `tests/extras/ta-13`）は **grep / awk / 行単位
    正規表現**で frontmatter を読むため、YAML として壊れていても素通りする
    （壊れた行もそのまま `key: value` として拾えてしまう）。本スクリプトは
    **実 YAML パーサ（PyYAML）で frontmatter を parse** し、name / description が
    取得できない SKILL.md を FAIL にすることでこの盲点を塞ぐ。

対象:
    `<root>/<skill-name>/SKILL.md`
    既定 root: `.agents/skills`（正本）, `.claude/skills`, `.codex/skills`,
    `plugin/*/skills`
    `.codex/skills` は `scripts/install-plangate-skills-to-codex.sh` の生成物だが、
    **Codex ランタイムが実際に読む場所**であり strict パース失敗の消費先そのもの
    なので必ず走査対象に含める（生成物だから見なくてよい、ではない）。

検査項目:
    1. 先頭に `---` で開始し `---` で閉じる frontmatter ブロックがある
    2. そのブロックが YAML として parse できる
    3. parse 結果が mapping である
    4. `name` / `description` が非空の文字列である

配線について: 本スクリプトはスタンドアロンの静的解析。CI への直接配線
（`.github/workflows/`）と doctor（`bin/plangate`）は Hardening Override 対象の
ため、回帰検出は `tests/extras/ta-64-skill-frontmatter.sh`（`tests/run-tests.sh`
経由で CI 実行される）が担う。

Usage:
    python3 scripts/check-skill-frontmatter.py
    python3 scripts/check-skill-frontmatter.py --root <path>
    python3 scripts/check-skill-frontmatter.py --extra-root <path>
    python3 scripts/check-skill-frontmatter.py --selftest

Exit codes:
    0 — 全 SKILL.md の frontmatter が健全
    1 — 破損 SKILL.md あり
    2 — 実行環境 / 引数エラー（PyYAML 不在 / **走査対象 0 件** を含む。
        検査が no-op に退行したまま緑を返さないための fail-closed）
"""

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_KEYS = ("name", "description")
DETAIL_PREVIEW_LEN = 120


@dataclass
class Finding:
    path: Path
    reason: str


def _load_yaml_module():
    """PyYAML を import する。不在なら None（呼び出し側で exit 2）。"""
    try:
        import yaml  # noqa: PLC0415 - 依存不在を実行時に判定するため関数内 import
    except ImportError:
        return None
    return yaml


def extract_frontmatter_block(text: str) -> str | None:
    """先頭 `---` 〜 終端 `---` までの本文を返す。ブロックが無ければ None。

    終端は **列 0 の `---`**（行頭空白なし。行末の空白 / CR は許容）だけを認める。
    `strip()` 一致で終端判定すると、ブロックスカラー（`description: |`）の中の
    **インデントされた `---`** で早期に打ち切られ、その後ろにある破損キーを
    見逃す。YAML ではブロックスカラーの内容は親キーより深くインデントされる
    ため、列 0 の `---` がスカラー内容の途中に現れることはない（列 0 まで
    dedent した時点でスカラーは終わる）。したがって列 0 アンカーは
    早期打ち切りだけを塞ぎ、既存の記法を落とさない。

    「最後の `---` までを終端とする」案は採らない。SKILL.md 本文中の
    **水平線 `---`** を終端と誤認して markdown 本文を YAML として parse し、
    本リポジトリの実測で 146 件中 16 件が偽陽性になる。
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for idx in range(1, len(lines)):
        line = lines[idx]
        if line.rstrip() == "---" and line == line.lstrip():
            return "\n".join(lines[1:idx])
    return None


def check_skill_md(path: Path, yaml_mod) -> Finding | None:
    """1 ファイルを検査し、問題があれば Finding を返す。"""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return Finding(path, f"read error: {exc}")

    block = extract_frontmatter_block(text)
    if block is None:
        return Finding(path, "frontmatter ブロックが無い（先頭 `---` 〜 列 0 の `---` が閉じていない）")

    try:
        data = yaml_mod.safe_load(block)
    except Exception as exc:  # noqa: BLE001 - YAML の各種エラーを一律 FAIL 化
        detail = " ".join(str(exc).split())[:DETAIL_PREVIEW_LEN]
        return Finding(path, f"YAML parse 失敗（strict YAML パーサ（Codex 等）が frontmatter を読めない）: {detail}")

    if not isinstance(data, dict):
        return Finding(path, f"frontmatter が mapping でない（type={type(data).__name__}）")

    missing = [
        key
        for key in REQUIRED_KEYS
        if not isinstance(data.get(key), str) or not data.get(key, "").strip()
    ]
    if missing:
        return Finding(path, f"必須キーが非空文字列でない: {', '.join(missing)}")

    return None


def discover_skill_roots(base_roots: list[Path]) -> list[Path]:
    """`.agents/skills` / `.claude/skills` / `.codex/skills` / `plugin/*/skills` を列挙する。"""
    roots: list[Path] = []
    for base in base_roots:
        for rel in (
            Path(".agents") / "skills",
            Path(".claude") / "skills",
            Path(".codex") / "skills",
        ):
            candidate = base / rel
            if candidate.is_dir():
                roots.append(candidate)
        plugin_dir = base / "plugin"
        if plugin_dir.is_dir():
            for child in sorted(plugin_dir.iterdir()):
                candidate = child / "skills"
                if candidate.is_dir():
                    roots.append(candidate)
    return roots


def collect_skill_files(skill_roots: list[Path]) -> list[Path]:
    files: list[Path] = []
    for root in skill_roots:
        files.extend(sorted(root.glob("*/SKILL.md")))
    return files


def _display(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def format_report(findings: list[Finding], scanned: int) -> str:
    if not findings:
        return f"OK: SKILL.md {scanned} 件すべて frontmatter パース可能"

    lines = [f"合計 {len(findings)} 件の frontmatter 破損を検出（走査 {scanned} 件）", ""]
    lines.append("| path | 理由 |")
    lines.append("|------|------|")
    for f in findings:
        lines.append(f"| {_display(f.path)} | {f.reason} |")
    lines.append("")
    lines.append("修正例: description に `Use when:` 等のコロンを含む場合は値全体をダブルクォートで囲む")
    return "\n".join(lines)


def run_scan(roots: list[str], extra_roots: list[str]) -> int:
    yaml_mod = _load_yaml_module()
    if yaml_mod is None:
        print(
            "ERROR: PyYAML が見つかりません（pip install pyyaml）。"
            "検査未実施を成功として扱わないため exit 2 とします。",
            file=sys.stderr,
        )
        return 2

    if roots:
        skill_roots = [Path(r).resolve() for r in roots]
        for r in skill_roots:
            if not r.is_dir():
                print(f"ERROR: root が存在しません: {r}", file=sys.stderr)
                return 2
    else:
        base_roots = [REPO_ROOT] + [Path(r).resolve() for r in extra_roots]
        skill_roots = discover_skill_roots(base_roots)

    # fail-closed: 走査対象 0 件を「破損なし」として緑にしない。
    # REPO_ROOT は __file__ 起点で固定のため、配置変更 / root 改名 / plugin 構造
    # 変更のいずれでも silently 0 件に退行しうる（検査の no-op 化）。
    if not skill_roots:
        print(
            "ERROR: skills root が 1 つも見つかりません"
            f"（探索基点: {', '.join(_display(Path(r)) for r in ([REPO_ROOT] + [Path(x).resolve() for x in extra_roots]))}）。"
            "検査未実施を成功として扱わないため exit 2 とします。",
            file=sys.stderr,
        )
        return 2

    files = collect_skill_files(skill_roots)
    if not files:
        print(
            "ERROR: SKILL.md が 1 件も見つかりません"
            f"（走査 root: {', '.join(_display(r) for r in skill_roots)}）。"
            "検査未実施を成功として扱わないため exit 2 とします。",
            file=sys.stderr,
        )
        return 2

    findings = [f for f in (check_skill_md(p, yaml_mod) for p in files) if f is not None]

    print(format_report(findings, len(files)))
    return 1 if findings else 0


# =========================================================
# selftest
# =========================================================

# 実際に壊れていた行（#plangate-setup）。クォート無し + 値中の `Use when:` で
# YAML が行途中を新しいマッピングキーと解釈する。
BROKEN_DESCRIPTION_LINE = (
    "description: PlanGate 初期セットアップを対話的に進めるためのチェックリスト、"
    "5 要素対応観点、Human-owned 操作の script 提示テンプレ。doctor を単一検証源とする。"
    "Use when: 「PlanGate をセットアップして」「導入したい」と依頼された時。"
)
FIXED_DESCRIPTION_LINE = f'description: "{BROKEN_DESCRIPTION_LINE[len("description: "):]}"'


def run_selftest() -> int:
    import tempfile

    yaml_mod = _load_yaml_module()
    if yaml_mod is None:
        print("SELFTEST ERROR: PyYAML が見つかりません", file=sys.stderr)
        return 2

    failures: list[str] = []

    def check(name: str, condition: bool) -> None:
        if not condition:
            failures.append(name)

    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp)
        skills = base / ".agents" / "skills"

        def write_skill(name: str, body: str) -> Path:
            d = skills / name
            d.mkdir(parents=True)
            p = d / "SKILL.md"
            p.write_text(body, encoding="utf-8")
            return p

        # Case 1（負側 / 実 defect の再現）: クォート無し `Use when:` → parse 失敗
        broken = write_skill(
            "broken-unquoted",
            f"---\nname: broken-unquoted\n{BROKEN_DESCRIPTION_LINE}\n---\n\n# broken\n",
        )
        f1 = check_skill_md(broken, yaml_mod)
        check("負側: クォート無し Use when: を検出する", f1 is not None)
        check("負側: 理由が YAML parse 失敗である", f1 is not None and "YAML parse 失敗" in f1.reason)

        # Case 2（正側 / 修正後）: 同一文言をダブルクォートで囲めば PASS
        fixed = write_skill(
            "fixed-quoted",
            f"---\nname: fixed-quoted\n{FIXED_DESCRIPTION_LINE}\n---\n\n# fixed\n",
        )
        check("正側: クォート済み同一文言は PASS", check_skill_md(fixed, yaml_mod) is None)

        # Case 3: frontmatter ブロックが無い
        nofm = write_skill("no-frontmatter", "# no frontmatter\n\nbody\n")
        f3 = check_skill_md(nofm, yaml_mod)
        check("frontmatter 不在を検出する", f3 is not None and "frontmatter ブロック" in f3.reason)

        # Case 4: 閉じ `---` が無い
        unclosed = write_skill("unclosed", "---\nname: unclosed\ndescription: x\n\n# body\n")
        check("閉じ `---` 欠落を検出する", check_skill_md(unclosed, yaml_mod) is not None)

        # Case 5: description キー欠落
        nodesc = write_skill("no-description", "---\nname: no-description\n---\n\n# body\n")
        f5 = check_skill_md(nodesc, yaml_mod)
        check("description 欠落を検出する", f5 is not None and "description" in f5.reason)

        # Case 6: description が空文字
        emptydesc = write_skill("empty-description", '---\nname: empty-description\ndescription: ""\n---\n')
        check("空 description を検出する", check_skill_md(emptydesc, yaml_mod) is not None)

        # Case 7: name 欠落
        noname = write_skill("no-name", "---\ndescription: ok\n---\n\n# body\n")
        f7 = check_skill_md(noname, yaml_mod)
        check("name 欠落を検出する", f7 is not None and "name" in f7.reason)

        # Case 8: 正常な skill は PASS
        good = write_skill("good", "---\nname: good\ndescription: 正常なスキル\n---\n\n# good\n")
        check("正常な SKILL.md は PASS", check_skill_md(good, yaml_mod) is None)

        # Case 9（F-4 負側）: ブロックスカラー内のインデント付き `---` で早期打ち切りされ、
        # その後ろの破損キーを見逃さないこと（`strip()` 一致終端だと PASS してしまう）
        block_trap = write_skill(
            "block-scalar-trap",
            "---\nname: block-scalar-trap\ndescription: |\n  複数行の説明。\n  ---\n  区切りに見える行\nbroken key: value: value\n---\n\n# body\n",
        )
        check("F-4 負側: ブロックスカラー内 `---` の後ろにある破損を検出", check_skill_md(block_trap, yaml_mod) is not None)

        # Case 10（F-4 正側 / 偽陽性ガード）: 本文中の水平線 `---` を終端と誤認しない。
        # 「最後の `---` まで再 parse」案はここで markdown 本文を YAML として読み FAIL する
        md_hr = write_skill(
            "markdown-hr",
            "---\nname: markdown-hr\ndescription: 本文に水平線を含む正常スキル\n---\n\n# 見出し\n\n---\n\n本文: コロンを含む行\n",
        )
        check("F-4 正側: 本文中の水平線 `---` を終端と誤認しない", check_skill_md(md_hr, yaml_mod) is None)

        # Case 11（F-4 正側）: 正常なブロックスカラー description は PASS のまま
        block_ok = write_skill(
            "block-scalar-ok",
            "---\nname: block-scalar-ok\ndescription: |\n  複数行の説明。\n  Use when: 「使うとき」\n---\n\n# body\n",
        )
        check("F-4 正側: 正常なブロックスカラーは PASS", check_skill_md(block_ok, yaml_mod) is None)

        # Case 12: root 探索が .agents/skills を拾う
        roots = discover_skill_roots([base])
        check("discover_skill_roots が .agents/skills を拾う", skills in roots)

        # Case 13（F-1）: `.codex/skills` を探索対象に含む
        codex_skills = base / ".codex" / "skills"
        codex_skills.mkdir(parents=True)
        (codex_skills / "codex-only").mkdir()
        (codex_skills / "codex-only" / "SKILL.md").write_text(
            "---\nname: codex-only\ndescription: codex 側のみ\n---\n", encoding="utf-8"
        )
        check("F-1: discover_skill_roots が .codex/skills を拾う", codex_skills in discover_skill_roots([base]))

        # Case 14: 集約レポートと exit code
        files = collect_skill_files(roots)
        findings = [f for f in (check_skill_md(p, yaml_mod) for p in files) if f is not None]
        check("走査で 11 件中 7 件の破損を検出", len(files) == 11 and len(findings) == 7)
        report = format_report(findings, len(files))
        check("レポートに破損 path が載る", "broken-unquoted" in report)
        check("正常時レポートは OK 始まり", format_report([], 3).startswith("OK"))

        # Case 15（F-2）: 走査対象 0 件は exit 2（緑にしない）
        empty_base = base / "empty-base"
        empty_base.mkdir()
        check("F-2: skills root 不在のベースからは root を 1 つも拾わない", discover_skill_roots([empty_base]) == [])
        empty_root = base / "empty-skills-root"
        empty_root.mkdir()
        check("F-2: SKILL.md 0 件の root 指定は exit 2（rc=0 で緑にしない）", run_scan([str(empty_root)], []) == 2)
        check("F-2: 存在しない root 指定は exit 2", run_scan([str(base / "nope")], []) == 2)

    if failures:
        print("SELFTEST FAIL:")
        for name in failures:
            print(f"  - {name}")
        return 1

    print("SELFTEST PASS (21 checks)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--root",
        action="append",
        default=[],
        dest="roots",
        help="検査する skills ルートを直接指定する（例: path/to/.agents/skills）。複数指定可",
    )
    parser.add_argument(
        "--extra-root",
        action="append",
        default=[],
        dest="extra_roots",
        help="追加で走査するベースディレクトリ（.agents/ .claude/ plugin/ を配下に持つパス）。複数指定可",
    )
    parser.add_argument(
        "--selftest",
        action="store_true",
        help="内蔵ケース（破損 fixture を含む）で検出ロジックを自己テストする",
    )
    args = parser.parse_args(argv)

    if args.selftest:
        return run_selftest()

    try:
        return run_scan(args.roots, args.extra_roots)
    except Exception as exc:  # noqa: BLE001 - CLI 境界での明示的エラー化
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
