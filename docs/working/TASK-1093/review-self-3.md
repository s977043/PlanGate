# 簡易 C-1 再レビュー（v3） — TASK-1093 (#1093) / C-3 裁定 2026-08-18 反映後

> 実施: 2026-08-18 / mode=**high-risk**（**v2 の critical から戻した**）
> 対象: [C-3 裁定](https://github.com/s977043/PlanGate/issues/1093#issuecomment-5320820417)
> （案 B: 2 分割 / defer 容認 / U-5 持ち越し / R-004 は本 PBI では塞げない）を
> **1 回確定反映**した後の `plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md`
> 位置づけ: working-context.md 順序規約 (3) **簡易 C-1**。
> 初回 C-1 = `review-self.md` / C-2 反映後 C-1 = `review-self-2.md`（**いずれも書き換えていない**）

## 総合判定: **WARN**（exec 不可 — **人間 C-3 が必須**。mode=high-risk のため autonomous APPROVE 不可）

**WARN の内訳**: ① **U-6**（新規の Human 判断）/ ② **Mode の override**（素の判定は critical・
差分はタスク数軸のみ）/ ③ 継続 WARN（U-5 持ち越し・R-004 は塞げない）。

裁定 4 点はすべて反映済み。**方式（v2 = 判定を書き写さない / exit code 契約 / self-validating）は
一切変更していない**。残る WARN は **新規に 1 件の Human 判断（U-6）**が生じたことによる。

U-6 は「分割したせいで契約非適合 script が残る期間、`--check` をどう扱うか」であり、
**分割そのものが構造的に生む論点**である。plan で握りつぶさず明示した。

## Plan チェック（7 項目・簡易）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | **PASS** | AC-1〜AC-7 は**増減なし**。#1114 へ移した TC は **専用表で「移した」と明記**し、AC-3 は fixture 版（TC-06'）で機構を実証 + 実 script 実証を #1114 の受入条件へ引き継ぐ。U-6 に対し TC-25〜28 / E-11 / E-12 / MUT-8 / MUT-9 を追加 |
| C1-PLAN-02 | Unknowns 処理 | **WARN** | U-1 / U-2 / U-4 は**解決済として表に残した**（消していない）。U-3 は異議なし。**U-5 は「未決・持ち越し」と明示**し Non-goals + 専用節 + test-cases 末尾の 3 箇所で「意図的な状態」と読めるようにした。**U-6 が新規**（Human 判断） |
| C1-PLAN-03 | スコープ制御 | **PASS** | v2 で WARN だった「31 本に及ぶスコープ拡大」が **#1114 へ分離されて解消**。逆方向の逸脱（AI が apply script を触る）は **SC-5 / T-20 / Iron Law** の 3 重で止める |
| C1-PLAN-04 | テスト戦略 | **PASS** | 8 層構成を維持。判定品質層を **fixture 版（MUT-6'）に置換**し、実 script 全数版を #1114 へ。**移行状態層（U-6）を新設** |
| C1-PLAN-05 | Work Breakdown の Output | **PASS** | 再採番後の全 13 Step に成果物。旧 Step 5（移行）を除去、Step 6（`contract` 実装）を新設 |
| C1-PLAN-06 | 依存関係 | **PASS** | 旧「T-05→T-06→T-07（契約→適合→検出器）」を **「T-05→T-06（契約→検出器）」+「本 PBI→#1114」** に組み替え。**#1114 が本 PBI の exec 完了を前提とすることを両側に記載**（#1114 issue 本文の「依存」節と一致） |
| C1-PLAN-07 | 動作検証の自動化 | **PASS** | evidence は `<repo_root>` 引数で再実行可能。TC-10 のみ半自動と明示 |

## ToDo チェック（5 項目・簡易）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TODO-01 | タスク粒度 | **WARN** | Agent タスクは **実測 22 本（T-01〜T-22。todo.md のタスク行を数えて確認）で v2 から減っていない** — 旧 T-06（移行）を #1114 へ移した一方 **T-08（`contract` 実装）を新設**したため相殺した。**定量軸では critical 帯（21+）に残る**。plan の Mode 判定でこれを**隠さず明記**し、high-risk は **C-3 override** によるものと記録した。Human 6 |
| C1-TODO-02 | depends_on | **PASS** | 全タスクに記載。**H-1b（`c3.json` 発行）を独立タスク化**し、v3 で `plan_hash` が変わることを明記 |
| C1-TODO-03 | チェックポイント | **PASS** | 停止条件を **SC-1〜SC-7** へ。**SC-5 を「`--apply` 挙動を変えた」から「`scripts/apply-*.sh` を編集したくなった」へ差し替え**（分割後の正しい境界）。**SC-7（`legacy` の値域拡大）を新設** |
| C1-TODO-04 | Iron Law 遵守 | **PASS** | `--apply` 非実行 / **apply script 非編集（新規）** / HO 非編集 / **defer を増やさない** / **`undecidable` に defer を効かせない** / **`legacy` を広げない** / 判定品質の変異を緑にしない |
| C1-TODO-05 | 完了条件 | **PASS** | 全実装タスクに `rollback:` 記載。**ロールバックが単段になった**（移行の段は #1114 が持つ）ことは Mode 判定表にも反映 |

## TestCases チェック（3 項目・簡易）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TC-01 | 受入基準との紐付き | **PASS** | AC→TC 表を更新。**#1114 へ移した TC を削除せず専用表に列挙**（TC-16/MUT-6・TC-06・TC-17 の 3 件と、各々の本 PBI 側代替） |
| C1-TC-02 | Edge case 網羅 | **PASS** | E-01〜E-12。**E-11（`contract` 未知値→undecidable）/ E-12（`legacy` と `defer` の二重免除を禁止）** を追加 |
| C1-TC-03 | 自動化可否 | **PASS** | TC-10 を除き全件自動。**「CI で走らない」ことを test-cases 末尾に明記**し、CI 実行を前提とする assert を禁止 |

## 追加チェック（high-risk / リリースプロセス保護帯）

| ID | 観点 | 判定 | 根拠 |
|----|------|------|------|
| C1-EX-01 | Mode 判定の妥当性 | **WARN（override として記録）** | 6 軸すべてを v2 と対比した表で再判定し、**5 軸が high-risk 帯**。引き下げの根拠は**「critical の主因＝多数 script への横断変更が #1114 へ移った」**ことであり、「着手を早めたいから下げた」ではない。**ただしタスク数軸は 22 のままで critical 帯に残る**ため、**素の判定ロジックでは critical / 最終 high-risk は C-3 の明示 override** と plan に明記した（mode-classification 判定ロジック 4）。`standard` には落としていない |
| C1-EX-07 | **override で落ちるフェーズを補っているか** | **PASS** | override により **V-4（critical 専用）が必須でなくなる**。本 PBI は `scripts/release-prep.sh` 自体を変更するため、**V-4 相当の確認を TC-11（`--check`）/ TC-23（`vX.Y.Z` 経路 rc）で代替**すると plan に明記。**フェーズを落として検査も落とす**状態にしていない |
| C1-EX-02 | 承認境界を緩めていないか | **WARN → 構造で担保** | `contract=legacy` は **新しい WARN 経路**であり、実質「一括の猶予」に見えうる。**凍結集合 / 一方向 / #1114 OPEN 検査 / 毎回表示**の 4 拘束を課し、**MUT-8 / MUT-9 で拘束の除去が kill される**ようにした。**採否は U-6 として Human に出した**（AI が単独で導入しない） |
| C1-EX-03 | 「手段の棄却 ≠ 穴を塞げない」の遵守 | **PASS** | R-004（hook 層保護）は **C-3 で「本 PBI では塞げない」と確定**。Non-goals + §4 の裁定注記 + T-21 起票 + handoff 既知課題の 4 箇所に残し、黙って落としていない |
| C1-EX-04 | **絶対件数を契約値にしていないか** | **PASS** | `plan.md` / `todo.md` / `test-cases.md` から「34 本 / 31 本」を**全廃**（`grep` で 0 件）。`pbi-input.md` に残る 1 箇所は**測定時点のスナップショット**と明記し、同値性は `comm -3` に委ねると追記 |
| C1-EX-05 | **行番号アンカーを使っていないか** | **PASS** | HO 正本は「`_override=0` 直後の `case` ブロック」、検出器は `check_pending_applies()`、rc 握り潰しは `run_checks \|\| true` と、**すべて記号 / 関数名で参照** |
| C1-EX-06 | `c3.json` を発行していないか | **PASS** | **未発行**。v3 で `plan_hash` が変わることを plan 末尾・todo H-1b・status.md の 3 箇所に明記 |

## C-3 裁定 → 反映先の対応

| 裁定項目 | 反映先 |
|---------|-------|
| **U-4 / 案 B: 2 分割** | plan v3 注記・Non-goals・Approach 1・Work Breakdown（旧 Step 5 除去）・Files 表・Mode 判定表 / todo v3 注記・旧 T-06 移設・SC-5 差替・Iron Law / test-cases「#1114 へ移した TC」表 / pbi-input Out of scope |
| **Mode を high-risk へ戻す** | plan「Mode 判定」（6 軸の v2↔v3 対比 + 引き下げ理由）/ todo 冒頭 / 本レビュー C1-EX-01 |
| **U-1 / defer を認める** | plan §4「C-3 2026-08-18 の裁定」（名指し対象・**AI は増やさない**・**`undecidable` に効かせない**）/ todo H-2（発行タイミングを #1114 後に）/ SC-2 |
| **U-5 / 未決持ち越し** | plan Non-goals + **「既知の制約: 検出器は CI で一度も走らない」節** / todo H-5 / test-cases 末尾節 |
| **R-004 / 本 PBI では塞げない** | plan Non-goals + §4 裁定注記 / todo T-21 / Iron Law |
| （裁定の帰結として新規） | **U-6**（`contract=legacy` の採否）— plan §3-bis / verdict 表 / R-6・R-9 / SC-7 / todo T-08 / test-cases TC-25〜28・E-11・E-12・MUT-8・MUT-9 |

## 指摘事項（v3）

| ID | Severity | 内容 | 対応 |
|----|----------|------|------|
| **S-6** | **major → Human 判断へ移送** | 分割により**契約非適合 script が残る期間**が生まれ、放置すると `--check` が**恒久 NOT READY** になる | **U-6** として C-3 判断（採用 = `contract=legacy`→WARN / 不採用 = NOT READY を受け入れる）。**どちらも fail-open ではない** |
| **S-7** | minor | `contract=legacy` は「AI が増やせない免除」だが、**新しい WARN 経路**であることに変わりはない | 凍結集合 + 一方向 + OPEN 検査 + 毎回表示 + **MUT-8 / MUT-9** |
| **S-8** | minor | AC-3 の**実 script での実証**が本 PBI から外れる | **削除ではなく #1114 へ移設**と明記。**起票内容に含まれることを T-21 で確認**する |
| **S-9** | **minor → Human 確認事項** | **タスク数 22 は critical 帯のまま**で、high-risk は C-3 override による。todo の粒度を粗くすれば数字上は 20 以下にできるが、**それは数字合わせであり実施しない** | plan / status / 本レビューの 3 箇所に **override である事実**を記録。C-3 で override を追認されたい |
| **S-2**（継続） | major → 塞げない | `defer` / `ack` は非 HO パスの承認トークンで **hook が block しない** | **C-3 で確定**。4 層防御 + follow-up 起票 + handoff 既知課題 |
| **S-3**（継続） | minor | `--check` は **CI 未配線**（実測 0 件） | **U-5 持ち越し**。3 箇所で「意図的」と読めるよう明記 |

## exec 開始条件

- [ ] **H-1: 人間 C-3 APPROVE**（mode=high-risk / **autonomous APPROVE 不可**）
- [ ] **U-6**: `contract=legacy`→WARN を採用するか（不採用なら T-08 / TC-25〜28 / MUT-8・MUT-9 を落とす）
- [ ] **Mode override の追認**: 素の判定は critical（タスク数軸のみ 21+）。high-risk は C-3 override（S-9）
- [x] **U-1 / U-2 / U-4**: 2026-08-18 の C-3 で裁定済
- [x] **U-5**: 「未決のまま持ち越し」で確定（本 PBI は明示するところまで）
- [x] **R-004**: 「本 PBI では塞げない」で確定（follow-up 起票へ）
- [x] C-2 実施済（REJECT → v2 で反映）
- [ ] **`c3.json` は未発行**。**v3 で `plan_hash` が変わったため、Human が本更新の後に発行する**
