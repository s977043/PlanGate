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

__doc__ = """_ai_loop_link_rewrite.py — plugin bundle 用の markdown リンク自己完結化。

背景（issue #790）: sync-plugin-plangate.sh の _sync_ai_loop_ref_content が
docs/workflows/ai-loop/*.md・docs/ai/ai-loop/*.md を plugin/plangate/skills/
ai-loop-cycle/references/ へバンドルしているため、正本側の `../` /
`../../` / `../../../` 相対リンクが導入先（plugin consumer）ではリンク切れに
なる。本スクリプトは **plugin へ書き込む直前のコピー内容のみ**に対しリンクを
書き換える（正本 docs/ 側は一切変更しない — 正本は本リポジトリ内で相対リンク
が正しく解決するため）。

変換ルール（markdown インラインリンク `[text](path)` /
`[text](path#anchor)` のみ対象。フェンス付きコードブロック内・画像
`![alt](path)`・http(s)://・mailto:・同一ファイル内アンカー単独 (#foo) は
対象外）:

1. **同一実体判定**（issue #790 MAJOR 是正）: リンクの相対パスを変換対象
   ファイルの **ソースパス基準** で normpath 解決し、その実ファイルパスが
   「その basename でバンドルされた元ファイルの実パス」と **一致** する場合の
   み `[text](./name.md)`（アンカー保持）。basename が偶然バンドル集合に
   含まれても、解決先が別実体（例: `docs/ai/subagent-delegation/README.md`
   と `docs/ai/ai-loop/README.md`）なら 3 の外部扱いに落とす。
2. path が「本スキル自身の SKILL.md」（`skills/<skill_name>/SKILL.md` 形式・
   または既に `../SKILL.md`）→ `[text](../SKILL.md)`（references/ の親に実在）。
   他スキルの SKILL.md（例 `skills/pr-watch/SKILL.md`）は同梱されないため
   3 に落とす（basename 一致だけで無条件 ../SKILL.md 化すると誤誘導するため）。
3. 上記いずれでもない（真に外部・bundle 非同梱、または同一実体でない）
   → リンクを解除し **インラインコード表記** に統一する。basename が
   バンドル集合と衝突しうる（同名がバンドルにある）場合や他スキル SKILL.md は
   `<親ディレクトリ>/<basename>` として識別性を保つ（例
   `subagent-delegation/README.md`・`pr-watch/SKILL.md`）。それ以外は
   `<basename>`（例 `working-context.md`）。

   **リンクラベルの扱い（issue #1232 / 元 AC = #1196 案 B）**: 脱リンク時に
   ラベル（link_text）を捨てると、ラベルが説明文だった場合に配布物だけが意味を
   失う（例 `[`maintenance.json` 発行元ギャップ](...)` → `` `x.md` ``）。そこで
   `_is_path_label()` で **ラベル全体がパス 1 トークンか**を判定し、
   - パス 1 トークン（例 `` `docs/workflows/ai-loop/x.md` ``）→ 従来どおり
     basename へ正規化（情報は失われない）
   - それ以外（説明文・パスを含む文・空白を含む文）→
     `` <ラベル>（`<basename>`） `` としてラベルを保持
   判定は **空白を含めば必ず記述ラベル**（安全側）とする。部分一致で
   「パスを含む説明文」をパス扱いすると同じ消失が別形で残るため。

冪等性: 変換済み（`./name.md`・`../SKILL.md`・インラインコード化済み）に
再適用しても不変。`./<basename>`（basename∈bundle）は既に自己完結形なので
canonical fixed-point として素通しする（references/ 内では常に正しい sibling
参照。本リポジトリの 2 ソースディレクトリ docs/workflows/ai-loop と
docs/ai/ai-loop は basename 衝突が無いことを確認済みのため、sibling `./name.md`
が別実体を指す誤変換は起きない）。

Usage:
    _ai_loop_link_rewrite.py <content_src> <source_path> <skill_name> <bundle_map_tsv>

  content_src   : 変換対象の内容を読むファイル（ho-paths.md はヘッダ前置後の
                  一時ファイル）
  source_path   : 相対リンク解決の基準となる **論理ソースパス**（正本 doc の
                  実パス。ho-paths.md はヘッダ前置前の元パス）
  skill_name    : スキル名（例 ai-loop-cycle）
  bundle_map_tsv: `basename<TAB>ソース実パス` を 1 行 1 件で列挙した TSV。
                  この写像の key 集合がバンドル集合を成す。

標準出力に変換後の内容を書き出す（sync script 側で mktemp 経由の比較・
書き込みに使う想定）。
"""

import os
import re
import sys

# フェンス付きコードブロック（``` と ~~~ の両方）を保護対象にする
# （コードブロック内は変換しない）。開き marker と同一 marker で閉じる
# （``` は ``` で・~~~ は ~~~ で）ようバックリファレンスで対にする。
# インラインコードで囲まれたリンク表示テキスト（本リポジトリの支配的記法
# `[`text`](path)`）はリンク構造の一部として扱い、あえてマスクしない
# （マスクすると `[` と `](path)` が分断され、リンクとして検出できなくなる）。
_FENCE_RE = re.compile(r"(?P<fence>```|~~~).*?(?P=fence)", re.DOTALL)
# 画像 `![...](...)` は変換対象外（直前が `!` のリンクはスキップ）。
_LINK_RE = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s][^)]*)\)")

_EXTERNAL_SCHEMES = ("http://", "https://", "mailto:")


def _real(path: str) -> str:
    # 同一実体判定は symlink を解決してから比較する（macOS の /tmp→/private/tmp 等で
    # リンク解決先とバンドル元 abspath の表現が食い違い、同一実体を「別」と誤判定して
    # 過剰に inline code 化するのを防ぐ / gemini MEDIUM）。realpath は存在しない末尾
    # 要素にも安全（字句的に正規化）で、存在ファイルには symlink 解決も効く。
    return os.path.realpath(path)


_WHITESPACE_RE = re.compile(r"\s")


def _is_path_label(link_text: str) -> bool:
    """リンクラベルが **全体としてパス 1 トークン** かを判定する。

    このコーパスのリンクは大半が `[`docs/workflows/ai-loop/x.md`](../x.md)` の
    ように **ラベル自体がパス**であり、その場合ラベルを basename へ正規化しても
    情報は失われない（従来挙動）。一方 `[`maintenance.json` 発行元ギャップ](…)`
    のような **記述ラベル**を basename へ潰すと、何の話なのかが読み手に伝わらなく
    なる。両者を区別するための判定。

    **部分一致で判定しないこと**（TASK-1232 敵対レビュー MAJOR-1）。
    「パスを含む説明文」「拡張子で終わる説明文」を部分一致でパス扱いすると、
    塞いだはずの消失が別形で残る:

        [EH-3 の check-plan-hash.sh](…)    末尾が .sh
        [詳細は docs/ai/foo.md を参照](…)   "/" を含む

    したがって **空白を含むラベルは無条件で記述ラベル**（安全側）とし、
    空白なしのときだけ `/` または `.` の有無でパスらしさを見る。拡張子を
    allowlist で列挙すると `.jsonl` / `.ndjson` のような新しい拡張子を
    取りこぼすため、列挙はしない。
    """
    plain = link_text.replace("`", "").strip()
    if not plain:
        return True  # ラベルが空なら保持しても意味がない = 従来どおり basename のみ
    if _WHITESPACE_RE.search(plain):
        return False  # 空白を含む = 説明文（安全側）
    return "/" in plain or "." in plain


def _wrap(link_text: str, inline: str) -> str:
    """脱リンク結果にラベルを添える整形（記述ラベルのときのみ呼ぶ）。

    `_inline()` と foreign SKILL.md 分岐の 2 箇所で同じ整形を使うため関数化する
    （片方だけ書式を変える事故を防ぐ / 同レビュー MINOR-4）。

    ラベルが basename と同一（例 `[README](../../ai/README)`）なら添えても情報が
    増えないため、`README（`README`）` のような重複を作らず inline のみを返す。
    """
    if link_text.replace("`", "").strip() == inline.strip("`"):
        return inline
    return f"{link_text}（{inline}）"


def _inline(
    segments: list[str], basename: str, bundle: set[str], link_text: str | None = None
) -> str:
    """外部リンクをインラインコード化する。basename がバンドル集合と衝突しうる
    場合は識別性のため親ディレクトリを前置する（例 subagent-delegation/README.md）。

    `link_text` に **記述ラベル**（パスでない説明文）が渡された場合は、ラベルを
    捨てずに `<ラベル>（`<basename>`）` の形で保持する。ラベルを落とすと配布物
    だけが意味を失う（issue #1232 と同型の「参照はあるが導入先で成立しない」）。
    ラベルがパスそのものの場合は従来どおり basename へ正規化する（冪等性・
    既存リンクの出力不変を維持）。
    """
    if basename in bundle and len(segments) >= 2:
        inline = f"`{segments[-2]}/{basename}`"
    else:
        inline = f"`{basename}`"
    if link_text is not None and not _is_path_label(link_text):
        return _wrap(link_text, inline)
    return inline


def _rewrite_links_in_segment(
    text: str, bundle: set[str], bundle_src: dict[str, str], src_dir: str, skill_name: str
) -> str:
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

        # ディレクトリ参照（末尾 "/"、例 "../../workflows/ai-loop/"）にも対応。
        # 末尾スラッシュを除いた最終セグメントを basename 相当として扱う。
        stripped = path_part.rstrip("/")
        if not stripped:
            return m.group(0)
        segments = stripped.split("/")
        basename = segments[-1]
        if not basename:
            return m.group(0)

        # canonical fixed-point（冪等性）: 既に `./<basename>`（basename∈bundle）
        # なら references/ 内で正しい sibling 参照なので素通し。
        if path_part == f"./{basename}" and basename in bundle:
            return m.group(0)

        # 本スキル自身の SKILL.md（構造的同一性判定）→ ../SKILL.md
        is_own_skill_md = (
            basename == "SKILL.md"
            and (
                path_part == "../SKILL.md"
                or (
                    len(segments) >= 3
                    and segments[-3] == "skills"
                    and segments[-2] == skill_name
                )
            )
        )
        if is_own_skill_md:
            return f"[{link_text}](../SKILL.md{anchor_suffix})"

        is_foreign_skill_md = (
            basename == "SKILL.md"
            and len(segments) >= 3
            and segments[-3] == "skills"
            and segments[-2] != skill_name
        )
        if is_foreign_skill_md:
            # 他スキルの SKILL.md は同梱されない → `<skill>/SKILL.md` inline
            inline = f"`{segments[-2]}/SKILL.md`"
            if not _is_path_label(link_text):
                return _wrap(link_text, inline)
            return inline

        # 同一実体判定（issue #790 MAJOR）: basename がバンドル集合にあっても、
        # 相対リンクを src_dir 基準で解決した実パスがバンドル元と一致する時のみ
        # ./name.md 化する。不一致なら別実体なので外部扱い（inline code）。
        if basename in bundle:
            resolved = _real(os.path.join(src_dir, path_part))
            if resolved == _real(bundle_src[basename]):
                return f"[{link_text}](./{basename}{anchor_suffix})"
            return _inline(segments, basename, bundle, link_text)

        return _inline(segments, basename, bundle, link_text)

    return _LINK_RE.sub(_replace, text)


def rewrite(
    content: str, bundle_src: dict[str, str], source_path: str, skill_name: str
) -> str:
    """フェンス付きコードブロックを保護しつつ、それ以外にリンク変換を適用する。"""
    bundle = set(bundle_src.keys())
    # source_path も realpath 化して基準ディレクトリを求める（両辺 symlink 解決で一致判定）
    src_dir = os.path.dirname(os.path.realpath(source_path))
    out: list[str] = []
    last = 0
    for m in _FENCE_RE.finditer(content):
        out.append(
            _rewrite_links_in_segment(
                content[last : m.start()], bundle, bundle_src, src_dir, skill_name
            )
        )
        out.append(m.group(0))
        last = m.end()
    out.append(
        _rewrite_links_in_segment(content[last:], bundle, bundle_src, src_dir, skill_name)
    )
    return "".join(out)


def _load_bundle_map(tsv_path: str) -> dict[str, str]:
    bundle_src: dict[str, str] = {}
    with open(tsv_path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\r\n")  # CRLF 環境で末尾 \r を残さない（gemini MEDIUM）
            if not line:
                continue
            basename, _, abspath = line.partition("\t")
            if not basename or not abspath:
                continue
            bundle_src[basename] = abspath
    return bundle_src


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        sys.stderr.write(
            "usage: _ai_loop_link_rewrite.py "
            "<content_src> <source_path> <skill_name> <bundle_map_tsv>\n"
        )
        return 2
    content_src, source_path, skill_name, bundle_map_tsv = argv[1:5]
    bundle_src = _load_bundle_map(bundle_map_tsv)
    with open(content_src, encoding="utf-8") as f:
        content = f.read()
    sys.stdout.write(rewrite(content, bundle_src, source_path, skill_name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
