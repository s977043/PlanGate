# EXECUTION TODO — TASK-0871

> mode: high-risk（実装タスクは rollback 必須）。L-0〜V-4・PR 作成は
> workflow-conductor が自動制御するため本 todo に含めない。

## 準備フェーズ

- [ ] T-01 矛盾一覧の確定監査（plan 付録 A/B の rg を実行し evidence 保存。
  あわせて `gh issue view 871 --json body` の**成功ログを evidence 化**し、
  issue 原文の独立照合を可能にする — C-2 R-001 反映）
  - Owner: agent / depends_on: なし
  - files: `docs/working/TASK-0871/evidence/verification/terminology-audit.md`,
    `docs/working/TASK-0871/evidence/verification/issue-871-fetch.log`
  - rollback: 不要（読取・evidence 追加のみ）
- [ ] T-02 HO 対象パス突合（touch 予定ファイルを `scripts/hooks/check-plan-hash.sh` の HO パターンと照合し、S6 の適用方式を確定）
  - Owner: agent / depends_on: T-01
  - files: （読取のみ）
  - rollback: 不要

## 実装フェーズ

- [ ] T-03 `rollout-policy.md` 新設（00_concept 冒頭「Phase 1: 導入先適用」節と lite/clean/reversible 条件・auto-approve 方針・不変条件を移設）
  - Owner: agent / depends_on: T-02
  - files: `docs/workflows/ai-loop/rollout-policy.md`
  - rollback: `git revert <commit>`（新規 1 ファイルのため削除で完全復元）
- [ ] T-04 `00_concept.md` 正本化再構成（正本宣言 / 5 責務表〔Core・ai-dev・Delivery・Evolution・Human〕/ terminal state 定義〔PR_CREATED / MERGE_READY / MERGED + 判定主体〕/ C-3'=標準・Human C-3=escalate の経路定義 / 裁定状態と Delivery 状態の区別 / 内外 Loop 区別 / active run harness 自己変更禁止 / Phase 1 節を rollout-policy 参照 1 行へ）
  - Owner: agent / depends_on: T-03 / 🚩 完了時 diff を Human に提示
  - files: `docs/workflows/ai-loop/00_concept.md`
  - rollback: `git revert <commit>`（本タスクを単一 commit に閉じる）
- [ ] T-05 周辺 docs 参照整合（six-stage / adaptive / flow-detect / stop-rollback / loopspec / execution-runbook の責務・terminal state 重複を正本参照へ削減。差分が出るもののみ）
  - Owner: agent / depends_on: T-04
  - files: `docs/workflows/ai-loop/*.md`
  - rollback: `git revert <commit>`
- [ ] T-06 Core Contract 整合（§1-bis に ai-loop 実行プロファイル時の AI 責務終点 = merge-ready と正本参照を追記。Iron Law / Stop rules 本文は不変）
  - Owner: agent / depends_on: T-04 / 🚩 CLAUDE.md 参照系。diff 提示・Human 確認
  - files: `docs/ai/core-contract.md`
  - rollback: `git revert <commit>`
- [ ] T-07 command / skill 整合（`.claude/commands/ai-loop-workflow.md`〔HO 対象〕と `.agents/skills/ai-loop-cycle/SKILL.md`、および **`.claude/skills/ai-loop-cycle/SKILL.md`〔repo ローカル実行版・HO 外・AI 編集可。C-2 R-007 反映。並存解消方針は plan Q5 = C-3 確定〕** の PoC 表現を「恒久定義=正本参照 / 適用制限=rollout-policy 参照」に分離）
  - Owner: agent（diff 作成まで）+ human（HO 対象の適用判断） / depends_on: T-04 / 🚩 HO 接触: Human 承認前に commit しない
  - files: `.claude/commands/ai-loop-workflow.md`, `.agents/skills/ai-loop-cycle/SKILL.md`, `.claude/skills/ai-loop-cycle/SKILL.md`
  - rollback: `git revert <commit>`。Human 手適用分は Human が同 diff の逆適用で戻す
- [ ] T-08 plugin sync 整合（`sh scripts/sync-plugin-plangate.sh` を dry-run し references 同梱差分を確認。差分があれば同期し、正本に同期関係を明記。**sync スクリプト内コメントの stale 数値「17 本」〔実態 12 本〕は数値レス化 or 採否理由記録 — C-2 R-009 反映**）
  - Owner: agent / depends_on: T-05, T-06, T-07（plan の (S4∥S5∥S6)→S7 と一致 / C-1 F-4 反映）
  - files: `plugin/` 配下（sync スクリプト経由のみ）
  - rollback: `git revert <commit>`（sync 再実行で再現可能）

## 検証フェーズ

- [ ] T-09 link check + markdownlint（C-2 R-005 反映・コマンド/条件を固定）
  - 対象: `git diff --name-only origin/main...HEAD -- '*.md'` の全件
  - コマンド: リポジトリ CI と同一（`.github/workflows/` の markdownlint /
    link check job 定義から実行コマンドを抽出・転記して使用。抽出結果も
    evidence に含める）
  - PASS 条件: **exit code 0**（両チェックとも）
  - ログ保存先: `docs/working/TASK-0871/evidence/verification/lint-linkcheck.log`
  - Owner: agent / depends_on: T-08 / files: evidence のみ
  - rollback: 不要
- [ ] T-10 用語監査の再実測（plan 付録 B 全コマンド。旧定義残は採否理由を evidence 化）
  - Owner: agent / depends_on: T-09
  - files: `docs/working/TASK-0871/evidence/verification/`
  - rollback: 不要
- [ ] T-11 sync dry-run 差分ゼロの最終確認（evidence 保存）
  - Owner: agent / depends_on: T-10 / rollback: 不要
- [ ] T-12 独立レビュー（maker と別コンテキストで責務境界・C-3/C-3'・terminal state 矛盾 0 件を確認、記録）
  - Owner: agent（別コンテキスト） / depends_on: T-11 / 🚩 矛盾 >0 は T-04〜T-07 へ差し戻し
  - rollback: 不要

## 完了フェーズ

- [ ] T-13 AC-1〜AC-10 突合表を evidence 化し current-state / status 更新。
  **H-01 で確定した AC-9 スコープ限定・#866 別トラック化の承認結果を
  issue #871 コメントと `evidence/` の双方に記録する（C-2 R-002/R-003 反映）**
  - Owner: agent / depends_on: T-12, H-01 / rollback: 不要

## 👤 Human タスク

- [ ] H-01 C-3 ゲート（同期・必須）: plan / todo / test-cases 承認、**Q1〜Q6 の確定**
  （Q4: AC-9 スコープ限定の明示承認 / Q5: `.claude/skills/ai-loop-cycle` 並存の扱い /
  Q6: rollout-policy 配布形態）、`approvals/c3.json` 発行。
  **承認結果（特に Q4 の scope 限定）は issue #871 へ scope 注記コメントとして残す**（C-2 R-002/R-003）
  - depends_on: C-1/C-2 完了
- [ ] H-02 T-07 の HO 対象ファイル適用判断（AI diff の採否）
  - depends_on: T-07 diff 提示
- [ ] H-03 C-4 PR レビュー・merge（Human-owned 固定）

## ⚠️ 依存関係

- T-03〜T-08 は H-01（C-3 APPROVED）まで着手不可（Iron Law #1）
- T-07 は H-02 なしに完了扱いにしない（HO 常時 block 運用）
