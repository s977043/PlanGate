# TASK-0145 EXECUTION PLAN — EHS strict 発火配線（#527）

> EPIC #527 の残: EHS-1/2/3 の物理配線。main 方針（`bin/plangate` ベース）に準拠。
> TASK-0143（EH-4/5/7 CLI 配線）の後続。hook-enforcement.md §EHS の「未配線理由」を解消。

## Goal

`bin/plangate` が `validation_bias: strict` 時に EHS-1/2/3 を強制発火する機構を配線し、
hook 物理配線を 12/12 完成へ近づける。非 strict（既定 normal）では発火せず既存挙動不変。

## Approach / 増分分割

| 増分 | EHS | 配線先 | 状態 |
|------|-----|--------|------|
| **1（本PR）** | EHS-1 V-3 必須化 | `cmd_verify` の V-3 case を strict 時 block | ✅ 実装 |
| 2 | EHS-3 fix-loop 上限 | `cmd_verify` fix-loop に `check-fix-loop.sh` strict | plan のみ |
| 3 | EHS-2 handoff 6要素 | `handoff --verify` 経路に `check-handoff-elements.sh` strict | plan のみ（意味論: 完了時検査） |

**発火条件の解決**: `PLANGATE_VALIDATION_BIAS` env（conductor が `model-profiles.yaml` の
active profile から解決・エクスポート）。将来 `--profile` 直接解決ヘルパーを追加可。

## 増分1 実装（EHS-1）

- `scripts/_apply_task_0145_patches.py` + `scripts/apply-task-0145-ehs-wiring.sh`（HO apply-script、dry-run/--apply）
  - `cmd_verify` の V-3 case を「strict かつ V-3 不合格 → `return 1`（block）」へ。非 strict は warn 維持。
- `tests/extras/ta-46-ehs-wiring.sh`（未適用 SKIP / 適用後 TC-01〜04 PASS）

## Constraints / Non-goals

- `bin/plangate` は HO → AI 直接編集不可。apply-script を Human が適用（TASK-0143 eh457 と同方式）。
- EHS-2/3 の実装は増分2/3（本PRは EHS-1 のみ）。
- `validation_bias` の profile 直接解決ヘルパーは将来拡張（本PRは env 注入方式）。

## Testing Strategy

- ta-46: 未適用 SKIP、適用後 TC-01（strict 発火条件配線）/ TC-02（block=return 1）/ TC-03（既定 normal 非発火）/ TC-04（patched 構文健全）。
- sandbox 適用検証で全 TC PASS 確認済み（実ツリー HO 非改変）。
- `sh tests/run-tests.sh` 0 FAIL（適用前 349 passed）。

## Risks & Mitigations

| Risk | 対策 |
|------|------|
| strict 注入経路（conductor）未整備で EHS-1 が発火しない | env 既定 normal で安全側。conductor 側 export は別タスクで明文化 |
| patch が bin/plangate 行変化で失敗 | 文字列アンカー方式（行番号非依存）+ apply 前 dry-run |

## Mode判定

**モード**: high-risk（`bin/plangate` = Hardening Override パス）/ lite_eligible=false
