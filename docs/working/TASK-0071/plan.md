---
task_id: TASK-0071
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0071 Governance Hardening

## Goal

AI 不可侵領域（settings 自己改変 / merge）を「例外的回避対象」から
「正式なワークフロー責務分界」へ転換し、Shadow Configuration と
heredoc 回避を構造的に解消する。

## Constraints / Non-goals

- sockpuppet 禁止・self-mod ガードは恒久制約として受容（回避実装はしない）
- merge 自動化は Non-goal（Human-owned に固定）
- EH-3 の C-3 ハッシュ強制力（plan.md 保護）は弱めない
- 既存 hook テスト 60 件に回帰を出さない

## Approach Overview

4 サブシステムを段階導入。S1→S2 を先行（即効性・低リスク）、S3 を設計重め、
S4 を全体の正本化として最後に締める。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1a | settings パッチ正本配置（templates/ or docs/ai/）+ 適用 script | apply script | agent | med | - |
| S1b | `bin/plangate doctor --check-settings` 実装（wiring 適用判定, 非0 fail） | doctor 拡張 | agent | high | 🚩AC-2 |
| S1c | タスクロック: doctor 未PASSで handoff/V-1 完了不可（workflow + hook） | ロック機構 | agent | high | 🚩AC-3 |
| S2 | CI に settings drift check（wiring + schema 不整合）required 追加 | workflow yaml | agent | med | 🚩AC-4 |
| S3a | EH-3 メンテモード/除外タグ設計（有効期限・粒度の意思決定） | design note | agent | crit | 🚩設計レビュー |
| S3b | SKIP_REASON 強制記述 + C-3/C-4 追認証跡 | hook + workflow | agent | high | 🚩AC-6 |
| S4 | 責務 4 分類を rules 正本化（AI/Human/CI/Workflow-owned） | .claude/rules | agent | low | 🚩AC-7 |
| V | 全 hook テスト回帰 + V-3 外部レビュー（Codex+Gemini）+ V-4（critical） | テスト/レビュー | agent | high | - |

## Files / Components to Touch（想定・plan 段階の仮）

- `bin/plangate`（doctor --check-settings サブコマンド）
- `scripts/`（settings 適用 script, drift check）
- `scripts/hooks/check-plan-hash.sh`（メンテモード/除外タグ, SKIP_REASON）
- `.github/workflows/`（drift check required）
- `.claude/rules/`（責務 4 分類正本）
- `docs/ai/` or `templates/`（settings パッチ正本）
- `tests/hooks/run-tests.sh`（回帰 + 新規）

## Testing Strategy

- Unit/Behavior: doctor --check-settings の適用/未適用判定、drift 検出
- Contract: PLANGATE_HOOK_FILE 優先, stdin key 解決, jq なし fallback
- 回帰: 既存 60 hook テスト全 green 維持
- Integration: タスクロック（未適用で handoff 完了不可）E2E
- CI: drift check が required failure になることを PR で実証

## Risks & Mitigations

- R1: doctor の適用判定誤検出 → settings の正規表現でなく構造（jq）で判定
- R2: メンテモードが新たなバイパス経路化 → 有効期限 + 監査ログ + C-3/C-4 追認必須
- R3: タスクロックが正常作業を阻害 → bypass（PLANGATE_BYPASS_HOOK）と整合・文書化
- R4: スコープ過大 → S1/S2 と S3/S4 を別 PR に分割可能な設計

## Questions / Unknowns

- メンテモードの有効期限既定値・付与権限（C-3 で意思決定）
- 除外タグの粒度（ファイル単位 / TASK 単位）
- S1〜S4 を 1 PBI 1 PR か、S1+S2 / S3 / S4 に分割するか（C-3 判断）

## Mode判定

**モード**: critical

**判定根拠**:
- 変更ファイル数: 7+（CLI/hook/CI/rules/docs/tests） → 超高
- 受入基準数: 8 → 高
- 変更種別: 強制力の意味的変更 + ワークフロー定義変更 + 横断 → アーキ変更
- リスク: 極高（強制 Hook とガバナンス責務分界の再定義）
- 例外ルール: セキュリティ/強制力関連 → 最低中、本件は横断アーキで critical
- **最終判定**: critical（C-2/V-3/V-4 必須、S1+S2 / S3 / S4 の PR 分割を強く推奨）
