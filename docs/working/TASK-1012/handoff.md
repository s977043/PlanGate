---
task_id: TASK-1012
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-08-10
author: qa-reviewer
v1_release: ""
---

# TASK-1012 Handoff Package

> WF-05 Verify & Handoff の必須出力（`.claude/rules/hybrid-architecture.md` Rule 5 / `.claude/rules/working-context.md` 必須 6 要素）。
> 本 handoff は **C-4（PR レビュー）の前**に提出する完了資産である。

## メタ情報

```yaml
task: TASK-1012
related_issue: https://github.com/s977043/plangate/issues/1012
author: qa-reviewer
issued_at: 2026-08-10
branch: feat/1012-exec
exec_head: ad4971db18a0bd3a664969b859c5e644693b13fe
base: origin/main = fac3445
mode: high-risk（lite_eligible=false / Human C-3 決定 2026-08-10 / C-2 R-003）
c3: APPROVED（plan_hash 一致。plan / todo / test-cases / pbi-input は exec 中に未編集）
implementation_files: tests/extras/ta-26-plugin-sync.sh（1 ファイルのみ）
```

**Goal**: `tests/extras/ta-26-plugin-sync.sh` の TC-13 が起動する再帰防止モードの子プロセス
（`PG_T26_NO_RECURSE=1`）で、sandbox 実行を伴う重い TC 群をスキップし実行時間を短縮する。
**親プロセスのカバレッジは変えない**（AC-2 で固定）。

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| **AC-1** ゲート対象 TC が子でスキップされ `[SKIP]` 行が出る | **PASS** | `evidence/test-runs/t26-child.log`: 新規 `[SKIP] TC-20〜TC-25`（L18）/ `[SKIP] TC-26〜29/32/34〜36`（L19）の 2 行。ゲート**外**の `[PASS] TC-30`（L20）/ `[PASS] TC-33`（L21）は子でも実行済み。子サマリ `TA-26 standalone: 15 passed, 0 failed` |
| **AC-2** 親プロセスのカバレッジ不変 | **PASS** | `ids-base.txt` と `ids-opt.txt`（PASS TC-ID 集合）の `diff` が **rc=0**、要素数 **32**。サマリも `32 passed, 0 failed` で一致 |
| **AC-3** `ta-26` standalone が 0 failed | **PASS** | `t26-parent-opt.log` 末尾 = `TA-26 standalone: 32 passed, 0 failed` / rc=0（baseline `t26-parent-base.log` と同値） |
| **AC-4** フルスイート `sh tests/run-tests.sh` が 0 failed | **PASS** | `full-suite-clean.log:673` = `Results: 540 passed, 0 failed` / rc=0（clean tree 実測） |
| **AC-5** 実行時間短縮を交互 A/B で実測 | **WARN（便益未達 / Human 受理済み）** | `t05-ab-timing.log`: 交互 A/B 4 往復。BASE 中央値 **49.789s** → OPT 中央値 **42.709s**、`OPT/BASE = 0.8578` = **14.22% 短縮**。判定基準は `test-cases.md:204` の `OPT <= BASE × 0.85`（15% 以上）で、**0.8578 > 0.85 のため未達**。→ §4 妥協点 |
| **AC-6** ゲート内定義 → ゲート外参照のシンボル越境 0 件 | **PASS** | `t04-mutations.log`: 適用後 tree で `containment_violations=0` / `identifiers=77 crossings=0` / rc=0。検証スクリプトは `evidence/verification/tc-a6a.sh` |
| **TC-INV**（不変条件: 既存行を書き換えない） | **PASS** | `git diff -w origin/main...ad4971d -- tests/extras/ta-26-plugin-sync.sh` = **18 insertions / 0 deletions**。実体は 4 hunk（説明コメント + `if` / `printf` / `else` × 2、`fi` × 2）のみで既存行の内容変化 0（`-w` なしの 538 行は `else` ブロック化に伴うインデント変更） |

**総合**: **6 / 7 PASS**（AC-1・AC-2・AC-3・AC-4・AC-6・TC-INV）、**AC-5 のみ WARN**。FAIL は 0。

**WARN の扱い**: AC-5 は **Human が 2026-08-10 に「受け入れて PR 化」と裁定済み**。
AI が自動受理したものではない（`test-cases.md:205` の「取り消し判断ゲート」を人間が通した）。詳細は §4。

### 検出力の実証（変異検証 4 種 / `t04-mutations.log`）

「PASS が空振りでないこと」を旧挙動へ戻す変異で実証済み。

| 変異 | 内容 | 期待 | 実測 | 復元後 |
|------|------|------|------|--------|
| ① | 新規 2 ゲートの条件のみ反転 | AC-2 が FAIL | 親 `18 passed`（baseline 32）→ summary diff rc=1 | `32 passed` に復帰（再 PASS） |
| ② | ゲート B の終端 `fi` を TC-36 の手前へ移動 | AC-1 の TC-A1b が FAIL | TC-A1b=**1**（`[PASS] TC-36` が子で実行された） | TC-A1b=**0**（再 PASS） |
| ③ | 末尾へ `: "$_t26_tgt36"` を注入 | AC-6 が越境 1 件以上 | `CROSS _t26_tgt36 (def L738) <- L824` / `crossings=1` / rc=1 | `crossings=0` / rc=0 |
| ④ | 範囲入力（call site）を広げる。ファイル無改変 | TC-A6a (1b) 排他アサーションが `IN-RANGE` | `572-759` → violations=1 / rc=1、`572-810` → violations=2 / rc=1 | 正しい範囲 `572-748` で violations=0 / crossings=0 / rc=0 |

**変異④の行数値は plan の推定値が使えなかった**。plan は適用**前** tree の値（`558-741` / `558-791`）を
記載していたが、ゲート適用でファイル行がずれるため、適用後 tree で実測し直した値
（TC-30 = L750 / TC-33 = L761 / ゲート B 終端 = L759）へ置き換えて実施している
（`evidence/test-runs/exec-summary.md` §A-4 脚注）。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| **K-1: `PG_T26_NO_RECURSE` が呼び出し元 env の漏れから保護されていない**（[#1036](https://github.com/s977043/plangate/issues/1036) 起票済 / OPEN） | **major** | open（本 PBI の scope 外） | **Yes（最優先）** |
| **K-2: V-2 / V-3 が未実施**（high-risk では必須） | major | open | No（本 PBI 内で消化すべき残工程） |
| **K-3: C-2 のコードベース整合レーンが未実施**（`review-principles.md` §7-bis） | minor | accepted | No |
| **K-4: `status.md` / `decision-log.jsonl` が本ブランチに存在しない** | minor | open | No |
| **K-5: AC-5 の便益未達（14.22% < 15%）** | minor | **accepted**（Human 裁定） | No（§4 妥協点） |

**Critical 課題**: なし（critical = 0）。

### K-1 詳細（最重要 follow-up）

`tests/run-tests.sh:20` の `unset` 行は 7 個の env（`PLANGATE_SKIP_REASON` / `PLANGATE_HOOK_TASK` /
`PLANGATE_HOOK_FILE` / `PLANGATE_BYPASS_HOOK` / `PLANGATE_HOOK_STRICT` / `PG_HARNESS_SOURCED` /
`PLANGATE_ALLOW_MASS_DELETE`）を落とすが、**`PG_T26_NO_RECURSE` はそこに含まれていない**（実測確認済み）。
このため呼び出し元シェルで `export PG_T26_NO_RECURSE=1` されている環境では、
**子プロセスに限らず親実行でもゲートが発火し、TC が黙って消える**。しかも
`TA-26 standalone: 15 passed, 0 failed` / rc=0 で**グリーンに見える**（fail-open）。

**#1012 はこの既存穴を作ったわけではないが、被害を 5.7 倍に拡大した**:
消える TC は従来 3 件（TC-03 / TC-04 / TC-13）だったが、本 PBI で **17 件**（+14）になる。
消えるのは **#877 / #914 / #970 の mass-delete guard 回帰テスト群**であり、
「guard が壊れてもテストが緑」という最悪の失敗形になりうる。

> 起票済み: **#1036**（OPEN, 2026-08-10）
> `fix(tests): PG_T26_NO_RECURSE が呼び出し元 env の漏れから保護されておらず、親実行でも 17 TC が黙って消える（#1012 で影響 5.7 倍）`

### K-2 詳細

Mode = high-risk のため `.claude/rules/mode-classification.md` のフェーズ適用マトリクス上
**V-2（コード最適化）/ V-3（外部モデルレビュー）が必須**であり、`todo.md:86-88` の完了条件にも入っている。
これらは workflow-conductor が制御する工程で Agent タスク A-1〜A-6 の外にあるため、**exec 完了時点で未実施**。
V-2 は TC-INV を壊せないため改変余地が極小であり、「最適化なし」の判定でも
**その判定と根拠を evidence に残す**こと（未実施と、実施して変更なしを区別する）が `todo.md:87` で要求されている。

### K-4 詳細

`docs/working/TASK-1012/` に `status.md` / `current-state.md` / `decision-log.jsonl` が存在しない
（`plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md` / `review-self.md` / `review-external.md` /
`evidence/` のみ）。`working-context.md` は status.md にフェーズ履歴を残すことを求めており、
**AC-5 の Human 裁定（2026-08-10）は現状この handoff にしか記録されていない**。
C-4 前に status.md を補完するのが望ましい。

## 3. V2 候補（今回の scope 外）

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| `PG_T26_NO_RECURSE` の env 漏れ防止（`run-tests.sh` の unset 集合へ追加 + 静的検査） | 本 PBI の in-scope は「ゲートの追加」のみ。env 保護は別 failure mode | **High** | [#1036](https://github.com/s977043/plangate/issues/1036) |
| TC-03/04 の md5sum 4 回実行（約 16s）/ sync 内 refs 1 本ごとの `python3` 起動（約 23 回）の削減 | 実行時間の**最大の伸びしろ**だが #914 diff 外（#771 / #790 由来） | High | — |
| TC-13 の連鎖 FAIL 構造そのものの是正 | 別 PBI で扱う | Medium | #1011（V3-06） |
| 経路2 guard の fail-open | production code に手を入れる必要があり本 PBI では一切触らない方針 | Medium | #1009 |
| guard を弱める変異 2 種が通り抜ける（検出力ギャップ） | 同上 | Medium | #1010 |
| `test_run_evidence.py::test_tc45` が dirty tree で誤 FAIL | テスト基盤側の別課題 | Low | #997 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| **AC-5 未達（14.22% < 15%）のまま PR 化する** | (a) 実装を revert して見送る / (b) さらに重い TC もゲートに入れて 15% を超える | **Human が 2026-08-10 に「受け入れて PR 化」と裁定**。(b) は子のカバレッジ縮小をさらに広げ、K-1 と合わさって危険度が上がる。取り消しは `git revert` 1 手で可能なため受理のリスクは可逆 |
| ゲートを **2 組**に分割し、ヘルパー定義（`_T26_AI_LOOP_REFS_REL` / `_t26_mk_ai_loop_guard_sandbox` / `_t26_mk_refs_guard_sandbox`）と静的検査 TC-30 / TC-33 をゲート外に残す | TC-20〜36 を 1 つの `if` で丸ごと囲む | 1 組にするとヘルパー定義がゲート内に落ち、ゲート外の TC-30 / TC-33 から参照されて**シンボル越境**が発生する。`set -e` が無いため越境は `command not found` のまま継続 FAIL し、TC-13 の `0 failed` 判定を壊す（AC-6） |
| `if` / `printf [SKIP]` / `else` / `fi` 形式（既存 L62-68 と同型） | 早期 `return` / 関数抽出 | 既存パターン踏襲。TC-INV（`git diff -w` が追加行のみ）を満たすため既存行を書き換えない |
| `scripts/sync-plugin-plangate.sh`（production code）に一切触れない | 本体側で高速化する | TASK-0914 `handoff.md:129` の既存規約。本 PBI は test harness のみ。**素実行も禁止**（検証は sandbox 経由） |

### AC-5 未達の詳細（**最重要の申し送り**）

- **plan の参考値「約 40% 短縮」は TC-35/36 追加前の tree での測定**であり、現 tree では再現しない。
  現 tree では子で省略される TC が全体に占める割合が当時より小さい
  （`test-cases.md:220` に「当時の tree には TC-35/36 が無いため直接比較できない」と明記済み）。
- **恒久コストは確定する**: TC-13 の子プロセスで **14 TC**（TC-20〜25 の 6 件 + TC-26〜29 / 32 / 34〜36 の 8 件）
  が実行されなくなる。これは**テスト意味論の変更**である。
  ただし TC-13 の判定目的は「子が `TA-26 standalone: … 0 failed` を出す」＝ standalone fallback の証明に限られ、
  これらの TC は必ず親プロセス側で実行されるため**親のカバレッジは不変**（AC-2 で実証済み）。
- **C-2 の R-004（major）が予告していた事態が現実化した**:
  > 「**AC-5 に拘束力が無い**。FAIL 条件が「OPT 中央値 > BASE 中央値」だけで、短縮率 0〜15% は WARN で
  > 受理して完了できる。**恒久コスト（子のカバレッジ縮小＝テスト意味論の変更）は確定する一方、
  > 便益未達でも完了する非対称**。取り消し判断ゲートが plan / todo のどこにも無い」
  （`review-external.md:29`、反映コミット `16cd2a4`）

  R-004 の反映で `test-cases.md:210-220` に「WARN 継続時の取り消し判断ゲート」が追加され、
  **AI が自動受理せず人間へ上げる**構造になっていた。今回そのゲートが実際に作動し、
  Human が「受け入れて PR 化」を選択した。**指摘 → 反映 → 実際の作動**まで一巡している。
- **取り消し手順**: `git revert` 1 手。

## 5. 引き継ぎ文書

### 概要

`tests/extras/ta-26-plugin-sync.sh` に **`PG_T26_NO_RECURSE=1` のときだけ発火するスキップゲートを 2 組追加**した
（既存 L62-68 の TC-03/04 ゲートと同型）。TC-13 が起動する再帰防止モードの子プロセスで、
sandbox repo を都度構築して sync を実走させる重い TC 群（TC-20〜25 / TC-26〜29 / 32 / 34〜36 = 計 14 件）を省略する。
実装差分は **1 ファイル・`git diff -w` で 18 行追加 0 行削除**。

現状は **AC 6 件中 5 件 + 不変条件 TC-INV が PASS、AC-5 のみ WARN**。
AC-5 は「15% 以上の短縮」を求めていたが実測 **14.22%** で未達。
**Human が 2026-08-10 に受け入れを裁定済み**のため PR 化可能な状態にある。

**PR 化の前に片付けるべき残件は K-2（V-2 / V-3 未実施）**。Mode = high-risk では必須工程であり、
`todo.md` の完了条件にも入っている。
**マージ後に最優先で着手すべきは K-1（#1036）**。本 PBI が既存の fail-open の被害を 3 TC → 17 TC に拡大したため。

### 触れないでほしいファイル

- `docs/working/TASK-1012/plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md`:
  **C-3 承認済み**。編集すると `plan_hash` が壊れ EH-3 が mismatch を検知する。
  C-2 / V-3 の追加指摘は `review-external.md` へ **`R-NNN` 採番して追記専用**で集約する（既存 R-001〜R-014 は書き換えない）。
- `tests/extras/ta-26-plugin-sync.sh` の **standalone preamble・harness 判別式**: TC-33 が静的走査するため触ると落ちる。
- `scripts/sync-plugin-plangate.sh`: production code。本 PBI では一切触らない方針。素実行も禁止。
- `docs/working/TASK-1012/evidence/`: 実測ログ。再実行して上書きすると裏取りの連続性が切れる。

### 次に手を入れるなら

1. **V-2 / V-3 を実施する**（K-2）。V-2 は TC-INV を壊せないため改変余地が極小 →
   「最適化なし」判定でも**根拠を evidence に残す**（未実施と区別するため）。
   変更した場合は AC-1〜AC-4 を再実行して回帰なしを確認する。
2. **#1036 に着手する**（K-1）。`run-tests.sh` の unset 集合へ `PG_T26_NO_RECURSE` を追加し、
   「unset 集合が extras の判別 env を包含する」静的検査（TC-33 と同型）を足すのが筋。
3. **ゲート境界の直後に TC を追加するときは AC-6（`evidence/verification/tc-a6a.sh`）を再実行する**。
   ゲート内で定義したシンボルをゲート外から参照すると、`set -e` が無いため
   `command not found` のまま継続 FAIL し TC-13 の `0 failed` 判定を壊す。
4. **行番号ベースの範囲入力は毎回実測し直す**（変異④の教訓）。ゲート適用でファイル行がずれるため、
   plan 記載の推定値をそのまま使うと空振りする。

#### 避けるべきアンチパターン

- **ゲートを 1 組に統合する**: ヘルパー定義がゲート内に落ちて AC-6 が壊れる。
- **「速くならないからもっと TC をゲートに入れる」**: 子のカバレッジ縮小が広がり、K-1 と合わさって
  「guard が壊れてもテストが緑」の窓が拡大する。
- **`TA-26 standalone: N passed` の `N` を契約値として固定する**: AC-3 は「0 failed」を要求し、
  総数は基点実測に従うと明記されている（`pbi-input.md` AC-3）。

### 参照リンク

- 親 issue: <https://github.com/s977043/plangate/issues/1012>
- follow-up issue: <https://github.com/s977043/plangate/issues/1036>
- plan: `docs/working/TASK-1012/plan.md`（改訂 11）
- C-1: `docs/working/TASK-1012/review-self.md`（9 ラウンド / 計 55 件反映）
- C-2 + 独立 river-review: `docs/working/TASK-1012/review-external.md`（R-001〜R-014）
- exec 実測サマリ: `docs/working/TASK-1012/evidence/test-runs/exec-summary.md`
- status.md: **未作成**（K-4）

## 6. テスト結果サマリ

| レイヤー | 対象 | 件数 | PASS | FAIL | SKIP |
|---------|------|------|------|------|------|
| フルスイート（clean tree） | `sh tests/run-tests.sh` | 540 | **540** | **0** | — |
| 統合（親 / 適用後） | `sh tests/extras/ta-26-plugin-sync.sh` | 32 | **32** | **0** | — |
| 統合（親 / baseline） | 同上（適用前） | 32 | **32** | **0** | — |
| 統合（子 / 再帰防止） | `PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh` | 15 | **15** | **0** | **17**（うち本 PBI 由来 14） |
| 静的（シンボル越境） | `evidence/verification/tc-a6a.sh` | — | `containment_violations=0` / `identifiers=77 crossings=0` | rc=0 | — |
| 変異検証 | 変異 ①〜④ | 4 | 4（全件 kill・復元後に再 PASS） | 0 | — |

全実行の rc = 0（変異注入時の意図的 rc=1 を除く）。

### SKIP の内訳（子プロセスのみ）

| SKIP 行 | 件数 | 由来 |
|---------|------|------|
| `[SKIP] TC-03/TC-04` | 2 | **既存**（本 PBI 以前から） |
| `[SKIP] TC-13 再帰防止` | 1 | **既存** |
| `[SKIP] TC-20〜TC-25` | 6 | **本 PBI で追加** |
| `[SKIP] TC-26〜29/32/34〜36` | 8 | **本 PBI で追加** |
| 合計 | **17** | 32 − 15 = 17 と一致 |

### フルスイート件数 539 → 540 の内訳（**本 PBI 由来ではない**）

`full-suite.log`（dirty tree 実行, 539）と `full-suite-clean.log`（clean tree 実行, 540）の
**`diff` は 1 テストケース分のみ**（4 行の `[WARN]` ブロック → 1 行の `[PASS]` + `Results:` 行）。
**TA-26 セクションは両ログで完全一致**（実測で確認済み）。

原因は `tests/extras/ta-57-pr-convergence.sh` の **TC-14 / AC-7（base ref 依存の差分検査）**:

| 実行条件 | 出力 |
|---------|------|
| dirty 実行時 | `[WARN] TC-14 / AC-7 差分検査は **未実行**: HEAD と異なる base ref (origin/main / main) が無い checkout` |
| clean 実行時 | `[PASS] TC-14 / AC-7: delivery.py / c3_contract.py / c3prime_verify.py が origin/main から 0 行差分` |

つまり **checkout の状態依存で TC-14 が実行されたかどうか**の差であり、本 PBI の変更とは無関係。
AC-4 の判定根拠には **clean tree 実測の `540 passed, 0 failed`** を採る。

> 補足: `evidence/test-runs/exec-summary.md` §A-3 の AC-4 行は先行実行の `full-suite.log`（539）を引いており、
> 後から追加された `full-suite-clean.log`（540）を反映していない。数値の矛盾ではなく**実行条件の違い**である。

## 7. Metrics summary

該当なし（`bin/plangate metrics` は未取得）。

---

## WF-05 完了条件チェック

| 項目 | 状態 |
|------|------|
| handoff 必須 6 要素 | 済 §1〜§6 |
| V-1 受け入れ検査 | 済（AC-1〜AC-6 + TC-INV / 変異 4 種で検出力実証） |
| L-0 リンター | 済（`full-suite-clean.log` 追加で指摘解消） |
| **V-2 コード最適化** | **未実施**（high-risk 必須 / K-2） |
| **V-3 外部モデルレビュー** | **未実施**（high-risk 必須 / K-2） |
| V-4 リリース前チェック | 該当なし（critical のみ） |
| C-4 PR レビュー | 未（Human-owned） |
| merge | 未（**Human-owned 固定**。AI は実施しない） |
