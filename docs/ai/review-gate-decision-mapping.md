# Review Gate Decision Mapping（TASK-0129）

> **Status**: 実装済み（TASK-0129 / #543）
> **位置づけ**: 外部レビュー結果（Decision/Risk/Stop-Work）を C-3 判定に接続し
> #544 の plan 充足を強制する Phase2 Gate の正本。
> **関連**: #543 #544 #527 / 設計: PR #553 (`docs/working/discussions/2026-06-15-543-plan-review-gate-design.md`)

## 1. 目的

PlanGate の責務はレビューそのものでなく「**レビュー結果で進行可否を判定し止める・通す**」こと。
外部レビューア（river-reviewer / Gemini / Codex 等）が返す `Decision` フィールドを
`c3_status` に接続し、進行可否を「止める・通す」強制層とする。

## 2. Decision → c3_status Mapping（正本）

| 外部 Decision | c3_status | 挙動 |
|---------------|-----------|------|
| `go` | `APPROVED` 候補 | 他条件（Risk / Stop-Work 等）が問題なければ exec 可 |
| `revise_plan` | `CONDITIONAL` | Required Plan Changes を R-NNN 集約 → 反映 → 再判定（既存 CONDITIONAL フローに乗せる） |
| `human_approval_required` | 人間 C-3 強制 | autonomous APPROVE 無効化。mode-classification の Hardening Override 同等の格上げ |
| `no_go` | `REJECTED` | plan 再生成 |
| （未知 / 欠落） | 人間 C-3 強制（安全側） | 不明な Decision は `human_approval_required` と同等に扱う |

### 2.1 設計原則

- **安全側倒し**: 未知 Decision 値・欠落は人間 C-3 強制（autonomous APPROVE 不可）
- **additive 拡張**: `review_decision` は `c3.json` の optional フィールド（既存 c3.json は後方互換）
- **R-NNN 集約フロー**: `revise_plan` → CONDITIONAL 時は `review-external.md` に R-NNN で集約し、確定反映後に `c3.json` を APPROVED で発行（既存 CONDITIONAL フロー不変）

## 3. Risk → mode/autonomous 接続

| Risk 値 | 影響 |
|---------|------|
| `high` | mode 最低 `high-risk`・autonomous APPROVE 無効化（`mode-classification.md` と整合） |
| `medium` | mode 最低 `standard` 推奨（既存フロー）|
| `low` | mode 判定は通常通り |
| （欠落） | 安全側: `medium` 相当として扱う |

## 4. Stop-Work Conditions ↔ #544/#551 機械トリガー対応表

> 外部レビューが `Stop-Work Conditions` を列挙した場合、以下の機械トリガーへ接続する。
> 検知方式は **post-flight（ツール実行後の事後検知）** が基本（`codex-guarded.sh` は
> 非対話セッション中のリアルタイムフックを持たないため）。実行層実装は #527 配下。

| Stop-Work Condition（外部レビュー記述） | #544/#551 機械トリガー | 発火時の動作 |
|----------------------------------------|----------------------|-------------|
| 変更ファイル数が計画の 2 倍超 / +5 件超 | `file_count_exceeded`（変更ファイル 2 倍 or +5） | 次サイクルで Replan 要求 |
| テスト/実行が連続 3 回失敗 | `consecutive_failures`（連続失敗 3 回） | 停止・Replan 要求 |
| 同一処理ループが 3 回反復 | `loop_repetition`（反復 3 回） | 停止・Resume 待機 |
| plan 外ファイルへの波及 | `out_of_plan_scope`（plan 外波及） | 停止・scope 再確認 |
| 受入基準（AC）の変更 | `ac_mutation`（AC 変更） | 停止・人間判断必須 |

### 4.1 Do Not Touch → forbidden_files（EH-6）

外部レビューの `Do Not Touch` リスト（ファイルパス列挙）は、
`forbidden_files`（EH-6 / `scripts/hooks/check-forbidden-files.sh`）に接続する。
実装着手前に plan の `forbidden_files` セクションへ明記し、EH-6 が発火時にブロックする。

### 4.2 Verification Required → Verification Automation

外部レビューの `Verification Required` 列挙は、plan の `Testing Strategy` /
`Verification Automation` セクションへの **必須注入**とする。
C-1 充足チェック（§5）で未記入を検出する。

## 5. C-1 充足チェック拡張（Stop Condition / Replan Triggers 検出）

> `plan-quality-check` Skill の `done_check` / `risk_check` 観点を拡張し、
> 以下の未記入を `WARN/FAIL` として検出する。

| チェック項目 | 対応観点 | 判定 |
|-------------|---------|------|
| Stop Condition の記入（いつ停止するか） | `done_check` 拡張 | 未記入 → WARN |
| Replan Triggers の機械値（具体的な閾値） | `risk_check` 拡張 | 未記入 → WARN |
| Loop Attempts の上限記入 | `done_check` 拡張 | 未記入 → INFO |

### 5.1 review-self テンプレート追加チェック項目（C1-LOOP-01/02）

| ID | チェック内容 | 判定基準 |
|----|------------|---------|
| C1-LOOP-01 | plan に Stop Condition（停止条件）が記入されているか | 未記入 → WARN |
| C1-LOOP-02 | plan に Replan Triggers（再計画トリガー）と機械値が記入されているか | 未記入 → WARN、機械値なし → WARN |

これらは high-risk / critical モードでは **FAIL** として扱う（安全側）。

## 6. schema 拡張フィールド（apply-script 経由で人間適用）

> `schemas/c3-approval.schema.json` は Hardening Override 対象。
> AI は apply-script（`scripts/apply-task-0129-schema.sh`）を生成し、
> **人間が適用**する（responsibility-classes.md: Human-owned）。

追加フィールド（additive・`required` に追加しない）:

| フィールド | 型 | 説明 |
|----------|---|------|
| `review_decision` | string（enum） | 外部レビューの Decision（`go` / `revise_plan` / `human_approval_required` / `no_go`）|
| `review_risk` | string（enum） | 外部レビューの Risk（`low` / `medium` / `high`）|
| `review_stop_works` | array of string | 外部レビューの Stop-Work Conditions リスト |
| `review_source` | string | レビューアの識別子（例: `river-reviewer` / `gemini`）|
| `lite_eligible` | boolean | `false` 固定（承認境界変更 PBI は常に Standard C-3 同期）|

## 7. 承認境界整合（AC-06）

本 PBI（TASK-0129）は承認境界の中核（c3-approval.schema / working-context.md）を変更する。

| 項目 | 値 |
|------|---|
| mode | `high-risk`（承認境界周辺の変更 → 最低 high / mode-classification.md 例外ルール）|
| lite_eligible | `false`（強制）|
| C-3 | Standard 同期（autonomous APPROVE 不可）|
| HO 適用 | Human が apply-script を実行（AI 直接編集不可）|

## 8. 関連

- `schemas/c3-approval.schema.json` — 機械可読スキーマ（apply-script 拡張）
- `.claude/rules/working-context.md` — C-3 ゲート定義・CONDITIONAL フロー（HO 対象）
- `.claude/rules/mode-classification.md` — 5 段階モード・autonomous APPROVE 無効化条件
- `docs/working/discussions/2026-06-15-543-plan-review-gate-design.md` — 設計ノート
- `docs/ai/external-reviewer-interface.md` — 外部レビューア接続規約（#227 / TASK-0089）
- `scripts/apply-task-0129-schema.sh` — schema 拡張 apply-script（Human 適用）
- `scripts/apply-task-0129-wc.sh` — working-context 追記 apply-script（Human 適用）
- Issue [#543](https://github.com/s977043/plangate/issues/543) — Plan Review Gate 判定連携
- Issue [#544](https://github.com/s977043/plangate/issues/544) — Loop 安全制御（#551 機械トリガー）
- Issue [#527](https://github.com/s977043/plangate/issues/527) — Enforcement Integrity（実行層実装）
