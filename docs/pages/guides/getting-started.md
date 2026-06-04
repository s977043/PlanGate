# はじめる（Getting Started）

> **Status**: Stable
> **Review cadence**: Monthly
> **Owner**: Product / Maintainer

## PlanGate とは

PlanGate は、AI コーディングエージェントをプロダクト開発に安全に組み込むためのゲート型ワークフローハーネスです。AI がいきなりコードを書くのではなく、まず計画と受入条件を作り、人間が承認してから実装へ進む `No approved plan, no code.` の原則を実現します。

詳しくは [Product Overview](../explanation/product/overview.md) を参照してください。

## 前提条件

- Claude Code または Codex CLI
- Git リポジトリ
- GitHub アカウント

## インストール

### Marketplace から（推奨）

**Claude Code セッション内:**

```text
/plugin marketplace add s977043/PlanGate
/plugin install plangate
```

**CLI から:**

```bash
# Claude Code
claude plugin marketplace add s977043/PlanGate
claude plugin install plangate

# Codex（marketplace 追加 + スキル展開）
codex plugin marketplace add s977043/PlanGate
sh ~/plangate/install.sh --codex
```

### ワンコマンド（clone して install.sh）

```bash
git clone https://github.com/s977043/plangate.git ~/plangate
cd path/to/your-project
sh ~/plangate/install.sh
```

詳細は [plugin/plangate/README.md](../../../plugin/plangate/README.md) を参照してください。

---

## 3ステップで始める（Phase 0 体験）

Phase 0 は「Day 1 で体験する」フェーズです。ultra-light モードで 1 タスクを最後まで完了し、PlanGate の基本的な流れを体感します。plan / C-1〜C-4 / V-1〜V-4 / エージェント / フック / metrics はすべて不要です。まず動かすことが目的です。

### ステップ 1: リポジトリに PlanGate を設定する

```bash
bin/plangate init <TASK-番号>
```

`init` コマンドは `docs/working/TASK-<番号>/` ディレクトリを作成し、作業コンテキスト管理の起点となるファイルを配置します。Phase 0 では `.claude/settings.json` の hooks 未配線でも問題ありません。

### ステップ 2: 最初のタスクを ultra-light で実行する

ultra-light モードは typo 修正・設定値変更・コメント修正など、影響範囲が最小のタスクに使います。

1. 変更したいファイルを直接編集する（plan.md は任意）
2. 変更をコミットする
3. `bin/plangate doctor` でハーネスの健全性を確認する

```bash
# doctor で現在の設定状態を確認する
bin/plangate doctor
```

Phase 0 では plan.md や C-1〜C-4 のゲートはスキップして構いません。成果物は変更そのものです。

### ステップ 3: plan → exec → PR の流れを確認する

ultra-light での体験後、次の流れが PlanGate の基本サイクルです。

```text
PBI INPUT → plan.md 生成 → C-3 人間承認 → exec（実装）→ PR → C-4 レビュー → Done
```

この流れを意識した上で、次のフェーズ（Phase 1: 計画導入）へ進むと、`pbi-input.md → plan.md` の生成を体験できます。

## 次のステップ

- **段階的導入ガイド**: [https://github.com/s977043/PlanGate/blob/main/docs/staged-adoption-guide.md](https://github.com/s977043/PlanGate/blob/main/docs/staged-adoption-guide.md) — Phase 0 〜 Phase 3 の成長パスと、各フェーズで使うコンポーネントの詳細
- **高品質な実行計画ができるまで**: [../explanation/product/plan-creation-process.md](../explanation/product/plan-creation-process.md) — PBI INPUT から C-3 承認まで、計画を生むプロセスの解説
- **Product Overview**: [../explanation/product/overview.md](../explanation/product/overview.md) — PlanGate の概要、対象ユーザー、価値、仕組み

## 関連ページ

- [Product Overview](../explanation/product/overview.md)
- [高品質な実行計画ができるまで](../explanation/product/plan-creation-process.md)
- [Demo Script](./product-demo-script.md)
- [Product FAQ](../reference/product-faq.md)
- [段階的導入ガイド（GitHub）](https://github.com/s977043/PlanGate/blob/main/docs/staged-adoption-guide.md)
