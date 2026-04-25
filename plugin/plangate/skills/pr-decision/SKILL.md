---
name: pr-decision
description: gate status + evidence status + review findings + unresolved risks + rollback plan から PR 可否を判定する。判定根拠を structured output で出力し、マージ可能かどうかを明示する。
---

# PR Decision Skill

Evidence Ledger + Review Gate + GateStatus + Rollback Plan の状態から PR 可否を判定し、
判定根拠を structured output で出力する。

## Iron Law

`NO PR WITHOUT EVIDENCE-BASED GATE PASSAGE`

証拠なしの PR 作成を防ぐ。全ての Gate が通過していることを確認してから PR を作成する。

## 入力（5 つ）

1. **Gate Status**: Completion Gate の `checks` オブジェクト（PASSED / BLOCKED）
2. **Evidence Status**: EvidenceLedger の `status`（passed / failed / skipped）
3. **Review Findings**: Review Gate の finding 一覧（severity 付き）
4. **Unresolved Risks**: `plan.md` の Risks & Mitigations で未解決のもの
5. **Rollback Plan**: 存在するか、内容は適切か

## 出力: PR 判定レポート

```markdown
## PR 判定レポート

### 判定: {APPROVE | BLOCK | CONDITIONAL}

### Gate Status

| Gate | 状態 |
|------|------|
| Design Gate | {passed / blocked / skipped} |
| TDD Gate | {passed / blocked / skipped} |
| Review Gate | {passed / blocked / skipped} |
| Completion Gate | {PASSED / BLOCKED} |

### Evidence Status

- Overall: {passed / failed / skipped}
- Missing: {欠落している証拠（なければ "なし"）}

### Review Findings サマリ

| Severity | 件数 |
|----------|------|
| critical | {N} |
| major | {N} |
| minor | {N} |
| info | {N} |

### Unresolved Risks

- {未解決リスクのリスト（なければ "なし"）}

### Rollback Plan

- 存在: {あり / なし}
- 内容の妥当性: {適切 / 不足}

### 判定根拠

{判定理由を 3〜5 行で記述}

### アクション

- {次のアクション（マージ可能 / 修正が必要な項目）}
```

## 判定基準

| 判定 | 条件 |
|------|------|
| **APPROVE** | Completion Gate PASSED + Evidence Ledger passed + critical finding = 0 + Rollback Plan あり（critical モード） |
| **BLOCK** | Completion Gate BLOCKED、または critical finding >= 1、または Evidence Ledger failed |
| **CONDITIONAL** | major finding >= 1 かつ critical = 0、または minor リスクが残存 → 条件付き承認（担当者の判断） |

## 手順

### Step 1: 入力収集

以下の形式で入力を収集する:

```json
{
  "gateStatus": {
    "completionGate": "PASSED | BLOCKED",
    "checks": {
      "designGate": "passed | blocked | skipped",
      "tddEvidence": "passed | blocked | skipped",
      "reviewGate": "passed | blocked | skipped",
      "evidenceLedger": "passed | blocked | skipped",
      "humanApproval": "passed | blocked | skipped",
      "rollbackPlan": "passed | n/a | blocked"
    }
  },
  "evidenceStatus": {
    "status": "passed | failed | skipped",
    "missingEvidence": ["<欠落している証拠>"]
  },
  "reviewFindings": [
    {
      "severity": "critical | major | minor | info",
      "description": "<finding の説明>",
      "resolved": true
    }
  ],
  "unresolvedRisks": ["<未解決リスクの説明>"],
  "rollbackPlan": {
    "exists": true,
    "adequate": true
  }
}
```

### Step 2: BLOCK 条件チェック（優先）

以下のいずれかに該当する場合、判定を **BLOCK** とする:

1. `gateStatus.completionGate === "BLOCKED"`
2. `reviewFindings` に `severity === "critical"` が 1 件以上ある
3. `evidenceStatus.status === "failed"`

### Step 3: CONDITIONAL 条件チェック

BLOCK でない場合、以下のいずれかに該当する場合、判定を **CONDITIONAL** とする:

1. `reviewFindings` に `severity === "major"` が 1 件以上ある
2. `unresolvedRisks` が 1 件以上ある
3. Rollback Plan が critical モードで存在しない

### Step 4: APPROVE 判定

BLOCK でも CONDITIONAL でもない場合、判定を **APPROVE** とする。

### Step 5: 判定レポート生成

「出力: PR 判定レポート」のフォーマットで結果を出力する。

## 使用例

**入力例（APPROVE）**:

```json
{
  "gateStatus": {
    "completionGate": "PASSED",
    "checks": {
      "designGate": "passed",
      "tddEvidence": "passed",
      "reviewGate": "passed",
      "evidenceLedger": "passed",
      "humanApproval": "passed",
      "rollbackPlan": "n/a"
    }
  },
  "evidenceStatus": { "status": "passed", "missingEvidence": [] },
  "reviewFindings": [
    { "severity": "minor", "description": "変数名の改善提案", "resolved": false }
  ],
  "unresolvedRisks": [],
  "rollbackPlan": { "exists": false, "adequate": false }
}
```

**出力例（APPROVE）**:

```markdown
## PR 判定レポート

### 判定: APPROVE

### Gate Status

| Gate | 状態 |
|------|------|
| Design Gate | passed |
| TDD Gate | passed |
| Review Gate | passed |
| Completion Gate | PASSED |

### Evidence Status

- Overall: passed
- Missing: なし

### Review Findings サマリ

| Severity | 件数 |
|----------|------|
| critical | 0 |
| major | 0 |
| minor | 1 |
| info | 0 |

### Unresolved Risks

- なし

### Rollback Plan

- 存在: なし
- 内容の妥当性: — （standard モードのため任意）

### 判定根拠

Completion Gate が PASSED となっており、全ての必須 Gate を通過している。
Evidence Ledger の status は passed で証拠が揃っている。
critical / major finding は 0 件であり、minor finding 1 件はマージの障害とならない。
Rollback Plan は standard モードのため必須ではない。

### アクション

- PR 作成・マージ可能
- minor finding（変数名改善）は次スプリントの V2 候補として記録推奨
```

## 想定 phase

- WF-05 Verify & Handoff

## カテゴリ

- quality-gate
- release-control

## 関連

- Rule: `completion-gate.md`（Gate Status の詳細）
- Rule: `evidence-ledger.md`（Evidence Status の詳細）
- Rule: `review-gate.md`（Review Findings の詳細）
- Skill: `skill-policy-router`（GatePolicy・requiresWorktree）
- Workflow: `docs/workflows/05_verify_and_handoff.md`
