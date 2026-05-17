# TASK-0071 INDEX

> 生成日: 2026-05-17 / 更新: 2026-05-17
> フェーズ: 親 PBI（D-1 3分割）— **S1+S2 完了**（TASK-0080 / PR #254 MERGED）/ S3・S4 残

## スライス進捗（D-1 確定: S1+S2 / S3 / S4 の3分割）

| スライス | 内容 | 実装 PBI | 状態 |
| --- | --- | --- | --- |
| **S1+S2** | Manual Gate（wiring契約+apply script+doctor --check-settings）+ タスクロック + CI settings-drift | TASK-0080 / **PR #254** | ✅ **MERGED**（`526470a`）|
| **S3** | EH-3 メンテモード / SKIP_REASON 例外申請 | 未起票 | C-3 確定待ち（S3a の3点: ①30分/最大30分・延長別承認 ②env廃止・承認ファイル方式 ③SKIP_REASON未追認=CI required failure）|
| **S4** | 責務4分類（AI/Human/CI/Workflow-owned）rules 正本化 | 未起票 | 着手可（独立・低リスク）|

## ファイル一覧

| ファイル | 状態 |
| --- | --- |
| pbi-input.md | done（親計画）|
| plan.md | done（S1〜S4 設計）|
| review-external.md | done（C-2 / S3 用 3点）|
| s3a-design-note.md | done（S3 設計・C-3確定待ち）|
| handoff.md | S3/S4 完了時に親 handoff 発行 |
