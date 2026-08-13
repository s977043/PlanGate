# TASK-1078 S-2 テストケース定義

> 正本: [`plan.md`](./plan.md) / 受入基準: [`pbi-input.md`](./pbi-input.md)
> 実行系: `tests/extras/codex-bridge/run.sh`（新規・`tests/extras` の共有 exit 契約に従う）

## 前提（全 TC 共通）

- **env はテストが明示設定する**。セッションからの継承を禁止する（計画時に `PLANGATE_HOOK_TASK` の継承で判定が変わることを実測）
  - `PLANGATE_HOOK_TASK`: 各 TC で指定（`unset` の場合は `env -u` で明示的に外す）
  - `PLANGATE_HOOK_STRICT`: 既定 `0`（本 PBI で既定を変えない）
  - `PLANGATE_DELEGATION_NOCOMMIT`: 各 TC で指定
- payload は実測形状（`hook_event_name` / `tool_name` ∈ {`apply_patch`, `Bash`} / `tool_input` / `cwd` / `permission_mode` / `tool_use_id`）
- 判定は bridge の stdout から `hookSpecificOutput.permissionDecision` を抽出して行う

## 受入基準 → テストケース マッピング

| AC | 内容 | TC |
|---|---|---|
| AC-01 | deny すべきケースで deny | TC-01・TC-02・TC-03・TC-04 |
| AC-02 | allow すべきケースで allow | TC-05・TC-06・TC-07 |
| AC-03 | 変異注入で FAIL する | TC-08・TC-09 |
| AC-04 | stderr は判定に使わない | TC-10 |
| AC-05 | 未知 rc は deny / reason 非空 | TC-11・TC-12 |
| AC-06 | 登録状態（前提条件） | TC-13 |
| AC-07 | ランタイム block 証跡 | TC-14 |
| AC-08 | Claude 側非回帰 | TC-15 |
| AC-09 | 責務分界の一意性 | TC-16 |

## テストケース一覧

### TC-01: EH-9 が委譲文脈の commit を deny する（stdin 依存）

- 前提: `PLANGATE_DELEGATION_NOCOMMIT=1` / `PLANGATE_HOOK_TASK` unset
- 入力: `tool_name=Bash` / `tool_input.command="git commit -m wip"` → `check-delegation-commit-boundary.sh`
- 期待: `permissionDecision="deny"` / reason 非空
- 種別: Unit（自動）
- 備考: **stdin 転送が無いと allow になる**（計画時実測）。stdin 修正の唯一の直接証明

### TC-02: EH-9 が委譲文脈の force push を deny する

- 前提: TC-01 と同じ
- 入力: `tool_input.command="git push --force origin main"`
- 期待: `deny`
- 種別: Unit（自動）

### TC-03: EH-3 が HO パスへの書き込みを deny する（stdout 非依存・rc=2 経路）

- 前提: `PLANGATE_HOOK_TASK` **unset**
- 入力: `tool_name=apply_patch` / patch 本文に `*** Update File: .claude/settings.json` → `check-plan-hash.sh`
- 期待: `deny` / reason に `HARDENING_OVERRIDE` を含む
- 種別: Unit（自動）
- 備考: **修正前 bridge でも deny**（rc=2 経路）。回帰検出用の固定点

### TC-04: EH-2 が C-3 未承認を deny する（stdout 依存・STRICT=1）

- 前提: `PLANGATE_HOOK_STRICT=1` / `approvals/c3.json` 不在
- 入力: `apply_patch` → `docs/working/TASK-9999/plan.md` → `check-c3-approval.sh`
- 期待: `deny`
- 種別: Unit（自動）
- 備考: hook は **rc=0 + stdout `{"continue":false}`**。**stdout 判定の直接証明**

### TC-05: 通常の実装作業が allow される（誤検出ゼロ側）

- 前提: `PLANGATE_HOOK_TASK` unset / `STRICT=0` / `NOCOMMIT` unset
- 入力: `apply_patch` → `docs/working/TASK-9999/plan.md`（plan.md 実在）→ 4 hook すべて
- 期待: **全件 `allow`**
- 種別: Unit（自動）

### TC-06: 通常セッションの git commit が allow される

- 前提: `PLANGATE_DELEGATION_NOCOMMIT` **unset**
- 入力: TC-01 と同じ command
- 期待: `allow`
- 種別: Unit（自動）
- 備考: EH-9 の blast radius が委譲文脈に限定されることの保証

### TC-07: 非 HO パスの production 編集が allow される（既定 STRICT=0）

- 前提: `STRICT=0` / `PLANGATE_HOOK_TASK` unset
- 入力: `apply_patch` → `docs/ai/notes.md` → 4 hook
- 期待: 全件 `allow`
- 種別: Unit（自動）

### TC-08: 変異 1 — stdin 転送を除去すると TC-01 / TC-02 が FAIL する

- 前提: bridge の stdin 転送行（call site）を修正前へ戻す
- 期待: **TC-01・TC-02 が FAIL**、他は PASS のまま
- 種別: Mutation（手動適用 + 自動判定）
- 備考: 期待値側を書き換えて FAIL を作らない

### TC-09: 変異 2 — stdout 判定を除去すると TC-04 が FAIL する

- 前提: bridge の stdout 判定ブロックを削除する
- 期待: **TC-04 が FAIL**（および STRICT=1 の EH-1 ケースが FAIL）、TC-03 は PASS のまま（rc=2 経路のため）
- 種別: Mutation（手動適用 + 自動判定）

### TC-10: stderr の block 相当文字列で deny にならない

- 前提: stdout に `{"continue":true}`、**stderr にのみ** `"continue":false` を含む文字列を出す stub hook
- 期待: `allow`
- 種別: Unit（自動）
- 備考: 計画時に **false deny を実測で再現済み**。判定チャネル分離の回帰テスト

### TC-11: 未知 exit code が deny になる（fail-closed）

- 前提: `exit 127` を返す stub hook
- 期待: `deny` / reason に `rc=127` を含む
- 種別: Unit（自動）

### TC-12: 無出力 block でも reason が非空

- 前提: 無出力で `exit 2` / `exit 1` を返す stub hook
- 期待: `deny` かつ `permissionDecisionReason` が**非空**
- 種別: Unit（自動）
- 備考: 空 reason の deny は Codex ランタイムで**黙って握り潰される**（実測）

### TC-13: 登録状態（**前提条件の確認**）

- 前提: 注記キー除去後
- 手順: `codex app-server` の `hooks/list`
- 期待: PlanGate hook **5 件** / `warnings[]` 空 / 全件 `enabled=true` / `trustStatus="trusted"`
- 種別: Manual（課金ゼロ）
- ⚠️ **本 TC の PASS を成果として報告しない。** 登録は前提であって強制力ではない

### TC-14: ランタイム block 証跡（**Human 承認が前提**）

- 前提: TC-13 PASS + Human が実走 1 回を承認
- 手順: `codex exec` を 1 回（非 `--ephemeral` / deny 対象を先 / 「ブロックされても retry しない」を prompt に明示）
- 期待: stderr に `Command blocked by PreToolUse hook:` + PlanGate hook 名 / **対象ファイルが生成されていない**
- 種別: E2E（課金あり・1 回限り）
- 未承認時: **WARN**（理由・代替・未充足リスクを handoff と `settings-wiring-contract.md` に記録）

### TC-15: Claude 側の非回帰

- 手順: `git diff origin/main -- scripts/hooks .claude`
- 期待: **差分 0**
- 種別: Manual（自動化可）

### TC-16: 責務分界の一意性

- 手順: `docs/ai/settings-wiring-contract.md` の責務分界節が**パス単位の表**で、`.codex/hooks/*.sh` の新規追加・既存改変の双方の帰属が読めることを目視確認する
- 期待: `.codex/**` = AI-owned / HO 9 カテゴリ = Human-owned が一意。機械判定（`check-plan-hash.sh` の case 文）との一致が明記されている
- 種別: Manual（レビュー）

## エッジケース

| # | ケース | 期待 |
|---|---|---|
| E-1 | `tool_input` にファイルパスが無い `apply_patch`（Add/Delete/Update いずれの行も無い） | `PLANGATE_HOOK_FILE` 未設定で hook 起動 → allow（誤検出ゼロ側）。**crash しない** |
| E-2 | stdin が空（Codex 以外からの起動） | allow。**bridge 自体が異常終了しない** |
| E-3 | stdin が壊れた JSON | allow（パス抽出失敗）。ただし stderr に診断を残す |
| E-4 | hook 名が `scripts/` 直下にのみ実在（EH-13 相当） | フォールバックで解決され、not-found deny にならない |
| E-5 | hook 名がどちらにも無い | 従来どおり `deny` / reason 非空 |
| E-6 | hook が 15 秒を超える | Codex の timeout 設定に従う。**bridge 側では扱わない**（挙動を変えない） |
| E-7 | `PLANGATE_BYPASS_HOOK=1` | 全 hook が allow を返す（既存 escape hatch が生きていること） |
| E-8 | 同一 matcher group の複数 hook のうち 1 本が deny | Codex 側の打ち切り仕様は U-6（未確定）。**bridge の期待値は hook 単位で判定する** |

## 自動化可否

| 種別 | 件数 | 自動化 |
|---|---|---|
| Unit（bridge I/O） | TC-01〜TC-07・TC-10〜TC-12 + E-1〜E-5・E-7 | ✅ 完全自動・課金ゼロ |
| Mutation | TC-08・TC-09 | ⚠️ 変異適用は手動、判定は自動 |
| Manual（課金ゼロ） | TC-13・TC-15・TC-16 | ⚠️ TC-13 は S-3 で自動化予定 |
| E2E（課金あり） | TC-14 | ❌ Human 承認が必要・1 回限り |
