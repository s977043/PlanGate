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

- `architecture-sketch`
- `domain-modeling`
- `risk-assessment`
- `implementation-plan`

## 主担当 Agent

- `solution-architect`
- `orchestrator`

## 次 phase への引き継ぎ

- artifact クラス: **design**（形式: `design.md` 相当）
- 含まれる要素: 上記「完了条件」の 6 項目
- 受け取り先: WF-04（`implementation-agent`）
