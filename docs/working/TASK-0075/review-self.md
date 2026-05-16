---
task_id: TASK-0075
artifact_type: review-self
schema_version: 1
status: draft
---

# C-1 セルフレビュー — TASK-0075

## Plan（7項目）
| ID | 判定 | 備考 |
|----|------|------|
| 受入基準網羅 | PASS | AC-1〜8 が S1〜S7/V 対応 |
| Unknowns | PASS | opt-inフラグ形/seedsスキーマを S2・C-3 に分離 |
| スコープ制御 | PASS | #231/#200本体/skill自動更新/既定ON/#228再定義/他F を Out |
| テスト戦略 | PASS | 構造grep + opt-in文書トレース + 既定OFF回帰 |
| WB Output | PASS | 各 Step Output |
| 依存関係 | PASS | #228/#200/#231責務分離・他F非依存 |
| 動作検証自動化 | WARN | フェーズ定義主体。grep構造+文書トレースで担保（D-3） |

## ToDo（5項目）: 粒度/depends_on/CP/IronLaw/完了条件 全 PASS
## TestCases（3項目）: 紐付き PASS / Edge E1〜E4 PASS / 自動化 WARN（opt-in は文書トレース）

## 総合判定: CONDITIONAL（C-3 意思決定）

### D-1（C-3 必須・major）: opt-in フラグの具体形
候補: (i) コマンドオプション（`/ai-dev-workflow TASK-X retro` 明示実行）
(ii) pbi-input メタ `retro_enabled: true` (iii) config/env。**推奨: (i)
明示コマンド + (ii) メタ宣言の併用**（既定 OFF を最も自然に担保、env は
TASK-0071 自己付与リスク教訓で非推奨）。C-3 確定。

### D-2（C-3 判断・minor）: improvement-seeds.md スキーマ粒度
最小: `{date, task_id, 5項目テキスト, confirmed_by}`。冗長化を避け #200
集計が吸える最小に。C-3 で確認。

### D-3（C-3 判断・minor）: mode（high-risk か critical か）
ワークフロー定義変更は critical 相当だが、opt-in・既定OFF・handoff後の
純追加で影響限定 → high-risk 妥当。C-3 で最終確定。

### D-4（info）: 動作検証の限界
フェーズ定義主体のため grep 構造検証 + opt-in 文書トレース + 既定OFF 回帰で
担保。V-3 で設計妥当性補完。

### 推奨
D-1（フラグ形）中心、D-2/D-3 は推奨案確認。high-risk のため V-3 必須。
