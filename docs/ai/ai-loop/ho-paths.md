# Arbiter — HO（Hardening Override）パス集約リスト

> **Status**: Phase 0 ドキュメント（2026-07-01。構築フェーズ番号 — #807 のデプロイ段階 Phase 0/1 とは別系）。
> **目的**: "touches-HO" 判定の基準となるパスを machine-readable な形式で列挙する。
> Phase 2 の Decision table から参照される。
> **出典**: `docs/ai/hook-enforcement.md`、`docs/ai/autonomous-degraded-gates-spec.md` の
> `NoHardeningOverridePath` 条件

---

## touches-HO 判定ルール

> **「上記パスのいずれか一つでも変更対象に含む場合、boundary=touches-HO とし、必ず human escalate とする」**
> **優先順位**: `ho-paths.md` の HO パス一覧が machine-readable 正本。`concept.md §3` の「変更禁止」リストは人間向け概説。両者が異なる場合は `ho-paths.md` を優先する。

Arbiter の flow → detect → escalate において、変更対象ファイルパスが以下の HO パス一覧に
一致するものを含む場合は、W チェック（detect フェーズ）をスキップして即座に human escalate とする。
これは Arbiter でも緩和しない**絶対条件**（iron law 相当）。

---

## HO パス一覧

| パス | 分類 | 変更禁止理由 |
|------|------|------------|
| `bin/plangate` | HO-core | 実行エンジン。AI 直接編集不可。制御極性（block until approved）が Arbiter と逆 |
| `scripts/hooks/**` | HO-hook | フック本体（全ファイル）。AI 直接編集不可。誤変更で安全装置が無効化される |
| `schemas/**` | HO-schema | バリデーション定義（全ファイル）。AI 直接編集不可。スキーマ改ざんで不変条件が崩壊する |
| `.claude/rules/*.md` | HO-rules | L0 契約正本。AI 直接編集不可。in-the-loop 前提の契約を Arbiter が変更しない |
| `.claude/settings*.json` | HO-settings | Human-owned 設定。AI 自己改変禁止（self-mod guard） |
| `.claude/settings.local.json` | HO-settings | 同上。ローカル設定も Human-owned |
| `CLAUDE.md` | HO-contract | AI-Human 間の基本契約。AI による変更は契約の自己改ざんに相当 |
| `AGENTS.md` | HO-contract | 同上。Codex 用基本契約 |
| `docs/ai/core-contract.md` | HO-contract | Iron Law 正本。最上位制約。Arbiter でも変更不可 |
| `docs/ai/*.md`（トップレベルの md のみ。`docs/ai/ai-loop/` 配下は対象外） | HO-contract | PlanGate 既存ドキュメント正本。Arbiter PoC が既存仕様を書き換えないための境界 |
| `.github/workflows/*.yml` | HO-ci | CI/CD 定義。AI 直接編集不可。誤変更で安全装置・検証が無効化される |
| `**/approvals/*.json` | HO-approval | 人間承認トークン。AI 代理作成禁止。provenance の偽造防止 |
| `.claude/commands/*.md` | HO-rules | コマンド定義。実行入口・承認境界に影響。AI 直接編集不可 |
| `.claude/agents/*.md` | HO-rules | Agent 行動契約。統制回避防止。AI 直接編集不可 |
| `.claude/settings.example.json` | HO-settings | settings 契約例。自己改変・緩和防止 |
| `.github/workflows/*.yaml` | HO-ci | CI/CD 定義（yaml 拡張子）。AI 直接編集不可 |
| `plugin/plangate/**` | HO-plugin | プラグイン本体。AI 直接編集不可 |
| `docs/ai/ai-loop/ho-paths.md` | HO-contract | HO 境界定義そのもの（本ファイル）。Arbiter が自己の判定基準を自己改変しないための機械層（原則 1 参照） |

---

## 分類定義

| 分類 | 説明 |
|------|------|
| HO-core | 実行エンジン・制御中枢。AI 直接変更不可 |
| HO-hook | フックスクリプト本体。安全装置の物理実装 |
| HO-schema | バリデーション・スキーマ定義 |
| HO-rules | L0 契約正本（in-the-loop 統制の根拠） |
| HO-settings | Human-owned 設定ファイル（self-mod guard 対象） |
| HO-contract | AI-Human 間の基本契約・Iron Law |
| HO-ci | CI/CD 定義・自動検証の物理配線 |
| HO-approval | 人間承認トークン・provenance 証跡 |
| HO-plugin | CLI プラグイン本体 |

---

## 判定アルゴリズム（Phase 2 Decision table 向け）

```pseudocode
入力: 変更対象ファイルパスのリスト
出力: boundary = "touches-HO" | "clean"

boundary = "clean"
for each path in changed_files:
    if matches_any_ho_pattern(path):
        boundary = "touches-HO"
        break  # 1 つでも該当すれば即確定

if boundary == "touches-HO":
    → human escalate（W チェックをスキップ）
else:
    → detect フェーズ（W チェック）へ進む
```

### パターンマッチの例

```text
bin/plangate                → HO-core
scripts/hooks/check-hook.sh → HO-hook
schemas/plan.schema.json   → HO-schema
.claude/rules/mode-classification.md → HO-rules
.claude/settings.json       → HO-settings
.claude/settings.local.json → HO-settings
CLAUDE.md                   → HO-contract
AGENTS.md                   → HO-contract
docs/ai/core-contract.md    → HO-contract
.github/workflows/ci.yml    → HO-ci
docs/working/TASK-0123/approvals/c3.json → HO-approval
plugin/plangate/index.js    → HO-plugin
```

---

## Arbiter 固有の追加原則

1. **docs/ai/ai-loop/ 配下の Phase 1 定義**（issue #739 解消 / #807）:
   `docs/ai/ai-loop/` 配下の AI 編集可は Phase 1（導入先実リポジトリでの検証）
   移行後も**継続**する（変更禁止リストに含まれない）。ただし、**本ファイル
   （`ho-paths.md`）自体の変更（HO 境界の定義変更）は Human 承認必須**とする
   — HO パス集約リストの改廃は境界そのものの変更であり、Arbiter PoC が
   自己の判定基準を自己改変しない（AI 自己完結禁止・responsibility-classes.md
   と一貫）。HO パスへの記述が HO 本体の変更を意味するわけではない（参照のみ）
   という原則は変わらない。この Human 承認必須は機械層でも強制される —
   本ファイル自身（`docs/ai/ai-loop/ho-paths.md`）を上記 HO パス一覧に
   HO-contract として登録済みであり、変更対象に含む run は
   boundary=touches-HO で即 human escalate となる（#808 review-team
   consensus 反映）。

2. **policy ファイル（将来定義）は HO-policy として追加予定**: Arbiter の
   `auto-approve-lite-clean@v1` 等の policy ファイルは制定・改版が Human-owned のため、
   Phase 1 以降に HO-policy として追加する。

---

## 関連ドキュメント

- `docs/ai/ai-loop/concept.md` — Arbiter の基本概念（検証スコープ含む）
- `docs/ai/ai-loop/asset-inventory.md` — PlanGate 資産の uses/not-uses 分類
- `docs/ai/hook-enforcement.md` — HO パスの元定義（PlanGate 既存仕様）
- `docs/ai/autonomous-degraded-gates-spec.md` — `NoHardeningOverridePath` 条件の定義元
