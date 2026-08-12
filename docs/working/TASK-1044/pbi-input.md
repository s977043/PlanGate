# PBI INPUT PACKAGE — TASK-1044

> Issue: [#1044](https://github.com/s977043/plangate/issues/1044)（P2 / bug）
> 親系譜: TASK-0921 Slice 1（#921）handoff 既知課題 2（HR-4 残存）/ 2-bis（F-3）
> 同クラス: #1026（シェル間セマンティクス逆転で静かに通る）

## Context / Why

TASK-0921 Slice 1 で導入した tests/extras の bootstrap（層 A 12 本 + ta-61 に複製）は、
harness 判定を 3 env（`PG_HARNESS_SOURCED=1` / `FIXTURES_DIR` 非空 / `EXTRAS_DIR` 非空）の
AND のみで行う。このため **3 env がすべて漏出した環境で直接実行**すると harness mode と
誤判定し、失敗が rc に伝播しない。

**現 main（`48f6971`）での再実測（2026-08-12 / 本 plan 作成時）**:

実測 1 — helper `_extra-contract.sh` 欠落 + 3 env 漏出 + 直接実行（issue #1044 記載の症状）:

| shell | rc |
|---|---|
| dash | **0（silent pass。`[FAIL] helper unresolved` は stderr に出るが rc=0）** |
| zsh | **0** |
| bash | 1 |
| sh | 1 |

実測 2 — **helper が存在しても** 3 env 漏出 + 直接実行では harness 誤判定により
standalone rc 契約が丸ごと無効化される（本 plan 作成時に新規確認・issue 未記載）:

| shell | rc |
|---|---|
| dash / zsh / bash / sh | **すべて 0**（SKIP 経路が rc=3 でなく rc=0。カウンタ未初期化・summary 未出力・7 env unset 不発） |

つまり根本原因は「helper 欠落分岐の脱出」ではなく **harness 判定述語が『実際に source
されているか』を見ていない**ことにあり、修正は mode 判定そのものに直接実行検知を
加える必要がある。

## What (Scope)

### In scope

1. **bootstrap の harness 判定に直接実行ガードを追加**する（`$0` basename ベース）。
   対象 = 層 A 12 本 + `ta-61-extra-contract.sh` 本体 bootstrap + ta-61 内 heredoc fixture
   （ta-99-probe-c 複製）+ helper `_pg_extra_resolve_mode`（bootstrap と helper の述語は
   常に同一 — TASK-0921 plan L676-678 の mode 分裂禁止を継承）
2. **変更後スニペットの正本を本 PBI の plan.md「### Mode resolution v2」へ移す**
   （TASK-0921 plan は承認済み歴史文書として不変。DoD の機械照合先を新正本へ切替）
3. **F-3（`_extra-contract.sh` L34/L117 の standalone 既定値非対称）の是正**:
   handoff 2-bis が「#1044 と同族の follow-up 対象」と明示し、0921 で見送った理由
   （変異 evidence の HEAD 整合失効）は新 PBI では該当しないため **In scope**。
   finalize が init 前に呼ばれた契約違反を fail-closed（exit 4 + stderr 診断）で顕在化させる
4. **回帰テスト追加**（ta-61 に TC 追加）: env 漏出 + 直接実行の 2 シナリオ
   （helper 欠落 → rc=1 / helper 存在 → standalone 契約維持）を dash で検証
5. **変異注入による検出力実証**: 修正前 HEAD で新 TC が FAIL すること、および
   ガードの call site を壊した変異で新 TC が FAIL（kill）することを evidence 化

### Out of scope

- 層 B / 層 C の contract 移行（TASK-0921 Slice 2 の範囲）
- ta-31 の分岐内 `return 0 2>/dev/null || true` 4 箇所（層 B / Slice 2）
- 層 C 空振り PASS の機械検出（HJ-2 裁定で Slice 2 D-2 (c) に委譲済み）
- `tests/run-tests.sh` 本体の変更（bootstrap / helper 側のみで完結させる）
- zsh を harness runner として公式サポートすること（runner は sh 前提を維持）

## 受入基準

| AC | 内容 |
|---|---|
| AC-1 | 3 env 漏出 + helper 欠落 + 直接実行が **dash / zsh / bash / sh の 4 シェルすべてで rc=1**（実測 1 の是正） |
| AC-2 | 3 env 漏出 + helper 存在 + 直接実行が **standalone として動作**する（7 env unset・カウンタ初期化・summary 出力・rc 0/1/3 契約が有効。実測 2 の是正） |
| AC-3 | 正規経路の無回帰: `sh tests/run-tests.sh` フルスイートが rc=0 / fail=0、かつ層 A 12 本の standalone 直接実行（清浄 env）が従来どおりの rc を返す |
| AC-4 | 述語の同一性: direct-exec ガードを含む新述語が **15 出現**（層 A 12 + ta-61 本体 + ta-61 fixture 複製 + helper）で本 PBI plan「### Mode resolution v2」と文字単位同一（機械照合） |
| AC-5 | **変異注入**: (a) 修正前 HEAD で新 TC を走らせ FAIL を実証（pre-fix evidence）。(b) 修正後、ガードの call site を壊す変異（直接実行検知行の除去）を dash で走らせ、新 TC が FAIL（kill）することを実証 |
| AC-6 | F-3 是正: `pg_extra_contract_finalize` が `_PG_EXTRA_STANDALONE` 未設定（init 前呼出）のとき silent に harness 扱いへ落ちず、fail-closed（stderr 診断 + exit 4）となる。既存 TC-10（静的検出）は不変で PASS |
| AC-7 | ta-61 既存 TC（TC-01〜TC-29）が全 PASS（ガード追加による fixture 回帰なし） |

## Notes from Refinement

- 修正案の `$0` アンカーは issue 記載のファイル名 literal 埋め込み（`*ta-46-ehs-wiring.sh)`）
  ではなく **`${0##*/}` の `ta-*.sh` glob 照合**とする。literal 埋め込みは 15 出現の
  バイト一致 DoD（TASK-0921 が確立した機械照合可能性）を壊すため
- TASK-0921 plan「#### bootstrap の helper 解決規約」の「`$0` をアンカーにしてはならない」は
  **helper のディレクトリ解決**に対する禁止（harness では `$0`=run-tests.sh のため）。
  本 PBI の `$0` 利用は**直接実行の検知**であり、`$0`=run-tests.sh が `ta-*.sh` に一致しない
  ことをそのまま利用する = 矛盾しない（plan の Approach で明記）
- runner が zsh で起動された場合 zsh の FUNCTION_ARGZERO により source 先で `$0` が
  変わりうるが、runner は `sh tests/run-tests.sh` 前提（CI 実体 dash / README 規約）であり
  制約として明記する

## Estimation Evidence

- **Risks**: ta-61 の sandbox 系 TC（TC-14〜17 / TC-29）が bootstrap 複製をコピーして
  実行するため、述語変更が fixture 期待値を壊す可能性 → exec 冒頭で ta-61 全走を baseline 化
- **Unknowns**: macOS `/bin/sh`（bash 3.2）と CI `sh`（dash）の挙動差は実測 1 で確認済み。
  他に露出するシェル依存は変異注入と 4 シェルマトリクスで検出する
- **Assumptions**: tests/extras の実行ファイルは `ta-*.sh` 命名規約に従う（README 規約。
  `_extra-contract.sh` は glob 非一致 — TASK-0921 plan R-014 反証材料で実測済み）
