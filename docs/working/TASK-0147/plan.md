# TASK-0147 EXECUTION PLAN — validation_bias の conductor export 配線（#527 follow-up）

> EPIC #527（CLOSED）の受容済み Non-goal を follow-up として正規化。
> TASK-0145/0146 で EHS-1/2/3 は `bin/plangate` に配線・適用済みだが、発火条件
> `PLANGATE_VALIDATION_BIAS` を **実 run で誰も export していない**ため、strict
> profile でも EHS が発火しない。本 PBI でその最後の経路を埋める。

## Goal

`model-profiles.yaml` の active/指定 profile の `validation_bias` を解決し、
`bin/plangate verify` / `handoff --verify` 実行時に `PLANGATE_VALIDATION_BIAS`
として自動 export する機構を配線する。strict profile で EHS-1/2/3 が実 run 発火し、
normal/lenient では従来どおり非発火（既存挙動不変）。

## Approach Overview

| 案 | 内容 | 評価 |
|----|------|------|
| A（採用）| `bin/plangate verify`/`handoff` が `--profile <key>` を受理し、`model-profiles.yaml` から `validation_bias` を解決して内部で `PLANGATE_VALIDATION_BIAS` を export | 既存 `--profile`（context/eval）と一貫・最小侵襲 |
| B | conductor agent (`workflow-conductor.md`) が手順として env export を指示 | プロンプト依存＝強制力なし（Hook 哲学に反する）。補助のみ |
| C | `model-profiles.yaml` の "active" を別途持たせ常時自動解決 | active 概念が未定義・スコープ増。将来拡張 |

→ **案A を主、案B を補助文書**として併用。env を明示注入済みなら尊重（上書きしない）。

## Work Breakdown

| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| 1 | `_resolve_validation_bias.py`（profile key → bias 解決ヘルパー、yaml 読取） | agent | low | yaml parse 健全性 |
| 2 | apply-script: `cmd_verify`/`cmd_handoff` 冒頭で `--profile` 解決し `PLANGATE_VALIDATION_BIAS` を export（env 既設定時は尊重） | agent | **HO** | 🚩 bin/plangate 改変 |
| 3 | `tests/extras/ta-49-bias-export.sh`（未適用SKIP / 適用後 TC-01〜05） | agent | low | — |
| 4 | `workflow-conductor.md` に profile→bias 運用補足（補助・非強制） | agent | **HO** | 🚩 .claude/agents 改変 |
| 5 | hook-enforcement.md の follow-up ギャップ記述を「配線済み」へ更新 | agent | low | PR #642 とのコンフリクト調整 |

## Files / Components to Touch

- `scripts/_resolve_validation_bias.py`（新規・AI 直接可）
- `scripts/apply-task-0147-bias-export.sh` + `_apply_task_0147_patches.py`（新規・AI 直接可）
- `bin/plangate`（**HO** / apply-script 経由・Human 適用）
- `.claude/agents/workflow-conductor.md`（**HO** / apply-script 経由・Human 適用）
- `tests/extras/ta-49-bias-export.sh`（新規）
- `docs/ai/hook-enforcement.md`（doc）

## Testing Strategy

- ta-49: TC-01（`--profile` で strict 解決→export）/ TC-02（normal profile は非 export＝既定 normal）/ TC-03（env 明示注入を上書きしない）/ TC-04（不正 profile key はエラーまたは normal fallback・安全側）/ TC-05（patched 構文健全 `sh -n`）。
- `sh tests/run-tests.sh` 0 FAIL（未適用は SKIP）。
- strict profile での EHS-1/2/3 実発火を統合確認（sandbox apply）。

## Risks & Mitigations

| Risk | 対策 |
|------|------|
| profile→bias 自動解決が誤って strict 化し既存 run を block | env 既定 normal・明示 `--profile` 指定時のみ解決・env 既設定尊重の三重安全側 |
| HO 2 ファイル（bin/plangate + workflow-conductor）改変でレビュー負荷増 | apply-script + Human 適用、文字列アンカー方式。conductor 変更は非強制の補足のみに限定 |
| PR #642（doc）と hook-enforcement.md が競合 | #642 マージ後に rebase、または本 PBI で doc 変更を持たない選択 |
| 閉じた EPIC #527 の再開 | follow-up PBI として新 issue 起票（スコープを export 経路のみに限定） |

## Questions / Unknowns

- `model-profiles.yaml` の「active profile」概念は未定義 → 本 PBI は **明示 `--profile`** に限定し、active 自動選択は別 PBI（案C）に送る。
- conductor（AI エージェント）が実際に `--profile` を渡す運用フローを強制する手段はプロンプト止まり → 強制は CLI 側（案A）に閉じ、conductor は補助。

## Mode判定

**モード**: high-risk（`bin/plangate` + `.claude/agents/` = Hardening Override パス 2 種）/ `lite_eligible=false`

**判定根拠**:

- 変更ファイル数: 6 → high
- 変更種別: HO パス配線（承認境界周辺）→ 最低 high（AC-10）
- リスク: 中〜高（実 run の strict 発火に影響）
- **最終判定**: high-risk（人間 C-3 必須、autonomous APPROVE 不可）
