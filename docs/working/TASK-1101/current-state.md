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
| **T-07〜T-13** ta-65 拡充 | ✅ **16 passed / 0 failed**。TC-08 直積 **195 件すべて rc=2** |
| **T-14** 変異注入 | ✅ **10 種（7 + 第 8 + 順序 + M10）すべて kill** |
| **PR 前レビュー是正** | ✅ **AC-1 未達（repo root 除去の大小文字依存）を是正**。是正前の実装で新 TC が 30/195 FAIL することを先に確認済み。詳細: [`evidence/test-runs/prereview-ac1-root-case.md`](./evidence/test-runs/prereview-ac1-root-case.md) |

### Step 6〜9 の到達点（**2026-08-15 23:50 セッション中断時点**）

| ToDo | 状態 | 中身 |
|---|---|---|
| **T-15**（Step 6） | ✅ **完了** | `tests/extras/ta-67-pg-fold-path-portability.sh` を新設。`ta-67` **5 passed / 0 failed (rc=0)**、`ta-61` 契約 **92 passed / 0 failed (rc=0)**。変異 4 種（M1 / M5 / M7 / M10）で検出力を実証（いずれも `TC-02` で FAIL） |
| **T-16**（Step 7） | 🔶 **途中（判定保留）** | **fork 増加ゼロを実測**（3 経路とも base と patched で同一）。**ただし長い大文字パスで実行時間が非線形に悪化**する問題を検出（status.md「Step 7 の重要な検出」参照）。**是正方式が未決**のため PASS を出していない |
| **T-17**（Step 8） | ⬜ **未着手** | `ta-65` / `ta-12` / `ta-39` / `ta-45` は個別には rc=0 を確認済みだが、**`sh tests/run-tests.sh` の通し実行は本ラウンドで未実施** |
| **T-18**（Step 9） | ⬜ **未着手** | `docs/ai/hook-enforcement.md` は未編集 |
| **T-19** | ⬜ **未着手** | `handoff.md` は未作成 |

### 次セッションの手順（この順で再開する）

1. **status.md の「Step 7 の重要な検出」を読む**。長大な大文字パスで
   `_pg_fold_tolower` が O(n²) になり、**セグメント上限 256 は文字数を制限しない**ため
   `1 セグメント × 20,000 文字` でハングしうる。**EH-3 に timeout は無い**
2. **是正方式をオーケストレータに確認する**（案 1「文字数上限を fail-closed に追加」は
   plan の fail-closed 2 条件からの**逸脱**なので独断で実装しない。案 2「写像を
   セグメント単位に分割」は plan 内で収まる可能性が高い）
3. 方式確定後、`tests/fixtures/pg-fold-path.sh` を直し、`ta-65` / `ta-67` を再実行
4. Step 8（`sh tests/run-tests.sh`）→ Step 9 → handoff の順

### Step 9 / handoff に**必ず**入れる（オーケストレータ指示 / PR 前レビューの成果）

- **FS エイリアスによる残存迂回**（本 PBI の退行ではなく、plan が Non-goal 宣言した
  シンボリックリンク解決の領域。ただし **Non-goal の一行で済ませず「生きた残存迂回」
  として明記**する）。オーケストレータ実測:
  ```
  REPO_ROOT の解決先: /tmp/pg1101-alias-96118
  rc=2  /tmp/pg1101-alias-96118/CLAUDE.md                  ← block（正）
  rc=0  /private/tmp/pg1101-alias-96118/CLAUDE.md          ← 素通り
  rc=0  /System/Volumes/Data/private/tmp/.../CLAUDE.md     ← 素通り
  ```
  `ls -l` で **3 表記とも同一 inode・同一タイムスタンプ**に到達することを確認済み
  （macOS の firmlink / `/tmp`→`/private/tmp` エイリアス）。
  **「HO は常時 block される」と読めてはいけない**（AC-7 (3)(4) と同じ趣旨）。
  → `hook-enforcement.md` の残存記述 + handoff の既知課題 + V2 候補に載せる。
  **issue 起票はオーケストレータが行う**（AI は文書化まで）
- **`ta-45` TC-01 が C-3 conversation 分岐を一度も通っていない**件も handoff の
  既知課題に残す。**起票はオーケストレータ**
- **Step 7 の性能問題**（未解決なら既知課題 + V2 候補に必ず載せる）

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
