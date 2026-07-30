# PBI INPUT PACKAGE — TASK-0916

> Issue: [#916](https://github.com/s977043/plangate/issues/916)（enhancement / ai-loop / governance / **priority:P0**）
> 由来: [#907](https://github.com/s977043/plangate/issues/907) / PR #912 で新設した rollout-policy §2 の「判定基盤 carve-out」の **機械層 follow-up**（同節が自ら「機械層化の射程（V2）」として予告している範囲）
> 作成: 2026-07-30（**main `b306b12` で行番号・記号アンカー・件数をすべて再実測**。行番号は目安であり記号アンカー〔関数名・変数名・テスト名〕を正とする）
> EPIC: [#870](https://github.com/s977043/plangate/issues/870) の Child Issues に登録済み（close blocker ではない）

## Context / Why

`docs/workflows/ai-loop/rollout-policy.md` §2 は、ai-loop 自身の判定基盤を auto-approve 拡張の適用対象から**除外し escalate 固定**とする「判定基盤 carve-out」を定めている（L52-58 実測）。しかし同節は**自らそれが規範層にとどまることを明記**している:

> **規範層である旨の明示**: arbiter（`arbiter.py`）の `boundary_check` は ho-paths.md の HO 表からのみ touches-HO を導出するため、上記 carve-out パスは現状 **boundary=clean と判定される**（機械層では escalate しない）。よって本 carve-out は**規範層**であり、eligible 判定時に実行者が escalate する責務を負う（W チェック 2 体が併せて担保）。
> — `docs/workflows/ai-loop/rollout-policy.md` L57

つまり **ai-loop が自分の判定基盤を書き換える変更を、機械層は clean として通してしまう**。自己改変防止が人間・W チェックの運用に依存しており、`ho-paths.md` 自身が持つ self-protection 原則（原則 1: 「Arbiter が自己の判定基準を自己改変しないための機械層」）と非対称な状態にある。

### 実測による裏取り（main `b306b12`）

| 主張 | 実測方法 | 結果 |
|------|---------|------|
| `boundary_check()` は HO 表のみを出典とする | `scripts/ai-loop/arbiter.py` の `def boundary_check`（L281）と docstring | **確認**。docstring に「出典: docs/ai/ai-loop/ho-paths.md 判定アルゴリズム」と明記され、引数は `changed_files` と `ho_patterns` のみ |
| carve-out glob が HO 表に未登録 | `docs/ai/ai-loop/ho-paths.md` の HO パス一覧表（L26-46・**21 パターン**）を全数確認 | **確認**（0 件）。`scripts/ai-loop/**` / `docs/workflows/ai-loop/**` / `docs/ai/ai-loop/**` / `*/skills/ai-loop-cycle/**` はいずれも表に存在しない |
| 現仕様が既存テストで固定されている | `scripts/ai-loop/test_arbiter.py` | **確認**。`test_docs_ai_ai_loop_excluded`（L107・`docs/ai/ai-loop/concept.md` → `clean`）/ `test_clean_path`（L165・`scripts/ai-loop/arbiter.py` → `clean` かつ `matched == []`） |
| carve-out 用の判定分岐が存在しない | `arbitrate()`（L884-1128）の `priority_table`（**行番号でなく記号アンカーで指す**・L1033-1062 付近）+ テーブル外の priority 0（L942-955）/ priority 5（L1071-1128）を全列挙 | **確認**。現在の priority は `0, 1, 1.5, 1.6, 1.65, 1.7, 1.9, 1.95, 2, 3, 4, 5, 6` の 13 ステップで、carve-out 相当は皆無 |

## What（Scope）

### In scope

1. **共通 escalate-path 評価器の新設**（`arbiter.py`）
   - carve-out glob 集合に `changed_files` が 1 件でも一致したら **escalate 固定**（`HUMAN_ESCALATED`）にする判定を追加する
   - **`boundary_check()` 自体は変更しない**。別関数（`carve_out_check()` 等）として追加し、`Signals`（L821-838）へ `carve_out_hit` 相当を足して `priority_table` に新規行を挿す additive 変更とする
   - 挿入位置は **priority 1（touches-HO）の直後**が第一候補。既存の割込み追加は `1.5 / 1.6 / 1.65 / 1.7 / 1.9 / 1.95` と **1.x の小数刻み**で行われている前例に倣う（`decision-table.md` L57「priority 1〜6 の番号体系は変更しない」を尊重）
   - `POLICY_REF`（L560 = `"auto-approve-lite-clean@v4"`）の改版が必要かを plan 段階で判定する
2. **carve-out glob の機械可読な正本化（1 箇所）**
   - 現在 carve-out glob は `rollout-policy.md` の散文中にのみ存在する。arbiter が読める形（`ho-paths.md` の既存テーブル形式 or 専用ファイル）へ 1 箇所化する
   - 対象は rollout-policy §2 の **①〜③**（下記「carve-out の対象範囲」を正とする）
   - **解決不能時は fail-closed**（正本ファイル欠落・パース 0 件のとき `HUMAN_ESCALATED` に倒す）。既存 `resolve_ho_patterns()` が「fail-open は絶対に行わない」としている規律に揃える（RV-M3）
   - **`scripts/sync-plugin-plangate.sh` の同期対象へ carve-out 正本を追加する**。同スクリプトは whitelist 方式で、新設ファイルは明示追加しないと `plugin/plangate/skills/ai-loop-cycle/references/` へ配布されず、**plugin bundled fallback 経路で carve-out が常に無効化**される（RV-M3）
3. **`decision-table.md` への priority 行追記**（正本間ドリフト防止）
4. **負側テストの追加**（`test_arbiter.py`）
   - carve-out パスが escalate 固定になること / 非該当パスの判定が不変であること
   - **既存の `test_docs_ai_ai_loop_excluded` / `test_clean_path` のアサーションは維持する**（「HO 表からは clean」は別レイヤーの仕様。carve-out は新 priority 行で escalate させる）

#### carve-out の対象範囲（rollout-policy L52-58 実測。**issue 本文より本表を正とする**）

| # | 対象 | glob |
|---|------|------|
| ① | 強制エンジンコード | `scripts/ai-loop/**` |
| ② | ai-loop policy / spec 文書 corpus 全体 | `docs/workflows/ai-loop/**` ・ `docs/ai/ai-loop/**` |
| ③ | ai-loop 実行手順スキル | `.agents/skills/ai-loop-cycle/**` ・ `.claude/skills/ai-loop-cycle/**` |

**配布派生（`plugin/plangate/skills/ai-loop-cycle/**` 等）は対象に含めない**（**暫定。U-5 で確定。案 (a) 採用時は本行を plan で更新する**）。rollout-policy が「正本を carve-out することで実質的に保護される。配布側の独立改変は CI の sync drift-check で検出する」と明記しているため（L56 実測）。

> 注 1: 事前調査で「③ の skills は carve-out 本体に含まれない可能性がある」との所見が出たが、**実測により誤りと確認した**。rollout-policy L55 は `.agents/skills/ai-loop-cycle/**` ・ `.claude/skills/ai-loop-cycle/**` を ③ として明示的に carve-out に含めている（両ディレクトリの**実在も確認済み**）。配布派生（`plugin/**`）のみが別扱い。
>
> **⚠️ 注 2（配布派生除外の前提が弱い / plan で必ず扱う）**: rollout-policy が根拠とする「CI の sync drift-check で検出する」は、**merge をブロックする強制力を持たない**。main の ruleset（`Protect default branch` / id `14939019`）の `required_status_checks` は **`Markdown lint` の 1 本のみ**（2026-07-30 実測）で、`sync-plugin-plangate / drift-check` は必須チェックに未登録。したがって配布派生への独立改変を含む PR が drift-check 失敗のまま merge され得る window が構造的に残る。
>
> さらに **TASK-0907 の plan（L13）では carve-out ① を「`scripts/ai-loop/**` + 配布版」と記述**しており、rollout-policy の最終実装文言（配布派生は別扱い）と**表現が一致していない**。どちらを機械層の対象とするかは plan の設計判断（下記 U-5）。

### Out of scope

- **rollout-policy §5 の不変条件の変更**（本番承認フロー WF-00〜07 の C-3 は常に Human・§5 不変）
- **#906 の「導入先 ho-paths §2 domain-gate 表」の設計そのもの**（本 PBI は評価器の骨格を作り、#906 は入力ソースを足す側）
- 配布派生（`plugin/plangate/skills/ai-loop-cycle/**`）の独立監視（CI sync drift-check の担当）— **暫定。U-5 で確定**
- `decision-table.md` ↔ `arbiter.py` の**文言レベル機械照合の一般化**（下記 Unknowns U-3。本 PBI では carve-out 行の整合のみ担保する）
- `LoopSpec` への `scope.escalate_paths` / `deny_paths` 追加（下記 Notes の設計判断で非採用）

## 受入基準

- **AC-1**: carve-out glob（①〜③）に一致する `changed_files` を含む入力で、arbiter が **escalate 固定**（`HUMAN_ESCALATED`）を返す。負側テストで固定する。**加えて carve-out 正本が解決できない入力（ファイル欠落 / パース 0 件）でも `HUMAN_ESCALATED` になる**ことを負側テストで固定する（fail-closed。RV-M3）
- **AC-2**: carve-out glob が **機械可読な正本 1 箇所**に存在し、arbiter がそこから実行時解決する。**かつ `rollout-policy.md` §2 の ①〜③ 散文列挙を新正本への参照へ置換し、glob・条件の再掲を残さない**（issue #916 AC-2 の「rollout-policy §2 はそれを参照する（断片化しない）」を満たす。TASK-0871 plan AC-4 の「バナーは参照形式に統一し、数値・条件・glob の再掲を禁止する」と同型。再掲を残すと TASK-0913 が是正対象とした二重管理ドリフトを再生産する）。**あわせて §2 の「規範層である旨の明示」(L57) と「機械層化の射程（V2）」(L58) を機械層強制済みの記述へ更新する**（本 PBI 完了後もこの 2 行を残すと「機械層では escalate しない」という虚偽記述が正本に残る — RV-M1）
- **AC-3**: rollout-policy **§5 の不変条件が無傷**であること（差分確認で証明。§5 に触れていないこと）。**加えて `changed_files` が HO と carve-out の両方に一致する入力で、裁定理由が `priority 1`（touches-HO）のままであることをテストで固定する**（carve-out 行を priority 1 の前に挿すと decision-table の「HO は絶対条件」表現と実装がズレるが、決定値が同じ `HUMAN_ESCALATED` のため既存テストでは検出できない — RV-m1）
- **AC-4**: **carve-out 非該当パスの判定が不変**であること（既存 247 テストが全 PASS。とくに `test_docs_ai_ai_loop_excluded` / `test_clean_path` / `test_ho_pattern_drift_against_source_of_truth` / `test_ho_paths_md_itself` が PASS）
- **AC-5**: 評価器が **パターン集合を引数で受ける一般形**（例: `(patterns, changed_files) -> (hit: bool, matched: list)`）で実装され、**carve-out glob 以外の任意のパターン集合を渡しても同一関数で判定できる**ことをテストで固定する（#906 が「入力ソースを足すだけ」で再利用できる構造の機械的保証。旧案の「または接続点を記録する」という OR 条件は、glob をハードコードした専用関数でも通過してしまう空振り条件だったため撤回 — RV-M4。接続点メモは AC ではなく handoff 要素へ降ろす）
- **AC-6**: `decision-table.md` に新 priority 行が追記され、`arbiter.py` の `priority_table` と**齟齬がない**こと
- **AC-7**: テスト 2 系統がいずれも green
  - `sh tests/run-tests.sh` = **430 passed / 0 failed**（現 baseline 実測値。arbiter のテストはここに**含まれない**）
  - `python3 scripts/ai-loop/test_arbiter.py`（**リポジトリルート起点必須**）= **247 tests OK** + 新規追加分

## Notes from Refinement

### 設計判断: carve-out glob の置き場所（policy 側 vs LoopSpec 側）

issue #916 は提案 (A) 機械可読な glob 一覧 / (B) LoopSpec への `scope.escalate_paths` 追加 の 2 案を挙げているが、**実測により (A) を推す**:

- `docs/workflows/ai-loop/loopspec.md` L24 が「**LoopSpec は arbiter.py への入力そのものではない**」と明記している。LoopSpec 側に置くと、arbiter へ渡すための変換層が別途必要になる
- `escalate_paths` / `deny_paths` は loopspec.md・arbiter.py いずれにも**現存しない**（grep 0 件）。新規フィールド追加は §2/§3 必須フィールド表・記入例など docs 側の追従コストを伴う
- (A) なら既存の `resolve_ho_patterns()`（CLI → CWD → plugin bundled の順で実行時解決・fail-closed）と同型の解決関数を足すだけで完結する

### ⚠️ `ho-paths.md` へ追記する場合は Human patch 分離が必須

carve-out glob を `docs/ai/ai-loop/ho-paths.md` に追記する案を採る場合、**同ファイル自身が HO-contract として HO 表に登録されている**（L46 実測）ため、AI が直接編集できない:

- L108-117 実測: 「本ファイル（`ho-paths.md`）自体の変更（HO 境界の定義変更）は Human 承認必須とする」「この Human 承認必須は機械層でも強制される — 本ファイル自身を HO パス一覧に HO-contract として登録済み」
- `test_ho_paths_md_itself`（L112）が `ho-paths.md` への変更が `touches-HO` かつ `classification == "HO-contract"` になることを assert している
- → **Human patch 分離**（AI が patch を作成 → `git apply --check` + worktree 実適用テストで検証 → Human が適用）を踏襲する。参照すべき前例は以下（**実測で区別**）:

| 参照先 | 位置づけ | 実体 |
|--------|---------|------|
| **TASK-0871** | **実適用まで完了した前例**（最優先で参照） | `docs/working/TASK-0871/approvals/ho-apply-approval.md`（H-02 承認記録）+ `approvals/c3.json`。`.claude/commands/ai-loop-workflow.md` への patch を Human が適用し、`git apply --check --reverse` で事後検証、c3.json 再発行まで実施 |
| **TASK-0872** | **patch 一式のフォーマット前例** | `docs/working/TASK-0872/patches/`（`*.patch` + `*.new` 併置） |
| TASK-0913 | **前例ではなく同方式を採用する姉妹 PBI**（計画段階） | `CLAUDE.md`（HO）を Human 適用 patch で分離する方針を pbi-input L50/L58 で宣言。前例としては TASK-0872 を引いている |

- plan 段階で「専用ファイル新設なら Human patch 不要」との比較を行うこと（U-1）

### 再利用できる既存資産（すべて `arbiter.py` 内・実測）

| 資産 | 行 | 用途 |
|------|-----|------|
| `_ho_pattern_to_regex()` | L224- | セグメント境界を尊重した glob→regex 変換（`*` = 1 セグメント内 / `**` = 0 個以上）。`lru_cache` 付き。**carve-out glob も同じ意味論なので直接流用可** |
| `parse_ho_paths_table()` | L150- | md テーブルパーサ（pattern / 分類 / 理由 の 3 列）。**別ファイルに対してのみ転用可**。`ho-paths.md` 内に carve-out 表を併置する用途には使えない（全文走査のため HO 表として取り込まれる — U-1 / RV-M2）|
| `resolve_ho_patterns()` / `_candidate_ho_paths_sources()` | L193- / L177- | CLI 明示 → CWD → plugin bundled の順で実行時解決 + fail-closed。同型の carve-out 版の雛形 |
| `check_allowed_paths()` | L362- | `_ho_pattern_to_regex` を再利用した「一致すれば逸脱」判定（priority 1.5 相当）。carve-out 判定と同型 |

### #906 との機構共有

- #906 は「導入先 `ho-paths.md` §2（`.env*` / 認証ミドルウェア / 共有 Model / migrations 等の domain-gate）を arbiter が実行時に読まない」という**同型のギャップ**
- 両 issue が「**共通 escalate-path 評価器 1 本 + 入力 2 系統**（carve-out glob / §2 domain-gate 表）」を推奨し、相互参照を記載している
- **本 PBI（#916）を先に実装して評価器の骨格を作り、#906 は入力ソースを足す形**にすると、評価器が二重実装にならない。plan 段階で評価器のシグネチャを #906 が使える一般形（パターン集合と changed_files を受ける）にしておくこと

### 自己適用（bootstrap）の運用影響

本 PBI の差分自体が carve-out ①②（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**`）に該当する。したがって**実装以降は ai-loop 自身の改修 run が常に escalate 固定**になる（Human C-3 前提なので実害はないが、「ai-loop 自身のドッグフーディングは auto-approve 不可」という運用影響が発生する）。plan / todo に 1 行残して受け入れを明確にする（RV-i2）。

### テスト実行系統は 2 つある（重要・実測で判明）

| 系統 | コマンド | 件数 | 備考 |
|------|---------|------|------|
| PlanGate 本体 harness | `sh tests/run-tests.sh` | **430 passed / 0 failed** | `grep -c "ai-loop\|arbiter" tests/run-tests.sh` = **0**。**arbiter のテストは含まれない** |
| arbiter 単体 | `python3 scripts/ai-loop/test_arbiter.py` | **247 tests OK** | **リポジトリルート起点が必須**。`cd scripts/ai-loop && python3 -m unittest test_arbiter` は CWD 依存の `resolve_ho_patterns()` が ho-paths.md を解決できず **116 failures / 4 errors** になる（実測） |

plan / todo には**両系統を明記**し、レビュー時に「CWD を間違えた大量 failure」を回帰と誤認しないようにする。

### Mode 見込み: high-risk（critical への引き上げを plan で再判定）

- 定量: 変更ファイル数 **10〜12 → high 帯（6-15）確定**（RV-M5 で計数規則を TASK-0907 に揃えた）
  - AI 編集 5〜6: `arbiter.py` / `test_arbiter.py` / carve-out 正本（`ho-paths.md` or 新設）/ `rollout-policy.md` / `decision-table.md` / `sync-plugin-plangate.sh`（同期対象追加）
  - **sync 自動生成 4〜6**（実測: `scripts/sync-plugin-plangate.sh` L345 が `arbiter.py` / `test_arbiter.py` を、L194 付近が `docs/workflows/ai-loop/*.md` と選抜した `docs/ai/ai-loop/*.md` を `plugin/plangate/skills/ai-loop-cycle/{scripts,references}/` へ同期する）: `plugin/.../scripts/{arbiter,test_arbiter}.py` / `plugin/.../references/{rollout-policy,decision-table,ho-paths}.md` (+ carve-out 正本)。**同期しないと drift-check が差分検出するため PR に必ず含まれる**
  - 比較対象の TASK-0907 も派生を計数している（同 plan Metrics Evidence: 「4（AI 編集=1・sync 自動生成=2・Human patch=1）」）ため、同一規則で並べる
- 受入基準数 **7** → high 帯（6-10）
- **定性が支配的**: 対象が **arbiter の承認境界判定そのもの**。`.claude/rules/mode-classification.md` の例外ルール「**承認境界周辺の変更 → 最低でも「高」**」に該当する
- HO 9 カテゴリ（`.claude/rules/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows/*` / `CLAUDE.md` / `AGENTS.md` / `.claude/settings*.json` / `.claude/commands/*.md` / `.claude/agents/*.md`）は**非該当**（`scripts/ai-loop/` は `scripts/hooks/` ではない）
- ただし `ho-paths.md` へ追記する案では**同ファイルが HO-contract として HO 該当** → **`lite_eligible=false` + Human C-3 必須**
- **⚠️ critical 引き上げの検討材料（plan で必ず判断する）**: 同一の carve-out 概念を **rollout-policy.md の散文追加のみ**で導入した **TASK-0907 は Mode=critical**（実測: `docs/working/TASK-0907/plan.md` L26 / L38「Mode critical 維持」）。本 PBI は散文ではなく **auto-approve 可否を決める `arbitrate()` の分岐そのもの**を変更するため、リスクの性質は TASK-0907 と同等以上（誤実装は「escalate すべき自己改変が auto-approve される」= self-mod bypass に直結）。high-risk では **V-4（リリース前チェック）がスキップされる**点も踏まえ、plan では「なぜ TASK-0907 より軽いモードで足りるのか」を明示するか、**安全側で critical へ引き上げる**
- **暫定判定: high-risk**（C-2 複数観点 + Human C-3 同期。autonomous APPROVE 不可）。上記の比較を経て plan で最終確定する

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| carve-out 判定を `boundary_check()` に混ぜ込むと、既存の「HO 表からは clean」仕様（`test_docs_ai_ai_loop_excluded` / `test_clean_path`）を壊す | 既存 247 テストが大量に落ち、原因が「挙動を変えた」と誤読されて論点 A まで疑われる手戻り | `boundary_check()` は変更せず**別関数 + 新 priority 行**の additive 変更にする（AC-4 で固定） |
| carve-out 対象が広すぎて ai-loop の通常の改善作業まで全部 escalate になる | 機械強制が形骸化し override 運用に流れる | 対象は rollout-policy §2 の ①〜③ に**厳密に一致**させる。配布派生は含めない。plan で「正当な改善作業が escalate される頻度」を見積もる |
| `decision-table.md` と `arbiter.py` の priority が乖離する | 正本間ドリフト（#913 が是正した類の再生産） | AC-6。ただし文言レベルの機械照合は現状**未実装**（U-3） |
| `ho-paths.md` を AI が直接編集してしまう | HO 不可侵原則の違反。`test_ho_paths_md_itself` 相当の不変条件に抵触 | Human patch 分離（TASK-0872 / TASK-0913 前例）。または専用ファイル新設で回避 |
| `POLICY_REF` を改版し忘れる / 不要に改版する | policy バージョンと実挙動の不一致、または既存 `PolicyRefVersionTests` の破壊 | plan 段階で「carve-out 追加は policy の意味論変更か」を判定して決める（U-2 / U-7）|
| 配布派生を carve-out 対象外にしたまま、その安全性根拠である CI drift-check が **merge をブロックしない**（ruleset の必須チェックは `Markdown lint` のみ・実測） | 配布派生への独立改変が escalate されず main に混入する window が残る = carve-out の抜け道 | U-5 で 3 案比較。少なくとも「CI で検出されるが merge ブロックは未配線」と正確に記録し、必須チェック追加の follow-up 起票を判断する |

### Unknowns

- **U-1**: carve-out glob の正本を `ho-paths.md` へ §追加するか、**専用ファイルを新設**するか。→ plan の論点として 2 案比較する。**⚠️ 「案 A は既存パーサを流用できるので安い」という当初の見立ては実測で否定された（RV-M2）**: `parse_ho_paths_table()` は `for line in content.splitlines()` で**ファイル全文を走査**し、判定条件は「行が `|` 始まり」「セル数 ≥ 4」「第 1 セルがバッククォート付きパターン」「第 2 セルが非空」のみ（セクションを見ていない）。したがって `ho-paths.md` に同形式の carve-out 表を追記すると **`scripts/ai-loop/**` 等が HO パターンとして取り込まれ** `boundary_check()` が touches-HO を返し、In scope 4 / AC-4 が維持を明記している `test_clean_path` / `test_docs_ai_ai_loop_excluded` が破綻する。案 A を採るなら **`parse_ho_paths_table()` の section-scoped 化（+ その回帰テスト）が必然**で、これは「`boundary_check()` 本体を変更しない」という In scope 1 の安全設計とも衝突する。**案 A は案 B（専用ファイル）より安くない**
- ~~U-2~~ **解消済み（RV-m2 / 実測）**: `POLICY_REF` は **改版する（`@v4` → `@v5`）**。arbiter.py 自身が改版基準を明文化しており「escalate 条件を追加するだけの安全側変更」で `@v1`→`@v2` / `@v2`→`@v3` と改版した前例がある一方、「gate 挙動は変えない provenance 拡張」では非改版としている。carve-out は**新規 escalate 分岐の追加 = gate 挙動変更**なので改版が既定。残る作業は U-7（`PolicyRefVersionTests` の期待値更新）のみ
- **U-3**: `decision-table.md` ↔ `arbiter.py` の**文言レベル機械照合が現状ない**（実測: ho-paths.md には `test_ho_pattern_drift_against_source_of_truth` があるが、decision-table.md 相当の drift check は存在せず、担保は `DecisionTablePriorityTests` の**挙動テスト**と目視レビュー）。carve-out 行についてドリフト検査を新設するか、挙動テストのみで足りるとするか
- **U-4**: 新 priority 番号を何にするか（`1.1` / `1.05` / priority 1 への統合）。既存は `1.5 / 1.6 / 1.65 / 1.7 / 1.9 / 1.95` と 1.x 刻み
- **U-5**: **配布派生（`plugin/plangate/skills/ai-loop-cycle/**` 等）を carve-out glob に含めるか**。rollout-policy 最終文言は「含めない（CI drift-check で担保）」だが、①その CI が **merge ブロックの強制力を持たない**（ruleset の必須チェックは `Markdown lint` のみ・実測）②**TASK-0907 plan L13 は ① を「+ 配布版」と記述**しており表現が不一致。plan で (a) 配布派生も glob に含める / (b) 含めず `sync-plugin-plangate / drift-check` を ruleset の必須チェックへ追加する follow-up を起票する / (c) 現状維持 + リスク受容を明記 の 3 案を比較する
- **U-6**: carve-out 版の解決関数に **CLI 引数（`--carve-out-paths` 等）を持たせるか**。持たせる場合の追従先は **`docs/workflows/ai-loop/execution-runbook.md` と skills 配下**（= carve-out ③ 自身。配布同期あり）。**`bin/plangate` は arbiter を呼ばないため無関係**（実測: `grep -c arbiter bin/plangate` = **0**。同ファイルが参照するのは `c3prime_verify.py` のみ）。当初「`bin/plangate` が HO 該当なので Human patch が追加発生する」と見積もっていたが**前提が誤りだった — RV-m3**
- **U-7**: `POLICY_REF` の改版（U-2 で「する」と確定）に伴い、`PolicyRefVersionTests` が現在 `@v4` を期待値として持つため**同テストの更新が必須**
- **U-8**: carve-out 判定の**適用リポジトリスコープ**（plangate 本体の run 限定か、plugin 経由で導入先の run にも効かせるか）。rollout-policy の carve-out は「plangate 本体拡張の適用対象から除外」という文脈だが、arbiter は plugin 配布され CWD 基準で解決する。#906（導入先の domain-gate）との境界に関わるため plan で 1 行決める（RV-i1）

### Assumptions

- rollout-policy §2 の carve-out 定義（①〜③ + 配布派生の扱い）が**現行のまま**であること（main `b306b12` L52-58 で確認済み）
- `ho-paths.md` の HO 表フォーマット（pattern / 分類 / 理由 の 3 列・21 パターン）と `parse_ho_paths_table()` の対応が維持されること
- テスト baseline: `sh tests/run-tests.sh` = 430/0、`python3 scripts/ai-loop/test_arbiter.py` = 247 OK（いずれも main `b306b12` で実測済み）
- carve-out ③ の対象ディレクトリ `.agents/skills/ai-loop-cycle/` と `.claude/skills/ai-loop-cycle/` は**いずれも実在する**（2026-07-30 実測）
- #906 は本 PBI 実装後に「入力ソースを足す」形で着手される（本 PBI は #906 の実装を含まない）
