# PBI INPUT — TASK-0103 / #281 reporting 精度 follow-up

## Context / Why
#200 dogfooding 振り返りで (1)hook violation 絶対数膨張（test/dev 混入）
(2)期間窓に旧 TASK 混入 が顕在化。Codex 相談で「#281=Do（最小・承認境界外・
reporting単独）/ #282=Defer（承認境界・Human トリガ）」と方針確定。

## What
- In: scripts/reporting.py（--exclude-test-hooks 構造化フィルタ / --tasks run
  スコープ・共に opt-in）/ docs/ai/reporting.md（判定軸明文化）
- Out: events/hook-events schema 変更 / 既存 period 破壊 / run_id インフラ
  新設 / C-3・C-4・承認境界変更 / #282（別 issue・Defer）

## 受入基準（#281）
- AC1: hook violation が test/dev 由来行を除外でき判定軸が reporting.md に明文化
- AC2: run スコープ（--tasks 任意）追加・未指定時 period 従来挙動と完全等価
- AC3: events.ndjson 不在/clean checkout で従来挙動等価（in-place 検証）
- AC4: run-tests.sh 回帰なし
- AC5: reporting.md に運用手順+精度限界更新

## Notes
test/dev 判定は構造化キー（TASK-HOOKTEST prefix / tests/fixtures パス）。
`-` 曖昧行は除外しない（実 violation 隠蔽回避・Codex 落とし穴1）。両 opt-in
default=従来＝behavior-preserving。run_id 化は Out-of-scope（limitation 明記）。

## Estimation
Risks: 実 violation 誤除外（緩和: 構造化キー限定・曖昧残置）/ period 破壊
（緩和: opt-in・2期間 in-place 等価）/ Unknowns: なし
