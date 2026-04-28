# 作業コンテキスト管理ルール

## 目的

セッション切れや日付またぎでコンテキストが失われることを防ぐ。
チケット単位で作業状態を `docs/working/` 配下にファイルとして保存し、次回セッションで即座に復元可能にする。

## PlanGateワークフローとの対応

このルールはPlanGateワークフロー v5-v6の各フェーズで生成される成果物を永続化する。
PlanGateガイド: `docs/plangate.md`
ワークフロー詳細: `docs/ai-driven-development.md`

```text
Ready → In Progress
  → 0: Brainstorming 🤖👤（対話的な要件整理・設計書生成、任意）
  → A: PBI INPUT PACKAGE作成 👤
  → B: Plan + ToDo + Test Cases同時生成 🤖
  → C-1: セルフレビュー 🤖（17項目チェック）
  → C-2: 外部AIレビュー 🤖
  → C-3: 人間レビュー 👤（三値ゲート: APPROVE / CONDITIONAL / REJECT）
  → D: Agent実行 🤖（TDD）
  → L-0: リンター自動修正 🤖
  → V-1: 受け入れ検査 🤖
  → V-2: コード最適化 🤖（high-risk/criticalモードのみ）
  → V-3: 外部モデルレビュー 🤖
  → V-4: リリース前チェック 🤖（criticalモードのみ）
  → PR作成 🤖
  → C-4: 人間レビュー 👤（GitHub上: APPROVE / REQUEST CHANGES / REJECT）
  → Done
```

## ディレクトリ構造

### 単一 PBI（標準）

```text
docs/working/
└── TASK-{ticket-number}/
    ├── pbi-input.md         # A: PBI INPUT PACKAGE（人間が作成）
    ├── plan.md              # B: EXECUTION PLAN（Prompt 1で生成）
    ├── todo.md              # B: EXECUTION TODO（Prompt 1で生成）
    ├── test-cases.md        # B: テストケース定義（Prompt 1で生成）
    ├── INDEX.md             # B: チケット索引（plan完了時に自動生成）
    ├── current-state.md     # B〜: 現在状態スナップショット（タスク完了ごとに自動更新）
    ├── review-self.md       # C-1: セルフレビュー結果（Prompt 2で生成）
    ├── review-external.md   # C-2: 外部AIレビュー結果（任意）
    ├── decision-log.jsonl   # B〜: 判断履歴（append-only、plan完了時に初期化）
    ├── status.md            # D〜: フェーズ履歴・完了記録のアーカイブ（随時追記）
    ├── handoff.md           # WF-05: 完了時の引き継ぎパッケージ（全 PBI で必須、Rule 5）
    └── evidence/            # C-1〜: レビュー根拠・検証ログ
        ├── c1-review/       #   C-1 の根拠（FAIL時必須）
        ├── c2-review/       #   C-2 の根拠
        ├── test-runs/       #   テスト実行ログ
        ├── verification/    #   動作検証スクリーンショット・ログ
        └── e2e/             #   E2E 検証結果
```

### 親 PBI（Orchestrator Mode）

親 PBI を扱う場合は別ディレクトリ `docs/working/PBI-{number}/` を併用する。詳細は [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) を参照。

```text
docs/working/
└── PBI-{parent-number}/
    ├── parent-plan.md          # 親計画（テンプレート: docs/working/templates/parent-plan.md）
    ├── dependency-graph.md     # 子 PBI 依存関係グラフ
    ├── parallelization-plan.md # 並行実行計画
    ├── integration-plan.md     # 統合チェック / 親完了条件
    ├── risk-report.md          # 親 PBI レベルの集約リスク
    ├── approvals/
    │   ├── parent-c3.json      # 親計画ゲート承認
    │   └── parent-integration.json  # 統合ゲート承認
    ├── children/
    │   ├── PBI-{n}-01.yaml     # 子 PBI 仕様（schema: docs/schemas/child-pbi.yaml）
    │   ├── PBI-{n}-02.yaml
    │   └── ...
    └── handoff.md              # 親 PBI 完了時の引き継ぎ（必須）
```

子 PBI の作業コンテキストは既存の `TASK-XXXX/` 構造を再利用する想定。実装は別 PBI（[`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) の V2 範囲）。

## コンテキスト読み込みプロトコル（Progressive Disclosure）

セッション開始時・フェーズ遷移時のファイル読み込みを段階的に行い、不要な情報の読み込みを抑制する。

| Level | 対象ファイル | 読み込みタイミング |
|-------|------------|-----------------|
| **L0**（常に読む） | INDEX.md → current-state.md | セッション開始時に必ず最初に読む |
| **L1**（フェーズに応じて） | plan → pbi-input.md | plan フェーズで読む |
| | exec → plan.md, todo.md, test-cases.md | exec フェーズで読む |
| | review → plan.md, review-self.md, review-external.md | review フェーズで読む |
| | status → status.md, todo.md | status 確認時に読む |
| **L2**（根拠が必要な時のみ） | evidence/{該当ディレクトリ}, decision-log.jsonl | レビュー根拠の確認・振返り時 |
| **L3**（履歴全体が必要な時のみ） | status.md 全体, 他チケットの working context | 横断的な分析・過去参照時 |

**フォールバック**: INDEX.md が存在しない場合（旧形式チケット）→ L1 から開始（status.md を直接読む = 従来動作）。

### current-state.md / status.md / handoff.md の役割分担

| ファイル | 役割 | 目安行数 | 更新タイミング |
|---------|------|---------|--------------|
| current-state.md | 「今どこにいて、次に何をするか」のスナップショット | ~20行 | タスク完了ごとに上書き |
| status.md | フェーズ履歴・完了記録のアーカイブ | 制限なし | フェーズ遷移・セッション終了時に追記 |
| **handoff.md** | WF-05 完了時の引き継ぎパッケージ（完了資産） | 制限なし | WF-05 完了時に 1 回生成 |

### handoff（WF-05 完了資産 / Rule 5）

全 PBI で `handoff.md` を**必須出力**とする（Rule 5 遵守: 最終成果物は毎回 handoff に集約）。

- **配置**: `docs/working/TASK-XXXX/handoff.md`（1 PBI につき 1 ファイル）
- **テンプレート**: `docs/working/templates/handoff.md`
- **必須 6 要素**:
  1. 要件適合確認結果（AC ごとの PASS / FAIL / WARN）
  2. 既知課題一覧
  3. V2 候補
  4. 妥協点（採用しなかった選択肢と理由）
  5. 引き継ぎ文書（自由記述のサマリ）
  6. テスト結果サマリ
- **責任**: `qa-reviewer` が中核を作成し、`orchestrator` が最終統合
- **PR マージ後も削除しない**（完了資産として保管、次の担当者・次スプリントが参照）
- **light モード以下**で簡易版を採用する場合も、本テンプレートを踏襲し、該当しない項目は「該当なし」と明記

status.md / current-state.md が「進行中の情報管理」であるのに対し、handoff.md は「完了後の資産発行」である。役割が明確に異なる。

### evidence/ の保管ルール

- **PASS 判定**: evidence は省略可（判定理由のみ review ファイルに記載）
- **WARN 判定**: evidence 推奨
- **FAIL 判定**: evidence 必須（evidence がない FAIL は無効）

## 各ファイルの役割

### pbi-input.md（PBI INPUT PACKAGE）

フェーズAで人間が作成。以下を含める:

- Context / Why（なぜやるか）
- What（Scope）: In scope / Out of scope
- 受入基準
- Notes from Refinement（議論で決まったこと）
- Estimation Evidence: Risks / Unknowns / Assumptions

### plan.md（EXECUTION PLAN）

フェーズB（Prompt 1）で生成。以下を含める:

- Goal
- Constraints / Non-goals
- Approach Overview
- Work Breakdown（各Stepに Output / Owner / Risk / 🚩チェックポイント）
- Files / Components to Touch
- Testing Strategy（Unit / Integration / E2E / Verification Automation）
- Risks & Mitigations
- Questions / Unknowns
- Mode判定（ultra-light / light / standard / high-risk / critical）

### todo.md（EXECUTION TODO）

フェーズB（Prompt 1）でplanと同時生成。以下を含める:

- 🤖 Agentタスク（準備 → 実装 → 検証 → 完了の4フェーズ）
- 👤 Humanタスク（C-3: exec前ゲート、C-4: PRレビュー）
- ⚠️ 依存関係（Agent ↔ Human）
- 各タスクに Owner（agent / human）と 🚩チェックポイントを明記
- L-0〜V-4, PR作成はworkflow-conductorが自動制御するため含めない

### test-cases.md（テストケース定義）

フェーズB（Prompt 1）でplanと同時生成。以下を含める:

- 受入基準 → テストケースマッピング
- テストケース一覧（前提条件 / 入力 / 期待出力 / 種別）
- エッジケース

### review-self.md（セルフレビュー結果）

フェーズC-1（Prompt 2）で生成。以下を含める:

- Planチェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化
- ToDoチェック（5項目）: タスク粒度、depends_on設定、チェックポイント設定、Iron Law遵守、完了条件
- TestCasesチェック（3項目）: 受入基準との紐付き、Edge case網羅、自動化可否
- 判定: PASS / WARN / FAIL + 指摘事項

### review-external.md（外部AIレビュー結果）

フェーズC-2で生成（任意）。外部AIツールによるレビュー結果。

### status.md（作業ステータス）

フェーズD以降で随時更新。以下を含める:

- **全体構成**: PR一覧（ブランチ名、状態）
- **各PRの実装状態**: コミット履歴、変更ファイル一覧
- **計画からの変更点**: リネーム、削除、設計変更などの差分を明記
- **残タスク**: チェックリスト形式（`- [ ]` / `- [x]`）
- **V系ステップ進捗**: L-0/V-1〜V-4の完了状況
- **モード判定結果**: ultra-light / light / standard / high-risk / critical
- **Claude Codeプロンプト**: 次の作業をClaude Codeに依頼する際のプロンプト（コンテキスト・背景・タスク込み）
- **参照ファイル一覧**: 関連ドキュメントへのパス

#### 段階別出力フォーマット

status.mdの更新タイミングと記載内容を段階で分ける:

**開始時**（セッション開始・exec開始）:
- 現在のフェーズと残タスク数を記録
- 前回セッションからの変更点を確認・記載

**実装中**（各🚩チェックポイント通過時）:
- 完了したステップと変更ファイルを追記
- 計画からの逸脱があれば「計画からの変更点」に即記録
- 仮定した事項があれば明記

**終了時**（セッション終了・exec完了）:
- 実装結果サマリ: 完了した作業、変更ファイル一覧、実行したコマンド
- 検証結果: lint/test/typecheckの結果
- V系ステップ結果: L-0/V-1〜V-4の結果サマリ
- 既知の制約・リスク
- 次回セッション用のClaude Codeプロンプト（コンテキスト・背景・具体的タスクを含む）

## 運用ルール

### セッション開始時

1. 対象チケットの `docs/working/TASK-XXXX/` が存在するか確認する
2. `INDEX.md` が存在すれば読み、現在フェーズを確認する（L0）
3. `current-state.md` を読み、中断地点・ブロッカーを把握する（L0）
4. フェーズに応じて必要なファイルを読む（L1、Progressive Disclosure プロトコルに従う）
5. `INDEX.md` が存在しない場合（旧形式）→ `status.md` を読み、現在の状態を把握してから作業を開始する（フォールバック）

### 作業中

- 計画から逸脱する変更（リネーム、機能削除、設計変更）が発生した場合、`status.md` の「計画からの変更点」セクションに記録する
- タスク完了時は `todo.md` と `status.md` の残タスクチェックリストを更新する

### セッション終了時・中断時

- `status.md` を最新の状態に更新する
- 特に「残タスク」と「Claude Codeプロンプト」が次回セッションで使えるよう整備する

### Claude Codeへの作業委譲時

プロンプトに以下を必ず含める:

- `docs/working/TASK-XXXX/status.md` の参照指示
- 外部チケットURL（任意、Why / Whatの理解用）
- 命名変更など計画との差分の明示
- 具体的なタスクリスト

### ゲート条件

#### C-3ゲート（計画承認・三値）

- `review-self.md`（C-1）と`review-external.md`（C-2）のレビュー結果を人間が確認
- 三値で判断:
  - **APPROVE**: exec開始。status.mdに`## C-3 Gate: APPROVED`を記録
  - **CONDITIONAL**: 指摘をplan.mdに反映 + 簡易C-1再実行 → exec開始。status.mdに`## C-3 Gate: CONDITIONAL`を記録
  - **REJECT**: plan再生成。status.mdに`## C-3 Gate: REJECTED`を記録
- C-2（`review-external.md`）は任意。C-2をスキップする場合はC-1のみで判断可
- FAILが出た場合は指摘事項を反映してplan.md / todo.md / test-cases.mdを再生成する

#### C-4ゲート（PRレビュー・三値）

- GitHub上でPRをレビュー
- **APPROVE**: マージ → Done
- **REQUEST CHANGES**: 指摘内容に基づきexecから再実行
- **REJECT**: planからやり直し（稀）

## v7 ハイブリッドアーキテクチャ: Handoff の必須化

PlanGate v7 ハイブリッドアーキテクチャ（TASK-0021 で導入）では、**全 PBI で handoff.md を必須出力**とする（Rule 5）。

### handoff.md の位置付け

| ファイル | 役割 | 更新タイミング | 読者 |
|---------|------|-------------|------|
| `status.md` | フェーズ履歴アーカイブ | フェーズ遷移毎 | 未来の担当者、監査 |
| `current-state.md` | 今の状態スナップショット | タスク完了毎 | 現担当者、セッション復旧時 |
| **`handoff.md`** | **完了時の引き継ぎパッケージ** | **TASK 完了時（必須）** | **次の担当者、レビュアー** |

### handoff.md 必須 6 要素

- 要件適合確認結果（`acceptance-review` Skill の出力）
- 既知課題一覧（`known-issues-log` Skill の出力）
- V2 候補（今回の scope 外）
- 妥協点（選ばなかった選択肢と理由）
- 引き継ぎ文書（5 分で状況把握できるサマリ）
- テスト結果サマリ

### タイミング

WF-05 Verify & Handoff phase で生成。PlanGate ゲートでは V-1 PASS 後、C-4 ゲート前に発行。

### テンプレート

[`docs/working/templates/handoff.md`](../../docs/working/templates/handoff.md)

### 関連

- Workflow: [`docs/workflows/05_verify_and_handoff.md`](../../docs/workflows/05_verify_and_handoff.md)
- Agent: `.claude/agents/qa-reviewer.md`（主担当）、`.claude/agents/orchestrator.md`（最終発行）
- 例外: critical インシデント対応等、緊急度が極めて高い場合は事後追補で可
