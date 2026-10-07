# Growth Harness — HO patch 案（`working-context.md`）

> 種別: **差分案のみ（適用しない）**。対象は HO パス `.claude/rules/working-context.md`
> （ミラー `plugin/plangate/rules/working-context.md` も同時適用が必要）。
> 適用は Human が [`ho-apply-script`](../../../.claude/skills/ho-apply-script/SKILL.md) の型で行う。
> 設計正本: [`docs/ai/growth-harness.md`](../../ai/growth-harness.md) L3。
> 基準: `origin/main` = `7fad3e71`（2026-10-07）。

## 0. #1157 設計との分担（重複させない）

| 変更点 | 正本 |
| --- | --- |
| L0 / L1 / L2 表への digest 追加 | **#1157** [`1157-seeds-read-path-patch.md`](./1157-seeds-read-path-patch.md) §6.2。本案では再掲しない |
| seeds 節末尾への digest 参照 1 行 | **#1157** §6.2 |
| 「セッション開始時」手順への digest 読み込み | **#1157** §6.2 の手順 5 を土台に、本案で「**最新** digest」と「鮮度確認」を足す（下記 diff） |

なお #1157 §6.2 の手順追記は「`:297-299` の直後」を指すが、現行では当該手順は `:392-398`
（記号アンカー: `### セッション開始時`）にある。行番号ではなく見出しで位置を決めること。
また #1157 の手順 5 を先に適用する場合は、下記 diff の 6 は 5 の直後に置き、番号を詰める。

## 1. 差分案（unified diff）

```diff
--- a/.claude/rules/working-context.md
+++ b/.claude/rules/working-context.md
@@ -392,8 +392,14 @@
 ### セッション開始時
 
 1. 対象チケットの `docs/working/TASK-XXXX/` が存在するか確認する
 2. `INDEX.md` が存在すれば読み、現在フェーズを確認する（L0）
 3. `current-state.md` を読み、中断地点・ブロッカーを把握する（L0）
 4. フェーズに応じて必要なファイルを読む（L1、Progressive Disclosure プロトコルに従う）
 5. `INDEX.md` が存在しない場合（旧形式）→ `status.md` を読み、現在の状態を把握してから作業を開始する（フォールバック）
+6. 最新の `docs/working/improvement-digest.md` を読む（L0。過去 run の現役知見）。
+   `superseded` とマークされた知見は使わない。digest の最終更新が
+   `docs/working/improvement-seeds.md` の最終更新より古い場合は、未統合の seeds が
+   ある旨を status.md に記録する（digest を AI が黙って再生成しない）。
+   digest は参照入力であり、C-3 / C-4 / HO の承認境界を緩和する根拠にしない
+   （[`docs/ai/growth-harness.md`](../../docs/ai/growth-harness.md) 不変条件）。
 
```

鮮度の比較は `git log -1 --format=%ct -- <path>` 同士で行う（同ファイル §INDEX.md 鮮度契約 4 と同じ方式）。

## 2. 適用時の確認（Human）

- 適用順は「#1157 §6.2（文章ベースの手順・unified diff なし）→ 本 patch」に固定する。
- 本 patch の diff は `origin/main` = `7fad3e71` 時点の `working-context.md` に対して作成している。
  #1157 適用後は文脈行（手順番号）がずれるため、#1157 適用後に AI へ本 patch の再生成を依頼してから当てる
  （AI は dry-run のみ、適用は Human）。
- ミラー `plugin/plangate/rules/working-context.md` も同じ順で適用する。

- `### セッション開始時` 見出し・`### improvement-seeds.md（WF-06 Retro / opt-in・append-only）`
  見出しを変更しない（後者は `scripts/apply-quality-command-gate.sh` がアンカーとして使用。#1157 §6.2 注記）。
- 本体とミラーの diff が 0 であること。
- `git apply --check` 単独を検証としない。worktree で実適用し、fwd / rev の両方を確認する（ho-apply-script 手順 4）。
- Mode: 承認境界周辺の変更 → 最低 high、`lite_eligible=false`、同期 C-3（`mode-classification.md` 例外ルール）。
