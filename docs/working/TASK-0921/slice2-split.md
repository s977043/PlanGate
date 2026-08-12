# TASK-0921 Slice 2 サブスライス 3 分割設計書

> **Status**: 分割設計（plan 前段階）。**本書は plan.md（C-3 承認済み・編集禁止）を変更しない別紙**。
> **Refs**: Human 裁定（2026-08-12・plan D-5）= issue [#921](https://github.com/s977043/plangate/issues/921) 2026-08-12 05:49 コメント
> 「Slice 2（層 B 36 + 層 C 5 + 層 0 の 4 + writeback = 46 ファイル）は**サブスライス 3 分割**で進める
> （1 本あたり 13-15 ファイル = high-risk 帯・C-3 はサブスライスごとに発行）。critical 一括は不採用」
> **前提**: Slice 1 は PR #1046（merge commit 48f6971）でマージ済み（層 A 12 本 + `_extra-contract.sh` +
> ta-61 contract TA + README rc 契約。変異 18/18 KILL・フルスイート 612/0）

## 1. 実ファイル再列挙（2026-08-12 / base = origin/main `6089e23`）

plan.md の Slice 2 対象を現 main で再実測した結果。

| 項目 | plan 時点 | 現 main 実測 | 差分 |
|---|---:|---:|---|
| `ls tests/extras/ta-*.sh \| wc -l` | 57 | **58** | **+1 = `ta-61-extra-contract.sh`**（Slice 1 で追加された contract TA 本体。**Slice 1 帰属・Slice 2 の移行対象ではない**。ただし各サブスライスで allowlist 縮約のため touch する — §3） |
| `_extra-contract.sh` を source 済み（移行済み） | 0（plan 時点） | **13** = 層 A 12 + ta-61 | Slice 1 完了と整合 |
| ta-61 `_pending_migration` 行数 | —（Slice 1 生成物） | **45** | **層 B 36 + 層 C 5 + 層 0 4 = 45 と完全一致。増減なし** |
| ta-62 以降の新規追加 | — | **存在しない** | — |

**結論: Slice 2 の移行対象は plan 時点から増減なし（45 本 + writeback 1 = 46）。**
plan の層帰属（層 B 36 / 層 C 5 / 層 0 4）はそのまま有効。

### 層別の実ファイル一覧（pbi-input L93-98 層表 / plan L318-330 層帰属サマリを現 main で照合済み）

- **層 0（4 本 / 既存 standalone 契約の helper 吸収）**: `ta-26-plugin-sync.sh` / `ta-58-git-destructive-guard.sh` / `ta-59-apply-settings-merge.sh` / `ta-60-run-evidence.sh`
- **層 B（36 本 / harness-only 化 = fail-fast exit 2）**: `ta-04` `ta-05` `ta-07` `ta-09` `ta-10` `ta-12` `ta-13` `ta-14-codex-guarded` `ta-14-skip-acknowledge` `ta-15` `ta-16` `ta-17` `ta-18` `ta-19` `ta-20` `ta-21` `ta-22` `ta-23` `ta-24` `ta-25` `ta-27` `ta-28` `ta-29` `ta-30` `ta-31` `ta-33` `ta-34` `ta-35` `ta-36` `ta-37` `ta-41` `ta-42` `ta-54` `ta-55` `ta-56` `ta-57`
- **層 C（5 本 / HJ-2 裁定: D-2 (c) により層 B と同一クラスで harness-only 化）**: `ta-06` `ta-08` `ta-11` `ta-32` `ta-38`
- **writeback（1 本）**: `docs/working/TASK-0914/handoff.md`（§3 V2 候補表『#921 完了時に AC-6 の判定を exit code ベースへ戻す』行のクローズ。plan AC-6）

## 2. 依存: TASK-1044（bootstrap 述語 = Mode resolution v2）— 全サブスライス共通の前提

**TASK-1044**（PR #1049 マージ済み・**C-3 待ち**）は bootstrap 述語を「Mode resolution v2
（`_pg_extra_resolve_mode` 変数消費形ガード）」へ変える plan を持つ。**Slice 2 の全 45 本の移行は
「どちらの述語（現行形 / v2 変数消費形）を複製するか」が TASK-1044 の C-3 結果に依存する。**

| TASK-1044 C-3 結果 | Slice 2 が複製する bootstrap |
|---|---|
| APPROVED → exec 完了 | **v2（変数消費形）** を複製（TASK-1044 が層 A + ta-61 を v2 化した後の main 実体を雛形にする） |
| REJECTED | **現行形** を複製 |

**織り込み（BLOCKED 扱い）**:

- 各サブスライスの **plan 作成は TASK-1044 決着前でも可**だが、**exec 開始は TASK-1044 の C-3
  決着（+ APPROVED の場合はその exec/merge 完了）後**とする。blocker = TASK-1044 C-3 /
  owner = human / unblock_condition = TASK-1044 の C-3 発行（REJECT なら即解除、APPROVE なら
  TASK-1044 merge 後に解除）。
- **複製元は plan にハードコードしない**: 各サブスライス exec 開始時に
  `tests/extras/_extra-contract.sh` と移行済みファイル（層 A / 先行サブスライス）の bootstrap を
  **main 実体から再実測して雛形にする**（plan の「file count / ta 番号をハードコードしない」制約、
  および feedback「plan の記述は exec で初めて検証される」と同方針）。
- 中間状態（SS-1 完了後に TASK-1044 相当の述語変更が別途入る等）が生じた場合は、**述語の混在を
  contract TA（ta-61）が検出する構造が正**であり、混在検出時は当該サブスライスを停止して Human へ。

## 3. 3 サブスライス割り当て案

**設計原則**: (1) 層 0 は既存 standalone 契約の吸収＝**性質が違う**ため最終サブスライスへ隔離し、
plan 明記の Stop Condition（TC-33 差し替え設計の再読・確定 — plan L1060-1065）を単独で扱う。
(2) 機械的に同型な層 B/C（marker + init + fail-fast exit 2）は件数で均等割り。
(3) リスク均等化: 最難の層 0 を持つ SS-3 は同型作業を最少（11 本）にする。
(4) 各サブスライスで ta-61 の `_pending_migration` から移行済み basename を削除（allowlist 縮約）—
これが contract TA の検査対象化＝移行の機械検証であり、省略不可（plan Human 決定 4 の設計コスト）。

| サブスライス | 移行対象（ta-*.sh） | 本数 | 付随 touch | 実 touch 数 | Mode 見込み |
|---|---|---:|---|---:|---|
| **SS-2-1**（層 B 前半） | `ta-04` `ta-05` `ta-07` `ta-09` `ta-10` `ta-12` `ta-13` `ta-14-codex-guarded` `ta-14-skip-acknowledge` `ta-15` `ta-16` `ta-17` `ta-18` `ta-19` `ta-20` | **15** | ta-61 allowlist 縮約（15 行削除） | 16 | **high-risk**（§3.1） |
| **SS-2-2**（層 B 後半） | `ta-21` `ta-22` `ta-23` `ta-24` `ta-25` `ta-27` `ta-28` `ta-29` `ta-30` `ta-31` `ta-33` `ta-34` `ta-35` `ta-36` `ta-37` | **15** | ta-61 allowlist 縮約（15 行削除） | 16 | **high-risk**（§3.1） |
| **SS-2-3**（層 B 残 + 層 C + 層 0 + writeback） | 層 B: `ta-41` `ta-42` `ta-54` `ta-55` `ta-56` `ta-57` / 層 C: `ta-06` `ta-08` `ta-11` `ta-32` `ta-38` / 層 0: `ta-26` `ta-58` `ta-59` `ta-60` | **15** | ta-61 allowlist **残 15 行削除 + `_pending_migration` 関数ごと削除**（plan L374 の完了条件）+ `TASK-0914/handoff.md` writeback | 17 | **high-risk**（§3.1・要 C-3 確定） |

検算: 15 + 15 + 15 = **45**（層 B 36 + 層 C 5 + 層 0 4。過不足なし・重複なし）。

### 3.1 Mode 判定の正直な注記（裁定の 46 と実 touch 数の乖離）

Human 裁定は「46 ファイル → 3 分割・1 本 13-15 = high-risk 帯」だが、**各サブスライスは移行対象に
加えて ta-61（allowlist 縮約）を必ず touch する**ため、実 touch 数は 16 / 16 / 17 となる。
移行対象 45 本を 3 分割して各 ≤14 に抑えても ta-61 込みで 45 本は 3 本に収まらない
（14×3 = 42 < 45）＝ **「ta-61 込みで全サブスライス ≤15」は数学的に不成立**。

- **本案の立場**: 定量算入の主対象は「移行対象 15 本」= high-risk 帯（6-15）。ta-61 の行削除
  （SS-2-3 のみ関数削除）と `TASK-0914/handoff.md`（作業コンテキスト文書）を定量算入するかは
  **各サブスライス plan の Mode 判定節で明示し、C-3 で Human が確定する**（G-2）。
- 安全側原則（mode-classification「判定不能なら引き上げ」）を厳密適用すると 16+ = critical 帯に
  触れるが、裁定が「critical 一括は不採用・13-15 = high-risk 帯・C-3 はサブスライスごと」を明示
  しているため、**本書では見込み = high-risk とし、確定は各 C-3 に委ねる**（勝手に緩和も引き上げ確定もしない）。

### 3.2 サブスライス別の scope / 依存 / 停止条件

#### SS-2-1（層 B 前半 15 本）

- **Scope**: 上表 15 本へ marker + init + fail-fast ガード（standalone 検知 → 明示メッセージ →
  exit 2）。ta-61 allowlist から 15 basename 削除。負側テスト（standalone rc=2 / harness 完走）。
- **依存**: TASK-1044 C-3 決着（§2）。先行サブスライスなし（Slice 2 の先頭）。
- **停止条件**:
  - exec 開始時の再実測で `ls tests/extras/ta-*.sh` が 58 本 + 想定集合と不一致（新規 ta-62 等の出現を含む）
  - `_pending_migration` の実体が 45 行でない（先行変更の混入）
  - AC-4 baseline（`sh tests/run-tests.sh`）が exec 開始時再実測で FAIL
  - bootstrap 述語が main 上で確定できない（TASK-1044 中間状態の混在検出）

#### SS-2-2（層 B 後半 15 本）

- **Scope**: SS-2-1 と同型 15 本。ta-61 allowlist から 15 basename 削除。
- **固有リスク**: **`ta-31-codex-plugin-status.sh` は `mktemp` 失敗時にだけ通る `return 0
  2>/dev/null || true` 型を 4 箇所持つ**（plan L131 / issue 2026-08-12 コメントでも Slice 2 残件と
  明記）。harness-only 化（exit 2 ガード）は body 到達前に効くため原則衝突しないが、**分岐内
  早期脱出の扱い（除去するか・ガードで到達不能として残すか）を SS-2-2 plan で明示**する。
- **依存**: TASK-1044 C-3 決着。SS-2-1 完了（allowlist 縮約の直列性: ta-61 の同一関数を編集するため
  並行させない。契約検証の前提も先行分の main 反映が前提）。
- **停止条件**: SS-2-1 と同一 + ta-31 の 4 箇所の設計が plan 段階で確定していない場合は exec 前に停止。

#### SS-2-3（層 B 残 6 + 層 C 5 + 層 0 4 + writeback）

- **Scope**:
  - 層 B 残 6 + 層 C 5 = 11 本を harness-only 化（層 C は HJ-2 裁定 = D-2 (c) により層 B と同一クラス。
    fail-fast は `fail` カウンタに依存しないため空振り PASS も塞がる）
  - **層 0 の 4 本 = 既存 standalone 契約（legacy footer 2 系統）の helper 吸収**（marker + init +
    末尾 finalize。plan Task 4b / R-003）。**harness-only 化ではない**（finalize 型）— 取り違えたら即停止
  - ta-61: 残 15 行削除 + **`_pending_migration` 関数ごと削除**（Slice 2 完了の機械的証跡）
  - `docs/working/TASK-0914/handoff.md` writeback（§3 V2 候補表の当該行クローズ。**他行は不変**）
- **依存**: TASK-1044 C-3 決着。SS-2-2 完了。
- **停止条件**（SS-2-1 共通分に加えて）:
  - **plan.md の TC-33 差し替え節（L1040-1065 付近）を再読し差し替え設計が確定するまで層 0 に着手しない**
    （plan 明記の Stop Condition）
  - 層 0 の legacy footer（`ta-26` 形 / `ta-59`・`ta-60` 形の 2 系統）が plan の実測（R-015a / MN-6）と
    現 main で一致しない場合は停止・再実測
  - `TASK-0914/handoff.md` の対象行が特定できない・当該行以外への波及が必要になった場合は停止（scope 拡大）

## 4. 管理方式 — **案 B 採用（Human 裁定 2026-08-12・AskUserQuestion / G-1 確定）**

> **確定（2026-08-12 Human 裁定・AskUserQuestion 経由）**: **案 B = サブスライスごとに新 TASK ×3 を
> 起票**し、各 TASK が自前の plan.md / plan_hash / `approvals/c3.json` を持つ（issue #921 を親 Refs）。
> 同時に **G-3 = 本分割案（§3 の SS-2-1 / 2-2 / 2-3 割当・順序）承認**。
> **G-2 = 定量算入（ta-61 縮約・writeback）の扱いは各サブスライスの C-3 で確定**（据え置き）。
> 以下の両案比較表は判断記録として残す。

plan.md L338-339 は「**Slice 2 は本 PBI のスコープに含めたまま『後続スライス』として扱う。別 PBI へ
切り出すか否かは Slice 1 完了時に判断し、本時点では決めない**」と明記し、判断を Human に留保していた。
2026-08-12 の D-5 裁定（3 分割・C-3 サブスライスごと発行）に続き、**同日の追加 Human 裁定
（AskUserQuestion）で案 B を採用**した。これは plan が留保した「Slice 1 完了時の判断」の履行であり、
承認済み plan.md との矛盾ではない（plan L338 の委譲先の決定）。

| 観点 | 案 A: 同一 TASK-0921 内サブスライス | 案 B: サブスライスごとに新 TASK 起票（#921 を親 Refs） |
|---|---|---|
| plan 正本 | `slice2a-plan.md` 等の**別名ファイル**（承認済み plan.md は不変） | 各 TASK の `plan.md`（標準配置） |
| C-3 / plan_hash / EH-3 機構 | **正規経路から外れる**: EH-3 / `approvals/c3.json` は TASK ディレクトリの `plan.md` 1 本に束縛。別名 plan への c3 発行は `bin/plangate exec` / hook の想定外で、c3.json の上書き再発行は監査履歴が濁る | **1:1 で整合**: plan_hash・c3.json・`PLANGATE_HOOK_TASK` が標準どおり機能。「C-3 をサブスライスごとに発行」という裁定と機構的に自然一致 |
| トレーサビリティ | issue #921 一本で完結・文脈/evidence 継続 | Refs 規律が必要（issue #921 を親、各 TASK plan / commit に Refs 明記） |
| handoff / DoD | TASK-0921 handoff にサブスライス節を積み増し（1 TASK 1 handoff 原則と緊張） | 各 TASK で必須 6 要素 handoff（Rule 5 標準） |
| オーバーヘッド | 小（起票不要） | 中（pbi-input / 起票 ×3。ただし本書 §3 が実質の入力になる） |
| 先例 | — | TASK-1044（#921 の follow-up を別 TASK 起票）と同型 |

**採用の帰結**: サブスライスごとに新 TASK を起票し（pbi-input は本書 §3 を入力として作成）、各 TASK が
plan.md / plan_hash / `approvals/c3.json` を標準配置で持つ。issue #921 を親として各 TASK の plan /
commit に Refs を明記する。

## 5. Human 判断の結果（本書の出口）

| ID | 判断事項 | 結果 | 出所 |
|---|---|---|---|
| **G-1** | 管理方式 | **確定: 案 B（新 TASK ×3 起票・各 TASK が plan_hash / c3.json を保持）** | Human 裁定 2026-08-12（AskUserQuestion） |
| **G-2** | Mode 定量算入の扱い（ta-61 縮約・writeback） | **据え置き: 各サブスライスの C-3 で確定** — §3.1 | 同上 |
| **G-3** | 本分割案（SS-2-1 / 2-2 / 2-3 の割当・順序） | **確定: 承認** | 同上 |
| （既存） | TASK-1044 の C-3 | **未決着（残 blocker）** — 全サブスライス exec の前提 — §2 | — |
