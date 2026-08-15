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

## 🔶 exec の中断点（次セッションはここから）

### 完了済み

| タスク | 結果 |
|---|---|
| **T-01** baseline 再測定 | ✅ `evidence/test-runs/baseline.md`。**738 passed / 2 failed**（2 件とも本 PBI と無関係と切り分け済み）。**AC-6 主対象 4 本は全 PASS** |
| **T-02** 迂回面の再測定 | ✅ **FS 到達する迂回 12 件**を再確認（`.//CLAUDE.md` 含む）。C-2 時点から変化なし |

### 未着手（**T-03 から**）

**T-03 以降は `.sh` への書き込みを伴うため、no-task セッションでは EH-3 が block する。**

```
scripts/lib/pg-fold-path.sh   rc=2  ← [Hook EH-3] SKIP 拒否: SKIP_REASON 未設定
tests/extras/ta-65-*.sh       rc=2  ← 同上
docs/**.md（非 HO）            rc=0  ← doc-light で通る
```

`PLANGATE_HOOK_TASK` / `PLANGATE_SKIP_REASON` は**起動時に固定**されるため、実行中の `export` では解除できない。

### 再開方法

```sh
PLANGATE_HOOK_TASK=TASK-1101 claude
```

`c3.json` は APPROVED・`plan_hash` も一致しているので、**そのまま T-03 から exec に入れる**。

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

## 参照

- [pbi-input.md](./pbi-input.md) — AC-1〜AC-11 / Mode override の根拠 / 正規化順序の確定
- [plan.md](./plan.md) — **v4**（Step 0〜9）
- [todo.md](./todo.md) — T-01〜T-19 / H-01〜H-03 / Step ↔ ToDo 対応表
- [test-cases.md](./test-cases.md) — TC-01〜TC-14 + **TC-11b**
- [review-self.md](./review-self.md) — C-1（**v1 に対する結果**。v3/v4 の解消状況は review-external.md の表を参照）
- [review-external.md](./review-external.md) — C-2 + 簡易 C-1 + RiverReview の集約と監査表
- [evidence/c2-review/ho-bypass-surface.md](./evidence/c2-review/ho-bypass-surface.md) — 迂回面の実測
