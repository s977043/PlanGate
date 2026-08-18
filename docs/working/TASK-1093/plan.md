# EXECUTION PLAN — TASK-1093 (#1093)

> `scripts/release-prep.sh` の `check_pending_applies()` を **stdout 文字列一致から
> 実態ベース判定へ差し替え**、`sync-plugin-installed.sh` を READY 条件から外し、
> `--dry-run` の判定契約を apply script 側に定める。**`--apply` は AI が実行しない**。
>
> **v2（C-2 REJECT 反映 / `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007 R-008 R-009 R-010 R-011 R-012`）**
> — **方式を変更した**。詳細は下記「方式変更の理由」。
>
> **v3（C-3 裁定 2026-08-18 反映 / 案 B: 2 分割）** — **方式（v2）は一切変更していない**。
> 変更したのは **スコープの分割**のみ:
> **本 PBI = 検出器 + `--dry-run` exit code 契約 + 台帳（マニフェスト）**、
> **既存 apply script の契約適合移行 = [#1114](https://github.com/s977043/PlanGate/issues/1114)**。
> Mode は **critical → high-risk に戻した**。裁定正本:
> [#1093 コメント](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417)。

## Goal

**リリース readiness 検査の「適用待ち apply」判定が、
`--dry-run` の stdout に何を印字するかに依存せず、
(a) fail-open せず / (b) 誤検出せず / (c) 実行環境に依存せず / (d) 検出漏れしない**
状態にする。緑が出たときに「本当に適用待ちが無い」と言える構造にする。

## 方式変更の理由（R-001 / R-002 / R-003）

v1 は **台帳（registry）に「適用済みを判定する marker probe」を書く**方式だった。
C-2 の 3 つの major はいずれも **この方式そのもの**への疑義であり、実測で妥当:

| 指摘 | v1 方式の欠陥 | 実測 |
|------|-------------|------|
| **R-002** | probe の marker が**コメント行**でも成立する。旧実装（stdout 文字列一致）と**同じ「表現を測る」クラスの再生産** | `bin/plangate:2248` は `  # EHS-2 (TASK-0146 / #527): ...` ＝**コメント**。実装本体を消しても `applied` になる |
| **R-001** | 「適用済み」の定義が **2 ファイルの内容同値**である script が実在し、単一ファイル + marker では表現不能 | `grep -ln "cmp -s\|diff -q" scripts/apply-*.sh` → **4 本** |
| **R-003** | 「script を実行しない」と「stdout の status 行を cross-check する」を同時に主張していた（実行しなければ stdout は得られない） | plan v1 Approach 1 と 3 の矛盾 |

**根本原因は「適用済みかの判定を、script の外に第 2 の実装として書き写したこと」**である。
書き写した以上、(i) 表現が実装からズレる（R-002）/ (ii) 表現力が足りない（R-001）/
(iii) 正しさを保証する手段が無い、という 3 つが必ず付いてくる。

**したがって v2 は「判定を書き写さない」。**
適用済みか否かの**唯一の正しい判定は、その script 自身の冪等判定**である
（`--apply` が「既適用なら何もしない」を決めているのと**同一のコードパス**）。
これは書き写した probe と違い **self-validating** — 誤っていれば `--apply` 自体が壊れるため、
Human が適用時に必ず気付く。台帳 probe の誤りは**永久に silent**。

**v2 = script 自身の冪等判定を、strict な exit code 契約で機械可読にして読み取る。**
R-003 が指摘した矛盾は、**「実行しない」という主張を取り下げる**ことで解消する
（R-003 推奨対応 2 を採用）。実行に伴う (a) rc / (c) 環境差 / timeout は
**ガードとして仕様化し TC を立てる**（下記 Approach 2）。

> **`--apply` は実行しない。実行するのは `--dry-run` のみ**（Non-goal 不変）。

## Constraints / Non-goals

### Constraints

- **`bin/plangate` / `.github/workflows/*` / `scripts/hooks/*.sh` は HO パス — AI は編集しない**
- **apply script の `--apply` は AI が実行しない**（sandbox 内であっても / Human-owned）
- **他セッション占有域に触れない**: `tests/extras/ta-65-*` / `scripts/hooks/check-plan-hash.sh`（#1101）
- **`check_pending_applies()` は関数名で参照する**（行番号アンカー禁止 / #1089 教訓）
- **`tests/run-tests.sh` の baseline 件数を契約値にしない**（実測: 本ブランチ head で **rc=0**）
- **新規 `tests/extras/ta-67-*.sh` は `ta-61` の extras 実行契約に初日から full 準拠**（R-005）

### Non-goals

- **既存 apply script の exit code 契約への適合（移行）** → **[#1114](https://github.com/s977043/PlanGate/issues/1114)**
  （**C-3 2026-08-18 の案 B により本 PBI から分離**）。本 PBI は**契約を定義し、契約に従って読む側**を作る。
  対象集合は `ls scripts/apply-*.sh` と台帳の**集合同値**で表現し、件数（34 / 31）を契約値にしない
- 個々の apply script の**実質ロジックの是正**（逆方向差分 / 引数解析欠落 / rc≠0 の原因）→ **#1114**
- HO 9 カテゴリの内容変更 / 承認境界の緩和 / C-3・C-4 の変更
- `sync-plugin-installed.sh` 自体の実装変更（**呼び出し位置のみ**移す）
- **`release-plugin` 系の hook 層保護（`ack` / `defer` を HO 対象に加えること）** →
  **follow-up（別 issue）**。HO 定義本体（`scripts/hooks/check-plan-hash.sh` の
  `_override=0` 直後の `case` ブロック）の変更が必要で、**本 PBI では塞げない**（R-004。下記 §4 参照）
- **`release-prep.sh --check` の CI 配線** — 下記「既知の制約: 検出器は CI で一度も走らない（U-5）」

### 既知の制約: 検出器は CI で一度も走らない（U-5 / **持ち越し・意図的**）

- **実測**: `grep -rn "release-prep" .github/` → **0 件**。
  `scripts/release-prep.sh` は **どの workflow からも呼ばれていない**
- `.github/workflows/*` は **Hardening Override 対象**であり、**AI は配線できない**（実測 rc=2）
- したがって本 PBI が入れる機械強制は **`tests/extras/ta-67-*` 経由で `tests/run-tests.sh` に乗る分のみ**。
  `--check` 本体は **「Human がリリース時に手で走らせたとき」にだけ効く**
- **この非対称は本 PBI の欠陥ではなく、意図して残した状態**である。
  解消するには Human が workflow へ配線する（H-5）。**C-3 2026-08-18 で「未決のまま持ち越し」と裁定済み**

## Approach Overview

### 1. `--dry-run` verdict 契約（exit code / apply script 側）

`--dry-run`（および引数なし）で、**script 自身の冪等判定の結果を exit code で返す**:

| rc | 意味 |
|----|------|
| **0** | **applied** — 適用済み。何も変わらない |
| **10** | **pending** — 未適用。`--apply` すれば変更が入る |
| **その他（1 含む）** | **undecidable** — 判定不能（対象不在 / アンカー不一致 / 内部エラー） |

- `--dry-run` は**非破壊**（既存契約を維持）。**diff の印字は自由**（検出器は読まない）
- 未知引数は従来どおり `exit 1`
- **stdout は判定に使わない**（旧実装の失敗を繰り返さない）。
  `PLANGATE-APPLY-STATUS` 行の cross-check は **v2 で廃止**（R-003）

**本 PBI は契約を「定義し・正本化し・読む側を作る」ところまで**を担う。
**既存 script を契約へ適合させる作業（移行）は [#1114](https://github.com/s977043/PlanGate/issues/1114)**
（C-3 案 B）。例として `apply-task-0146-ehs23-wiring.sh` は判定本体が
`scripts/_apply_task_0146_patches.py` にあり現在その rc が素通しされている（実測 rc=1）が、
その「verdict を 0/10 に写す」改修は **#1114 の作業**である。

本 PBI では契約の実証に **sandbox 内の fixture apply script**（契約準拠のもの / 非準拠のもの /
rc その他を返すもの）を使う。**リポジトリの実 script は変更しない**。

### 2. 検出器（`check_pending_applies()`）— 実行ガード付き

台帳の各行について `sh <script> --dry-run` を **ガード下で 1 回だけ**実行する:

- **rc を捨てない**（`2>/dev/null || true` を撤廃）
- **timeout を掛ける**（超過 → `undecidable`）
- **rc が 0 / 10 以外 → `undecidable`**（stdout の内容によらず）
- **stdout / stderr は診断表示のみ**に使い、判定には一切使わない

verdict:

| 値 | 由来 | READY への影響 |
|----|------|--------------|
| `applied` | rc=0 | OK |
| `pending` | rc=10、`defer` 無し | **NG** |
| `pending(defer=#N)` | rc=10、Human 発行の `defer` 有り | **WARN（毎回表示・不可視化しない）** |
| `n/a (local)` | `scope=local` — untracked なローカル設定が対象。**実行もしない** | OK（理由 + `bin/plangate doctor --check-settings` への導線を表示。R-008） |
| `unmigrated(#1114)` | `contract=legacy`（**実行しない**。契約非適合なので rc に意味が無い） | **WARN（毎回表示）**。§3-bis / U-6 |
| `undecidable` | rc がその他 / timeout / 台帳行なし / 台帳破損 / `contract=legacy` かつ #1114 が CLOSED | **NG（fail-closed）** |

- **(a) 解消**: rc を判定の一次情報にし、想定外 rc は必ず NG
- **(b) 解消**: 無条件ヘッダのような**印字**は判定に影響しない
- **(c) 解消**: `scope=local` は**実行せず** `n/a` 固定＝両環境で同一出力
- **(d) 解消**: 台帳が全 script を網羅し、印字の有無に依存しない

### 3. 台帳 = マニフェスト（**判定を持たない**）

`scripts/apply-registry.tsv`（新規・非 HO）。**probe は書かない**（R-002 の再生産防止）:

| 列 | 内容 |
|----|------|
| `script` | `scripts/apply-*.sh` の basename |
| `scope` | `release`（READY 対象） / `local`（untracked ローカル設定対象・実行しない） |
| `targets` | script が書き込む**宣言済み対象パス**（`;` 区切り）。**MUT-6 と `scope` 整合検査に使う。判定には使わない** |
| `contract` | `adopted`（rc 契約に適合済み）/ `legacy`（**#1114 で移行予定**） |
| `defer` | `#NNNN`（Human 発行）or 空 |

- **カバレッジ**: `ls scripts/apply-*.sh` の集合と台帳の集合が `comm -3` で**空**（集合同値。
  件数の絶対値は使わない / R-012）。未登録 script は `undecidable`→NOT READY
- **`scope` 整合**: `scope=local` の `targets` が **1 つでも tracked なら FAIL**（`n/a` の抜け道化防止）

### 3-bis. `contract` 列 — 2 分割が構造的に要求する唯一の追加（**U-6**）

分割により、**契約に適合していない script が本 PBI 完了時点で残る**。
何もしなければ全 `scope=release` 行が `undecidable`→**恒久 NOT READY** となり、
`--check` が Human にとって使い物にならない。これは**分割の必然的な帰結**であり、
黙って fail-open にはしない。**移行期間を有限・可視・凍結**にして扱う:

| `contract` | verdict | READY への影響 |
|-----------|---------|--------------|
| `adopted` | rc に従う（`applied` / `pending` / `undecidable`） | 通常どおり |
| `legacy` | **`unmigrated(#1114)`** | **WARN（毎回表示・不可視化しない）** |

**`legacy` を「第 2 の fail-open」にしないための拘束**:

- **凍結集合**: `legacy` を許すのは **台帳を作成したコミット時点で存在した `scripts/apply-*.sh` の集合**に限る。
  以後に追加される script は **`adopted` でなければ台帳に載せられない**（初日から契約準拠）
- **一方向**: `legacy → adopted` のみ。**`adopted → legacy` への差し戻しはテストで FAIL**
- **期限は issue の生存**: `#1114` が **CLOSED なら `legacy` 行は `undecidable`→NG**
  （`defer` の OPEN 検査と同じ機構を再利用）
- **`defer` とは別物**: `defer` は **Human 発行の個別免除**（SC-2 で AI は増やさない）。
  `contract=legacy` は **C-3 が決めた分割そのものの表現**であり、
  値域が凍結集合に閉じているため AI が新たな免除を作れない

> **U-6（Human 判断）**: 上記 `contract` 列を採用するか、
> **採用せず「#1114 完了までは `--check` が NOT READY で構わない」とするか**。
> AI 提案は **採用**（`--check` を使える状態に保ちつつ、移行の未完了を毎回可視化するため）。
> 不採用でも本 PBI の他の設計は変わらない（`contract` 列と `unmigrated` verdict を落とすだけ）。

### 4. `undecidable` / `pending` の運用出口（R-001）

v1 は `unknown`→NG に出口が無く、SC-1 発火＝**恒久 NOT READY** だった。v2 は:

- `pending` + **Human 発行 `defer=#NNNN`** → **WARN**（READY を阻まない。毎回表示）
- `undecidable` + `defer` → **依然 NG**（判定不能を defer で消させない）。
  解消は「契約適合させる」か「`scope` を正す」かのどちらかで、**握りつぶす経路を作らない**

**C-3 2026-08-18 の裁定（U-1 = defer を認める）**:

- **適用すると退行するもの**は `pending` + `defer=<別 issue>` として記録し、**リリースをブロックしない**
- 裁定で**名指しされた対象**: **`apply-ai-loop-workflow-command.sh`**
  （コピー元 prompt が 2026-07-08 止まり / 適用先が 2026-07-24 = **適用すると 2 週間分の退行**）。
  実際の `defer` 行の投入は #1114 の移行時（当該 script が `adopted` になった後）に Human が行う
- **AI は `defer` を増やさない**（**SC-2 を維持**）。裁定は「defer という機構を認める」であって
  「AI が defer を発行してよい」ではない
- **`undecidable` に `defer` を効かせない**（**TC-21 を維持**）＝握りつぶす経路を作らない

`defer` の発行元・保護（R-004）:

- **発行は Human のみ**。AI は `defer` を増やさない（**SC-2**）
- **`decision-log.jsonl` への記録を必須**とし、`defer` 行と 1:1 対応させる
- **参照 issue が OPEN であること**を検査（close 済み `defer` の永久化を防ぐ）
- **残存リスク（明示）**: `scripts/*.tsv` は **HO 9 カテゴリ外**（実測: `check-plan-hash.sh` の
  `_override=0` 直後 `case` に `.tsv` 無し）＝ **hook は AI の書き換えを block しない**。
  防御は SC-2（規範層）+ `decision-log` + OPEN 検査 + `git diff` 1 行可視性の 4 層のみ。
  **hook 層の保護には HO パス（hook / workflow）の変更が必要で本 PBI では不可能**。
  → **follow-up issue として起票**し handoff の既知課題に残す（塞げないことを黙らない）

> **C-3 2026-08-18 の裁定（R-004）**: 「**本 PBI では塞げない**」を確定。
> `scripts/*.tsv` を Hardening Override の対象に加えるには **HO 定義自体
> （`scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロック）の変更**が必要で、
> それ自体が HO パスである。**follow-up として別扱い**とし、本 PBI の Non-goals に明記した。
> 本 PBI での扱いは **4 層の規範/監査防御 + 起票（T-19）+ handoff 既知課題**まで。

### 5. `run_checks()` の整理

- `check_plugin_cache_sync()` を `run_checks()` から**除去**し、
  `docs/release-process.md` の**リリース後**手順へ移設（AC-6）
- **`run_checks || true`（`vX.Y.Z` 経路）の rc 握り潰しを解消**し `--check` と同じ rc 伝播に揃える（**R-006**）。
  同一ファイル・同一クラスの fail-open を残さない

### 6. 契約の正本化（R-009）

`docs/ai/ho-change-workflow.md` の「標準フロー」2 に**既存の apply script 契約がある**
（冪等 / `--dry-run` は unified diff / 未知引数は exit 1 / アンカー不在は exit 1）。
新契約を**追記するだけでは矛盾する**（既存は「アンカー不在→exit 1」、新契約は rc 体系を持つ）。
→ **既存記述を同時に整理し、rc 規約を 1 か所に統合**する（追記して矛盾を残さない）。

## Work Breakdown

> **v3**: 旧 Step 5（apply script を契約適合させる）を **#1114 へ移設**し、
> 旧 Step 12（Out of scope 分の起票）は **#1114 の起票をもって完了済**。以下は再採番後。

| # | Step | Output | Owner | Risk | 🚩 チェックポイント |
|---|------|--------|-------|------|------------------|
| 1 | apply script 全数の `--dry-run` 実測（**完了済**） | `evidence/apply-dryrun-matrix.txt` | AI | low | `ls scripts/apply-*.sh` の集合と matrix の集合が `comm -3` で空（R-012） |
| 2 | 各 script の**冪等判定の所在**を実測（判定がどこにあるか。**書き写さない**） | `evidence/idempotency-predicates.md` | AI | medium | 判定を持たない script（例: `apply-task-0134-progress.sh`）を名指しで列挙。**是正はしない（#1114）** |
| 3 | 台帳（マニフェスト）作成 | `scripts/apply-registry.tsv` | AI | medium | `probe_expr` 列が**存在しない**こと（方式逸脱の検出）。`contract` 列の初期値は Step 2 の実測に基づく |
| 4 | verdict 契約の正本化 + 既存契約の整理 | `docs/ai/ho-change-workflow.md` | AI | medium | 既存の rc 記述と**矛盾が残っていない**（R-009）。**#1114 が参照できる形になっていること** |
| 5 | `check_pending_applies()` 差し替え（実行ガード付き） | `scripts/release-prep.sh` | AI | **high** | 旧 `[dry-run]` 文字列一致が grep で 0 件 |
| 6 | `contract=legacy` の凍結集合 / 一方向 / OPEN 検査を実装（**U-6 採用時のみ**） | `scripts/release-prep.sh` | AI | medium | `adopted→legacy` 差し戻しと**凍結集合外の `legacy`** が FAIL すること |
| 7 | `run_checks \|\| true` 解消 + `check_plugin_cache_sync()` 除去 | `scripts/release-prep.sh` | AI | medium | `vX.Y.Z` 経路が NOT READY で rc≠0（R-006） |
| 8 | リリース後手順への移設 | `docs/release-process.md` | AI | low | `run_checks()` から `sync-plugin-installed` 参照 0 件（R-007） |
| 9 | 回帰テスト（**ta-61 契約 full 準拠**） | `tests/extras/ta-67-release-prep-pending.sh` | AI | **high** | marker 1 個 / `pg_extra_contract_init ta-67-release-prep-pending <cap>` / `finalize` / rc 層 / standalone 両対応（R-005） |
| 10 | 変異注入（**MUT-1〜5 / MUT-7 + MUT-6' = fixture に対する判定品質 kill**） | `evidence/mutation-kill.txt` | AI | **high** | 空振り fixture でないこと。**実 script に対する MUT-6 は #1114** |
| 11 | `defer` 保護の 4 層実装 | `decision-log.jsonl` 連携 | AI | medium | **`undecidable` に `defer` が効かない**こと（TC-21） |
| 12 | follow-up 起票（R-004 の hook 層保護 / U-5 の CI 配線） | issue | AI | low | **塞げないことを明記**して起票（R-004 / U-5） |
| 13 | 証跡の再現可能化 | `evidence/*`（`<repo_root>` 引数） | AI | low | 別ディレクトリから同一結果 |

## Files / Components to Touch

| ファイル | 区分 | 変更 |
|---------|------|------|
| `scripts/release-prep.sh` | **非 HO** | `check_pending_applies()` 差し替え / `check_plugin_cache_sync()` 除去 / `run_checks \|\| true` 解消 |
| `scripts/apply-registry.tsv` | **非 HO・新規** | マニフェスト（**判定を持たない**） |
| `scripts/apply-*.sh` | **非 HO** | **本 PBI では変更しない**（契約適合の移行は **#1114**）。台帳には**登録のみ**する |
| `tests/extras/ta-67-release-prep-pending.sh` | **非 HO・新規** | 回帰テスト（ta-61 契約準拠） |
| `docs/ai/ho-change-workflow.md` | **非 HO** | rc 契約の正本化 + **既存記述の整理**（R-009） |
| `docs/release-process.md` | **非 HO** | plugin キャッシュ同期をリリース後手順へ |
| `docs/working/TASK-1093/**` | **非 HO** | plan / evidence |
| `bin/plangate` / `.github/workflows/*` / `scripts/hooks/*.sh` | **HO** | **触らない**（CI 配線も不可 → Non-goals に明記） |
| `tests/extras/ta-65-*` / `scripts/hooks/check-plan-hash.sh` | 他セッション占有 | **触らない** |
| `docs/working/_merge/*-release-runbook.md` | **非 HO** | **Non-goal**（テンプレ更新は別 PBI。R-007） |

## Testing Strategy

| 層 | 内容 |
|----|------|
| **Unit** | 台帳パースの境界（空行 / コメント / タブ欠落 / 重複 / `scope` 整合）。verdict マッピング（rc→4 値） |
| **Integration** | HEAD 実機で `pending` / `applied` の**両方向**を実証。ガード（rc その他 / timeout）で `undecidable`→NG |
| **判定品質（R-002 / v3 で分割）** | **MUT-6'（本 PBI）**: sandbox の **fixture apply script**（契約準拠・単一 tracked target）の**実装本体を壊し marker/コメントは残す**変異で、`--dry-run` が **rc=10 に反転**し検出器が `pending` を出すことを要求。**契約と検出器の組が判定品質を測れる**ことの実証。**実 script 全数に対する MUT-6 は #1114**（対象 script が `adopted` になって初めて実行できるため） |
| **移行状態（新設 / U-6）** | `contract=legacy` が **WARN として毎回出る** / **凍結集合外の `legacy` が FAIL** / **`adopted→legacy` 差し戻しが FAIL** / **#1114 CLOSED で `undecidable`→NG** |
| **環境同値（AC-5）** | `.claude/settings.json` **有 / 無**の 2 sandbox で判定出力を `diff` して同一。実機 2 環境でも各 1 回実走 |
| **Mutation（検出器側）** | MUT-1〜5（旧実装 / `undecidable`→OK / カバレッジ照合除去 / `n/a` 無条件付与 / defer 検査除去） |
| **sandbox コスト（R-010）** | 複製は **`scripts/` + `tests/` + `bin/` + `.claude/` の最小サブツリー**（`docs/` = 18M を除外）。1 回複製して使い回す。`.github/workflows/test.yml` は `timeout-minutes: 10` |
| **extras 契約（R-005）** | `ta-67` 単体 standalone 実行が rc 契約を満たし、`ta-61` が `ta-67` を covered set として PASS すること |
| **回帰 baseline（AC-7）** | `sh tests/run-tests.sh` **rc=0**（本ブランチ head で実測 **rc=0** を取得済）。件数は記録のみ |

## Risks & Mitigations

| ID | リスク | 緩和 |
|----|-------|------|
| R-1 | 一斉 NG 化でリリースが止まる | `defer`（Human 発行・WARN・毎回表示。**C-3 で承認済**）+ `contract=legacy`（U-6） |
| R-2 | ~~台帳と script の drift~~ → **v2 で消滅**（判定を書き写さない） | 台帳は `scope` / `targets` / `contract` / `defer` のみ。判定は script 内の 1 箇所 |
| R-3 | ~~契約適合の改修が実質ロジックを変えてしまう~~ → **v3 で本 PBI から消滅** | **#1114 へ移設**（旧 SC-5 も同様） |
| R-4 | `defer` が非 HO パスの承認トークン（**R-004**） | 4 層防御（SC-2 / decision-log / OPEN 検査 / diff 可視性）。**hook 層保護は C-3 で「本 PBI では塞げない」と確定** → follow-up 起票（Step 12） |
| R-5 | 判定が弱い script が残る | 本 PBI では **fixture に対する MUT-6' で「測れること」を実証**。**実 script の判定品質は #1114 の MUT-6** |
| R-6 | **`contract=legacy` が第 2 の fail-open になる** | 凍結集合 + 一方向 + #1114 OPEN 検査 + WARN 毎回表示。**U-6 不採用なら NOT READY を受け入れる**（どちらも fail-open ではない） |
| R-9 | **#1114 が着手されず `legacy` が恒久化する** | `#1114` CLOSED で `undecidable`→NG に倒れる設計 + WARN の毎回表示。**期限を issue の生存に紐付ける** |
| R-7 | sandbox コストが CI timeout を超える | 最小サブツリー + 複製使い回し（R-010）。超過時は MUT-6 を別 job / 手動実行へ退避 |
| R-8 | 本 PBI が承認境界を緩めていないか | 変更は **NG を増やす方向のみ**（fail-open→fail-closed）。SC-3 で毎回確認 |

## 停止条件 / Stop Conditions

| ID | 条件 | 行動 |
|----|------|------|
| **SC-1** | 契約適合させられない script が出た | `undecidable`（または `unmigrated`）のまま**握りつぶさず**報告。`defer` で消さない |
| **SC-2** | `defer` を新規に付けたくなった | **即停止・Human 判断**。**AI は `defer` を増やさない**（C-3 2026-08-18 で維持を確認） |
| **SC-3** | 差分が HO パス / `ta-65-*` / 承認境界に及んだ | **即停止**。`git diff --stat` で 0 件を毎回確認 |
| **SC-4** | AC-5 が「両環境同一」にならない | 設計（`scope` 定義）に戻る。テストを緩めない |
| **SC-5** | **`scripts/apply-*.sh` を編集したくなった** | **即停止**（**#1114 の scope**。本 PBI は台帳登録のみ） |
| **SC-6** | fixture の MUT-6' が kill されない | **緑にしない**。契約 or 検出器の設計に戻る |
| **SC-7** | **凍結集合外の script に `legacy` を付けたくなった** | **即停止・Human 判断**（`legacy` の値域拡大は分割の裁定を超える） |

## Questions / Unknowns

| ID | 内容 | 状態 / 要判断者 |
|----|------|----------------|
| **U-1** | 新規可視化される `pending` の初期 `defer` の是非 | **✅ 解決（C-3 2026-08-18）**: **defer を認める**。適用すると退行するものは `pending`+`defer=<別 issue>` でリリースをブロックしない。名指し対象 = **`apply-ai-loop-workflow-command.sh`**。**AI は defer を増やさない / `undecidable` には効かせない**は維持（§4） |
| **U-2** | ~~契約を既存 script 全数へ遡及するか~~ | **✅ 解決**: 遡及は前提。**遡及作業自体は #1114**（U-4 の帰結） |
| **U-3** | `defer` を台帳同居にするか別ファイルにするか | AI 提案 = 台帳同居（`git diff` に 1 行で出る）。**C-3 で異議なし** |
| **U-4** | スコープ分割の是非 | **✅ 解決（C-3 2026-08-18）**: **案 B: 2 分割**。本 PBI = 検出器＋契約＋台帳（**high-risk**）/ 移行 = **#1114** |
| **U-5** | `--check` の **CI 未配線**（`grep -rn "release-prep" .github/` → **0 件**）。配線は HO のため AI 不可 | **⏸ 未決のまま持ち越し（C-3 2026-08-18）**。本 PBI は Non-goals + 「既知の制約」節で**意図的な状態**として明示。配線するなら **Human（H-5）** |
| **U-6（新規 / v3）** | 分割により契約非適合 script が残る間、`--check` を **`contract=legacy`→WARN** で使える状態に保つか、**#1114 完了まで NOT READY を受け入れる**か（§3-bis） | **Human（C-3）**。AI 提案 = **採用**（凍結集合 + 一方向 + #1114 OPEN 検査で fail-open にしない） |

## Mode 判定

**モード**: **high-risk**（v2 の critical から**戻した**。C-3 2026-08-18 の案 B 確定による）

**判定根拠**:

| 軸 | v2（critical 時） | **v3（分割後）** | 判定 |
|----|------------------|-----------------|------|
| 変更ファイル数 | `release-prep.sh` / 台帳 / `ta-67` / doc 2 本 / working context + **apply script（`scope=release` 分）** ≒ 37 | **`scripts/release-prep.sh` / `scripts/apply-registry.tsv`（新規）/ `tests/extras/ta-67-*.sh`（新規）/ `docs/ai/ho-change-workflow.md` / `docs/release-process.md`** + working context = **成果物 5 + working context** | **high-risk**（6-15） |
| 受入基準数 | 7 | **7（AC-1〜AC-7。増減なし）** | high-risk（6-10） |
| タスク数 | 22（T-01〜T-22） | **22（実測・変わっていない）** — 旧 T-06（移行）を #1114 へ移設した一方、**T-08（`contract` 実装）を新設**したため相殺 | ⚠️ **定量軸では critical 帯（21+）** |
| 変更種別 | 横断的な契約導入（多数 script + 検出器 + 正本） | **1 検出器 + 1 台帳 + 1 契約正本**（**リポジトリの apply script を 1 本も変更しない**） | **high-risk**（機能追加/複数レイヤー） |
| リスク | false green の再生産 | 同左（**変わらない**） | high-risk |
| ロールバック | 段階的（契約適合 → 検出器 の 2 段） | **単段**（`git checkout origin/main -- scripts/release-prep.sh` + 新規 2 ファイルの `git rm`）。**移行の段は #1114 が持つ** | high-risk（計画的に必要） |

**判定の内訳（隠さずに書く）**:

- **6 軸中 5 軸が high-risk 帯**。critical の主因だった
  **「横断的リファクタリング＝多数の apply script に触れる」**が **#1114 へ移り**、
  本 PBI に残るのは **検出器 1 本・台帳 1 本・契約正本 1 本**になった
- **ただし「タスク数 22」は定量軸では critical 帯（21+）に残る**（v2 から減っていない）。
  内訳は **粒度の細かさ**によるもので、成果物は 5 ファイル + working context に閉じる
- したがって **素の判定ロジック（各軸の最大値）では critical**、
  **C-3 の明示 override により high-risk** となる。
  これは [`mode-classification.md`](../../../.claude/rules/mode-classification.md) 判定ロジック 4
  「**ユーザーがオーバーライドした場合はそちらを優先**」に基づく正規の経路であり、
  **override の事実と根拠を記録に残す**（[C-3 裁定 2026-08-18](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417)
  「**#1093 は high-risk に戻す（critical へ引き上げない）**」）
- **リリースプロセス保護に直結する**点は変わらないので `standard` には落とさない

**Hardening Override 判定**: `scripts/release-prep.sh` / `scripts/apply-registry.tsv` /
`tests/extras/*` / `docs/**` は **HO 9 カテゴリ非該当**
（正本 = `scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロック。**行番号では参照しない**）。
→ **HO 対象外**。ただし `.github/workflows/*` は HO のため **CI 配線は AI 不可**（U-5 / 既知の制約）。

**最終判定**: **high-risk**（**C-3 override**。素の判定は critical / 差分はタスク数軸のみ）
→ `lite_eligible=false` / **C-2 必須（実施済・REJECT → v2 で反映）** /
**C-3 は人間必須（high-risk も autonomous APPROVE 不可）** / V-2・V-3 実行。
**V-4（リリース前チェック）は critical 専用のため素の判定では対象**だったが、
override により**必須ではなくなる**。本 PBI は `scripts/release-prep.sh` そのものを変更するため、
**V-4 相当の確認（`--check` / `vX.Y.Z` 両経路の rc）は TC-11 / TC-23 で代替**している
（フェーズを落としても検査を落としていない）。

> **`c3.json` は本更新の後に Human が発行する。**
> v3 で plan 本体が変わったため **`plan_hash` が変わる**。
> working-context.md の順序規約（確定反映 → 簡易 C-1 → `c3.json` 発行 → exec）に従うこと。
