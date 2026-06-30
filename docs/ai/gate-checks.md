# Gate Checks — c3.json 拡張仕様（TASK-0125）

> Issue #430「Codex Dynamic Workflows 風の計画承認ゲート」を PlanGate に取り込む。
> 先行議論（Codex/Gemini 相談）で「新ゲート追加でなく `c3.json` の `gate_checks`
> フィールド拡張」が適切と合意。本仕様はその内容を定義する。

## 1. 概要

`gate_checks` は C-3 承認時に人間が任意で記録する計画ゲートチェックリスト。
Goal / Scope / Risk の 3 項目を boolean で記録し、審査の透明性を高める。

C-1 前に `pass / needs_revision / blocked` を判定する実行準備ゲートは、本仕様ではなく
[`plan-review-readiness-gate.md`](./plan-review-readiness-gate.md) が扱う。`gate_checks`
は C-3 承認記録の optional フィールドであり、Plan Review Readiness Gate を代替しない。

| フィールド | 型 | 必須 | 説明 |
|----------|---|------|------|
| `gate_checks.goal` | boolean | 任意 | plan.md に Goal と成功条件が明確に定義されているか |
| `gate_checks.scope` | boolean | 任意 | In scope / Out of scope の境界が明示されているか |
| `gate_checks.risk` | boolean | 任意 | Risks & Mitigations が列挙されているか |
| `gate_checks.note` | string | 任意 | 人間の補足コメント |

## 2. 設計方針

### 2.1 既存 plan.md セクションとの関係

Goal / Scope / Risk の各チェックは、plan.md の**既存セクション**
（受入基準 / Constraints / Risks & Mitigations）の記入状態を確認するものであり、
**新たな記入要件を課しない**。

```
plan.md の既存セクション         gate_checks 対応
─────────────────────────────  ──────────────────
## Goal                     →  goal: true/false
## Constraints / Non-goals  →  scope: true/false
## Risks & Mitigations      →  risk: true/false
```

### 2.2 Evidence Gate は不採用

Codex Dynamic Workflows が提案する Evidence Gate（計画の判断根拠記録）は、
PlanGate では **`handoff.md` の必須 6 要素（§4 妥協点 / §2 既知課題）** が
WF-05 完了後に担う役割と重複し、時系列が逆転（exec 前に要求 → exec 後の成果物）
するため不採用とする。

### 2.3 Test Gate は不採用（plan.md 側で対応済み）

Test Gate（検証方針の明示）は plan.md の **Testing Strategy** セクションが既に担い、
V-1 受け入れ検査が `test-cases.md` 全件突合で担保する。
`gate_checks` への追加は重複のため本 PBI 範囲外とし、V2 候補とする。

## 3. 適用条件

| モード | gate_checks 推奨 | 理由 |
|--------|----------------|------|
| `ultra-light` | 非推奨 | C-3 自体が簡易版 / スキップ対象 |
| `light` | 非推奨 | C-3 は差分確認のみ |
| `standard` | **推奨** | plan.md の 3 セクションが存在するモード |
| `high-risk` | **推奨** | 同上 + リスク管理重要度が高い |
| `critical` | **推奨** | 同上 + 人間 C-3 必須のため記録価値が高い |

**`gate_checks` は optional**。未記入でも既存フローは壊れない（後方互換）。

## 4. c3.json 記入例

```json
{
  "task_id": "TASK-XXXX",
  "phase": "C-3",
  "c3_status": "APPROVED",
  "approved_by": "human",
  "approved_at": "2026-06-03T00:00:00Z",
  "plan_hash": "sha256:...",
  "gate_checks": {
    "goal": true,
    "scope": true,
    "risk": true,
    "note": "リスクは低い。Risks セクションに軽微な 1 件のみ"
  }
}
```

## 5. スキーマ

`schemas/c3-approval.schema.json` に `gate_checks` プロパティを追加済み（TASK-0125）。

## 6. 関連

- `schemas/c3-approval.schema.json` — 機械可読スキーマ（`gate_checks` property 追加）
- `.claude/rules/working-context.md` — C-3 ゲート定義（HO 対象）
- `.claude/rules/mode-classification.md` — 5 段階モード定義
- Issue [#430](https://github.com/s977043/plangate/issues/430) — Codex Dynamic Workflows 参考

## 7. V2 候補

| 候補 | 理由 |
|------|------|
| Test Gate（gate_checks.test）追加 | plan.md Testing Strategy との対応 |
| `lite_eligible=false` との機械連動 | gate_checks 全 false → Lite 非適用の自動判定 |
| `bin/plangate gate-check TASK-XXXX` コマンド | 対話的な gate_checks 入力 CLI |
