# EXECUTION PLAN — TASK-1093 (#1093)

> `scripts/release-prep.sh` の `check_pending_applies()` を **stdout 文字列一致から
> 実態ベース判定へ差し替え**、`sync-plugin-installed.sh` を READY 条件から外し、
> `--dry-run` の判定契約を apply script 側に定める。**`--apply` は AI が実行しない**。
>
> **v2（C-2 REJECT 反映 / `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007 R-008 R-009 R-010 R-011 R-012`）**
> — **方式を変更した**。詳細は下記「方式変更の理由」。

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

- 個々の apply script の**実質ロジックの是正**（逆方向差分 / 引数解析欠落 → 別 issue 起票のみ）。
  **exit code 契約への適合は「中身の是正」ではなく契約適合として in scope**
  （issue の In scope「`--dry-run` の出力契約を apply スクリプト側にも定める」）
- HO 9 カテゴリの内容変更 / 承認境界の緩和 / C-3・C-4 の変更
- `sync-plugin-installed.sh` 自体の実装変更（**呼び出し位置のみ**移す）
- **`release-prep.sh --check` の CI 配線**（実測: `grep -rn "release-prep" .github/` → **0 件**＝
  検出器は現在どの workflow からも呼ばれていない。`.github/workflows/*` は **HO** のため
  AI は配線できない）。**本 PBI の機械強制は `ta-67` 経由で `run-tests.sh` に乗る分のみ**であり、
  `--check` 本体は「Human がリリース時に手で走らせたとき」に効く。**この非対称を Goal に含めない**

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

`apply-task-0146-ehs23-wiring.sh` を例にすると、判定本体は
`scripts/_apply_task_0146_patches.py` にあり現在その rc が素通しされている（実測 rc=1）。
契約適合は「python の verdict を 0/10 に写す」だけで、**実質ロジックには触れない**。

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
| `undecidable` | rc がその他 / timeout / 台帳行なし / 台帳破損 | **NG（fail-closed）** |

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
| `defer` | `#NNNN`（Human 発行）or 空 |

- **カバレッジ**: `ls scripts/apply-*.sh` の集合と台帳の集合が `comm -3` で**空**（集合同値。
  件数の絶対値は使わない / R-012）。未登録 script は `undecidable`→NOT READY
- **`scope` 整合**: `scope=local` の `targets` が **1 つでも tracked なら FAIL**（`n/a` の抜け道化防止）

### 4. `undecidable` / `pending` の運用出口（R-001）

v1 は `unknown`→NG に出口が無く、SC-1 発火＝**恒久 NOT READY** だった。v2 は:

- `pending` + **Human 発行 `defer=#NNNN`** → **WARN**（READY を阻まない。毎回表示）
- `undecidable` + `defer` → **依然 NG**（判定不能を defer で消させない）。
  解消は「契約適合させる」か「`scope` を正す」かのどちらかで、**握りつぶす経路を作らない**

`defer` の発行元・保護（R-004）:

- **発行は Human のみ**。AI は `defer` を増やさない（**SC-2**）
- **`decision-log.jsonl` への記録を必須**とし、`defer` 行と 1:1 対応させる
- **参照 issue が OPEN であること**を検査（close 済み `defer` の永久化を防ぐ）
- **残存リスク（明示）**: `scripts/*.tsv` は **HO 9 カテゴリ外**（実測: `check-plan-hash.sh` の
  `_override=0` 直後 `case` に `.tsv` 無し）＝ **hook は AI の書き換えを block しない**。
  防御は SC-2（規範層）+ `decision-log` + OPEN 検査 + `git diff` 1 行可視性の 4 層のみ。
  **hook 層の保護には HO パス（hook / workflow）の変更が必要で本 PBI では不可能**。
  → **follow-up issue として起票**し handoff の既知課題に残す（塞げないことを黙らない）

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

| # | Step | Output | Owner | Risk | 🚩 チェックポイント |
|---|------|--------|-------|------|------------------|
| 1 | 34 本全数の `--dry-run` 実測（**完了済**） | `evidence/apply-dryrun-matrix.txt` | AI | low | `ls scripts/apply-*.sh` の集合と matrix の集合が `comm -3` で空（R-012） |
| 2 | 各 script の**冪等判定の所在**を実測（判定がどこにあるか。**書き写さない**） | `evidence/idempotency-predicates.md` | AI | medium | 判定を持たない script（例: `apply-task-0134-progress.sh`）を名指しで列挙 |
| 3 | 台帳（マニフェスト）作成 | `scripts/apply-registry.tsv` | AI | medium | `probe_expr` 列が**存在しない**こと（方式逸脱の検出） |
| 4 | verdict 契約の正本化 + 既存契約の整理 | `docs/ai/ho-change-workflow.md` | AI | medium | 既存の rc 記述と**矛盾が残っていない**（R-009） |
| 5 | apply script を契約適合させる（rc 0/10/その他） | `scripts/apply-*.sh`（`scope=release` 分） | AI | **high** | **実質ロジックを変えていない**ことを 1 本ずつ diff で確認 |
| 6 | `check_pending_applies()` 差し替え（実行ガード付き） | `scripts/release-prep.sh` | AI | **high** | 旧 `[dry-run]` 文字列一致が grep で 0 件 |
| 7 | `run_checks \|\| true` 解消 + `check_plugin_cache_sync()` 除去 | `scripts/release-prep.sh` | AI | medium | `vX.Y.Z` 経路が NOT READY で rc≠0（R-006） |
| 8 | リリース後手順への移設 | `docs/release-process.md` | AI | low | `run_checks()` から `sync-plugin-installed` 参照 0 件（R-007） |
| 9 | 回帰テスト（**ta-61 契約 full 準拠**） | `tests/extras/ta-67-release-prep-pending.sh` | AI | **high** | marker 1 個 / `pg_extra_contract_init ta-67-release-prep-pending <cap>` / `finalize` / rc 層 / standalone 両対応（R-005） |
| 10 | 変異注入（**MUT-6 = 判定品質の kill を含む**） | `evidence/mutation-kill.txt` | AI | **high** | MUT-6 が 1 本でも kill されない＝判定が弱い script を**名指しで報告** |
| 11 | `defer` 保護の 4 層実装 + follow-up 起票 | `decision-log.jsonl` 連携 / issue | AI | medium | hook 保護不能を**明記**して起票（R-004） |
| 12 | 別 issue 起票（Out of scope 分） | issue | AI | low | 中身は直さない |
| 13 | 証跡の再現可能化 | `evidence/*`（`<repo_root>` 引数） | AI | low | 別ディレクトリから同一結果 |

## Files / Components to Touch

| ファイル | 区分 | 変更 |
|---------|------|------|
| `scripts/release-prep.sh` | **非 HO** | `check_pending_applies()` 差し替え / `check_plugin_cache_sync()` 除去 / `run_checks \|\| true` 解消 |
| `scripts/apply-registry.tsv` | **非 HO・新規** | マニフェスト（**判定を持たない**） |
| `scripts/apply-*.sh` | **非 HO** | **verdict 契約（rc 0/10/その他）への適合のみ**。実質ロジックは変えない |
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
| **判定品質（新設 / R-002）** | **MUT-6**: 台帳 `targets` の**実装本体を壊して marker/コメントは残す**変異を作り、当該 script の `--dry-run` が **rc=10 に反転する**ことを要求。反転しない script は**判定が弱い**として FAIL・名指し報告。対象は **`scope=release` かつ `targets` が単一 tracked ファイルの全行**（**集合で定義。件数は契約にしない**） |
| **環境同値（AC-5）** | `.claude/settings.json` **有 / 無**の 2 sandbox で判定出力を `diff` して同一。実機 2 環境でも各 1 回実走 |
| **Mutation（検出器側）** | MUT-1〜5（旧実装 / `undecidable`→OK / カバレッジ照合除去 / `n/a` 無条件付与 / defer 検査除去） |
| **sandbox コスト（R-010）** | 複製は **`scripts/` + `tests/` + `bin/` + `.claude/` の最小サブツリー**（`docs/` = 18M を除外）。1 回複製して使い回す。`.github/workflows/test.yml` は `timeout-minutes: 10` |
| **extras 契約（R-005）** | `ta-67` 単体 standalone 実行が rc 契約を満たし、`ta-61` が `ta-67` を covered set として PASS すること |
| **回帰 baseline（AC-7）** | `sh tests/run-tests.sh` **rc=0**（本ブランチ head で実測 **rc=0** を取得済）。件数は記録のみ |

## Risks & Mitigations

| ID | リスク | 緩和 |
|----|-------|------|
| R-1 | 一斉 NG 化でリリースが止まる | `defer`（Human 発行・WARN・毎回表示）+ U-1 で初期値を C-3 判断 |
| R-2 | ~~台帳と script の drift~~ → **v2 で消滅**（判定を書き写さない） | 台帳は `scope` / `targets` / `defer` のみ。判定は script 内の 1 箇所 |
| R-3 | 契約適合の改修が**実質ロジックを変えてしまう** | Step 5 の 🚩 で 1 本ずつ diff 確認。`--apply` 側の挙動が変わる変更は即停止（SC-5） |
| R-4 | `defer` が非 HO パスの承認トークン（**R-004**） | 4 層防御（SC-2 / decision-log / OPEN 検査 / diff 可視性）+ **hook 保護不能を明記して follow-up 起票** |
| R-5 | 判定が弱い script（コメントだけで applied を返す等）が残る | **MUT-6 が FAIL として顕在化**。修正は別 issue（Out of scope）だが**緑にはしない** |
| R-6 | 契約非適合 script が残ると恒久 NOT READY | `undecidable` は `defer` 不可（意図的）。**scope 分割（U-4）で移行計画を Human が選ぶ** |
| R-7 | sandbox コストが CI timeout を超える | 最小サブツリー + 複製使い回し（R-010）。超過時は MUT-6 を別 job / 手動実行へ退避 |
| R-8 | 本 PBI が承認境界を緩めていないか | 変更は **NG を増やす方向のみ**（fail-open→fail-closed）。SC-3 で毎回確認 |

## 停止条件 / Stop Conditions

| ID | 条件 | 行動 |
|----|------|------|
| **SC-1** | 契約適合させられない script が出た | `undecidable` のまま**握りつぶさず**報告。`defer` で消さない |
| **SC-2** | `defer` を新規に付けたくなった | **即停止・Human 判断**。AI は `defer` を増やさない |
| **SC-3** | 差分が HO パス / `ta-65-*` / 承認境界に及んだ | **即停止**。`git diff --stat` で 0 件を毎回確認 |
| **SC-4** | AC-5 が「両環境同一」にならない | 設計（`scope` 定義）に戻る。テストを緩めない |
| **SC-5** | 契約適合の改修が `--apply` 側の挙動を変えた | **即停止**（Out of scope 侵犯） |
| **SC-6** | MUT-6 で判定が弱い script が出た | **緑にしない**。名指しで報告し別 issue 化 |

## Questions / Unknowns

| ID | 内容 | 要判断者 |
|----|------|---------|
| **U-1** | 新規可視化される `pending` の初期 `defer` の是非。**とくに `apply-ai-loop-workflow-command.sh`（適用すると 2 週間分の退行）を名指しで**: `pending`+`defer=<別 issue>` とするか（R-011） | **Human（C-3）** |
| **U-2** | ~~契約を既存 34 本へ遡及するか~~ → **v2 では遡及が前提**（そうしないと判定が成立しない）。残る判断は U-4 | 解決済 |
| **U-3** | `defer` を台帳同居にするか別ファイルにするか | AI 提案 = 台帳同居（`git diff` に 1 行で出る） |
| **U-4（新規）** | **スコープ分割の是非**。契約適合は `scope=release` の **31 本**に及び Mode が **critical** になる。(A) 単一 PBI で全 31 本 / (B) #1093 = 検出器＋契約＋台帳、後続 = 移行、の 2 案 | **Human（C-3）** |
| **U-5（新規）** | `--check` は **CI 未配線**（`grep -rn "release-prep" .github/` → 0 件）。配線は HO のため AI 不可。Human が配線するか、`ta-67` 経由の強制で足りるとするか | **Human（C-3）** |

## Mode 判定

**モード**: **critical**（v1 の high-risk から**引き上げ**）

**判定根拠**:

- 変更ファイル数: `release-prep.sh` / 台帳 / `ta-67` / doc 2 本 / working context + **契約適合させる apply script（`scope=release` = 34 − `local` 3 = **31 本**）** → 合計 **37 前後** → **critical**（16+）
- 受入基準数: 7（AC-1〜AC-7）→ high
- タスク数（見込み）: 13 Step / 20 前後 → high
- 変更種別: **横断的な契約導入**（31 script + 検出器 + 正本）→ **critical**
- リスク: 誤ると「リリースして良い」の判定が誤る（false green の再生産）→ high
- ロールバック: **段階的ロールバックが必要**（契約適合 → 検出器 の 2 段）→ **critical**

**Hardening Override 判定**: `scripts/release-prep.sh` / `scripts/apply-*.sh` /
`scripts/apply-registry.tsv` / `tests/extras/*` / `docs/**` は **HO 9 カテゴリ非該当**
（正本 = `scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロック）。
→ **HO 対象外**。ただしリリースプロセス保護に直結するため安全側判定を維持。

**最終判定**: **critical**
→ `lite_eligible=false` / **C-2 必須（実施済・REJECT → 本反映）** /
**C-3 は人間必須（autonomous APPROVE 不可）** / V-2・V-3・**V-4** 実行。

> **Mode が上がったことは U-4（スコープ分割）と表裏**である。
> 分割（案 B）を選ぶ場合、#1093 側は high-risk に戻りうる。**C-3 で併せて判断されたい**。
