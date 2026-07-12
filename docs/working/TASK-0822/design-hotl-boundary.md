# TASK-0822: HOTL境界の正本化 設計

> 親: #822 EPIC（HITL→HOTL変革）
> 対象: docs/workflows/ai-loop/agentic-six-stage-loop.md に新セクション追加

## Goal

「何が非ブロック化（HOTL化＝人間の事前承認なしで進む）し、何がHuman固定（HITL＝人間の事前承認必須）で残るか」を、
このセッションで実装した機構（#813/#815/#817/#819/#820/#818のD-1〜D-3）を根拠に、既存正本の1セクションとして明文化する。

## 既存正本との整合（重複定義しない）

- responsibility-classes.md（AI自己完結禁止・4分類）: 正本のまま。本セクションはそれを ai-loop 文脈で「どの箇所が該当するか」の対応表を作るだけ
- orchestrator-mode.md（AS-1〜5・ChildExecAllowed・ParentDone）: 正本のまま。変更・緩和しない
- design-philosophy.md §7: 既存の記述と矛盾しないよう突合してから追記

## 追加セクション案（agentic-six-stage-loop.md へ「## 8. HOTL境界（EPIC #822）」として追加）

### 8.1 非ブロック化されている部分（HOTL・事前承認なしで自動進行）

このセッションで実装した以下は、人間の**事前**承認なしに自動で進む:

| 段階 | 機構 | 実装PR |
|---|---|---|
| HO境界の実行時解決 | ho-paths.md実行時parse・解決不能時はfail-closed | #813 |
| plan品質チェック | priority 1.7（gates.c1/breakdown必須） | #817 |
| size機械検証 | priority 1.9（size_ok申告と実測ファイル数の突合） | #820 |
| W check（2モデル独立） | Model A/B裁定 | 既存 |
| arbiter裁定 | AUTO_APPROVED/HUMAN_ESCALATED/BLOCKED | 既存 |
| candidate提示 | discovery D-2/D-3（read-only・Gate非bypass） | #824/#826 |

**条件**: 上記いずれもlite 4軸を満たし・HO非接触・plan品質ゲート通過の場合のみAUTO_APPROVEDに到達しうる。

### 8.2 Human固定（HITL・事前承認が必須のまま）で残る部分

以下は**このセッションの変更で一切緩和されていない**（responsibility-classes.md / orchestrator-mode.mdの正本のまま）:

| 項目 | 固定理由 | 正本 |
|---|---|---|
| merge | NO MERGE BY AI（sockpuppet禁止と一貫） | responsibility-classes.md |
| HO接触 | touches-HOは無条件escalate（priority 1・絶対条件） | ho-paths.md / arbiter.py |
| escalateの自己解決 | AI自己完結禁止 | responsibility-classes.md |
| 重大/criticalリスク | AC-8安全側でHuman確定 | mode-classification.md |
| discoveryの着手決定 | candidate提示のみ・execはHuman/orchestratorが起動 | design-d1.md/d3.md |
| C-3/C-4ゲートの判定主体 | APPROVE/REJECT等の決定権は人間のまま | working-context.md |

### 8.3 「事後監査」による安全性担保（EPIC #822リスク対応）

AUTO_APPROVEDの経路は全て以下で事後監査可能（record保存・#815/#819）:
- run_id/round_index/task_id（#815）
- gates.c1/breakdown の生値（#819）
- size_ok申告 vs 実測ファイル数（#820）
- metrics.pyでfirst-pass rate等を集計可能（#812）

## 制約

- 変更ファイルは agentic-six-stage-loop.md 1つのみ（既存本文・他セクション不可侵）
- 既存の判断1〜3（§5）、既存の6段階対応表（§2）と矛盾させない
- 「完全自律」「HITL全廃」等の過大主張をしない
