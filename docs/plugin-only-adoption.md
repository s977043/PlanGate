# plugin-only 環境の動作境界と CLI 非依存の最小導入パス

> `plugin/plangate/` のみを消費側リポジトリに導入し、`bin/plangate` CLI を
> 一切配置しない環境（以下 **plugin-only 環境**）で、何が動き何が動かないかを
> 宣言する正本。issue [#686](https://github.com/s977043/plangate/issues/686)
> （[#454](https://github.com/s977043/plangate/issues/454) 案B のフォローアップ）に対応する。
> 関連: [`plugin-stability-and-sync.md`](ai/plugin-stability-and-sync.md) /
> [`staged-adoption-guide.md`](staged-adoption-guide.md)

## 1. 課題

`plugin/plangate/` はスキル・エージェント・ルール・コマンドを配布するが、
一部スキルは内部で `bin/plangate <subcommand>` の実行を前提とする。
`bin/plangate` は PlanGate フルリポジトリの `git clone` を伴う配置が必要で、
消費側リポジトリに外部リポジトリ由来のファイルを持ち込む判断コストが
導入の障壁になる（growth-lab での実例: 2026-06-19、`/plangate-setup` の
初手 `bin/plangate doctor --json` が失敗し、CLI 導入自体が見送られた）。

plugin-only 環境でどこまで PlanGate の価値（レビュー観点・plan/handoff の
型・mode 判定）を得られるかが未宣言のため、「CLI を入れないなら PlanGate
は使えない」という誤解で導入自体が否決されるケースがある。本書はこれを
是正し、**CLI なしでも到達できる範囲**を明示する。

## 2. 動作境界マトリクス

`plugin/plangate/skills/*/SKILL.md` を全件 (36 件) 実地確認し、
`bin/plangate` への言及有無・用途で仕分けた（推測ではなく `grep -c
"bin/plangate" plugin/plangate/skills/*/SKILL.md` の実行結果に基づく）。

### 2.1 plugin-only で完全に動く（CLI 言及ゼロ・観点/手順のみ）

| スキル | 用途 |
|--------|------|
| `brainstorming` / `ai-dev-brainstorm` | 要件の対話的整理 |
| `architecture-sketch` | 設計スケッチ |
| `acceptance-criteria-build` / `acceptance-review` | 受入基準の作成・検証 |
| `requirement-gap-scan` / `edgecase-enumeration` | 要件の抜け漏れ・エッジケース洗い出し |
| `risk-assessment` / `nonfunctional-check` | リスク・非機能観点の洗い出し |
| `review-gate` | 6 観点レビュー（差分から finding を収集し severity を付与するレビューフレーム。専用コマンドは不要） |
| `diff-audit` | セルフレビュー（構造化チェックリスト、旧 self-review） |
| `known-issues-log` / `evidence-ledger` | 既知課題・根拠の記録 |
| `context-load` / `context-packager` | コンテキストの読み込み・引き継ぎパケット作成 |
| `feature-implement` / `design-gate` | 実装ガイド・設計ゲート観点 |
| `codex-multi-agent` / `codex-mvp-split` / `subagent-dispatch` / `subagent-driven-development` / `subagent-team-design`（旧 setup-team） | マルチエージェント運用パターン |
| `manual-cloud-task` / `pr-decision` | 手動運用の意思決定補助 |
| `skill-creator` / `systematic-debugging` | スキル設計・デバッグ手法 |

上記 25 スキルは **観点・手順・レビューフレームのみ**で構成され、
`bin/plangate` を一切呼ばない。plugin だけで完全に機能する。

### 2.2 CLI 必須（`bin/plangate` の実行が中核機能）

| スキル | `bin/plangate` 依存箇所 | plugin-only での代替可否 |
|--------|------------------------|--------------------------|
| `ai-dev-exec` | `exec` によるタスク実行制御 | 不可（exec 制御そのものが CLI 機能） |
| `ai-dev-verify` | `validate` / `verify` による機械検証 | 不可（機械検証はハード強制が前提） |
| `ai-dev-plan` | `plan` 生成補助の一部 | 部分可（plan.md 自体は手動で書ける） |
| `plangate-setup` | `doctor --json` によるヘルスチェック起点 | 不可（doctor が唯一の検証源） |
| `local-exec-handoff` | `resume` / `status` / `exec` / `validate` | 部分可（手動 current-state.md 読み書きで代替） |

### 2.3 部分依存（本体は plugin-only で動くが一部 CLI 連携を含む）

| スキル | CLI 連携箇所 | plugin-only での扱い |
|--------|------------|----------------------|
| `plan-review-gate` | C-2 外部レビュー起動（`bin/plangate review --phase c2`）/ `validate` | C-1 セルフレビュー・C-3 三値判定は手動で完結可。C-2 自動起動と機械検証（plan_hash 整合）のみ CLI 必須 |
| `intent-classifier` | render / approve / doctor / exec への意図ルーティング | ルーティング先の一部（render/approve/exec）が CLI 前提。それ以外の意図分類は plugin-only で機能 |
| `skill-policy-router` | ops ドメインでの CLI 操作案内 | ルーティング自体は plugin-only。案内先が CLI 前提なだけ |
| `working-context` | settings タスクロック（`doctor --check-settings`）の言及 | ディレクトリ構造・各ファイルの役割定義は plugin-only で機能。タスクロック判定のみ CLI 必須 |

**判定基準**: 「ゲートの機械的強制（hook 検証・plan_hash 改竄検知・
`doctor` による Shadow Config 防止）」を伴う機能は CLI 必須、
「観点・型・手動判断の補助」に閉じる機能は plugin-only で完結する。

## 3. CLI 非依存の最小導入パス（Level 0）

[`staged-adoption-guide.md`](staged-adoption-guide.md) の Phase 0〜3 は
いずれも `bin/plangate init` / `doctor` を前提とするため、plugin-only
環境向けに **Level 0（CLI 非依存）** を本書で定義する。段階的導入ガイドの
Phase 0 に先行する準備段階として位置づける。

| Step | 使うスキル | 到達できること |
|------|-----------|----------------|
| 1 | `brainstorming` / `architecture-sketch` | 要件・設計を対話的に整理する |
| 2 | `acceptance-criteria-build` / `requirement-gap-scan` | 受入基準を作り、抜け漏れを洗い出す |
| 3 | plan.md / handoff.md を手動作成（[`working-context.md`](../.claude/rules/working-context.md) の各ファイル役割定義に従う） | PlanGate の型に沿った計画・引き継ぎ資産を残す |
| 4 | `risk-assessment` / `edgecase-enumeration` / `nonfunctional-check` | 実装前のリスク・エッジケース・非機能観点を洗い出す |
| 5 | `review-gate` / `diff-audit` | 実装後に 6 観点・チェックリストでレビューする |
| 6 | `known-issues-log` / `evidence-ledger` | 既知課題・レビュー根拠を記録し次担当へ引き継ぐ |
| 7 | [`mode-classification.md`](../.claude/rules/mode-classification.md) を手動参照 | 変更規模に応じた運用強度（5 段階モード）を自己判定する |

**得られるもの**: レビュー観点・plan/handoff の型・mode 分類による運用強度の
目安。**得られないもの**: hook による強制力（plan 未承認での実装ブロック、
plan_hash 改竄検知、`doctor` による Shadow Config 検出）。Level 0 は
「ゲートが人の記憶と規律だけで運用される」状態であることを明示的に認識する。

## 4. CLI が必要になる転換点

以下のいずれかに達した時点で `bin/plangate` の導入（CLI 転換）を検討する。
いずれも「**ゲートを機械的に強制したい**」という要求が起点になる。

| 転換点 | 必要になる CLI 機能 |
|--------|---------------------|
| 「plan 未承認で実装が進んでしまう」ミスを防ぎたい | `exec`（C-3 APPROVED の c3.json 必須化） |
| plan の事後改竄・差し替えを検知したい | `validate`（plan_hash 整合検証） |
| settings wiring の未適用状態で完了扱いにしたくない（Shadow Config 防止） | `doctor --check-settings` |
| 外部 AI レビューを C-2 / V-3 で自動起動したい | `review --phase {c2,v3}` |
| 複数人・複数タスクでの運用状況を横断把握したい | `status` / `timeline` / `metrics` |

これらは §2 のとおり「機械的強制」が本質のため、Skill（ソフト強制）では
代替できない。[`hybrid-architecture.md`](../.claude/rules/hybrid-architecture.md)
の CLAUDE.md / Skill / Hook 境界ルール（Hook のみが「絶対に通さない」制御を
持つ）と整合する。

## 5. 既存正本との関係

- [`staged-adoption-guide.md`](staged-adoption-guide.md): CLI 導入済み環境の
  Phase 0〜3 成長パスの正本。本書の Level 0 はその **前段（CLI 未導入時）**
  を補完する。CLI 導入後は staged-adoption-guide の Phase 0 に接続する。
- [`ai/plugin-stability-and-sync.md`](ai/plugin-stability-and-sync.md):
  plugin 自体の安定性レベル・バージョン固定取得手順の正本。本書は
  plugin 取得後の「CLI なしでの活用範囲」を扱い、取得方法自体は同書に従う。
- 本書は動作境界の**宣言**に留め、CLI 最小サブセット同梱や `npx` 配布等
  （issue #686 提案 2・3）の実装可否は別 PBI で扱う。
