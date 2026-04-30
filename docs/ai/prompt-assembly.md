# Prompt Assembly — Core / Phase / Risk / Model Adapter 4 層化

> **Status**: v1（PBI-116-03 で初版確立、Phase 3 / PBI-116）
> 関連: [`core-contract.md`](./core-contract.md) / [`model-profiles.md`](./model-profiles.md) / [`responsibility-boundary.md`](./responsibility-boundary.md) / [`structured-outputs.md`](./structured-outputs.md)

## 1. 目的

PlanGate の **不変制約（Iron Law）/ phase 別成功条件 / mode 別検証深度 / モデル別補正** を、変更頻度と責務が異なる 4 つの独立層に分離する。これにより:

- モデル変更時にプロンプト全文を fork せず adapter 差替えで対応
- phase / mode 追加時に独立した skeleton を追加するだけで拡張可能
- Eval（PBI-116-05）で各層を独立検証可能

## 2. 4 層構造

```text
base_contract        ← Phase 1 / docs/ai/core-contract.md
+ phase_contract     ← classify / plan / approve-wait / execute / review / verify / handoff
+ risk_mode_contract ← ultra_light / light / standard / high_risk / critical
+ model_adapter      ← Phase 2 / Model Profile.adapter（outcome_first / outcome_first_strict / explicit_short / legacy_or_unknown）
= 実プロンプト
```

### 各層の責務（境界マトリクス）

| Layer | 役割 | 変更頻度 | 配置 |
|-------|------|--------|------|
| `base_contract` | PlanGate 不変ルール（Iron Law / scope discipline / verification honesty）| **不変**（モデル / phase / mode 越境） | `docs/ai/core-contract.md`（Phase 1 成果） |
| `phase_contract` | phase 別の Goal / Success criteria / Stop rules / Output discipline | 中（phase 追加時） | `docs/ai/contracts/<phase>.md` |
| `risk_mode_contract` | mode 別の検証深度（C-2/V-2/V-3 必要性、fix loop 上限）+ Gate 要件 | 低（mode 分類調整時） | `docs/ai/contracts/<mode>.md` 相当（本 PBI では概念のみ、詳細は `mode-classification.md`）|
| `model_adapter` | モデル別の verbosity / reasoning effort / 出力 style 補正 | 高（モデル世代変更時） | `docs/ai/adapters/<adapter>.md` |

## 3. 上位概念との接続（C-2 EX-03-05 対応）

Prompt Assembly の 4 層は、**[`responsibility-boundary.md`](./responsibility-boundary.md) の Prompt layer 内サブ構造** である。Tool Policy / Hook / CLI validate は **別 layer** であり、本 PBI scope 外:

```text
[Responsibility Boundary]
├── Prompt Layer
│   └── Prompt Assembly（本 PBI、4 層）
├── Tool Policy Layer (PBI-116-06 / docs/ai/tool-policy.md)
├── Hook Layer (PBI-116-06 / docs/ai/hook-enforcement.md)
└── CLI / validate Layer (別 PBI)
```

Eval（PBI-116-05）は本 4 層を切り分けて独立検証する。

## 4. Phase 1 / 2 互換説明

### Core Contract v1 互換（C-2 EX-03-01 対応）

Phase 1 [`core-contract.md`](./core-contract.md) § 3 の Success criteria 表は **6 phase**（classify / plan / approve-wait / execute / review / handoff）で `review` に受入確認を包含。

Prompt Assembly では **`verify` を `review` から分離** し独立 layer として明示化する（**7 phase**）:

| Core Contract v1 (6) | Prompt Assembly (7) | 変更点 |
|--------------------|--------------------|------|
| review（受入確認 + 設計品質）| **review**（設計品質）+ **verify**（受入確認）| `verify` を独立化 |
| その他 5 phase | classify / plan / approve-wait / execute / handoff | 不変 |

→ 既存 Core Contract は変更しない。Prompt Assembly は **拡張的解釈** として 7 phase を採用。

### Phase 2 schema 互換（verbosity_by_phase）

[`schemas/model-profile.schema.json`](../../schemas/model-profile.schema.json) の `verbosity_by_phase` は **5 phase**（classify / plan / execute / review / handoff）。Prompt Assembly が新設する 2 phase の解決方針:

| Prompt Assembly phase | schema 対応 | 解決方針 |
|---------------------|----------|--------|
| `approve-wait` | なし | **verbosity 不適用**（ユーザー承認待ち、AI 出力なし） |
| `verify` | なし | **`review` の verbosity を継承**（review と verify はレビュー観点で連続） |

→ schema 変更は本 PBI scope 外、解決ロジック側で吸収。

## 5. 解決ロジック（擬似コード）

```typescript
// Prompt Assembly の入力型
type PlanGatePromptContext = {
  taskId: string;             // TASK-XXXX
  phase: PhaseId;             // 7 phase enum
  mode: ModeId;               // 5 mode enum
  modelProfile: string;       // "gpt-5_5" 等、model-profiles.yaml キー
  taskContext: string;        // pbi-input + plan + status のサマリ
};

type PhaseId = "classify" | "plan" | "approve-wait" | "execute" | "review" | "verify" | "handoff";
type ModeId = "ultra_light" | "light" | "standard" | "high_risk" | "critical";

// 4 層を組み立てる
function assemble(ctx: PlanGatePromptContext): string {
  const baseContract = readMarkdown("docs/ai/core-contract.md");
  const phaseContract = readMarkdown(`docs/ai/contracts/${ctx.phase}.md`);
  const riskModeContract = lookupRiskMode(ctx.mode); // mode-classification.md 参照
  const profile = readYaml("docs/ai/model-profiles.yaml").models[ctx.modelProfile];
  const modelAdapter = readMarkdown(`docs/ai/adapters/${profile.adapter}.md`);

  // verbosity 解決（Phase 2 schema 互換）
  const verbosity = resolveVerbosity(ctx.phase, profile.verbosity_by_phase);
  // - approve-wait → 不適用
  // - verify → review の値を継承
  // - その他 → schema の値

  return [
    baseContract,         // 不変（必ず先頭）
    phaseContract,        // phase 固有
    riskModeContract,     // mode 別 Gate 要件
    modelAdapter,         // モデル別 style + verbosity 適用
    ctx.taskContext,      // TASK 固有（最後）
  ].join("\n\n");
}

function resolveVerbosity(phase: PhaseId, byPhase: Record<string, "low"|"medium"|"high">): "low"|"medium"|"high"|null {
  if (phase === "approve-wait") return null;          // 不適用
  if (phase === "verify") return byPhase["review"];   // review 継承
  return byPhase[phase];                              // schema 値
}
```

実装言語の選択（TypeScript / shell / Python）は本 PBI scope 外（別 PBI で決定）。

## 6. モデル別 prompt full fork を避ける方針

| アンチパターン | 推奨 |
|------------|------|
| モデルごとに plan.md / exec.md を fork | `model_adapter` だけ差し替え、他 3 層は共通 |
| プロンプトに巨大な JSON 例を埋め込み | [`structured-outputs.md`](./structured-outputs.md) の schema 参照に置き換え |
| `必ず` / `絶対` をプロンプトに散在 | Iron Law を `core-contract.md` の Hard constraints に集約（Phase 1 で達成） |

## 7. .claude/ と plugin/plangate/ への適用

本 4 層構造は `docs/ai/*` で **一般化された定義**。実利用は:

- `.claude/commands/ai-dev-workflow.md` などのコマンド層から本層を参照
- `plugin/plangate/commands/ai-dev-workflow.md` など Plugin 配布版も同じ層を参照
- 配布形態固有の差分は Plugin 限定 rules で表現（[`responsibility-boundary.md`](./responsibility-boundary.md) § 6 共存方針）

実装層への適用は本 PBI scope 外（別 PBI / Plugin 同期 PBI で対応）。

## 8. phase / adapter 一覧

### 7 Phase Contract

| Phase | ファイル | 役割 |
|-------|---------|------|
| classify | [`contracts/classify.md`](./contracts/classify.md) | mode 判定 |
| plan | [`contracts/plan.md`](./contracts/plan.md) | 計画策定 |
| approve-wait | [`contracts/approve-wait.md`](./contracts/approve-wait.md) | C-3 承認待機 |
| execute | [`contracts/execute.md`](./contracts/execute.md) | 実装 |
| review | [`contracts/review.md`](./contracts/review.md) | 設計品質レビュー |
| verify | [`contracts/verify.md`](./contracts/verify.md) | 受入確認 |
| handoff | [`contracts/handoff.md`](./contracts/handoff.md) | 引き継ぎ |

### 4 Model Adapter（schema enum 全件）

| Adapter | ファイル | 想定モデル |
|---------|---------|----------|
| outcome_first | [`adapters/outcome_first.md`](./adapters/outcome_first.md) | gpt-5_5（標準） |
| outcome_first_strict | [`adapters/outcome_first_strict.md`](./adapters/outcome_first_strict.md) | gpt-5_5_pro（強力推論） |
| explicit_short | [`adapters/explicit_short.md`](./adapters/explicit_short.md) | gpt-5_mini（軽量） |
| legacy_or_unknown | [`adapters/legacy_or_unknown.md`](./adapters/legacy_or_unknown.md) | フォールバック |

将来 `schemas/model-profile.schema.json` の `adapter` enum が拡張されたら、対応する `adapters/<name>.md` を追加（C-2 EX-03-04 方針）。

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- TASK: [`docs/working/TASK-0043/`](../working/TASK-0043/)
- Phase 1: [`core-contract.md`](./core-contract.md)
- Phase 2: [`model-profiles.md`](./model-profiles.md) / [`model-profiles.yaml`](./model-profiles.yaml) / [`tool-policy.md`](./tool-policy.md) / [`hook-enforcement.md`](./hook-enforcement.md) / [`responsibility-boundary.md`](./responsibility-boundary.md) / [`structured-outputs.md`](./structured-outputs.md)
- 接続先 Phase 4: PBI-116-05 (Eval Cases) で 4 層を独立検証
