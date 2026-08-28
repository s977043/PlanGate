# Current State — TASK-1101

> 更新: 2026-08-28 / base = `origin/main` = `75d832d`（取り込み済み）/ **plan は v4（編集禁止）**

## 今どこにいるか

**exec 完了（Step 0〜9 + handoff）。次は Human の H-02（patch 適用）と H-03（C-4）。**

```
A: PBI INPUT     ✅ 完了（AC-1〜AC-11）
B: Plan/ToDo/TC  ✅ 完了（plan v4）
C-1 / C-2 / RiverReview  ✅ 完了
C-3: 人間        ✅ APPROVED（2026-08-15T10:30:43Z / plan_hash 三点照合済み）
D: exec          ✅ **Step 0〜9 完了（T-01〜T-19）**
WF-05 handoff    ✅ **発行済み（2026-08-28）— 8/11 PASS・3 WARN・0 FAIL**
H-02 patch 適用  ⬜ **Human 待ち**（HO 対象パスのため AI 不可）
H-03 C-4         ⬜ 未着手
```

**判定の正本は [`handoff.md`](./handoff.md) §1。** 本ファイルは索引であり判定の正本ではない。

## 本セッション（2026-08-28）でやったこと

| ToDo | 結果 |
|---|---|
| **base 追随** | `dfaeebb` → `75d832d` を **merge** で取り込み（rebase 禁止）。`check-plan-hash.sh` / `ta-65` / `ta-67` / `pg-fold-path.sh` / apply スクリプトは **main 側で未変更**を実測 → patch アンカーと parity は無傷。更新されていたのは `docs/ai/hook-enforcement.md`（Step 9 の対象）のみ |
| **T-16（Step 7）判定 = 是正** | 小文字化を `/` セグメント単位に分割 + 長さ由来の fail-closed 2 条件（全体長 4096 超 / セグメント長 255 超）を追加。`len=2749` **10,803ms → 208ms**、`1 セグメント × 20,000 文字` **未完（ハング）→ 58ms / rc=1**。上限内 worst case 531ms。**AC-8 からの逸脱**として status.md #9 と decision-log に記録 |
| **T-17（Step 8）** | `ta-65` 17/0・`ta-67` 5/0・`ta-12` 14/0・`ta-39` 8/0・`ta-45` 7/0。**`sh tests/run-tests.sh` の通し実行は禁止指示により未実施＝ degrade（AC-6 WARN）** |
| **T-18（Step 9）** | `docs/ai/hook-enforcement.md`: 既知残存を 2 → **3 系統**（FS エイリアスを追加）、変換クラスを 3 種 → **7 種**へ訂正、**残存脅威モデル**を追記。**AC-7 は WARN**（FS エイリアスの追跡 issue が未起票）|
| **T-19** | `handoff.md` 発行 |

## 残っていること

| # | 内容 | Owner |
|---|---|---|
| 1 | `sh scripts/apply-1101-ho-normalization.sh --apply` → 成功したら `tests/fixtures/eh3-normalization-pending-1101.flag` を**削除** | 👤 Human（H-02）|
| 2 | 追跡 issue 2 件の起票（**FS エイリアスによる HO 迂回** / **`ta-45` TC-01 が C-3 conversation 分岐を通っていない**）→ `hook-enforcement.md` に番号を書き込むと **AC-7 が PASS** | オーケストレータ |
| 3 | CI で `sh tests/run-tests.sh` の緑を確認（**AC-6 の degrade 解消**）| CI |
| 4 | C-4 ゲート | 👤 Human（H-03）|

## ブロッカー

| 対象 | 状態 |
|---|---|
| `plan.md` の編集 | **AI 不可**（EH-3 / C-3 承認済み `plan_hash` と一致。1 バイト変えると MISMATCH）|
| `scripts/hooks/check-plan-hash.sh` の適用 | **AI 不可**（HO 対象パス）。patch + apply スクリプトを AI が作り、**Human が `--apply`** |

## 直近の重要な判明事項（引き継ぎ用の要約）

1. **⚠️ 正規化の適用順序**（RiverReview critical）— 畳み込みを最初に置かないと `.//CLAUDE.md` が素通りする。v4 で解決
2. **`_norm_target` は HO 判定専用ではない**（R-001 / critical）— 下流 3 経路が共有。**派生変数 `_ho_key`** で回避
3. **zsh で正規化が no-op になる**（R-002 / critical）— `ta-65` は常に `sh` を起動するため検出不可能。**`ta-67` の 4 シェル直接評価**で担保
4. **Bash 経路では HO 自体が存在しない**（**#1104**）— 本 PBI は `Edit` / `Write` 経路のみ
5. **`ta-45` は AC-2 の回帰網にならない**（exec Step 5 の実測）— 担保は `ta-65` TC-10
6. **⚠️ 防御の追加が非機能の穴を開けうる**（本セッションの Step 7）— セグメント**数**の上限は総**文字数**を制限せず、timeout の無い EH-3 では暴走が **block ではなくハング**になる。fail-closed 化のときは実行時間の軸も測ること
7. **FS エイリアス（firmlink / シンボリックリンク）は #1101 適用後も残る**— 「HO は常時 block される」と読んではならない

## 参照

- [handoff.md](./handoff.md) — **判定の正本**
- [status.md](./status.md) — フェーズ履歴 / 計画からの変更点（#9 = AC-8 逸脱）
- [evidence/test-runs/step7-performance.md](./evidence/test-runs/step7-performance.md) — 本セッションの主成果
- [plan.md](./plan.md)（v4・編集禁止）/ [todo.md](./todo.md) / [test-cases.md](./test-cases.md)
- [review-external.md](./review-external.md) — R-001〜R-013 / S-1〜S-4
