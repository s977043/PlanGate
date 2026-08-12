# TASK-1044 current-state

- **今どこ**: フェーズ B 完了（pbi-input / plan / todo / test-cases / C-1 まで作成済み）
- **mode**: high-risk（人間 C-3 必須・autonomous APPROVE 不可）
- **次にやること**:
  1. C-2 外部レビュー（high-risk のため必須）
  2. 👤 C-3 人間レビュー + **Q-1 裁定**（F-3 init 前 finalize の exit 4 案 vs harness 保護案）
  3. APPROVED c3.json 発行後に exec（T-03 から TDD）
- **ブロッカー**: C-3 待ち（exec ゲート）
- **再実測結果（2026-08-12 / main 48f6971）**: issue #1044 再現確認済み。
  helper 欠落: dash=0 / zsh=0 / bash=1 / sh=1。**helper 存在: 4 シェルすべて rc=0**
  （拡大所見 — 修正位置を mode 判定本体とする根拠）
- **重要決定**: 直接実行ガードは `${0##*/}` の `ta-*.sh` glob（バイト一致 DoD 維持）/
  新正本 = 本 plan「### Mode resolution v2」/ F-3 In scope
- **river-review 反映済み（F-1〜F-5 / 2026-08-12）**: F-1 = helper は関数内 `$0` 非評価の
  **変数消費形**へ設計変更（zsh FUNCTION_ARGZERO 対策）。sandbox 4 シェル再実測:
  helper 存在 + 3 env 漏出 + 直接実行 = dash/zsh/bash/sh 全 rc=3 + summary、
  helper 欠落 = 全 rc=1、runner source（dash/bash/sh）非 exit、清浄 env = 全 rc=3
