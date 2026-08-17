# テストケース定義 — TASK-1110 (#1110)

`TOKEN` = `docs/working/TASK-0001/approvals/c3.json`（TA-25 既存の架空 fixture パス。
実 approvals には触れない）。すべて `tool_name=Bash` / `hook_event_name=PreToolUse` の
PreToolUse payload を stdin へ与えて `scripts/check-approval-token-write.sh` を起動する。

## 受入基準 → テストケース マッピング

| AC | 内容 | TC |
|----|------|----|
| AC-1 | トークン名 + 無関係リダイレクト → rc=0 | T1110-TC-01, T1110-TC-02 |
| AC-2 | 真の陽性は block 維持 | T1110-TC-03（+ 既存 T1045-TC-04/05/06） |
| AC-3 | 判定不能は fail-closed | T1110-TC-04 |
| AC-4 | BLOCK メッセージに一致した先を出す | T1110-TC-05 |
| AC-5 | 既存 TA-25 が PASS | 既存 TC 全体（個別実行 rc=0） |
| AC-6 | 変異が実 TC の FAIL で kill される | T1110-TC-06（M-1）, T1110-TC-07（M-2） |

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

### T1110-TC-06: 変異 M-1 = 相関判定を OR に戻す（AC-6）

- 変異（**call site**）: `# t1110-redirect-correlate` の行を `_redirect_tok=1` 固定へ置換
- 期待: **T1110-TC-01 が FAIL**（誤検出が復活する）→ mutant killed
- 種別: Mutation / 自動化: 可（既存 `_t25_mutate` を prefix `T1110` で再利用）

### T1110-TC-07: 変異 M-2 = 相関判定を常時 false（AC-6）

- 変異（**call site**）: 同じ行を `_redirect_tok=0` 固定へ置換
- 期待: **T1045-TC-04（`> TOKEN` の block）が FAIL**（真の陽性が抜ける）→ mutant killed
- 種別: Mutation / 自動化: 可
- 意図: 「誤検出を減らす」方向へ倒しすぎた場合に既存 TC が気付くことの実証。

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

| TC | 変更前 | 変更後 | 理由 |
|----|--------|--------|------|
| T1045-TC-19 | `echo (a > b) TOKEN` → rc=2（保守的 block） | **rc=0** | リダイレクト先が `b` でトークンパスに解決されない。ケース A と同型の誤検出であり #1110 の是正対象そのもの |
