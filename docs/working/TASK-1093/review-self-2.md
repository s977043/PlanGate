# 簡易 C-1 再レビュー — TASK-1093 (#1093) / C-2 反映後

> 実施: 2026-08-15 / mode=**critical**（v2 で high-risk から引き上げ）
> 対象: C-2（REJECT / major 5・minor 5・info 3）を **1 回確定反映**した後の
> `plan.md` / `todo.md` / `test-cases.md`
> 位置づけ: working-context.md の順序規約 (3) **簡易 C-1**。初回 C-1 は `review-self.md`

## 総合判定: **WARN**（exec 不可 — **人間 C-3 が必須**。mode=critical のため autonomous 不可）

C-2 の major 5 件はすべて反映済みで、**方式変更により R-001 / R-002 / R-003 は
「緩和」ではなく「構造的に消滅」**させた。残る WARN は **Human 判断 3 件（U-1 / U-4 / U-5）**
と、**本 PBI では塞げないと結論した 1 件（R-004 の hook 層保護）**による。

## Plan チェック（7 項目・簡易）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | **PASS** | AC-1〜AC-7 が TC に 1:1。C-2 反映で **TC-17〜TC-24 の 8 本**と **E-09 / E-10**、**MUT-6 / MUT-7** を追加。穴 (a)(b)(c)(d) の対応表も更新 |
| C1-PLAN-02 | Unknowns 処理 | **WARN** | U-2 は解決（方式変更で遡及が前提化）。**U-1 / U-3 が残り、U-4（スコープ分割）/ U-5（CI 配線）が新規追加**。いずれも **Human 判断として明示**し H-1 に紐付け済（隠していない） |
| C1-PLAN-03 | スコープ制御 | **WARN** | Non-goals は明確だが、**契約適合が `scope=release` 31 本に及び Mode が critical へ上がった**。これは C-2 指摘への正当な対応だが**スコープ拡大には違いない**ため、U-4 として C-3 の明示判断を求める形にした |
| C1-PLAN-04 | テスト戦略 | **PASS** | Unit / Integration / **判定品質（MUT-6）** / 環境同値 / Mutation / extras 契約 / sandbox コスト / 回帰 baseline の 8 層。**v1 に欠けていた「判定そのものを殺す変異」を追加**（R-002 の中核） |
| C1-PLAN-05 | Work Breakdown の Output | **PASS** | 全 13 Step に成果物。Step 1 は実測済み |
| C1-PLAN-06 | 依存関係 | **PASS** | **T-05→T-06（契約正本化が先）/ T-06→T-07（script 適合が先、逆だと全件 undecidable）** を新規に明記。H-1→T-04 以降も維持 |
| C1-PLAN-07 | 動作検証の自動化 | **PASS** | evidence は `<repo_root>` 引数で再実行可能。TC-10 のみ半自動と明示 |

## ToDo チェック（5 項目・簡易）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TODO-01 | タスク粒度 | **PASS** | Agent 22 / Human 5。critical 帯（21+）と整合 |
| C1-TODO-02 | depends_on | **PASS** | 全タスクに記載。契約→適合→検出器の順序を強制 |
| C1-TODO-03 | チェックポイント | **PASS** | 停止条件を **SC-1〜SC-6** に拡張（**SC-5 契約適合が `--apply` 挙動を変えた / SC-6 判定が弱い script を緑にしない** を新設） |
| C1-TODO-04 | Iron Law 遵守 | **PASS** | `--apply` 非実行（sandbox 内も）/ HO 非編集 / `defer` を増やさない / **判定が弱い script を緑にしない** の 4 点。**`--check` の CI 配線が AI にできないこと**も Iron Law の帰結として明記 |
| C1-TODO-05 | 完了条件 | **PASS** | 全実装タスクに `rollback:` 記載 |

## TestCases チェック（3 項目・簡易）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TC-01 | 受入基準との紐付き | **PASS** | AC→TC 表 + 穴→TC 表を更新。構造検査（TC-14〜TC-16, TC-20〜TC-23）の位置づけも明記 |
| C1-TC-02 | Edge case 網羅 | **PASS** | E-01〜E-10。**E-09 / E-10 が「stdout に依存しない」ことを正負両面で固定**（R-003） |
| C1-TC-03 | 自動化可否 | **PASS** | TC-10 を除き全件自動 |

## 追加チェック（critical / リリースプロセス保護帯）

| ID | 観点 | 判定 | 根拠 |
|----|------|------|------|
| C1-EX-01 | HO 判定の正しさ | **PASS** | `scripts/*.sh` / `*.tsv` / `tests/extras/*` / `docs/**` は HO 9 カテゴリ非該当。記号アンカーで参照。**`.github/workflows/*` は HO のため CI 配線を Non-goals に落とした**のは正しい帰結 |
| C1-EX-02 | 承認境界を緩めていないか | **PASS** | 変更は NG を増やす方向のみ（fail-open→fail-closed、`vX.Y.Z` 経路も追加で締める）。`defer` は緩和機構だが **`undecidable` には効かない** + 4 層防御 + 毎回表示 |
| C1-EX-03 | **「手段の棄却 ≠ 穴を塞げない」の遵守** | **PASS** | R-004 の hook 層保護は**代替を探索した上で**「HO 変更が必要＝本 PBI では不可能」と結論し、**follow-up 起票（T-21）+ handoff 既知課題**に落とした。黙って落としていない |

## C-2 指摘の反映漏れ確認

| R-NNN | 反映先が plan/todo/test-cases に存在するか |
|-------|------------------------------------------|
| R-001 | ✅ plan Approach 3/4・todo T-04/T-09・TC-21・E-05 |
| R-002 | ✅ plan 方式変更・Testing Strategy・todo T-16・TC-16/TC-17・MUT-6 |
| R-003 | ✅ plan Approach 1/2・TC-18/TC-19・E-09/E-10 |
| R-004 | ✅ plan Approach 4・todo T-09/T-21・TC-20/TC-21/TC-22（hook 保護のみ **明示的に不可**と記載） |
| R-005 | ✅ plan Constraints・todo T-14 🚩・TC-24 |
| R-006 | ✅ plan Approach 5・todo T-12・TC-23・MUT-7 |
| R-007 | ✅ TC-12 改訂・plan Files 表（runbook = Non-goal） |
| R-008 | ✅ plan verdict 表・todo T-10・TC-09 |
| R-009 | ✅ plan Approach 6・todo T-05 🚩 |
| R-010 | ✅ plan Testing Strategy・todo T-15・test-cases sandbox 方針 |
| R-011 | ✅ plan U-1（名指し）・todo H-1 |
| R-012 | ✅ plan Step 1 🚩・todo T-01 🚩・TC-14 |
| R-013 | — （レビュア自身が反証済・対応不要） |

**反映漏れ: 0 件。**

## 実測に基づく検証（v2 で新たに確認したもの）

| 主張 | 実測コマンド | 結果 |
|------|-------------|------|
| `cmp -s` / `diff -q` 型が実在（R-001） | `grep -ln "cmp -s\|diff -q" scripts/apply-*.sh` | **4 本**（レビュア指摘と一致） |
| EHS-2 marker はコメント（R-002） | `grep -n '# EHS-2 (TASK-0146' bin/plangate` | **`2248:  # ...` = コメント行** |
| `apply-task-0146` の判定は外部 python にあり rc が素通し | スクリプト全文を精読 | `set -eu` + `python3 _apply_task_0146_patches.py $ROOT 1` → **python の rc=1 がそのまま script の rc になる**。契約適合は「verdict を 0/10 に写す」だけで実質ロジック不変 |
| `run_checks \|\| true` の存在（R-006） | `grep -n 'run_checks' scripts/release-prep.sh` | **80（定義）/ 97（--check）/ 125（`\|\| true`）** |
| ta-61 の契約内容（R-005） | `sed -n '210,265p' tests/extras/ta-61-extra-contract.sh` | marker ERE / count==1 / `pg_extra_contract_init <basename-id> <capability>` の一致検査を確認 |
| `check-settings-wiring.sh` の存在（R-008） | `ls scripts/check-settings-wiring.sh` | **存在**（導線として妥当） |
| baseline（AC-7） | `sh tests/run-tests.sh` | **rc=0**（本ブランチ head。件数は契約にしない） |

## 指摘事項（v2）

| ID | Severity | 内容 | 対応 |
|----|----------|------|------|
| **S-1** | **major → Human 判断へ移送** | **Mode が critical に上がり、31 本の apply script に触れる**。C-2 指摘への正当な対応だがスコープ拡大 | **U-4** として C-3 判断（単一 PBI / 分割の 2 案を提示） |
| **S-2** | **major → 本 PBI では塞げないと結論** | `defer` は非 HO パスの承認トークンで **hook が block しない**（R-004） | 4 層防御で緩和 + **follow-up 起票**。handoff 既知課題。**塞げないことを明記** |
| **S-3** | minor | `--check` は **CI 未配線**（0 件）。機械強制は `ta-67` 経由の分のみ | **U-5** として C-3 判断。plan Non-goals に明記済 |
| **S-4** | minor | MUT-6 で**判定が弱い script** が顕在化した場合、本 PBI では直せない（Out of scope） | **緑にしない**（SC-6）+ 名指し報告 + 別 issue（T-21） |
| **S-5** | info | sandbox コストが `timeout-minutes: 10` を超える可能性 | 最小サブツリー + 使い回し。超過時は MUT-6 退避を明記（R-010） |

## exec 開始条件

- [ ] **H-1: 人間 C-3 APPROVE**（mode=critical / **autonomous APPROVE 不可**）
- [ ] **U-1**: 初期 `defer` の是非（**`apply-ai-loop-workflow-command.sh` を名指しで**判断）
- [ ] **U-4**: スコープ分割（A: 単一 critical PBI / B: 検出器と移行を分割）
- [ ] **U-5**: `--check` の CI 配線を Human が行うか、`ta-67` 経由で足りるとするか
- [x] C-2 実施済（REJECT → 本反映で対応）
- [ ] **`c3.json` は未発行**（本セッションでは発行しない。Human が確定後 plan の `plan_hash` で発行）
