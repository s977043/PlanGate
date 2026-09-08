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

__doc__ = """harness_version.corpus_hash の producer（#1299）。

契約正本: docs/workflows/ai-loop/run-evidence-contract.md §4-1。

## なぜ producer が要るのか

`corpus_hash` は run_evidence.py では**注入値**として受け取り、形式
（sha256: + 64hex）と run 中不変（AC-12 / fail-closed）だけを検査する。
値を**何から計算するか**は文書定義しか無く、実装が存在しなかった。その結果
対象範囲を誰も再現できず、scripts/hooks/**（enforcement 層）が範囲外である
ことも機械的には現れなかった（#1299）。本モジュールはその定義を実行可能な
1 本の実装に固定する。

## scope の 2 系統（carve-out と corpus_hash を分離する）

docs/workflows/ai-loop/rollout-policy.md §2 の carve-out (1)(2)(3) は
**AI が自走で触ってよいか**（承認境界）の定義であり、corpus_hash は
**run の同一性を何で判定するか**（検証範囲）である。目的が違うため同じ集合
である必然性が無い。#1299 以前は前者を後者に流用していたため、**最も強制力の
ある層（hook）だけが検証の外**にあった。

- carve-out  : (1)(2)(3) 自走禁止の判定基盤
- enforcement: run 中に実際に block / allow を決める実体（hook 本体・
               他 Provider の配線・CLI ゲート・schema 契約）
- full       : 上記の和集合。**corpus_hash の既定値**

含めないものと理由は EXCLUSIONS を参照（非対称を黙って残さない）。

## 残存脅威モデル（完全性を主張しない）

守る: リポジトリに追跡される enforcement 実体の内容変化。
守らない: (a) untracked な実行時配線（.claude/settings.json）の差し替え、
(b) ランタイムに実際に登録されたか（hooks/list 相当）、(c) CI 側
（.github/workflows/**）の変化、(d) 環境変数・PATH による実行系の差し替え。
(a)(b) は V2 HarnessManifest の components[].registered が担当する
（docs/ai/ai-loop-v2/harness-manifest.md）。本 hash は多層防御の 1 層である。

## 使い方

    python3 scripts/ai-loop/corpus_hash.py                # sha256:... を 1 行出力
    python3 scripts/ai-loop/corpus_hash.py --scope carve-out
    python3 scripts/ai-loop/corpus_hash.py --explain      # 対象と per-file digest

exit code: 0=算出成功 / 2=対象が 1 件も展開されなかった（fail-closed）。
"""

import argparse
import glob as _glob
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from c3_contract import canonical_hash  # noqa: E402

#: scope 名 -> glob パターン群。末尾 "/**" はディレクトリ配下の全ファイル再帰。
SCOPES = {
    # (1)(2)(3): rollout-policy.md §2 判定基盤 carve-out（自走禁止）。
    "carve-out": (
        "scripts/ai-loop/**",
        "docs/workflows/ai-loop/**",
        "docs/ai/ai-loop/**",
        ".agents/skills/ai-loop-cycle/**",
        ".claude/skills/ai-loop-cycle/**",
    ),
    # (4) enforcement 層（#1299）: run 中に Gate / Verifier の判定を実際に変える実体。
    "enforcement": (
        "scripts/hooks/**",
        "scripts/check-approval-token-write.sh",
        ".codex/hooks.json",
        ".codex/hooks/**",
        ".cursor/hooks.json",
        ".cursor/hooks/**",
        "bin/plangate",
        "schemas/*.schema.json",
    ),
}

#: **意図的に含めないもの**と理由（含まれないものも明示する / #1299 AC）。
EXCLUSIONS = {
    ".claude/settings.json": (
        "実行時 wiring の実体だが untracked（端末ローカル）であり、リポジトリ内容から"
        "再現できない。含めると同じ commit でも corpus_hash が端末ごとに変わり run 間"
        "比較が成立しない。配線が実際に登録されたかは V2 HarnessManifest の"
        " components[].registered が持つ。残存ギャップ: 配線だけを差し替えた drift は"
        "本 hash では検出できない。"),
    ".claude/settings.example.json": (
        "契約の参照値であって実行時配線ではない。実体との drift は settings-drift CI"
        "（CI-owned）が担当する。"),
    ".github/workflows/**": (
        "CI-owned の enforcement であり harness プロセス内では発火しない。run 中の変化は"
        " ci_outcomes 側に現れ、改変自体は branch protection と C-4 が抑止する。"
        "churn も大きく run 同一性の指標としてノイズになる。"),
    ".claude/rules/**, .claude/agents/**, .claude/commands/**, AGENTS.md, CLAUDE.md": (
        "規範層（HO ではあるが理由は承認境界の保護）。判定を実行するのは hook / CLI 側"
        "であり、run 同一性の根拠は実体側に置く。"),
}

_DEFAULT_SCOPE = "full"


def _iter_files(root, pattern):
    """1 パターンを repo 相対パスの sorted list へ展開する（通常ファイルのみ）。"""
    out = []
    if pattern.endswith("/**"):
        base = os.path.join(root, pattern[:-3])
        if os.path.isdir(base):
            for dirpath, dirnames, filenames in os.walk(base):
                dirnames.sort()
                for name in sorted(filenames):
                    full = os.path.join(dirpath, name)
                    if os.path.isfile(full) and not os.path.islink(full):
                        out.append(os.path.relpath(full, root))
    elif "*" in pattern:
        for full in _glob.glob(os.path.join(root, pattern)):
            if os.path.isfile(full) and not os.path.islink(full):
                out.append(os.path.relpath(full, root))
    else:
        full = os.path.join(root, pattern)
        if os.path.isfile(full) and not os.path.islink(full):
            out.append(os.path.relpath(full, root))
    return sorted(out)


def patterns_for(scope):
    if scope == "full":
        return tuple(SCOPES["carve-out"]) + tuple(SCOPES["enforcement"])
    if scope not in SCOPES:
        raise KeyError(scope)
    return tuple(SCOPES[scope])


def collect(root, scope=_DEFAULT_SCOPE):
    """{repo 相対パス: sha256:<file digest>} を返す（決定論・path 昇順）。"""
    digests = {}
    for pattern in patterns_for(scope):
        for rel in _iter_files(root, pattern):
            with open(os.path.join(root, rel), "rb") as fh:
                digests[rel] = "sha256:" + hashlib.sha256(fh.read()).hexdigest()
    return digests


def compute(root, scope=_DEFAULT_SCOPE):
    """corpus_hash（sha256: + 64hex）を返す。対象 0 件は例外（fail-closed）。

    空 glob を 0 件のまま通すと「常に同じ hash」になり検査が黙って空振りする
    （検査には positive control が要る）。ここで必ず落とす。
    """
    digests = collect(root, scope)
    if not digests:
        raise ValueError(
            "corpus 対象が 0 件（scope=%s / root=%s）。glob が空振りしている"
            % (scope, root))
    return canonical_hash(digests)


def main(argv=None):
    ap = argparse.ArgumentParser(description="harness_version.corpus_hash を算出する")
    ap.add_argument("--root", default=None, help="repo root（既定: 本スクリプトの ../..）")
    ap.add_argument("--scope", default=_DEFAULT_SCOPE,
                    choices=("full", "carve-out", "enforcement"),
                    help="既定 full = carve-out + enforcement（契約値）")
    ap.add_argument("--explain", action="store_true",
                    help="対象ファイルと per-file digest を JSON 出力する")
    ap.add_argument("--list-exclusions", action="store_true",
                    help="意図的に含めないものと理由を JSON 出力する")
    opts = ap.parse_args(argv)

    if opts.list_exclusions:
        print(json.dumps(EXCLUSIONS, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    root = opts.root or os.path.dirname(os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))))
    try:
        digests = collect(root, opts.scope)
        if not digests:
            raise ValueError(
                "corpus 対象が 0 件（scope=%s / root=%s）。glob が空振りしている"
                % (opts.scope, root))
    except ValueError as exc:
        sys.stderr.write("ERROR: %s\n" % exc)
        return 2

    value = canonical_hash(digests)
    if opts.explain:
        print(json.dumps({
            "scope": opts.scope,
            "patterns": list(patterns_for(opts.scope)),
            "file_count": len(digests),
            "corpus_hash": value,
            "files": digests,
        }, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(value)
    return 0


if __name__ == "__main__":
    sys.exit(main())
