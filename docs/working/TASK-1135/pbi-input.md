# PBI INPUT PACKAGE — TASK-1135（DRAFT）

> **DRAFT — 人間が最終確定する前の下書き**（ワーカー作成 2026-09-05）。本書の判定・スライス分割・AC は
> オーガナイザー提案（2026-09-05 実測）と issue / hook 実装を突合した**提案**であり、確定は Human。
> Issue: [#1135](https://github.com/s977043/plangate/issues/1135)（親 EPIC [#1035](https://github.com/s977043/plangate/issues/1035) 配下 / 自律度ラダー L1→L2）
> 測定基点: 本 worktree HEAD = `9f7bac9`（`fix/1104-bash-route` 派生）。`scripts/hooks/check-plan-hash.sh` の最終変更は
> `9043536`（#1089）で、**#1104 no-op（PR #1271・OPEN）と #1101 正規化はいずれも未適用**
> （`tests/fixtures/eh3-bash-lane-pending-1104.flag` / `eh3-normalization-pending-1101.flag` が現存）。
> 以下で「hook の分岐」を挙げる際は**関数名・分岐条件で参照し、行番号は使わない**（#1089 の教訓）。

## Context / Why

**EH-3（`scripts/hooks/check-plan-hash.sh`）の no-task 経路は「承認境界か」ではなく「`.md` か」「対象パスが与えられたか」で
通す / 塞ぐを決めている。** その結果、承認境界（HO 9 カテゴリ / 承認トークン / merge）と無関係な対象まで AI が到達できず、
AI 単独で完了できる作業が構造的に制限される。さらに **AI 自身が自分の到達範囲を誤認する**（#1135 コメント: 「HO 外」と
「到達可能」は別）ため、patch 提示止まり・迂回誘発・Human 適用漏れという 3 種の実害が出ている。

### 実害（実測ベース）

| 日付 | 事象 | 出典 |
|---|---|---|
| 2026-08-18 | bugfix 11 issue が `.sh` / `.py` を要し **patch 提示止まり**（PR #1119 / #1128〜#1134）。うち #1021 / #947 / #1044 / #921 は対象が `tests/extras/*.sh` で承認境界と無関係。#1044 は plan APPROVED 済みで exec だけが塞がる | #1135 本文 |
| 2026-08-18 | `docs/working/templates/plan.md` の 1 行修正（#1018）が basename `plan.md` で block | #1135 / #1031 |
| 2026-08-18 | `/ai-loop-cycle` 3 回とも帯外（`gates.c1` ← Plan Package ← `plan.md` ← EH-3 block の循環） | #1135 / #927 非対称 C |
| 2026-08-18 | #1144 の配布作業 3 件（`scripts/sync-plugin-plangate.sh` / `plugin/plangate/hooks/hooks.json`（新規作成）/ `plugin.json`）が **HO 外なのに** SKIP_REASON 未設定で rc=2 | #1135 コメント |
| 2026-08-26 | ハーネス指定スクラッチパッド（repo 外）への `.html` Write が rc=2。同内容を Bash heredoc で書くと素通り（= #1104 迂回の誘発） | #1234 |
| 2026-08-20 | Human 決定「開発は ai-loop-workflow で」が no-task セッションで実行不能（#1180 M-1 の 1 語置換を裁定できず） | #1197 |
| 2026-08-12〜13 | v8.19.0 リリースで Human 5 手。HO patch の適用 1 手は構造的に残るが、**どの patch が未適用かを機械が把握していない** | #1077 |
| 2026-09-05 | 旧 hook + Bash matcher 配線（PR #1267）下で、no-task セッションのオーガナイザー 1 + ワーカー 3 の**全 Bash** が `SKIP_REASON 未設定` で停止。maintenance 30 分窓が切れると `.md` の doc-light 経路も含め全経路停止。EH-3 env は起動時固定で実行中付与不可 | オーガナイザー実測 |

### 摩擦 5 型の判定（hook の該当分岐を根拠に「守るべき対象か / 摩擦か」）

| # | 摩擦 | 到達する hook 分岐（関数名 / 分岐条件） | 判定 | 根拠 |
|---|---|---|---|---|
| **F1** | read-only Bash まで全 block | Bash payload は `tool_input.command` のみ → stdin 補完（`jq '.tool_input.file_path // .file_path'` / `grep -o '"file_path"'`）で `target_file` が空 → HO `case "$_norm_target"` 不一致 → `case "$_tf_lc" in */plan.md)` 不一致 → maintenance 不在 → `_dl_ext` が `md` でない → **SKIP_REASON 例外申請ブロック（`_skipr` 空 → `SKIP_BLOCKED` / exit 2）** | **摩擦**（対象パス不明の payload を止めても防御にならない）。**ただし Edit/Write で `file_path` が空のケースは fail-closed を維持**（異常 payload） | Bash レーンは PR #1271 の `BASH_LANE_NOOP`（`_tool_name = "Bash"` かつ `target_file` 空かつ `task_id` 空）で解消予定。**本 PBI は #1271 に依存し、Bash レーンの判定には触れない**。「no-task で SKIP_REASON 要求」の構造自体は Gray 帯（後述）向けに残す |
| **F2** | repo 外パスの block（#1234） | `_norm_target` の正規化は `./` 除去と `$REPO_ROOT/` 前置除去のみ → repo 外の絶対パスはそのまま残る → HO 不一致 → `.md` でなければ SKIP_REASON ブロック。逆に repo 外の `.../CLAUDE.md` は `_dl_ext = md` で **DOC_LIGHT_SKIP（false negative）** | **摩擦**（repo 外は守る対象でない）**かつ同じ欠落が false negative も生む**（#1234 コメント Phase 0） | 「repo 内 / 外」の分類が存在しないのが原因。**是正は #1234 の in-scope そのもの**であり、本 PBI では**依存先**として扱う（重複実装しない） |
| **F3** | no-task で `plan.md` 新規作成不可（#1197） | no-task 分岐冒頭の `case "$_tf_lc" in */plan.md\|plan.md)` が **basename 一致で無条件 exit 2**（maintenance / SKIP_REASON より前。`PLANGATE_SKIP_REASON` も効かない） | **守る（`docs/working/TASK-*/plan.md`）/ 摩擦（`docs/working/templates/plan.md`）の混在**。前者は「C-3 承認後の plan 改変を TASK 文脈を消して通す攻撃」の阻止で設計どおり。後者はテンプレートであって承認成果物でない | basename 判定にディレクトリ条件を組み合わせれば分離できる（#1135 AC-3）。**新規作成の許可条件（#1197 案 B）は本 PBI では扱わない**（#1197 の C-3 判断事項） |
| **F4** | HO patch 適用が Human 手作業で漏れる（#1077） | hook の分岐ではなく**プロセスの欠落**。現状 `docs/working/_reports/*-patch-applicable.md` 4 本に対し pending flag は 2 本（`960-*` / `1104-bash-route-guard-*` に flag なし）で、flag 命名 `eh3-<topic>-pending-<issue>.flag` と report 命名 `<issue>-<topic>-patch-applicable.md` に機械的対応が無い。doctor に「未適用 patch」の項目は無い（`cmd_doctor` の section は v8.6.0 Metrics & Privacy 等のみ） | **摩擦**（適用は Human 固定で正しいが、「何が未適用か」を機械が出さないのは責務分界の Workflow-owned / CI-owned 部分の欠落） | `responsibility-classes.md`「検証は三者分担 / 適用待ちの追跡・完了ロック = Workflow-owned」。AI-owned 側は list/check の提供まで |
| **F5** | AI-owned 範囲が未明文化（#1135） | 規範層の欠落。hook 側は `DOC_LIGHT_SKIP`（非 HO `.md`）が唯一の「AI が書ける帯」の暗黙定義 | **摩擦** | `.claude/rules/*.md` は HO → 正本作成も AI は patch まで |

**判定の総括**: 5 型のうち「守るべき対象」は **F3 の `docs/working/TASK-*/plan.md` 部分と、F1 の Edit/Write 異常 payload のみ**。
それ以外は承認境界の外にある摩擦であり、**HO 9 カテゴリ・承認トークン・merge・`plan.md` 本体ガードを 1 バイトも弱めずに**是正できる。

### 本 PBI が変えないもの（Human 決定済み・不変）

- (a) #1263 は CI byte 一致ゲート方式 / (b) #1269「未解決 `$VAR` 先は block」= fail-closed 不変 / (c) **承認境界（HO 書き込み・承認トークン・merge）は本 PBI で一切弱めない**
- `PLANGATE_BYPASS_HOOK` / `PLANGATE_SKIP_TOKEN_GUARD` の扱い

## What（Scope）

**1 スライス = 1 PR** で分割する。HO パスに触れるスライスは **AI は patch 文書（`docs/working/_reports/<issue>-<topic>-patch-applicable.md`・
`git apply` 可能な unified diff・marker 抽出可能）+ apply スクリプト（`scripts/apply-*.sh`・`--dry-run/--apply/--revert`・smoke 失敗時自動 revert =
#1101 方式）+ pending flag + テストまで。適用は Human**。

### In scope

| スライス | 内容 | HO 接触 | AI-owned 範囲 | Human-owned |
|---|---|---|---|---|
| **S1: `apply-pending` 突合**（オーガナイザー案 S4。**最優先**） | `docs/working/_reports/*-patch-applicable.md` と `tests/fixtures/*-pending-*.flag`（および各 report が指す対象ファイルの実体）を突合し、**未適用 patch / stale flag / flag 欠落 report** を列挙する。`--list`（一覧）/ `--check`（未適用があれば rc≠0）。doctor に「Pending HO patches」section を追加 | **`bin/plangate` は HO 9 カテゴリ** → 配線のみ HO | **実体は `scripts/plangate-apply-pending.sh`（非 HO・AI 直接編集可）に置き、`bin/plangate` へは dispatch 1 行 + doctor section 呼び出しの最小 patch** に留める。report ↔ flag の対応規約（命名 or report 冒頭 front-matter で `pending_flag:` を宣言）を `docs/ai/hook-enforcement.md` に明文化 | `bin/plangate` patch の適用。**patch の適用自体は本ツールでは行わない**（list/check のみ） |
| **S2: AI-owned レーン正本**（issue AC-1） | `.claude/rules/ai-owned-lane.md`（新規・正本）に 3 帯を定義: **AI-owned**（no-task でも書ける）/ **Human-owned**（常時 block・現行不変）/ **Gray**（SKIP_REASON or maintenance 承認・現行どおり）。`docs/ai/hook-enforcement.md` の no-task 経路表と `responsibility-classes.md` からは**参照のみ**（再定義しない） | `.claude/rules/*.md` は HO | 正本の本文を patch 文書として作成。`docs/ai/hook-enforcement.md` の更新は非 HO で直接 | `.claude/rules/` への配置 |
| **S3: EH-3 no-task 経路をレーン判定へ接続**（issue AC-2/3/4/5/6） | no-task 分岐に **レーン判定関数**（例 `_eh3_lane()`; `_norm_target` を入力に `ai-owned` / `gray` を返す。HO は既存 `_override` で先に確定）を追加し、`ai-owned` なら `LANE_SKIP`（`hook-events.log` 記録・`skip-decision-log.jsonl` には書かない = 人間追認不要）で exit 0。allowlist 初期値: `tests/extras/*.sh`（**ただし承認境界を検査する `ta-65` / `ta-79` / 本 PBI の `ta-NN` は既定で除外 = Gray 維持。含めるのは Human C-3 の明示裁定時のみ**）/ `docs/working/templates/**`（`plan.md` 含む）/ 非 HO `.md`（現行 DOC_LIGHT_SKIP を吸収するか併存かは plan で決定）。**`case */plan.md)` は `docs/working/TASK-*/plan.md` 形状に限定**してテンプレートを外す | `scripts/hooks/*.sh` は HO | patch 文書 + `scripts/apply-1135-eh3-lane.sh` + `tests/fixtures/eh3-lane-pending-1135.flag` + 新規 `tests/extras/ta-NN-eh3-lane.sh`（サンドボックス複製で patch 適用後を実測・変異注入） | hook への適用・flag 削除。`sh scripts/apply-claude-settings.sh` は不要（配線変更なし） |

実行順: **S1 → S2 → S3**（S1 が S2/S3 の patch 適用漏れを機械検出する土台。S2 が S3 の allowlist 正本）。S2 と S3 は同一 PR にしない
（HO 2 ファイルの適用待ちを 1 つに束ねると片方の遅延が他方を巻き込む = #1031 の分割理由と同型）。

### Out of scope（変更しない / 別 issue）

- **承認境界の変更**: HO 9 カテゴリの定義・承認トークン（`approvals/*.json` / `maintenance.json`）の扱い・merge（NO MERGE BY AI）・`docs/working/TASK-*/plan.md` の no-task block
- **#1269**（未解決 `$VAR` 先の block）/ **#1263**（CI byte 一致ゲート）本体
- **#1104 本体**（Bash コマンド文字列からの書き込み先抽出）。Bash レーンは PR #1271 の `BASH_LANE_NOOP` を前提とし、本 PBI は `target_file` が与えられた経路のみを扱う
- **#1234**（repo 外パスの containment 判定）。オーガナイザー案 S1「判定順を『対象か？』先行に（repo 外 → SKIP）」は #1234 の in-scope と同一のため、**本 PBI には入れず依存先とする**（下記 Notes）
- **#1197**（no-task での `plan.md` 新規作成 / `bin/plangate plan new` bootstrap 免除 = オーガナイザー案 S3）。採用案 A/B/C は #1197 の C-3 判断
- **SKIP_REASON をセッションファイルから読む**（オーガナイザー案 S2）。既定は不採用（下記 Notes / Unknown U-1 で Human 判断）
- `plugin/plangate/**`（配布物）のレーン帰属（Unknown U-2。決まるまで Gray のまま）
- `check-forbidden-files.sh` へのレーン判定の複製（EH-3 単独で判定する）
- 導入先（plugin 配布物に `scripts/hooks/` は含まれない）での挙動

## 受入基準

> **消費箇所ごと**に立てる（hook 分岐 / doctor 出力 / テスト / docs / 適用機構）。全体量化子「すべて」は使わず、対象を列挙するか「列挙表の各行」で書く。
> rc は `PLANGATE_HOOK_TASK` 未設定・maintenance 不在・`PLANGATE_SKIP_REASON` 未設定・`Write` payload の条件で測る（`ta-65` / `ta-79` と同じサンドボックス複製方式）。

### S1（apply-pending / doctor）

- [ ] **AC-01**（CLI 出力）: `bin/plangate apply-pending --list` が、`docs/working/_reports/` 配下の `*-patch-applicable.md` **各ファイル**について `report / flag / 実体の適用状態 / 判定（PENDING · APPLIED · STALE_FLAG · NO_FLAG）` を 1 行ずつ出力する。着手時点の 4 本（`960-ho` / `1101-normalization` / `1104-bash-route-guard` / `1104-bash-lane-noop`）が期待どおりの判定で出る実測ログを添える
- [ ] **AC-02**（rc）: `--check` は PENDING / STALE_FLAG / UNDETERMINED が 1 件以上なら rc=1、0 件なら rc=0。NO_FLAG は WARN 表示のみで rc に影響しない（既存 report の遡及 flag 付与は本 PBI で行うが、将来の report 作成者の漏れを rc で止めるかは Unknown U-3）
- [ ] **AC-03**（doctor 出力）: `bin/plangate doctor` の出力に `=== Pending HO patches ===` section が追加され、AC-01 と同じ判定が表示される
- [ ] **AC-03b**（doctor `--json` 出力）: `--json` 経路（`doctor_check.py` 委譲）でも AC-03 と同じ項目・同じ判定が出る（text と JSON で件数が一致）
- [ ] **AC-04**（適用状態の検出方法）: 「適用済み」判定は report 内 marker 抽出 patch の `git apply --check --reverse` 成功（= 既に当たっている）で行い、flag の有無だけで判定しない（`ta-79` TC-00b の stale 検出と同じ原理）。forward / reverse の**双方**が失敗する場合（部分適用・手直し適用・context drift）は第 5 状態 **`UNDETERMINED`** とし、`--check` の rc=1 に含める（沈黙・誤 PENDING にしない）
- [ ] **AC-05**（責務）: `apply-pending` は**読み取りのみ**。`--apply` 相当のオプションを持たない（適用は Human 固定。`responsibility-classes.md` と一致）
- [ ] **AC-06**（テスト）: `tests/extras/ta-NN-apply-pending.sh` が report/flag/実体の 4 組合せ（PENDING / APPLIED / STALE_FLAG / NO_FLAG）を fixture で再現し PASS。判定関数の各分岐を 1 つずつ壊す変異で対応 TC が FAIL する
- [ ] **AC-07**（docs）: report ↔ flag の対応規約と **patch 抽出 marker（`<!-- PG-PATCH-BEGIN -->` / `<!-- PG-PATCH-END -->`）の必須化**が `docs/ai/hook-enforcement.md` に明文化され、既存 4 report がその規約に適合する（遡及分は同 PR で是正。現状 marker を持つのは `1104-bash-lane-noop` の 1 本のみで、`960-ho` / `1101-normalization` は素の fence、`1104-bash-route-guard` は apply スクリプト設計のため patch 化されていない部分を `UNDETERMINED` ではなく **`NO_PATCH`（apply script 経由）** として別扱いにする）
- [ ] **AC-08**（HO 接触の最小化）: `bin/plangate` への差分が dispatch 行 + doctor section 呼び出しに限られることを patch 文書の diffstat で示す

### S2（レーン正本 / docs）

- [ ] **AC-09**（正本の存在）: `.claude/rules/ai-owned-lane.md`（patch 文書として提示・Human 適用）に 3 帯（AI-owned / Human-owned / Gray）と、各帯の判定根拠（「承認境界か」「承認成果物か」「検証の土台か」）が書かれている
- [ ] **AC-10**（参照のみ）: `docs/ai/hook-enforcement.md` の no-task 経路表と `responsibility-classes.md`（HO・patch）は正本を**参照**し、帯の内容を再定義しない（`grep` で allowlist の重複列挙が 0 件）
- [ ] **AC-11**（不変の明記）: 正本に「Human-owned 帯 = HO 9 カテゴリ（`mode-classification.md` 承認境界節の `case` ブロックを参照・行番号不使用）+ 承認トークン + merge」が現行から**変更なし**である旨と、「AI-owned は allowlist であって bypass ではない」旨が明記されている

### S3（EH-3 レーン判定）

- [ ] **AC-12**（hook 分岐・AI-owned）: no-task で `tests/extras/ta-99-x.sh` / `docs/working/templates/plan.md` / `docs/working/templates/todo.md` / `docs/ai/foo.md` が **rc=0**、出力が `LANE_SKIP`。`LANE_SKIP` 経路は `skip-decision-log.jsonl` に**追記しない**。`.md` が既存 `DOC_LIGHT_SKIP` に先に落ちる場合は現行どおり `EH-3_DOC_LIGHT_SKIP` を追記してよい（`scripts/check-skip-acknowledged.sh` の追認対象外のため CI 負債にならない）
- [ ] **AC-12b**（hook 分岐・境界テストは Gray 維持）: no-task で `tests/extras/ta-65-eh3-ho-task-context.sh` / `tests/extras/ta-79-eh3-bash-lane.sh` が引き続き **rc=2**（`SKIP 拒否: SKIP_REASON 未設定`）。allowlist の glob が境界テストを吸い込まないことの負例
- [ ] **AC-13**（hook 分岐・plan.md ガード維持）: no-task で `docs/working/TASK-9999/plan.md` / `docs/working/TASK-9999/PLAN.md` / `docs/working/TASK-9999/plan.md `（末尾空白）が **rc=2**（`BLOCK: plan.md edited without TASK context`）。`PLANGATE_SKIP_REASON` 設定下でも rc=2
- [ ] **AC-14**（hook 分岐・HO 退行なし）: HO 9 カテゴリ（`ta-65` が hook の `case` から動的抽出する全パターン・現行 15）× #1101 の変換 13 形（7 種 + 2 種複合、`ta-65` TC-08）の直積が **rc=2**（`HARDENING_OVERRIDE`）。`ta-65` の既存直積 TC をそのまま流用し、レーン判定が HO 判定より**後**に評価されることを patch の配置で示す
- [ ] **AC-14b**（hook 分岐・承認トークン不変）: レーン allowlist に `approvals/**` / `_maintenance/**` / `*.json` 承認成果物を含めない（正本と hook patch を `grep` して 0 件）
- [ ] **AC-14c**（テスト・承認トークン guard 回帰）: 承認トークンへの書き込み guard は EH-13 `scripts/check-approval-token-write.sh` が担い本 PBI で変更しない。`ta-25` に新規 FAIL なし。issue #1135 AC-4 後段の「承認トークンのパスも block」は AC-14b + AC-14c で担保する
- [ ] **AC-15**（hook 分岐・Gray 帯偽陽性なし）: no-task で `scripts/foo.sh` / `scripts/lib/foo.sh` / `bin/other` / `schemas/x.json`（非 `.schema.json`）/ `.github/CODEOWNERS` / `plugin/plangate/hooks/hooks.json`（新規作成。現行は `.gitkeep` のみ）が引き続き **rc=2**（`SKIP 拒否: SKIP_REASON 未設定`）
- [ ] **AC-16**（hook 分岐・maintenance 併存）: maintenance 承認ファイル存在時の one_shot 消費 / `allowed_paths` / conversation-mode c3.json 経路の rc と出力が現行と一致（`_norm_target` の消費者 3 本 = #1101 AC-2 と同じ回帰表明）
- [ ] **AC-17**（テスト・検出力）: レーン判定関数内の各分岐（allowlist の各エントリ・`TASK-*` ディレクトリ条件・HO 先行）を 1 つずつ壊す変異を注入し、対応 TC が FAIL する。**patch 未適用の hook に対して AC-12 の TC が FAIL する**ことも含む
- [ ] **AC-18**（テスト・可搬性）: レーン判定関数を `sh` / `dash` / `bash` / `zsh` で直接評価した入出力が一致（#1101 AC-4 と同方式。`ta-*` 経由では測れない）
- [ ] **AC-19**（適用機構）: `scripts/apply-1135-eh3-lane.sh` が `--dry-run/--apply/--revert` を持ち、`--apply` 直後の smoke（AI-owned 1 件 rc=0 / HO 1 件 rc=2 / `TASK-*/plan.md` 1 件 rc=2）失敗時に自動 revert する。`tests/fixtures/eh3-lane-pending-1135.flag` が S1 の `apply-pending --list` で PENDING として出る
- [ ] **AC-20**（docs）: `docs/ai/hook-enforcement.md` の no-task 経路表に `LANE_SKIP` 行が追加され、Bash 経路（#1104）・repo 外（#1234）が「本レーン判定の対象外」として追跡 issue 番号付きで残る
- [ ] **AC-21**（実証）: 適用後、塞がっていた作業 1 件以上（候補: #1021 `tests/extras/ta-09-metrics.sh` / #1031 Slice 1 `docs/working/templates/plan.md`）を no-task セッションの `Write` で完了させた記録を添える
- [ ] **AC-22**（回帰）: `sh tests/run-tests.sh` に新規 FAIL がない。baseline は各スライス着手時に `origin/main` で再測定し、**絶対件数を契約値にしない**（本 worktree では実行禁止のため、実行は統合ブランチ側）

## Notes from Refinement

> 判断の正本は `decision-log.jsonl`（plan 生成時に初期化）。以下は要約。**オーガナイザー提案 4 スライスへの修正・却下**を含む。

### オーガナイザー提案 4 スライス（優先順 S4→S1→S2→S3）との対応

| 提案 | 本書での扱い | 理由 |
|---|---|---|
| **S4** `apply-pending --list/--check` | **採用 → S1（最優先）** | F4 の実測（report 4 本 vs flag 2 本・命名の非対応・doctor 項目なし）で必要性を裏付け。**修正点**: `bin/plangate` は HO 9 カテゴリなので「AI 直接実装」ではなく、実体を `scripts/`（非 HO）に置き `bin/plangate` は配線 patch のみ（AC-08）。適用状態は flag でなく `git apply --check --reverse` で判定（AC-04） |
| **S1** no-task 判定順を「対象か？」先行（repo 外 → SKIP / HO → BLOCK 不変） | **却下（本 PBI から除外・#1234 を依存先に）** | 内容が #1234 の In scope と同一（repo containment 判定 + AC-3 逆方向迂回 + false negative）。#1234 は既に AC 5 本と Mode（high-risk・2 ラウンド）を持つ独立 PBI で、ここに複製すると同じ HO 関数に 2 つの patch が競合する。**「対象か？先行」という順序設計自体は妥当**で、S3 のレーン判定は #1234 適用後の `_norm_target`（repo 内相対パス）を入力にする前提で書く |
| **S2** SKIP_REASON をセッションファイル（gitignore・監査転記）からも読む | **既定不採用（Unknown U-1 で Human 判断）** | (1) hook コメントは「SKIP_REASON 源は env のみ」と明示し、V-3 MJ-2 で todo.md 源を**死に分岐として除去**した経緯がある。(2) maintenance は「承認ファイルのみ = AI 自己付与不可（R-011）」が設計原則で、AI が実行中に書けるファイルを SKIP 源にすると **Gray 帯全体が「AI 自己宣言 + 事後追認」帯に変わる**（HO は不変でも Gray の意味が変わる = レーン設計の変更を 1 スライスで暗黙に行うことになる）。(3) 実害として挙がった対象（`tests/extras` / templates / 配布作業 3 件）は S3 の allowlist で到達可能になり、S2 が無くても Why の実害は解消する。**Human が「Gray 帯を事後追認帯にする」ことを明示的に決めるなら別 PBI として起票** |
| **S3** `bin/plangate plan new` の新規 TASK bootstrap に限り EH-3 免除 | **却下（#1197 へ）** | (1) #1197 が案 A（起動導線明示・推奨）/ B（承認トークン未発行時のみ新規作成許可）/ C の選択を C-3 判断としており、ここで B 相当を先取りすると #1197 の判断を空洞化する。(2) CLI 経路は Bash レーンで、#1271 適用後は `BASH_LANE_NOOP`（`target_file` 空 ∧ `task_id` 空 ∧ stdin 非空 ∧ jq 存在 ∧ `tool_name=Bash` の 5 条件。jq 不在時は従来どおり `SKIP_BLOCKED` で安全側）により**そもそも EH-3 が見ない**（免除の実装対象が無い）。#1104 本体で Bash 書き込み先抽出が入った時点で初めて「bootstrap の allow 条件」が要るので、その設計は #1104 本体 + #1197 案 B の安全条件（新規作成のみ・c3.json 未発行時のみ・変異注入で実証）に委ねる |

### 追加した論点

- **「HO 外」≠「到達可能」の誤認防止**（#1135 コメント）: S2 の正本に「no-task 経路の 3 段（HO → plan.md → レーン/SKIP_REASON）」を図示し、AI が自分の到達範囲を判定できる **1 コマンド**（例 `bin/plangate lane <path>` = レーン判定関数の dry-run）を S3 に含めるかは Unknown U-4
- **`DOC_LIGHT_SKIP` との関係**: 現行の非 HO `.md` 自動 SKIP は `skip-decision-log.jsonl` に `EH-3_DOC_LIGHT_SKIP` を書くが `scripts/check-skip-acknowledged.sh` は `EH-3_SKIP` のみを追認対象にするため CI 負債にならない。`LANE_SKIP` も同じ扱い（skip-decision-log に書かない or 追認不要 event）にする。maintenance 承認ファイル存在時は現行どおり token ライフサイクル優先（doc-light を発火させない）— レーン判定を maintenance より前に置くか後に置くかは plan で確定（前に置くと maintenance 窓の消費を回避できるが、`allowed_paths` で AI-owned 帯を**狭める**運用ができなくなる）
- **`tests/extras/*.sh` を開ける是非**（issue 設計上の注意 2）: テストコードは承認境界ではないが「検証の土台」。対抗策は AC-17（変異注入）に加え、**`tests/extras/ta-65` / `ta-79` / 新規 `ta-NN`（承認境界を検査するテスト）を allowlist から除外するか**を Unknown U-5 とする（除外すると「承認境界のテストは Gray」= 現行維持）
- **allowlist 初期値からの意図的な除外**: issue #1135 の AI-owned 案にある `docs/**/*.md（アーカイブ除く）` の「アーカイブ除く」条件は、現行 `DOC_LIGHT_SKIP` が既に非 HO `.md` を無条件 SKIP しており本 PBI で狭めると退行になるため S3 の初期 allowlist に含めない（Unknown U-9: アーカイブ配下 `.md` を Gray に戻すかは plan で裁定）
- **却下案の構造化**: 上表の S1/S2/S3 却下理由は plan 生成時に `decision-log.jsonl` の `alternatives_rejected` へ転記する（テンプレ規約。本書はその要約）
- **EH-13 の偽陽性（本書作成時に実測）**: 本書を Bash heredoc で書こうとしたところ、EH-13 `scripts/check-approval-token-write.sh` が本文中の Markdown 強調 `**DRAFT**` を `rule=file-redirect, redirect_target=**DRAFT` としてワイルドカード付きリダイレクト先と誤認し block した（承認トークン系パスとは無関係）。fail-closed 設計どおりの挙動だが、「heredoc 本文の `**` をリダイレクト先として解析する」クラスは #1115 の外側ゲートの残存偽陽性として別途記録が要る（本 PBI の scope 外・Unknown U-8）。回避は `Write` ツール（EH-3 が発火するより強いガードのレーン）で行い、迂回ではない
- **本 worktree の前提ずれ**: オーガナイザーの指示は「この worktree の版は #1104 hotfix + #1101 正規化が適用済み」としていたが、実測では両方未適用（flag 2 本現存・hook 最終変更 #1089・`.claude/settings.json` 不在）。本書の rc 表は**未適用の hook**に対する読解であり、plan 生成時に #1271 マージ後の `origin/main` で再測定すること

## Estimation Evidence

### Risks

| リスク | 影響 | 緩和 |
|---|---|---|
| allowlist の glob が意図より広い（例 `docs/working/templates/**` に将来 HO 相当の物が置かれる） | AI-owned 帯の silent 拡大 | 正本に「追加は Human C-3 必須」を明記。AC-15 の Gray 偽陽性なし TC と AC-14 の HO 直積を同一 TC ファイルに置き、allowlist 変更時に両方が回る |
| レーン判定を HO 判定より**前**に置いてしまう実装ミス | HO 迂回（critical） | AC-14 + 変異「レーン判定を HO の前へ移す」で TC FAIL を実証（AC-17） |
| `tests/extras` を AI が書けることで承認境界テストが弱められる | 緑が意味を失う | U-5 の除外判断 + 既存 `ta-*` の変異注入テストが残る + C-4 Human レビュー |
| 3 スライス分の HO patch が Human 適用待ちで滞留 | 摩擦が解消しない | S1 を最優先で入れ、doctor が未適用を毎回表示する |
| #1234 / #1271 の適用順と patch 競合（同一 no-task 分岐） | `git apply` 失敗 | S3 の patch は #1271 + #1234 適用後の `origin/main` を基点に作る（順序を plan に固定） |
| 実 Claude Code セッション 1 周の未検証（fixture payload のみ） | 実 API 形状由来の失敗 | AC-21 の実証を実セッションで行い、残存脅威モデルに「未検証」を明記（§7-quater） |

### Unknowns（Human 判断が要るもの）

- **U-1**: オーガナイザー案 S2（SKIP_REASON セッションファイル）を **本 PBI で不採用**とし、「Gray 帯を事後追認帯にする」判断を別 issue に切り出してよいか（既定: 不採用）
- **U-2**: `plugin/plangate/**`（配布物 = `sync-plugin-plangate.sh` の生成物）と `scripts/sync-plugin-plangate.sh` のレーン帰属。issue コメントで Human 判断待ち。候補: Gray 維持（既定）/ AI-owned + sync dry-run 一致を CI で検査
- **U-3**: `apply-pending --check` で NO_FLAG（report はあるが flag が無い）を rc=1 にするか WARN に留めるか（既定: WARN。遡及分は S1 で flag を付与）
- **U-4**: AI が自分の到達範囲を事前判定する `bin/plangate lane <path>`（判定関数の dry-run）を S3 に含めるか（`bin/plangate` は HO のため配線 patch が増える）
- **U-5**: `tests/extras/*.sh` のうち**承認境界を検査するテスト**（`ta-65` / `ta-79` / 本 PBI の `ta-NN`）は**既定で除外**（安全側 = `mode-classification.md` の「判定不能は該当扱い」と同方向）。**含める側へ倒すには Human C-3 の明示裁定が要る**
- **U-6**: レーン判定を maintenance 判定の前に置くか後に置くか（上記 Notes）
- **U-7**: 着手順。issue は「#1101 / #1104 の是正後に入れるほうが安全」としており、本書は #1271（Bash no-op）と #1234（containment）を S3 の前提にした。**S1 / S2 は依存なしで先行可**
- **U-8**: EH-13 の heredoc 本文 `**` 偽陽性を issue 起票するか（本 PBI 外。起票は Human または承認後の AI）
- **U-9**: アーカイブ配下 `.md` を Gray に戻すか（issue 案の「アーカイブ除く」条件。現行 DOC_LIGHT_SKIP を狭める退行になるため既定は「戻さない」）
- **U-10**: AC-04 の `UNDETERMINED`（forward / reverse 双方 fail）を S1 で rc=1 に含めるか、Human 目視へ回すか（既定は rc=1）

### Assumptions

- PR #1271 がマージされ `BASH_LANE_NOOP` が `origin/main` に入る（Bash レーンは本 PBI の対象外）
- #1234 が S3 より先に適用され、レーン判定の入力 `_norm_target` は repo 内相対パスに限定される
- HO 9 カテゴリ・承認トークン・merge・`docs/working/TASK-*/plan.md` ガードの定義は変えない
- `tests/extras/*.sh` / `scripts/apply-*.sh` / `scripts/plangate-apply-pending.sh` / `docs/ai/*.md` / `docs/working/**`（`TASK-*/plan.md`・`approvals/**`・`_maintenance/**` を除く）は HO 対象外で AI が直接編集できる
- **Mode = high-risk**（`.claude/rules/*.md` / `scripts/hooks/*.sh` / `bin/plangate` = HO 対象パスに触れるため `mode-classification.md` の例外ルール「承認境界周辺 → 最低 high」に該当。`lite_eligible=false` 強制・**人間 C-3 同期**・autonomous APPROVE 不可）。定量基準では AC 26 本（S1: 9 / S2: 3 / S3: 14）が `critical` 帯に入るが、#1101 と同じく「穴が塞がったことを消費箇所ごとに測るために分解した結果」であり、スライス単位（S1: 9 / S2: 3 / S3: 14）では high-risk 帯。**override の可否は C-3 で Human が裁定**（#1101 の選択肢 A/B/C と同形）
- **敵対レビュー**: `review-principles.md` §7-quater により承認境界に触れる S3 は **2 ラウンド以上**を plan に含める。2 ラウンド目は「レーン判定の追加が HO 判定・plan.md 判定・maintenance 経路に新たに開けた穴」を疑う。S1 も `bin/plangate`（外部作用層）に触れるため 2 ラウンド。S2 は文書のみだが正本であるため 1 ラウンド + C-3
- 本 PBI は ai-loop-workflow の帯外（`touches-HO`）で escalate 固定

## 関連

- #1035（親 EPIC）/ #927（非対称 C）/ #1092（実害データ出所）
- #1104 / PR #1267 / PR #1271（Bash レーン）/ #1101 / TASK-1101（HO 正規化・patch 方式の先例）/ #1089（HO を task 文脈非依存に）
- #1234（repo 外 containment）/ #1197（no-task plan.md 新規作成）/ #1077（リリース Human 手数）/ #1031（templates/plan.md 見出し契約）/ #1144（配布作業 3 件）
- `docs/working/_reports/1104-bash-lane-noop-patch-applicable.md` §1 / §4、`docs/ai/hook-enforcement.md` no-task 経路表、`.claude/rules/responsibility-classes.md`、`.claude/rules/mode-classification.md` 承認境界節
