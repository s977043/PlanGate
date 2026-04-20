# PBI INPUT PACKAGE: Solution Design phase を独立させる（WF-03）

> 作成日: 2026-04-20
> PBI: [TASK-0021-D] Solution Design phase を独立させる（WF-03）
> チケットURL: https://github.com/s977043/plangate/issues/26
> 親チケット: https://github.com/s977043/plangate/issues/22

---

## Context / Why

要件と実装の間の設計抜けを減らすため、**Solution Design を独立フェーズ化**する（逆輸入改善点②）。PlanGate は「計画」は強いが、実装前の設計 artifact が弱い。WF-03 を深化させることで、以下を実装前に明文化できる:

- モジュール境界
- 状態管理方針
- エラーパス
- テスト観点
- 依存制約

---

## What（Scope）

### In scope

- `docs/workflows/03_solution_design.md` を #23 で作成した基盤から深化
- 設計 artifact テンプレート作成: `docs/working/templates/design.md`（新規）
- `solution-architect` Agent（#25 で作成）の出力フォーマットを定義
- PlanGate の plan.md との役割分担を明示
  - plan.md = やる順番・完了条件（Workflow）
  - **design.md = 実装構造の決定事項（Solution Design の成果物）**
- `architecture-sketch` / `risk-assessment` Skill（#24 で整備）の出力が design.md にどう取り込まれるかを定義
- 既存 PlanGate フロー（A→B→C-1〜C-3→D）における WF-03 の挿入位置を図示
- サンプル design.md を 1 件作成（既存 TASK-0023 などを題材に）

### 設計 artifact に含めるべき要素

- [ ] モジュール構成（境界と責務）
- [ ] データフロー
- [ ] 状態管理方針
- [ ] 失敗時の扱い（エラーパス / リトライ / フォールバック）
- [ ] テスト観点（Unit / Integration / E2E の分担）
- [ ] 依存ライブラリ制約
- [ ] 技術的妥協点（V1 で諦める範囲）

### Out of scope

- Workflow 5 phase の基盤定義（#23 で対応済）
- 他の phase（WF-01/02/04/05）の深化
- 設計レビュー自動化

---

## 受入基準

- [ ] WF-03 `03_solution_design.md` が独立 phase として深化されている
- [ ] 設計 artifact テンプレート（`docs/working/templates/design.md`）が作成
- [ ] `solution-architect` Agent の出力フォーマットと一致
- [ ] plan.md との役割分担が明示
- [ ] 既存 PlanGate フロー（A→B→C-1〜C-3→D）における WF-03 の挿入位置が示されている
- [ ] サンプル design.md が 1 件作成されている

---

## Notes from Refinement

### plan.md と design.md の役割分担

| 観点 | plan.md | design.md |
|-----|---------|-----------|
| 主目的 | やる順番・完了条件 | 実装構造の決定事項 |
| 出力者 | spec-writer / workflow-conductor | solution-architect |
| 変化頻度 | チケット毎 | チケット毎 + アーキ変更時 |
| 対象読者 | 実装者・レビュアー・PM | 実装者・アーキテクト |

### 想定モード判定

**light**（低）を想定。

- 変更ファイル数: 4（03_solution_design.md 更新、design.md テンプレ、サンプル、挿入位置図）
- 変更種別: ドキュメント深化
- リスク: 低

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| plan.md と design.md の境界が曖昧で二重管理 | Medium | 役割分担表を冒頭に掲載、例示で明確化 |
| solution-architect Agent 出力と design.md が乖離 | Medium | #25 完了後に整合確認、乖離あれば修正 |
| サンプル design.md が具体的すぎて再利用困難 | Low | テンプレはそのまま、サンプルは「参考例」として記載 |

### Unknowns

- design.md の最適な section 粒度（実運用で調整）

### Assumptions

- `docs/working/templates/` が既存で、design.md 追加で整合

---

## 依存

- **前提**: #23（Workflow 定義）、#24（Skill）、#25（Agent）完了
- **後続**: なし
