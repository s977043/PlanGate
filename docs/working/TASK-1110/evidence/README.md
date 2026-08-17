# TASK-1110 evidence

`TOKEN` = 架空の承認トークンパス（`docs/working/TASK-0001/approvals/c3.json`）。
実 `approvals/` には一切触れていない。

## ファイル

| ファイル | 内容 |
|----------|------|
| `gen_cases.py` | 18 ケースのコマンド文字列生成（base64 で `cases.txt` を出力） |
| `probe.sh` | PreToolUse payload を組み立てて EH-13 を起動し rc を記録する |
| `probe-before.log` | **修正前**（`HEAD` = `7d91f7b` 時点の guard）の 18 ケース実測 |
| `probe-after.log` | **修正後**の 18 ケース実測 |
| `ta25-red.log` | TC 追加直後（実装前）の TA-25 実行 = RED（3 FAIL） |
| `ta25-after.log` | 実装後の TA-25 個別フル実行 = 0 failed（変異 11 種すべて killed） |
| `mutation-M1.log` | M-1（相関を OR へ回帰）の 適用→FAIL→復元→PASS |
| `mutation-M2.log` | M-2（相関を常時 false）の 適用→FAIL→復元→PASS |

## A〜E（issue #1110 本文の 5 ケース）

| # | コマンド | 期待 | 修正前 | 修正後 |
|---|----------|------|--------|--------|
| A | `git commit -m 'docs: TOKEN' > /tmp/log.txt` | rc=0 | **rc=2**（誤検出） | **rc=0** ✅ |
| B | `git commit -m 'docs: TOKEN handling'` | rc=0 | rc=0 | rc=0 ✅ |
| C | `git commit -m 'docs: approval token' > /tmp/log.txt` | rc=0 | rc=0 | rc=0 ✅ |
| D | `echo x > TOKEN` | rc=2 | rc=2 | rc=2 ✅ |
| E | `cat TOKEN` | rc=0 | rc=0 | rc=0 ✅ |

## 追加 13 ケース（境界 / fail-closed）

| # | コマンド | 期待 | 修正前 | 修正後 |
|---|----------|------|--------|--------|
| 6 | `echo x >> TOKEN` | rc=2 | rc=2 | rc=2 ✅ |
| 7 | `echo x > ./TOKEN` | rc=2 | rc=2 | rc=2 ✅ |
| 8 | `echo 'TOKEN' > /tmp/note.txt` | rc=0 | **rc=2**（誤検出） | **rc=0** ✅ |
| 9 | `echo x > "TOKEN"` | rc=2 | rc=2 | rc=2 ✅ |
| 10 | `echo x > .../maintenance.json` | rc=2 | rc=2 | rc=2 ✅ |
| 11 | `git commit -m 'docs: TOKEN' > /dev/null` | rc=0 | rc=0 | rc=0 ✅ |
| 12 | `cp /tmp/x TOKEN` | rc=2 | rc=2（copy-like） | rc=2（copy-like）✅ |
| 13 | `echo hi > /tmp/a.txt; echo x > TOKEN` | rc=2 | rc=2 | rc=2 ✅ |
| 14 | `echo x > .../TASK-0001/../TASK-0001/approvals/c3.json` | rc=2 | rc=2 | rc=2 ✅ |
| 15 | `cat > TOKEN <<EOF …`（heredoc） | rc=2 | rc=2 | rc=2 ✅ |
| 16 | `git commit -m 'docs: TOKEN' 2>&1` | rc=0 | rc=0 | rc=0 ✅ |
| 17 | `echo x >   TOKEN`（空白 3 個） | rc=2 | rc=2 | rc=2 ✅ |
| 18 | `echo x > $(cat /tmp/p) # TOKEN` | rc=2 | rc=2 | rc=2 ✅（fail-closed） |

修正で rc が変わったのは **#1（A）と #8 のみ**。いずれもリダイレクト先が
トークンパスに解決されない誤検出であり、真の陽性は 1 件も落ちていない。

## 変異注入（call site を壊す）

| 変異 | 内容 | 期待 kill | 結果 |
|------|------|-----------|------|
| M-1 | `# t1110-redirect-correlate` の行を `_redirect_tok=1` 固定（= 元の OR 判定へ回帰） | T1110-TC-01 | **KILLED**（T1110-TC-01/02/05 が FAIL） |
| M-2 | 同じ行を `_redirect_tok=0` 固定（= 真の陽性を落とす） | T1045-TC-04 | **KILLED**（T1023-TC-03 / T1045-TC-04/05/06 / T1110-TC-03/04/05 が FAIL） |

**空振り（適用しても PASS のまま）は 0 件。** 既存の変異 9 種（T1023-TC-15〜17e /
T1045-TC-09 / T1045-TC-10）も引き続きすべて killed（`ta25-after.log`）。
とくに T1045-TC-09（正規化 no-op 化 → T1045-TC-01 が FAIL）が生きていることは、
相関判定を導入しても `_strip_nonwrite_redirects` が load-bearing のままである
ことの機械的な担保になっている。

## 実行環境

- `sh tests/extras/ta-25-approval-token-guard.sh` → **exit 0 / 77 passed, 0 failed**
- BSD sed（macOS 既定）と GNU sed（`gsed` を `sed` として PATH 先頭に配置）の
  両方で TA-25 = 0 failed を確認
- **フルスイート `tests/run-tests.sh` は実行していない**（ta-61 が入れ子で
  full-suite を再実行するため、並走ワーカーの相互妨害を避ける指示による）
