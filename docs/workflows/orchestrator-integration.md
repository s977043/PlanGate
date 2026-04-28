# Workflow: Orchestrator Integration (子 PBI 統合 → 親 PBI 完了)

> **Status**: Specification（v1, 仕様策定のみ）
> 関連: [`docs/orchestrator-mode.md`](../orchestrator-mode.md) / Issue [#109](https://github.com/s977043/plangate/issues/109)
> 主担当 Agent: Integration Agent（既存 `orchestrator` の handoff 発行を拡張）+ qa-reviewer

## 目的

子 PBI 群の `child:done` 達成後に、**親 PBI 受入基準のカバレッジ確認 + 統合チェック + 親完了ゲート**を実行し、`parent:done` に到達する。

「Gate を消さない」原則の終着点であり、AI が単独で `parent:done` を宣言できないように設計されている。

## 入力

- 親 PBI の `parent-plan.md`
- 子 PBI 群の YAML（`children/PBI-XXX-NN.yaml`）すべて
- 各子 PBI の handoff.md（必須、`docs/working/<child-context>/handoff.md`）
- `integration-plan.md` のチェックリスト

## 完了条件（ParentDone 不変条件）

```text
ParentDone =
  AllRequiredChildrenAccepted
  AND ParentAcceptanceCriteriaCovered
  AND IntegrationChecksPassed
  AND NoOpenBlockingGap
  AND HumanOrPolicyFinalApprovalPassed
```

詳細は [`docs/orchestrator-mode.md`](../orchestrator-mode.md) の「Gate 条件（不変条件）」を参照。

## 状態遷移

```text
（前提: required な子 PBI がすべて child:done）
   │
   ▼
parent:children_done
   │
   │  Step I-1: 受入基準カバレッジ確認
   │   └ 親 PBI の各 AC が ≥ 1 子 PBI の covers_parent_ac でカバーされているか
   ▼
parent:coverage_checked
   │
   │  Step I-2: 統合チェック実行
   │   └ integration-plan.md のチェックリストを 1 件ずつ突合
   ▼
parent:integration_checked
   │
   │  Step I-3: gap 検出 / 解決
   │   ├ 未解決 gap があれば new_child_pbi_proposed に分岐
   │   └ なければ次へ
   ▼
parent:integration_review
   │
   │  Step I-4: 親完了ゲート（統合ゲート）
   │   ├ 👤 人間レビューまたは事前定義 policy
   │   └ APPROVE / REQUEST CHANGES / REJECT
   ▼
parent:done
   │
   ▼
（handoff 発行）
```

### Gap 検出時の分岐

```text
parent:integration_review (gap detected)
   │
   ▼
gap_detected
   │
   │  Step I-3a: 新規子 PBI 提案
   ▼
new_child_pbi_proposed
   │
   │  WithinParentScope または HumanApprovedScopeChange
   ▼
parent_plan_updated
   │
   │  親計画の更新は再承認を要する
   ▼
reapproval_required
   │
   │  Step D-7（親計画ゲート）に戻る
   ▼
parent:decomposition_approved (再)
   │
   ▼
child:planned（新規子 PBI）
```

`NewChildPBIAllowed` 不変条件は [`docs/orchestrator-mode.md`](../orchestrator-mode.md) を参照。

## 各 Step の詳細

### Step I-1: 受入基準カバレッジ確認

| 項目 | 内容 |
| --- | --- |
| 入力 | 親 `parent-plan.md` の AC 一覧 + 各子 PBI の `covers_parent_ac` |
| 出力 | カバレッジマトリクス（`integration-plan.md` 内） |
| Sub Agent | Integration Agent |
| Skill | `acceptance-review` |

カバレッジ判定:

- 親 AC ごとに「どの子 PBI が証跡を提供したか」を記録
- 0 子 PBI でカバーされる親 AC が 1 件でもあれば → gap_detected

### Step I-2: 統合チェック実行

| 項目 | 内容 |
| --- | --- |
| 入力 | `integration-plan.md` のチェックリスト |
| 出力 | チェック結果（PASS / FAIL / WARN） |
| Sub Agent | Integration Agent + qa-reviewer |
| Skill | `acceptance-review` / `nonfunctional-check` |

統合チェックの代表項目:

- 子 PBI 単独テストでは検出できない結合テスト
- 子 PBI 間の API contract 整合性
- パフォーマンス劣化の累積影響
- セキュリティ境界の整合性
- 親 PBI 全体としての UX フロー

### Step I-3: Gap 検出 / 解決

| 項目 | 内容 |
| --- | --- |
| 入力 | Step I-1 / I-2 の結果 |
| 出力 | gap リスト + 解決方針 |
| Sub Agent | Integration Agent |

#### Gap が解決可能な場合

- 既存子 PBI の修正で対応 → 該当子 PBI の plan 更新 + 再 exec
- 新規子 PBI 追加で対応 → `gap_detected` → `new_child_pbi_proposed` フロー

#### Gap が解決不能な場合

- 親 PBI スコープ自体の見直しを 👤 人間に提起
- `risk-report.md` に escalation として追記

### Step I-4: 親完了ゲート（統合ゲート）

| 項目 | 内容 |
| --- | --- |
| 入力 | カバレッジマトリクス + 統合チェック結果 + handoff サマリ |
| 出力 | `approvals/parent-integration.json` |
| 担当 | 👤 人間 または 事前定義 policy |
| 判定値 | APPROVE / REQUEST CHANGES / REJECT |

判定後の遷移:

- **APPROVE**: `parent:done` → handoff.md 発行
- **REQUEST CHANGES**: 指摘内容に応じて Step I-1 〜 I-3 のいずれかに戻る
- **REJECT**: 親 PBI 自体の再評価（稀、極めて重大な発見時のみ）

## 親 PBI handoff.md

`parent:done` 到達時に、親 PBI レベルの handoff.md を発行する。必須 6 要素は既存テンプレート [`docs/working/templates/handoff.md`](../working/templates/handoff.md) に従い、以下を **集約** する:

1. 要件適合確認結果（親 AC × 子 PBI カバレッジマトリクス）
2. 既知課題一覧（全子 PBI の known-issues を集約 + 親レベル課題）
3. V2 候補（残った gap で本 PBI で扱わなかったもの）
4. 妥協点（親計画作成時 + 統合時の選択ログ）
5. 引き継ぎ文書（親 PBI 全体のサマリ）
6. テスト結果サマリ（子 PBI 各々 + 統合チェック）

## カバレッジ判定の例

### 例: 親 PBI に AC が 3 件、子 PBI が 3 件

| 親 AC | 子 PBI-XXX-01 | 子 PBI-XXX-02 | 子 PBI-XXX-03 | カバー判定 |
| --- | --- | --- | --- | --- |
| parent-AC-1 | ✅ covers | — | — | ✅ |
| parent-AC-2 | — | ✅ covers | ✅ covers | ✅ |
| parent-AC-3 | — | — | — | ❌ **gap** |

→ `gap_detected` → 新規子 PBI 提案 or 既存子 PBI 修正

## 既存 PlanGate Gate との対応

| 既存 PlanGate | Orchestrator Integration |
| --- | --- |
| V-1: 受け入れ検査 | 子 PBI 単位 + Step I-1 / I-2 で親レベルにも適用 |
| V-3: 外部モデルレビュー | 親 PBI レベルで任意実施（high-risk 推奨） |
| **PR 作成** | 各子 PBI で個別 PR、親 PBI は統合 PR or release-note のみ |
| **C-4: PR レビュー** | 各子 PBI PR で実施。親 PBI は **統合ゲート（Step I-4）** が相当 |

## 呼び出す Skill

| Skill | 使用 Step | 出典 |
| --- | --- | --- |
| `acceptance-review` | I-1, I-2 | 既存 `.claude/skills/` |
| `nonfunctional-check` | I-2 | 既存 |
| `known-issues-log` | handoff 発行時 | 既存 |
| `coverage-matrix-build` | I-1 | **新規（実装 PBI で追加検討）** |

## エラーハンドリング

| 異常 | 対処 |
| --- | --- |
| カバレッジ未達（gap 検出） | Step I-3a へ分岐、新規子 PBI 提案 |
| 統合チェック FAIL | 該当子 PBI に差し戻し、再 exec |
| 統合ゲート REJECT | 親 PBI 再評価（人間判断） |
| 子 PBI handoff.md 欠落 | 該当子 PBI を `child:done` から差し戻し |

## 実装フェーズ提案（後続 PBI で）

1. **Phase 1**: 手動運用（カバレッジマトリクス手作業 + Step I-4 を人間レビュー）
2. **Phase 2**: カバレッジマトリクス自動生成（`covers_parent_ac` フィールドからの集計）
3. **Phase 3**: 統合チェックの自動化（CI で integration-plan.md を機械実行）
4. **Phase 4**: gap_detected → new_child_pbi_proposed の半自動提案
