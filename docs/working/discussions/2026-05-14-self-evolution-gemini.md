# 自己進化フレーム外部知見検証: Claude × Gemini ディスカッション

- 日時: 2026-05-14
- 主題: Claude × Codex で確定した「観測 → 評価 → 学習 → ガバナンス」自己進化フレームを、Gemini の Web 検索能力で外部知見と突合する
- 参加者: Claude Code（Opus 4.7）/ Gemini CLI (v0.38.2)
- 前提:
  - `2026-05-14-steering-loop-codex.md`（Steering Loop 強化方針）
  - `2026-05-14-self-evolution-codex.md`（自己進化 15 軸 / 半年ロードマップ）

## Claude のプロンプト（要旨）
4 つの問いを構造化して投げた:
1. Q1: 「観測 → 評価 → 学習 → ガバナンス」フレームの業界・学術での類似概念は何か
2. Q2: dogfooding eval suite の業界ベストプラクティス（LangSmith / Inspect / Braintrust / Aider / Cursor 等）
3. Q3: 着手順序「観測 → 自己評価 → 学習」の業界妥当性、逆順を支持する事例の有無
4. Q4: PlanGate が見落としている観点（OpenTelemetry GenAI / Cost attribution / LLM-as-a-judge 標準化等）

各 Q について **外部ソース URL 引用必須** / 「PlanGate への適用提案」を 2-3 bullet で明示するよう指示。

## Gemini の回答全文

エンジニアリングアドバイザーとして、PlanGateの進化ロードマップを業界・学術の最新動向と照らし合わせ、構造的に分析・評価します。Web検索による事実確認に基づき回答します。

---

## Q1. 業界・学術の類似フレーム

PlanGateが提唱する「観測 → 評価 → 学習 → ガバナンス」という循環は、自律型システムやLLM Opsの世界でいくつかの確立された概念と共鳴しています。

### 1. MAPE-K (Autonomic Computing)
IBMが提唱したクラシックな自律制御モデル **MAPE-K (Monitor-Analyze-Plan-Execute-Knowledge)** は、PlanGateのフレームワークに最も近しい構造です。
- **Monitor (観測):** events.ndjson / Trace Timeline
- **Analyze (評価):** Dogfooding Eval / C-3/C-4 Gates
- **Plan/Execute (学習・制御):** Playbook昇格 / Workflow
- **Knowledge (ガバナンス/記憶):** AGENTS.md / Skill / 15軸の階層
> **引用:** [IBM Autonomic Computing Reference Architecture](https://www.ibm.com/developerworks/library/ac-common.html)

### 2. Reflexion フレームワーク
MIT等の研究チームが発表した **Reflexion** は、エージェントが「自己反省（Linguistic Feedback）」を通じて学習する手法です。
- **異同:** Reflexionは単一タスク内での「試行錯誤」に重点を置いていますが、PlanGateは「開発プロセス全体の再現性とガバナンス」を対象としており、よりマクロな（Ops寄りの）視点を持っています。
> **引用:** [Reflexion: Language Agents with Verbal Reinforcement Learning](https://arxiv.org/abs/2303.11366)

### 3. Cognitive Architectures for LLM Agents
業界では「エージェントの記憶と学習」を整理する際に、**Control (判定) / Memory (記憶) / Perception (観測)** の3要素で構成するフレームが一般的です。PlanGateの「Steering Loop」はこれらを有機的に結合する「OS」の役割を果たそうとしています。
> **引用:** [A Survey on Large Language Model based Autonomous Agents (Tsinghua University)](https://arxiv.org/abs/2308.11432)

#### PlanGate への適用提案
- **Knowledge Baseの明示化:** MAPE-Kにおける「Knowledge」に相当する部分（過去の失敗パターンや成功したPlaybookのDB）を、単なるSkillファイルではなく「ベクトル化された検索可能な記憶」として扱う検討。
- **ループの多層化:** 短期的な「Reflexion（タスク内修正）」と、長期的な「MAPE-K（システム改善）」を分離して定義する。

---

## Q2. Dogfooding Eval Suite のベストプラクティス

「自らを評価する」Dogfooding Evalは、先端的なエージェント基盤において標準的な品質担保手法となりつつあります。

### 1. Braintrust: AI-Native CI/CD
Braintrustは、開発ワークフローの中に「Scorer」を組み込み、リリースごとに「過去の最良のトレース」と比較する仕組みを提供しています。
- **事例:** 開発者が自身のプロンプト変更を評価するために、本番のログ（Traces）をそのままテストケースとしてリプレイ（Backtest）する。
> **引用:** [Braintrust - AI Testing and Evaluation](https://www.braintrust.dev/docs/guides/evals)

### 2. Inspect AI (UK AISI)
イギリスのAI安全研究所が公開した **Inspect AI** は、複雑なエージェントの行動を多角的に評価するためのツールキットです。
- **事例:** 「エージェントが環境を破壊していないか」「ガバナンスに従っているか」を、サンドボックス環境での実行ログから自動判定する。
> **引用:** [UK AISI Inspect AI Framework](https://github.com/UKGovernmentBEIS/inspect_ai)

### 3. Aider / Cursor のアプローチ
- **Aider:** 独自の「Benchmark Suite」を持ち、リポジトリ全体に対する編集の正確性を「自分自身で」測定し、リーダーボードを更新し続けています。
- **Cursor:** 内部的には「ユーザーの修正行動」を最強の正解ラベル（Implicit Feedback）として、予測モデルの評価に利用しています。
> **引用:** [Aider Benchmarks](https://aider.chat/docs/benchmarks.html)

#### PlanGate への適用提案
- **Replayability (再現実行):** v8.7.0で構築するTraceから「失敗したターン」を抽出し、v8.8.0で「その失敗を回避できるか」を自動テストする回帰テストスイートの構築。
- **LLM-as-a-Judgeの多層化:** PlanGateのC-4判定（Orchestrator Mode遵守）をそのまま評価器（Judge）としてCIに組み込む。

---

## Q3. 着手順序の業界妥当性

「観測（v8.7.0）→ 自己評価（v8.8.0）→ 学習（v8.9.0）」という順序は、データエンジニアリングおよびMLOpsの **「Hierarchy of Needs（マズローの欲求階層説になぞらえたデータ活用階層）」** と完全に一致します。

### 1. Data Engineering Hierarchy of Needs
Monica Rogati氏が提唱したこのモデルでは、ピラミッドの底辺に **「Collect (観測・収集)」** があり、その上に **「Clean/Move (整理)」**、**「Analyze (評価・分析)」**、そして頂点に **「A/B Testing, ML (学習・最適化)」** が位置します。
- 観測なしに評価はできず、評価なしに学習（最適化）は不可能です。
> **引用:** [The AI Hierarchy of Needs (Monica Rogati)](https://hackernoon.com/the-ai-hierarchy-of-needs-18f111fcc00d)

### 2. 反論：「学習（データ収集）を先にすべき」という視点
一部の **Data-Centric AI** の立場からは、「評価手法を固める前に、まずは多様な失敗・成功データを集める（学習の準備）べき」という議論があります。
- **事例:** TeslaのAutopilot開発では、「評価基準」が固まる前に「特定のレアケース（例：犬が道を横切る）」の映像をひたすら収集する仕組み（データエンジン）を構築しました。
> **引用:** [Andrej Karpathy - Operation Vacation (Data Engine)](https://karpathy.ai/stateofai.html)

#### PlanGate への適用提案
- **順序の妥当性:** Codex推奨の順序は王道であり、変更の必要なし。
- **並行検討:** v8.7.0の観測段階で、将来の学習（v8.9.0）を見据えて「これはPlaybookに昇格できそうだ」という **"Promising Trace"** にフラグを立てる機能を入れておく（Tesla流のデータ収集）。

---

## Q4. PlanGate が見落としている観点

外部知見から見たPlanGateの不足要素を指摘します。

### 1. OpenTelemetry GenAI Semantic Conventions
業界はログ形式の標準化に向かっています。`events.ndjson` は独自形式ですが、将来的に外部ツール（LangSmith, Honeycomb等）と連携するなら、OpenTelemetryのGenAI仕様に準拠した属性名（`gen_ai.prompt`, `gen_ai.usage.tokens` 等）を組み込むべきです。
> **引用:** [OpenTelemetry Semantic Conventions for GenAI](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/)

### 2. Cost / Token Attribution (経済性ガバナンス)
PlanGateは「Level 0 経済性」を掲げていますが、現状の `events.ndjson` に「どのエージェントが何トークン消費し、何円かかったか」の集計機能が弱い可能性があります。
- **事例:** **LangPortal** や **Helicone** は、エージェントごとのユニットコストを可視化し、閾値を超えた場合にゲートを閉じる機能を持ちます。
> **引用:** [Helicone - LLM Observability](https://www.helicone.ai/)

### 3. LLM-as-a-Judge の「不確実性」管理
評価（v8.8.0）において、LLMによる判定（C-4ゲート等）はそれ自体が揺らぎます。
- **必要要素:** 同じトレースに対して複数回Judgeを実行し、一致率（Confidence）を算出する、あるいは異なるモデル（GPT-4o vs Claude 3.5 Sonnet）でクロスチェックする標準プロトコル。
> **引用:** [Prometheus: Inducing Fine-grained Evaluation Capability in LLMs](https://arxiv.org/abs/2310.08491)

#### PlanGate への適用提案
- **[入れるべき] Token-Aware Events:** `events.ndjson` にトークン使用量とモデル名を必須フィールドとして追加。
- **[入れるべき] OpenTelemetry 互換 Layer:** 独自ログを OTel 形式に変換する Hook または Parser。
- **[まだ不要] Distributed Tracing:** 現在はローカル/単一セッションがメインのため、分散トレーシング（複数サーバー間連携）の複雑性は後回しで良い。

---

## 結論：PlanGate への戦略的アドバイス

1. **v8.7.0 (観測):** 独自進化にこだわりすぎず、**OpenTelemetry互換性** を持たせることで、業界標準の観測ツールを活用可能にする。
2. **v8.8.0 (評価):** 「何が正しいか」をLLMが決める際、**不確実性（Judgeの揺らぎ）** を数値化する仕組みを導入する。
3. **ロードマップ:** 「観測 → 評価 → 学習」は論理的に堅牢。ただし、観測（v8.7.0）の時点で **「将来の学習用データとしてのタグ付け」** を実装することで、v8.9.0の立ち上がりを加速させる。

---

## 決定事項サマリ（Claude 統合）

### 業界知見との照合結果
Gemini 確認により、Codex と決めた「観測 → 評価 → 学習 → ガバナンス」フレームは **業界の主流フレームと完全に整合** することが裏付けられた:

| PlanGate 概念 | 業界対応 | 出典 |
|------------|---------|------|
| 観測 → 評価 → 学習 → ガバナンス | **MAPE-K** (IBM Autonomic Computing) | ibm.com |
| 半年順序の妥当性 | **AI Hierarchy of Needs** (Rogati) | hackernoon |
| 観測時のタグ付け先行 | **Data Engine** (Karpathy / Tesla) | karpathy.ai |
| dogfooding eval | **Braintrust / Inspect AI / Aider Benchmarks** | braintrust.dev / UK AISI / aider.chat |

### 新たに発見した「PlanGate 不足要素」（業界常識との差分）

| 要素 | 評価 | 根拠 |
|-----|-----|------|
| **OpenTelemetry GenAI 準拠** | 入れるべき | 業界が semconv 標準化中。LangSmith/Honeycomb 連携が将来必須 |
| **Token / Cost attribution** | 入れるべき | events.ndjson に必須フィールド化。Helicone 等が常識的に実装 |
| **LLM-as-a-judge の不確実性管理** | 入れるべき | C-4 等の Judge が揺らぐため一致率/Confidence 必要（Prometheus 論文） |
| **Distributed tracing** | 不要（現状） | 単一セッション中心のため後回し可 |

### 順序判断の修正提案（Gemini）
- Codex 推奨「観測 → 評価 → 学習」は王道で変更不要
- ただし **v8.7.0 観測段階で「将来 playbook 昇格候補」のフラグ付け機能** を入れることで、v8.9.0 学習フェーズの立ち上がりを加速（Tesla Data Engine の思想）

### MAPE-K マッピング（PlanGate Self-Evolution = autonomic computing）
```
Monitor   → events.ndjson / Trace Timeline v1
Analyze   → Dogfooding Eval / C-3/C-4 Gates
Plan/Exec → Playbook 昇格 / Workflow / Skill
Knowledge → AGENTS.md / Skill ライブラリ / 15 軸の階層
```
PlanGate は事実上「LLM 開発向けの autonomic computing フレーム」になりつつあると位置付けられる。

### 短期 / 長期ループの分離（Reflexion + MAPE-K）
- **短期**: Reflexion 型タスク内 self-refine（exec 中の自己修正）
- **長期**: MAPE-K 型システム改善（retrospective → playbook）
両者を別ループとして明示すべき。

## 次アクション（前 2 ディスカッションへの統合）

- [ ] `docs/ai/harness-improvement-roadmap.md` Control Plane track 章に **MAPE-K mapping** 図を追加
- [ ] Trace Timeline v1 (PBI-HI-009) Issue に **OpenTelemetry GenAI semantic conventions** 互換 layer を Out of Scope ではなく v8.7.0 → v8.8.0 のいずれかで検討する旨を追記
- [ ] events.ndjson schema 1.1 拡張に **token usage / cost / model_name** フィールドを追加候補とする
- [ ] v8.8.0 Dogfooding Eval Suite の設計に **LLM-as-a-Judge 一致率（multi-judge consensus）** を AC に含める
- [ ] v8.7.0 観測実装時に **"Promising Trace" タグ機能**（Tesla Data Engine 思想）を最小実装

## 参考文献（Gemini 引用）

- IBM Autonomic Computing Reference Architecture (MAPE-K)
- Reflexion: Language Agents with Verbal Reinforcement Learning (arXiv:2303.11366)
- A Survey on Large Language Model based Autonomous Agents (arXiv:2308.11432)
- Braintrust: AI Testing and Evaluation (braintrust.dev)
- UK AISI Inspect AI Framework (github.com/UKGovernmentBEIS/inspect_ai)
- Aider Benchmarks (aider.chat/docs/benchmarks.html)
- The AI Hierarchy of Needs - Monica Rogati (hackernoon)
- Andrej Karpathy - Operation Vacation / Data Engine
- OpenTelemetry Semantic Conventions for GenAI (opentelemetry.io)
- Helicone - LLM Observability
- Prometheus: Inducing Fine-grained Evaluation Capability in LLMs (arXiv:2310.08491)

