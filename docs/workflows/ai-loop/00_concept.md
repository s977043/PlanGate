# ai-loop-workflow 概念ドキュメント

> 適用ドメイン: ai-loop-workflow（docs/workflows/ai-loop/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）

---

## 1. 位置づけ

ai-loop-workflow は PlanGate（WF-00〜WF-07）と**並立する独立 PoC**。
PlanGate を置き換えず、競合しない。

```text
PlanGate（WF-00〜WF-07）   → in-the-loop 本番統制（並走期は継続稼働）
ai-loop-workflow            → on-the-loop PoC（低リスク帯の flow → detect → escalate）
```

Arbiter が存在証明を超えるまで PlanGate が本番統制を担う。

---

## 2. WF-00〜07 との並立関係

| 観点 | PlanGate（WF-00〜07） | ai-loop-workflow |
| ------ | ---------------------- | ----------------- |
| ループモデル | in-the-loop（実行前承認） | on-the-loop（逸脱時昇格） |
| 適用対象 | 全変更 | low-risk 変更のみ（boundary=clean, lite=true） |
| 実行ブロック | 承認前にブロック | 事前ブロックしない（flow） |
| 競合 | なし | なし |
| カバーする工程 | 開発プロセス全体（intent→要件→設計→実装→検証→handoff） | **intent 受付から merge-ready（CI 全 job green + AI レビュー指摘対応完了）まで一気通貫**。工程の実体（WF-00〜03・C-1・C-2・exec・V 系）は PlanGate と共通利用するが、**C-3（人間の計画承認）のみを AI 裁定ゲート（C-3'）に置換**し、成果の担保責任は ai-loop が持つ |
| 変更の生成 | 責務内（WF-02〜04 で要件・設計・実装を導く） | **責務内（ai-dev-workflow より広い）**。生成から「CI 通過 + AI レビュー指摘対応完了」まで一気通貫で責務を持つ。工程の実体（生成・計画そのもの）は PlanGate 資産を共通利用するが、**成果の担保**（merge-ready 到達）は ai-loop 固有の責務 |

両者は競合しない。並走期において:

- PlanGate が本番統制を担当する
- Arbiter は PoC 領域（docs/ai/ai-loop/ と docs/workflows/ai-loop/）で実験的に稼働する

Arbiter は plan 生成・要件展開・設計（WF-01〜03）の**工程の実体**を再実装せず、
PlanGate 既存フローをそのまま利用する。置き換えの対象は **C-3 のみ**であり、
C-2（2 レーン契約、[`review-principles.md`](../../../.claude/rules/review-principles.md)
§7-bis）は不変のまま踏襲する。判断実行は L1 = RiverReview 委譲、C-4・merge
は引き続き Human-owned 固定（詳細は次節）。ただし ai-loop-workflow は
**ai-dev-workflow（AI 工程は PR 作成まで、C-4 は人間）より広い責務**を持ち、
PR 作成後の CI・AI レビュー指摘対応が完了し merge-ready に到達するまでを
自らの DoD とする（詳細は §6）。

---

## 3. PlanGate フロー共通化と C-3 置換（C-3'）

### 3.1 ユーザー設計判断（verbatim・2026-07-02）

> 「ai-loopでもPlanGateのフローを踏襲し、計画・設計の品質を保つ価値があると考えており、C-2までのフローは共通化したい。C-3を人ではなく、AIレビューを強化した仕組みに置き換える方式を考えていた。」
>
> 「『ai-loop は生成に責務を持たない』は間違え。ai-loopは成果物がCI通過し、CI時のAIレビューの指摘事項の対応の完了までを責務として『ai-dev』よりも広い責務を担保する」
>
> 「そのために、PR作成前のセルフレビューの強化も整える」

追加判断（AskUserQuestion）: 既存 C-2（2 レーン・[`review-principles.md`](../../../.claude/rules/review-principles.md)
§7-bis）は**不変**のまま、**後段に W チェック（C-3'）を追加**する方式を選択。

### 3.2 確定パイプライン

```text
WF-00〜03 / plan・todo・test-cases 生成   ← PlanGate と共通
C-1 セルフレビュー                         ← 共通
C-2 外部 AI レビュー（2 レーン・不変）      ← 共通（ここまで完全踏襲）
C-3'（置換点）: AI 裁定ゲート = Arbiter
  boundary / lite / class 前提チェック
  → W チェック（Model A 順方向 / Model B adversarial）
  → severity 分類 → C/D 裁定 → decision table
  ├─ AUTO_APPROVED + provenance 刻印 → exec へ
  └─ HUMAN_ESCALATED → 従来の人間 C-3 へ降格
exec / L-0 / V 系                          ← 共通
強化セルフレビュー（PR 作成前・必須）      ← ai-loop 固有（§3.4）
PR 作成
CI + AI レビュー指摘対応ループ（merge-ready まで）← ai-loop 固有（§3.3）
C-4・merge                                 ← Human-owned 固定（不変）
```

### 3.3 責務範囲（ai-dev-workflow との比較）

ai-loop-workflow の責務範囲は **intent 受付から「成果物が CI を通過し、
CI/PR 時の AI レビュー指摘への対応が完了する（= merge-ready 状態）」まで**
であり、ai-dev-workflow（AI 工程は PR 作成まで、C-4 は人間）より**広い責務**
を担保する。

| 項目 | ai-dev-workflow | ai-loop-workflow |
|------|------------------|-------------------|
| AI 責務の終点 | PR 作成まで | **merge-ready**（CI green + AI レビュー指摘対応完了）まで |
| PR 後の CI 失敗対応 | 人間主導（都度） | AI が対応ループを回す（review-feedback-loop.md §2 と接続） |
| PR 後の AI レビュー指摘対応 | 人間主導（都度） | AI が採用/理由付き不採用を記録し対応完了まで担保 |
| 人間の関与 | C-3（計画承認）+ C-4（merge） | **escalate 時の判断のみ + C-4（merge）** |

**DoD（merge-ready 到達条件）**: CI 全 job green **かつ** AI レビュー指摘が
ゼロ、または全件対応完了（採用 / 理由付き不採用の記録）。これを満たして
初めて C-4 待ちに到達する。

PR 後の CI・AI レビュー指摘対応ループは
[`review-feedback-loop.md`](./review-feedback-loop.md) §2 の L4 学習閉ループ
と接続する（指摘 → 対応 → 観点への還元 → 次回セルフレビューでの事前捕捉）。

### 3.4 強化セルフレビュー（PR 作成前・必須ステップ）

merge-ready 責務を担保するため、exec / V 系完了後・PR 作成前に**強化セルフ
レビュー**を必須ステップとして組み込む:

- **内容**: self-review スキル（Phase 1〜13 全観点）+
  [`plan-review-readiness-gate.md`](../../ai/plan-review-readiness-gate.md)
  §8/§9 観点 + review-feedback-loop（L4）で還元済みの観点を必ず通す
- **狙い**: PR 作成後の CI 失敗・AI レビュー指摘を事前に潰し、「PR 作成後に
  指摘を受けない状態」に近づける。指摘が出た場合は L4 ループ
  （[`review-feedback-loop.md`](./review-feedback-loop.md) §2）で観点へ
  還元し、次回はセルフレビューで事前に捕捉される（閉ループ）
- 手順の詳細は [`execution-runbook.md`](./execution-runbook.md) を参照

### 3.5 位置づけの整理

本節は PlanGate 既存の C-3 Autonomous APPROVE
（[`working-context.md`](../../../.claude/rules/working-context.md) #353）・
C-3 条件付き降格（F5-AD）の判定を decision table + provenance で完全機械化
した位置づけである。escalate は従来の人間 C-3 への降格であり、**承認境界の
撤廃ではない**。touches-HO は W チェック結果にかかわらず常に人間へ固定
（[`concept.md`](../../ai/ai-loop/concept.md) §5「不変の原則」参照）。

---

## 4. autonomous-degraded-gates-spec.md との関係

Phase 0（#655）の結論を参照:
`docs/working/TASK-0655/TASK-0655-c3-review.html`

| 区分 | 内容 |
| ------ | ------ |
| 拡張 | Arbiter は `docs/ai/autonomous-degraded-gates-spec.md` の degraded-gates 概念を**拡張する** |
| 非代替 | `docs/ai/autonomous-degraded-gates-spec.md` を置き換えない。PlanGate 本番の degraded-gates はそのまま |
| 参照元 | `NoHardeningOverridePath` 条件を `docs/ai/ai-loop/ho-paths.md` の起点として参照 |

---

## 5. 共通スキル参照方法

intent-classifier 等の PlanGate 共通スキルは shared として参照するが、
Arbiter 側のコードから直接変更しない（参照のみ）。

asset-inventory.md の uses/not-uses 分類に従う:
`docs/ai/ai-loop/asset-inventory.md`

---

## 6. 関連ドキュメント

- `docs/ai/ai-loop/arbiter-policy.md` — Arbiter L0 policy
- `docs/ai/ai-loop/ho-paths.md` — HO パス集約（touches-HO 判定の正本）
- `docs/ai/ai-loop/asset-inventory.md` — 共通資産 uses/not-uses 分類
- `docs/ai/ai-loop/concept.md` — Arbiter の基本概念（Phase 0）
- `docs/ai/ai-loop/related-specs.md` — 既存仕様との関係（Phase 0）
- `docs/ai/autonomous-degraded-gates-spec.md` — 参照元（変更禁止）
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — C-3' の flow→detect→escalate 動作フロー
- [`docs/workflows/ai-loop/execution-runbook.md`](./execution-runbook.md) — PR 前セルフレビュー・PR 後指摘対応ループの実行手順
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) — CI/AI レビュー指摘対応を L4 学習へ還元する閉ループ
- [`docs/ai/plan-review-readiness-gate.md`](../../ai/plan-review-readiness-gate.md) — 強化セルフレビュー §8/§9 観点の参照元
- [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis — C-2 の 2 レーン契約（不変）
- [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) — C-3 Autonomous APPROVE（#353）・C-3 条件付き降格（F5-AD）の正本
