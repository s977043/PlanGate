# C-2 / V-3 外部レビュー — TASK-1115 (#1115) EH-13 glob bypass の封鎖

> 実施日: 2026-08-18
> 対象: `origin/fix/1115-eh13-glob-bypass` head = `5ccc1fe`（base = `origin/main` = `17cd044`）
> レビューア: 外部レビューア（V-3 相当 / 読み取り + レビュー記録のみ。実装ファイルは編集していない）
> 観点 / severity: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §2〜4（5 観点 / critical-major-minor-info）
> 変異評価の観点: [`.claude/skills/diff-audit/SKILL.md`](../../../.claude/skills/diff-audit/SKILL.md) Phase 6 item 6〜8

## VERDICT: **REJECT**

理由（いずれも単独で REJECT 相当）:

1. **R-001 (critical)**: 是正の中核である「先頭 glob を (B) から除外してよい」根拠が
   `approvals/` 配下にしか成立せず、**保護トークンの 1 つ `maintenance.json`
   （`docs/working/_maintenance/` = approvals 外）は先頭 glob で今も上書きできる**。
   issue #1115 本文の是正前実測表に載っている対象であり「広げたと宣言したのに塞げていない」。
2. **R-003 (major)**: 日常操作の**新規誤検出を 11 件実測**。plan / issue の
   「誤検出が増えていないことは実測済み」は測定 5 ケースに対してのみ成立し、
   一般には成立しない。
3. **R-004 (major)**: PreToolUse（全 Bash 実行のたびに走る）で **最大 163 倍・9.6 秒/call**
   の実行時間劣化。#1110 で維持した「常時経路は無劣化」の水準を割っている。

## 検証環境・再現手順

```sh
# probe（本番と同一の stdin PreToolUse payload 経路）
payload=$(CMD="$cmd" python3 -c 'import json,os; print(json.dumps({
  "hook_event_name":"PreToolUse","tool_name":"Bash",
  "tool_input":{"command":os.environ["CMD"]},"session_id":"probe"}))')
printf '%s' "$payload" | sh scripts/check-approval-token-write.sh; echo "rc=$?"
```

- PRE = `git show origin/main:scripts/check-approval-token-write.sh`
- POST = branch `5ccc1fe` の同ファイル
- shell 展開の実証は **中立名 `tok/x9.json`** のみを使用（保護パスへは一切書き込んでいない）

---

## 指摘一覧

### R-001 / critical / セキュリティ / 「広げたと宣言したのに塞げていない」

**`maintenance.json` は先頭 glob で今も上書きできる。**

plan.md は (B) から先頭 glob を外す根拠をこう書いている:

> approvals 配下の `*.json` は **(A) と既存リテラル判定 `*/approvals/*.json`**
> の双方で閉じているので、外しても穴は開かない

この命題は `approvals/` 配下に限って真である。しかし保護 basename リスト
（`t1115-protected-basenames`）の 1 つ **`maintenance.json` は
`docs/working/_maintenance/maintenance.json`（approvals 外）** に置かれる
（`bin/plangate:778`）。したがって (A) も `*/approvals/*.json` も掛からず、
**先頭 glob 除外がそのまま bypass になる。**

実測（POST = `5ccc1fe`）:

```
rc=0 | cp /tmp/evil docs/working/_maintenance/*.json
rc=0 | tee docs/working/_maintenance/*.json
rc=0 | echo x > docs/working/_maintenance/*.json
rc=0 | cp /tmp/evil docs/working/_maintenance/*
rc=0 | sed -i s/a/b/ docs/working/_maintenance/*.json
rc=0 | cp /tmp/evil docs/working/_maintenance/?aintenance.json
rc=0 | install -m 644 /tmp/evil docs/working/_maintenance/[m]aintenance.json
```

**「先頭 glob は広すぎるから除外」という誤検出抑制の理屈は、`?aintenance.json` /
`[m]aintenance.json` には当てはまらない。** これらは 1 ファイルだけを狙い撃つ
パターンであり、`*.json` のような「日常コマンド」ではない。除外条件が
*形（先頭が glob か）* で切られていて *広さ* で切られていないため、
**誤検出抑制の理屈が通らない語まで一律に通してしまっている。**

シェル側の成立性（中立名 `tok/x9.json`・全シェル実測。保護パスへは未書き込み）:

```
sh    | cp SRC tok/*.json    | x9.json=PWNED      sh    | cp SRC tok/?9.json   | x9.json=PWNED
bash  | cp SRC tok/*.json    | x9.json=PWNED      bash  | cp SRC tok/?9.json   | x9.json=PWNED
zsh   | cp SRC tok/*.json    | x9.json=PWNED      zsh   | cp SRC tok/?9.json   | x9.json=PWNED
dash  | cp SRC tok/*.json    | x9.json=PWNED      dash  | cp SRC tok/?9.json   | x9.json=PWNED
ksh   | cp SRC tok/*.json    | x9.json=PWNED      ksh   | cp SRC tok/[x]9.json | x9.json=PWNED
```

（引数レーンの pathname expansion は POSIX 必須 = **shell 非依存**。
redirect レーンは bash/zsh のみ。issue の「訂正・拡大」節と一致。）

**前提条件（正直な限定）**: glob は既存ファイルにしか展開されないため、これは
**既存の maintenance token の上書き**であって新規偽造ではない。ただし
`bin/plangate maintenance start` 後に残る token の内容（有効期限・スコープ）を
AI が書き換えられることを意味し、**「AI は自分の実行許可を発行/延長できない」
という承認境界そのもの**を破る。

**推奨対応**: (A) を `approvals/` 限定ではなく **「保護 token が存在しうる
ディレクトリ集合」** に一般化する。最小案は
`*/_maintenance/*` を (A) と同じ扱いにする（basename に glob があれば fail-closed）。
併せて `*maintenance.json*` と同じく `_maintenance/` を `_is_token_path` 側にも
足すのが構造的に一貫する。

---

### R-002 / major / セキュリティ / 同クラスの未封鎖（brace expansion）

**brace expansion（`{a,b}`）は検査の glob メタ文字集合（`*` `?` `[`）に含まれず、
PRE / POST で挙動が同一（rc=0）。しかも glob と違い「存在しないファイルを作れる」
＝ token の新規偽造ができる。**

実測（PRE / POST とも全件 rc=0）:

```
rc=0 | printf x | tee docs/working/TASK-9/approvals/c3.jso{n,n}
rc=0 | printf x | tee docs/working/TASK-9/approvals/parent-c3.jso{n,n}
rc=0 | cp /tmp/evil docs/working/TASK-9/approvals/c3.jso{n,n}
rc=0 | printf x | tee docs/working/TASK-9/approval{s,s}/c3.jso{n,n}
rc=0 | printf x | tee docs/working/_maintenance/maintenance.jso{n,n}
rc=0 | echo x > docs/working/TASK-9/approvals/c3.jso{n,n}
```

シェル側（中立名・**存在しないファイルが作られること**を実証）:

```
sh    | dir now contains: [x9.json ]        <- tee tok/x{9,9}.json
bash  | dir now contains: [x9.json ]
zsh   | dir now contains: [x9.json ]
ksh   | dir now contains: [x9.json ]
dash  | dir now contains: [x{9,9}.json ]    (brace 非対応 = 不成立)
```

**`c3.json` も含めて全保護 token が偽造可能**（`approvals/` の (A) も
`*/approvals/*.json` リテラルも、`.json` で終わらない `c3.jso{n,n}` には掛からない）。

issue 本文の In scope は「ワイルドカード（`*` / `?` / `[...]`）」なので**文字どおりには
scope 外**だが、本 PBI の是正の本質は「シェル展開後の姿と照合していない」ことであり、
brace はその**より強力な兄弟クラス**である。少なくとも **残存クラス表に明記されていない**
（表にあるのは先頭 glob / 変数代入語 / 文字列連結 / `rm` の 4 つ）ため、
handoff 読者は「#1115 のクラスは閉じた」と誤読する。

**推奨対応**: (1) 残存クラス表に brace expansion を追加し follow-up issue を起票、
または (2) `_may_expand_to_token_path` のメタ文字集合に `{` を追加し、
brace を含む語は「展開候補の直積を静的に生成できない = fail-closed」で扱う。
severity は「同一 PBI で閉じるか否か」の判断次第で critical へ上げてよい。

---

### R-003 / major / 保守性・可読性 / 誤検出（正当な操作を止める）

**新規誤検出を 11 件実測（PRE rc=0 → POST rc=2）。** plan §誤検出の実測は
5 ケースしか測っておらず、その 5 ケースが全て `*` 先頭 glob か `approvals-notes`
という「除外条件に当たるよう選ばれた」サンプルになっている。

| # | コマンド | PRE | POST | なぜ落ちるか |
|---|----------|-----|------|-------------|
| 1 | `cp src/c* /tmp/out/` | 0 | **2** | `c*` が `c3.json` に一致 |
| 2 | `mv m* archive/` | 0 | **2** | `m*` が `maintenance.json` に一致 |
| 3 | `cp public/m*.json dist/` | 0 | **2** | manifest.json / metadata.json の日常操作 |
| 4 | `cp p*.json build/` | 0 | **2** | `p*.json` が `parent-c3.json` に一致（package.json 等） |
| 5 | `sed -i s/a/b/ c[0-9].json` | 0 | **2** | `c[0-9].json` が `c3.json` に一致 |
| 6 | `find . -name '*.json' -print0 \| xargs -0 sed -i s/a/b/` | 0 | **2** | 下記 R-006（引用で先頭 glob 除外が無効化） |
| 7 | `cp '*.json' /tmp/` | 0 | **2** | 同上 |
| 8 | `mv approvals/*.md notes/` | 0 | **2** | (A) は拡張子を見ない（保護は `*.json` のみなのに） |
| 9 | `cp approvals/*.pdf /tmp/` | 0 | **2** | 同上。しかも **approvals から外へ出す読み方向** |
| 10 | `perl -i -pe s/x/y/ m*` | 0 | **2** | `m*` |
| 11 | `cp c?.json /tmp/` | 0 | **2** | `c?.json` |

対照（POST でも rc=0 のまま = 正しい）: `cp schemas/*.json /tmp/` /
`sed -i s/a/b/ docs/working/*/status.md` / `cp docs/img/c*.png site/` /
`install -m 644 c*.conf /usr/local/etc/` / `dd if=/dev/zero of=c*.img`。

**特に 8 / 9 は設計上の欠陥**。(A) は「`approvals/` 配下は `*/approvals/*.json` が
**全件**保護対象」という前提で書かれているが、実際に保護されているのは
**`.json` だけ**である。`approvals/*.md` / `approvals/*.pdf` は保護対象でないのに
block される。9 は `cp approvals/*.pdf /tmp/`＝**approvals から外へコピーする読み方向**
であり、token の書き込みですらない。

**推奨対応**:
- (A) を `basename の glob 展開結果が `.json` になりうる語` に限定する
  （少なくとも「拡張子部分に glob が掛かっていない かつ `.json` 以外で終わる」語は除外）。
- (B) は保護 basename との一致だけでなく**語の情報量**でガードする
  （例: glob を除いたリテラル部分が 3 文字未満なら「広すぎる」として block しない、
  あるいは block ではなく警告 + 明示確認へ落とす）。現状の `c*` / `m*` / `p*` は
  「保護 basename に一致しうる」だけで、実際に狙っているとは到底言えない。

---

### R-004 / major / パフォーマンス / PreToolUse 常時経路の実行時間劣化

**glob を含む語ごとに `$(printf … | tr -d …)`（サブシェル + 2 プロセス）を fork する**
ため、語数に対して線形にプロセス生成が増える。PreToolUse は**全 Bash 実行のたび**に走る。

実測（各 10 回の平均 ms/call・同一マシン）:

| コマンド | PRE | POST | 倍率 |
|----------|-----|------|------|
| `git status`（glob なし） | 58.4 | 55.1 | 1.0x |
| `cp a*.txt b*.txt c*.txt d*.txt e*.txt /tmp/` | 54.1 | **137.3** | 2.5x |
| `find . -name '*.ts' -o … \| xargs sed -i s/a/b/`（6 glob） | 49.5 | **294.5** | 5.9x |
| 合成 50 語（全語 glob） | 55.6 | **600.8** | 10.8x |
| 合成 200 語（全語 glob） | 49.1 | **2400.9** | 48.9x |
| 合成 800 語（全語 glob） | 52.5 | **9631.3** | **163.4x** |

**原因の特定（変異で証明）**: `_gm_b2=$(printf '%s' "$_gm_base" | tr -d "'\"")` を
`_gm_b2="$_gm_base"` に置換した mutant（下記 MX-1）で再測定:

| ケース | POST | MX-1（fork 除去） |
|--------|------|-------------------|
| 50 語 glob | 600.8 | **96.7** |
| 200 語 glob | 2400.9 | **116.1** |
| 800 語 glob | 9631.3 | **175.4** |

**glob を含まない語は高速パスで早期 return するため無劣化**（55ms）だが、
glob を含む語（先頭 glob 以外）1 つにつき 2 プロセスが増える。

**推奨対応**: 引用符除去をループ外へ出す（コマンド全体に対して 1 回 `tr` する）か、
`case`/パラメータ展開でループ内 fork を無くす。ループ内 `$( … | … )` は
常時発火 hook では採ってはいけないパターン。

---

### R-005 / minor / 保守性 / 変異が空振り: 引用符除去行に TC が 1 件も無い

自分で立てた変異 **MX-1**（call site を壊す変異 / diff-audit Phase 6 item 6）:

```
sed 's@^  _gm_b2=.*$@  _gm_b2="$_gm_base"@'   # t1115-basename-glob-unquoted 経路を無効化
→ ta-25 focused 実行: child rc=0 / FAIL 0 件 = **空振り（mutant 生存）**
```

`_gm_b2`（混在引用 `"c3.jso"*` 対応）を丸ごと殺しても**どの TC も落ちない**。
すなわちこの行は:

- 検出力が実証されていない（Phase 6 item 6 の「空振りは TC の欠陥」に該当）
- **R-004 の実行時間劣化の唯一の原因**
- **R-003 #6/#7（`find -name '*.json'`）の誤検出の原因**

つまり **未検証のコードが、性能劣化と誤検出の両方を単独で発生させている。**

**推奨対応**: `"c3.jso"*` 形式の正側 TC を追加して検出力を実証するか、
費用対効果が合わないなら削除する（削除すれば R-004 と R-003 #6/#7 が同時に消える）。

---

### R-006 / minor / セキュリティ / 先頭 glob 除外が「引用」で非対称に壊れる

`_gm_b2` の引用符除去により、**引用された先頭 glob は除外を外れて block される**が、
**引用されていない先頭 glob は通る**。方向が逆である:

```
rc=2 | cp '*.json' /tmp/                                   ← 引用あり → block（誤検出）
rc=0 | cp /tmp/evil docs/working/_maintenance/*.json       ← 引用なし → 通過（bypass / R-001）
```

セキュリティ上重要なのは後者（実際に展開される側）であり、前者
（`find -name '*.json'` のように **shell が展開しない**リテラル引数）は展開されない。
**実際に危険な方を通し、危険でない方を止めている。**

**推奨対応**: R-001 / R-005 の対応と併せて、除外条件を「引用の有無」ではなく
「その語が展開されうる位置にあるか」で判断するか、`_gm_b2` を廃止する。

---

### R-007 / minor / 保守性 / 変異が空振り: (A) の相対パス分岐に TC が無い

自分で立てた変異 **MX-3**:

```
sed 's@^    \*/approvals/\*|approvals/\*)@    */approvals/*)@'   # (A) の相対形 `approvals/*` を削除
→ ta-25 focused 実行: child rc=0 / FAIL 0 件 = **空振り（mutant 生存）**
```

一方でこの変異は**実挙動の穴を作る**:

```
POST : rc=2 | tee approvals/x9.jso*
MX-3 : rc=0 | tee approvals/x9.jso*     ← 穴が開くのに TC が気づかない
```

`case "$_gm_w" in */approvals/*|approvals/*)` の第 2 パターン（相対パス起点）を
通す TC が 1 件も無い。fixture は全て `docs/working/…/approvals/…` の絶対形。

**推奨対応**: 相対形 `approvals/c3.jso*` の正側 TC を 1 件追加する。

---

### R-008 / info / 保守性 / 変異が等価: 語分割の `>` は冗長

自分で立てた変異 **MX-2**（語分割の `tr` セットから `>` を除去）は
ta-25 で空振りしたが、**追加調査の結果これは等価変異**だった:

```
POST : rc=2 | echo x>docs/working/TASK-9/approvals/c3.jso*
MX-2 : rc=2 | echo x>docs/working/TASK-9/approvals/c3.jso*   ← 挙動同一
```

`_gm_base="${_gm_w##*/}"` が最後の `/` 以降を取るため、`x>docs/…/c3.jso*` を
1 語のまま渡しても basename は同じ `c3.jso*` になる。したがって
plan / コード comment の

> `>` を区切りに含めるのでリダイレクト先も同じ語として評価される

という**必要性の説明は実際には成り立っていない**（有害ではないが、
根拠として書かれている以上は不正確）。指摘は文書の正確性のみ。

---

### R-009 / minor / 保守性 / 残存クラス表が実際の到達先を過小に見せている

残存クラス表の記載:

| クラス | 例 | 理由 |
|--------|----|------|
| approvals 外の先頭 glob | `cp x foo/*3.json` | (B) から除外（誤検出抑制とのトレードオフ） |

例が `foo/*3.json` という**保護 token に到達しない架空パス**になっているため、
「無害な取りこぼし」に読める。実際の到達先は **`docs/working/_maintenance/maintenance.json`**
（R-001）であり、issue 本文の是正前実測表に載っている対象そのものである。

**推奨対応**: R-001 を修正するか、修正しないなら残存クラス表に
`docs/working/_maintenance/*.json` を**実パスで**明記し、severity と
follow-up issue 番号を添える。加えて brace expansion（R-002）を追加する。

---

### R-010 / info / 既存ギャップ（本 PBI 範囲外・記録のみ）

`_has_write_intent` に無い書き込み系動詞。PRE / POST とも rc=0（挙動不変）:

```
rc=0 | rm docs/working/TASK-9/approvals/*.json          （plan で自己申告済み）
rc=0 | rm -f docs/working/_maintenance/maintenance.json （自己申告済み）
rc=0 | chmod 000 docs/working/TASK-9/approvals/c3.json
rc=0 | gzip docs/working/_maintenance/maintenance.json  （原本が消える = 可用性）
rc=0 | touch docs/working/TASK-9/approvals/c3.json
rc=0 | mktemp docs/working/TASK-9/approvals/c3.json
rc=0 | OUT=docs/…/approvals/c3.jso*; cp /tmp/evil $OUT   ← ただし POST は rc=2（副作用で偶然 block）
```

`chmod` / `gzip` は内容偽造ではないが token の**可用性・整合性**に影響する。
本 PBI 範囲外だが、`rm` の follow-up と同じ issue にまとめる価値がある。

---

## 重点レビュー項目 別の判定

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| 1 | 誤検出（最重要） | **指摘あり** | R-003（11 件実測）/ R-006 |
| 2 | 広げたつもりで塞げていない経路 | **指摘あり** | R-001（critical）/ R-002 / R-009 |
| 3 | 変異の質（M-7〜M-11 / Phase 6 item 6〜8） | **一部指摘あり** | M-7〜M-11 の主張は成立（下記）。ただし自作変異 3 種のうち 2 種が空振り = R-005 / R-007 |
| 4 | `ta-61` extras 実行契約 | **問題なし**（補足あり） | 下記 |
| 5 | 非機能（PreToolUse 常時経路） | **指摘あり** | R-004（最大 163 倍） |
| 6 | 一般的な落とし穴 | **問題なし** | 下記 |

### 項目 4 の詳細 — `ta-61` extras 実行契約

実測:

```
sh tests/extras/ta-25-approval-token-guard.sh            → rc=0 / TA-25 standalone: 98 passed, 0 failed
PG_T61_NO_RECURSE=1 sh tests/extras/ta-61-extra-contract.sh → rc=0 / TA-61 standalone: 82 passed, 0 failed
harness 相当（PG_HARNESS_SOURCED=1 + FIXTURES_DIR/EXTRAS_DIR を与えて source）→ ta-25 起因の FAIL 0 件
```

**補足（契約カバレッジの限界 / info）**: `ta-25-approval-token-guard.sh` は
`ta-61` の `_pending_migration` 許可リスト（`tests/extras/ta-61-extra-contract.sh:95`）
に載っており、`_extra-contract.sh` を使わない legacy 形式のままである。
したがって **`ta-61` は `ta-25` の rc 契約（rc 0/1/2/3 レイヤ・force-fail probe 差分）を
検査していない**。「`ta-25` の改変が `ta-61` の契約を壊していないか」に対する答えは
「`ta-61` はそもそも `ta-25` を rc 契約の検査対象にしていないので壊れようがない」であり、
実効的な保証は上記の `ta-25` 直接実行（rc=0）でのみ得られている。
本 PBI が新たに壊した点は無いため指摘ではないが、
`ta-25` は mutation 実行で最も重い extras の 1 つでありながら契約検査の外にある、
という事実は handoff に残す価値がある。

### 項目 3 の詳細 — 実装担当の変異主張の検証

**M-8 の「(A) のみ無効化 → `c3.jso*` では生存し `approvals/x9.jso*` で kill」は成立する。**
論理検証:

- M-8 で (A) を never-match にすると `approvals/x9.jso*` は
  (B) でも拾えない（basename `x9.jso*` はどの保護 basename にもパターン一致しない）
  かつ `_is_token_path` にも掛からない（`*/approvals/*.json` は `.json` 終端を要求し、
  語は `jso*` で終わる）。→ T1115-TC-01 が FAIL。
- 一方 `c3.jso*` は (B) が拾うので T1115-TC-02 は PASS のまま。
- ta-25 実測: `[PASS] T1115-M-8 mutant killed by real TC (T1115-TC-01 FAILs)`。

→ **レーン内部の分類の切り分けが実証されている**（Phase 6 item 6 の
「レーン全体を落とす変異だけで済ませない」を満たす）。

**M-10 の「誤検出方向・負側 TC でしか殺せない」も成立する。**
M-10（先頭 glob ガード除去）は判定を **block 側にしか動かさない**ため、
rc=2 を期待する正側 TC の結果は原理的に変化しない。実測でも
`[PASS] T1115-M-10 mutant killed by real TC (T1115-TC-03 FAILs)` と
**負側 TC が kill 元**になっている。

**M-7 / M-9 / M-11 も個別に論理検証し、いずれも主張どおり。**

**item 7（負側 TC が本番経路を通っているか）: 問題なし。** 全 TC が
`.claude/settings.json` からの本番呼び出しと同じ stdin PreToolUse payload 経路で、
明示引数・テスト専用 env に偏っていない。

**item 8（絶対件数 assert）: 問題なし。** 新規 TC に `wc -l` / `grep -c` 由来の
件数等値比較は無い。

### 項目 6 の詳細

- **行番号アンカー**: 新規コード / TC / plan いずれも記号アンカー
  （`t1115-*` タグ / `#1115` / パターン文字列）で参照しており、行番号での参照は無い。
- **絶対件数の契約化**: 無し（上記 item 8）。
- **空振り AC**: R-005 / R-007 が該当（変異空振り 2 件）。
- **負側 TC の経路の偏り**: 無し。
- **Hardening Override 混入**: **0 件**（`git diff --name-only origin/main...HEAD` を
  HO 9 カテゴリで grep して該当なし。変更は `scripts/check-approval-token-write.sh` /
  `tests/extras/ta-25-*.sh` / `docs/working/TASK-1115/**` のみ）。

---

## 反証を試みて棄却した指摘候補

| 候補 | 棄却理由 |
|------|---------|
| 「`ta-25` standalone が rc=1 を返す = 契約違反」 | **自分の計測ミス**。コマンド末尾の `grep -c '\[FAIL\]'` が 0 件で rc=1 を返していた。クリーンに再実行して rc=0 / 98 passed 0 failed を確認 |
| 「語分割の `>` を落とすと穴が開く」（MX-2） | **等価変異**だった。basename 抽出が `##*/` なので `>` を区切りに入れなくても同じ basename が得られる。R-008 として文書の不正確性のみに格下げ |
| 「`sed -i 's/c*/x/' f.txt` のような正規表現が誤検出される」 | **棄却**。`${w##*/}` が `s/c*/x/` の最後の `/` 以降を取るため basename が `'` になり glob 判定に入らない。実測でも rc=0 |
| 「`cp docs/img/c*.png site/` が誤検出される」 | **棄却**。`c*.png` は `c3.json` にパターン一致しない。実測 rc=0 |
| 「`cp dist/* /tmp/` が誤検出される」 | **棄却**。先頭 glob 除外が効き rc=0（この除外自体は R-001 の bypass 源だが、誤検出抑制としては機能している） |
| 「brace 形式は `dash` で成立しないので無害」 | **棄却**。sh(macOS) / bash / zsh / ksh の 4 シェルで成立を実測。Claude Code の Bash ツールが使う shell では live |
| 「ta-61 harness 相当で `ta-53-doctor-prepush` が FAIL する」 | **棄却（自作ドライバの副作用）**。ta-53 は本 branch の変更対象外で、standalone 実行では PASS。最小ドライバが `run-tests.sh` の env を完全再現していないための artifact と判断し、branch の欠陥として計上しない |

---

## 監査表

| R-NNN | severity | status | reflected_in | notes |
|-------|----------|--------|--------------|-------|
| R-001 | critical | open | — | `_maintenance/` の先頭 glob bypass。(A) を保護ディレクトリ集合へ一般化 |
| R-002 | major | open | — | brace expansion（token 新規偽造可・PRE/POST 同一）。修正 or 残存クラス明記 + issue |
| R-003 | major | open | — | 新規誤検出 11 件。特に (A) の拡張子非考慮（`approvals/*.md` / `*.pdf`） |
| R-004 | major | open | — | ループ内 fork による最大 163 倍の実行時間劣化 |
| R-005 | minor | open | — | `_gm_b2` 行が変異空振り（未検証）かつ R-003/R-004 の原因 |
| R-006 | minor | open | — | 引用の有無で先頭 glob 除外が逆向きに壊れる |
| R-007 | minor | open | — | (A) 相対パス分岐 `approvals/*` が変異空振り（未検証） |
| R-008 | info | open | — | 語分割の `>` は等価。comment / plan の根拠記述が不正確 |
| R-009 | minor | open | — | 残存クラス表の例が実到達先（`_maintenance/`）を隠している |
| R-010 | info | open | — | `chmod` / `gzip` / `touch` の write-intent ギャップ（既存・範囲外） |

**critical: 1 件 / major: 3 件 / minor: 4 件 / info: 2 件。指摘ゼロではない。**


---

## 実装担当 disposition（TASK-1115 / 追記専用）

> V-3 REJECT を受けた再設計後の対応。**事実性は争っていない** — 指摘の実測は
> すべて再現した上で、修正 / 棄却 / 範囲外を判断している。
> 実測根拠: `evidence/v3-both-directions.txt`（pre / v1 / v2 の 3 版・両方向）/
> `evidence/v3-consistency.txt` / `evidence/v3-perf.txt` / `evidence/lane-scan.txt`。
> v1 = `5ccc1fe`（REJECT された版）、v2 = 本是正。

### 設計変更の要点（R-001 と R-003 の共通根への対応）

レビューアの指摘どおり、初版は **(A) をディレクトリで括り (B) を *形*（先頭に
glob があるか）で除外する**という **異なる軸の混在** だった。軸を揃え、
**保護対象を「ディレクトリ条件 × basename 条件」の組**で定義し直した。

| 組 | ディレクトリ条件 | basename 条件 |
|----|------------------|---------------|
| **P1** | 保護ディレクトリ（承認トークン置き場 **2 箇所**）配下 | **`.json` で終わりうる** |
| **P2** | 任意 | 保護名リテラルに一致しうる **かつ 1 文字を除いて pin する** |

除外は **形ではなく幅**（保護名をどれだけ pin するか）で行う。これにより
「1 文字だけ譲る狙い撃ち」は P2 が捕らえ（R-001）、「一致はしうるが狙っていない
広い語」は幅ガードで通す（R-003）。P1 は拡張子を見るようになり、保護対象でない
ファイル種別を止めなくなった（R-003 #8/#9）。

### disposition 一覧

| R-NNN | severity | disposition | 根拠（実測） |
|-------|----------|-------------|--------------|
| R-001 | critical | **fixed** | 保護ディレクトリを**集合**として定義。指摘の 4 ケースが `pre=0 / v1=0 → v2=2`。`T1115-TC-08` + 変異 `M-8`（集合から 2 つ目を落とす）で固定 |
| R-002 | major | **fixed（残存クラス化ではなく封鎖）** | `{` をメタ文字に追加し、`{` 以降を `*` へ正規化（`*` は brace 展開結果を包含するので安全側）。指摘の 2 ケースが `pre=0 / v1=0 → v2=2`。`T1115-TC-09` + 変異 `M-15` |
| R-003 | major | **fixed 9 / 11・rejected 2 / 11** | #1〜#4 / #6 / #7 / #8 / #9 / #10 が `v1=2 → v2=0`。#5 `c[0-9].json` と #11 `c?.json` は**棄却**（下記） |
| R-004 | major | **fixed** | fork を全廃（`$( … | tr … )` → パラメータ展開）し、さらに文字走査を**保護ディレクトリ配下 or 保護名にパターン一致した語だけ**に遅延。800 語 `v1=14684ms → v2=116ms`（`pre=126ms` = **劣化なし**） |
| R-005 | minor | **fixed** | 保護ディレクトリ**外**に置いた混在引用 fixture で `_strip_quotes` 経由の P2 のみを撃つ `T1115-TC-13` を追加。変異 `M-12`（引用除去を no-op 化）で kill |
| R-006 | minor | **fixed** | 引用の有無で軸が変わらないよう、除去後も**同じ幅ガード**を通す。`cp '*.json' /tmp/` と `find -name '*.json'` は `v1=2 → v2=0`、非引用側の bypass は P1 で閉鎖。`T1115-TC-12` |
| R-007 | minor | **fixed** | 保護ディレクトリの**相対形** fixture を追加（`T1115-TC-14`）。変異 `M-13`（相対形を落とす）で kill |
| R-008 | info | **一部棄却 + 記述是正** | `>` は**等価ではない**。リダイレクト先が `/` を含まない形では basename 抽出だけでは語を切り出せず、`>` を区切りから外すと取りこぼす。`T1115-TC-15` + 変異 `M-14` で非等価性を固定し、コメントの根拠記述もその形に書き換えた |
| R-009 | minor | **fixed** | 残存クラス表を実測ベースで全面改訂（plan / test-cases） |
| R-010 | info | **acknowledged（範囲外・記録のみ）** | `_has_write_intent` 側の既存ギャップであり #1115 で新規に生じたものではない。follow-up 候補として handoff / status に記載 |

### R-003 #5 / #11 を棄却する根拠

`c[0-9].json` / `c?.json` は「保護名を **1 文字だけ** 譲るパターン」であり、
**そのリテラル形は origin/main で既に block されている**（`evidence/v3-consistency.txt`）:

```
pre=2 v2=2  sed -i.bak -e s/a/b/ <protected-name>
pre=0 v2=2  sed -i.bak -e s/a/b/ c[0-9].json
pre=2 v2=2  cp <protected-name> /tmp/
pre=0 v2=2  cp c?.json /tmp/
pre=0 v2=0  cp schemas/*.json /tmp/
```

つまりこの 2 件は **新しい誤検出クラスではなく、既に受け入れられている block の
glob 形**である（`_is_token_path` は保護名を**ディレクトリ非依存**で保護しており、
`cp <protected-name> /tmp/` という読み方向すら既に rc=2）。ここを通すには
幅ガードを「全 pin」まで上げるしかなく、そうすると本 PBI の是正対象
（末尾 1 文字を崩す形）が丸ごと素通りするため、**両立しない**。

読み方向を通したいという論点自体は妥当だが、それは
**`_has_write_intent` に方向判定が無いという既存設計**の問題であり、
#1115 の範囲外（R-010 と同じ扱いで follow-up）。

### 変異の空振りに関する正直な記録

`# t1115-base-meta`（basename にメタ文字が無い語の早期 return）は
**性能ガードであって意味論を変えない**。この行を壊しても後続 P1 / P2 の
どちらにも該当しないため **等価変異**になる。したがって **TC を立てていない**
（立てても kill できないため）。この事実をコードコメントにも明記した。
