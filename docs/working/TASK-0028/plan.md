# TASK-0028 EXECUTION PLAN

> 生成日: 2026-04-20
> PBI: [TASK-0021-F] Rule 1〜5 と PlanGate ガバナンス層の統合ルールを明文化
> チケットURL: https://github.com/s977043/plangate/issues/28

## Goal

`docs/plangate-v7-hybrid.md` を新設し、Rule 1〜5 / 境界ルール / ガバナンス層と実行層の接続 / v5/v6 整合 を明文化する。`.claude/rules/hybrid-architecture.md` を追加。

## Constraints / Non-goals

- 既存 v5/v6 ドキュメント・`.claude/rules/` 既存ファイルは変更しない（note 追加のみ可）
- Workflow/Skill/Agent の実体は参照のみ
- **Non-goals**: 実体配置（#23-#27）、テンプレ作成

## Approach Overview

1. 既存 v5/v6 ドキュメント調査、v7 との差分整理
2. `docs/plangate-v7-hybrid.md` 作成（構成: 背景 / Rule / 境界 / 接続 / 既存との関係）
3. `.claude/rules/hybrid-architecture.md` 作成（Rule 1〜5、境界ルール）
4. 既存 v5/v6 に v7 への導線 note 追加
5. #23-#27 の要素参照（仮参照、未完でも可）

## Work Breakdown

### Step 1: v5/v6 調査と差分整理

- **Output**: `docs/working/TASK-0028/evidence/v5-v6-v7-diff.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 既存 v5/v6 の主要概念と v7 ハイブリッドの関係が明示

### Step 2: `docs/plangate-v7-hybrid.md` 作成

- **Output**: `docs/plangate-v7-hybrid.md`
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 以下セクション全て含む
  - 背景（ハイブリッドの意義）
  - ガバナンス層 vs 実行層
  - Rule 1〜5
  - CLAUDE.md / Skill / Hook 境界ルール
  - ガバナンス × 実行層の接続表
  - 既存 v5/v6 との関係・差分

### Step 3: `.claude/rules/hybrid-architecture.md` 作成

- **Output**: `.claude/rules/hybrid-architecture.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: Rule 1〜5 と境界ルールが簡潔にルール化

### Step 4: 既存 v5/v6 ドキュメントへの note 追加

- **Output**: `docs/plangate.md` や `docs/plangate-v6-roadmap.md` に v7 導線追加
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 既存文書の冒頭 or 末尾に「v7 ハイブリッドは `docs/plangate-v7-hybrid.md` 参照」と追記

### Step 5: #23-#27 への参考記述（非ブロッキング）

- **Output**: v7 ドキュメント内で #23-#27 の issue 番号レベルの参考記述（仮リンクは**必須化しない**）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**:
  - #23-#27 は issue 番号レベルで参照（例: 「詳細は #23 参照」）
  - 仮リンク・未完成果物への依存を完成条件・テスト条件から除外
  - #23-#27 完了時の実リンク化は optional（本 TASK のブロッカーではない）

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 新規 | docs/plangate-v7-hybrid.md | v7 設計ドキュメント |
| 新規 | .claude/rules/hybrid-architecture.md | Rule 1〜5 + 境界ルール |
| 修正 | docs/plangate.md | v7 導線 note（冒頭または参照セクション） |
| 修正 | docs/plangate-v6-roadmap.md | v7 導線 note |
| 新規 | docs/working/TASK-0028/evidence/v5-v6-v7-diff.md | v5/v6/v7 差分 |

## Testing Strategy

- **Unit**: 各ファイル存在、必須セクション
- **Integration**: v7 ドキュメント内から v5/v6 ドキュメントへのリンクが機能（手動確認）
- **Verification**:
  - `grep -c "Rule 1\|Rule 2\|Rule 3\|Rule 4\|Rule 5" docs/plangate-v7-hybrid.md` → 5 以上
  - `grep -c "Rule" .claude/rules/hybrid-architecture.md` → 5 以上
  - `grep -l "v7\|plangate-v7-hybrid" docs/plangate.md docs/plangate-v6-roadmap.md` → 2 件
  - 接続表の機械確認: `grep -c "GATE\|STATUS\|APPROVAL\|ARTIFACT" docs/plangate-v7-hybrid.md` → 4 以上、`grep -c "Workflow\|Skill\|Agent" docs/plangate-v7-hybrid.md` → 3 以上
  - v5/v6 整合節の存在: `grep -l "v5\|v6" docs/plangate-v7-hybrid.md` 内で「差分」「位置付け」キーワードが出現

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| v5/v6 記述矛盾 | Step 1 差分整理で明示、note 追加で位置付け明確化 |
| Rule 未参照化（#23-#27 で適切に引用されない） | 他 TASK で本 TASK の Rule 番号を参照、相互リンク |
| `.claude/rules/` 既存ファイル破壊 | 新規ファイル追加、既存は note 追加のみ |

## Questions / Unknowns

- 既存 `.claude/rules/working-context.md` / `review-principles.md` / `mode-classification.md` に Rule 1〜5 を織り込むか、新規ファイルに集約するか
  - 採用方針: 新規 `.claude/rules/hybrid-architecture.md` に集約、既存は note で相互参照

## Mode判定

**モード**: `light`

**判定根拠**:
- 変更ファイル数: 5
- 受入基準数: 6
- リスク: 低
- **最終判定**: light

## 依存

- **前提**: #23-#27 と並行可能（完了後の再整合あり）
- **後続**: なし（本 TASK 完了で #22 Close 可能）
