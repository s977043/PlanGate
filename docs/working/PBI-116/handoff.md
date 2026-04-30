---
task_id: PBI-116
artifact_type: parent-handoff
schema_version: 1
status: final
issued_at: 2026-04-30
author: orchestrator
parent_pbi: PBI-116
v1_release: ""
---

# Parent Handoff — PBI-116（最新実行モデル対応 EPIC）

> Orchestrator Mode 親 PBI の集約 handoff。Parent Integration Gate（👤 user 判断）の根拠ファイル。
> 関連: [`parent-plan.md`](./parent-plan.md) / [`integration-plan.md`](./integration-plan.md) / Issue [#116](https://github.com/s977043/plangate/issues/116)

## メタ情報

```yaml
parent_pbi: PBI-116
title: 最新実行モデル対応 — Outcome-first / Model Profile / Eval 基盤
issue: https://github.com/s977043/plangate/issues/116
mode: high-risk
milestone: v8.2
state: parent:done  # 2026-04-30 APPROVED (approvals/parent-integration.json)
issued_at: 2026-04-30
children_done: 6/6
```

## 1. 要件適合確認結果（parent-AC × 6 子 PBI 集約）

| parent-AC | 内容 | カバー子 PBI | 判定 | 根拠 |
|-----------|------|------------|------|------|
| parent-AC-1 | Core Contract が outcome-first 形式で定義 | PBI-116-01 | PASS | `docs/ai/core-contract.md`（Iron Law 7 項目）+ CLAUDE.md/AGENTS.md から参照 |
| parent-AC-2 | 実行モデル別差分が Model Profile として設定化 | PBI-116-02 | PASS | `docs/ai/model-profiles.yaml`（4 profiles）+ schema |
| parent-AC-3 | prompt assembly が 4 層で説明・実装 | PBI-116-03 | PASS | `docs/ai/prompt-assembly.md`（170 行）+ contracts/ × 7 + adapters/ × 4 |
| parent-AC-4 | Structured Outputs schema 案定義 | PBI-116-04 | PASS | `docs/ai/structured-outputs.md` + 4 schemas（review-result / acceptance-result / mode-classification / handoff-summary）|
| parent-AC-5 | model migration eval cases 追加 | PBI-116-05 | PASS | `docs/ai/eval-plan.md` + 8 eval cases + comparison-template |
| parent-AC-6 | Tool Policy / Hook enforcement 責務境界 | PBI-116-04, 06 | PASS | `docs/ai/tool-policy.md` + `hook-enforcement.md` + `responsibility-boundary.md` |
| parent-AC-7 | C-3 / C-4 / scope discipline / verification honesty 維持 | 全子 PBI | PASS | 全子 PBI で C-3 APPROVED 記録、scope/verification は eval cases で release blocker 化 |
| parent-AC-8 | CLAUDE.md / AGENTS.md 薄型化（token 削減） | PBI-116-01 | PASS | CLAUDE.md 43→21 / AGENTS.md 61→29（実測） |

**総合**: 8/8 parent-AC PASS / **release blocker 該当なし**

## 2. 子 PBI 一覧と handoff サマリ

| 子 PBI | TASK | Phase | PR | covers_parent_ac | state |
|--------|------|-------|------|--------------|------|
| PBI-116-01 | TASK-0039 | 1 | #132 / #133 / #134 | parent-AC-1, AC-7, AC-8 | done |
| PBI-116-02 | TASK-0040 | 2 | #137 / #141 | parent-AC-2 | done |
| PBI-116-04 | TASK-0042 | 2 | #138 / #143 | parent-AC-4, AC-6 | done |
| PBI-116-06 | TASK-0041 | 2 | #139 / #142 | parent-AC-6 | done |
| PBI-116-03 | TASK-0043 | 3 | #145 / #146 / #147 | parent-AC-3 | done |
| PBI-116-05 | TASK-0044 | 4 | #148 / #149 | parent-AC-5 | done |

各子 PBI の詳細 handoff: `docs/working/TASK-XXXX/handoff.md`（必須 6 要素完備、TASK-0039〜TASK-0044）

## 3. 既知課題一覧（親 PBI レベル集約）

| 課題 | Severity | 状態 | 出元 | V2 候補か |
|------|---------|------|------|---------|
| 自動 eval runner 未実装（reasoning_token / latency / tool call 集計） | minor | accepted | PBI-116-05 | Yes |
| Hook enforcement 実装が仕様止まり（ハード強制は別 PBI） | minor | accepted | PBI-116-04, 06 | Yes |
| schema validation の CI 統合未実装（schemas/ は定義のみ） | minor | accepted | PBI-116-04 | Yes |
| Structured Outputs の実 LLM 適用は別 PBI（schema 定義のみ） | minor | accepted | PBI-116-04 | Yes |
| Model Profile の baseline 測定は実運用後 | info | open | PBI-116-05 | Yes |

**Critical 課題**: なし。リリース可。

## 4. V2 候補（次 EPIC へ）

| V2 候補 | 出元 | 推定優先度 | 関連 |
|--------|------|----------|------|
| 自動 eval runner（reasoning_token / latency / tool call / schema validate）| PBI-116-05 | High | （新規 EPIC）|
| Hook enforcement 実装（plan 未承認 exec ブロック等のハード強制）| PBI-116-04, 06 | High | （新規 EPIC）|
| Structured Outputs の実 LLM 適用 + schema validate CI 統合 | PBI-116-04 | High | （新規 EPIC）|
| Model Profile baseline 測定（v8.2 baseline）| PBI-116-05 | High | （新規 PBI）|
| 全モデル / provider 網羅比較 | PBI-116-05 | Low | — |
| 外部観測ダッシュボード（Grafana / Looker 等） | PBI-116-05 | Low | — |

## 5. 妥協点（親 PBI レベル）

| 選択した方針 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| Spec のみ（実装層は別 PBI） | Hook enforcement / eval runner 同梱 | EPIC スコープを「最新モデル対応 **基盤**」に限定。実装層は v8.3+ で別 EPIC として切り出すのが妥当 |
| 4 phase 構成（並行 → 順次 → 順次 → 順次） | 全並行 / 全順次 | dependency-graph で Phase 1 = AC-1 基盤、Phase 2 = 並列可能 3 件、Phase 3 = AC-3 統合、Phase 4 = AC-5 最終 evaluation。順序最適化 |
| 子 PBI 単位で PR 分割（統合 PR なし）| 統合 monorepo PR | レビューコスト・リバート容易性・並列性のため小単位 PR 採用（Codex 相談で確定） |
| C-2 Codex 統合レビュー（Phase 2 の 3 PBI を 1 回） | 各 PBI 個別 C-2 | Codex 呼び出しコスト圧縮 + Phase 2 の責務隣接性が高いため統合可 |
| Phase 4 で C-2 skip | C-2 Codex 実施 | standard / doc-only / Phase 1〜3 同パターン踏襲、review-external.md に skip 理由記録 |

## 6. テスト結果サマリ

| 子 PBI | AC | TC PASS | TC WARN | TC FAIL |
|--------|----|---------|---------|---------|
| PBI-116-01 | 8/8 | — | — | 0 |
| PBI-116-02 | 全 PASS | — | — | 0 |
| PBI-116-04 | 全 PASS | — | — | 0 |
| PBI-116-06 | 全 PASS | — | — | 0 |
| PBI-116-03 | 全 PASS | — | — | 0 |
| PBI-116-05 | 8/8 | 8 | 1（行数）| 0 |

各 PBI の詳細は `docs/working/TASK-XXXX/handoff.md` § 6 を参照。

## 7. 統合チェック結果（Integration Plan ↔ 実測）

### A. Artifact 完備性 ✅

- [x] 全 6 子 PBI の `handoff.md` 存在（TASK-0039〜0044）
- [x] 各 handoff.md が必須 6 要素を含む（grep で確認、`## 1.` 〜 `## 6.` 各 1 件以上）
- [x] 全子 PBI が `state: done`

### B. 受入基準カバレッジ ✅

- [x] parent-AC-1〜AC-8 全て子 PBI YAML の `covers_parent_ac` でカバー（§ 1 表参照）

### C. 統合動作確認 ✅

- [x] CLAUDE.md / AGENTS.md 薄型化後も C-3 / C-4 ワークフロー機能（PBI-116-03/05 で実証）
- [x] Model Profile（4 種）+ phase 別 reasoning_effort / verbosity が定義
- [x] Prompt assembly 4 層が明文化（base_contract / phase_contract / risk_mode_contract / model_adapter）
- [x] Structured Outputs schema 4 件が `schemas/` に存在
- [x] eval cases（PBI-116-05）で 8 観点定義 + release blocker 4 観点

### D. リグレッションなし ✅

- [x] 既存 5 mode 分類維持（`.claude/rules/mode-classification.md`）
- [x] handoff 必須化（Rule 5）維持
- [x] AI 運用 4 原則（CLAUDE.md `<law>`）維持
- [x] Iron Law 7 項目を `core-contract.md` に hard mandate として保持

### E. ドキュメント整合 ✅

- [x] 新規ドキュメント参照は core-contract / model-profiles / prompt-assembly / tool-policy / eval-plan が `docs/ai/` 配下に整列
- [x] orchestrator-mode.md Spec 範囲を逸脱なし
- [x] hybrid-architecture.md Rule 1〜5 違反なし

### Gap Tracking

| ID | Gap | Severity | 状態 | 対応 |
|----|-----|---------|------|------|
| (なし) | — | — | — | — |

**Open Gap**: 0 件 → `parent:done` 遷移可能。

## 8. 次の担当者へ（5 分サマリ）

### 概要

PlanGate v8.2 milestone の中核 EPIC。GPT-5.5 以降の outcome-first モデルに対応するため、以下の **基盤** を整備した（実装層は別 EPIC）。

1. **Core Contract**（Iron Law 7 項目）を独立ドキュメント化、CLAUDE.md/AGENTS.md を 43→21 / 61→29 に薄型化
2. **Model Profile**（4 profile）+ schema で実行モデル差分を設定化
3. **Prompt Assembly 4 層**（base / phase / risk_mode / model adapter）で組み立てを構造化
4. **Structured Outputs schema**（4 件）と Hook enforcement 仕様
5. **Eval Cases 8 観点**（うち 4 観点を release blocker）でモデル移行の合否判定基準

### 触れないでほしいファイル

- `docs/ai/core-contract.md`（Iron Law 正本）
- `docs/ai/model-profiles.yaml`（profile 定義正本）
- `docs/ai/prompt-assembly.md`（4 層構造正本）
- `docs/ai/eval-plan.md` / `eval-cases/*`（8 観点正本）
- `schemas/*.schema.json`（4 schemas 正本）

これらの変更は **別 EPIC** として議論する。

### 次に手を入れるなら

**推奨される次のステップ**:
1. **Parent Integration Gate（👤 user）** — `approvals/parent-integration.json` に APPROVED 署名 → `parent:done` 遷移
2. EPIC #116 を Close
3. **v8.2 baseline 測定 PBI** を起票（本 eval framework での初回測定）
4. **eval runner 実装 PBI** を起票（reasoning_token / latency / tool call 集計）
5. **Hook enforcement 実装 PBI** を起票（plan 未承認 block 等のハード強制）
6. **schema validate CI 統合 PBI** を起票

**避けるべきアンチパターン**:
- Spec のみで満足してしまい実装 EPIC を切り出さない
- baseline 未取得のまま新モデル比較
- eval cases の release blocker 観点（scope/approval/verification/format）を WARN に格下げ

### 参照リンク

- EPIC: [#116](https://github.com/s977043/plangate/issues/116)
- parent-plan: [docs/working/PBI-116/parent-plan.md](./parent-plan.md)
- integration-plan: [docs/working/PBI-116/integration-plan.md](./integration-plan.md)
- 各子 handoff: [TASK-0039](../TASK-0039/handoff.md) / [TASK-0040](../TASK-0040/handoff.md) / [TASK-0041](../TASK-0041/handoff.md) / [TASK-0042](../TASK-0042/handoff.md) / [TASK-0043](../TASK-0043/handoff.md) / [TASK-0044](../TASK-0044/handoff.md)
- 振り返り: [docs/working/retrospective-2026-04-30.md](../retrospective-2026-04-30.md)

## 9. Parent Integration Gate（👤 user 判断）— ✅ APPROVED 2026-04-30

統合チェック A〜E 全 PASS / Open Gap 0 件 / Release blocker なし。
**ユーザー (s977043) APPROVED により `parent:done` 遷移、EPIC #116 Close 可。**

承認記録: [`approvals/parent-integration.json`](./approvals/parent-integration.json)

```yaml
parent_pbi_id: PBI-116
decision: APPROVED
approver: s977043 (mine_take)
approved_at: 2026-04-30
post_approval_action: parent state を done に遷移し、EPIC #116 を Close
```

### 次 EPIC 候補（V2）

handoff § 4 「V2 候補」を参照。優先度 High は以下 4 件:

1. v8.2 baseline 測定 PBI（本 eval framework での初回測定）
2. eval runner 実装 PBI（reasoning_token / latency / tool call 集計）
3. Hook enforcement 実装 PBI（plan 未承認 block 等のハード強制）
4. schema validate CI 統合 PBI
