# TASK-1044 current-state

- **今どこ**: **C-2 Round 2 完了（REJECT）→ R-014〜R-020 の 1 回確定反映 + 簡易 C-1
  再実行 #3 まで完了**（`C1-VERDICT-4` / plan_hash =
  `sha256:cce20c06ba273a6d4297f63f47fab4e0837519f394012b5a0b3aa2a0866f0352`）。
  Round 1 の major 7 件は両レーンが実質解消と確認。
  以下は Round 1 時点の記録（履歴として保持）: **C-2 完了（REJECT）→ 1 回確定反映 + 簡易 C-1 再実行まで完了**
  （branch `docs/1044-c2-reflect` / base `6089e23`）。plan パッケージ本体は PR #1049 で
  main へマージ済みだが、C-2 は未実施だったため本追補で実施した
- **mode**: high-risk（人間 C-3 必須・autonomous APPROVE 不可）
- **次にやること**:
  1. 本追補のマージ（オーガナイザーが PR 作成）
  2. 👤 C-3 人間レビュー + 裁定 4 件 — **Q-1 (1)** F-3 の方式（exit 4 案 vs harness 保護案）/
     **Q-1 (2)** R-024 carve-out の可否 / **Q-3 (1)** AC 行数 12 の読み替え追認 /
     **Q-3 (2)** 変更ファイル数の分母定義（15 か 16 か）— Round 2 R-015 で追加。
     Q-3 には安全側の向きの両論（整合レーン = 既定 critical / 設計レーン = high-risk 維持）を併記済み
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
- **C-2 Round 2 結果（2026-08-12 / 2 レーンとも REJECT・major 2 / minor 4 / info 1）**:
  `review-external.md`「C-2 Round 2」節へ R-014〜R-020 を追記集約し全件反映。
  最重要 = **R-014**（「完全列挙 4 本」を TC-37 の走査母数と誤読すると TC-37 が
  残り 8 本を未設定として FAIL、逆に 4 本固定リストへ狭めると AC-8 が手書きリストへ退化）
  → 走査母数を `. "$T61_HELPER"` 由来の動的導出（実測 12 本）へ。
  **R-015** で Mode 分母の自己矛盾を解消し Q-3 を 2 軸へ拡張。
  **R-017** で旧変異 4 本（M-01/02/03/16）を再走対象とし T-11b を新設。
  **R-018** で M-4 の期待値を訂正し M-4b を追加。tasks は 12 本（T-11b 追加）
