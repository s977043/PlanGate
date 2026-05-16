---
task_id: TASK-0077
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0077（計画成果物の検証）

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5 |
| AC-6 | TC-6 |
| AC-7 | TC-7 |

## テストケース（設計ドキュメント構造検証）
- **TC-1**: 設計に Lite/Standard 判定軸 + 自動推定 + 人間 override が定義
- **TC-2**: Lite ゲート構成（C-1+外部1本+C-3）と mode-classification 関係が整理
- **TC-3**: C-3 降格条件 + 同期/非同期 opt-in が「承認境界撤廃しない」形で定義
- **TC-4**: TASK-0071 との責務境界表が存在し重複・矛盾なし
- **TC-5**: 承認境界後退リスク + 緩和（opt-in既定OFF/reject巻戻し/監査）明記
- **TC-6**: #213 Plan Health / #226 接続点が定義
- **TC-7**: 「実装は C-3 承認後の別 phase」と明記され計画段階で停止する条項あり

## エッジケース
- E1: Lite 判定が誤って大規模 PBI を Lite 化 → 人間 override 必須・既定 Standard
- E2: C-3 降格中に exec 並行で reject → 巻き戻し手順が設計に存在
- E3: opt-in 未指定 → 従来 full ゲート（既定 OFF＝挙動不変）
