# EXECUTION PLAN — TASK-1101（v4 / RiverReview 反映版）

> Issue: [#1101](https://github.com/s977043/PlanGate/issues/1101) / PBI INPUT: [pbi-input.md](./pbi-input.md)
> **v4**: **RiverReview** の指摘（critical 1 / major 10 / minor 8 / info 1）を反映。**critical は 4 回のレビューが見逃した設計欠陥**。
> **v3**: 簡易 C-1 の指摘（N-1〜N-4 + 未解消 3 件）を反映。
> **v2**: C-2（2 レーン + C-1）の R-001〜R-013 / S-1〜S-4 を確定反映。集約元: [`review-external.md`](./review-external.md)
> Refs: R-001〜R-013 / S-1〜S-4 / N-1〜N-4 / RiverReview C-1・M-1〜M-10・m-1〜m-8・i-1

## Goal

`scripts/hooks/check-plan-hash.sh` の Hardening Override 判定を、**パス表記の揺れで迂回できない**ようにする。**HO 9 カテゴリ（15 パターン）× 変換クラス 7 種とその 2 種複合**の直積で block が成立し、かつ **`_norm_target` の下流 consumer と監査ログの意味論を一切変えない**状態にする。

> **適用範囲**: 本 PBI は **`Edit|Write` 経路のみ**を扱う。**`Bash` 経路には HO 判定が存在せず**（配線済み hook の実測）、そちらは **#1104** で追跡する。**「HO は常時 block される」と書かない**（AC-7）。

## Constraints / Non-goals

### Constraints

- **HO 9 カテゴリの定義は変えない**（対象パスの増減は範囲外）
- **`_norm_target` の値を変えない**（R-001。下流 3 経路が大小文字に感応して共有している）
- **監査ログには生の要求パスを残す**（S-1）。ただし**対象は `reason` と `_audit/hook-events.log`**（M-1。HO block 経路は `skip-decision-log.jsonl` に書かない）
- **fork を増やさない**（R-012 / AC-11。`sed` / `tr` を新規に足さない）
- **単語分割に依存しない**（R-002。zsh で no-op になる）
- **偽陽性を出さない**（AC-3 / TC-11b）
- **`scripts/hooks/check-plan-hash.sh` は HO 対象パス** → AI は patch 生成と **sandbox 検証**まで、**適用は Human**
- POSIX sh の範囲で書き、**zsh を含む 4 シェルで同一挙動**にする

### Non-goals

- `check-forbidden-files.sh` への HO 判定追加（二重化は別論点）
- **`Bash` 経路への HO 配線**（**#1104** で追跡。本 PBI の代替ではない）
- `plan.md` 判定側の正規化（既に実装済み）
- `PLANGATE_BYPASS_HOOK` / `PLANGATE_SKIP_TOKEN_GUARD` の扱い（明示 bypass は設計どおり）
- シンボリックリンクの解決（**意図的にしない**）
- **`skip-decision-log.jsonl` への HO block 記録の追加**（M-1。HO 保護ファイルへの新規ログ出力＝ Human 適用範囲の拡大になるため）
- FS に到達しない表記（`/CLAUDE.md` / `CLAUDE.md/` / 先頭空白 / `bin\plangate`）への対応（R-004 で到達不能を実測済み）。**これらは block せず skip する** — 期待値は test-cases §エッジケース表 / TC-11b と一致させる（N-1）

## Approach Overview

### 中核の設計判断 1: `_norm_target` を書き換えない（R-001）

v1 は `_norm_target` の確定処理そのものを置き換える設計だったが、**`_norm_target` は HO 判定専用ではない**。

> **⚠️ 以下は記号アンカーで参照する**（M-6 / #1089 の教訓）。**本 PBI 自身が同ファイルへ `_ho_key` を挿入するため、行番号は exec 開始と同時にずれる。** 行番号は「参考」であり、検証時は記号で探すこと。

| 記号アンカー | 消費点 | 大小文字感応 |
|---|---|---|
| `case "$_norm_target" in` の直後の `docs/working/TASK-*/approvals/c3.json)` | C-3 conversation mode の判定 | **あり**（`TASK-`） |
| `NORM_TARGET="$_norm_target"` → Python 内の `fnmatch.fnmatchcase(norm_target, pat)` | maintenance `allowed_paths` の照合 | **あり**（関数仕様） |
| `_dl_ext=$(printf '%s' "$_norm_target" \| sed ...)` | doc-light の拡張子判定 | — |
| `reason="C3_CONVERSATION_SKIP: ...` / `reason="DOC_LIGHT_SKIP: ...` / `reason="MAINTENANCE_SKIP: ...` / `_esc_c3=` / `_esc_dl=` | 監査ログ / `reason` | — |

（参考行: c3.json 判定 ≒ L152 / `fnmatchcase` ≒ L225 / doc-light ≒ L193 / ログ ≒ L177・L198・L200・L273。**着手時に記号で再特定すること**）

したがって **`_norm_target` は据え置き**、**HO 判定専用の派生変数 `_ho_key`** を新設し、そこにだけ正規化を適用する。

```
_norm_target  … 既存のまま（./ 除去 + repo root 除去）。下流はすべてこれを見る
_ho_key       … _norm_target とは独立に target_file から導出。HO の case 判定だけが見る
reason / log  … 生の target_file を出す（S-1 / AC-9）
```

これにより **maintenance 窓・C-3 conversation・doc-light・監査ログのいずれも意味論が変わらない**。

### 中核の設計判断 2: 畳み込みを最初に置く（**RiverReview critical**）

**v3 の順序には、本 PBI が塞ぐ対象そのものを素通りさせる欠陥があった。**

```
v3: (1)末尾空白 → (2)先頭 ./ 除去 → (3)畳み込み → (4)repo root 除去

.//CLAUDE.md
  → (2) は ${v#./} で先頭 2 文字だけを剥がす  →  /CLAUDE.md
  → (3) は // が無いので何もしない
  → (4) は repo root に一致しない
  → どの HO パターンにも当たらず skip = 穴が開いたまま
```

**`.//CLAUDE.md` は実ファイルに到達する**（実測: 6,572 bytes の実体）。

**これは v3 が作り込んだ退行**でもある。v2 にあった「先頭 `/` 除去」がこのケースを偶然塞いでいたが、絶対パス偽陽性（N-1）への対応で削除した結果、開いた。**「指摘に対応した結果、別の穴が開く」**クラスで、**C-1 → C-2 3 レーン → 簡易 C-1 の 4 回すべてが見逃した**。

**確定（v4）: 畳み込みを最初に置く。**

```
(1) 末尾空白の除去
(2) // の畳み込み / . セグメントの除去 / .. の字句的畳み込み   ← 最初に
(3) 先頭 ./ の除去（反復・(2) の残余対策）
(4) repo root の除去
(5) 小文字化                                                  ← _ho_key のみ
```

実測で両立を確認済み:

```
.//CLAUDE.md           → CLAUDE.md               block ✅
bin//plangate          → bin/plangate            block ✅
bin/./plangate         → bin/plangate            block ✅
bin/../bin/plangate    → bin/plangate            block ✅
$REPO_ROOT/./CLAUDE.md → CLAUDE.md               block ✅
/tmp/x/note.md         → /tmp/x/note.md          先頭 / を保持 = skip ✅
```

> **「先頭 `/` の除去」は入れない**（N-1 / N-2）。入れると **repo 外への書き込みが全部止まる**（作業ディレクトリを含む。現 main では 4 件とも rc=0 で通っている）。

### fail-closed（R-005 / R-007 / AC-8）

以下は **block（rc=2）へ倒す**:

- **(a)** 畳み込み後に**先頭 `..` が残る**（repo 外を指すが、cwd 次第で repo 内 HO に到達しうる）
- **(b)** **セグメント数が上限（256）を超える**（無限ループ防止。EH-3 に `timeout` は設定されていないため、暴走は block ではなく**ハング**になる）

> **「絶対パスが残る」は条件に含めない（N-1 / N-2 で確定）。** 含めると repo 外への書き込みが全部止まる。また先頭 `/` 除去を入れない以上、**到達不能**な条件でもあり、TC が**空振り fixture** になる。絶対パスを **block しないこと**は **TC-11b** で明示的に表明する。
>
> **(a) は畳み込みの「後」に判定する**。`a/b/../../../CLAUDE.md` は畳み込み**前**は先頭 `..` ではないが、**後**に転じる（TC-11(d)）。

### 実装方式（R-002 / R-012 / m-5）

**単語分割を使わない**パラメータ展開ループで書く:

```sh
# NG: IFS=/ + 未クォート $var の for ループ → zsh で no-op（実測）
# OK: ${v%%/*} / ${v#*/} を回す。fork ゼロ・全シェル共通
```

**小文字化の実装**（m-5 / 未定義だった中核部分を確定）:

- **`${v,,}` は使えない**（実測: `sh`（bash 3.2）/ `dash` とも `bad substitution`）
- **`tr` / `sed` も使わない**（AC-11 = fork 増加ゼロ）
- → **1 文字ずつ `case` で写像するループ**で実装する（`A`〜`Z` のみを対象にし、**マルチバイト文字は素通しする**）
- **マルチバイトの扱い**は Step 6 で `LANG=ja_JP.UTF-8` を含めて実測する（Q3）。素通しなら locale 非依存になる
- **セグメント上限 256 との相互作用**に注意（文字ループ × セグメントループの二重ループになるため、Step 7 で fork ではなく**実行時間**も測る）

`sed` / `tr` は**新規に足さない**（実測: `sed` 1 回 ≒8ms/回 vs 純シェル ≒1〜2ms/回、hook 全体は 0.048s）。

### `case` パターンの小文字化（R-011）

`_ho_key` を小文字化するため、HO の `case` を小文字側で受ける。**ラベルは 9 行だがパターンは 15 個**（`|` 分割後）なので、**両方の数を数えて全数確認**する。大文字を含むのは `AGENTS.md|CLAUDE.md` の 1 行のみ（実測確認済み）。

## Work Breakdown

> **v1 からの順序変更（R-008）**: apply スクリプト作成を**前倒し**し、Step 4 以降の検証を **sandbox 複製 + patch 適用**で行う。`ta-65` は `cp "$_T65_HOOK_SRC" "$_T65_TMP/scripts/hooks/check-plan-hash.sh"`（記号アンカー / 参考 ≒ L80）で複製する構造なので、**Human 適用を待たずに実測できる**（#1091 が実際に採った方法）。

### Step 0: 準備（**v4 で追加 / M-10・N-4**）

- **Output**: baseline の再測定記録 + 迂回面の再実測（`evidence/c2-review/ho-bypass-surface.md` の更新）
- **Owner**: agent
- **Risk**: 低
- 🚩 **チェックポイント**: **絶対件数を契約値にしない**。測定環境（OS / シェル / 日時 / main SHA）とセットで記録する。C-2 の実測は `dfaeebb` 時点なので**着手時点で再測定**する
- `rollback:` 不要（読取のみ）
- 対応 ToDo: **T-01 / T-02**

> **v3 まで Step 0 は存在せず**、T-01 は Step 8 の🚩に埋もれ、T-02 は plan のどの Step にも対応が無かった。監査表には「plan v3 の Step 0」と**虚偽の反映記録**があった（M-10）。

### Step 1: 正規化関数の実装（単体）

- **Output**: `_pg_fold_path()`（仮）を単体ファイルとして実装。単語分割非依存・fork ゼロ・セグメント上限つき・**1 文字 `case` 写像による小文字化**
- **Owner**: agent
- **Risk**: 中 — 実装ミスは**全 Edit/Write のハング**につながる
- 🚩 **チェックポイント**: **本体に組み込む前**に、`sh` / `dash` / `bash` / `zsh` で直接評価して入出力が一致すること（R-002 の再発防止）
- 🚩 **順序を (2) 畳み込み → (3) `./` 除去 にする**（RiverReview critical）。逆順にすると `.//CLAUDE.md` が skip される
- `rollback:` 単体ファイルなので削除するだけ

### Step 2: patch の作成と apply スクリプト（**前倒し**）

- **Output**:
  - `check-plan-hash.sh` への patch（`_ho_key` 新設 + `case` 小文字化 + `reason`/ログを生パスへ）
  - `scripts/apply-1101-ho-normalization.sh`（`--dry-run` 既定 / `--apply` / **`--revert`** / **適用後 smoke check + 失敗時の自動 revert**）
- **Owner**: agent（**適用は Human**）
- **Risk**: 中
- 🚩 **チェックポイント**: **AI は `--dry-run` のみ実行**する
- 🚩 **`_norm_target` への代入を増やさない**（R-001）
- 🚩 **S-2**: `scripts/apply-eh3-ho-always.sh`（旧 HO ブロックを **verbatim 保持**している。記号: `_override=0` 直後の `case` ブロック文字列）と `scripts/fix-eh3-doc-light-maint-guard.sh`（`_norm_target` を含む挿入文字列）が**本 patch でアンカーを失う**。**無効化 / 注記 / 削除のいずれかを決めて実施**する
- `rollback:` `--revert`

### Step 3: sandbox 検証環境の構築

- **Output**: `ta-65` の複製先に patch を当てた状態で HO 判定を実測できる仕組み
- **Owner**: agent
- **Risk**: 低
- 🚩 **チェックポイント**: 未適用 main の hook と patch 済み hook の**両方**を同一 harness で測れること
- `rollback:` 不要

### Step 4: テストの拡充と反転

- **Output**:
  - `ta-65` **TC-07 を fixed 期待へ反転**（KNOWN-GAP を外す）
  - **`ta-65` TC-06 を拡充**（変換を施した非 HO ケース: `docs/x/../AGENTS.md` / `scripts/hooks/../hooks/x.py` / `bin/../bin/other` / `docs/working/TASK-T65/../TASK-T65/CLAUDE.md.bak`）
  - **新 TC: 直積検証**（9 カテゴリ 15 パターン × 変換 7 種 + 2 種複合 → 全件 rc=2 / AC-1）。**`.//` 形を必ず含める**
  - **新 TC: `_norm_target` 不変の回帰表明 3 本**（maintenance `allowed_paths` / c3.json conversation / doc-light / AC-2）
  - **新 TC: fail-closed 2 件**（先頭 `..` / セグメント上限 / AC-8）**+ 絶対パスを block しない表明**（TC-11b）
  - **新 TC: 監査ログが生パスを保持**（`reason` と `hook-events.log` / AC-9）
- **Owner**: agent（`tests/extras/` は HO 対象外）
- **Risk**: 低
- 🚩 **チェックポイント**: **patch 未適用の hook に対して新 TC が FAIL** すること（検出力の実証）
- `rollback:` `git checkout -- tests/extras/`

### Step 5: 変異注入による検出力の実証

- **Output**: `evidence/test-runs/` に **7 変異 + 第 8 変異**それぞれで対応 TC が FAIL した記録
- **第 8 変異（M-4 / 必須）**: **`_norm_target` 自体に `_ho_key` の正規化（特に小文字化）を適用する** ＝ **v1 設計を注入**し、**TC-02/03/04 と `ta-45` が FAIL** すること
- **Owner**: agent
- **Risk**: 低
- 🚩 **チェックポイント**: 変異は**関数内の各正規化ステップ**を 1 つずつ壊す（call site を壊すと全変異が同じ FAIL に潰れる）
- 🚩 **第 8 変異が無いと AC-2 の回帰網は空振り**（7 変異はいずれも `_ho_key` 側しか壊さず TC-02/03/04 を kill できない）
- 🚩 **`.//` 形の変異**（畳み込みを `./` 除去の後ろへ動かす）で **直積 TC が FAIL** すること（critical の回帰検出）
- `rollback:` 不要

### Step 6: 4 シェル可搬性の実証（**方法を変更 / R-003**）

- **Output**: **正規化関数を `sh` / `dash` / `bash` / `zsh` で直接評価**した入出力表。**大文字を含む入力**と `LANG=ja_JP.UTF-8` を含める
- **Owner**: agent
- **Risk**: 中
- 🚩 **チェックポイント**: **`ta-65` 経由で確認しない**。`ta-65` は hook を常に `sh "$_T65_HOOK"` で起動する（記号アンカー）ため false green になる
- 🚩 **大文字入力を必ず含める**（M-7）。旧版は `..` / `//` / `/./` の 3 クラスしか測っておらず、**最もシェル差が出る小文字化が未測定**だった
- `rollback:` 不要

### Step 7: 性能実測（**基準を変更 / R-012**）

- **Output**: **追加 fork 数**の測定（目標: **増加ゼロ**）と、典型 / 病的パスでの**実行時間**
- **Owner**: agent
- **Risk**: 低
- 🚩 **チェックポイント**: fork が増えていたら実装を見直す。**加えて、1 文字 `case` 写像 × セグメントループの二重ループの実行時間**を測る（m-5）
- `rollback:` 不要

### Step 8: 回帰確認（**対象を追加 / S-4**）

- **Output**: HO / `_norm_target` 下流を検査する既存 4 本が PASS した記録 — `ta-65` / `ta-12`（TC-24 / TC-33）/ `ta-39`（TC-03 / TC-06）/ `ta-45`
- **Owner**: agent
- **Risk**: 中 — `ta-45` は R-001 の破壊で RED になる経路
- 🚩 **チェックポイント**: `sh tests/run-tests.sh` rc=0。baseline は **Step 0 で測定した値**と比較する
- `rollback:` 不要

### Step 9: 文書更新

- **Output**: `docs/ai/hook-enforcement.md` の「既知の残存」を更新。以下 5 点を**すべて**満たす（AC-7 / TC-10 が grep で機械確認）:
  1. 解消済み項目が残っていない
  2. **残存ゼロ、または追跡 issue 番号が本文に存在**
  3. **記述が `Edit|Write` 経路に限定されることを明示**（M-8）
  4. **`Bash` 経路の追跡先として `#1104` を本文に残す**（M-8）
  5. **変換クラスの列挙を 3 種 → 7 種へ訂正**（S-3 / **m-7**: 旧記述は「ta-65 TC-07 が 4 ケースを固定」と **TC の内容**を述べており、**迂回総数を 4 件と主張してはいない**。訂正対象は「総数」ではなく「**列挙した変換クラスの不足**」）
- **Owner**: agent
- **Risk**: 低
- 🚩 **「HO は常時 block される」と書かない**（`Bash` 経路が開いているため過大な達成宣言になる）
- `rollback:` `git checkout -- docs/ai/hook-enforcement.md`

## Files / Components to Touch

| ファイル | 変更 | HO 対象 | 適用者 |
|---|---|---|---|
| `scripts/hooks/check-plan-hash.sh` | `_ho_key` 新設 / `case` 小文字化 / ログを生パスへ。**`_norm_target` は据え置き** | **YES** | **Human**（patch 経由） |
| `tests/extras/ta-65-eh3-ho-task-context.sh` | TC-07 反転 / TC-06 拡充 / 新 TC 5 系統 | no | AI |
| `docs/ai/hook-enforcement.md` | 「既知の残存」の更新（**5 点 / Edit\|Write 限定の明示と #1104 の追跡先を含む**） | no | AI |
| `scripts/apply-1101-ho-normalization.sh` | 新規（`--dry-run` / `--apply` / `--revert` / smoke check） | no | AI 作成 / Human 実行 |
| `scripts/apply-eh3-ho-always.sh` | **stale 化への対処**（無効化 / 注記 / 削除を決める） | no | AI |
| `scripts/fix-eh3-doc-light-maint-guard.sh` | 同上（アンカーが壊れうる） | no | AI |

## Testing Strategy

### Unit

正規化関数を単体で評価。**境界ごとに期待を明記**:

| 入力 | 期待 |
|---|---|
| 空文字列 | skip（現行踏襲） |
| `/` のみ | skip（FS 到達不能） |
| `..` のみ | **block**（fail-closed） |
| 先頭 `..` が残る | **block** |
| セグメント 257 個 | **block**（上限超過） |
| 絶対パス（`/tmp/...`） | **不変 → skip**（TC-11b） |

### Integration

- **直積検証**: 9 カテゴリ 15 パターン × 変換 7 種 + 2 種複合（AC-1）。**`.//` 形を含む**
- **偽陽性**: `ta-65` TC-06 の 10 件 + 変換済み非 HO ケース（AC-3）+ **絶対パス 4 件**（TC-11b）
- **下流不変**: maintenance / c3.json conversation / doc-light（AC-2）
- **既存 4 本の回帰**: `ta-65` / `ta-12` / `ta-39` / `ta-45`（AC-6 / S-4）

### Verification Automation

- **変異注入**（Step 5・**7 変異 + 第 8 変異**）
- **4 シェル直接評価**（Step 6・**`ta-65` 経由にしない**・**大文字入力を含む**）
- **fork 数と実行時間の測定**（Step 7）
- `sh tests/run-tests.sh` rc=0（**絶対件数を契約値にしない**）

## Risks & Mitigations

| リスク | 影響 | 緩和 |
|---|---|---|
| **正規化の順序ミス** | **本 PBI が塞ぐ対象が素通り**（`.//CLAUDE.md`）。**4 回のレビューが見逃した実績あり** | **畳み込みを最初に置く**（v4）+ 直積 TC に `.//` 形 + Step 5 の順序変異 |
| **`_norm_target` を壊す** | maintenance 窓の全滅 / C-3 conversation の silent 死 | **派生変数 `_ho_key`**（R-001）+ AC-2 + **第 8 変異**（M-4） |
| **zsh で正規化が no-op** | ガードが fail-open。**`ta-65` では検出不能** | 単語分割非依存の実装（R-002）+ AC-4 の 4 シェル直接評価 |
| 無限ループ | **EH-3 に timeout が無く、block でなくハング**（実測確認済み） | セグメント上限 256 → **block**（AC-8）+ apply 後の smoke check |
| 偽陽性 | 開発が止まる | AC-3 の拡充ケース + **TC-11b**（絶対パス） |
| 適用が Human 依存で検証できない | 完了が滞る | **sandbox 複製 + patch**（Step 3 / R-008） |
| 旧 apply スクリプトの stale 化 | 巻き戻し事故 | Step 2 🚩 で対処を決める（S-2） |
| 監査ログが正規化値になる | 攻撃の原文が消える | ログは生 `target_file`（AC-9 / S-1） |
| fork 増で全編集が遅くなる | 体感劣化 | 純シェル実装（AC-11 / R-012）+ Step 7 で実行時間も測定 |
| **過大な達成宣言** | **Bash 経路の穴が文書上消える** | **AC-7 (3)(4)** で `Edit\|Write` 限定と #1104 を必須化（M-8） |

## Questions / Unknowns

> **v1 の Q1・Q3 は C-2 を受けて確定済み**。承認後の方式分岐を残さない。

1. ~~repo root 跨ぎ `..` の扱い~~ → **確定**: 先頭 `..` が残ったら **block**（AC-8）
2. ~~性能劣化時の方式分岐~~ → **確定**: **純シェル実装で fork 増加ゼロ**（AC-11）
3. **残る Unknown**: マルチバイト環境（`ja_JP.UTF-8`）での小文字化の挙動。**Step 6 の 4 シェル評価に `LANG` を変えたケースを含める**。**1 文字 `case` 写像で `A`〜`Z` のみを対象にしマルチバイトは素通しする**方針のため、**方式分岐にはならない**（問題があれば対象文字集合の調整で吸収）

## Mode 判定

**モード**: **`high-risk`（ユーザー override / C-3 承認事項）**

**判定根拠**:

| 軸 | 値 | 帯 |
|---|---|---|
| 変更ファイル数 | 6 | high-risk |
| **受入基準数** | **11** | **critical** ⚠️ |
| 変更種別 | **承認境界そのものの判定ロジック** | high-risk（例外ルール） |
| リスク | **高**（EH-3 は全 Edit/Write の前段。timeout が無いため暴走はハング） | high-risk |
| 影響範囲 | hook 層全体 | high-risk |

**⚠️ 定量基準では `critical` 帯（M-3）**: 正本の定量表は **受入基準数 `11+` = 超高**、判定ロジックは「各軸の最大値を採用」。AC を 7 → 11 に増やした結果、帯を跨いでいる。

**override の根拠**: AC が 11 件あるのは「**穴が塞がったこと**を測るために検証条件を分解した結果」であり、**変更の危険度が critical 相当に上がったわけではない**。実体は「HO 判定ロジックの局所変更 + テスト」で、`critical` が要求する **V-2 / V-4**（横断リファクタ・リリース前チェック）を要する規模ではない。正本の「**ユーザーがオーバーライドした場合はそちらを優先**」に該当。

**2026-08-15 ユーザー承認済み**（A=critical へ引上げ / **B=override して high-risk 維持** / C=AC 統合 のうち **B**）。**C-3 でこの override ごと承認を得ること。**

**`lite_eligible=false`**（HO 対象パスに該当するため強制。C-3 は **Standard・同期**固定、autonomous APPROVE 不可）
