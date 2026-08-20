# Arbiter — HO（Hardening Override）パス集約リスト

> **Status**: Phase 0 ドキュメント（2026-07-01。構築フェーズ番号 — #807 のデプロイ段階 Phase 0/1 とは別系）。
> **目的**: "touches-HO" 判定の基準となるパスを machine-readable な形式で列挙する。
> Phase 2 の Decision table から参照される。
> **出典**: `docs/ai/hook-enforcement.md`、`docs/ai/autonomous-degraded-gates-spec.md` の
> `NoHardeningOverridePath` 条件

---

## 参照解決順（`.claude/rules/*.md` / 導入先で必ずこの順に探す）

本ドキュメントは `.claude/rules/mode-classification.md` を参照する。
このパスは上流リポジトリ基準のため、導入先では **次の順で探索する**:

1. 導入先リポジトリの `.claude/rules/mode-classification.md`
2. 無ければ plugin root 配下 `<plugin_root>/rules/mode-classification.md`。
   `<plugin_root>` は **Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して展開・確認した
   絶対パス**（Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
   という文字列をそのまま Read しない）。変数が空・未設定ならキャッシュを glob で推測せず 3 へ進む
3. どちらにも無い場合は **「正本 `mode-classification.md` を参照できなかった」と明示**し、
   推測で内容を補わない

---

## 参照解決順（`docs/**` / 導入先で必ずこの順に探す）

本ドキュメントが参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本ドキュメント内の記述を代替正本として扱い、推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため、plugin root 段を置いても必ず空振りする（クラス A の rules 参照が plugin root 配下で解決できるのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

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
| `plugin/plangate/scripts/**` | HO-plugin-dist | 配布実行スクリプト（利用者が実行）。同期元が無く drift 検出不能。サプライチェーン防護 |
| `plugin/plangate/hooks/**` | HO-plugin-dist | 配布 hook（安全装置本体）。同期元が無く drift 検出不能 |
| `plugin/plangate/**/agents/*.yaml` | HO-plugin-dist | 配布 agent 設定。同期元が無く drift 検出不能 |
| `plugin/plangate/.claude-plugin/**` | HO-plugin-dist | plugin manifest（version 行以外に同期元が無い） |
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
| HO-plugin-dist | plugin 配布物のうち**同期元を持たない独自実体**（実行系）。sync が生成する派生成果物は対象外（PR drift check で担保） |

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
plugin/plangate/scripts/install-plangate-skills.sh → HO-plugin-dist
plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md → clean（派生成果物・PR drift check で担保）
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

> **注（#842 B'案確定 / 2026-07-13）**: `plugin/plangate/**` は**一律 HO ではない**。
> plugin 配下を 2 分し、**同期元を持たない独自実体（実行系）のみ `HO-plugin-dist` として
> HO 対象**とする（上表 4 パターン）。sync が生成する**派生成果物は HO 対象外**とし、
> 正規 sync（`scripts/sync-plugin-plangate.sh`）の書き込みを阻害しない。派生成果物の
> 整合は CI-owned（`sync-plugin-plangate.yml` の **PR 段階 drift check** + main push の
> 同期 PR → Human C-4 merge）で担保する。
