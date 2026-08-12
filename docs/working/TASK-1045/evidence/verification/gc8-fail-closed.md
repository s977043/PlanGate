# GC-8: 正規化ヘルパの fail-closed — 検出力の実証（A-5a / R-002 / R-009 / SC-9）

- 実行日: 2026-08-13
- payload: `printf x > <TOKEN>`（真の書き込み。**必ず block されなければならない**）

## 実装した 3 要件

| 要件 | 実装 | 位置 |
|---|---|---|
| **(i)** fail-closed フォールバック | `_wc_n=$(_strip_nonwrite_redirects "$_wc") \|\| _wc_n="$_wc"` | `_has_write_intent()` 内（`# t1045-redirect-normalize`） |
| **(ii)** `command -v sed`（`jq` と同契約） | `command -v sed >/dev/null 2>&1 \|\| _parse_unknown "sed not available"` | **`_parse_unknown()` 定義の後・`# --- 1) target:` の直前**（R-010） |
| **(iii)** `LC_ALL=C` 固定 | 正規化パイプライン行に付与 | `_strip_nonwrite_redirects()` 内 |

## 検出力マトリクス（実走）

2 種の PATH を用意して各 build を起動:
- **sed-absent**: `cat` / `grep` / `sh` / `jq` のみ symlink（`sed` 不在）
- **sed-fails**: 上記 + `#!/bin/sh` / `exit 1` の `sed` シム（存在するが必ず失敗）

```text
  build                      mode           rc    sed-not-avail  writes-token  parse-unknown
  no-i.sh ((i) 欠落)         sed-absent     2     YES            no            YES
  no-i.sh ((i) 欠落)         sed-fails      0     no             no            no      ← FAIL-OPEN
  check-approval-token-write sed-absent     2     YES            no            YES
  check-approval-token-write sed-fails      2     no             YES           no
```

**plan の R-009 表を独立に再現した。**

| build | TC-22（sed 不在） | TC-22b（sed 失敗） |
|---|---|---|
| (i)+(ii)+(iii) 全部 = 本実装 | rc=2 → **PASS** | rc=2 → **PASS** |
| **(ii)+(iii) のみ（(i) 欠落）** | rc=2 → **PASS してしまう（穴を検出できない）** | **rc=0 = FAIL-OPEN → TC-22b が FAIL して検出** |

→ **`T1045-TC-22` 単独では (i) の欠落を素通しする**ことが実測で確定。
**`T1045-TC-22b` が (i) の検出力を担う唯一の TC** であり、
その二重条件（`rc==2` かつ `writes token path` を含み **かつ `parse-unknown` を含まない**）は
偽 PASS 防止のため必須である（`ta-25:118` の `T1023-TC-02b` と同型）。

## R-010（(ii) の挿入位置）の確認

`command -v sed` は `_parse_unknown()` 定義（`:76-88` 相当）の **後**、
`# --- 1) target:` の **直前** に置いた。
関数定義より前に置いた場合の失敗様式（`command not found` → `rc=127` → 非 block、
かつ `T1023-TC-05` の巻き添え FAIL）は発生していない
（実測: `T1023-TC-05` は PASS を維持、`T1045-TC-22` は `rc=2` + `sed not available`）。

## スイート上の機械担保

- `T1045-TC-22`（通常群）: `sed` 不在 PATH → `rc==2` かつ stderr に `sed not available`
- `T1045-TC-22b`（通常群）: `sed` 失敗シム PATH → `rc==2` かつ `Bash command writes token path` を含み、
  **`parse-unknown` を含まない**
- 静的検査: `grep -c 'LC_ALL=C' scripts/check-approval-token-write.sh` ≥ 1 かつ
  正規化パイプライン行に付与されていること（R-016）→ 実測 2 件（コメント 1 + パイプライン行 1）
