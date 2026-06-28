# TASK-0148 EXECUTION PLAN — 休眠 EHS の CI 移植（EHS-1 / EHS-2 を PR トリガー化）

> EPIC #527 後続。現状把握（hook-enforcement.md §0 / PR #647）で判明した
> 「CLI を使わない運用では EHS-1/2/3 が休眠」する問題への対応。PR トリガーで
> 自然に発火する EHS-1 / EHS-2 を **CI（GitHub Actions）へ移植**し、CLI 非依存で
> 常時強制する。EHS-3（fix-loop 計数）は CLI プロセス内でしか意味を持たないため
> 移植対象外（CLI 維持）。

## Goal

PR をトリガーに、対象 TASK の **EHS-1（V-3 外部レビュー必須）/ EHS-2（handoff 6要素）**
を CI で検査し、不足を **PR ステータスで block** する。`bin/plangate` を回さなくても
品質ゲートが効く状態にする。**既存の手動 CLI 経路は維持**（二重防御）。

## Approach Overview

| 案 | 内容 | 評価 |
|----|------|------|
| A（採用）| PR トリガーの新 workflow `ehs-pr-gates.yml`。変更された `docs/working/TASK-XXXX/` から TASK と mode を導出し、既存 `check-v3-review.sh` / `check-handoff-elements.sh` を strict 実行 | 既存スクリプト流用・CLI 非依存・bypass 不能 |
| B | `bin/plangate verify` を CI step で呼ぶ | verify は validate/eval/metrics 等を含み CI で重い・副作用大。ゲート部分だけ切り出せない |
| C | PreToolUse hook 化 | EHS は「PR / 完了時」トリガーで Edit 単位ではない。層が合わない |

→ **案A**。EHS-1/EHS-2 のトリガー（PR / 完了時）と CI の発火点が一致する。

## 主要な設計論点（Unknowns）

1. **TASK と mode の導出**: CI は PR の変更ファイルから `docs/working/TASK-XXXX/` を検出し、
   `plan.md` の Mode 判定（または `c3.json`）から mode を読む必要がある。複数 TASK 変更・
   TASK 無し PR（doc-only 等）の扱いを定義する（安全側: 検出 0 件は SKIP、複数は各々検査）。
2. **適用条件**: EHS-1 は `mode ∈ {standard, high-risk, critical}` のみ。CI は mode を
   判定して条件分岐する。`validation_bias=strict` 概念は CI では「PR ゲートは常時 strict」
   とするか profile 連動にするかを決める（**推奨: PR では mode ベースで常時適用**。
   profile はローカル CLI 向け概念のため CI では mode を一次条件にする）。
3. **handoff 不在 PR の扱い**: WF-05 未到達の中間 PR で handoff.md が無い段階を
   どう扱うか（推奨: handoff.md が存在する場合のみ 6 要素を検査。完了 PR ラベル
   等で必須化は別 PBI）。
4. **EH-4 / EH-5 の扱い**: 同じく休眠だが本 PBI のスコープ外（EHS に限定）。
   別 PBI で test-cases / verification evidence の CI 検査を検討。

## Work Breakdown

| Step | Output | Owner | Risk | チェックポイント |
|------|--------|-------|------|----|
| 1 | TASK/mode 導出ヘルパー（変更ファイル→TASK→mode）。非HO `scripts/_*.py` or workflow inline | agent | low | 複数/0 件の安全側 |
| 2 | `.github/workflows/ehs-pr-gates.yml`（PR トリガー、EHS-1/EHS-2 を条件付き strict 実行） | agent | HO | .github/workflows |
| 3 | CI 用に `check-v3-review.sh`/`check-handoff-elements.sh` を非破壊で呼ぶラッパ（必要なら） | agent | low | 既存挙動不変 |
| 4 | テスト: fixture PR シナリオ（V-3 欠落で fail / 充足で pass / doc-only で skip） | agent | low | — |
| 5 | hook-enforcement.md §0 を「EHS-1/2 は CI 常時強制」へ更新（PR #647 マージ後） | agent | low | #647 と整合 |

## Files / Components to Touch

- `.github/workflows/ehs-pr-gates.yml`（新規・**HO**）
- `scripts/_derive_task_mode.py` 等（新規・非HO）
- `scripts/hooks/check-v3-review.sh` / `check-handoff-elements.sh`（**変更しない**前提で流用。必要なら別 PBI）
- `docs/ai/hook-enforcement.md`（doc）
- `tests/`（CI シナリオ）

## Testing Strategy

- ローカル: 導出ヘルパーの単体（複数 TASK / 0 件 / mode 判定）。
- CI シナリオ: act もしくは fixture で「V-3 欠落→fail」「充足→pass」「doc-only→skip」。
- 既存 suite 0 FAIL（流用スクリプトの非破壊を担保）。

## Risks & Mitigations

| Risk | 対策 |
|------|------|
| CI が TASK/mode を誤検出し正当な PR を誤 block | 検出 0 件=SKIP・判定不能=SKIP（安全側）。block は明確に充足不足のときのみ |
| 既存 doc-only / 非 TASK PR が落ちる | TASK ディレクトリ変更が無い PR は対象外（早期 exit） |
| `.github/workflows` 改変（HO）| apply ではなく通常 PR + 人間 C-3。required check 化は admin 設定（Human-owned）|
| EHS-3 も移したく見える | スコープ外と明記（CLI プロセス計数のため CI 不適）|
| #647 と doc 競合 | #647 マージ後に §0 更新を本 PBI に取り込む |

## Non-goals

- EHS-3 の CI 化（CLI 維持）
- EH-4 / EH-5 の CI 化（別 PBI 候補）
- required status check の必須化（GitHub 設定 = Human-owned admin）
- `bin/plangate verify` 自体の CI 実行

## Mode判定

**モード**: high-risk（`.github/workflows/*.yml` = Hardening Override パス）/ `lite_eligible=false`

**判定根拠**:

- 変更ファイル数: 4-5 → standard〜high
- 変更種別: CI ゲート新設（承認境界周辺）→ 最低 high（AC-10 / .github/workflows は HO）
- リスク: 中（誤 block で開発を止めうる → 安全側 SKIP 設計で緩和）
- **最終判定**: high-risk（人間 C-3 必須）
