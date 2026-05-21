# TASK-0107 review-self.md — C-1 セルフレビュー（17 項目）

> **Phase**: C-1（plan / todo / test-cases に対する AI セルフレビュー）
> **Date**: 2026-05-22
> **対象**: plan.md / todo.md / test-cases.md（R-009〜R-013 反映後）
> **Mode**: high-risk → **17 項目フルチェック**（mode-classification.md）
> **Note**: 本 C-1 は C-2 R3（Codex + Gemini）の事前評価と並行実施。C-2 R3 で REJECT 出された R-009〜R-013 を反映後の自己評価。

---

## 1. 総合判定

**PASS**（17 項目すべて PASS、blocker 0）

C-2 R3 で Codex が指摘した R-009〜R-013 を全て反映済。Gemini は R3 で APPROVE 済。R-001〜R-013 の指摘がそれぞれ pbi-input.md r1 / plan.md / todo.md r1 / test-cases.md / review-external.md に整合した形で反映されていることを確認。

---

## 2. Plan チェック（7 項目）

### C1-PLAN-01 受入基準網羅性
- **判定**: PASS
- **根拠**: plan.md Work Breakdown の Step 1〜8 が AC-1〜AC-13 を網羅
  - AC-1 (起動) → Step 4 Command
  - AC-2〜AC-5 (doctor 連携・提示のみ・再検証・サマリ) → Step 5 Agent
  - AC-6 (Skill 5 要素) → Step 3
  - AC-7 (Rule 1-5) → Step 3/4/5 共通
  - AC-8 (handoff) → Step 8
  - AC-9 (frontmatter 一致) → Step 5
  - AC-10 (settings.json diff = 0) → Step 4
  - AC-11/12 (永続ロック・check-settings PASS) → Step 6
  - AC-13 (脱出経路) → Step 5/6

### C1-PLAN-02 Unknowns 処理
- **判定**: PASS
- **根拠**: U1/U3/U4/U5/U6/U7 すべて plan.md §Questions / Unknowns に解決 Step が明示（U6/U1/U4/U7 は Step 1 で確定、U3 は Step 6、U5 は Step 3）

### C1-PLAN-03 スコープ制御
- **判定**: PASS
- **根拠**: plan.md §Constraints / Non-goals に test 可能な境界（doctor 本体改修禁止 / Hook 追加禁止 / 再設定 v2 範囲 等）が明示。AC-10 で settings.json diff = 0 を機械検証

### C1-PLAN-04 テスト戦略
- **判定**: PASS
- **根拠**: plan.md §Testing Strategy に Mock A/B/C の 3 系統 + static/grep + integration/gate test の組合せが明記

### C1-PLAN-05 Work Breakdown Output
- **判定**: PASS
- **根拠**: 各 Step に明確な Output（contract-notes.md / SKILL.md / Command md / Agent md / status.md+jsonl / test sh / handoff.md）

### C1-PLAN-06 依存関係
- **判定**: PASS
- **根拠**: Step 1/2 → Step 3/4/5（並列可）→ Step 6 → Step 7 → Step 8 の依存が一貫

### C1-PLAN-07 動作検証自動化
- **判定**: PASS
- **根拠**: test-cases.md §「既知の自動化制約」+ 各 TC 種別（grep / unit mock / integration / manual）で自動化と手動の切り分けが明示

---

## 3. ToDo チェック（5 項目）

### C1-TODO-01 タスク粒度
- **判定**: PASS
- **根拠**: T-01〜T-08 + G-C3 が 1 タスク 1 出力で揃う

### C1-TODO-02 depends_on 設定
- **判定**: PASS
- **根拠**: R-009 反映後、T-03〜T-08 の depends_on に G-C3 が明示。依存関係グラフが plan の Step 順と一貫

### C1-TODO-03 チェックポイント設定
- **判定**: PASS
- **根拠**: 各 T-NN / G-C3 に 🚩 Checkpoint が記載

### C1-TODO-04 Iron Law 遵守
- **判定**: PASS
- **根拠**: R-010 反映後、L-0 / V-1 / V-2 / V-3 / PR は §workflow-conductor 後続フェーズ欄に分離。実装 todo（T-01〜T-08）には含まれない（working-context.md Iron Law 準拠）

### C1-TODO-05 完了条件
- **判定**: PASS
- **根拠**: 各 T の Output と Checkpoint が test 可能（Bash grep / diff / file existence / jsonl パース）

---

## 4. TestCases チェック（3 項目）

### C1-TEST-01 受入基準との紐付き
- **判定**: PASS
- **根拠**: test-cases.md §マッピング表で AC-1〜AC-13 ⇄ TC-01〜TC-22 が 1:N で完備

### C1-TEST-02 Edge case 網羅
- **判定**: PASS
- **根拠**: EC-01（TASK ID 不明時）/ EC-02（schema 変更）/ EC-03（同時起動 v1 unsupported）/ EC-04（doctor 起動失敗）を網羅。R-013 反映で EC-03 が「unsupported 検出」に明確化

### C1-TEST-03 自動化可否
- **判定**: PASS
- **根拠**: R-012 反映後、TC-01/06/07/08/21/22 の種別フィールドに `manual` が反映済（grep verify: manual 出現 8 件）

---

## 5. 統合チェック（2 項目）

### C1-INT-01 Mode 整合（high-risk）
- **判定**: PASS
- **根拠**: R-011 反映後、plan.md §Mode 判定 / フェーズ適用が `high-risk` + `lite_eligible=false` で一貫。「lite C-2」表記を撤廃し「R1+R2+R3 実施」に修正済。Hardening Override 適用も明記

### C1-INT-02 Workflow-owned 永続ロック統合
- **判定**: PASS
- **根拠**: R-001 反映で pbi-input.md r1 §1責務表 + §3 AC-11/12 + §4 設計原則 + plan.md Step 6 + todo.md T-06 + test-cases.md TC-18/19/20 が一貫。`doctor --check-settings PASS` ゲートが V-1/handoff 完了条件として明示

---

## 6. 指摘事項

なし（blocker 0）。

R-009〜R-013 反映により Codex R3 の major × 4 / minor × 1 はすべて解消。Gemini R3 info × 2（R-009/R-010 注: 別採番のため本 review-self では番号衝突回避のため言及のみ）は info レベルで C-3 後の exec 中に吸収可能。

## 7. C-3 ゲート進行可否

**ready for C-3**

主要前提:
- `lite_eligible=false` のため **同期 C-3 必須**（Hardening Override 適用）
- C-3 の判定主体は **Human**（責務4分類 AI-owned 不可）
- 承認後 `docs/working/TASK-0107/approvals/c3.json` 発行 → `bin/plangate exec` で T-01 開始

