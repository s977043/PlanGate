# PBI INPUT PACKAGE — TASK-0908

> Issue: [#908](https://github.com/s977043/plangate/issues/908)（feat / ai-loop / EPIC [#870](https://github.com/s977043/plangate/issues/870) 登録済み）
> 由来: #869（Harness Evolution Loop）派生。下流依存: #909 / #910 は本 PBI の Run Evaluation Result schema 確定待ち
> 作成: 2026-07-25（main 51489e1 基点。既存資産の実在をリポジトリ内 grep で裏取り済み）

## Context / Why

ai-loop には LoopSpec・Arbiter・rubric grader・metrics・Trust Ledger（provenance / decision record）が既に存在するが、1 Run について「最終成果（Outcome）」だけでなく「どの経路で到達したか（Trajectory）」を統合評価する契約がなく、評価結果が複数資産に分散している。#869 の外側 Harness Evolution Loop が改善候補の採用判断に使える「1 Run 単位の標準化された評価証拠」が存在しない。

本 PBI は全面新規導入ではなく、**既存正本の再利用**で 4 層（Outcome / Trajectory / Component / Operational）を 1 Run 単位で接続する。

実在確認済みの既存資産（2026-07-25・main 51489e1 実測）:

| 資産 | 実パス | 備考 |
|------|--------|------|
| LoopSpec 正本 | `docs/workflows/ai-loop/loopspec.md` | §3 必須フィールド（`allowed_paths` 等）・§6 provenance 整合注記 |
| LoopSpec 派生 | `scripts/ai-loop/plan_package.py`（`derive_loopspec()`） | Plan Package からの決定論的派生（#872） |
| Arbiter | `scripts/ai-loop/arbiter.py`（+ `test_arbiter.py`） | 裁定 record を `docs/working/ai-loop-runs/*.json` に発行 |
| rubric grader | `.claude/skills/ai-loop-cycle/SKILL.md` Step 5.5（rubric 5 項目） | review-principles §2 の docs-run 翻訳 |
| metrics | `scripts/ai-loop/metrics.py`（+ `test_metrics.py`） | decision record 集計。legacy / invalid run meta / skipped の明示分類 |
| Trust Ledger / provenance | `docs/workflows/ai-loop/decision-table.md` §5（provenance schema 正本。`gates` フィールド等） | `docs/ai/ai-loop/asset-inventory.md` に思想の継承記録 |
| terminal state 定義 | `docs/workflows/ai-loop/00_concept.md` §2.2（`PR_CREATED` / `MERGE_READY` / `MERGED`）・§2.3 裁定状態との語彙群区別 | shadow mode 不変対象 |
| 実行証跡 | `docs/working/ai-loop-runs/*.json`（裁定 record）/ `docs/working/TASK-XXXX/run.ndjson`（git 追跡済みの例: TASK-0872/0896。TASK-0873 分は 51489e1 時点で untracked） / `docs/working/_metrics/events.ndjson` | Trajectory Eval の入力源 |
| eval-runner / dogfooding | `docs/ai/eval-runner.md` / `docs/ai/dogfooding-eval.md` | Component Eval の既存対応先 |
| 実行手順正本 | `docs/workflows/ai-loop/execution-runbook.md` | issue 言及資産。required events の手順根拠 |
| rollout policy | `docs/workflows/ai-loop/rollout-policy.md` §2（判定基盤 carve-out） | 本 PBI の対象パスが該当（後述） |

> 注: issue 本文の「`docs/working/**/events.ndjson`」は、実体としては `docs/working/_metrics/events.ndjson`（gitignore 対象）と各 TASK の `run.ndjson` に分散している。gap analysis（下記 In scope 1）で対応表に正確な実パスを固定する。

## What（Scope）

### In scope

1. **Gap analysis**: 既存イベント・schema・metrics と 4 層 Eval の対応表を作成（上表の実パス基点）
2. **4 層の責務定義**: Outcome / Trajectory / Component / Operational の責務を定義し、LoopSpec を Eval Contract の正本として扱う（新規競合契約を作らない）
3. **Run Evaluation Result**: LoopSpec・実行証跡から派生する additive な独立 artifact として schema（または同等の機械可読 contract）を定義（`schema_version` / `run_id` / `loopspec_ref` / `outcome` / `trajectory` / `component` / `operational` / `rubric` / `evidence_refs` / `limitations` / `decision_ref`）
4. **Trajectory Eval v1（決定論評価）**:
   - required events / ordering: plan・LoopSpec 確定後の exec 開始 / exec 後の deterministic verification / PR 前の rubric grader 完了 / retry 後の再検証
   - violations / anomalies: approval 前編集・verification skipped・grader feedback 無視・`allowed_paths` 逸脱・HO 境界迂回・同一 tool call 過剰 retry・round limit 超過・terminal state 後の継続実行
   - operational signals: round 数・first-pass rate・tool call 数・token/time/cost・Human escalation 率・rollback/reversal
5. **Shadow result 生成**: Run Evaluation Result を生成するが Gate 判定には使わない（shadow mode）
6. **Dogfooding**: ai-loop docs-only Run で結果を蓄積し、代表 Run 10 件以上で false positive / false negative をレビュー
7. **plugin 配布版との同期方針**の定義（`sync-plugin-plangate.sh` 経由の派生関係を踏まえる）

### Out of scope（issue Non-goals 準拠）

- LLM Judge 単独で AUTO_APPROVED を決めること
- 新しい terminal state の追加（`00_concept.md` §2.2 の 3 state は不変）
- hidden CoT や生 Session 全文の保存
- 全 provider の session parser の一括実装
- production WF-00〜07 の即時変更
- policy / HO / C-4 / first principles の自動変更
- Gate 接続（hard gate 化）の実施 — 本 PBI は「Gate 接続判断」の材料（false positive 評価）までで、接続自体は後続判断（**pbi 側の明確化**: issue 実装段階 5 の「限定ルールの hard gate 候補化」は候補提示まで含むが、接続実施は本 PBI 外と解釈を固定）

## 受入基準（issue #908 AC）

- AC-1: Outcome / Trajectory / Component / Operational の責務が定義されている
- AC-2: LoopSpec が Eval Contract の正本であり、新規の競合契約を作っていない
- AC-3: Run Evaluation Result schema または同等の機械可読 contract が定義されている
- AC-4: 既存 eval-runner / metrics / rubric grader / events / decision record との対応表がある
- AC-5: required events と順序違反を fixture で検証できる
- AC-6: verification skipped・approval 前 edit・round limit 超過を検出できる
- AC-7: unknown / evidence 不足は fail-open せず `unknown` または escalation 候補として明示される
- AC-8: shadow mode では既存 terminal state・Arbiter 判定を変更しない
- AC-9: 代表 Run 10 件以上で false positive / false negative をレビューする
- AC-10: Trust Ledger または関連 record から評価結果を追跡できる
- AC-11: plugin 配布版との同期方針が定義されている

## Notes from Refinement

- **重要制約 1 — shadow mode**: 初期導入は shadow mode。既存 terminal state（`PR_CREATED` / `MERGE_READY` / `MERGED`）と Arbiter 判定ロジックを一切変更せず、hard gate 化しない。Run Evaluation Result は Gate 判定に使わない独立 artifact（AC-8 / Non-goals と一致）
- **重要制約 2 — 判定基盤 carve-out**: 本 PBI の主対象パス（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**` / `docs/ai/ai-loop/**`。carve-out 全体は `.agents`/`.claude` の `skills/ai-loop-cycle/**` を含む 4 glob 系統）は `rollout-policy.md` §2 の**判定基盤 carve-out（escalate 固定・glob）に該当**する。本 PBI を ai-loop-workflow で回す場合、arbiter 機械層では boundary=clean と判定されうるが（carve-out は規範層）、**auto-approve 不可・escalate（Human C-3'/C-3）が必須**
- **重要制約 3 — LLM Judge は soft signal 補助のみ**: LLM grader は Verifier の補助（soft signal）に限定し、Gate の hard decision は既存の決定論ロジック（arbiter / DoD 判定）を維持する
- **Mode 判定**（`.claude/rules/mode-classification.md` 定量基準による機械判定）:
  - 受入基準数: **11 → critical（11+ 帯）**
  - 変更ファイル数（見込み）: schema/contract 新設 + trajectory rules + fixture + 対応表 + 同期方針で 6-15 → high-risk
  - 定性: shadow mode の additive 追加でシステム挙動不変だが、影響対象が ai-loop 判定基盤（carve-out 領域）
  - HO 判定: `scripts/ai-loop/` / `docs/workflows/ai-loop/` / `docs/ai/ai-loop/` は HO 9 カテゴリ非該当。ただし schema を `schemas/*.schema.json` に置く設計を採る場合は **HO 該当**（判定不能軸は安全側 = 該当扱い）
  - **最終判定: critical**（定量最大値 = AC 11+。plan 段階で実装段階分割により AC を分けても、安全側で critical 起点とし、分割後の子スライスで再判定する）
  - 帰結: `lite_eligible=false`・人間 C-3 必須（autonomous APPROVE 不可）・V-4 まで実施
- **schema 配置は plan 段階の設計判断**: `schemas/` 直下（HO・JSON Schema 検証に乗る）か `docs/workflows/ai-loop/` 配下の contract 文書（carve-out 内・非 HO）かで承認境界の扱いが変わる。安全側は後者から開始し、Gate 接続判断の段階で `schemas/` 昇格を検討
- **下流依存**: #909 / #910 は本 PBI の Run Evaluation Result schema 確定待ち。schema フィールド（特に `trajectory` / `operational` の内訳）は下流が参照する contract になるため、`schema_version: 1` の互換方針を明記する
- **実装段階（issue 準拠・plan の Work Breakdown 骨子）**: (1) Gap analysis → (2) Shadow result → (3) Trajectory rules v1 → (4) Dogfooding → (5) Gate 接続判断（判断材料の提出まで。接続自体は out of scope）

> **✅ schema 配置論点の裁定（2026-07-31・Human。本ブロックは schema 配置のみに係る — 他の C-3 論点は未裁定のまま）**: **案 2 段階方式**を採用。Phase 1（shadow）は
> `docs/schemas/`（非 HO）で 4 PBI（#894/#874/#869/#908）同側に統一し、本番接続
> （promotion gate / Gate 接続）の C-3 で `schemas/` へ **1 回の HO patch で昇格**
> （前例 `3ec2e24`）。昇格判定は Gate 接続 PR の Human C-3 チェックリストで行う。
> 裁定の正本: [`docs/working/discussions/2026-07-31-schema-placement-ho-arbitration.md`](../discussions/2026-07-31-schema-placement-ho-arbitration.md) §7

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 実行証跡の分散（`ai-loop-runs/*.json` / `run.ndjson` / `_metrics/events.ndjson`）により Trajectory の required events が欠測し、violation 誤検出（false positive）が多発 | 代表 Run 10 件レビュー（AC-9）で FP/FN 率を実測 | 欠測は AC-7 に従い `unknown` 明示・rule を shadow のまま据え置き |
| `_metrics/events.ndjson` が gitignore 対象のため、評価の再現性（他環境での再実行）が担保できない | gap analysis で入力源ごとの永続性を分類 | 永続証跡（`ai-loop-runs/*.json` / `run.ndjson`）のみを v1 の必須入力とする |
| carve-out 領域の変更のため ai-loop dogfooding 自体が escalate 固定 → Human 裁定コストが回転率を律速 | dogfooding 段階を docs-only Run に限定 | Human C-3' バッチ裁定で吸収 |

### Unknowns

- Run Evaluation Result の配置先（`schemas/*.schema.json` = HO か、ai-loop 配下 contract 文書か）→ ~~plan で確定（安全側 = HO 該当想定で見積もる）~~ → **✅ 裁定済み（2026-07-31）: 案 2 = `docs/schemas/`（非 HO）で確定**（上記裁定ブロック参照）。**見積もりも非 HO 前提へ更新してよい**
- 「approval 前編集」「grader feedback 無視」を既存証跡のどのイベントから決定論的に導出できるか（session ログ非保存の制約下で）→ gap analysis で対応表化し、導出不能項目は `unknown` に落とす
- rubric grader（SKILL.md Step 5.5）の出力が機械可読形式で証跡化されているか → 実 Run record の実測で確認

### Assumptions

- 既存資産（上表 10 系統）が main 51489e1 で安定していること（実在は grep 裏取り済み）
- #909 / #910 は本 PBI の schema 確定後に着手する（本 PBI 内で先行実装しない）
- metrics.py の `run` メタ（run_id / round_index / task_id）刻印（#812/#815）が今後の Run で継続的に付与されること（legacy record は AC-9 の母数から除外可）
