# EXECUTION PLAN — TASK-0914

> Issue: [#914](https://github.com/s977043/plangate/issues/914)（fix / sync / #877 follow-up）
> 入力: [`pbi-input.md`](./pbi-input.md)
> 基点: main `90c313d`（2026-07-25。行番号・判定式・extras 本数はすべて本 commit で実測）
> R-204 スコープ: **案 C**（判別式統一 + standalone env 無害化まで。exit code 伝播は別 issue）— 2026-07-25 Human 決定

## Goal

`scripts/sync-plugin-plangate.sh` に残存する **src 駆動の無ガード削除 2 経路**へ mass-delete safety guard を適用し、#877 で確立した `guard_fired` → 終端 `exit 3` + `PLANGATE_ALLOW_MASS_DELETE=1` override の枠組みを全削除経路で一貫させる。あわせて `tests/extras/` の harness/standalone 判別方式を `PG_HARNESS_SOURCED` AND 方式へ統一し、standalone 実行が外部 env 汚染で静かに誤動作する経路を塞ぐ。

## Constraints / Non-goals

### Constraints

- **`sync_dir` 内 guard 本体の判定式（`_stale_count > _src_count`）は変更しない**。#877 / PR #915 で dry-run/実行の一致性を根拠に確定済み（[`docs/working/TASK-0877/plan.md`](../TASK-0877/plan.md) 論点 B）
- **POSIX sh 制約**: 配列なし・`local` なし。`guard_fired` の global 集約は「`sync_dir` 呼び出しがサブシェルを経由しない」ことに依存する（既存 L27-29 コメント）。新規 guard 呼び出し箇所も `$(...)` を挟まないこと
- **HO（Hardening Override）対象外の確認済み**: 変更対象は `scripts/sync-plugin-plangate.sh`（`scripts/` 直下。`scripts/hooks/*.sh` ではない）/ `tests/**` のみ。HO 9 カテゴリに該当しないため `lite_eligible` 無効化条件には抵触しない（ただし Mode=high-risk により Human C-3 は必須）
- **`.github/workflows/*.yml` は変更しない**（HO 対象。`exit 3` で job は自動 fail する = #877 と同じ設計）

### Non-goals

- `sync_dir` guard の再設計（#877 で完了）
- scripts allowlist `case` 削除経路（L350-363）への guard 適用 — **src 欠損に依存せず mass-delete しないため対象外**（実測: 削除条件は L355 のハードコード allowlist のみで、`AI_LOOP_SCRIPTS_DIR` は L338 のコピー元存在ガードにしか使われない）
- extras 11 本への standalone exit code 伝播（`exit $fail` 相当）の追加 → **別 issue へ切り出し**（本 plan Step 6）
- `tests/extras/README.md` の「現行テスト一覧」表のドリフト是正（**53 本**中 12 本しか掲載されていない既存文書負債）→ 別 issue 候補（V2）

## Approach Overview

1. **判定部分のみを純関数化**して 3 経路で共有する。既存 `sync_dir` の guard は「集計 → 判定 → `_warn` → `guard_fired=1` → `return 0`」が一体だが、`return` による早期脱出は *`sync_dir` 関数からの脱出*であり呼び出し元 `for` の継続を意図した制御である。経路1（`for _skill_dir` の内側）・経路2（トップレベル `if`）は制御構造が異なるため、**`return` を含む部分は共通化せず、判定 + 警告 + フラグ立てのみを関数化**する。

   ```sh
   # 戻り値: 0 = 削除を保留せよ（blocked） / 1 = 削除を続行してよい
   _mass_delete_blocked() {  # $1=label $2=base_count $3=stale_count
     [ "$3" -gt "$2" ] || return 1
     if [ "${PLANGATE_ALLOW_MASS_DELETE:-0}" = "1" ]; then _warn "WARN: ... 解除しました ..."; return 1; fi
     _warn "WARN: DELETE skipped for $1 — base=$2 / stale=$3 ..."
     guard_fired=1
     return 0
   }
   ```

   呼び出し側は `if _mass_delete_blocked "$_label" "$_b" "$_s"; then <削除ループを skip>; fi`。`sync_dir` 側は `if _mass_delete_blocked ...; then return 0; fi` に置換して既存挙動を保つ。

2. **base/stale の集計は経路ごとに実装**する（データ構造が異なるため）。経路2 のベース集合は src ディレクトリ走査ではなく文字列 `_ai_loop_expected_refs`（スペース区切り）であり、共通関数へは**件数（整数）で渡す**ことで型差を吸収する。

3. **R-204** は 11 本すべてが同一の 3 行パターンを持つため、条件式の置換 + standalone 分岐内への `unset` 1 行追加という機械的変更で足りる。共有 preamble ファイル化は既存慣習（extras は自己完結・ta-26 も自前実装）から外れるため採らず、V2 候補に落とす。

### 論点と判断

| 論点 | 選択肢 | 判断 | 根拠 |
|------|--------|------|------|
| **A. 共通化の範囲** | A-1 guard 全体を関数化（`return` 含む） / **A-2 判定+警告+フラグのみ関数化** | **A-2** | `return` の意味が呼び出し元の制御構造ごとに異なる（`sync_dir` 関数からの脱出 vs ループ内 skip）。A-1 は経路1/2 で制御フローが壊れる |
| **B. 共通関数の引数型** | B-1 ディレクトリパスを渡し関数内で走査 / **B-2 件数（整数）を渡す** | **B-2** | 経路2 のベース集合は文字列 `_ai_loop_expected_refs` でディレクトリ走査に還元できない（POSIX sh に配列なし）。件数へ抽象化すれば 3 経路で揃う |
| **C. 閾値** | C-1 経路ごとに専用閾値 / **C-2 既存と同一 `stale > base`** | **C-2** | 期待集合が空（base=0）なら stale>0 で必ず発火し、#877 の実害（22→7 の無警告削除）を直接塞ぐ。経路ごとに閾値を変えると override 頻発（形骸化）と判定根拠の分散を招く |
| **D. README 除外の扱い** | D-1 `sync_dir` と同じく README.md を src/dst 双方から除外 / **D-2 除外しない（`*.md` 全件）** | **D-2** | 経路1/2 の対象は skill の `references/` 配下で、`sync_dir`（`.claude/agents` 等）と違い README.md を同期対象に含む慣習がない。除外条件を増やすと src/dst の対称性検証（既存 TC-17 相当）が経路ごとに必要になり保守コストが上がる。**C-2 で実測確定（U-1・R-353）**: 経路1 の対象 skill（`skill-creator` / `review-gate`）の src 側 `references/` に README.md は不在。`plugin/plangate/skills/ai-loop-cycle/references/README.md` は実在するが、これは経路2 が `_ai_loop_spec_files`（L212）経由で正規同期する対象であり D の判断対象外 → **D-2 を維持** |
| **D'. symlink 除外の対称性** | D'-1 base/stale 集計では symlink を数える / **D'-2 コピーループと同一条件で `[ -L ]` 除外** | **D'-2** | 経路1 のコピーループ（L163）は `[ -L "$_rf" ] && continue` で symlink を明示除外している（#805 対応）。集計側で除外しないと「N 件と数えて guard を通したのに実際は M 件消す」= `sync_dir` 自身が L91-93 のコメントで名指し警告する **#861 再発型の guard 無効化**を招く。現状 `.agents/skills/*/references/` の symlink は 0 件（実測）で顕在化しないが、1 件追加されただけで閾値が静かにズレる（R-351） |
| **E. R-204 の env 無害化手段** | E-1 共有 preamble ファイル `_standalone-preamble.sh` / **E-2 各本にインライン 1 行** | **E-2** | ta-26 の既存実装と同型（既存パターン準拠）。共有ファイルは `ta-*.sh` glob 外の新規ファイル導入で、extras 自己完結の慣習を崩す。11 箇所の重複は許容し、共通化は V2 候補（drift 検知は AC-9 の静的検査で担保 — R-306） |
| **F. unset 対象 env** | F-1 `PLANGATE_ALLOW_MASS_DELETE` のみ（ta-26 と同一） / **F-2 `run-tests.sh` の unset リストと同一集合** | **F-2** | 今回の実害は `PLANGATE_HOOK_TASK` 漏洩（ta-26 の unset 対象外）だった。harness が無害化している集合と standalone が無害化する集合を揃えるのが「判別方式の統一」の趣旨に一致。**対象 env は下記に明示列挙**（行番号参照のみだと #915 マージ後のような行シフトで検証不能になる — R-306） |

#### 論点 F の対象 env（明示列挙 / `run-tests.sh` の unset 集合と一致させる）

```text
PLANGATE_SKIP_REASON  PLANGATE_HOOK_TASK  PLANGATE_HOOK_FILE  PLANGATE_BYPASS_HOOK
PLANGATE_HOOK_STRICT  PG_HARNESS_SOURCED  PLANGATE_ALLOW_MASS_DELETE
```

**7 件**（main `90c313d` 実測）。Step 5 の完了判定は「この列挙集合と各 extras の standalone unset 集合が一致」で行い、将来の drift は AC-9 の静的検査（`run-tests.sh` の集合 ⊆ 各 extras の集合）で検出する。

### 実害の実測（本 plan 作成時に再現）

`PLANGATE_HOOK_TASK=TASK-0914` が設定されたシェルから `sh tests/extras/ta-39-eh3-doc-light.sh` を standalone 実行すると **7 件 FAIL**（PASS 1）（EH-3 が sandbox 外の TASK-0914 の plan.md を探しに行く）。`env -u PLANGATE_HOOK_TASK` で再実行すると**全 PASS**。exit code はいずれも 0 のため CI・手元双方で静かに通る。これが R-204（外部 env 漏れによる誤判定）の実害実例であり、AC-7 の回帰テスト対象。

## 受入基準（確定版）

pbi-input の AC-1〜AC-6 を継承し、**AC-6 を強化**・**AC-7 / AC-8 / AC-9 を追加**する（2026-07-25 Human 決定「案 C」+ C-2 指摘 R-301 / R-304 / R-306 に基づく。差分は下表の「pbi からの変更」列）。

| ID | 内容 | pbi からの変更 |
|----|------|--------------|
| AC-1 | ai-loop references 削除ループ（`_ai_loop_expected_refs` 駆動）で期待集合が空/極小のとき削除を保留し、`guard_fired` 経由で終端 `exit 3` する | 継承 |
| AC-2 | 汎用 references 削除ループ（`_src_refs`/`_dst_refs` 突合）でも同様（`_src_refs` 空化ケース） | 継承 |
| AC-3 | 各経路の負側テスト（guard 発火）と正常系テスト（通常削除）が `tests/extras/ta-26-plugin-sync.sh` に追加される | 継承 |
| AC-4 | `PLANGATE_ALLOW_MASS_DELETE=1` による override が全経路で一貫して効く | 継承 |
| AC-5 | `tests/extras/README.md` に harness 判別規約が明記される | 継承 |
| AC-6 | 既存 11 extras が `PG_HARNESS_SOURCED` 方式へ移行し、`sh tests/run-tests.sh`（**444 passed / 0 failed** = 430 + 新規 14 TC）と各 standalone 実行の双方が **①出力に `[FAIL]` を含まない ②exit 0 ③`[PASS]` 件数が移行前 baseline と一致**（3 条件すべて） | **強化**（現状 11 本は exit code に FAIL を反映しないため「exit 0」単独では空振り。さらに③がないと「分岐に入らず 1 件も実行せず exit 0」でも条件を満たす — R-301） |
| AC-7 | `PLANGATE_HOOK_TASK` 等の `PLANGATE_*` / `PG_HARNESS_SOURCED` / `FIXTURES_DIR` が**外部から汚染された状態**で 11 本を standalone 実行しても、AC-6 の 3 条件と同一結果になる | **追加**（今回の実害の直接的な回帰。R-204 の趣旨＝外部 env 漏れ耐性そのもの） |
| AC-8 | extras 11 本の standalone exit code 伝播欠落が独立 issue として起票され、本 PBI の scope 外であること・切り出しの代償が handoff の「妥協点」に記録される | **追加**（案 C のスコープ境界を成果物として固定する。R-309） |
| AC-9 | `tests/extras/ta-*.sh` に対する静的検査（**`ta-26` も対象**）で、**`PG_HARNESS_SOURCED` を伴わない `FIXTURES_DIR` 単独の harness 判別が 0 件**であること。あわせて `run-tests.sh` の unset 集合 ⊆ 各 extras の standalone unset 集合 であること（いずれも **11 という件数をハードコードしない** grep ベース判定） | **追加**（R-304 / R-306。「統一」は全体性質であり、個別ファイルの置換完了とは別命題。挙動テストだけでは残存を検出できない） |

## Work Breakdown

### Step 1: 前提実測と guard 共通関数の導入

- **Output**: `_mass_delete_blocked()` が `scripts/sync-plugin-plangate.sh` に追加され、既存 `sync_dir` 内 guard（**L103-113**。内側 `if`〜対応する `fi` 2 個までを含む — R-352）が同関数呼び出しへ置換される。`sh -n` PASS、`sh tests/run-tests.sh` が **430 passed / 0 failed** を維持
- **Owner**: agent
- **Risk**: 中（既存 guard の挙動を変えると TC-08〜TC-17 が回帰する）
- 🚩 **チェックポイント**: 置換後に `tests/extras/ta-26-plugin-sync.sh` の既存 **16 TC**（TC-14 は欠番）が全 PASS すること（`sync_dir` 経路の挙動不変を証明）
- **事前実測（R-301 / AC-6 の baseline 確立）**: 移行前の 11 本について ①各本の `[PASS]` 件数（AC-6 条件③の baseline）②失敗表記が全 11 本で `[FAIL]` に統一されているか（非統一なら AC-6 の判定語彙を拡張）を実測し `status.md` へ記録する
- **WARN 文の維持必須語（RV-m4）**: 共通関数化で既存 WARN 文を書き換える際、`#861 safety guard` / `解除しました` / `mass-delete safety guard が発火` の **3 語は変えない**（既存 TC-08 / TC-12 が grep で判定しているため、変えると guard 挙動と無関係な理由で 🚩 が落ちる）。`src=` → `base=` の語彙変更のみ許容
- U-1 / U-2 は C-2 で解消済み（[`review-external.md`](./review-external.md) §Unknowns の解消）。Step 1 での再実測は不要
- `rollback:` `git checkout -- scripts/sync-plugin-plangate.sh`

### Step 2: 経路2（ai-loop references）へ guard 適用

- **Output**: `_ai_loop_expected_refs` の要素数を `_ai_loop_ref_base_count` として算出し、`PLUGIN_AI_LOOP_REFS` 内の非期待 `*.md` 数を `_ai_loop_ref_stale_count` として先に集計。`_mass_delete_blocked` が blocked を返したら L316-329 の削除ループ全体を skip する
- **Owner**: agent
- **Risk**: 高（真の hazard 経路。閾値誤りで正当な reference 削減が block されると override が頻発し形骸化する）
- 🚩 **チェックポイント**: 「正本 2 ディレクトリ両方が空/消失 → guard 発火 + exit 3」「1 ファイルだけ正当に削除 → guard 非発火で削除実行」の双方を手動再現し、**実行ログを `evidence/verification/` へ保存**してから Step 3 へ進む（R-308。本経路は「最も危険な silent failure」に該当するため証跡必須）
- 実装メモ: 件数算出は `set -- $_ai_loop_expected_refs; _n=$#`（未 quote 展開が意図的なワード分割）。**C-2 実測（U-2）で後段の位置パラメータ使用が 0 件（`$@` / `shift` / `set --` なし、`$1` は L10 の `--dry-run` 判定のみ）と確定したため、この手法は安全**。`for` カウントループへの切替は不要
- `rollback:` `git checkout -- scripts/sync-plugin-plangate.sh`

### Step 3: 経路1（汎用 references）へ guard 適用

- **Output**: L173-183 のループについて、削除実行前に `_src_refs` 内 `*.md` 数（base）と `_dst_refs` 内で src に無い `*.md` 数（stale）を集計し、`_mass_delete_blocked "skills/$_skill_name/references" ...` で判定。blocked なら当該 skill の references 削除のみ skip（他 skill の処理は継続）
- **集計条件（R-351 / 論点 D'）**: base / stale の集計ループには**コピーループ（L163）と完全に同一の除外条件** `[ -L "$_rf" ] && continue` を入れる。集計定義と実削除条件を一致させないと「N 件と数えて guard を通したのに M 件消す」= #861 再発型の guard 無効化になる（`sync_dir` L91-93 のコメントが名指しで警告しているハザードクラス）
- **Owner**: agent
- **Risk**: 中（skill 単位ループ内での早期 skip。`continue` と `break` の取り違えで他 skill の処理を落とす懸念）
- 🚩 **チェックポイント**: 複数 skill のうち 1 つだけ空化した sandbox で、当該 skill のみ削除保留・他 skill は正常同期されることを確認し、**実行ログを `evidence/verification/` へ保存**（R-308）
- `rollback:` `git checkout -- scripts/sync-plugin-plangate.sh`

### Step 4: テスト追加（ta-26）

- **Output**: `tests/extras/ta-26-plugin-sync.sh` に経路1/経路2 の負側（guard 発火 + exit 3）・正常系（通常削除）・override・dry-run/実行の判定一致・静的検査の TC を追加。新規ヘルパー `_t26_mk_refs_guard_sandbox` / `_t26_mk_ai_loop_guard_sandbox` を既存 `_t26_mk_guard_sandbox`（L197-215）と同型で実装
- **タスク粒度**: 14 TC を 1 タスクで扱うと独立検証できないため、todo では **T-05a（経路2 TC）/ T-05b（経路1 TC）/ T-05c（静的 TC）に 3 分割**する（C-1 自己検出）
- **Owner**: agent
- **Risk**: 中（sandbox 構築が経路ごとに非対称。経路2 は `scripts/_ai_loop_link_rewrite.py`（python3 依存）を同梱する必要がある）
- 🚩 **チェックポイント**: **変異注入で検出力を実証**する — guard 適用前の実装（`git stash` 相当）に対して新規 TC が FAIL することを確認してから受理。空振り fixture を作っていないことの証明
- 実装制約: sandbox は既存 TC-08〜TC-17 と同じ**最小構成**（`CHANGELOG.md` / `.claude-plugin/marketplace.json` を置かない）にする。フル sandbox を真似ると marketplace 同期経路の exit 1 が有効化され guard の exit 3 と衝突する（#877 plan Risks 表の既知事象）
- rc 捕捉は `_rc=0; _out=$(sh ...) || _rc=$?` の型（`|| true` 直後の `$?` 空振りパターンを書かない）
- `rollback:` `git checkout -- tests/extras/ta-26-plugin-sync.sh`

### Step 5: R-204 — extras 11 本の判別方式統一 + env 無害化

- **Output**:
  - 11 本（ta-39/43/44/45/46/47/49/50/51/52/53）の `if [ -n "${FIXTURES_DIR:-}" ]; then` を `if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then` へ置換
  - **ta-39 のみ例外構造（R-350）**: 同ファイルは当該文字列を **2 箇所**持つ（L14 = ROOT 解決 / L55 = apply 未適用時の `return`/`exit` 分岐）。**2 箇所とも AND 条件化する**が、`unset` は **L14 側の else 節にのみ**追加する（L55 側は ROOT 解決ではないため無害化の対象外）。他 10 本は 1 箇所のみ（実測）
  - 各本の standalone 分岐（else 節）に論点 F の **7 env** の `unset` を追加
  - **`ta-26-plugin-sync.sh` の standalone unset も 7 env へ拡張（RV-M3）**: ta-26 は既に AND 判別済みだが unset は `PLANGATE_ALLOW_MASS_DELETE` 1 件のみ（実測）。AC-9 の包含検査は ta-26 も対象とするため、拡張しないと **TC-33 が自ファイルで自テストを落とす**。ファイル数 14 は不変（ta-26 は Step 4 で既に変更対象）
  - `tests/extras/README.md` の「隔離・後始末の規約（#530）」節へ項目 8 として判別規約を追記
- **Owner**: agent
- **Risk**: 低〜中（機械的置換だが 11 箇所 + ta-39 の例外。unset 追加位置を誤ると harness 実行側の env を壊す）
- 🚩 **チェックポイント**: `sh tests/run-tests.sh` が 0 failed を維持 + **AC-6 の 3 条件**（`[FAIL]` 不在 / exit 0 / `[PASS]` 件数が baseline 一致）+ **AC-7**（汚染 env 下でも同結果）+ **AC-9**（単独判別の残存 0・unset 集合の包含）
- `rollback:` `git checkout -- tests/extras/ tests/extras/README.md`

### Step 6: 別 issue 起票（スコープ切り出しの明示）

- **Output**:
  - 「extras 11 本の standalone 実行が内部 FAIL を exit code に反映しない（`exit $fail` 相当が欠落し、失敗が静かに通る）」を独立 issue として起票。本 plan の論点と実測（ta-39 の 6 FAIL が exit 0 で通った事実）を根拠として添付
  - **handoff.md の「妥協点」へ案 C の代償を記録（R-309 / AC-8）**: ①同一 11 ファイルを本 PBI と follow-up issue で 2 回触る（コンフリクト・二重レビューのコスト）②AC-6 の代理判定（`[FAIL]` 文字列 + `[PASS]` 件数）が follow-up 完了まで恒久的な検証手段として残る。follow-up 完了時に **AC-6 の判定を exit code ベースへ戻す**旨を V2 候補として明記
- **Owner**: agent（起票まで。優先度ラベル付与は issue-governance に従う）
- **Risk**: なし
- `rollback:` 不要（起票のみ。誤起票時は close）

## Files / Components to Touch

| ファイル | 変更種別 | Step |
|---------|---------|------|
| `scripts/sync-plugin-plangate.sh` | 関数追加 + 3 箇所の guard 適用 | 1/2/3 |
| `tests/extras/ta-26-plugin-sync.sh` | TC + ヘルパー追加 **+ standalone unset を 7 env へ拡張**（RV-M3） | 4 / 5 |
| `tests/extras/README.md` | 規約 1 項目追記 | 5 |
| `tests/extras/ta-39-eh3-doc-light.sh` | 判別式 + unset | 5 |
| `tests/extras/ta-43-eh2-strict-json.sh` | 同上 | 5 |
| `tests/extras/ta-44-eh457-cli-wiring.sh` | 同上 | 5 |
| `tests/extras/ta-45-c3-mode-config.sh` | 同上 | 5 |
| `tests/extras/ta-46-ehs-wiring.sh` | 同上 | 5 |
| `tests/extras/ta-47-ehs23-wiring.sh` | 同上 | 5 |
| `tests/extras/ta-49-bias-export.sh` | 同上 | 5 |
| `tests/extras/ta-50-precompact-guard.sh` | 同上 | 5 |
| `tests/extras/ta-51-doctor-w6.sh` | 同上 | 5 |
| `tests/extras/ta-52-doctor-skill-collision.sh` | 同上 | 5 |
| `tests/extras/ta-53-doctor-prepush.sh` | 同上 | 5 |

**計 14 ファイル**（`docs/working/TASK-0914/**` の plan/todo/test-cases/status/handoff を除く）。

## Testing Strategy

| 層 | 内容 |
|----|------|
| **Unit（shell）** | `sh -n scripts/sync-plugin-plangate.sh`（syntax）。`_mass_delete_blocked` の単体相当は ta-26 の TC で境界値（stale=base / stale=base+1 / base=0）を突く |
| **Integration** | `tests/extras/ta-26-plugin-sync.sh` の sandbox 実行。**経路1/2 それぞれで 負側（発火→exit 3）/ 正常系 / override / dry-run 一致 の 4 系統**（経路1 の dry-run 一致 = TC-32。R-303 で欠落を是正） |
| **Regression** | `sh tests/run-tests.sh` = **430 passed / 0 failed**（baseline 実測値、main `90c313d`）→ 新規 14 TC 追加後は **444 passed / 0 failed** |
| **Static** | AC-9（単独判別の残存 0 / unset 集合の包含）と AC-5（README 規約）は grep ベースの静的検査。**件数をハードコードしない**（R-304） |
| **Verification Automation** | AC-6 / AC-7 は 11 本を機械検証するループを **3 本に分離**: clean（V-1-A）/ `FIXTURES_DIR` 漏れ（V-1-B）/ `PG_HARNESS_SOURCED` 単独漏れ（V-1-B'）。V-1-A の `env -u` を流用すると汚染が剥がれ（R-302）、AND を両方注入すると harness 分岐へ入って全 TC が消える（RV-M2）。**全ループで `sh "$f" </dev/null` 必須**（RV-M1: 未リダイレクトだと `ta-50` が無限ハング）。3 ループを status.md に記録し V-1 で再実行 |
| **変異注入（必須）** | Step 4 で新規 TC の検出力を実証。弱体化方向（M-1〜M-5）+ 過剰発火（M-6 / **M-6b**）+ override 無効化（M-7）の **計 8 変異**（R-305 / RV-M4）。M-6 の対象は TC-24 / TC-29 に限定し、閾値の 1 段ずれ（`stale >= base`）は専用 fixture **TC-34** を持つ M-6b で突く |

## Risks & Mitigations

| Risk | 影響 | Mitigation |
|------|------|-----------|
| 経路2 の閾値設計を誤り、正当な reference 削減が block される | override 頻発 → guard の形骸化 | 閾値は既存と同一 `stale > base`（論点 C）。「1 件だけ削除」の正常系 TC を必ず置く（Step 2 🚩） |
| `set -- $_ai_loop_expected_refs` が位置パラメータを破壊し後段が壊れる | サイレント誤動作 | Step 2 で `$@` / `$1` の後段使用を grep で実測確認。使用があれば `for` カウントループへ切替 |
| 経路1 の skip を `break` で実装して他 skill の同期が落ちる | 同期漏れ | Step 3 🚩 で複数 skill sandbox を検証 |
| ta-26 の新規 sandbox をフル構成で作り marketplace 経路 exit 1 と衝突 | テストが guard 以外の理由で fail | 最小構成を明示（Step 4 実装制約） |
| 11 本の unset 追加位置を誤り harness 側の env を壊す | run-tests.sh の他テストが連鎖失敗 | unset は **standalone 分岐（else 節）の内側のみ**。Step 5 🚩 で 430/0 を確認 |
| `guard_fired` が新規呼び出し箇所でサブシェル内に入り global へ伝播しない | guard 発火しても exit 3 にならない（最も危険な silent failure） | 全呼び出しを `$(...)` 外に置く。exit 3 の TC を経路ごとに必ず置く（AC-1/AC-2 は exit 3 まで含めて判定） |
| AC-6 が exit code 伝播欠落により空振りしたまま | 移行の検証が形骸化 | AC-6 を 3 条件（`[FAIL]` 不在 / exit 0 / `[PASS]` 件数 baseline 一致）へ強化 + AC-7（env 汚染下）を追加。伝播そのものは Step 6 で別 issue 化 |
| 判別式の置換ミスで standalone 分岐に入らず「1 件も実行せず exit 0」になる | AC-6 が空振りし Step 5 が無検証で PASS（**最も起きやすい失敗モード**） | AC-6 条件③（`[PASS]` 件数 baseline 一致）で検出。baseline は Step 1 で 11 本分を実測記録（R-301） |
| 集計側と削除側の除外条件が非対称（symlink） | 「N 件と数えて M 件消す」= #861 再発型の guard 無効化 | 論点 D'-2。集計ループにコピーループと同一の `[ -L ]` 除外を入れる（R-351） |
| `${FIXTURES_DIR:-}` 単独判定が別ファイル/将来分に残存し「統一」が未達 | 挙動テスト（AC-6/AC-7）は clean env なら PASS するため残存を検出できない | AC-9 の静的検査（残存 0・件数ハードコードなし）で担保（R-304） |

## Questions / Unknowns

- ✅ **U-1（C-2 で解消）**: 経路1 の対象 skill（`skill-creator` / `review-gate`）の src 側 `references/` に README.md は**不在** → 論点 D-2 維持。`ai-loop-cycle/references/README.md` は実在するが経路2 が正規同期する対象で D の判断対象外（R-353）
- ✅ **U-2（C-2 で解消）**: 位置パラメータの後段使用は **0 件** → `set -- $_ai_loop_expected_refs` は安全
- **U-3（残る前提）**: `run-tests.sh` の unset リストが今後増えたとき、11 本のインライン unset との同期が手作業になる（論点 E の代償）→ **AC-9 の静的検査（`run-tests.sh` の集合 ⊆ 各 extras の集合）で drift を機械検出**し、恒久解の「standalone preamble 共通化」は V2 候補（R-306）
- **U-4（Step 1 で解消）**: 11 本の失敗表記が全て `[FAIL]` で統一されているか（非統一なら AC-6 条件①の判定語彙を拡張する。R-301）

## Stop Condition（即停止条件 / #544 AEE）

以下のいずれかに達したら **exec を止めて Human 判断を仰ぐ**（自律継続しない）。

1. **変更ファイル数が 16 以上**に達した（= critical 帯。Mode 再判定が必要）
2. **`guard_fired` の global 伝播が実装上どうしても成立しない**ことが判明した（POSIX sh のサブシェル制約に抵触。設計 A-2 の前提崩壊 → 論点 A の再検討が必要）
3. **変異注入（M-1〜M-7）で FAIL を確認できない TC が 1 件以上**残り、TC 設計の作り直しでも解消しない（= 検出力を実証できない → AC-3 の受理条件を満たせない）
4. **経路1/2 の閾値で override が必須になる正当ケース**が sandbox 検証中に判明した（= 論点 C の「経路ごとに閾値を変えない」判断が崩れる）
5. **HO 対象パスへの変更が必要**になった（現計画は非該当。必要になった時点で Human C-3 再承認が必須）
6. `sh tests/run-tests.sh` の **failed > 0 が同一原因で 3 回連続**し、かつ **RT-2 の再計画を実施しても解消しない**（RT-2 が先に走る。本条件は最終手段 — RV-i1）
7. **検証ループ（V-1-A / V-1-B / V-1-B'）が 60 秒を超えて無応答**（RV-M1: `</dev/null` 漏れで `ta-50` が `cat` にブロックされる既知の故障。まず stdin リダイレクトを確認し、それでも解消しなければ停止）

## Replan Triggers（機械値 / #544 AEE）

| # | トリガー（機械判定可能な値） | 再計画の内容 |
|---|------------------------------|-------------|
| RT-1 | 変更ファイル数 `> 15` | Mode を critical へ引き上げ、V-4（リリース前チェック）を追加。C-3 再承認 |
| RT-2 | `sh tests/run-tests.sh` の `failed > 0` が 3 回連続（同一原因） | 該当 Step の設計を見直し、todo を再生成 |
| RT-3 | M-1〜M-7 のうち **期待 FAIL が出ない変異が 1 件以上** | 対応 TC の fixture を再設計（空振り fixture の疑い） |
| RT-4 | V-1-A / V-1-B の `NG` 件数 `> 0` が 2 回連続 | Step 5 の置換方針（論点 E / F）を再検討 |
| RT-5 | `_ai_loop_expected_refs` の要素数が **移行前後で変化**（同期対象の意図しない増減） | 経路2 の集計ロジックを再設計 |
| RT-6 | 新規 TC 追加後の総テスト数が **444**（430 + 新規 14 TC）と **一致しない** | TC の重複・未登録を調査（`ta-26` への登録漏れ）|

## Mode判定

**モード**: **high-risk**

**判定根拠**:

- 変更ファイル数: **14**（sync 1 + ta-26 1 + README 1 + extras 11）→ high（6-15）
- 受入基準数: **9**（AC-1〜AC-9。C-2 反映で AC-9 追加）→ high（6-10）
- タスク数（見込み）: 6 Step / 実装単位で 11-20 相当 → high
- 変更種別: バグ修正（安全 guard 適用）+ テスト基盤の横断的変更 → high
- リスク: 高（silent failure の可能性がある guard 実装 + 11 ファイル横断）
- ロールバック: 計画的に必要（Step 単位で `git checkout --` 可）
- HO 対象パス: **非該当**（`scripts/` 直下 / `tests/**` のみ。`scripts/hooks/*.sh` ではない）
- **最終判定**: **high-risk** — 定量・定性ともに high。`lite_eligible=false`（新規設計あり = guard 共通関数の導入）。**C-3 は Human 必須**（mode-classification: high-risk は autonomous APPROVE 不可）。C-2 外部レビューは複数観点で実施
