# PBI INPUT PACKAGE — TASK-0871 正本定義統合・PoC 制約分離

> 出典（一次ソース）: GitHub issue [#871](https://github.com/s977043/plangate/issues/871)
> （2026-07-19 `gh issue view 871 --json body` で取得した本文を構造化）
> 親 EPIC: [#870](https://github.com/s977043/plangate/issues/870)（ai-dev / ai-loop 統合実行契約）
> EPIC 内の位置づけ: 第 1 子。「#871 で責務と状態語彙を固定」してから #872/#873 を並行実装する起点。

## Context / Why

現行の `docs/workflows/ai-loop/00_concept.md` には「ai-dev は PR 作成まで、ai-loop は
merge-ready まで」「C-3 のみ C-3' へ置換」が記載されている。一方、command
（`.claude/commands/ai-loop-workflow.md`）/ skill（`ai-loop-cycle`）/ Core Contract
（`docs/ai/core-contract.md`）/ six-stage 文書には、独立 PoC、Human C-3 固定、
PlanGate と ai-dev の語彙混在が残る。

恒久的なアーキテクチャ定義と、Phase 1 の適用制限が同じ節で扱われているため、
実装判断の基準が一意でない。

## 目的

PlanGate Core、ai-dev、ai-loop Delivery、ai-loop Evolution、Human Gate の責務と
終端状態を一つの正本へ統合し、PoC の rollout policy を別レイヤーへ分離する。

## What（Scope）

### In scope

- 正本となる architecture / responsibility document を一つ指定する
- `PR_CREATED`、`MERGE_READY`、`MERGED` の意味と判定主体を定義する
- ai-dev の AI 責務終点を PR 作成、ai-loop の AI 責務終点を merge-ready とする
- C-3' を eligible run の標準自動経路、Human C-3 を escalate 経路として定義する
- C-4 / merge / HO / policy / first principles は Human-owned に固定する
- Stable architecture と Phase 1 rollout policy（lite / clean / reversible）を別節または別文書にする
- 既存文書は新しい正本を参照し、責務・terminal state・decision table の重複定義を削減する
- plugin 同梱 references と正本の同期関係を明示する

### Out of scope（Non-goals / issue #871 準拠 + 本 plan での限定）

- C-3' arbiter や PR controller の実装
- lite 適用範囲の拡大
- C-4 / merge の自動化
- 文書階層全体の一括移動・改名
- **issue #866（intent-classifier / skill-policy-router の skills 正本三つ巴矛盾）は
  本 TASK のスコープ外・別トラック**。AC-9「正本一覧に同じ責務の複数正本が残って
  いない」の対象は ai-dev / ai-loop のアーキテクチャ・責務定義文書に限定する
  （理由: #866 のドメインは skills sync 機構側で、修正経路も sync スクリプト設計
  判断を伴うため。EPIC #870 でも #862/#866 は「前提」扱いの別 issue）

## 受入基準（issue #871 Acceptance Criteria・10 項目）

- AC-1: `PlanGate Core`、`ai-dev`、`ai-loop Delivery`、`ai-loop Evolution`、`Human` の 5 責務が定義されている
- AC-2: `ai-dev: Request → PR_CREATED`、`ai-loop: Request → MERGE_READY`、`Human: C-4 → MERGED` が明記されている
- AC-3: ai-loop が ai-dev の Plan / exec / verify を再実装せず共通利用することが明記されている
- AC-4: C-3 と C-3' の通常経路・escalate 経路・判定主体が矛盾なく定義されている
- AC-5: architecture invariant と rollout eligibility policy が分離されている
- AC-6: `AUTO_APPROVED` 等の裁定状態と `MERGE_READY` 等の Delivery 状態が区別されている
- AC-7: 内側の Delivery Loop と外側の Evolution Loop が区別されている
- AC-8: active run の harness 自己変更禁止と、改善を別 TASK / PR で行う規則が記載されている
- AC-9: 正本一覧に同じ責務の複数正本が残っていない（対象: ai-dev / ai-loop のアーキテクチャ・責務定義文書）
- AC-10: `.claude/commands/ai-loop-workflow.md`、`ai-loop-cycle`、`00_concept.md`、`agentic-six-stage-loop.md`、`adaptive-production-loop.md`、Core Contract の参照が整合している

## Verification（issue #871 準拠）

- 文書リンクチェックが PASS する
- `rg` 等による用語監査で、旧定義・矛盾表現が残る場合は一覧と採否理由が evidence にある
- plugin sync dry-run（`sh scripts/sync-plugin-plangate.sh` dry-run）が差分ゼロになる
- maker とは別コンテキストのレビューで、責務境界・C-3/C-3'・terminal state の矛盾が 0 件である

## Definition of Done / Close 条件（issue #871 準拠）

- 上記 Acceptance Criteria がすべて checked
- 正本を変更する PR が main へ merge 済み
- PR 本文または Issue コメントに link check、sync dry-run、独立 review の evidence がある
- #870 から本 Issue の成果物が canonical definition として参照されている
- 設計案のみ、未 merge の PR、矛盾一覧だけでは close しない

## Notes from Refinement

- EPIC #870 の責務境界表（PlanGate Core / ai-dev / ai-loop Delivery / ai-loop
  Evolution / Human、AI 責務終点 PR_CREATED / MERGE_READY / 改善 PR の
  MERGE_READY / MERGED）を正本文書へ転記・確定する
- 実装対象は文書（doc）だが、承認境界周辺パス（`.claude/commands/*.md`・
  `docs/ai/core-contract.md`＝CLAUDE.md 参照系）に touch するため
  mode-classification 例外ルールにより doc-light は適用不可・最低 high-risk

## Estimation Evidence

- Risks: 承認境界周辺（HO 対象 `.claude/commands/*.md`）の編集は
  会話内承認があっても AI 編集不可の運用（HO 常時 block）があり、
  該当 1 ファイルの適用は Human 手または明示承認フローが必要になり得る
- Unknowns: core-contract.md への追記量（§1-bis へ ai-loop 終点の追記 or
  参照 1 行のみで足りるか）は C-3 で確定
- Assumptions: 既存 `00_concept.md` の記載（§2/§3.3 の責務表）は EPIC #870 の
  統合定義と概ね一致しており、再構成＋分離で成立する（全面書き直し不要）
