# TASK-0027 EXECUTION PLAN

> 生成日: 2026-04-20
> PBI: [TASK-0021-E] Verify & Handoff を標準 phase 化する（WF-05）
> チケットURL: https://github.com/s977043/plangate/issues/27

## Goal

WF-05 Verify & Handoff を標準 phase として深化し、handoff package テンプレートを整備、全 PBI で handoff 必須化をルール化する。

## Constraints / Non-goals

- 既存 status.md / current-state.md の構造は変更しない
- `.claude/rules/working-context.md` は節追加のみ
- **Non-goals**: handoff 自動生成、他 phase 深化

## Approach Overview

1. #23 基盤の 05_verify_and_handoff.md 確認、深化ポイント特定
2. phase 共通契約（目的/入力/完了条件/呼び出しSkill/主担当Agent）を維持したまま深化
3. handoff.md テンプレート作成（6 要素、命名規約を明記）
4. `.claude/rules/working-context.md` に handoff セクション追加
5. 既存 status/current-state との役割分担記載
6. V-1 との関係明示

## Work Breakdown

### Step 1: #23 基盤確認 + 深化ポイント

- **Output**: `docs/working/TASK-0027/evidence/wf05-enhancement-points.md`
- **Owner**: agent
- **Risk**: 低

### Step 2: handoff.md テンプレ作成（命名規約含む）

- **Output**: `docs/working/templates/handoff.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - 6 要素（要件適合 / 既知課題 / V2候補 / 妥協点 / 引き継ぎ文書 / テスト結果）全て含む
  - **命名規約を冒頭に記載**: `docs/working/TASK-XXXX/handoff.md` 固定、1 PBI につき 1 ファイル

### Step 3: 05_verify_and_handoff.md 深化（phase 共通契約を維持）

- **Output**: `docs/workflows/05_verify_and_handoff.md` 更新
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**:
  - Rule 1 遵守（実装ノウハウ非混入）
  - phase 共通契約の 5 要素（目的/入力/完了条件/呼び出しSkill/主担当Agent）が明示的に保持されている
  - acceptance-review / known-issues-log との連携記載
  - V-1 との関係記載

### Step 4: .claude/rules/working-context.md 更新

- **Output**: `.claude/rules/working-context.md` に handoff 節追加
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 既存構造を壊さず、「handoff」節が追加、全 PBI で必須であることを明記

### Step 5: サンプル handoff.md 作成

- **Output**: `docs/working/TASK-0027/evidence/sample-handoff.md`（題材: TASK-0017）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 6 要素全てに TASK-0017 実例

### Step 6: V-1 との関係明示

- **Output**: 05_verify_and_handoff.md 内に明記
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: V-1 = 実装ゲート、handoff = 完了後資産、の区別が明示

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 修正 | docs/workflows/05_verify_and_handoff.md | 深化 |
| 新規 | docs/working/templates/handoff.md | テンプレ |
| 修正 | .claude/rules/working-context.md | handoff 節追加 |
| 新規 | docs/working/TASK-0027/evidence/wf05-enhancement-points.md | 深化ポイント |
| 新規 | docs/working/TASK-0027/evidence/sample-handoff.md | サンプル |

## Testing Strategy

- **Unit**: 各ファイル存在、必須要素
- **Integration**: working-context.md に handoff 節追加、既存構造との整合
- **Verification**:
  - `grep -c "handoff" .claude/rules/working-context.md` → 1 以上
  - handoff.md テンプレに 6 要素
  - サンプルが 6 要素全てを埋めている

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| status.md との重複で二重管理 | 役割分担表を 05_verify_and_handoff.md と rules 両方に記載 |
| Skill 実体未完 | 仮参照、#24 完了時に整合確認 |
| rules 既存構造破壊 | 節追加のみ、既存行への変更なし |

## Questions / Unknowns

- handoff.md のファイル名: チケットごとに `docs/working/TASK-XXXX/handoff.md` 固定
- light モードでの簡易版 handoff は本 TASK では規定しない（将来拡張）

## Mode判定

**モード**: `light`

**判定根拠**:
- 変更ファイル数: 5
- 受入基準数: 6
- リスク: 低
- **最終判定**: light

## 依存

- **前提**: #23 / #24 / #25 完了
- **後続**: なし
