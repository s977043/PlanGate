# PBI INPUT PACKAGE — TASK-0913

> Issue: [#913](https://github.com/s977043/plangate/issues/913)（docs / ai-loop / #907 follow-up）
> 由来: PR [#912](https://github.com/s977043/plangate/pull/912) River Review **M-2**（R-111）残件 + `docs/working/TASK-0907/handoff.md` §3 V2 候補
> 作成: 2026-07-25（main `51489e1` 基点。`grep -rn "配下のみ"` 全数照合を現 main で再実測済み）

## Context / Why

[#907](https://github.com/s977043/plangate/issues/907)（PR #912 / `ee9a1b5`）で `docs/workflows/ai-loop/rollout-policy.md` §2 の適用ドメインを拡張した。

- **新**: plangate 本体 = `lite=true ∧ boundary=clean ∧ reversible` 帯の本番フロー変更（判定基盤 carve-out を除く。C-3 は常に Human・§5 不変）
- **旧**: plangate 本体 = `docs/workflows/ai-loop/` 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用）

しかし**兄弟正本・エンジン docstring に旧狭域の宣言が残存**しており、正本間で矛盾している。#912 の River Review が major（M-2）として検出し、最小一手として `docs/ai/ai-loop/concept.md` §3 冒頭に「現在値は rollout-policy §2」のポインタのみ追加した。**残りの追従が本 PBI のスコープ**。

**実害**: ai-loop 実走時にエージェントが読むのは多くの場合 `decision-table` / `lite-criteria` / skill 経由の周辺正本であり、`rollout-policy` 単体の優先宣言では解決しない。旧バナーに従って「本体は ai-loop 配下だけ eligible」と**新 carve-out と正反対の判断**をする余地が残る。

## What（Scope）

### In scope — 追従が必要な箇所（main `51489e1` で `grep -rn "配下のみ" --include='*.md' --include='*.py'` 全数再照合済み）

| # | ファイル:行（現 main 実測） | 現状の記述 |
|---|---|---|
| 1 | `docs/workflows/ai-loop/decision-table.md:3` | 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ |
| 2 | `docs/workflows/ai-loop/lite-criteria.md:3` | 同上 |
| 3 | `docs/workflows/ai-loop/loop-safety-gates.md:4` | 同上 |
| 4 | `docs/workflows/ai-loop/review-feedback-loop.md:3` | 同上 |
| 5 | `docs/ai/ai-loop/arbiter-policy.md:3` | 同上 |
| 6 | `docs/ai/ai-loop/design-philosophy.md:6-8` | ①plangate 本体 = docs/ai/ai-loop/ / docs/workflows/ai-loop/ 配下のみ（バナーは 3 行構成） |
| 7 | `scripts/ai-loop/arbiter.py:4-7`（docstring のみ・論理コード変更なし） | 適用ドメイン（Phase 1 / #807）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ |
| 8 | `docs/ai/ai-loop/concept.md:93,94,112` | §3「変更可能な範囲」本文リスト（L85-88 の**現在値ポインタは #912 で追加済み**だが本文は旧のまま） |
| 9 | `CLAUDE.md:16` | 「**PlanGate 本番フロー WF-00〜07 は不変・ai-loop は Phase 1（導入先検証）**」— 本体適用ドメイン拡張（#907）に言及がない（`配下のみ` grep には非ヒット。目視照合） |

**派生コピーの追従（実測済み）**:

- `plugin/plangate/skills/ai-loop-cycle/**`（旧バナー 7 hit = references 6 本 + `scripts/arbiter.py` 1、加えて concept.md 本文 3 hit = 計 10 hit / 8 ファイル）は `scripts/sync-plugin-plangate.sh` が正本 1〜8 から自動生成（同スクリプト L186-358）。**個別編集不要**（sync 実行 + drift-check で担保）
- `.codex/skills/ai-loop-cycle/SKILL.md:3` に旧狭域 description（「本プラグイン同梱の ai-loop ドキュメント配下のみ」）が **stale 残存**（1 hit）。正本 `.agents/skills/ai-loop-cycle/SKILL.md:3` は追従済みのため、`sh scripts/install-plangate-skills-to-codex.sh` の再実行（source = `.agents/skills/`）で解消する（`.codex/skills` は非 HO・派生コピー）

### Out of scope

- 履歴アーカイブ（当時の記述として保全・改変しない）: `docs/working/TASK-0822/design-stop-rollback-final.md:5` / `docs/working/TASK-0907/pbi-input.md:9,20`（旧バナー 3 hit）ほか `docs/working/**` の過去 PBI 成果物一式
- 「配下のみ」を含むが適用ドメインと無関係な記述（変更しない）: `.claude/rules/mode-classification.md:115`（doc 種別定義）/ `docs/ai/subagent-delegation/dispatch-template.md:76-77`・`examples.md:246`（worktree 書込境界）
- 適用ドメイン自体の再変更（rollout-policy §2 は #907 で確定済み・本 PBI は**追従のみ**）
- carve-out の機械層化（`ho-paths.md` への ①〜③ HO 登録）→ rollout-policy §2 注記どおり別課題（[#916](https://github.com/s977043/plangate/issues/916) で追跡）

## 受入基準

- AC-1: 上記 1〜7 の旧狭域バナーが、現在値（rollout-policy §2 を正本とする旨）と矛盾しない記述に更新されている
- AC-2: `concept.md` §3 の本文リスト（8）が現在値と整合、または現在値ポインタで明確に上書きされていると読める
- AC-3: `CLAUDE.md`（9）に本体適用ドメイン拡張（#907 / carve-out 付き）が反映されている（**HO のため Human 適用 patch として分離**。Notes 参照）
- AC-4: **`rollout-policy.md` §2 を単一正本とし、各所は「参照」に留める**（lite/clean/reversible の条件・carve-out glob を各所で再定義しない＝断片化を作らない）
- AC-5: `grep -rn "配下のみ" --include='*.md' --include='*.py' docs/ scripts/ .claude/ .agents/ CLAUDE.md` の結果に、履歴アーカイブ（`docs/working/**`）と無関係用法（Out of scope 列挙分）以外の未追従が残らない（全数照合）
- AC-6: sync drift ゼロ — `sh scripts/sync-plugin-plangate.sh --dry-run` が正本追従後に plugin 側へ反映すべき差分を検出→本実行後 no changes、かつ `.codex/skills/ai-loop-cycle/SKILL.md` の stale drift（旧 description）が解消されている

## Notes from Refinement

- **実施経路の制約（最重要）**: 対象 1〜8 は #907 で新設された**判定基盤 carve-out**（`scripts/ai-loop/**`・`docs/workflows/ai-loop/**`・`docs/ai/ai-loop/**`・`*/skills/ai-loop-cycle/**`。rollout-policy §2 注記の glob）に該当する。**ai-loop で回す場合は escalate → 人間 C-3 固定**であり auto-approve されない（carve-out は規範層＝arbiter は boundary=clean と判定するため、実行者 + W チェック 2 体が escalate 責務を負う）
- **CLAUDE.md（9）は Hardening Override（HO）対象** → AI 編集不可。**Human 適用 patch ファイル提示方式**で分離する（前例: `docs/working/TASK-0872/patches/`）。patch は AI が作成・検証（`git apply --check` + worktree 実適用テスト）し、適用は Human-owned
- **AC-4 の断片化防止**: 各所のバナーは「適用ドメインの現在値は [`rollout-policy.md`](…) §2 を正本とする」参照形式に統一し、数値・条件・glob の再掲を禁止する（今回の M-2 と同型の再発を構造的に防ぐ）
- **Mode 判定（mode-classification.md 機械判定）**: **high-risk**
  - 定量: 変更ファイル数 = 正本 8 + CLAUDE.md patch 1 + 派生（plugin 約 8 は sync 自動・.codex 1 は script 再実行）→ 直接編集 8〜9 で **high 帯（6-15）**。受入基準 6 → high 帯。タスク数見込み 10 前後 → standard〜high
  - 定性（例外ルール優先): **承認境界周辺の変更**（`CLAUDE.md` = HO 9 カテゴリ該当）→ **最低 high + `lite_eligible=false` 強制 + Standard C-3 同期固定**。doc-light は「HO 対象パスの `.md` を含む」除外条件に該当し**適用不可**
  - critical 非該当: アーキテクチャ変更・横断リファクタなし（確定済み現在値への記述追従のみ）→ 最終 **high-risk**
- 出典: PR #912 River Review M-2（R-111）。`docs/working/TASK-0907/handoff.md` §3 V2 候補にも記録

## Estimation Evidence

- **対象**: 正本 9 箇所（うち HO 1 = `CLAUDE.md`）。plugin 派生 8 hit は sync 自動、`.codex` 派生 1 hit は install script 再実行で追従
- **論理コード変更ゼロ**（`arbiter.py` は docstring のみ）→ 検証は doc 整合・AC-5 全数 grep・AC-6 sync drift 中心。`python3 scripts/ai-loop/test_arbiter.py` の回帰確認で docstring 変更が挙動非影響であることを担保
- **Risks**: 各所で文言を再定義すると断片化が再発する → AC-4 で「参照のみ」を強制 / CLAUDE.md patch の Human 適用漏れ → handoff で PENDING-VERIFY として明示追跡
- **Unknowns**: `.codex/skills` の再生成が ai-loop-cycle 以外のスキルにも差分を出す可能性（install script は差分時のみ更新のため、スコープ超過差分が出た場合は当該分を見送り報告）
- **Assumptions**: rollout-policy §2（#907 / `ee9a1b5`）が main で確定・安定していること（`51489e1` で確認済み）
