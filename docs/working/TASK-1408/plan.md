---
task_id: TASK-1408
artifact_type: plan
schema_version: 1
status: draft
mode: critical
related_issue: https://github.com/s977043/plangate/issues/1408, https://github.com/s977043/plangate/issues/1329
created_by: ai-draft-pending-human
---

# TASK-1408 Implementation Plan（C-3 CONDITIONAL / c3.json 未発行）

## Goal

canon 7 本の I1 例外が #1402 により失効した事実を §7 に記録し、以後の canon 規定変更を I4 へ移行する。この記録自身も I4 で採用する。

## 結論（先に読む）

- 失効は確定事実として記録できる。M-2 と M-3 が baseline から動いている。
- **新規発見: 失効後すでに canon へ 4 回 merge が入っている**（`evaluation-trust-boundary.md` +15 と `north-star.md` を含む）。独立検証の読みでは規定変更 3 件（#1406、#1441、#1487）と索引 1 件（#1447）で、いずれも approving review 0 件である。記録に書かないと事実を隠すことになる（Q-1）。
- `Phase 1 exit criteria` は現在どこにも存在しない。追加ではなく節の新設になる。
- 本 PR の I4 は Human C-4 と、commit に固定して再現できる機械証跡で組む。独立な再組み立て（ME-6）は補助の assertion とし、機械証跡に数えない（R2-12）。CI は clone が浅い見込みで過去 SHA を検査できない（Q-3）。

## Context

- 同一 issue の open PR: #1408 / #1329 とも 0 件。タイトル検索でも canon / I4 / phase0 の重複なし（2026-11-06）。
- PR #1402: `gh pr view` で MERGED、`mergedAt` 2026-09-29T00:01:17Z、`mergeCommit` `3331e5c49751b268412d4db8e5862982ac0005d8`。

## 前提の実測検証

依頼の実測値を独立に再測定し、**すべて一致**した。測定は `git ls-tree` / `git grep` の commit 指定（作業ツリー非依存）。

| 前提 | 検証 | 実測 | 判定 |
|---|---|---|---|
| M-1 なし | 親 / merge / main の ls（非再帰）、再帰、内容 | 3 時点とも全て `(none)` | ✅ |
| M-2 は 0 → 6 → 11 ファイル | `git ls-tree -r <c> scripts/ai-loop-v2 bin/ai-loop-v2` | 親 0、merge 6、main 11 | ✅ |
| M-3 は 4 → 9 → 13 ファイル | §7 の語彙で `git grep -liE` | 親 = baseline 4 と一致、merge 9、main 13 | ✅ |
| 現在の M-3 に `scripts/ai-loop/test_pbi_materializer.py` | 同上 | 含まれる（Legacy namespace 側の新規） | ✅ |
| #1402 は canon を変更していない | `git diff --name-only 3331e5c4^1 3331e5c4 -- docs/ai/ai-loop-v2 schemas bin .github/workflows` | 出力なし | ✅ |
| 失効後の canon 変更 | `git log --first-parent 3331e5c4..origin/main -- <canon 7>` | 4 件（下表） | ✅ |
| Phase 1 exit criteria の所在 | `git grep "Phase 1 exit" origin/main -- docs tests scripts .github` | 0 件 | ✅ |
| Stage A canary の実行履歴 | `gh run list --workflow claude-subscription-canary.yml` | 0 件 | ✅ |
| CI は過去 SHA を持たない | `test.yml` / `ci.yml` に `fetch-depth` なし | checkout 既定（浅い clone）と推定 | N/A → Q-3（CI 実ログ未確認） |

### 失効後に merge された canon 差分

| mainline commit | PR | merged (UTC) | canon 差分（+/−） | reviewDecision |
|---|---|---|---|---|
| `a6d1ea5f` | #1406 | 2026-09-29T00:04 | artifact-responsibilities +7/−1、taxonomy +1/−1 | 空 |
| `6d626360` | #1441 | 2026-10-04T05:31 | artifact-responsibilities +115/−2、evaluation-trust-boundary +15/−0、north-star +104/−2 | 空 |
| `0122d6f9` | #1447 | 2026-10-04T13:05 | README +2/−1 | 空 |
| `a3c9146d` | #1487 | 2026-10-05T00:48 | north-star +25/−1 | 空 |

4 件とも author = mergedBy = `s977043`、approving review 0 件。この値から Human と AI の区別はできず、**Human 判断の機械証跡はない**。規定変更か索引かは独立検証の読みであり、確定には Human 裁定が要る（Q-1）。

## Questions / Unknowns

| ID | 問い | 推奨 | 判断者 |
|---|---|---|---|
| **Q-1** | 上表の失効後差分をどう扱うか | **(a) 起点を 2026-09-29 の失効日に固定して §7 に列挙し、事後 I4 か例外扱いかの判定を別 issue に分け、その完了を Phase 1 exit の依存にする**。別 issue は PR 前に起票する（名指し承認）。(b) 本 PR で事後 I4 まで行うのはスコープ拡大。(c) 起点を記録日にすると 3 件を黙って免除し、§7 より弱くなるので不可 | Human（C-3 前） |
| Q-2 | M-1 判定コマンドの是正。#1329 の既存処分は「次回 canon 更新時に再帰検査へ是正」 | **既存処分に従う。新節で「以後の判定は再帰版」と定め、既存行は baseline 当時の記録として残す**。追記だけで処分を満たせる。判定結果は `ls` 版と再帰版で同じ `(none)` だった | Human |
| Q-3 | I4 の「machine evidence」は何を満たせばよいか | **別 context の実行者が `measure.sh` を読まず §7 と AC からコマンドを組み立て、結果を集合で照合する + PR head の CI 緑**（下記 ME 表）。同じスクリプトの再実行は決定性しか示さない。CI で過去 SHA を検査するには workflow（HO）の変更が必要で、本 PR の目的に対して過剰 | Human |
| Q-4 | AC-4 の置き場所を `.github/PULL_REQUEST_TEMPLATE.md` にしてよいか | **はい（§7 からは参照のみ）**。CI は同テンプレートのパスを `ci.yml` L102 で参照しており、exec で影響を確認する | Human |
| Q-5 | #1329 の 2026-09-23 コメント「runtime evidence 確認後に記録 / final invalidation pending」を覆してよいか | **C-3 で裁定する**。§7 正本の「M が動いた時点で失効」を優先し、Stage A の証拠を失効の条件にしない。両 issue への追記は merge 後に名指し承認で行い、本 PR の差分には含めない | Human（C-3） |
| Q-6 | AC-4 の「canon 変更 PR ごとの再測定」を、失効後はどう扱うか | **失効により再測定は判定条件として終了し、I4 証跡に置き換えると明記する**。置き場所はテンプレート。PR author がチェックし、reviewer が semantic に判定する | Human |

**Human 裁定（2026-11-06、2026-11-07）**: Q-1〜Q-6 は推奨どおり。R2-9 は Replan Trigger（§3 / §4 の弱化）に該当として扱い、例外なしの I4 へ是正した。別 issue は #1643 として起票した（2026-11-07、Human 名指し承認）。C-3 は CONDITIONAL で、未収束のまま計画レビューを打ち切ることを承認した。Q-5 は plan の推奨のまま、Human の c3.json 発行で確定する。

**C-2 は未収束**: 新クラスが 3 ラウンド連続で出たので、Human 裁定（2026-11-07）により主張を証明できる範囲へ絞り、R4 は行わない。打ち切りの可否は C-3 で Human が判断する。

**C-3 で確認する裁定後の変更**: Q-3 の推奨にあった ME-6 を機械証跡から外した（R2-12）。Q-6 の「reviewer が判定」は、non-normative の確定を Human に限る形へ強めた（R2-10）。

## 計画の核

### AC 対応表

| AC | 実現 | 置き場所 | TC |
|---|---|---|---|
| 1408-AC-1 | merge SHA と `gh pr view` の出力 | §7 失効節 | TC-01 |
| 1408-AC-2 | M-2 の親 / merge / main 測定（親が負の対照） | §7 失効節 | TC-02 |
| 1408-AC-3 | 「2026-09-29 に失効」 | §7 失効節 | TC-03 |
| 1408-AC-4 | 以後の規定変更は I4 | §7 失効節、exit criteria | TC-03, TC-05 |
| 1408-AC-5 | 非遡及の明記 | §7 失効節 | TC-04 |
| 1408-AC-6 | 別 context レビュー + ME-1〜5、ME-7（ME-6 は補助） | evidence、handoff | TC-07, TC-08 |
| 1408-AC-7 | Human merge | GitHub | H-03 |
| 1329-AC-1 | 3 時点の実測出力 | §7 失効節 | TC-02, TC-06 |
| 1329-AC-2 | 「失効」明記 | §7 失効節 | TC-03 |
| 1329-AC-3 | exit criteria 1 行 | §8 新設節 | TC-05 |
| 1329-AC-4 | PR テンプレート 1 項目 + review gate | テンプレート、§7 は参照のみ | TC-09 |
| 1329-AC-5 | 下記の裁定表 | §7 失効節 | TC-06 |

### #1329 残指摘の裁定（案）

| # | 内容 | 裁定 |
|---|---|---|
| 2 | 語彙近似の限界 | **解消扱い**。#1329 本文の semantic invalidation gate（語彙によらず機械強制の有無を reviewer が判定、不能は失効候補）で対応済みと記録する。失効が確定したので本例外に対する役割は終わる |
| 4 | `ls schemas/` 非再帰 | **新節で再帰版へ是正、既存行は当時の記録として保存**（Q-2） |
| 5 | fail-closed の主体と時期 | **implementation PR author + reviewer / PR ごと**（#1329 本文のとおり）。置き場所は AC-4 |

### §7 への記録文案

`#### I4 移行条件` の判定規則の後、`#### 経緯` の前に追記する。既存の本文は変更しない。

```markdown
#### 例外の失効（記録: TASK-1408）

**本例外は 2026-09-29（UTC）に失効した。** 動いた条件は M-2 と M-3、M-1 は baseline のまま。
以後の canon 7 本の規定変更は I4（Human + machine independent evidence）を要求する。Human C-4 と merge の責務は変わらない。
本節は M による失効の記録であり、2026-09-23 の #1329 コメントにある「runtime evidence 確認後の記録」を置き換える。

- **一次証拠**: PR #1402 `mergeCommit` = `3331e5c49751b268412d4db8e5862982ac0005d8`、`mergedAt` = 2026-09-29T00:01:17Z（`gh pr view 1402 --json mergeCommit,mergedAt`）
- **実測**（`git ls-tree -r` / `git grep -liE` を commit 指定で実行。M-1 は再帰で測定）:

  | 時点 | M-1 | M-2 | M-3 |
  | --- | --- | --- | --- |
  | `3331e5c4^1`（#1402 の親） | なし | なし | baseline 4 ファイルと一致 |
  | `3331e5c4`（#1402 の squash） | なし | `scripts/ai-loop-v2/` 6 ファイル | 9 ファイル（baseline + 5） |
  | `<base>`（記録の分岐元。確定 SHA を書く） | なし | <実測> | <実測> |

  > ファイル数は測定値であって契約値ではない。出力全文: `docs/working/TASK-1408/evidence/measurements.txt`
- **実行系の存在**: #1402 は RunEvent / RunState / Decision / Delivery の検査を実行コードとして導入した（#1329 の #1402 preflight で semantic invalidation = YES）。本記録は存在の事実のみを扱い、**実装の正しさを判定しない**。
- **baseline は更新しない。** 新たに現れたファイルを baseline へ加えることは本例外の延長と同義であり行わない。M-3 の baseline 4 ファイルは測定の基準点として残す。#1329 の「baseline 欄へ反映」は本節の記録をもって満たす。
- **遡及しない。** Phase 0 / Phase 0.1 の充足記録（I1）は当時の規定に照らして有効なまま残す。
- **#1402 は canon を変更していない**（`git diff --name-only 3331e5c4^1 3331e5c4 -- docs/ai/ai-loop-v2` が空）。
- **失効後から本記録までの canon 差分**（`git log --first-parent 3331e5c4..<base> -- phase0-migration.md を含む canon 7 本`）: `a6d1ea5f`（#1406）/ `6d626360`（#1441）/ `0122d6f9`（#1447）/ `a3c9146d`（#1487）。merge 主体は `s977043`、approving review は 0 件で、**Human 判断と I4 の機械証跡は確認できない**。規定変更か否かの判定と扱いは #1643 に分離する。
- **§3 / §4 は変更しない。** 本節は失効の記録である。
- **再測定の終了**: 失効後は、本 §7 判定規則の再測定の 2 つの時機（Phase 1 着手時、canon 変更 PR ごと）のどちらも判定条件ではない。記録と再測定の規則はここで終了し、以後は I4 証跡で判定する。既存の行は当時の規定として残す。
- **以後の I4 の最低要件**: (1) `reviewed_at_sha` に固定した独立レビュー。作成者と別の context で実施し、水準（I1 / I2 など）を記録する。(2) 機械証跡は、固定 commit で再現できるコマンドと出力で、作成者の外で再実行したもの。CI 緑だけでは足りない。(3) Human C-4。
- **non-normative の判定**: 変更が規定変更でないと確定できるのは Human だけで、C-4 で対象を名指しして承認する（本 §7 の判定主体の規則と同じ）。LLM のレビュアーは確定できない。判断できない場合は規定変更として扱う。
- **I4 の充足記録**: 本記録の Human C-4 と機械証跡は `docs/working/TASK-1408/handoff.md` に残す。記録を更新する PR 自身の merge を本文で充足と宣言しない。

| 残指摘（#1329） | 裁定 |
| --- | --- |
| 語彙近似の限界 | semantic invalidation gate で対応。失効により本例外での役割は終了 |
| M-1 の `ls schemas/` 非再帰 | 以後の判定は再帰版とする。上の判定コマンドは baseline 当時の記録として残す |
| fail-closed の主体と時期 | implementation PR author + reviewer / PR ごと。チェック項目は `.github/PULL_REQUEST_TEMPLATE.md` |
| canon 変更 PR ごとの再測定 | 失効により判定条件としては終了し、I4 証跡に置き換える |
```

### §8 新設節の文案

`## 8. Next phase` の末尾に追記する。

```markdown
### Phase 1 exit criteria

- [ ] §7 に列挙した失効後の canon commit（`3331e5c4..<base>`）の扱いを、#1643 で Human が裁定している
- [ ] `<base>` より後の canon 7 本の規定変更が、すべて I4（§7 の最低要件）で採用されている。例外は置かない
```

他の exit 項目は本 PR で作らない（既存の Phase 1 計画を先取りしない）。

### PR テンプレートの追加案（AC-4）

`## Validation` に 1 項目を追加する。

```markdown
- [ ] **If this PR changes `docs/ai/ai-loop-v2/` canon 7 files (see `phase0-migration.md` §7), I attached I4 evidence that meets the minimum requirements in §7: `reviewed_at_sha`, an independent review, and machine evidence reproducible at a fixed commit (CI alone is not enough). This replaces re-measuring M-1 to M-3. Only a Human can confirm a change is non-normative, by naming it at C-4; if undecidable, it is normative.**
```

### I4 充足に必要な機械証跡（本 PR）

§4 の I4 は「Human-owned 判断と機械 evidence の両方」である。§3 の主旨に合わせ、**作成者の申告でなく作成者の外から再現できる出力**を証跡とする。

| ID | 証跡 | 再現方法 | 独立性の根拠 |
|---|---|---|---|
| ME-1 | #1402 の merge SHA と時刻 | `gh pr view 1402 --json state,mergedAt,mergeCommit` | GitHub が記録した値 |
| ME-2 | M-2 の負の対照（親）と正の対照（merge） | `git ls-tree -r <SHA> scripts/ai-loop-v2 bin/ai-loop-v2` | commit SHA に固定で決定的 |
| ME-3 | M-1（再帰）/ M-3、検出器の陽性対照 | `git grep -liE "$V" <SHA> -- ...`。merge 時点で `scripts/ai-loop-v2/run_state.py` が検出され、親では検出されないこと | 同上 |
| ME-4 | 他 canon 6 本の差分なし、`phase0-migration.md` の削除なし（**規定の意味の不変は主張しない**） | `git diff --exit-code <base> <canon-sha> -- docs/ai/ai-loop-v2/evaluation-trust-boundary.md` と他 canon 5 本が空。`phase0-migration.md` は `--numstat` の削除 0 | 差分から決定的 |
| ME-5 | baseline 不変 | §7 の baseline 4 行ブロックが base と head で byte 一致 | 同上 |
| ME-6（補助、機械証跡に数えない） | 独立な組み立て | 別 context の実行者に `<base>` の §7 と issue AC だけを渡す。`git archive <canon-sha>` から `docs/working/TASK-1408/` を除いた tree と、対象 SHA の git object に対してコマンドを組み立てて実行し、ファイル集合を照合 | 「読まなかった」ことは確認できないので assertion と明記する |
| ME-7 | PR head の CI | `gh pr checks` | 実行基盤が別。ただし**内容の正しさは証明しない**（過去 SHA は検査しない） |

**測定対象の固定**: canon 差分を commit した SHA を `<canon-sha>` とし、ME とレビューの対象を固定する（`reviewed_at_sha` = `<canon-sha>`）。以後の commit は evidence と TASK 成果物だけとし、`git diff --exit-code <canon-sha> <head> -- docs/ai/ai-loop-v2 .github/PULL_REQUEST_TEMPLATE.md` が空であることを検査する。canon を直したら `<canon-sha>` から取り直す。

**証跡の結合**: `evidence/manifest.txt` に `measure.sh` の blob SHA、入力 SHA（`<base>`、`<canon-sha>`）、`measurements.txt` の digest、実行者、時刻を書く。最終 head で blob SHA と digest の一致を検査し、測定器や出力を変えたら再実行と再レビューを行う。

**作成者の外での実行**: Codex が ME-1〜5 を固定 SHA で再実行し、コマンドと出力を `evidence/independent-rerun.txt` に残す。これを C-4 の前提にする。決定性は測定方法の独立性を示さず、同じ `measure.sh` を使う部分は assertion と明記する。これで I4 の機械証跡として足りるかは Human が C-4 で判断する。

**意味の変更の明示**: 追記が既存規則に与える変更を差分形状から判定しない。本 PR の変更は「再測定の 2 つの時機の終了」と「non-normative の確定を Human に限る」で、独立レビューと Human C-4 の判断対象として PR 本文に列挙する。

Human 判断: C-4 merge。レビュー: **I1（別 context、docs 整合）+ I2（Codex、敵対）を 2 ラウンド以上**、`reviewed_at_sha` 必須。

これは I4 の「機械 evidence」の解釈案であり、§4 に細則はない（Q-3）。**完全性は主張しない。** レビュアーはいずれも LLM で、Human merge は第三者承認を保証しない（evidence-audit §3 の限界）。

### 波及

| 対象 | 判定 |
|---|---|
| `README.md` / `north-star.md` の Status 行 | **変更しない**。「Independent Review DONE (I1)」は歴史的事実で、正本は §7。変更すると本 PR の I4 対象を広げるだけ |
| `phase0-migration.md` 冒頭 Status 行 | 変更しない（新節で足りる）。C-2 で異論があれば再考 |
| `evaluation-trust-boundary.md` | **変更しない**（§3 / §4 を弱めない） |
| `loop-graph-harness.md` / `ratchet-traceability.md` | canon 外で I1 例外の記述なし。変更不要（`git grep` 済み） |
| `docs/working/TASK-1383/*`、`_reports/1422-*` | 履歴。変更しない |
| `reviewed_at_sha` 表（§7 既存） | `f8f1e8b8` 以降の表は `#1321`・`#1302` で止まっている。本 PR の差分範囲は新節に含まれるので、既存表は触らない |
| テスト | `tests/` に §7 を固定するものはない（`I4 移行条件` の grep 0 件）。新規テストは追加しない |

### #1374 と semantic gate の影響

**結論: #1374 のファイル変更は不要。ただし前提の読み替えが要る。**

- #1329 の 2026-09-23 コメントは「final invalidation: PENDING first Stage A canary evidence」としている。§7 の規定は M のいずれかが動いた時点で失効なので、**#1402 の M-2 で失効は確定済み**であり、Stage A の証拠を待たない。
- したがって #1374 の未了項目「#1329 semantic I4 invalidation review is executed after runtime establishment」は、失効の条件ではなくなる。Stage A の workflow は新たな失効候補ではなく、既に失効した体制の下の実行面である。
- **Stage B の入口条件は緩めない**。OAuth secret、canary 実走、負の assertion などの残項目は独立に有効。canary の PASS を失効や #1402 の正しさの証拠として扱わない。
- canary は実行 0 件、workflow は M-3 に現れない（実測）。

## Approach Comparison

| 案 | Evidence | Complexity | New Abstractions | Current-Need Trace | Verification | Trade-offs | 判定 |
|---|---|---|---|---|---|---|---|
| A: §7 / §8 への追記 + テンプレート 1 行 + evidence | §7 が記録先を指定 | 低 | なし | 全 AC | ME-1〜7 | 検出器は機械化されない（#1329 で follow-up 扱い） | **採用** |
| B: A + CI で canon 変更時に I4 証跡を強制 | #1329 は follow-up とする | 高。workflow は HO | gate 1 個 | なし（AC-4 は 1 箇所で足りる） | — | 強制力は上がるが範囲外 | 不採用 |
| C: extras テストで SHA を固定 | CI は過去 SHA を持たない見込み | 中 | テスト 1 本 | ME を CI で走らせたい場合のみ | 浅い clone で素通りの危険 | 不採用（Q-3 で再考可） |
| D: 全 canon の Status 行を更新 | Status は索引 | 低 | なし | なし | — | I4 対象が増えるだけ | 不採用 |

### Why this is the minimum sufficient design

- New abstractions: なし。節 2 個とチェック項目 1 行のみ
- Deferred: 機械 detector、失効後差分の事後 I4、Issue コメント（Q-5）

## Change Type / Verification Strategy

- Change type: docs
- Pre-change evidence: base で「例外の失効」節と `Phase 1 exit criteria` が 0 件
- Post-change evidence: head で各 1 件、ME-1〜7

## Files / Interfaces

| ファイル | 操作 | 目的 |
|---|---|---|
| `docs/ai/ai-loop-v2/phase0-migration.md` | modify（追記のみ） | §7 失効節、§8 exit criteria |
| `.github/PULL_REQUEST_TEMPLATE.md` | modify（1 行、HO 外） | AC-4 |
| `docs/working/TASK-1408/evidence/measure.sh`、`measurements.txt`、`manifest.txt`、`independent-rerun.txt` | create | ME |
| `docs/working/TASK-1408/*` | create | 標準成果物（plan.md は EH-3 のため `PLANGATE_HOOK_TASK=TASK-1408` 起動が必要） |
| GitHub issue（失効後差分の裁定） | create（Human の名指し承認後） | Q-1。`7b523a45`（#1350）が既存 `reviewed_at_sha` 表に未記載の件も含める |

## Work Breakdown

### Task 1: 測定スクリプトと出力

**Purpose**: ME-1〜5 を単一スクリプトにし、`<base>` に固定した出力を保存する。
**Files**: `evidence/measure.sh`、`evidence/measurements.txt`。
**Completion**: 再実行で同一出力。陽性対照が機能する。
**Rollback**: `git revert`。

### Task 2: §7 / §8 / テンプレートの追記

**Purpose**: 文案を確定値で反映する。exec 時に main を再測定し、新規 canon commit があれば差分表へ追加する。
**Files**: `phase0-migration.md`、`.github/PULL_REQUEST_TEMPLATE.md`。
**Completion**: `git diff --numstat` の削除 0、TC-01〜06、TC-09 PASS。
**Rollback**: `git revert`（1 commit）。

### Task 3: レビューと独立再実行

**Purpose**: I1 + I2 を 2 ラウンド、ME-6 を実行する。
**Completion**: `reviewed_at_sha` と出力 hash の記録、回避クラス台帳。
**Rollback**: 不要（記録のみ）。

### Task 4: handoff

**Purpose**: I4 の充足状態を「Human C-4 待ち」として正直に記録する。
**Rollback**: 不要。

## Verification Plan

| 種別 | コマンド | 期待結果 | Evidence |
|---|---|---|---|
| Docs lint | CI の `markdownlint` 経路 | exit 0 | CI |
| 回帰 | `sh tests/run-tests.sh` | FAIL なし | `evidence/test-runs/` |
| ME | `sh docs/working/TASK-1408/evidence/measure.sh <base> <canon-sha>` | 保存値と一致 | `evidence/` |
| 固定の検査 | `git diff --exit-code <canon-sha> <head> -- docs/ai/ai-loop-v2 .github/PULL_REQUEST_TEMPLATE.md` | 差分なし | `evidence/` |

### レビューレーン計画

| 成果物 | レーン | unavailable 時 |
|---|---|---|
| §7 / §8 文案 | R1: docs 整合 I1 / 敵対 I2（「例外を延命していないか」「§3 / §4 を弱めていないか」）。R2: 是正を疑う | external-reviewer-interface §10 に記録 |

## Plan Review Readiness

- Success Criteria: 全 AC、Done = Human C-4 merge
- Review Criteria: 非遡及、非延命、runtime 判定の混入なし、失効後差分を隠さない
- Backward compatibility: テンプレート 1 行の追加のみ
- Operational risk: 以後の canon PR の負担が増える（意図どおり）
- Non-goals: 上記 Out of scope
- Change-prohibited: `evaluation-trust-boundary.md`、他 canon 5 本、§7 の baseline ブロックと既存判定コマンド、`schemas/`、`scripts/ai-loop-v2/**`、workflows

## Replan Triggers

- exec 時の再測定で M-1 が動いている、または merge SHA が変わっている
- canon 他 6 本の変更が必要になった
- ME-6 のファイル集合が不一致（原因特定まで停止）
- レビューで §3 / §4 の弱化が 1 件でも指摘された
- `ci.yml` のテンプレート参照で template 変更が CI を変える

## Stop Condition

- Q-1 / Q-3 が未回答のまま exec が必要になった
- baseline の更新が必要に見えた
- runtime の正しさの判定を記録へ含める必要が出た

## Human Approval Boundary

- C-3、C-4、merge、Issue への投稿（Q-5）、失効後差分の扱いの裁定は Human

## 残存脅威モデル

守るもの: 失効事実と時点の記録、以後の I4 要求の明文化、baseline の非延命。

守らないもの: I4 の機械的な強制（PR テンプレートは自己申告で、CI gate ではない）。語彙に現れない実行系の検出。失効後 4 差分の内容の妥当性。レビュアーの独立性の機械的証明。Human merge の第三者性。

## Mode判定

**モード**: critical

**判定根拠**:
- 変更ファイル数: 2 + TASK 成果物 → light 相当
- 受入基準数: 12 → critical
- 変更種別: Evaluation Harness 定義である canon の独立性規定の移行 → critical
- **最終判定**: critical（Human 決定）。ファイル数は少ないが doc-light は不適用（canon の正本）。C-2 は複数観点、V-2〜V-4 の適用は docs 差分として V-4 中心に判断する
