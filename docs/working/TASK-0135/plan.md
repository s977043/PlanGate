# EXECUTION PLAN — TASK-0135 (#578)

## Goal
AIエージェント開発の反パターンのうち、既存 PlanGate で**未カバーの 3 観点**（Verification 実行不能時の代替 / Security 秘密情報非接触 / Scope 発見事項の予防的分離）を plan.md / review-self.md テンプレに追加する。重複・過剰実装はしない。

## Constraints / Non-goals
- templates のみ編集（HO 非該当）。AGENTS.md / .claude/rules / hooks は触らない。
- `_docs/{sop,decisions,logs,learned}` 新設しない（decision-log.jsonl / AGENT_LEARNINGS / _audit と重複）。
- gate 機械強制しない（Plan 段階のチェック観点）。secret-scan ツール導入しない。
- #565/#567 と独立。

## Approach Overview（Explore 重複マッピング反映）
既存充足分は参照に留め、新規 3 観点のみ追加:
1. **plan.md**: Verification Plan に「実行不能時の理由+代替確認」行 + Scope（既存 Out of Scope の近く）に「実装中の発見は別 Issue/メモへ分離（その場で直さない）」予防注記。
2. **review-self.md**: C1 に Security 観点 1 項目（`C1-SEC-01`）+ Scope 予防 1 項目（`C1-SCOPE-DISC-01`）を追加。件数更新。
3. **役割分担整理（#578 Done2）**: 新設でなく、plan.md / review-self.md から既存正本（decision-log.jsonl / AGENT_LEARNINGS.md / `_audit/` / documentation-management.md）への**参照リンク**を 1 箇所追記。

## Work Breakdown
- **S1** plan.md に Verification 実行不能時欄 + Scope 予防注記を追加 / Owner: agent / Risk: 既存 Verification Plan との整合 / rollback: git checkout で復元
- **S2** review-self.md に C1-SEC-01 / C1-SCOPE-DISC-01 を追加 + 件数更新 / Owner: agent / Risk: 既存項目との重複 / rollback: git checkout
- **S3** 既存参照リンク追記（役割分担 Done を参照で充足）/ Owner: agent / Risk: リンク切れ / rollback: git checkout

## Files / Components to Touch
- `docs/working/templates/plan.md`（AI 可・HO 外）
- `docs/working/templates/review-self.md`（AI 可・HO 外）
- 参照のみ（編集しない）: `.claude/rules/working-context.md` / `AGENTS.md` / `decision-log-schema.md` / `docs/ai/metrics-privacy.md`

## Testing Strategy
- 機械: 新項目 grep（C1-SEC-01 / C1-SCOPE-DISC-01 / 実行不能時欄）、件数整合 grep、markdownlint
- レビュー: 既存項目との重複ゼロ（AC-05）、HO 非該当（templates のみ）、#578 Done 4 項目の充足

## Risks & Mitigations
- R1 既存 C-1 と重複 / Explore マッピング準拠で新規 3 観点に限定 / 重複検出時は参照に変更
- R2 Security 観点で誤って大袈裟な実装 / 「Plan に含める要件」止まり・ツール導入は別 PBI / scope 逸脱時は停止
- R3 役割分担 Done を過剰実装（_docs 新設）/ 既存参照リンクで充足・新設しない / 衝突時は参照のみ

## Metrics Evidence
- 対象「変更ファイル」: 実数 2（plan.md + review-self.md）/ 見積もり 2 / ratio 1.0 → 採用。

## Questions / Unknowns
- secret scan の要件化のみ vs 実装 → 初回は要件化のみ（ツールは別 PBI）。

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 2（templates）→ standard
- 受入基準数: 5 → standard
- 変更種別: チェックリスト追加（doc・変更種別軸=doc 寄りだが review-self は C-1 観点の正本）
- 影響範囲: Plan/C-1 観点に限定（HO 非該当）
- **最終判定**: standard。ただし **Security 観点を追加**するため autonomous APPROVE マトリクスの「セキュリティ関連 → 人間 C-3 必須」を**安全側適用** → autonomous APPROVE 不可・人間 C-3 同期。HO 非該当（templates のみ）のため exec は AI 可。
