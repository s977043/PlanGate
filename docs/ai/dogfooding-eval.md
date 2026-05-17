# Dogfooding Eval v1（正本 / #231 PBI-HI-015 / v8.8.0）

> PlanGate 自身を評価する dogfooding eval。**single judge + human-readable
> rationale**（multi-judge 撤回・Round4 確定）。v1 は **決定論構造判定**を主と
> し、LLM 判定は judge-prompt テンプレ（§3）を外部レビュー基盤で呼べる形で
> 同梱する（v1 に LLM 揺らぎを持ち込まず再現性を確保）。

## 1. 実行

```bash
bin/plangate eval --dogfood <TASK-XXXX>
# → docs/working/<TASK>/eval-dogfood.md（5項目判定 + rationale）
```

既存 8-aspect eval（`bin/plangate eval <TASK>`）とは**独立 mode**（非破壊）。

## 2. 評価 5 項目（#228 run-outcome-review と整合）

| # | 項目 | 決定論判定の根拠 |
|---|------|----------------|
| 1 | PBI 入力から AC/Design/Task 分解が妥当か | pbi-input.md に AC セクション + plan.md に Work Breakdown |
| 2 | handoff 6 要素が満たされているか | handoff.md の `## 1〜6` セクション数 ≥ 6 |
| 3 | C-3/C-4 判定に必要な証跡があるか | approvals/c3.json 存在 + c3_status / handoff に C-4 言及 |
| 4 | Trace Timeline(experimental #229) に評価可能イベントが揃っているか | events.ndjson 存在（experimental＝無くても FAIL でなく PARTIAL） |
| 5 | Stop rules / core-contract 違反がないか | decision-log/handoff に未解決 VIOLATION・証跡なし完了主張が無い |

判定値: `PASS` / `PARTIAL` / `FAIL`（各項目 rationale 必須）。
#230 [gate-event-normalization](./gate-event-normalization.md) の status 正規化を
入力前処理に用いる（gate event の pass/fail/conditional/skipped/bypassed）。

## 3. judge-prompt テンプレート（LLM judge を呼ぶ場合・将来/外部基盤）

```text
あなたは PlanGate 実行品質の single judge です。以下の TASK 成果物
（pbi-input/plan/handoff/decision-log/events/eval）を入力に、評価5項目
（上表）を PASS/PARTIAL/FAIL で判定し、各項目に human-readable な rationale
を付してください。スコアは付けず、release blocker 該当のみ明示。
入力: {task_artifacts}
```

LLM 判定は v1 では必須でない（決定論構造判定が基盤）。外部レビュー基盤
（codex/gemini）で本テンプレを用いて補助 rationale を得られる。

## 4. 出力

`docs/working/<TASK>/eval-dogfood.md`: 5項目の判定表 + 各 rationale +
release blocker サマリ。外部 fixture（`tests/fixtures/eval-runner/`）でも
動作（作者 repo specific 前提を排除＝汎用 TASK ディレクトリ走査）。

## 5. 後方互換・整合

- 既存 8-aspect eval / eval-runner を破壊しない（`--dogfood` 独立 mode）。
- #228 5項目 / #229 timeline / #230 正規化 と整合。
- 自動学習・skill 自動更新は対象外（OSS で危険・延期）。

## 関連
- 前提: #228（run-outcome-review）/ #229（timeline）/ #230（gate normalization・PR #261）
- 親 EPIC: #193 / scripts: `scripts/eval-runner.py`（--dogfood mode）
