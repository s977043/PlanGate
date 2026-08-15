# Current State — TASK-1101

> 更新: 2026-08-15 / `origin/main` = `dfaeebb` / **plan は v4**

## 今どこにいるか

**C-3 APPROVED 済み → exec の Step 0 完了 → T-03 以降はセッション制約で中断。**

```
A: PBI INPUT     ✅ 完了（v4 まで反映）
B: Plan/ToDo/TC  ✅ 完了（plan v4 / todo / test-cases）
C-1: セルフ       ✅ 完了 → FAIL 11 → 反映 → 簡易 C-1 → WARN → 反映
C-2: 外部        ✅ 完了（2 レーン + C-1: critical 2 / major 6 / minor 4 / info 1）
RiverReview      ✅ 完了（critical 1 / major 10 / minor 8 / info 1）→ v4 で反映
C-3: 人間        ✅ **APPROVED**（2026-08-15T10:30:43Z / plan_hash 一致を三点照合で検証済み）
D: exec          🔶 **Step 0 のみ完了。T-03 以降は中断**
```

### C-3 承認の実測記録

```
c3_status  = APPROVED
plan_hash  = sha256:9ecef6cb09d2a60f397967fb4cef2e8fc1a08ea004c2ef7ed920c5631504808e
approved_by= s977043@users.noreply.github.com
approved_at= 2026-08-15T10:30:43Z
bin/plangate validate TASK-1101 → C-3 Gate 全 PASS
```

> **経緯**: 初回の承認は **v3（critical を含む版）に対して発行**されていた（`plan.md` の v4 設置前に `approve` を実行したため）。`validate` は「承認後の改変なし」だけを見るので **PASS を返していた**。v4 設置 → hash MISMATCH で FAIL 検出 → `approve --force` で再承認、という順で是正した。

## 🔶 exec の進捗（**Step 0〜5 完了 / 次は Step 6**）

> 作業場所: worktree `/Users/user/Documents/GitHub/plangate-wt-1101`
> branch `feat/1101-ho-normalization` / base `73ac1db` / **push 未実施**

### 完了済み（Step 0〜5 / T-01〜T-14）

| タスク | 結果 |
|---|---|
| **T-01** baseline 再測定 | ✅ **pristine clone `73ac1db`** で `741 passed / 0 failed / rc=0`。**件数は契約値にしない**（本 PBI が TC を増やすため） |
| **T-02** 迂回面の再測定 | ✅ C-2（`dfaeebb`）時点から**変化なし**。絶対パス 3 件が rc=0（TC-11b の根拠）も記録 |
| **T-03** `_pg_fold_path()` | ✅ `tests/fixtures/pg-fold-path.sh`（正本）。**4 シェル + `LANG=ja_JP.UTF-8` で出力 byte 一致**を本体組み込み前に確認 |
| **T-04/T-05** patch + apply | ✅ `scripts/apply-1101-ho-normalization.sh`（`--dry-run` / `--apply` / `--revert` / `--emit` / smoke + 自動 revert）。**AI が実 repo に対して実行したのは `--dry-run` と `--emit` のみ** |
| **T-06** 旧 apply の stale 対処 | ✅ 削除せず**退役注記**。#1101 適用後に両者とも **no-op（byte 一致で不変）**を sandbox で実測 |
| **T-07〜T-13** ta-65 拡充 | ✅ **16 passed / 0 failed**。TC-08 直積 **165 件すべて rc=2** |
| **T-14** 変異注入 | ✅ **9 種（7 + 第 8 + 順序）すべて kill** |

### 次にやること（**Step 6 から**）

| ToDo | 内容 |
|---|---|
| **T-15** | 4 シェル可搬性の**正式な TC 化**（Step 1 の🚩として実測済みだが、リポジトリに残る検査になっていない） |
| **T-16** | 性能実測（追加 fork 数 = 目標ゼロ / 典型・病的パスの実行時間）。参考: apply の smoke で **20 runs 0.71s** |
| **T-17** | 既存 4 本 + `sh tests/run-tests.sh` の回帰確認（baseline = 741/0/rc=0 に対し**新規 FAIL ゼロ**で判定） |
| **T-18** | `docs/ai/hook-enforcement.md` の更新（AC-7 の 5 点 / `Edit\|Write` 限定と `#1104` の明示） |
| **T-19** | handoff.md |

### 実行時の注意（前セッションの中断原因）

`.sh` への書き込みは no-task セッションの EH-3 が block する。**`PLANGATE_HOOK_TASK=TASK-1101 claude` で起動する**こと（実行中の `export` では解除できない）。

> **Bash で `.sh` を書けば通るが、それは #1104 として起票した迂回そのもの**なので行わない。

## ブロッカー

| 対象 | 状態 |
|---|---|
| `plan.md` の編集 | **AI 不可**（EH-3）。draft → Human が `cp` で設置する運用 |
| `scripts/hooks/check-plan-hash.sh` の適用 | **AI 不可**（HO 対象パス）。patch + apply スクリプトを AI が作り、**Human が `--apply`** |

> exec の検証は **sandbox 複製 + patch** で先行できる（plan Step 3）。Human 適用を待たずに T-08〜T-17 を回せる。

## 直近の重要な判明事項

1. **⚠️ 正規化の適用順序**（RiverReview critical / **4 回のレビューが見逃した**）— v3 の順序では **`.//CLAUDE.md` が skip される**（実ファイルに到達する）。**v3 が作り込んだ退行**でもある（v2 の「先頭 `/` 除去」が偶然塞いでいたのを、絶対パス偽陽性への対応で削除した結果）。**v4 で畳み込みを最初に置いて解決**
2. **`_norm_target` は HO 判定専用ではない**（R-001 / critical）— 下流 3 経路が大小文字に感応して共有。破壊的に書き換えると **maintenance 窓が全滅し C-3 conversation が silent に死ぬ**。**派生変数 `_ho_key`** で回避
3. **zsh で正規化が no-op になる**（R-002 / critical）— `IFS=/` の単語分割が zsh では既定で起きない。**`ta-65` は常に `sh` を起動するため検出不可能**。単語分割非依存の実装 + **4 シェル直接評価**
4. **迂回面は既知 4 ケースより広い**（R-004）— 変換クラスは **7 種**、大小文字は **HO 9 カテゴリすべて**で迂回可能
5. **Bash 経路では HO 自体が存在しない**（**#1104**）— 本 PBI は `Edit|Write` 経路のみを扱う。**AC-7 で書き分けを義務化**（M-8）
6. **⚠️ `ta-45` は AC-2 の回帰網にならない**（exec Step 5 の実測）— plan / test-cases は「第 8 変異で `ta-45` が FAIL する」としていたが**再現しなかった**。`ta-45` TC-01 は **TASK 文脈**で EH-3 を起動するため C-3 conversation 分岐（no-task 経路の内側）に到達せず、判定も `grep -qiE 'SKIP|PASS'` と緩い。**AC-2 の担保は新設の `ta-65` TC-10**（M8 で 3 件 FAIL を実測）
7. **TC-07 は「fixed 固定」ではなく PENDING-APPLY flag 方式**（#1089 の KNOWN-GAP flag と同機構）— real hook への適用は Human-owned のため、単純反転すると適用まで CI が RED で PR がマージできない。`--apply` が flag を自動削除し、適用済みで残れば **stale 宣言として FAIL** する

## 参照

- [pbi-input.md](./pbi-input.md) — AC-1〜AC-11 / Mode override の根拠 / 正規化順序の確定
- [plan.md](./plan.md) — **v4**（Step 0〜9）
- [todo.md](./todo.md) — T-01〜T-19 / H-01〜H-03 / Step ↔ ToDo 対応表
- [test-cases.md](./test-cases.md) — TC-01〜TC-14 + **TC-11b**
- [review-self.md](./review-self.md) — C-1（**v1 に対する結果**。v3/v4 の解消状況は review-external.md の表を参照）
- [review-external.md](./review-external.md) — C-2 + 簡易 C-1 + RiverReview の集約と監査表
- [evidence/c2-review/ho-bypass-surface.md](./evidence/c2-review/ho-bypass-surface.md) — 迂回面の実測
