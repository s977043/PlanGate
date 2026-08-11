# TASK-1012 作業ステータス

> 最終更新: 2026-08-10 13:03
> 現在フェーズ: verify（WF-05 handoff 発行済 / V-2・V-3 未実施）
> モード: **high-risk**（`lite_eligible=false`）
>
> **本ファイルの成立経緯**: exec / handoff の時点では未作成だった（handoff.md §2 の
> **K-4** として既知課題に記録済み）。独立レビューの指摘を受け、`handoff.md` と
> `evidence/` の実測値のみを根拠に**事後補完**したものである。
> 記載値の裏取り元は各行に明記する。**推測時刻は書かない**。

## フェーズ履歴

> **日時は `YYYY-MM-DD HH:mm`（分まで）必須**（#463 / `.claude/rules/working-context.md`）。
> 出典を明記できないものは「時刻不詳」と書き、推測値では埋めない。

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ | 時刻の出典 |
|------------------------|---------|------------|-----------|
| 2026-08-10 10:09 | **Plan Package マージ** | PR **#1030** = commit `70d56b6`。plan / todo / test-cases / pbi-input / review-self / review-external が main へ入る。**マージは実装承認ではない**（C-3 は別ゲート） | `git log` の commit date（`70d56b6`） |
| 2026-08-10 **03:09** | **C-3 Gate: APPROVED** | `c3_status: APPROVED` / `plan_hash: sha256:b802fd0f…` / `approved_by: s977043@users.noreply.github.com` | **オーガナイザー実測値**（本 worktree では実体未確認 — 下記「C-3 Gate」節を参照） |
| 2026-08-10 12:07 | base 確定 | `origin/main` = `fac3445`（本 PBI の分岐基点） | `git log` の commit date（`fac3445`） |
| 2026-08-10 12:36 | **D: exec 完了** | `8c245f8` `test(ta-26): 再帰防止の子プロセスで sandbox 実行 TC 群をスキップする`。実装は **`tests/extras/ta-26-plugin-sync.sh` 1 ファイルのみ**（`git diff -w` で 18 insertions / 0 deletions） | `git log` の commit date（`8c245f8`） |
| 2026-08-10 12:40 | L-0 / evidence 追補 | `ad4971d` clean tree でのフルスイート実測（`full-suite-clean.log`）を追加し L-0 指摘を解消。evidence は計 **20 ファイル** | `git log` の commit date（`ad4971d`） |
| 2026-08-10（**時刻不詳**） | **AC-5 未達を Human が受け入れ裁定** | 短縮 **14.22%**（基準 15% = `OPT ≤ BASE × 0.85`）で未達。Human が「受け入れて PR 化」と裁定。**AI の自動受理ではない** | 日付は `handoff.md:49,110,128` の記載。**時刻は evidence から取得できないため不詳**（推測しない） |
| 2026-08-10 13:03 | **WF-05 handoff 発行** | `25a4039` `docs(handoff): WF-05 handoff を発行（AC 6/7 PASS・AC-5 は Human 裁定で受理）` | `git log` の commit date（`25a4039`） |
| 2026-08-10（**時刻不詳**） | 本 status.md を事後補完 | K-4（status / current-state / decision-log 欠落）の是正 | — |

> **注（`approved_at: 03:09` と他行の時刻の整合について）**: 本表の他行は `git log`
> のローカルタイムゾーン表示であり、`c3.json` の `approved_at` はオーガナイザーから
> 提供された生値である。**両者のタイムゾーンが同一かを本 worktree では検証していない**
> ため、時系列の前後関係を本表の見た目だけで断定しないこと（UTC 表記であれば
> Plan Package マージ 10:09 と exec 12:36 の間に収まる）。

## C-3 Gate: APPROVED

```yaml
c3_status: APPROVED
approved_at: 2026-08-10 03:09
plan_hash: sha256:b802fd0f…   # 先頭のみ（オーガナイザー提供）
approved_by: s977043@users.noreply.github.com
```

- **本 worktree からは `docs/working/TASK-1012/approvals/c3.json` の実体を確認できない**。
  `ls docs/working/TASK-1012/approvals` は `No such file or directory`（rc=1）であり、
  当該ファイルは untracked のためブランチ `feat/1012-exec`（head `25a4039`）に含まれていない。
  上記 4 値は**オーガナイザーの実測値をそのまま引用**したものであり、本ワーカーによる
  一次確認は行っていない。
- 間接的な裏取り: `handoff.md:27` が `c3: APPROVED（plan_hash 一致。plan / todo /
  test-cases / pbi-input は exec 中に未編集）` と記録している。
- Mode = **high-risk** のため `.claude/rules/working-context.md` の
  「C-3 Autonomous APPROVE 判定マトリクス」により **autonomous APPROVE は不可**で、
  **人間 C-3 が必須**。本 PBI はその要件を満たしている（Human 承認）。
- 承認後の `plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md` の編集は
  `plan_hash` を破壊するため**禁止**。本 status.md の追加はこれらに触れていない。

## モード判定結果

| 項目 | 値 |
|------|---|
| モード | **high-risk** |
| `lite_eligible` | **false**（Human C-3 決定 2026-08-10 / C-2 の R-003 経由） |
| C-3 | **同期・人間必須**（autonomous APPROVE 不可） |
| 必須 V 系 | **V-2 / V-3 が必須**（`.claude/rules/mode-classification.md` フェーズ適用マトリクス）→ **いずれも未実施**（残タスク） |

出典: `handoff.md:26`（`mode: high-risk（lite_eligible=false / Human C-3 決定 2026-08-10 / C-2 R-003）`）。

## 全体構成（PR 一覧）

| PR | ブランチ | 状態 |
|----|---------|------|
| #1030 | Plan Package（plan / todo / test-cases 等） | **MERGED**（`70d56b6`）。※ **実装承認ではない** |
| （未作成） | `feat/1012-exec` | **OPEN 前**（実装 + evidence + handoff が積まれた状態。C-4 未実施） |

### `feat/1012-exec` のコミット

| SHA | 日時 | 内容 |
|-----|------|------|
| `8c245f8` | 2026-08-10 12:36 | 実装（`tests/extras/ta-26-plugin-sync.sh`） |
| `ad4971d` | 2026-08-10 12:40 | evidence 追補（clean tree フルスイート） |
| `25a4039` | 2026-08-10 13:03 | handoff 発行 |

base: `origin/main` = `fac3445`。

## 残タスク

- [ ] **V-2（コード最適化）** — high-risk では必須（`mode-classification.md`）。`todo.md:87` は
      「最適化なし」判定でも**根拠を evidence に残す**ことを要求（未実施と「実施して変更なし」を区別する）。
      TC-INV（既存行を書き換えない）を壊せないため改変余地は極小。
      **owner**: workflow-conductor（Agent タスク A-1〜A-6 の外の工程）
- [ ] **V-3（外部モデルレビュー）** — high-risk では必須。指摘は `review-external.md` へ
      `R-NNN` 採番で**追記専用**に集約する（既存 R-001〜R-014 は書き換えない）。
      **owner**: workflow-conductor
- [ ] **#1036 の対応**（K-1 / **major**）— `PG_T26_NO_RECURSE` が呼び出し元 env の漏れから
      保護されていない。`tests/run-tests.sh:20` の `unset` 集合に当該 env が**含まれていない**ため、
      呼び出し元で export されていると**親実行でもゲートが発火し TC が黙って消える**（fail-open。
      `TA-26 standalone: 15 passed, 0 failed` / rc=0 で緑に見える）。
      **本 PBI はこの穴を作ってはいないが、被害を 3 TC（TC-03/04/13）→ 17 TC に拡大した**。
      消えるのは #877 / #914 / #970 の mass-delete guard 回帰テスト群。
      **owner**: 別 PBI（マージ後に最優先）/ **unblock_condition**: #1036 の着手
- [ ] **C-4（PR レビュー / Human-owned）** — PR 未作成。merge は **Human-owned 固定**（AI は実施しない）
- [ ] `decision-log.jsonl` の要否判断（K-4 の残り。本補完では status.md / current-state.md のみ作成）

## 計画からの変更点

1. **変異④の行数値が plan の推定値どおりに使えなかった**
   plan は**適用前** tree の値（`558-741` / `558-791`）を記載していたが、ゲート適用でファイル行が
   ずれるため、**適用後 tree で実測し直した値**（TC-30 = L750 / TC-33 = L761 / ゲート B 終端 = L759）
   から `572-759` / `572-810` へ置き換えて実施した。
   plan 側にもその旨の注記があり、`evidence/test-runs/exec-summary.md` §A-4 脚注に実測経緯を記録済み。
   → 教訓: **行番号ベースの範囲入力は毎回実測し直す**（plan の推定値をそのまま使うと空振りする）。

2. **AC-5 が未達。plan の参考値「≈40% 短縮」は現 tree では再現しない**
   当該参考値は **TC-35/36 追加前の tree** での測定であり、現 tree では子で省略される TC が
   全体に占める割合が当時より小さい（`test-cases.md:220` に「当時の tree には TC-35/36 が無いため
   直接比較できない」と明記済み）。実測は **14.22%**。

3. **ゲートを 2 組に分割**（1 つの `if` で TC-20〜36 を丸ごと囲まない）
   1 組にするとヘルパー定義（`_T26_AI_LOOP_REFS_REL` / `_t26_mk_ai_loop_guard_sandbox` /
   `_t26_mk_refs_guard_sandbox`）がゲート内に落ち、ゲート外の TC-30 / TC-33 から参照されて
   **シンボル越境**が発生する（AC-6 違反）。`set -e` が無いため越境は `command not found` のまま
   継続 FAIL し、TC-13 の `0 failed` 判定を壊す。

## 実測サマリ

### 受入基準の判定（AC-1〜AC-6 + TC-INV）

| 受入基準 | 判定 | 根拠（実測） |
|---------|------|------------|
| **AC-1** ゲート対象 TC が子でスキップされ `[SKIP]` 行が出る | **PASS** | `t26-child.log`: 新規 `[SKIP] TC-20〜TC-25`（L18）/ `[SKIP] TC-26〜29/32/34〜36`（L19）の 2 行。ゲート**外**の `[PASS] TC-30`（L20）/ `[PASS] TC-33`（L21）は子でも実行済み |
| **AC-2** 親プロセスのカバレッジ不変 | **PASS** | `ids-base.txt` と `ids-opt.txt` の `diff` が **rc=0**、要素数 **各 32 行**（本ワーカーが `wc -l` で実測） |
| **AC-3** `ta-26` standalone が 0 failed | **PASS** | `t26-parent-opt.log` = `TA-26 standalone: 32 passed, 0 failed` / rc=0（本ワーカーが grep で実測） |
| **AC-4** フルスイート `sh tests/run-tests.sh` が 0 failed | **PASS** | `full-suite-clean.log` = `Results: 540 passed, 0 failed` / rc=0（**clean tree** 実測。本ワーカーが grep で実測） |
| **AC-5** 実行時間短縮を交互 A/B で実測 | **WARN（便益未達 / Human 受理済み）** | BASE 中央値 **49.789s** → OPT 中央値 **42.709s** / `OPT/BASE = 0.8578` = **14.22% 短縮**。基準は `OPT ≤ BASE × 0.85`（15% 以上）で **0.8578 > 0.85 のため未達** |
| **AC-6** シンボル越境 0 件 | **PASS** | `t04-mutations.log`: 適用後 tree で `containment_violations=0` / `identifiers=77 crossings=0` / rc=0。検証スクリプト `evidence/verification/tc-a6a.sh` |
| **TC-INV**（既存行を書き換えない） | **PASS** | `git diff -w origin/main...ad4971d -- tests/extras/ta-26-plugin-sync.sh` = **18 insertions / 0 deletions** |

**総合: 6 / 7 PASS、AC-5 のみ WARN、FAIL は 0。**

### AC-5 の交互 A/B 実測（`t05-ab-timing.log`）

| 回 | BASE (s) | OPT (s) |
|----|---------|--------|
| 1 | 53.669 | 47.433 |
| 2 | 50.162 | 43.306 |
| 3 | 48.994 | 41.251 |
| 4 | 49.416 | 42.112 |
| **中央値** | **49.789** | **42.709** |

`OPT / BASE = 0.8578` → **14.22% 短縮**（基準 15% に未達 / 最大 4 往復まで実施済み）。
BASE 健全性アサーション（`grep -c 'TC-20〜TC-25' /tmp/ta26.base`）= 0 件で実装未 commit を確認済み。

**AC-5 の扱い**: `test-cases.md:205` の「取り消し判断ゲート」（C-2 の R-004 指摘を反映して追加された）
が実際に作動し、**Human が 2026-08-10 に「受け入れて PR 化」を裁定**した。
AI が自動受理したものではない。取り消しは `git revert` 1 手で可能。

### 検出力の実証（変異検証 4 種 / `t04-mutations.log`）

| 変異 | 内容 | 期待 | 実測 | 復元後 |
|------|------|------|------|--------|
| ① | 新規 2 ゲートの条件のみ反転 | AC-2 が FAIL | 親 `18 passed`（baseline 32）→ summary diff rc=1 | `32 passed` に復帰（再 PASS） |
| ② | ゲート B の終端 `fi` を TC-36 の手前へ移動 | AC-1 の TC-A1b が FAIL | TC-A1b=**1**（`[PASS] TC-36` が子で実行された） | TC-A1b=**0**（再 PASS） |
| ③ | 末尾へ `: "$_t26_tgt36"` を注入 | AC-6 が越境 ≥1 | `CROSS _t26_tgt36 (def L738) <- L824` / `crossings=1` / rc=1 | `crossings=0` / rc=0 |
| ④ | 範囲入力（call site）を広げる。ファイル無改変 | 排他アサーションが `IN-RANGE` | `572-759` → violations=1 / rc=1、`572-810` → violations=2 / rc=1 | 正しい範囲 `572-748` で violations=0 / rc=0 |

4 件すべて kill・復元後に再 PASS。

### テスト結果サマリ

| レイヤー | 対象 | 件数 | PASS | FAIL | SKIP |
|---------|------|------|------|------|------|
| フルスイート（**clean tree**） | `sh tests/run-tests.sh` | 540 | **540** | **0** | — |
| 統合（親 / 適用後） | `sh tests/extras/ta-26-plugin-sync.sh` | 32 | **32** | **0** | — |
| 統合（親 / baseline） | 同上（適用前） | 32 | **32** | **0** | — |
| 統合（子 / 再帰防止） | `PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh` | 15 | **15** | **0** | **17**（うち本 PBI 由来 14） |

SKIP 17 件の内訳: `[SKIP] TC-03/TC-04` 2 件（既存）/ `[SKIP] TC-13 再帰防止` 1 件（既存）/
`[SKIP] TC-20〜TC-25` 6 件（本 PBI）/ `[SKIP] TC-26〜29/32/34〜36` 8 件（本 PBI）。32 − 15 = 17 と一致。

### フルスイート 539 → 540 の内訳（**本 PBI 由来ではない**）

`full-suite.log`（**dirty tree** 実行 = `Results: 539 passed, 0 failed`）と
`full-suite-clean.log`（**clean tree** 実行 = `Results: 540 passed, 0 failed`）の差は
**1 テストケース分のみ**。原因は `tests/extras/ta-57-pr-convergence.sh` の **TC-14 / AC-7**
（base ref 依存の差分検査）:

| 実行条件 | 該当行（両ログとも L591） |
|---------|------------------------|
| dirty 実行時 | `[WARN] TC-14 / AC-7 差分検査は **未実行**: HEAD と異なる base ref (origin/main / main) が無い checkout` |
| clean 実行時 | `[PASS] TC-14 / AC-7: delivery.py / c3_contract.py / c3prime_verify.py が origin/main から 0 行差分` |

本ワーカーが両ログの L591 を実測して上記を確認した。
**TA-26 セクションは両ログで完全一致**＝本 PBI 由来ではない。
**AC-4 の判定根拠には clean tree 実測の `540 passed, 0 failed` を採る。**

### 既知の食い違い（レビュアー検出済み・そのまま記録）

`evidence/test-runs/exec-summary.md` **§A-3 の AC-4 行は `full-suite.log` の `539 passed` を引いており**、
後から追加された `full-suite-clean.log`（540）を反映していない。
これは**数値の矛盾ではなく実行条件（dirty / clean）の違い**である。
evidence は実測ログであり再実行して上書きすると裏取りの連続性が切れるため、
`exec-summary.md` は**修正せず**、差異の理由を本 status.md と `handoff.md:249-250` に記録する方針を採る。

## V 系ステップ進捗

| ステップ | 結果 |
|---------|------|
| L-0 | **済**（`ad4971d` で `full-suite-clean.log` を追加し指摘解消） |
| V-1 | **済**（AC-1〜AC-6 + TC-INV / 変異 4 種で検出力実証。6/7 PASS・AC-5 のみ WARN・FAIL 0） |
| V-2 | **未実施**（high-risk では必須 / K-2） |
| V-3 | **未実施**（high-risk では必須 / K-2） |
| V-4 | 該当なし（critical のみ） |

## 既知課題（handoff.md §2 より）

| 課題 | Severity | 状態 |
|------|---------|------|
| K-1 `PG_T26_NO_RECURSE` の env 漏れ未保護（[#1036](https://github.com/s977043/plangate/issues/1036) 起票済 / OPEN） | **major** | open（本 PBI scope 外・**最優先 follow-up**） |
| K-2 V-2 / V-3 未実施 | major | open（本 PBI 内で消化すべき残工程） |
| K-3 C-2 のコードベース整合レーン未実施 | minor | accepted |
| K-4 `status.md` / `decision-log.jsonl` 不在 | minor | **本ファイルで status.md / current-state.md を補完**（`decision-log.jsonl` は未対応） |
| K-5 AC-5 の便益未達（14.22% < 15%） | minor | **accepted**（Human 裁定 2026-08-10） |

critical = 0。

## 次の作業（Claude Code プロンプト）

```text
TASK-1012（issue #1012）の残工程を進めてください。

現在地: ブランチ feat/1012-exec に実装（tests/extras/ta-26-plugin-sync.sh 1 ファイル）+
evidence 20 件 + handoff.md + status.md が積まれた状態。C-3 は APPROVED 済み、
V-1 は 6/7 PASS（AC-5 のみ WARN・Human 裁定で受理済み）。PR は未作成。

先に docs/working/TASK-1012/status.md と handoff.md を読んでください。

やること（順に）:
1. V-2（コード最適化）を実施する。Mode=high-risk のため必須。TC-INV（既存行を
   書き換えない）を壊せないため改変余地は極小 → 「最適化なし」判定でも根拠を
   evidence/ に残すこと（未実施と「実施して変更なし」を区別する。todo.md:87）。
   変更した場合は AC-1〜AC-4 を再実行して回帰なしを確認する。
2. V-3（外部モデルレビュー）を実施する。指摘は review-external.md へ R-NNN 採番で
   追記専用に集約する（既存 R-001〜R-014 は書き換えない）。
3. PR を作成し C-4（Human-owned）へ回す。merge は Human-owned 固定で AI は実施しない。

絶対に触らないもの:
- plan.md / todo.md / test-cases.md / pbi-input.md（C-3 承認済み。編集すると
  plan_hash が壊れ EH-3 が mismatch を検知する）
- evidence/ の既存ログ（再実行して上書きすると裏取りの連続性が切れる）
- scripts/sync-plugin-plangate.sh（production code。素実行も禁止）
- ta-26-plugin-sync.sh の standalone preamble / harness 判別式（TC-33 が静的走査する）

マージ後の最優先 follow-up は #1036（K-1）。本 PBI が既存 fail-open の被害を
3 TC → 17 TC に拡大したため。
```

## 参照ファイル一覧

| 種別 | パス |
|------|------|
| handoff（完了資産） | `docs/working/TASK-1012/handoff.md` |
| plan（改訂 11 / **編集禁止**） | `docs/working/TASK-1012/plan.md` |
| todo（**編集禁止**） | `docs/working/TASK-1012/todo.md` |
| test-cases（**編集禁止**） | `docs/working/TASK-1012/test-cases.md` |
| pbi-input（**編集禁止**） | `docs/working/TASK-1012/pbi-input.md` |
| C-1（9 ラウンド / 計 55 件反映） | `docs/working/TASK-1012/review-self.md` |
| C-2 + 独立 river-review（R-001〜R-014） | `docs/working/TASK-1012/review-external.md` |
| exec 実測サマリ | `docs/working/TASK-1012/evidence/test-runs/exec-summary.md` |
| AC-6 検証スクリプト | `docs/working/TASK-1012/evidence/verification/tc-a6a.sh` |
| 親 issue | <https://github.com/s977043/plangate/issues/1012> |
| follow-up issue（K-1） | <https://github.com/s977043/plangate/issues/1036> |
| Plan Package PR | <https://github.com/s977043/plangate/pull/1030> |
