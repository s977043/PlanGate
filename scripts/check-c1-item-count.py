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
C-1 チェック項目数の整合検査（#960 再発防止）。

## 何を守るか

C-1 のチェック項目数が本文に直書きされ、正本を更新しても追随せず
15 / 17 / 20 / 25 の 4 通りに散った（#960）。本検査は 2 点を守る:

1. **正本の自己整合** — `docs/working/templates/review-self.md` の
   「C-1 チェック項目数（正本）」表の **合計** が、同ファイルの実際の
   項目見出し（`### C1-...`）の数と一致すること。
2. **他ドキュメントの追随** — 他ファイルが C-1 の項目数を数値で直書き
   している場合、その数が**正本から導出できる値**（合計、区分ごとの数、
   簡易版 `C1-PLAN-01`〜`07` の 7）のいずれかであること。

## この検査自身が空振りしないための設計

- **ID の形を仮定しない**。項目 ID は `C1-PLAN-01` / `C1-PLAN-08-AEE` /
  `C1-SUP-PLAN-01` / `C1-TODO-RB` / `C1-B1B2-16` / `C1-SCOPE-DISC-01` と
  形が揃っていない。`C1-[A-Z]+-[0-9]+` のような決め打ちは 25 項目のうち
  **19 しか拾えず、少なく数える**。よって `### C1-` で始まる見出し行を数える。
- **許容値を定数で持たない**。許容値はすべて正本ファイルから導出する。
  定数で持つと、正本を更新したときに本検査自身が古い値を守り続ける。
- **`.claude/worktrees/` を走査しない**。エージェント作業用の worktree は
  任意の時点のコピーであり、正本の状態を表さない。

## 限界（この検査が守らないもの）

- 数値を伴わない誤りは検出しない（例: 項目の内容が実体と食い違う）。
- `docs/working/` 配下は過去記録として走査対象外。当時の値のまま残ってよい。
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CANON_REL = "docs/working/templates/review-self.md"
CANON = REPO_ROOT / CANON_REL

SCAN_ROOTS = (".claude", "plugin/plangate", "docs/ai", "docs/workflows", ".agents", ".codex")
EXCLUDE_PARTS = (".claude/worktrees/",)

TOTAL_RE = re.compile(r"\|\s*\*\*合計\*\*\s*\|[^|]*\|\s*\*\*(\d+)\*\*\s*\|")
ROW_COUNT_RE = re.compile(r"^\|(?!\s*\*\*合計)[^|]+\|[^|]*`C1-[^|]*\|\s*(\d+)\s*\|", re.MULTILINE)
HEADING_RE = re.compile(r"^###\s+(C1-\S+?):", re.MULTILINE)
INLINE_RE = re.compile(r"(\d+)\s*項目")


def derive_allowed(text):
    """許容される項目数の集合を正本から導出する。"""
    allowed = set()

    m = TOTAL_RE.search(text)
    total = int(m.group(1)) if m else None
    if total is not None:
        allowed.add(total)

    # 区分ごとの数（表の各行）
    allowed.update(int(n) for n in ROW_COUNT_RE.findall(text))

    headings = HEADING_RE.findall(text)
    allowed.add(len(headings))

    # 接頭辞ごとの実数
    prefixes = {}
    for h in headings:
        prefixes[h.rsplit("-", 1)[0]] = prefixes.get(h.rsplit("-", 1)[0], 0) + 1
    allowed.update(prefixes.values())

    # 簡易版（mode-classification の「Plan 項目のみ」）= C1-PLAN-01〜07
    simple = sum(1 for h in headings if re.fullmatch(r"C1-PLAN-0[1-7]", h))
    if simple:
        allowed.add(simple)

    return total, headings, allowed


def iter_targets():
    for root in SCAN_ROOTS:
        base = REPO_ROOT / root
        if not base.exists():
            continue
        for path in base.rglob("*.md"):
            rel = path.relative_to(REPO_ROOT).as_posix()
            if any(part in rel for part in EXCLUDE_PARTS):
                continue
            if path == CANON:
                continue
            yield path, rel


def main() -> int:
    if not CANON.exists():
        print(f"FAIL: 正本が見つからない: {CANON_REL}", file=sys.stderr)
        return 1

    text = CANON.read_text(encoding="utf-8")
    total, headings, allowed = derive_allowed(text)

    rc = 0
    if total is None:
        print("FAIL: 正本に「合計」行が無い（項目数表が壊れている）", file=sys.stderr)
        print(f"  対象: {CANON_REL}", file=sys.stderr)
        return 1

    if total != len(headings):
        print(
            f"FAIL: 正本の宣言値と実体が不一致: 合計={total} / 項目見出し={len(headings)}",
            file=sys.stderr,
        )
        print(f"  対象: {CANON_REL}", file=sys.stderr)
        print(f"  検出した項目: {', '.join(headings)}", file=sys.stderr)
        rc = 1

    for path, rel in sorted(iter_targets(), key=lambda t: t[1]):
        try:
            body = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for line_no, line in enumerate(body.splitlines(), 1):
            if "C-1" not in line and "C1" not in line and "セルフレビュー" not in line:
                continue
            for found in INLINE_RE.findall(line):
                if int(found) not in allowed:
                    print(
                        f"FAIL: C-1 項目数の直書きが正本から導出できない: {found}",
                        file=sys.stderr,
                    )
                    print(f"  {rel}:{line_no}: {line.strip()}", file=sys.stderr)
                    print(
                        f"  正本の合計={total} / 許容={sorted(allowed)}"
                        f" （正本: {CANON_REL}）",
                        file=sys.stderr,
                    )
                    rc = 1

    if rc == 0:
        print(f"PASS: C-1 項目数 {total}（項目見出し {len(headings)} と一致）"
              f" / 直書き参照はすべて正本から導出可能")
    return rc


if __name__ == "__main__":
    sys.exit(main())
