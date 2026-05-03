# PlanGate

PlanGate は、AI コーディングエージェントをプロダクション開発で扱うためのゲート型ワークフローです。

「計画を承認しないと AI は 1 行もコードを書けない」という関所モデルを中核に、PBI から計画、承認、実装、検証、handoff までを構造化します。

![Harness Engineering と PlanGate の関係](assets/harness-plangate-readme-dark-v2.png)

## はじめに読むもの

| ドキュメント | 内容 |
| --- | --- |
| [公開ドキュメント入口](../pages/index.md) | River-Reviewer 形式に寄せた `pages/` 配下の公開説明ドキュメント |
| [Product Overview](../pages/explanation/product/overview.md) | PlanGate の概要、対象ユーザー、価値、仕組み |
| [PM / PO Elevator Pitch](../pages/explanation/product/pm-po-elevator-pitch.md) | PM / PO に PlanGate を説明するための短いピッチ、タグライン、定期見直し観点 |
| [思想と問題設定](./philosophy.md) | PlanGate が向き合う課題、ハーネスエンジニアリングとの関係 |
| [PlanGate ガイド](./plangate.md) | 全体像、フェーズ、運用手順 |
| [v7 ハイブリッドアーキテクチャ](./plangate-v7-hybrid.md) | Governance × Modularity、Workflow / Skill / Agent 3 層 |
| [Orchestrator Mode 仕様](./orchestrator-mode.md) | 親 PBI 分解 / 子 PBI 並行実行 / 統合ゲートの仕様（v1, Spec only） |
| [Workflow 定義](./workflows/README.md) | WF-01〜WF-05 + Orchestrator Decomposition / Integration |
| [Harness Improvement Roadmap](./ai/harness-improvement-roadmap.md) | モデル差分・実利用データ・評価結果を使って PlanGate ハーネスを継続改善するロードマップ |
| [plugin 移行ガイド](./plangate-plugin-migration.md) | Claude Code plugin として使う場合の導入・移行 |
| [OSS Governance](./oss-governance.md) | OSS 公開設定・運用判断 |

## PlanGate の位置づけ

PlanGate は、一般的なハーネスエンジニアリングの考え方を PBI 単位の開発運用に落とし込むための仕組みです。

- Harness Engineering: AI を安全に動かす外側の仕組みを設計する
- PlanGate: 計画、承認ゲート、検証、handoff を PBI 単位で固定する
- Workflow / Runtime: レビュー、ログ、再試行、役割分担を実行層として組み込む

## 中核アイデア

| アイデア | 内容 |
| --- | --- |
| 計画先行 | 実装前に plan / todo / test-cases を作り、承認前の実装を止める |
| ゲート制御 | C-3 と C-4 で人間の判断点を固定する |
| 検証内蔵 | L-0 / V-1〜V-4 により、検証をワークフローに含める |
| 状態の永続化 | チケット単位で計画、レビュー、検証、handoff を残す |
| 実行層の分離 | Workflow / Skill / Agent を分け、再利用性と拡張性を高める |

## ドキュメント配置について

公開説明ドキュメントは River-Reviewer を参考に `pages/` 配下へ移動しました。

`docs/` は開発者向け runbook、内部運用、workflow 定義、作業ログを中心に扱います。

`docs/working/` 配下にはチケット単位の作業コンテキストやレビュー記録が含まれるため、公開サイトの主要導線には含めません。
