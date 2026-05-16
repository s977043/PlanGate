---
task_id: TASK-0080
artifact_type: review-self
schema_version: 1
status: draft
---

# C-1 セルフレビュー — TASK-0080

## Plan（7項目）
| ID | 判定 | 備考 |
|----|------|------|
| 受入基準網羅 | PASS | AC-1〜7 が S1〜S6/V 対応 |
| Unknowns | PASS | タスクロック強制層を S1/C-3 に分離 |
| スコープ制御 | PASS | S3/S4・settings実適用・F5AD/#213 を Out。self-mod ガード受容 |
| テスト戦略 | PASS | doctor 適用/未適用 + ロックシナリオ + 非破壊回帰 + 冪等 |
| WB Output | PASS | 各 Step Output |
| 依存関係 | PASS | TASK-0071(#244)設計・#242/#243マージ済（充足） |
| 動作検証自動化 | PASS | doctor exit / CI job / hook テストで機械化 |

## ToDo（5項目）: 全 PASS（V-4 critical 含む）
## TestCases（3項目）: 紐付き PASS / Edge E1〜E4 PASS / 自動化 PASS

## 総合判定: CONDITIONAL（C-3 で実装是非 + 1点意思決定）

### D-1（C-3 必須・critical）: タスクロックの強制層
候補: (i) Hook EH-x（PreToolUse/手動 CLI で handoff/V-1 完了を block）
(ii) doctor exit 連動（V-1/handoff 前に doctor --check-settings 必須化）
(iii) workflow 完了条件（05_verify_and_handoff の DoD に追加）。
**推奨: (ii)+(iii) 併用**（V-1/handoff の DoD に doctor --check-settings PASS
を必須化＝既存ゲート機構に乗せる。新規 Hook を増やさず決定論）。Shadow
Config 防止の本質は「適用したと誤認できない」こと。C-3 で確定。

### D-2（info）: settings 実適用は AI 不可（恒久制約）
本 PBI は script+検証+ロックを提供。適用自体はユーザー実行（self-mod
ガード）。AC-2 の script はユーザーが `!` 等で実行する前提（plan/handoff 明記）。

### 留意
- AC-6（適用済みで誤検出ゼロ）が最重要。正常完了を阻害しない回帰を V-1/S6 で機械保証
- critical のため V-3+V-4 必須

### 推奨
D-1（ロック強制層）を C-3 の中心意思決定に。設計は TASK-0071 確定済、
本 PBI は S1+S2 実装スライス。
