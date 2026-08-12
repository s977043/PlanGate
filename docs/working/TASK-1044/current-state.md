# TASK-1044 current-state

- **今どこ**: **C-2 完了（REJECT）→ 1 回確定反映 + 簡易 C-1 再実行まで完了**
  （branch `docs/1044-c2-reflect` / base `6089e23`）。plan パッケージ本体は PR #1049 で
  main へマージ済みだが、C-2 は未実施だったため本追補で実施した
- **mode**: high-risk（人間 C-3 必須・autonomous APPROVE 不可）
- **次にやること**:
  1. 本追補のマージ（オーガナイザーが PR 作成）
  2. 👤 C-3 人間レビュー + 裁定 3 件 — **Q-1 (1)** F-3 の方式（exit 4 案 vs harness 保護案）/
     **Q-1 (2)** R-024 carve-out の可否 / **Q-3** AC 分割に伴う mode 件数の読み替え追認
  3. APPROVED c3.json 発行後に exec（T-03 から TDD）
- **ブロッカー**: C-3 待ち（exec ゲート）。
  ⚠️ **`approve TASK-1044` は本追補のマージ後に行うこと** — 反映前に承認すると
  C-2 REJECT の plan を承認した状態になる（現時点で `c3.json` は未発行）
- **C-2 結果（2026-08-12 / 2 レーンとも REJECT）**: 統合 major 7 / minor 5 / info 1 を
  `review-external.md` に R-001〜R-013 として集約し全件反映。最重要 = **R-001**
  （本 PBI の修正が ta-61 fixture 4 本を「静かに通るテスト」化し HR-4 検出力を消す）→
  AC-8（静的 TC）+ 変異 M-4 + fixture 完全列挙で封鎖。
  AC は 7 → 12 行（AC-2 を 2a〜2d へ分割 + AC-8 / AC-9 新設。実質要件数は 9）、
  TC は TC-30b / TC-37 / TC-38 を追加
- **再実測結果（2026-08-12 / main 48f6971）**: issue #1044 再現確認済み。
  helper 欠落: dash=0 / zsh=0 / bash=1 / sh=1。**helper 存在: 4 シェルすべて rc=0**
  （拡大所見 — 修正位置を mode 判定本体とする根拠）
- **重要決定**: 直接実行ガードは `${0##*/}` の `ta-*.sh` glob（バイト一致 DoD 維持）/
  新正本 = 本 plan「### Mode resolution v2」/ F-3 In scope
- **river-review 反映済み（F-1〜F-5 / 2026-08-12）**: F-1 = helper は関数内 `$0` 非評価の
  **変数消費形**へ設計変更（zsh FUNCTION_ARGZERO 対策）。sandbox 4 シェル再実測:
  helper 存在 + 3 env 漏出 + 直接実行 = dash/zsh/bash/sh 全 rc=3 + summary、
  helper 欠落 = 全 rc=1、runner source（dash/bash/sh）非 exit、清浄 env = 全 rc=3
