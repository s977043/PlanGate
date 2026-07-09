#!/usr/bin/env python3
"""_ai_loop_link_rewrite.py — plugin bundle 用の markdown リンク自己完結化。

背景（issue #790）: sync-plugin-plangate.sh の _sync_ai_loop_content が
docs/workflows/ai-loop/*.md・docs/ai/ai-loop/*.md を verbatim cp で
plugin/plangate/skills/ai-loop-cycle/references/ へバンドルしているため、
正本側の `../` / `../../` / `../../../` 相対リンクが導入先（plugin
consumer）ではリンク切れになる。本スクリプトは **plugin へ書き込む直前の
コピー内容のみ**に対しリンクを書き換える（正本 docs/ 側は一切変更しない
— 正本は本リポジトリ内で相対リンクが正しく解決するため）。

変換ルール（markdown リンク `[text](path)` / `[text](path#anchor)` のみ対象。
コードブロック内は対象外。http(s)://・mailto:・同一ファイル内アンカー単独
(#foo) は対象外）:

1. path の basename が references/ にバンドルされる集合（bundle_basenames）
   に含まれる → `[text](./name.md)`（アンカー保持）
2. path が「本スキル自身の SKILL.md」（basename が SKILL.md で、
   `skills/<skill_name>/` 配下を指す、または既に `../SKILL.md` 形式）
   → `[text](../SKILL.md)`（アンカー保持。references/ の親に実在するため）
   ※ 他スキルの SKILL.md（例: `skills/pr-watch/SKILL.md`）は本スキルに
   同梱されないため、この規則の対象外とし 3 に落とす（誤った参照先を
   防ぐための限定 — basename 一致だけで無条件に ../SKILL.md 化すると
   別スキルの SKILL.md へ誤誘導するため）
3. 上記いずれでもない（真に外部・bundle 非同梱）
   → リンクを解除し、basename のインラインコード表記に統一する
   （表示テキストは破棄。例外: 他スキルの SKILL.md は `<skill>/SKILL.md`
   として識別性を保持する）

冪等性: 変換済みファイル（`./name.md` や `../SKILL.md`、インラインコード化
済み）に再度適用しても不変であること。

Usage:
    _ai_loop_link_rewrite.py <src_file> <skill_name> [bundle_basename ...]

標準出力に変換後の内容を書き出す（sync script 側で mktemp 経由の
比較・書き込みに使う想定）。
"""
from __future__ import annotations

import re
import sys

# フェンス付きコードブロックのみ保護対象とする（コードブロック内は変換しない）。
# インラインコードで囲まれたリンク表示テキスト（本リポジトリの支配的記法
# `[`text`](path)`）はリンク構造の一部として扱い、あえてマスクしない
# （マスクすると `[` と `](path)` が分断され、リンクとして検出できなくなる）。
_FENCE_RE = re.compile(r"```.*?```", re.DOTALL)
_LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)\s][^)]*)\)")

_EXTERNAL_SCHEMES = ("http://", "https://", "mailto:")


def _rewrite_links_in_segment(text: str, bundle: set[str], skill_name: str) -> str:
    def _replace(m: "re.Match[str]") -> str:
        link_text, path = m.group(1), m.group(2)

        if path.startswith(_EXTERNAL_SCHEMES):
            return m.group(0)
        if path.startswith("#"):
            return m.group(0)

        path_part, sep, anchor = path.partition("#")
        if not path_part:
            return m.group(0)
        anchor_suffix = f"#{anchor}" if sep else ""

        # ディレクトリ参照（末尾 "/"、例 "../../workflows/ai-loop/"）にも対応する。
        # 末尾スラッシュを除いた最終セグメントを basename 相当として扱う
        # （素朴に split("/")[-1] だけだと空文字になり無変換のまま dead link が
        # 残ってしまうため）。
        _stripped = path_part.rstrip("/")
        if not _stripped:
            return m.group(0)
        segments = _stripped.split("/")
        basename = segments[-1]
        if not basename:
            return m.group(0)

        is_foreign_skill_md = (
            basename == "SKILL.md"
            and len(segments) >= 3
            and segments[-3] == "skills"
            and segments[-2] != skill_name
        )
        if basename == "SKILL.md" and not is_foreign_skill_md:
            return f"[{link_text}](../SKILL.md{anchor_suffix})"
        if basename in bundle:
            return f"[{link_text}](./{basename}{anchor_suffix})"
        if is_foreign_skill_md:
            # 他スキルの SKILL.md は同梱されないため、識別性を保つため
            # `<skill>/SKILL.md` の inline code に落とす（basename 単独
            # だと ai-loop-cycle 自身の SKILL.md と区別できないため）
            return f"`{segments[-2]}/SKILL.md`"
        return f"`{basename}`"

    return _LINK_RE.sub(_replace, text)


def rewrite(content: str, bundle: set[str], skill_name: str) -> str:
    """フェンス付きコードブロックを保護しつつ、それ以外にリンク変換を適用する。"""
    out: list[str] = []
    last = 0
    for m in _FENCE_RE.finditer(content):
        out.append(_rewrite_links_in_segment(content[last : m.start()], bundle, skill_name))
        out.append(m.group(0))
        last = m.end()
    out.append(_rewrite_links_in_segment(content[last:], bundle, skill_name))
    return "".join(out)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        sys.stderr.write(
            "usage: _ai_loop_link_rewrite.py <src_file> <skill_name> [bundle_basename ...]\n"
        )
        return 2
    src_file, skill_name = argv[1], argv[2]
    bundle = set(argv[3:])
    with open(src_file, encoding="utf-8") as f:
        content = f.read()
    sys.stdout.write(rewrite(content, bundle, skill_name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
