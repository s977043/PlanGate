# Arbiter — PlanGate 共通資産棚卸し

> **Status**: Phase 0 ドキュメント（2026-07-01）。
> **目的**: PlanGate の既存資産について、ai-loop-workflow での利用可否を分類する。
> **原則**: 設計哲学は継承するが、in-the-loop 前提の契約・実装は再設計が必要。

---

## 分類基準

| 分類 | 意味 |
|------|------|
| **uses（共通利用可能）** | Arbiter でもそのまま参照・活用できる資産 |
| **not-uses（再設計が必要）** | in-the-loop 前提に最適化されており、on-the-loop 用に再設計が必要な資産 |

---

## uses — 共通利用可能な資産

| 資産 | 場所 | 共通利用の理由 |
|------|------|--------------|
| スキル群（intent-classifier, hypothesis-logger 等） | `.claude/skills/` | ワークフロー非依存。判断実行スキルは Arbiter の L1 でも活用可能 |
| HO パス定義の哲学 | `docs/ai/hook-enforcement.md` | Arbiter でも変更禁止ファイルは同じ。HO の思想を継承 |
| provenance の設計哲学 | `docs/ai/plan-review-readiness-gate.md` 等 | 証跡担保の思想は継承。Arbiter の auto-approve + provenance 刻印に活用 |
| Plan Review Readiness Gate | `docs/ai/plan-review-readiness-gate.md` | 判定フレームとして参照可。detect フェーズの設計に活用 |
| Iron Law（core-contract.md） | `docs/ai/core-contract.md` | Arbiter でも最上位制約。Iron Law は on-the-loop でも不変 |
| 責務 4 分類の設計哲学 | `.claude/rules/responsibility-classes.md` | Human-owned / AI-owned の区別の思想は Arbiter でも継承 |
| PlanGate の失敗履歴・INC 群 | `docs/working/` 各チケット | Arbiter の threat model 初期値として最大の遺産 |
| 承認境界・決定論・HO の設計思想 | `docs/ai/hook-enforcement.md` 等 | 設計哲学レベルで参照（契約・実装は継承しない） |
| WF-00〜03 / C-1 / C-2 フロー | `docs/workflows/` / `.claude/rules/` | 計画・設計品質ゲートとして共通利用（C-2 契約 = [`review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis は不変） |

---

## not-uses — on-the-loop 用に再設計が必要な資産

| 資産 | 場所 | 再設計が必要な理由 |
|------|------|------------------|
| L0 契約（責務分類本体） | `.claude/rules/responsibility-classes.md` | in-the-loop 前提に最適化されている。on-the-loop では責務モデルが異なる（Policy-owned / Sensor-owned が新設） |
| bin/plangate exec（実行エンジン） | `bin/plangate` | "block until approved" 前提で設計されており、flow → detect と制御の極性が逆。HO-core のため AI 直接編集不可 |
| C-3 承認ロジック | `.claude/rules/working-context.md` 等 | 実行前承認が前提。ai-loop では C-3 を C-3'（AI 裁定ゲート）に置換する（置換対象であり再設計対象。詳細は [`00_concept.md`](../../workflows/ai-loop/00_concept.md) §3） |
| mode-classification | `.claude/rules/mode-classification.md` | in-the-loop の mode 判定に特化。on-the-loop では boundary（touches-HO / clean）と lite が主軸 |
| C-4 自律承認拡張（autonomous-degraded-gates） | `docs/ai/autonomous-degraded-gates-spec.md` | in-the-loop 内の例外的自律化仕様。Arbiter では flow が既定動作のため極性が異なる（関係は related-specs.md 参照） |
| HO パス（scripts, schemas, settings 等）の実装 | `scripts/hooks/*.sh`, `schemas/`, `.claude/settings*.json` | HO-core のため AI 直接変更不可。Arbiter 側で独自定義を持つ（ho-paths.md 参照） |

---

## 継承する設計哲学（要約）

Arbiter は以下の PlanGate 設計哲学を**実装でなく思想として**継承する:

1. **承認境界の死守**: HO パスに触れた瞬間は常に人間へ。緩和なし。
2. **provenance の強制**: 誰が・どの policy で・何を自律許可したかを刻印。
3. **決定論・明示的失敗・トレース可能**: 判断は機械的・明示的・追跡可能。
4. **policy 制定は永久 in-the-loop**: 自分の枠を自分で書き換えない（第0の承認境界）。

---

## plugin bundled resources の担保（#842 B案 / 2026-07-13 確定）

`plugin/plangate/**` は `.claude/**` 等の**派生成果物**であり、HO 対象外とする
（`ho-paths.md` から `HO-plugin` を削除済み）。正本側は EH-3 の 9 カテゴリで
保護されているため、派生側の整合は **CI-owned** に一本化する:

`.github/workflows/sync-plugin-plangate.yml`（同期元 = `.claude/**` /
`.agents/skills/**` / `CHANGELOG.md` / `docs/ai/ai-loop/**` / `scripts/ai-loop/**`）
が main push 時に drift を検出 → 同期 PR を自動作成 → **Human C-4 merge**。

---

## 関連ドキュメント

- `docs/ai/ai-loop/concept.md` — Arbiter の基本概念
- `docs/ai/ai-loop/ho-paths.md` — HO パス一覧（touches-HO 判定基準）
- `docs/ai/ai-loop/related-specs.md` — 既存仕様との関係整理
