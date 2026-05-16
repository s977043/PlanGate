---
task_id: TASK-0075
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0075

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5 |
| AC-6 | TC-6 |
| AC-7 | TC-7 |
| AC-8 | TC-8 |

## テストケース
- **TC-1**: 06_retro.md が存在し必須セクション（目的/入力/完了条件/呼ぶSkill/主担当）を持ち、execution-sequence/README に R が反映
- **TC-2**: opt-in 正本に「既定 OFF・明示フラグでのみ発火」が定義され、フラグ無しで R 非発火が文書トレース可能
- **TC-3**: ドラフトは #228 固定5項目・スコアリングしない（#231 と責務非重複）が明記
- **TC-4**: improvement-seeds.md の配置・append-only・run またぎ累積スキーマが定義
- **TC-5**: 人間 confirm/skip 1行で確定・自動はドラフトのみ（承認境界維持）が明記
- **TC-6**: #200 期間集計が improvement-seeds.md を入力源にする接続点が定義
- **TC-7**: #228 を再定義せず参照（テンプレ仕様は #228 準拠）と明記
- **TC-8**: 既定 OFF で既存 workflow/run 挙動不変、doc 整合性回帰なし

## エッジケース
- E1: opt-in フラグ未指定 → R は完全に発火しない（既存フロー不変）
- E2: confirm されない（人間 skip）→ seeds に追記せず run は正常終了
- E3: improvement-seeds.md 不在 → 初回 confirm 時に作成（append-only 維持）
- E4: critical インシデント等で handoff 事後追補時も R は opt-in のまま（強制しない）
