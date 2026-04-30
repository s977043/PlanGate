# /ai-dev-workflow

PlanGate ワークフロー v5 の各フェーズを実行する。

PlanGateガイド: `docs/plangate.md`
ワークフロー詳細: `docs/ai-driven-development.md`
ルール: `.claude/rules/working-context.md`

## 引数

$ARGUMENTS に以下の形式で渡される:

- `TASK-XXXX brainstorm` — フェーズ0: Brainstorming（アイデア→設計書の対話的生成）
- `TASK-XXXX plan` — フェーズB〜C-2: Plan + ToDo + Test Cases生成 → セルフレビュー（17項目）→ 外部AIレビュー → 指摘反映（一括自動実行）
- `TASK-XXXX exec` — フェーズD〜C-4: Agent実行 → 多層防御検証 → PR作成
- `TASK-XXXX status` — 現在のフェーズと進捗を表示

## Iron Law（不可侵ルール）

違反したら即停止する 7 項目の Iron Law（[`docs/ai/core-contract.md`](../../docs/ai/core-contract.md) の Hard constraints が正本）。

| ルール | 意味 |
|-------|------|
| `NO EXECUTION WITHOUT REVIEWED PLAN FIRST` | 承認なしにコードを書くな |
| `NO SCOPE CHANGE WITHOUT USER APPROVAL` | 勝手にスコープを変えるな |
| `NO CODE WITHOUT APPROVED DESIGN FIRST` | 設計なしにコードを書くな |
| `NO MERGE WITHOUT TWO-STAGE REVIEW` | 2段階レビューなしにマージするな |
| `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE` | 証拠なしに完了と言うな |
| `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST` | 原因調査なしに修正するな |

## 前提条件

- `docs/working/TASK-XXXX/` が存在すること（なければ `/working-context TASK-XXXX` で作成を促す）
- フェーズDの実行は、C-3（人間レビュー）が完了するまでブロック

## 実行フロー

### サブコマンド: brainstorm（フェーズ0）

**入力**: ユーザーのアイデア・要件（口頭 or テキスト）
**出力**: `pbi-input.md`（PBI INPUT PACKAGE）

brainstormingスキルを呼び出し、対話的にPBI INPUT PACKAGEを生成する。

1. `docs/working/TASK-XXXX/` が存在しなければ作成
2. brainstormingスキルの8ステッププロセスを実行:
   - コードベース調査 → 1質問ずつの対話 → アプローチ提案 → 設計書生成 → レビュー
3. 完了後、`docs/working/TASK-XXXX/pbi-input.md` に保存
4. `status.md` を更新（フェーズ0完了を記録）
5. 次ステップ案内: `plan` サブコマンドへの遷移を提案

### サブコマンド: plan（フェーズB〜C-2一括実行）

**入力**: PBI INPUT PACKAGE（`pbi-input.md` or ユーザー入力）
**出力**: `plan.md` + `todo.md` + `test-cases.md` + `INDEX.md` + `current-state.md` + `decision-log.jsonl` + `evidence/` + `review-self.md` + `review-external.md`

> C-1（セルフレビュー）とC-2（外部AIレビュー）はAgent自身の作業のため、ユーザー確認なしで自動実行する。
> WARN/FAILがあればplan/todoを自動修正し、最終結果をユーザーに提示する。

#### コンテキスト読み込み（plan）

1. `INDEX.md` を読む → 存在すれば現在フェーズを確認（再実行の場合）
2. 存在しなければ新規チケットとして進行
3. `pbi-input.md` を読む（plan フェーズの L1 対象）

#### ステップ1: PBI INPUT PACKAGE取得

1. `docs/working/TASK-XXXX/pbi-input.md` が存在するか確認
   - 存在しなければ: ユーザーにPBI情報を直接入力してもらい、pbi-input.mdを生成
2. PBI INPUT PACKAGEの内容を読む

#### ステップ2: Plan + ToDo + Test Cases生成（フェーズB）

以下の3つの成果物を同時生成:

##### plan.md（EXECUTION PLAN）

```markdown
# TASK-XXXX EXECUTION PLAN

> 生成日: YYYY-MM-DD
> PBI: {タイトル}
> チケットURL: {URL}（任意）

## Goal
## Constraints / Non-goals

- {制約1}
- {制約2}
- **Non-goals（スコープ外）**: {スコープ外の項目}

## Approach Overview

## Work Breakdown

### Step 1: {ステップ名}
- **Output**: {具体的な成果物}
- **Owner**: agent / human
- **Risk**: 低 / 中 / 高
- **🚩 チェックポイント**: {確認内容}

### Step N: ...

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
|------|------------|---------|

## Testing Strategy
- **Unit**:
- **Integration**:
- **E2E**:
- **Edge cases**:
- **Verification Automation**:

## Risks & Mitigations

| リスク | 対策 |
|-------|------|

## Questions / Unknowns

## Mode判定

> 判定基準の正本: `.claude/rules/mode-classification.md`

**モード**: {ultra-light | light | standard | high-risk | critical}

**判定根拠**:
- 変更ファイル数: {N} → {モード}
- 受入基準数: {N} → {モード}
- 変更種別: {種別} → {モード}
- リスク: {レベル} → {モード}
- **最終判定**: {モード}（{オーバーライドの場合はその理由}）
```

##### todo.md（EXECUTION TODO）

```markdown
# TASK-XXXX EXECUTION TODO

> 生成日: YYYY-MM-DD

## 🤖 Agent タスク

### 準備フェーズ
- [ ] 🚩 Scope/受入基準を再掲し、作業範囲を固定する [Owner: agent]
- [ ] 🚩 既存コード/仕様を探索し、変更点候補を列挙する [Owner: agent]
- [ ] 🚩 実装方針を決定し、Planとの差分がないことを確認する [Owner: agent]

### 実装フェーズ（TDD: RED → GREEN → REFACTOR）
- [ ] 🚩 {タスク内容} [Owner: agent]

### 検証フェーズ
- [ ] 🚩 テスト追加/更新 [Owner: agent]
- [ ] 🚩 動作検証スクリプト実行 [Owner: agent]
- [ ] 🚩 受入基準の全確認 [Owner: agent]

### 完了フェーズ
- [ ] 🚩 コミット作成 [Owner: agent]
- [ ] 🚩 status.md最終更新 [Owner: agent]

> 注: L-0〜V-4, PR作成はworkflow-conductorが自動制御するため、todo.mdには含めない。

## 👤 Human タスク
- [ ] C-3: Plan/ToDo/Test Casesの人間レビュー（exec前ゲート） [Owner: human]
- [ ] C-4: PRレビュー・承認（GitHub上） [Owner: human]

## ⚠️ 依存関係
- Agent実装 → Human C-3レビュー承認後にexec開始
- PR作成 → Human C-4レビュー承認後にマージ
```

##### test-cases.md（TEST CASES）

`docs/ai-driven-development.md` のPrompt 1のテストケースフォーマットに従って生成。

`status.md` を更新（フェーズB完了を記録）

#### ステップ2.5: 索引・状態ファイル生成（v6追加）

Plan + ToDo + Test Cases 生成完了後、以下のファイルを自動生成する:

1. **`INDEX.md`** を `docs/working/templates/INDEX.md` テンプレートに従い生成
   - チケット概要を pbi-input.md から1-2文で要約
   - 現在のフェーズを `plan` に設定
   - 変更ファイル一覧を plan.md の Files/Components to Touch から抽出
2. **`current-state.md`** を `docs/working/templates/current-state.md` テンプレートに従い生成
   - フェーズを `plan`、進捗を「B-3完了、C-1開始前」に設定
3. **`decision-log.jsonl`** を空ファイルで初期化
   - B-1/B-2 で行った判断（確認質問の回答、アプローチ選定理由）を初期エントリとして記録
4. **`evidence/`** ディレクトリを作成（サブディレクトリ: `c1-review/`, `c2-review/`, `test-runs/`, `verification/`, `e2e/`）

#### ステップ3: セルフレビュー自動実行（フェーズC-1）

> ユーザー確認不要。plan/todo/test-cases生成後にそのまま実行する。

1. `plan.md` + `todo.md` + `test-cases.md` + `pbi-input.md` を読み込む
2. 以下の17項目をチェック:

**Planチェック（7項目）**:
1. 受入基準網羅性 — 全受入基準に対してVerificationが書かれているか（必須）
2. Unknowns処理 — 放置されていないか、質問として明文化されているか（必須）
3. スコープ制御 — Out of scopeへ踏み込みそうな箇所がないか（必須）
4. テスト戦略 — Unit/Integration/E2E/Edge casesが妥当か（必須）
5. Work Breakdown Output — 各Stepに具体的な成果物があるか（必須）
6. 依存関係 — 移行・ロールバックが必要なのに欠けていないか（必須）
7. 動作検証自動化 — テストコードだけでなく動作検証手段が具体的か（必須）

**ToDoチェック（5項目）**:
8. タスク粒度 — 各タスクが2〜5分で完了できる粒度か（必須）
9. depends_on設定 — 依存関係が明示されているか（必須）
10. チェックポイント設定 — 各StepにToDo更新タイミングが設定されているか（推奨）
11. Iron Law遵守 — 承認前コード実行・スコープ逸脱の危険がないか（必須）
12. 完了条件 — 各タスクに完了条件が記述されているか（推奨）

**TestCasesチェック（3項目）**:
13. 受入基準との紐付き — 全受入基準に対してテストケースがあるか（必須）
14. Edge case網羅 — 境界値・異常系が設計されているか（必須）
15. 自動化可否 — 手動テストのみでなく自動化できるか（推奨）

**B-1/B-2チェック（2項目）**:
16. B-1確認質問 — PBI INPUTの曖昧な箇所を確認質問で解消したか、または曖昧さがないことを確認したか（必須）
17. B-2アプローチ比較 — 2案以上のアプローチを比較し、推薦案の選定理由を明記したか（必須）

3. 各項目にPASS / WARN / FAILを判定
4. `docs/working/templates/review-self.md` のschemaに従い `review-self.md` を生成（check_id付き構造化形式: C1-PLAN-01〜C1-B1B2-17）
   - FAIL時は `evidence/c1-review/{check_id}.md` にエビデンスを保存し、evidence_ref で参照
   - サマリーテーブル（PASS/WARN/FAIL件数）と自動修正ログテーブルを含める
5. FAILがある場合はplan/todo/test-casesを自動修正してから次のステップへ
6. `status.md` を更新（フェーズC-1完了を記録）
7. `current-state.md` を更新（フェーズを `C-1` に、進捗を更新）

#### ステップ4: 外部AIレビュー自動実行（フェーズC-2）

> ユーザー確認不要。専門エージェントを使用して複数視点でレビューする。

1. 利用可能なエージェントに以下の観点でレビューを依頼:
   - **実装観点**: 調査対象の網羅性、根本原因分析の妥当性、修正方針の実現可能性
   - **影響範囲観点**: 変更の影響範囲、既存機能への副作用
   - **コードベース網羅探索**: planに記載されていない見落とし箇所の全量検索
2. レビュー結果を統合し、`docs/working/templates/review-external.md` のschemaに従い `review-external.md` を生成（check_id付き構造化形式: C2-BE-01, C2-FE-01, C2-EXP-01 等）
   - FAIL時は `evidence/c2-review/{agent}-{check_id}.md` にエビデンスを保存
3. 重要指摘（WARN/FAIL）がある場合、plan/todo/test-casesを自動修正
4. `status.md` を更新（フェーズC-2完了を記録）
5. `current-state.md` を更新（フェーズを `C-2` に更新）

> プロジェクト固有のエージェント構成に応じてレビュー観点をカスタマイズすること。

#### ステップ5: 最終結果の提示

1. フェーズB〜C-2の全結果をユーザーにサマリ表示:
   - C-1結果（PASS/WARN/FAIL件数、17項目）
   - C-2結果（重要指摘件数、自動修正した内容）
   - 生成されたファイル一覧
2. C-3（人間レビュー）の三値判断を案内:
   - **APPROVE** → `/ai-dev-workflow TASK-XXXX exec`
   - **CONDITIONAL** → 指摘をplan.mdに反映 + 簡易C-1再実行 → exec
   - **REJECT** → plan再生成（`/ai-dev-workflow TASK-XXXX plan`）。status.mdには`## C-3 Gate: REJECTED`と記録される

**人間が特に集中すべき点（AIが見落としやすい）:**
- ビジネスコンテキストとの整合性（技術的には正しいがビジネス的に不適切なケース）
- 曖昧な要件の解釈が意図と合っているか
- ユーザー影響の判断（技術リスク vs ユーザー体験）
- AIが「Unknownsなし」と判断したが実際には残っているもの

> レビュー時間の目標: 15分以内 / PBI（C-1/C-2で事前フィルタ済みのため）

### サブコマンド: exec（フェーズD〜C-4）

**入力**: Approved済みの `plan.md` + `todo.md` + `test-cases.md`
**出力**: 実装 + 多層防御検証 + PR

#### コンテキスト読み込み（exec）

1. `INDEX.md` を読む → 現在フェーズを確認（L0）
2. `current-state.md` を読む → 中断地点を確認（L0）
3. 以下のファイルのみ読む（L1）:
   - `plan.md`（承認済み計画）
   - `todo.md`（タスク進捗）
   - `test-cases.md`（テスト定義）
4. `evidence/` は検証結果の記録時のみアクセスする（L2）
5. **読まない**: `pbi-input.md`（exec フェーズでは計画が権威）、`review-self.md`、`review-external.md`

1. **C-3ゲート確認（三値対応）**:
   - ユーザーに「C-3（人間レビュー）の結果は？ APPROVE / CONDITIONAL / REJECT」と確認
   - APPROVE → exec開始
   - CONDITIONAL → 指摘反映済みか確認 → exec開始
   - REJECT → 停止、plan再生成を案内
   - 未回答 → 停止
2. `plan.md`、`todo.md`、`test-cases.md` を読み込む（L1、上記コンテキスト読み込みに従う）
3. 以下の Iron Law に従って実装:
   - TODOの「🤖 Agent タスク」だけを実行。「👤 Human タスク」には手を出さない
   - スコープ外はやらない
   - 不明点は即座に停止してユーザーに質問
   - 🚩チェックポイントでtodo.md更新・動作検証を実施
   - **todo.mdのチェック更新はリアルタイムに行う**（各ステップ完了時に即座に`- [ ]`→`- [x]`に更新）
   - テストコードだけでなく実際に動かして確認
   - TDD: test-cases.mdに基づいてテスト先行（RED → GREEN → REFACTOR）
5. **Behavior rules**（実装時の行動規則）:
   - **Blast radiusを最小化**: 関係ないファイルを変更しない。リファクタリングは依頼された範囲のみ
   - **既存パターン優先**: 実装前に `Grep`/`Glob` で既存の類似実装を探し、そのパターンに従う。一般論で上書きしない
   - **小さく実装して検証**: 1ステップ実装 → lint/test → 次のステップ。一気に全部やらない
   - **依存追加は事前説明**: 新しいパッケージやライブラリを追加する場合、理由を説明してからインストール
   - **仮定は明示して続行**: 不明点があるが作業を進められる場合、仮定を `status.md` に記録して続行。ブロッキングな不明点のみ停止
   - **空のTODOコメントを残さない**: 実装が完了したコードに `// TODO` を残さない（未実装の場合はtodo.mdに記録）
6. **計画変更ルール**（実装中に計画との乖離が発生した場合）:

   計画は作業仮説であり、実装中の発見で更新される。変更の重大度で対応を分ける:

   - **小**（リネーム、ファイル分割、引数変更）: `status.md` に記録して続行
   - **中**（設計方針の部分変更、テーブル構造変更、Step順序の入替）: `plan.md`を更新 → `status.md`に変更理由を記録 → 続行
   - **大**（アーキテクチャ変更、スコープ変更、受入基準への影響）: 実装停止 → plan更新 → ユーザー承認（第1原則）→ 再開

   **変更時の原則**:
   - 変更理由は必ずコードベース由来（既存実装・依存関係・テスト結果・技術的制約）。「なんとなく」は不可
   - 最終目標（受入基準）は変えない。変えるのはルートであって成果物ではない
   - すでに作ったものをなるべく活かす。破棄コストを最小化
   - 変更範囲を広げすぎない。計画変更を口実にリファクター祭りを始めない

7. **exec以降の多層防御フロー**（workflow-conductorが自動制御）:
   - D: TDD実装 → L-0: リンター自動修正 → V-1: 受け入れ検査 → V-2: コード最適化（フルのみ）→ V-3: 外部モデルレビュー → V-4: リリース前チェック（フルのみ）→ PR作成 → C-4: 人間レビュー
8. 各🚩チェックポイントで `todo.md` のチェックをリアルタイム更新
9. `status.md` を最終更新（段階別出力フォーマットに従う）

### サブコマンド: status

#### コンテキスト読み込み（status）

1. `INDEX.md` を読む → チケット概要とフェーズを確認（L0）
2. `current-state.md` を読む → 現在の進捗・ブロッカーを確認（L0）
3. 詳細が必要な場合のみ `status.md` と `todo.md` を読む（L1）

1. `docs/working/TASK-XXXX/` 配下の全ファイルの存在を確認
2. 現在のフェーズを判定:
   - `pbi-input.md` のみ → フェーズA完了
   - `plan.md` + `todo.md` + `test-cases.md` あり → フェーズB完了
   - `review-self.md` あり → フェーズC-1完了
   - `review-external.md` あり → フェーズC-2完了
   - `status.md` に「C-3 Gate: APPROVED」または「C-3 Gate: CONDITIONAL」記載 → C-3承認済み
   - `status.md` に「Agent実行中」記載 → フェーズD進行中
   - `status.md` にV系進捗記載 → L-0/V-1〜V-4進行中
   - `status.md` に「完了」または「Done」記載 → フェーズD完了
3. `status.md` の残タスクを表示
4. 次に実行すべきサブコマンドを提案

## 重要ルール

- **第1原則の適用**: サブコマンド実行時に作業計画を報告し、実行自体を承認とみなす。サブコマンド内部の個別ファイル操作では確認不要。確認が必要なのはC-3ゲート、C-4ゲート、計画変更「大」のみ
- **ゲート遵守**: C-3（人間レビュー）未承認ではexecを実行しない
- **todo.mdリアルタイム更新**: execフェーズで各ステップ完了時に即座にチェックを入れる
- 既存コードのパターンに従う（`Grep`/`Glob`で探索してから実装）
- status.mdのフェーズ履歴には日時（YYYY-MM-DD HH:MM）を記録する
