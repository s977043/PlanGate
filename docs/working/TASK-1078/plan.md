---
task_id: TASK-1078
artifact_type: plan
schema_version: 1
status: draft
mode: high-risk
related_issue: https://github.com/s977043/plangate/issues/1078
created_by: orchestrator
---

# TASK-1078 S-2 Implementation Plan — Codex hook bridge の I/O 契約修正

> 本 plan は #1078 のスライス **S-2** のみを対象とする。S-1（文書是正）は完了済み、S-3〜S-6 は後続。
> 入力: [`pbi-input.md`](./pbi-input.md) / [`evidence/codex-exec-spike.md`](./evidence/codex-exec-spike.md)（本文 + 追記 1 / 追記 2）
>
> **evidence 参照の実在性**（R-F05）: `evidence/codex-payload-spike.md` は**本ブランチに存在しない**。
> 同内容は PR [#1088](https://github.com/s977043/plangate/pull/1088)（branch `spike/1078-codex-payload`・**未マージ**）にある。
> 本 plan / pbi-input / test-cases は **`codex-exec-spike.md` の「追記 1」「追記 2」に載っている実 payload 実物**のみを根拠とし、
> #1088 は**参考リンク**として扱う（マージ待ちを本 PBI の前提条件にしない）。

## Goal

`.codex/hooks/eh-bridge.sh` の I/O 契約を PlanGate hook の実際の入出力仕様に合わせ、
**bridge が deny を返すべき入力に対して実際に deny を返す**状態を作る。
そのうえで `.codex/hooks.json` の注記キーを除去して hook を登録し、
**「登録されたが効かない」中間状態を一度も経由せずに**、Codex ランタイムでの block を**取れる範囲で**実証する。

### S-2 の完了の定義（何をもって「終わった」と呼ぶか）

本 PBI は「効いていることの証明」を **3 層に分解**し、**それぞれ別の強度で**扱う。
まとめて 1 つの成果として主張しない（R-1）。

| 層 | 内容 | 証明可能性 | 本 PBI での扱い |
|---|---|---|---|
| **L-A: bridge 契約層** | 実 payload 形状の入力に対し bridge が正しく deny / allow を返す | **完全に証明可能**（課金ゼロ・決定論的・変異注入で検出力も実証） | **必達**（AC-01〜05・AC-10〜12） |
| **L-B: 登録層** | `hooks/list` に登録され warnings が空 | 証明可能（課金ゼロ） | **前提条件 P-1**。**受入基準にしない**（AC ではない） |
| **L-C: ランタイム発火層** | Codex が実際に hook を呼び、deny で操作を止める | **U-4 が未解決のため証明できるとは限らない** | **AC-07。PASS または WARN（理由記録付き）** |

**L-A が全て PASS すれば S-2 の主要価値（bridge の I/O 契約が正しい）は達成**である。
L-C は「S-2 で確定できれば望ましい」が、**確定できなかったこと自体が S-4（`trusted_hash` 運用）の前提条件を確定させる成果**として扱う。
**L-A を満たさないまま L-B / L-C に進むことだけを禁止する**（順序の逆転禁止）。

## Context

- 背景: [`pbi-input.md`](./pbi-input.md) §Context / Why
- 関連 Issue: <https://github.com/s977043/plangate/issues/1078>
- 関連 artifact: `pbi-input.md` / `todo.md` / `test-cases.md` / `status.md`（S-1 由来・本 PBI では追記のみ）

## Scope

### In Scope

- `.codex/hooks/eh-bridge.sh`（I/O 契約: stdin 転送 / stdout 判定 / fail-closed / hook パス解決 / **複数パス patch の全件評価** / 一時ファイルの `mktemp` 化）
- `.codex/hooks.json`（matcher の死に文字列除去 → 最後に注記キー除去）
- bridge の fixture 駆動テスト（新規）
- `docs/ai/settings-wiring-contract.md` の責務分界節の曖昧さ解消

### Out of Scope

- EH-13 / EH-12 の配線（S-7 へ申し送り）/ `scripts/**` の hook 本体（HO・Human-owned）/ `.claude/settings*.json`
- `hooks/list` 検査の doctor・CI 組み込み（S-3）/ `trusted_hash` 運用の**自動化**（S-4。ただし手順の確立は本 PBI の前提として実施）

> 実装中にスコープ外の不具合を見つけた場合はその場で直さず handoff の V2 候補 / 別 Issue へ分離する。

## Global Constraints

- **`scripts/hooks/*.sh` を 1 行も変更しない**（HO パス。変更が必要と判明したら停止して Human 判断を仰ぐ）
- **`.claude/settings*.json` を変更しない**
- **`PLANGATE_HOOK_STRICT` の既定値を変えない**（既定 warning のまま。強度変更は別 PBI）
- deny の `permissionDecisionReason` は**常に非空**にする（空 reason は Codex ランタイムで黙って握り潰されることが実測済み）
- **判定に使う入力は hook の「stdout」と「exit code」の 2 つ。`stderr` は判定に使わない**（reason 素材にのみ使う）。
  誤読防止のため明記する: **exit code は判定チャネルである**（EH-3 は block を `rc=2` で表すため、rc を捨てると EH-3 の deny が消える）。
  「stdout のみ」という短縮表現は使わない（R-F11）

## 前提の実測検証（#786）

> 実施日 2026-08-13 / base `origin/main` = `8f57e59` / 合成サンドボックス（実リポジトリのファイルは複製のみ・書き込みなし）。
> 5 hook の複製 + 実 payload 形状 fixture 6 種 × bridge 4 variant × `PLANGATE_HOOK_STRICT` × `PLANGATE_HOOK_TASK` を全数実行。
>
> 🔴 **本表の実行ログは本ブランチに commit されていない**（R-F05）。したがって本表は現時点で
> **「再現待ちの仮説」であり、証跡ではない**。exec では以下で埋める:
>
> 1. **Task 1（T-01）が本表と同じ条件を fixture テストとして再現し、その実行ログを `evidence/verification/` に commit する**。
>    T-01 の期待値は本表から**転記するのではなく、実行結果で確定する**。転記した期待値と実測が食い違った場合は
>    **本表の側を訂正**し、`decision-log.jsonl` と `status.md` に差分を記録する（plan の記述は exec で初めて検証される）。
> 2. 本表を根拠に「〜が実測で確定している」と handoff / doc に書くのは、上記 commit が済んだ後に限る。

| 前提 | 検証方法 | 実測結果 | 判定 |
|---|---|---|---|
| 現行 bridge は allow に倒れる | variant A（現行）に 18 ケース投入 | **16/18 allow**。deny は EH-3 の HO パス 2 件のみ（`.claude/settings.json` / `bin/plangate`・TASK 文脈なし時） | ✅（ただし「全 allow」は誤り。下記 ❗ 参照） |
| **stdin を転送すると deny が出始める** | variant B（stdin 転送のみ）を A と同条件で比較 | **A と完全一致（差分 0 件）**。STRICT=0/1・TASK 有無の 4 条件すべてで同一 | ❌ **前提崩壊** |
| block は exit code で表現される | 5 hook を直接起動して rc と stdout を観測 | **EH-1 / EH-2 / EH-6 / EH-9 は block 時も `rc=0`**、stdout に `{"continue":false,...}`。**exit 2 を使うのは EH-3 のみ** | ❌ **前提崩壊** |
| stdout を判定に使えば deny が回復する | variant D（stdout 解釈のみ・stdin 非転送） | EH-1 / EH-2 の deny が回復。**EH-9 は allow のまま** | ✅ |
| stdin と stdout の両方が要る | variant C（両方） | **EH-9 の deny が回復**（D との唯一の差） | ✅ |
| deny の reason が空になりうる | 無出力 `exit 2` / `exit 1` の hook を bridge に投入 | reason は `"PlanGate <name> blocked: "`。**前置文字列により常に非空** | ✅（設計ではなく偶然。契約として明文化する） |
| stdout/stderr を混ぜても安全 | stderr にのみ `"continue":false` を出す hook を variant C に投入 | **false deny が発生**（stdout は `{"continue":true}`） | ❌ **判定チャネル分離が必須** |
| hook の env はテストで固定されている | `env \| grep PLANGATE` | セッションが **`PLANGATE_HOOK_TASK` を継承**。付与すると EH-3 の HO block が**消える** | ❌ **テストは env を明示制御する** |

❗ **重要な訂正**: 「現行 bridge は 12/12 allow」は**条件付きで正しい**。`PLANGATE_HOOK_TASK` が設定された状態では HO パスも allow になるが、
**未設定なら EH-3 の HO 常時 block は現行 bridge でも deny を返す**。すなわち**注記キーの除去だけでも EH-3 の HO block は発火し始める**。

### stdin 転送後に deny が出始めるケース（実測・variant C / 既定 `STRICT=0`）

| # | payload | 対象 | decision | 誰が deny したか |
|---|---|---|---|---|
| P1 | `apply_patch` → `docs/working/TASK-9999/plan.md` | 通常作業 | **allow** | — |
| P2 | `apply_patch` → `.claude/settings.json` | HO パス | **deny** | EH-3（HO 常時 block） |
| P3 | `apply_patch` → `bin/plangate` | HO パス | **deny** | EH-3（HO 常時 block） |
| P4 | `apply_patch` → `docs/working/TASK-8888/notes.md`（plan.md 不在） | 未計画 TASK | **allow** | —（STRICT=1 なら EH-1 / EH-2 が deny） |
| P5 | `Bash` `git commit -m wip` | 委譲文脈（`NOCOMMIT=1`） | **deny** | EH-9 |
| P6 | `Bash` `git push --force origin main` | 委譲文脈（`NOCOMMIT=1`） | **deny** | EH-9 |
| P5' | 同 P5・`NOCOMMIT` 未設定 | 通常セッション | **allow** | — |

**結論: 既定設定で deny されるのは「HO パスへの書き込み」と「委譲文脈での commit/push」のみ**。
通常の実装作業は deny されない。**したがって段階導入は成立し、Codex が使用不能にはならない**（停止条件 SC-1 は発火しない）。
`STRICT=1` を与えた場合のみ EH-1 / EH-2 が広く deny する（本 PBI では既定を変えない）。

> 🔴 **HO deny の成立条件（#1089 との関係）**: 上表の P2 / P3（HO パスの deny）は
> **`PLANGATE_HOOK_TASK` が未設定であること**に依存する。`check-plan-hash.sh` の
> Hardening Override 判定は `if [ -z "$task_id" ]` ブロックの**内側**にあり
> （`task_id` は `PLANGATE_HOOK_TASK` 由来）、**TASK が設定された Codex セッションでは HO block が発火しない**。
> これは本 PBI の scope 外の別欠陥として [#1089](https://github.com/s977043/plangate/issues/1089) に起票済み。
>
> - 本 PBI は **`.codex/**` の I/O 契約のみを直す**。#1089 の修正は `scripts/hooks/*.sh`（HO パス / Human-owned）であり **S-2 では触らない**。
> - したがって **S-2 完了後も「TASK 文脈下の HO 書き込み」は Codex 側で block されない**。
>   この限界は handoff と `settings-wiring-contract.md` に**明記する**（AC-09）。
> - bridge は `docs/working/TASK-*/` を含むパスから `PLANGATE_HOOK_TASK` を自動導出する（`eh-bridge.sh:57-64`）。
>   HO パスは `docs/working/` 配下でないため自動導出では設定されないが、**セッション env が既に持っていれば継承される**（R-4）。

## Questions / Unknowns（#786）

- 🔴 **U-4（未解決・本 PBI 最大の前提リスク）**: **`--dangerously-bypass-hook-trust` を付けずに Codex の PreToolUse hook が発火するか。**

  **これは「未確認」ではなく「反証寄りの実測がある」状態である。** `evidence/codex-exec-spike.md` の 3 回の実走を突き合わせると:

  | run | trustStatus | `--ephemeral` | `--dangerously-bypass-hook-trust` | hook 発火 |
  |---|---|---|---|---|
  | #1（L91-101） | **trusted**（手書き `[hooks.state]`） | あり | **なし** | **0 回**（probe A / B とも呼ばれず） |
  | #2（L159-162） | trusted | なし | **あり** | 発火（probe A/B 各 2 回） |
  | #3（L284-287） | **untrusted** | なし | **あり** | 発火（probe A が 3 回） |

  → **「bypass を付けずに hook が 1 度でも発火した」観測は 1 件も存在しない。**
  さらに evidence L109 は失敗候補として「手書き `[hooks.state]` の trust は **`hooks/list` には反映されるが実行時には効かない**」を挙げており、
  run #3 は **untrusted のまま bypass で発火**している（L287）。

  ❗ **したがって「`hooks/list` で `trusted` を確認すれば発火可否の検証は不要」という当初の解消条件は成立しない**（自リポジトリの evidence がそれを否定している）。

  **新しい解消条件（本 PBI で採用）**:
  1. AC-07 の実走は **`--dangerously-bypass-hook-trust` を付けない**（Task 5 Step 4・TC-14 の必須条件）。
  2. bypass 無しで block が観測できた → **U-4 解消・AC-07 PASS**。
  3. bypass 無しで block が観測できない → **AC-07 を PASS にしない（WARN 固定）**。
     このとき「`trusted_hash` は `hooks/list` 上の表示を変えるだけで実行時発火を保証しない」ことが確定し、
     **その検証は S-4（`trusted_hash` 運用）の前提**として申し送る。**この結果も S-2 の成果である**（U-4 が「未確定」から「否定」へ動く）。
  4. **どちらに転んでも L-A（bridge 契約層）の完了判定には影響しない。**

  > **なぜ課金ゼロで先に切り分けられないか**: evidence L182 のとおり、app-server `thread/start` 経由では
  > SessionStart hook すら発火せず、**課金ゼロで hook 発火を観測できる経路は探索済みで見つかっていない**。
  > よって U-4 の解消には実走 1 回が必要で、それが Task 4（H-01）の Human 判断対象である。

- **U-5**: `codex exec` が PreToolUse を評価する条件（run #1 では `--ephemeral` あり・bypass なしで発火 0、run #2 で 2 変数を同時に変えたため未切り分け）。
  **解消条件**: AC-07 の実走を **非 `--ephemeral` かつ bypass 無し**で行う。これで残る差分が trust だけになり、U-4 と同時に切り分けられる。
- **U-6**: 1 matcher group 内の複数 hook が最初の deny で打ち切られるか。**解消条件**: AC-07 の証跡読解時に stderr の hook 名で判断（設計には影響しない）。
- **U-7（gating ではない）**: Codex の matcher が正規表現の完全一致か部分一致か。

  ❗ 当初の解消条件「Stage 2 後の `hooks/list` で確認」は**構造的に実行不能**だった。Stage 2 の完了条件は
  「注記キーが残り parse 拒否＝登録 **0 件**」であり、**0 件の状態では matcher を観測できない**（唯一の不可逆ステップの後にしか解けない）。

  **再評価の結果、U-7 は T-04 の gating 条件ではない**:
  現行 matcher `apply_patch|Edit|Write` から `Edit|Write` を除いて `apply_patch` にする変更は、
  **完全一致・部分一致・正規表現 alternation のいずれの解釈でも `apply_patch` に対するマッチを減らさない**
  （alternation の 1 項をそのまま残すため）。よって「この変更で apply_patch が拾われなくなる」経路は存在しない。
  **解消条件**: Stage 3（注記キー除去後）の `hooks/list` で matcher 文字列と登録件数を記録する（**観測であって gate ではない**）。
  異常時の戻しは Task 3 の Rollback（1 コマンド）。

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | `eh-bridge.sh` を拡張（stdin 転送 + stdout 判定 + fail-closed + パス解決フォールバック） | 既存 guard を共用（#1078 Non-goals 準拠）・1 箇所に集約 | 配線済み 5 hook すべての挙動が変わる → 回帰検証が要る | **採用** |
| B | EH-13 専用アダプタを新設 | 既存 5 hook に影響しない | Codex 側に独自 guard を増やす方向で **#1078 Non-goals に抵触**・二重実装 | 不採用 |
| C | hook 本体（`scripts/hooks/*.sh`）を Codex 形式に合わせる | bridge が薄くなる | **HO パス改変＝Human-owned**・Claude 側の挙動に影響 | 不採用 |

### Recommended Approach

**案 A**。ただし「B の懸念（回帰）」を**注記キーを kill switch として使う段階導入**で吸収する。

> **設計の核**: `.codex/hooks.json` の注記キーが残っている限り、**Codex は当該ファイルを読み込めず hook は 1 件も登録されない**。
> つまり **Stage 1〜2 の変更は Codex ランタイムに一切影響しない**。注記キーは事実上の **feature flag** であり、
> その除去（Stage 3）が唯一の「有効化」操作になる。ロールバックは **1 行の再追加**で全体を即時無効化できる。
>
> ⚠️ **「parse 拒否」の正確な意味**（R-F08）: `.codex/hooks.json` は **JSON 構文としては valid** である
> （`python3 -m json.tool .codex/hooks.json` は **rc=0**。ta-15 TC-03 が PASS しているのはこのため）。
> 拒否しているのは **Codex 側の serde スキーマ層**で、**top-level に `description` / `hooks` 以外のキーがあること**が原因
> （evidence 追記 1 L176 で `description` のみの hooks.json が warning 無しで受理されることを実測）。
> したがって kill switch の成立条件は「**JSON 構文を壊すこと**」ではなく「**top-level に未知キーを 1 つ足すこと**」である。
> rollback 手順・テスト・doc はすべてこの表現に統一する（構文破壊を rollback 手段にしてはならない）。

## Files / Interfaces

| ファイル | 操作 | 目的 | 公開インターフェース / 依存 |
|---|---|---|---|
| `.codex/hooks/eh-bridge.sh` | modify | I/O 契約修正 | 入力: Codex PreToolUse JSON (stdin) / 出力: `hookSpecificOutput.permissionDecision` |
| `.codex/hooks.json` | modify | matcher 整理 → 注記キー除去 | top-level は `description` / `hooks` のみ |
| `tests/extras/ta-65-codex-bridge-io.sh` | create | fixture 駆動テスト（**フラット配置必須**・下記 ❗） | `tests/extras` 共有 exit 契約（`_extra-contract.sh`）に従う |
| `tests/extras/ta-15-codex-hook-bridge.sh` | modify | 既存の同一対象テストの棚卸し（Task 1b） | TC-03 を 2 値化 / TC-04 の「wires」断定を除去 |
| `tests/fixtures/codex-bridge/*.json` | create | 実 payload 形状 fixture | 既存慣行に一致（`FIXTURES_DIR="tests/fixtures"` / `tests/run-tests.sh:23`。`tests/extras/` 配下に fixture ディレクトリを新設しない） |
| `tests/extras/README.md` | modify | 一覧表に ta-65 を追記（既存規約） | — |
| `docs/ai/settings-wiring-contract.md` | modify | 責務分界のパス単位明確化 + S-2 の限界明記 | — |
| `docs/working/TASK-1078/status.md` | modify | フェーズ履歴追記（**既存記述は改変しない**） | — |

❗ **テストをサブディレクトリに置いてはならない**（R-F03。当初案 `tests/extras/codex-bridge/run.sh` は**誤り**）:

- loader は `tests/run-tests.sh:165` の **`for extra in "$EXTRAS_DIR"/ta-*.sh`** ＝ **フラット glob**。
  サブディレクトリ配下のファイルは**永久に発見されず、CI で 1 度も実行されない**（＝静かに通る失敗）。
- extras は **実行されるのではなく `.` で source される**（`tests/run-tests.sh:169`）。
  よって独立した `run.sh` ではなく、**`pass` / `fail` カウンタを共有する `ta-NN-*.sh`** として書く。
- 命名は `ta-NN-<short-name>.sh`（`tests/extras/README.md:7`）。**現行の最大は `ta-64` なので `ta-65` を採る**
  （採番衝突時は `ls tests/extras/` を再確認して次の空き番号にする。番号は本 plan の契約値ではない）。
- `pg_extra_contract_init "ta-65" <standalone-capable|harness-only>` を先頭で呼び、共有 exit 契約に載せる（#921 / `ta-61` 参照）。
- **fixture は `tests/fixtures/codex-bridge/` に置く**（既存 12 ディレクトリと同じ慣行。`FIXTURES_DIR` = `tests/fixtures`）。
  harness 経由では `$FIXTURES_DIR` で参照でき、standalone 実行を残す場合はスクリプト位置からの相対で解決する
  （解決できないなら `pg_extra_contract_init "ta-65" harness-only` を宣言して standalone 経路を持たない）。

## Work Breakdown

> **plan Task ↔ todo T-NN 対応表**（R-F02。**番号が別体系なので必ずこの表で読み替える**）:
>
> | plan | todo | 内容 | 不可逆性 |
> |---|---|---|---|
> | Task 1 | **T-01** | fixture + baseline テスト（ta-65） | 可逆 |
> | Task 1b | **T-00** | 既存 `ta-15` の棚卸しと責務分界 | 可逆 |
> | Task 2 | **T-02** | bridge の I/O 契約修正 | 可逆（Codex 未到達） |
> | Task 2b | **T-03** | 変異注入によるテスト検出力の実証 | 可逆 |
> | Task 3 | **T-04** | **matcher の死に文字列除去**（`Edit`/`Write`） | 可逆 |
> | Task 4 | **H-01** | 👤 有効化前ゲート（Human 判断） | — |
> | Task 5a | **T-05** | `trusted_hash` 手順の確立 | 可逆（文書のみ） |
> | Task 5b | **T-06** | **注記キー除去＝有効化** | 🔴 **唯一の不可逆ステップ** |
> | Task 6 | **T-07** | 責務分界 doc の是正 | 可逆 |
> | — | T-08 / T-09 | 非回帰の証明 / status・handoff | 可逆 |
>
> ⚠️ **番号の衝突に注意**: 「plan Task 4」は **Human ゲート**、「todo T-04」は **matcher 除去**であり、**別物**。
> 本文中では常に **`plan Task N` / `todo T-NN` と接頭辞つきで書く**。**不可逆ステップは `todo T-06`（= plan Task 5b）だけ**である。

### Task 1（todo T-01）: fixture と baseline テストの導入（挙動不変）

**Purpose**: 実 payload 形状の fixture を固定し、**現行 bridge の挙動をテストで固定**する。以後の変更差分を機械的に可視化する。

**Files**: Create `tests/extras/ta-65-codex-bridge-io.sh`, `tests/fixtures/codex-bridge/*.json`

**Steps**:

- [ ] Step 1: 実測済み payload 形状（`hook_event_name` / `tool_name` ∈ {`apply_patch`, `Bash`} / `tool_input` / `cwd` / `permission_mode` / `tool_use_id`。実物は `evidence/codex-exec-spike.md` 追記 1 L189-196 / 追記 2 L292-298）で fixture を作成する
- [ ] Step 2: **テスト用サンドボックスの構造を確定する**（下記「テストサンドボックス設計」）。bridge は `scripts/**` を改変せずに検証できなければならない
- [ ] Step 3: テストが bridge を呼び、`permissionDecision` を抽出して期待値と突合する。**`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_STRICT` / `PLANGATE_DELEGATION_NOCOMMIT` を必ず明示設定**する（継承禁止 / `env -u` で明示 unset）
- [ ] Step 4: bridge 呼び出しは必ず **stdin を明示的に与える**（`printf '%s' "$payload" | ...`）。stdin 無しで呼ぶと `INPUT=$(cat)` がハングしうる
- [ ] Step 5: 期待値は**転記ではなく実行結果で確定**し、本 plan「前提の実測検証」表との差分があれば **plan 側を訂正**する
- [ ] Step 6: **`tests/extras/README.md` の一覧表に `ta-65` の行を追記する**（既存規約。README は Files 表に挙がっているが Step が無かった＝ R2-4）
- [ ] Step 7: `sh tests/run-tests.sh` を **全体実行**して PASS することを確認する（**単体実行だけで済ませない**。loader に拾われたことの唯一の証明）
- [ ] Step 8: 実行ログを `evidence/verification/` に commit する

> **stage 依存 TC の導入タイミング**（R2-1）: 本タスクで導入するのは **TC-22a（2 値 assertion）まで**。
> **TC-22b（matcher に `Edit`/`Write` が無い）は Task 3（todo T-04）のコミットで導入する**。
> T-01 の時点では matcher に `Edit|Write` が残っているため、ここで入れると **T-01〜T-03 の完了条件（スイート全体 GREEN）を満たせなくなる**。

**テストサンドボックス設計**（R-F13。**`scripts/` に stub を置かないための唯一の経路**）:

- bridge の hook 解決は `REPO_ROOT=$(cd "$(dirname $0)/../.." && pwd)` で **自身の位置から相対**に決まる（`eh-bridge.sh:25-26`）。
  したがって **bridge を `<sandbox>/.codex/hooks/eh-bridge.sh` へ複製すれば `REPO_ROOT` は `<sandbox>` になる**。
- 実 hook を使う TC（EH-1/2/3/6/9）は `scripts/hooks/*.sh` を **`<sandbox>/scripts/hooks/` へ複製**（読み取りのみ・実体は改変しない）。
- stub hook を使う TC（未知 rc / 無出力 block / stderr 汚染 / フォールバック）は **`<sandbox>/scripts/hooks/` または `<sandbox>/scripts/` に stub を置く**。
- **bridge 側に「hook ルートを差し替える環境変数」を新設しない**。新設すると *guard の解決先を実行時に上書きできる* 穴を作る（是正が新しい穴を作る典型）。
- サンドボックスは `mktemp -d` で作り、**末尾で明示削除**する（`register_cleanup` を使う。trap は張らない＝`tests/extras/README.md` の規約）。

**Completion Criteria**: `sh tests/run-tests.sh` が PASS（ta-65 が実際に実行されたことをテスト名の出力で確認）/ `.codex/` に差分が無い / `scripts/**` に差分が無い

**Rollback**: 追加ファイルを削除（`git rm tests/extras/ta-65-codex-bridge-io.sh` + fixtures）。**ランタイム影響なし**

### Task 1b（todo T-00）: 既存 `ta-15` の棚卸しと責務分界

**Purpose**: **同一対象を検査している既存テストが「Codex が拒否している設定」に対して緑を出し続けている**ことを解消する。

**背景（実測 / R-F04）**: `tests/extras/ta-15-codex-hook-bridge.sh` は本 plan の対象と**同じ 2 ファイル**を検査しているが、当初 plan に 1 度も登場していなかった。

| ta-15 の TC | 現行の判定 | 問題 |
|---|---|---|
| TC-03 `hooks.json is valid JSON`（`python3 -m json.tool`） | **PASS** | **JSON 構文は valid なので当然 PASS**。Codex の serde スキーマ拒否は検知しない（緑の誤シグナル） |
| TC-04 `wires all 5 PlanGate hooks`（`grep`） | **PASS** | **登録されていない**設定に対して「5 本配線済み」と報告する（#1078 が潰そうとしている誤りそのもの） |
| TC-05 / TC-06 / TC-07 | PASS | bridge の I/O 契約を **Task 2 で変える**ため、回帰の当たり判定になる |

**Files**: Modify `tests/extras/ta-15-codex-hook-bridge.sh`（**最小限**）

**Steps**:

- [ ] Step 1: ta-15 の 7 TC を実行して現行の PASS 内容を記録する（`evidence/verification/`）
- [ ] Step 2: 責務分界を決めて明記する — **ta-15 = ファイル存在・構文・配線の静的検査 / ta-65 = I/O 契約の振る舞い検査**
- [ ] Step 3: TC-03 の**表明を実態に合わせる**: 「JSON として valid」に加え **top-level キー集合**を検査する。
      🔴 **実装は TC-22a と同じ「stage 依存 2 値 assertion」に統一する**（`{description, hooks}` に一致 → `enabled` 分岐 /
      それ以外 → `disabled` 分岐で「未知キーが実在する＝ kill switch が効いている」を assert）。
      **どちらの分岐でも必ず 1 つ以上 assert する**。
      **2 値にすることで T-06 とのコミット同期が不要になる**（旧案の「同一コミットで有効化」は採らない。
      別タスク間のコミット同期は T-00 の `depends_on` を T-06 まで引き延ばし、依存グラフを壊すため＝ R2-6）
- [ ] Step 4: TC-04 の表明文言から「**wires**（配線済み）」の断定を外し、「hooks.json に 5 hook の**記述**がある」ことのみを述べる文言に直す

> **Task 2 実施後の ta-15 回帰確認（TC-05/06/07 が PASS のまま）は Task 2（todo T-02）のチェックポイントで行う**。
> 本タスクの完了条件に含めない（**T-00 は `depends_on: なし` であり、他タスクの完了を待つ要件を持たせない**＝ R2-6）。

**Completion Criteria**: ta-15 と ta-65 の責務が重複せず、**登録されていない状態で「配線済み」と読める表明が残っていない** /
**他タスクの完了を待たずに単独で GREEN になる**

**Rollback**: `git checkout -- tests/extras/ta-15-codex-hook-bridge.sh`

### Task 2（todo T-02）: bridge の I/O 契約修正（挙動は変わるが Codex には未到達）

**Purpose**: 入力・出力の両契約を直す。**注記キーが残っているため Codex ランタイムには一切影響しない**。

**Files**: Modify `.codex/hooks/eh-bridge.sh`, `tests/extras/ta-65-codex-bridge-io.sh`

**Steps**:

- [ ] Step 1: 期待値を修正後の契約（variant C 相当）に更新し、**RED** を確認する（現行 bridge で FAIL）
- [ ] Step 2: stdin を hook へ転送する（`INPUT` を hook の stdin へ流す）
- [ ] Step 3: hook の **stdout と stderr を別ファイルに分離**して捕捉する。
      一時ファイルは **`mktemp` で作る**（現行 `eh-bridge.sh:69` の `/tmp/eh-bridge-out.$$` は**予測可能な名前**であり、
      判定入力が第三者に先回りして作成・改変されうる。Step 3 でファイルが 2 本に増えるため必ず対処する）。
      作成した一時ファイルは **成功・失敗いずれの経路でも削除**する。
      🔴 **検証は `TMPDIR` に依存させない**: `darwin` の BSD `mktemp` は **`TMPDIR` を無視する**ことを実測済み
      （bare も `-t` も `/var/folders/.../T/` を返す）。**stub hook が `$PPID` から予測可能名の不在を観測する方式**を使う
      （設計と実測は `test-cases.md` の E-9 設計根拠を参照。**簡略化しない**）
- [ ] Step 4: **判定は stdout と exit code の 2 つで行う**（`"continue":false` / `permissionDecision:"deny"` → deny、`rc=2|1` → deny）。**stderr は判定に使わず reason 素材に限定**する
- [ ] Step 5: 未知 exit code を **deny** にする（fail-closed）。reason に rc を含める
- [ ] Step 6: hook 実体の解決を `scripts/hooks/<name>` → `scripts/<name>` の順にフォールバックさせる。どちらにも無ければ従来どおり deny
- [ ] Step 7: deny 時の reason が**常に非空**であることを保証する（空なら固定文言を埋める）
- [ ] Step 8: **`apply_patch` の複数ファイル patch を全件評価する**（下記 ❗）
- [ ] Step 9: **stdin の異常系の fail 方向を確定する**（下記「fail 方向の contract」）
- [ ] Step 10: **GREEN** を確認する（`sh tests/run-tests.sh` の全体実行）

❗ **複数ファイル `apply_patch` の取りこぼし（R-F15 / 実測）**: 現行の抽出は
`eh-bridge.sh:50` の **`re.search`** ＝ **先頭 1 件のみ**を返す。`apply_patch` は 1 コマンドで複数ファイルを扱えるため、
**「無害なファイルを 1 件目、HO パスを 2 件目」に並べるだけで guard を素通りできる**。
「登録されて効いている」状態でこれが残ると、**S-2 が有効化するのは穴の空いたガード**になる。

- 抽出を `re.findall` 相当（**全件**）へ変更する。
- **抽出した全パスについて hook を評価し、1 件でも deny なら deny**（reason に該当パスを含める）。
- 実装コストが許容外と判明した場合の**代替**: 「複数パスを含む `apply_patch` は **deny**（fail-closed）」でもよい。
  **allow に倒すことだけは選択しない**。どちらを採ったかを `decision-log.jsonl` に記録する。

**fail 方向の contract（R-F18・入力側と出力側の向きを揃える）**:

| 入力 | 判定 | 根拠 |
|---|---|---|
| stdin が**壊れた JSON**（構文エラー） | **deny**（fail-closed） | v8.19.0 の EH-13 が parse-unknown を block 扱いにした先例と同じ向き。**壊れた JSON はパスを隠せる**ため allow は危険 |
| stdin が **valid JSON だが object でない**（`null` / 配列 / 文字列 / 数値） | **deny**（fail-closed） | 上と同じ情報欠落側（R2-8）。**現行は `AttributeError` で python が rc=1 終了し、シェルの `2>/dev/null \|\| echo ""` により黙って「パス不明」レーンへ落ちている**（実測）。`isinstance(d, dict)` を明示判定し、偽なら診断つき deny にする（例外任せにしない） |
| stdin が**空** | **allow** | 評価対象のツール入力が存在しない（Codex 経由では起こらない）。ここを deny にすると **Codex 以外からの誤起動でセッションを壊す**副作用が勝る |
| `tool_input` にパスが無い（E-1） | **hook に委譲**（`PLANGATE_HOOK_FILE` 未設定で起動し hook の判定に従う） | bridge が独自に allow を返すのではなく、判定権を hook 側に残す |

> **この 3 行は「allow のままにする」判断を含むため、根拠を plan 本文に固定する**（レビューで再燃させない）。

**Completion Criteria**: `sh tests/run-tests.sh` GREEN / `.codex/hooks.json` 未変更 / `scripts/**` 未変更 / 一時ファイルが残らない /
**既存 `ta-15` の TC-05・TC-06・TC-07 が PASS のまま**（Task 1b から移した回帰確認＝ R2-6）

**Rollback**: `git checkout -- .codex/hooks/eh-bridge.sh`。**この時点では Codex ランタイムに影響が出ていない**ため無害

### Task 2b（todo T-03）: 変異注入によるテスト検出力の実証

**Purpose**: 新規テストが**実際に落ちること**を実証する（「空振り fixture」を排除する）。

**Steps**:

- [ ] Step 1: 変異 1 — **bridge の stdin 転送の call site を修正前へ戻す** → **EH-9 ケース（TC-01 / TC-02）が FAIL** することを確認
- [ ] Step 2: 変異 2 — **bridge の stdout 判定ブロックを削除する** → **EH-1 / EH-2 ケース（TC-04 / TC-17）が FAIL** することを確認
- [ ] Step 3: 変異 3 — **複数パス抽出を `re.search` に戻す** → **TC-19 が FAIL** することを確認
- [ ] Step 4: 変異 4a — **一時ファイル名を `/tmp/eh-bridge-out.$$` に戻す** → **E-9a が FAIL** することを確認（TC-23）
- [ ] Step 5: 変異 4b — **一時ファイルの `rm -f` を除去する** → **E-9b が FAIL** することを確認（TC-23）
- [ ] Step 6: 各変異を戻し、**GREEN** を再確認する

> **変異 4a / 4b は plan 作成時にサンドボックスで実測済み**（未修正 bridge に対し `predictable_present=YES` /
> `rm` 除去時に `/tmp/eh-bridge-out.<pid>` にマーカーが残存）。**この 2 つが kill できないなら E-9 は空振り**である。
>
> **変異は bridge の call site を壊す**（関数の中身ではなく呼び出し箇所）。**テスト側の期待値を書き換えて FAIL を作らない**。
> 変異が FAIL を起こさない TC は「空振り」であり、その TC は**乖離帯として handoff に記録**する。

**Completion Criteria**: **5 変異（1 / 2 / 3 / 4a / 4b）すべて**で**想定した TC が FAIL** / 復帰後に GREEN

**Rollback**: 変異は一時適用のみ。`git checkout -- .codex/hooks/eh-bridge.sh`

### Task 3（todo T-04）: matcher の死に文字列除去（**マッチを減らさない／ランタイム影響なし**）

**Purpose**: `apply_patch|Edit|Write` から Codex に存在しない `Edit` / `Write` を除く。

**Files**: Modify `.codex/hooks.json`

**Steps**:

- [ ] Step 1: matcher を `apply_patch` に変更する（`Bash` group は不変）
- [ ] Step 2: **同一コミットで TC-22b（matcher に `Edit`/`Write` が無い）を ta-65 に追加する**（R2-1。**本タスクが TC-22b の所有者**）
- [ ] Step 3: **注記キーが残っている**こと（top-level に未知キーがあり Codex に読まれない状態）を確認する
- [ ] Step 4: `hooks/list` が **依然として PlanGate hook 0 件・同一 warning** であることを確認する（＝有効化されていないことの確認）
- [ ] Step 5: `sh tests/run-tests.sh` 全体 GREEN を確認する

> ⚠️ **「挙動不変」という表現は使わない**（R2-9）。matcher を**リテラル完全一致**として解釈する semantics では、
> 現行の `apply_patch|Edit|Write` は**どのツール名にもマッチしない**。その場合、本変更は「不変」ではなく
> **0 → 1 の有効化**になる。正確には「**`apply_patch` へのマッチを減らさない / この時点ではランタイム影響なし**」
> （注記キーが残っているため未登録）。

**Completion Criteria**: `hooks/list` が依然として PlanGate hook **0 件**・同一 warning（＝有効化されていない）/ `.codex/hooks.json` の差分が matcher 1 箇所のみ

> ⚠️ **ここで matcher 文字列そのものは確認できない**（0 件登録なので `hooks/list` に matcher が現れない）。
> U-7 の観測は **Stage 3（todo T-06）以降**に回す。ただし U-7 は本タスクの gating 条件ではない（Unknowns §U-7 の再評価を参照）。

**Rollback**: `git checkout -- .codex/hooks.json`

### Task 4（todo H-01）: 有効化前ゲート（👤 Human 判断ポイント）

**Purpose**: 「登録されたが効かない」状態で止まらないことを、**有効化の前に**確認する。

**Steps**:

- [ ] Step 1: todo T-00〜T-04 が GREEN であることを提示する（`sh tests/run-tests.sh` の出力ごと）
- [ ] Step 2: Stage 3 で発生する deny の範囲（本 plan の実測表 + Task 1 で再現済みのログ）を提示する
- [ ] Step 3: `trusted_hash` の付与手順（編集後に hash が変わるため再 trust が要る）を提示する
- [ ] Step 4: **U-4 の未解決状態と、AC-07 が WARN に終わりうること**を明示して提示する
- [ ] Step 5: **AC-07 の実走 1 回（課金あり・`--dangerously-bypass-hook-trust` を付けない）の可否**について Human の判断を得る
- [ ] Step 6: 🚩 **チェックポイント**: Human の承認が得られるまで **todo T-06**（注記キー除去）に進まない

**Completion Criteria**: Human の可否判断が `status.md` に記録されている

**Rollback**: 不要（判断のみ）

### Task 5a（todo T-05）: `trusted_hash` 手順の確立

**Purpose**: 「編集 → 再 trust」の運用手順を文書化する（**適用そのものは Human-owned**）。

**Steps**:

- [ ] Step 1: `CODEX_HOME/config.toml` の `[hooks.state."<abs>/.codex/hooks.json:pre_tool_use:<i>:<j>"] trusted_hash` の書式を記す
- [ ] Step 2: **hash は hook 単位**（同一ファイル内の別 matcher group は個別）である点を明記する（evidence L74 実測）
- [ ] Step 3: **`trusted_hash` は `CODEX_HOME` ごとのローカル状態であり、リポジトリに乗らない**ことを明記する（下記 ❗）

❗ **配布境界（R-F17 / AC-09 に含める）**: `trusted_hash` は各利用者の `CODEX_HOME/config.toml` にあり、**git 管理下にない**。
したがって **main にマージした時点で、著者以外の全クローンは「hook は登録される / 発火するかは不明」状態に入る**。
**S-2 が強制力を保証できるのは `trusted_hash` を設定済みの環境に限られる**。これを doc（`settings-wiring-contract.md`）と handoff に**明記する**。
（未設定環境への自動配布・doctor 検査は **S-3 / S-4**。本 PBI では**限界の明示**までが scope）

**Completion Criteria**: 手順が再現可能な形で記述されている / 配布境界が doc に書かれている

**Rollback**: 不要（文書のみ）

### Task 5b（todo T-06）: 注記キー除去＝有効化（🔴 唯一の不可逆ステップ）

**Purpose**: `$schema_note` / `$note` を `description` に寄せ、hook を登録・発火させる。

**Files**: Modify `.codex/hooks.json`

**Steps**:

- [ ] Step 1: top-level を `description` / `hooks` の 2 キーのみにする
- [ ] Step 2: `hooks/list` で **登録件数 5・`warnings[]` 空・`enabled` true** を確認する（**前提条件 P-1 の確認であって成果ではない**）
- [ ] Step 3: `matcher` 文字列と件数を記録する（U-7 の観測。**gate ではない**）
- [ ] Step 4: `trustStatus` を確認し、`trusted` でなければ `trusted_hash` を付与して再確認する
- [ ] Step 5: Task 4（H-01）で承認された場合のみ、`codex exec` を **1 回**実行して block 証跡を取得する。
      **必須条件**: **`--dangerously-bypass-hook-trust` を付けない** / 非 `--ephemeral` / deny 対象を先 / 「ブロックされても retry しない」を prompt に明示
- [ ] Step 6: stderr に `Command blocked by PreToolUse hook:` が出ていること、**対象ファイルが生成されていないこと**の 2 点を証跡として保存する
- [ ] Step 7: **block が観測できなかった場合**は「AC-07 = WARN」として、以下を記録する（**PASS にしない・再走で bypass を付けない**）:
      (a) 使用したコマンドと `hooks/list` の `trustStatus` / (b) **U-4 が「否定」側に動いた**こと /
      (c) `trusted_hash` の実行時有効性の検証を **S-4 の前提**として申し送ること

> 🔴 **bypass 付きの block 観測を AC-07 の根拠にしてはならない**（R-F01）。
> `evidence/codex-exec-spike.md` の 3 回の実走で block が観測できたのは **すべて `--dangerously-bypass-hook-trust` 付き**であり、
> **bypass 無しで発火した観測は 1 件も存在しない**（L99 / L109 / L287）。
> bypass 付きの結果は「bridge の deny が Codex に正しく伝わる」ことの証明にはなるが、
> **「通常運用で強制力がある」ことの証明にはならない**。両者を混同した記述を handoff / doc に書かない。

**Completion Criteria**: AC-01〜AC-05・AC-10〜AC-12 が PASS / **前提条件 P-1 が充足** / AC-07 が PASS または **WARN（理由・代替・未充足リスクを記録）**

**Rollback**:

- **即時無効化**: `.codex/hooks.json` の **top-level に未知キーを 1 行足す**（例 `"$note"`）→ Codex が当該ファイルを受理しなくなり **PlanGate hook が全件未登録に戻る**（双方向に再現済み・決定論的）。
  **JSON 構文を壊す方法は使わない**（他ツールの誤動作を招くため。R-F08）
- **通常**: `git revert` で todo T-06 のコミットを戻す
- **緊急**: `PLANGATE_BYPASS_HOOK=1` を与えて全 hook を pass させる（既存の escape hatch）

### Task 6（todo T-07）: 責務分界の曖昧さ解消（doc）

**Purpose**: 「新規 hook 追加は AI-owned / 既存 hook 改変は Human-owned」の適用範囲をパス単位で一意にする。

**Files**: Modify `docs/ai/settings-wiring-contract.md`

**Steps**:

- [ ] Step 1: 責務分界節を**パス単位の表**に置き換える（下記「責務分界」節の内容）
- [ ] Step 2: 機械判定（`check-plan-hash.sh` の HO case 文に `.codex/**` が**無い**こと）と記述が一致していることを明記する
- [ ] Step 3: **軸 C（強制力）に S-2 の到達点と限界を書く**:
      (a) bridge 単体の deny は実証済み / (b) ランタイム block は AC-07 の結果に従う（WARN のときは「未実証」と書く）/
      (c) **`trusted_hash` 未設定環境では強制力を保証しない**（R-F17）/ (d) **TASK 文脈下の HO block は #1089 のため効かない**

**Completion Criteria**: `.codex/hooks/eh-bridge.sh` の改変責務が一意に読める / 上記 4 つの限界が doc に書かれている

**Rollback**: `git checkout -- docs/ai/settings-wiring-contract.md`

## Verification Plan

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence 保存先 |
|---|---|---|---|
| **スイート全体（必須）** | **`sh tests/run-tests.sh`** | **exit 0 かつ出力に `TA-65` が現れる**（= loader に拾われた証明） | `evidence/verification/` |
| Unit（bridge I/O） | `sh tests/extras/ta-65-codex-bridge-io.sh`（standalone 経路） | 共有 exit 契約どおり（0 / 1 / 2 / 3） | `evidence/verification/` |
| 既存テスト非回帰 | `sh tests/run-tests.sh` の `TA-15` セクション | Task 2 実施後も PASS | `evidence/verification/` |
| 変異注入 | Task 2b の **5 変異**（1 / 2 / 3 / 4a / 4b）を個別適用 | **想定した TC が FAIL** する | `evidence/verification/` |
| 登録状態（**前提条件 P-1**） | `codex app-server` の `hooks/list` | 5 件 / `warnings` 空 / `enabled` / `trustStatus` | `evidence/verification/` |
| ランタイム block | `codex exec` 1 回（Human 承認時のみ・**bypass フラグ無し**） | stderr に `Command blocked by PreToolUse hook:` / 対象ファイル不在 | `evidence/verification/` |
| 非回帰（Claude 側） | `git diff $(git merge-base HEAD origin/main) -- scripts/hooks .claude` | 差分 0 | `evidence/verification/` |
| Lint | `npx markdownlint-cli2 docs/working/TASK-1078/*.md` | 本 PBI 由来 0 件 | `evidence/verification/` |

> **非回帰 diff の基点（R-F14）**: `git diff origin/main` は **origin/main が進むたびに結果が変わる動く基点**であり、
> 無関係な他 PR の変更を「本 PBI の差分」として拾う。**`git merge-base HEAD origin/main` で固定した SHA を基点**にし、
> 使用した SHA を evidence に**併記**する（後から再現可能にする）。

**検証が実行不能な場合の扱い**:

> **検証が実行不能な場合**: AC-07（課金を伴う実走）が Human 判断で不可となったときは、理由・代替・未充足リスクを
> `handoff.md` と `settings-wiring-contract.md` に明記する。
>
> - **代替として使えるもの**: bridge 単体の deny（L-A）+ evidence 追記 2 の「**非空 reason の deny は `codex_core::tools::router` で block される**」
>   ＝ **「bridge が deny を返せば Codex は止める」ことの証明**。
> - **代替として使えないもの**: 同証跡を「**通常運用で hook が発火する**」ことの証明に流用すること。
>   当該 run は `--dangerously-bypass-hook-trust` 付きであり、**発火の前提条件は未証明のまま**である（U-4）。
> - この 2 つを分けて書く。混ぜた瞬間に #1078 が潰そうとしている誤りを再生産する。

### レビューレーン計画（#786）

| 成果物 | レーン | unavailable 時の代替 |
|---|---|---|
| `eh-bridge.sh` の I/O 契約 | 設計妥当性（契約の完全性・fail 方向）/ コードベース整合（`scripts/hooks/cursor-adapter.sh` 等の既存アダプタ慣行） | 単レーン時は実測 fixture で裏取り |
| 段階導入と rollback | 設計妥当性（不可逆点の位置・kill switch の実在性） | サンドボックスでの双方向再現 |

## Risks & Mitigations

| # | リスク | 緩和 |
|---|---|---|
| R-1 | 「登録された」を成果と誤認する | **登録は AC ではなく前提条件 P-1**（受入基準から外した）。AC-01（bridge deny）+ AC-07（ランタイム block）で担保 |
| R-2 | fail-closed 化で hook のエラーが全 deny に化ける | Task 5b の kill switch rollback を手順化。reason に rc を含めて原因を即特定可能にする |
| R-3 | stderr 由来の false deny | **判定を stdout と exit code に限定し stderr を除外**（AC-04・実測で再現済み） |
| R-4 | `PLANGATE_HOOK_TASK` 継承でテストが非決定的になる | テストで env を明示設定（AC-01/02 の前提） |
| R-5 | **U-4 が「bypass 無しでは発火しない」だった場合** | **AC-07 を WARN 固定にし、L-A（bridge 契約層）で S-2 を完了させる**。`trusted_hash` の実行時有効性検証は S-4 の前提として申し送る。`hooks/list` の `trusted` 表示を発火の証明として使わない |
| R-6 | Codex の matcher 仕様（U-7）で `apply_patch` 単独指定が効かない | **alternation の 1 項を残す変更のためマッチは減らない**（Unknowns §U-7）。Stage 3 で matcher と件数を観測し、異常なら Task 3 の Rollback |
| **R-7** | **`trusted_hash` は `CODEX_HOME` ごとのローカル状態**で git に乗らない。マージ後、著者以外の全クローンが「登録済み・発火不明」に入る | **S-2 の強制力保証範囲を「trusted 済み環境のみ」と doc に固定**（AC-09 / Task 5a Step 3）。全環境への展開は S-3 / S-4 |
| **R-8** | **`PLANGATE_HOOK_TASK` が設定された Codex セッションでは EH-3 の HO block が発火しない**（[#1089](https://github.com/s977043/plangate/issues/1089)。HO 判定が `if [ -z "$task_id" ]` の内側） | 本 PBI では**直さない**（`scripts/hooks/*.sh` = HO / Human-owned）。**限界として doc と handoff に明記**し、TC で現状挙動を固定する（TC-20） |
| **R-9** | **複数ファイル `apply_patch` で 2 件目以降のパスが検査されない**（`eh-bridge.sh:50` の `re.search`）。有効化と同時に「穴の空いたガード」を出荷する | Task 2 Step 8 で**全件抽出 + 1 件でも deny なら deny**。実装困難時は「複数パスは deny」の fail-closed 代替。**allow に倒さない**（TC-19 / AC-10） |
| **R-10** | 是正が新しい穴を作る（hook 解決先を env で差し替え可能にする等） | **bridge に解決先 override を新設しない**。テストは**サンドボックスへ bridge を複製**して `REPO_ROOT` を移す方式で行う（Task 1 の設計） |

## 責務分界（本 PBI の提案）

`docs/ai/settings-wiring-contract.md` の現行 3 行は、**2 行目（`.codex/**` は AI-owned）と 3 行目（既存 hook 改変は Human-owned）が
同一パスに二重適用されうる**ため一意に読めない。機械判定（`check-plan-hash.sh` の HO case 文）に `.codex/**` は**含まれない**
＝技術層は AI 改変を block していない。**記述を機械判定に合わせる**方向で以下に置き換えることを提案する。

| 対象 | 新規追加 | 既存改変 | 技術層の強制 |
|---|---|---|---|
| `scripts/hooks/*.sh` / `bin/plangate` / `.claude/settings*.json` / その他 HO 9 カテゴリ | Human-owned | **Human-owned** | EH-3 が常時 block |
| `.codex/hooks.json` / `.codex/hooks/*.sh` | AI-owned | **AI-owned** | 無し（HO 対象外） |

- ただし `.codex/hooks/*.sh` の**強制セマンティクスを変える改変**（本 PBI が該当）は、
  mode を **high-risk 以上に固定**し `lite_eligible=false` + **同期 C-3** を要求する（承認境界に準ずる扱い）。
- **本 PBI 自身がこの規約の最初の適用例**であり、Task 6 でその旨を記す。

## Mode 判定

**モード**: `high-risk`

**判定根拠**:

- 変更ファイル数: 7〜9（bridge / hooks.json / 新規テスト + fixtures / `ta-15` / `tests/extras/README.md` / doc 2 件）→ 高
- 受入基準数: **11**（AC-01〜05・07〜12。AC-06 は前提条件 P-1 へ移動して欠番）→ 高
- 変更種別: **code**（hook のロジック変更）→ doc-light 適用外
- リスク: 高（無効なガードを「有効」に見せる失敗モードが本 PBI の中心。fail-closed 化による全 deny のリスクもある）
- ロールバック: 計画的に必要（kill switch を明示設計）→ 高
- **承認境界周辺の判定**: `.codex/hooks/*.sh` は HO 9 カテゴリの**文言上は対象外**（`check-plan-hash.sh` L124-134 に `.codex` は無い）。
  しかし本 PBI は **HO 対象 hook（`scripts/hooks/*.sh`）の強制力そのものを左右する**。
  `mode-classification.md` の「自動推定の安全側」に従い **該当扱い**とし、**最低 high** を適用する。
- **最終判定**: `high-risk` / `lite_eligible=false` / **人間 C-3 必須**（autonomous APPROVE 不可）

## 段階導入の要約

> 🔴 **本表は可読化であり、実行順の正本は [`todo.md`](./todo.md) の各タスク定義の `depends_on`**（R2-5）。
> **本表と `depends_on` が食い違った場合も `depends_on` を正とする。**
> （旧版は本表が `G(Task 4) → 3a(Task 5a)` の順で、todo の `T-05 → H-01` と逆だった。
> 正しくは **T-05 が先**である — plan Task 4 Step 3 が「`trusted_hash` の付与手順を**提示する**」と定めており、
> 手順が存在しないとゲートの判断材料が揃わないため。以下は修正済みの順序。）

| Stage | plan Task | todo | Codex ランタイムへの影響 | rollback |
|---|---|---|---|---|
| 0 | Task 1 / 1b | T-01 / T-00 | **なし**（テスト追加・既存テスト是正のみ） | ファイル削除 / `git checkout` |
| 1 | Task 2 / 2b | T-02 / T-03 | **なし**（top-level 未知キーにより未読込＝未登録） | `git checkout` |
| 2 | Task 3 | T-04 | **なし**（同上。TC-22b を同一コミットで導入） | `git checkout` |
| 3a | Task 5a | **T-05** | なし（文書のみ） | 不要 |
| **G** | **Task 4** | **H-01** | — | 判断のみ（**T-05 の後**） |
| 3b | **Task 5b** | **T-06** | 🔴 **あり（唯一の有効化）** | **top-level に未知キーを 1 行足して全件無効化** / `git revert` / `PLANGATE_BYPASS_HOOK=1` |
| 4 | Task 6 | T-07 | なし（doc） | `git checkout` |

## 後続への申し送り（S-2 に含めない理由つき）

- **EH-13 / EH-12 の配線（S-7 候補）**: EH-13 の parsed-safe 集合は `{Bash, Edit, Write, MultiEdit}` で、
  **Codex の `apply_patch` は parse-unknown → `exit 2` → deny** になる。素直に配線すると `apply_patch` が全 deny する。
  解は 2 つ: (a) EH-13 の集合に `apply_patch` を足す（**HO パス改変＝Human-owned**）/ (b) bridge が `apply_patch` を
  `file_path` 付きの形へ**正規化**して渡す（AI-owned・HO 不変）。**(b) を推奨**するが、
  「アダプタが tool_name を書き換える」ことの是非は設計判断であり、S-2 のスコープでは決めない。
- **S-3**: `hooks/list` 検査の doctor / CI 組み込み。**本 PBI の前提条件 P-1 を恒常化するのは S-3 の役割**。
- **S-4**: `trusted_hash` 運用の自動化。**手順の確立は本 PBI の前提として実施**するが、自動化は S-4。
  **AC-07 が WARN で終わった場合は「`trusted_hash` が実行時発火に効くか」の検証も S-4 の前提**に加わる（U-4）。
- **[#1089](https://github.com/s977043/plangate/issues/1089)（別 PBI・本 PBI の scope 外）**: `PLANGATE_HOOK_TASK` 設定時に
  Hardening Override の block が発火しない。修正対象は `scripts/hooks/check-plan-hash.sh` ＝ **HO パス / Human-owned** のため S-2 では触らない。
  **S-2 完了後も「TASK 文脈下の HO 書き込み」は Codex 側で止まらない**（R-8）。混同しないこと。
- **`scripts/` フォールバック（本 PBI で実装するが到達しない経路）**: EH-13 / EH-12 を配線しないため、
  `scripts/hooks/` に無く `scripts/` にある hook は**当面存在しない**。本 PBI では **S-7 の前準備として実装し、stub で AC-12 として検証**する
  （実配線時に「解決できず全 deny」になる事故を先に潰す）。**実配線は S-7**。
- **`PLANGATE_HOOK_STRICT` の既定**: 現状 warning 既定であるため、EH-1 / EH-2 / EH-6 は本 PBI 完了後も
  **Codex 側で block しない**。「11 wiring 分の強制力が揃った」とは主張できない。この差は別 PBI で扱う。

## Plan Review Readiness

### Success Criteria

- **AC-01〜AC-05・AC-07〜AC-12**（[`pbi-input.md`](./pbi-input.md)。**AC-06 は前提条件 P-1 へ移動・欠番**）
  ↔ [`test-cases.md`](./test-cases.md) の **TC-01〜TC-23**（TC-22 は **TC-22a / TC-22b** に分割）
  - **AC 対応を持たない TC**: **TC-13**（前提条件 P-1 の確認手順）/ **TC-20**（#1089 の限界を現状固定・**あるべき挙動ではない**）
  - **エッジケース**: E-1〜E-10（**E-3'** / **E-9a・E-9b** を含む）
- Completion boundary（「S-2 の完了の定義」の再掲）:
  - **必達**: **bridge が deny すべき入力に deny を返す**ことを課金ゼロで実証（L-A）
  - **前提**: `hooks/list` の登録（P-1。成果として主張しない）
  - **PASS または WARN**: Codex ランタイムでの block（L-C / AC-07。**bypass フラグ無しでの観測に限る**）
- EH-13 / EH-12 の配線・STRICT 既定の変更・CI 組み込み・#1089 の修正は**別 PBI**

### Review Criteria

- Design alignment: #1078 Non-goals（Codex 側に独自 guard を新設しない）を守り、既存 `scripts/` guard を共用しているか
- Test expectations: 変異注入で FAIL することまで確認しているか（テストの検出力）
- Security: 承認境界の強制方向。fail-closed 化が**緩和ではなく強化**であること
- Maintainability: 判定チャネル（stdout / stderr / exit code）の責務が bridge 内で一意か
- Backward compatibility: `.claude` 側の hook 挙動が無傷（AC-08）+ **既存 `ta-15` が壊れていない**
- Operational risk: 有効化後の deny 範囲が実測表どおりに限定されること・kill switch が実在すること
- **Test reachability**: 新規テストが **loader に拾われる場所**にあり、`sh tests/run-tests.sh` で実際に走ったことを出力で示せるか
- **主張の強度**: 「登録」「trusted 表示」「bypass 付きの block」を**強制力の証明として使っていない**か

### Required Context

- Issue #1078（再定義コメント / 訂正コメント）/ Issue #1089（HO block の欠陥・**S-2 の scope 外**）
- `docs/ai/settings-wiring-contract.md` §Codex CLI parity（3 軸・bridge 欠陥表）
- `evidence/codex-exec-spike.md`（**本文 + 追記 1 + 追記 2**。とくに L91-114 / L284-287 の bypass 依存）
- PR #1088（`evidence/codex-payload-spike.md` の出所・**未マージ**・参考）
- `tests/run-tests.sh` L160-175（extras loader の glob）/ `tests/extras/README.md` / `tests/extras/_extra-contract.sh`
- `tests/extras/ta-15-codex-hook-bridge.sh`（**同一対象の既存テスト**）
- `.claude/rules/mode-classification.md`（HO 9 カテゴリ）/ `.claude/rules/responsibility-classes.md`
