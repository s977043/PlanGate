# Documentation Management

> **Status**: v0
> **Review cadence**: Monthly
> **Reference**: River-Reviewer documentation structure

## 1. 目的

PlanGate のドキュメント管理方針と更新ルールを定義する。

Kiro 前提の配置ではなく、River-Reviewer を参考に、公開説明ドキュメントは `pages/`、開発・運用ドキュメントは `docs/` に分ける。

このドキュメントは、次の判断を揃えるための正本である。

- どのドキュメントをどこに置くか
- いつドキュメントを更新するか
- 誰がレビューするか
- PR で何を確認するか
- 古い情報をどう扱うか
- 定期見直しで何を確認するか

## 2. Directory policy

| Directory | Role |
| --- | --- |
| `pages/` | 公開サイト・外部説明・プロダクト説明・ガイド・リファレンス |
| `pages/explanation/` | 背景、思想、設計意図、プロダクト説明 |
| `pages/guides/` | 導入手順、運用手順、デモ手順、ドキュメント管理方針 |
| `pages/reference/` | FAQ、仕様、スキーマ、用語集、参照資料 |
| `docs/` | 開発者向け runbook、内部運用、作業ログ、移行メモ、workflow 定義 |
| `docs/working/` | TASK 単位の作業コンテキスト、レビュー記録、handoff |

## 3. Placement rules

### `pages/explanation/` に置くもの

- Product Overview
- Philosophy
- Positioning
- Before / After
- Value Proposition Canvas
- Architecture explanation
- Roadmap narrative

### `pages/guides/` に置くもの

- Quickstart
- Setup guide
- Demo Script
- Workflow usage guide
- Documentation Management
- Governance guide

### `pages/reference/` に置くもの

- FAQ
- Glossary
- Schema reference
- CLI reference
- Known limitations
- Contract definitions

### `docs/` に置くもの

- 開発者向け runbook
- 内部運用メモ
- workflow 定義
- hook / eval / metrics の実装詳細
- release / audit / migration logs
- `docs/working/` 配下の task-specific artifacts

## 4. Documentation update rules

### 4.1 更新が必須になる変更

以下の変更を行う PR では、関連ドキュメントも同じ PR で更新する。

| Change type | Required documentation update |
| --- | --- |
| User-facing behavior change | `pages/guides/` または `pages/reference/` を更新する |
| Product messaging change | `pages/explanation/product/` を更新する |
| Workflow / Gate change | `docs/` の workflow 定義と公開 guide の影響を確認する |
| CLI command change | CLI reference / guide / demo script を更新する |
| Schema change | reference / schema docs / examples を更新する |
| Metrics / Eval / Keep Rate change | metrics / eval docs と product messaging の整合を確認する |
| Model Profile / Provider behavior change | model profile docs と positioning / FAQ の影響を確認する |
| Security / Privacy / Public data policy change | governance docs / FAQ / reference を更新する |
| Breaking change | migration note / release note / affected guide を更新する |

### 4.2 更新が不要な変更

以下は原則としてドキュメント更新不要。ただし、利用者の理解に影響する場合は更新する。

- typo fix in implementation
- internal refactor with no behavior change
- test-only change
- CI-only maintenance
- dependency update with no user-facing impact

### 4.3 PR checklist

ドキュメントに影響する可能性がある PR では、以下を確認する。

```text
- [ ] User-facing behavior changed?
- [ ] Public docs under pages/ need updates?
- [ ] Developer docs under docs/ need updates?
- [ ] sidebars.js needs navigation updates?
- [ ] FAQ needs a new entry or changed answer?
- [ ] Product positioning or elevator pitch changed?
- [ ] Screenshots / examples / commands are still accurate?
- [ ] Old paths or duplicated docs were removed or redirected?
```

### 4.4 Required front matter block

公開説明ドキュメントには、先頭付近に以下の情報を置く。

```text
> **Status**: v0 / Draft / Stable / Deprecated
> **Review cadence**: Monthly / Quarterly / On change
> **Owner**: Product / Maintainer / Engineering / Governance
```

短い reference ページでは `Owner` を省略してもよいが、`Status` と `Review cadence` は原則として残す。

### 4.5 Status policy

| Status | Meaning |
| --- | --- |
| `Draft` | 内容が検討中。外部向けに使う場合は注意する |
| `v0` | 初版。大きな変更が入り得る |
| `Stable` | 現行仕様・説明として正本扱いできる |
| `Deprecated` | 古い内容。移行先を明記する |

### 4.6 Review cadence policy

| Document type | Default cadence |
| --- | --- |
| Product messaging | Monthly |
| FAQ | Monthly |
| Demo Script | Monthly |
| Governance | Monthly |
| CLI / Schema reference | On change |
| Workflow / Hook / Eval implementation docs | On change |
| Architecture explanation | Quarterly |
| Historical / migration notes | No regular review |

### 4.7 Owner policy

| Area | Owner |
| --- | --- |
| Product Overview / Positioning / Elevator Pitch | Product / Maintainer |
| FAQ / Demo Script | Product / Maintainer |
| Workflow / Gate docs | Engineering / Maintainer |
| CLI / Schema reference | Engineering |
| Metrics / Eval / Keep Rate docs | Engineering / Governance |
| Documentation Management | Governance / Maintainer |
| `docs/working/` artifacts | Task owner |

## 5. Source of truth rules

### 5.1 Product narrative

Product narrative の正本は以下とする。

```text
pages/explanation/product/overview.md
pages/explanation/product/positioning.md
pages/explanation/product/pm-po-elevator-pitch.md
```

README や issue でプロダクト説明を書く場合は、上記と矛盾させない。

### 5.2 FAQ

FAQ の正本は以下とする。

```text
pages/reference/product-faq.md
```

導入検討時の反論・質問が増えた場合は、まず FAQ を更新する。

### 5.3 Demo

デモ手順の正本は以下とする。

```text
pages/guides/product-demo-script.md
```

CLI や workflow の変更でデモ手順が変わる場合は、必ず更新する。

### 5.4 Documentation governance

ドキュメント配置・更新ルールの正本はこのファイルとする。

```text
pages/guides/governance/documentation-management.md
```

## 6. Sidebar policy

River-Reviewer と同様、公開 docs の navigation は `sidebars.js` で管理する。

カテゴリは以下を基本とする。

```text
- index
- ガイド
- リファレンス
- 解説
```

PlanGate では Product narrative を `解説 > プロダクト` に置く。

### Sidebar update rule

`pages/` に新しい公開ページを追加した場合は、原則として `sidebars.js` へ追加する。

例外は以下のみ。

- 一時的な draft
- 外部導線に含めない検証用ページ
- 明示的に hidden とするページ

## 7. Current migration

今回のプロダクト説明資料は、以下のように `pages/` へ移動する。

| Old path | New path |
| --- | --- |
| `docs/product/README.md` | `pages/index.md` / `pages/explanation/product/overview.md` |
| `docs/product/product-brief.md` | `pages/explanation/product/overview.md` |
| `docs/product/before-after.md` | `pages/explanation/product/before-after.md` |
| `docs/product/positioning.md` | `pages/explanation/product/positioning.md` |
| `docs/product/value-proposition-canvas.md` | `pages/explanation/product/value-proposition-canvas.md` |
| `docs/product/faq.md` | `pages/reference/product-faq.md` |
| `docs/product/demo-script.md` | `pages/guides/product-demo-script.md` |
| `docs/pm-po-elevator-pitch.md` | `pages/explanation/product/pm-po-elevator-pitch.md` |

## 8. Monthly review

月 1 回、以下を見直す。

- `pages/` と `docs/` の役割が混ざっていないか
- 外部向け説明が `pages/` に集約されているか
- `docs/working/` が公開導線に含まれていないか
- Product Overview / Positioning / FAQ が実装状況とズレていないか
- Harness Improvement Roadmap の進捗が反映されているか
- `sidebars.js` の導線が壊れていないか
- Deprecated なページに移行先が明記されているか
- README / issue / PR で使っている説明が product narrative と矛盾していないか

## 9. Deprecation and removal rules

### 9.1 Deprecation

古いページをすぐ削除しない場合は、先頭に以下を明記する。

```text
> **Status**: Deprecated
> **Replacement**: `path/to/new-page.md`
```

### 9.2 Removal

以下に該当する場合は削除してよい。

- 移行先が明確である
- sidebar / docs index から参照されていない
- issue / README / PR template から参照されていない
- 内容が重複している
- historical value が低い

### 9.3 Historical records

意思決定や移行履歴として残す価値があるものは、削除せず `docs/` 側へ移す。

## 10. Non-goals

この方針は以下を目的にしない。

- すべての既存 `docs/` を即時 `pages/` に移行すること
- Docusaurus 導入をこのPRで完了すること
- `docs/working/` を公開サイトに含めること
- Kiro 前提の運用を継続すること
- すべてのページを毎月全面改訂すること

## 11. Principle

公開説明は `pages/`。
開発・運用・作業ログは `docs/`。
TASK 固有の状態は `docs/working/`。

User-facing change には doc update を伴わせる。
古い情報は放置せず、更新・非推奨化・削除のいずれかを選ぶ。
