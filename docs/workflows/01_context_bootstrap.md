# WF-01 Context Bootstrap

> PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ 実行層 / Phase 1/5

## 目的

案件の前提・制約・品質基準を読み込み、後続 phase が迷わず進められる共通コンテキストを確立する。

## 入力

- プロジェクトの `CLAUDE.md`
- 既存コード（関連範囲）
- チケット / 依頼文（URL、添付資料を含む）
- 技術制約・ライセンス・セキュリティ要件

## 完了条件

- 対象範囲が明文化されている
- 使用可能な技術スタック / 既存ライブラリの制約が一覧化されている
- 禁止事項（スコープ外 / 触ってはいけないファイル / 承認の必要な操作）が一覧化されている
- 成果物定義（Definition of Done の骨子）が明文化されている

## 呼び出す Skill

- `context-load`
- `constraint-extract`
- `definition-of-done`

## 主担当 Agent

- `orchestrator`
- `requirements-analyst`

## 次 phase への引き継ぎ

- artifact クラス: **context**（形式: `context.md` 相当）
- 含まれる要素: 上記「完了条件」の 4 項目
- 受け取り先: WF-02（`requirements-analyst` / `qa-reviewer`）
