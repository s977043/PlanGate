# テストケース定義 — TASK-1110 (#1110)

`TOKEN` = `docs/working/TASK-0001/approvals/c3.json`（TA-25 既存の架空 fixture パス。
実 approvals には触れない）。すべて `tool_name=Bash` / `hook_event_name=PreToolUse` の
PreToolUse payload を stdin へ与えて `scripts/check-approval-token-write.sh` を起動する。

## 受入基準 → テストケース マッピング

| AC | 内容 | TC |
|----|------|----|
| AC-1 | トークン名 + 無関係リダイレクト → rc=0 | T1110-TC-01, T1110-TC-02, T1110-TC-09 |
| AC-2 | 真の陽性は block 維持 | T1110-TC-03, **T1110-TC-06, T1110-TC-07**（+ 既存 T1045-TC-04/05/06） |
| AC-3 | 判定不能は fail-closed（切り詰めクラスを含む） | T1110-TC-04, **T1110-TC-06** |
| AC-3b | レーン間で判定が一致する | **T1110-TC-08** |
| AC-4 | BLOCK メッセージに一致した先を出す | T1110-TC-05, **T1110-TC-10** |
| AC-5 | 既存 TA-25 が PASS | 既存 TC 全体（個別実行 rc=0） |
| AC-6 | 変異が実 TC の FAIL で kill される（レーン内部を含む） | M-1〜M-6（下表） |

## テストケース一覧

### T1110-TC-01: 誤検出解消（負の対照 / AC-1）

| 入力コマンド | 期待 | 意図 |
|--------------|------|------|
| `git commit -m 'docs: TOKEN' > /tmp/log.txt` | **rc=0** | ケース A。トークン名 + 無関係リダイレクト |
| `git commit -m 'docs: TOKEN handling'` | rc=0 | ケース B。リダイレクトなし（回帰確認） |
| `git commit -m 'docs: approval token' > /tmp/log.txt` | rc=0 | ケース C。トークン名なし + リダイレクト |
| `cat TOKEN` | rc=0 | ケース E。読み取りのみ |

- 種別: Integration（hook 実起動）/ 自動化: 可

### T1110-TC-02: トークン名を書き込む先が別ファイル（負の対照 / AC-1）

| 入力コマンド | 期待 |
|--------------|------|
| `echo 'TOKEN' > /tmp/note.txt` | **rc=0** |

- 意図: 「トークンパス文字列を**内容として**別ファイルへ書く」は block しない。
  `file_path` レーンの M-3（MultiEdit は内容を見ない）と同じ思想。
- 種別: Integration / 自動化: 可

### T1110-TC-03: 真の陽性の維持（AC-2）

| 入力コマンド | 期待 | 観点 |
|--------------|------|------|
| `echo x > ./TOKEN` | **rc=2** | `./` 前置の正規化漏れを作らない（#1101 同型） |
| `echo x > "TOKEN"` | **rc=2** | 引用付きの先 |
| `echo x >   TOKEN` | **rc=2** | 空白の詰め方に依存しない |
| `echo x > docs/working/TASK-0001/../TASK-0001/approvals/c3.json` | **rc=2** | `..` 混在 |
| `echo hi > /tmp/a.txt; echo x > TOKEN` | **rc=2** | 複文の後段だけがトークン宛 |
| `cat > TOKEN <<EOF\n{}\nEOF` | **rc=2** | heredoc（複数行）で崩れない |
| `echo x > docs/working/_maintenance/maintenance.json` | **rc=2** | maintenance トークン |

- 種別: Integration / 自動化: 可

### T1110-TC-04: 判定不能は block 側（fail-closed / AC-3）

| 入力コマンド | 期待 | 判定不能の理由 |
|--------------|------|----------------|
| `echo x > $(cat /tmp/p) # TOKEN` | **rc=2** | コマンド置換で先が静的に解決できない |
| `echo x > $OUT # TOKEN` | **rc=2** | 変数展開 |
| `echo x > /tmp/*.json # TOKEN` | **rc=2** | glob |
| `echo x >   # TOKEN` | **rc=2** | 先が空（コメント境界で語が取れない） |
| `cat TOKEN > /dev/stdout` | **rc=2** | 正規化後に残った擬似デバイス（既存 T1045-TC-11 と同値） |

- 種別: Integration / 自動化: 可
- 注: `>` の先が `/dev/null` の場合は `_strip_nonwrite_redirects` が除去済みのため
  この段には到達しない（既存 T1045-TC-01 が担保）。

### T1110-TC-05: BLOCK メッセージ（AC-4）

- 入力: `echo x > TOKEN`
- 期待: rc=2 かつ stderr が `rule=file-redirect` と
  `redirect_target=docs/working/TASK-0001/approvals/c3.json` を含む
- 種別: Integration / 自動化: 可

### T1110-TC-06: 切り詰めクラスは block（AC-2 / AC-3 / V-3 R-001）

終端文字を含むトークンパスを引用・退避して書いた先。語の切り詰めで
**非トークンの前半分に化けて通過してはならない**。`TASK` セグメントに終端文字を 1 つ埋める。

| 入力コマンド（先の形） | 期待 |
|------------------------|------|
| `echo x > 'docs/working/TASK 0001/approvals/c3.json'`（空白） | **rc=2** |
| 同上を `"` で囲んだもの | **rc=2** |
| TAB / `;` / `&` / `\|` / `(` / `)` / `<` / `#` を埋めた引用済みパス | **各 rc=2** |
| `echo x > docs/working/TASK\ 0001/approvals/c3.json`（バックスラッシュ退避） | **rc=2** |

- 種別: Integration / 自動化: 可
- **修正前（`f922442`）はすべて rc=0**（真の陽性喪失）。main は全て rc=2。

### T1110-TC-07: 語中の `#` は終端でない（AC-2 / V-3 R-001）

- 入力: `echo x > docs/working/TASK#0001/approvals/c3.json`（引用なし・退避なし）
- 期待: **rc=2**
- 意図: `#` を終端文字に含めると、**退避不要で書ける形**を取りこぼす。
  語頭の `#` はコメント開始なので「先が無い」= block（T1110-TC-04 の空ケース）。

### T1110-TC-08: レーン間で判定が一致する（AC-3b / V-3 R-001）

同一の空白入りトークンパス `"/Users/u/My Drive/pg/TOKEN"` に対して:

| レーン | 期待 |
|--------|------|
| `>`（redirect） | **rc=2** |
| `tee`（copy-like） | rc=2 |
| `cp`（copy-like） | rc=2 |
| `Write` ツール（file レーン） | rc=2 |

- 意図: 「そのパスは到達しない」という論法を封じる。修正前は `>` だけ rc=0 だった。

### T1110-TC-09: 改行畳み込みの負の対照（AC-1 / V-3 R-005）

- 入力: `cat <<EOF > /tmp/log.txt` + 本文行にトークンパス + `EOF`
- 期待: **rc=0**（書き込み先は `/tmp/log.txt`。本文は内容にすぎない）
- 意図: 改行を畳まないと本文行が「先」として評価され誤 block になる。

### T1110-TC-10: 診断値を持ち越さない（AC-4 / V-3 R-005）

- 前提: `sed` が必ず失敗するシムを PATH 先頭に置く（`_strip_nonwrite_redirects` /
  相関判定がともに fail-closed で診断値を立てる）
- 入力: `cp <TOKEN> /tmp/x`（`>` を含まない = redirect レーン不成立）
- 期待: rc=2 かつ stderr が `rule=copy-like` を含み、**`redirect_target=` を含まない**

### 変異注入（AC-6）

**レーン全体**を落とす変異だけでは、**レーン内部の分類ミス**（解決不能 →
解決済み非トークン）は原理的に検出できない。V-3 R-001 の穴はまさにそれだったため、
レーンを生かしたまま分類だけを誤らせる変異を必須とする。

| 変異 | 種別 | 内容 | 期待 kill |
|------|------|------|-----------|
| M-1 | レーン全体（call site） | `_redirect_tok=1` 固定（元の OR 判定へ回帰） | T1110-TC-01 |
| M-2 | レーン全体（call site） | `_redirect_tok=0` 固定（真の陽性を落とす） | T1045-TC-04 |
| **M-3** | **レーン内部** | 引用・退避の検出を無効化 | **T1110-TC-06** |
| **M-4** | **レーン内部** | 終端文字クラスへ `#` を戻す | **T1110-TC-07** |
| **M-5** | **レーン内部** | 診断値リセットの削除 | **T1110-TC-10** |
| **M-6** | **レーン内部** | 改行畳み込みの無効化 | **T1110-TC-09** |

- 種別: Mutation / 自動化: 可（既存 `_t25_mutate` を prefix `T1110` で再利用）

## エッジケース（既存 TC で担保 / 期待値不変）

| ケース | 期待 | 担保 TC |
|--------|------|---------|
| `2>/dev/null` を伴う読み取り | rc=0 | T1045-TC-01, T1045-TC-17 |
| `2>&1` / `>&2` / `3>&-` | rc=0 | T1045-TC-02/03/03b |
| `/dev/nullX` / `/dev/null/../TOKEN` | rc=2 | T1045-TC-12, T1045-TC-13 |
| `&>` / `&>>`（`/dev/null` 宛を含む） | rc=2 | T1045-TC-14（U-2 の block 維持） |
| `>& <file>` | rc=2 | T1045-TC-15 |
| `cp` / `mv` / `tee` によるトークン書き込み | rc=2 | T1045-TC-07 |
| sed 不在 / sed 失敗 | rc=2 | T1045-TC-22 / T1045-TC-22b |

## 期待値を変更する既存 TC（#1110 の是正対象）

> **2 件**（V-3 R-003 反映。初版はこの表に `T1045-TC-19` しか書いておらず、
> `T1023-TC-09` の反転が宣言範囲外だった）。

| TC | 変更前 | 変更後 | 理由 | C-3 判断 |
|----|--------|--------|------|----------|
| T1045-TC-19 | `echo (a > b) TOKEN` → rc=2（保守的 block） | **rc=0** | リダイレクト先が `b` でトークンパスに解決されない。ケース A と同型の誤検出であり #1110 の是正対象そのもの。TASK-1045 handoff K-2 が自ら「minor（残存誤検知）」と分類済 | 低 |
| **T1023-TC-09** | `cat TOKEN && echo hi > /tmp/other.txt` → rc=2（相関解析しない仕様） | **rc=0** | トークンへ 1 バイトも書かない。ケース A と同型 | **要判断**: **TASK-1023 pbi-input AC-04 を redirect レーンに限り上書き**する（非 redirect レーンは従来どおり安全側 block のまま） |

`T1045-TC-19` については、TASK-1045 plan の停止条件 SC-6（TC-11〜15 / TC-19 が
rc=0 になったら critical 停止）は **TASK-1045 exec 中の条件**であり後続 PBI を
縛らない。#1110 は同じ真の陽性を「先がトークンパスに解決されるか」という別経路で
維持しており、TC-11〜15 は本 PR でも rc=2 のまま（V-3 R-004 / 実測済み）。
