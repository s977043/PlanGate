# TASK-0019 EXECUTION PLAN

> 生成日: 2026-04-19
> PBI: [TASK-0016-C] PlanGate 中核 agents（8体）を plugin に移植する
> チケットURL: https://github.com/s977043/plangate/issues/19

## Goal

PlanGate ワークフローを完結させる中核 6 agents を `plugin/plangate/agents/` に配置し、プロジェクト固有前提を除去することで、他プロジェクトでも汎用的に使える plugin を完成させる。rules 3 ファイルと中核スクリプトも合わせて移植する。

## Constraints / Non-goals

- 対象 agents: 6 体（`workflow-conductor`, `spec-writer`, `implementer`, `linter-fixer`, `acceptance-tester`, `code-optimizer`）※ `test-engineer` / `release-manager` は .claude/ に存在しないため除外
- 対象 rules: 3 ファイル（`working-context.md`, `review-principles.md`, `mode-classification.md`）
- プロジェクト固有前提（Laravel/PostgreSQL/ECS 等）の除去は必須
- `.claude/agents/` は温存（デュアル運用）
- **Non-goals**: 他 agents の移植、挙動のリファクタリング、hooks 実装、プロジェクト固有スクリプトの移植

## Approach Overview

1. 6 agents の現行定義をスキャンし、プロジェクト固有前提を抽出
2. `plugin/plangate/agents/` に 6 agents をコピー配置
3. 各 agent から固有前提を除去（汎用表現へ置換）
4. rules 3 ファイルを `plugin/plangate/rules/` に配置し、参照パスを修正
5. plugin 中核スクリプトを `plugin/plangate/scripts/` に配置
6. `plugin.json` の agents / rules エントリを更新
7. agents 間の相互参照が plugin 内で解決されることを確認
8. plan → C-1 → exec → L-0 → V-1 → PR フローの plugin 内完結を検証

## Work Breakdown

### Step 1: agents 固有前提スキャン + 依存調査 + 決定ログ

- **Output**:
  - `docs/working/TASK-0019/evidence/agents-scan.md`（各 agent の固有前提箇所）
  - `docs/working/TASK-0019/evidence/dependency-scan.md`（rules / scripts / 他 agents への参照依存）
  - `docs/working/TASK-0019/evidence/reference-resolution.md`（plugin 内 agent/rules 参照方式の決定ログ。例: `plangate:implementer` 形式、rules は `plugin/plangate/rules/` 絶対参照）
  - `docs/working/TASK-0019/evidence/script-inventory.md`（`scripts/` に配置する具体スクリプト一覧の決定ログ）
  - `docs/working/TASK-0019/evidence/base-commit.md`（本 TASK 着手時点の commit SHA）
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**:
  - 6 agents 全件のスキャン完了、プロジェクト固有記述の特定
  - rules/scripts 依存調査が `dependency-scan.md` に独立して記録されている
  - agent/rules 参照方式（prefix、解決規則）が実装前に確定
  - `scripts/` 対象スクリプト名が具体的に列挙されている
  - `.claude/` 基準 SHA が記録されている

### Step 2: agents コピー配置

- **Output**: `plugin/plangate/agents/{agent名}.md` × 8
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 8 ファイルが plugin 側に存在、内容が原本と一致

### Step 3: 固有前提除去

- **Output**: 汎用化された 6 agents 定義
- **Owner**: agent
- **Risk**: 高
- **🚩 チェックポイント**: Step 1 で特定した固有前提が全て汎用表現に置換され、かつ agent の本質的役割が維持されている

### Step 4: rules 配置と参照修正

- **Output**: `plugin/plangate/rules/` に 3 ファイル、agents 内 rules 参照パスの修正
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 3 rules が plugin 側に存在、agents からの参照パスが plugin 内を指す

### Step 5: 中核スクリプト配置

- **Output**: `plugin/plangate/scripts/` に該当スクリプト（`scripts/` から中核のみ）
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 中核スクリプトが plugin 内に存在し、動作する

### Step 6: plugin.json 更新

- **Output**: agents / rules エントリ追記
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 6 agents と 3 rules が列挙、JSON valid

### Step 7: agents 間相互参照検証

- **Output**: `docs/working/TASK-0019/evidence/agent-chain-test.md`
- **Owner**: agent
- **Risk**: 高
- **🚩 チェックポイント**: workflow-conductor が 7 agents を plugin 内から呼び出せる

### Step 8: フロー完結検証

- **Output**: `docs/working/TASK-0019/evidence/flow-completion-test.md`
- **Owner**: agent
- **Risk**: 高
- **🚩 チェックポイント**: plan → C-1 → exec → L-0 → V-1 → PR フロー全体が plugin 内 6 agents で動作する証跡

### Step 9: `.claude/agents/` / `.claude/rules/` 非破壊確認

- **Output**: `docs/working/TASK-0019/evidence/non-destructive-check.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: `git diff --stat <base-sha> -- .claude/agents/ .claude/rules/` で変更 0 件（基準 SHA は Step 1 の `evidence/base-commit.md` 参照）

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 新規 | plugin/plangate/agents/workflow-conductor.md | コピー + 汎用化 |
| 新規 | plugin/plangate/agents/spec-writer.md | コピー + 汎用化 |
| 新規 | plugin/plangate/agents/implementer.md | コピー + 汎用化 |
| 新規 | plugin/plangate/agents/linter-fixer.md | コピー + 汎用化 |
| 新規 | plugin/plangate/agents/acceptance-tester.md | コピー + 汎用化 |
| 新規 | plugin/plangate/agents/code-optimizer.md | コピー + 汎用化 |
| 新規 | plugin/plangate/rules/working-context.md | コピー |
| 新規 | plugin/plangate/rules/review-principles.md | コピー |
| 新規 | plugin/plangate/rules/mode-classification.md | コピー |
| 新規 | plugin/plangate/scripts/** | 中核スクリプト |
| 修正 | plugin/plangate/.claude-plugin/plugin.json | agents/rules エントリ追記 |
| 新規 | docs/working/TASK-0019/evidence/agents-scan.md | スキャン結果 |
| 新規 | docs/working/TASK-0019/evidence/agent-chain-test.md | 参照検証 |
| 新規 | docs/working/TASK-0019/evidence/flow-completion-test.md | フロー検証 |

## Testing Strategy

- **Unit**: 各 agent / rules ファイルが plugin 側に存在
- **Integration**: plugin.json agents/rules エントリ件数、rules 参照解決
- **E2E**: plan → C-1 → exec → L-0 → V-1 → PR フローが plugin 内 6 agents で完結
- **Edge cases**: 固有前提除去による挙動変化、agents 間参照の prefix、rules パス破損
- **Verification Automation**:
  - `ls plugin/plangate/agents/ | wc -l` → 8
  - `ls plugin/plangate/rules/ | wc -l` → 3
  - `grep -r "Laravel\|PostgreSQL\|ECS\|Cloudflare" plugin/plangate/agents/` → 0 件（汎用化確認）
  - フロー手動検証（PlanGate ワークフローを plugin 内で 1 周）

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| 固有前提除去で agent 挙動が過度に汎用化される | 汎用化ガイドライン策定、除去後の動作を既存プロジェクトで確認 |
| agents 間参照が plugin 内で解決できない | Step 1 で参照方式を調査、Step 7 で全組み合わせを検証 |
| rules 参照パスが plugin 化で壊れる | agents 内の rules パス記述を一覧化、systematic 書き換え |
| 隠れた固有依存を持つ agent がある | Step 1 のスキャンを徹底、review-external.md でも確認 |
| plugin 側と `.claude/` 側で agent 衝突 | prefix（`plangate:`）明示、呼び出し順序ルールを migration note に記載 |

## Questions / Unknowns

- plugin 経由 agent 呼び出しの prefix（`Task(subagent_type="plangate:implementer")` か）
- rules ファイルの plugin 内参照方式（相対 / 絶対）
- scripts/ に入れるべき中核スクリプトの具体リスト（Step 5 で決定）
- 固有前提除去の最適粒度（Step 1 の結果で判断）

## Mode判定

**モード**: `full`

**判定根拠**:
- 変更ファイル数: 14-20（6 agents + 3 rules + bin + plugin.json + evidence） → full
- 受入基準数: 9 → full
- 変更種別: 複数 agent 定義の修正＋配置＋汎用化 → full
- リスク: 高（固有前提除去・参照整合・フロー完結） → full
- **最終判定**: full

**full モードのゲート適用**:
- C-1 セルフレビュー: 17項目チェック
- C-2 外部AIレビュー: 必須
- V-2 コード最適化: 必須
- V-3 外部モデルレビュー: 必須

## 依存

- **前提**: TASK-0017, TASK-0018 完了
- **後続**: TASK-0020（README + migration note）
