# PBI INPUT PACKAGE: Verify & Handoff を標準 phase 化する（WF-05）

> 作成日: 2026-04-20
> PBI: [TASK-0021-E] Verify & Handoff を標準 phase 化する（WF-05）
> チケットURL: https://github.com/s977043/plangate/issues/27
> 親チケット: https://github.com/s977043/plangate/issues/22

---

## Context / Why

完了時に known issues / V2 候補 / handoff を **毎回必須出力**にする（逆輸入改善点③）。Rule 5 に従い、最終成果物を毎回 handoff に集約する。PlanGate は status.md で進行状態を持つが、「終わらせ方」を強化する。

---

## What（Scope）

### In scope

- `docs/workflows/05_verify_and_handoff.md` を #23 基盤から深化
- handoff package テンプレート作成: `docs/working/templates/handoff.md`（新規）
- 既存 status.md / current-state.md との役割分担明示
  - status.md = フェーズ履歴・完了記録のアーカイブ
  - current-state.md = 今どこにいて、次に何をするか
  - **handoff.md = 完了時の引き継ぎパッケージ（新規）**
- `acceptance-review` / `known-issues-log` Skill（#24）が handoff に統合される流れ定義
- V-1 受け入れ検査との関係を明示（V-1 は実装ゲート、handoff は完了後の資産）
- `.claude/rules/working-context.md` に handoff.md のセクション追加

### handoff package に含めるべき要素

- [ ] 要件適合確認結果（`acceptance-review` の出力）
- [ ] 既知課題一覧（`known-issues-log` の出力）
- [ ] V2 候補（今回の scope 外として認識した項目）
- [ ] 妥協点（なぜこの実装を選んだか / 諦めた選択肢）
- [ ] 引き継ぎ文書（次の担当者が読む想定のサマリ）
- [ ] テスト結果サマリ

### Out of scope

- Workflow 5 phase の基盤定義（#23 で対応済）
- 他 phase の深化
- handoff 自動生成ツール

---

## 受入基準

- [ ] WF-05 `05_verify_and_handoff.md` が標準 phase として深化
- [ ] handoff package テンプレート（`docs/working/templates/handoff.md`）作成
- [ ] 既存 status.md / current-state.md との役割分担明示
- [ ] `acceptance-review` / `known-issues-log` Skill 連携定義
- [ ] 全 PBI で handoff 必須であるルールが `.claude/rules/working-context.md` に記載
- [ ] V-1 受け入れ検査との関係が明示

---

## Notes from Refinement

### status / current-state / handoff の役割分担

| ファイル | 役割 | 更新タイミング | 読者 |
|---------|------|-------------|------|
| status.md | フェーズ履歴アーカイブ | フェーズ遷移毎 | 未来の担当者、監査 |
| current-state.md | 今の状態スナップショット | タスク完了毎 | 現担当者、セッション復旧時 |
| handoff.md | 完了時の引き継ぎパッケージ | TASK 完了時 | 次の担当者、レビュアー |

### 想定モード判定

**light**（低）を想定。

- 変更ファイル数: 4（05_verify_and_handoff.md、handoff.md テンプレ、.claude/rules 更新、サンプル）
- 変更種別: ドキュメント深化
- リスク: 低

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| handoff.md が status.md と重複で二重管理 | Medium | 役割分担表を冒頭に、相互リンクで関係性明示 |
| 全 PBI 必須化がオーバーヘッド | Low | テンプレに短縮版を用意、light モードでは簡易版で可 |
| acceptance-review / known-issues-log が #24 未完だと参照不可 | Medium | 本 TASK では名前参照のみ、#24 完了後に実体参照に切替 |

### Unknowns

- handoff.md のファイル命名規約（`handoff.md` 固定 vs `handoff-YYYY-MM-DD.md` 等）→ テンプレに記載

### Assumptions

- `docs/working/templates/` に追加可能
- `.claude/rules/working-context.md` の構造を壊さず節追加可能

---

## 依存

- **前提**: #23 / #24 / #25 完了
- **後続**: なし
