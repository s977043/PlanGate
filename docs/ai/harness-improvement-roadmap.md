# Harness Improvement Roadmap

> **Status**: v1.1（Phase 0 / 1 + Governance Done — v8.6.0 で完走、Phase 2 以降と Lightweight Plan Quality Checks は Proposed）
> **Progress**: Phase 0 ✅ / Phase 1 ✅ / Governance (#201, #202) ✅ / Phase 2〜6 🔵 Open / Lightweight Plan Quality Checks (#213) 🔵 Open
> 関連: [`philosophy.md`](../philosophy.md) / [`eval-plan.md`](./eval-plan.md) / [`eval-runner.md`](./eval-runner.md) / [`metrics.md`](./metrics.md) / [`metrics-privacy.md`](./metrics-privacy.md) / [`issue-governance.md`](./issue-governance.md) / [`eval-baselines/2026-05-04-baseline.md`](./eval-baselines/2026-05-04-baseline.md) / [`model-profiles.md`](./model-profiles.md) / [`prompt-assembly.md`](./prompt-assembly.md) / [`tool-policy.md`](./tool-policy.md) / [`hook-enforcement.md`](./hook-enforcement.md)

## 1. 目的

PlanGate を「固定されたゲート型ワークフロー」ではなく、**モデル差分・実利用データ・評価結果をもとに継続改善される AI ハーネス製品**として育てる。

既存の PlanGate は、C-3 / C-4 ゲート、成果物永続化、検証、Model Profile、Prompt Assembly、Tool Policy、Hook Enforcement、Eval Runner を持つ。本ロードマップは、これらを土台に次の段階へ進めるための実装順序を定義する。

中心方針:

```text
仮説 → ハーネス変更 → eval → 実利用シグナル計測 → 採用 / rollback → retrospective
```

## 2. 背景

AI コーディングエージェントの品質は、モデル単体だけでは決まらない。モデルに渡すコンテキスト、使わせるツール、編集インターフェース、承認境界、検証方法、失敗時の回復、実利用メトリクスによって大きく変わる。

PlanGate はこの外枠を担うハーネスである。したがって、PlanGate 自体も通常のソフトウェア製品と同じく、仮説、実験、測定、改善のループで育てる。

加えて、計画品質は実装後の eval / metrics だけではなく、実装前の段階で構造化できる。`gstack` 的な重い agent workflow を直接移植するのではなく、まずは Plan Check / Risk Check / Done Check によって、不足情報・リスク・前提・完了条件を軽量に見える化する。

## 3. 設計原則

| 原則 | 内容 |
| --- | --- |
| Hard gate は残す | C-3 / C-4 / scope / verification honesty / evidence は PlanGate の中核として維持する |
| 補助輪は減らす | モデルが自力で取得できる情報は、固定注入ではなく動的取得へ移す |
| モデル差分を明示する | プロンプト全文 fork ではなく、Model Profile / adapter / tool interface preference で吸収する |
| 感覚判断を禁止する | Profile / prompt / workflow 変更は eval と実利用シグナルで判断する |
| 成果物の残存を測る | code だけでなく plan / test-cases / handoff の Keep Rate を見る |
| 計画品質を先に構造化する | 実装・QA・release の前に Missing Items / Risks / Assumptions / Done Criteria を抽出する |
| 低リスクは軽く、高リスクは厳しく | mode に応じて検証深度、context budget、strictness を変える |

## 4. 現状ベースライン

PlanGate にはすでに以下が存在する。

| 領域 | 既存資産 | 次の伸びしろ |
| --- | --- | --- |
| Workflow / Gate | C-3 / C-4、WF-01〜WF-05、Orchestrator | Gate 通過率 / 差し戻し率の計測 |
| Model Profile | `reasoning_effort` / `verbosity` / `context budget` / `tool_policy` / `validation_bias` | 編集形式、retry strategy、provider capability の追加 |
| Prompt Assembly | `base_contract` + `phase_contract` + `risk_mode_contract` + `model_adapter` | Context Engine との接続 |
| Tool Policy | phase 別 allowed tools + profile 射影 | provider / model 別の tool interface preference |
| Hook Enforcement | EH-1〜EH-7 / EHS-1〜EHS-3 | violation を改善データとして集計 |
| Eval | 8 観点 + release blocker + `bin/plangate eval` | 実利用シグナル、Keep Rate、session log parser 拡張 |
| Plan Quality | C-3 plan / test-cases / handoff | Missing Items / Risks / Assumptions / Done Criteria の構造化 |

## 5. ロードマップ概要

> **v1.2 (2026-05-15 更新)**: Claude × Codex × Gemini の 5 ディスカッション（Steering Loop / 自己進化軸 / 外部知見照合 / Devil's Advocate / 外部ユーザー視点）を経て、v8.7.0 主軸を **OSS 整備（#226/#224/#225）** に組み替え。自己進化機能は副・experimental 扱いに格下げ。ログ: `docs/working/discussions/2026-05-14-*.md` / `2026-05-15-external-user-codex.md`

| Phase | 名称 | 目的 | 主な成果物 | Status |
| --- | --- | --- | --- | --- |
| 0 | Baseline alignment | 既存 eval / hook / profile の現在地を固定する | baseline report | ✅ Done (v8.6.0 / #194) |
| 1 | Metrics v1 | 実利用シグナルを保存できるようにする | event schema / metrics command | ✅ Done (v8.6.0 / #195) |
| **v8.7.0 主** | **段階的導入ガイド** | OSS 利用者の最大摩擦「どこまで使えばよいか不明」を解消する | Level 1-5 導入レベル / docs | 🔵 Open (v8.7.0 / #226) |
| **v8.7.0 主** | **Plugin 成熟化** | 配布の確実性を機能思想より先に固める | 解決順 / prefix / 更新手順 | 🔵 Open (v8.7.0 / #224) |
| **v8.7.0 主** | **バージョニング安定性ポリシー** | breaking vs additive を明文化、既存 artifact 互換を保証 | versioning-policy.md | 🔵 Open (v8.7.0 / #225) |
| v8.7.0 副 | Run Outcome Review v1 | run 完了時の振り返りを軽量 markdown で標準化 | outcome-review.md template | 🔵 Open (v8.7.0 / #228) |
| v8.7.0 副 | Lightweight Plan Quality Checks | 計画の不足・リスク・前提・完了条件を軽量に構造化する | Plan Check / Risk Check / Done Check | 🔵 Open (v8.7.0 / #213) |
| v8.7.0 副 | Harness Eval expansion | eval-runner をハーネス変更判断に使いやすくする | comparison / release gate 拡張 | 🔵 Open (v8.7.0 / #196) |
| v8.7.0 副 | Tool Error Taxonomy | hook/tool failure の分類軸 | error taxonomy / recovery policy | 🔵 Open (v8.7.0 / #203) |
| v8.7.0 副 | PlanGateBench Fixture | 評価対象固定 | fixture suite | 🔵 Open (v8.7.0 / #204) |
| v8.7.0 実験 | Trace Timeline v1 (Experimental) | 観測基盤の最小実装、quickstart 非掲載 | schema 1.1 additive / timeline JSON | 🔵 Open (v8.7.0 / #229) |
| v8.8.0 | Dogfooding Eval v1 | PlanGate 自身を評価対象にする (single judge + human rationale) | eval suite / fixture | 🔵 Open (v8.8.0 / #231) |
| v8.8.0 | Gate Event Normalization | gate_id / phase / status の語彙正規化 | normalized schema | 🔵 Open (v8.8.0 / #230) |
| v8.8.0 | Model Profile v2 | モデルごとの実行特性を表現する | edit interface / retry / capability | 🔵 Open (v8.8.0 / #197) ← v8.7.0 から押し出し |
| v8.8.0 | Keep Rate | AI 成果物が残ったかを測る | code / plan / acceptance / handoff keep rate | 🔵 Open (v8.8.0 / #198) |
| v8.9.0 候補 | Dynamic Context Engine | 契約コンテキストと作業コンテキストを分離する | context manifest / context command | 🔵 Open (v8.9.0 / #199) |
| v8.9.0 候補 | Reporting & Retrospective | スプリント改善に接続する | metrics report / retrospective template | 🔵 Open (v8.9.0 / #200) |
| - | Issue/Label/Milestone Governance | Issue 運用ルール固定 | issue-governance.md / Issue Form | ✅ Done (v8.6.0 / #201) |
| - | Metrics Privacy Policy | metrics 公開・秘匿境界 | metrics-privacy.md | ✅ Done (v8.6.0 / #202) |

**注**: v8.9.0 の確定スコープは v8.8.0 完了後に判断する（Devil's Advocate ラウンドの「半年フル 3 milestone は過大」結論を反映）。

## 6. Phase 0: Baseline alignment

### 目的

今後の改善を比較可能にするため、現行 PlanGate の baseline を固定する。

### 作業

- 代表 TASK を 3〜5 件選ぶ
- `bin/plangate eval` で baseline を出す
- hook violation / C-3 / C-4 / V-1 / handoff の現状を確認する
- 現行 Model Profile ごとの比較表を残す

### 成果物

```text
docs/ai/eval-baselines/
  2026-XX-XX-baseline.md
  2026-XX-XX-baseline.json
```

### 完了条件

- baseline 対象 TASK が明記されている
- 8 観点 eval 結果が残っている
- release blocker 有無が明記されている
- 以後の profile / prompt / workflow 変更と比較できる

## 7. Phase 1: Metrics v1

### 目的

PlanGate の実利用イベントを append-only で記録し、改善判断に使える状態にする。

### 対象イベント

| Event | 意味 |
| --- | --- |
| `task_initialized` | working context 作成 |
| `plan_generated` | plan / todo / test-cases 生成 |
| `c3_decided` | C-3 の APPROVE / CONDITIONAL / REJECT |
| `exec_started` | 実装開始 |
| `hook_violation` | EH / EHS 違反検知 |
| `v1_completed` | 受入検査結果 |
| `fix_loop_incremented` | V-1 fix loop 回数 |
| `external_review_completed` | V-3 結果 |
| `pr_created` | PR 作成 |
| `c4_decided` | C-4 の APPROVE / REQUEST CHANGES |
| `handoff_completed` | handoff 完了 |

### 成果物

```text
schemas/plangate-event.schema.json
scripts/metrics-collector.py
bin/plangate metrics <TASK-XXXX>
docs/ai/metrics.md
docs/working/_metrics/events.ndjson
```

### 最小スキーマ案

```json
{
  "ts": "2026-05-03T00:00:00Z",
  "task_id": "TASK-XXXX",
  "event": "c3_decided",
  "phase": "plan",
  "mode": "standard",
  "model_profile": "gpt-5_5",
  "provider": "codex",
  "decision": "APPROVE",
  "metadata": {}
}
```

### 完了条件

- event schema が存在する
- CLI から TASK 単位の summary を出せる
- hook violation が metrics に集計される
- 既存 workflow を壊さず opt-in で使える

## 8. Phase 2: Harness Eval expansion

### 目的

`bin/plangate eval` を、単発 TASK 評価だけでなく、ハーネス変更の採用判断に使えるようにする。

### 作業

- baseline 比較を profile / prompt / workflow 変更単位で扱う
- release blocker を PR / release checklist に組み込む
- session log parser を拡張する
- tool call count / retry count / hook violation count を eval 結果に入れる

### 成果物

```text
schemas/eval-result.schema.json        # 必要なら拡張
scripts/eval-runner.py                 # comparison 拡張
docs/ai/eval-runner.md                 # 運用手順更新
docs/ai/eval-comparison-template.md    # metrics 列追加
```

### 追加したい列

| 列 | 内容 |
| --- | --- |
| gate_bounce_rate | C-3 / C-4 差し戻し率 |
| hook_violation_count | EH / EHS 違反数 |
| v1_first_pass | V-1 初回 PASS の有無 |
| fix_loop_count | 修正ループ回数 |
| tool_call_count | tool 呼び出し回数 |
| rework_count | AI 出力後の再修正数 |
| plan_health_score | Lightweight Plan Quality Checks による計画品質スコア |
| open_risk_assumption_count | 未解決 risk / assumption の合計数（Lightweight Plan Quality Checks 出力）|

### 完了条件

- harness 変更前後の比較が 1 コマンドで出せる
- release blocker が機械判定される
- 代表 TASK 3 件以上で比較結果が残る

## 9. Phase 3: Model Profile v2

### 目的

モデルごとの「得意な実行形式」を Model Profile に明示する。

### 追加候補

```yaml
edit_interface_preference:
  primary: patch
  fallback: string_replace
context_acquisition:
  strategy: dynamic_first
  initial_context_budget: standard
retry_strategy:
  on_edit_failure: reread_then_retry_small_diff
  on_test_failure: inspect_error_then_fix
provider_capabilities:
  supports_patch: true
  supports_string_replace: true
  supports_parallel_subagents: false
telemetry_tags:
  provider: openai
  generation: gpt-5.5
```

### 方針

- Core Contract / Gate / Artifact schema はモデル別に変更しない
- 変更するのは adapter / tool interface / context budget / retry / validation bias に限定する
- 未知モデルは `legacy_or_unknown` に倒す

### 成果物

```text
schemas/model-profile.schema.json       # v2 拡張
docs/ai/model-profiles.yaml             # profile 更新
docs/ai/model-profiles.md               # 説明更新
docs/ai/adapters/*.md                   # 必要に応じて追加
```

### 完了条件

- profile v2 schema が定義されている
- 既存 profile が v2 に移行されている
- unknown model fallback が維持されている
- eval で v1 baseline と比較されている

## 10. Support: Lightweight Plan Quality Checks

### 目的

`gstack` 的な重い agent workflow を直接移植せず、計画品質を上げる思想だけを PlanGate に軽量に取り込む。

PlanGate の初期価値は、AI が PR review / QA / release まで自動実行することではなく、計画の不足・リスク・暗黙の前提・完了条件を早い段階で明らかにすることにある。

この支援項目では、Plan Check / Risk Check / Done Check を定義し、AI の指摘を自由文ではなく Plan の状態として保存できるようにする。

### Check types

| Check | 目的 | 主な出力 |
| --- | --- | --- |
| `plan_check` | 計画の目的、対象、成功条件、スコープを確認する | score, missing_items, summary |
| `risk_check` | 失敗要因、依存関係、未決事項、暗黙の前提を確認する | risks, assumptions, next_actions |
| `done_check` | 完了条件、検証方法、リリース後確認を確認する | done_criteria, validation_notes |

### 成果物

```text
schemas/plan-quality-check.schema.json
skills/plan-quality-check/SKILL.md
docs/ai/plan-quality-checks.md
bin/plangate
```

### 出力項目

| 項目 | 内容 |
| --- | --- |
| Plan Health Score | 計画品質の概算スコア |
| Missing Items | 不足している情報 |
| Risks | 起きると困ること |
| Assumptions | 正しい前提として置いていること |
| Done Criteria | 完了条件 |
| Next Actions | 次に決める / 確認すること |

### 完了条件

- `Plan Check` / `Risk Check` / `Done Check` の責務が文書化されている
- Missing Items / Risks / Assumptions / Done Criteria / Next Actions の出力構造が定義されている
- Plan Health Score の最小内訳が定義されている
- AI 出力が自由文だけでなく JSON として扱える
- 軽量 Check は手動実行できる
- Check 結果を Plan の状態として保存できる方針がある
- heavy Gate / PR review / browser QA に依存しない
- `gstack` は参考思想に留め、直接移植しない方針が明記されている

## 11. Phase 4: Keep Rate

### 目的

AI が作った成果物が、本当にチーム開発で採用・維持されたかを測る。

### 指標

| 指標 | 内容 |
| --- | --- |
| Code Keep Rate | AI が変更したコードが一定時間後も残っている割合 |
| Plan Keep Rate | C-3 承認済 plan の todo / 方針が handoff まで維持された割合 |
| Acceptance Keep Rate | `test-cases.md` の受入条件が V-1 / V-4 まで有効だった割合 |
| Handoff Keep Rate | `handoff.md` の既知課題 / V2 候補 / 妥協点が後続 PBI で参照された割合 |

### 測定タイミング

- PR 作成時
- PR merge 時
- merge 後 24h
- merge 後 7d
- 関連 PBI 開始時

### 成果物

```text
scripts/keep-rate.py
bin/plangate keep-rate <TASK-XXXX>
schemas/keep-rate-result.schema.json
docs/ai/keep-rate.md
```

### 完了条件

- 最低 Code / Plan / Acceptance の 3 指標を算出できる
- 算出不能な場合は `unknown` として honesty を保つ
- eval / metrics report に取り込める

## 12. Phase 5: Dynamic Context Engine

### 目的

固定コンテキスト注入を減らし、phase / mode / model に応じて必要な情報を動的に組み立てる。

### 方針

| 種別 | 扱い |
| --- | --- |
| PBI / approved plan / test-cases / C-3 承認 (c3.json) | 契約コンテキストとして固定 |
| git status / diff / recent files / test failure | 作業コンテキストとして動的取得 |
| repo structure / coding rules | 必要時取得 |
| 過去 handoff / 関連 PBI | 必要時検索 |

### Context Manifest 案

```json
{
  "task_id": "TASK-XXXX",
  "contract_context": [
    "pbi-input.md",
    "plan.md",
    "test-cases.md",
    "approvals/c3.json"
  ],
  "dynamic_sources": [
    { "type": "git", "name": "git_status", "refresh": "before_execute" },
    { "type": "filesystem", "name": "recent_files", "refresh": "session_start" },
    { "type": "test", "name": "last_test_failure", "refresh": "after_test" }
  ]
}
```

### 成果物

```text
schemas/context-manifest.schema.json
scripts/context-engine.py
bin/plangate context <TASK-XXXX> --phase execute --profile gpt-5_5
docs/ai/context-engine.md
```

### 完了条件

- contract context と dynamic context が分離されている
- mode / profile に応じた context budget が適用される
- stale plan / stale C-3 は Hook / validate と矛盾しない
- Prompt Assembly との接続方針が明記されている

## 13. Phase 6: Reporting & Retrospective

### 目的

PlanGate の実利用シグナルを、スプリントレビュー / retrospective で使える形にする。

### レポート項目

| 項目 | 意味 |
| --- | --- |
| C-3 approval / conditional / reject | plan 品質 |
| C-4 approve / request changes | exec 品質 |
| V-1 first pass rate | 実装・受入条件の一致度 |
| fix loop count | 自己修正効率 |
| hook violation rate | ガードレール違反傾向 |
| Plan Health Score | 計画品質の変化 |
| Open Risk / Assumption Count | 未解決 risk / assumption の傾向（`open_risk_assumption_count` 由来）|
| Keep Rate | AI 成果物の実採用度 |
| latency / cost | 運用効率 |
| model profile comparison | profile ごとの費用対効果 |

### 成果物

```text
bin/plangate report --from <date> --to <date>
docs/ai/reporting.md
docs/working/retrospective-template.md
```

### レトロスペクティブで使う問い

```text
今スプリントで AI が最も失敗した phase はどこか？
C-3 差し戻しは PBI の問題か、profile / prompt / context の問題か？
Plan Check で検出された不足情報は、実装中の手戻りを減らしたか？
Risk Check で検出された risk / assumption は、後続の失敗と対応していたか？
V-1 失敗は test-cases の弱さか、exec の弱さか？
どの Model Profile が最も費用対効果が良かったか？
次スプリントで 1 つだけハーネス改善するなら何か？
```

### 完了条件

- 期間指定で metrics report が出る
- sprint retrospective に貼れる Markdown が生成される
- 次の harness improvement PBI 候補が抽出できる

## 13.5. Control Plane track（v1.2 追加）

> **位置づけ**: Steering Loop A-F は新ロードマップではなく、既存 Phase 2〜6 に重ねる **横断 track**。
> **議論経緯**: `docs/working/discussions/2026-05-14-steering-loop-codex.md` / `2026-05-14-self-evolution-codex.md` / `2026-05-14-self-evolution-gemini.md` / `2026-05-14-devils-advocate-codex.md` / `2026-05-15-external-user-codex.md`

### 13.5.1 自己進化フレーム（MAPE-K mapping）

| 自己進化要素 | PlanGate での担当 | 業界対応 |
| --- | --- | --- |
| Monitor (観測) | events.ndjson / Trace Timeline v1 (Experimental) | OpenTelemetry GenAI semconv (参考、準拠は v8.8.0 以降判断) |
| Analyze (評価) | Dogfooding Eval v1 (v8.8.0) / C-3/C-4 / Run Outcome Review | LLM-as-a-Judge（single judge + human rationale）|
| Plan/Execute (学習・制御) | Playbook 昇格（v8.9.0 候補）/ Workflow | Reflexion（短期）+ MAPE-K（長期）の二層 |
| Knowledge (記憶) | AGENTS.md / Skill / handoff / docs/ai | Cognitive Architectures for LLM Agents |

> **重要**: Steering Loop は自己進化の **中心** ではなく **観測・再現基盤**。中心は「評価 → 学習 → ガバナンス」。Steering Loop はこの 3 つを強化するが代替しない（Devil's Advocate ラウンド検証済み）。

### 13.5.2 自己進化 15 軸の地図（実装計画ではなく参照地図）

```text
Level 0 (制約・安全):   安全性 / ガバナンス / 経済性
Level 1 (見える化):     観測 / 記憶 / 外部環境適応
Level 2 (比較・説明):   再現性 / 自己評価 / 品質回帰 / 因果分析
Level 3 (改善候補生成): 学習 / 協調 / 標準化
Level 4 (改善最適化):   適応 / 探索最適化
```

実装計画に直結させると過大化するため、**地図として残し、実装計画とは切り離す**（Devil's Advocate ラウンド推奨）。

### 13.5.3 段階的導入レベル（#226 で具体化）

外部 OSS 利用者は段階的に PlanGate を採用できる:

- **Level 1**: plan 承認だけ
- **Level 2**: handoff まで
- **Level 3**: hooks / validate
- **Level 4**: metrics / outcome review ← **自己進化軸は実質ここから開始**（Run Outcome Review v1 は自己進化軸の主役）
- **Level 5**: eval / timeline（dogfooding eval / experimental timeline）

初回導線（quickstart）に自己進化機能を混ぜない。Level 5 の機能は experimental / advanced 扱い。

### 13.5.4 意図的に切り捨てる軸（明示）

以下は **OSS 価値より維持費が勝つ** ため切り捨てる:

- **OpenTelemetry GenAI semconv 準拠**: docs 参考情報のみ。実装論点にしない。
- **Token / Cost attribution の schema 必須化**: 任意メタデータに留める。
- **LLM-as-a-Judge multi-judge consensus**: v8.8.0 AC にしない。single judge で十分。
- **自動学習 / skill 自動更新**: 1 人運用では誤学習回復コストが高い。人間承認つき markdown 記録のみ。
- **Promising Trace タグの先行実装**: 判定基準未定。`reusable_decision` 等の素朴ラベルに置換。
- **「自己進化」という用語の対外表現**: 実務語彙（run review / timeline / regression check）に置換。

### 13.5.5 Event schema policy

`events.ndjson` は `schema_version: 1.1` へ additive bump:

- 追加 optional top-level fields: `gate_id` / `phase` / `parent_event_id` の **3 件のみ**（議論初期の 6 件案から削減）
- `trace_id` / `artifact_refs` / `policy_refs` は v8.8.0 以降に判断
- `additionalProperties: false` と Metrics Privacy Policy (#202) は維持
- 既存 1.0 event は後方互換で読める

> **注 (steering-loop ログとの整合)**: `2026-05-14-steering-loop-codex.md` Round 2 の DoD 7 項目では `trace_id` を前提とした紐付け規則が記載されているが、Round 4 Devil's Advocate ラウンドで「schema を広げすぎる罠」を考慮し、v8.7.0 では `parent_event_id` のみで紐付けを成立させる方針に **修正済み**。`trace_id` の追加判断は v8.8.0 で再評価する。

### 13.5.6 OSS 価値整合（Round 5 確定）

| 機能 | OSS としての価値 | 個人最適化リスク | 判断 |
| --- | --- | --- | --- |
| Trace Timeline | 監査・再現・debug | イベント粒度が作者運用に最適化されやすい | v8.7.0 は experimental に格下げ |
| Run Outcome Review | チームでも個人でも振り返り型 | 項目過多でメモ化 | v8.7.0 の自己進化軸の主役 |
| Dogfooding Eval | ハーネス変更の退行検知 | 評価ケースが作者 repo 閉じ | v8.8.0、外部 fixture 意識 |
| events.ndjson 拡張 | 自動分析の材料 | privacy / 互換負債 | 最小 additive のみ |
| 自動学習 / skill 自動更新 | 将来価値 | OSS では危険 | 延期 |

### 13.5.7 チーム導入で破綻する 5 箇所（要明文化）

3〜10 人チーム導入時に破綻する箇所（Round 5 で抽出）:

1. **Outcome Review の競合** → owner 1 名集約、複数人入力は別ファイル
2. **events.ndjson 共有** → v8.7.0 では共有 store を作らない（個人ローカル、summary だけ転記）
3. **handoff 作成責任** → 実装 owner、C-4 前 reviewer 確認、merge 後追記禁止
4. **Skill/Playbook 所有権** → 通常 PR と同じ扱い、自動更新禁止
5. **Mode 判定揺らぎ** → decision table + 例外集を先に整備

## 14. 優先順位

最初に着手する順序は以下を推奨する。

1. **Phase 1: Metrics v1** — 実利用シグナルがないと以後の改善が感覚判断になる
2. **Phase 2: Harness Eval expansion** — 既存 eval-runner を採用判断に使えるようにする
3. **Phase 3: Model Profile v2** — provider / model 差分を実行層に反映する
4. **Lightweight Plan Quality Checks** — plan / risk / done の品質を構造化し、後続 metrics / eval / reporting の入力にする
5. **Phase 4: Keep Rate** — 成果物が実際に残ったかを見る
6. **Phase 5: Dynamic Context Engine** — context の肥大化を抑え、モデル性能向上に追随する
7. **Phase 6: Reporting & Retrospective** — チーム改善サイクルに接続する

## 15. PBI 候補

### PBI-HI-001: Metrics v1

```text
As a PlanGate maintainer,
I want workflow events to be recorded as structured metrics,
So that harness improvements can be judged by real usage signals.
```

Acceptance Criteria:

- `schemas/plangate-event.schema.json` が存在する
- `docs/working/_metrics/events.ndjson` に append-only で記録できる
- `bin/plangate metrics <TASK>` で summary を出せる
- hook violation / C-3 / V-1 / C-4 が最低限集計される

### PBI-HI-002: Eval comparison for harness changes

```text
As a PlanGate maintainer,
I want eval results to compare harness changes against a baseline,
So that profile / prompt / workflow changes are not released by intuition.
```

Acceptance Criteria:

- baseline と target の比較が出る
- release blocker が明示される
- latency / cost / hook violation / V-1 first pass が比較される
- 代表 TASK 3 件以上で比較できる

### PBI-HI-003: Model Profile v2

```text
As a PlanGate maintainer,
I want model profiles to include tool interface and retry preferences,
So that each provider can use the execution style it handles best.
```

Acceptance Criteria:

- `edit_interface_preference` が schema 化される
- 既存 profile が v2 に移行される
- unknown model fallback がある
- eval baseline との比較が残る

### PBI-PQ-001: Lightweight Plan Quality Checks

```text
As a PlanGate maintainer,
I want plans to be checked for missing information, risks, assumptions, and done criteria,
So that teams can improve plan quality without introducing heavy agent workflow automation.
```

Acceptance Criteria:

- `Plan Check` / `Risk Check` / `Done Check` の責務が文書化されている
- Missing Items / Risks / Assumptions / Done Criteria / Next Actions の出力構造が定義されている
- Plan Health Score の最小内訳が定義されている
- AI 出力が自由文だけでなく JSON として扱える
- heavy Gate / PR review / browser QA に依存しない

### PBI-HI-004: Keep Rate v1

```text
As a PlanGate maintainer,
I want to measure whether AI-generated artifacts remain useful,
So that PlanGate can optimize for accepted work, not just generated work.
```

Acceptance Criteria:

- Code Keep Rate / Plan Keep Rate / Acceptance Keep Rate を算出できる
- 算出不能時は `unknown` と明記する
- results が JSON / Markdown で保存される

### PBI-HI-005: Dynamic Context Engine v1

```text
As a PlanGate maintainer,
I want context to be assembled dynamically by phase, mode, and profile,
So that agents receive enough information without excessive static context.
```

Acceptance Criteria:

- `context-manifest.schema.json` が存在する
- contract context と dynamic context が分かれている
- `bin/plangate context` で resolved context を出せる
- Prompt Assembly との接続方針が documented である

## 16. Non-goals

本ロードマップでは以下を直接の目的にしない。

- C-3 / C-4 を弱めること
- PlanGate を完全自律型 coding agent にすること
- すべてのタスクで最大検証を強制すること
- 特定 provider 専用の workflow に寄せること
- LLM judge の判定を hard gate にすること
- `gstack` の slash command / browser daemon / PR review automation をそのまま移植すること

## 17. リスクと対策

| リスク | 対策 |
| --- | --- |
| metrics が増えて運用が重くなる | Phase 1 は opt-in / append-only / 最小 event から始める |
| LLM judge が誤判定する | satisfaction signal は soft metric とし、release blocker にしない |
| Lightweight Plan Quality Checks が hard gate 化して重くなる | 初期は手動実行可能な lightweight check とし、blocking 判定にしない（Plan / Risk / Done Check のいずれも非 blocking 維持）|
| Keep Rate 算出が不安定 | unknown を許容し、honesty を優先する |
| context engine が複雑化する | contract / dynamic の 2 分類から始める |
| profile v2 が provider 固有に寄りすぎる | Core Contract / Gate / Artifact schema は共通維持する |

## 18. 推奨する最初の着手

最初は **PBI-HI-001: Metrics v1** から始める。

理由:

- 現在の PlanGate には eval-runner と hook があるが、実利用イベントの統一ログがまだ薄い
- Metrics が入ると、以後の Model Profile v2 / Keep Rate / Context Engine の効果測定が可能になる
- 実装範囲を schema + collector + summary に限定すれば、既存 workflow を壊しにくい

最初の実装単位:

```text
1. schemas/plangate-event.schema.json
2. scripts/metrics-collector.py
3. bin/plangate metrics <TASK-XXXX>
4. docs/ai/metrics.md
5. hook violation / C-3 / V-1 / C-4 の最小集計
```

次に **PBI-PQ-001: Lightweight Plan Quality Checks** を進める。

理由:

- Metrics / Eval / Reporting の前段として、plan / risk / done の品質を構造化できる
- heavy Gate / PR review / browser QA に依存せず、既存 workflow を壊しにくい
- C-3 / C-4 を弱めず、むしろ plan review の入力品質を上げられる
