# HO 適用手順 — TASK-0907（H2）

> 対象は HO（Hardening Override）= `.claude/commands/*.md`。**AI は編集不可**（self-mod ガード）。
> 本 patch は AI が生成し **sandbox で実適用テスト済み**（dry-run/実適用 exit 0・適用後 = 完成形 byte 一致）。
> 適用は **Human-owned**（責務4分類）。

> **適用対象は v3 のみ**（v1 は適用済み・v2 は生成後に supersede して削除）。v3 は現 HEAD へ
> clean 適用可を sandbox 実適用テストで確認済み（dry-run/apply exit 0・適用後 = 完成形 byte 一致）。
> v3 は R-109（機械層 escalate の過大断言）を是正し、carve-out 集合を rollout-policy §2 注記へ参照委譲する。

## 対象ファイル（HO）

- `.claude/commands/ai-loop-workflow.md` — 実行前チェック3 の文言を §2 適用ドメイン拡張と整合。ガード非後退（承認境界/HO 接触は通常フロー・NO MERGE BY AI・touches-HO 停止規則は不変）を保持。

## 適用手順（Human・repo ルートで）

```sh
cd /Users/user/Documents/GitHub/plangate
# 1. 適用前 dry-run（exit 0 を確認）
patch -p1 --dry-run < docs/working/TASK-0907/patches/ai-loop-workflow-command-v3.patch
# 2. 適用
patch -p1 < docs/working/TASK-0907/patches/ai-loop-workflow-command-v3.patch
# 3. 適用後、plugin command を sync 再生成（T5）
sh scripts/sync-plugin-plangate.sh
# 4. byte 一致検証（AC-5 command 部）
cmp .claude/commands/ai-loop-workflow.md plugin/plangate/commands/ai-loop-workflow.md && echo "cmd sync OK"
```

## 切り戻し

```sh
# 未 commit なら
git checkout -- .claude/commands/ai-loop-workflow.md plugin/plangate/commands/ai-loop-workflow.md
# または reverse patch
patch -R -p1 < docs/working/TASK-0907/patches/ai-loop-workflow-command-v3.patch
```

## 未適用時の安全性（EC-1）

未適用でも **fail-closed**。差は実行前チェック3 の**文言のみ**で、arbiter の boundary/lite 判定・停止規則には影響しない（機能差なし）。適用は C-3 APPROVED（済）後の H2 で実施。

## 順序ロック

**T5（plugin command sync）・T6 の command 部は本 patch 適用（H2）の後**。適用前に sync すると plugin が旧 `.claude` 内容で上書きされる（`Refs: R-103`）。
