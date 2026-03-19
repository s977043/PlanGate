# /ai-dev-workflow

AI駆動開発ワークフロー v2 の各フェーズを実行する。

ワークフロー詳細: `docs/ai-driven-development.md`
ルール: `.claude/rules/working-context.md`

## 引数

$ARGUMENTS に以下の形式で渡される:

- `TASK-XXXX brainstorm` — フェーズ0: Brainstorming（アイデア→設計書の対話的生成）
- `TASK-XXXX plan` — フェーズB〜C-2: Plan + ToDo生成 → セルフレビュー → 外部AIレビュー → 指摘反映（一括自動実行）
- `TASK-XXXX exec` — フェーズD: Agent実行
- `TASK-XXXX status` — 現在のフェーズと進捗を表示

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
**出力**: `plan.md` + `todo.md` + `review-self.md` + `review-external.md`

> C-1（セルフレビュー）とC-2（外部AIレビュー）はAgent自身の作業のため、ユーザー確認なしで自動実行する。
> WARN/FAILがあればplan/todoを自動修正し、最終結果をユーザーに提示する。

#### ステップ1: PBI INPUT PACKAGE取得

1. `docs/working/TASK-XXXX/pbi-input.md` が存在するか確認
   - 存在しなければ: ユーザーにPBI情報を直接入力してもらい、pbi-input.mdを生成
2. PBI INPUT PACKAGEの内容を読む

#### ステップ2: Plan + ToDo生成（フェーズB）

以下の2つの成果物を同時生成:

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

### 実装フェーズ
- [ ] 🚩 {タスク内容} [Owner: agent]

### 検証フェーズ
- [ ] 🚩 テスト追加/更新 [Owner: agent]
- [ ] 🚩 動作検証スクリプト実行 [Owner: agent]
- [ ] 🚩 受入基準の全確認 [Owner: agent]

### 完了フェーズ
- [ ] 🚩 PR説明を作成する [Owner: agent]
- [ ] 🚩 未解決Unknownsが0か確認 [Owner: agent]

## 👤 Human タスク
- [ ] {タスク内容} [Owner: human]

## ⚠️ 依存関係
```

`status.md` を更新（フェーズB完了を記録）

#### ステップ3: セルフレビュー自動実行（フェーズC-1）

> ユーザー確認不要。plan/todo生成後にそのまま実行する。

1. `plan.md` + `todo.md` + `pbi-input.md` を読み込む
2. 以下の12項目をチェック:

**Planチェック（7項目）**:
1. 受入基準網羅性 — 受入基準の全項目がWork Breakdownにマッピングされているか
2. Unknowns処理 — Questions/Unknownsが0、または解決手段が明記されているか
3. スコープ制御 — Non-goalsが明確で、スコープクリープの兆候がないか
4. テスト戦略 — Unit/Integration/E2Eの対象が具体的か
5. Work Breakdown Output — 各Stepに具体的なOutputがあるか
6. 依存関係 — Step間の依存が矛盾なく順序付けられているか
7. 動作検証自動化 — Verification Automationが具体的か

**ToDoチェック（5項目）**:
8. Owner明確性 — 全タスクにagent/humanが明記されているか
9. Agent/Human分離 — 明確に分かれているか
10. 実行順序 — 依存関係に矛盾がないか
11. チェックポイント設定 — 各タスクに🚩があるか
12. 動作検証タスクの具体性 — コマンド/期待結果があるか

3. 各項目にPASS / WARN / FAILを判定
4. `review-self.md` を生成
5. FAILがある場合はplan/todoを自動修正してから次のステップへ
6. `status.md` を更新（フェーズC-1完了を記録）

#### ステップ4: 外部AIレビュー自動実行（フェーズC-2）

> ユーザー確認不要。利用可能なサブエージェントまたは外部AIツールを使用して複数視点でレビューする。

1. 利用可能なエージェントに以下の観点でレビューを依頼:
   - **実装観点**: 調査対象の網羅性、根本原因分析の妥当性、修正方針の実現可能性
   - **影響範囲観点**: 変更の影響範囲、既存機能への副作用
   - **コードベース網羅探索**: planに記載されていない見落とし箇所の全量検索
2. レビュー結果を統合して `review-external.md` を生成
3. 重要指摘（WARN/FAIL）がある場合、plan/todoを自動修正
4. `status.md` を更新（フェーズC-2完了を記録）

> プロジェクト固有のエージェント構成に応じてレビュー観点をカスタマイズすること。

#### ステップ5: 最終結果の提示

1. フェーズB〜C-2の全結果をユーザーにサマリ表示:
   - C-1結果（PASS/WARN/FAIL件数）
   - C-2結果（重要指摘件数、自動修正した内容）
   - 生成されたファイル一覧
2. 次のステップを案内: C-3（人間レビュー）→ `/ai-dev-workflow TASK-XXXX exec`

### サブコマンド: exec（フェーズD）

**入力**: Approved済みの `plan.md` + `todo.md`
**出力**: 実装 + PR

1. **ゲート確認**: ユーザーに「C-3（人間レビュー）はApprovedですか？」と確認(y/n)。未承認なら停止
2. `plan.md` と `todo.md` を読み込む
3. `status.md` を読み込み、計画からの変更点を確認
4. 以下の絶対ルールに従って実装:
   - TODOの「🤖 Agent タスク」だけを実行。「👤 Human タスク」には手を出さない
   - スコープ外はやらない
   - 不明点は即座に停止してユーザーに質問
   - 🚩チェックポイントでtodo.md更新・動作検証を実施
   - **todo.mdのチェック更新はリアルタイムに行う**（各ステップ完了時に即座に`- [ ]`→`- [x]`に更新）
   - テストコードだけでなく実際に動かして確認
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

7. 実行フロー: 準備フェーズ → 実装フェーズ → 検証フェーズ → 完了フェーズ
8. 各🚩チェックポイントで `todo.md` のチェックをリアルタイム更新
9. PR作成（ブランチ命名規則に従う）
10. `status.md` を最終更新（段階別出力フォーマットに従う）

### サブコマンド: status

1. `docs/working/TASK-XXXX/` 配下の全ファイルの存在を確認
2. 現在のフェーズを判定:
   - `pbi-input.md` のみ → フェーズA完了
   - `plan.md` + `todo.md` あり → フェーズB完了
   - `review-self.md` あり → フェーズC-1完了
   - `review-external.md` あり → フェーズC-2完了
   - `status.md` に「Agent実行中」記載 → フェーズD進行中
   - `status.md` に「完了」または「Done」記載 → フェーズD完了
3. `status.md` の残タスクを表示
4. 次に実行すべきサブコマンドを提案

## 重要ルール

- **第1原則の適用**: サブコマンド実行時に作業計画を報告し、実行自体を承認とみなす。サブコマンド内部の個別ファイル操作では確認不要。確認が必要なのはC-3ゲートと計画変更「大」のみ
- **ゲート遵守**: C-3（人間レビュー）未承認ではexecを実行しない
- **todo.mdリアルタイム更新**: execフェーズで各ステップ完了時に即座にチェックを入れる
- 既存コードのパターンに従う（`Grep`/`Glob`で探索してから実装）
- status.mdのフェーズ履歴には日時（YYYY-MM-DD HH:MM）を記録する
