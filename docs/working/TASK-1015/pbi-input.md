# PBI INPUT PACKAGE — TASK-1015

> Issue: [#1015](https://github.com/s977043/plangate/issues/1015)「How / What / Why / Why not の知識配置契約を Plan・実装・検証・記録へ導入する」
> スコープ: **本 PBI は issue 本文「実装フェーズ」の Phase 0（現行棚卸しと ADR）のみ**を対象とする。Phase 1〜4 は後続スライスとして In scope 外（順序依存を明記）
> 作成: 2026-08-05（**作成時点 main = `a2a02b9e66d5ba928fd06374a158c9b37cdd4250`（`a2a02b9`）で実測**。裏取り結果は下表）
> 関連: [#867](https://github.com/s977043/plangate/issues/867)（継続的リファクタリング = Knowledge Delta）/ [#981](https://github.com/s977043/plangate/issues/981)（Plan Contract）/ [#874](https://github.com/s977043/plangate/issues/874)（RunEvidence 契約）/ [#980](https://github.com/s977043/plangate/issues/980)（Agent Identity）/ [river-review#1783](https://github.com/s977043/river-review/issues/1783)（独立レビュー側）

## Context / Why

issue #1015 は次の基本原則を PlanGate の計画・承認・実行・検証契約へ導入する。

> コードは **How** を説明できる構造にする。
> テストは **What** を実装から独立して固定する。
> コミットや Plan には **Why** を残す。
> コメントや ADR には、将来再検討されそうな **Why not** を残す。

これは記述スタイルではなく、Planner と Executor・Builder と Reviewer・現在の実装者と将来の保守者が異なる状況で発生する **5 つの情報損失パターン**を防ぐための知識配置・継承契約である（issue 本文より）。

| # | 情報損失パターン | 本 PBI での位置づけ |
|---|---|---|
| L-1 | コードを読んでも責務・境界・実現方法が理解できない | How の配置先（コード構造・命名・型）を契約化 |
| L-2 | テストが内部実装へ密結合し、リファクタリング時に仕様と実装を区別できない | What の配置先（test-cases / tests）を契約化 |
| L-3 | なぜ変更したかが会話や一時的なセッションにしか残らない | Why の永続化先（Issue / pbi-input / plan / commit）を契約化 |
| L-4 | 自然に見える代替案を過去に却下した理由が失われ、AI や後続開発者が同じ失敗へ戻す | Why not の配置先（ADR / Decision Record / 局所コメント）を契約化 |
| L-5 | 同じ説明を複数成果物へ重複記載し、更新漏れ・矛盾・stale 化を起こす | 正本と派生物の分離・重複検出を契約化 |

**ただし本 PBI は新しい巨大な文書体系を追加しない**。issue の Design Precondition 7（既存 SSoT と後方互換性を優先）に従い、既存 artifact へ additive に導入する。Phase 0 の役割は「**現行がどこまで担っているかを実測で確定し、契約の正本配置と適用判定を ADR で決める**」ことに限定される。

---

## 裏取り結果 1: 既存 artifact 棚卸し（作成時点 main = `a2a02b9`・すべて実ファイルで確認）

issue Phase 0 チェックボックス 1 に対応。テンプレート正本は `docs/working/templates/`、artifact 規約の正本は [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md)。

| artifact | テンプレート正本 | 規約の正本 | 主要セクション（実測・行番号） |
|---|---|---|---|
| `pbi-input.md` | `docs/working/templates/pbi-input.md` | `working-context.md:169-177`（`### pbi-input.md（PBI INPUT PACKAGE）`） | `## Context / Why`(:5) / `## What（Scope）`(:9) / `## 受入基準`(:19) / `## Notes from Refinement`(:24) / `## Estimation Evidence`(:29) |
| `plan.md` | `docs/working/templates/plan.md` | `working-context.md:179-191`（`### plan.md（EXECUTION PLAN）`） | front matter `related_issue`(:7) / `## Goal`(:16) / `## Context`(:20) / `## Scope`(:29) / `## Global Constraints`(:41) / `## 前提の実測検証`(:48) / `## Questions / Unknowns`(:58) / `## Approach Comparison`(:62) / `### Recommended Approach`(:69) / **`## Files / Interfaces`(:73)** / `## Work Breakdown`(:80) / `## Verification Plan`(:157) / `## Plan Review Readiness`(:178) / `## Replan Triggers`(:210) / `## Stop Condition`(:227) / `## Human Approval Boundary`(:241) / `## C-1 Self Review Checklist`(:251)。**【発見事項・本 PBI では是正しない】`:73` の見出し `## Files / Interfaces` は ai-loop の抽出器が探す `Files / Components to Touch` と部分一致しないため、現行テンプレから素直に生成した plan は `derive_loopspec()` で fail-closed する（実測: `extract_allowed_paths()` = `[]`）。#981 の plan は `## Files / Components to Touch` を採っており、テンプレ正本と乖離している** |
| `test-cases.md` | **テンプレート不在**（`docs/working/templates/` に実体なし） | `working-context.md:204-210`（`### test-cases.md（テストケース定義）`） | 規約が要求する要素: 受入基準 → テストケースマッピング / テストケース一覧（前提条件・入力・期待出力・種別）/ エッジケース |
| `todo.md` | **テンプレート不在**（同上） | `working-context.md:193-202`（`### todo.md（EXECUTION TODO）`） | 規約が要求する要素: Agent タスク 4 フェーズ / Human タスク / 依存関係 / Owner + 🚩 / `rollback:` |
| `handoff.md` | `docs/working/templates/handoff.md` | `working-context.md:107-124`（`### handoff（WF-05 完了資産 / Rule 5）`） | `## 1. 要件適合確認結果`(:27) / `## 2. 既知課題一覧`(:39) / `## 3. V2 候補`(:50) / **`## 4. 妥協点`(:59)** / `## 5. 引き継ぎ文書`(:68) / `## 6. テスト結果サマリ`(:87) / `## 7. Metrics summary`(:97) |
| `decision-log.jsonl` | `docs/working/templates/decision-log-schema.md` | 同左（スキーマ正本） | 必須: `ts` / `phase` / `task` / `type` / `decision`(:19) / **`reason`(:20)** / `alternatives`(:21) / `chosen_by`(:23)。任意: **`alternatives_rejected`(:22)** = `[{option, rationale}]`。必須条件は **`phase=brainstorm` での採用案決定時**を前提に「mode が high-risk / critical、または human decision の場合」(:44)＝**`phase=brainstorm` 限定の条件付き必須**であり、全 phase の必須ではない |
| `design.md` | `docs/working/templates/design.md` | WF-03 の任意 artifact | `## 1. モジュール構成（境界と責務）`(:16) / `## 2. データフロー`(:49) / `## 3. 状態管理方針`(:63) / `## 4. 失敗時の扱い`(:72) / `## 5. テスト観点`(:85) / `## 6. 依存ライブラリ制約`(:98) / `## 7. 技術的妥協点`(:109) |
| `review-self.md`（C-1） | `docs/working/templates/review-self.md` | `working-context.md:212-219`（`### review-self.md（セルフレビュー結果）`） | Plan 7 + AEE 2(:23-88) / Superpowers 2(:90-108) / ToDo 6(:110-152) / TestCases 3(:154-175) / B-1B2 2(:177-191) / SEC・SCOPE-DISC・UI(:193-212) |
| `review-external.md`（C-2） | `docs/working/templates/review-external.md` | `working-context.md:221-241`（`### review-external.md（外部AIレビュー結果 / 指摘の追記専用集約）`） | `## 外部レビュー実行可否（必須）`(:17) / 観点別セクション(:40-72) / `## Plan Alignment / Evidence Alignment / Production Readiness`(:74) |
| **Trust Ledger 相当** | なし（単一台帳ファイルは存在しない） | [`docs/workflows/ai-loop/agentic-six-stage-loop.md`](../../workflows/ai-loop/agentic-six-stage-loop.md) | `## 3. Trust Ledger 索引`(:65)。decision record JSON / 摩擦台帳 / review-feedback-loop / CB-1 事後 reject の **4 系列を束ねる上位概念**であり(:76)、成熟度は「△（単一正本への完全統合は未了）」と自己申告(:50) |
| RunEvidence | `docs/schemas/run-evidence.schema.json` | #874（OPEN） | required: `run_id` / `task_id` / `source_sha` / `final_head_sha` / `plan_hash` / `c3_prime_decision_ref` / `ci_outcomes` / `review_findings` / `repair_rounds` / `replan_count` 他(:7-22) |
| TDD evidence ledger | `docs/working/templates/evidence-tdd-ledger.json` | — | `evidence[]` の各要素に `command` / `exitCode` / `outputExcerpt` / `filePath` / `conclusion`。`phase` は `tdd_red` / `tdd_green` / `refactor_verify` の 3 値 |
| **ADR** | **フォーマット規約文書は不在** | 慣行のみ | 実在は `docs/decisions/adr-001-approve-out-of-band.md` の **1 件のみ**。節構成: `## Context`(:10) / `## Problem Statement`(:23) / `## Decision Drivers`(:32) / **`## Considered Options`(:39、Option A-D)** / `## Decision`(:106) / `## Consequences`(:118) / `## Related`(:128)。**採番規約・命名規約は同ファイル内に記載なし**（`採番` / `naming` の grep ヒット 0）。`docs/decisions/README.md` も不在 |
| **commit 規約** | — | `CONTRIBUTING.md:62-75` | Conventional Commits。**プレフィックス表（`feat:` / `fix:` / `docs:` / `chore:` / `refactor:` / `test:`）と例のみ**。**body に Why を書くことを要求する記述はない** |

---

## 裏取り結果 2: Knowledge Placement Contract 8 行 × 現行充足度

issue Phase 0 チェックボックス 2 に対応。判定は **既存で満たす / 一部満たす / 未対応** の 3 値。根拠はファイル:行。**推測で「実装済み」と書いていない**。

| # | Knowledge（issue の表） | issue が挙げる主な正本 | 判定 | 現行の担い手（根拠ファイル:行） |
|---|---|---|---|---|
| K-1 | Problem / Why now | Issue / `pbi-input.md` | **既存で満たす** | `docs/working/templates/pbi-input.md:5`（`## Context / Why`）/ `docs/working/templates/plan.md:20`（`## Context`）+ `:23`（「関連Issue: {URL}」）/ front matter `related_issue`（`plan.md:7`）。**記述面は充足。機械検査は未対応**（裏取り 3 の D1） |
| K-2 | Chosen approach / Why this | `plan.md` / Decision Record | **既存で満たす** | `docs/working/templates/plan.md:62`（`## Approach Comparison` = 案・メリット・デメリット・**採用/不採用**の表）+ `:69`（`### Recommended Approach` =「採用案と理由。既存設計との整合性、実装コスト、保守性、テスト容易性を含める」）/ `docs/working/templates/decision-log-schema.md:19-20`（`decision` / `reason` が **必須**フィールド） |
| K-3 | Observable behavior / What | `test-cases.md` / tests | **一部満たす** | 規約は `.claude/rules/working-context.md:204-210`（`### test-cases.md（テストケース定義）`: 受入基準 → TC マッピング / 前提条件・入力・期待出力・種別 / エッジケース）。AC↔TC の構造は `schemas/acceptance-result.schema.json` の `acItem.linkedTestCases` / `tcResult.tcId` にある。**不足**: (a) `test-cases.md` の**テンプレート実体が存在しない**、(b) 「実装詳細ではなく観測可能な振る舞いを固定する」という**観点そのものが既存 artifact のどこにも明文化されていない**（`private method` / `Characterization` の grep は working-context / templates 配下で 0 件） |
| K-4 | Implementation / How | code structure / names / types | **一部満たす** | 最も近いのは `docs/working/templates/design.md:16`（`## 1. モジュール構成（境界と責務）`）だが、**design.md は WF-03 の任意 artifact であり必須 artifact 集合に含まれない**（`bin/plangate:986` が既定で存在検査するのは `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` の 5 点。加えて `hybrid-architecture.md` Rule 5 が `handoff.md` を全 PBI 必須とする。design.md はいずれにも入っていない）。「How はコード構造・命名・型・不変条件から読み取れること」を要求する契約は**既存 artifact に不在**。レビュー観点としては `.claude/rules/review-principles.md:15`（`1. **可読性(Readability)**` = 命名の適切さ・構造の明確さ）/ `:16`（`2. **拡張性(Extensibility)**` = アーキテクチャ境界・依存方向・責務分離）が近いが、**配置契約ではなく評価軸** |
| K-5 | Rejected alternatives / Why not | ADR / Decision Record | **既存で満たす** | **現行で最も充実している領域**。(a) `docs/working/templates/decision-log-schema.md:22` の `alternatives_rejected` = `[{"option","rationale"}]`、**`:44` で「`phase=brainstorm` での採用案決定時で、mode が high-risk / critical、または human decision の場合」に必須**（`phase=brainstorm` が前提条件。standard 以下は任意 = 儀式化回避の既存判断）/ (b) `docs/working/templates/handoff.md:59`（`## 4. 妥協点` =「選択した実装 / 諦めた代替案 / 理由」の表、`:63-66`）/ (c) `docs/working/templates/plan.md:62` の「採用 / 不採用」列 / (d) `docs/decisions/adr-001-approve-out-of-band.md:39`（`## Considered Options` Option A-D）+ `:106`（`## Decision`）。**不足**: issue が求める「**再検討条件**（将来どうなったら再考するか）」の欄がどこにもない |
| K-6 | Change-unit intent / Why this commit | commit message | **一部満たす** | `CONTRIBUTING.md:62-75` は Conventional Commits の**プレフィックス表と 1 行例のみ**で、body に Why を書く要求はない。issue が避けよと言う「`fix` / `update` だけで終える」を**現行規約は防いでいない**。ただし PlanGate の実運用は squash merge 前提のため、issue Design Precondition 2（重要な Why を commit だけに依存しない）と整合させる方が安全側 |
| K-7 | Local constraint / Why here | code comment | **未対応** | **コードコメントに関する規約が repo 内に存在しない**（`.claude/rules/` **6 ファイル**（`hybrid-architecture.md` / `mode-classification.md` / `orchestrator-mode.md` / `responsibility-classes.md` / `review-principles.md` / `working-context.md`）・`CONTRIBUTING.md`・`docs/working/templates/` を確認。コメント記述規約の記載なし）。`TODO` / `workaround` / `temporary` の撤去条件を要求・検査する仕組みも不在（裏取り 3 の D4） |
| K-8 | Verification evidence | test result / RunEvidence / review artifact | **既存で満たす** | `docs/schemas/run-evidence.schema.json:7-29`（`"required": [` 〜 `],` の全 21 キー）（required に `plan_hash` / `source_sha` / `final_head_sha` / `ci_outcomes` / `review_findings`）/ `docs/working/templates/evidence-tdd-ledger.json`（`command` / `exitCode` / `outputExcerpt` / `conclusion`）/ `schemas/acceptance-result.schema.json`（`evidenceLog` / FAIL 時 `failReason` 必須）/ `docs/working/templates/plan.md:157`（`## Verification Plan` に「Evidence保存先」列）+ `:167`（検証不能時は理由と代替確認方法を明記 = #578）/ hook EH-5 `scripts/hooks/check-verification-evidence.sh:76-83`（evidence ファイル存在検査）。issue が避けよと言う「『テスト済み』という自己申告のみ」は**既に構造的に防がれている** |

### 8 行の集計

| 判定 | 件数 | Knowledge |
|---|---|---|
| 既存で満たす | **4** | K-1 Problem/Why now / K-2 Chosen approach / **K-5 Why not（ただし「再検討条件」列の追加は Phase 1 候補として保持）** / K-8 Verification evidence |
| 一部満たす | **3** | K-3 Observable behavior（テンプレ不在 + 観点未明文）/ K-4 Implementation/How（design.md が任意 artifact）/ K-6 commit Why（形式のみ・Why 要求なし） |
| 未対応 | **1** | K-7 Local constraint / Why here（コメント規約が repo に存在しない） |

> **したがって Phase 1 以降の追加対象は K-3・K-4・K-6・K-7 の 4 点に集中する**（K-5 は例外的に**既存表への「再検討条件」列追加のみ**を候補として保持する = 新規セクションではない）。K-1・K-2・K-5・K-8 は**既存セクションを正本として指し示すだけ**とし、新規セクションを作らない（issue Design Precondition 7「同じ意味の新規ファイルを安易に増やさない」/ 情報損失パターン L-5 の自己適用）。
>
> **K-5 を「新規に契約を作る」と扱わない理由**: `alternatives_rejected` が既に `{option, rationale}` の構造化フィールドとして存在し、しかも **high-risk / critical / human decision では必須**という適用判定まで済んでいる（`decision-log-schema.md:44`）。ここに Plan の `## Alternatives / Why not` を新設すると、同一情報が plan / decision-log / handoff の 3 箇所に並ぶ = **L-5 を本 PBI 自身が誘発する**。issue の「Plan artifact への追加候補」ブロックは**既存セクションとの重複を確認したうえで、必要最小限を導入する**と自ら但し書きしており、この確認結果が本表である。

---

## 裏取り結果 3: Deterministic checks 6 項目の実現可能性

issue「Validation / Gate 方針 → Deterministic checks」の 6 項目について、現行実装で既にできるものと新規に要るものを実測した。

| ID | issue の checks 項目 | 判定 | 現行実装（根拠ファイル:行）と不足点 |
|---|---|---|---|
| D1 | Plan から Issue / source を参照できる | **一部満たす** | テンプレに欄はある（`docs/working/templates/plan.md:7` `related_issue`）が**検査は皆無**。`bin/plangate validate`（`bin/plangate:914-1046`）が見るのは ①必須 artifact の**ファイル存在のみ**（`:971-984`、`plangate_check_file`=`bin/plangate:73` は存在確認だけ）②`approvals/c3.json` の C-3 ③`plan_hash` 突合（`:1018-1034`）の 3 点。さらに `schemas/plan.schema.json:7` の required は `task_id` / `artifact_type` / `schema_version` のみで、**`:38` が `additionalProperties: false`** のため `related_issue` は schema 上の**禁止フィールド**。ただし**これは実効的な禁止ではない**: `.md` の front matter を schema に掛ける経路自体が存在しない（`scripts/schema_mapping.py:20-45` のキーはすべて `*.json`）ため、テンプレ `plan.md:7` が既に `related_issue` を持っていても**誰も落とさない = schema と template が既に不整合のまま放置されている**。したがって **Phase 2 の D1 の本体は「schema 修正（HO 接触）」ではなく「front matter 検証経路の新設」**であり、HO 接触の見積もりが変わりうる（plan で明示すること）。PR 側には `scripts/check-pr-issue-link.sh:75`（closing keyword 検出）があるが `:16` で「Exit code: 常に 0」= **非ブロッキング** |
| D2 | test-cases と tests / verification command の対応がある | **一部満たす** | 存在検査のみ: `scripts/hooks/check-test-cases.sh:51-69`（EH-4、既定 warning / `PLANGATE_HOOK_STRICT=1` で exit 1）、`scripts/hooks/check-verification-evidence.sh:76-83`（EH-5、ファイル名パターン一致）。**データ形は既にある**（`schemas/acceptance-result.schema.json` の `linkedTestCases` / `tcId` / `evidenceLog`、`docs/working/templates/evidence-tdd-ledger.json` の `command` / `exitCode`）。**不足は「`test-cases.md` をパースして acceptance-result / 実テストと突合する実装」**。現状の突合は `.claude/agents/acceptance-tester.md`（LLM）任せ |
| D3 | ADR 必須と分類された変更で ADR 参照がある | **未対応** | `grep -rn "ADR\|adr-" bin/plangate scripts/hooks .github/workflows schemas workflows` → **ヒット 0**。`grep -rn "docs/decisions" bin scripts .github workflows schemas` → **ヒット 0**。mode 定義 `workflows/*.yaml` にも ADR 要求なし。**分類・要求・参照検査のすべてが新規** |
| D4 | `TODO` / `workaround` / `temporary` に issue・期限・撤去条件がある | **未対応** | **検査器が存在しない**（`scripts/` / `scripts/hooks/` / `.github/workflows/` に `TODO` / `FIXME` / `workaround` / `temporary` を検査するコードは該当なし）。既存の `TODO` 出現は 2 種類に分かれ、**いずれも検査側ではない**: (a) **テンプレ雛形に `TODO` を埋める側** = `scripts/ai-dev-prepare-cloud.sh:73-78` / `scripts/ai-dev-common.sh:181-274` / `scripts/release-prep.sh:73`（「手動確認 TODO（機械化対象外）」と明記）、(b) **実コード中の恒久 TODO コメントそのもの** = `scripts/check-codex-plugin-status.sh:10-11`（公式 status API 提供時に移行する旨。**issue 参照も撤去条件の期限も付いていない = D4 が検出対象とすべき実例が repo 内に既に存在する**）。**完全新規** |
| D5 | artifact 間リンク切れがない | **一部満たす（既存資産あり・CI 未配線）** | `scripts/check-stale-skill-refs.py` が outbound の stale パス参照を静的検出するが、**同ファイル `:18-21` が「doctor / L-0 / CI への配線は Hardening Override 対象（`bin/plangate`, `.github/workflows/`）に触れるため別 PBI の follow-up とする」と自認**しており未配線。inbound 側の `.claude/skills/ref-integrity-scan/SKILL.md` は**スクリプトではなく grep 手順書**。**markdownlint はリンク切れを検査しない**（`.markdownlint-cli2.jsonc` は MD013 / MD024 / MD060 の 3 設定のみ。MD051/052/053 は同一文書内アンカーと参照定義の解決であってファイル実在検査ではない）。CI の markdownlint 対象 glob（`.github/workflows/ci.yml:54-64`）は 10 パターンで、**`docs/working/**` は対象外**。リンクチェッカー（lychee / markdown-link-check 等）は repo 内に存在しない |
| D6 | commit / PR / evidence から task ID を追跡できる | **一部満たす（ai-loop 経路は強い）** | RunEvidence が `task_id` + `source_sha` + `final_head_sha` + `plan_hash` を required で束ねる（`docs/schemas/run-evidence.schema.json:7-29`（`"required": [` 〜 `],` の全 21 キー））。**`pr_number` は RunEvidence schema の required ではない**（同 schema に `pr_number` の grep ヒット 0 件）。PR 番号は `delivery` の **`kind=merge_ready` entry の `record.pr_number` からのみ**解決される（`scripts/ai-loop/run_evidence.py:489-496` の `def derive_delivery_fields()` docstring `:493`「注入 `--pr-number` は cross-check 専用であり、注入だけを根拠に実値化しない」）。`:512-515` が `--pr-number` と record の不一致を error にする。実装 `run_evidence.py:739-743` は `task_id` が `TASK-[0-9]{4}` かつ**ディレクトリ名と一致**することを検証。受理側の検証器も同じ形式検査を再実行する（`scripts/ai-loop/run_evidence_verify.py`）。**不足は入口 1 点**: `TASK-[0-9]` 正規表現 14 箇所はすべて**パス由来または引数/JSON フィールド検証**であり、**commit message / PR body から TASK-ID を機械抽出する仕組みは該当なし**（`.github/workflows/` に `TASK-` の正規表現 0 件） |

### 6 項目の集計と Phase 2 への含意

| 判定 | 件数 | 項目 |
|---|---|---|
| 一部満たす（既存資産の配線・拡張で到達しうる） | **4** | D1 / D2 / D5 / D6 |
| 未対応（新規） | **2** | D3（ADR 参照）/ D4（temporary コメント） |

> **Phase 2 の実装先に関する Phase 0 での注意**: D1 を schema で強制する経路は `schemas/plan.schema.json`（`:38` の `additionalProperties: false` 解除 + `related_issue` 追加）を要し、**`schemas/*.schema.json` は Hardening Override 対象パス**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) の 9 カテゴリ）。**ただし D1 の本体は schema ではなく「`.md` front matter を検証する経路の新設」**であり（現状その経路が存在しないため schema 側の制約は実効していない）、経路を `scripts/` 直下のスタンドアロン検査として作れば HO を回避できる可能性がある。同様に D5 の CI 配線は `.github/workflows/`、D4 を hook 化するなら `scripts/hooks/` がいずれも HO。**Phase 0 の ADR は「どの check をどの層（validator / hook / CI）に置くか」を決める際に HO 接触の有無を評価軸に含める**こと。

---

## 裏取り結果 4: ADR の現状と採番

issue Phase 0 チェックボックス 4（ADR 作成）の前提。

| 事実 | 実測 |
|---|---|
| ADR ディレクトリ | `docs/decisions/`。**実在は `adr-001-approve-out-of-band.md` の 1 件のみ**。`README.md` / 採番規約ファイルは不在 |
| フォーマット規約 | **文書化されていない**。ADR-001 の節構成（Context / Problem Statement / Decision Drivers / Considered Options / Decision / Consequences / Related）が de facto |
| `adr-002` の予約 | `docs/working/TASK-0981/plan.md:110`（作成先を `adr-002-plan-contract-canonical-source.md` に確定）/ `:114`（「本 ADR が `adr-002` を占有する。#980 は `adr-003` 以降を使う」）。**実ファイルは未作成** |
| `adr-003` 以降の予約 | `docs/working/TASK-0980/pbi-input.md:355`（#980 側は「ADR 3 本、採番 `adr-002`〜`adr-004`」と想定）。**#981 plan（002 占有・#980 は 003 以降）と数値が食い違っている**。実ファイルはいずれも未作成 |

### #1015 の採番提案

**採番だけを先に固定する方法は成立しない**。理由:

- **`adr-005` は衝突候補**。`TASK-0980/pbi-input.md:355` は **ADR を 3 本**想定しており、#981 の宣言（002 を占有・#980 は 003 以降）に従うと #980 は **003 / 004 / 005** を消費しうる
- **「実ファイル最大番号 +1」も単独では機能しない**。現状 `docs/decisions/` の実ファイルは `adr-001` のみで、この式は **`adr-002` を返して #981 の予約と衝突する**

したがって次を採る:

- **第一候補（採番方式）: Phase 0 では番号を確定せず、`docs/decisions/README.md` に「予約表」を置いて PR 作成直前に確定する**。予約表には #981 / #980 / #1015 の各宣言を記録し、**宣言と実ファイルの両方を突き合わせられる状態**にする（README 新設は「新しい文書体系を増やさない」制約と緊張するため、**ADR-001 のフォーマットを追認する最小記述 + 予約表**に留める）
- **第二候補（README を作らない場合）: `adr-006` 以降を採る**（#980 の 3 本想定 = 003-005 を回避した次番）
- **採番判定式の補正（決定論的に書く）**: 「実ファイル最大番号 +1」ではなく **「`max(docs/decisions/ の実ファイル番号) + 1` **以上**で、予約集合 `{002（#981 が占有宣言）, 003-005（#980 が ADR 3 本を想定）}` に含まれない**最小**の番号」** とする。作成時点の実測値（実ファイル = `adr-001` のみ）ではこの式は **`006` に一意収束**し、上記の第二候補と一致する
- **PR 作成直前に採番を再確認**する（#981 / #980 が先に merge して番号を消費している可能性があるため）

---

## 責務境界

issue Phase 0 チェックボックス 3 に対応。**本 PBI はこれらを置き換えず、重複実装しない**。

| 相手 | 相手の担当 | #1015 の担当 | 境界の言い方 |
|---|---|---|---|
| **#867**（継続的リファクタリング / OPEN） | **リファクタリング固有**の Knowledge Delta（Newly learned / Existing representation / Delta / Required structural response）、Preparatory Refactoring・Characterization Test の適用条件、振る舞い変更と構造変更の分離、Behavior Preservation ゲート、投機的抽象化の検出 | **変更種別を問わない横断契約**: How / What / Why / Why not の配置先、成果物間の参照と追跡、重複・欠落・矛盾・stale の検出、Planner と Executor が異なる場合の判断継承 | #867 =「**構造をどう変えるか**の知識同期」/ #1015 =「**どんな変更でも知識をどこに置くか**」。issue #1015 本文が自ら「#867 を置き換えず…横断的な Knowledge Placement Contract を正本とする」と宣言済み。**接続点**: #867 の Knowledge Delta は #1015 の Why / Why not の**具体適用の 1 パターン**であり、#1015 の契約が Delta の記述先（plan / ADR）を与える。**重複危険**: 両方が Plan に新セクションを足すと plan.md が肥大化する → Phase 1 でセクション追加を提案する際は #867 の `## Knowledge Delta` 案との統合可否を先に判定する |
| **#981**（Plan Contract / OPEN・PR1 の pbi-input / plan / C-1 / C-2 が main 実在） | **どの Plan を実行してよいか** — Plan の識別・不変性・承認束縛。`plan_hash` / `plan_package_hash` / `artifact_hashes` による同一性、C-1・C-2 evidence の plan hash 束縛、C-3' approval record、exec preflight の stale / source SHA 検証、Executor の実行主体・実行参照・revision / resume | **どの知識をどこに置くか** — Plan の**中身の構成**（何を書き、何を書かないか）と成果物間の知識分担 | **hash 契約としては直交、しかし plan.md の見出し構造では結合している**（下記）。`plan_hash` 自体は `scripts/ai-loop/c3_contract.py:119-121` の `sha256_of_file()`（`read_bytes()`）で算出される**不透明な bytes の hash** であり、中身に何を書くかを問わない。#1015 が Plan にセクションを足せば `plan_hash` は当然変わるが、それは**承認前の plan 生成時点**の話であり、#981 の「承認後の改変を検知する」機構とは競合しない。**ただし `plan_hash` の直交性を Plan Contract 全体の直交性と混同してはならない**: `scripts/ai-loop/plan_package.py:188` の `def derive_loopspec()` は `plan.md` の **`## Goal` 節（`:207-209`）・`## Files / Components to Touch` 節（`:211-214`）・`Verification Automation:` 行（`:216-218`）**を機械パースし、いずれかが取れなければ `PlanPackageError` で **fail-closed**。抽出された `allowed_paths` は `scripts/ai-loop/arbiter.py:362-374` `check_allowed_paths()` で **scope 逸脱判定の入力**になる。すなわち **plan.md の見出し構造は実行境界ゲートを駆動している**（`TASK-0981/plan.md:115` も同じ依存を自覚済み）。**接続点**: 両者とも Planner ≠ Executor の情報継承を扱うが、#981 は「参照の正しさ」（正しい Plan を見ているか）、#1015 は「参照先に十分な情報があるか」（見ても判断を復元できるか）。**ADR 採番は #981 の adr-002 予約を尊重する**（上記「裏取り結果 4」） |
| **#874**（RunEvidence 契約 / OPEN） | Run 単位の evidence 生成契約（`run_id` / `plan_hash` / `c3_prime_decision_ref` / `ci_outcomes` / `review_findings` / `terminal_state` 等）、observation と cause hypothesis の分離、#869 / #811 への接続 | Knowledge Placement Contract の **K-8（Verification evidence）が RunEvidence を正本として指す**こと。**RunEvidence の schema・生成器を #1015 では変更しない** | **#1015 は参照するだけ**。K-8 は既に「既存で満たす」判定であり、Phase 1 で新フィールドを提案しない。#874 の `review_findings` は Phase 3（Review integration）の finding taxonomy と接続しうるが、**taxonomy の正本は #874 / River Review 側に置き、#1015 は参照定義まで** |
| **#980**（Agent Identity / 署名付きイベント / OPEN） | Principal / ActorSession / Delegation の主体モデル、署名付きイベント、監査モデル | 「Planner と Executor が異なる場合に**判断根拠を引き継げる**か」の**情報側**。**誰が実行したかの真正性は扱わない** | **直交**。#1015 は「Plan を読めば実装できるか」（情報の十分性）、#980 は「誰がそれをやったか」（主体の真正性）。Phase 4 の検証シナリオ 5（Planner と実行者が異なる）は #980 の実装を待たずに検証できる（人間が 2 セッションに分けて実施すれば足りる） |
| **Review Gate**（[`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md)） | 5 レビュー観点（`:15-19`、`## 2. 5つのレビュー観点`）/ Severity 4 段階（`:23-28`、`## 3. Severity定義（4段階）` の表）/ 判定基準（`:32-36`、`## 4. 判定基準` の表）/ C-2 の 2 レーン責務契約（`:62-91`、`## 7-bis. C-2 レビュア責務契約（2 レーン / TASK-0076 F5-B）`） | Phase 3 で **C-1 / C-2 に Knowledge Placement 観点を追加**する際、**5 観点・Severity・判定基準は不変**とする | `review-principles.md:64`（`> #234-B 反映。**5 つのレビュー観点・Severity・判定基準（§2〜4）は不変**。`）が既に明文化。#1015 の観点は §2 の**可読性・保守性の具体適用**として追加し、**新しい severity 体系を作らない** |
| **River Review**（[river-review#1783](https://github.com/s977043/river-review/issues/1783)） | 実際の diff / tests / Plan / ADR / comments を対象とした**欠落・矛盾・stale・誤配置の独立レビュー**。finding と evidence を返す | Knowledge Placement Contract、artifact 配置、適用条件、traceability、gate 接続 | issue コメント（2026-08-05 / s977043）で明示分離済み。**River Review は PlanGate の C-3 / C-4 / GO・NO-GO / merge authority を持たない**。**#1015 では review logic を一切実装しない**（Non-goals） |

---

## What（Scope）

### In scope（Phase 0 のみ）

**S-1〜S-7** は issue 本文「実装フェーズ → Phase 0: 現行棚卸しと ADR」のチェックボックス 5 項目に 1:1 対応する。**S-6b は issue「Human Approval Boundary」由来の派生スコープ**であり、チェックボックスとの 1:1 対応の外側にある（S-6 で「ADR を要求する条件」を定義する以上、要否の最終判断者の帰属が Phase 0 で決まるため追加した）。

| # | 作業 | 成果物（想定） |
|---|---|---|
| S-1 | `docs/working/TASK-1015/` の標準 artifact 作成 | `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md` / `handoff.md`（本 `pbi-input.md` と合わせて Plan Package 6 要素） |
| S-2 | 既存 artifact の棚卸し（本 pbi-input の「裏取り結果 1」を plan で確定版に昇格） | plan 内の棚卸し表 |
| S-3 | How / What / Why / Why not を表現済みの箇所の特定（「裏取り結果 2」の 8 行 × 3 値判定を確定） | plan または ADR の付表 |
| S-4 | #867 / #981 / #874 / #980 / Review Gate / River Review との重複・責務境界の整理 | ADR の境界節（本 pbi-input の「責務境界」表を確定版に） |
| S-5 | **Knowledge Placement Contract の ADR 作成** | `docs/decisions/adr-00N-knowledge-placement-contract.md`（採番は「裏取り結果 4」に従い確定）+ **`docs/decisions/README.md`（採番規約 + 予約表。第一候補の採番方式を採る場合のみ / 0〜1 ファイル）** |
| S-6 | **必須 / 条件付き / 非対象の適用判定を定義** | ADR の決定事項（issue「適用判定」節の「常に要求する最小契約」/「Why not を要求する条件」/「ADR を要求する条件」/ Design Precondition 6「生成物・外部管理物は原則対象外」を 1 つの判定表に統合） |
| S-6b | **Human Approval Boundary の帰属決定** — issue「Human Approval Boundary」5 項目（ADR 要否の最終判断 / 重要な代替案の採否 / C-3・C-4・merge / policy・HO・first principles の変更 / semantic finding への例外承認）のうち、**S-6 で「ADR を要求する条件」を定義する以上「要否の最終判断者」は Phase 0 の決定事項になる** | ADR に Human-owned 項目の表を置き、**「条件は機械判定、要否の最終判断は Human-owned」**の分界を明記する。残る 4 項目（代替案の採否 / C-3・C-4・merge / policy・HO 変更 / semantic finding 例外承認）は**既存の責務 4 分類（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）と C-3 / C-4 で既に Human-owned**であることを確認して**再定義しない**。semantic finding への例外承認の運用手順のみ Phase 3 送りとし、その旨を ADR に書く |
| S-7 | Deterministic checks 6 項目の**実装可能性と配置層の方針決定**（validator / hook / CI のどこに置くか。HO 接触の有無を評価軸に含める） | ADR の決定事項 + Phase 2 スコープへの反映 |

### Out of scope（後続スライス / 順序依存あり）

issue 本文の Phase 順序を厳守する。**Phase 0 の ADR で正本と適用判定が決まるまで Phase 1 以降に着手しない**。

```text
Phase 0: 現行棚卸し・ADR・適用判定の定義      ← 本 PBI
  ↓
Phase 1: Docs / Template（契約の文書化・plan/test-cases/handoff/PR template への最小追加・良い例/悪い例・plugin 配布方針）
  ↓
Phase 2: Deterministic validation（参照整合・ADR-required 検出・temporary comment 検査・stale link。opt-in / warning mode から開始）
  ↓
Phase 3: Review integration（C-1 / C-2 への観点追加・River Review との入出力契約・finding taxonomy・Human escalation 接続）
  ↓
Phase 4: Dogfooding / Evaluation（代表変更で実走・計測・**契約が認知負荷を増やすだけの場合は適用条件を縮小**）
```

| 対象 | 理由 |
|---|---|
| Phase 1: template への項目追加（`docs/working/templates/plan.md` 等） | Phase 0 の ADR で「どの Knowledge を既存セクションに割り当て、どこだけ新設するか」が決まらないと、K-5 のように**既に満たしている領域へ重複セクションを足す**事故が起きる（L-5 の自己適用） |
| Phase 2: validator / hook / CI 実装 | 配置層と HO 接触の判断が Phase 0 の S-7 に依存。**`schemas/` / `scripts/hooks/` / `.github/workflows/` はいずれも HO 対象**で AI 直接変更不可のため、実装先が決まらないと Human 適用タスクを見積もれない |
| Phase 3: C-1 / C-2 への観点追加 | `.claude/rules/` は HO 対象。かつ finding taxonomy は River Review #1783 側の設計と揃える必要があり、#1783 の進捗に依存 |
| Phase 4: dogfooding・計測・適用条件の縮小 | Phase 1〜3 の成果物が前提 |
| **`docs/working/templates/test-cases.md` / `todo.md` の新規テンプレート作成** | 棚卸しで判明した既存ギャップだが、**#1015 のスコープではない**（Knowledge 配置契約とは別問題）。Phase 0 の handoff に**発見事項として報告**し、別 issue 起案の候補とする |

### Non-goals

issue「Non-goals」を保持し、本 PBI 固有のものを追加する。

- **新しい巨大な文書体系の追加**（既存 artifact への additive 導入に限定。同じ意味の新規ファイルを増やさない）
- **全成果物の作成強制**（すべての変更に ADR / コメント / 長文 commit を要求しない。規模・リスク・非自明性に応じて適用する）
- **River Review の diff review logic を PlanGate へ重複実装すること**
- **既存 SSoT の破壊 / 後方互換性を壊す変更**（既存 artifact・CLI・record の形式を Phase 0 では 1 バイトも変えない）
- コメント量・文書量を品質指標にすること
- コードの How を設計文書だけへ移すこと
- テストで内部実装を一切参照しないと絶対化すること（Characterization Test 等の例外は目的と撤去条件を記録する前提で認める）
- LLM reviewer 単独で設計品質や承認可否を決めること
- Git 履歴戦略の全面変更
- **既存の C-3 / C-4 / `NO MERGE BY AI` の変更**（issue AC にも明記。Phase 0 の成果物はいずれもゲート判定に影響しない）
- **#867 の Knowledge Delta 設計の先取り / 置き換え**
- **#874 RunEvidence schema の変更**（K-8 は参照のみ）
- **#980 の Principal / ActorSession の実装**

---

## 受入基準

> **起案である旨の明示**: issue #1015 本文の「Acceptance Criteria」16 項目は **#1015 全体（Phase 0〜4）** の AC であり、**Phase 0 単独の AC ではない**。以下 AC-1〜AC-5 は issue「実装フェーズ → Phase 0」のチェックボックス 5 項目を 1:1 で保持したもの、AC-6〜AC-8 は本 pbi-input が**起案**として追加した検証可能性・非退行の担保である（plan で最終確定する）。**ただし AC-5 のみ「チェックボックス ⑤（適用判定の定義）+ S-6b（Human Approval Boundary の帰属決定）の合成**であり、厳密な 1:1 ではない（plan で AC-9 として独立させる案も可）。

| AC | 内容 | 検証方法 |
|---|---|---|
| **AC-1** | `pbi-input.md` / `plan.md` / `test-cases.md` / `todo` / `handoff` / Trust Ledger / Decision Record / ADR / commit 規約を棚卸しした（issue Phase 0 ①） | plan または ADR に棚卸し表があり、**各 artifact のテンプレート正本パス・規約正本パス・主要セクション**が記載されている。テンプレート不在の artifact（`test-cases.md` / `todo.md`）は「不在」と明記され、代替の規約参照先（`.claude/rules/working-context.md:204-210` = `### test-cases.md（テストケース定義）` / `:193-202` = `### todo.md（EXECUTION TODO）`）が示されている。**すべての参照先が実在し、かつ行番号が示す先が併記した見出し名と一致すること**を確認できる（`sed -n` 等での実体照合。行番号だけでは「実在するが別セクションを指す」誤りを検出できないため、**見出し名の併記を必須**とする） |
| **AC-2** | 既存セクションで How / What / Why / Why not を表現済みの箇所を特定した（issue Phase 0 ②） | Knowledge 8 行それぞれに **「既存で満たす / 一部満たす / 未対応」** の判定と**ファイル:行の根拠**が付いている。かつ **「既存で満たす」と判定した Knowledge に Phase 1 の新規セクション追加が 1 件も割り当てられていない**ことを表上で確認できる（重複記載による stale = 情報損失パターン L-5 の自己適用）。**判定の境界**: 既存表への**列追加は「新規セクション追加」に含まない**（K-5 の「再検討条件」列がこれに当たる。列追加は同一の正本の中で情報を増やす操作であり、正本を 2 つに増やす操作ではないため L-5 を誘発しない） |
| **AC-3** | #867 / Plan Contract（#981）/ Evidence Contract（#874）/ Review Gate との重複・責務境界を整理した（issue Phase 0 ③） | ADR に責務境界の表があり、**各相手について「相手の担当 / #1015 の担当 / 境界の言い方」の 3 列**が埋まっている。特に **#867 とは「リファクタリング固有 vs 変更種別を問わない横断」**、**#981 とは「どの Plan を実行してよいか vs どの知識をどこに置くか」**が明記されている。River Review との分界（review logic を実装しない）も記載されている |
| **AC-4** | Knowledge Placement Contract の ADR または同等 Decision Record を作成した（issue Phase 0 ④） | `docs/decisions/adr-00N-*.md` が実在し、ADR-001 の節構成（Context / Problem Statement / Decision Drivers / Considered Options / Decision / Consequences / Related）を踏襲している。**採番が `docs/decisions/` の実ファイルと衝突せず、かつ #981 / #980 が宣言済みの予約番号とも衝突していない**ことを PR 作成直前に再確認した記録がある |
| **AC-5** | 必須 / 条件付き / 非対象の適用判定を定義した（issue Phase 0 ⑤） | ADR に適用判定表があり、**(a) 常に要求する最小契約**（4 項目）**(b) Why not を要求する条件**（6 条件）**(c) ADR を要求する条件**（5 条件）**(d) 非対象**（generated / vendored / lock / minified / migration tool 生成物）が漏れなく記載されている。かつ **軽微変更で契約が発火しないこと**を、代表シナリオ（issue 検証シナリオ 1「軽微なバグ修正」= ADR / Why not 不要）で説明できる。**さらに issue「Human Approval Boundary」の「ADR が必要かの最終判断」が Human-owned であることが明記され**、機械判定できる条件（(c)）と最終判断者の分界が示されている（S-6b） |
| **AC-6**（起案） | Deterministic checks 6 項目の実現可能性が実測で判定されている | ADR または plan に D1〜D6 の「既存で満たす / 一部満たす / 未対応」判定と根拠ファイル:行がある。かつ **各 check の配置層（validator / hook / CI）と HO 接触の有無**が評価されている（Phase 2 が「実装先が決まらない」で止まらないため） |
| **AC-7**（起案） | 既存挙動が不変であることが確認できる | Phase 0 は文書のみの変更であることを **base SHA を固定した** `git diff a2a02b9 --stat` で示す（`origin/main` は進行中に動くため非決定的。基点 SHA は本 pbi-input 冒頭の作成時点 main、exec 時に再確定する）。加えて `sh tests/run-tests.sh` と `bin/plangate validate` の既存ケースが Phase 0 前後で同一結果であることを記録（実コマンドは plan で確定） |
| **AC-8**（起案） | 契約が認知負荷を増やすだけになった場合の撤退条件が定義されている | ADR に **「適用条件を縮小する判断基準」**（issue Phase 4 が自ら述べる撤退条項）が Phase 4 を待たずに書かれている。最低限、**(a) どの指標が悪化したら縮小するか**（不要コメント / 不要 ADR の生成率、レビュー差し戻し率）**(b) 縮小の最小単位**（条件付き適用 → opt-in → 撤回）が定義されている |

### #1015 全体 AC 16 項目と Phase 0 の関係（起案・plan で確定）

| #1015 全体 AC | Phase 0 で扱う範囲 |
|---|---|
| How / What / Why / Why not の定義と配置先が文書化されている | **ADR で定義まで**（template への反映は Phase 1） |
| 既存 artifact との重複分析が完了し、新しい正本を不必要に増やしていない | **Phase 0 で完了**（AC-2） |
| #867 および River Review との責務境界が明確である | **Phase 0 で完了**（AC-3） |
| 軽微変更・通常変更・設計変更ごとの適用条件と省略条件がある | **Phase 0 で定義**（AC-5）。例示は Phase 1 |
| Why not / ADR を要求する条件が定義されている | **Phase 0 で完了**（AC-5） |
| コメントが必要な条件と不要なコメントの例がある | 条件は Phase 0（AC-5）、**例は Phase 1** |
| テストが実装詳細ではなく What を固定するための review criteria がある | **Phase 3**（K-3 が「一部満たす」＝観点が未明文） |
| 重要な Why が commit 履歴だけに依存しない | **Phase 0 で方針決定**（K-6 の判定と Design Precondition 2 の整合）。強制は Phase 2 |
| task → Plan → tests → diff → evidence → decision を追跡できる | **Phase 0 で実現可能性判定**（AC-6 の D6）。実装は Phase 2 |
| 機械判定と semantic review の境界が定義されている | **Phase 0 で定義**（AC-6 + AC-3 の River Review 分界） |
| temporary / workaround コメントに参照・撤去条件を要求できる | **Phase 2**（D4 が未対応） |
| Planner / Executor 分離ケースで判断継承を検証している | **Phase 4** |
| squash 後にも重要な判断を再構成できる | **Phase 0 で方針決定**（K-6）。検証は Phase 4 |
| 既存 C-3 / C-4 / `NO MERGE BY AI` を変更しない | **Phase 0 で変更しないことを宣言**（Non-goals）。issue「Human Approval Boundary」5 項目のうち **ADR 要否の最終判断のみ Phase 0 の決定事項**（S-6b）、残り 4 項目は既存の責務 4 分類・C-3 / C-4 で Human-owned のため再定義しない |
| 代表シナリオ 8 件以上の fixture または dogfooding evidence がある | **Phase 1（例）〜 Phase 4（dogfooding）** |
| 既存利用者へ破壊的変更を与えず、段階導入・migration 方針がある | Phase 0 は文書のみで自明に非破壊（AC-7）。段階導入方針は **Phase 2 の opt-in / warning mode** |

---

## Notes from Refinement

### 「既存で満たす」4 領域に手を入れない理由

Knowledge 8 行のうち K-1 / K-2 / K-5 / K-8 は既存 artifact が既に担っている。ここへ Phase 1 で新セクションを足すと、**同じ説明が 2 箇所以上に並び、片方だけ更新されて矛盾する** = issue 自身が列挙する情報損失パターン L-5 を、この契約の導入によって発生させることになる。

したがって Phase 0 の ADR は、これら 4 領域について **「正本はここ」と既存パスを指し示す表を作るだけ**とする。issue の「Plan artifact への追加候補」ブロック（`## Decision Context` 以下 5 小節）は、この照合の結果として**必要最小限まで削る**のが Phase 1 の作業になる。現時点の照合結果に基づく削減案（plan で確定）:

| issue の追加候補 | 照合結果 | 扱い（案） |
|---|---|---|
| `### Why` | `plan.md:20` `## Context` + `pbi-input.md:5` `## Context / Why` が既存 | **新設しない**（既存を指す） |
| `### What must remain true` | `test-cases.md` 規約はあるが「実装から独立した不変条件」の観点は未明文（K-3 = 一部） | **追加候補として残す**（ただし新セクションか既存 `## Verification Plan` への注記かは Phase 1 で判断） |
| `### Chosen approach` | `plan.md:69` `### Recommended Approach` が既存 | **新設しない** |
| `### Alternatives / Why not` | `plan.md:62` `## Approach Comparison`（採用/不採用列）+ `decision-log-schema.md:22` `alternatives_rejected` が既存 | **新設しない**。ただし**「再検討条件」の欄が現行にない**ため、既存表への列追加を検討 |
| `### Knowledge placement` | 対応する既存セクションなし | **本 PBI の中核的な追加候補**。ただし全 PBI 必須にせず、適用判定（AC-5）に従って条件付きとする |

### commit の Why をどう扱うか（K-6 の方針素案）

`CONTRIBUTING.md:62-75` は Conventional Commits の**プレフィックスのみ**を規定しており、body の Why を要求していない。一方 issue の Design Precondition 2 は「重要な Why を commit だけに依存しない」と述べる。この 2 つは矛盾せず、次の整理が成立する（ADR で確定）:

- **局所的・変更単位の Why** → commit body（**強制しない**。Conventional Commits の現行規約は変更しない）
- **タスク全体・承認対象の Why** → Issue / `pbi-input.md` / `plan.md`（**既に必須**）
- **長期的な設計判断・代替案比較** → ADR / `decision-log.jsonl`（**既に条件付き必須**: `decision-log-schema.md:44`）
- **PR 単位の説明** → PR body / `handoff.md`（**既に必須**: `hybrid-architecture.md` Rule 5）

すなわち **PlanGate では squash merge 後も重要な Why が失われない構造が既にある**。K-6 を「一部満たす」としたのは commit 規約側の話であり、**Phase 2 で commit message に Why を強制する方向へ進めるべきではない**（儀式化のリスクが便益を上回る）というのが本 pbi-input の起案である。

### Phase 0 で判明した既存不整合（記録のみ・**本 PBI では是正しない**）

棚卸しの副産物として、既存 artifact 側に L-5（重複・矛盾）そのものの実例が見つかった。本 PBI は「知識をどこに置くか」の契約を決める Phase であり、**Phase 0 のスコープを広げないため是正はしない**。ADR の「発見事項」節または別 issue の候補として引き継ぐ。

| # | 不整合 | 実測 | 扱い |
|---|---|---|---|
| G-1 | **plan テンプレの見出しが ai-loop 抽出器と一致しない** | `docs/working/templates/plan.md:73` = `## Files / Interfaces` に対し、抽出器は `Files / Components to Touch` を部分一致で探す（`plan_package.py:170-185`）。実測で `extract_allowed_paths(テンプレ)` = `[]` → `plan_package.py:212-214` で fail-closed。#981 の plan は `## Files / Components to Touch` を採っておりテンプレ正本と乖離 | **Phase 1 の影響評価に含める**（新規セクション追加の副作用ではなく既存不整合であることを明記済み） |
| G-2 | **`decision-log-schema.md` 正本の内部矛盾** | `:22` の表セルは `**必須=high-risk / critical / human decision**` で `phase` 条件を含まないが、`:44` の本文は「**`phase=brainstorm` での採用案決定時で**、mode が high-risk / critical、または human decision の場合」と `phase` 前提を課している。同一ファイル内で必須条件の範囲が食い違う | **記録のみ**。K-5 の根拠を引くときは常に `:44`（狭い方＝安全側）を正とする。是正は別 issue 候補 |
| G-3 | **`test-cases.md` / `todo.md` のテンプレート実体が存在しない** | `docs/working/templates/` に両ファイルなし。規約は `working-context.md:204-210` / `:193-202` のみ | **Out of scope**。handoff で発見事項として報告し別 issue を起案（U-7） |

> **本節自体が契約の自己適用**である。「重複・欠落・矛盾・stale を検出可能にする」（issue 目的 2）を Phase 0 の棚卸しで実行した結果がこの 3 件であり、**検出したものを即座に直すのではなく、正本と是正フェーズを明示して引き継ぐ**という扱い方が Knowledge Placement Contract の運用例になる。

### Mode 判定案（plan で確定）

Phase 0 は**文書のみの変更**を想定する（ADR 1 件 + working context artifact）。

| 軸 | 判定 | 根拠 |
|---|---|---|
| 変更ファイル数 | ADR 1 + `docs/decisions/README.md` 0〜1（採番方式の第一候補を採る場合）+ working context 6〜7 = **7〜9 ファイル** | **high-risk 帯**（6-15。上限側が 9 でも帯は変わらず判定不変） |
| 受入基準数 | AC-1〜AC-8 = **8 個** | **high-risk 帯**（6-10） |
| タスク数（見込み） | 棚卸し確定 + 境界整理 + ADR 執筆 + 適用判定 + checks 評価 + artifact 一式 ≈ **11〜15** | **high-risk 帯**（11-20） |
| 変更種別 | doc（差分は `.md` のみの見込み） | doc |
| リスク | **中〜高** — ADR が Phase 1〜4 の設計を拘束する。誤った正本配置を確定すると後続全 Phase が二重正本の上に積み上がる | high-risk |
| 影響範囲 | 直接の差分は `docs/` に閉じるが、**契約として C-1 / C-2（`.claude/rules/`）・template・validator の将来変更を規定する** | 複数レイヤーに波及 = high-risk |
| ロールバック | ADR は revert 可能（文書のみ）。ただし後続 PBI が参照し始めると実質的に不可逆 | 計画的に必要 |

**Hardening Override（HO）の判定**:

- **Phase 0（本 PBI）の差分は HO 対象パスを含まない見込み**。ADR は `docs/decisions/`、artifact は `docs/working/TASK-1015/` であり、いずれも HO 9 カテゴリ（`.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` / `.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows/*.{yml,yaml}` / `AGENTS.md`・`CLAUDE.md`）に該当しない。`docs/working/templates/` も HO 対象外（テンプレート変更は Phase 1 の話でもあり、本 Phase では触れない）
- **high-risk は定量 3 軸（変更ファイル数 / 受入基準数 / タスク数）で独立に成立**しており、「承認境界周辺の変更 → 最低でも高」の例外ルールに依存しない。したがって **`mode-classification.md` の安全側条項（「該当不確実な場合は該当扱い」）を援用する必要はない**（Phase 0 の差分は HO 9 カテゴリに明確に非該当 = 不確実ではない）。C-3 で争点化させないため、mode の根拠は**定量軸を主**とする
- **`lite_eligible=false` の根拠は「新規設計の有無」**: `lite_eligible` は「変更ファイル数が少・**新規設計なし**・既存パターン踏襲」の 3 軸すべてを満たすときのみ true の候補となる（[`mode-classification.md`](../../../.claude/rules/mode-classification.md)）。本 PBI は **ADR で正本配置と適用判定を新規に決定する = 新規設計あり**のため、この軸で false が確定する。さらに `critical` でなくとも high-risk mode は autonomous APPROVE 判定マトリクス上「不可」（[`working-context.md`](../../../.claude/rules/working-context.md)）
- **`doc-light` は適用しない**。差分は `.md` のみだが、[`mode-classification.md`](../../../.claude/rules/mode-classification.md) の doc-light 除外条件「ドキュメントが API 仕様・契約の正本で、コード側の追従を要する」に該当する（ADR が Phase 2 の validator 実装を規定する）

**結論（安全側の初期値）**:

```text
mode           = high-risk
lite_eligible  = false     （承認境界周辺 → 強制 false）
C-3            = 同期・人間必須（autonomous APPROVE 不可）
```

**Phase 1 以降の HO 見通し**（Phase 0 の handoff に BLOCKED として先出しする対象）:

| Phase | HO 接触見込み | Human 適用が要る操作 |
|---|---|---|
| Phase 1 | `docs/working/templates/*`（HO 外）中心。ただし PR template = `.github/PULL_REQUEST_TEMPLATE.md` は HO 9 カテゴリの `.github/workflows/` **ではない**ため AI 編集可 | なし（要再確認） |
| Phase 2 | **`schemas/*.schema.json`（D1）/ `scripts/hooks/*.sh`（D4）/ `.github/workflows/*.yml`（D5 配線）= いずれも HO** | patch 提示 → Human 適用 |
| Phase 3 | **`.claude/rules/review-principles.md` 等 = HO** | patch 提示 → Human 適用 |

---

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|---|---|---|
| **契約が認知負荷を増やすだけになる** — issue 自身が Phase 4 で「適用条件を縮小する」と撤退条項を書いており、設計者もこのリスクを認識している | 全 PBI に「Knowledge placement を書け」が課され、実質はテンプレの穴埋めになる。書かれた内容が誰にも読まれず stale 化し、**契約が情報損失を減らすどころか L-5（重複・矛盾）を増やす** | **AC-5（適用判定）を Phase 0 のブロッキング完了条件にする**。「常に要求する最小契約」を issue が挙げる 4 項目**だけ**に固定し、それ以外はすべて条件付きにする。さらに **AC-8 で撤退条件を Phase 4 を待たずに ADR へ書く**（縮小の最小単位: 条件付き適用 → opt-in → 撤回）。検証シナリオ 1（軽微なバグ修正で ADR / Why not 不要）を Phase 0 の説明責任に含める |
| **既存 artifact との重複記載が stale を生む** — K-1 / K-2 / K-5 / K-8 は既に満たされており、そこへセクションを足すと同一情報が 2 箇所に並ぶ | Plan と handoff と decision-log に同じ Why not が 3 回書かれ、1 つだけ更新される。**この契約自身が防ごうとした失敗を、この契約が引き起こす** | **AC-2 の後半条件**（「既存で満たす」判定の Knowledge に Phase 1 の新規セクション追加を割り当てない）を機械的に確認可能な受入基準として置く。Phase 1 の template 変更は **ADR の割当表に載っているものだけ**に限定する |
| **ADR 採番が #980 / #981 と衝突する** — `adr-002` は #981 plan（`docs/working/TASK-0981/plan.md:110,114`）が、`adr-002`〜`adr-004` は #980 pbi-input（`docs/working/TASK-0980/pbi-input.md:355`）が予約を宣言しているが**双方の数値が食い違っており、かつ実ファイルは 1 件も作成されていない** | 3 PBI が同じ番号の ADR を作り、merge 時に衝突するか、片方が黙って上書きされる | 「裏取り結果 4」のとおり **単純な「実ファイル最大番号 +1」は現状 `adr-002` を返して #981 の予約と衝突するため機能しない**。判定式を **「実ファイル最大番号 +1 かつ他 PBI が宣言済みの予約番号を除外した最小値」** に補正したうえで、**第一候補は「Phase 0 では番号を確定せず `docs/decisions/README.md` に予約表を置き、PR 作成直前に確定する」**（第二候補 = `adr-006` 以降）。README を作る場合も ADR-001 のフォーマットを追認する最小記述 + 予約表に留め、新しい文書体系にしない |
| **Phase 1 の Plan セクション追加が #981 系の機械パースと干渉する** — `plan_package.py:149-164` `_extract_section()` は **`"## "` で始まる行を `heading in line` の部分一致**で探し、**次の `"## "` 行で本文を打ち切る**。`:170-185` `extract_allowed_paths()` はその節から `` `path/like` `` を抽出し、`arbiter.py:362-374` が scope 逸脱判定に使う | (a) 新 `##` を既存節の途中に挿入すると `_extract_section` が本文を切り詰める (b) `## Knowledge placement (Goal ...)` のような見出しが**部分一致で `## Goal` より先にヒット**する (c) **新節に backtick パスを書き、それが Files 節内に置かれると `allowed_paths` が汚染され scope 判定が緩む / 誤る**。いずれも fail-closed 例外かゲート誤判定になる。**(c) は #981 で実際に発生した事故と同型**（plan の `## Files / Components to Touch` 節に置いた「触れないもの（明示）」の backtick パスが `extract_allowed_paths()` に許可パスとして抽出され、**C-1 が FAIL（`docs/working/TASK-0981/review-self.md` の `F-1` / `C1-PLAN-03`）として検出**して C-3 前の是正対象になった。C-1 は PASS / WARN / FAIL の三値であり `major` は使わない） | **Phase 1 で `docs/working/templates/plan.md` にセクションを追加・挿入する際は `plan_package.extract_allowed_paths()` / `_extract_section()` / `derive_loopspec()` への影響評価を必須とする**（Phase 0 の ADR の follow-up として明記）。チェック項目 4 点を ADR に残す: **(0)【既存不整合・新規追加以前の問題】現行テンプレ `docs/working/templates/plan.md:73` の見出しは `## Files / Interfaces` であり、抽出器が探す `Files / Components to Touch` と部分一致しない。実測で `extract_allowed_paths(テンプレ本文)` = `[]` / `_extract_section(..., "Files / Components to Touch")` = `None` となり、`plan_package.py:212-214` の `raise PlanPackageError(["derive: \`## Files / Components to Touch\` からパスを抽出できない"])` に落ちる = 現行テンプレから素直に生成した plan は `derive_loopspec()` で fail-closed する。Phase 1 の影響評価は新規追加の副作用だけでなく、この既存不整合の是正要否を含めること（本 PBI では是正しない = Phase 0 は棚卸しと ADR まで）** (1) 新見出し名が既存見出し名を部分一致で先取りしないこと (2) 挿入位置が既存節の本文を分断しないこと (3) 新節に backtick パスを書かない（書く場合は Files 節の外に置く） |
| **#867 と Plan セクションを取り合う** — #867 は `## Knowledge Delta` の追加を提案しており、#1015 も `## Decision Context` 系の追加候補を持つ | plan.md が肥大化し、どちらも読まれなくなる（`docs/working/templates/plan.md` は既に 251 行以上で 15 セクション） | Phase 1 でセクション追加を提案する**前に**、#867 の `## Knowledge Delta` 案との統合可否を判定することを ADR の follow-up として明記。**#867 が先に merge した場合は #1015 が従属する**（横断契約が固有パターンを包含する方向） |
| **Phase 2 の実装先が HO で止まる** — D1 は `schemas/plan.schema.json`（`:38` の `additionalProperties: false` 解除が必要）、D4 は `scripts/hooks/`、D5 の CI 配線は `.github/workflows/` がいずれも HO 対象 | Phase 2 が「patch 提示のみ」で終わり、deterministic checks が 1 件も稼働しない | **AC-6 で配置層と HO 接触を Phase 0 の評価軸に含める**。HO を回避できる経路（例: `scripts/` 直下のスタンドアロン検査 + 既存の `scripts/check-stale-skill-refs.py` 方式）を代替として先に評価する。HO 接触が不可避な項目は Phase 0 の handoff に **BLOCKED（owner=human）** として先出しする |
| **`scripts/check-stale-skill-refs.py` の未配線を「配線するだけ」と過小評価する** | 同ファイル `:18-21` が自ら「doctor / L-0 / CI への配線は Hardening Override 対象（`bin/plangate`, `.github/workflows/`）に触れるため別 PBI の follow-up とする」と述べており、**配線こそが HO 作業** | D5 の評価では「スクリプトの存在」と「enforcement の有無」を分けて記載する。契約に書いてあることと機械強制されることを混同しない |
| **裏取り表の行番号が進行中に stale 化する / そもそも作成時点で誤っている** | 「対象 / 対象外」の判定が反転し、Phase 1 で誤った箇所を触る。**実害**: 本 pbi-input の初版は `.claude/rules/working-context.md` の 7 参照すべてが 1 セクション分ずれており、**K-3 の根拠行が `review-self.md` の規約を指し、AC-1 が「実在するが別物を指す行」を受入条件として固定**していた（River Review MJ-1 で是正） | 行番号だけでなく**セクション見出し名・フィールド名を必ず併記する**（`## Approach Comparison` / `alternatives_rejected` / `## 4. 妥協点` / `plangate_check_file` / `### test-cases.md（テストケース定義）` 等）。**見出し名の併記が無い参照は緩和が効かない**ため許容しない。AC-1 の検証方法にも「行番号が示す先が併記見出しと一致すること」を条件として明記済み。plan では exec 直前に現 main 基点で `sed -n` により再走査する |
| **River Review の review logic を無自覚に取り込む** — Phase 3 で C-1 / C-2 に観点を足すとき、「コメントが stale か」「テストが実装詳細を固定していないか」は本質的に diff レビューであり、PlanGate 側で書きたくなる | river-review#1783 と同じ判定が 2 箇所に実装され、両者が食い違ったときの優先順位という新しい失敗モードが生まれる | Non-goals に明記済み。ADR の境界節で **「PlanGate は placement の契約と gate 接続、River Review は実 diff に対する finding 生成」**を層として固定し、Phase 3 のスコープから review logic の実装を外す |

### Unknowns

- **U-1**: **ADR の採番と、採番規約文書の要否**。実測では `docs/decisions/` に `adr-001-approve-out-of-band.md` の 1 件のみが実在し、`README.md` も採番規約も不在。#981（`adr-002` 占有宣言 = `TASK-0981/plan.md:114`）と #980（**ADR 3 本**想定 = `TASK-0980/pbi-input.md:355`）の宣言が食い違っており、#981 の宣言に従うと #980 は 003-005 を消費しうる。**(a) 予約表付き `docs/decisions/README.md` を作り PR 直前に確定する（第一候補）/ (b) README を作らず `adr-006` 以降を採る / (c) 実ファイル最大番号 +1 かつ予約番号を除外した最小値を機械的に採る** のいずれかを plan で確定。**単純な「実ファイル最大番号 +1」は `adr-002` を返して衝突するため採らない**
- **U-2**: **`## Knowledge placement` を Plan に新設するか、既存セクションへの注記に留めるか**。新設は「新しい文書体系を追加しない」制約と緊張する一方、既存セクション（`## Files / Interfaces` 等）への注記では Executor が見落とす可能性がある。判断軸: (a) 全 PBI 必須にしないこと、(b) 適用判定で発火する条件が明確であること、(c) #867 の `## Knowledge Delta` と統合可能であること
- **U-3**: **「What must remain true」（実装から独立した不変条件）の置き場所**。K-3 が「一部満たす」であり、`test-cases.md` にはテンプレートすら無い。**(a) `test-cases.md` テンプレートを新設してそこに入れる**（ただしテンプレ新設は #1015 のスコープ外と本 pbi-input が宣言している）/ **(b) `plan.md:157` の `## Verification Plan` に注記として足す** / **(c) Phase 1 の判断に委ねる** のいずれか
- **U-4**: **commit の Why を Phase 2 で機械検査するか**。本 pbi-input の起案は「しない」（儀式化リスク）だが、issue AC は「重要な Why が commit 履歴だけに依存しない」を求めており、これは**検査ではなく代替経路の存在**で満たせる。ADR でどちらの解釈を採るか
- **U-5**: **Deterministic checks を opt-in で始める場合の既定値と有効化単位**。issue Phase 2 は「既存フローを壊さない opt-in または warning mode から開始する」と述べる。既存の hook 群は `PLANGATE_HOOK_STRICT=1` で warning → error に切り替わる方式（`scripts/hooks/check-test-cases.sh:51-69`）を採っており、これを踏襲するか、`.plangate` 設定で個別に有効化するか
- **U-6**: **finding taxonomy の正本をどちらに置くか**。issue Phase 3 は「finding taxonomy と severity を統一する」と述べるが、severity の正本は既に `.claude/rules/review-principles.md:23-28`（`## 3. Severity定義（4段階）` の表）にあり、River Review #1783 側も finding を返す。**PlanGate 側が taxonomy を定義して River Review が従うのか、River Review 側の taxonomy を PlanGate が受理するのか**を Phase 0 で方向づけるか、Phase 3 に委ねるか
- **U-7**: **`test-cases.md` / `todo.md` のテンプレート不在をどう扱うか**。棚卸しで判明した既存ギャップだが #1015 のスコープではない。**(a) Phase 0 の handoff で発見事項として報告し別 issue を起案する / (b) Phase 1 に取り込む**（スコープ拡大のリスクあり）のいずれか。本 pbi-input の起案は (a)
- **U-8**: **plugin / downstream 配布時の参照方針**（issue Phase 1 の項目）。`plugin/plangate/` 配下に skills / agents のミラーが存在し、`.claude/skills/` `.agents/skills/` `.codex/skills/` `plugin/plangate/skills/` の **4 配置に複製**がある（`ref-integrity-scan` で実測）。ADR を新設した場合、その参照を plugin 側にミラーするか、PlanGate 本体への参照リンクに留めるか

### Assumptions

- issue #1015 本文および 2026-08-05 のコメント（s977043 / River Review 側の分離宣言）が有効な設計前提であること。特に **「新しい巨大な文書体系を追加しない」「原則は配置ガイドであり全成果物の作成を強制しない」「River Review の review logic を重複実装しない」「既存 SSoT と後方互換性を優先」「生成物・外部管理物は原則対象外」** の 5 つを最上位制約として扱う
- 上記 4 つの裏取り表の実測が現 main（`a2a02b9`）で有効であること（exec 時に再走査して確定する）
- Phase 0 はコードを 1 行も変更しない（文書のみ）。したがって既存テスト・CLI・record の後方互換は自明に維持される（AC-7 は形式的確認）
- #867 / #874 / #980 / #981 はいずれも **OPEN** であり、本 PBI 期間中に merge されない前提で境界を書く（merge された場合は plan の exec 直前に責務境界表を再確認する）
- river-review#1783 は本 PBI 期間中に PlanGate 側の設計を拘束しない（finding の入出力契約は Phase 3 で調整する）
- issue の Acceptance Criteria 16 項目は **#1015 全体（Phase 0〜4）** の AC であり、Phase 0 単独の完了条件ではないこと（本 pbi-input の AC-1〜AC-5 は issue「Phase 0」チェックボックス 5 項目に 1:1 対応（AC-5 のみ ⑤ + S-6b の合成）、AC-6〜AC-8 は起案）
- `NO MERGE BY AI` / Human C-4 のみが merge へ到達、および既存の C-3 / C-4 ゲート判定は本 PBI のいかなる成果物によっても変更されない
