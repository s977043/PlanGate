# PBI INPUT PACKAGE — TASK-0907

> Issue: [#907](https://github.com/s977043/plangate/issues/907)（P1 / enhancement / area:workflow / governance）
> 由来: EPIC #870 ai-loop vNext 運用改善 / #807（Phase 0→1 移行）の延長
> 作成: 2026-07-23（main 3b987a1 基点）

## Context / Why

ai-loop-workflow は Phase 1（導入先適用）だが、`docs/workflows/ai-loop/rollout-policy.md` §2 の適用ドメインでは **plangate 本体（提供元リポジトリ）については `docs/workflows/ai-loop/` 配下のみ（dogfooding 域）**に限定され、本番承認フロー（実コード変更）へは「**非適用・据え置き**」となっている。

ai-loop の実運用改善（ドッグフーディング）を進めるため、plangate 本体の実コード変更のうち **`lite=true ∧ boundary=clean ∧ reversible` 帯**に ai-loop を適用できるよう適用ドメインを拡張する。これにより後続の #877 等の lite/clean/reversible な bug fix を ai-loop で回して改善知見を得られる。

> **Human 決定（2026-07-23・verbatim）**:
> 「適用ドメインを拡張し ai-loop で開発」
> 「基本的に開発は ai-loop-workflow を使って開発をして欲しい 改善をすすめたいため」

## What（Scope）

### In scope
- `rollout-policy.md` §2 適用ドメイン表: plangate 本体行を「`docs/workflows/ai-loop/` 配下のみ」→「同配下 ＋ `lite=true ∧ boundary=clean ∧ reversible` な本番フロー変更」へ拡張
- §2 auto-approve 方針: plangate 本体でも lite 4 軸充足で `AUTO_APPROVED` 対象に含める（導入先と同一扱い・#807 と整合）
- Human 決定 verbatim を移行根拠として §2 に追記
- `.claude/commands/ai-loop-workflow.md`（＋ `plugin/plangate/commands/ai-loop-workflow.md` 同期版）実行前チェック 3 の文言調整（承認境界・HO 接触は通常フロー / lite/clean な本番変更は ai-loop 可）

### Out of scope
- §5 不変条件の変更（**NO MERGE BY AI** / HO 接触＝無条件 escalate / W チェック独立 2 体 / lite AC-8 安全側 は不動・明示維持）
- `lite.size_ok` の機械算出（#780 slice C）
- 導入先リポジトリの適用条件（§3）変更

## 受入基準

- AC-1: rollout-policy §2 で plangate 本体の `lite/clean/reversible` な本番変更が eligible と読める
- AC-2: §5 不変条件が一字も緩和されていない（差分で確認）
- AC-3: Human 決定 verbatim が §2 に移行根拠として記録される
- AC-4: ai-loop-workflow command の実行前チェック 3 が §2 と整合する
- AC-5: sync（`.claude` ↔ `.agents` ↔ `plugin` ↔ `.codex`）drift ゼロ

## Notes from Refinement

- **Mode 見込み**: critical（承認境界＋ワークフロー定義変更）→ `lite_eligible=false` → 人間 C-3 固定
- **本 PBI の開発自体を ai-loop で回す**（`rollout-policy.md` は現行 dogfooding 域内・`lite=false` で escalate → 人間 C-3。ai-loop が承認境界を遵守して人間へ上げる実証を兼ねる）
- `ai-loop-workflow.md` command はHO 該当か要確認（`.claude/commands/*.md` は mode-classification HO 9 カテゴリの 1 つ）→ HO の場合 Human patch 適用経路。plan で確定

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 承認境界の緩和と誤読される | §5 不変条件を「変更なし・明示維持」と差分で示す・C-2/River Review で確認 | 文言に「承認境界不動」を明記 |
| sync drift（4 経路） | `sh scripts/sync-plugin-plangate.sh` 実行 + 照合 | drift 検出時は再同期 |
| command が HO 該当で AI 直編集不可 | `scripts/hooks/check-plan-hash.sh` の HO パターン照合 | Human patch 適用（patches/ 同梱） |

### Unknowns
- `ai-loop-workflow.md` command 文言調整が既存テスト（doctor / CI）に影響するか → plan で実測

### Assumptions
- touch は 3〜4 ファイル（`rollout-policy.md` ＋ command ×2 ＋ 必要なら `00_concept.md` 参照整合）
- 論理コード変更なし（docs / command md のみ）→ テストは doc 整合・リンク健全性中心
