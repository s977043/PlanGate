# Phase Contract: verify

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ
> Prompt Assembly で `review` から分離独立化（[`core-contract.md`](../core-contract.md) v1 では review に包含）

## Goal

`test-cases.md` の各 TC を実行し、**受入基準（AC）と機械突合** する。V-1 受け入れ検査。

## Success criteria

- 全 TC が PASS / WARN / FAIL / SKIP のいずれかに判定
- AC × TC マトリクスが [`schemas/acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json) 準拠
- fix loop は最大 5 回（超過時 ABORT、[`hook-enforcement.md`](../hook-enforcement.md) EHS-3）

## Stop rules

- TC FAIL の root cause 不明 → 停止
- fix loop が 5 回超過 → ABORT、ユーザー判断にエスカレーション
- test-cases.md なしで進行しようとした → block（EH-4）
- 検証ログなしで PR 作成しようとした → block（EH-5）

## Output discipline

- `evidence/verification.md` または `evidence/v1-acceptance-result.md`
- acceptance-result.json（schema 準拠、任意）

## verbosity 継承

Prompt Assembly の verbosity 解決では本 phase は **`review` の verbosity を継承**（[`prompt-assembly.md`](../prompt-assembly.md) § 4 schema 互換参照）。

## 関連

- [`schemas/acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json)
- [`docs/ai/structured-outputs.md`](../structured-outputs.md) — V-1 出力の schema 化方針
