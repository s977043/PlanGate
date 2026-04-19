# Workflow 実行層（WF-01〜WF-05）

> PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ
>
> 親 PBI: [#22](https://github.com/s977043/plangate/issues/22) / `docs/working/TASK-0021/pbi-input.md`

## 位置づけ

PlanGate（統制の外殻）の内側で動作する **実行層（Execution Architecture）** の骨格。本ディレクトリは「何をどの順番で / 各 phase の完了条件は何か」だけを定義する（**Rule 1**: Workflow は順序と完了条件だけ）。具体的な観点・手順は Skill / Agent / CLAUDE.md に委譲される。

## 目次（5 phase）

| Phase | 目的 | ファイル |
| --- | --- | --- |
| **WF-01** Context Bootstrap | 前提・制約・品質基準を読み込む | [`01_context_bootstrap.md`](./01_context_bootstrap.md) |
| **WF-02** Requirement Expansion | 曖昧な要求から仕様の抜け漏れを洗い出す | [`02_requirement_expansion.md`](./02_requirement_expansion.md) |
| **WF-03** Solution Design | 仕様を実装可能な構造へ落とす | [`03_solution_design.md`](./03_solution_design.md) |
| **WF-04** Build & Refine | 設計に従って最小単位で実装 | [`04_build_and_refine.md`](./04_build_and_refine.md) |
| **WF-05** Verify & Handoff | 品質確認し、次フェーズへ渡せる状態にする | [`05_verify_and_handoff.md`](./05_verify_and_handoff.md) |

## Artifact クラス（Phase 間受け渡し）

各 phase は以下のクラス名の artifact を生成し、次 phase に渡す（テンプレート本文は後続サブ issue で確定）。

| From → To | artifact クラス | 主要内容 |
| --- | --- | --- |
| WF-01 → WF-02 | **context** | 対象範囲 / 使用技術 / 禁止事項 / 成果物定義 |
| WF-02 → WF-03 | **requirements** | 機能 / 非機能 / 対象外 / 例外 / UX期待値 / AC |
| WF-03 → WF-04 | **design** | モジュール構成 / データフロー / 状態管理 / 失敗時扱い / テスト観点 / 依存制約 |
| WF-04 → WF-05 | **known-issues**（+ コード差分） | 動作コード / 自己レビュー / 妥協点 / コミット履歴 |
| WF-05 → 呼び出し元 | **handoff** | 要件適合 / 既知課題 / V2候補 / 妥協点 / 引き継ぎ文書 |

## 実行シーケンス（標準）

```text
1. orchestrator          が WF-01 を開始
2. requirements-analyst  が WF-02（requirement-gap-scan）で仕様拡張
3. qa-reviewer           が WF-02（edgecase-enumeration / acceptance-criteria-build）で締める
4. solution-architect    が WF-03 で実装構造化
5. implementation-agent  が WF-04 で実装
6. qa-reviewer           が WF-05 で要件照合
7. orchestrator          が WF-05 handoff を出す
```

## PlanGate 既存フェーズとの対応表

本 Workflow は PlanGate の **実行層**。PlanGate の**統制層**（人間ゲート / 承認 / 状態保存）は別レイヤーとして両立する。

| PlanGate フェーズ | レイヤー | 主担当 | 対応する WF / ゲート |
| --- | --- | --- | --- |
| **A**: PBI INPUT PACKAGE 作成 | 統制 / 人間 | 人間 | WF-01 / WF-02 への入力提供 |
| **B**: Plan + ToDo + TestCases 生成 | 統制 / AI | `workflow-conductor` 経由（内部で `spec-writer` が生成） | WF-01〜WF-03 を横断する計画策定 |
| **C-1**: セルフレビュー（17項目） | 統制 / AI | 主エージェント | 計画品質ゲート（WF 外） |
| **C-2**: 外部AIレビュー | 統制 / AI | 外部 AI（Codex 等） | 計画独立検証ゲート（WF 外） |
| **C-3**: 人間レビュー（三値） | 統制 / 人間 | 人間 | 計画承認ゲート（WF 外） |
| **D**: Agent実行（TDD） | 実行 / AI | `implementation-agent` | **WF-04 Build & Refine** |
| **L-0**: リンター自動修正 | 実行 / AI | `linter-fixer` | WF-04 内の品質制御 |
| **V-1**: 受け入れ検査 | 実行 / AI | `acceptance-tester` | **WF-05 Verify**（受け入れ確認部分） |
| **V-2**: コード最適化 | 実行 / AI | `code-optimizer` | WF-04 延長 / WF-05 入口（full/critical のみ） |
| **V-3**: 外部モデルレビュー | 実行 / AI | 外部 AI | WF-05 内の独立検証 |
| **V-4**: リリース前チェック | 実行 / AI | `release-manager` | **WF-05 Handoff 前**の最終ゲート（critical のみ） |
| **PR 作成** | 統制 / AI | `workflow-conductor` が制御 | WF-05 の handoff を GitHub PR として発行 |
| **C-4**: 人間レビュー（PR） | 統制 / 人間 | 人間 | 実装承認ゲート（WF 外） |

**読み方**:

- **統制層**（PlanGate）: A / B / C-1 / C-2 / C-3 / PR作成 / C-4 — 「止める・承認する・状態を保存する」役割
- **実行層**（Workflow）: D / L-0 / V-1 / V-2 / V-3 / V-4 — 「柔軟で拡張可能な実行基盤」の中身を WF-01〜WF-05 で構造化

## Rule 1 の適用

- 本 phase 定義には **実装ノウハウを書かない**（手順・How to・Steps・具体的な書き方）
- 完了条件は **状態形式**（「〜が明文化されている」「〜が決定されている」）で記述する
- 動作形式（「〜を明文化する」「〜を実施する」）は手順であり、Workflow には書かない
- 実装ノウハウは Skill / Agent / CLAUDE.md に委譲する

## 関連

- 親 PBI: `docs/working/TASK-0021/pbi-input.md`
- 本 TASK 実行記録: `docs/working/TASK-0022/`
- PlanGate 本体: `docs/plangate.md` / `docs/plangate-v6-roadmap.md`
- モード分類: `.claude/rules/mode-classification.md`
- レビュー原則: `.claude/rules/review-principles.md`
