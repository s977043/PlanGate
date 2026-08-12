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

**指摘ゼロではない**（critical 0 / major 2 / minor 6・info 2）。

**反映状況の実測**: 監査表の `status` 列は `reflected` 8 件 + `acknowledged` 1 件 +
`reflected`（i-1）1 件の計 10 行で、**未反映を表す status の行は 0 件**
（`grep -c 'reflected' review-external.md` と行数の突合で確認）。
`R-001`〜`R-008` の 8 件すべてを **1 回で確定反映済み**。
