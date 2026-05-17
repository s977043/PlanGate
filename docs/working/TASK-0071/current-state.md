# TASK-0071 現在状態

> 更新: 2026-05-17 / フェーズ: 完了クローズ

## 完了

Governance Hardening 親 PBI。D-1 で S1+S2/S3/S4 の3分割を C-3 決定し全実装:
- S1+S2 = TASK-0080 / PR #254 MERGED（Shadow Config 恒久対処）
- S4 = TASK-0081 / PR #256 MERGED（責務4分類正本）
- S3 = TASK-0082 / PR #257 MERGED（EH-3 メンテ+SKIP_REASON）

親 handoff 発行済。本 PBI は完全クローズ。

## 残（ユーザー操作・別トラック）

- `sh scripts/apply-claude-settings.sh` で AC-8/EH-9 wiring 実適用
- skip-ack / settings-drift の ruleset required 化（Human-owned）
