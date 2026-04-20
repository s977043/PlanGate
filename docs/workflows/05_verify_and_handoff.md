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

- `acceptance-review`（Review カテゴリ）
- `known-issues-log`（Review カテゴリ）

## 主担当 Agent

- `qa-reviewer`
- `orchestrator`

## 次 phase への引き継ぎ

- artifact クラス: **handoff**（形式: `docs/working/TASK-XXXX/handoff.md` 固定 / 1 PBI につき 1 ファイル）
- 必須 6 要素（`docs/working/templates/handoff.md` 参照）:
  1. 要件適合確認結果
  2. 既知課題一覧
  3. V2 候補
  4. 妥協点
  5. 引き継ぎ文書
  6. テスト結果サマリ
- 受け取り先: 本 Workflow の呼び出し元（PlanGate 統制層 / 次スプリント / 別チーム）

## 既存 PlanGate 資産との役割分担

| artifact | 役割 | 更新タイミング |
| --- | --- | --- |
| `status.md` | フェーズ履歴・完了記録のアーカイブ | フェーズ遷移・セッション終了時 |
| `current-state.md` | 今どこにいて、次に何をするか（スナップショット） | タスク完了ごとに上書き |
| **`handoff.md`（新設）** | 完了時の**引き継ぎパッケージ**（次の担当者・次スプリントへ） | WF-05 完了時に 1 回生成 |

status.md / current-state.md は**進行中の情報管理**、handoff.md は**完了後の資産発行**。役割が異なる。

## V-1 受け入れ検査との関係

| 観点 | V-1（PlanGate 実装ゲート） | handoff（WF-05 完了資産） |
| --- | --- | --- |
| 目的 | 実装が受入基準を機械的に満たすかを判定 | 次の担当者が作業を継続・引き継ぐために必要な情報を発行 |
| タイミング | 実装直後（WF-04 末尾 / WF-05 入口） | WF-05 完了時 |
| 形式 | 突合結果（PASS / FAIL / WARN） | 6 要素の統合パッケージ |
| 責任 | `acceptance-tester` or `qa-reviewer` | `qa-reviewer` + `orchestrator`（統合発行） |

V-1 は**ゲート**（通過/拒否）、handoff は**資産**（次フェーズへの引き継ぎ）。V-1 の結果は handoff の「要件適合確認結果」に統合される。

## handoff 必須化の原則（Rule 5）

親 PBI で合意された **Rule 5**: 「最終成果物は毎回 handoff に集約する。仕様 / 既知課題 / V2 候補 / 確認結果を残す。」

全 PBI（mode 問わず）で handoff.md を**必須出力**とする。詳細は `.claude/rules/working-context.md` の「handoff」節を参照。
