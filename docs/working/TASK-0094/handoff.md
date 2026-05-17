# Handoff — TASK-0094 / #204 PBI-HI-011 PlanGateBench Fixture Suite
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 fixture directory 存在 | PASS |
| AC2 代表 fixture 5 件以上（8 件）| PASS |
| AC3 各 fixture に eval focus/expected behavior | PASS |
| AC4 scope/approval/verification discipline fixture | PASS |
| AC5 bin/plangate eval 接続方針 | PASS（#196 依存明記）|
| AC6 #196 eval comparison と矛盾しない | PASS（schema 非変更・補完・マージ順明記）|
| AC7 fixture 追加ルール記載 | PASS |
V-1 全 PASS。V-3（Codex）critical 0 / major 4 / minor 1 → 全反映・回帰 PASS。
## 2. 既知課題
- **#196/PR #268 依存**: `--harness-compare` は #196 提供。推奨マージ順
  PR #268 → 本 PR。未マージ環境は個別 `eval <TASK>` で代表選定（fixture
  シナリオ固定自体は #196 非依存で単独有効）。
- fixture は非実行のシナリオ契約（完全自動実行/LLM judge 採点は Non-goal）。
## 3. V2 候補
- fixture ↔ 実 TASK マッピング表の自動生成（#196 --harness-compare 連携）。
- fixture カバレッジ計測（未カバー eval aspect の検出）。
- #200 Reporting と連携し regression detection の定点観測。
## 4. 妥協点
- #196 CLI への前方参照を「依存・マージ順」で明示し、未マージでも fixture
  が単独有効になる設計に留めた（#196 を本 PBI で先取り実装しない）。
## 5. 引き継ぎ
#204 を standard で実装。8 fixture（examples/eval-fixtures/**）+ plangatebench.md
正本（一覧/接続/#196整合/追加ルール/Non-goal）+ eval-runner.md 連携注記。
V-3 で #196 依存明記 / plan_check 非 blocking / mode 分岐 / 認可 critical 固定
撤回（正本整合）を修正。**これで v8.7.0 残（#213/#196/#203/#204）4 件すべて
実装完了**（PR #267-270）。次は v8.8.0（#197/#198）。
## 6. テスト結果
V-1: AC1-7 + E1/E2 全 PASS。V-3 反映後回帰全 PASS。schema 非変更維持。
