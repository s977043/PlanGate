# PBI INPUT — TASK-0105 / #282 check-plan-hash.sh 不正JSON strict 化

## Context / Why
ユーザーが「EH-3 承認境界変更として #282 着手」を明示承認（Human トリガ）。
TASK-0100 実証検証で判明: check-plan-hash.sh の寛容 sed 抽出は不正 JSON の
c3.json でも plan_hash を抽出し承認判定の入力健全性を損なう。strict 化で
不正記録を承認境界の根拠にしない安全側へ。

## What
- In: scripts/hooks/check-plan-hash.sh（sed→strict python heredoc・
  plan_hash_util と意味一致）/ tests/extras/ta-11（phc_shell 実抽出化・
  malformed を parity assert）/ docs/ai/hook-enforcement.md（注記）
- Out: EH-3 の block/warn 判定ロジック / plan_hash 形式 / c3 schema /
  Python util 側（#276 確定）変更 / shell 全面 Python 化

## 受入基準（#282）
- AC1: check-plan-hash.sh が不正JSON で plan_hash を寛容抽出せず strict
  （plan_hash_util と同一挙動）
- AC2: ta-11 が 正常/注入/無/不正JSON すべて shell≡python parity・PASS
- AC3: EH-3 既存 block/warn（正常PASS・改竄BLOCK・no-task SKIP）回帰なし
  （run-tests 全 PASS）
- AC4: python3 依存の可搬性確認（同フック :108 で既出＝新規依存なし）
- AC5: 承認境界がより厳格化＝安全側であることを hook-enforcement.md に明記

## Notes
Human トリガ承認済。承認境界変更（より厳格＝安全側）。PR 本文に
承認境界変更/Human review required 明記。正常系・改竄検知の挙動不変。

## Estimation
Risks: 既存 block/warn 回帰（緩和: 実リポジトリ検証 a/b/c + ta-11 4/4 +
run-tests 68/0）/ python 不在（緩和: :108 既出依存）/ Unknowns: なし
