---
task_id: TASK-0074
artifact_type: review-self
schema_version: 1
status: draft
---

# C-1 セルフレビュー — TASK-0074

## Plan（7項目）
| ID | 判定 | 備考 |
|----|------|------|
| 受入基準網羅 | PASS | AC-1〜8 が S1〜S6/V 対応 |
| Unknowns | PASS | UI判定方式を S2/C-3 に分離 |
| スコープ制御 | PASS | Figma自動取得/視覚回帰自動化/他F を Out |
| テスト戦略 | PASS | init生成回帰 + grep構造 + 文書検証 |
| WB Output | PASS | 各 Step Output |
| 依存関係 | PASS | 他F非依存・#236参照 |
| 動作検証自動化 | PASS | init 生成回帰で機械化可 |

## ToDo（5項目）: 粒度/depends_on/CP/IronLaw/完了条件 全 PASS
## TestCases（3項目）: 紐付き PASS / Edge E1〜E3 PASS / 自動化 PASS（init 生成 + grep）

## 総合判定: CONDITIONAL（C-3 軽微意思決定）

### D-1（C-3 判断・minor）: UI タスク判定トリガ方式
候補: (i) plan メタからの自動推定（変更ファイルが components/styles 等） 
(ii) pbi-input で人手宣言（is_ui_task: true）。**推奨: (ii) 人手宣言を
基本 + (i) を補助ヒント**（自動のみは誤判定でゲート回避/過剰要求の双方
リスク。#236 は「曖昧進行もゲート回避も防ぐ」が要件）。C-3 で確認。

### D-2（info）: テンプレ肥大の認知負荷
条件付き見出し + 「非UIは本節削除可」明記 + 参照なし明示で緩和。plan の
Risk R1/R3 に記載済み。strong enforcement を入れないため標準で許容範囲。

### 推奨
D-1（判定方式）のみ C-3 軽微確認。standard モードのため C-2 任意・V-3 実施。
