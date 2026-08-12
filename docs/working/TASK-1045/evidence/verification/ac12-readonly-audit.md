# A-12: AC-12 — 起点そのものの解消を実測（plan Step 7 / T1045-TC-17）

- 実行日: 2026-08-13 / 修正後 guard（`feat/1045-exec`）

`<TOKEN>` を対象とする read-only 監査コマンド（#1023 AC-09 相当）が guard を通過することを実測。

| # | コマンド | 修正前 rc | 修正後 rc |
|---|---|---:|---:|
| 1 | `find docs/working -name c3.json -type f 2>/dev/null` | 2 | **0** |
| 2 | `grep -l c3_status <TOKEN> 2>/dev/null` | 2 | **0** |
| 3 | `jq -r .c3_status <TOKEN> 2>/dev/null` | 2 | **0** |
| 4 | `git log --oneline -- <TOKEN> 2>/dev/null` | 2 | **0** |
| 5 | `cat <MAINT> 2>/dev/null` | 2 | **0** |
| 6 | `cat <TOKEN> 2>&1` | 2 | **0** |
| 7 | `cat <TOKEN> >&2` | 2 | **0** |
| 8 | `cat <TOKEN> 3>&-` | 2 | **0** |
| 9 | `ls <TOKEN> 1>/dev/null` | 2 | **0** |
| 10 | `cat <TOKEN> 2>>/dev/null` | 2 | **0** |
| 11 | `grep -c '<TOKEN>' .gitignore 2>/dev/null` | 2 | **0** |

**11 形すべて exit 0。AC-12 の起点（読み取り監査が止まる）は解消した。**

## 解消しなかった 1 件（GC-2 の宣言済み取りこぼし・handoff の既知課題）

| コマンド | 修正前 | 修正後 | 理由 |
|---|---:|---:|---|
| `python3 -c "print('<TOKEN> -> ok')"` | 2 | **2** | 文字列リテラル中の `->` の `>` はリダイレクトと区別できない。plan **GC-2**（完全なシェル構文解析を行わない）で **block 維持＝誤検知として扱わない**と宣言済み。固定 TC は `T1045-TC-19` |

同様に `&>/dev/null` 付きの読み取りも **U-2 の裁定により block 維持**（固定 TC = `T1045-TC-14 (3)`）。
両者は handoff の既知課題に記載する。

スイート上の機械担保: `T1045-TC-17`（通常群、上記 1〜5 をループ assert）
+ focused 群の `T1045-TC-01` / `TC-02` / `TC-03` / `TC-20`。
