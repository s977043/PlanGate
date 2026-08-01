# Product FAQ: PlanGate

> **Status**: Stable
> **Review cadence**: Monthly
> **Owner**: Product / Maintainer

## 基本理解

### Q. PlanGate は何ですか？

PlanGate は、AI コーディングエージェントをプロダクト開発に安全に組み込むためのゲート型ワークフローハーネスである。

AI が本番コードを書く前に、PBI、計画、TODO、受入条件、人間承認を必須化する。

> 詳細は [Product Overview](../explanation/product/overview.md) を参照。

### Q. 一言で言うと？

```text
No approved plan, no code.
```

AI がコードを書く前に、計画と受入条件を通す仕組みである。

### Q. Phase 0 では plan や C-3 をスキップできます。No approved plan, no code と矛盾しませんか？

矛盾しない。Phase 0 ultra-light は、PlanGate を初日に体験するための導入モードである。

標準の guarded flow では、AI が実装に入る前に plan / todo / test-cases と C-3 承認を通す。

Phase 0 は低リスク・学習目的の例外であり、チーム運用では Phase 1 以降で承認境界を段階的に強める。

### Q. 誰向けですか？

主な対象は、AI コーディングエージェントをチーム開発で使う以下の人たちである。

- PM
- PO
- EM
- CTO
- Developer
- Scrum team
- OSS adopter

## 価値に関する質問

### Q. AI の速度が落ちませんか？

短期的には、実装前に plan / test-cases / approval を通すため、即時実装より遅く見える。

しかし PlanGate の狙いは、初速だけを最大化することではない。

間違ったものを速く作るリスク、PR レビューでの手戻り、受入条件の後付け、スコープ逸脱を減らすことで、プロダクトデリバリー全体の速度と信頼性を上げる。

また、PlanGate は mode によって軽量化できる。

- ultra-light
- light
- standard
- high-risk
- critical

低リスクでは軽く、高リスクでは厳しくする。

> 詳細は [Before / After](../explanation/product/before-after.md) を参照。

### Q. AI に任せる意味が薄れませんか？

薄れない。

PlanGate は AI を止めるための仕組みではなく、AI が正しい範囲で速く動くための仕組みである。

AI が得意な実装、調査、検証、レビュー補助は活かしつつ、何を作るか、何を Done とするか、人間がどこで判断するかを固定する。

### Q. PM / PO が直接使うものですか？

直接操作しなくても価値がある。

PM / PO にとって重要なのは、AI が作業する前に PBI の意図、受入条件、Done の定義が確認可能になり、実装後に検証結果と handoff が残ることである。

Developer や EM が PlanGate を運用していても、PM / PO の責任範囲である価値、スコープ、受入条件が守られやすくなる。

## 競合・代替手段に関する質問

### Q. Cursor や Claude Code と競合しますか？

競合ではなく補完である。

Cursor、Claude Code、Codex CLI などは、AI エージェントが実際に作業する実行環境である。

PlanGate は、それらの上位で、PBI、計画、承認、検証、handoff を管理するワークフローハーネスである。

### Q. CI/CD で十分では？

十分ではない。

CI/CD は主に実装後の検証を扱う。

PlanGate は実装前に、何を作るか、どう作るか、何を満たせば Done かを固定する。

また ai-loop を使う場合は、PR 作成後の CI / review repair を `MERGE_READY` まで収束させる。CI の結果を見るだけではなく、失敗・レビュー指摘・修正反復を delivery state として扱う点が違う。

つまり PlanGate は、post-check だけでなく pre-implementation governance と post-PR delivery convergence を扱う。

### Q. ただのプロンプト集ですか？

違う。

PlanGate は prompt だけでなく、以下を含む。

- Gate
- Artifact
- Hook Enforcement
- Eval
- Metrics
- Model Profile
- Prompt Assembly
- Workflow DSL
- Handoff
- Delivery State Machine

PlanGate はプロンプトではなく、AI エージェントをチーム開発に組み込むための workflow harness である。

## 運用に関する質問

### Q. C-3 / C-4 とは何ですか？

C-3 は実装前の計画承認である。

AI が作った plan、todo、test-cases を人間が確認し、承認する。承認前は本番コードを書けない。

C-4 は実装後のレビュー承認である。

実装、検証結果、handoff を確認し、PR / merge に進めるか判断する。

### Q. ai-loop の C-3' は人間承認をなくすものですか？

完全になくすものではない。

C-3' は eligible run に限って AI 裁定で進める経路である。HO 接触（Hardening Override = AI 改変不可ファイル群への接触）、policy 変更、判定不能、重大な不一致がある場合は Human に escalate する。

また、C-4 / merge は Human-owned のままで、AI は merge しない。

### Q. MERGE_READY とは何ですか？

`MERGE_READY` は、ai-loop Delivery が PR 作成後の CI / review repair を完了したと判断する状態である。

AI の責務は `MERGE_READY` までであり、`MERGED` へ進める最終判断と merge は人間が行う。

### Q. 低リスクな修正でも重くなりませんか？

PlanGate は mode によって軽量化する。

小さな修正は ultra-light / light、高リスクな変更は high-risk / critical として扱う。

重要なのは、すべてを重くすることではなく、リスクに応じて承認と検証の深さを変えることである。

## 品質・測定に関する質問

### Q. PlanGate を入れると何が測れるようになりますか？

代表的には以下を測る。

- C-3 approval / conditional / reject
- C-4 approve / request changes
- V-1 first pass rate
- fix loop count
- MERGE_READY convergence rate（指標として定義済み。`bin/plangate metrics` による自動計測は未実装）
- hook violation rate
- Code Keep Rate
- Plan Keep Rate
- Acceptance Keep Rate
- Handoff usefulness

### Q. Keep Rate とは何ですか？

AI が作った成果物が、一定時間後も残っているかを見る指標である。

PlanGate では code だけでなく、plan、test-cases、handoff も対象にする。

## Short answers

| Question | Short answer |
| --- | --- |
| 何をするもの？ | AI がコードを書く前に計画と受入条件を通す |
| なぜ必要？ | 間違ったものを速く作るリスクを下げるため |
| 誰向け？ | AI coding agents を使うプロダクトチーム |
| 何が違う？ | 承認境界、監査可能性、Scrum-friendly delivery を重視する |
| 競合は？ | Cursor / Claude Code / Codex の代替ではなく補完 |
| Phase 0 は例外？ | 低リスク・学習目的の導入モードでは plan / C-3 を省略できる |
| ai-loop は何をする？ | PR 作成後の CI / review repair を `MERGE_READY` まで収束させる |
| 一番の価値は？ | PM / PO が守るべき価値、スコープ、Done を AI 開発でも守ること |

## 導入に関する質問

### Q. どこから始めればいいですか？

[はじめる（Getting Started）](../guides/getting-started.md) を参照してください。ultra-light モードで 1 タスクを完了する体験から始めるのが最短経路です。

段階的に導入を広げたい場合は [段階的導入ガイド](https://github.com/s977043/PlanGate/blob/main/docs/staged-adoption-guide.md) を参照してください。

### Q. 既存プロジェクトに追加できますか？

できます。既存コードへの変更は不要です。導入方法は 3 通り（最推奨は Marketplace）:

- **Marketplace（最推奨）**: `/plugin marketplace add s977043/PlanGate` → `/plugin install plangate`（Claude Code セッション内）。Codex は `codex plugin marketplace add s977043/PlanGate`。
- **ワンコマンド**: `git clone https://github.com/s977043/plangate.git ~/plangate` 後に `sh ~/plangate/install.sh`（`.claude/` と `.codex/` を自動検出）。
- **手動コピー**: `.claude/` をプロジェクトへコピー（補足手段）。

詳細は [はじめる §インストール](../guides/getting-started.md) を参照。Phase 0（ultra-light）から始め、習熟度に応じて段階的にモードを上げる運用を推奨します。

### Q. 依存関係・前提条件は何ですか？

- **Required**: git / POSIX sh（bash/zsh）/ python3（`install.sh`・metrics の前提）
- **Recommended**: Claude Code（plan 生成・exec の主導線）
- **Optional**: Codex CLI（exec 実装エージェント既定 / C-2・V-3 外部レビュー）、GitHub アカウント（PR ベースの C-4 ゲート）

PlanGate 自体は特定のプログラミング言語に依存しません。

### Q. チーム全員が PlanGate を理解する必要がありますか？

必須ではありません。最初は 1 人が PlanGate を使ってタスクを進め、C-3 / C-4 ゲートで他のメンバーがレビューする形でも機能します。

徐々に plan.md / test-cases.md の読み方をチームに共有していく運用が現実的です。

## 関連ページ

- [はじめる（Getting Started）](../guides/getting-started.md) — 実際に使い始める
- [Product Overview](../explanation/product/overview.md) — PlanGate の概要
- [高品質な実行計画ができるまで](../explanation/product/plan-creation-process.md) — 計画プロセスの詳細
- [Positioning](../explanation/product/positioning.md) — 競合・代替手段との差別化
