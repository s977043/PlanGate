# WF-04 Build & Refine

> PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ 実行層 / Phase 4/5

## 目的

設計に従って最小単位で実装し、差分ごとに整えた状態で次 phase に渡せるようにする。

## 入力

- WF-03 の artifact（design クラス）
- 実装対象の既存コード
- テスト観点（WF-03 で決定済）

## 完了条件

- 動作するコード差分が存在する
- 最低限の自己レビュー結果が一覧化されている
- 明示的な既知課題（妥協点・未着手項目）が一覧化されている
- 実装単位ごとのコミット履歴が記録されている

## 呼び出す Skill

- `scaffold-generate`
- `feature-implement`
- `local-review`
- `refactor-pass`

## 主担当 Agent

- `implementation-agent`

## 次 phase への引き継ぎ

- artifact クラス: **known-issues**（形式: `known-issues.md` 相当）+ コード差分
- 含まれる要素: 上記「完了条件」の 4 項目、特に「明示的な既知課題」
- 受け取り先: WF-05（`qa-reviewer`）
