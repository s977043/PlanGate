# TASK-1044 INDEX

> Issue: [#1044](https://github.com/s977043/plangate/issues/1044)（P2 / bug）
> extras bootstrap の harness 誤判定（3 env 漏出 + 直接実行）で silent pass になる経路の封鎖

## 現在フェーズ

**C-2 完了（REJECT → 1 回確定反映済）→ C-3 待ち**（mode: high-risk = 人間 C-3 必須）

> plan パッケージは PR #1049 で main へマージ済み（`6089e23`）だが、**その時点で C-2 は
> 未実施**だった。本追補（branch `docs/1044-c2-reflect`）で C-2 を実施し、
> **統合 verdict = REJECT（major 7 / minor 5 / info 1）**を `review-external.md` へ
> R-001〜R-013 として集約 → 1 回確定反映 → 簡易 C-1 再実行 まで完了。
> **`approvals/c3.json` は未発行**。承認は本追補のマージ後に行うこと。

## ファイル

| ファイル | 内容 |
|---|---|
| [pbi-input.md](pbi-input.md) | PBI INPUT PACKAGE（Context / Scope / 受入基準 AC-1〜7 / Risks） |
| [plan.md](plan.md) | EXECUTION PLAN（**### Mode resolution v2 = bootstrap 述語の新正本** / F-3 是正 / Mode 判定） |
| [todo.md](todo.md) | EXECUTION TODO（T-01〜T-10 / H-01〜02） |
| [test-cases.md](test-cases.md) | TC-30〜36 + EV-1〜4（変異注入） |
| [review-self.md](review-self.md) | C-1 セルフレビュー（17 項目 + 簡易再実行 ×2） |
| [review-external.md](review-external.md) | **C-2 外部レビュー（2 レーン / R-001〜R-013・監査表つき・追記専用）** |
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
- **C-2 反映の主眼（R-001）**: 本 PBI の修正は、放置すると ta-61 の fixture 4 本
  （`tc01.sh` / `tc01b.sh` / `tc21.sh` / `tc26-runner.sh`）を「静かに通るテスト」化し、
  **HR-4 回帰テストの検出力を消す**。fixture への `_pg_extra_direct=0` 明示
  （standalone 期待側も含む）+ **AC-8 静的 TC** + **変異 M-4** の 3 点で塞ぐ
- **残存エクスポージャ（R-006）**: 本 PBI で塞ぐのは bootstrap 系 13 本 + helper。
  `ta-25` / `ta-26` / `ta-58` / `ta-59` / `ta-60` の **5 本は 2 env AND のまま残る**
  （Slice 2 へ。`pbi-input.md`「残存エクスポージャ」節が正本）
- **C-3 で裁定すべき項目**: Q-1 (1) F-3 の方式 / Q-1 (2) R-024 carve-out の可否 /
  Q-3 AC 分割に伴う mode 件数の読み替え追認
