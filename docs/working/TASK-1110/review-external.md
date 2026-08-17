# TASK-1110 / #1110 — 外部レビュー（V-3 相当）

- **対象**: `origin/fix/1110-eh13-redirect-correlation` head = `f922442`
- **比較基準**: `origin/main` = `0385457`
- **レビュー worktree**: `/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a7a16f3a740ac59c7`
- **レビューブランチ**: `review/1110-v3`
- **実施日**: 2026-08-18
- **観点 / severity**: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §2〜4（5 観点 / 4 段階）
- **判定**: **REJECT**（critical 1 件 / major 2 件）

> 記法規約（TASK-1045 を踏襲）: 本文にトークンパス literal を直接書かない。
> `TOKEN` = `docs/working/TASK-0001/approvals/` + `c3` + `.json`（架空パス）。
> 実 `approvals/` には一切書き込んでいない。プローブは中立ファイル名のみ使用。

---

## 検証環境と再現手順

すべて hook 単体へ PreToolUse payload を stdin で与え、rc のみを観測した
（実ファイルへの書き込みは一切行っていない）。

| スクリプト | 内容 |
|-----------|------|
| `scratchpad/cases_v3.py` | 35 ケースの新旧比較（新規攻撃ケース含む） |
| `scratchpad/cases_v3b.py` | 切り詰め文字クラスの網羅 + fail-closed 宣言の全数照合 |
| `scratchpad/cases_v3c.py` | 現実的な spaced path バイパス + 実行時間 |
| `scratchpad/cases_v3d.py` | Write レーン / Bash レーンの非対称性 |
| `scratchpad/bench_v3.py` | 交互実行による median 実測（ノイズ相殺） |
| `scratchpad/my_mutations{,_full}.sh` | V-3 独自変異 M-A〜M-D |
| `scratchpad/ta25_harness_mode.sh` | `PG_HARNESS_SOURCED=1` + `FIXTURES_DIR` の harness 相当実行 |
| `scratchpad/run_gnu_ta25.sh` | GNU sed を PATH 先頭に置いた TA-25 実行 |

実行コマンドと exit code:

| コマンド | 結果 |
|----------|------|
| `sh tests/extras/ta-25-approval-token-guard.sh`（standalone / BSD sed） | **77 passed, 0 failed**（42.6s） |
| `sh scratchpad/run_gnu_ta25.sh`（GNU sed 4.10） | **77 passed, 0 failed** |
| `sh scratchpad/ta25_harness_mode.sh`（harness 相当） | **pass=77 fail=0 / EXIT=0** |
| `sh tests/extras/ta-61-extra-contract.sh` | **89 passed, 0 failed / EXIT=0**（入れ子フルスイート込み） |

---

## 指摘一覧

### R-001 — **critical** — リダイレクト先の「静的に解決できない」判定に切り詰めクラスが抜けており、真の陽性が落ちる

**観点**: セキュリティ / 保守性
**分類**: 「block 条件を狭めた結果、真の陽性が落ちた」型

`_redirect_writes_token()` は `>` 分割後の各レコードから先頭語を取り出す際、

```sh
-e 's%[[:space:];&|()<#].*$%%'   -e "s%^['\"]%%" -e "s%['\"]\$%%"
```

で **空白 / `;` / `&` / `|` / `(` / `)` / `<` / `#` に当たった時点で語を打ち切り**、
引用符は**先頭 1 文字と末尾 1 文字しか剥がさない**。その結果、
**引用（またはバックスラッシュ退避）されたトークンパスがこれらの文字を 1 つでも含むと、
語は非トークンの前半分に化けて「解決済みの非トークン」と判定され、block されない**。

fail-closed の宣言（コード内コメント / plan §fail-closed）は
「空 / `$` / バッククォート / glob / `/dev/*` / `&>`」だけを列挙しており、
**「切り詰めで別物になった語」が抜けている**。切り詰め後の語は静的に解決できて
いないのに、解決できた扱いで通過する。

#### 実測（`scratchpad/cases_v3b.py`）

引用済みパスの中に各文字を 1 つ埋めただけのケース。**9 クラスすべてで main は block、
PR は通す。**

```
TRUNC-CHAR   OLD    NEW    verdict
space        rc=2   rc=0   TRUE-POSITIVE LOST
tab          rc=2   rc=0   TRUE-POSITIVE LOST
semicolon    rc=2   rc=0   TRUE-POSITIVE LOST
amp          rc=2   rc=0   TRUE-POSITIVE LOST
pipe         rc=2   rc=0   TRUE-POSITIVE LOST
lparen       rc=2   rc=0   TRUE-POSITIVE LOST
rparen       rc=2   rc=0   TRUE-POSITIVE LOST
lt           rc=2   rc=0   TRUE-POSITIVE LOST
hash         rc=2   rc=0   TRUE-POSITIVE LOST
```

バックスラッシュ退避でも同じ（`scratchpad/cases_v3.py` N9: `echo x > my\ dir/TOKEN` → OLD rc=2 / NEW rc=0）。

#### 「到達しない経路ではない」ことの証明 — レーン非対称（`scratchpad/cases_v3d.py`）

同一の絶対パス（`/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/c3.json`）に対して:

```
Write tool, file_path = spaced token path      -> rc=2
Bash tool, redirect to the same spaced path    -> rc=0     ← 穴
Bash tool, tee to the same spaced path (ctrl)  -> rc=2
```

**同じファイルへの書き込みが、`Write` ツール経由と `tee` 経由では block されるのに、
`>` 経由だけ通る。** EH-13 が守る対象は同一なので、これは「そのパスは存在しない」
という論法で無効化できない。macOS の `My Drive` / `Google Drive` 配下、
`repo (2)` のような複製ディレクトリ、`PR#1` のようなブランチ用ディレクトリなど、
空白 / `(` / `#` を含むチェックアウトは現実に存在しうる。

```
abs path with a space (sq)                     OLD rc=2  NEW rc=0
abs path with a space (dq)                     OLD rc=2  NEW rc=0
dir with parentheses                           OLD rc=2  NEW rc=0
dir with a hash                                OLD rc=2  NEW rc=0
tee to spaced path (copy-like lane, control)   OLD rc=2  NEW rc=2
```

#### 推奨対応

**引用符を検出したら「静的に解決不能」として block 側へ倒す**のが最小修正。
完全なシェル構文解析（TASK-1045 GC-2 で不採用）に踏み込まずに閉じられる:

1. 切り詰め **前** のレコードに `'` / `"` / `\` が含まれていたら、
   `case` の fail-closed 群（`@EMPTY@` / `$` / バッククォート / glob）と同列に扱い
   `_wi_redirect_target` に理由を入れて `return 0`
2. あるいは、切り詰めで実際に文字が落ちたか（`s%…%%` の前後比較）を見て、
   落ちたレコードは解決不能扱いにする

いずれも「誤検知は増えるが真の陽性は落とさない」側であり、#1110 の主目的
（トークン名の**言及**だけで止まる誤検出の解消）は損なわれない
— 誤検出ケース A / N29〜N32 はいずれもリダイレクト先に引用符を持たない。

**追加すべき TC**: `T1110-TC-03` の真の陽性群へ「引用済みで空白を含む先」
「`(` を含む先」「バックスラッシュ退避された空白を含む先」を追加し、
`_redirect_writes_token` の fail-closed 分岐を壊す変異（本レビューの M-A 型）で kill を実証すること。

---

### R-002 — **major** — evidence の「真の陽性は 1 件も落ちていない」は全数照合されていない誤った量化子主張

**観点**: 保守性 / セキュリティ

`docs/working/TASK-1110/evidence/README.md:47-48`:

> 修正で rc が変わったのは **#1（A）と #8 のみ**。いずれもリダイレクト先が
> トークンパスに解決されない誤検出であり、**真の陽性は 1 件も落ちていない。**

これは **18 ケースという自作サンプル内での観測**であって、全数照合ではない。
R-001 のとおり、**最低 9 クラス（+ バックスラッシュ退避）で真の陽性が落ちている**。
plan §Risks の緩和策「判定不能は全て block 側」も同様に**未達**である
（切り詰めクラスが「判定不能」に分類されていない）。

同種の主張は `review-self.md` の
「既存 block 系 TC を期待値不変で維持し、M-2 変異で緩和を機械検出」にもあるが、
M-2（相関を常時 false）は**相関レーン全体を落とす**変異なので、
**相関レーン内部の分類ミス（解決不能→解決済み非トークン）は検出できない**。
実際、本レビューの M-A（fail-closed 分岐の無効化）は `T1110-TC-04` で killed だが、
切り詰めクラスにはそもそも TC が無いので変異以前に検出手段が存在しない。

**推奨対応**: R-001 修正後、evidence の当該断定を
「本 PBI が測定した N ケースの範囲では」とスコープ付きに書き換えるか、
機械的な全数根拠（TC + 変異）を添えること。

---

### R-003 — **major** — `T1023-TC-09` の期待値反転が承認済み plan の宣言範囲外で、かつ TASK-1023 の AC 本文を変更している

**観点**: 保守性（承認境界の追跡可能性）

PR は既存 TC の期待値を **2 件** 反転している（`T1045-TC-19` / `T1023-TC-09`）。
しかし承認プロセス上の宣言は次のように食い違う:

| 資料 | 宣言 |
|------|------|
| `docs/working/TASK-1110/plan.md:88` | 🚩「既存 TC の期待値変更は **`T1045-TC-19` のみ**。他の既存 TC はすべて期待値不変で PASS すること」 |
| `docs/working/TASK-1110/test-cases.md:101-105`「期待値を変更する既存 TC」 | **`T1045-TC-19` の 1 行のみ** |
| `docs/working/TASK-1110/review-self.md:53` | 「既存 TC の期待値を **2 件**反転した（`T1023-TC-09` / `T1045-TC-19`）… C-3 での確認事項」 |

さらに `T1023-TC-09` が固定していたのは単なる TC ではなく、
**TASK-1023 の受入基準本文**である:

```
docs/working/TASK-1023/pbi-input.md:48
AC-04: … token pathと別writeを混在させたcommandは安全側blockを仕様とする
```

（`docs/working/TASK-1023/test-cases.md:26` も「保守的rc=2（相関解析しない仕様）」）

**判定: 不当ではないが、宣言不足（手続き上の欠陥）**。
反転の**実質**は #1110 の是正対象クラスそのもの
（`cat TOKEN && echo hi > /tmp/other.txt` はトークンへ 1 バイトも書かない）なので、
「自分の変更を通すためのテスト書き換え」ではない。ただし
**人間が C-3 で承認した AC 文言を、plan が「変更しない」と宣言した対象に対して、
exec 中に無断で変更している**。承認境界そのものを扱う PBI でこれは通せない。

**推奨対応**:
1. `test-cases.md` の「期待値を変更する既存 TC」表へ `T1023-TC-09` を追記し、
   plan §Step の🚩「`T1045-TC-19` のみ」を 2 件へ修正
2. TASK-1023 `AC-04` の「混在は安全側 block を仕様とする」を
   **redirect レーンに限り #1110 で上書きした**旨を TASK-1023 側（handoff 等）へ追記
3. これらを反映したうえで **C-3 を取り直す**

---

### R-004 — **minor** — `T1045-TC-19` の反転は正当だが、TASK-1045 の停止条件 SC-6 との関係を明示していない

**観点**: 保守性

`T1045-TC-19`（文字列リテラル中の `>`）の反転は、**手続き上は正しく宣言されている**
（`pbi-input.md:72-73` / `plan.md:88` / `test-cases.md:105`）。かつ TASK-1045 自身が
これを **残存誤検知**として既知課題化していた:

```
docs/working/TASK-1045/handoff.md:77
K-2 … 文字列リテラル中の `>` … | minor（残存誤検知） | plan GC-2 の宣言どおり
     「誤検知として扱わない」。固定 TC = T1045-TC-19
```

したがって **反転そのものは正当**（意図的仕様の無断反転ではない）。

ただし TASK-1045 の plan には次の停止条件がある:

```
docs/working/TASK-1045/plan.md:696
SC-6: `>` 除外を入れた結果、T1045-TC-11〜15 / TC-19 … のいずれかが rc=0 になる
      → ガードが弱体化した（GC-1 違反 = critical）。即停止し …
```

これは TASK-1045 **exec 中**の停止条件であって後続 PBI を縛るものではないが、
`TC-19` だけを見た将来の監査者が「critical 停止条件が黙って踏まれた」と誤読する。
`TC-19` のテスト本文コメントに **TASK-1045 SC-6 は TASK-1045 exec 内の条件であり、
#1110 は相関判定を追加して同じ真の陽性を別経路で維持している** 旨の 1 行を足すこと。
なお `TC-11`〜`TC-15` は本 PR でも全て rc=2 のまま（実測済み）。

---

### R-005 — **minor** — 追加された 2 箇所が変異で kill されない（テスト未カバー）

**観点**: 保守性

V-3 独自変異を **77 TC のフルグループ**に対して実施した（`scratchpad/my_mutations_full.sh`）:

| 変異 | 内容 | 結果 |
|------|------|------|
| **M-A** | fail-closed 分岐（`$` / バッククォート / glob / `/dev/*`）を `continue` に置換 | **KILLED**（`T1110-TC-04`） |
| **M-B** | `&>` 早期 return を `return 1` に置換 | **KILLED**（`T1045-TC-14`） |
| **M-C** | commit `f922442` が足した診断値リセット `_wi_redirect_target=""` を削除 | **SURVIVED**（77 passed, 0 failed） |
| **M-D** | 改行畳み込み `tr '\n' ' '` を `cat` に置換 | **SURVIVED**（77 passed, 0 failed） |

- **M-C**: 2 本目のコミット `f922442`（「redirect レーン不成立時に診断値を持ち越さない」）は
  **回帰テストを 1 件も持たない**。挙動（rc）には影響しない診断メッセージ限定の修正だが、
  `T1110-TC-05` が `redirect_target` を assert している以上、
  **不成立時に `redirect_target` が付かないこと**の負の対照も 1 件足せる。
- **M-D**: 改行畳み込みは、無くても既存 TC はすべて通る。誤検知を減らす方向の
  最適化であり真の陽性側には影響しないが、意図を残すなら TC か
  「TC 無しである」旨の明示が要る。

（参考: ワーカー申告の M-1 / M-2 は独立に再現し、いずれも真に kill することを確認した。
空振り申告ではない。）

---

### R-006 — **minor** — `high-risk` PBI が C-3 未通過のまま exec 済み / handoff 未作成

**観点**: 保守性（プロセス）

- `docs/working/TASK-1110/status.md:17`: 「C-3: 人間レビュー **未実施（Human 待ち）**。`c3.json` は発行していない」
- `docs/working/TASK-1110/approvals/` は**存在しない**
- `plan.md:149`: **モード = `high-risk`**

[`working-context.md`](../../../.claude/rules/working-context.md) §C-3 Autonomous APPROVE 判定マトリクスでは
`high-risk / critical` は **autonomous APPROVE 不可（人間 C-3 必須）**。
承認境界の強制機構を弱める方向の変更が、承認ゲートを通さずに実装まで進んでいる。
status.md が正直に自己申告している点は評価するが、**R-001 / R-003 の是正後に
改めて人間 C-3 を取り、`handoff.md`（Rule 5 必須 6 要素）を発行してから PR 化すること。**

---

### R-007 — **info** — 実行時間: 非トークンコマンドは不変、トークン混在コマンドは約 2 倍（+38〜42ms）。hook に timeout 設定なし

**観点**: パフォーマンス

`scratchpad/bench_v3.py`（新旧を交互実行し median、N=60）:

| ケース | OLD median | NEW median | delta |
|--------|-----------|-----------|-------|
| 非トークン（PreToolUse の大多数） | 24.69 ms | 23.70 ms | **-0.98 ms** |
| トークン read のみ | 60.25 ms | 69.55 ms | +9.30 ms |
| トークン + リダイレクト 1 個 | 30.39 ms | 68.46 ms | **+38.06 ms** |
| トークン + リダイレクト 20 個 | 30.14 ms | 71.24 ms | +41.11 ms |
| トークン + リダイレクト 200 個 | 31.82 ms | 74.40 ms | +42.58 ms |

- **常時経路（トークン名を含まない Bash 呼び出し）は劣化なし**。
  `_has_write_intent()` は `_is_token_path "$_cmd"` の後段でしか呼ばれないため。
- 増分は `tr` / `sed` / `tr|sed` の追加サブプロセス 3 本分の固定コストで、
  **リダイレクト数に対して超線形にならない**（20 個と 200 個で +1.5ms しか差がない）。
- `.claude/settings.example.json` の EH-13 登録に `timeout` キーは無い
  （`grep -n timeout` → 0 件）。暴走時は block ではなくハングとして出るが、
  本変更に暴走要因は観測されなかった。**本 PR のブロッカーではない**（別 PBI 相当）。

---

### R-008 — **info** — glob 版トークン名（`c3.jso*`）は新旧同値で通過。#1110 の退行ではない（#1115 で既起票）

`scratchpad/cases_v3b.py` 実測: `echo x > docs/working/TASK-0001/approvals/c3.jso*`
→ **OLD rc=0 / NEW rc=0**。原因は外側ゲート `_is_token_path "$_cmd"` が
コマンド全体でトークンパターンに一致しないこと（相関判定には到達しない）。
既存穴であり本 PR の対象外。記録のみ。

---

### R-009 — **info** — `ta-61` の契約は本 PR で変化しない（実測 89 passed / 0 failed）

`tests/extras/ta-25-approval-token-guard.sh` は capability marker も
`pg_extra_contract_init` も持たない **契約導入前のレガシー extras** であり
（`grep -n 'pg_extra_contract_init' tests/extras/ta-25-*.sh` → 0 件）、
ta-61 の covered set の対象外。本 PR の diff は ta-25 の 1〜110 行目
（ヘッダ / standalone fallback / marker 相当領域）に**一切触れていない**ため、
marker 1 個 / init 一致 / finalize / rc 層の契約は構造的に不変。
standalone（rc=0 / 77 passed）と harness 相当（`PG_HARNESS_SOURCED=1` +
`FIXTURES_DIR` / `fail=0` / EXIT=0）の**両方**で緑を実測済み。

さらに `sh tests/extras/ta-61-extra-contract.sh` を PR head 上で完走させ、
**`TA-61 standalone: 89 passed, 0 failed` / `EXIT=0`** を実測した
（入れ子フルスイートを含むため長時間。`TC-14` の
「harness regression — suite rc=0, 0 failed, runtime-resolved last file
(`ta-66-codex-plugin-manifest.sh`) reached」も PASS）。
**marker 1 個 / init 一致 / finalize / rc 層（0/1/2/3）/ standalone 両対応の
契約は本 PR で破壊されていない。**

---

## 反証を試みて棄却した指摘候補

| 候補 | 反証（実測） | 結論 |
|------|-------------|------|
| `&>` / `&>>` が緩んだ | `cases_v3.py` N10/N11 = OLD rc=2 / NEW rc=2。変異 M-B（`&>` 早期 return を無効化）は `T1045-TC-14` で **KILLED** | 棄却 |
| fail-closed（`$` / バッククォート / glob `*?[` / 空 / `/dev/*`）は宣言だけで実効なし | `cases_v3b.py` で 9 項目すべて NEW rc=2 を実測。変異 M-A は `T1110-TC-04` で **KILLED** | 棄却（宣言と実測が一致） |
| ワーカー申告の M-1 / M-2 kill が空振り | 独立に再現。M-1 → `T1110-TC-01` FAIL、M-2 → `T1045-TC-04` FAIL | 棄却 |
| GNU sed で壊れる（BSD sed 依存） | GNU sed 4.10 を PATH 先頭に置いて TA-25 = **77 passed, 0 failed**。BSD sed も同値 | 棄却 |
| 絶対件数（77 / 18 / 13）が契約値になっている | diff に件数 assert の追加なし。`T1045-TC-21` は `TC-1[567]` の 7 件のみを数えており、新規 `_t25_mutate "TC-06"/"TC-07"` は該当しない | 棄却 |
| 行番号アンカーの使用 | `docs/working/TASK-1110/*.md` に `L\d+` 形式の行番号アンカーなし。コード側は `# t1110-redirect-correlate` の記号アンカーで既存規約に一致 | 棄却 |
| heredoc / `exec >` / `dd` / `truncate` / `install` / `sed -i` / `python open(...,'w')` などが抜けた | `cases_v3.py` N2〜N8, N17〜N19 すべて NEW rc=2 | 棄却 |
| `>|`（noclobber 上書き）が抜けた | N12 = NEW rc=2 | 棄却 |
| 複文・部分シェル・関数定義・改行区切りで抜ける | N13 / N14 / N23 / N24 / N27 / N28 すべて NEW rc=2 | 棄却 |
| 大文字 `C3.JSON` が抜けた | OLD rc=0 / NEW rc=0 = **既存挙動と同値**（`_is_token_path` は大小区別。#1110 の退行ではない） | 棄却（本 PR 対象外） |

---

## 私が新規に考えた攻撃ケース（抜粋 / 全 35 件は `scratchpad/cases_v3.py`）

| ID | ケース | OLD | NEW | 判定 |
|----|--------|-----|-----|------|
| N1 | 引用済みで空白を含む先へ `>` | rc=2 | **rc=0** | **真の陽性喪失（R-001）** |
| N9 | バックスラッシュ退避した空白を含む先へ `>` | rc=2 | **rc=0** | **真の陽性喪失（R-001）** |
| N2 | `exec > TOKEN` | rc=2 | rc=2 | OK |
| N3 | `exec 3> TOKEN` | rc=2 | rc=2 | OK |
| N4 | heredoc `cat <<EOF > TOKEN` | rc=2 | rc=2 | OK |
| N5 | `dd if=/dev/zero of=TOKEN` | rc=2 | rc=2 | OK |
| N6 | `python3 -c "open(TOKEN,'w').write(...)"` | rc=2 | rc=2 | OK |
| N7 | `approvals//c3.json`（区切り重複） | rc=2 | rc=2 | OK |
| N8 | `>` と先の間がタブ | rc=2 | rc=2 | OK |
| N12 | `>|`（noclobber 上書き） | rc=2 | rc=2 | OK |
| N22 | `IFS=/;` 改変後にリダイレクト | rc=2 | rc=2 | OK |
| N33 | プロセス置換 `> >(cat)` | rc=2 | rc=2 | OK |
| N34 | ブレース展開 `{a,c3.json}` | rc=2 | rc=2 | OK |
| N35 | `./a/../TOKEN` | rc=2 | rc=2 | OK |
| N29〜N32 | 誤検出であるべき 4 ケース（コミットメッセージ / 読取 + 別書込 / heredoc 本文 / リテラル `>`） | rc=2 | **rc=0** | **是正成功（意図どおり）** |

---

## 監査表

| R-NNN | severity | status | reflected_in | notes |
|-------|----------|--------|--------------|-------|
| R-001 | critical | OPEN | — | 切り詰めクラスを fail-closed へ。TC + 変異の追加必須 |
| R-002 | major | OPEN | — | evidence の全称主張をスコープ付きに是正 |
| R-003 | major | OPEN | — | `T1023-TC-09` 反転を plan / test-cases へ宣言し TASK-1023 AC-04 を追補、C-3 取り直し |
| R-004 | minor | OPEN | — | TASK-1045 SC-6 との関係を TC コメントに 1 行 |
| R-005 | minor | OPEN | — | `f922442` の診断値リセット / 改行畳み込みが変異で kill されない |
| R-006 | minor | OPEN | — | `high-risk` PBI が C-3 未通過 / handoff 未発行 |
| R-007 | info | OPEN | — | 実行時間 +38〜42ms（トークン混在時のみ）。hook timeout 未設定 |
| R-008 | info | OPEN | — | `c3.jso*` glob 穴は新旧同値（#1115） |
| R-009 | info | CLOSED | — | ta-61 = 89 passed / 0 failed（実測）。standalone / harness 両モードも緑 |

---

## 総括

**#1110 が狙った誤検出の解消は成功しており**（ケース A および本レビューの N29〜N32 が
rc=2 → rc=0）、`&>` の据え置き・`$` / バッククォート / glob / 空 / `/dev/*` の
fail-closed・移植性（BSD sed / GNU sed 双方で 77/0）・既存変異 9 種の維持は
**いずれも申告どおり実測で裏付いた**。

しかし、**リダイレクト先の抽出が「静的に解決できない」を数え落としており、
引用またはバックスラッシュ退避されたトークンパスが空白・`;`・`&`・`|`・`(`・`)`・
`<`・`#` を含むと block が外れる**（R-001）。同一パスが `Write` / `tee` では
block されるのに `>` だけ通るというレーン非対称が、これが理論上の話でないことを示す。
承認境界のガードで真の陽性が落ちる以上、**critical であり REJECT**。

加えて、**「真の陽性は 1 件も落ちていない」という evidence の断定は全数照合の
裏付けを欠いており**（R-002）、**承認済み plan が「変更しない」と宣言した既存 TC を
exec 中に反転している**（R-003）。この 2 点は、承認境界を扱う PBI の
検証プロセスとしてそれ自体が是正対象である。
