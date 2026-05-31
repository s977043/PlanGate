# TASK-0121 EXECUTION PLAN

> Source: pbi-input.md / Confirmed spec / Mode: **high-risk**
> Generated: 2026-05-31

## Goal

振り返りメトリクスの配点を Plan-primacy 思想に整合させ、対象複製サイトで「計画精度30 / テスト品質15 / プロセス遵守15 / 効率性10 / 成果物品質30」に統一する。あわせて consistency script により、旧配点残存・新 5 軸欠落・合計 100 不一致を機械検知できる状態にする。

## Constraints / Non-goals

- **配点固定**: 計画精度30 / テスト品質15 / プロセス遵守15 / 効率性10 / 成果物品質30。
- **評価語彙固定**: 計画精度は C-1 語彙（受入基準網羅性 / スコープ制御 / テスト戦略妥当性）を含める。
- **成果物品質定義固定**: 「計画で定めた品質の達成度 = 保全達成度」として扱う。
- **Hardening Override 境界**: `.claude/agents/workflow-conductor.md` と `.claude/agents/retrospective-analyst.md` は人間編集。
- **pre-push / CI 境界**: pre-push 配線と `.github/workflows/` 配線は人間編集。`.github/workflows/` は Hardening Override。
- **対象外**: `.codex/agents/retrospective_analyst.toml` は thin pointer のため変更しない。
- **Non-goals**: 過去 retrospective の再計算、5 軸以外の新評価軸追加、mode 判定ルール変更、C-1 / C-2 / C-3 ゲート定義変更。

## Approach

1. consistency script を先に追加し、現状の旧配点に対して RED を確認する。
2. 非 Hardening Override の複製サイトを agent が更新する。
3. Hardening Override の `.claude/agents/` 2 件と pre-push / CI 配線は human が更新する。
4. 全反映後、consistency script で GREEN を確認し、旧配点残存 0 / 新 5 軸存在 / 合計 100 を証跡化する。

## Metrics Evidence

| 指標 | 実数 | 見積もり | ratio | 判定 |
|------|------|----------|-------|------|
| 配点同期対象サイト | 5（うち `.codex` 1 件は対象外 pointer） | 5 | 1.0 | 採用 |
| 実更新対象サイト | 4 | 4 | 1.0 | 採用 |
| 新規 script | 1 | 1 | 1.0 | 採用 |
| Human-owned 編集 | 2 HO + pre-push/CI 配線 | 2+ | 1.0 | high-risk 維持 |

確認済み旧配点の主要出現:

- `docs/ai-driven-development.md`: 評価軸テーブルが旧配点。
- `.claude/agents/workflow-conductor.md`: 評価スコア行が旧配点。
- `.claude/agents/retrospective-analyst.md`: スコアカード denominator が旧配点。
- `plugin/plangate/agents/workflow-conductor.md`: 評価スコア行が旧配点。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | C-3 artifact 発行確認 | `docs/working/TASK-0121/approvals/c3.json`（APPROVED） | human | medium | plan_hash と APPROVED を確認 |
| 2 | consistency script 新規作成 | `scripts/check-retro-scoring-consistency.sh` | agent | medium | 旧状態で RED（non-zero） |
| 3 | 非 HO doc 正本更新 | `docs/ai-driven-development.md` | agent | medium | 新配点 + C-1 語彙 + 保全達成度 |
| 4 | plugin conductor 同期 | `plugin/plangate/agents/workflow-conductor.md` | agent | medium | `.claude` conductor と同義の新配点 |
| 5 | Claude conductor HO 更新 | `.claude/agents/workflow-conductor.md` | human | high | HO 人間編集、旧配点なし |
| 6 | retrospective analyst HO 更新 | `.claude/agents/retrospective-analyst.md` | human | high | `/30 /15 /15 /10 /30` に更新 |
| 7 | pre-push / CI 配線 | pre-push template or dispatcher、必要時 `.github/workflows/*` | human | high | script が push 前 / CI で実行される |
| 8 | GREEN 検証 | consistency script 実行ログ | agent | medium | 旧配点 0、新 5 軸、合計 100 |

## Files

| ファイル | 位置づけ | HO / 非HO | Owner | 変更方針 |
|---------|----------|-----------|-------|----------|
| `docs/ai-driven-development.md` | 複製サイト 1 | 非HO | agent | 評価軸テーブルを新配点へ更新し、計画精度・成果物品質の評価基準を再定義 |
| `.claude/agents/workflow-conductor.md` | 複製サイト 2 | HO | human | conductor の評価スコア行を新配点へ更新 |
| `.claude/agents/retrospective-analyst.md` | 複製サイト 3 | HO | human | scorecard denominator と根拠文言を新配点へ更新 |
| `plugin/plangate/agents/workflow-conductor.md` | 複製サイト 4 | 非HO | agent | plugin 配布版 conductor の評価スコア行を新配点へ同期 |
| `.codex/agents/retrospective_analyst.toml` | 複製サイト 5 | 対象外 | none | thin pointer のため変更禁止 |
| `scripts/check-retro-scoring-consistency.sh` | 新規 drift guard | 非HO | agent | 旧配点残存 0 / 新 5 軸存在 / 合計 100 を検証 |

Human-owned 配線候補:

| ファイル | Owner | 理由 |
|---------|-------|------|
| `scripts/templates/pre-push.sample` または既存 hook dispatcher | human | pre-push 連携は人間編集指定 |
| `.github/workflows/*.yml` / `.github/workflows/*.yaml` | human | `.github/workflows/` は Hardening Override |

## Testing Strategy

- **Unit**: `sh -n scripts/check-retro-scoring-consistency.sh` で shell 構文を確認する。
- **Integration**: `sh scripts/check-retro-scoring-consistency.sh` で対象複製サイトを横断検証する。
- **RED**: script 作成直後、旧配点が残る状態で実行し、旧配点残存または新配点欠落により non-zero exit になることを確認する。
- **GREEN**: agent 更新 + human HO 更新後に再実行し、旧配点残存 0、新 5 軸存在、配点合計 100 で exit 0 になることを確認する。
- **pre-push**: human が配線後、pre-push 経由で consistency script が呼ばれることを確認する。
- **CI**: human が `.github/workflows/` を編集した場合、対象 workflow で consistency script が実行されることを確認する。
- **E2E**: 実アプリケーション動作は対象外。ドキュメント / agent 定義 / hook wiring の構造検証を完了条件とする。

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| 複製サイトの部分更新でドリフトする | high | consistency script で対象サイトを固定し、旧配点残存 0 と新 5 軸を検証 |
| HO ファイルを agent が編集して境界違反する | high | `.claude/agents/` 2 件は todo.md で human task に分離 |
| `.codex` pointer を誤更新する | medium | Files で対象外 / 変更禁止を明記し、TC で diff なしを確認 |
| script が履歴 artifact を誤検出する | medium | 検証対象を今回の権威サイトに限定し、`docs/working/` は走査対象外 |
| pre-push / CI 配線が過検知で運用を止める | medium | human-owned 配線とし、RED/GREEN の失敗理由を明確化 |
| C-3 APPROVED 済みだが artifact 未発行 | medium | Step 1 を human task とし、exec 前に `c3.json` を発行 |

## Mode 判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 実更新 5 件以上（非HO 3 + HO 2 + 配線候補） → high-risk
- 受入基準数: 9 → high-risk
- 変更種別: ワークフロー / agent 定義 / hook 連携にまたがる複製サイト同期 → high-risk
- リスク: Hardening Override 2 件と `.github/workflows/` 配線を含む → high-risk
- lite_eligible: false（HO と pre-push/CI 配線を含み、Lite 条件を満たさない）
- **最終判定**: high-risk（確定スペックの Mode 指定と一致）

## Questions / Unknowns

- CI 連携を既存 workflow に追加するか、新規 workflow とするかは human が決める。
- pre-push 連携を既存 template に直接追加するか、dispatcher 化するかは human が決める。
