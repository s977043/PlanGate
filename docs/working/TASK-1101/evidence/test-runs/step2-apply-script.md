# Step 2 — apply スクリプトの安全性実測（T-04 / T-05 / T-06・TC-13 相当）

> 実施: 2026-08-15（exec） / branch `feat/1101-ho-normalization` / base `73ac1db`
> OS: Darwin 25.6.0 (macOS 26.6.1 / arm64)

## ⚠️ 実行範囲の宣言（責務境界）

`scripts/hooks/check-plan-hash.sh` は **Hardening Override 対象パス**であり、
適用は **Human-owned**。

- **本リポジトリの実ファイルに対して `--apply` は実行していない**
  （`git status` で `scripts/hooks/` に差分なしを毎回確認）
- 実リポジトリに対して AI が実行したのは **`--dry-run` と `--emit`（書き込みなし）のみ**
- `--apply` / `--revert` / smoke 失敗時の自動 revert は、
  **スクリプトごと mktemp サンドボックスへ複製**して検証した
  （スクリプトは `REPO_ROOT=$(dirname $0)/..` で自己位置から repo root を導くため、
   サンドボックスに置けば実リポジトリへ到達しない）

## 実測

| # | 検査 | 結果 |
|---|---|---|
| 1 | `--dry-run`（既定）が実ファイルを変更しない | rc=0 / hook byte 一致（unchanged） |
| 2 | 未知引数 `--bogus` は exit 1 | **rc=1** |
| 3 | `--apply` → 適用 + smoke 実行 | rc=0 / `smoke : OK (20 runs in 0.71s)` |
| 3b | `--apply` が PENDING-APPLY flag を削除 | `flag removed: OK` |
| 3c | 実行ビットが保存される（`os.replace` 対策） | `exec bit preserved: OK` |
| 4 | 再 `--apply` は冪等 | rc=0 / `already applied — nothing to do` |
| 5 | `--revert` | rc=0 / **元ファイルと byte 一致で復元** |
| 6 | 再 `--revert` は冪等 | rc=0 / `not applied — nothing to revert` |
| 7 | **smoke 失敗時の自動 revert** | 正本 fixture の `..` 畳み込みを壊して `--apply` → `smoke check FAILED — 自動 revert しました` / **rc=1** / hook は元に byte 一致で復元 |

smoke の検査内容: HO 1 件（`bin/../bin/plangate`）が rc=2+`HARDENING_OVERRIDE` /
非 HO 1 件が rc≠2 / **絶対パス 1 件が rc≠2**（偽陽性の検出）/ 20 回実行が 20 秒以内
（EH-3 に `timeout` が無く暴走が block ではなく**ハング**になるため）。
smoke は mktemp サンドボックス上の複製で行い **実 audit ログを汚さない**。

## T-06: 旧 apply スクリプトの stale 化への対処（S-2）

**方針: 削除せず「退役済み」注記を入れる**（過去の適用手順の記録としての価値を残しつつ、
新規実行を止める）。加えて **#1101 適用後に no-op であることを実測**した。

| スクリプト | 冪等判定 | #1101 適用後の `--dry-run` | #1101 適用後の `--apply` | hook 変更 |
|---|---|---|---|---|
| `scripts/apply-eh3-ho-always.sh` | `_override=0` の位置が `if [ -z "$task_id" ]` より前か | rc=0 `already applied` | rc=0 `already applied` | **なし（byte 一致）** |
| `scripts/fix-eh3-doc-light-maint-guard.sh` | `grep -q '! -f "$_maint"'` | rc=0 `SKIP (already fixed)` | rc=0 `SKIP (already fixed)` | **なし（byte 一致）** |

→ **巻き戻し事故は構造的に起きない**（どちらも冪等判定で先に抜ける）。ただし両者は
**#1089 / TASK-0138 当時の HO ブロックを verbatim 保持**しており、#1101 以降は
stale なスナップショットになるため、ヘッダに退役注記と参照先（`apply-1101-ho-normalization.sh`）を追記した。
