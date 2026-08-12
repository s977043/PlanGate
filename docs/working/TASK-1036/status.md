# TASK-1036 status

> Plan: [`plan.md`](./plan.md) / Mode: **standard** / `lite_eligible=false`
> Branch: `fix/1036-exec`（base `origin/main` = `d86eef9`）

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|---|---|---|
| 2026-08-12 09:41 | C-3 | Human C-3 APPROVED（c3.json 発行済み・plan_hash `sha256:638498e9...`。c3.json は gitignore 対象で worktree 外） |
| 2026-08-12 18:45 | exec 開始 | plan_hash 一致を worktree 内で実測（`shasum -a 256 plan.md` 先頭 64hex 完全一致）。base drift 確認: `48f6971..d86eef9` は docs のみ、対象 3 ファイルに変更なし（plan S-1 クリア） |
| 2026-08-12 18:53 | T-03 RED | `ta-62-t26-recurse-env-guard.sh` 新規作成（#921 契約準拠）。修正前 tree で rc=1: TC-D FAIL（leak 側に再帰防止 [SKIP] 4 行・diff 不一致）+ TC-S FAIL（配置不成立）→ `evidence/test-runs/red.log`。commit `b662ef6` |
| 2026-08-12 19:05 | T-04 GREEN | 案 (d) 適用（ta-26 harness 分岐 else 節へ unset + 禁止理由コメント）。ta-62 rc=0（2 passed）。AC-3 即時確認: `PG_T26_NO_RECURSE=1` 前置直接起動でガード発火（[SKIP] 4 / 15 passed, 0 failed / rc=0）。commit `33f1b68` |
| 2026-08-12 19:10 | T-05 | README 規約 7/8 追記（追記のみ。TC-30 の grep 対象 4 文言の残存を実測確認）。commit `e2242b3` |
| 2026-08-12 19:30 | T-06 | 変異 3 種すべて kill（M-1 動的 = TC-D FAIL / M-2 静的のみ・動的実行 0 回 = TC-S FAIL / M-3 sandbox = 既存 TC-33 FAIL + TC-S(3) FAIL）。復元後 PASS。→ `evidence/test-runs/mutation.log`。commit `2ff6b50` |
| 2026-08-12 19:35 | T-07 | 3 系統実測完了（harness=フルスイート内 TC-D/TC-S / standalone=green.log / 子相当=t04-child-guard.log）。TC-33・TC-30 非破壊を修正後 tree で直接確認（両 PASS）。**フルスイート Results + T1036-TC-E1 + S-5 実測はオーガナイザーが別途 background 実行**（本ワーカーの起動分は competing のため kill 済み） |
| 2026-08-12 19:45 | T-08 | handoff.md / status.md / decision-log.jsonl 確定。TASK-1036 配下のみ stage |

## 計画からの変更点

1. **ta-61 による TC-D 実行回数の増幅（plan 未計上の事実）**: `ta-61-extra-contract.sh`
   は migrated standalone-capable ファイルを full suite ごとに最大 3 回 standalone
   実走する（stage-1 clean / probe / contamination）。ta-62 は契約準拠（helper source）
   のため自動的にこの対象に入り、TC-D（ta-26 ×2 実行）の suite 追加時間は plan R-P7
   の想定（+約 90 秒 = 単回実行前提）より増幅される。→ S-5 の固定測定方法
   （user+sys 合計・3 回中央値）で実測し判定（T-07 に記録）。
2. **M-2 の動的実行禁止の実装方法**: sandbox から `tests/fixtures/` を除去し、
   TC-D の前提不在チェックで mutant ta-26 の source を構造的に 0 回にした
   （plan は「`sh -n` で構文のみ確認」とだけ記載。実 TC = TC-S の FAIL で kill を
   示すため、TC-S を含む ta-62 本体を実行しつつ動的経路のみ遮断する形を採用）。
3. **M-3 の随伴 FAIL**: mutant sandbox では TC-33 に加え TC-13 も FAIL する
   （子プロセス内の TC-33 FAIL が子 rc=1 として波及する下流効果。独立 kill には
   数えない。mutation.log に明記）。
4. **TC-33 波及ファイル数**: pbi-input N-1 の 15 → 現 tree では 18（ta-62 含む・
   extras 増加による。スナップショットであり契約値にしない）。

## 残タスク

- [x] T-03 RED
- [x] T-04 案 (d) 本体
- [x] T-05 README 規約 7/8
- [x] T-06 変異注入 3 種
- [x] T-07 3 系統 + TC-33/TC-30 非破壊（full suite Results + T1036-TC-E1 + S-5 はオーガナイザー担当）
- [x] T-08 handoff / status 最終化

## V 系ステップ進捗

- **L-0 / V-1〜V-3 / PR**: workflow-conductor / オーガナイザー制御（standard のため V-2/V-4 スキップ）
- `evidence/test-runs/t07-suite-clean.log` は本ワーカーが起動した competing フルスイートの**途中出力**（完了前に kill）。**完全な Results はオーガナイザーの background 実行が正**。本ファイルは partial として残す（削除しない）が、Results 判定には使わない

## 既知の残存リスク（handoff.md §2/§3 参照）

- K-1: 直接 standalone 起動時の env 漏れは本修正の対象外（harness 経路・CI は保護済み）
- K-2: ta-61 が standalone-capable ファイルを suite ごと最大 3 回実走するため TC-D の suite 追加時間は plan R-P7 想定より増幅（S-5 実測はオーガナイザー転記）
- V2: `PG_T61_NO_RECURSE` 同型クラス（plan P-10）
