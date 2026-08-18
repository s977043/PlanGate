# STATUS — TASK-1093 (#1093)

## 全体構成

| PR / ブランチ | 内容 | 状態 |
|---|---|---|
| [#1111](https://github.com/s977043/PlanGate/pull/1111) | Plan Package（v1 → C-2 REJECT → v2）初版 | **マージ済**（`origin/main`） |
| `docs/1093-split-scope` | **v3: C-3 裁定 2026-08-18（案 B: 2 分割）の反映** | 本セッション |

## モード判定結果

| 版 | Mode | 契機 |
|---|---|---|
| v1 | high-risk | 初版 |
| v2 | **critical** | C-2 REJECT 反映で契約適合が apply script 全数に及んだため引き上げ |
| **v3** | **high-risk（戻した）** | **C-3 2026-08-18 の案 B（2 分割）で移行が #1114 へ出たため** |

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-15 | B / C-1 | plan / todo / test-cases 生成、`review-self.md` |
| 2026-08-15 | C-2 | 外部レビュー **REJECT**（major 5 / minor 5 / info 3）→ `review-external.md` に `R-001`〜`R-013` |
| 2026-08-15 | C-2 反映 + 簡易 C-1 | 方式を v2 へ変更（**判定を書き写さない**）、`review-self-2.md`（WARN） |
| 2026-08-18 | **C-3 裁定（Human）** | **案 B: 2 分割 / defer 容認 / U-5 持ち越し / R-004 は本 PBI では塞げない** — [裁定コメント](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417) |
| 2026-08-18 | 分割先起票 | **[#1114](https://github.com/s977043/PlanGate/issues/1114)**（既存 apply script の契約適合移行） |
| 2026-08-18 | **裁定の確定反映（v3）+ 簡易 C-1** | 本ブランチ。`review-self-3.md`（**WARN** / exec 不可・人間 C-3 必須） |

## 計画からの変更点（v2 → v3 / **2 分割の反映**）

### 1. スコープの 2 分割

| 対象 | 移動先 |
|------|-------|
| **既存 apply script の exit code 契約への適合（移行）** | **#1114** |
| 個々の apply script の実質ロジック是正（逆方向差分 / 引数解析欠落 / rc≠0 の原因） | **#1114**（v2 では「別 issue 起票のみ」だったものを #1114 に集約） |

**本 PBI に残るもの**: **検出器（`check_pending_applies()`）+ `--dry-run` exit code 契約 + 台帳（マニフェスト）**。
**`scripts/apply-*.sh` は 1 本も変更しない**（台帳への登録のみ）。

### 2. Mode: critical → **high-risk**

引き下げの根拠は「着手を早めたい」ではなく、**critical の主因（多数 script への横断変更）が #1114 へ出たこと**。
6 軸すべてを v2 と対比した表を `plan.md` の「Mode 判定」に置いた。

**ただし正直に記録する**: **タスク数軸だけは 22 のままで critical 帯（21+）に残る**
（旧 T-06 の移設と T-08 の新設が相殺。実測 `grep -c "^| T-" todo.md` = **22**）。
したがって **素の判定ロジック（各軸の最大値）では critical**、
**最終 high-risk は C-3 の明示 override**（mode-classification 判定ロジック 4）である。
override により **V-4 が必須でなくなる**が、`scripts/release-prep.sh` 自体を変更する PBI であるため
**V-4 相当の確認は TC-11 / TC-23 で代替**する（フェーズは落としても検査は落とさない）。
リリースプロセス保護に直結する点は変わらないため `standard` には落としていない。

### 3. #1114 へ移した AC / タスク / TC（**削除ではない**）

| 種別 | ID | 移設先での扱い |
|------|----|--------------|
| Work Breakdown | **旧 Step 5**（apply script を契約適合させる） | #1114 の本体作業 |
| ToDo | **旧 T-06**（同上） | 同上 |
| TC / MUT | **TC-16 / MUT-6**（実 script 全数の判定品質 kill） | #1114。本 PBI は **TC-16' / MUT-6'**（fixture 版）で機構を実証 |
| TC | **TC-06**（実 `apply-task-0146-ehs23-wiring.sh` での AC-3 実証） | #1114。本 PBI は **TC-06'**（fixture 版） |
| TC | **TC-17**（`scope=release` 全行が 3 値に確定） | #1114 完了時の条件。本 PBI は **TC-17'**（`adopted` 全行が 3 値 + `legacy` 全行が `unmigrated`） |
| Stop Condition | **旧 SC-5**（契約適合が `--apply` 挙動を変えた） | #1114。本 PBI の SC-5 は「**`scripts/apply-*.sh` を編集したくなった → 即停止**」に差し替え |

**AC-1〜AC-7 は増減なし。** AC-3 は本 PBI で fixture 実証、実 script 実証は #1114 の受入条件へ引き継ぐ。

### 4. defer の扱い（裁定どおり明記）

- `pending` + **Human 発行 `defer=<別 issue>`** → **WARN**（リリースをブロックしない）
- 名指し対象 = **`apply-ai-loop-workflow-command.sh`**（適用すると 2 週間分の退行）
- **AI は `defer` を増やさない**（SC-2 維持） / **`undecidable` に `defer` を効かせない**（TC-21 維持）
- 実際の `defer` 行投入は **#1114 で当該 script が `adopted` になった後**に Human が行う（todo H-2）

### 5. U-5（CI 未配線）を「意図的な状態」として明示

`grep -rn "release-prep" .github/` → **0 件**。検出器は現状どの workflow からも呼ばれない。
`.github/workflows/*` は **HO のため AI は配線できない**（実測 rc=2）。
本 PBI の機械強制は **`ta-67` 経由で `run-tests.sh` に乗る分のみ**。
plan の Non-goals + **専用節「既知の制約: 検出器は CI で一度も走らない」** + test-cases 末尾節の 3 箇所に明記。

### 6. R-004（`ack` / `defer` の hook 層保護）を follow-up として明記

HO 定義本体（`scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロック）の変更が必要で、
それ自体が HO パス。**本 PBI では塞げない**ことを Non-goals・plan §4・todo T-21・Iron Law に記載。

### 7. 新規に生じた Human 判断: **U-6**

分割により契約非適合 script が残る期間が生まれる。放置すると `--check` が**恒久 NOT READY**。
台帳に **`contract` 列**（`adopted` / `legacy`）を置き、`legacy` を **`unmigrated(#1114)` → WARN** とする案を提示。
第 2 の fail-open にしないため **凍結集合 / 一方向 / #1114 OPEN 検査 / 毎回表示** の 4 拘束 + MUT-8 / MUT-9。
**採否は C-3 で Human が判断**（不採用なら T-08 / TC-25〜28 / MUT-8・MUT-9 を落とすだけで他の設計は不変）。

## 変更していないもの（**重要**）

- **v2 の方式**: 判定を台帳へ書き写さない / script 自身の冪等判定を exit code 契約で読む / self-validating
- **AC-1〜AC-7**
- **穴 (a)(b)(c)(d) と対応 TC の構造**
- `review-self.md` / `review-self-2.md` / `review-external.md`（**追記も書き換えもしていない**）

## 残タスク

- [ ] **👤 H-1: 人間 C-3 APPROVE**（mode=high-risk / autonomous APPROVE 不可）— **U-6 の判断を含む**
- [ ] **👤 H-1b: `c3.json` の発行** — **v3 で `plan_hash` が変わったため、本更新の後に発行すること**
      （working-context.md の順序規約: 確定反映 → 簡易 C-1 → `c3.json` 発行 → exec。
      **本セッションでは発行していない**）
- [ ] 🤖 exec（T-01〜T-22）— C-3 APPROVE 後
- [ ] 👤 H-5: `--check` の CI 配線（`.github/workflows/*` = HO。**U-5 持ち越し・任意**）

### BLOCKED

| タスク | blocker | owner | unblock_condition |
|--------|---------|-------|------------------|
| exec 開始 | C-3 未承認（`c3.json` 未発行） | human | H-1 + H-1b |
| `defer` 行の投入（`apply-ai-loop-workflow-command.sh`） | 当該 script が未 `adopted` | #1114 | #1114 で当該 script が契約適合 |
| **#1114 の着手** | 本 PBI の exec 未完了（契約と台帳が無いと移行先が無い） | 本 PBI | 本 PBI の exec 完了 |

## V 系ステップ進捗

| ステップ | 状態 |
|---------|------|
| C-1（初回 / C-2 反映後 / **v3**）| ✅ `review-self.md` / `review-self-2.md` / **`review-self-3.md`** |
| C-2 | ✅ REJECT → v2 で反映（`review-external.md` `R-001`〜`R-013`）|
| C-3 | ⏸ **裁定 2026-08-18 済（案 B）**。**`c3.json` は未発行** |
| exec 以降 | 未着手 |

## 参照ファイル一覧

- [`plan.md`](plan.md) / [`todo.md`](todo.md) / [`test-cases.md`](test-cases.md) / [`pbi-input.md`](pbi-input.md)
- [`review-self.md`](review-self.md) / [`review-self-2.md`](review-self-2.md) / [`review-self-3.md`](review-self-3.md) / [`review-external.md`](review-external.md)
- [`evidence/`](evidence/)
- issue [#1093](https://github.com/s977043/PlanGate/issues/1093) / 分割先 [#1114](https://github.com/s977043/PlanGate/issues/1114)
- [C-3 裁定コメント](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417)
