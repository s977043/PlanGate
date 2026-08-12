---
task_id: TASK-0921
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-08-12
author: exec-worker (qa 相当) / orchestrator 統合
v1_release: ""
---

# Handoff Package — TASK-0921（#921 Slice 1）

> 対象: 「静かに通る失敗」封鎖 — extras 共有 exit 契約 helper + 層 A 12 本移行 +
> contract TA（ta-61）+ README 規約。ブランチ `fix/0921-exec`（HEAD `db1c0bd`、
> base = origin/main `5e630f9`）。**push / PR / merge は未実施（Human-owned フローで後続）**。

## メタ情報

```yaml
task: TASK-0921
issue: "#921"
slice: 1 (層 A 12 本 + helper + contract TA + README = 15 ファイル)
mode: high-risk
branch: fix/0921-exec
head: db1c0bd
```

## 1. 要件適合確認結果（AC ごと）

> DoD 正本 = `test-cases.md` `## Exit Criteria` Slice 1 節。以下は AC 軸の要約。

| AC | 判定 | 根拠（evidence） |
|---|---|---|
| AC-1（層 A 12 本の範囲） | **PASS** | TC-04/05/12/13 実走（`ta61-standalone-run{1,2}.log` 74/0）。fail 注入は force-fail probe で全 12 本 rc=1 実証 |
| AC-2 (a) fail 注入 → exit 1 | **PASS** | TC-12(b) 全 12 本 rc=1 + probe marker |
| AC-2 (b) source 経路完走・集計 | **PASS** | TC-01/TC-14/TC-15/TC-26。full-suite 612/0/rc=0（282s） |
| AC-2 (c) 前提未充足 SKIP = rc=3 | **PASS** | TC-17（synthetic + sandbox 6 本）+ TC-29 dash/bash 両立（`dual-shell-skip.log` / `prereq-rc3.log`）。ta-49 は節スキップで rc は先行 TC に従う（rc=3 非要求 / F2） |
| AC-2 (d) カウンタ初期化 | **PASS** | helper init が `pass=0` / `fail=0`（TC-03/TC-04） |
| AC-3（TC-02 synthetic のみ / 全件は Slice 2） | **PASS** | TC-02 rc=2 + id-bearing message + body sentinel 不生成。TC-11 は対象 0 件の vacuous PASS を明示記録（`harness-only.log` / INFO-1） |
| AC-4（harness 回帰なし + runtime tail -1） | **PASS** | TC-14（最終ファイル ta-61 到達・runtime 解決）/ TC-15 / TC-21 |
| AC-5（allowlist 付き回帰テスト化） | **PASS**（allowlist 45 行付き。空の証明は Slice 2 / TC-24） | TC-25 全 assert（実在・未移行・非空・真部分集合・実行件数 12>0）+ 機械生成/転記 diff 照合（`pending-migration-gen.log` / `pending-migration-diff.log` IDENTICAL） |
| AC-6（README 規約 / TC-19） | **PASS**（writeback は Slice 2） | TC-19 全 token 充足。`tests/extras/README.md` に rc 0/1/2/3・marker・probe・rc2 別名前空間 |
| AC-7（pre-fix FAIL 実証 + 変異） | **PASS** | `pre-fix-head.log`（TC-09×12 / TC-19×4 / TC-25(3) FAIL）+ 変異 **18/18 KILL**（`mutation-summary.log`。M-01 は harness 経路 rc=1 / M-15 は dash=0・bash=1 の両 shell 記録） |
| 補助: HJ-4 規約（original rc 保持） | **PASS** | TC-06（fail=0 / fail>0 とも rc=3 保持）+ 全 12 本末尾 finalize 単独行 + TC-12 probe 実行ベース担保 |
| 補助: HR-4 述語（3 条件 AND） | **PASS** | 層 A 12 + ta-61 + helper = 14 箇所が plan `### Mode resolution` と文字単位同一（機械照合 bad=0）+ TC-01b/TC-01c |
| Human 側 DoD | **未了（Human-owned）** | C-4（H-02）。C-3 再承認は 2026-08-10 裁定反映後に発行済み（validate PASS） |

## 2. 既知課題一覧

1. **層 C の空振り PASS は本 PBI では一切解消しない**（HJ-2 裁定＝Slice 2 の D-2 (c) に委譲。
   harness モードでの層 C 空振り・将来ファイルの同種再生産は Slice 1 では機械検出されない）
2. **HR-4 残存**: 3 変数（PG_HARNESS_SOURCED / FIXTURES_DIR / EXTRAS_DIR）すべてが
   汚染された場合は依然 harness 分岐へ落ちる（裁定時に受容済みの残存リスク。
   **follow-up は issue #1044 起票済み**）
2-bis. **F-3: finalize 側既定値の非対称**（river-review info）: `_extra-contract.sh` の
   `pg_extra_contract_is_standalone`（`${_PG_EXTRA_STANDALONE:-1}`）と
   `pg_extra_contract_finalize`（`${_PG_EXTRA_STANDALONE:-0}`）で未初期化時の既定が
   非対称。**init 前に finalize を呼ぶ契約違反ファイルでのみ発現**し、その形は TC-10
   （top-level init 必須）が静的検出する。**helper を変更すると変異 evidence 18 本の
   HEAD 整合が失効するため本 PR では修正しない**。#1044 と同族の follow-up 対象
3. **helper 変異の self-referential swallow**: helper を壊す変異は contract TA 自身の
   standalone rc も同経路で壊しうる（M-01 で顕在化）。standalone チャネル単独では
   kill を偽陰性にしうるため、helper 変異クラスの検証は harness 経路（runner 集計）併用が必要
4. **ta-31 の分岐内 `return 0 2>/dev/null || true` 4 箇所**は層 B のため未解消（Slice 2 / R-021 残余）
5. **standalone 実行残骸**: ta-41 / ta-42 / ta-44 の standalone 実行が `docs/working/` 配下へ
   実ディレクトリを残す（issue #1021 と同クラス）。本 exec で 5 ディレクトリを削除したが
   恒久修正はスコープ外（#1021 系 follow-up）
6. **worktree では `doctor --check-settings` FAIL**（untracked settings 非複製の環境事由。
   本体 checkout は PASS 実測済み）
7. **rc=2 名前空間の読み違い余地**（構文破損の rc=2 と harness-only 拒否の rc=2）は
   TC-27 で緩和したが完全解消はしない（test-cases MN-H の既知の限界）

## 3. V2 候補（今回スコープ外）

| 候補 | 出典 |
|---|---|
| Slice 2: 層 B 36 + 層 C 5 の harness-only 移行（T-04）+ 層 0 4 本の footer 吸収（T-04b）+ `_pending_migration` 0 行化・関数削除（TC-24 / AC-5） | todo.md Slice 2 |
| `TASK-0914/handoff.md` §3 の CLOSED writeback（AC-6 後半） | T-07 / Slice 2 |
| HJ-1 / HJ-3 の CI patch 適用（HO 対象・Human 裁定待ち。patch は status.md に提示済み） | R-022 / R-026 |
| ta-54 の破壊的テスト（`rm -rf` trap なし復元）・ta-49 固定名 /tmp の是正 | status.md 未処理表 |
| standalone 実行残骸の構造的封鎖 | issue #1021 |

## 4. 妥協点（採用しなかった選択肢と理由）

1. **案 C（trap 方式）不採用 → 案 D（末尾 explicit finalize）**: `trap -p` が dash/zsh で
   使用不可・README 規約「trap は使わない」と衝突（実測で確定、Human 決定 1）
2. **allowlist の述語解決を不採用 → 明示 heredoc リスト**: 述語だと marker/init を持たない
   新規ファイルが黙って除外される（MJ-E。M-13 predicate 変異で FAIL を実証済み）
3. **ta-49 への一律 rc=3 を不採用 → 節スキップ**: 先行 TC が実走・集計済みのため rc=3 は
   「検査していない」の誤表明になり precedence（fail>0 → rc=1）と矛盾する
4. **「フルスイート 3 連続」→「フルスイート 1 回 + contract TA 単独 2 回」**（R-017 の CI 時間裁定。
   flaky 観測時は撤回する条件付き — 本 exec では flaky 観測なし）
5. **M-01 の standalone チャネルでの kill 実証を断念 → harness 経路で確定**（構造上不可能で
   あることを実測で確認。既知課題 3 として明示）

## 5. 引き継ぎ文書（5 分サマリ）

- **何をしたか**: extras の standalone 実行で `[FAIL]` を出しても rc=0 で通る「静かに通る失敗」を
  封鎖した。共有 helper `tests/extras/_extra-contract.sh`（rc 0/1/2/3 契約 + finalize precedence +
  probe seam + cleanup registry）を新設し、層 A 12 本（ta-39/40/43〜47/49〜53）を bootstrap +
  末尾 finalize へ移行。早期脱出 2 型 7 件（`|| exit 0` 3 + `|| true` 4）を除去し、全体ガード 6 本は
  `pg_extra_contract_skip`（rc=3）、ta-49 は節スキップ化。contract TA `ta-61` が marker/init/
  rc 契約/allowlist 健全性/dual-shell を回帰検査する。README に規約を正本化
- **状態**: exec 完了・全 GREEN・変異 18/18 KILL。**push / PR 未作成**。次は V-1 →
  PR 作成 → Human C-4。HJ-1/HJ-3 は patch 提示済み（Human 裁定・適用待ち）
- **読む順**: `current-state.md` → `status.md`「exec（Slice 1）実施記録」→
  `test-cases.md` `## Exit Criteria`（Slice 1 節）→ evidence
- **Slice 2 着手時**: Mode 再判定（H-04）+ AC-8 の pbi-input 追記裁定（H-05）が前提。
  `_pending_migration` から移行のたびに行を削除し、完了時に関数ごと削除

## 6. テスト結果サマリ

| 実行 | 結果 | evidence |
|---|---|---|
| RED（helper 不在 / 層 A 未移行） | rc=1 / rc=1（[FAIL] 30 件） | `red-ta61-no-helper.log` / `red-ta61-pre-migration.log` |
| pre-fix HEAD（AC-7） | contract TA FAIL（TC-09×12 / TC-19×4 / TC-25(3)） | `mutations/pre-fix-head.log` |
| GREEN: ta-61 standalone ×2 | rc=0 / 74 passed / 0 failed（569s） | `ta61-standalone-run{1,2}.log` |
| GREEN: full suite | rc=0 / 612 passed / 0 failed / 282s（baseline 231s → +51s、timeout 600s 余裕 318s） | `full-suite.log` / `ci-duration.log` |
| 変異（Slice 1 全 18 本） | **18/18 KILL**（M-01 dual-channel / M-14c 3 assert 個別発火 / M-15 両 shell） | `mutations/mutation-summary.log` + 各 `M-*.log` |
| dual-shell（TC-29） | 全体ガード 6 本 dash/bash とも rc=3、ta-49 同値 rc=0 + SKIP 診断 | `dual-shell-skip.log` |
| 静的検査 | `sh -n` 全件クリア（TC-27）/ 層 A 早期脱出イディオム 0 件 / 述語パリティ 14 箇所同一 / `seven` 文言 0 件 | `verification/syntax-exec.log` ほか |
