# TASK-0026 テストケース定義

> 生成日: 2026-04-20

## 受入基準 → TC マッピング

| 受入基準 | TC | 種別 |
|---------|-----|------|
| WF-03 独立 phase として深化 | TC-1 | Unit |
| design.md テンプレ作成 | TC-2 | Unit |
| solution-architect の出力フォーマットと一致 | TC-3 | Integration |
| plan.md との役割分担明示 | TC-4 | Unit |
| WF-03 挿入位置図作成 | TC-5 | Unit |
| サンプル design.md 1 件 | TC-6 | Unit |

## テストケース

### TC-1: 03_solution_design.md 深化

- **入力**: `docs/workflows/03_solution_design.md` を確認
- **期待出力**: #23 基盤の「目的/入力/完了条件/Skill/Agent」に加え、以下が含まれる
  - design artifact の 7 要素への言及
  - plan.md との役割分担
- **種別**: Unit

### TC-2: design.md テンプレ

- **入力**: `cat docs/working/templates/design.md`
- **期待出力**: 以下 7 要素の見出しが存在
  - モジュール構成
  - データフロー
  - 状態管理方針
  - 失敗時の扱い
  - テスト観点
  - 依存制約
  - 技術的妥協点
- **種別**: Unit

### TC-3: solution-architect 整合

- **入力**: #25 で作成される `.claude/agents/solution-architect.md` の「出力」セクションと design.md テンプレを突合（#25 未完の場合は本 TC スキップ）
- **期待出力**: 出力フォーマットが 7 要素と一致
- **種別**: Integration

### TC-4: plan.md との役割分担

- **入力**: `docs/workflows/03_solution_design.md` 内の役割分担表
- **期待出力**: plan.md と design.md の主目的・出力者・変化頻度・対象読者が表形式で記載
- **種別**: Unit

### TC-5: 挿入位置図

- **入力**: `docs/workflows/plangate-insertion-map.md`
- **期待出力**: A→B→C-1〜C-3→WF-03→D のフロー図（箇条書き or Mermaid）
- **種別**: Unit

### TC-6: サンプル design.md

- **入力**: `docs/working/TASK-0026/evidence/sample-design.md`
- **期待出力**: 7 要素全てに TASK-0023 を題材とした実例が記載
- **種別**: Unit

## エッジケース

### TC-E1: テンプレの空欄埋め可能性

- テンプレにプレースホルダー `{...}` があり、サンプルで実際の値に置換されていることを確認

### TC-E2: solution-architect 未完時の整合

- #25 未完の場合、本 TASK の TC-3 は「仮参照のみ」で PASS とし、#25 完了後に再検証
