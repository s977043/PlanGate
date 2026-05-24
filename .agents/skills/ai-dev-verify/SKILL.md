---
name: ai-dev-verify
description: "PlanGate の V-1〜V-4 受け入れ検査と handoff.md 発行を行う。Use when: exec 完了後に受け入れ検査を実行し PR 準備したい時。"
---

# AI-Driven Verify (PlanGate / Codex 共用)

PlanGate ワークフローの **verify & handoff フェーズ（WF-05）** を Codex / Claude Code 両方で実行する skill。Rule 5（最終成果物は毎回 handoff に集約）を担保する。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（handoff 必須化・6 要素・settings タスクロックの正本）
4. `.claude/rules/hybrid-architecture.md`（Rule 5）
5. `.claude/rules/review-principles.md`（V-3 外部レビュー観点）
6. `.claude/rules/mode-classification.md`（V-2/V-3/V-4 の mode 別適用）
7. `docs/working/TASK-XXXX/plan.md` / `test-cases.md` / `status.md`
8. `docs/working/templates/handoff.md`（handoff.md 6 要素の正本テンプレート）

## V-1〜V-4 の概要

mode 別の適用範囲は `.claude/rules/mode-classification.md` フェーズ適用マトリクスを正本とする。各フェーズの趣旨:

- **V-1 受け入れ検査**: test-cases.md の各 AC を機械的に PASS/FAIL 突合（推測ではなく実行結果のみ）。FAIL は exec へ差し戻し。evidence: `evidence/test-runs/`, `evidence/verification/`。
- **V-2 コード最適化** (high-risk / critical): 動作不変で可読性・効率性改善。テスト再実行で回帰なしを保証。
- **V-3 外部モデルレビュー** (standard 以上): 5 観点 + Severity 判定。R-NNN 採番で `review-external.md` 追記専用。
- **V-4 リリース前チェック** (critical): ドキュメント整合 / マイグレーション / ロールバック / セキュリティ。

## settings タスクロック（V-1 / handoff 完了の前提条件）

`bin/plangate doctor --check-settings` PASS を **V-1 / handoff 完了の前提**として要求（`.claude/rules/working-context.md` 正本）。未配線時は **Shadow Configuration 防止**のため handoff を完了扱いにできない。settings 適用は Human-owned（`sh scripts/apply-claude-settings.sh` を Human が実行）。

## handoff.md 発行（必須・Rule 5）

`docs/working/templates/handoff.md` を雛形に発行。**6 要素の正本**は `.claude/rules/working-context.md` の「handoff（WF-05 完了資産 / Rule 5）」節および `docs/working/templates/handoff.md` を参照。light モード以下で簡易版を採用する場合も本テンプレートを踏襲（該当なしは「該当なし」明記）。PR マージ後も削除しない（完了資産）。

## Output

- `docs/working/TASK-XXXX/handoff.md`（6 要素必須）
- `docs/working/TASK-XXXX/evidence/` 追記
- `docs/working/TASK-XXXX/status.md` 追記（V-1〜V-4 結果サマリ）

## CLI 呼び出し

- V-1 機械検証: `bin/plangate validate TASK-XXXX`
- V-3 外部 AI レビュー: `bin/plangate review TASK-XXXX --phase v3`
- settings 検証: `bin/plangate doctor --check-settings`
- 8 観点 eval: `bin/plangate eval TASK-XXXX`
- metrics 収集: `bin/plangate metrics TASK-XXXX --collect|--report`

> **handoff.md 発行コマンドは未実装**。skill 利用者が `docs/working/templates/handoff.md` をコピーし手動で 6 要素を記載する。

## 次フェーズへ

handoff 完了後は PR 作成 → C-4 ゲート（GitHub 上の人間レビュー）→ マージ。
