# WF-03 Solution Design

> PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ 実行層 / Phase 3/5

## 目的

確定した仕様を、実装可能な構造（モジュール境界 / データフロー / 状態管理 / 失敗時挙動 / テスト観点）へ落とし、実装前の設計抜けを減らす。

## 入力

- WF-02 の artifact（requirements クラス）
- 既存アーキテクチャ図 / ADR（該当がある場合）
- 依存ライブラリ・フレームワークの制約

## 完了条件

- モジュール構成（境界と責務）が決定されている
- データフローが決定されている
- 状態管理方針が決定されている
- 失敗時の扱い（エラーパス / リトライ / フォールバック）が決定されている
- テスト観点（Unit / Integration / E2E の分担）が決定されている
- 依存ライブラリ制約・技術的妥協点が一覧化されている

## 呼び出す Skill

- `architecture-sketch`（Design カテゴリ）
- `risk-assessment`（Check カテゴリ）

## 主担当 Agent

- `solution-architect`
- `orchestrator`

## 次 phase への引き継ぎ

- artifact クラス: **design**（形式: `design.md`）
- 配置先: `docs/working/TASK-XXXX/design.md`（1 PBI につき 1 ファイル）
- テンプレート: `docs/working/templates/design.md`（7 要素構造）
- 含まれる要素: モジュール構成 / データフロー / 状態管理 / 失敗時扱い / テスト観点 / 依存制約 / 技術的妥協点
- 受け取り先: WF-04（`implementation-agent`）

## plan.md との役割分担

WF-03 で生成する `design.md` は、PlanGate 既存の `plan.md` と併存する:

| 観点 | plan.md | design.md |
| ----- | --------- | ----------- |
| 主目的 | やる順番・完了条件 | 実装構造の決定事項 |
| 出力者 | `spec-writer` / `workflow-conductor` | `solution-architect` |
| 変化頻度 | チケット毎 | チケット毎 + アーキ変更時 |
| 対象読者 | 実装者・レビュアー・PM | 実装者・アーキテクト |

PlanGate 既存フロー（A → B → C-1 〜 C-3 → D）における WF-03 の挿入位置は [`docs/workflows/plangate-insertion-map.md`](./plangate-insertion-map.md) を参照。
