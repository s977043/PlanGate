# PlanGate Documentation

PlanGate は、AI コーディングエージェントをプロダクト開発に安全に組み込むためのゲート型ワークフローハーネスである。

AI がいきなりコードを書くのではなく、まず PBI を読み、計画、TODO、受入条件を作り、人間が承認してから実装へ進む。

```text
No approved plan, no code.
```

## はじめに読むもの

| ドキュメント | 内容 |
| --- | --- |
| [Product Overview](./explanation/product/overview.md) | PlanGate の概要、対象ユーザー、価値、仕組み |
| [PM / PO Elevator Pitch](./explanation/product/pm-po-elevator-pitch.md) | PM / PO 向けの短い説明、タグライン、月次見直し観点 |
| [Before / After](./explanation/product/before-after.md) | PlanGate 導入前後で何が変わるか |
| [Positioning](./explanation/product/positioning.md) | 競合・代替手段との差別化、ポジショニング |
| [Product FAQ](./reference/product-faq.md) | 導入検討時の FAQ / 反論処理 |
| [Demo Script](./guides/product-demo-script.md) | 5分 / 15分のデモ手順 |
| [Value Proposition Canvas](./explanation/product/value-proposition-canvas.md) | Customer Jobs / Pains / Gains の整理 |
| [Documentation Management](./guides/governance/documentation-management.md) | River-Reviewerを参考にしたドキュメント管理方針 |

## ドキュメント配置方針

PlanGate の公開説明ドキュメントは River-Reviewer を参考に `pages/` 配下で管理する。

- `pages/explanation/`: 背景、思想、プロダクト説明、ポジショニング
- `pages/guides/`: 操作手順、導入手順、デモ手順、運用ガイド
- `pages/reference/`: FAQ、仕様、スキーマ、用語集
- `docs/`: 開発者向け runbook、内部運用、作業ログ、移行メモ

## Main message

PlanGate は、AI が速くコードを書く時代に、PM / PO が守るべき「何を作るか」「なぜ作るか」「Done とは何か」を失わないためのゲート型ハーネスである。

AI は実装前に計画と受入条件を出し、人間が承認してからコードを書く。実装後は検証と handoff を残す。

だから PlanGate は、AI 開発を単なる自動化ではなく、プロダクト価値に接続された開発プロセスに変える。
