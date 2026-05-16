# settings wiring 契約（正本 / TASK-0080 S1）

> `.claude/settings.json` が満たすべき PreToolUse hook wiring の**正本**。
> `bin/plangate doctor --check-settings` がこの契約と実体を突合する。
> 適用は `scripts/apply-claude-settings.sh`（**ユーザー実行**。AI は
> self-mod ガードで `.claude/settings.json` を編集できないため）。

## 必須 PreToolUse hooks（matcher: Edit|Write 系）

| Hook | command（必須トークン） |
|------|------------------------|
| EH-1 plan-exists | `scripts/hooks/check-plan-exists.sh` |
| EH-2 c3-approval | `scripts/hooks/check-c3-approval.sh` |
| EH-3 plan-hash | `scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}` |
| EH-6 forbidden-files | `scripts/hooks/check-forbidden-files.sh` |
| EH-9 delegation-commit-boundary | `scripts/hooks/check-delegation-commit-boundary.sh` |

### 契約ポイント

- **EH-3 は `${PLANGATE_HOOK_FILE:-}` を第2引数に含む**（P4(d) ファイルパス
  感応 SKIP / TASK-0070 AC-8。これが本セッション通底の未適用 wiring）。
- **EH-9 wiring が存在する**（委譲 commit 境界 / TASK-0073）。
- 上記トークンが `.claude/settings.json` の PreToolUse command 群に
  すべて存在すれば `doctor --check-settings` PASS。1 つでも欠落で FAIL。

## 検証・適用

- 検証: `bin/plangate doctor --check-settings`（未適用箇所を列挙し非0）
- 適用: `sh scripts/apply-claude-settings.sh`（冪等。ユーザーが実行）
- CI: settings drift check（required）が契約逸脱を fail させる

## 不変

- `.claude/settings.json` の AI 直接編集は禁止（self-mod ガード・恒久制約）。
  AI は契約定義・検証・適用 script 提供まで。適用は人間。
- 本契約の追加 hook は settings.example.json と整合させること。


## 責務分離（V-3 MJ-2/MJ-3 反映）

| 層 | 検証対象 | 手段 | 役割 |
|----|---------|------|------|
| CI `settings-drift`（required）| `.claude/settings.example.json`（契約 reference）| `check-settings-wiring.sh --target example` | 正本 reference が契約と乖離しないことを保証（example が壊れたら全員に波及するため）|
| `bin/plangate doctor --check-settings` | `.claude/settings.json`（ユーザー実体）| 構造（JSON）検証 | 実環境の wiring 未適用＝Shadow Config を検出 |
| 既存 `bin/plangate doctor` hook-wiring check | `.claude/settings.json` vs `.claude/settings.example.json` | 既存 check（TASK-0069）| settings.example.json を契約整合させた結果、未適用を**通常 doctor でも FAIL**（従来の false-PASS を是正）|

`.claude/settings.json` は gitignore（ユーザーローカル）のため **CI では検出
不可**。実体 drift の検出は doctor（ローカル / V-1・handoff DoD）が担う。
両者は役割が異なり、どちらか一方では「Shadow Config を構造的に防ぐ」根拠に
ならない（CI=reference 健全性 / doctor=実体適用）。

## タスクロックの強制経路（V-3 MJ-1 反映）

V-1/handoff 完了の DoD（[`docs/workflows/05_verify_and_handoff.md`](../workflows/05_verify_and_handoff.md)
/ [`working-context.md`](../../.claude/rules/working-context.md)）に
「`doctor --check-settings` PASS」を必須化。強制は次の二重で成立する:

1. **DoD 明文 + 通常 `doctor` の hook-wiring FAIL**: settings.example.json を
   契約整合させたため、未適用環境では `bin/plangate doctor`（通常実行）も
   FAIL する。doctor FAIL 状態での完了報告は Iron Law（検証証拠なしに完了
   扱いしない）違反。
2. **`doctor --check-settings`**: 構造検証で未適用箇所を決定論的に列挙。

> 既知の限界（V2 候補）: 完全な PreToolUse-hook レベルの機械 block（V-1
> 実行経路への物理結線）は本スライス範囲外。現状は DoD + doctor FAIL +
> Iron Law による強制。完全機械化は TASK-0071 S3/S4 または別 PBI で扱う。
