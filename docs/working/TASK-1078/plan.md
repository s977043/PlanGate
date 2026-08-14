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

### 🔴 不可逆な有効化は「証拠の後」に置く（順序不変条件 / R3-F1）

> **旧版の構造欠陥**: `todo T-06`（注記キー除去＝ kill switch 撤去）が **AC-07 より前**にあり、
> AC-07 が WARN でも T-06 を巻き戻す要件が無かった。その結果、**計画どおり進めた既定の着地**が
> 「**11 AC PASS・`hooks/list` 5 件・warnings 空・スイート GREEN — 実効 block は 0**」になっていた。
> これは本 PBI が潰そうとしている「登録 ≠ 強制力」と**同型の終端状態**である。

**是正の核**: **L-C の証明を、実リポジトリの kill switch を撤去せずに取得する**。

- **AC-07 は「サンドボックス実走」で取得する**（`todo T-05b`）。
  サンドボックスは **実リポジトリの `eh-bridge.sh` と `scripts/hooks/*.sh` をそのまま複製**し、
  hooks.json は **T-06 適用後の目標形と同一内容**にする。**実リポジトリの `.codex/hooks.json` は一切変更しない**。
  この方式は既に実績がある（`evidence/codex-exec-spike.md` の 3 回の実走はすべて隔離サンドボックス）。
- **`todo T-06`（不可逆な有効化）の実行条件は「AC-07 が PASS」**。
- **AC-07 が WARN なら T-06 を実行しない**。kill switch を保持したまま **L-A のみで S-2 を閉じる**。
- **`H-01` は「実走の可否」と「有効化の可否」を分離して答えられない形にする**（片方だけの承認を成立させない）。

**順序不変条件（EIC: Evidence-before-Irreversible-Change）**:

```text
T-06（不可逆）を実行してよい ⇔ AC-07 が PASS（bypass 無しの block 証跡が存在する）
AC-07 が WARN → T-06 は実行しない → kill switch 保持 → Codex 側は「強制力なし（現状維持）」
```

### 「AC 全 PASS で実効 block 0」が構成できない理由

本 plan で到達しうる終端状態は次の 2 つだけであり、**どちらも「緑だが実効 0」にならない**:

| 終端 | AC-07 | T-06 | 実リポジトリでの発火観測 | `hooks/list` | doc に書く文言（**この文言以外を書かない**） |
|---|---|---|---|---|---|
| **終端 A1** | **PASS**（サンドボックス） | 実行 | **あり**（T-06b の確認実走） | 5 件 | 「**trusted 設定済み・上記 env 条件下で block する（実リポジトリで実測）**」 |
| **終端 A2** | **PASS**（サンドボックス） | 実行 | **なし**（Human が 2 回目を承認せず） | 5 件 | 🔴 「**trusted 設定済みかつ同一 env の環境で block する（サンドボックス実測）／実リポジトリでの発火は未観測**」 |
| **終端 B** | **WARN** | **実行しない** | — | **0 件**（kill switch 保持） | 「**Codex 側に強制力は無い（未有効化・現状維持）。U-4 は未解決**」 |

🔴 **終端 A2 の文言を短縮しない**（R4-F3）。`trusted_hash` は **per-`CODEX_HOME` で git に乗らない**（R-7）ため、
サンドボックスでの観測は**「別ディレクトリでの 1 回の観測」**である。これを「実リポジトリで block する」と書くと、
**前回 reject された終端とシグナルの見え方が同一**になる（根拠の置き換えにしかならない）。

- **終端 B では `hooks/list` が 0 件のまま**なので、「登録されているのに効かない」という誤認シグナルが**そもそも発生しない**。
- **完了条件で明示的に禁止する**: **「AC-07 が WARN かつ T-06 実行済み」は完了条件違反（FAIL）**とする。
  この 1 行により「AC 全 PASS ＋ 登録済み ＋ 実効 0」は**定義上構成不能**になる。
- 残る「登録されているが実効が薄い」懸念（EH-1/2/6 が STRICT 既定 warning で 0、EH-3 が #1089 で TASK 文脈では死ぬ、
  EH-9 は `NOCOMMIT=1` 限定）は **doc に「現時点で Codex 側が実際に止められるのは何か」を列挙して明記**する（AC-09）。
  **「11 wiring 分の強制力が揃った」とは書かない。**

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
     **その検証は S-4（`trusted_hash` 運用）の前提**として申し送る。
     🔴 **ただし「U-4 が否定に確定した」と書いてはならない**（R4-F3。**過剰主張**）。
     未発火の原因が「**手書き `[hooks.state]` の trust が実行時に効かない**」（evidence L109）だった場合、
     **実リポジトリでの非発火は含意されない**。正しくは「**サンドボックス条件下では未発火・U-4 は依然未解決**」。
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
| `tests/extras/ta-67-codex-bridge-io.sh` | create | fixture 駆動テスト（**フラット配置必須**・下記 ❗） | `tests/extras` 共有 exit 契約（`_extra-contract.sh`）に従う |
| `tests/extras/ta-15-codex-hook-bridge.sh` | modify | 既存の同一対象テストの棚卸し（Task 1b） | TC-03 を 2 値化 / TC-04 の「wires」断定を除去 |
| `tests/fixtures/codex-bridge/*.json` | create | 実 payload 形状 fixture | 既存慣行に一致（`FIXTURES_DIR="tests/fixtures"` / `tests/run-tests.sh:23`。`tests/extras/` 配下に fixture ディレクトリを新設しない） |
| `tests/extras/README.md` | modify | 一覧表に新規テストの行を追記（既存規約） | — |
| `docs/ai/settings-wiring-contract.md` | modify | 責務分界のパス単位明確化 + S-2 の限界明記 | — |
| `docs/working/TASK-1078/status.md` | modify | フェーズ履歴追記（**既存記述は改変しない**） | — |

❗ **テストをサブディレクトリに置いてはならない**（R-F03。当初案 `tests/extras/codex-bridge/run.sh` は**誤り**）:

- loader は `tests/run-tests.sh:165` の **`for extra in "$EXTRAS_DIR"/ta-*.sh`** ＝ **フラット glob**。
  サブディレクトリ配下のファイルは**永久に発見されず、CI で 1 度も実行されない**（＝静かに通る失敗）。
- extras は **実行されるのではなく `.` で source される**（`tests/run-tests.sh:169`）。
  よって独立した `run.sh` ではなく、**`pass` / `fail` カウンタを共有する `ta-NN-*.sh`** として書く。
- 命名は `ta-NN-<short-name>.sh`（`tests/extras/README.md:7`）。
- 🔴 **番号は契約値ではない。exec 開始時に必ず実測してから決める**（R3-F5）:

  ```sh
  git fetch origin main && git ls-tree --name-only origin/main tests/extras/
  ```

  - **本 plan 作成時（2026-08-14）の実測**: `ta-65-eh3-ho-task-context.sh`（#1089）と
    `ta-66-codex-plugin-manifest.sh`（#1090）が **`origin/main`（`0559781`）に既に存在**する。**次の空きは `ta-67`**。
  - ⚠️ **前版は「最大は ta-64 なので ta-65」と書いていたが、その後 main が進んで stale 化した**。
    **exec 時点でさらに進んでいる可能性があるため、上記コマンドの結果を正とする**（本文の `ta-67` は暫定値）。
- `pg_extra_contract_init "ta-<NN>" <standalone-capable|harness-only>` を先頭で呼び、共有 exit 契約に載せる（#921 / `ta-61` 参照）。

🔴 **到達性 assertion は「番号」ではなく「一意な識別子文字列」に対して行う**（R3-F5）:

- 旧版は「`sh tests/run-tests.sh` の出力に **`TA-65`** が現れること」を到達性の証明にしていたが、
  **`ta-65-eh3-ho-task-context.sh` が `=== TA-65: EH-3 Hardening Override × TASK 文脈 (#1089) ===` を出力する**ため、
  **新規テストが未配置・誤配置でも assertion が真になる**（自らが封じたはずの穴が別経路で再び開いていた）。
  さらに証跡・失敗ログ上で `TA-65` が **2 つの別物**を指してしまう。
- **是正**: テスト本体に **番号を含まない一意なマーカー文字列**を出力させ、それを検索する。

  ```text
  出力するマーカー（例）: PG_TA_CODEX_BRIDGE_IO_V1
  到達性の検証        : sh tests/run-tests.sh の出力に PG_TA_CODEX_BRIDGE_IO_V1 が現れること
  ```

- マーカーは **リポジトリ全体で一意**であること（導入時に `grep -r` で衝突が無いことを確認する）。
- **番号（`TA-67` 等）は表示上のラベルとしてのみ使い、機械判定には使わない**。
- **fixture は `tests/fixtures/codex-bridge/` に置く**（既存 12 ディレクトリと同じ慣行。`FIXTURES_DIR` = `tests/fixtures`）。
  harness 経由では `$FIXTURES_DIR` で参照でき、standalone 実行を残す場合はスクリプト位置からの相対で解決する
  （解決できないなら `pg_extra_contract_init "ta-<NN>" harness-only` を宣言して standalone 経路を持たない）。

## Work Breakdown

> **plan Task ↔ todo T-NN 対応表**（R-F02。**番号が別体系なので必ずこの表で読み替える**）:
>
> | plan | todo | 内容 | 不可逆性 |
> |---|---|---|---|
> | Task 1 | **T-01** | fixture + baseline テスト（新規 extras・番号は実測） | 可逆 |
> | Task 1b | **T-00** | 既存 `ta-15` の棚卸しと責務分界 | 可逆 |
> | Task 2 | **T-02** | bridge の I/O 契約修正 | 可逆（Codex 未到達） |
> | Task 2b | **T-03** | 変異注入によるテスト検出力の実証 | 可逆 |
> | Task 3 | **T-04** | **matcher の死に文字列除去**（`Edit`/`Write`） | 可逆 |
> | Task 4 | **H-01** | 👤 有効化前ゲート（Human 判断） | — |
> | Task 5a | **T-05** | `trusted_hash` 手順の確立 + hash 範囲の実測 | 可逆（文書のみ） |
> | Task 5a-2 | **T-05b** | **サンドボックス実走で AC-07 を確定** | 可逆（実リポジトリ無変更） |
> | Task 5b | **T-06** | **注記キー除去＝有効化**（**AC-07 PASS 時のみ**） | 🔴 **唯一の不可逆ステップ** |
> | Task 5c | **T-06b** | 実リポジトリでの確認実走（**2 回目・承認時のみ**） | 可逆（観測のみ） |
> | Task 6 | **T-07** | 責務分界 doc の是正 | 可逆 |
> | — | T-08 / T-09 | 非回帰の証明 / status・handoff | 可逆 |
>
> ⚠️ **番号の衝突に注意**: 「plan Task 4」は **Human ゲート**、「todo T-04」は **matcher 除去**であり、**別物**。
> 本文中では常に **`plan Task N` / `todo T-NN` と接頭辞つきで書く**。**不可逆ステップは `todo T-06`（= plan Task 5b）だけ**である。

### Task 1（todo T-01）: fixture と baseline テストの導入（挙動不変）

**Purpose**: 実 payload 形状の fixture を固定し、**現行 bridge の挙動をテストで固定**する。以後の変更差分を機械的に可視化する。

**Files**: Create `tests/extras/ta-67-codex-bridge-io.sh`, `tests/fixtures/codex-bridge/*.json`

**Steps**:

- [ ] Step 1: 実測済み payload 形状（`hook_event_name` / `tool_name` ∈ {`apply_patch`, `Bash`} / `tool_input` / `cwd` / `permission_mode` / `tool_use_id`。実物は `evidence/codex-exec-spike.md` 追記 1 L189-196 / 追記 2 L292-298）で fixture を作成する
- [ ] Step 2: **テスト用サンドボックスの構造を確定する**（下記「テストサンドボックス設計」）。bridge は `scripts/**` を改変せずに検証できなければならない
- [ ] Step 3: テストが bridge を呼び、`permissionDecision` を抽出して期待値と突合する。**`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_STRICT` / `PLANGATE_DELEGATION_NOCOMMIT` を必ず明示設定**する（継承禁止 / `env -u` で明示 unset）
- [ ] Step 4: bridge 呼び出しは必ず **stdin を明示的に与える**（`printf '%s' "$payload" | ...`）。stdin 無しで呼ぶと `INPUT=$(cat)` がハングしうる
- [ ] Step 5: 期待値は**転記ではなく実行結果で確定**し、本 plan「前提の実測検証」表との差分があれば **plan 側を訂正**する
- [ ] Step 6: **`tests/extras/README.md` の一覧表に新規テストの行を追記する**（既存規約。README は Files 表に挙がっているが Step が無かった＝ R2-4）
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

**Completion Criteria**: `sh tests/run-tests.sh` が PASS **かつ出力に一意マーカー `PG_TA_CODEX_BRIDGE_IO_V1` が現れる**
（＝ loader に拾われた証明。**番号で判定しない**）/ `.codex/` に差分が無い / `scripts/**` に差分が無い

**Rollback**: 追加ファイルを削除（`git rm tests/extras/ta-67-codex-bridge-io.sh` + fixtures）。**ランタイム影響なし**

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
- [ ] Step 2: 責務分界を決めて明記する — **ta-15 = ファイル存在・構文・配線の静的検査 / 新規 extras = I/O 契約の振る舞い検査**
- [ ] Step 3: TC-03 の**表明を実態に合わせる**: 「JSON として valid」に加え **top-level キー集合**を検査する。
      🔴 **実装は TC-22a と同じ「stage 依存 2 値 assertion」に統一する**（`{description, hooks}` に一致 → `enabled` 分岐 /
      それ以外 → `disabled` 分岐で「未知キーが実在する＝ kill switch が効いている」を assert）。
      **どちらの分岐でも必ず 1 つ以上 assert する**。
      **2 値にすることで T-06 とのコミット同期が不要になる**（旧案の「同一コミットで有効化」は採らない。
      別タスク間のコミット同期は T-00 の `depends_on` を T-06 まで引き延ばし、依存グラフを壊すため＝ R2-6）
- [ ] Step 4: TC-04 の表明文言から「**wires**（配線済み）」の断定を外し、「hooks.json に 5 hook の**記述**がある」ことのみを述べる文言に直す

> **Task 2 実施後の ta-15 回帰確認（TC-05/06/07 が PASS のまま）は Task 2（todo T-02）のチェックポイントで行う**。
> 本タスクの完了条件に含めない（**T-00 は `depends_on: なし` であり、他タスクの完了を待つ要件を持たせない**＝ R2-6）。

**Completion Criteria**: ta-15 と新規 extras の責務が重複せず、**登録されていない状態で「配線済み」と読める表明が残っていない** /
**他タスクの完了を待たずに単独で GREEN になる**

**Rollback**: `git checkout -- tests/extras/ta-15-codex-hook-bridge.sh`

### Task 2（todo T-02）: bridge の I/O 契約修正（挙動は変わるが Codex には未到達）

**Purpose**: 入力・出力の両契約を直す。**注記キーが残っているため Codex ランタイムには一切影響しない**。

**Files**: Modify `.codex/hooks/eh-bridge.sh`, `tests/extras/ta-67-codex-bridge-io.sh`

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
- [ ] Step 7b: 🔴 **bridge の出力を「必ず valid JSON になる方法」で生成する**（R3-F2。下記 ❗）
- [ ] Step 7c: 🔴 **`PLANGATE_HOOK_FILE` を毎回明示的に確定させる**（R3-F7b。下記 ❗❗）
- [ ] Step 8: **`apply_patch` の複数ファイル patch を全件評価する**（下記 ❗）
- [ ] Step 9: **stdin の異常系の fail 方向を確定する**（下記「fail 方向の contract」）
- [ ] Step 10: **GREEN** を確認する（`sh tests/run-tests.sh` の全体実行）

❗ **deny の reason が JSON エスケープされていない（R3-F2 / 実測）**

現行の生成経路は**文字列連結**であり、**有効化と同時に穴が出荷される**:

```sh
eh-bridge.sh:75  reason=$(tail -n 5 … | tr '\n' ' ' | tr '"' "'" | head -c 400)
eh-bridge.sh:84  printf '…"permissionDecisionReason":"PlanGate %s blocked: %s"…' "$HOOK_NAME" "$reason"
```

| 欠陥 | 内容 |
|---|---|
| **エスケープ不足** | サニタイズは **`"` → `'` のみ**。**バックスラッシュ・制御文字は素通り**し、JSON を壊す |
| **バイト単位の切り詰め** | `head -c 400` は**バイト単位**。hook の reason は**日本語**（例: `HARDENING_OVERRIDE: … は maintenance 窓内でも常時 block`）なので、**UTF-8 の途中で切れて不正バイト列**になりうる |
| **入力の由来** | reason 素材には **agent が影響できる文字列**が入る（`check-c3-approval.sh` の `$c3_file` は `PLANGATE_HOOK_TASK` 由来。検証は `case "$task_id" in TASK-*)` だけ） |
| **新契約で悪化** | 修正後は reason 素材が hook の **stdout JSON**（`{"continue":false,"stopReason":"…"}`）そのものになるため、**`\` の出現確率が上がる** |

**帰結**: bridge が不正 JSON を出す → Codex が decision を読めない → **既知の「空 reason の fail-open」と同種の、黙った allow**。
**現状 AC-05 は「非空」しか要求しておらず、JSON として valid かを誰も検査していない。**

**是正（すべて必須）**:

- (a) **reason を文字列連結で埋め込まない**。`python3 -c 'import json,sys; print(json.dumps(...))'` 等で
  **出力 JSON 全体をシリアライザに生成させる**（`printf` によるテンプレート組み立てをやめる）
- (a-2) 🔴 **シリアライザ失敗時の fail 方向を決める**（R4-F5。下記 ❗❗❗。**未規定のままにしない**）
- (b) **切り詰めは文字境界を守る**（バイト単位で切らない。例: python 側で文字数指定）
- (c) **全 deny TC の assertion に「bridge の stdout が `json.loads` できること」を追加**する
- (d) **変異 5: reason 素材に `\` と制御文字を注入する stub hook** を変異注入セットへ（下記 Task 2b）

❗❗❗ **シリアライザ化が作りうる「新しい全 allow 経路」（R4-F5）**

現行 bridge は python3 を**パス抽出にのみ**使い、失敗時は `2>/dev/null || echo ""` で「パス不明レーン」に落ちる（＝ **hook は動く**）。
ここに「出力 JSON 全体を python3 で生成する」設計を素朴に入れると、**python3 が無い / 失敗する環境では deny の出力そのものが消える**
→ **stdout 空 → decision 不明 → 既知の「空 reason の fail-open」と同種の、黙った allow が全 hook・全ケースで発生**する。

**却下した 2 案**:

| 案 | 却下理由 |
|---|---|
| **fail-closed（生成失敗 → 全 deny）** | python3 不在で **Codex が使用不能**になる（SC-1 相当の実害） |
| **`printf` テンプレートを fallback に残す** | **それがそのまま R-12（非エスケープ）の穴の再導入**になる |

🔴 **採用: 「補間しない静的リテラル」への退避**（どちらの穴も作らない第 3 の道）

- 生成器（python3）が **rc≠0 または空出力**だった場合、**あらかじめ用意した固定文字列**を出力する:
  - **判定が deny のとき**: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"PlanGate blocked (reason unavailable: serializer failed)"}}`
  - **判定が allow のとき**: 既存の allow リテラル
- **要点**: この退避経路は **reason を一切補間しない**ため、
  - **R-12 の穴を再導入しない**（外部文字列が JSON に入らない）
  - **decision は保存される**（deny は deny のまま＝ fail-closed 側）
  - **全 deny にならない**（allow 判定は allow のまま出る）
- **リテラルは実装時に `json.loads` で妥当性を確認**し、テストにも同じ文字列を固定値として持たせる。

**TC を 1 件追加（TC-25）**: `python3` を PATH から外した状態（または生成コマンドを強制的に rc≠0 にした状態）で、
**deny ケースが valid JSON の deny を返し、allow ケースが allow を返す**ことを検査する。
**変異 5 は「シリアライザを文字列連結に戻す」だけで、生成器が落ちる経路を kill しない**ため、
**変異 6（生成器を強制失敗させる）**を別途置く。

❗❗ **`PLANGATE_HOOK_FILE` の unset 漏れ（R3-F7b / 実測）**

`eh-bridge.sh:55-65` は `FILE_PATH` が空のとき **export しないだけ**で、**既存の env をクリアしない**。
Codex セッションが `PLANGATE_HOOK_FILE` を持っていると、**パスを抽出できなかった呼び出しで
「セッションが持つ古いパス」を対象に hook が判定する**（誤 allow / 誤 deny の両方向）。
`PLANGATE_HOOK_TASK` についても同様の継承問題を R-4 で認識していたが、**テストの問題としてしか扱っていなかった**。

**是正**: bridge は毎回 **`PLANGATE_HOOK_FILE` を「抽出値で export」または「明示的に unset」**する（中間状態を残さない）。
`PLANGATE_HOOK_TASK` の自動導出（`:57-64`）も同じ規律にする。**TC を 1 件追加**（E-11）。

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
- [ ] Step 6: 変異 5 — **reason のシリアライザ生成を文字列連結に戻す** →
      **`\` / 制御文字を出す stub hook のケース（TC-24）が FAIL** することを確認（R3-F2）
- [ ] Step 7: 変異 6 — **静的リテラルへの退避経路を削る**（生成器失敗時に空出力にする）→
      **TC-25 の deny ケースが FAIL** することを確認（R4-F5。**変異 5 ではこの経路を kill できない**）
- [ ] Step 8: 変異 7 — **hook 解決の探索順を入れ替える**（`scripts/` を `scripts/hooks/` より先にする）→
      **E-4 / AC-12 のケースが FAIL** することを確認（Model A 残指摘。**AC-12 に変異が 1 本も割り当てられていなかった**）
- [ ] Step 9: 各変異を戻し、**GREEN** を再確認する

> **変異 4a / 4b は plan 作成時にサンドボックスで実測済み**（未修正 bridge に対し `predictable_present=YES` /
> `rm` 除去時に `/tmp/eh-bridge-out.<pid>` にマーカーが残存）。**この 2 つが kill できないなら E-9 は空振り**である。
>
> **変異は bridge の call site を壊す**（関数の中身ではなく呼び出し箇所）。**テスト側の期待値を書き換えて FAIL を作らない**。
> 変異が FAIL を起こさない TC は「空振り」であり、その TC は**乖離帯として handoff に記録**する。

**Completion Criteria**: **8 変異（1 / 2 / 3 / 4a / 4b / 5 / 6 / 7）すべて**で**想定した TC が FAIL** / 復帰後に GREEN

**Rollback**: 変異は一時適用のみ。`git checkout -- .codex/hooks/eh-bridge.sh`

### Task 3（todo T-04）: matcher の死に文字列除去（**マッチを減らさない／ランタイム影響なし**）

**Purpose**: `apply_patch|Edit|Write` から Codex に存在しない `Edit` / `Write` を除く。

**Files**: Modify `.codex/hooks.json`

**Steps**:

- [ ] Step 1: matcher を `apply_patch` に変更する（`Bash` group は不変）
- [ ] Step 2: **同一コミットで TC-22b（matcher に `Edit`/`Write` が無い）を新規 extras に追加する**（R2-1。**本タスクが TC-22b の所有者**）
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
- [ ] Step 5: **TC-18（EH-6 の deny）が課金ゼロで再現できたか**を提示する。
      再現できていない場合は「**配線 5 本のうち 1 本は deny 経路が未検証のまま有効化することになる**」旨を判断材料に含める（Model A 補足）
- [ ] Step 6: 🔴 **一体の設問として**可否を得る（**分割して答えられない形にする** / R3-F1）
- [ ] Step 7: 🚩 **チェックポイント**: 上記の一体承認が得られるまで **`todo T-05b` にも `todo T-06` にも進まない**

**H-01 の設問（この形で 1 回だけ問う）**:

> **「サンドボックス実走 1 回（課金あり・bypass 無し）を許可し、その結果が PASS だった場合に限り
> `.codex/hooks.json` の注記キー除去（不可逆な有効化）まで進めてよいか？」**
>
> - **Yes** → `todo T-05b` を実行 →（AC-07 = PASS のときのみ）`todo T-06`
> - **No** → **実走も有効化も行わない**。AC-07 = WARN で終端 B に着地させる
>
> 🔴 **「有効化は可・実走は不可」という承認を成立させない**（R3-F1）。
> それを許すと **証拠ゼロのまま不可逆な有効化だけが実行される**（旧版で成立していた最悪経路）。
> 逆の「実走は可・有効化は不可」は**許される**（AC-07 を確定させて終端 B に着地する選択であり、安全側）。

**Completion Criteria**: Human の可否判断が `status.md` に記録されている

**Rollback**: 不要（判断のみ）

### Task 5a（todo T-05）: `trusted_hash` 手順の確立

**Purpose**: 「編集 → 再 trust」の運用手順を文書化する（**適用そのものは Human-owned**）。

**Steps**:

- [ ] Step 1: `CODEX_HOME/config.toml` の `[hooks.state."<abs>/.codex/hooks.json:pre_tool_use:<i>:<j>"] trusted_hash` の書式を記す
- [ ] Step 2: **hash は hook 単位**（同一ファイル内の別 matcher group は個別）である点を明記する（evidence L74 実測）
- [ ] Step 3: **`trusted_hash` は `CODEX_HOME` ごとのローカル状態であり、リポジトリに乗らない**ことを明記する（下記 ❗）
- [ ] Step 4: 🔴 **`trusted_hash` の対象範囲を実測する**（R3-F4。**書式を書き写すだけで終わらせない**）:
      1. サンドボックスで hook を `trusted` にする
      2. **`.codex/hooks.json` を変更せず `.codex/hooks/eh-bridge.sh` の内容だけを 1 行変更**する
      3. `hooks/list` を再取得し、`trustStatus` が `trusted` のままか `untrusted` に落ちるかを観測する
- [ ] Step 5: 結果を doc に反映する
      - **`untrusted` に落ちる** → bridge 内容も hash 対象。**再 trust プロンプトが AI 改変の検出層になる**
      - **`trusted` のまま** → 🔴 **bridge 内容は hash 対象外**。すなわち
        **trusted 済み環境では、AI が `eh-bridge.sh` を 1 行書き換えるだけで、再 trust も HO block も無しに
        Codex 側の全強制力を無効化できる**。これを**限界として doc に明記**する（AC-09）

❗ **なぜ実測が要るか（R3-F4）**: `trusted_hash` の鍵は
`…/.codex/hooks.json:pre_tool_use:<i>:<j>` 単位で、指しているのは hooks.json の **`command` 文字列**である
（実測: `command` は `sh "$(git rev-parse --show-toplevel)/.codex/hooks/eh-bridge.sh" <hook>.sh`）。
**bridge スクリプトの内容が hash に含まれるかは、どの証跡にも書かれていない**。
一方 `todo T-06` 以後、この bridge は**強制力の実体そのもの**であり、Task 6（AC-09）は
「`.codex/hooks/*.sh` は既存改変も **AI-owned**・技術層の強制なし」と確定させる。
**この 2 つが同時に成り立つと、AI が単独で強制力を消せる経路が残る**。実測して doc に書く。

❗ **配布境界（R-F17 / AC-09 に含める）**: `trusted_hash` は各利用者の `CODEX_HOME/config.toml` にあり、**git 管理下にない**。
したがって **main にマージした時点で、著者以外の全クローンは「hook は登録される / 発火するかは不明」状態に入る**。
**S-2 が強制力を保証できるのは `trusted_hash` を設定済みの環境に限られる**。これを doc（`settings-wiring-contract.md`）と handoff に**明記する**。
（未設定環境への自動配布・doctor 検査は **S-3 / S-4**。本 PBI では**限界の明示**までが scope）

**Completion Criteria**: 手順が再現可能な形で記述されている / 配布境界が doc に書かれている

**Rollback**: 不要（文書のみ）

### Task 5a-2（todo T-05b）: 🔴 サンドボックス実走で AC-07 を確定（**不可逆ステップの前**）

**Purpose**: **実リポジトリの kill switch を撤去せずに L-C（ランタイム発火）を確定する**。
これが `todo T-06` の実行可否を決める唯一の判断材料になる（EIC 不変条件）。

**Files**: なし（サンドボックスは `mktemp -d` / 実リポジトリは読み取りのみ）

**Steps**:

- [ ] Step 1: `mktemp -d` に **git init 済みサンドボックス**を作り、隔離 `CODEX_HOME` を用意する（既存 spike と同方式）
- [ ] Step 2: **実リポジトリの `.codex/hooks/eh-bridge.sh`（T-02 修正後）と `scripts/hooks/*.sh` をそのまま複製**する（改変しない）
- [ ] Step 3: サンドボックスの `.codex/hooks.json` を **`todo T-06` 適用後の目標形と同一内容**にする。
      🔴 **手で書き起こさず、後述の「導出変換」で機械的に生成し、`diff` が空であることを assertion にする**（R4-F2）
- [ ] Step 4: `hooks/list` で 5 件・`warnings[]` 空・`trustStatus` を確認し、`trusted_hash` を付与する
- [ ] Step 5: **`codex exec` を 1 回**実行する。🔴 **`--dangerously-bypass-hook-trust` を付けない** /
      非 `--ephemeral` / deny 対象を先 / 「ブロックされても retry しない」を prompt に明示
- [ ] Step 6: 判定する
      - **block を観測 → AC-07 = PASS**（`todo T-06` に進んでよい）
      - **block を観測できない → AC-07 = WARN**（🔴 **`todo T-06` に進まない**。**bypass を付けて再走しない**）
- [ ] Step 7: いずれの場合も証跡（コマンド全文 / `hooks/list` の `trustStatus` / stderr / `--json` / ファイル実在）を
      `evidence/verification/` に保存する

**Completion Criteria**: AC-07 が **PASS または WARN** として確定し、**その判定が `todo T-06` の実行可否として `status.md` に記録されている**

**Rollback**: サンドボックスを削除するだけ（**実リポジトリは無変更**）

❗ **導出変換の定義と、同値性を検証する機械（R4-F2）**

**旧版の誤り 2 点**（どちらも実測で確認済み）:

1. **「未知キーを除去する変換だけ」では目標形にならない**。実測:

   ```text
   実 .codex/hooks.json の top-level : ['$schema_note', '$note', 'hooks']
   除去のみの結果                    : ['hooks']          ← description が無い
   ```

   `todo T-06` の目標は **`description` に注記内容を寄せる**ことなので、変換は
   **「未知キー（`$` 始まり）を除去し、その内容を `description` に統合する」**でなければならない。
2. **同値性を検証する機械が存在しなかった**。**TC-22a / TC-22b は実リポジトリの `.codex/hooks.json` しか読まず、
   サンドボックス生成物と突合しない**（実測: TC-22a 節にサンドボックスへの言及は **0 件**）。
   これでは「同一内容にする」が**運用の心がけ**にとどまる。

**是正**:

- **導出を成果物（スクリプト）にする**。入力 = 実リポジトリの `.codex/hooks.json` / 出力 = 有効化後の目標形。
  変換規則は **(i) `$` 始まりの top-level キーを除去 (ii) その内容を `description` に統合 (iii) `hooks` は無改変**。
- **`diff <(導出結果) <sandbox>/.codex/hooks.json` が空であることを T-05b の assertion にする**（evidence 添付ではなく**合否判定**）。
- **`todo T-06` は同じ導出スクリプトの出力で `.codex/hooks.json` を置き換える**（手編集しない）。
  これにより「サンドボックスで検証した形」と「実リポジトリに入る形」が**同一の生成物**になる。

> **なぜサンドボックスで足りるか**: 実リポジトリとの差分は「hooks.json の内容」と「trust エントリのパス」だけであり、
> 前者は **上記の導出 + `diff` assertion** と **TC-22a / TC-22b** で担保し、後者は **どの環境でも個別に必要**（R-7 として doc 明記済み）。
> bridge と hook 本体は**同一ファイルを複製**しているため、L-C の成立条件は移送できる。
> 🔴 **ただし移送できるのは PASS 方向のみ**（Model A 指摘 / R4-F3）。WARN は実リポジトリでの非発火を含意しない。
>
> **なぜ実リポジトリで先に有効化しないか**: 有効化は**不可逆**（kill switch の撤去）であり、
> AC-07 が WARN に終わった場合に「登録済み・実効 0」という**本 PBI が潰そうとしている状態そのもの**を作るため。

### Task 5b（todo T-06）: 注記キー除去＝有効化（🔴 唯一の不可逆ステップ / **AC-07 PASS が前提**）

**Purpose**: `$schema_note` / `$note` を `description` に寄せ、hook を登録・発火させる。

**Files**: Modify `.codex/hooks.json`

**Steps**:

- [ ] Step 0: 🔴 **ゲート**: **`todo T-05b` で AC-07 が PASS** かつ **`H-01` の承認済み**であることを確認する。
      **どちらか一方でも欠けていれば本タスクを実行しない**（EIC 不変条件）
- [ ] Step 1: top-level を `description` / `hooks` の 2 キーのみにする
- [ ] Step 2: **同一コミットで TC-22a の宣言 stage を `disabled` → `enabled` に更新する**（R3-F3。下記 ❗）
- [ ] Step 3: `hooks/list` で **登録件数 5・`warnings[]` 空・`enabled` true** を確認する（**前提条件 P-1 の確認であって成果ではない**）
- [ ] Step 4: `matcher` 文字列と件数を記録する（U-7 の観測。**gate ではない**）
- [ ] Step 5: `trustStatus` を確認し、`trusted` でなければ `trusted_hash` を付与して再確認する
- [ ] Step 6: `sh tests/run-tests.sh` 全体 GREEN を確認する（TC-22a が `enabled` 分岐で PASS すること）

❗ **宣言 stage（`PG_EXPECTED_STAGE`）の更新は本タスクの一部**である。更新を忘れるとスイートが RED になるため、
**「有効化したのに宣言を直し忘れる」ことが機械的に検出される**（＝ 宣言と実体の drift 検出。R3-F3）。

> 🔴 **bypass 付きの block 観測を AC-07 の根拠にしてはならない**（R-F01）。
> `evidence/codex-exec-spike.md` の 3 回の実走で block が観測できたのは **すべて `--dangerously-bypass-hook-trust` 付き**であり、
> **bypass 無しで発火した観測は 1 件も存在しない**（L99 / L109 / L287）。
> bypass 付きの結果は「bridge の deny が Codex に正しく伝わる」ことの証明にはなるが、
> **「通常運用で強制力がある」ことの証明にはならない**。両者を混同した記述を handoff / doc に書かない。

**Completion Criteria**: **AC-07 が PASS である**（WARN のまま本タスクを完了させることはできない）/
AC-01〜AC-05・AC-10〜AC-12 が PASS / **前提条件 P-1 が充足** / 宣言 stage が `enabled` に更新済み

**本タスクを実行しない場合（AC-07 = WARN）の終端処理**:

- `.codex/hooks.json` は **注記キーを保持したまま**（kill switch 継続）。宣言 stage は `disabled` のまま。
- **完了条件は「AC-01〜05・08〜12 が PASS ＋ AC-07 が WARN ＋ T-06 未実行」で満たされる**（これが終端 B）。
- doc（AC-09）と handoff に「**Codex 側の強制力は未有効化（現状維持）。理由は U-4 未解決**」と明記する。

**Rollback**:

- **即時無効化**: `.codex/hooks.json` の **top-level に未知キーを 1 行足す**（例 `"$note"`）→ Codex が当該ファイルを受理しなくなり **PlanGate hook が全件未登録に戻る**（双方向に再現済み・決定論的）。
  **JSON 構文を壊す方法は使わない**（他ツールの誤動作を招くため。R-F08）
- **通常**: `git revert` で todo T-06 のコミットを戻す
- **緊急**: `PLANGATE_BYPASS_HOOK=1` を与えて全 hook を pass させる（既存の escape hatch）

### Task 5c（todo T-06b）: 実リポジトリでの確認実走（**終端 A1 にするための 2 回目・Human 承認時のみ**）

**Purpose**: **サンドボックスでの観測を実リポジトリへ移送できているか**を 1 回だけ確認し、終端 A の主張を「別ディレクトリでの観測」から
「**実リポジトリでの観測**」へ引き上げる。

**Steps**:

- [ ] Step 1: `todo T-06` 完了後（＝ 実リポジトリで登録済み・trusted 済み）に、**TC-14 と同一の env・同一の deny 対象**で `codex exec` を 1 回実行する
- [ ] Step 2: bypass 無し / 非 `--ephemeral` / retry 禁止を prompt に明示（TC-14 と同条件）
- [ ] Step 3: block を観測できたら **終端 A1**、観測できなければ **終端 A2 の文言に加えて「実リポジトリでは未発火」を明記**する

**Completion Criteria**: 実走の結果（block / 未 block）と使用 env が evidence に残り、doc の文言が終端 A1 / A2 のどちらかに確定している

**Rollback**: 不要（読取・観測のみ。**`.codex/hooks.json` は既に T-06 で確定済み**）

> **なぜ EIC に反しないか**: EIC は「**証拠より先に不可逆操作をしない**」ための不変条件であり、
> **不可逆操作の後に証拠を増やすことは禁じていない**（むしろ主張を強くする）。
>
> **なぜ既定で実施を推奨するか（課金 2 回のトレードオフ）**:
>
> - **費用**: `codex exec` 1 回（既存 spike の実測で `gpt-5.4-mini` / output 数百 token 規模）。**S-2 全体で 2 回**になる。
> - **便益**: `trusted_hash` は **per-`CODEX_HOME`** で、実リポジトリの trust エントリは**サンドボックスとは別のキー**である。
>   本 PBI の主題が「**登録 ≠ 強制力**」である以上、**実リポジトリで 1 度も発火を見ないまま「有効化した」と記録するのは、
>   本 PBI が潰そうとしている誤りの再生産に最も近い残存リスク**である。
> - **判断**: 費用対効果は釣り合うと考えるため **H-01 で「合計 2 回まで」を承認対象に含める**。
>   ただし **Human が 1 回のみを承認した場合は本タスクを実施せず、終端 A2 の文言で閉じる**（**完了条件を満たせなくはしない**）。

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
| **スイート全体（必須）** | **`sh tests/run-tests.sh`** | **exit 0 かつ出力に一意マーカー `PG_TA_CODEX_BRIDGE_IO_V1` が現れる**（= loader に拾われた証明。**番号で判定しない** / R3-F5） | `evidence/verification/` |
| Unit（bridge I/O） | `sh tests/extras/ta-67-codex-bridge-io.sh`（standalone 経路） | 共有 exit 契約どおり（0 / 1 / 2 / 3） | `evidence/verification/` |
| 既存テスト非回帰 | `sh tests/run-tests.sh` の `TA-15` セクション | Task 2 実施後も PASS | `evidence/verification/` |
| 変異注入 | Task 2b の **8 変異**（1 / 2 / 3 / 4a / 4b / 5 / 6 / 7）を個別適用 | **想定した TC が FAIL** する | `evidence/verification/` |
| 登録状態（**前提条件 P-1**） | `codex app-server` の `hooks/list` | 5 件 / `warnings` 空 / `enabled` / `trustStatus` | `evidence/verification/` |
| ランタイム block | `codex exec` 1 回（Human 承認時のみ・**bypass フラグ無し**） | stderr に `Command blocked by PreToolUse hook:` / 対象ファイル不在 | `evidence/verification/` |
| 非回帰（Claude 側） | `git diff $(git merge-base HEAD origin/main) -- scripts .claude`（🔴 **`scripts` 全体**。`scripts/hooks` だけにしない / R3-F7d） | 差分 0 | `evidence/verification/` |
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
| 🔴 **R-11** | **不可逆な有効化が証拠より先に来る**（旧版の既定の着地が「AC 全 PASS・登録済み・実効 0」だった） | **EIC 不変条件**: AC-07 は**サンドボックス実走**（T-05b）で取得し、**PASS のときのみ T-06 を実行**。WARN なら kill switch 保持で終端 B。**「AC-07 WARN かつ T-06 実行済み」を完了条件違反と明記**（R3-F1） |
| 🔴 **R-12** | **deny の reason が JSON エスケープされず、不正 JSON → 黙った allow** に化ける（`\`・制御文字が素通り / `head -c` がバイト単位で日本語を割る） | 出力 JSON を**シリアライザで生成**・**文字境界を守る切り詰め**・**全 deny TC に `json.loads` 可能性の assertion**・**変異 5** で検出力を実証（R3-F2 / AC-05 を拡張） |
| 🔴 **R-13** | **kill switch がテストから不可視**で、マージ後に誰かが top-level へ 1 行足すと**全 AC 緑のまま Codex 側強制力が全滅**する | TC-22a を **「宣言 stage（`PG_EXPECTED_STAGE`）vs 実体」の drift 検出**に変える。**どちらの向きの乖離も FAIL**（R3-F3） |
| 🔴 **R-14** | **`trusted_hash` に bridge 内容が含まれない**なら、trusted 済み環境で **AI が bridge を 1 行書き換えるだけで強制力を消せる**（Task 6 は `.codex/hooks/*.sh` を AI-owned と確定させる） | **T-05 Step 4 で実測**し、含まれないなら**限界として doc に明記**（AC-09）。含まれるなら再 trust プロンプトが検出層になる（R3-F4） |
| **R-15** | **`$(git rev-parse --show-toplevel)` は CWD 依存**（hooks.json の `command` 実測）。ネスト repo / submodule / 別 worktree では**別リポジトリの bridge が解決されうる** | 本 PBI では**挙動を変えない**（hooks.json の command を書き換えるとスコープが広がるため）。**限界として doc に明記**し、**S-3 の doctor / CI 検査項目候補**として申し送る（R3-F7a） |
| **R-16** | **`PLANGATE_BYPASS_HOOK=1` は被規制主体である agent 自身が設定できる**。強制力回復の主張の強度を下げる | 本 PBI では**escape hatch を維持**（緊急 rollback 手段として必要）。ただし **E-7 は「生存確認」であって安全性の証明ではない**と doc に明記し、**強制力の主張から除外**する（R3-F7c） |

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
| 3a | Task 5a | **T-05** | なし（文書のみ + `trusted_hash` 範囲の実測） | 不要 |
| **G** | **Task 4** | **H-01** | — | 判断のみ（**T-05 の後・実走と有効化を一体で承認**） |
| **3a-2** | **Task 5a-2** | **T-05b** | **なし**（サンドボックス実走。実リポジトリ無変更） | サンドボックス削除 |
| 3b | **Task 5b** | **T-06** | 🔴 **あり（唯一の有効化）**。**AC-07 PASS のときのみ実行** | **top-level に未知キーを 1 行足して全件無効化** / `git revert` / `PLANGATE_BYPASS_HOOK=1` |
| 3c | Task 5c | **T-06b** | なし（観測のみ・**承認時のみ実施**） | 不要 |
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
- **`$(git rev-parse --show-toplevel)` の CWD 依存（S-3 候補 / R3-F7a）**: `.codex/hooks.json` の 5 つの `command` は
  すべて `sh "$(git rev-parse --show-toplevel)/.codex/hooks/eh-bridge.sh" <hook>.sh` の形（実測）。
  **ネスト repo / submodule / 別 worktree では別リポジトリの bridge が解決されうる**。
  本 PBI では **`command` 文字列を変更しない**（変更するとスコープが広がり、`trusted_hash` も全件無効化される）。
  **限界として doc に明記し、doctor / CI 検査の候補として S-3 へ申し送る**。
- **`PLANGATE_BYPASS_HOOK=1` の悪用面（R3-F7c）**: 本 escape hatch は**被規制主体である agent 自身が設定できる**。
  緊急 rollback 手段として**維持する**が、**E-7 は「生存確認」であって安全性の証明ではない**。
  **強制力の主張から明示的に除外**する（doc に明記）。恒久的な扱いは別 PBI。
- **`PLANGATE_HOOK_STRICT` の既定**: 現状 warning 既定であるため、EH-1 / EH-2 / EH-6 は本 PBI 完了後も
  **Codex 側で block しない**。「11 wiring 分の強制力が揃った」とは主張できない。この差は別 PBI で扱う。

## Plan Review Readiness

### Success Criteria

- **AC-01〜AC-05・AC-07〜AC-12**（[`pbi-input.md`](./pbi-input.md)。**AC-06 は前提条件 P-1 へ移動・欠番**）
  ↔ [`test-cases.md`](./test-cases.md) の **TC-01〜TC-26**（TC-22 は **TC-22a / TC-22b** に分割）
  - **AC 対応を持たない TC**: **TC-13**（前提条件 P-1 の確認手順）/ **TC-20**（#1089 の限界を現状固定・**あるべき挙動ではない**）
  - **エッジケース**: E-1〜E-12（**E-3'** / **E-9a・E-9b** / **E-11・E-12** を含む）
- **終端条件**: 上記に加え **EIC 不変条件**（AC-07 = WARN なら `todo T-06` 未実行）を満たすこと
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
