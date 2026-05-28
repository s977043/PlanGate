# 高品質な実行計画ができるまで（Plan Creation Process）

> PlanGate の差別化は「ゲート」だけでなく、**承認に値する高品質な実行計画を生むまでのプロセス**にあります。
> 本ドキュメントは、PBI INPUT から C-3 承認に至るまで *何を・なぜ・どの順で* 行っているかを 1 本に通した解説です。
> 各機構の判定基準・不変条件は再定義せず、正本へリンクします（本ドキュメントは「流れと意図」を担う）。

## 1. なぜ PlanGate は「計画」に投資するのか

AI コーディングエージェントの失敗の多くは「実装が下手」ではなく「**前提の取り違え・スコープの誤認・規模の過小評価**」から起きます。PlanGate は実装前にこれらを潰すため、計画を *作文*（それらしい文章）ではなく **実行可能な計画**（誰が・何を・どの順で・どう検証するかが決まっている状態）として生成することを契約で求めます。

- Iron Law: `NO EXECUTION WITHOUT REVIEWED PLAN FIRST`（正本: [`docs/ai/core-contract.md`](../ai/core-contract.md)）
- plan の Goal は「作文ではなく実行可能な計画」（正本: [`docs/ai/contracts/plan.md`](../ai/contracts/plan.md)）

計画フェーズの成果物（`plan.md` / `todo.md` / `test-cases.md`）が承認ゲート C-3 を通って初めて、実装（exec）が解禁されます。**計画の品質がそのまま実装の安全性と完遂率を決める**——これが投資の理由です。

## 2. 計画ができるまでの全体像

```text
Brainstorm（任意）
   ↓  対話で要件・設計を発散→収束（PBI INPUT PACKAGE の素地）
A: PBI INPUT PACKAGE 👤        ← 人間が「何を・なぜ」を構造化して入力
   ↓
B-1: 確認質問（最大 3 問）🤖   ← 曖昧さを潰す
   ↓
★ 事前メトリクス検証（mandatory gate）🤖  ← 「全件」系は実数を取る／3 倍ルール
   ↓
B-2: アプローチ比較（2〜3 案の trade-off）🤖
   ↓
B-3: plan / todo / test-cases 同時生成 + Mode 判定 🤖
   ↓
C-1: セルフレビュー（17 項目）🤖
   ↓
C-2: 外部 AI レビュー（任意 / 観点固定）🤖
   ↓
C-3: 人間レビュー（APPROVE / CONDITIONAL / REJECT）👤
   ↓
→ exec 解禁
```

A〜B は [Workflow](../workflows/README.md) の WF-02（Requirement Expansion）〜 WF-03（Solution Design）に対応します。

## 3. 各ステップで何をしているか

### A: PBI INPUT PACKAGE（人間）

計画の出発点。人間が「何を・なぜ」を構造化して渡します。

- **入力**: 課題・背景
- **行為**: Context / Why、What（In/Out of scope）、受入基準、Refinement メモ、Risks / Unknowns / Assumptions を記述
- **成果物**: `docs/working/TASK-XXXX/pbi-input.md`
- **正本**: [`working-context.md` § pbi-input.md](../../.claude/rules/working-context.md)

> ここが曖昧だと後続すべてが揺れます。Brainstorm フェーズ（任意）は、この PBI INPUT を対話で固めるための前処理です。

### B-1: 確認質問（最大 3 問）

AI が PBI INPUT を読み、計画を立てる前に**曖昧さを最大 3 問だけ**確認します。質問を絞るのは、際限ない往復を避け、本質的な不確実性だけを潰すためです。

- **正本**: [`docs/ai-driven-development.md` § Prompt 1](../ai-driven-development.md) / [`ai-dev-plan` SKILL](../../.agents/skills/ai-dev-plan/SKILL.md)

### ★ 事前メトリクス検証（B-1 → B-2 の mandatory gate）

PlanGate の計画品質を支える要のひとつ。「全部 / 全件 / 残り N 件」のような**規模に関わる対象は、AI の見積もりだけで進めず実数を取得**します。

- **行為**: `grep -rln ... | wc -l` / `find ... | wc -l` / `rg --files | wc -l` で対象範囲を限定して実数を取る
- **3 倍ルール（実数 / AI 見積もり）**:
  - ≥ 3 倍 → スコープ過大。**縮小 or 別タスクへ切替**
  - 1〜3 倍 → 範囲内。採用し plan の Risks / Metrics Evidence に記録
  - < 1 倍 → スコープ過小。**Mode を 1 段下げる候補**
- **安全側不変条件**: 実数取得不能・対象が曖昧・承認境界を含む可能性 → **必ず Mode 引き上げ側に倒す**（`lite_eligible=false`）
- **出力契約**: `plan.md` に `## Metrics Evidence` 欄（見積もり / 実数 / 比率 / 判定）を必須化
- **正本**: [`docs/ai/plan-metrics-verification.md`](../ai/plan-metrics-verification.md)

> 実例: ある画像描き直しタスクで AI は「規模 M」と推奨したが、実数を取ると 1697 ファイル（約 17 倍）。検証なしで着手していれば 1 セッションで完遂不能だった。このゲートが軌道修正を生む。

### B-2: アプローチ比較（2〜3 案の trade-off）

単一案に飛びつかず、**2〜3 案を trade-off 付きで比較**してから採用案を選びます。後から「なぜこの方式か」を C-3 レビュアーが追えるよう、選定理由を残します。

- **監査**: 主要判断を `decision-log.jsonl` に append-only で記録

### B-3: plan / todo / test-cases 同時生成 + Mode 判定

3 ファイルを**同時に**生成します。実装の手順（todo）と検証の基準（test-cases）を計画と同時に確定させることで、「計画はあるがテストがない」状態を構造的に防ぎます。

- **`plan.md`**: Goal / Constraints / Approach Overview / Work Breakdown / Files / Testing Strategy / Risks / Mode 判定 / Metrics Evidence
- **`todo.md`**: タスク粒度 2〜5 分、各タスクに `Owner`（agent/human）・`depends_on`・`files` を必須
- **`test-cases.md`**: 各 受入基準 → テストケースのマッピング、Edge case、自動化可否
- **Mode 判定**: ultra-light / light / standard / high-risk / critical の 5 段階。承認境界に触れるパスは最低 high-risk へ自動補正
- **正本**: [`mode-classification.md`](../../.claude/rules/mode-classification.md) / [`working-context.md`](../../.claude/rules/working-context.md)

### C-1: セルフレビュー（17 項目）

生成した計画を AI 自身が 17 項目で点検します（Plan 7 / ToDo 5 / TestCases 3 + 判定）。受入基準の網羅、Unknowns 処理、スコープ制御、テスト戦略、依存関係などを PASS / WARN / FAIL で評価。

- **成果物**: `review-self.md`
- **正本**: [`working-context.md` § review-self.md](../../.claude/rules/working-context.md)

### C-2: 外部 AI レビュー（任意 / 観点固定）

別モデル（Codex / Gemini 等）による計画レビュー。指摘は `review-external.md` に **指摘 ID `R-NNN`** で追記専用集約し、計画本体への反映は 1 回だけ確定します（版管理の破綻を防ぐ）。

- **責務 2 レーン**: 設計妥当性レーン（plan を読む）/ コードベース整合レーン（既存パターンとの不整合を見る）
- **正本**: [`review-principles.md` § 7-bis](../../.claude/rules/review-principles.md) / [`external-reviewer-interface.md`](../ai/external-reviewer-interface.md)

### C-3: 人間レビュー（三値ゲート）

計画を承認できるかを人間が判断します。**ここを通るまで実装は 1 行も解禁されません**。

- **APPROVE**: exec 開始（`approvals/c3.json` に APPROVED + 確定後 plan の `plan_hash`）
- **CONDITIONAL**: R-NNN 反映 → 簡易 C-1 → APPROVED 発行 → exec
- **REJECT**: plan 再生成
- **正本**: [`working-context.md` § C-3 ゲート](../../.claude/rules/working-context.md)

## 4. 高品質を担保している仕組み

計画品質は「頑張る」ではなく**構造**で担保しています。

| 仕組み | 何を防ぐか | 正本 |
| --- | --- | --- |
| Success criteria | 必須セクション欠落（実行不能な計画） | [`contracts/plan.md`](../ai/contracts/plan.md) |
| Stop rules | 受入基準未カバー／scope 外作業の混入 | [`contracts/plan.md`](../ai/contracts/plan.md) |
| 事前メトリクス検証（3 倍ルール） | 規模の過小評価・スコープ過大 | [`plan-metrics-verification.md`](../ai/plan-metrics-verification.md) |
| 安全側不変条件（AC-8） | 判定不能時に楽観側へ倒れること | [`mode-classification.md`](../../.claude/rules/mode-classification.md) |
| 3 ファイル同時生成 | 「計画はあるがテストがない」 | [`working-context.md`](../../.claude/rules/working-context.md) |
| C-1 / C-2 / C-3 多層レビュー | 単一視点の見落とし | [`review-principles.md`](../../.claude/rules/review-principles.md) |
| plan_hash + C-3 ゲート | 承認後の計画こっそり改変 | [`core-contract.md`](../ai/core-contract.md) |

## 5. 成果物チェックリスト（C-3 に出す前）

- [ ] `pbi-input.md` に受入基準・In/Out of scope がある
- [ ] `plan.md` に Goal / Constraints / Approach / Work Breakdown / Files / Testing Strategy / Risks / Mode / **Metrics Evidence** が揃っている
- [ ] 「全件」系の対象は**実数**を取り、3 倍ルールで判定済み
- [ ] `todo.md` の全タスクが 2〜5 分粒度 + Owner / depends_on / files 付き
- [ ] `test-cases.md` で全受入基準 → テストケースが紐づき、Edge case を含む
- [ ] `review-self.md`（C-1 17 項目）が PASS、FAIL は evidence 付き
- [ ] Mode 判定の根拠が記録されている（承認境界に触れるなら最低 high-risk）

## 6. 参考資料（正本クロスリファレンス）

- 実行契約: [`docs/ai/core-contract.md`](../ai/core-contract.md)
- plan フェーズ contract: [`docs/ai/contracts/plan.md`](../ai/contracts/plan.md)
- 事前メトリクス検証: [`docs/ai/plan-metrics-verification.md`](../ai/plan-metrics-verification.md)
- Mode 分類: [`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
- 作業コンテキスト / ゲート: [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md)
- レビュー原則: [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md)
- plan 生成 skill: [`.agents/skills/ai-dev-plan/SKILL.md`](../../.agents/skills/ai-dev-plan/SKILL.md)
- ワークフロー全体像 / プロンプト: [`docs/ai-driven-development.md`](../ai-driven-development.md)
- Workflow 定義（WF-02 / WF-03）: [`docs/workflows/README.md`](../workflows/README.md)
- 全体ガイド: [`docs/plangate.md`](../plangate.md)
