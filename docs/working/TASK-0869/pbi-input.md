# PBI INPUT PACKAGE — TASK-0869

> Issue: [#869](https://github.com/s977043/plangate/issues/869)（P1 / enhancement / area:workflow / area:eval / area:metrics）
> 関連 EPIC: [#870](https://github.com/s977043/plangate/issues/870)（#874 RunEvidence 契約が本 PBI の入力供給元）
> 作成: 2026-07-22（調査・main 53879e1 裏取り済み。AC/fixture/Non-goals は issue verbatim + 2026-07-18 棚卸しコメント反映）

## Context / Why

内側の ai-loop（1 タスクを `MERGE_READY` へ収束させる Delivery Loop）は #872/#873 系で機械化が進んだが、**複数の完了 Run から「次に試す最小のハーネス変更」を機械可読な候補として作り、評価・Gate・Trust Ledger へ安全につなぐ外側の Evolution Loop** は明示的な契約として未定義。issue #869 はこれを PlanGate-native な振り返り・実験オーケストレーションとして検討・定義する。2026-07-18 の棚卸しコメント（issue verbatim）により、本 Issue は完了済み EPIC #193/#200 の重複再実装ではなく、それらが提供した metrics / eval / retrospective / rollback 部品を **candidate generation → experiment → gate に接続する orchestration gap** として維持され、初期スコープは「1. Gap analysis → 2. Shadow mode → 3. Historical paired replay / activation check → 4. 根拠が得られた場合のみ limited canary」の順序に固定された。

実測（2026-07-22・main 53879e1）:

- **Evolution Loop の機械層は完全ゼロ**: `schemas/`（29 ファイル実測）に candidate / experiment schema 不在。`rg "HarnessImprovementCandidate|harness-improvement-candidate|HarnessExperimentResult"` は全リポジトリで **0 件**（issue 本文のみ）。`scripts/ai-loop/` は `arbiter.py` / `c3prime_verify.py` / `discovery.py` / `metrics.py` / `plan_package.py` + テストのみで clustering / shadow 抽出 / baseline 接続なし
- **candidate 抽出は現状すべて手動**: `docs/ai/reporting.md` §6「次の harness improvement PBI 候補 抽出方針」は advisory の人間判断表。`docs/working/ai-loop-runs/frictions-digest-001.md` は F-1〜F-24 の**手動**状態表（検証つき派生ダイジェスト）で、機械可読 candidate 契約ではない
- **WHERE×WHY enum は未正本化**: issue 提案の WHY 語彙（`context_loss` / `premature_finalize` / `routing_mismatch` 等）は `docs/` / `scripts/` で **0 件**（issue 本文のみに存在）
- **入力素材は実在**: 完了 Run record は `docs/working/ai-loop-runs/*.json` **28 件**（実測）。ただし `rg harness_version scripts/` は **0 件** = RunEvidence（#874）は pbi-input 合意のみで producer 未実装
- **workflow 正本の不在**: `docs/workflows/ai-loop/`（14 ファイル実測）に `harness-evolution-cycle.md` は存在しない。内側/外側の区別と **active run の harness 自己変更禁止**は `docs/workflows/ai-loop/00_concept.md` **§4.1** が既定（改善は別 TASK/Plan/PR とし、C-4 を経て次回以降の run にのみ反映）
- **schema 配置の HO 分岐**: `schemas/**` は **HO**（`docs/ai/ai-loop/ho-paths.md` L28「AI 直接編集不可」）。非 HO 前例は `docs/schemas/child-pbi.yaml` のみ。issue 本文のたたき台 `schemas/harness-improvement-candidate.schema.json` は HO 側の提案（#874 pbi-input と同型の C-3 分岐）
- **CLI 入口の HO 回避**: issue たたき台の `plangate report --emit-candidates` は `bin/plangate`（HO）改変を要する。`scripts/ai-loop/` 配下の単体 CLI なら非 HO で AI 実装可能

## What（Scope）

### In scope（棚卸しコメントの順序 1〜3 = Shadow まで。canary は根拠取得後の後続）

1. **Gap analysis（対応表）**: 既存部品（`metrics.py` / reporting §6 / frictions-digest / eval-baseline / rubric grader #753 / rollback）と外側ループ 8 段（Observe → Cluster → Propose → Replay/Eval → Gate → Canary → Measure → Record/Rollback)の対応表を `docs/workflows/ai-loop/harness-evolution-cycle.md` に正本化。内側/外側の責務・停止条件の区別は 00_concept.md §4.1 を参照し重複定義しない
2. **2 schema**: `HarnessImprovementCandidate`（issue 記載の `candidate_id` / `source_run_ids` / `target_layer` / `target_surface` / `allowed_paths` / `observed_pattern` / `cause_hypothesis` / `baseline_version` / `proposed_change` / `expected_metric` / `acceptance_threshold` / `risk` / `boundary_impact` / `evaluation_plan` / `canary_plan` / `rollback_plan` / `status` / `decision` / `decision_reason` を最低項目）+ `HarnessExperimentResult`（baseline/candidate・activation・品質・回帰・コスト・採否）。配置先は HO 分岐（下記 Notes）で **C-3 確定**
3. **WHERE×WHY enum の正本化**: `WHERE`（`prompt`/`context`/`harness`/`loop` の 4 値）× `WHY`（`context_loss`/`premature_finalize`/`retry_loop`/`review_miss`/`routing_mismatch`/`tool_error`/`false_positive`/`cost_overrun`/`boundary_escalation`/`model_capability_limit` の 10 値）を schema enum として固定し、`observed_pattern`（観測事実）と `cause_hypothesis`（原因仮説）をフィールド分離
4. **Shadow 抽出 CLI `scripts/ai-loop/evolution.py`**（非 HO・隔離 PoC）: 完了 Run evidence（現行 28 record + #874 RunEvidence fixture）から candidate を**生成するだけ**（read-only・変更適用なし）。既存 `plan_package.py`/`c3prime_verify.py`/`metrics.py` の決定論・fail-closed・冪等規約を踏襲（timestamp 注入・`now()` 直参照禁止・legacy/invalid/skip の明示区分）。**#874 producer 未実装を fixture 駆動で吸収**し #874 完了を待たない
5. **§4.1 並存規約の機械チェック**: candidate の `allowed_paths` が active run の `allowed_paths` と交差する場合は **BLOCKED を明示**（00_concept.md §4.1「active run の harness 自己変更禁止」を shadow 段階から機械担保）
6. **#811 / #874 接続境界の文書化**: promotion が必要な候補は #811 の審査契約へ接続（sub-gate、置き換えない）。入力は #874 RunEvidence adapter IF（`source_run_ids` / `baseline harness version` を candidate が保持 = #874 AC-7/AC-8 の consume 側）
7. **fixture（`tests/fixtures/ai-loop/evolution/` + `tests/extras/ta-NN`）**: WHERE 4 層（Prompt/Context/Harness/Loop）の代表候補 + 10 件以上の代表ケース + allowed_paths 交差 BLOCKED + privacy（raw transcript / hidden CoT 非要求）を CI 検証

### Out of scope（issue Non-goals verbatim + 棚卸しコメント）

- `design-philosophy.md` の invariants（承認境界、maker/checker 分離、決定的 adjudication、fail-safe、停止条件）の変更
- terminal decision の新設（既存 `AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED` を再利用）
- policy / HO / C-4 / first principles の変更の自動化（C-4 と merge は Human-owned 固定）
- PlanGate production WF-00〜07 の挙動変更
- 生の Session transcript、hidden CoT、秘密情報の学習資産としての保存
- モデルの自己書き換え、無制限の Skill / Hook 自動更新
- remote service / SaaS の必須化（Hermes / ai-second-brain 非依存で単体動作）
- #811 Memory Promotion Gate の置き換え（promotion sub-gate として接続のみ）
- limited canary の実適用（棚卸し順序 4 = 「根拠が得られた場合のみ」。本 PBI は shadow + replay 検証まで。自動適用は low-risk・reversible・boundary-clean・`allowed_paths` 内限定の原則のみ文書化）

## 受入基準（issue #869 Definition of Done verbatim・10 項目）

- AC-1: 内側の task loop と外側の evolution loop の責務・停止条件が区別されている
- AC-2: Hermes / ai-second-brain なしで PlanGate 単体動作する evidence contract が定義されている
- AC-3: raw transcript / hidden CoT を要求しない
- AC-4: Candidate / Experiment Result の schema、provenance、rollback が定義されている
- AC-5: 提案者と評価者が分離され、paired baseline、activation、regression が検証できる
- AC-6: 既存 terminal decision、C-4 / merge、production WF-00〜07 の境界を変更しない
- AC-7: #811 との責務境界と接続条件が文書化されている
- AC-8: 10 件以上の代表ケースで評価し、critical regression が 0 件である
- AC-9: Prompt / Context / Harness / Loop の代表候補を fixture で検証できる
- AC-10: 採用 / 修正 / 却下と理由を Trust Ledger または ADR に残せる

### In scope↔AC 対応（issue DoD に無いが In scope 実装物に紐づく検証条件）

- AC-11（In scope 5 対応）: candidate の `allowed_paths` が active run の `allowed_paths` と交差する場合、shadow 段階でも当該 candidate が `BLOCKED` になる機械チェックがあり、00_concept.md §4.1（active run harness 自己変更禁止）が担保される
- AC-12（In scope 3 対応）: WHERE（4 値）× WHY（10 値）enum が schema で正本化され、`observed_pattern` と `cause_hypothesis` がフィールド分離されている（enum 外の値は fail-closed で reject）

### In scope↔AC マッピング

| In scope | 対応 AC |
|----------|---------|
| 1 Gap analysis / harness-evolution-cycle.md | AC-1, AC-6 |
| 2 schema 2 本 | AC-4, AC-10 |
| 3 WHERE×WHY enum 正本化 | AC-12（+ AC-4） |
| 4 shadow 抽出 CLI evolution.py | AC-2, AC-3, AC-5 |
| 5 allowed_paths 交差 BLOCKED | AC-11（+ AC-6） |
| 6 #811/#874 接続境界 | AC-7 |
| 7 fixture 群 | AC-8, AC-9（+ AC-3 privacy 検証） |

### DoD / Close 条件（issue「検討したい論点」= C-3 論点として繰り越し）

issue 本文の 5 論点は pbi-input では確定せず C-3 / plan で確定する:

1. Trigger（`N completed runs` 主 vs 既存 retrospective schedule 統合）
2. candidate の位置づけ（`events.ndjson` 派生 artifact vs Reporting output 正式 schema）
3. Phase 1 自動適用範囲（docs-only vs lite 条件充足の downstream `allowed_paths`）— 本 PBI は shadow のみのため後続論点
4. #811 必須 promotion sub-gate の対象範囲
5. Trust Ledger（既存 record への optional fields vs 独立 experiment ledger）

## Notes from Refinement（調査で確定した設計方針）

- **HO 分岐（C-3 論点・#874 と同型）**: schema を issue たたき台どおり `schemas/` に置くと **HO patch（Human 適用）**が必要（`ho-paths.md` L28）。AI 主体で回すなら `docs/schemas/`（非 HO・前例 `child-pbi.yaml`）に契約文書として置き、機械検証は非 HO validator（`scripts/ai-loop/evolution.py` 側）が担う。**どちらを採るかを C-3 で確定**。#874 RunEvidence schema と**同じ側に揃える**（分裂させない）ことを推奨
- **CLI は `bin/plangate` 非改変**: issue たたき台 `plangate report --emit-candidates` は HO（`bin/plangate`）に触れるため、Phase 1 shadow は `scripts/ai-loop/evolution.py` 単体 CLI（非 HO・本番から呼ばれない隔離 PoC）とする。bin/plangate への sub-command 統合は canary 以降の後続（HO patch）
- **#874 consume 契約**: #874 pbi-input（main merge 済み・commit 8b21555）の In scope 8「#869/#811 接続 adapter IF」が本 PBI の入力。candidate は `source_run_ids` と `baseline harness version` を保持（#874 AC-7/AC-8 の受け側）。#874 の producer / `harness_version` 供給は未実装（`rg harness_version scripts/` 0 件・実測）のため、evolution.py は **RunEvidence fixture 駆動**で先行実装し、#874 実装後に実 record へ接続
- **既存 record との関係**: 現行 arbiter record 28 件（legacy 9 キー / run メタ 14 キー世代混在）は補助入力。`metrics.py` の legacy/invalid/skip 明示区分（fail-silent 禁止）パターンを踏襲
- **frictions-digest との関係**: `frictions-digest-001.md`（F-1〜F-24 手動状態表）は candidate 抽出の**手動前例**であり、本 PBI の機械可読 candidate 契約に置き換えられるのではなく、shadow 出力の妥当性検証（人手ダイジェストとの突合）素材として利用可能
- **提案者/評価者分離の既存部品**: #811 promotion sub-gate、#753 rubric grader を verifier 部品として再利用（棚卸しコメント verbatim・再実装しない）。paired replay / activation check / sealed regression set は fixture で契約検証（実 canary は後続）
- **growth-core 改善系スキルとの責務重複なし**: repo 取り込みスキルの衝突管理は `docs/ai/skill-collision-detection.md` に正本があり、evolution 責務のスキルは取り込まれていない（実測）。growth-core plugin 側の改善系スキル（agent-self-improvement / engineering-process-improvement / retrospective-improvement）は**人間主導のセッション振り返り・プロセス改善 PR 化**が責務で、本 PBI の機械可読 candidate 契約・shadow 抽出（決定論 CLI）とは責務が重複しない
- **正本の置き場**: 内側/外側の区別・active run harness 自己変更禁止は 00_concept.md §4.1 が既定。`harness-evolution-cycle.md` は§4.1 を参照する外側ループの詳細正本とし、重複定義しない（issue たたき台の `docs/ai/ai-loop/harness-evolution-policy.md` を独立させるかは plan で確定）

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| schema HO 分岐（`schemas/` vs `docs/schemas/`）で #874 と配置が分裂 | C-3 で #874 と同側に確定 | docs/schemas/ + 非 HO validator（AI 完結）|
| #874 RunEvidence 未実装で入力契約が動かない | RunEvidence fixture 駆動で先行実装（#874 完了を待たない） | adapter IF はフィールド契約まで・実接続は #874 実装後 |
| shadow のつもりが適用系に踏み込む（§4.1 違反） | evolution.py を read-only 決定論 CLI に固定 + allowed_paths 交差 BLOCKED（AC-11）+ ソースに書き込み経路なしのテスト | 生成物は `docs/working/` 配下 candidate record のみに限定 |
| 「10 件以上の代表ケース」（AC-8）の素材不足 | 完了 Run record 28 件（実測）+ frictions-digest F-1〜F-24 から代表ケース抽出 | 不足分は synthetic fixture（決定論・issue の非決定挙動記録規律に従う）|
| privacy 違反（raw transcript / hidden CoT 混入） | privacy fixture で機械検証（AC-3）+ metrics-privacy.md 4 層強制の既存枠 | evidence は参照（run_id / F-ID）のみ・本文非保存 |
| #811 未実装で promotion 接続が検証不能 | 接続「条件」の文書化まで（AC-7 は文書化が要求水準・issue verbatim） | promotion 実接続は #811 実装後の後続 |

### Unknowns

- schema 配置先（`schemas/` HO vs `docs/schemas/` 非 HO・#874 と同側）→ **C-3 で確定**
- Trigger / candidate 位置づけ / Trust Ledger 形式（issue 論点 1・2・5）→ C-3 / plan で確定
- `harness-evolution-policy.md`（docs/ai/ai-loop/ 側）を独立文書にするか harness-evolution-cycle.md に集約するか → plan で確定
- clustering の粒度（WHERE×WHY の組をキーにした決定論 group-by で足りるか、類似度判定が要るか）→ plan で確定（Phase 1 は決定論 group-by を推奨・LLM 判定は shadow で不使用）

### Assumptions

- 新設: `evolution.py` + test + schema 2 本（配置先は C-3）+ WHERE×WHY enum + `harness-evolution-cycle.md` + fixture 群（`tests/fixtures/ai-loop/evolution/` + `tests/extras/ta-NN`、ta-55 様式）。既存正本（00_concept.md §4.1 / reporting.md / design-philosophy.md invariants）は変更しない
- **Mode: critical で確定**（`mode-classification.md` 定量基準の機械判定: **受入基準数 = issue DoD verbatim 10 + In scope 対応 2 = 12 → 11+ で超高（critical）が決定論**。変更ファイル数は schema 2 + evolution.py + test + workflow 正本 + fixture 複数 + ta-NN で 6-15（高）〜16+、「各軸の最大値を採用」で critical 確定）。**autonomous APPROVE 不可・人間 C-3 必須・V-4 リリース前チェック要**。事前調査の「high-risk 見込み」は AC 数の機械判定で critical へ更新（hedge しない）。schema を `schemas/` に置く場合は **Hardening Override 発火**（lite_eligible 無効化・Standard 同期 C-3・HO patch の Human 適用）が追加で確定
