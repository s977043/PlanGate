# TASK-0071 現在状態

> 更新: 2026-05-17 / 親 PBI（D-1 3分割）

## 今ここ

D-1 で S1+S2 / S3 / S4 の3分割を C-3 決定。**S1+S2 は TASK-0080（PR #254）
として実装・V-3 fix-loop + V-4 完了・MERGED**（Shadow Config 恒久対処＝
wiring契約正本 + apply script + doctor --check-settings + V-1/handoff
タスクロック + CI settings-drift）。本セッション通底の AC-8 摩擦に構造決着。

## 残

- **S3**（EH-3 メンテモード/SKIP_REASON）: s3a-design-note.md の C-3 確定3点
  待ち（①30分/延長別承認 ②env廃止・承認ファイル方式 ③SKIP_REASON未追認=
  CI required failure）。確定後に実装 PBI 起票
- **S4**（責務4分類 rules 正本化）: 独立・低リスク・着手可
- AC-8 wiring 実適用: `sh scripts/apply-claude-settings.sh`（ユーザー実行・
  TASK-0080 で 1 コマンド化済）

## 次アクション

1. ユーザー: `sh scripts/apply-claude-settings.sh` で AC-8/EH-9 wiring 適用
2. S3 の C-3 3点を確定 → S3 実装 PBI 起票
3. S4 実装 PBI 起票（独立着手可）
