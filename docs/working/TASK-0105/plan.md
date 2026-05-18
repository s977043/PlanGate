# EXECUTION PLAN — TASK-0105 / #282

## Goal
check-plan-hash.sh の plan_hash 抽出を strict JSON 化し不正 c3.json を承認
境界の根拠にしない（安全側）。正常系・改竄検知は不変。

## Constraints / Non-goals
- EH-3 block/warn 判定 / plan_hash 形式 / c3 schema / Python util / shell
  全面 Python 化 はしない。抽出のみ strict 化。

## Approach Overview
:183-184 の grep|sed を python3 heredoc（:108 前例パターン・json.loads→
dict 確認→sha256: prefix→bare hex・不正/欠落/非object/prefix不一致は空）へ。
plan_hash_util.recorded_plan_hash と意味一致。ta-11 phc_shell も同 strict
へ更新し malformed を parity assert。hook-enforcement.md に注記。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | check-plan-hash.sh strict 化 | agent | 中 | 🚩 AC1/AC3 |
| S2 | ta-11 phc_shell strict + parity | agent | 中 | 🚩 AC2 |
| S3 | hook-enforcement.md 注記 | agent | 低 | 🚩 AC5 |
| S4 | EH-3 回帰+全スイート検証 | agent | 中 | 🚩 AC3/AC4 |

## Files / Components to Touch
- scripts/hooks/check-plan-hash.sh / tests/extras/ta-11-plan-hash-contract.sh
  / docs/ai/hook-enforcement.md

## Testing Strategy
- Verification: ta-11 4/4 parity / 実リポジトリ (a)正常→PASS (b)不正JSON→
  SKIP (c)改竄→BLOCK exit1 / run-tests 68/0 / sh -n / scope 限定。

## Risks & Mitigations
- block/warn 回帰 → 実リポジトリ a/b/c + ta-11 + run-tests で機械保証
- python 可搬性 → :108 既出依存（新規追加なし）確認済

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**: 承認境界（EH-3）変更・hooks/test/doc 横断・Human トリガ済 →
standard（V-3 必須）
