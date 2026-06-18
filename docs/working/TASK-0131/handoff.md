# HANDOFF — TASK-0131 (#565)

> 生成: 2026-06-18T22:18:58Z / exec（C-3 APPROVED・high-risk・HO 含む）

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-01 | rollback 規約を正本に明文化（working-context + ai-dev-plan SKILL 双方） | **PARTIAL** | ai-dev-plan SKILL（正本+2ミラー）反映済。working-context.md は **HO のため apply-script 生成（人間適用待ち）** |
| AC-02 | mode 別 必須/任意ルール | PASS | high-risk/critical 必須・standard 任意・検証/読取のみ rollback:不要 を SKILL に明記 |
| AC-03 | 記入サンプル | PASS | TASK-0131/todo.md 各タスクに rollback: 記載済（PR #568 で確立） |
| AC-04 | 正本+ミラー整合 | PASS | ai-dev-plan 3 ファイル diff 一致（working-context は apply 後に完全一致） |
| AC-05 | C-1 が rollback 欠落検出 | PASS | plan-quality-check 補足2 + review-self C1-TODO-RB（high-risk/critical 欠落→FAIL） |

## 2. 既知課題一覧
- **AC-01 完全達成は working-context.md への HO 適用後**。`sh scripts/apply-task-0131-rollback.sh`（人間）実行で解消。settings タスクロックと同型（HO 適用前は V-1 完全 PASS にしない）。

## 3. V2 候補
- rollback の機械検証を bin/plangate validate に組み込む（現状は規約 + C-1 観点）。

## 4. 妥協点
- working-context.md は HO のため AI 直接編集せず apply-script 化（責務4分類: HO 適用は Human-owned）。
- ai-dev-plan SKILL は .claude/skills に実体が無く、正本 .agents + .codex + plugin の 3 ファイル構成（既存実態に従う）。

## 5. 引き継ぎ文書（サマリ）
todo.md の各タスクに rollback（戻し手順）を記す規約を ai-dev-plan SKILL（正本+2ミラー）に明文化し、high-risk/critical で必須化。C-1（plan-quality-check + review-self C1-TODO-RB）で rollback 欠落を検出。working-context.md（HO）への同規約反映は apply-script を生成済（人間適用待ち）。

## 6. テスト結果サマリ
- ai-dev-plan 3 ミラー rollback 規約一致 / plan-quality-check 補足2 / review-self C1-TODO-RB + 6項目: 全 PASS
- working-context.md(HO) 未編集を確認（apply-script のみ）/ apply-script 構文 OK
- markdownlint: CI 委譲
