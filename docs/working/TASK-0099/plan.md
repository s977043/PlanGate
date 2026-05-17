# EXECUTION PLAN — TASK-0099 / /simplify follow-up

## Goal
#198/#199 の merged スクリプトを behavior-preserving に局所クリーンアップ。

## Constraints / Non-goals
- 出力・機能・受入基準を変更しない（純リファクタ）。
- 共有モジュール化（reuse H-1 plan_hash_util / M-2 paths）は横断 PBI＝対象外。

## Approach
keep-rate.py: 一括 git show / _unknown・_ratio / 定数 / c3 json / hashlib top。
context-engine.py: _POLICY_ORDER / c3 json / nesting 緩和 / コメント trim。
各々 main 版と in-place 出力比較で等価性を機械検証。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | keep-rate.py 局所改善 | agent | 低 | 🚩 AC1/AC3 |
| S2 | context-engine.py 局所改善 | agent | 低 | 🚩 AC2/AC3/AC4 |

## Files / Components to Touch
- scripts/keep-rate.py / scripts/context-engine.py

## Testing Strategy
- Verification: 改善前(main)と改善後を in-place で複数 TASK 実行し JSON 等価比較。
  context-engine は MJ-2（stale→invalidated/exit1）回帰 + schema validate。

## Risks & Mitigations
- 等価性崩れ → in-place diff（TASK-0095/0087/0090/0096）で機械確認済

## Questions / Unknowns
なし

## Mode判定
**モード**: light
**判定根拠**: 2 ファイル・behavior-preserving リファクタ・出力不変 → light
