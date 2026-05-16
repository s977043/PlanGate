---
task_id: TASK-0076
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0076

> F5-BC: C-2 責務分離 + C-2 指摘の plan 反映差分管理
> 起源（field feedback）: #234-B / #234-C（関連: #227 / #200 / #230）

## Context / Why

#234 field report の B/C:

- **B**: C-2 レビュアが plan 検証のため実コードを精読し、exec で同ファイルを
  再精読（調査二重化）。plan レビューと実装レビューの責務境界が曖昧で、
  plan 段階のトークン/時間が膨張
- **C**: C-2 + 外部指摘を plan/todo/test-cases に都度反映し計画ファイルへ
  8+ 回編集。指摘→反映→再指摘の往復で版管理困難・監査性低下・反映自体が
  ゲートコスト化（過去に設計変更3回×8ファイル一括書換も観測）

いずれも「ゲートの価値は保ちつつ運用コストを下げる」改善。承認境界・
レビュー観点そのものは変えない（プロセスの責務分界と差分管理のみ）。

## What — Scope

### In scope

- **B: C-2 を 2 レーンに分離**
  - 設計妥当性レーン: plan の論理 / 受入基準網羅 / スコープのみ（実コード読まない）
  - コードベース整合レーン: 既存パターン探索を 1 エージェントに集約
  - 実装詳細レビューは V-3 に寄せる（責務契約として明文化）
  - review-principles.md / C-2 レビュア責務契約に「何を読み何を読まないか」定義
- **C: 指摘の plan 反映差分管理**
  - 指摘は `review-external.md`（追記専用ログ）に集約
  - 計画本体（plan/todo/test-cases）は **exec 開始時に 1 回だけ確定反映**
  - 差分追跡: 「指摘ID → 反映コミット」を記録（監査可能性原則と整合）
  - working-context.md / 該当 workflow に反映フロー定義

### Out of scope

- A: Lite/Standard 分岐 / D: C-3 降格 → TASK-0077（F5-AD・別 PBI）
- #227 river-reviewer の実装本体（責務契約の定義のみ・接続は参照）
- #200/#230 のイベント実装本体（接続点の定義のみ）
- 承認境界・5レビュー観点の変更（プロセス分界のみ）

## Acceptance Criteria

- [ ] AC-1: C-2 が「設計妥当性」「コードベース整合」の 2 レーンに分離定義される
- [ ] AC-2: 設計妥当性レーンは実コードを読まない／コードベース整合は 1 エージェント集約／実装詳細は V-3 へ、が責務契約として明文化される
- [ ] AC-3: review-principles.md（または C-2 責務正本）に B の責務分界が反映され既存観点と矛盾しない
- [ ] AC-4: C-2 指摘は review-external.md 追記専用に集約する運用が定義される
- [ ] AC-5: 計画本体は exec 開始時に 1 回だけ確定反映する運用が定義される
- [ ] AC-6: 「指摘ID → 反映コミット」の差分追跡方式が定義され #200/#230 接続点が明記される
- [ ] AC-7: working-context.md / 該当 workflow に C の反映フローが反映される
- [ ] AC-8: 既存 hook テスト / doc 整合性に回帰がない（承認境界・観点不変）

## Notes from Refinement

- B は #227（river-reviewer 標準 IF）に「C-2 レビュア責務契約」を載せる要望
- C は #200（Reporting）/ #230（Gate Event Normalization）に
  「review-finding → plan-revision トレース」イベントとして接続
- 承認境界・5観点は不変（#234 の「ゲート価値は残す」前提）

## Estimation Evidence

**Risks**: レビュー運用変更。責務分界誤りで C-2 が形骸化 → 既存観点不変を明記
**Unknowns**: 差分追跡の具体形（指摘ID 採番 / コミットtrailer / events）→ C-3
**Assumptions**: プロセス/doc 変更主体で強制 Hook 不要。Mode 想定: standard
