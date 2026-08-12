# A-1b: BSD / GNU `sed` 等価性の先行検証（plan Step 1b / UV-1 / RT-1）

- 実行日: 2026-08-13
- BSD: `/usr/bin/sed`（macOS 標準）
- GNU: `/opt/homebrew/bin/gsed` — **GNU sed 4.10**（本検証のためにローカル導入。リポジトリ変更なし）
- 実験条件: **`LC_ALL=C` 固定**（plan GC-6 / R-007）
- 対象: `_strip_nonwrite_redirects()` の正規化パイプラインのみ（`scripts/` は未変更のスクラッチ）

## 正規化パイプライン（POSIX BRE のみ / GNU 拡張 `\|` `\+` `\b` 不使用）

```sh
printf '%s' "$1" | LC_ALL=C sed \
  -e 's|&>|\&>#|g' \
  -e 's|[0-9]*>&[0-9][0-9]*||g' \
  -e 's|[0-9]*>&-||g' \
  -e 's|[0-9]*>>*[[:space:]]*/dev/null$||' \
  -e 's|[0-9]*>>*[[:space:]]*/dev/null\([^A-Za-z0-9_./-]\)|\1|g'
```

## 結果

| 方言 | ケース数 | MISMATCH | 判定 |
|---|---:|---:|---|
| BSD `sed` | 29 | 0 | PASS |
| GNU `sed` 4.10 | 29 | 0 | PASS |

**両方言の出力は `diff` で完全一致（byte identical）**。正規化後文字列・分類ともに差異なし。

```text
$ diff bsd.out gnu.out && echo IDENTICAL
IDENTICAL
TOTAL=29 MISMATCH=0   (BSD)
TOTAL=29 MISMATCH=0   (GNU)
```

→ **`RT-1` は発火せず**。plan の中核前提（GC-6: POSIX 範囲の単一実装が両方言で等価）は成立。
plan の想定は 26 ケースだったが、実行したのは誤検知 14 + 退行防止 15 の **29 ケース**
（plan の 26 ケース集合を包含する上位集合）。

### 内訳（抜粋・分類は「残存 `>` を見る判定」の結果）

| ケース | 期待 | BSD | GNU |
|---|---|---|---|
| `2>/dev/null` / `2>&1` / `>&2` / `3>&-` / `2>>/dev/null` / `1>/dev/null` | nowrite | ✅ | ✅ |
| `>/dev/null 2>&1` / `2>/dev/null \| head` / `2>/dev/null; echo` / `(… 2>/dev/null)` | nowrite | ✅ | ✅ |
| `ls > /dev/null ; cp TOK /tmp/x` / `cp` / `tee` / `mv` 単独 | nowrite（`>` 判定として。**copy-like ルールが別途 block**） | ✅ | ✅ |
| `> TOK` / `>> TOK` / `1> TOK` / `&& echo hi > /tmp/other.txt` | write | ✅ | ✅ |
| `> /dev/stdout` / `> /dev/stderr` / `> /dev/fd/3` | write | ✅ | ✅ |
| `2>/dev/nullX` / `> /dev/null/../TOK` | write | ✅ | ✅ |
| `&> /tmp/o` / `&>> /tmp/o` / `&> /dev/null` | write | ✅ | ✅ |
| `>& /tmp/o` / `echo 'a > b' TOK` / `exec 3> TOK` | write | ✅ | ✅ |

## locale 依存の失敗（GC-8 (iii) の根拠）

不正バイト列（`abc\303\050def`）を BSD `sed` へ与えたとき:

```text
LC_ALL=en_US.UTF-8 → sed: RE error: illegal byte sequence   rc=1
LC_ALL=C           → rc=0
```

→ **`LC_ALL=C` 固定は正規化失敗の発生確率を下げる緩和**。ただし代替ではなく、
GC-8 の (i) fail-closed フォールバック / (ii) `command -v sed` はいずれも必須のまま実装した。

## CI（Linux / GNU）について

CI 実行は PR 作成後にしか回らない（本 PBI は PR を作らない指示）。
ただし **GNU sed 4.10 での実行結果を本ローカル環境で取得済み**であり、
`sed` 方言差に起因する UV-1 のリスクは実測で退役している。
残る CI 固有の差分（GNU `grep` / Linux `/bin/sh` = dash）は C-4 前の CI 実行で確認する。
