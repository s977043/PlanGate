---
task_id: TASK-0077
artifact_type: review-self
schema_version: 1
status: draft
---

# C-1 セルフレビュー — TASK-0077（計画のみ先行）

## Plan（7項目）
| ID | 判定 | 備考 |
|----|------|------|
| 受入基準網羅 | PASS | AC-1〜7 が S1〜S5/検証 対応 |
| Unknowns | PASS | Lite 軸/降格既定値を S2/S3/C-3 分離 |
| スコープ制御 | PASS | 実装を明示 Out（計画のみ）。B/C・#213実装本体・TASK-0071重複を Out |
| テスト戦略 | PASS | 設計構造 grep + rules 無改変 diff 確認 |
| WB Output | PASS | 各 Step Output、実装は範囲外と明記 |
| 依存関係 | PASS | C-3 停止条項・TASK-0076 独立・TASK-0071 境界 |
| 動作検証自動化 | PASS | 計画成果物の構造検証で機械化可 |

## ToDo（5項目）: 全 PASS（C-3 停止条件明記）
## TestCases（3項目）: 紐付き PASS / Edge E1〜E3 PASS / 自動化 PASS

## 総合判定: CONDITIONAL（C-3 = 承認境界変更の是非そのものを人間判断）

### 本 PBI の C-3 の特殊性
通常 C-3 は「計画を承認し exec へ」だが、本 PBI の C-3 は
**「承認境界を opt-in で可変にする設計を是とするか」という統制根幹の判断**。
APPROVE でも実装は自動継続せず、別 PBI/phase の起票可否を C-3 で別途決定
（plan に不変条項として記載済）。

### D-1（C-3 必須・critical）: Lite は mode-classification の直交軸か内包か
直交（Lite/Standard を mode と別軸）か、内包（既存 5 mode に Lite フラグ）か。
**推奨: 内包（mode 判定に "lite_eligible" 派生フラグを足す）**＝二重分類を
避け mode-classification 正本性を維持。C-3 で確定。

### D-2（C-3 必須・critical）: C-3 降格の既定と適用厳格度
「C-1 PASS かつ C-2 critical/major=0 かつ Lite」を満たしても **既定は同期
（従来）**、明示 opt-in 時のみ非同期降格。reject 即時巻き戻し + 監査必須。
C-3 で承認境界後退許容度を人間判断。

### 推奨
本 PBI は **C-3 提示で停止**。D-1/D-2 と「承認境界可変化の是非」を人間が
判断。critical のため C-2 外部レビューを計画に対して実施。
