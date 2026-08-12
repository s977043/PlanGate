# TASK-1044 INDEX

> Issue: [#1044](https://github.com/s977043/plangate/issues/1044)（P2 / bug）
> extras bootstrap の harness 誤判定（3 env 漏出 + 直接実行）で silent pass になる経路の封鎖

## 現在フェーズ

**C-2 完了（REJECT → 1 回確定反映済）→ C-3 待ち**（mode: high-risk = 人間 C-3 必須）

> plan パッケージは PR #1049 で main へマージ済み（`6089e23`）だが、**その時点で C-2 は
> 未実施**だった。本追補（branch `docs/1044-c2-reflect`）で C-2 を実施し、
> **統合 verdict = REJECT（major 7 / minor 5 / info 1）**を `review-external.md` へ
> R-001〜R-013 として集約 → 1 回確定反映 → 簡易 C-1 再実行 まで完了。
> さらに **C-2 Round 2**（統合 verdict = REJECT / major 2 / minor 4 / info 1。
> Round 1 の major 7 件は両レーンが実質解消と確認）を **R-014〜R-020** として
> 同ファイルへ**追記集約** → 1 回確定反映 → 簡易 C-1 再実行 #3（`C1-VERDICT-4`）まで完了。
> **C-2 Round 3 は 2 レーンとも APPROVE（major 0 / minor 3）**。
> **R-021〜R-023** を追記集約 → 1 回確定反映 → 簡易 C-1 再実行 #4（`C1-VERDICT-5`）まで完了。
> さらに **PR 作成前 River Review（major 2 / minor 6）** を **R-024〜R-031** として
> 追記集約 → 1 回確定反映 → 簡易 C-1 再実行 #5（`C1-VERDICT-6`）まで完了。
> さらに **River Review 2 回目（major 1 / minor 3）** を **R-032〜R-035** として
> 追記集約 → 1 回確定反映 → 簡易 C-1 再実行 #6（`C1-VERDICT-7` /
> plan_hash `sha256:53ed2595…`）まで完了。
> **承認トークンはこの最新 hash で発行すること**（過去 hash で発行すると EH-3 mismatch）。
> **`approvals/c3.json` は未発行**。承認は本追補のマージ後に行うこと。

## ファイル

| ファイル | 内容 |
|---|---|
| [pbi-input.md](pbi-input.md) | PBI INPUT PACKAGE（Context / Scope / **受入基準 12 行 = AC-1 / AC-2a〜2d / AC-3〜AC-9**（実質要件 9）/ 残存エクスポージャ / Risks） |
| [plan.md](plan.md) | EXECUTION PLAN（**### Mode resolution v2 = bootstrap 述語の新正本** / F-3 是正 / Mode 判定） |
| [todo.md](todo.md) | EXECUTION TODO（T-01〜T-11b / H-01〜02） |
| [test-cases.md](test-cases.md) | TC-30〜38 + EV-1〜4（変異注入 M-1〜M-4b） |
| [review-self.md](review-self.md) | C-1 セルフレビュー（17 項目 + 簡易再実行 ×6・冒頭に `C1-VERDICT` 非対称の注記 / R-034） |
| [review-external.md](review-external.md) | **外部レビュー集約（C-2 Round 1〜3 = R-001〜R-023 + PR 前 River Review 1・2 回目 = R-024〜R-035・監査表つき・追記専用・末尾に `C2-VERDICT` 1 行）** |
| [current-state.md](current-state.md) | 現在状態スナップショット |
| [decision-log.jsonl](decision-log.jsonl) | 判断履歴（append-only） |

## キーポイント

- 再実測済み（2026-08-12 / main `48f6971`）: helper 欠落 = dash/zsh rc=0、
  **helper 存在でも 4 シェル rc=0**（実測 2 / issue 未記載の拡大所見）
- 修正 = harness 判定へ direct-exec ガード（`${0##*/}` の `ta-*.sh` glob）を AND。
  issue 案のファイル名 literal はバイト一致 DoD を壊すため不採用。
  **`$0` 評価は bootstrap トップレベル 1 回のみ・helper は変数消費形**
  （zsh FUNCTION_ARGZERO で関数内 `$0` = 関数名 → 関数内評価はガード不発 —
  river-review F-1 是正、変数消費形を 4 シェル再実測済み）
- F-3（finalize 既定値非対称）は **In scope**（fail-closed 化。Q-1 = C-3 裁定事項）
- 正本管理: TASK-0921 plan「### Mode resolution」は不変のまま、本 plan
  「### Mode resolution v2」が新正本
- **C-2 反映の主眼（R-001 / R-014・R-018 で確定）**: 本 PBI の修正は、放置すると
  ta-61 の fixture を「静かに通るテスト」化し **HR-4 回帰テストの検出力を消す**。
  **`_pg_extra_direct=0` は helper を直接 source する全 fixture（`. "$T61_HELPER"` 由来で
  動的導出・本 PR 時点の実測 12 本）へ明示設定**する（standalone 期待側も含む）。
  うち**挙動が変わるのは `tc01.sh` / `tc01b.sh` / `tc21.sh` / `tc26-file1.sh` の部分集合**
  であって **TC-37 の走査母数ではない**（4 本の固定リストにすると AC-8 が手書きリストへ
  退化する / R-014）。担保は **AC-8 静的 TC（TC-37）** + **変異 M-4（TC-01c kill）/
  M-4b（TC-01b kill）** の 3 点セット
- **残存エクスポージャ（R-006）**: 本 PBI で塞ぐのは bootstrap 系 13 本 + helper。
  `ta-25` / `ta-26` / `ta-58` / `ta-59` / `ta-60` の **5 本は 2 env AND のまま残る**
  （Slice 2 へ。`pbi-input.md`「残存エクスポージャ」節が正本）
- **C-3 で裁定すべき項目（計 5 件）**: Q-1 (1) F-3 の方式 / Q-1 (2) R-024 carve-out の可否 /
  Q-3 (1) AC 行数 12 の読み替え追認 / **Q-3 (2) 変更ファイル数の分母定義（15 か 16 か）**
  （Round 2 R-015 で追加。安全側の向きの両論 + 裁定の実質的影響を Q-3 に併記済み）/
  **Q-4 `FIXTURES_DIR` 単独条件の検出力**（`TC-01d` + `M-4c` で塞ぐか V2 送りか。
  Round 3 R-022 で追加。**AI は実装していない** = scope 拡大は Human 裁定事項）
