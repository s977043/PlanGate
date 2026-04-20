# TASK-0026 EXECUTION PLAN

> 生成日: 2026-04-20
> PBI: [TASK-0021-D] Solution Design phase を独立させる（WF-03）
> チケットURL: https://github.com/s977043/plangate/issues/26

## Goal

WF-03 Solution Design を独立 phase として深化し、`design.md` テンプレートと sample、plan.md との役割分担を明示する。

## Constraints / Non-goals

- #23 で作成した `docs/workflows/03_solution_design.md` を上書き深化
- plan.md / design.md の共存（plan.md は削除・改変しない）
- **Non-goals**: 他 phase 深化、設計レビュー自動化

## Approach Overview

1. #23 の 03_solution_design.md を読み、深化ポイント特定
2. design.md テンプレート作成（7 要素）
3. solution-architect（#25）の出力フォーマット整合
4. PlanGate 既存フロー図に WF-03 挿入位置を追加
5. サンプル design.md 作成

## Work Breakdown

### Step 1: 既存 WF-03 基盤確認 + 深化ポイント洗い出し

- **Output**: `docs/working/TASK-0026/evidence/wf03-enhancement-points.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: #23 の基盤記述と深化差分が明示

### Step 2: design.md テンプレート作成

- **Output**: `docs/working/templates/design.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 7 要素（モジュール構成 / データフロー / 状態管理 / エラーパス / テスト観点 / 依存制約 / 技術的妥協点）全て含む

### Step 3: 03_solution_design.md 深化

- **Output**: `docs/workflows/03_solution_design.md` 更新
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: Rule 1 遵守（実装ノウハウなし）を維持しつつ、入力・出力を詳細化

### Step 4: solution-architect との整合

- **Output**: #25 で予定される solution-architect agent の出力フォーマットと design.md テンプレの対応確認
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 出力フォーマットが design.md テンプレと一致（#25 未完の場合は名前参照のみ）

### Step 5: PlanGate フロー図に WF-03 挿入位置追加

- **Output**: `docs/workflows/plangate-insertion-map.md`
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: A→B→C-1〜C-3→**WF-03**→D のフロー図

### Step 6: サンプル design.md 作成

- **Output**: `docs/working/TASK-0026/evidence/sample-design.md`（題材: TASK-0023）
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: 7 要素全てに実例が書かれている

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
| --- | --- | --- |
| 修正 | docs/workflows/03_solution_design.md | 深化（WF-03 独立） |
| 新規 | docs/working/templates/design.md | テンプレート |
| 新規 | docs/workflows/plangate-insertion-map.md | 挿入位置図 |
| 新規 | docs/working/TASK-0026/evidence/wf03-enhancement-points.md | 深化ポイント |
| 新規 | docs/working/TASK-0026/evidence/sample-design.md | サンプル |

## Testing Strategy

- **Unit**: 各ファイル存在、必須セクション
- **Integration**: design.md と plan.md の役割分担表が一貫
- **Verification**:
  - design.md テンプレに 7 要素見出しが全て存在
  - 挿入位置図に WF-03 が A/B/C/D と接続
  - サンプルが全 7 要素を埋めている

## Risks & Mitigations

| リスク | 対策 |
| --- | --- |
| plan.md と design.md の境界曖昧 | Step 3 で役割分担表を明記 |
| solution-architect と不整合 | #25 完了時に再確認、本 TASK 中は仮参照 |

## Questions / Unknowns

- サンプル design.md の題材: TASK-0023 を採用（Workflow 基盤定義なので設計構造を示しやすい）

## Mode判定

**モード**: `light`

**判定根拠**:
- 変更ファイル数: 5 → light
- 受入基準数: 6 → light/standard 境界、ドキュメント系のため light
- リスク: 低 → light
- **最終判定**: light

## 依存

- **前提**: #23 / #24 / #25 完了
- **後続**: なし
