# TASK-0120 Handoff — gh account pinning helper

> Session Retro (PR #401) Try #2 由来 / Mode: light / WF-05

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | TC | 判定 |
|----|------|-----|------|
| AC-1 | switch 後 gh 実行 | TC-01/01b | ✅ PASS |
| AC-2 | 冪等 (既に s977043 なら skip) | TC-02 | ✅ PASS |
| AC-3 | doc 整備 | TC-03 | ✅ PASS |
| AC-4 | SessionStart hook 責務整理 | TC-04 | ✅ PASS |
| AC-5 | ta-23 | TC-05 | ✅ PASS (TA-23 全 case) |
| AC-6 | shellcheck + regression | TC-06/06b | ✅ PASS (shellcheck PASS / 203 passed 0 failed) |

## 2. 既知課題

- ラッパは**明示的に呼ぶ**運用（`sh scripts/gh-s977043.sh <args>`）。透過 alias 化
  （`gh` を自動ラップ）は scope 外（誤爆・他リポジトリ影響を避けるため）。

## 3. V2 候補

- shell alias / function 提供（opt-in、`.zshrc` 等への登録ガイド）
- gh-pin-account.sh と本ラッパの共通 core 抽出（switch ロジック重複の DRY 化）

## 4. 妥協点

- 権限不足/未登録環境では switch 失敗を **warning + 続行** とした（block しない）。
  → CI 等 s977043 不在環境でラッパ経由 gh が動かなくなる事故を避けるため。
- 透過 wrapper（`gh` 名の shadow）ではなく別名ラッパとした（誤爆回避）。

## 5. 引き継ぎ文書（サマリ）

session 中の gh active account drift による 403/FORBIDDEN を防ぐラッパ
`scripts/gh-s977043.sh` を新設。各 gh 操作の直前に `gh auth switch --user s977043`
を冪等実行し `exec gh "$@"` で透過。既存 SessionStart hook `gh-pin-account.sh`
（session 開始時 1 回 pin）を**補完**する（責務分界は doc に明記）。
HO 対象外（scripts/ ルート直下）のため通常 exec path で実装完了。

## 6. テスト結果サマリ

- TA-23: 7 case 全 PASS
- shellcheck scripts/gh-s977043.sh: PASS
- 全体 regression: **203 passed, 0 failed**
