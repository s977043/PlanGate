# EXECUTION PLAN — TASK-0100 / Plan Hash Utility 共有化

## Goal
plan_hash の Python 側ロジックを scripts/plan_hash_util.py に集約し、承認境界
整合を EH-3 shell との契約テストで機械固定する。

## Constraints / Non-goals
- check-plan-hash.sh(shell EH-3 正本) の実行経路を変更しない（承認境界変更）。
- paths(M-2) 共有化 / plan_hash 形式変更 / metrics schema 変更 / import 基盤
  再設計はしない。

## Approach Overview
plan_hash_util.py（strict json = 承認境界保護正本、実証検証で確定）→
keep-rate/context-engine/metrics_collector を差し替え（local _read_c3_plan_hash
除去・inline hashlib 除去）→ tests/extras/ta-11 + fixtures で shell↔python
契約（正常 parity / 不正JSON strict 差異 = 仕様）を固定 → 全消費者 in-place
等価検証 + 全スイート回帰。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | plan_hash_util.py | agent | 中 | 🚩 AC1 |
| S2 | 3 消費者差し替え | agent | 中 | 🚩 AC2/AC3 等価 |
| S3 | ta-11 契約テスト + fixtures | agent | 中 | 🚩 AC4 |
| S4 | 全スイート回帰 | agent | 低 | 🚩 AC5 |

## Files / Components to Touch
- scripts/plan_hash_util.py（新規）
- scripts/keep-rate.py / context-engine.py / metrics_collector.py（差し替え）
- tests/extras/ta-11-plan-hash-contract.sh + tests/fixtures/plan-hash-contract/*（新規）

## Testing Strategy
- Verification: 3 消費者を main 版と in-place で複数 TASK 出力 diff（完全等価）
  + ta-11（shell↔python parity / 不正JSON 意図差異）+ run-tests.sh 全件 +
  py_compile。

## Risks & Mitigations
- 承認境界意味ズレ → ta-11 で parity + 意図的 strict 差異を機械固定（実証済）
- 等価崩れ → 3 消費者 in-place 等価（TASK-0095/0090/0096）確認済
- shell 触れない → check-plan-hash.sh 無変更を diff で保証（Non-goal）

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**: 新規 util + 3 ファイル refactor + 新規 test/fixtures（5+ファイル）
・承認境界整合・behavior-preserving → standard（V-3 実施）
