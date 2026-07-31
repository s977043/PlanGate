# TASK-0917 作業ステータス

> 最終更新: 2026-07-31 15:53
> 現在フェーズ: **verify（WF-05 Verify & Handoff / T-49・T-50）**
> モード: **critical**（`lite_eligible=false` / V-4 対象 / rollout-policy §2 判定基盤 carve-out ①② 該当のため ai-loop 自走は escalate 固定）
> Issue: [#917](https://github.com/s977043/plangate/issues/917)（P0 / EPIC [#870](https://github.com/s977043/plangate/issues/870) の close blocker）
> branch: `feat/task-0917-delivery`（base `origin/main` = `b45ab17` → 途中で `origin/main` を merge）

## フェーズ履歴

> **日時は `YYYY-MM-DD HH:mm`（分まで）必須**（#463）。各行に**出典**を明記する。
> plan フェーズ（B / C-1 / C-2）の分単位の実時刻は残っていない（`decision-log.jsonl` の `ts` は UTC の名目値で、commit 実時刻・`approved_at` と前後関係が整合しない）。そのため **正式化 PR #931 の merge 時刻を代表値**とし、個々の判定内容は `decision-log.jsonl` を参照する。

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ | 出典 |
|------------------------|---------|------------|------|
| 2026-07-30 21:33 | A: PBI INPUT | `pbi-input.md` 正式化（2 レーンレビュー `R-001`〜`R-016` 全件反映） | commit `20e666f`（PR #925 merge） |
| 2026-07-31 08:26 | C-3 Gate | **APPROVED**（`plan_hash` = `sha256:f72077a3…86cc29`・`plangate approve --force` で再発行） | `approvals/c3.json` `approved_at` = `2026-07-30T23:26:43Z` |
| 2026-07-31 08:30 | B / C-1 / C-2 / River Review | plan・todo（T-1〜T-51）・test-cases（TC 51 件）正式化。**C-1 = FAIL（major 1 = F-1 / minor 5）→ 是正後 PASS**、**C-2 = 2 レーン**（River Review FAIL / 敵対 WARN・`R-017`〜`R-033`・major 12）、**PR 直前 River Review = FAIL**（`RR-01`〜`RR-08`・major 3）→ 全件処理 | commit `adc6c41`（PR #931 merge）/ `decision-log.jsonl` |
| 2026-07-31 11:23 | D: exec Wave 1（T-4〜T-18） | AST 境界検査器 + `gh_exec.py`（AC-5）を新設 | commit `a1964f1` |
| 2026-07-31 11:24 | D: exec Wave 2-3（T-19〜T-26） | 供給経路（`extract_allowed_paths` public 化 / `ci_taxonomy.py`）+ GitHub Collector（AC-1 / AC-2 / AC-8 / AC-9） | commit `3e763ae` |
| 2026-07-31 11:24 | D: exec Wave 4（T-27〜T-32・T-51） | Action Executor / Reconciler（AC-3 / AC-6）+ `finding_type` 語彙の単一定数表化 | commit `84f1f56` |
| 2026-07-31 11:24 | D: exec Wave 5-6（T-33・T-34・T-43） | `ta-57-pr-convergence.sh` 新設（fixture E2E + unit test 7 本の実行導線）+ `ta-56` のラベル是正 | commit `1ad7cc2` |
| 2026-07-31 11:24 | D: exec Wave 7a（T-37〜T-40） | plugin 配布同期へ新規 12 本を追加（2 箇所の列挙を機械照合 / sync 2 回目 no-op） | commit `15f51db` |
| 2026-07-31 11:24 | D: exec Wave 7b（T-41・T-42・T-44） | `delivery-state-machine.md` §4 追補 + `execution-runbook.md` の多層防御記載（contract ブロック不変） | commit `578cb17` |
| 2026-07-31 12:14 | V-3: 敵対レビュー R1（T-45 / 3 レーン） | **FAIL**（critical 6 / major 10 / minor 9）→ 境界検査器の検出漏れ critical 4 件を是正 | commit `b4bc0f6` |
| 2026-07-31 12:57 | V-3: R1 是正（続き） | fail-open 群（critical 2 / major 8 / minor 4）を是正 | commit `41a71a9` |
| 2026-07-31 13:36 | V-3: 敵対レビュー R2（T-46 / 2 レーン） | **FAIL / WARN**（critical 2 / major 5 / minor 4）→ critical 2 件を根本是正（束縛追跡 / fail-closed 既定） | commit `cd50bfc` |
| 2026-07-31 14:03 | V-3: R2 是正（続き） | レーン b の major 3 / minor 4（push rc 検査・未消費値の配線）を是正 | commit `d9603d7` |
| 2026-07-31 15:25 | V-3: R3 収束確認 | **FAIL**（critical 2 / minor 1 / info 1）→ `ast.Subscript` 経路を是正し残存脅威モデルを明示 → **critical / major ゼロ収束** | commit `c5001cc` |
| 2026-07-31 15:28 | D: main 取り込み | `origin/main` を merge（衝突なし） | commit `3c1242f` |
| 2026-07-31 15:48 | V-1: 受け入れ検査（T-47 / T-48）+ T-35 / T-36 | 実 PR [#940](https://github.com/s977043/PlanGate/pull/940) で 1 周実走 → 証跡を `evidence/e2e/` に保存（**実装の欠陥 0 件**）。**V-1 = WARN（条件付き PASS）・FAIL 0 件**。AC-4 は部分充足 → **T-35 実施により充足へ更新** | commit `e519a87` / `evidence/e2e/{README,run-log,findings}.md` |
| 2026-07-31 15:53 | WF-05: Verify & Handoff（T-49 / T-50） | `status.md` / `current-state.md` / `handoff.md` を発行。`todo.md` のチェック更新 | 本ファイル / `handoff.md` |

## 全体構成（PR 一覧）

| PR | ブランチ | 状態 |
|----|---------|------|
| （未作成） | `feat/task-0917-delivery` | 本 PBI 本体。`origin` へ `3c1242f` まで push 済み（`e519a87` は未 push）。PR 作成は WF-05 完了後 → C-4 |
| [#940](https://github.com/s977043/PlanGate/pull/940) | `chore/task-0917-e2e-probe` | **draft / OPEN**（head `7b22922`・2026-07-31 15:53 に GET で実測）。**AC-4 検証専用 / DO NOT MERGE**。close + branch 削除は **Human-owned（未了）** |

## 実装状態

| 種別 | 件数 | 内容 |
|------|------|------|
| commit | **13**（`origin/main..HEAD`） | 実装 4 / E2E 1 / plugin sync 1 / doc 1 / 是正 5（R1×2・R2×2・R3×1）+ merge 1・全 commit に `Refs:` あり |
| 変更ファイル | **58**（`git diff --name-only origin/main...HEAD`） | 手作業 19（新規 13 / 改変 6）+ plugin 自動同期 14 + `docs/working/TASK-0917/evidence/` 25 |
| 新規モジュール | 6 + テスト 6 | `gh_exec` / `check_exec_boundary` / `collector` / `ci_taxonomy` / `executor` / `reconciler` |
| `allowed_paths` 逸脱 | **0 件** | 全変更ファイルが `plan.md` 由来の `allowed_paths` 21 件配下（毎コミット前に機械照合） |
| `docs/working/_audit/` の混入 | **0 件** | RR-08 の要件どおり本 branch から除外（`git diff --name-only` に `_audit` は 0 件） |

## 計画からの変更点（9 件）

1. **`test_*.py` にも実行系トークン検査を適用**（plan は「除外 + argv 不変条件のみ」）。plan より**厳格側**への逸脱。
2. **`required_checks[]` ⊇ 照合を checks が settled のときだけ発火**（plan は無条件と読める）。無条件だと repair push 直後に必ず escalate し、AC-4 の 1 周が回らないため。
3. **Executor の pre-check を「head ≠ `expected_parent_sha` かつ祖先」で判定**。`git merge-base --is-ancestor X X` は **exit 0**（コミットは自分自身の祖先）であり、plan 文言どおりの実装では**未 push 時に常に skip して repair が永久に反映されない**。
4. **`gh_exec._spawn()` の監査済み入口を 3 件に凍結**（`run_gh` / `run_git` / `push_pr_head`）。plan には入口数の固定が無かった。
5. **git operand の `..` を range 区切りとしてのみ許可**（Collector が `main...HEAD` を実使用するため）。
6. **`required_checks_empty` を fail-closed 化**。副作用として **required check を定義していない導入先では全 run が escalate する**（前提条件として `execution-runbook.md` に明記済み）。
7. **Wave 7（T-37〜T-44）を T-35 / T-36 より先に実施**（`depends_on` の順序を入れ替え）。doc / 配布の確定を先に済ませ、実走証跡を最終形の実装に対して取るため。
8. **T-41 の §4 追補が 5 文 → 8 点に増加**（R1 / R2 / R3 の是正で残存脅威モデルの明示が追加されたため）。
9. **T-43 は `ta-56` のラベルを「51→57 に書き換え」ではなく削除**。V2 候補 `R-033`（件数ラベルがまた乖離する構造）を前倒しで除去し、件数の機械固定は `ta-57` の TC-15 に単一化した。

## V 系ステップ進捗

| ステップ | 結果 |
|---------|------|
| L-0 | **PASS**（`npx markdownlint-cli2 "docs/working/TASK-0917/*.md"` = 0 issues。python は stdlib only / 追加 linter 設定なし） |
| V-1 | **WARN（条件付き PASS）/ FAIL 0 件** — 詳細は [`handoff.md`](./handoff.md) §1 |
| V-2 | 実施なし（コード最適化は R1〜R3 の是正に内包。独立フェーズとしては未実施） |
| V-3 | **実施（3 ラウンド）** — R1 FAIL → R2 FAIL/WARN → R3 FAIL → **critical / major ゼロ収束** |
| V-4 | **未実施**（critical モードのためリリース前チェック対象。PR 作成前に workflow-conductor が制御） |

## テスト結果（実測 / 2026-07-31）

| 対象 | 実測値 |
|------|-------|
| `sh tests/run-tests.sh` | **453 passed / 0 failed**（worktree baseline 429 + `ta-57` の 24） |
| Stop Condition | worktree 下限 **436** に対し **453**（+17）→ 充足 |
| unit tests 合計 | **486**（`check_exec_boundary` 130 / `gh_exec` 60 / `collector` 98 / `ci_taxonomy` 25 / `executor` 48 / `reconciler` 29 / `plan_package` 39 / `delivery` 57） |
| AC-7（判定エンジン不変） | 3 ファイル差分 **0 行** / `test_delivery.py` **57 OK** / contract byte 一致（`cmp -s` = 0・両者 2181 bytes） |
| 実行境界検査 | `check_exec_boundary: clean`（26 ファイル / 違反 0） |
| 実 PR 実走（AC-4 / TC-11） | 実装の欠陥 **0 件**。外部書き込みは**コメント 1 件 + push 1 回のみ** |

## 残タスク

- [ ] **C-4**: PR 作成 → Human レビュー・承認・マージ（**NO MERGE BY AI**）
- [ ] **PR #940 の後片付け**（close + branch `chore/task-0917-e2e-probe` 削除）— **Human-owned**（Executor は原理的に実行できない）
- [ ] Q3 起票 issue（repo 設定の穴 3 件 / [#928](https://github.com/s977043/plangate/issues/928) 系）の対応判断 — 本 PBI の完了条件外
- [ ] **follow-up issue の起票**: `.github/workflows/test.yml` に `fetch-depth: 0` を入れ、AC-7 の差分 0 行検査を PR 時 CI で実行可能にする（`.github/workflows/` は HO 該当のため本 PBI では触らない）
- [ ] `handoff.md` §3 の V2 候補をロードマップ / issue へ反映
- [ ] WF-05 成果物（`status.md` / `current-state.md` / `handoff.md` / `todo.md`）の commit（**T-49 の最終 1 コミット**。オーガナイザーが実施）

## モード判定結果

**critical**（`plan.md` §Mode判定のまま不変）。判定根拠: 受入基準 9 件 / 手作業変更ファイル 19 本 / タスク 51 件 / **リポジトリに初めて外部作用層を導入**する。`lite_eligible=false`・人間 C-3 詳細レビュー必須・V-4 対象。

## 次の作業（Claude Code プロンプト）

```text
TASK-0917（#917 実 PR 収束 / Collector・Executor・Reconciler）の WF-05 は完了済み。
worktree: /Users/user/Documents/GitHub/plangate-wt-0917（branch feat/task-0917-delivery）

まず docs/working/TASK-0917/current-state.md → handoff.md の順に読むこと。

次にやること:
1. WF-05 成果物 4 ファイル（status.md / current-state.md / handoff.md / todo.md）を
   1 コミットにまとめて push（Refs: #917。docs/working/_audit/ を混入させない）
2. gh pr create で PR を作成（base main / head feat/task-0917-delivery）。
   本文は handoff.md §5 の引き継ぎ文書を要約し、既知課題 8 件と
   「AC-7 の差分 0 行検査が PR 時 CI では空振りする」ことを明記する
3. C-4（Human レビュー・マージ）を待つ。**AI はマージしない**
4. マージ後に Human が PR #940 を close + branch 削除（AI は実行不可）
5. follow-up issue を起票: .github/workflows/test.yml の fetch-depth: 0

禁止: plan.md の編集（plan_hash が無効化される） / delivery.py・c3_contract.py・
c3prime_verify.py の変更（AC-7） / .github/workflows/ の変更（HO 該当）
```

## 参照ファイル一覧

- [`handoff.md`](./handoff.md) — WF-05 完了資産（必須 6 要素）
- [`current-state.md`](./current-state.md) — 現在状態のスナップショット
- [`plan.md`](./plan.md) / [`todo.md`](./todo.md) / [`test-cases.md`](./test-cases.md) — C-3 承認済み（`plan.md` は編集禁止）
- [`review-self.md`](./review-self.md) / [`review-external.md`](./review-external.md) — C-1 25 項目 / `R-001`〜`R-035` + `RR-01`〜`RR-08`
- [`evidence/e2e/README.md`](./evidence/e2e/README.md) / [`run-log.md`](./evidence/e2e/run-log.md) / [`findings.md`](./evidence/e2e/findings.md) — AC-4 実走証跡
- [`docs/workflows/ai-loop/delivery-state-machine.md`](../../workflows/ai-loop/delivery-state-machine.md) / [`execution-runbook.md`](../../workflows/ai-loop/execution-runbook.md) — 正本 doc
