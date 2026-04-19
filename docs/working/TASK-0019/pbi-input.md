# PBI INPUT PACKAGE: PlanGate 中核 agents（8体）を plugin に移植する

> 作成日: 2026-04-19
> PBI: [TASK-0016-C] PlanGate 中核 agents（8体）を plugin に移植する
> チケットURL: https://github.com/s977043/plangate/issues/19
> 親チケット: https://github.com/s977043/plangate/issues/16

---

## Context / Why

Issue #16（plugin 化）の 3 つ目のステップとして、PlanGate ワークフローを完結させる中核 agents を plugin に同梱する。

agents は PlanGate の実行主体であり、これが plugin に入ることで以下が実現する:

- 他リポジトリで **plan → C-1 → exec → L-0 → V-1 → PR** の一連フローが plugin だけで回る
- プロジェクト固有 agents（Laravel 等）を含めないことで他プロジェクトへの汎用配布が可能になる
- rules 3 ファイルも合わせて移植することで、agents が参照する判定基準が plugin 内で完結する

---

## What（Scope）

### In scope

- 以下 8 agents を `.claude/agents/` から `plugin/plangate/agents/` に配置（コピー）:
  - `workflow-conductor`
  - `spec-writer`
  - `implementer`
  - `test-engineer`
  - `linter-fixer`
  - `acceptance-tester`
  - `code-optimizer`
  - `release-manager`
- 各 agent 定義の **プロジェクト固有前提の除去**:
  - Laravel / PostgreSQL / ECS / Cloudflare Pages 等の具体前提を汎用表現に修正
  - 「このプロジェクト」系の記述を汎用化
- PlanGate rules 3 ファイルを `plugin/plangate/rules/` に配置:
  - `working-context.md`
  - `review-principles.md`
  - `mode-classification.md`
- plugin 中核スクリプトを `plugin/plangate/scripts/` に配置（TASK-0017 の仕様調査により `bin/` ではなく `scripts/` を採用）
- `plugin.json` の agents / rules エントリを追記
- agents 間の相互参照（workflow-conductor → implementer 等）が plugin 内で解決されることを確認

### Out of scope

- 他の agents（`backend-specialist`, `frontend-specialist`, `database-architect`, `devops-engineer`, `security-auditor`, `penetration-tester`, `performance-optimizer`, `migration-agent`, `research-analyst`, `explorer-agent`, `project-planner`, `retrospective-analyst` 等）の移植
- agent 挙動のリファクタリング
- `.claude/agents/` 側の削除（A. デュアル運用のため温存）
- hooks の実装
- marketplace 登録メタデータ
- プロジェクト固有スクリプト（CI のプロジェクト依存部分等）の移植

---

## 受入基準

- [ ] 8 agents 全てが `plugin/plangate/agents/` 配下に存在する
- [ ] 各 agent 定義からプロジェクト固有前提（Laravel/PostgreSQL/ECS 等の具体記述）が除去されている
- [ ] rules 3 ファイルが `plugin/plangate/rules/` 配下に存在する
- [ ] `plugin.json` の agents / rules エントリが正しく記載されている
- [ ] plan → C-1 セルフレビュー → exec → L-0 → V-1 → PR のフローが plugin 内 8 agents で完結する
- [ ] agents 間の相互参照（呼び出しチェーン）が plugin 内で解決される
- [ ] rules 3 ファイルが plugin 内 agents から参照可能である
- [ ] 既存 `.claude/agents/` 側の動作が壊れていない（デュアル運用成立）
- [ ] plugin 中核スクリプト（該当あれば）が `scripts/` に配置されている

---

## Notes from Refinement

### 決定事項（親 TASK-0016 より継承）

- 対象 agents: 8 体（PlanGate 中核）
- 除外 agents: プロジェクト固有 / 専門用途 / 補助の計 10 体
- 対象 rules: 3 ファイル
- plugin 名: `plangate`

### プロジェクト固有前提の除去指針

| 修正対象 | 修正前例 | 修正後例 |
|---------|---------|---------|
| DB 依存 | `PostgreSQL 16 + Laravel Eloquent` | `データベース（プロジェクト依存）` |
| フレームワーク | `Laravel 11` | `バックエンドフレームワーク` |
| インフラ | `AWS ECS + CodeBuild + CodeDeploy` | `コンテナオーケストレーション` |
| ツール | `PHPUnit + Vitest + React Testing Library` | `テストフレームワーク（プロジェクト依存）` |

※ 具体的な除去対象は exec フェーズで agent ごとに精査する。

### 想定モード判定

**full**（高）を想定。

- 変更ファイル数: 11-15（agents 8 + rules 3 + plugin.json + 検証）
- 変更種別: 複数 agent 定義の修正＋配置
- リスク: 高（agent 間の参照関係が複雑、固有前提除去で挙動変化の可能性）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| 固有前提除去により agent の動作が汎用化されすぎて実用性を失う | High | 汎用化レベルのガイドライン策定、汎用後も既存プロジェクトで動作確認 |
| agents 間の参照（例: workflow-conductor → implementer）が plugin 内解決できない | High | 参照方式を事前調査、壊れる場合は参照 prefix を修正 |
| rules 参照パスが plugin 化で壊れる | Medium | 各 agent 定義内の rules パス記述を一覧化、plugin 内パスへ書き換え |
| 8 agents のうち隠れた固有依存を持つ agent がある | Medium | 各 agent の全文レビューを C-1 セルフレビューで実施 |
| plugin 側と `.claude/` 側で agent 名衝突、呼び出し先が不定 | Medium | prefix（`plangate:`）で明示、または呼び出し順序ルールを確立 |

### Unknowns

- plugin 経由 agent の呼び出し方（`Task(subagent_type="plangate:implementer")` 形式が使えるか）
- rules ファイルが plugin 内でどう参照されるか（相対パス / URI）
- bin/ に入れるべき中核スクリプトの具体リスト
- 固有前提除去の最適な粒度

### Assumptions

- TASK-0017（スケルトン）と TASK-0018（skills）が完了している
- 8 agents は現行 `.claude/agents/` で動作している
- rules 3 ファイルは現行ルールの正本として機能している
- agent 定義ファイルは plugin 側でも互換（Markdown + frontmatter 構造）

---

## 依存

- **前提**: Sub #17（TASK-0017）、Sub #18（TASK-0018）完了
- **後続**: Sub #20（TASK-0020: README + migration note）

---

## 次フェーズへの申し送り

- B: plan 生成（TASK-0018 完了後に着手）
- plan では agent 定義スキャン（固有前提抽出）タスクを先頭に含める
- C-1 セルフレビュー（full モードで 17項目チェック）
- C-2 外部AIレビュー（full モード必須）
- C-3 ゲート後に exec
