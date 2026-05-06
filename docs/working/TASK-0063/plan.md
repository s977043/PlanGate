# EXECUTION PLAN: TASK-0063 (v8.6.0 PR1)

## Goal
v8.6.0 範囲で privacy policy の実効強制と governance 完結。

## Mode
high-risk（hook 新規 + multi-file 修正、ただし opt-in 設計で既存挙動には影響なし）

## Approach
1. `scripts/hooks/check-metrics-privacy.sh` 新規（既存 hook パターン踏襲）
2. fixture 2 種（good / bad-forbidden）
3. `tests/hooks/run-tests.sh` に EH-8 6 test cases
4. `tests/extras/ta-09-metrics.sh` に C-2 + D-1 (= 2 cases)
5. `docs/ai/metrics-privacy.md` §10 を「v8.6.0 実装済」化
6. GitHub label A-4 は PR 外で完了済

## Files
- `scripts/hooks/check-metrics-privacy.sh` (new)
- `tests/fixtures/hooks/check-metrics-privacy/good/sample.json` (new)
- `tests/fixtures/hooks/check-metrics-privacy/bad-forbidden/sample.json` (new)
- `tests/hooks/run-tests.sh` (+6 tests)
- `tests/extras/ta-09-metrics.sh` (+2 tests)
- `docs/ai/metrics-privacy.md` §10 (修正)
- `docs/working/TASK-0063/*` (new)

## Test
- L-0: shellcheck / markdown lint
- V-1: 9 AC 突合
- 自動: tests/run-tests.sh 32→34、tests/hooks/run-tests.sh 42→48
