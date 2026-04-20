# PBI INPUT PACKAGE: Rule 1〜5 と PlanGate ガバナンス層の統合ルールを明文化

> 作成日: 2026-04-20
> PBI: [TASK-0021-F] Rule 1〜5 と PlanGate ガバナンス層の統合ルールを明文化
> チケットURL: https://github.com/s977043/plangate/issues/28
> 親チケット: https://github.com/s977043/plangate/issues/22

---

## Context / Why

ハイブリッドアーキテクチャの **設計原則（Rule 1〜5）** と、**CLAUDE.md / Skill / Hook の境界ルール** を明文化し、PlanGate ガバナンス層との統合方針を確立する。既存 PlanGate v5/v6 ドキュメントとの整合も取る。

本 TASK は #22 ハイブリッドアーキテクチャの **統合レイヤ**。#23〜#27 と並行進行可能だが、最終的に全 sub-issue を包括する位置付け。

---

## What（Scope）

### In scope

- `docs/plangate-v7-hybrid.md`（仮、v7 設計ドキュメント）を新設
- Rule 1〜5 を明記
- CLAUDE.md / Skill / Hook の境界ルールを明記
- PlanGate ガバナンス層（GATE / STATUS / APPROVAL / ARTIFACT）と実行層（Workflow / Skill / Agent）の接続方法を定義
- 既存 `docs/plangate.md` / `docs/plangate-v6-roadmap.md` との整合
- `.claude/rules/` に必要なルールファイルを追加 or 既存ファイルに統合

### Rule 1〜5（再構築ルール）

| Rule | 内容 |
|---|---|
| Rule 1 | Workflow は順序と完了条件だけを持つ。実装ノウハウは書かない |
| Rule 2 | Skill は再利用単位に限定する。案件固有の話を入れない |
| Rule 3 | Agent は責務だけを持つ。ツール固有手順や案件固有仕様は持たせない |
| Rule 4 | 案件固有情報は CLAUDE.md に寄せる。Agent や Skill に埋め込まない |
| Rule 5 | 最終成果物は毎回 handoff に集約する。仕様 / 既知課題 / V2候補 / 確認結果を残す |

### CLAUDE.md / Skill / Hook の境界ルール

| 対象 | 役割 | 置き場所 |
|---|---|---|
| CLAUDE.md | 案件固有情報、常時必要な文脈 | プロジェクトルート |
| Skill | 再利用可能な手順・観点（必要時だけ読み込む） | `.claude/commands/` or `.claude/skills/` |
| Hook | 強制力が必要な決定論的制御 | `.claude/settings.json` の hooks |

### ガバナンス層と実行層の接続

| 統制層（PlanGate） | 実行層（Workflow/Skill/Agent） |
|---|---|
| GATE（計画を止める） | Workflow phase 完了条件で制御 |
| STATUS（状態を保存） | status.md + current-state.md + handoff.md |
| APPROVAL（承認管理） | C-3 ゲート / C-4 ゲート |
| ARTIFACT（成果物正本化） | plan.md / design.md / handoff.md |

### Out of scope

- Workflow / Skill / Agent の実体配置（#23 / #24 / #25 で対応）
- design.md / handoff.md のテンプレ作成（#26 / #27 で対応）
- PlanGate v5/v6 ドキュメントの全面改訂（差分・位置付けのみ記載）

---

## 受入基準

- [ ] `docs/plangate-v7-hybrid.md` が作成されている
- [ ] Rule 1〜5 が明記されている
- [ ] CLAUDE.md / Skill / Hook の境界ルールが明記されている
- [ ] ガバナンス層と実行層の接続表が含まれる
- [ ] 既存 v5/v6 との整合（差分・位置付け）が明記
- [ ] `.claude/rules/` の該当ファイルが更新されている（または新規追加）

---

## Notes from Refinement

### v7 の位置付け

- v5: 現行（ゲート型開発ワークフロー）
- v6: ロードマップ（context-engineering 統合等）
- **v7: ハイブリッドアーキテクチャ**（#22 TASK-0021 で導入）

### 想定モード判定

**light**（低）を想定。

- 変更ファイル数: 3-4（v7 ドキュメント、rules 追加、既存ドキュメント note 追加）
- 変更種別: ドキュメント追加・整合
- リスク: 低（既存構造を壊さず追加）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| 既存 v5/v6 ドキュメントとの記述矛盾 | Medium | 差分テーブル・位置付け明記、矛盾箇所は本 TASK で調整 |
| Rule 1〜5 が他 TASK（#23〜#27）で参照されるが未完のまま | Medium | 本 TASK は他と並行可能だが、最終整合のため #23-#27 完了後にも再確認 |
| `.claude/rules/` への追加が既存運用を変える | Low | 新規ルールファイル追加、既存は変更しない方針 |

### Unknowns

- v7 ドキュメントのファイル名: `docs/plangate-v7-hybrid.md` で確定
- rules 追加先: 新規 `.claude/rules/hybrid-architecture.md` 推奨

### Assumptions

- 既存 v5/v6 ドキュメントは `docs/` 配下にある
- `.claude/rules/` への追加で既存運用を壊さない

---

## 依存

- **前提**: #23-#27 と並行（最終整合のため後半で実施推奨）
- **後続**: なし（本 TASK 完了で #22 親 Close 可能）
