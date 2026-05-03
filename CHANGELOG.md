# Changelog

PlanGate の主要リリース履歴。

このファイルは各リリース時点の内容を記録するものであり、この pull request の差分一覧ではない。

## v8.6.0 - 2026-05-04

feat: Harness Improvement Roadmap Phase 0/1 + Governance — v8.6.0 milestone 完走

EPIC #193 [Harness Improvement Roadmap](https://github.com/s977043/plangate/issues/193) の **v8.6.0 milestone P0 4 件すべて完走**。改善前 baseline 固定（#194）と運用 governance（#201, #202）を先に置き、その上に Metrics v1（#195）を実装。これにより以後の harness 改善（#196 Eval expansion / #197 Model Profile v2 / #198 Keep Rate / #199 Dynamic Context）を **比較で判断** できる基盤が整った。

### Added

- **`docs/ai/issue-governance.md`**（**PBI-HI-007** / #201 / TASK-0059） — Issue 必須セクション / Label taxonomy（kind / area / priority / status の 4 軸）/ Milestone mapping policy（推測禁止条項）/ Roadmap PBI 作成 checklist（10 項目）/ Issue template policy / EPIC governance を正本化
- **`.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml`**（#201） — Roadmap PBI 用 GitHub Issue Form。Why / What / AC / Non-goals / Labels / Milestone を必須入力として強制
- **`docs/ai/metrics-privacy.md`**（**PBI-HI-008** / #202 / TASK-0060） — Metrics v1 実装前の privacy / public data policy。保存可能 12 カテゴリ / 禁止 9 カテゴリ / file path / stack trace / command output / provider metadata の扱い / redact / sanitize / 完全除外 / retention 90日 / public-private 別運用差分
- **`docs/ai/eval-baselines/2026-05-04-baseline.{md,json}`**（**PBI-HI-000** / #194 / TASK-0061） — v8.5.0 直後の baseline。代表 5 TASK（TASK-0050/0054/0055/0056/0057）で 8 観点 eval、機械可読 JSON snapshot、後続改善との比較ポイント
- **`schemas/plangate-event.schema.json`**（**PBI-HI-001** / #195 / TASK-0062） — 11 events（task_initialized / plan_generated / c3_decided / exec_started / hook_violation / v1_completed / fix_loop_incremented / external_review_completed / pr_created / c4_decided / handoff_completed）。conditional required（c3 / c4 / v1 / hook / fix_loop）。privacy §3 Allowed のみ（§4 Forbidden は schema 上に存在させない）
- **`scripts/metrics_collector.py`**（#195） — TASK ディレクトリから 6 events 自動導出 + NDJSON append。`--dry-run` / `--events-log` 対応。mode 自動検出、AC count を ✅PASS/❌FAIL/⚠️WARN マーカーから抽出
- **`scripts/metrics_reporter.py`**（#195） — events.ndjson から TASK / aggregate summary。`--json` 対応、hook violation / C-3 / V-1 / C-4 / fix_loop_max / mode を集計
- **`docs/ai/metrics.md`**（#195） — 9 章運用 guide（CLI 使用例 / privacy / schema 検証 / baseline 比較 / 後続改善との接続点）
- **`tests/extras/ta-09-metrics.sh`**（#195） — 8 test cases（schema validation / c3_decided 検出 / v1_completed 検出 / aggregate report / JSON output 含む）
- **`pages/`**（PR #205） — River-Reviewer 参考の公開ドキュメント構造（overview / pm-po-elevator-pitch / before-after / positioning / value-proposition-canvas / demo-script / FAQ / governance/documentation-management）+ `sidebars.js`
- **`docs/ai/harness-improvement-roadmap.md`**（PR #192） — EPIC #193 の正本ドキュメント

### Changed

- **`bin/plangate`**: `metrics` サブコマンド追加（`--collect` / `--report` / `--aggregate` / `--json` / `--events-log`）。help text と dispatcher も更新
- **`.gitignore`**: `docs/working/_metrics/events.ndjson` を除外（[metrics-privacy.md §8](docs/ai/metrics-privacy.md) 準拠、public repo に commit させない）
- **`pages/guides/governance/documentation-management.md`** 冒頭に `Related: docs/ai/issue-governance.md` を追記（doc 配置側 / Issue 運用側の 2 ファイル体制を明示）
- **README.md / README_en.md**（PR #190） — v8.5.0 状態に同期、Hook enforcement 10/10、CLI tests 24 PASS / Hook tests 42 PASS、最新状態セクション追加
- **GitHub milestones**: `v8.6.0` / `v8.7.0` / `v8.8.0` / `v8.9.0` を新規作成。EPIC #193 配下の子 PBI 11 件 (#194〜#204) を EPIC の表通りに一括訂正（v7.x 誤紐付けからの復元）
- **`tests/run-tests.sh`**: 24 → **32 PASS**（ta-09 で +8 件、既存 24 件は 0 件 regress）

### Process Notes

- **v8.6.0 milestone P0 完走**: #194 Baseline alignment / #201 Issue/Label/Milestone Governance / #202 Metrics Privacy / #195 Metrics v1 の 4 件、すべて 1 セッション内で連続実装・マージ
- **依存順守**: governance（#201）/ privacy（#202）/ baseline（#194）を先に整備してから Metrics v1（#195）を実装。schema 設計時に privacy §3/§4 が先行参照され、§4 Forbidden は schema 上に存在しない設計を強制
- **マージ戦略**: 全 PR を admin squash merge（branch protection 下、CI all green、thread resolve 後）
- **PR 連動**: 8 PR（#190 / #192 / #205 / #206 / #207 / #208 / #209 + 本リリース PR）を v8.5.0 → v8.6.0 期間にマージ
- **再発防止**: milestone 不整合（11 PBI が誤って v7.x 系列に紐付き）は本リリースで全件訂正。今後は `plangate-roadmap-task.yml` テンプレートと issue-governance.md §4「推測禁止条項」で再発防止

### Next EPIC 候補（v8.7.0 / v8.8.0 / v8.9.0）

- **v8.7.0 (P1, 4 件)**:
  - #196 Eval comparison for harness changes — mode 別 release blocker 判定、metrics v1 連携
  - #197 Model Profile v2 — edit interface preference / retry strategy / provider capability / unknown model fallback
  - #203 Tool Error Taxonomy and Recovery Policy — tool error 分類・回復・計測
  - #204 PlanGateBench Fixture Suite — eval fixture 固定 + regression 検知
- **v8.8.0 (P1/P2, 2 件)**:
  - #198 Keep Rate v1 — Code / Plan / Acceptance / Handoff Keep Rate
  - #199 Dynamic Context Engine v1 — context manifest による契約 / 作業 context 分離
- **v8.9.0 (P2, 1 件)**:
  - #200 Reporting & Retrospective — sprint retrospective 統合
- **その他**:
  - Hook 側からの metrics 自動 emit（v8.7+ 候補、Metrics v1 完了で道筋確定）
  - GitHub API 経由 pr_created / c4_decided 取得（metrics v1 v2 候補）

## v8.5.0 - 2026-05-01

feat: Hook enforcement 完成 — 10/10 hooks 実装 (#169 EPIC 完走)

v8.4.0 で確立した 3 mode hook 設計（default warning / strict block / bypass escape）を全 spec に適用し、**Issue #169 残 Hook EPIC を完走**。`docs/ai/hook-enforcement.md` の Status は v3 → **v5 (Implementation: 10/10 hooks Done)** に到達、`tests/hooks/run-tests.sh` は 21 → **42 件 PASS** に成長。同 release で v8.4 baseline 自動測定 + extras README 拡充も完了。

### Added

- `scripts/hooks/check-plan-exists.sh`（**EH-1**、PreToolUse） — plan.md なし production code 編集 block（#183 / TASK-0056）
- `scripts/hooks/check-plan-hash.sh`（**EH-3**、PreToolUse + CLI） — c3.json plan_hash と現 plan.md sha256 突合（#183 / TASK-0056）
- `scripts/hooks/check-test-cases.sh`（**EH-4**、CLI） — V-1 前に test-cases.md 不在を warn / block（#184 / TASK-0057）
- `scripts/hooks/check-verification-evidence.sh`（**EH-5**、CLI） — PR 作成前に evidence/ verification 系不在を warn / block（#184 / TASK-0057）
- `scripts/hooks/check-forbidden-files.sh`（**EH-6**、PreToolUse + CLI） — 子 PBI YAML の forbidden_files glob と編集対象 path を fnmatch で突合（#184 / TASK-0057）
- `scripts/hooks/check-merge-approvals.sh`（**EH-7**、CLI） — マージ前に c3.json + c4-approval.json の両 APPROVED を確認（#185 / TASK-0058）
- `scripts/hooks/check-v3-review.sh`（**EHS-1**、CLI、mode 連携） — standard / high-risk / critical で V-3 review 必須化、light / ultra-light は SKIP（#185 / TASK-0058）
- `tests/extras/README.md` に「set -e 互換書法」セクション — command substitution の exit code 捕捉パターン（#182）
- `docs/ai/eval-comparison-template.md` に **v8.4 baseline** 行 + v8.3→v8.4 比較テーブル（#181 / TASK-0055）
- `docs/ai/eval-baseline-procedure.md` を v2 化（自動手順を主、v8.3 手動を後方互換）

### Changed

- `docs/ai/hook-enforcement.md` Status v3 → **v5**（10/10 hooks Done、§ 4 表に全 hook 完備、§ 4.5「全 10 hook 完了 (#169 完走)」）
- `.claude/settings.example.json`: PreToolUse に EH-1 / EH-3 / EH-6 を追加（**EH-1 + EH-2 + EH-3 + EH-6** の 4 hook 構成）
- `tests/hooks/run-tests.sh`: 12 → **42 件 PASS**（fixture 8 種追加）
- `tests/run-tests.sh`: 24 件 PASS 維持（変動なし、loader 経由）

### Process Notes

- **Issue #169 EPIC を 4 セッション × 計 11 PR で完走**（#157 前段の EH-2/EHS-2/EHS-3 + #183 EH-1/EH-3 + #184 EH-4/EH-5/EH-6 + #185 EH-7/EHS-1）
- 同日（2026-05-01）に 7 セッション連続実行で 16 PBI 完走、25 PR マージ、12 Issue close、累積 V2 候補ゼロを達成
- 全 10 hook で **3 mode 設計**（default / strict / bypass）+ 監査ログを統一、`tests/extras/` 構造（#170）でマージ衝突源を根絶した状態を維持

### Next EPIC 候補（V2）

1. **EH-7 上位拡張**: GitHub branch protection / ruleset 自動適用（外部 GitHub API 操作、別 PBI）
2. **EHS-1 phase 分離**: C-2 vs V-3 で review-external.md を分離する運用モデル
3. **Hook subcommand 統合**: `bin/plangate hook <name>` への CLI 統合
4. **claude-cli session log parser**（#168 v2、対話履歴 JSONL 統合）
5. **tool_call_count 抽出**（codex JSONL の response_item 解析）
6. **session log 自動検出**（cwd → 最新 rollout 推測）
7. **共通 hook helper**（`scripts/hooks/_lib.sh` で emit_judgment / log_event を集約、現状は 10 ファイル × 各 50〜100 行で許容範囲）

## v8.4.0 - 2026-05-01

feat: 自動化基盤の節目 — eval runner / schema validate CI / hook enforcement / 環境改善

v8.3.0（最新実行モデル対応 + eval framework 仕様）で整備した基盤を、**実 CI / 実 CLI / 実 hook** に落とし込んだリリース。retrospective Try T-1〜T-6 のうち 6 件 + 派生 V2 候補 5 件を消化、合計 11 PBI（TASK-0045〜0054）を完走。マージ済 18 PR（#161〜#178）。

### Added

- `scripts/check-pr-issue-link.sh` + `.github/workflows/check-pr-issue-link.yml` — 子 PBI auto-close 漏れ防止 CI（PBI #170 / Issue #159 → TASK-0045）
- `docs/ai/eval-comparison-template.md` の v8.3 baseline 行 + `docs/ai/eval-baseline-procedure.md` — 8 観点 baseline + 集計手順（PBI #155 → TASK-0046）
- `scripts/validate-schemas.py` + `bin/plangate validate-schemas` + `.github/workflows/schema-validate.yml` — JSON artifact の schema 機械検証（PBI #158 → TASK-0047）
- `docs/ai/contracts/{plan,review,verify,handoff,classify}.md` に schema reference を追加（PBI #158）
- `scripts/hooks/check-c3-approval.sh` / `check-handoff-elements.sh` / `check-fix-loop.sh` — EH-2 / EHS-2 / EHS-3 の 3 mode 設計 hook（default warning / `PLANGATE_HOOK_STRICT=1` で block / `PLANGATE_BYPASS_HOOK=1` で escape）（PBI #157 → TASK-0048）
- `.claude/settings.example.json` — opt-in な PreToolUse / SessionStart hook 登録例
- `tests/hooks/run-tests.sh` + 各 fixture — hook 単体テスト 12 ケース
- `bin/plangate eval` + `scripts/eval-runner.py` + `schemas/eval-result.schema.json` — 8 観点機械評価 CLI、baseline 比較、release blocker 違反検知（PBI #156 → TASK-0049）
- `docs/ai/eval-runner.md` — eval CLI の正本仕様
- `tests/extras/` ディレクトリ + `tests/extras/README.md` — 拡張テストブロック分離による衝突源根絶（PBI #170 → TASK-0050）
- `scripts/schema_mapping.py` — `FILENAME_TO_SCHEMA` を 1 箇所集約（DRY、PBI #172 → TASK-0051）
- `scripts/gh-pin-account.sh` + SessionStart hook — gh CLI active account 自動固定 shim（PBI #171 → TASK-0052）
- `scripts/parsers/codex_log_parser.py` + `--session-log` option — Codex JSONL から latency / tokens を実測値化（PBI #168 → TASK-0054）
- `tests/fixtures/codex-log/sample.jsonl` — 実 codex rollout の最小 fixture
- `docs/working/retrospective-2026-05-01.md` + `retrospective-2026-05-01-s2.md` — 2 セッションの振り返り

### Changed

- `bin/plangate` v0.1.0 → **v0.2.0** — `validate-schemas` / `eval` サブコマンド追加、help 拡充
- `scripts/eval-runner.py` v1.0.0 → **v1.2.0** — schema_mapping 共通化（v1.1）+ codex session log parser 統合（v1.2）
- `schemas/c3-approval.schema.json` / `schemas/c4-approval.schema.json` — `patternProperties: { "^_": {} }` を追加し human-readable annotation を許容（PBI #167 → TASK-0053）
- `docs/ai/hook-enforcement.md` — Status v1（Spec only）→ **v2 (Implementation: Done)**、§ 4 全面書換
- `docs/ai/eval-plan.md` 引き継ぎ先を eval-runner / structured-outputs CI に明記
- `docs/ai/structured-outputs.md` — § 8 マイグレーションガイド追記
- `docs/ai/eval-cases/format-adherence.md` — Detection 手順を新 CI に整合
- `docs/schemas/child-pbi.yaml` — optional `related_issue: <int>` フィールドを追記
- `tests/run-tests.sh` — base test + extras loader 構造に再設計、合計 21 → **24 件 PASS**

### Fixed

- 既存 PBI（PBI-116 配下）の c3.json schema 違反問題を schema 緩和で解消（PBI #167 → TASK-0053）

### DX / Process

- gh CLI active account 自動固定により、plangate 作業中の auth 切戻による mutation 失敗を抑止
- handoff.md 必須 6 要素を全 11 PBI で 100% 出力（Rule 5 遵守）
- eval-result.json は `release_blocker_violations` 配列に違反を記録、stderr WARNING + exit 1 で CI 統合可能

### Process Notes

- **Auto Mode 連続実行**: 同日（2026-05-01）に 3 セッションで 11 PBI を完走、合計 12 PR マージ・10 Issue close（うち 5 件は同日中に起票・解消）
- **マージコンフリクト**: 5 PR 連続実装の後半（#163 / #164 / #165）で `tests/run-tests.sh` 末尾領域に衝突発生 → PBI #170 で `tests/extras/` 分離に再設計し根絶
- **3 モード Hook 設計**: critical mode の作業妨害リスクを default warning で回避、strict は環境変数で opt-in、bypass は監査ログに記録

### Next EPIC 候補（V2）

1. **#169 残 Hook 実装**（EH-1 / EH-3〜EH-7 / EHS-1 = 7 hook、3 セッション分割推奨）
2. claude-cli session log parser（codex のみ実装済、対話履歴の保存場所要調査）
3. tool_call_count 抽出（codex JSONL の response_item 解析）
4. session log 自動検出（cwd → 最新 rollout 推測）

## v8.3.0 - 2026-04-30

feat: 最新実行モデル対応 — Outcome-first / Model Profile / Prompt Assembly / Eval 基盤 (EPIC #116)

PlanGate v8.2 milestone 中核 EPIC として、GPT-5.5 以降の outcome-first モデルに対応する基盤を整備。
Orchestrator Mode 実運用ケース第一号として親 PBI（PBI-116）を 6 子 PBI に分解、4 phase で実行。
17 PR（#126〜#151）をマージ、parent-AC × 8 全 PASS / Open Gap 0 / Release blocker 0 で完了。

### Added

- `docs/ai/core-contract.md` — Iron Law 7 項目を outcome-first 形式で正本化（PBI-116-01）
- `docs/ai/model-profiles.yaml` — 実行モデル別 4 profile（gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown）（PBI-116-02）
- `schemas/model-profile.schema.json` — Model Profile JSON Schema（PBI-116-02）
- `docs/ai/prompt-assembly.md` — 4 層 Prompt Assembly（base_contract / phase_contract / risk_mode_contract / model_adapter）（PBI-116-03）
- `docs/ai/contracts/` × 7（各 phase 別 contract 定義）+ `docs/ai/adapters/` × 4（profile 別 adapter）（PBI-116-03）
- `docs/ai/structured-outputs.md` + 4 schema（review-result / acceptance-result / mode-classification / handoff-summary）（PBI-116-04）
- `docs/ai/responsibility-boundary.md` / `docs/ai/tool-policy.md` / `docs/ai/hook-enforcement.md`（PBI-116-04, 06）
- `docs/ai/eval-plan.md` — model migration eval framework 8 観点 / 4 観点を release blocker（PBI-116-05）
- `docs/ai/eval-cases/` × 8 — scope-discipline / approval-gate / verification-honesty / format-adherence（release blocker）+ ac-coverage / stop-behavior / tool-overuse / latency-cost（WARN）（PBI-116-05）
- `docs/ai/eval-comparison-template.md` — prompt × model profile × reasoning effort 比較表（PBI-116-05）
- `docs/working/PBI-116/` 親 PBI artifact 一式（parent-plan / dependency-graph / parallelization-plan / integration-plan / risk-report / handoff / approvals）

### Changed

- `CLAUDE.md` — 43 行 → 21 行に薄型化、Iron Law を `core-contract.md` に分離参照（PBI-116-01）
- `AGENTS.md` — 61 行 → 29 行に薄型化、Codex 共有プロンプトを Core Contract 経由に統合（PBI-116-01）

### Process Notes

- Orchestrator Mode 実運用ケース第一号として 4 phase 構成（並行 → 順次 → 順次 → 順次）で運用検証
- Phase 2 の 3 並行子 PBI を Codex C-2 統合レビュー 1 回で処理（呼び出しコスト 1/3 圧縮）
- 全 6 子 PBI で `handoff.md` 必須 6 要素出力（Rule 5 遵守）
- Parent Integration Gate 通過記録: `docs/working/PBI-116/approvals/parent-integration.json`
- 振り返り: `docs/working/retrospective-2026-04-30.md` § PBI-116 EPIC 完了

### Next EPIC 候補（V2）

1. v8.2 baseline 測定 PBI（本 eval framework での初回測定）
2. eval runner 実装 PBI（reasoning_token / latency / tool call 集計の自動化）
3. Hook enforcement 実装 PBI（plan 未承認 block 等のハード強制）
4. Structured Outputs 実 LLM 適用 PBI（schema validate CI 統合含む）

## v8.2.0 - 2026-04-28

feat: Parent-Child PBI Orchestrator Mode 仕様策定 + ドキュメント同期 (#111 #112 #113 #114)

### Added

- `docs/orchestrator-mode.md` — Parent-Child PBI Orchestrator Mode のアーキテクチャ正本（Issue #109、Spec only / 実装は別 PBI）
- `docs/schemas/child-pbi.yaml` — 子 PBI YAML スキーマ + バリデーション規則
- `docs/workflows/orchestrator-decomposition.md` — 親 PBI → 子 PBI 分解 Workflow（D-1〜D-7）
- `docs/workflows/orchestrator-integration.md` — 子 PBI 統合 → 親 PBI 完了判定 Workflow（I-1〜I-4 + Gap 分岐）
- `docs/working/templates/parent-plan.md` / `dependency-graph.md` / `parallelization-plan.md` / `integration-plan.md` — 親 PBI 用 4 種テンプレート
- `.claude/rules/orchestrator-mode.md` — Gate 不変条件（ChildExecAllowed / ParentDone / NewChildPBIAllowed）の正本
- `docs/rfc/plangate-decompose.md` — `plangate decompose` CLI RFC（Status: Draft）
- `scripts/check-orchestrator-docs.sh` — Orchestrator Mode ドキュメント整合性検証スクリプト（TC-01〜TC-20）
- README に CLI セクション追加（`bin/plangate init/status/validate/review/exec` の使用例）
- README「中核アイデア」表に Control OS 行追加

### Changed

- `docs/plangate-v7-hybrid.md` — Mode×Gate×Skill 表を `skill-policy-router` 正本に同期、`critical` の rollback / security review / staged deploy を補足
- `docs/plangate-plugin-migration.md` — Rules (8) → (9) 修正、Provider RFC と Workflow DSL 接続を「完了済み」に移動、14 skills 呼び出し例追加
- `docs/plangate.md` — 「ライト / フル」2 分類 → 5 モード表へ置換
- `docs/ai-driven-development.md` — `フルのみ` → `high-risk / critical のみ` に置換、5 モード表へ更新
- `README.md` / `README_en.md` — install warning を NOTE に緩和（dual-mode 可・`plangate:` prefix 注記）、Repository Layout に `/bin` `/workflows` `/tests` を追加、Testing を v8.1.0 の 10 件テストに更新
- `docs/index.md` — Orchestrator Mode 仕様へのリンク追加

## v8.1.0 - 2026-04-27

feat: Provider CLI 対応 — validate --mode、review（Gemini CLI）、exec（OpenCode）コマンド追加 (#107)

### Added

- `bin/plangate validate --mode <mode>` — `workflows/<mode>.yaml` を読み込み、`gate_enforcement.c3.required_artifacts` から artifact リストを動的決定
- `bin/plangate review <TASK-XXXX>` — 外部 AI レビューコマンド。`PLANGATE_EXTERNAL_REVIEWER=gemini` で Gemini CLI を呼び出し、結果を `review-external.md` に書き出す
- `bin/plangate exec <TASK-XXXX>` — 実装エージェント dispatch。C-3 gate をクリアしないとブロック。`PLANGATE_IMPL_AGENT=opencode` で OpenCode を起動
- `bin/plangate doctor` — gemini / opencode CLI の存在を INFO として表示（次セクション参照）
- `tests/run-tests.sh` — validate --mode、review、exec の新規テスト 6 件追加（合計 10 件）

## v8.0.2 - 2026-04-27

docs: README 日本語メイン化・plugin migration guide 0.5.0 対応 (#100 #101 #102 #103)

### Changed

- `README.md` — 日本語版に差し替え（English README は `README_en.md` へ移動）
- `README_en.md` — 新規作成（English primary README、旧 README.md の内容）
- `docs/plangate-plugin-migration.md` — plugin 0.5.0 対応・手順を最新化
- `docs/working/README.md` — `full` → `high-risk` 表記を修正

## v8.0.1 - 2026-04-27

docs: examples/minimal-node/ 追加 — Node.js 最小構成サンプル (#93)

### Added

- `examples/minimal-node/README.md` — Node.js/Express プロジェクトへの PlanGate 導入手順サンプル
- `examples/minimal-node/CLAUDE.md` — プロジェクト向け最小 CLAUDE.md テンプレート

## v8.0.0 - 2026-04-27

feat: v8.0 — Workflow DSL・Provider RFC・CLI テストスイート (#81 #82 #83) (#98)

### Added

- `workflows/` — Workflow DSL (YAML) 5種（ultra-light / light / standard / high-risk / critical）
  - 各フェーズの完了条件・入出力・担当エージェントを機械可読形式で定義
- `docs/rfc/provider-gemini-cli.md` — Gemini CLI Provider RFC（外部レビュー役割）
- `docs/rfc/provider-opencode.md` — OpenCode Provider RFC（実装エージェント役割）
- `tests/run-tests.sh` — plangate CLI テストスイート（シェルスクリプト）
- `tests/fixtures/` — テスト用フィクスチャ 4種（complete-task / missing-approval / stale-plan-hash / broken-pbi）
- `.github/workflows/test.yml` — plangate CLI テスト CI workflow
- `CONTRIBUTING.md` — 新規 Provider 追加手順（`#adding-a-new-provider`）を追加
- `README.md` — Testing セクション・Provider Support セクションを追加

## v7.5.2 - 2026-04-27

fix: python3 で JSON パースするよう timeline コマンドを修正 (#96)

- `bin/plangate` — `python` → `python3` に変更（macOS デフォルト環境対応）

## v7.5.1 - 2026-04-27

feat: bin/plangate CLI v0.1.0 追加 (#95)

### Added

- `bin/plangate` — plangate CLI シェルスクリプト
  - `init TASK-XXXX` — タスクフォルダとテンプレートファイルを生成
  - `doctor` — 環境セットアップをチェック（Claude Code plugin / Codex CLI / 必須コマンド等）
  - `status TASK-XXXX` — 現在フェーズと次アクションを表示
  - `validate TASK-XXXX` — 成果物・承認状態・plan_hash 整合性を検証
  - `abort TASK-XXXX` — abort イベントを run.ndjson に記録
  - `timeline TASK-XXXX` — run.ndjson イベントログをタイムライン表示
  - `resume TASK-XXXX` — current-state.md を表示してセッション再開

## v7.5.0 - 2026-04-27

docs: v7.5 — Deferred Decisions 判断記録・Discussions 設定確認・導線追加 (#88 #89) (#94)

### Added

- `docs/oss-governance.md` — Deferred Decisions 判断結果を記録（Required approvals / Scorecard required check / GitHub Actions allowlist）
- `docs/oss-governance.md` — GitHub Discussions 設定確認セクション追加（6カテゴリ・利用方針）
- `.github/ISSUE_TEMPLATE/config.yml` — Q&A / Ideas カテゴリへの Discussions リンクを追加

## v7.4.0 - 2026-04-26

docs: v7.4 — CONTRIBUTING.ja・TROUBLESHOOTING・JSON schemas・gate enforcement spec (#92)

### Added

- `CONTRIBUTING.md` — 日本語貢献フロー・セットアップ手順・コミットメッセージ規約を追記
- `TROUBLESHOOTING.md` — 導入・設定・ワークフロー・CI トラブル対応ガイドを新規追加
- `schemas/` — Artifact JSON Schema 7種（pbi-input / plan / todo / test-cases / review-self / review-external / handoff）
- `docs/working/templates/` — 全テンプレートに frontmatter 追加（task_id / artifact_type / schema_version / status）
- `docs/working/TASK-XXXX/approvals/c3.json` — gate enforcement 仕様を新規定義

## v7.3.3 - 2026-04-27

docs: v7.3 governance — CI/Scorecard badges + docs/working/ public policy (#84 #87) (#91)

### Added

- `README.md` — CI / OpenSSF Scorecard バッジを追加
- `docs/oss-governance.md` — docs/working/ 公開方針・AGENT_LEARNINGS.md 位置づけを明示

## v7.3.2 - 2026-04-26

docs: v7.3 onboarding — English README, examples/, plugin install guide (#73 #74 #75 #76)

### Added

- `README.md` — English primary README: 30s/2min/10min structure, plugin install at top, dedup warning
- `README.ja.md` — Japanese version (restructured from previous `README.md`)
- `examples/` — Worked example of PlanGate artifacts (Node.js user registration scenario)

## v7.3.1 - 2026-04-26

plugin v0.5.0: setup-team を skill 一覧に追加、broken reference 制約の削除、README バージョン更新。

- `plugin/plangate/README.md` — skill 数 11 → 14、setup-team 追加、既知制約から解消済み broken reference を削除
- `plugin/plangate/.claude-plugin/plugin.json` — v0.4.0 → v0.5.0、description に Setup Team を追記
- `docs/working/TASK-0037/handoff.md` — Rule 5 完了資産を発行

## v7.3.0 - 2026-04-26

モード命名の完全統一、setup-team スキル追加、pg-check × skill-policy-router 連携明示を行ったリリース。

### setup-team スキル追加（TASK-0035）

- `plugin/plangate/skills/setup-team/` — タスク規模・モードに応じたマルチエージェントチーム設計スキルを追加
- `.claude/skills/setup-team/` / `.agents/skills/setup-team/` にも同一ファイルを配置
- `skills/codex-multi-agent/SKILL.md` の broken reference（`../setup-team/SKILL.md`）を解消

### full → high-risk モード命名完全統一（TASK-0036）

- `plugin/plangate/agents/workflow-conductor.md` — 5 箇所置換（フェーズ表、判定ロジック、status.md テンプレート、V-2 記述）
- `plugin/plangate/agents/code-optimizer.md` — frontmatter description + When You Should Be Used
- `plugin/plangate/rules/working-context.md` — V-2 記述・plan.md テンプレート・status.md テンプレート
- `plugin/plangate/commands/ai-dev-workflow.md` — Mode判定テンプレート
- `.claude/` 側の対応ファイル（agents/workflow-conductor.md, agents/code-optimizer.md, agents/README.md, rules/mode-classification.md, rules/working-context.md, commands/ai-dev-workflow.md）も同様に更新

### pg-check × skill-policy-router 連携明示（TASK-0037）

- `plugin/plangate/commands/pg-check.md` — GatePolicy との連携セクションを追加
- `skill-policy-router` が `check` を requiredSkills に含む場合に `/pg-check` が自動要求される旨を明記

## v7.2.0 - 2026-04-26

Epic [#53](https://github.com/s977043/plangate/issues/53)「PlanGate を AI コーディングの開発統制 OS へ拡張する」の Phase 1〜3 を完了したリリース。

### Phase 1: 軽量スキル基盤（#54/#55/#56）

- `skills/intent-classifier/` — User Request を 7 分類（feature / bug / refactor / research / review / docs / ops）
- `skills/skill-policy-router/` — Intent + Mode → GatePolicy（requiredSkills / requiresEvidence / requiresFailingTestFirst / requiresWorktree）
- `skills/evidence-ledger/` — EvidenceLedger スキーマ・証拠記録・Completion Gate 連携
- `rules/evidence-ledger.md` — Completion Gate ブロック条件正本
- `rules/mode-classification.md` — `full` → `high-risk` リネーム + GatePolicy 定義追加
- `/pg-think` / `/pg-hunt` / `/pg-check` / `/pg-verify` コマンド追加

### Phase 2: 強制ゲート基盤（#57）

- `rules/design-gate.md` + `skills/design-gate/` — high-risk 以上で Design Artifact 8 項目必須
- `commands/pg-tdd.md` — Red→Green→Refactor TDD cycle + Evidence Ledger 連携
- `rules/review-gate.md` + `skills/review-gate/` — 6 観点レビュー、critical finding → Completion Gate ブロック
- `rules/completion-gate.md` — 全 Gate 通過を一元管理する 5 条件チェックポイント
- `rules/mode-classification.md` — Gate 適用マトリクス追加

### Phase 3: エージェント統制基盤（#58）

- `skills/context-packager/` — Allowed Context 6 要素を構造化して出力
- `rules/subagent-roles.md` — 6 ロール定義（planner / implementer / reviewer / security-reviewer / test-reviewer / documentation-reviewer）
- `skills/subagent-dispatch/` — 依存関係グラフ生成・並列実行可能タスク特定・dispatch
- `rules/worktree-policy.md` — high-risk: 必須(推奨), critical: 必須(強制)。`requiresWorktree` フラグ接続
- `skills/pr-decision/` — Evidence Ledger + Review Gate + GateStatus から APPROVE / BLOCK / CONDITIONAL 判定

### ドキュメント・その他

- `docs/plangate-v7-hybrid.md` — PlanGate Control OS 理想ワークフロー節を追加
- `plugin.json` — v0.3.0 → v0.4.0

## v7.1.0 - 2026-04-23

README 刷新、GitHub Pages 公開、Claude Code / Codex CLI 共用スキルの整備を行ったリリース。

- README をハーネスエンジニアリング上の位置づけを軸に再構成
- `docs/philosophy.md` を追加し、思想・問題設定・PlanGate の設計解釈を分離
- GitHub Pages 用の `docs/index.md` と `docs/_config.yml` を整備
- MIT `LICENSE` を追加
- `.agents/skills/` に Codex CLI / Claude Code 共用スキルを追加
- GitHub Pages を `main` / `docs` で公開

## v7.0.0 - 2026-04-20

Workflow / Skill / Agent の 3 層で実行層を再構築したハイブリッドアーキテクチャのリリース。

- `docs/plangate-v7-hybrid.md` を追加
- WF-01〜WF-05 の Workflow 定義を追加
- v7 用 Skill / Agent の責務分離を整理
- `design.md` と `handoff.md` を成果物として強化

## v6.0.0 - 2026-04-09

Context Engineering、18 エージェント体制、5 段階モード分類を含むロードマップリリース。

- `docs/plangate-v6-roadmap.md` を追加
- context engineering 統合の方向性を整理
- タスク規模別の実行モード分類を整理

## v5.0.0 - 2026-04-09

L-0 リンター自動修正とハーネスエンジニアリング知見を統合したリリース。

- L-0 リンター自動修正ループを設計
- V-1〜V-4 の検証段階を整理
- ハーネスエンジニアリング観点を PlanGate に統合

## v4.0.0 - 2026-04-09

takt 知見を統合し、実装後検証と C-3 三値ゲートを強化したリリース。

- V-1〜V-4 の検証構造を導入
- C-3 ゲートを APPROVE / CONDITIONAL / REJECT の三値に整理
- マルチエージェント協調の実践知見を反映

## v3.0.0 - 2026-04-09

AI 駆動開発ワークフローの基盤リリース。

- PBI から Plan / ToDo / Test Cases を生成する基本フローを整理
- 計画承認後に Agent 実行へ進むゲート型モデルを定義
- Claude Code を中心とした AI 駆動開発ワークフローを文書化
