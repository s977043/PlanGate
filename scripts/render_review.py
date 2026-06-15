#!/usr/bin/env python3
"""render_review.py — C-3 レビュー対象 MD を 1 枚の自己完結 HTML に集約する。

TASK-0127. Python 標準ライブラリのみ（新規 pip 依存なし）。

Usage:
    python3 scripts/render_review.py --task TASK-XXXX [--work-dir DIR] [--out FILE]

出力: docs/working/<TASK>/<TASK>-c3-review.html（既定）
対象: working-context.md 定義の C-3 アーティファクト 7 種（存在するもののみ）。
"""
import argparse
import html
import os
import re
import sys

# C-3 対象 7 種（表示順）
C3_ARTIFACTS = [
    ("pbi-input.md", "PBI INPUT PACKAGE"),
    ("plan.md", "EXECUTION PLAN"),
    ("todo.md", "EXECUTION TODO"),
    ("test-cases.md", "TEST CASES"),
    ("review-self.md", "C-1 セルフレビュー"),
    ("review-external.md", "C-2 外部レビュー"),
    ("handoff.md", "HANDOFF"),
]

_INLINE_CODE = re.compile(r"`([^`]+)`")
_BOLD = re.compile(r"\*\*([^*]+)\*\*")
_ITALIC = re.compile(r"(?<!\*)\*(?!\*)([^*]+)\*(?!\*)")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
_CHECK = re.compile(r"^(\s*)[-*+]\s+\[([ xX])\]\s+(.*)$")


_SCHEME = re.compile(r"^\s*([a-zA-Z][a-zA-Z0-9+.\-]*):")
_ALLOWED_SCHEMES = ("http", "https", "mailto")


def _link_sub(m):
    """[label](url) を安全に <a> へ。許可外スキーム(javascript:/data: 等)はリンク化しない。"""
    label = m.group(1)
    href = html.unescape(m.group(2)).strip()
    sm = _SCHEME.match(href)
    if sm and sm.group(1).lower() not in _ALLOWED_SCHEMES:
        return label  # 不許可スキーム → プレーンテキスト（リンク無効化）
    return '<a href="%s">%s</a>' % (html.escape(href, quote=True), label)


def _inline(text):
    """インライン記法を HTML へ。先にエスケープし、code は二重エスケープ回避。"""
    # code span を placeholder で退避（中身はエスケープ）
    spans = []

    def _stash(m):
        spans.append(html.escape(m.group(1)))
        return "\x00%d\x00" % (len(spans) - 1)

    tmp = _INLINE_CODE.sub(_stash, text)
    tmp = html.escape(tmp)
    tmp = _BOLD.sub(r"<strong>\1</strong>", tmp)
    tmp = _ITALIC.sub(r"<em>\1</em>", tmp)
    # link: href のスキームを検証（javascript:/data: 等は不許可・ラベルのみ描画）
    tmp = _LINK.sub(_link_sub, tmp)
    # placeholder 復元
    tmp = re.sub(r"\x00(\d+)\x00", lambda m: "<code>%s</code>" % spans[int(m.group(1))], tmp)
    return tmp


def _render_table(rows):
    """GFM パイプ表（rows: 生行リスト, 2 行目は区切り）を HTML table へ。"""
    def cells(line):
        s = line.strip()
        if s.startswith("|"):
            s = s[1:]
        if s.endswith("|"):
            s = s[:-1]
        return [c.strip() for c in s.split("|")]

    head = cells(rows[0])
    body = [cells(r) for r in rows[2:]]
    out = ['<table>', '<thead><tr>']
    out += ['<th>%s</th>' % _inline(c) for c in head]
    out.append('</tr></thead><tbody>')
    for r in body:
        out.append('<tr>' + ''.join('<td>%s</td>' % _inline(c) for c in r) + '</tr>')
    out.append('</tbody></table>')
    return '\n'.join(out)


def _is_table_sep(line):
    return bool(re.match(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$", line))


def _disp_width(t):
    """日本語など全角を 2, ASCII を 1 として概算表示幅。"""
    w = 0
    for ch in t:
        w += 2 if ord(ch) > 0x2E7F else 1
    return w


def render_flow_svg(text):
    """簡易 flow 記法（`A -> B` / `A -> B : label`）を依存ゼロの自己完結 inline SVG へ。
    線形フロー/状態遷移図を矩形ノード + 矢印で縦方向に描く。外部 JS/CSS/画像なし。"""
    edges = []
    order = []
    seen = {}

    def node(name):
        name = name.strip()
        if name and name not in seen:
            seen[name] = len(order)
            order.append(name)
        return seen.get(name)

    for raw in text.splitlines():
        line = raw.strip()
        if not line or "->" not in line:
            continue
        label = ""
        body = line
        # ラベル分離: " : "（前後スペース）または最後の矢印後の " :" のみ。
        # ノード名内のコロン（Step 1: Init / http:// 等）との混同を防ぐ。
        if " : " in body:
            body, label = body.split(" : ", 1)
        else:
            parts_arrow = body.rsplit("->", 1)
            if len(parts_arrow) == 2 and " :" in parts_arrow[1]:
                body_pre, tail = parts_arrow
                tgt, label = tail.split(" :", 1)
                body = "%s->%s" % (body_pre, tgt)
        parts = [p for p in body.split("->")]
        # L-2: 連鎖（A->B->C）に末尾ラベルが付く場合、ラベルは最終エッジのみに付与する。
        for k in range(len(parts) - 1):
            a = node(parts[k]); b = node(parts[k + 1])
            if a is not None and b is not None:
                edge_label = label.strip() if k == len(parts) - 2 else ""
                edges.append((a, b, edge_label))

    if not order:
        return "<pre><code>%s</code></pre>" % html.escape(text)

    BW = max(140, max(_disp_width(n) for n in order) * 8 + 28)
    BH = 42
    GAP = 40
    LX = 24            # 左マージン（矢印 routing 用の右側余白も確保）
    RX = 150           # 右側 routing 用余白（距離依存 rx + 自己ループ対応）
    W = LX + BW + RX
    H = 24 + len(order) * (BH + GAP)

    def cx():
        return LX + BW / 2

    def box_y(idx):
        return 24 + idx * (BH + GAP)

    out = []
    out.append('<svg class="flow" viewBox="0 0 %d %d" width="%d" height="%d" '
               'xmlns="http://www.w3.org/2000/svg" role="img">' % (W, H, W, H))
    out.append('<defs><marker id="arr" markerWidth="10" markerHeight="10" refX="8" refY="3" '
               'orient="auto" markerUnits="strokeWidth">'
               '<path d="M0,0 L8,3 L0,6 z" fill="#57606a"/></marker></defs>')
    # 矢印（先に描いてノードを上に）
    for a, b, label in edges:
        ya = box_y(a) + BH
        yb = box_y(b)
        if b == a + 1:
            x = cx()
            out.append('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="#57606a" '
                       'stroke-width="1.5" marker-end="url(#arr)"/>' % (x, ya, x, yb - 2))
            if label:
                out.append('<text x="%g" y="%g" font-size="11" fill="#57606a">%s</text>'
                           % (x + 6, (ya + yb) / 2 + 3, html.escape(label)))
        elif b == a:
            # 自己ループ: 右側に丸いカーブ（y1==y2 で平坦化しないよう bezier）
            y = box_y(a) + BH / 2
            sx = LX + BW
            out.append('<path d="M%g,%g C%g,%g %g,%g %g,%g" fill="none" stroke="#8c959f" '
                       'stroke-width="1.3" stroke-dasharray="4 3" marker-end="url(#arr)"/>'
                       % (sx, y - 8, sx + 22, y - 14, sx + 22, y + 14, sx + 2, y + 8))
            if label:
                out.append('<text x="%g" y="%g" font-size="11" fill="#8c959f">%s</text>'
                           % (sx + 26, y + 4, html.escape(label)))
        else:
            # 非隣接: 右側を回す。複数エッジの重なり防止にノード間距離で rx を外へ。
            dist = abs(a - b)
            rx = LX + BW + 20 + min(50, dist * 10)
            y1 = box_y(a) + BH / 2
            y2 = box_y(b) + BH / 2
            sx = LX + BW
            out.append('<path d="M%g,%g H%g V%g H%g" fill="none" stroke="#8c959f" '
                       'stroke-width="1.3" stroke-dasharray="4 3" marker-end="url(#arr)"/>'
                       % (sx, y1, rx, y2, sx + 2))
            if label:
                out.append('<text x="%g" y="%g" font-size="11" fill="#8c959f">%s</text>'
                           % (rx + 4, (y1 + y2) / 2, html.escape(label)))
    # ノード
    for idx, name in enumerate(order):
        y = box_y(idx)
        out.append('<rect x="%g" y="%g" width="%g" height="%g" rx="8" '
                   'fill="#ddf4ff" stroke="#54aeff" stroke-width="1.5"/>'
                   % (LX, y, BW, BH))
        out.append('<text x="%g" y="%g" font-size="13" text-anchor="middle" '
                   'fill="#0a3069">%s</text>' % (cx(), y + BH / 2 + 4, html.escape(name)))
    out.append('</svg>')
    return '<div class="flow-wrap">%s</div>' % "".join(out)


def md_to_html(md, sid="", headings_out=None):
    """簡易 Markdown→HTML。sid 指定時は見出しに id を付与し headings_out に (level, text, id) を収集。"""
    lines = md.splitlines()
    out = []
    i = 0
    n = len(lines)
    in_code = False
    code_buf = []
    fence_lang = ""
    list_stack = []  # 'ul'/'ol'
    hcount = 0

    def close_lists():
        while list_stack:
            tag = list_stack.pop()
            out.append("</%s>" % ("ul" if tag == "checklist" else tag))

    while i < n:
        line = lines[i]

        # コードフェンス
        m = re.match(r"^```(.*)$", line)
        if m and not in_code:
            close_lists()
            in_code = True
            fence_lang = m.group(1).strip().lower()
            code_buf = []
            i += 1
            continue
        if in_code:
            if line.strip() == "```":
                if fence_lang == "flow":
                    out.append(render_flow_svg("\n".join(code_buf)))
                else:
                    out.append("<pre><code>%s</code></pre>" % html.escape("\n".join(code_buf)))
                in_code = False
                fence_lang = ""
            else:
                code_buf.append(line)
            i += 1
            continue

        # 水平線
        if re.match(r"^\s*---+\s*$", line):
            close_lists()
            out.append("<hr>")
            i += 1
            continue

        # 見出し
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            close_lists()
            lvl = len(m.group(1))
            raw = m.group(2)
            if sid:
                hid = "%s-h%d" % (sid, hcount); hcount += 1
                if headings_out is not None:
                    headings_out.append((lvl, raw, hid))
                out.append('<h%d id="%s">%s</h%d>' % (lvl, hid, _inline(raw), lvl))
            else:
                out.append("<h%d>%s</h%d>" % (lvl, _inline(raw), lvl))
            i += 1
            continue

        # 表（現在行が | を含み、次行が区切り）
        if "|" in line and i + 1 < n and _is_table_sep(lines[i + 1]):
            close_lists()
            tbl = [line, lines[i + 1]]
            j = i + 2
            while j < n and "|" in lines[j] and lines[j].strip():
                tbl.append(lines[j])
                j += 1
            out.append(_render_table(tbl))
            i = j
            continue

        # チェックボックス
        m = _CHECK.match(line)
        if m:
            if not list_stack or list_stack[-1] != "checklist":
                close_lists()
                out.append("<ul class='checklist'>")
                list_stack.append("checklist")
            checked = "checked" if m.group(2).lower() == "x" else ""
            out.append(
                "<li><input type='checkbox' disabled %s> %s</li>"
                % (checked, _inline(m.group(3)))
            )
            i += 1
            continue

        # 箇条書き
        m = re.match(r"^\s*[-*+]\s+(.*)$", line)
        if m:
            if not list_stack or list_stack[-1] != "ul":
                close_lists()
                out.append("<ul>")
                list_stack.append("ul")
            out.append("<li>%s</li>" % _inline(m.group(1)))
            i += 1
            continue

        # 番号リスト
        m = re.match(r"^\s*\d+\.\s+(.*)$", line)
        if m:
            if not list_stack or list_stack[-1] != "ol":
                close_lists()
                out.append("<ol>")
                list_stack.append("ol")
            out.append("<li>%s</li>" % _inline(m.group(1)))
            i += 1
            continue

        # 引用
        m = re.match(r"^>\s?(.*)$", line)
        if m:
            close_lists()
            out.append("<blockquote>%s</blockquote>" % _inline(m.group(1)))
            i += 1
            continue

        # 空行
        if not line.strip():
            close_lists()
            i += 1
            continue

        # 段落
        close_lists()
        out.append("<p>%s</p>" % _inline(line))
        i += 1

    if in_code:  # 未閉フェンス救済
        out.append("<pre><code>%s</code></pre>" % html.escape("\n".join(code_buf)))
    close_lists()
    return "\n".join(out)


CSS = """
:root{--fg:#1f2328;--muted:#656d76;--bd:#d0d7de;--bg:#fff;--accent:#0969da;--code:#f6f8fa}
*{box-sizing:border-box}
body{margin:0;font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;color:var(--fg);background:#fafbfc}
.wrap{max-width:980px;margin:0 auto;padding:24px}
header h1{margin:0 0 4px}
.meta{color:var(--muted);font-size:14px;margin-bottom:16px}
nav.toc{position:sticky;top:0;background:var(--bg);border:1px solid var(--bd);border-radius:8px;padding:12px 16px;margin-bottom:24px}
nav.toc strong{display:block;margin-bottom:6px}
nav.toc a{display:inline-block;margin:2px 10px 2px 0;color:var(--accent);text-decoration:none}
nav.toc a:hover{text-decoration:underline}
section.doc{background:var(--bg);border:1px solid var(--bd);border-radius:8px;padding:8px 24px 24px;margin-bottom:28px}
section.doc>h2.doc-title{border-bottom:2px solid var(--bd);padding-bottom:8px}
h1,h2,h3,h4{line-height:1.3}
table{border-collapse:collapse;width:100%;margin:12px 0;font-size:14px}
th,td{border:1px solid var(--bd);padding:6px 10px;text-align:left;vertical-align:top}
th{background:var(--code)}
code{background:var(--code);padding:.15em .35em;border-radius:4px;font-size:85%}
pre{background:var(--code);padding:12px;border-radius:8px;overflow:auto}
pre code{background:none;padding:0}
blockquote{margin:8px 0;padding:0 12px;color:var(--muted);border-left:3px solid var(--bd)}
ul.checklist{list-style:none;padding-left:18px}
ul.checklist li{margin:2px 0}
hr{border:none;border-top:1px solid var(--bd);margin:16px 0}
a{color:var(--accent)}
.missing{color:var(--muted);font-style:italic}
img,svg{max-width:100%}
.flow-wrap{margin:12px 0;padding:8px;background:var(--bg);border:1px solid var(--bd);border-radius:8px;overflow:auto}
svg.flow text{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
nav.perspectives{background:#fff8e6;border:1px solid #f0d98c;border-radius:8px;padding:12px 16px;margin-bottom:24px}
nav.perspectives strong{display:block;margin-bottom:6px}
nav.perspectives a{display:inline-block;margin:2px 10px 2px 0;color:var(--accent);text-decoration:none;font-weight:600}
nav.perspectives a:hover{text-decoration:underline}
nav.perspectives .missing{margin:2px 10px 2px 0;display:inline-block}
"""


KEY_PERSPECTIVES = [
    ("Goal/目的", ["goal", "目的", "ゴール"]),
    ("Scope/対象", ["scope", "対象", "non-goal", "非対象"]),
    ("Risk", ["risk", "リスク"]),
    ("Test/検証", ["test", "テスト", "verification", "検証"]),
    ("Stop/Replan", ["stop condition", "replan", "停止", "差し戻し", "stop-work"]),
    ("承認/Approval", ["approval", "承認", "受入", "mode判定"]),
]


def build_perspective_nav(all_headings):
    items = []
    for label, kws in KEY_PERSPECTIVES:
        hit = None
        for _lvl, text, hid in all_headings:
            low = text.lower()
            if any(re.search(r'(?<![a-zA-Z])' + re.escape(k), low) for k in kws):
                hit = hid
                break
        if hit:
            items.append('<a href="#%s">%s</a>' % (hit, html.escape(label)))
        else:
            items.append('<span class="missing">%s（なし）</span>' % html.escape(label))
    return '<nav class="perspectives"><strong>承認観点ナビ</strong>' + "".join(items) + "</nav>"


def build_html(task_id, sections, perspective_nav=""):
    toc = "".join('<a href="#%s">%s</a>' % (sid, html.escape(title)) for sid, title, _ in sections)
    body = []
    for sid, title, content in sections:
        body.append('<section class="doc" id="%s">' % sid)
        body.append('<h2 class="doc-title">%s</h2>' % html.escape(title))
        body.append(content)
        body.append('</section>')
    return """<!DOCTYPE html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>%s — C-3 Review</title>
<style>%s</style></head>
<body><div class="wrap">
<header><h1>%s</h1><div class="meta">C-3 レビュー集約ビュー（self-contained）</div></header>
<nav class="toc"><strong>目次</strong>%s</nav>
%s
%s
</div></body></html>
""" % (html.escape(task_id), CSS, html.escape(task_id), toc, perspective_nav, "\n".join(body))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--work-dir", default=None)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    if not re.match(r"^TASK-[0-9]{4}$", args.task):
        sys.stderr.write("error: invalid task id: %s (expected TASK-XXXX)\n" % args.task)
        return 2

    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    work_dir = args.work_dir or os.path.join(repo, "docs", "working", args.task)
    if not os.path.isdir(work_dir):
        sys.stderr.write("error: TASK directory not found: %s\n" % work_dir)
        return 1

    sections = []
    all_headings = []
    found = 0
    for fname, title in C3_ARTIFACTS:
        path = os.path.join(work_dir, fname)
        sid = re.sub(r"[^a-z0-9]+", "-", fname.lower())
        label = "%s (%s)" % (title, fname)
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as f:
                hd = []
                rendered = md_to_html(f.read(), sid, hd)
                sections.append((sid, label, rendered))
                all_headings.extend(hd)
            found += 1
    if found == 0:
        sys.stderr.write("error: no C-3 artifacts found under %s\n" % work_dir)
        return 1

    perspective_nav = build_perspective_nav(all_headings)
    out = args.out or os.path.join(work_dir, "%s-c3-review.html" % args.task)
    with open(out, "w", encoding="utf-8") as f:
        f.write(build_html(args.task, sections, perspective_nav))
    sys.stdout.write("rendered %d artifact(s) -> %s\n" % (found, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
