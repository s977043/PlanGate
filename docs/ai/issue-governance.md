# Issue / Label / Milestone Governance

> **Status**: v1
> **Review cadence**: Monthly
> **Owner**: Governance / Maintainer
> **Related**: [EPIC #193](https://github.com/s977043/plangate/issues/193) / [pages/guides/governance/documentation-management.md](../../pages/guides/governance/documentation-management.md)

## 1. 目的

PlanGate の Issue 運用 (Issue 必須セクション / Label taxonomy / Milestone mapping) を正本化する。

ドキュメント配置・更新ルールは [`pages/guides/governance/documentation-management.md`](../../pages/guides/governance/documentation-management.md) が正本。本ドキュメントは **Issue / Label / Milestone 側** を扱う。

## 2. Issue required sections

すべての PlanGate roadmap issue は以下のセクションを持つ。

| Section | Purpose |
|---------|---------|
| **Why** | この Issue が必要な背景・問題・コスト |
| **What** | scope / out-of-scope / suggested files / suggested outputs |
| **Acceptance Criteria** | チェック可能な完了条件（チェックボックス箇条書き）|
| **Non-goals** | 明示的にやらないこと、誤解防止 |
| **Labels** | 付与するラベル一覧 |
| **Milestone** | 紐付ける milestone |
| **Parent EPIC / Roadmap** | 親 EPIC / ロードマップ doc / 関連 PR の引用 |

軽微な bug / typo は `bug_report.yml` / `feature_request.yml` テンプレートで OK。Roadmap PBI は `plangate-roadmap-task.yml` を使う。

## 3. Label taxonomy

PlanGate ラベルは 4 軸で分類する。複数軸を組み合わせて付与する。

### 3.1 kind（必須、1 件のみ）

| Label | 用途 |
|-------|-----|
| `enhancement` | 新規機能追加・改善 |
| `bug` | 不具合修正 |
| `documentation` | ドキュメント変更が主体 |
| `governance` | 運用ルール・ガバナンス変更 |
| `refactor` | 振る舞いを変えないリファクタリング |
| `security` | セキュリティ関連 |

### 3.2 area（任意、複数可）

| Label | 用途 |
|-------|-----|
| `area:cli` | bin/plangate 関連 |
| `area:hooks` | scripts/hooks/ 関連 |
| `area:eval` | eval-runner / eval-cases 関連 |
| `area:schema` | schemas/ 関連 |
| `area:workflow` | docs/workflows/ 関連 |
| `area:metrics` | metrics 関連 |
| `area:docs` | 公開 docs / pages 関連 |

### 3.3 priority（必須、1 件のみ）

| Label | 用途 |
|-------|-----|
| `priority:P0` | 直近 milestone の必須項目 |
| `priority:P1` | 次 milestone 候補 |
| `priority:P2` | 中期計画 |
| `priority:P3` | 着手未定 |

### 3.4 status（任意、状態遷移で更新）

| Label | 用途 |
|-------|-----|
| `status:blocked` | 他 Issue / 外部要因で着手不可 |
| `status:in-progress` | 着手中 |
| `status:needs-review` | レビュー待ち |
| `status:wontfix` | 対応しない判断 |

> **note**: 既存 Issue にこれらのラベルが未付与でも、新規 Issue 作成時から徹底する。一括 backfill は scope 外（Non-goals）。

## 4. Milestone mapping

### 4.1 命名規則

`vMAJOR.MINOR.PATCH` の semver。次期予定 milestone は EPIC で先に作成する。

### 4.2 紐付けルール

- **EPIC**: 紐付ける PBI 群と同じ milestone を持たせる（or なし）
- **PBI**: 必ず 1 件の milestone を持つ
- **bug / hotfix**: 該当する直近 milestone を付与
- **推測禁止**: GitHub に該当 milestone が存在しない場合、先に作成する。番号を推測して紐付けてはならない（[EPIC #193 policy](https://github.com/s977043/plangate/issues/193) を踏襲）

### 4.3 milestone 移動

milestone をまたいで移動する場合（次期へ繰越など）は、Issue コメントに **理由 + 移動日** を残す。

## 5. Roadmap issue creation checklist

新しい roadmap PBI を作成するときに通すチェックリスト。

```text
- [ ] Title が `PBI-HI-NNN: <短い説明>` などロードマップ規約に沿っている
- [ ] Why / What / Acceptance Criteria / Non-goals が揃っている
- [ ] Suggested files / outputs が記載されている
- [ ] Parent EPIC / Roadmap doc / Related PR が冒頭で引用されている
- [ ] Labels (kind + priority、必要なら area) が付与されている
- [ ] Milestone が EPIC の表に従って付与されている
- [ ] 該当 milestone が GitHub 上に存在する（なければ先に作成）
- [ ] Acceptance Criteria は AI / human が機械的に検証できる粒度になっている
- [ ] EPIC の child policy / scope と矛盾していない
- [ ] documentation-management.md の Directory policy と矛盾していない
```

## 6. Issue template policy

GitHub Issue テンプレートは `.github/ISSUE_TEMPLATE/` 配下に置く。

| Template | 用途 |
|----------|-----|
| `bug_report.yml` | バグ報告 |
| `feature_request.yml` | 軽量な機能要望 |
| `plangate-roadmap-task.yml` | EPIC #193 等の roadmap PBI |
| `config.yml` | テンプレート選択画面の設定 |

`plangate-roadmap-task.yml` は Section 2 / 5 を強制するために事前にスキャフォールドを提供する（Why / What / AC / Non-goals / Labels / Milestone を必須入力）。

## 7. EPIC governance

EPIC issue は以下を満たす。

- 親 EPIC 自身に milestone を付ける（最終リリース予定の milestone でもよい）
- Roadmap to milestones 表で「Issue ↔ Milestone ↔ Priority」を一覧化する
- Milestone policy を本文中で明記し、不在時の作成順序を指示する
- 子 PBI 作成後、EPIC 本体の表を最新化する

## 8. 既存 Issue への適用

このガバナンスは新規 Issue 作成時から適用する。既存 Issue について：

- **milestone 不整合**は気付き次第訂正する（今回 #194〜#204 一括訂正がその例）
- **label 不足**は次回更新ついでに backfill。一括対応は scope 外
- **必須セクション欠落**は再ファイリング不要、引き続き運用する

## 9. PR と Issue の連動

- 1 PBI = 1 PR が原則。複数 PR に分割する場合は EPIC 側で分割理由を残す
- PR 本文で `closes #N` / `fixes #N` / `resolves #N` のいずれかを書く（自動 close 対象）
- doc-only PR は `documentation` ラベルを付ければ issue-link チェックを skip 可能（PR `<!-- skip-issue-link-check -->` でも可）

## 10. Non-goals

- すべての既存 Issue を一括で本ガバナンスへ整合させること
- GitHub Projects / 自動ラベリング bot の導入
- release automation の実装
- 全 PR への必須 reviewer 強制

## 11. 関連

- [EPIC #193 Harness Improvement Roadmap](https://github.com/s977043/plangate/issues/193)
- [pages/guides/governance/documentation-management.md](../../pages/guides/governance/documentation-management.md)（Doc 配置 / 更新ルール正本）
- [.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml](../../.github/ISSUE_TEMPLATE/plangate-roadmap-task.yml)
- [docs/ai/metrics-privacy.md](./metrics-privacy.md) — Metrics v1 (#195) の privacy policy（v8.6.0 governance trio の一角）
- [docs/ai/metrics.md](./metrics.md) — Metrics v1 運用 guide
- [docs/ai/eval-baselines/2026-05-04-baseline.md](./eval-baselines/2026-05-04-baseline.md) — v8.6.0 比較起点 baseline
