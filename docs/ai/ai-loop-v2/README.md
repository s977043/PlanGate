# ai-loop V2

> **Status**: Phase 0 **MERGED**（PR #1273・Human C-4 DONE）/ Independent Review **PENDING（separate checker required）** / Phase 0.1 **CANON_HARDENING**（#1275）
> **North Star**: [`north-star.md`](./north-star.md)
> **Migration**: [`phase0-migration.md`](./phase0-migration.md)

ai-loop V2 は、既存 ai-loop の増築ではなく、**Verifier-driven Delivery Loop + Evidence-driven Evolution Loop** として再構築する。

このディレクトリは V2 の思想・境界・移行判断の正本を置く。既存 `docs/ai/ai-loop/` と `docs/workflows/ai-loop/` は PoC / Legacy evidence として保持し、V2 へ暗黙継承しない。

## 参照順

V2 の Issue / Plan / PR は次の順に参照する。

1. [`north-star.md`](./north-star.md) — 目的、不変原則、自己進化境界
2. [`phase0-migration.md`](./phase0-migration.md) — Legacy freeze と既存資産の移行分類
3. Phase 0.1 canon（#1275）
   - [`taxonomy.md`](./taxonomy.md) — Lifecycle State / Terminal Outcome / Stop Reason / Policy Verdict の 4 軸
   - [`harness-manifest.md`](./harness-manifest.md) — Harness identity と Runtime Activation 6 段階
   - [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) — Candidate 不可侵 authority / Independence Level / `INCONCLUSIVE`
   - [`artifact-responsibilities.md`](./artifact-responsibilities.md) — artifact 責務分離 / event projection / revision CAS
4. Phase 1 以降で作る Architecture / Contract / State / Verification 文書

## Phase 0 / 0.1 rule

Phase 0 / 0.1 中は V2 実装を開始しない。North Star と移行境界、次いで語彙・identity・Trust Boundary を先に固定し、その後の設計・Issue 分割を North Star に照らしてレビューする。

## Legacy との関係

`docs/ai/ai-loop/**` と `docs/workflows/ai-loop/**` は Legacy / PoC / Evidence。V2 namespace から参照する場合は `evidence` / `reusable pattern` として扱い、V2 North Star と矛盾する箇所では Legacy を V2 の正本にしない。
