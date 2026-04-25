# サブエージェントロール定義（正本）

> マルチエージェント実行における各ロールの責務・入力・出力を定義する。
> ロール境界を明確にすることで、エージェント間の情報汚染と責務の重複を防ぐ。

## 目的

各エージェントが「何をするか」「何をしないか」を明確にする。
ロールを超えた判断・変更は禁止し、越権が起きた場合は直ちにエスカレーションする。

## 6 ロール定義

| ロール | 責務 | 主な入力 | 主な出力 |
|--------|------|---------|---------|
| **planner** | タスク分解・依存関係グラフ生成・work breakdown | `pbi-input.md`, `design.md` | `plan.md`, `todo.md`, Allowed Context |
| **implementer** | Allowed Context の範囲内でコード実装（TDD） | Allowed Context, `test-cases.md` | 実装コード, EvidenceItem |
| **reviewer** | 仕様準拠・コード品質・破壊的変更チェック（6 観点） | 実装コード, `pbi-input.md` | Review Gate レポート（severity 付き finding） |
| **security-reviewer** | セキュリティ観点専任レビュー（OWASP 準拠） | 実装コード, API 仕様 | セキュリティ finding（severity 付き） |
| **test-reviewer** | テストカバレッジ・エッジケース・パターン準拠チェック | テストコード, `test-cases.md` | テスト品質レポート |
| **documentation-reviewer** | ドキュメント整合性・命名・説明の正確性チェック | Markdown ファイル, `SKILL.md` 類 | ドキュメント品質レポート |

## ロール別の禁止事項

| ロール | 禁止事項 |
|--------|---------|
| planner | コードを書かない。実装の詳細に踏み込まない |
| implementer | Allowed Context 外のファイルを変更しない。設計決定をしない |
| reviewer | コードを書かない。実装に介入しない |
| security-reviewer | コード品質・パフォーマンスには介入しない（セキュリティ専任） |
| test-reviewer | 機能実装には介入しない（テスト品質専任） |
| documentation-reviewer | コード・テストには介入しない（文書専任） |

## 並列実行可能なロールの組み合わせ

| パターン | 理由 |
|--------|------|
| `reviewer` + `security-reviewer` + `test-reviewer` | 全て同じ実装を入力として受け取る → 依存なし → 並列可 |
| `implementer` 複数 | Allowed Context が重複しない場合 → 並列可 |
| `planner` → `implementer` | planner の出力が implementer の入力 → 依存あり → 逐次 |
| `implementer` → `reviewer` | implementer の完了を待つ → 逐次 |

## Mode 別ロール適用

| Mode | 最小ロール構成 |
|------|-------------|
| ultra-light | planner なし、implementer のみ（直接実装） |
| light | implementer + reviewer |
| standard | planner + implementer + reviewer |
| high-risk | planner + implementer + reviewer + security-reviewer |
| critical | planner + implementer + reviewer + security-reviewer + test-reviewer + documentation-reviewer |

## エスカレーション条件

以下が発生した場合、実行を停止してオーケストレーターに報告する。

- implementer が Allowed Context 外のファイルを変更しようとした
- reviewer が実装コードの修正を提案した（報告にとどめ、変更しない）
- 複数の implementer が同一ファイルを変更しようとした（競合リスク）
- ロール境界が曖昧なタスクを割り当てられた

## 関連

- Skill: `context-packager`（各ロールへの Allowed Context 生成）
- Skill: `subagent-dispatch`（ロール別タスク分配）
- Rule: `completion-gate.md`（全ロールの完了を Completion Gate で統合）
- Rule: `review-gate.md`（reviewer ロールの判定基準）
