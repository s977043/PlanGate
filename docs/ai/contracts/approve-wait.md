# Phase Contract: approve-wait

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ
> **AI 出力なし** — ユーザー承認待ち phase

## Goal

C-3 / Parent C-3 / Child C-3 ゲートの **人間判断を待つ**。AI は本 phase で write tool を一切使わない。

## Success criteria

- `approvals/c3.json` に `c3_status: APPROVED` または `CONDITIONAL` または `REJECTED` が記録される
- `plan_hash` が記録され、後続の整合性検証に使われる

## Stop rules

- AI が誤って write tool を起動 → Hook で即 block（[`hook-enforcement.md`](../hook-enforcement.md) EH-2）
- 承認なしに次 phase へ進もうとした → block

## Output discipline

- AI 出力なし（待機状態）
- ユーザー入力（APPROVED / CONDITIONAL / REJECTED）のみ

## verbosity 不適用

Prompt Assembly の verbosity 解決では本 phase は **不適用**（[`prompt-assembly.md`](../prompt-assembly.md) § 4 schema 互換参照）。

## 関連

- [`tool-policy.md`](../tool-policy.md) — approve-wait phase で write 全禁止
- [`schemas/c3-approval.schema.json`](../../../schemas/c3-approval.schema.json)
