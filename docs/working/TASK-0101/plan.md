# EXECUTION PLAN — TASK-0101 / #277 reuse M-2

## Goal
scripts のパス定数を _paths.py へ集約し命名統一（behavior-preserving）。

## Constraints / Non-goals
- env override/設定注入/package化/shell・hooks 巻込/plan_hash_util 依存/
  振る舞い変更 はしない（Codex 助言・YAGNI）。

## Approach Overview
_paths.py（固定定数）新規 → 11 script の path 定義を `from _paths import` に
置換、各 script の既存変数名へ alias（差分最小・下流不変）。import bootstrap
（scripts/ を sys.path へ・既存慣習整合）を 1 行付与。全スイート + smoke +
metrics plan_hash 等価で behavior-preserving 検証。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | scripts/_paths.py | agent | 低 | 🚩 AC1 |
| S2 | 11 script 置換（alias 維持）| agent | 中 | 🚩 AC2 |
| S3 | 回帰: run-tests + smoke + plan_hash 等価 | agent | 中 | 🚩 AC3/4/5 |

## Files / Components to Touch
- scripts/_paths.py（新規）
- 上記 11 script（path 定義のみ置換）

## Testing Strategy
- Verification: sh tests/run-tests.sh 全件 / 主要 CLI smoke（keep-rate/context/
  report/validate-schemas/eval-runner/metrics_reporter/schema_mapping）/
  metrics_collector plan_hash 等価 / shell・hooks・bin git diff 空 / py_compile。

## Risks & Mitigations
- import 経路 → bootstrap(sys.path.insert scripts) 1行・両実行経路で smoke 確認
- 挙動差 → alias で下流変数名不変・全スイート 68/0・plan_hash 等価で機械保証
- scope 逸脱 → shell/hooks/bin/plan_hash_util を Non-goal・git diff で不巻込確認

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**: 12 ファイル（新規1+11置換）・schema_mapping/eval 含む・
behavior-preserving だが横断 → standard（V-3 実施）
