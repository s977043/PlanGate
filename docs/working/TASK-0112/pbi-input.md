# TASK-0112 PBI INPUT PACKAGE

> Codex 推奨優先順 C (2026-05-26): mode-classification.md 例外ルール拡張
> 出自: TASK-0106 Retrospective Try アクション

## Context / Why

TASK-0106 (#289 EH-3 maintenance CLI) の retrospective で、**承認境界周辺の改修が mode=standard と判定されたが実態は high-risk 相当だった**ことが Problem として記録された ([`docs/working/TASK-0106/retrospective.md`](../TASK-0106/retrospective.md) §2 Problem)。

現行 `.claude/rules/mode-classification.md` の例外ルールは「セキュリティ関連→最低 中」「DB スキーマ変更→最低 高」「公開 API 破壊的変更→最低 超高」の 3 種のみで、**承認境界 (Hardening Override 対象パス) 周辺の改修** に対する mode 自動補正ルールが不在。本 PBI で例外ルールに追加し、自動推定の安全側を構造化する。

## What (Scope)

### In scope

- `.claude/rules/mode-classification.md` の例外ルールに「承認境界周辺の変更 → 最低でも『高』」を追加
- 対象パスを Hardening Override 対象と一致させて明示（`scripts/hooks/check-plan-hash.sh` の検出パターンと整合）
- 監査ログ (`docs/working/_audit/`) のデータ一括変更 CLI も承認境界相当として扱う旨（TASK-0110 を踏まえる）
- `working-context.md` AC-10 Hardening Override（`lite_eligible=false` 強制）との整合明示
- 自動推定の安全側（該当不確実→該当扱い）を AC-8 と一貫させる

### Out of scope

- mode 自動推定の実装変更（本 PBI は文言追加のみ）
- 既存の 3 例外ルール（セキュリティ/DB/公開 API）の改変
- EH-10 self-set gate hook 実装（PR #339 RFC とは orthogonal）

## 受入基準

- AC-1: `.claude/rules/mode-classification.md` の例外ルールに「承認境界周辺の変更 → 最低でも『高』」が追加されている
- AC-2: 対象パス一覧が Hardening Override 対象（`.claude/`, `scripts/hooks/`, `bin/plangate`, `schemas/`, `.github/workflows/`, `AGENTS.md`, `CLAUDE.md`）と一致
- AC-3: `working-context.md` AC-10 / AC-8 安全側と整合する記述（重複定義ではなく相互参照）
- AC-4: 監査ログ一括変更 CLI も承認境界相当（TASK-0110 を例示）
- AC-5: 自動推定の安全側ルール（不確実→該当扱い）が明記
- AC-6: markdownlint pass + リンク健全性 CI pass

## Notes from Refinement

- `.claude/rules/` は Hardening Override 対象で AI 直接編集不可 → 本 PBI で c3.json APPROVED + EH-3 maintenance window 経由で適用
- 既存例外ルール 3 種は破壊しない（additive change）
- TASK-0110 (#301) と関連: 監査ログ一括変更 CLI のため最低「高」適用＝TASK-0110 を Standard で進めることへの軽微な是正は出るが、本 PBI merge 時点での「以降の PBI から適用」とする

## Estimation

### Risks

- 既存 PBI が「standard 想定」で進行中の場合、ルール拡張で再評価が必要 → mitigation: 「本 PBI merge 後着手の PBI から適用」と明記
- 例外ルール乱立で運用負担増 → mitigation: 対象パスは Hardening Override と完全一致させて単一情報源化

### Unknowns

- mode 自動推定の実装側 (plan-health 等) が本ルール追加を機械的に反映するか → 本 PBI 範囲外、follow-up で対応

### Assumptions

- `.claude/rules/mode-classification.md` の例外ルール構造が変わらない
- Hardening Override 対象パスは `scripts/hooks/check-plan-hash.sh` の現行検出パターンを正本とする
