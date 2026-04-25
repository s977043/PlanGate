# Completion Gate ルール（正本）

> 正本。Completion Gate の定義・ブロック条件・判定フローはこのファイルのみで管理する。
> 参照元: `design-gate.md`、`review-gate.md`、`evidence-ledger.md`、`/pg-verify` コマンド

## 目的

全 Gate の通過を一元管理する最終チェックポイント。
5 つのブロック条件がすべて満たされた時のみ「completion-gate: PASSED」とする。

「動くはず」「たぶん通過した」という曖昧な完了主張を排除し、証拠に基づく Gate 通過を強制する。

## 5 つのブロック条件（必須）

### 条件 1: Design Gate パス必須（high-risk/critical）

- Mode が `high-risk` 以上かつ Design Gate を通過していない場合 → **BLOCKED**
- 具体的なブロック事由:
  - `docs/working/TASK-XXXX/design.md` が存在しない
  - `design.md` の 8 項目のいずれかが未記入
  - Mode が `critical` で人間の明示的承認が記録されていない
- 参照: `plugin/plangate/rules/design-gate.md`

### 条件 2: TDD 証拠必須（high-risk/critical）

- Mode が `high-risk` 以上かつ Evidence Ledger に `type: "test"` の証拠がない場合 → **BLOCKED**
- failing test（exitCode=1）の記録が必須（`requiresFailingTestFirst` フラグ対応）
- 参照: `plugin/plangate/rules/evidence-ledger.md`、`plugin/plangate/commands/pg-tdd.md`

### 条件 3: Review Gate パス必須

- `severity=critical` の finding が 1 件以上ある場合 → **BLOCKED**（全モード）
- Mode が `critical` で `severity=major` の finding が 1 件以上ある場合 → **BLOCKED**
- 参照: `plugin/plangate/rules/review-gate.md`

### 条件 4: Evidence Ledger passed 必須

- `/pg verify` の出力で `status: "passed"` でない場合 → **BLOCKED**
- 必須証拠（claim に対応する evidence）が欠落している場合 → **BLOCKED**
- `EvidenceLedger` 自体が存在しない場合（V-1 受け入れ検査フェーズ以降）→ **BLOCKED**
- 参照: `plugin/plangate/rules/evidence-ledger.md`

### 条件 5: 人間承認記録必須（high-risk/critical）

- Mode が `high-risk` 以上かつ人間承認の記録が `docs/working/TASK-XXXX/status.md` に存在しない場合 → **BLOCKED**
- `critical` モードでは `rollback plan` の存在も必須
- 参照: `plugin/plangate/rules/design-gate.md`（critical 承認要件）

## Mode 別適用マトリクス

| 条件 | ultra-light | light | standard | high-risk | critical |
|------|------------|-------|----------|-----------|----------|
| Design Gate | スキップ | スキップ | スキップ | **必須** | **必須** |
| TDD 証拠 | スキップ | 推奨 | 推奨 | **必須** | **必須** |
| Review Gate | スキップ | スキップ | critical のみブロック | critical+major 推奨 | critical+major ブロック |
| Evidence Ledger | スキップ | 推奨 | **必須** | **必須** | **必須** |
| 人間承認 | 不要 | 不要 | 不要 | **必須** | **必須（明示的）** |
| Rollback Plan | 不要 | 不要 | 不要 | 推奨 | **必須** |

> Mode 定義は `plugin/plangate/rules/mode-classification.md` を参照。

## Completion Gate の実行フロー

`/pg verify` コマンドが Completion Gate の最終確認ステップとして使用される。

```text
/pg verify
  → EvidenceLedger JSON を出力
  → 5 条件チェック（Design Gate / TDD / Review Gate / Evidence Ledger / 人間承認）
  → PASSED / BLOCKED 判定
```

## PASSED 判定の出力形式

```json
{
  "completionGate": {
    "status": "PASSED",
    "checkedAt": "ISO8601",
    "mode": "high-risk",
    "checks": {
      "designGate": "passed",
      "tddEvidence": "passed",
      "reviewGate": "passed",
      "evidenceLedger": "passed",
      "humanApproval": "passed",
      "rollbackPlan": "n/a"
    }
  }
}
```

## BLOCKED 判定の出力形式

```json
{
  "completionGate": {
    "status": "BLOCKED",
    "checkedAt": "ISO8601",
    "mode": "high-risk",
    "checks": {
      "designGate": "passed",
      "tddEvidence": "BLOCKED - no type:test evidence found",
      "reviewGate": "passed",
      "evidenceLedger": "passed",
      "humanApproval": "passed",
      "rollbackPlan": "n/a"
    },
    "blockedBy": ["tddEvidence"]
  }
}
```

## 関連

- Rule: `plugin/plangate/rules/design-gate.md`
- Rule: `plugin/plangate/rules/review-gate.md`
- Rule: `plugin/plangate/rules/evidence-ledger.md`
- Rule: `plugin/plangate/rules/mode-classification.md`（Mode 定義・GatePolicy）
- Command: `plugin/plangate/commands/pg-verify.md`（実行検証フロー）
- Skill: `review-gate`（Review Gate 実施手順）
- Skill: `design-gate`（Design Artifact 生成手順）
- Iron Law: `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`
