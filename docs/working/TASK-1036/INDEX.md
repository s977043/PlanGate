# TASK-1036 INDEX

> 最終更新: 2026-08-12 05:10 UTC

## チケット概要

`PG_T26_NO_RECURSE` の呼び出し元 env 漏れを harness 経路で無害化し（案 (d): `ta-26` harness 分岐 unset）、漏れを検出する回帰テスト（`ta-62` 新規）を変異注入付きで追加する。消える TC 群は mass-delete guard 回帰テスト（#877/#914/#970）を含む「静かに通る失敗」クラス。

## 現在のフェーズ

C-1 完了・Human C-3 待ち（c3.json 初回発行が必要）

## 次のアクション

- 👤 H-01: C-3 判断（案 (d) / Mode=standard / T1036-TC-D の実行時間設計 / AC 候補-1 採否）→ 確定 plan_hash に c3.json 初回発行
- 🤖 その後 T-03（RED）から exec 開始

## ファイルマップ

| ファイル | 説明 |
|---|---|
| `pbi-input.md` | PBI INPUT PACKAGE（base `408cebb` / U-1・U-3 実走決着済み） |
| `plan.md` | 実行計画（base `48f6971` で前提を全数再実測済み） |
| `todo.md` | Human/Agent タスクと依存順 |
| `test-cases.md` | AC ↔ TC マッピングと変異注入設計 |
| `review-self.md` | C-1 セルフレビュー（17 項目） |
| `current-state.md` | 現在状態スナップショット |
| `decision-log.jsonl` | 判断履歴（append-only） |

## 変更ファイル一覧（実装 scope）

`tests/extras/ta-26-plugin-sync.sh`（3-4 行）/ `tests/extras/ta-62-t26-recurse-env-guard.sh`（新規）/ `tests/extras/README.md`（規約 7/8 追記）。現時点の差分は Plan Package のみ。HO 対象パスに触れない。
