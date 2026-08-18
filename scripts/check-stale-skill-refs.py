#!/usr/bin/env python3
"""
check-stale-skill-refs.py — repo-owned skill/command/agent の stale パス参照検出

Issue #691.

repo-owned の `.claude/skills/**/*.md` / `.claude/commands/**/*.md` /
`.claude/agents/**/*.md` はコード内のファイルパスを参照して書かれるが、
リファクタリング後に誰も更新せず陳腐化しやすい（interactive-ocean 実例:
2026-04-09 作成のレビューコマンド 7 件が 2026-06-27 の barrel 化 PR 後も
約 2 ヶ月間旧パスを指したまま気づかれなかった）。

本スクリプトは対象 Markdown 内のファイルパス参照を抽出し、リポジトリ内に
実在しないものを WARN として列挙する。false-positive canary（#499 の
ガイドライン準拠）として glob 表記・プレースホルダ・URL・アンカーのみの
参照を除外する。

配線について: 本スクリプトはスタンドアロンの静的解析であり、
doctor / L-0 / CI への配線は Hardening Override 対象（bin/plangate,
.github/workflows/）に触れるため別 PBI の follow-up とする
（docs/ai/stale-ref-detection.md 参照）。

Usage:
    python3 scripts/check-stale-skill-refs.py [ROOT ...]
    python3 scripts/check-stale-skill-refs.py --selftest

Exit codes:
    0 — stale 参照なし
    1 — stale 参照あり（WARN 列挙）
    2 — 引数エラー
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_TARGET_GLOBS = (
    ".claude/skills/**/*.md",
    ".claude/commands/**/*.md",
    ".claude/agents/**/*.md",
)

# Markdown リンク `](path)` からパスらしき文字列を取り出す
MD_LINK_RE = re.compile(r"\]\(([^)]+)\)")

# インラインコードスパン（バッククォート 1 個以上の対）。
# 開始と同じ本数のバッククォートで閉じる Markdown の規則に合わせ、
# `` `[a](./b)` `` のような「リンク記法そのものを見せるためのコードスパン」も
# 1 つのスパンとして捉える (#1087)
INLINE_CODE_RE = re.compile(r"(`+)([^\n]*?)\1")

# コード起点として扱うプレフィックス（リポジトリ内パスらしさの判定）
CODE_PATH_PREFIXES = (
    "src/",
    "docs/",
    "scripts/",
    ".claude/",
    "schemas/",
    "bin/",
    "app/",
    "lib/",
    "tests/",
    "test/",
)

# 除外対象: URL
URL_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.\-]*://")

# 除外対象: アンカーのみ（#section）
ANCHOR_ONLY_RE = re.compile(r"^#[^/]*$")

# 除外対象: プレースホルダ・例示（<...>, {...}, path/to, TASK-XXXX の XXXX 部等）
PLACEHOLDER_TOKENS = (
    "path/to",
    "example",
    "foo",
    "bar",
    "xxxx",
    "<",
    ">",
    "{",
    "}",
    "...",
)

# glob 表記
GLOB_CHARS = ("*", "?")


def _strip_anchor_and_query(path: str) -> str:
    """`#anchor` や `?query` をパス判定用に取り除く。"""
    for sep in ("#", "?"):
        idx = path.find(sep)
        if idx != -1:
            path = path[:idx]
    return path


def is_excluded(raw: str) -> tuple[bool, str]:
    """False-positive ガード。除外すべきなら (True, 理由) を返す。"""
    candidate = raw.strip()
    if not candidate:
        return True, "empty"

    if URL_RE.match(candidate):
        return True, "url"

    if ANCHOR_ONLY_RE.match(candidate):
        return True, "anchor-only"

    lowered = candidate.lower()
    for token in PLACEHOLDER_TOKENS:
        if token in lowered:
            return True, "placeholder"

    for ch in GLOB_CHARS:
        if ch in candidate:
            return True, "glob"

    return False, ""


def looks_like_repo_path(raw: str) -> bool:
    """コード内パス参照らしいかを判定する（誤検出を減らすための緩い正規化）。"""
    candidate = _strip_anchor_and_query(raw.strip())
    if not candidate:
        return False

    # コードブロック言語指定や単なる単語（拡張子なし・スラッシュなし）は除外
    if "/" not in candidate and "." not in candidate:
        return False

    # 明らかに自然文の一部（空白を含む）は除外
    if " " in candidate:
        return False

    if candidate.startswith(CODE_PATH_PREFIXES):
        return True

    # 相対パス表記（./ や ../）も対象
    if candidate.startswith("./") or candidate.startswith("../"):
        return True

    return False


def extract_candidates(text: str) -> list[str]:
    """Markdown リンクとインラインコードからパス候補を抽出する。

    **コードスパンをマスクしてから** Markdown リンクを探す (#1087)。
    コードスパンの中に書かれたリンク記法は「記法の説明」であって
    リンクではないため、リンクとして拾うと偽陽性になる:

        `` `[file.md](./file.md)` 形式でリンク化し ``
             ^^^^^^^^^^^^^^^^^^^ 参照ではなく記法の例示

    コードスパンの**中身**は従来どおり候補として拾う（挙動不変）。
    """
    candidates: list[str] = []
    masked = list(text)
    for match in INLINE_CODE_RE.finditer(text):
        candidates.append(match.group(2))
        for idx in range(match.start(), match.end()):
            masked[idx] = " "
    for match in MD_LINK_RE.finditer("".join(masked)):
        candidates.append(match.group(1))
    return candidates


def resolve_repo_relative(path_str: str, source_file: Path) -> Path:
    """相対パスをリポジトリルート基準に解決する。"""
    cleaned = _strip_anchor_and_query(path_str.strip())
    if cleaned.startswith("./") or cleaned.startswith("../"):
        base = source_file.parent
        return (base / cleaned).resolve()
    return (REPO_ROOT / cleaned).resolve()


def gitignored_paths(rel_paths: list[str]) -> set[str]:
    """与えた REPO_ROOT 相対パスのうち gitignore 対象のものを返す (#1087)。

    gitignore 対象のファイルは「リポジトリに存在しないことが正常」であり、
    存在しないことを stale 参照として扱ってはならない
    （例: `.claude/settings.json` は各利用者がローカル生成する）。

    これは同時に **実行環境依存の解消**でもある。`Path.exists()` だけを見ると
    settings.json を持つ開発機と持たない CI で判定が食い違い、
    「開発者がローカルで再現できない CI 失敗」を生む。

    **縮退**: git が使えない / 想定外の exit code の場合は空集合を返す
    （= 何も除外しない = 従来挙動）。検査を緩める方向に倒さない。
    """
    if not rel_paths:
        return set()
    try:
        proc = subprocess.run(
            ["git", "check-ignore", "--stdin"],
            cwd=str(REPO_ROOT),
            input="\n".join(rel_paths),
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return set()
    # 0 = 1 件以上が ignore 対象 / 1 = どれも ignore 対象でない
    # それ以外（128 等）は git が判断できていないので除外しない
    if proc.returncode not in (0, 1):
        return set()
    return {line.strip() for line in proc.stdout.splitlines() if line.strip()}


def check_file(path: Path) -> list[tuple[int, str, str]]:
    """1 ファイルを検査し、(行番号, 参照文字列, REPO_ROOT 相対の参照先) を返す。"""
    warnings: list[tuple[int, str, str]] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return warnings

    for lineno, line in enumerate(lines, start=1):
        for raw in extract_candidates(line):
            excluded, _reason = is_excluded(raw)
            if excluded:
                continue
            if not looks_like_repo_path(raw):
                continue

            cleaned = _strip_anchor_and_query(raw.strip())
            if not cleaned:
                continue

            resolved = resolve_repo_relative(raw, path)
            try:
                rel_target = resolved.relative_to(REPO_ROOT).as_posix()
            except ValueError:
                # リポジトリ外へ逸脱するパス（../ の辿りすぎ等）はスコープ外として無視
                continue

            if not resolved.exists():
                warnings.append((lineno, cleaned, rel_target))

    return warnings


def iter_target_files(roots: list[str]) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        for path in sorted(REPO_ROOT.glob(root)):
            if path.is_file() and path.suffix == ".md":
                files.append(path)
    return files


def run_scan(roots: list[str]) -> int:
    files = iter_target_files(roots)

    findings: list[tuple[Path, int, str, str]] = []
    for path in files:
        rel = path.relative_to(REPO_ROOT)
        for lineno, ref, rel_target in check_file(path):
            findings.append((rel, lineno, ref, rel_target))

    # gitignore 判定は 1 回のバッチ呼び出しにまとめる（参照 1 件ごとに
    # subprocess を起動しない）
    ignored = gitignored_paths(sorted({f[3] for f in findings}))

    total_warnings = 0
    skipped_ignored = 0
    for rel, lineno, ref, rel_target in findings:
        if rel_target in ignored:
            skipped_ignored += 1
            continue
        print(f"WARN {rel}:{lineno} → 非実在パス: {ref}")
        total_warnings += 1

    if skipped_ignored:
        # 何を見なくなったかを黙らせない（#1109 と同型の false green を作らない）
        print(
            f"INFO: {skipped_ignored} 件は gitignore 対象パスのため除外"
            "（存在しないことが正常。docs/ai/stale-ref-detection.md 参照）"
        )

    if total_warnings == 0:
        print(f"OK: {len(files)} ファイルを検査し stale パス参照なし")
        return 0

    print(f"合計 {total_warnings} 件の stale パス参照を検出")
    return 1


# =========================================================
# selftest
# =========================================================


def run_selftest() -> int:
    """内蔵ケースで false-positive ガードと実在/非実在判定を検証する。"""
    failures: list[str] = []

    def check(name: str, condition: bool) -> None:
        if not condition:
            failures.append(name)

    # 1. 実在パス → 除外されず、実在するので WARN にならない
    real_path = "scripts/check-stale-skill-refs.py"
    excluded, _ = is_excluded(real_path)
    check("real-path not excluded", not excluded)
    check("real-path looks_like_repo_path", looks_like_repo_path(real_path))
    resolved = resolve_repo_relative(real_path, REPO_ROOT / ".claude/skills/dummy/SKILL.md")
    check("real-path resolves and exists", resolved.exists())

    # 2. 非実在パス → WARN 対象
    fake_path = "scripts/definitely-not-a-real-file-691.py"
    excluded, _ = is_excluded(fake_path)
    check("fake-path not excluded", not excluded)
    resolved_fake = resolve_repo_relative(fake_path, REPO_ROOT / ".claude/skills/dummy/SKILL.md")
    check("fake-path does not exist", not resolved_fake.exists())

    # 3. glob 表記 → 除外
    glob_path = "config/*.ts"
    excluded, reason = is_excluded(glob_path)
    check("glob excluded", excluded and reason == "glob")

    glob_path2 = "docs/**/*.md"
    excluded2, reason2 = is_excluded(glob_path2)
    check("double-glob excluded", excluded2 and reason2 == "glob")

    # 4. プレースホルダ → 除外
    placeholder_cases = [
        "<repo-root>/src/index.ts",
        "path/to/file.ts",
        "docs/example/foo.md",
        "{{TASK_ID}}/plan.md",
    ]
    for case in placeholder_cases:
        excluded, reason = is_excluded(case)
        check(f"placeholder excluded: {case}", excluded and reason == "placeholder")

    # 5. URL → 除外
    url_cases = ["https://github.com/s977043/plangate", "http://example.com/docs"]
    for case in url_cases:
        excluded, reason = is_excluded(case)
        check(f"url excluded: {case}", excluded and reason == "url")

    # 6. アンカーのみ → 除外
    anchor_cases = ["#section", "#見出し"]
    for case in anchor_cases:
        excluded, reason = is_excluded(case)
        check(f"anchor excluded: {case}", excluded and reason == "anchor-only")

    # 7. 自然文（スペースを含む）は looks_like_repo_path で false
    check(
        "natural language not path",
        not looks_like_repo_path("this is not a path at all"),
    )

    # 8. check_file 統合テスト
    sample_text = (
        "See [real](scripts/check-stale-skill-refs.py) and "
        "[fake](scripts/does-not-exist-691.py) and `config/*.ts` glob and "
        "`path/to/example.md` placeholder.\n"
    )
    tmp_candidates = extract_candidates(sample_text)
    check(
        "extract_candidates finds all 4 refs",
        len(tmp_candidates) == 4,
    )

    # 9. #1087 B-1: コードスパン内のリンク記法はリンクとして拾わない
    notation_line = "`` `[file.md](./file.md)` `` 形式でリンク化し"
    notation_cands = extract_candidates(notation_line)
    check(
        "code-span link notation is not extracted as a link",
        "./file.md" not in notation_cands,
    )
    # 通常の（コードスパン外の）リンクは従来どおり拾う = 検出力を落としていない
    plain_link = "see [x](docs/no-such-file-1087.md) here"
    check(
        "plain markdown link is still extracted",
        "docs/no-such-file-1087.md" in extract_candidates(plain_link),
    )
    # インラインコード内の素のパスも従来どおり拾う
    check(
        "inline-code path is still extracted",
        "docs/no-such-file-1087.md" in extract_candidates("`docs/no-such-file-1087.md`"),
    )

    # 10. #1087 B-2: gitignore 対象は除外、非対象は除外しない
    ignored = gitignored_paths([".claude/settings.json", "scripts/check-stale-skill-refs.py"])
    check("gitignored path is reported as ignored", ".claude/settings.json" in ignored)
    check(
        "tracked path is not reported as ignored",
        "scripts/check-stale-skill-refs.py" not in ignored,
    )
    # 除外が広すぎないこと: ignore パターンに合致しない typo は除外されない
    typo_ignored = gitignored_paths([".claude/settingz.json"])
    check("typo near an ignored path is NOT excluded", ".claude/settingz.json" not in typo_ignored)
    check("empty input returns empty set", gitignored_paths([]) == set())

    if failures:
        print("SELFTEST FAIL:")
        for name in failures:
            print(f"  - {name}")
        return 1

    total_checks = 8 + 7 + len(placeholder_cases) + len(url_cases) + len(anchor_cases)
    print(f"SELFTEST PASS ({total_checks} checks)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "roots",
        nargs="*",
        default=list(DEFAULT_TARGET_GLOBS),
        help="検査対象の glob パターン（デフォルト: skills/commands/agents 配下の *.md）",
    )
    parser.add_argument(
        "--selftest",
        action="store_true",
        help="内蔵の false-positive ガード自己テストを実行する",
    )
    args = parser.parse_args(argv)

    if args.selftest:
        return run_selftest()

    try:
        return run_scan(args.roots)
    except Exception as exc:  # noqa: BLE001 - CLI 境界での明示的エラー化
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
