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

__doc__ = """Growth Harness L2: improvement-seeds と digest の差分を読み取り専用で棚卸しする（#1545 / #1608）。

構造判定は行単位のブロック状態機械で行う（CommonMark のブロック規則のうち、判定に使う
fenced code / HTML block（type 1〜7）/ indented code / ATX 見出し / setext 見出し / 段落・リストだけを持つ）。
正規表現は 1 行の字句判定にだけ使う。

残存脅威モデル（本検査は多層防御の 1 層にすぎず、最終保証は C-4 の Human レビュー）
守るもの:
- 正規形でない日付見出し（表記ゆれ・lookalike・blockquote / リスト内 / setext / 不可視文字・全角数字を含むもの）は拒否
- code / HTML ブロック内の seed と確認マーカーは数えない。閉じていない fence / HTML ブロックは拒否
- 確認マーカーの欠落・重複（ネストしたものを含む）・否定値・プレースホルダ・不可視文字は拒否。
  値は HTML タグ・コメントとインライン記号（` * _ ~）を外した表示上の値で判定する
- リスト項目内で開いた fence / HTML ブロックは項目の終了で閉じる。seed でない節見出しで確認マーカーの帰属を切る
- 閉じ "#" 列や末尾空白を含む見出しは、renderer の表示と識別子がずれるため拒否
守らないもの:
- CommonMark の全規則ではない。リスト項目の内容オフセットは 2 桁固定の近似で、順序付きリスト
  （"1. " など）の継続行・入れ子の深いリストでは renderer と判定がずれうる
- 先頭語が否定値と同綴りの正当な人名（例: "Na Yeon"）は拒否する（安全側の誤り / #1608 Q-4）
- 本文中の文としての confirmed_by の言及も確認マーカー候補として扱う（安全側の誤拒否）
- confirmed_by の値が実在の Human による確認であることは検証しない（authority を参照）
"""

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

CANONICAL_SEED = re.compile(r"## ([0-9]{4}-[0-9]{2}-[0-9]{2} — .+)")
# 末尾の閉じ "#" 列は renderer が表示しないため、識別子に含まれると表示と食い違う
CLOSING_SEQUENCE = re.compile(r"[ \t]#+[ \t]*$")
# \d は Unicode 数字にも一致する。全角数字などの lookalike を候補として拾うために意図して使う。
DATE_LIKE = re.compile(r"\d{4}-\d{2}-\d{2}")
ATX = re.compile(r"(#{1,6})(?:[ \t]|$)")
FENCE_OPEN = re.compile(r"(`{3,}|~{3,})(.*)")
SETEXT_UNDERLINE = re.compile(r"(?:=+|-+)[ \t]*")
LIST_MARKER = re.compile(r"(?:[-*+]|[0-9]{1,9}[.)])(?:[ \t]+|$)")
CONFIRMATION = re.compile(r"- confirmed_by:[ \t]*(.*)")
HTML_TYPE1 = re.compile(r"<(?:script|pre|style|textarea)(?:[ \t>]|$)", re.IGNORECASE)
HTML_TYPE1_END = re.compile(r"</(?:script|pre|style|textarea)>", re.IGNORECASE)
HTML_TYPE6 = re.compile(
    r"</?(?:address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|"
    r"dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|"
    r"html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|"
    r"section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)(?:[ \t>]|/>|$)",
    re.IGNORECASE,
)
HTML_TYPE7 = re.compile(
    r"(?:<[A-Za-z][A-Za-z0-9-]*(?:[ \t]+[A-Za-z_:][A-Za-z0-9_.:-]*"
    r"(?:[ \t]*=[ \t]*(?:[^ \t\"'=<>`]+|'[^']*'|\"[^\"]*\"))?)*[ \t]*/?>"
    r"|</[A-Za-z][A-Za-z0-9-]*[ \t]*>)[ \t]*"
)
HTML_SIMPLE_STARTS = (("<!--", "-->"), ("<?", "?>"), ("<![CDATA[", "]]>"))
UNCONFIRMED = {
    "<human>", "pending", "tbd", "none", "未確認",
    "no", "n", "false", "-", "n/a", "na", "null", "unconfirmed", "rejected", "なし", "未", "否", "保留",
}
CANONICAL_ERROR = "seed heading does not match the canonical '## YYYY-MM-DD — <task_id>' format"


def has_invisible(text: str) -> bool:
    for char in text:
        category = unicodedata.category(char)
        if category[0] == "C" or category in ("Zl", "Zp") or (category == "Zs" and char != " "):
            return True
    return False


def skeleton(text: str) -> str:
    """不可視の書式文字を落とし、Unicode 空白を ASCII 空白に寄せる（候補の検出専用。受理判定には使わない）。"""
    chars = []
    for char in text:
        category = unicodedata.category(char)
        if category == "Cf":
            continue
        chars.append(" " if category == "Zs" or char == "\t" else char)
    return "".join(chars).strip(" ")


def strip_containers(text: str) -> str:
    """blockquote とリストマーカーの接頭辞を外す。"""
    while True:
        if text.startswith(">"):
            text = text[1:].lstrip(" ")
            continue
        marker = LIST_MARKER.match(text)
        if marker and text[marker.end():]:
            text = text[marker.end():]
            continue
        return text


def indent_of(line: str) -> tuple[int, str]:
    column = 0
    for index, char in enumerate(line):
        if char == " ":
            column += 1
        elif char == "\t":
            column += 4 - column % 4
        else:
            return column, line[index:]
    return column, ""


def html_block_start(rest: str, interrupts_paragraph: bool):
    """HTML ブロックの開始なら終了条件を返す（None は空行で終わる type 6/7）。開始でなければ False。"""
    if HTML_TYPE1.match(rest):
        return HTML_TYPE1_END
    for opener, closer in HTML_SIMPLE_STARTS:
        if rest.startswith(opener):
            return closer
    if rest.startswith("<!") and rest[2:3].isalpha():
        return ">"
    if HTML_TYPE6.match(rest):
        return None
    if not interrupts_paragraph and HTML_TYPE7.fullmatch(rest):
        return None
    return False


def html_block_ends(line: str, closer) -> bool:
    if isinstance(closer, str):
        return closer in line
    return bool(closer.search(line))


def classify(source: str) -> list[tuple[str, str]]:
    """各行を (kind, line) に分類する。kind は blank / code / html / heading / text。"""
    lines = source.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    result: list[tuple[str, str]] = []
    fence = None
    html = None
    in_html = False
    paragraph: list[str] = []
    in_list = False
    previous_blank = True
    block_in_list = False
    for line in lines:
        if (fence is not None or in_html) and block_in_list and line.strip(" \t") and indent_of(line)[0] < 2:
            # リスト項目内で開いたブロックは、項目が終わる（列 0〜1 の行が来る）と一緒に閉じる
            fence, in_html, in_list, paragraph = None, False, False, []
        if fence is not None:
            result.append(("code", line))
            column, rest = indent_of(line)
            closing = FENCE_OPEN.fullmatch(rest)
            if (
                column <= 3 + (2 if block_in_list else 0)
                and closing
                and closing.group(1)[0] == fence[0]
                and len(closing.group(1)) >= len(fence)
                and not closing.group(2).strip(" \t")
            ):
                fence = None
            continue
        if in_html:
            if html is None and not line.strip(" \t"):
                in_html = False
                result.append(("blank", line))
                previous_blank = True
                continue
            result.append(("html", line))
            if html is not None and html_block_ends(line, html):
                in_html = False
            continue
        if not line.strip(" \t"):
            result.append(("blank", line))
            paragraph = []
            previous_blank = True
            continue
        column, rest = indent_of(line)
        block_in_list = in_list and column >= 2 and not paragraph
        if block_in_list:
            column -= 2
        elif in_list and column < 2 and previous_blank and not LIST_MARKER.match(skeleton(rest)):
            in_list = False
        previous_blank = False
        if column >= 4 and not paragraph:
            result.append(("code", line))
            continue
        if column <= 3:
            opening = FENCE_OPEN.fullmatch(rest)
            if opening and (opening.group(1)[0] == "~" or "`" not in opening.group(2)):
                fence = opening.group(1)
                paragraph = []
                result.append(("code", line))
                continue
            closer = html_block_start(rest, bool(paragraph))
            if closer is not False:
                paragraph = []
                result.append(("html", line))
                start = rest.find("<") + 1
                in_html = not (closer is not None and html_block_ends(rest[start:], closer))
                html = closer
                continue
            if paragraph and SETEXT_UNDERLINE.fullmatch(rest):
                if any(DATE_LIKE.search(skeleton(text)) for text in paragraph):
                    raise ValueError(CANONICAL_ERROR)
                paragraph = []
                result.append(("text", line))
                continue
            if ATX.match(rest):
                paragraph = []
                in_list = in_list and column > 0
                result.append(("heading", line))
                continue
        if LIST_MARKER.match(skeleton(rest)):
            in_list = True
        paragraph.append(rest)
        result.append(("text", line))
    if fence is not None:
        raise ValueError(f"unclosed code fence '{fence}'")
    if in_html and html is not None:
        raise ValueError("unclosed HTML block")
    return result


def canonical_title(heading: str) -> str | None:
    match = CANONICAL_SEED.fullmatch(heading)
    if match is None or has_invisible(heading) or heading != heading.rstrip(" ") or CLOSING_SEQUENCE.search(heading):
        return None
    return match.group(1)


def seed_title(line: str) -> str | None:
    """日付見出しの候補なら正規形のタイトルを返し、候補でなければ None。正規形でない候補は拒否する。"""
    content = strip_containers(skeleton(line))
    if not content.startswith("#") or not DATE_LIKE.search(content):
        return None
    title = canonical_title(line)
    if title is None:
        raise ValueError(CANONICAL_ERROR)
    return title


def is_unconfirmed(value: str) -> bool:
    # 表示上の値で判定する: HTML タグ・コメントを落とし、インライン強調・コードの記号を外す。
    if "<!--" in value and "-->" not in value:
        return True
    rendered = re.sub(r"<!--.*?-->|<[^>]*>", "", value)
    normalized = re.sub(r"[`*_~]", "", rendered).strip().lower()
    first = re.split(r"[\s（(:：,、]", normalized, maxsplit=1)[0]
    return not normalized or normalized in UNCONFIRMED or first in UNCONFIRMED


def read_declared_seeds(path: Path) -> list[str]:
    entries: list[str] = []
    confirmations: list[list[str]] = []
    in_seed = False
    for kind, line in classify(path.read_text(encoding="utf-8-sig")):
        if kind not in ("text", "heading"):
            continue
        title = seed_title(line)
        if title is not None:
            entries.append(title)
            confirmations.append([])
            in_seed = True
            continue
        if kind == "heading" and len(ATX.match(indent_of(line)[1]).group(1)) <= 2:
            in_seed = False  # seed でない節見出しで、確認マーカーの帰属を切る
            continue
        content = strip_containers(skeleton(line))
        if entries and content.lower().startswith("confirmed_by"):
            if not in_seed:
                raise ValueError("confirmation marker outside a seed section")
            confirmations[-1].append(line)
    if not entries:
        raise ValueError("no seed entries found")
    for title, markers in zip(entries, confirmations):
        marker = CONFIRMATION.fullmatch(markers[0]) if len(markers) == 1 else None
        if marker is None or has_invisible(marker.group(1)) or is_unconfirmed(marker.group(1)):
            raise ValueError(f"seed has missing or ambiguous confirmation marker: {title}")
    if len(entries) != len(set(entries)):
        raise ValueError("duplicate seed heading")
    return entries


def read_digest_index(path: Path) -> list[str]:
    lines = classify(path.read_text(encoding="utf-8-sig"))
    starts = [i for i, (kind, line) in enumerate(lines) if kind == "heading" and line.rstrip(" \t") == "## 対象エントリ"]
    if not starts:
        raise ValueError("digest is missing the target entry section")
    if len(starts) != 1:
        raise ValueError("digest has more than one target entry section")
    indexed = []
    for kind, line in lines[starts[0] + 1:]:
        if kind == "heading" and len(ATX.match(indent_of(line)[1]).group(1)) <= 2:
            break
        if kind == "blank":
            continue
        if kind != "text" or not line.startswith("- "):
            raise ValueError("digest entry section contains an unrecognized record")
        title = line[2:].strip(" ")
        if canonical_title("## " + title) is None:
            raise ValueError("digest entry does not match the seed identity format")
        indexed.append(title)
    if not indexed or len(indexed) != len(set(indexed)):
        raise ValueError("digest index empty or contains duplicates")
    return indexed


def inventory(seeds_path: Path, digest_path: Path, threshold: int) -> dict:
    if threshold < 1:
        raise ValueError("threshold must be positive")
    seeds = read_declared_seeds(seeds_path)
    indexed = read_digest_index(digest_path)
    missing = set(indexed) - set(seeds)
    if missing:
        raise ValueError("digest refers to seeds that are absent or lack a confirmation marker")
    indexed_set = set(indexed)
    new = [entry for entry in seeds if entry not in indexed_set]
    return {
        "status": "REVIEW_CANDIDATE" if len(new) >= threshold else "BELOW_THRESHOLD",
        "entries_with_confirmation_marker": len(seeds),
        "already_indexed": len(indexed),
        "unindexed_count": len(new),
        "threshold": threshold,
        "unindexed_entries": new,
        "authority": "READ_ONLY_UNVERIFIED_MARKER_NO_PROMOTION",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=Path, required=True)
    parser.add_argument("--digest", type=Path, required=True)
    parser.add_argument("--threshold", type=int, default=5)
    args = parser.parse_args()
    try:
        result = inventory(args.seeds, args.digest, args.threshold)
    except (OSError, ValueError, UnicodeError) as exc:
        print(f"improvement-seed inventory error: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
