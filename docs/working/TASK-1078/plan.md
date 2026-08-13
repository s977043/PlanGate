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
> 入力: [`pbi-input.md`](./pbi-input.md) / [`evidence/codex-exec-spike.md`](./evidence/codex-exec-spike.md) / [`evidence/codex-payload-spike.md`](./evidence/codex-payload-spike.md)

## Goal

`.codex/hooks/eh-bridge.sh` の I/O 契約を PlanGate hook の実際の入出力仕様に合わせ、
**Codex セッションで承認境界ガードが実際に block する**状態を、**「登録されたが効かない」中間状態を一度も経由せずに**作る。

## Context

- 背景: [`pbi-input.md`](./pbi-input.md) §Context / Why
- 関連 Issue: <https://github.com/s977043/plangate/issues/1078>
- 関連 artifact: `pbi-input.md` / `todo.md` / `test-cases.md` / `status.md`（S-1 由来・本 PBI では追記のみ）

## Scope

### In Scope

- `.codex/hooks/eh-bridge.sh`（I/O 契約: stdin 転送 / stdout 判定 / fail-closed / hook パス解決）
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
- 判定チャネルは **stdout のみ**。stderr は reason 生成にのみ使う

## 前提の実測検証（#786）

> 実施日 2026-08-13 / base `origin/main` = `8f57e59` / 合成サンドボックス（実リポジトリのファイルは複製のみ・書き込みなし）。
> 5 hook の複製 + 実 payload 形状 fixture 6 種 × bridge 4 variant × `PLANGATE_HOOK_STRICT` × `PLANGATE_HOOK_TASK` を全数実行。

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

## Questions / Unknowns（#786）

- **U-4**: `trustStatus:"untrusted"` の hook が実行時に発火するか。**解消条件**: Stage 3 の gate で `hooks/list` の `trustStatus` を確認し、`trusted` でなければ `trusted_hash` を付与してから進む（発火可否そのものの検証は不要にする設計）。
- **U-5**: `codex exec` が PreToolUse を評価する条件（`--ephemeral` / trust bypass のどちらが効いたか未切り分け）。**解消条件**: AC-07 の実走を非 `--ephemeral` で行う。
- **U-6**: 1 matcher group 内の複数 hook が最初の deny で打ち切られるか。**解消条件**: AC-07 の証跡読解時に stderr の hook 名で判断（設計には影響しない）。
- **U-7**: Codex の matcher が正規表現の完全一致か部分一致か（`apply_patch` のみに絞る変更の安全性）。**解消条件**: Stage 2 後の `hooks/list` で `matcher` 文字列と登録件数を確認。

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | `eh-bridge.sh` を拡張（stdin 転送 + stdout 判定 + fail-closed + パス解決フォールバック） | 既存 guard を共用（#1078 Non-goals 準拠）・1 箇所に集約 | 配線済み 5 hook すべての挙動が変わる → 回帰検証が要る | **採用** |
| B | EH-13 専用アダプタを新設 | 既存 5 hook に影響しない | Codex 側に独自 guard を増やす方向で **#1078 Non-goals に抵触**・二重実装 | 不採用 |
| C | hook 本体（`scripts/hooks/*.sh`）を Codex 形式に合わせる | bridge が薄くなる | **HO パス改変＝Human-owned**・Claude 側の挙動に影響 | 不採用 |

### Recommended Approach

**案 A**。ただし「B の懸念（回帰）」を**注記キーを kill switch として使う段階導入**で吸収する。

> **設計の核**: `.codex/hooks.json` の注記キーが残っている限り、ファイル全体が parse 拒否され **hook は 1 件も登録されない**。
> つまり **Stage 1〜2 の変更は Codex ランタイムに一切影響しない**。注記キーは事実上の **feature flag** であり、
> その除去（Stage 3）が唯一の「有効化」操作になる。ロールバックは **1 行の再追加**で全体を即時無効化できる。

## Files / Interfaces

| ファイル | 操作 | 目的 | 公開インターフェース / 依存 |
|---|---|---|---|
| `.codex/hooks/eh-bridge.sh` | modify | I/O 契約修正 | 入力: Codex PreToolUse JSON (stdin) / 出力: `hookSpecificOutput.permissionDecision` |
| `.codex/hooks.json` | modify | matcher 整理 → 注記キー除去 | top-level は `description` / `hooks` のみ |
| `tests/extras/codex-bridge/` | create | fixture 駆動テスト + fixtures | 共有 exit 契約（`tests/extras` 既存規約）に従う |
| `docs/ai/settings-wiring-contract.md` | modify | 責務分界のパス単位明確化 | — |
| `docs/working/TASK-1078/status.md` | modify | フェーズ履歴追記（**既存記述は改変しない**） | — |

## Work Breakdown

### Task 1: fixture と baseline テストの導入（挙動不変）

**Purpose**: 実 payload 形状の fixture を固定し、**現行 bridge の挙動をテストで固定**する。以後の変更差分を機械的に可視化する。

**Files**: Create `tests/extras/codex-bridge/fixtures/*.json`, `tests/extras/codex-bridge/run.sh`

**Steps**:

- [ ] Step 1: 実測済み payload 形状（`hook_event_name` / `tool_name` ∈ {`apply_patch`, `Bash`} / `tool_input` / `cwd` / `permission_mode`）で fixture を 6 件作成する
- [ ] Step 2: `run.sh` が bridge を呼び、`permissionDecision` を抽出して期待値と突合する。**`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_STRICT` / `PLANGATE_DELEGATION_NOCOMMIT` を必ず明示設定**する（継承禁止）
- [ ] Step 3: 期待値を **現行挙動**（本 plan の実測表 variant A）で記述し、`sh tests/extras/codex-bridge/run.sh` が PASS することを確認する

**Completion Criteria**: 現行 bridge に対して全件 PASS / `.codex/` に差分が無い

**Rollback**: 追加ファイルを削除（`git rm -r tests/extras/codex-bridge`）。**ランタイム影響なし**

### Task 2: bridge の I/O 契約修正（挙動は変わるが Codex には未到達）

**Purpose**: 入力・出力の両契約を直す。**注記キーが残っているため Codex ランタイムには一切影響しない**。

**Files**: Modify `.codex/hooks/eh-bridge.sh`, `tests/extras/codex-bridge/run.sh`

**Steps**:

- [ ] Step 1: 期待値を修正後の契約（variant C 相当）に更新し、**RED** を確認する（現行 bridge で FAIL）
- [ ] Step 2: stdin を hook へ転送する（`INPUT` を hook の stdin へ流す）
- [ ] Step 3: hook の **stdout と stderr を別ファイルに分離**して捕捉する
- [ ] Step 4: **stdout のみ**を判定に使う（`"continue":false` / `permissionDecision:"deny"` → deny）。stderr は reason 素材に限定する
- [ ] Step 5: 未知 exit code を **deny** にする（fail-closed）。reason に rc を含める
- [ ] Step 6: hook 実体の解決を `scripts/hooks/<name>` → `scripts/<name>` の順にフォールバックさせる。どちらにも無ければ従来どおり deny
- [ ] Step 7: deny 時の reason が**常に非空**であることを保証する（空なら固定文言を埋める）
- [ ] Step 8: **GREEN** を確認する（`sh tests/extras/codex-bridge/run.sh`）
- [ ] Step 9: **変異注入**で検出力を実証する（Step 2 の転送を戻す → EH-9 ケースが FAIL / Step 4 の stdout 判定を戻す → EH-1・EH-2 ケースが FAIL）。両方とも FAIL することを確認してから元に戻す

**Completion Criteria**: テスト GREEN / 変異注入で FAIL を確認済み / `.codex/hooks.json` 未変更 / `scripts/**` 未変更

**Rollback**: `git checkout -- .codex/hooks/eh-bridge.sh`。**この時点では Codex ランタイムに影響が出ていない**ため無害

### Task 3: matcher の死に文字列除去（挙動不変）

**Purpose**: `apply_patch|Edit|Write` から Codex に存在しない `Edit` / `Write` を除く。

**Files**: Modify `.codex/hooks.json`

**Steps**:

- [ ] Step 1: matcher を `apply_patch` に変更する（`Bash` group は不変）
- [ ] Step 2: **注記キーは残したまま**であること（parse 拒否＝未登録の状態を維持）を目視と `hooks/list` で確認する

**Completion Criteria**: `hooks/list` が依然として PlanGate hook 0 件・同一 warning を返す（＝有効化されていない）

**Rollback**: `git checkout -- .codex/hooks.json`

### Task 4: 有効化前ゲート（Human 判断ポイント）

**Purpose**: 「登録されたが効かない」状態で止まらないことを、**有効化の前に**確認する。

**Steps**:

- [ ] Step 1: Task 1〜3 のテストが GREEN であることを提示する
- [ ] Step 2: Stage 3 で発生する deny の範囲（本 plan の実測表）を提示する
- [ ] Step 3: `trusted_hash` の付与手順（編集後に hash が変わるため再 trust が要る）を提示する
- [ ] Step 4: **AC-07 の実走 1 回（課金あり）の可否**について Human の判断を得る
- [ ] Step 5: 🚩 **チェックポイント**: Human の承認が得られるまで Task 5 に進まない

**Completion Criteria**: Human の可否判断が `status.md` に記録されている

**Rollback**: 不要（判断のみ）

### Task 5: 注記キー除去＝有効化（唯一の不可逆ステップ）

**Purpose**: `$schema_note` / `$note` を `description` に寄せ、hook を登録・発火させる。

**Files**: Modify `.codex/hooks.json`

**Steps**:

- [ ] Step 1: top-level を `description` / `hooks` の 2 キーのみにする
- [ ] Step 2: `hooks/list` で **登録件数 5・`warnings[]` 空・`enabled` true** を確認する（**前提条件の確認であって成果ではない**）
- [ ] Step 3: `trustStatus` を確認し、`trusted` でなければ `trusted_hash` を付与して再確認する
- [ ] Step 4: Task 4 で承認された場合のみ、`codex exec` を **1 回**実行して block 証跡を取得する（非 `--ephemeral`・deny 対象を先・「ブロックされても retry しない」を prompt に明示）
- [ ] Step 5: stderr に `Command blocked by PreToolUse hook:` が出ていること、**対象ファイルが生成されていないこと**の 2 点を証跡として保存する

**Completion Criteria**: AC-01〜AC-06 が PASS / AC-07 が PASS または WARN（理由記録付き）

**Rollback**:

- **即時無効化**: `.codex/hooks.json` の top-level に不正キー（例 `"$note"`）を 1 行戻す → ファイル全体が parse 拒否され **PlanGate hook が全件未登録に戻る**（本挙動は双方向に再現済み・決定論的）
- **通常**: `git revert` で Task 5 のコミットを戻す
- **緊急**: `PLANGATE_BYPASS_HOOK=1` を与えて全 hook を pass させる（既存の escape hatch）

### Task 6: 責務分界の曖昧さ解消（doc）

**Purpose**: 「新規 hook 追加は AI-owned / 既存 hook 改変は Human-owned」の適用範囲をパス単位で一意にする。

**Files**: Modify `docs/ai/settings-wiring-contract.md`

**Steps**:

- [ ] Step 1: 責務分界節を**パス単位の表**に置き換える（下記「責務分界」節の内容）
- [ ] Step 2: 機械判定（`check-plan-hash.sh` の HO case 文に `.codex/**` が**無い**こと）と記述が一致していることを明記する

**Completion Criteria**: `.codex/hooks/eh-bridge.sh` の改変責務が一意に読める

**Rollback**: `git checkout -- docs/ai/settings-wiring-contract.md`

## Verification Plan

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence 保存先 |
|---|---|---|---|
| Unit（bridge I/O） | `sh tests/extras/codex-bridge/run.sh` | exit 0 / 全件期待どおり | `evidence/verification/` |
| 変異注入 | Task 2 Step 9 の 2 変異を個別適用 | いずれも FAIL する | `evidence/verification/` |
| 登録状態 | `codex app-server` の `hooks/list` | 5 件 / `warnings` 空 / `trusted` | `evidence/verification/` |
| ランタイム block | `codex exec` 1 回（Human 承認時のみ） | stderr に `Command blocked by PreToolUse hook:` / 対象ファイル不在 | `evidence/verification/` |
| 非回帰（Claude 側） | `git diff origin/main -- scripts/hooks .claude` | 差分 0 | `evidence/verification/` |
| Lint | `npx markdownlint-cli2 docs/working/TASK-1078/*.md` | 本 PBI 由来 0 件 | `evidence/verification/` |

> **検証が実行不能な場合**: AC-07（課金を伴う実走）が Human 判断で不可となったときは、理由・代替（bridge 単体 deny + 既存の 3 回目実走証跡の援用）・未充足リスクを `handoff.md` と `settings-wiring-contract.md` に明記する。

### レビューレーン計画（#786）

| 成果物 | レーン | unavailable 時の代替 |
|---|---|---|
| `eh-bridge.sh` の I/O 契約 | 設計妥当性（契約の完全性・fail 方向）/ コードベース整合（`scripts/hooks/cursor-adapter.sh` 等の既存アダプタ慣行） | 単レーン時は実測 fixture で裏取り |
| 段階導入と rollback | 設計妥当性（不可逆点の位置・kill switch の実在性） | サンドボックスでの双方向再現 |

## Risks & Mitigations

| # | リスク | 緩和 |
|---|---|---|
| R-1 | 「登録された」を成果と誤認する | AC-06 を成果主張に使わない。AC-01（bridge deny）+ AC-07（ランタイム block）で担保 |
| R-2 | fail-closed 化で hook のエラーが全 deny に化ける | Task 5 の kill switch rollback を手順化。reason に rc を含めて原因を即特定可能にする |
| R-3 | stderr 由来の false deny | 判定チャネルを stdout に限定（AC-04・実測で再現済み） |
| R-4 | `PLANGATE_HOOK_TASK` 継承でテストが非決定的になる | テストで env を明示設定（AC-01/02 の前提） |
| R-5 | U-4 が「untrusted は発火しない」だった場合 | Task 5 Step 3 で `trusted` を確認してから進む（発火可否の検証自体を不要にする） |
| R-6 | Codex の matcher 仕様（U-7）で `apply_patch` 単独指定が効かない | Task 3 の後 `hooks/list` で matcher と件数を確認。異常なら matcher を元に戻す |

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

- 変更ファイル数: 6〜8（bridge / hooks.json / テスト一式 / doc 2 件）→ 高
- 受入基準数: 9 → 高
- 変更種別: **code**（hook のロジック変更）→ doc-light 適用外
- リスク: 高（無効なガードを「有効」に見せる失敗モードが本 PBI の中心。fail-closed 化による全 deny のリスクもある）
- ロールバック: 計画的に必要（kill switch を明示設計）→ 高
- **承認境界周辺の判定**: `.codex/hooks/*.sh` は HO 9 カテゴリの**文言上は対象外**（`check-plan-hash.sh` L124-134 に `.codex` は無い）。
  しかし本 PBI は **HO 対象 hook（`scripts/hooks/*.sh`）の強制力そのものを左右する**。
  `mode-classification.md` の「自動推定の安全側」に従い **該当扱い**とし、**最低 high** を適用する。
- **最終判定**: `high-risk` / `lite_eligible=false` / **人間 C-3 必須**（autonomous APPROVE 不可）

## 段階導入の要約

| Stage | Task | Codex ランタイムへの影響 | rollback |
|---|---|---|---|
| 0 | Task 1 | **なし**（テスト追加のみ） | ファイル削除 |
| 1 | Task 2 | **なし**（parse 拒否のため未登録） | `git checkout` |
| 2 | Task 3 | **なし**（同上） | `git checkout` |
| G | Task 4 | — | 判断のみ |
| 3 | Task 5 | **あり（唯一の有効化）** | 不正キー 1 行の再追加で全件無効化 / `git revert` / `PLANGATE_BYPASS_HOOK=1` |
| 4 | Task 6 | なし（doc） | `git checkout` |

## 後続への申し送り（S-2 に含めない理由つき）

- **EH-13 / EH-12 の配線（S-7 候補）**: EH-13 の parsed-safe 集合は `{Bash, Edit, Write, MultiEdit}` で、
  **Codex の `apply_patch` は parse-unknown → `exit 2` → deny** になる。素直に配線すると `apply_patch` が全 deny する。
  解は 2 つ: (a) EH-13 の集合に `apply_patch` を足す（**HO パス改変＝Human-owned**）/ (b) bridge が `apply_patch` を
  `file_path` 付きの形へ**正規化**して渡す（AI-owned・HO 不変）。**(b) を推奨**するが、
  「アダプタが tool_name を書き換える」ことの是非は設計判断であり、S-2 のスコープでは決めない。
- **S-3**: `hooks/list` 検査の doctor / CI 組み込み。**本 PBI の AC-06 を恒常化するのは S-3 の役割**。
- **S-4**: `trusted_hash` 運用の自動化。**手順の確立は本 PBI の前提として実施**するが、自動化は S-4。
- **`PLANGATE_HOOK_STRICT` の既定**: 現状 warning 既定であるため、EH-1 / EH-2 / EH-6 は本 PBI 完了後も
  **Codex 側で block しない**。「11 wiring 分の強制力が揃った」とは主張できない。この差は別 PBI で扱う。

## Plan Review Readiness

### Success Criteria

- AC-01〜AC-09（[`pbi-input.md`](./pbi-input.md)）↔ [`test-cases.md`](./test-cases.md) の TC-01〜TC-14
- Completion boundary: Codex セッションで **HO パス書き込みと委譲文脈の commit/push が block される**ところまで。
  EH-13 / EH-12 の配線・STRICT 既定の変更・CI 組み込みは別 PBI

### Review Criteria

- Design alignment: #1078 Non-goals（Codex 側に独自 guard を新設しない）を守り、既存 `scripts/` guard を共用しているか
- Test expectations: 変異注入で FAIL することまで確認しているか（テストの検出力）
- Security: 承認境界の強制方向。fail-closed 化が**緩和ではなく強化**であること
- Maintainability: 判定チャネル（stdout / stderr / exit code）の責務が bridge 内で一意か
- Backward compatibility: `.claude` 側の hook 挙動が無傷（AC-08）
- Operational risk: 有効化後の deny 範囲が実測表どおりに限定されること・kill switch が実在すること

### Required Context

- Issue #1078（再定義コメント / 訂正コメント）
- `docs/ai/settings-wiring-contract.md` §Codex CLI parity（3 軸・bridge 欠陥表）
- `evidence/codex-payload-spike.md` / `evidence/codex-exec-spike.md`
- `.claude/rules/mode-classification.md`（HO 9 カテゴリ）/ `.claude/rules/responsibility-classes.md`
