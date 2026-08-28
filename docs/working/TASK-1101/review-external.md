# C-2 外部レビュー結果 — TASK-1101（追記専用集約）

> Issue: [#1101](https://github.com/s977043/PlanGate/issues/1101)
> 実施: 2026-08-15 / `origin/main` = `dfaeebb` / 対象 plan_hash: 未発行（C-3 前）
> 体制: 3 レーン（設計妥当性 / コードベース整合 / C-1 セルフレビュー）
> 規約: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md)「C-2 指摘の差分管理」— **追記専用・R-NNN 採番・計画本体への反映は 1 回だけ確定**

## サマリ

| Severity | 件数 |
|---|---|
| **critical** | **2** |
| **major** | **6** |
| minor | 4 |
| info | 1 |

**総合判定: C-3 へ進めない（NO）。plan の確定反映が必要。**

**独立した 3 レーンが同一の critical に到達**した（設計妥当性 R-001 / C-1 の C1-PLAN-03 / コードベース整合の項目 1）。単一レーンだけなら見逃していた可能性が高い。

### オーガナイザーによる裏取り

ワーカーの原因帰属は**すべて一次ソースで再確認**した。以下は**私自身が実測したもの**:

| 主張 | 裏取り結果 |
|---|---|
| `_norm_target` が HO 判定後も共有される | ✅ `grep` で L152/177/179/193/198/200/207/273 を確認 |
| L152 が大文字 `TASK-`・L225 が `fnmatchcase` | ✅ 実コードで確認 |
| TC-07 の 4 ケース以外にも迂回がある | ✅ 5 系統を追加実測（`evidence/c2-review/ho-bypass-surface.md`） |
| `ta-65` が `sh` 固定で AC-4 が false green | ✅ L66 / L215 の `sh "$_T65_HOOK"` を確認 |
| EH-3 に timeout 未設定 → 無限ループはハング | ✅ `settings.json` に `timeout` 無しを確認 |
| **zsh で正規化が no-op になる** | ✅ **4 シェルで直接実測して再現**（下記 R-002） |
| `realpath` は macOS に存在する（plan の記述が誤り） | ✅ `/bin/realpath` の存在と `readlink -f /tmp` の成功を確認 |
| 末尾空白は実ファイルに到達しない（pbi-input の記述が誤り） | ✅ `cat "CLAUDE.md "` が `No such file` |

---

## 指摘一覧

### [R-001] critical — `_norm_target` を書き換えると下流 3 経路が壊れる

**該当**: plan.md「Approach Overview」(g) / Step 1 Output / Files to Touch

`_norm_target` は HO 判定**専用ではない**。HO ブロック（L95-110）を通過した後も生き続け、**大小文字に感応する消費点**が下流にある:

| 行 | 消費点 | 感応性 |
|---|---|---|
| L152 | `case "$_norm_target" in docs/working/TASK-*/approvals/c3.json)` | **大文字 `TASK-`** |
| L207-225 | `NORM_TARGET` → Python `fnmatch.fnmatchcase(norm_target, pat)` | **明示的に大小文字を区別** |
| L193 | doc-light の拡張子判定 | — |
| L177/179/198/200/273 | 監査ログと `reason` 文字列 | — |

**失敗シナリオ（コードベース整合レーンが mutation で実測）**:

```
PLANGATE_HOOK_FILE=docs/working/TASK-T45/approvals/c3.json
  原本      : rc=0  [Hook EH-3 C3_CONVERSATION_SKIP]
  小文字化後: rc=2  [Hook EH-3] SKIP 拒否: SKIP_REASON 未設定
```

- **maintenance 窓の全滅**: `allowed_paths: ["docs/working/TASK-1101/*"]` が `fnmatchcase` で一致しなくなり `OUT_OF_SCOPE` → **Human が承認した編集が全部 block**。しかも `2>/dev/null || true` で握り潰され**原因が見えない**
- **C-3 conversation mode の silent 死**: `TASK-*` に不一致 → **block されないので誰も気づかない**（fail-open 方向の退行）。`ta-45` が RED になる

**Fix**: `_norm_target` は据え置き、**HO 判定専用の派生変数**（例 `_ho_key`）にのみ正規化を適用する。plan の (a)〜(f) と (g) を分離し、「`_norm_target` は (a)〜(f) まで、(g) は HO マッチ用の派生のみ」と明記。

---

### [R-002] critical — zsh で正規化が silent に no-op になり、ガードが fail-open する

**該当**: plan.md「Approach Overview」(f) / Step 5 / AC-4

`IFS=/` + 未クォート `$var` の for ループによる分割は、**zsh では既定で単語分割が起きない**（`SH_WORD_SPLIT` off）。**オーガナイザーが 4 シェルで直接実測**:

```
sh    docs/../CLAUDE.md -> CLAUDE.md          bin/../bin/plangate -> bin/plangate
bash  docs/../CLAUDE.md -> CLAUDE.md          bin/../bin/plangate -> bin/plangate
dash  docs/../CLAUDE.md -> CLAUDE.md          bin/../bin/plangate -> bin/plangate
zsh   docs/../CLAUDE.md -> docs/../CLAUDE.md  bin/../bin/plangate -> bin/../bin/plangate
```

**zsh 配下では正規化が丸ごと効かず、塞いだはずの穴が全部開く。** しかも `ta-65` は常に `sh` を起動する（R-003）ため、**AC-4 では絶対に検出できない**。

> MEMORY の「**設定の存在は効いている証拠でない**」と同型の false green。本 repo のユーザー環境の既定シェルは zsh である点も重い。

**Fix**: 単語分割に依存しない実装（`${v%/*}` / `${v#*/}` のパラメータ展開ループ）にする。加えて AC-4 の検証方法を R-003 のとおり変更する。

---

### [R-003] major — AC-4「4 シェルで `ta-65` を実行」は false green

**該当**: plan.md Step 5 / pbi-input AC-4

```
tests/extras/ta-65-...sh:66   sh "$_T65_HOOK" </dev/null 2>&1
tests/extras/ta-65-...sh:215  | PLANGATE_HOOK_TASK="$_T65_TASK" sh "$_T65_HOOK" 2>&1
```

**hook の起動シェルが `sh` にハードコード**されており、harness を dash/bash/zsh で回しても hook 本体は常に `sh`。hook の shebang も `#!/bin/sh`。

**Fix**: Step 5 の Output を「`ta-65` 実行記録」から「**正規化関数を 4 シェルで直接評価した入出力表**」へ変更（例: `for s in sh dash bash zsh; do "$s" -c '. fold.sh; _fold …'; done`）。R-002 はこの方法でのみ検出できる。

---

### [R-004] major — 迂回面は既知 4 ケースより広く、AC-1 が「穴が塞がったこと」を測っていない

**該当**: pbi-input AC-1 / plan.md「Testing Strategy > Unit」

TC-07 の 4 ケースは**部分集合**。オーガナイザーとコードベース整合レーンの実測（TASK 文脈）で、**FS に実到達する迂回**が多数:

| 系統 | 例 | rc | FS 到達 |
|---|---|---|---|
| 連続スラッシュ | `bin//plangate` / `.//CLAUDE.md` / `.claude//rules/x.md` | 0 | **到達** |
| `/./` セグメント | `bin/./plangate` / `.claude/./rules/x.md` | 0 | **到達** |
| repo root 跨ぎ | `$REPO_ROOT//CLAUDE.md` / `$REPO_ROOT/./CLAUDE.md` / `$REPO_ROOT/docs/../CLAUDE.md` | 0 | **到達** |
| 大小文字（**9 カテゴリ全部**） | `Bin/plangate` / `.CLAUDE/rules/x.md` / `scripts/hooks/x.SH` / `.github/workflows/x.YML` / `schemas/x.SCHEMA.json` / `.claude/Settings.json` | 0 | **到達** |
| 到達しない（対応不要） | `/CLAUDE.md` / `CLAUDE.md/` / ` CLAUDE.md` / `bin\plangate` | 0 | 到達しない |

**`bin/plangate` に到達する未文書の経路が少なくとも 4 系統ある。** また `scripts/hooks/../../scripts/hooks/x.sh` が block されるのは**設計ではなく偶然**（glob の先頭一致）。

**plan は大小文字を `AGENTS.md`/`CLAUDE.md` の話としか書いていないが、実際は 9 カテゴリすべてが大文字で迂回可能。**

**Fix**: AC-1 を「TC-07 の 4 ケース」から「**HO 9 カテゴリ × 変換クラス（`./` 前置 / `//` / `/./` / `..` 往復 / repo root 跨ぎ / 大小文字 / 末尾空白）とその 2 種複合の直積が全件 rc=2**」へ格上げ。**到達性を実測した一覧**を根拠にする。

---

### [R-005] major — (a)〜(g) の順序では repo root 跨ぎが塞がらない

**該当**: plan.md「Approach Overview」の順序表 / Questions 1

(b) `./` 除去 → (c) repo root 除去 → (d) `//` 畳み込み の順は**絶対パス入力で破綻する**:

- `$REPO_ROOT//CLAUDE.md` → (c) で `$REPO_ROOT/` を剥がすと **`/CLAUDE.md` が残り**、以降どのステップも HO に当たらない
- `$REPO_ROOT/./CLAUDE.md` → 同様に `./CLAUDE.md` / `/CLAUDE.md` が残る
- `$REPO_ROOT/../plangate/CLAUDE.md` → (c) 後に先頭 `..` が残り畳み込めない

**Fix**: (d)(e)(f) を (c) の**前**に置く、かつ (c) の後に**先頭 `/` の除去**を追加。さらに「畳み込み後に先頭 `..` または絶対パスが残ったら **block へ倒す**」fail-closed を入れ、Questions 1 を消す。

---

### [R-006] major — TC-06（偽陽性の表明）が正規化前の入力集合のまま

**該当**: plan.md Step 3 / pbi-input AC-3

TC-06 の 10 件は**正規化しても値が変わらないパス**ばかりで、正規化強化によって新設されるコードパスをほぼ通らない。**AC-3 は「正規化強化による偽陽性が出ないこと」を測れていない**。

> ただしコードベース整合レーンが plan 記述どおりの mutation で TC-06 を実測し、**10 件全件 rc=0 / HO=no**（偽陽性なし）を確認済み。**現時点で偽陽性は出ていない**が、**測定装置として不十分**という指摘は成立する。

**Fix**: Step 3 を「TC-07 反転 **+ TC-06 拡充**」に改め、正規化を通しても非 HO であるべきケース（`docs/x/../AGENTS.md` / `scripts/hooks/../hooks/x.py` / `bin/../bin/other`）を Output に列挙。AC-3 を「既存 10 件 + 変換を施した非 HO ケース N 件」へ。

---

### [R-007] major — 無限ループ時は block でなくハングする。ループ上限が Output にも AC にも無い

**該当**: plan.md Step 1 `rollback:` / Risks 表 1 行目 / Step 7 `rollback:`

**EH-3 に `timeout` が設定されていない**（`settings.json` を実測）。無限ループは block ではなく**ハング**になり、Edit/Write が無反応になる。「ループ上限を設ける」は **Risks 表の中だけの約束**で Output にも AC にも無い。apply スクリプトの `--revert` も Output に無く「手順を**記載**」＝ドキュメント止まり。

**Fix**: (1) ループ上限（例 256 セグメント）を Step 1 Output と AC に昇格し、**上限超過は block へ倒す**。(2) apply スクリプトに `--revert` を実装 Output として明記。(3) 適用直後の smoke check（HO 1 件が rc=2 / 非 HO 1 件が rc≠2 / 実行時間が閾値内）を apply スクリプトに実装し、失敗したら**自動 revert**。

---

### [R-008] major — Step 4〜6 は patch 適用済み hook を要するが、適用は Human-owned で Step 7 が後ろ（依存の逆行）

**該当**: plan.md Step 4 / 5 / 6 / 7 の順序

**Fix**: `ta-65` は `cp "$_T65_HOOK_SRC" "$_T65_TMP/..."`（L80）で **sandbox に複製する構造**なので、**複製側に patch を当てて検証する**手順を Step 4 の前に置く（#1091 が実際に採った方法）。Step 7 の apply スクリプト作成を前倒しし、AI は `--dry-run` + sandbox 検証のみ行う。

---

### [R-009] minor — plan の `realpath` 不採用理由が事実誤認

**該当**: plan.md Constraints / Approach の方式比較表

**実測（macOS 26.6.1）**: `/bin/realpath` は**存在し**、`readlink -f /tmp` も**動く**（→ `/private/tmp`）。plan の「macOS 標準に無い」は**誤り**。

ただし**不採用の結論は妥当**。正しい理由は:

```
$ realpath 'nonexistent/../foo.md'; echo rc=$?
realpath: nonexistent/../foo.md: No such file or directory
rc=1
```

**BSD 実装は存在しないパスで失敗する**（GNU の `realpath -m` 相当が無い）→ **Write の新規ファイル作成時に正規化できず fail-open する**。加えてシンボリックリンクを解決してしまう。

**Fix**: 不採用理由を「存在しない」から「**存在しないパスで rc=1（新規 Write を正規化できない）+ シンボリックリンクを解決する**」へ差し替える。誤った前提のまま C-3 を通すと、後で反証されて再承認になる。

---

### [R-010] minor — pbi-input の「末尾空白は実ファイルに到達する」が事実誤認

**該当**: pbi-input.md「迂回が成立する 4 ケース」表の `"CLAUDE.md "` 行

**実測（APFS）**: `cat "CLAUDE.md "` → `No such file or directory`。**末尾空白は実ファイルに到達しない**（大小文字だけが到達する: `cat CLAUDE.MD` は中身が出る）。

**Fix**: 末尾空白は「実到達経路」ではなく「**ガードの一貫性**」の問題として記述を訂正。**塞ぐこと自体には賛成**（深刻度の根拠だけを直す）。

---

### [R-011] minor — HO 判定の `case` ラベルは 9 行だがパターンは 15 個

**該当**: plan.md Step 2 チェックポイント「9 カテゴリすべてを再確認」

`ta-65` TC-00 の実測は **15 パターン**（`case` ラベル 9 行 × `|` 分割）。「9 カテゴリ / **15 パターン**」と両方書かないと Step 2 の全数確認が取りこぼす。

---

### [R-012] minor — Step 6 の性能観点が `..` ループになっているが、支配的なのは fork 数

**該当**: plan.md Step 6

**実測（200 回 / `/bin/sh`）**:

| 実装 | 典型 | 病的 | 1 回あたり |
|---|---|---|---|
| `sed` を 1 回挟む | 1.70s | 1.84s | **≒ 8ms** |
| 純シェル（fork なし） | 0.21s | 0.42s | **≒ 1〜2ms** |
| hook 全体 1 回 | — | — | 0.048s |

**コストは `..` ループではなく外部コマンドの fork が支配的。** `sed`/`tr` を 2 本足すと全 Edit/Write に ~10ms 上乗せされる。

**Fix**: Step 6 のチェックポイント文言を**追加 fork 数**基準へ。純シェル実装を第一候補に据える（R-002 の対応とも整合）。

---

### [R-013] info — AC-2 は AC-5 に包含される

AC-2「通過を許す実装に戻すと RED」は AC-5 の 3 変異の部分集合。Step 3 の🚩で実質担保される。削除または AC-5 へ統合を推奨。

---

## scope 外の報告（本 PBI では対応しない・追跡先を作る）

| # | 内容 | 扱い |
|---|---|---|
| S-1 | **HO ログが小文字化された値を出す**（現行 L107 は `_norm_target` を出力）。監査ログに**実際の要求パスと異なる文字列**が残ると事後追跡で「誰が何を編集しようとしたか」が復元できない。**ログには生の `target_file` を出すべき** | R-001 の Fix（派生変数化）で自然に解決する。**AC に「監査ログが生パスを保持する」を追加**して取りこぼしを防ぐ |
| S-2 | **`scripts/apply-eh3-ho-always.sh` が現行 HO ブロックを verbatim 保持**（L123-145 / L163-173）。本 PBI が同ブロックを書き換えると**照合に失敗する / 古い形へ巻き戻す**。`scripts/fix-eh3-doc-light-maint-guard.sh` も `_norm_target` を含む挿入文字列でアンカーが壊れうる | **Step 7 で旧スクリプトの扱い（無効化 / 注記 / 削除）を決める**。plan に追記 |
| S-3 | **`docs/ai/hook-enforcement.md` の「既知の残存」が 4 ケース限定**（L146-152）だが実際は 15 件以上 | AC-7 に「**記述件数が過少だったことの訂正**」を含める |
| S-4 | `ta-12-maintenance.sh`（TC-24 / TC-33）・`ta-39-eh3-doc-light.sh`（TC-03 / TC-06）・`ta-45-c3-mode-config.sh` も HO / `_norm_target` 下流を検査している。**TC-07 反転時に一緒に壊れうる** | **Step 3 の対象に 3 本を追加**し、回帰確認を AC-6 に含める |

---

## 監査表（追記専用 / squash・rebase 耐性）

> `reflected_in` は**未コミット**のため反映先ファイルで記録する。**コミット確定時に SHA を追記**すること（squash / rebase 耐性のため、コミットメッセージにも `Refs: R-001 … S-4` を含める）。

| R-NNN | severity | status | reflected_in（反映先） | notes |
|---|---|---|---|---|
| R-001 | critical | **REFLECTED** | plan §中核の設計判断（`_ho_key`）/ Constraints / **AC-2** / todo T-04🚩 / TC-02・03・04 | HO 専用の派生変数へ。**3 レーンが独立に検出** |
| R-002 | critical | **REFLECTED** | plan §実装方式 / pbi-input 方式表「❌ 採用不可」/ **AC-4** / todo T-03 | zsh no-op。オーガナイザーが**4 シェル実測で再現** |
| R-003 | major | **REFLECTED** | plan Step 6 / **AC-4**「`ta-65` 経由での確認は不可」/ TC-07🚩 | 検証方法を関数直接評価へ |
| R-004 | major | **REFLECTED** | **AC-1**（直積）/ TC-01 / pbi-input §迂回が成立するケース（7 変換クラス） | 既知 4 ケースは部分集合だった |
| R-005 | major | **REFLECTED** | plan §正規化の順序 + §fail-closed / **AC-8** | **v3 で (5) を削除**（N-1/N-2） |
| R-006 | major | **REFLECTED** | **AC-3** / plan Step 4 / TC-06 | TC-06 拡充 |
| R-007 | major | **REFLECTED** | **AC-8 / AC-10** / plan Step 2 / plan Risks | ループ上限 / `--revert` / smoke check |
| R-008 | major | **REFLECTED** | plan §順序変更注記 / Step 2 前倒し / Step 3 / todo T-07 | sandbox 複製への patch 適用 |
| R-009 | minor | **REFLECTED** | pbi-input §実装方針の候補と評価 | `realpath` 不採用理由の差し替え |
| R-010 | minor | **REFLECTED** | pbi-input §迂回が成立するケース +「重要な訂正」 | 末尾空白の到達性訂正 |
| R-011 | minor | **REFLECTED** | plan §`case` の小文字化 / **AC-1** / todo T-04🚩 | 9 カテゴリ / **15 パターン** |
| R-012 | minor | **REFLECTED** | plan Step 7 / **AC-11** / TC-14 | fork 数基準へ |
| R-013 | info | **REFLECTED** | pbi-input 受入基準の前書き / **AC-5** へ統合 | 旧 AC-2 を統合 |
| S-1 | — | **REFLECTED** | **AC-9** / plan Constraints / TC-12 / todo T-13 | 監査ログが生パスを保持 |
| S-2 | — | **REFLECTED** | plan Step 2🚩 / Files 表 / todo T-06 | 旧 apply スクリプトの stale 対処 |
| S-3 | — | **REFLECTED** | **AC-7** / plan Step 9 / TC-10 / todo T-18 | 文書の件数訂正 |
| S-4 | — | **REFLECTED** | **AC-6** / plan Step 8 / TC-09 / todo T-17 | 既存 4 本の回帰 |

**17/17 反映済み**（簡易 C-1 が全件を独立確認）。

## 簡易 C-1（v2 に対する再レビュー）で新たに検出された指摘

| N-n | severity | status | reflected_in | notes |
|---|---|---|---|---|
| **N-1** | major | **REFLECTED** | plan v3 §正規化の順序（**(5) 削除**）/ Non-goals / pbi-input §絶対パスの扱い / test-cases エッジケース表 / **TC-11b 新設** | `/CLAUDE.md` の期待値が 3 箇所で矛盾していた。**実測で決着**（block 一律は scratchpad を止めるため採れない） |
| **N-2** | major | **REFLECTED** | **AC-8 を 2 条件へ** / TC-11 に**具体値 5 件** | 「絶対パスが残る」は**到達不能な条件**で TC が空振り fixture だった |
| **N-3** | minor | **REFLECTED** | todo §依存関係（**H-01 を全 T の前段として描画**） | グラフだけ読むと C-3 前に exec が走る構成に見えた |
| **N-4** | minor | **REFLECTED** | todo §plan Step ↔ ToDo 対応表 / plan v3 の Step 0 | T-01 / T-02 に対応する Step が無かった |
| C1-TODO-10 | — | **REFLECTED** | todo T-11 / T-12 / T-13 / T-18 / T-19 に🚩追加 | 🚩 欠落 5 件 |
| C1-PLAN-01 | — | **REFLECTED** | todo §plan Step ↔ ToDo 対応表 | AC ↔ Step の対応が追える形に |
| C1-B1B2-16 | — | **未反映（受容）** | — | B-1 確認質問の記録。**WARN の実体だった未決論点（repo root 跨ぎ `..`）は AC-8 で block に確定済み**のため実害なし |

## 次の手順（`working-context.md` の規定順）

1. ✅ **review-external.md に R-NNN を集約**（本ファイル）
2. ✅ **確定反映**（v2 で R-001〜S-4、v3 で N-1〜N-4）
3. ✅ **簡易 C-1 再実行** → WARN（N-1〜N-4 検出）→ v3 で反映
4. ⬜ **人間が最終 `c3.json` を発行**（確定後 plan の `plan_hash`）← **次はここ**
5. ⬜ exec

> **`c3.json` の発行は確定反映の後**。先に発行すると EH-3 が後続の反映を mismatch として検知する。
> **Mode = high-risk / `lite_eligible=false` / HO 対象パスを含むため autonomous APPROVE 不可・C-3 は Human 同期必須。**

## 本 PBI の前提に関する重要な注記（#1104）

本 PBI の作業中に、**HO を含むファイル書き込みガード 5 本が `Edit|Write` matcher のみに配線されており、Bash 経由の書き込みで全部迂回できる**ことが判明した（**#1104**）。

**本 PBI（`Edit|Write` 経路の正規化）は #1104 の代替ではなく、逆もまた然り。** ただし **AC-7 で `hook-enforcement.md` を更新する際、「`Edit|Write` 経路では常時 block / `Bash` 経路は #1104 で追跡中」と書き分けること**。そうしないと「HO は常時 block される」という過大な達成宣言になる。
