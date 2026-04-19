# WF-02 Requirement Expansion

> PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ 実行層 / Phase 2/5

## 目的

曖昧な要求から仕様の抜け漏れを洗い出し、実装前に合意できる粒度の要件セットを整える。

## 入力

- WF-01 の artifact（context クラス）
- 初期要求（チケット本文、関係者コメント）
- 想定ユースケース / 想定エッジケース

## 完了条件

- 機能要件が一覧化されている
- 非機能要件（性能 / 保守性 / 安全性 / アクセシビリティ等）が一覧化されている
- 対象外（Out of scope）が明文化されている
- 例外条件・エラーパスが一覧化されている
- UX 期待値（主要導線の受け入れ基準）が明文化されている

## 呼び出す Skill

- `requirement-gap-scan`
- `nonfunctional-check`
- `edgecase-enumeration`
- `acceptance-criteria-build`

## 主担当 Agent

- `requirements-analyst`
- `qa-reviewer`

## 次 phase への引き継ぎ

- artifact クラス: **requirements**（形式: `requirements.md` 相当）
- 含まれる要素: 上記「完了条件」の 5 項目 + 受け入れ条件（AC）一覧
- 受け取り先: WF-03（`solution-architect`）
