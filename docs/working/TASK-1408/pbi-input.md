# PBI INPUT PACKAGE: canon I1 例外の失効を記録し I4 へ移行する（#1408 + #1329）

> **状態: Human 確定（2026-11-07、C-3 CONDITIONAL）**。受入基準とスコープはこの内容で確定した。
> 基準: `origin/main` = `9445df17`（2026-11-06 実測）。

## Context / Why

`docs/ai/ai-loop-v2/phase0-migration.md` §7 は、canon 7 本の独立レビュー要求 I1 を「実行系が無い間の明示的例外」とし、M-1 / M-2 / M-3 のいずれかが baseline から動いたら失効すると定めている。PR #1402（merge `3331e5c49751b268412d4db8e5862982ac0005d8`、2026-09-29）で `scripts/ai-loop-v2/**` が入り M-2 が動いたが、失効はまだ §7 に記録されていない。

**Human の決定**: #1408 と #1329 を統合し critical 扱いとする。失効記録自身にも I4（Human C-4 + 機械証跡）を適用する。

- Discovery depth: expanded
- PBI author: ai（Human 決定に基づく下書き）
- Application timing: follow_up
- Target layer: harness

## What（Scope）

### In scope

- §7 への失効記録（失効日、動いた条件、実測出力、遡及しないこと、以後 I4）
- Phase 1 exit criteria への canon 7 I4 レビュー項目の追加
- #1329 残指摘 #2 / #4 / #5 の裁定の記録
- AC-4 の置き場所の確定
- 本 PR の I4 証跡

### Out of scope

- `evaluation-trust-boundary.md` §3 / §4 の規定変更
- #1402 自身や runtime の正しさの判定
- baseline へのファイル追加（例外の延命になる）
- Phase 0 / 0.1 の I1 充足の遡及的な作り直し
- 失効後に merge 済みの canon 差分の再レビュー（#1643）
- #1374 の Stage A / canary の実行

## 受入基準

### #1408

- [ ] 1408-AC-1: #1402 merged SHA を一次証拠として記録
- [ ] 1408-AC-2: M-2 post-merge positive control を記録
- [ ] 1408-AC-3: exception expiry を明記
- [ ] 1408-AC-4: future canon normative changes = I4 を明記
- [ ] 1408-AC-5: historical Phase 0/0.1 I1 review は遡及無効化しない
- [ ] 1408-AC-6: separate review + machine evidence
- [ ] 1408-AC-7: Human-authorized C-4 merge

### #1329

- [ ] 1329-AC-1: M-1 / M-2 / M-3 の再測定を実施し、実測出力を記録
- [ ] 1329-AC-2: 動いた条件が 1 件以上なので「失効」を §7 に明記
- [ ] 1329-AC-3: Phase 1 exit criteria に canon 7 本の I4 レビュー項目が 1 行存在
- [ ] 1329-AC-4: canon 7 本を変更する PR の再測定タイミングの置き場所が 1 つに決まっている
- [ ] 1329-AC-5: 残指摘 2 / 4 が解消または「対応しない」と裁定されている

## Notes from Refinement

- #1408 Safety: #1402 から canon を変更しない（実測で差分なし）、baseline を延命しない、runtime の正しさと governance 記録を混ぜない。
- #1329 本文の Phase 1 operational invalidation gate は AC-4 を implementation PR checklist + review gate と定める。

## Estimation Evidence

### Risks

- 失効後に merge された canon 差分（最大の新規発見。plan.md Q-1）の扱いを誤ると、記録が事実を隠すことになる。
- 記録自身の I4 充足を記録が自己宣言すると循環する。

### Unknowns

plan.md の Questions を参照。

### Assumptions

- Human C-4 の定義は `docs/working/_reports/1275-phase0-01-evidence-audit.md` §3（Human による merge 操作）に従う。
