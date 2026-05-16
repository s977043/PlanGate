---
task_id: TASK-0072
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3 外部レビュー — TASK-0072

critical モードのため V-3 必須。Codex + Gemini を独立実行。**判定が割れた**。

## 判定: Codex=REJECT(Critical2) / Gemini=APPROVE → critical をブロッカー採用し fix-loop

Codex の Critical #1 は設計の本質的欠陥（Gemini は見落とし）。critical-mode
core-contract 変更のため、保守的かつ正しく critical 指摘を修正してから完了とする。

## Critical（Codex・修正必須）

| # | 指摘 | 修正 |
|---|------|------|
| CR-1 | preflight 主体が誤り。conductor は**既に subagent**として起動後に Task 不可を検知しても自らメインへ移す手段がない→デッドロック本質が残る。判定は conductor 起動**前**の exec router（`/ai-dev-workflow exec`）に置くべき | `.claude/commands/ai-dev-workflow.md` の exec router に capability preflight を定義。conductor は「委譲可能時のみ router が起動する」構造へ。conductor.md から「conductor がメインへ移す」含意を削除 |
| CR-2 | ツール名不整合。conductor frontmatter は `Agent` 許可だが差分は `Task` 可否で判定。実ツール名と契約のズレで存在検査が誤判定→フォールバック過剰発火 | 「サブエージェント起動（`Agent`/`Task`）の利用可否」に統一表記し、命名差の注記を追加 |

## Major（Codex）

| # | 指摘 | 修正 |
|---|------|------|
| MJ-1 | 「直接 Implementer 実行」が曖昧。implementer.md は単一タスク前提。直接実行時の runner 責務（タスク分割/依存順/status/todo/L-0/V-1/V-3/PR）未定義 | core-contract §5-bis に direct-implementer-mode の runner 責務を明文化 |
| MJ-2 | §5-bis「人間介入不要」が強すぎ。C-3/plan_hash/allowed_files/scope停止/C-4 維持を §5-bis 自体に明記しないと統制回避の口実 | §5-bis に「direct mode でも C-3/plan_hash/allowed_files/todo/status/V-gates/C-4 は不変」を明記 |
| MJ-3 | conductor.md 内で「どんな小さい修正でも委譲」と「委譲不可なら直接実行」が衝突 | 「conductor 自身は直接実装しない／router が conductor-mode と direct-implementer-mode を選ぶ」境界に書き換え |

## Minor

- taxonomy「判定不能」と「不可」の同一扱い理由を短く残す（監査性）
- AGENT_LEARNINGS.md:59 の旧学び「top-level 前提・メイン代行」を本 PR で更新（古い学びが新 contract を上書きする抜け穴）

## Gemini（APPROVE・補強）

- §5-bis を実行不変条件へ昇格した点を高評価。Iron Law 非侵害を確認
- 直接実行で並列性が失われる性能低下はデッドロック停止より遥かに許容可能
- preflight をツール存在検査にした堅牢性を評価（ただし CR-1 の主体問題は未指摘）

## 対応

fix-loop で CR-1/CR-2/MJ-1/MJ-2/MJ-3 + Minor 2 を反映 → 再 V-1 → 再 push。

## 出典

- Codex: /tmp/t0072-codex-v3.md（REJECT）
- Gemini: /tmp/t0072-gemini-v3.md（APPROVE）
