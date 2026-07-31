# PBI INPUT PACKAGE — TASK-0894

> Issue: [#894](https://github.com/s977043/plangate/issues/894)（P1 / enhancement / area:workflow / governance / area:eval / area:metrics）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)
> 作成: 2026-07-22（調査・worktree 現物裏取り済み。AC / Scope / fixture / DoD は issue verbatim）

## Context / Why

参照投稿（issue 記載の一次ソース）は、AI 活用の中心が単発 Prompt から
`Discover → Plan → Execute → Verify → Iterate` を外部状態・客観的検証・停止条件で制御する
Loop へ移ると整理している。PlanGate ai-loop vNext には #872（Plan-first / C-3' binding）・
issue #873（PR convergence / `MERGE_READY` 状態機械）・#874（RunEvidence）・#869（Evolution Loop）が
並ぶが、これらを横断する **共通の Loop 制御契約（Verifier 階層・停止予算・進捗判定・採用コスト
metrics）** はまだ定義されていない。各 Workflow が個別に停止条件・成功判定を持つと、同じ Run 内で
語彙・境界・fail-closed 方針がずれる。本 PBI は共通 `LoopControlContract` を定義する。

実測（2026-07-22・worktree 現物）:

- **Verifier 実体は 5 層に分散実装済みだが、層間順序と結果語彙の共通契約が無い**:
  1. LoopSpec 決定論検証（`docs/workflows/ai-loop/loopspec.md` 必須フィールド + I-4 安全側差し戻し）
  2. Plan Package + C-1/breakdown マーカー（`arbiter.py` priority 1.6/1.65/1.7 の `gates.c1 == "PASS"` / `plan_package` 整合）
  3. W チェック + rubric（LLM 判断 Model A/B/C/D。`arbiter.py` L16 が「L2 は決定論のみ・LLM 判断は W チェック」と分離を明記）
  4. arbiter 決定論裁定（`decision-table.md` priority 0〜6 + 1.5/1.6/1.65/1.7/1.9/1.95 の機械実装）
  5. terminal 3 値（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`・exit 0/2/3）+ `MERGE_READY`（DoD 状態・`00_concept.md` §2.3 で語彙区別済み）
- **issue が要求する 4 値 verifier status（`pass|fail|unavailable|inconclusive`）は不存在**:
  `rg "inconclusive|unavailable"` が `scripts/ai-loop/` および `docs/workflows/ai-loop/` で **0 件**
  （実測。`scripts/eval-runner.py:136` に verifier 語彙と無関係な文字列
  `codex_log_parser unavailable` が 1 件あるのみ）
- **停止予算は round 系のみ**: `cost_cap` は run 予算＝**round 数単位**（`arbiter.py` L713〜/L1008〜・priority 1.95・#840）。
  time / token / cost_usd / 連続失敗上限は不存在。`loopspec.md` **L125** が「cost cap フィールドは
  設けない — enforcement 不在の宣言フィールドを作らない（#749 で enforcement 設計と同時に検討する）」
  と明記しており、本 PBI はこの注記を解除する enforcement 側の位置づけ
- **no-progress detector は明示された follow-up**: `loopspec.md` **L281** が「独立した detector 化は
  follow-up 候補（効果測定後に判断）」と記載。fingerprint / oscillation は repo 全域 **0 件**
  （`rg -i "fingerprint|oscillation"` 2007 files 検索・実測）
- **採用コスト metrics は不存在**: `scripts/ai-loop/metrics.py` はレート系のみ
  （first-pass rate＝`first_pass` 導出 / `escalate_rate` / `human_intervention_rate` 等）。
  `cost` / `token` / `human_minutes` フィールドは **0 件**（実測）
- **最重要リスク＝正本断片化**: `loop-safety-gates.md` **§6**（L198「既存正本との不整合防止（再定義しない
  事項の一覧）」）と `stop-rollback.md` **§0**（「本書は既存正本の再定義ではない」）が、ラウンド上限 3 /
  CB-1〜3 / escalate 予算等の**数値再定義を禁止**している。本契約が数値を再宣言すると 3 つ目の正本を
  作って断片化する → 「数値は既存正本への参照固定・enum / reason code は additive 正規化層」を
  設計原則にする（下記 C-3 論点 1）

## What（Scope）

### In scope（issue Scope verbatim・8 項目）

1. 共通の Loop decision enum / reason code / schema を定義する
2. Verifier 実行順序と blocking 規則を定義する
3. budget / stop / no-progress / repeated-failure / oscillation 判定を共通化する
4. #872 / #873 / #874 / #869 から利用する adapter 境界を定義する
5. terminal decision と全 Verifier 結果を RunEvidence へ渡す
6. risk / task profile 別の既定 budget を定義する
7. CLI / workflow が同じ reason code を返せるようにする
8. 既存の停止条件を棚卸しし、重複・矛盾・責務漏れを整理する

### Out of scope（issue Non-goals verbatim・7 項目）

- #873 の PR 状態機械を再実装すること
- #869 の candidate 生成・実験 policy を再実装すること
- model 自身の重み更新
- hidden CoT / raw session transcript の保存
- 全タスクへ同一 budget・同一 KPI を強制すること
- AI への merge 権限付与
- Human-owned policy / C-4 / first principles の自動変更

## 受入基準（issue #894 verbatim・14 項目）

- AC-1: Loop decision / termination reason / verifier result の schema が一意に定義されている
- AC-2: Worker の自己申告だけでは `success` にならない
- AC-3: deterministic failure を model reviewer の PASS で上書きできない
- AC-4: verifier unavailable / inconclusive 時に fail-open しない
- AC-5: stage ごとに iteration / time / token / cost / repair budget を設定できる
- AC-6: `no_progress` を evidence delta と blocker 差分で判定できる
- AC-7: 同一失敗を fingerprint で検出し、指定回数で停止できる
- AC-8: oscillation 検知時に同一修正戦略を継続せず replan または Human escalation になる
- AC-9: terminal decision が artifact hash / source SHA / head SHA へ束縛される
- AC-10: #873 の `MERGE_READY` 条件と矛盾せず、共通 decision へ変換できる
- AC-11: #874 の RunEvidence へ budgets / verifier results / termination / metrics を保存できる
- AC-12: active run 中に policy / budget / harness version が暗黙変更されない
- AC-13: task profile 別の既定値と override policy がある
- AC-14: auto-merge / Human-owned C-4 境界を変更しない

### 必須 fixture（issue verbatim・12 件）

1. deterministic PASS + spec PASS + reviewer PASS → success
2. tests FAIL + reviewer PASS → continue または blocked、success 不可
3. reviewer unavailable → human_escalated または blocked
4. max iteration 到達 → budget_exhausted
5. artifact 未変更・同一 failure 反復 → repeated_failure
6. finding 数・evidence に変化なし → no_progress
7. resolved finding 再出現 → oscillation / replan
8. source SHA 変更 → stale verifier result 無効化
9. low-risk task profile 正常系
10. high-risk path で Human-owned policy gate 発火
11. accepted change の cost / human minutes 集計
12. RunEvidence 再生成時に同じ terminal decision となる

### DoD / Close 条件（issue verbatim 要点）

既存 workflow の停止条件棚卸し + gap 分析文書化 / schema・validator・decision engine 相当の機械検証が
main へ merge / #872・#873・#874 の最低 1 経路ずつの共通契約消費統合 test / 12 fixture CI PASS /
representative TASK での continue → repair → verify → terminal decision E2E evidence /
no-progress・repeated-failure・budget-exhausted の停止理由が RunEvidence に残る /
cost per accepted change を 1 件以上の実 Run または再現 fixture で算出 /
EPIC #870 DoD へ PR・test・E2E evidence link 反映。
**設計文書のみ、stage 固有の ad-hoc 判定のみ、Worker の完了宣言のみでは close しない**。

## Notes from Refinement（調査で確定した設計方針と C-3 論点）

### 設計方針

- **数値は既存正本への参照固定・enum は additive 正規化層**: `loop-safety-gates.md` §6 /
  `stop-rollback.md` §0 の「再定義しない」契約を継承する。本契約は
  (1) ラウンド上限 3・CB-1〜3・escalate 予算等の**数値を再宣言しない**（`round_limit_ref` 型の
  参照フィールドを踏襲）、(2) decision enum / reason code / verifier status の**語彙正規化**と
  **層間順序**（決定論 → 仕様 → 独立 reviewer → policy → loop decision）のみを新規定義する
- **loopspec L125 注記の正式解除**: 「cost cap フィールドは設けない（#749 で enforcement 同時実装）」
  の条件を本 PBI が enforcement 側で満たす。time / token / cost_usd / 連続失敗の各予算は
  enforcement と宣言フィールドを**同一 PR 内で対にする**（宣言だけ先行させない＝同注記の原則維持）
- **loopspec L281 follow-up の履行**: no-progress detector を「同型指摘の再発 → Optimize 送り +
  ラウンド上限 3」の現行実体から独立 detector（evidence delta + blocker 差分 + fingerprint）へ昇格
- **4 値 status は既存 3 値裁定と別レイヤ**: verifier result の `pass|fail|unavailable|inconclusive` は
  **verifier 単位**の語彙、`AUTO_APPROVED|HUMAN_ESCALATED|BLOCKED` は **run 裁定（terminal）**の語彙、
  issue の decision 8 値（continue / success / blocked / human_escalated / budget_exhausted /
  no_progress / repeated_failure / policy_denied）は **loop decision** の語彙。3 者の変換表を契約に含め、
  `unavailable` / `inconclusive` は fail-open 禁止（AC-4）で `review-principles.md` §7-ter
  （実行不可の明示記録）と整合させる
- **決定論パターン先例の転写**: `plan_package.py`（決定論・fail-closed・冪等）/ `c3prime_verify.py`
  （exit code 契約）/ `metrics.py`（fail-silent 禁止の明示区分）/ `arbiter.py` priority 1.95
  （cost_cap 境界値=通過・超過のみ escalate）を踏襲
- **metrics 拡張は additive**: `metrics.py` に `cost_usd` / `tokens` / `human_minutes` /
  `accepted_change` を追加する際、既存レート系集計（first-pass rate＝`first_pass` 導出 /
  `escalate_rate` 等）と record 世代区分を壊さない（additive フィールド + 欠落時は集計分母から明示除外）

### C-3 論点一覧（人間判断が必要な事項）

1. **正本断片化の回避方針の承認**（最重要）: 上記「数値は参照・enum は additive 正規化層」で
   `loop-safety-gates.md` §6 / `stop-rollback.md` §0 と矛盾しない設計とするか。
   数値を本契約へ集約し直す（既存正本の版上げを伴う大工事）代替案は非推奨
2. **2 分割の採否**: 推奨は
   (a) **契約 doc + enum / reason code / 変換表を #873 実装前に先行確定**
   （#873 は `MERGE_READY` → 共通 decision の変換表のみを consume する。AC-10 の依存を先に解く）、
   (b) **decision engine + fingerprint / no-progress detector + metrics 拡張は #874 と並行**。
   選択肢: (a)(b) を別 PBI に分割するか、本 PBI 内の PR 分割（PR-1=契約 / PR-2=engine）に留めるか
3. **schema 配置の HO 分岐**: `schemas/**` は HO（`docs/ai/ai-loop/ho-paths.md` L28「AI 直接編集不可」）。
   `schemas/` なら HO patch（Human 適用）+ Hardening Override 発火、`docs/schemas/`（非 HO・前例
   `child-pbi.yaml`）なら AI 完結 + 機械検証は非 HO validator。**#874 の C-3 決定と同一の配置に揃える**
4. **terminal 3 値 vs decision 8 値の関係確定**: `MERGE_READY`（DoD 状態）を decision enum に
   含めるか、変換表の右辺（#873 側の状態）に留めるか。#874 の `terminal_state`
   （`MERGE_READY|HUMAN_ESCALATED|BLOCKED`）との語彙合わせを #874 実装前に先行確定する
5. **task profile の粒度**: risk class（既存 5 mode / LoopSpec risk）と task profile
   （探索的 / 定型修正）のどちらを既定 budget のキーにするか
6. **#869 adapter の検証非対称**: In scope 4（adapter 境界）は #869 を含むが、issue の
   AC 14 項目・fixture 12 件・DoD 統合テスト（#872/#873/#874 の最低 1 経路ずつ）には
   #869 検証が無い（issue 自体の非対称）。#869 adapter の検証を**追加 AC 化する**か、
   **#869 側 PBI へ後続分離する**か（issue 合意要・issue コメントでの提起を推奨）

> **✅ schema 配置論点の裁定（2026-07-31・Human。本ブロックは schema 配置のみに係る — 他の C-3 論点は未裁定のまま）**: **案 2 段階方式**を採用。Phase 1（shadow）は
> `docs/schemas/`（非 HO）で 4 PBI（#894/#874/#869/#908）同側に統一し、本番接続
> （promotion gate / Gate 接続）の C-3 で `schemas/` へ **1 回の HO patch で昇格**
> （前例 `3ec2e24`）。昇格判定は Gate 接続 PR の Human C-3 チェックリストで行う。
> 裁定の正本: [`docs/working/discussions/2026-07-31-schema-placement-ho-arbitration.md`](../discussions/2026-07-31-schema-placement-ho-arbitration.md) §7

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 正本断片化（§6 / §0 の再定義禁止契約と衝突） | 契約 doc に「参照固定フィールド一覧」を持たせ、CI で数値リテラルの再宣言を検出 | 数値を含む節を既存正本への参照のみに縮退 |
| #873 未実装のまま AC-10（`MERGE_READY` 変換）が検証不能 | 2 分割 (a) で変換表を先行確定し、#873 が consume する側に固定 | fixture で契約先行検証（実 delivery を待たない） |
| schema HO 分岐で承認境界の強度が割れる | C-3 論点 3 で #874 と同一配置に確定 | docs/schemas/ + 非 HO validator で AI 完結 |
| 4 値 status 導入が既存 3 値裁定（exit 0/2/3 契約）を壊す | 変換表 + `test_arbiter.py` 回帰で既存 exit code 不変を機械検証 | verifier status は新規レイヤのみに閉じ、arbiter 裁定語彙に触れない |
| budget 宣言フィールドだけ先行し enforcement が置き去り（L125 注記の再発） | 宣言 + enforcement + fixture を同一 PR で対にする | enforcement 未了の budget 軸は契約に載せない（additive に後追い） |
| fingerprint 正規化（timestamp / line number / request ID 除去）の偽陰性・偽陽性 | fixture 5（同一 failure 反復）+ 正規化 unit test | 初版は保守的（完全一致寄り）にし、正規化規則を additive に拡張 |

### Unknowns

- schema 配置先（`schemas/` HO vs `docs/schemas/` 非 HO）→ ~~C-3 で確定（#874 と同一決定に揃える）~~ → **✅ 裁定済み（2026-07-31）: 案 2 = `docs/schemas/`（非 HO）で確定**（上記裁定ブロック参照）
- 2 分割 (a)/(b) の PBI 分割 vs PR 分割 → **C-3 で確定**
- `MERGE_READY` を decision enum に含めるか変換表右辺に留めるか → **C-3 で確定（論点 4）**
- task profile 別既定 budget の初期値（実測データ不足。Run-001〜 の arbiter record から導出可能かは plan で確認）
- #868（model routing）未実装のため independent reviewer 選択の粒度は暫定・後日整合

### Assumptions

- 新設想定: 契約 doc（`docs/workflows/ai-loop/` 配下）+ schema（配置先 C-3）+ decision engine /
  validator（`scripts/ai-loop/`・非 HO）+ fingerprint / no-progress detector + `metrics.py` additive
  拡張 + 12 fixture + 既存停止条件の棚卸し文書
- `scripts/ai-loop/**` は PoC 隔離（本番から呼ばれない）で AI 実装可能（#874 と同前提）
- **Mode: critical で確定**（`mode-classification.md` 定量基準: **受入基準数 11+ → 超高（critical）が
  決定論的**。本 PBI は issue AC が **14 項目**で 11+ 確定。変更ファイル数も契約 doc + schema +
  engine + validator + detector + metrics 拡張 + 12 fixture + 棚卸し文書で 16+（超高）。
  「各軸の最大値を採用」で critical 確定）。加えて停止・escalate 契約は**承認境界周辺**
  （「承認境界周辺の変更 → 最低でも高」の趣旨に該当・安全側で該当扱い）。
  **autonomous APPROVE 不可・人間 C-3 必須・V-4 リリース前チェック要**。
  schema を `schemas/` に置く場合は **Hardening Override 発火**（lite_eligible 無効化・
  Standard 同期 C-3 強制）が追加で確定。2 分割 (a)（契約 doc + enum のみ）を独立 PBI に
  切り出す場合でも、AC は issue verbatim 14 項目を分割先へ按分するまで critical 判定を維持する
