---
name: ai-dev-verify
description: "PlanGate の V-1〜V-4 受け入れ検査と handoff.md 発行を行う。Use when: exec 完了後に受け入れ検査を実行し PR 準備したい時。"
---

# AI-Driven Verify (PlanGate / Codex 共用)

PlanGate ワークフローの **verify & handoff フェーズ（WF-05）** を Codex / Claude Code 両方で実行する skill。Rule 5（最終成果物は毎回 handoff に集約）を担保する。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（handoff 必須化・6 要素）
4. `.claude/rules/hybrid-architecture.md`（Rule 5）
5. `.claude/rules/review-principles.md`（V-3 外部レビュー観点）
6. `.claude/rules/mode-classification.md`（V-2/V-3/V-4 の mode 別適用）
7. `docs/working/TASK-XXXX/plan.md` / `test-cases.md` / `status.md`
8. `docs/working/templates/handoff.md`

## V-1 受け入れ検査（必須）

- test-cases.md の各 AC を機械的に PASS/FAIL 突合
- 推測ではなく**実行結果のみで判定**
- FAIL があれば exec へ差し戻し（修正後再検査）
- evidence: `evidence/test-runs/`, `evidence/verification/`

## V-2 コード最適化（high-risk / critical のみ）

- 動作を変えずに可読性・効率性を改善
- テスト再実行で回帰がないことを保証

## V-3 外部モデルレビュー（standard 以上）

- 5 観点（可読性 / 拡張性 / Perf / Security / 保守性）+ Severity 判定
- 指摘は R-NNN 採番、`review-external.md` に追記専用
- critical / major は修正必須

## V-4 リリース前チェック（critical のみ）

- ドキュメント整合 / マイグレーション計画 / ロールバック手順 / セキュリティチェック

## handoff.md 発行（必須・Rule 5）

`docs/working/templates/handoff.md` を雛形に、以下 6 要素を必ず含める:

1. **要件適合確認結果**: 各 AC の PASS / FAIL / WARN（V-1 出力）
2. **既知課題一覧**: 残課題・回避策・影響範囲
3. **V2 候補**: 今回 scope 外の改善候補
4. **妥協点**: 採用しなかった選択肢と理由
5. **引き継ぎ文書**: 5 分で状況把握できるサマリ
6. **テスト結果サマリ**: ユニット / 統合 / E2E の結果

light モード以下で簡易版を採用する場合も本 6 要素のテンプレートを踏襲（該当なしは「該当なし」明記）。PR マージ後も削除しない（完了資産として保管）。

## settings タスクロック

handoff 完了の前提条件として `bin/plangate doctor --check-settings` PASS。未配線時は handoff を完了扱いにできない。

## Output

- `docs/working/TASK-XXXX/handoff.md`（6 要素必須）
- `docs/working/TASK-XXXX/evidence/` 追記
- `docs/working/TASK-XXXX/status.md` 追記（V-1〜V-4 結果サマリ）

## CLI 呼び出し

- V-1 実行: `bin/plangate verify TASK-XXXX`
- handoff 発行: `bin/plangate handoff TASK-XXXX`

## 次フェーズへ

handoff 完了後は PR 作成 → C-4 ゲート（GitHub 上の人間レビュー）→ マージ。
