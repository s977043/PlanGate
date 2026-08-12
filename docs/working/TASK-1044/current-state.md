# TASK-1044 current-state

- **今どこ**: **PR 作成前 River Review 3 回目（major 1 = PR ブロッカー / minor 2）を
  R-036〜R-038 として 1 回確定反映 + 簡易 C-1 再実行 #7 まで完了**（`C1-VERDICT-8` /
  plan_hash = `sha256:24f3faf99c427637f377e6580dc7f0667d2e103aa2f2fd0ee7adb461183f8bb4`）。
  **PR ブロッカーは解消**（River Review 判定: 是正が新たな major を生む連鎖は止まっている）。
  **承認トークンはこの最新 hash で発行すること**。直前は River Review 2 回目
  （R-032〜R-035 / `C1-VERDICT-7`）。直前は River Review 1 回目（R-024〜R-031 /
  `C1-VERDICT-6`）。
  **承認トークンはこの最新 hash で発行すること**（`cce20c06…` / `d1f6c5ea…` など
  過去 hash で発行すると EH-3 が後続反映を mismatch 検知）。
  直前は C-2 Round 3 完了（2 レーンとも APPROVE / major 0）→ R-021〜R-023 反映
  （`C1-VERDICT-5` / `d1f6c5ea…`）。Round 2 は REJECT → 全件反映済（`C1-VERDICT-4` /
  `cce20c06…`）。
  Round 1 の major 7 件は両レーンが実質解消と確認。
  以下は Round 1 時点の記録（履歴として保持）: **C-2 完了（REJECT）→ 1 回確定反映 + 簡易 C-1 再実行まで完了**
  （branch `docs/1044-c2-reflect` / base `6089e23`）。plan パッケージ本体は PR #1049 で
  main へマージ済みだが、C-2 は未実施だったため本追補で実施した
- **mode**: high-risk（人間 C-3 必須・autonomous APPROVE 不可）
- **次にやること**:
  1. 本追補のマージ（オーガナイザーが PR 作成）
  2. 👤 C-3 人間レビュー + **裁定 5 件** — **Q-1 (1)** F-3 の方式（exit 4 案 vs harness 保護案）/
     **Q-1 (2)** R-024 carve-out の可否 / **Q-3 (1)** AC 行数 12 の読み替え追認 /
     **Q-3 (2)** 変更ファイル数の分母定義（15 か 16 か）— Round 2 R-015 で追加 /
     **Q-4** `FIXTURES_DIR` 単独条件の検出力（`TC-01d` + `M-4c` で塞ぐか V2 送りか）
     — Round 3 R-022 で追加。**計 5 件**。
     Q-3 には安全側の向きの両論（整合レーン = 既定 critical / 設計レーン = high-risk 維持）と
     裁定の実質的影響（差分は V-4 と C-4 複数レビュアー推奨のみ）を併記済み
  3. APPROVED c3.json 発行後に exec（T-03 から TDD）
- **ブロッカー**: C-3 待ち（exec ゲート）。
  ⚠️ **`approve TASK-1044` は本追補のマージ後に行うこと** — 反映前に承認すると
  C-2 REJECT の plan を承認した状態になる（現時点で `c3.json` は未発行）
- **C-2 結果（2026-08-12 / 2 レーンとも REJECT）**: 統合 major 7 / minor 5 / info 1 を
  `review-external.md` に R-001〜R-013 として集約し全件反映。最重要 = **R-001**
  （本 PBI の修正が ta-61 の helper 直接 source fixture を「静かに通るテスト」化し
  HR-4 検出力を消す。**対象は動的導出の 12 本**で、`tc01` / `tc01b` / `tc21` /
  `tc26-file1` は**挙動が変わる部分集合**であって TC-37 の母数ではない / R-014）→
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
- **C-2 Round 3 結果（2026-08-12 / 2 レーンとも APPROVE・major 0 / minor 3）**:
  `review-external.md`「C-2 Round 3」節へ R-021〜R-023 を追記集約し全件反映。
  **R-021** = R-014 / R-018 の是正漏れ 3 箇所（plan Files 節・plan Risks 表・
  pbi-input AC-7）を掃除し、掃除後に 6 パターンの `grep` で**残存 0 件を実測**。
  **R-022** = 「3 条件すべてに検出力」は実測 2/3（`FIXTURES_DIR` 単独条件を kill する
  TC が base の `ta-61` に無い）→ 文言を 2 条件へ縮小し **Q-4 を新設**（実装はしない）。
  **R-023** = Q-3 に裁定の実質的影響を追記。**mn-D は現状維持で確定**（書き換えなし）
- **PR 作成前 River Review 結果（2026-08-12 / major 2 / minor 6）**:
  `review-external.md`「PR 作成前 River Review」節へ R-024〜R-031 を追記集約し全件反映。
  **R-024** = AC-4 の「marker 由来 = 母数 14」が base で不成立（base は 12 出現 / 12 ファイル・
  ta-61 は marker 非保持）→ **照合単位を marker の「出現」へ確定**し
  **ファイル単位ループを禁止**（ta-61 は 1 ファイル 2 出現で、ファイル単位だと
  fixture 複製が照合網から外れ「静かに通る」）。
  **R-025** = 変異 evidence の分母は **実測 19**（handoff の 18 は `M-14ab` 分割後に
  未更新の stale 値 = TASK-0921 側の誤り）→ **15 superseded + 4 再走で全件分類**。
  minor 6 件（L0 層の掃除 / 裁定件数 / EH-3 順序 / AC-2c を 7 env へ / AC-3 の動的導出 /
  frontmatter + `C2-VERDICT` 1 行）も反映
- **PR 作成前 River Review 2 回目（2026-08-12 / major 1 / minor 3 / info 1）**:
  R-032〜R-035 を追記集約し反映。**R-032（major）は R-030 の副作用** — AC-3 の
  marker 由来集合に `ta-61` 自身が入り、TC-34 を素直に実装すると**入れ子フルスイート
  再走で無限再帰 / per-file `timeout 180` 超過 FAIL** になる。
  → **contract TA 自身（`$_T61_SELF_ID`）を除外**（`ta-61:304` の既存パターンに合わせる）+
  S6 / T-07 の「層 A 12 本」を動的表現へ。
  **R-033** = AC-2c を `_T61_GUARDED_ENVS` の実行時導出消費へ（7 名固定・行番号アンカーを撤回）。
  **R-034** = C-1 マーカーの stale は **(b) 対応しない**を選択し review-self 冒頭へ注記。
  **R-035** = frontmatter `verdict` を schema enum 準拠の `PASS` へ
- **PR 作成前 River Review 3 回目（2026-08-12 / major 1 = PR ブロッカー / minor 2）**:
  R-036〜R-038 を追記集約し反映。**R-036（PR ブロッカー）** = `plan.md` の Testing Strategy
  だけが AC-2c の否定済み判定式（`env | grep -c '^PLANGATE_…' = 0`）を指示し続けており、
  R-029 / R-033 が plan へ一度も反映されていなかった → **guarded env の実行時導出**へ書き換え。
  **R-037** = stale 可視化のための注記自体が `C1-VERDICT-6` を名指しして stale 化 →
  特定の N を除去。**R-038** = 委譲先 `_T61_GUARDED_ENVS` は `head -1` で先頭 1 行しか
  読まないため実装時の追加 assert を TC-31 (3) に明記し、TC-15 の過大表明を是正。
  **全数照合を 3 段へ拡張**（過去否定語 / **本ラウンド非契約化語** / **AC ID 軸の横断照合**）
