# WF-05 Verify & Handoff

> PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ 実行層 / Phase 5/5

## 目的

品質確認を行い、次の担当者・次フェーズ・次スプリントへ渡せる handoff パッケージを完成させる。

## 入力

- WF-04 の artifact（known-issues クラス）+ コード差分
- WF-02 の artifact（requirements クラス）
- テスト実行結果 / CI 結果

## 完了条件

- 要件適合確認結果が一覧化されている
- 既知課題一覧が最終化されている
- V2 候補（今回の scope 外と確認された項目）が一覧化されている
- 妥協点（選ばなかった選択肢と理由）が明文化されている
- 引き継ぎ文書が handoff パッケージとして統合されている

## 呼び出す Skill

- `acceptance-review`
- `test-matrix-check`
- `known-issues-log`
- `handoff-package`

## 主担当 Agent

- `qa-reviewer`
- `orchestrator`

## 次 phase への引き継ぎ

- artifact クラス: **handoff**（形式: `handoff.md` 相当）
- 含まれる要素: 上記「完了条件」の 5 項目を統合した handoff パッケージ
- 受け取り先: 本 Workflow の呼び出し元（PlanGate 統制層 / 次スプリント / 別チーム）
