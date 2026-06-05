# Why PlanGate

> **Status**: Stable
> **Review cadence**: Monthly
> **Owner**: Product / Maintainer
> **これは何**: PlanGate 導入検討者が最初に読む 1 ページ。3 分で「自分に必要か」を判断し、5 分で導入を始められるように構成しています。

## 承認なし、コードなし。AI 時代の Backlog Governance

PlanGate は、AI コーディングエージェントを **承認境界・監査可能性・スクラム親和性** を保ったままプロダクト開発へ接続するためのゲート型ハーネスです。

AI がいきなり本番コードを書くのではなく、まず **何を作るか / Done は何か** を成果物として固定し、人間が承認してから実装へ進みます。

```text
No approved plan, no code.
```

PlanGate は AI ツールの代替ではありません。Claude Code / Codex などの実行エージェントの **上位に乗せる補完レイヤー** として、速度を落とさずに統制を取り戻します。

---

## こんな課題、ありませんか

AI 開発で次のいずれかに心当たりがあれば、PlanGate が効きます。

- AI が「良かれと思って」スコープ外まで先回りし、**間違ったものを速く作ってしまう**
- 全ステップを監視するのは重い。かといって **フル自律は怖い**。中間がない
- レビューしたいのに、AI の作業が **会話ログにしか残らず**、後から説明できない
- OSS は入れてみたが **「どこまで使えばいいか」が不明** で定着しない
- 複数の AI ツールを併用していて、**特定 SaaS にロックインされたくない**

---

## PlanGate が固定する 3 つの価値

| 価値 | 何が起きるか | 主に効く人 |
| --- | --- | --- |
| **間違ったものを速く作るリスクを止める** | AI は C-3 承認前に本番コードを書けない。何を作るか・Done は何かを実装前に成果物として固定し、AI の先回りをワークフローで抑える | PM / PO / EM |
| **承認境界を 2 ゲートに集約** | 人間判断を C-3（実装前の計画承認）と C-4（PR 最終レビュー）の 2 点に集約。APPROVE / CONDITIONAL / REJECT の三値で残す。過剰監視でもフル自律でもない中間設計 | EM / CTO / Tech Lead |
| **会話ログでなく成果物で監査できる** | plan / review / verification / handoff を `docs/working/` に残す。承認後の plan 改変は plan_hash、scope 外編集は forbidden_files を hook（12/12 実装済）で機械検知 | CTO / 監査・規制対応チーム |

さらに、

- **段階的に採用できる**: Phase 0（ultra-light で 1 タスク体験）から Phase 3（フル運用）まで、必要な分だけ。「全部使わないと意味がない」を避ける設計。
- **ロックインなし**: 成果物は全て Markdown で provider 非依存。Claude Code / Codex 両対応、SaaS 前提なし。

> **損益分岐点の目安**: 3 人以上 & 3 ヶ月以上続くプロジェクトで効果が出ます。単発の使い捨てスクリプトには過剰です。

---

## 自律エージェントフレームワークとの違い

| 観点 | 自律エージェントフレームワーク | PlanGate |
| --- | --- | --- |
| 最適化する対象 | 自律性・速度・タスク完遂 | 承認境界・監査可能性・スクラム親和性 |
| 人間の関与 | 最小化する | C-3 / C-4 の 2 点に**集約して固定**する |
| AI ツールとの関係 | それ自体が実行主体 | 実行エージェントの**上位ハーネス**（代替ではなく接続） |
| 成果物 | 主にコード | plan / review / verification / handoff（全て Markdown） |

PlanGate は「AI をどれだけ自由に走らせるか」ではなく、**「どこで人間が止め、何を証跡として残すか」** を設計するためのレイヤーです。

---

## 3 ステップで始める

導入は実質 3 コマンドです。

### 1. Marketplace から導入

**Claude Code セッション内:**

```text
/plugin marketplace add s977043/PlanGate
/plugin install plangate
```

**CLI から（Claude Code / Codex 両対応, v8.11.0〜）:**

```bash
# Claude Code
claude plugin marketplace add s977043/PlanGate
claude plugin install plangate

# Codex（marketplace 登録 → スキル展開）
codex plugin marketplace add s977043/PlanGate
sh install.sh --codex
```

### 2. hook 強制を配線（必須）

承認境界の保護（plan_hash / forbidden_files）は hook で機械強制されます。**これを配線しないと保護が無効** です。

```bash
bin/plangate doctor --fix
# 事前に差分を確認したい場合
bin/plangate doctor --fix --dry-run
# CI など非対話環境
bin/plangate doctor --fix --yes
```

### 3. Phase 0 を体験 — ultra-light で 1 タスク完了

```bash
bin/plangate init <TASK-番号>   # 例: bin/plangate init TASK-0001
# 対象ファイルを直接編集してコミット
bin/plangate doctor             # ハーネスの健全性を確認
```

ultra-light モードでは計画フェーズを省略し、**1 タスクを最後まで通す体験** に集中できます。

---

## 段階的に広げる

最初から全部使う必要はありません。チーム合意の上で、フェーズ境界ごとに強度を上げていきます。

| Phase | やること | ゲート強度 |
| --- | --- | --- |
| **Phase 0** | ultra-light で 1 タスクを最後まで完了。ツールに慣れる | hook 配線のみ |
| **Phase 1** | 計画を書く習慣をつける。`PBI INPUT → plan.md → C-3 承認 → exec → PR → C-4` を light モードで運用 | C-3 / C-4（warning） |
| **Phase 2-3** | EH-1〜EH-7 を warning→block へ昇格 + EH-9、standard 以上で V-3 外部レビュー必須化 | フル運用（block） |

### 成功イメージ

- **導入 1 週間後**: AI が承認前にコードを書かなくなり、「何を作るか」が plan.md として毎回残る。レビューが会話ログ追跡から成果物確認に変わる。
- **導入 1 ヶ月後**: C-3 / C-4 の 2 ゲートがチームの標準リズムになり、承認後の改ざん・scope 外編集が hook で自動検知される。AI 作業の成功・失敗を後から説明できる状態が定着する。

> Phase の詳細・各コンポーネントの昇格手順は [段階的導入ガイド][staged-adoption] を参照してください。

---

## 次に読むもの

| ドキュメント | 内容 |
| --- | --- |
| [はじめる（Getting Started）](../../guides/getting-started.md) | 3 ステップで基本的な流れを手を動かして体験する |
| [段階的導入ガイド][staged-adoption] | Phase 0 〜 Phase 3 の成長パスと各フェーズで使うコンポーネント |
| [Product FAQ](../../reference/product-faq.md) | 導入検討時の FAQ / 反論処理 |
| [Product Overview](./overview.md) | 概要、対象ユーザー、価値、仕組み |
| [Positioning](./positioning.md) | 競合・代替手段との差別化 |

[staged-adoption]: ../../../staged-adoption-guide.md
