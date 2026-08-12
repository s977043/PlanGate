# C-2 外部レビュー結果 — TASK-1045

> Issue: [#1045](https://github.com/s977043/plangate/issues/1045)
> 対象: [`plan.md`](./plan.md) / [`todo.md`](./todo.md) / [`test-cases.md`](./test-cases.md)
> レビュー時点の plan head: `d594175`（C-1 指摘 W-1〜W-5 反映後）
> 実施方式: **2 レーン**（[`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis）

**本ファイルは追記専用**。指摘は `R-NNN` で採番し、計画本体への反映は **1 回だけ確定**する
（順序規約: 集約 → 1 回確定反映 → 簡易 C-1 → Human が `c3.json` 発行 → exec）。

## レーン別判定

| レーン | 判定 | 内訳 |
|---|---|---|
| **設計妥当性レーン** | **APPROVE** | major 1（R-001）/ minor 4（R-003・R-004・R-005・R-006） |
| **コードベース整合レーン** | **REJECT** | major 2（R-001・R-002）/ minor 2（R-007・R-008） |
| **統合判定** | **CONDITIONAL**（major を 1 回確定反映のうえ簡易 C-1 → Human C-3） | critical 0 / major 2 / minor 4 |

## 設計方向についての肯定的所見（INFO-1 / 反映不要）

整合レーンが **plan の正規化仕様を scratchpad の guard 複製へ実装して実走測定**した結果:

| 実測 | 結果 |
|---|---|
| 既存 suite | **47 passed / 0 failed**（**`T1023-TC-09` を含め全 PASS**） |
| 誤検知 / 退行マトリクス | **19 ケース中 19 一致（mismatch 0）** |
| `_t25_mutate` の `${5:-T1023}` 化 + 既存 7 呼び出しを 4 引数のまま実行 | **47 passed / 0 failed**・ラベルは `T1023-` のまま → **GC-4-B (a) は互換** |

**GC-3 の主張（`>` を token path 宛に限定すると `T1023-TC-09` が退行する）は正しく、
plan の方針は `T1023-TC-09` を壊さない**ことが実走で確認された。**設計方向の変更は不要。**

---

## 指摘一覧

### R-001 [major] RED ウィンドウの期待 FAIL 集合が未定義 + `SC-4` が誤発火する

- **レーン**: 設計妥当性 + コードベース整合（**両レーンが独立に同一結論へ到達**）
- **観点**: 保守性 / 拡張性

**症状（整合レーンが実走で再現）**:

```text
sh tests/extras/ta-25-approval-token-guard.sh       → EXIT=0 / 47 passed, 0 failed
（focused 群へ FAIL する TC を 1 件注入）             → EXIT=1 / 45 passed, 3 failed
```

```text
[FAIL] T1045-TC-01 …
[FAIL] T1023-TC-15pre  mutation baseline failed (rc=1) — mutation kill判定は無効
[FAIL] T1023-TC-17post restore run failed (rc=1)
[PASS] T1023-TC-15 / 16 / 17 / 17b / 17c / 17d / 17e   ← 既存 7 種は全 PASS
```

**機構**: `ta-25:621-627`（baseline）と `ta-25:676-684`（restore）は
**原本 guard で focused 群を子実行し「rc==0 かつ `[FAIL]` 0 件」を要求**する。
RED ウィンドウでは focused 群に FAIL する TC が存在するため、**この 2 件が必ず FAIL する**。

**plan 側の欠陥**:

1. Step 2 のチェックポイントは「既存 mutation 7 種が引き続き PASS」としか書いておらず、
   **RED 中もこの文言は成立してしまう**。実行エージェントは
   「チェックポイントは通ったが suite は exit 1 で見知らぬ FAIL が 2 件ある」状態に置かれる
2. **`SC-4` の発火条件が「`T1023-TC-15`〜`17e` のいずれかが FAIL」とラベル範囲で書かれている**。
   `TC-15pre` / `TC-17post` は `ta-25:611` のセクション見出しの内側にあるラベルであり、
   範囲表現では**包含されると読める** → **RED ウィンドウで `SC-4` が誤発火する**

**より悪い分岐（設計レーン）**: 「RED 中の mutation baseline FAIL は無視してよい」という
**運用学習が定着し、本物の baseline 破壊を見逃す**。**#874 と同型の感度低下**であり、
**plan 自身が R-7 で警戒している失敗様式**そのもの。

**是正（両レーン一致）**:

1. Step 2 のチェックポイントに**期待 FAIL 集合を列挙的に明記**
   （`T1045-TC-01`〜`03` + `TC-20` + `T1023-TC-15pre` + `T1023-TC-17post` = **6 件**）。
   これらが **`SC-1` / `SC-4` の対象外**であることを 1 行で宣言
2. **`SC-4` の発火条件をラベル範囲 → 7 ラベルの列挙**へ書き換え
   （`TC-15` / `16` / `17` / `17b` / `17c` / `17d` / `17e`。**`TC-15pre` / `TC-17post` を明示除外**）
3. **「`TC-15pre` / `TC-17post` が PASS へ戻ること」を Step 3（GREEN）完了後の別チェックポイント**として新設
4. **`A-4` の 🚩 から「全体 rc / 0 failed」判定を外し、`grep -q "[FAIL] T1023-…"` の
   ラベル単位判定**へ置き換える（ハーネスの kill 契約と同じ土俵にする）
5. 設計制約の言語化:
   **「focused 群には、無変異 guard 下で恒久的に FAIL する TC を置けない」**

### R-002 [major] 正規化ヘルパが `sed` を fail-open で持ち込む（GC-1 / GC-5 に抵触・AC 未カバー）

- **レーン**: コードベース整合（**実走で再現**）
- **観点**: セキュリティ

**症状**:

```text
payload = printf x > <TOKEN>
guard-with-failing-helper rc = 0   ← 2(block) でも 1 でもなく 0 = ALLOW / stderr 出力なし
```

**真の token 書き込みが無言で通過する。**

**機構**: 現行 `_has_write_intent()` は全ルールが
`printf … | grep -q … && return 0` の **AND-list** で、`grep` の非 0 は「不一致」という
**正しい意味**を持つ。plan の方式は `_wc_n=$(printf … | sed …)` という**コマンド置換の代入**。
呼び出し側は `check-approval-token-write.sh:136` の
`if _is_token_path "$_cmd" && _has_write_intent "$_cmd"; then` であり、
**`if` 条件内は `set -e` が無効**なので、**パイプライン失敗は「異常終了」ではなく
「書き込み意図なし」として静かに扱われる**。

**確立パターンからの逸脱**: 本 repo の外部依存はすべて `command -v` で守られ、不在は明示処理される
（`check-approval-token-write.sh:97` / `check-plan-hash.sh:35` /
`check-delegation-commit-boundary.sh:114`）。
**`sed` にだけこの守りが無い状態は、#1023 が塞いだ「parse fail-open」と同一クラス**。

**到達経路**: 整合レーンの追試では **stdin レーンからは未実証**
（`jq -r` が不正 UTF-8 を U+FFFD へサニタイズするため誘発できず、guard は rc=2 のまま）。
**ただし守るべきは「到達経路が今は無い」ではなく「弱める側へ倒れる形をそもそも作らない」**であり、
これは **GC-1 が最上位制約として掲げている内容**。

**変異でも検出されない**: 変異 (b) は `# t1045-file-redirect` の判定行しか壊さず、
`SC-6` も `TC-11`〜`15` / `19` の rc=0 しか見ていない。

**是正（追加すべき AC 候補 / TC 候補）**:

- **AC 候補 A**: `_strip_nonwrite_redirects()` の失敗を **fail-closed** に。
  `_norm=$(…) || _norm="$_wc"`（**正規化できなければ元文字列で判定 = block 維持**）を
  **Step 3 の必須実装事項**として明記
- **AC 候補 B**: 起動時に `command -v sed …` を追加し、**`jq` と同じ fail-closed 契約に揃える**
- **TC 候補**: **`T1023-TC-05`（jq 不在 PATH）と同型の `sed` 不在 PATH TC** を追加し `rc=2` を要求。
  **この TC は上記実装が無ければ `rc=0` で落ちるため検出力が実証できる**

### R-003 [minor] `RT-2` の発火条件が実質判定不能

- **レーン**: 設計妥当性
- 「同一の判定コードを共有」は **POSIX `sh` の独立スクリプト群では発火しない**（構造上ほぼ常に偽）
- **是正**: 「(a) 他の稼働ガードが本ガードを invoke / source、または
  (b) 本ガードの複製が `.claude/settings*.json` に実配線」へ書き換え
- **実測では (a)(b) とも該当なし**（`scripts/hooks/check-approval-token-write.sh` は
  `origin/main` に**不在**）

### R-004 [minor] `Q-1` に「引き下げると何を失うか」が無い

- **レーン**: 設計妥当性
- **是正**: `critical` → `high-risk` の実質差分は **V-4 が落ちること**のみ。
  「承認境界（`lite_eligible=false` / 同期 C-3 / autonomous 不可）は不変」と 1 行

### R-005 [minor] `SC-6` の列挙に `T1045-TC-07` が無い

- **レーン**: 設計妥当性
- **併記回避は `/dev/null` 除外を入れる本 PBI で最も直接的な弱体化シナリオ**（AC-07 の中核）
- **是正**: `SC-6` に `T1045-TC-07 (1)` を追加

### R-006 [minor] fd クローズ（`N>&-`）除外に対応する AC が無い

- **レーン**: 設計妥当性
- Goal は `N>&-` を除外対象に含むが **AC-03 の文面は「fd 複製」止まり**。
  **除外面（危険な方向）が AC の外側で拡張**されており、C-4 レビュアーが承認範囲を判別できない
- **是正**: AC-03 の解釈を「fd 複製**および fd クローズ**」へ広げる旨を plan で明記
  （`pbi-input.md` は確定物のため編集せず、plan 側で AC-03 の適用範囲を宣言する）

### R-007 [minor] `LC_ALL` の固定が `GC-6` に無い

- **レーン**: コードベース整合
- BSD `sed` は UTF-8 locale 下で不正バイト列に `RE error: illegal byte sequence`（実測 rc=1）
- **`GC-6` は方言のみ対象で locale を見ていない**
- **是正**: 正規化パイプラインを **`LC_ALL=C` 固定**で実行することを
  `GC-6` と Step 1b の実験条件に明記（**R-002 の緩和にもなる**）

### R-008 [minor] `apply-task-0123-patches.sh` の複製導線は実在

- **レーン**: コードベース整合
- 同 script（`67-88` 行）が `scripts/check-approval-token-write.sh` →
  `scripts/hooks/…` へ `cp` し、**既存時はスキップして更新しない**
- `origin/main` に当該ファイルは無く実害ゼロだが、
  **過去に適用した環境には修正が伝播しない古い fork が残る**
- **是正**: **`GC-7` は維持したまま handoff の既知課題へ 1 行**（follow-up issue 起票が適切）

---

## 情報（反映不要）

| ID | 内容 |
|---|---|
| **INFO-1** | 設計方向の実走裏付け（上記§）。**設計方向の変更は不要** |
| **i-1** | plan の `U-5` は `settings.example.json:72,81` のみを根拠にしているが、**稼働中の `.claude/settings.json:102,111` も `scripts/` 直下を直接呼んでおり `scripts/hooks/` 側の複製は存在しない**ことを両レーンが実測。「再適用不要」は本環境で成立。A-1 の調査ログに稼働側の実測も 1 行残すと handoff の説得力が上がる |

## 自己申告 3 点への C-2 判定

| 申告 | 判定 |
|---|---|
| `TC-20` を focused 群に含めた是非 | **維持を推奨（絞るな）**。`3>&-` は**除外を固定する唯一の TC**で、この挙動は AC-01〜03 のどれにも文言上含まれていない（→ R-006）。kill 判定は `ta-25:655` のラベル特定なので **focused が太っても既存 7 種は壊れない**（GC-4-A の副作用分析は正しい）。連鎖 FAIL の想定は未実証だが**外れても契約は壊れない**（契約上の kill 対象は 2 件、残り 5 件は観測項目） |
| `&>` を除外しない（U-2） | **妥当。既定のままで良い**。「未知の残存」ではなく「**既知・固定・記録済みの残存**」 |
| `RT-2` の境界 | **不安は正当**（→ R-003） |

---

## 監査表（追記専用 / squash・rebase 耐性）

| R-NNN | severity | lane | status | reflected_in | notes |
|---|---|---|---|---|---|
| R-001 | major | 設計 + 整合 | reflected | `docs/1045-plan` C-2 反映 commit | Step 2 期待 FAIL 集合 6 件 / `SC-4` 7 ラベル列挙 / Step 3 復帰 CP / `A-4` ラベル単位判定 / GC-4-C 新設 |
| R-002 | major | 整合 | reflected | 同上 | `GC-8` 新設（fail-closed 契約）/ Step 3 必須実装 2 件 / `T1045-TC-22` 追加 / `SC-9` 追加 |
| R-003 | minor | 設計 | reflected | 同上 | `RT-2` を (a) invoke・source / (b) settings 実配線 の 2 条件へ |
| R-004 | minor | 設計 | reflected | 同上 | `Q-1` に「失うのは V-4 のみ・承認境界は不変」を追記 |
| R-005 | minor | 設計 | reflected | 同上 | `SC-6` に `T1045-TC-07 (1)` を追加 |
| R-006 | minor | 設計 | reflected | 同上 | plan で AC-03 の適用範囲を「fd 複製 + fd クローズ」と宣言（`pbi-input.md` は不編集） |
| R-007 | minor | 整合 | reflected | 同上 | `GC-6` に `LC_ALL=C` 固定 / Step 1b の実験条件へ明記 |
| R-008 | minor | 整合 | reflected | 同上 | handoff 既知課題 + follow-up issue を `A-14` の必須記載事項へ |
| INFO-1 | info | 整合 | acknowledged | — | 設計方向の変更不要。反映不要 |
| i-1 | info | 設計 + 整合 | reflected | 同上 | `A-1` の調査項目へ稼働 settings の実測を 1 行追加 |

**Round 1 の集計**: critical 0 / major 2 / minor 6・info 2。

**反映状況の実測**: 監査表の `status` 列は `reflected` 8 件 + `acknowledged` 1 件 +
`reflected`（i-1）1 件の計 10 行で、**未反映を表す status の行は 0 件**
（`grep -c 'reflected' review-external.md` と行数の突合で確認）。
`R-001`〜`R-008` の 8 件すべてを **1 回で確定反映済み**。

---

## C-2 Round 2（R-001〜R-008 反映後の再レビュー）

> 対象 head: `e3b4a3e` / plan=`sha256:d859a66c…`
> **上記 Round 1 の記述（R-001〜R-008 / 監査表の該当行）は 1 文字も変更していない**（追記専用）。

## レーン別判定（Round 2）

| レーン | 判定 | 内訳 |
|---|---|---|
| **設計妥当性レーン** | **APPROVE** | major 1（R-009）/ minor 2（R-011・R-012） |
| **コードベース整合レーン** | **REJECT** | major 1（R-009）/ minor 1（R-010） |
| **統合判定** | **CONDITIONAL**（R-009 / R-010 を確定反映のうえ簡易 C-1 → Human C-3） | critical 0 / major 1 / minor 2 / info 1 |

**両レーンが独立に R-009 へ到達**し、整合レーンが**組合せ行列を実走して証明**した。

## Round 1 指摘の解消確認（再対応不要 / 反映不要）

| 項目 | 確認内容 |
|---|---|
| **R-001** | `GC-4-C` の期待 FAIL 6 件が**整合レーンの実走結果と機構レベルで一致**。`SC-4` のラベル列挙化 / Step 3 の復帰 CP / `A-4` のラベル単位判定 / `R-13` すべて反映済み |
| **R-002** | `GC-8` は原因（**`if` 条件内で `set -e` 無効**）まで正確。「到達経路は未実証」も**追試どおりに正しく留保**（誇張なし） |
| **R-003〜R-008** | すべて解消 |
| `SC-4` の 7 ラベル | `ta-25` の `_t25_mutate` 呼び出し 7 件の mid を機械抽出した結果と**完全一致** |
| 旧表記 `TC-01〜07` | plan / test-cases / todo の 3 ファイルで **0 hits** |
| AC / TC 検算 | AC 13 / TC 22・連番で全出現 / 双方向 orphan 0 / focused 7 + 通常 15 |

> 設計レーンが Round 1 の自分の見落とし（`ta-25:621-626` だけ読み `:676-684` の restore 側を
> 見ていなかった）を認め、整合レーンの訂正を「私の指摘より 1 件広い範囲で正しい」と受け入れている。

## 前 round の未実測 2 点は**両方とも実走で成立**（代案不要 / INFO-2）

| 未実測点（筆者申告） | 実走結果 |
|---|---|
| `T1045-TC-22` の実装形（`sed` だけ外した PATH が POSIX sh の内部処理を壊さないか） | **成立**。`cat`/`grep`/`sh`/`jq` を symlink した PATH で **rc=2** / `BLOCK (parse-unknown): sed not available`。`printf` / `case` / `command -v` / `[` は builtin で外部 `sed` に非依存。guard が外部起動するのは `cat` / `jq` / `grep` / `sed` のみ |
| `GC-8 (ii)` が `T1023-TC-05`（jq 不在）を壊さないか | **壊さない**。`ta-25:143` の assert は `[ "$_t25_rc" = "2" ] && grep -q 'parse-unknown'` であり **「jq」という語は assert していない**。`jq` も `sed` も無い PATH → rc=2 / `sed not available` → assert PASS。**実ハーネスでも確認**: GC-8 (i)(ii)(iii) 適用済み guard で full suite **`47 passed, 0 failed` / EXIT=0** |

---

## 指摘一覧（Round 2）

### R-009 [major] `T1045-TC-22` は `GC-8` の (ii) しか撃っておらず、**(i) が欠けた実装を素通しする**

- **レーン**: 設計妥当性 + コードベース整合（**両レーンが独立に到達**）
- **観点**: セキュリティ / 保守性

**組合せ行列（整合レーンが実走。筆者も独立に再現）**:

| 実装 | `sed` **不在**（= TC-22 の入力） | `sed` **存在するが実行時に失敗** |
|---|---|---|
| (i)+(ii)+(iii) 全部 | rc=2 fail-closed | **rc=2 fail-closed** |
| **(ii)+(iii) のみ（(i) 欠落）** | **rc=2 → TC-22 は PASS** | **rc=0 ＝ FAIL-OPEN** |
| (i)+(iii) のみ | rc=2 | rc=2 |
| どちらも無し（Round 1 の形） | rc=0 | rc=0 |

**決定的な実測**:

```text
=== does T1045-TC-22 (sed ABSENT) detect the missing-(i) build? ===
  TC-22 form vs no_i build: rc=2 -> TC-22 PASSES (hole NOT detected)
```

**(i) を落とした build に TC-22 を当てると rc=2 で PASS する。**
したがって **`SC-9`（TC-22 が FAIL したら停止）は発火しない**。

**over-claim**: `test-cases.md:181` は「**`sed` 不在 / 失敗 で `rc=2`。`T1045-TC-22`**」と書いており、
**TC-22 が実際にはカバーしていない「失敗」ブランチまで担保したと明記**している。

**なぜ重大か**: **`GC-8` 自身が「変異では検出されないので専用 TC が必要」と正しく述べているのに、
その専用 TC が要件 3 件中 1 件しか撃っていない。**

> 設計レーン: **plan が最も警戒している #874 型の失敗様式そのもの（TC はあるが検出力が無い）が、
> #874 対策として追加された節の中で再発している構図**
>
> 整合レーン: repo の既往教訓「**1 原因が複数箇所を壊すと片側だけ直して AC が PASS**」そのもの。
> 実装者が (i) を書き忘れても **TC-22 は緑、`SC-9` も沈黙、変異 (b) も無反応**で、
> `AC-04` は PASS のまま通過する

**是正（両レーンの案が一致・設計変更不要）**:

1. **`T1045-TC-22b` を通常群へ追加**: **`sed` が存在するが必ず失敗する PATH** で `rc=2` を要求
   - **レシピは実証済み**: 一時 PATH に `cat`/`grep`/`sh`/`jq` を symlink し、
     そこへ **`#!/bin/sh` + `exit 1` の `sed` シム**を置いて `printf x > <TOKEN>` を投げる
   - **(i) が無ければ `rc=0` で落ちる**ので、**これで初めて (i) の検出力が実証される**
2. **`SC-9` の発火条件を「`T1045-TC-22` または `TC-22b` が FAIL」へ拡張**
3. **`test-cases.md:181` の「不在 / 失敗」を TC-22（不在）と TC-22b（失敗）へ分けて紐付ける**

**AC 紐付けは TC-22 と同じ `AC-04` で orphan は増えない**（TC 総数 22 → 23、focused 7 + 通常 16）。

> 設計レーン補足: **TC-22 も stub 方式へ寄せてよい**。**少なくとも TC-22 は stderr に
> 「`sed` 起因である」根拠（`parse-unknown` の reason 文字列）まで assert する**ことを推奨。
> 現状は理由を assert していないため、**外部依存を 1 つ列挙し漏らすと別の `parse-unknown` で
> rc=2 になり偽 PASS**になる。

### R-010 [minor だが実装を壊す] `command -v sed` の挿入位置が未指定。上部に置くと `rc=127`（＝**非 block**）

- **レーン**: コードベース整合

plan は「guard **起動時に**」としか書いていないが、
**`_parse_unknown()` の定義は `check-approval-token-write.sh:76-81`**（**筆者も実測確認**）。

「起動時」を素直に読んで **bypass ブロック直後（`:32` 付近＝関数定義より前）** に置くと:

```text
guard_gc8_early.sh  (sed check placed BEFORE _parse_unknown definition)
  TC-22 form → rc=127 (exp 2) *** MISMATCH ***
  TC-05 form → rc=127 / assert grep -q 'parse-unknown' : FAIL   ← TC-05 も巻き添えで落ちる
```

**`_parse_unknown` が未定義で `command not found` → `rc=127`。
127 は PreToolUse の block（2）ではないので非 block。**

**是正**: `GC-8` の 2 に **「`_parse_unknown()` 定義の後（`:81` 以降）かつ
`PLANGATE_SKIP_TOKEN_GUARD` bypass ブロックの後、`# --- 1) target:` の直前に置く」**
と位置を 1 文で固定（**この位置は full suite 47/0 で実証済み**）。

### R-011 [minor] 正本と写しが逆転している

- **レーン**: 設計妥当性（m-5）

| 箇所 | 状態 |
|---|---|
| **`plan.md:620` の `SC-1` 行** | 「Step 1 の baseline が `0 failed` でない」のまま。**`GC-4-C` と Step 2 CP が言う「RED 中に期待 FAIL 6 件以外が FAIL したら SC-1 発火」という第 2 の発火条件が正本の表に無い** |
| **`todo.md` の `SC-1` 行** | **入っている**（＝正本と写しが逆転） |
| **`todo.md` の `RT-2` 行** | **R-003 前の旧文言**（「同一判定コードを共有していると判明」）のまま。plan 側の (a)/(b) 判定可能化と食い違う |

**SC / RT 表だけを見て動く実行者（まさに todo を手元に置く exec エージェント）に、
R-001・R-003 の是正効果が届かない。**

**是正**: `plan.md` の `SC-1` 行に「**または RED ウィンドウ（GC-4-C）で期待 FAIL 6 件以外が FAIL**」を
追記し、`todo.md` の `RT-2` 行を **(a) invoke/source / (b) settings 実配線**へ差し替え（各 1 行）。

### R-012 [info] `GC-8` の挙動変更を handoff の既知課題へ

- **レーン**: 設計妥当性

`N>&-` には「AC の適用範囲宣言」を新設した一方、**`GC-8` は宣言なしで `AC-04` に相乗り**している。
**方向が「厳格化」なので承認範囲上の危険は無く是正不要**だが、
**`command -v sed` は `sed` 不在環境で token パス関連の全 Bash 呼び出しを block する挙動変更**でもあるため、
**handoff の既知課題に 1 行**あると C-4 / 運用側に親切
（`jq` と同契約なので新規クラスではない）。

---

## 監査表（Round 2 / 追記専用）

| R-NNN | severity | lane | status | reflected_in | notes |
|---|---|---|---|---|---|
| R-009 | major | 設計 + 整合 | reflected | `docs/1045-plan` C-2 R2 反映 commit | `T1045-TC-22b` 追加（stub 方式で (i) を撃つ）/ `SC-9` を TC-22 **または** TC-22b へ拡張 / `GC-8` に要件↔TC 対応表 / test-cases:181 の over-claim 解消 / TC-22・22b とも reason 文字列を assert |
| R-010 | minor | 整合 | reflected | 同上 | `GC-8` の 2 に挿入位置を固定（`_parse_unknown()` 定義後 `:81` 以降・`# --- 1) target:` 直前）。`rc=127` 非 block の失敗様式を明記 |
| R-011 | minor | 設計 | reflected | 同上 | `plan.md` `SC-1` に第 2 発火条件を追記 / `todo.md` `RT-2` を (a)(b) へ差し替え |
| R-012 | info | 設計 | reflected | 同上 | `A-14` handoff 必須記載へ「`sed` 不在環境での挙動変更」を追加 |
| INFO-2 | info | 整合 | acknowledged | — | 前 round の未実測 2 点が実走で成立。代案不要 |

**Round 2 の集計**: critical 0 / major 1 / minor 2 / info 1。

**反映状況の実測**: Round 2 監査表 5 行の `status` は `reflected` 4 / `acknowledged` 1。
**未反映を表す status の行は 0 件。**
`R-009`〜`R-012` の 4 件すべてを **1 回で確定反映済み**。

---

## C-2 Round 3（R-009〜R-012 反映後の再レビュー）

> 対象 head: `4c4fc53` / plan=`sha256:c7b3bf70…`
> **Round 1・Round 2 の記述（R-001〜R-012 / 監査表の該当行）は 1 文字も変更していない**（追記専用）。

### レーン別判定（Round 3）

| レーン | 判定 | 内訳 |
|---|---|---|
| **設計妥当性レーン** | **`C2-VERDICT: APPROVE`** | major 1（R-013 / M-3）+ info 1 |
| **コードベース整合レーン** | **`C2-VERDICT: APPROVE`** | 同一事象を MINOR-4 として検出 |
| **統合判定** | **APPROVE**（R-013 を確定反映すれば C-3 へ渡せる） | critical 0 / major 1 / minor 0 / info 1 |

**R-009〜R-012 の反映は全件受理。** severity は両レーンで割れた（設計 = major / 整合 = minor）が
**是正内容は完全に一致**しており、**設計レーンの評価（major）を採る**。

### 棄却判断（`TC-22` を stub 方式へ寄せない）は両レーンに支持された

> 設計レーン（**補足を出した当人**）: **maker の棄却理由が正しく、私の補足が誤りでした。**
> Round 2 で (i) と (ii) を 1 本の TC に畳めると考えたが、**両者は入力条件
> （`sed` 不在 / `sed` 存在かつ失敗）が排他**なので原理的に 1 本では撃てない。
> **2 本立ては私が提案した形より厳密**

整合レーンも実走で「**シム PATH では FULL build と NO-(ii) build が出力レベルで区別不能**」を示し、
棄却を裏付けた。

### Round 2 指摘の解消確認（再対応不要）

**M-2 / MAJOR-3**（要件↔TC 表・組合せ行列・`SC-9` 拡張・over-claim 分離）/
**m-5 / R-011**（`SC-1` の 2 発火条件 + 「本表が正本であり todo はその写し」/ `RT-2` 差し替え）/
**R-010**（挿入位置。**設計レーンが行番号を独立実測して一致**: bypass `:32-35` /
`_parse_unknown()` `:76-81` / `# --- 1) target:` `:83`）/ **R-012** — **すべて解消**。

**AC / TC の検算も両レーンが独立実施**:
**AC 13 / TC 23（`TC-01`〜`22` + `TC-22b`）/ 双方向 orphan 0 / focused 7 + 通常 16**、
件数表記の 4 箇所同期も一致。

設計レーンは「**(ii) が load-bearing でない**」ことの Mode / AC への影響も評価し、
**「影響なし・(ii) を必須要件に残す判断は妥当**（`jq` と同契約に揃えるのは `GC-5` に沿った
defense-in-depth で診断品質も上がる）」と判定した。

---

### R-013 [major] `GC-8` の reason assert 指示が `TC-22b` の実測経路と正面から矛盾している

- **レーン**: 設計妥当性（M-3 / major）+ コードベース整合（MINOR-4）
- **観点**: 保守性 / セキュリティ

**症状**: `plan.md:243-247` は

```text
**reason 文字列の assert（両 TC 共通・R-009 設計レーン補足）**:
（`sed not available` 等の reason 文字列）まで assert する**。
```

と **両 TC 共通で `sed` 起因の reason を assert せよ**と指示している。
しかし整合レーンが実走で確定した **`TC-22b` の正しい（FULL 実装での）経路**は:

```text
rc=2  route=normal-block
detail: 検出: Bash command writes token path: printf x > <TOKEN>
```

**要件 (i) のフォールバック `_wc_n=$(…) || _wc_n="$_wc"` は設計上サイレント**であり、
**`sed` 起因の reason はどこにも出ない**。

**さらに実測経路が文書に未記録**: `test-cases.md` を grep したところ
**`normal-block` / `route=` の記載は 0 件**（**筆者も再実測して 0 件を確認**）。つまり
**正本が誤った assert 対象を積極的に指示しており、`TC-22b` の正しい期待 reason はどこにも無い**。

**筆者による独立実走（FULL 実装 (i)+(ii)+(iii) のプロトタイプ）**:

| 入力 | rc | stderr | `sed not available` | `writes token path` | `parse-unknown` |
|---|---|---|---|---|---|
| **TC-22**（`sed` 不在） | 2 | `BLOCK (parse-unknown): sed not available` | **YES** | no | **YES** |
| **TC-22b**（`sed` 存在するが失敗） | 2 | `BLOCK: … 検出: Bash command writes token path: …` | **no** | **YES** | **no** |

→ **C-2 の指摘どおり。現行の `GC-8` に素直に従うと `TC-22b` は必ず FAIL する。**

**なぜ major か（設計レーンの評価を採用）**:

> **未指定なら実装者の裁量だが、現状は正本が誤った assert 対象を積極的に指示している。
> 対称性から `parse-unknown` を書く以前に、素直に `GC-8` に従うだけで踏む**

**帰結**:

- **`TC-22b` の FAIL は `SC-9` に配線され、`SC-9` は critical / 即停止**
  → **正しい実装が critical 停止を引き起こす**（`R-13` と同じ「正しいのに落ちる」失敗様式が、
  **今度は最上位の停止条件で再演**）
- **実行者が停止を「誤発火」と判断して `SC-9` を緩めると、本物の fail-open を見逃す経路が開く**。
  `SC-9` は **`R-12`（critical）の唯一の機械的担保**であり、ここの感度を落とすのは最も避けたい
- **C-3 承認後は `plan_hash` が凍結**され、正本の矛盾は「exec 時の逸脱記録」としてしか処理できない

**是正（両レーンの案が一致・plan 1 文 + test-cases 2 セル・設計変更ゼロ）**:

| TC | 撃つ要件 | 期待 assert |
|---|---|---|
| **`TC-22`** | (ii) | `rc==2` **かつ** stderr に **`sed not available`** を含む |
| **`TC-22b`** | (i) | `rc==2` **かつ** stderr に **`Bash command writes token path`** を含み、**かつ `parse-unknown` を含まない** |

**`TC-22b` の「`parse-unknown` を含まない」は必須**:

> これが無いと、**外部依存の列挙漏れ等で別経路の `parse-unknown` に落ちても
> `rc=2` + 文字列一致で偽 PASS** になり、**(i) の検出力という `TC-22b` 唯一の存在理由が失われる**

**この二重条件はリポジトリ内の既存パターン**（**筆者も `ta-25:118` を実測確認**）:

```sh
if [ "$_t25_rc" = "2" ] && grep -q 'file_path=' "$T25_ERR" && ! grep -q 'parse-unknown' "$T25_ERR"; then
```

**新規発明ではないのでそのまま踏襲する。**

### INFO-3 [info] `SC-9` の説明欄に原因切り分けの 1 行を（R-013 のついでに）

`SC-9` は `TC-22` / `TC-22b` どちらの FAIL も一律「**fail-open（GC-1 違反 = critical）**」と
説明しているが、**(ii) は安全性では load-bearing ではない**
（整合レーンが「(i)+(iii) のみ」の build を測り、`sed` 不在・シムとも `rc=2` を確認）。

> **`TC-22` 単独の FAIL は「fail-open」ではなく「診断契約の破壊」**。
> `SC-9` の説明欄に「**TC-22 の FAIL は (ii) の契約破壊、TC-22b の FAIL が真の fail-open**」と
> 1 行あると、**停止時の原因切り分けが速くなる**

---

### 監査表（Round 3 / 追記専用）

| R-NNN | severity | lane | status | reflected_in | notes |
|---|---|---|---|---|---|
| R-013 | major | 設計（M-3）+ 整合（MINOR-4） | reflected | `docs/1045-plan` C-2 R3 反映 commit | `GC-8` の「両 TC 共通」を「**期待 reason は TC ごとに異なる**」へ改訂 + 実測経路表（`route`）を明記 / `test-cases.md` の `TC-22`・`TC-22b` 期待結果セルを確定（`TC-22b` は `parse-unknown` を**含まない**の二重条件・`ta-25:118` 踏襲）/ `todo` A-5a の CP も同期 |
| INFO-3 | info | 設計 | reflected | 同上 | `SC-9` 説明欄へ「TC-22 = 診断契約の破壊 / TC-22b = 真の fail-open」を 1 行追加 |

**Round 3 の集計**: critical 0 / major 1 / minor 0 / info 1。

**反映状況の実測**: Round 3 監査表 2 行の `status` はいずれも `reflected`。
**未反映を表す status の行は 0 件。**
`R-013` と `INFO-3` を **1 回で確定反映済み**。

---

## River Review（PR 作成前レビュー / R-014〜R-018）

> 対象 head: `5847e69` / plan=`sha256:744b3c4f…`
> **判定: PR 作成「可」**。ただし **`plan_hash` を変えずに直せる major 1 件**あり。
> **Round 1〜3 の記述（R-001〜R-013 / INFO-3 / 各監査表）は 1 文字も変更していない**（追記専用）。

### 大前提: 本ラウンドの是正は `plan_hash` に影響しない

**EH-3（`scripts/hooks/check-plan-hash.sh:89`）の照合対象は
`*/plan.md|plan.md)` = `plan.md` 単体**（**筆者も実測確認**）。
したがって **`todo.md` / `test-cases.md` / `INDEX.md` / `decision-log.jsonl` /
`review-*.md` / `current-state.md` をいくら直しても
`plan_hash = sha256:744b3c4f…` は不変**であり、**C-3 のやり直しも再ハッシュも不要**。

**R-014〜R-018 の是正は `plan.md` を一切編集していない。**

### R-014 [major] `TC-22` / `TC-22b` を `ta-25` へ追加する owner がどのタスクにも無い

- **観点**: 保守性 / セキュリティ

**実測**: `todo.md` 全体で **`TC-22` を「追加せよ」と指示する行は存在しない**。

```text
todo.md:209   （**`TC-22` / `TC-22b` は A-5a で先に追加済み**。…）  ← 括弧書きの前提のみ
todo.md:22    SC-9 …（参照のみ）
todo.md:193 / :315   … 両方 PASS（完了条件のみ）
```

**`A-5a`（`todo.md:154-173`）の「内容」は guard 本体の実装のみ**で、テスト追加の指示が無い
（🚩 は「**スクラッチで確認**」）。一方 **`plan.md:465` は Step 2（RED）で
「… + `TC-22` + `TC-22b` は通常群へ追加」**と書いており、**plan と todo が矛盾**している。
todo 側の分解（A-2/A-3 / A-7 / A-8 / A-8b / A-9/A-10）では
**`TC-22` / `TC-22b` が誰にも割り当てられていない**。

**Impact**: `TC-22b` は **plan 自身が「`R-12`（critical / fail-open）の唯一の機械的担保」
「(i) の検出力を担う唯一の TC」と宣言**しているもの。

> exec エージェントが A-7 の括弧書きを信じると、**(i) の検出はスクラッチでの 1 回限りの目視に退化し、
> コミットされたスイートには残らない**。これは**本 plan が最も警戒している #874 型
> （「TC はあるのに検出力が無い」）の、しかも対策節そのものでの再発**

**同クラスの派生**: `plan.md:465` は **`TC-07` / `TC-17` も Step 2 で `ta-25` へ追加**と書くが、
**todo `A-11`（`:257-264`）/ `A-12` は `rollback: 不要（読み取り・記録のみ）` = ファイル変更なしの
evidence タスク**として定義されている（**筆者も実測確認**）。
**`SC-6` は `T1045-TC-07 (1)` の rc をスイート条件として参照**している（`plan.md:688`）ので、
**`TC-07` が `ta-25` に入らないと GC-1 の機械担保が 1 本細る**。

**是正（`todo.md` のみ）**: **plan の Step 2 記述と一致する側に寄せ**、
**通常群 16 件すべてに owner を割り当てる**（`A-5a` に `TC-22` / `TC-22b`、
`A-7` に残余 `TC-07` / `TC-16` / `TC-17` / `TC-18` を追加）。

### R-015 [minor] `INDEX.md` / `decision-log.jsonl` が Plan Package に含まれていない

**実測**（`git ls-tree origin/main` / **筆者も再確認**）:

```text
TASK-1044（main）: INDEX.md  current-state.md  decision-log.jsonl  pbi-input.md  plan.md  review-self.md  test-cases.md  todo.md
TASK-1045（現状）:            current-state.md                      pbi-input.md  plan.md  review-external.md  review-self.md  test-cases.md  todo.md
```

`.claude/rules/working-context.md` は `INDEX.md` =「B: plan 完了時に自動生成」、
`decision-log.jsonl` =「B〜: plan 完了時に初期化」と定めており、
**直前の同型 PBI TASK-1044 は両方を含む**。

**Impact**: **L0 の読み込みプロトコル（`INDEX.md` → `current-state.md`）が旧形式フォールバックに落ちる。**
SC / RT 発火時の追記先（append-only 監査証跡）が exec 時に新規作成扱いになる。

**是正**: **`INDEX.md` と空初期化の `decision-log.jsonl` を追加**（**`plan.md` 不変 = `plan_hash` 影響なし**）。

### R-016 [minor] `GC-8` の要件 (iii)（`LC_ALL=C`）だけ欠落を落とせる検査が無い

`plan.md:230` の要件↔検出 TC 表は (iii) の「撃つ TC」を
**「Step 1b の方言 / locale 実験」**としているが、**Step 1b が回すのは scratchpad の
プロトタイプであって出荷される guard 本体ではない**。
一方 `plan.md:165` は「**GC-8 の 3 要件はすべて必須**」、`todo.md:314` の完了条件は
「**GC-8 の 3 件が実装され TC-22/22b が両方 PASS**」と書く。
→ **(iii) を実装し忘れても `TC-22` も `TC-22b` も `SC-9` も緑のまま通る。**

> (iii) 欠落の帰結は fail-open ではなく「BSD + UTF-8 locale で誤 block 増」なので**安全側**だが、
> 「**3 件すべて必須**」という契約が **(iii) について機械的に成立せず、完了条件が人手申告に依存**する

**是正（`todo.md` のみ）**: `A-5a` の 🚩 に**静的検査を 1 行**
（`grep -c 'LC_ALL=C' scripts/check-approval-token-write.sh` が 1 以上、
**かつ正規化パイプライン行に付いていること**）。

### R-017 [minor] `route=` はリポジトリ内に先例が無い記法

**実測**: `grep -rn 'route=' docs/ scripts/ tests/ bin/`（TASK-1045 除外）→
**guard 出力としては 0 hits**（**筆者も再実測**。唯一の他ヒットは
`scripts/ai-loop/test_check_exec_boundary.py:1303` の Python `subTest(route=label)` で無関係）。
**guard は `route=` を一切出力しない**（`check-approval-token-write.sh:70-88` の
`_block` / `_parse_unknown` に該当文字列なし）。

**Impact**: 実装者が「実測経路 = `route=normal-block`」を **stderr に含まれるべきトークン**と
誤読して assert すると、**正しい実装で `TC-22b` が FAIL → `SC-9`（critical / 即停止）を誤発火**。
**R-013 が塞いだのと同一の失敗様式。**

**是正（`test-cases.md` のみ = `plan_hash` 不変）**: 記法規約に 1 行
（「**`route=` は本文書内の経路ラベルであり guard の出力文字列ではない**」）。
**`plan.md:254-255, 273` の `route=` もこの規約で読めるため `plan.md` は触らない。**

### R-018 [minor] Round 1 集計の内部不一致

```text
review-external.md:17     統合判定  critical 0 / major 2 / minor 4
review-external.md:15-16  レーン内訳 設計 minor 4（R-003〜006）+ 整合 minor 2（R-007/008）= 6
review-external.md:209    Round 1 集計 minor 6
```

**`:17` だけが 4**。C-3 / C-4 が「Round 1 の minor は 4 件」と読むと
**R-007（`LC_ALL=C`）/ R-008（複製導線）の 2 件が集計から落ちる**
（指摘本体と監査表は 8 件そろっているので**反映漏れには至っていない**）。

**是正**: **追記専用ファイルなので既存行は書き換えず、本節末尾に訂正 1 行を追記**（下記）。

> **【訂正 / R-018】`review-external.md:17` の Round 1 統合判定の minor 件数は
> `4` ではなく `6` が正**（設計レーン minor 4 = R-003〜R-006 ＋ 整合レーン minor 2 = R-007・R-008）。
> `:209` の「Round 1 の集計: critical 0 / major 2 / minor 6・info 2」および
> Round 1 監査表（R-001〜R-008 の 8 行）が正しい。**`:17` は追記専用方針により原文を保持する。**

### Human C-3 へ諮る 1 件（本ラウンドでは実装しない）

**`plan.md:582-593` の `Files / Components to Touch` から
`evidence/` / `decision-log.jsonl` / `current-state.md` が欠けている。**

```text
extract_allowed_paths(plan.md) → 7 パス（guard / ta-25 / plan / todo / test-cases / status / handoff）
```

しかし **Step 1 / 1b / 6 / 7 / 8 の Output は `evidence/verification/*.md` と `evidence/test-runs/`**、
**Stop / Replan の共通規約は `decision-log.jsonl` への記録を必須**にしている。

> **ai-loop 経路で exec すると evidence / decision-log の書き込みが `allowed_paths` 外となり
> escalation ないし「plan に無いファイルを作った」逸脱扱いになる**
> （`SC-7` は `docs/working/TASK-1045/` 単位なので停止はしない）

**これは `plan.md` 編集 = `plan_hash` 再計算が必要**なため、
**`todo.md` の H-1 に `Q-3` として追加**した（本ラウンドでは plan を編集しない）。

### River Review が「問題なし」と判定した項目（対応不要）

| 項目 | 判定 |
|---|---|
| maker 自己申告 1（`rule=` 付与後の部分一致） | **問題なし**。`plan.md:368` が detail 形式を確定し「`writes token path` を残す」ことを明文で拘束。**「文言そのものを変える」設計を許す記述は plan 内に無い** |
| maker 自己申告 2（簡略プロトタイプ） | **許容**。`plan.md:182` で明示され `UV-2` → `RT-5` に接続済み。**「未実証を実証済みと書いていない」点が重要で、それが守られている** |
| maker 自己申告 3（(ii) 未測定） | **info 級・是正不要**。`SC-9` は**いずれか**の FAIL で発火するので停止条件は緩まない |
| 量化子 | **全数照合してすべて実測と一致。over-claim は検出されず** |
| 絶対件数の固定 | **無し**。`47 passed` は参考値と明示され、退行判定は「0 failed かつ pass 数 ≥ baseline」 |
| 未裁定 Question の配線 | **素通り経路なし**。UV-1〜UV-4 も RT-1 / RT-5 / SC-3 / RT-4 へ 1 対 1 接続 |
| `review-external.md` | **実質追記専用**。数値・severity・R-NNN・監査表は不変 |

**総評**: 「実測に基づく行番号・件数の正確さ、量化子の全数照合、絶対件数を契約にしない扱い、
未検証事項の SC/RT への全接続は、**この repo の既往教訓を正面から満たしている**」

---

### 監査表（River Review / 追記専用）

| R-NNN | severity | lane | status | reflected_in | notes |
|---|---|---|---|---|---|
| R-014 | major | River Review | reflected | `docs/1045-plan` RR 反映 commit | `todo` に**通常群 16 件の owner 表**を新設。`A-5a` へ `TC-22` / `TC-22b`、`A-7` へ `TC-07` / `TC-16` / `TC-17` / `TC-18` を割当。`A-5a` / `A-7` の `rollback:` も更新。`A-11` / `A-12` は evidence 専任と明記。**`plan.md` 不変** |
| R-015 | minor | River Review | reflected | 同上 | `INDEX.md` 新規作成 + `decision-log.jsonl` を初期化 |
| R-016 | minor | River Review | reflected | 同上 | `A-5a` の 🚩 に `LC_ALL=C` の静的検査を追加（(iii) の欠落検出） |
| R-017 | minor | River Review | reflected | 同上 | `test-cases.md` の記法規約へ「`route=` は文書内ラベルで guard 出力ではない」を追加 |
| R-018 | minor | River Review | reflected | 同上 | 本節末尾に訂正 1 行を追記（`:17` の minor は 6 が正）。**既存行は書き換えていない** |
| Q-3 | — | River Review | **deferred（Human C-3 裁定へ）** | `todo.md` H-1 の `Q-3` | `Files / Components to Touch` へ `evidence/` 等を追加して `plan_hash` を取り直すか、現状受容か。**AI は裁定しない** |

**River Review の集計**: critical 0 / major 1 / minor 4 / Human 裁定 1。

**反映状況の実測**: 監査表 6 行のうち `reflected` 5 / `deferred`（Human 裁定）1。
**`plan.md` は本ラウンドで 1 文字も編集していない**（`plan_hash` = `744b3c4f…` 不変を実測確認）。

---

## C-3 裁定の反映（R-019 / 追記専用）

> 本節は **C-3 で人間が下した裁定 3 件を記録し、plan への 1 回確定反映を追跡する**。
> **R-001〜R-018 および既存の全監査表は 1 文字も変更していない**（追記専用方針）。

### R-019 [—] C-3 裁定 3 件（Q-1 / Q-2 / Q-3）の確定反映

**入力**: Human による C-3 裁定。**AI は裁定内容を変更していない。**

| Q | 裁定 | plan への帰結 | plan 編集 |
|---|---|---|---|
| **Q-1**（Mode を `critical` か `high-risk` か） | **`critical` のまま** | V-4（リリース前チェック）と C-4 複数レビュアー推奨が適用される。`lite_eligible=false` / 同期 C-3 / autonomous APPROVE 不可 は元から不変 | **不要**（既定どおり。裁定の事実のみ Questions 節へ記録） |
| **Q-2**（`&>` / `&>>` を除外に含めるか） | **block 維持**（安全側） | 除外面を増やさない。**残存誤検知は `T1045-TC-14 (3)` で意図的に固定**し、**handoff の既知課題へ記載する** | **不要**（既定どおり。裁定の事実のみ Questions 節へ記録） |
| **Q-3**（`Files / Components to Touch` へ evidence 等を追加するか） | **追加して `plan_hash` を取り直す** | `Files / Components to Touch` へ 3 行追加。ai-loop 経路の exec で evidence / decision-log / current-state の書き込みが `allowed_paths` 内に収まる | **必要**（Files 節 3 行追加 → `plan_hash` 再算出） |

### `extract_allowed_paths()` の実測（反映前 / 反映後）

`scripts/ai-loop/plan_package.py` の `extract_allowed_paths()` を実際に import して実行した結果。

| タイミング | パス数 | 内訳 |
|---|---|---|
| **反映前** | **7** | guard / ta-25 / plan / todo / test-cases / status / handoff |
| **反映後** | **10** | 上記 7 ＋ **evidence 配下 / decision-log.jsonl / current-state.md** |

**禁止パスの混入は 0 件**。`Files NOT to Touch` は `## Files / Components to Touch` の**外**に
あり `_extract_section()` が拾わないため、反映後も **10 パスちょうど**で HO 対象パスは 1 件も含まれない。

### `plan_hash` の遷移（**Human が承認トークン再発行に使う値**）

| | sha256 |
|---|---|
| **反映前**（`C1-VERDICT-5` 時点） | `744b3c4f0cb05e10dc756e43e89ff263743c571c526838757fc9dee270fe2c7f` |
| **反映後（確定値）** | **`30261b118da7761f7a78d9090c4fcda9f1d1dbd07af27cbff58ddd436029e681`** |

**`plan.md` の変更は `Files / Components to Touch` 節の 3 行追加 + 注記と、
`Questions / Unknowns` 節への裁定記録のみ。設計・AC・TC・Work Breakdown・
Stop Condition / Replan Trigger はいずれも不変。**

### 順序（EH-3 / `working-context.md` §C-3 ゲート）

```text
(1) plan 編集 ✅ → (2) 簡易 C-1 ✅ → (3) 新 plan_hash 算出 ✅
  → (4) 👤 Human が承認トークンを再発行（Human-owned・AI は作成しない）
  → (5) exec（別ワーカー）
```

**(4) より前に (1)〜(3) を完了させている**ため、EH-3 の mismatch は発生しない。
本ラウンドの担当ワーカーは **(1)〜(3) のみ**を実施し、承認トークンには一切触れていない。

### 監査表（C-3 裁定 / 追記専用）

| R-NNN | severity | lane | status | reflected_in | notes |
|---|---|---|---|---|---|
| R-019 | — | Human C-3 裁定 | reflected | `docs/1045-c3-verdict` C-3 裁定反映 commit | Q-1 = `critical` 維持 / Q-2 = block 維持 / Q-3 = **3 パス追加 + `plan_hash` 再算出**。`plan.md` は Files 節と Questions 節のみ変更 |
| Q-3 | — | River Review | **resolved（R-019 で反映）** | 同上 | 前ラウンドで `deferred` としていた 1 件を Human が裁定し、本ラウンドで確定反映 |

**C-3 裁定の集計**: 裁定 3 件（うち plan 編集を伴うもの 1 件）/ 新規指摘 0 件 / 未裁定の残 0 件。
