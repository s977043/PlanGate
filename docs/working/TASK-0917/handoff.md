---
task_id: TASK-0917
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-07-31
author: qa-reviewer
v1_release: "e519a87"  # WF-05 発行時点の HEAD。以降の完了資産 commit で branch HEAD は前進する（確定は C-4 マージ時）
---

# TASK-0917 Handoff Package

> WF-05 Verify & Handoff の必須出力（`.claude/rules/hybrid-architecture.md` Rule 5）。
> 対象: **実 PR 収束（GitHub Collector / Action Executor / Reconciler）**

## メタ情報

```yaml
task: TASK-0917
related_issue: https://github.com/s977043/plangate/issues/917
parent_epic: https://github.com/s977043/plangate/issues/870
author: qa-reviewer
issued_at: 2026-07-31
mode: critical
branch: feat/task-0917-delivery
v1_release: e519a87  # WF-05 発行時点の HEAD。未 merge（PR 未作成）で、完了資産 commit により branch HEAD は前進する。C-4 承認・マージをもって確定
c3_gate: APPROVED (2026-07-30T23:26:43Z / plan_hash sha256:f72077a3...86cc29)
c4_gate: pending
```

## 1. 要件適合確認結果

**V-1 総合判定: WARN（条件付き PASS）— FAIL 0 件**。9 基準中 **8 PASS / 1 WARN / 0 FAIL**。

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| **AC-1** snapshot が head SHA に束縛（`checks[].sha` / `review.sha` = `head_sha`） | **PASS** | TC-01 / 01a / 01b / 01c / 02 / 03（`test_collector.py` 98 tests）。実走でも check-run 7 件すべて head 一致・stale 混入なし（`evidence/e2e/run-log.md` §2）。旧 head の `APPROVED` は採用せず `{"state":"none"}` に縮約 |
| **AC-2** `required_checks[]` ⊇ 照合で部分登録 green を拒否 | **PASS** | TC-04（負側 / 中核）/ TC-05 / TC-06。取得失敗は `required_checks_fetch_failed:<reason>`、空集合は `required_checks_empty` で**いずれも fail-closed**。⚠️ 実 repo の required checks は `["Markdown lint"]` の **1 件のみ**で実効カバレッジは薄い（`findings.md` F-3。実装ではなく repo 設定側の事実） |
| **AC-3** intent → 実行 → receipt → reconcile が冪等 | **PASS** | TC-07 / 08 / 09 / 09b（`test_executor.py` 48 / `test_reconciler.py` 29）。実走で同一 action 再実行 = `already_receipted` / **subprocess 起動 0 回**、Reconciler は intent 1 / receipt 1 / pending 0 / orphan 0 |
| **AC-4** 実 PR の repair E2E が 1 周通る | **PASS**（条件付き） | TC-10（fixture = 機械化された合格基準 / `ta-57`）+ **TC-11（実 PR #940 で 1 周実走・T-35 / T-36）** + TC-39。`WAITING_FOR_REVIEW` → `WAITING_FOR_CHECKS` → `WAITING_FOR_REVIEW` の遷移を実データで確認し**実装の欠陥 0 件**。条件: repair commit の生成主体は Executor の外（`findings.md` F-9）、`repair_ci` intent は `assess()` 由来ではなく同一形状で組み立て（F-10）＝**「1 周の完全自動」は未達**（scope 外） |
| **AC-5** 破壊的操作を実行する経路が存在しない | **PASS**（scope 限定） | TC-20〜TC-31 / 31b / 31c（`test_gh_exec.py` 60 / `test_check_exec_boundary.py` 130）。`check_exec_boundary: clean`（26 ファイル / 違反 0）。実走の spawn ledger に merge / review / close / force / delete は **1 件も出現しない**。⚠️ **scope は「Executor 経路のみ」**（in-process allowlist はプロセス外の `gh` を塞がない。C-3 で承認済みの限界） |
| **AC-6** #894 Loop Control Contract との接続点 | **WARN** | TC-12 / TC-13（fixture 統合テスト）は PASS。`escalation_flags` の opaque reason code が `assess()` を素通しして `HUMAN_ESCALATED` に到達し `record.jsonl` に state entry が残ることを固定。⚠️ **実 PR 実走では未実証**（3 回の collect すべて `escalation_flags` が空で `apply_escalation_flags()` が未呼出 / `findings.md` F-8）。実データによる実証は #894 の enum 確定後 |
| **AC-7** `delivery.py` / `c3_contract.py` / `c3prime_verify.py` が不変 | **PASS** | TC-14 / 15 / 16。`git diff --stat origin/main -- <3 ファイル>` = **0 行**（2026-07-31 15:53 再実測）/ `test_delivery.py` = **57 OK** / contract byte 一致（`cmp -s` = 0・両者 2181 bytes）。⚠️ この検査は **PR 時 CI では実行されない**（既知課題 K-5） |
| **AC-8** `ci_failure_taxonomy` の供給元が機械的に特定できる | **PASS** | 供給主体 = `scripts/ai-loop/ci_taxonomy.py`（`delivery-state-machine.md` §4 に 1 文で明記）。TC-17 / 18 / 19（`test_ci_taxonomy.py` 25 tests）。manual entry 優先・`code` を機械が断定しない・未該当は出力せず既存 fail-closed に委ねる |
| **AC-9** raw check evidence を同梱し `checks[]` の導出を機械照合 | **PASS**（縮小 scope 内） | TC-32 / 33 / 34。`raw_check_runs` を同梱し `verify_raw_evidence()` / `verify_snapshot_evidence()` が導出を照合、改竄 `checks[]` を拒否。⚠️ **縮小実施**（Collector 内自己照合まで。手作り snapshot を `delivery.py` へ直接投入する経路は塞がない）— C-3 Q1 で Human 承認済み |

**総合**: `8/9 基準 PASS + 1 WARN（AC-6）/ FAIL 0`

**WARN の扱い**: AC-6 は接続先（#894 Loop Control Contract）が**未着手で enum 未確定**のため、本 PBI では「I/F だけ先に固定し値は #894 で埋める」（C-3 D5 承認）に限定している。fixture 統合テストで接続点は機械固定済みであり、実データ実証は #894 側の完了後に回す。**V1 リリースを止める理由にはならない**。

## 2. 既知課題一覧

**critical / major の open blocker はゼロ**（V-3 は R3 で critical / major ゼロ収束）。以下は V1 でそのまま出す妥協点と、実走・レビューで判明した周辺課題。

| ID | 課題 | Severity | 状態 | V2 候補か |
|----|------|---------|------|---------|
| K-1 | **PR [#940](https://github.com/s977043/PlanGate/pull/940)（AC-4 検証用 probe）の後始末が未了**。draft / OPEN のまま head = `7b22922`。close + branch 削除は **Human-owned**（Executor は原理的に実行不可） | major | open（Human 待ち） | No（運用タスク） |
| K-2 | **`ta-25` L86 が `[SKIP]` を印字しながら `pass=$((pass + 1))` を実行**。SKIP を pass に計上する fail-open な会計で、**Stop Condition の下限判定精度を静かに下げる**。`allowed_paths` 外のため本 PBI では未修正 | major | accepted | **Yes** |
| K-3 | **`ta-54` TC-05 が「`docs/workflows/ai-loop/` の未コミット差分ゼロ」を assert** するため、当該 doc を編集する PBI は**作業中に必ず 1 FAIL する**（コミットすれば解消）。判定軸が「正しさ」ではなく「コミット状態」になっている | minor | workaround | **Yes** |
| K-4 | **`ta-13` TC-17 が linked worktree では常に SKIP**（`.git` がファイルのため）。worktree 429 / 共有 checkout 430 という baseline 差 1 の実体 | minor | accepted | **Yes** |
| K-5 | **AC-7 の差分 0 行検査が PR 時 CI で実行されない**。`actions/checkout` の `fetch-depth` 既定 1 で base ref が存在せず、`git diff origin/main -- <3 ファイル>` が成立しない。`.github/workflows/` は **HO 該当**のため本 PBI では触っていない | major | open（**follow-up issue が必要**） | **Yes**（`test.yml` に `fetch-depth: 0`） |
| K-6 | **プロダクション runner が存在しない**。`collector.collect` / `executor.execute_actions` / `reconciler.reconcile` の非テスト呼び出し元は `ta-57` のみ ＝ **この 3 層は現時点で誰も起動しない**（実走は harness 経由） | major | accepted（Phase 1 の設計どおり） | **Yes**（exec レーン接続） |
| K-7 | `test_gh_exec.py:583` の docstring が `TC-14` と誤記（正しくは `todo.md` の **`T-14`**） | minor | open | No |
| K-8 | **AC-6 の Executor 側は fixture でのみ実証**。実 PR 実走では `escalation_flags` が 3 回とも空で `apply_escalation_flags()` が未呼出（`findings.md` F-8） | minor | accepted | **Yes** |
| K-9 | **`gh` アカウントのドリフト**。active account が `kominem-unilabo` へ勝手に戻るため、`gh` を使う操作は `gh auth switch --user s977043` と**同一 Bash 呼び出しで atomic 実行**しないと別アカウントで発火する | minor | workaround（手順を `evidence/e2e/README.md` に明記） | No（環境運用） |
| K-10 | `git push` の**失敗パス（rc != 0）が実環境で未実証**。実 PR で意図的に reject を起こすには禁止操作が必要なため fixture（`_push_handler(push_rc=...)`）でのみ担保（`findings.md` F-7） | minor | accepted | **Yes** |

**Critical 課題の対応**: open な critical は **0 件**。K-1 / K-2 / K-5 / K-6 は major だが、いずれも**本 PBI の成果物の正しさではなく周辺（運用・CI 配線・上位レーン）の課題**であり、C-4 レビューでの合意をもって V1 リリース可能と判断する。K-5 のみ **follow-up issue の起票を C-4 前後の必須アクション**とする。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 |
|--------|------|----------|------|
| **プロセス外の物理ガード**（同一セッションの別プロセス / Bash からの `gh` を塞ぐ） | in-process allowlist の原理的限界。hook / CI / branch protection 側の多層防御が要る | **High** | AC-5 / Q3 起票 issue |
| **exec レーン（repair commit の生成主体）の接続** | Executor は publish のみが責務で commit を作らない。「1 周」を無人で回すには commit 生成レーンが別途必要（`findings.md` F-9 / K-6） | **High** | AC-4 / EPIC #870 |
| **`.github/workflows/test.yml` に `fetch-depth: 0`** | AC-7 の差分 0 行検査を PR 時 CI で実行可能にする（K-5）。HO 該当のため本 PBI では触らない | **High** | K-5 |
| **`ta-25` の SKIP 計上の是正** | `[SKIP]` を pass に数える fail-open な会計（K-2）。Stop Condition の下限判定精度に効く | Medium | K-2 |
| **`gh_exec.rules=` の外部差し替えを機械強制で禁止** | 現状はコメントによる意図の凍結まで。allowlist テーブルの差し替えは構造的に塞がれていない | Medium | AC-5 |
| **required checks の config キャッシュ** | 現状は取得失敗を fail-closed に倒すのみ。ただし「取得できない環境で古い集合を正と誤認する」逆リスクがあるため設計を要検討 | Medium | AC-2 / D1-A |
| **実 API drift の継続検出** | fixture は手書きのため実 REST 形状の変化を捕捉できない。定期的な実走 or 契約テストが要る | Medium | `findings.md` A 群 |
| **AC-6 の実データ実証**（`escalation_flags` の伝播） | #894 の enum 確定後に fixture 外で実証する（K-8） | Medium | #894 |
| **`ta-54` TC-05 の判定軸の見直し** | 「未コミット差分ゼロ」は正しさではなくコミット状態を測っている（K-3） | Low | K-3 |
| **`ta-42` の order-dependence** | 中断時の残骸が次回の誤 FAIL を生む | Low | — |
| **`test_c3prime_verify.py` の `["python3", ...]` → `sys.executable`** | 境界検査器の grandfather 例外 1 件の解消。**本 PBI では凍結を維持**（`allowed_paths` を増やさないため） | Low | C-1 F-1 裁定 |
| **`git push` 失敗パスの実環境実証** | probe 用に一時的に push を拒否する branch を用意する等（K-10） | Low | K-10 |
| ~~`ta-56` のテスト件数ラベルの動的抽出~~ | **解消済み**（`R-033` → T-43 でラベル構造ごと除去。件数の機械固定は `ta-57` の TC-15 に単一化） | — | R-033 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| **AST 静的検査は「多層防御の 1 層」と位置づけ、完全性を主張しない** | 「任意の回避経路を塞ぎ切る検査器」 | 敵対レビュー 3 ラウンドで**毎回 1 つ深い回避クラスが出た**（R1: 直接記述・`getattr` → R2: ローカル別名 → R3: `ast.Subscript`）。この事実自体が「塞ぎ切れる」という主張が成り立たない証拠。**保証の主体は runtime の `gh_exec` allowlist + C-4 Human レビュー + branch protection** であり、静的検査はその補助 |
| **AC-9 は縮小実施**（raw 同梱 + Collector 内自己照合まで） | snapshot 供給経路そのものの信頼境界を閉じる | **手作り snapshot を `delivery.py` へ直接投入する経路は塞がない**。Phase 1 の信頼境界は解消しきらない（C-3 Q1 で Human 承認済み） |
| **D1-A: ⊇ 照合を Collector の pre-check + `escalation_flags` に限定** | D1-B: `validate_snapshot()` / `assess()` に `required_checks[]` 分岐を追加 | D1-B は **AC-7（判定エンジン不変）と正面衝突**し、57 テストと contract byte 一致の再設計を招く。代償として ⊇ 照合の正しさは Collector のテストでしか担保されない |
| **`delivery.py` 不可侵（AC-7）のため採れなかった是正 3 件を放置** | `load_entries()` の `entry_id` 欠落拒否 / `assess()` 入口での `verify_snapshot_evidence()` 呼び出し / `cr_incomplete` の実質デッド化の解消 | いずれも `delivery.py` の変更が必要で **Out of scope + AC-7 違反**。次に判定器へ手を入れる PBI で回収する |
| **通知コメント → pre-check → repair push → receipt の順序** | push を先に打つ（コメント失敗で push を止めない） | 逆順だと「不可逆な push 済み・receipt 無し」が発生する。この順序なら中断時の残骸が**可逆な「余分なコメント 1 件」に限定**される（R-021 / C-3 承認）。代償: push しない run でもコメントが残りうる |
| **`required_checks_empty` の fail-closed 化** | 空集合を「制約なし」として通す | 部分登録 green の穴を塞ぐ側に倒した。代償として **required check を定義していない導入先では全 run が escalate する**（前提条件として `execution-runbook.md` に明記） |
| **⊇ 照合を checks が settled のときだけ発火** | plan 文言どおり無条件で照合 | 無条件だと repair push 直後（check 未登録）に必ず escalate し、**AC-4 の 1 周が実 PR で回らない**（実走 F-5 で「push 直後に CodeQL が未登録」を実測） |
| **AC-4 = fixture 主体 + 実 PR 手動実走 1 回** | 実 test repository を新設し CI 常設 | 認証・レート制限・`.github/workflows/`（HO）への波及を避けた。機械化された合格基準は `ta-57` 側に置き、実走は**証跡**として位置づける（再現手順を `evidence/e2e/README.md` に保存） |
| **新規 12 本を plugin 配布へ同梱** | 配布しない（本体のみ） | `delivery.py` を既に配布している前例と一貫。代償として **`executor.py` / `gh_exec.py`（唯一の外部書き込み層）が下流リポジトリに渡る**（carve-out で保護される前提・C-3 Q10 で承認） |

## 5. 引き継ぎ文書

### 概要

`delivery.py`（純判定器 / TASK-0873）の**外側 2 層**を新設した。**GitHub Collector**（実 PR から head SHA 束縛の snapshot を組み立てる）、**Action Executor**（唯一の外部書き込み層）、**Reconciler**（intent ↔ receipt 突合・冪等）に加え、外部作用を構造的に封じ込める **`gh_exec.py`（in-process allowlist）** と **`check_exec_boundary.py`（AST 境界検査器）**、AC-8 の供給主体 `ci_taxonomy.py` を実装した。`delivery.py` / `c3_contract.py` / `c3prime_verify.py` は**一行も変更していない**（差分 0 行を実測）。

現状は **branch `feat/task-0917-delivery` に 14 commit / 変更 64 ファイル**（`origin/main..HEAD` / 2026-07-31 再実測）。`origin` へは `3c1242f` まで push 済みで、**`e519a87` / `aab4d53` の 2 commit が未 push**。うち WF-05 発行時点（`e519a87`）は 13 commit / 58 ファイルで、差分は完了資産 6 ファイルの発行 commit。**PR は未作成**で、次のゲートは **C-4（Human レビュー・マージ）**。テストは `sh tests/run-tests.sh` = 453 passed / 0 failed、unit 486 件。実 PR [#940](https://github.com/s977043/PlanGate/pull/940) で 1 周を実走し**実装の欠陥は 0 件**だった。**PR #940 は draft / OPEN のまま残っている**ので、C-4 後に人間が close + branch 削除すること。

### 触れないでほしいファイル

- `scripts/ai-loop/delivery.py` / `c3_contract.py` / `c3prime_verify.py`: **AC-7 で差分 0 行を固定**。触ると 57 テストと contract byte 一致が壊れ、承認境界の契約が破綻する
- `docs/workflows/ai-loop/delivery-state-machine.md` の `<!-- contract:begin/end -->` ブロック: `ta-56` の `cmp -s` が byte 一致を検査する（手編集禁止・emit から再生成する）
- `docs/working/TASK-0917/plan.md`: **C-3 承認済みで `plan_hash` に束縛**。編集すると `plan_hash` が無効化され exec がブロックされる
- `.github/workflows/**` / `bin/plangate` / `schemas/**` / `.claude/**`: **HO（Hardening Override）該当**。本 PBI では意図的に非接触

### 次に手を入れるなら

- **推奨**: ①K-5 の follow-up（`test.yml` に `fetch-depth: 0`）→ ②exec レーンを繋いで「1 周の完全自動」（K-6 / F-9）→ ③#894 確定後に AC-6 を実データで実証
- **`gh_exec.py` の allowlist を触るときは必ず負側テストから**。allow 経路の一意性（rule table を空にすると全 allow が Denied）と末尾の無条件 `raise Denied` が設計の要
- **アンチパターン**: 「AST 検査器を強化したから安全」と考えること。**3 ラウンドで 3 回とも新しい回避クラスが出た**。検査器は 1 層に過ぎず、`gh_exec` allowlist（runtime）と C-4 Human レビューが保証の主体
- **アンチパターン**: `escalation_flags` を握り潰して snapshot を破棄すること。破棄すると `record.jsonl` に state entry が残らず、#894 の no-progress 検知が「何も起きていない run」と区別できなくなる
- **アンチパターン**: `allowed_paths` を広げて逸脱を解消すること（AC-5 / scope を緩める方向の是正はしない）
- **運用**: `gh` を使う処理は `gh auth switch --user s977043` と**同一 Bash 呼び出しで atomic 実行**する（K-9）

### 参照リンク

- Issue: [#917](https://github.com/s977043/plangate/issues/917) / EPIC: [#870](https://github.com/s977043/plangate/issues/870)（close blocker）
- plan: [`plan.md`](./plan.md) / todo: [`todo.md`](./todo.md) / test-cases: [`test-cases.md`](./test-cases.md)
- status: [`status.md`](./status.md) / current-state: [`current-state.md`](./current-state.md)
- AC-4 実走証跡: [`evidence/e2e/README.md`](./evidence/e2e/README.md)（再現手順）/ [`run-log.md`](./evidence/e2e/run-log.md)（実測値）/ [`findings.md`](./evidence/e2e/findings.md)（F-1〜F-10）
- 正本 doc: [`delivery-state-machine.md`](../../workflows/ai-loop/delivery-state-machine.md) / [`execution-runbook.md`](../../workflows/ai-loop/execution-runbook.md)

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit（本 PBI 関連 **8 本**: `check_exec_boundary` / `gh_exec` / `collector` / `ci_taxonomy` / `executor` / `reconciler` / `plan_package` / `delivery`） | **486** | **486** | 0 / 0 | AC-1〜AC-3 / AC-5 / AC-8 / AC-9 の全 TC |
| Integration（`test_reconciler.py` に内包） | 上記に含む | 全 PASS | 0 / 0 | Collector → `assess()` → Executor → receipt → Reconciler の 1 周（TC-09b / TC-12 / TC-13） |
| E2E（`sh tests/run-tests.sh` / shell harness 全体） | **453** | **453** | **0** / —（`ta-13` TC-17 は linked worktree で SKIP） | `ta-57-pr-convergence.sh` の 24 件を含む |
| 手動 E2E（実 PR 1 周 / TC-11） | 1 周 | 1 周 | 0 | AC-4。外部書き込みは**コメント 1 件 + push 1 回のみ** |

**unit の内訳**: `check_exec_boundary` 130 / `gh_exec` 60 / `collector` 98 / `ci_taxonomy` 25 / `executor` 48 / `reconciler` 29 / `plan_package` 39 / `delivery` 57 = **486**

> ⚠️ **486 は上記 8 本の合計であって `scripts/ai-loop/test_*.py` の glob 全体ではない**。glob は **13 本**（上記 8 本 + `arbiter` 247 / `discovery` 42 / `metrics` 40 / `c3_contract` 22 / `c3prime_verify` 12）で、13 本すべてを実行すると **849**（2026-07-31 実測）。glob 表記で再実行して 849 を得ても 486 は誤りではない。

**Stop Condition**: worktree 下限 **436**（= worktree baseline 429 + 新規 PASS 行 7）に対し実測 **453**（+17）→ 充足。共有 checkout の baseline は 430（差 1 は `ta-13` TC-17 の worktree SKIP / K-4）。

**AC-7 の 3 点**（再実測 2026-07-31 15:53）:

- `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py` → **0 行**（出力なし / exit 0）
- `python3 scripts/ai-loop/test_delivery.py` → **`Ran 57 tests ... OK`**
- contract ブロックの `cmp -s` → **byte 一致**（両者 2181 bytes）

**実行境界検査**: `python3 scripts/ai-loop/check_exec_boundary.py` → **`clean`（26 ファイル / 違反 0）**

**FAIL / SKIP の詳細**: FAIL は 0 件。`[SKIP]` の印字は **3 件**（2026-07-31 実測）:

- `ta-13` TC-17 — linked worktree では `.git` がファイルのため常に SKIP（**pass 非計上** / K-4）
- `ta-05` F-8 — `schemas/c3-prime.schema.json` が配置済みのため SKIP（**pass 非計上**）
- `ta-25` TC-06 — `[SKIP]` を印字しながら `pass=$((pass + 1))` を実行（**pass 計上** / K-2）。**計上方法自体が既知課題**

453 の内訳に影響するのは pass 計上される `ta-25` TC-06 のみで、**453 という実測値は不変**。

## 7. Metrics summary（v8.6.0+、任意）

**該当なし**（本 PBI では `bin/plangate metrics` を収集していない。`bin/plangate` は HO 該当で本 branch から非接触のため、metrics 収集は別途実施する）。

参照: [`docs/ai/metrics.md`](../../ai/metrics.md)
