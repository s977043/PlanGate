---
name: acceptance-review
description: "実装結果を受け入れ条件（AC）と照合し、適合 / 不足を明確化する。Use when: WF-05 Verify & Handoff で要件適合確認が必要な時、PR の受入基準チェックを網羅的に実施したい時。"
---

# Acceptance Review

実装差分と AC（受け入れ条件）を突き合わせ、**適合 / 不足 / 保留** を判定する Skill。
PlanGate v8.3 では、本 Skill の出力が `handoff.md § 1` の正本となる（必須 6 要素の 1 つ）。

## カテゴリ

Review

## 想定 Phase

WF-05 Verify & Handoff

## PlanGate v8.3 整合（必読）

本 Skill は v8.3 eval framework の以下 3 観点と直接結び付く。判定結果はこれらの観点ラベルで分類すること。

| eval 観点 | 出処 | release blocker |
|----------|------|----------------|
| **AC coverage** | [`eval-cases/ac-coverage.md`](../../../docs/ai/eval-cases/ac-coverage.md) | NO（WARN）|
| **verification honesty** | [`eval-cases/verification-honesty.md`](../../../docs/ai/eval-cases/verification-honesty.md) | **YES** |
| **format adherence** | [`eval-cases/format-adherence.md`](../../../docs/ai/eval-cases/format-adherence.md) | **YES**（schema 準拠率 < 95%）|

### Iron Law との関係

- **Iron Law #3 (NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE)**: 本 Skill の判定は必ず実行ログ / コマンド出力 / evidence ファイルに紐付ける。「PASS と思われる」「動いているはず」は禁止。
- **Iron Law #4 (NO HIDING FAILURES OR UNCERTAINTY)**: 失敗・未実行・未検証の AC は「不足 / 保留」として明示し、verification honesty FAIL を避ける。

## 入力

- AC 一覧（`acceptance-criteria-build` の出力 / `pbi-input.md` の AC セクション / `parent-plan.md` の parent-AC）
- 実装差分（コード変更 + `known-issues-log` の出力）
- テスト実行結果 / CI 結果 / `evidence/` ディレクトリのログ
- schema validation 結果（[`schemas/acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json) で validate 可能な JSON 出力対象）

## 出力

要件適合確認結果（`handoff.md § 1` に統合される）。可能な限り [`acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json) に準拠する JSON も併記する。

### 必須要素

- AC ごとの **PASS / FAIL / WARN** 判定（PlanGate では適合 / 不足 / 保留 を PASS / FAIL / WARN で正規化）
- 各判定の **適合根拠**（テストケース ID / evidence ファイルパス / 実行ログ抜粋）
- FAIL / WARN 時の **フォローアップ計画**（次タスク / V2 候補へ振り分け）
- **V2 候補**（scope 外と確認された項目）
- **schema 準拠率**（生成 artifact が schemas/ で validate される割合、format adherence 観点）

### 表形式（handoff §1 と整合）

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1 | PASS / FAIL / WARN | テスト結果 / evidence へのリンク |
| AC-2 | ... | ... |

**総合**: `<N>/<M> 基準 PASS`
**FAIL / WARN の扱い**: V1 で許容する理由、V2 候補への移行等

### 親 PBI（Orchestrator Mode）の場合

子 PBI の `covers_parent_ac` フィールドから parent-AC × child PBI のカバレッジ表を作成し、未カバー parent-AC を Gap として明示する（`integration-plan.md` の Gap Tracking と同期）。

## 判定基準

| 判定 | 条件 |
|------|------|
| **PASS** | AC を満たすことを示す evidence（テストログ / 動作確認 / 出力例）が存在 |
| **FAIL** | AC を満たさない / evidence なし / 未実装 |
| **WARN** | 部分的に満たすが、scope の範囲で許容（理由を明記）|

**禁止**:
- evidence なき PASS（verification honesty FAIL → release blocker）
- 「概ね動く」「だいたい OK」の主観判定
- FAIL を WARN に格下げして release blocker を回避（Iron Law #4 違反）

## 使い方

1. WF-05 で `qa-reviewer` Agent が本 Skill を呼び出す
2. AC 一覧 + 実装 diff + evidence を入力に判定実行
3. 出力を `handoff.md § 1 要件適合確認結果` に統合
4. release blocker（verification honesty FAIL / format adherence FAIL）が発生したら直ちに `qa-reviewer` から `orchestrator` にエスカレーション

## 関連 Skill

- [`acceptance-criteria-build`](../acceptance-criteria-build/SKILL.md): AC 一覧生成（本 Skill の前段）
- [`known-issues-log`](../known-issues-log/SKILL.md): 既知課題抽出（handoff §2、本 Skill と並走）
- [`self-review`](../self-review/SKILL.md): 実装側の事前 self-review（17 項目 + Iron Law + 8 eval 観点）

## 関連ドキュメント（PlanGate v8.3）

- Workflow: [`docs/workflows/05_verify_and_handoff.md`](../../../docs/workflows/05_verify_and_handoff.md)
- 親 Rule: Rule 5（最終成果物は handoff に集約、[`hybrid-architecture.md`](../../rules/hybrid-architecture.md)）
- handoff テンプレート: [`docs/working/templates/handoff.md`](../../../docs/working/templates/handoff.md)
- [`docs/ai/eval-plan.md`](../../../docs/ai/eval-plan.md) — 8 eval 観点（AC coverage / verification honesty / format adherence）
- [`docs/ai/eval-cases/ac-coverage.md`](../../../docs/ai/eval-cases/ac-coverage.md)
- [`docs/ai/eval-cases/verification-honesty.md`](../../../docs/ai/eval-cases/verification-honesty.md)
- [`docs/ai/eval-cases/format-adherence.md`](../../../docs/ai/eval-cases/format-adherence.md)
- [`docs/ai/structured-outputs.md`](../../../docs/ai/structured-outputs.md) + [`schemas/acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json)
- [`docs/ai/contracts/verify.md`](../../../docs/ai/contracts/verify.md) — verify phase contract
- [`docs/ai/contracts/handoff.md`](../../../docs/ai/contracts/handoff.md) — handoff phase contract
- Iron Law #3 / #4 ([`docs/ai/core-contract.md`](../../../docs/ai/core-contract.md))
