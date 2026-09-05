# ai-loop V2 Phase 0 — Freeze / Migration Matrix

> **Status**: Phase 0 **MERGED**（PR #1273・Human C-4 DONE）/ Independent Review **PENDING（separate checker required）** / Phase 0.1 **CANON_HARDENING**（#1275）
> **North Star**: [`north-star.md`](./north-star.md)
> **Baseline**: Phase 0 `main@9f7bac9f62dccc057be5ae58570dcb65a4acbec8` / Phase 0.1 `main@1e95e8a`

## 1. Phase 0 decision

ai-loop V2 は既存 ai-loop の追加改修として作らない。

- `ai-dev-workflow`: Stable。利用者向け契約は維持する。
- existing `ai-loop`: Legacy / PoC。新規機能は原則追加しない。
- `ai-loop V2`: `docs/ai/ai-loop-v2/` を思想・移行正本の新 namespace とし、Verifier-driven Delivery Loop + Evidence-driven Evolution Loop として再構築する。

既存 ai-loop は削除しない。実装・契約・失敗履歴を Evidence として再利用する。

## 2. Legacy freeze policy

Legacy ai-loop に許可する変更:

- security fix
- critical bug fix
- migration / compatibility support
- V2 移行に必要な観測・説明の追加

原則として Legacy ai-loop に追加しないもの:

- 新しい autonomy model
- 新しい C-3' eligibility 拡張
- 新しい Evolution 機能
- V2 専用 state / contract / verifier の本実装
- 新しい主要 orchestration stage

例外を入れる場合は、V2 North Star に照らして「Legacy に入れる必要」を Plan に明示する。

## 3. Classification rule

| Classification | Meaning |
|---|---|
| **KEEP** | V2 の中核要件として概念・契約を継承する |
| **ADAPT** | 問題設定・Evidence は継承するが V2 責務へ合わせ再設計する |
| **SUPERSEDE** | 現行 ai-loop 固有構造を前提としており、V2 の新契約で置き換える |
| **DEFER** | 有用だが V2 Delivery MVP の critical path 外。後段へ送る |
| **LEGACY EVIDENCE** | 完了済み/既存実装を新正本にせず、fixture・pattern・失敗履歴として再利用する |

`SUPERSEDE` は即 close を意味しない。V2 側の replacement が main に入るまでは回帰・移行の参照元として保持する。

## 4. Issue migration matrix

### V2 Core / Delivery critical path

| Issue | Class | V2 treatment |
|---|---|---|
| #870 ai-loop vNext EPIC | **ADAPT → REBASELINED（Phase 0.1）** | V2 親 EPIC として本文を全面 rebaseline。Verifier-driven Delivery + Evidence-driven Evolution + Self-Evolving Harness を中核、C-3' は optional autonomy / policy profile。旧本文は Legacy Evidence として Issue 内に保持 |
| #894 Loop Control Contract | **KEEP PROBLEM / ADAPT CONTRACT** | Verifier hierarchy / budget / progress / stop の問題設定は KEEP。単一 `LoopControlContract` は LoopContract / RunState / VerificationResult / FailureRecord / Decision Engine / RunEvidence へ分解（[`artifact-responsibilities.md`](./artifact-responsibilities.md) §2） |
| #1025 Durable Run State | **KEEP + CONCURRENCY HARDENING** | RunState / intent-receipt / resume を V2 core として利用。revision CAS / concurrent resume / `STATE_CONFLICT` を追加（同 §4） |
| #874 RunEvidence | **KEEP + REBASELINE** | producer contract は KEEP。`harness_version` → `harness_manifest_ref`、RunEvidence = deterministic event projection、非完了 Run も Evolution input（同 §3） |
| #916 arbiter self-protection | **KEEP → Evaluation Trust Boundary へ昇格** | 局所 carve-out から `Candidate cannot modify the authority that judges the candidate` の Legacy 実例へ（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §2） |
| #1029 rollback execution | **ADAPT** | C-3' 固有 rollback としてではなく V2 stop / recovery / external decision rollback の pattern として再設計 |
| #1241 task_id portability | **KEEP** | V2 Core の portability / external task identity 契約へ取り込む。`TASK-XXXX` 固定を V2 正本にしない |

### Verification / Eval

| Issue | Class | V2 treatment |
|---|---|---|
| #908 Run / Trajectory Eval | **KEEP** | Delivery/Evolution 評価の共通 Eval profile へ |
| #909 Executable Regression Set | **KEEP** | V2 regression / held-out / sealed eval の土台へ |
| #910 grader calibration / drift | **KEEP** | independent model reviewer の校正・drift 監視へ |
| #1124 verifier detection power | **KEEP** | PASS 数ではなく検出力を測る V2 verifier quality へ接続 |

### Evolution

| Issue | Class | V2 treatment |
|---|---|---|
| #869 Run Retrospective / Harness Evolution | **KEEP + REBASELINE** | V2 Evolution Loop の中核。Skill / Agent / Flow / Verifier の CREATE / UPDATE / SPLIT / MERGE / DEPRECATE を正式対象化。Legacy inner-loop / `AUTO_APPROVED` 中心の表現と V2 canonical flow を区別（Promotion Decision に `INCONCLUSIVE`） |
| #811 Memory Promotion Gate | **ADAPT / SUB-GATE** | Promotion 対象が Rule/Skill等の場合の sub-gate。V2 Evolution 全体の owner にはしない |

### Autonomy / policy

| Issue | Class | V2 treatment |
|---|---|---|
| #1035 HOITL → HOTL ladder | **ADAPT** | 自律度 rollout / measurement は継承。ただし V2 Core と C-3' eligibility を分離し、Delivery E2E 完成後に再baseline |
| #1059 changed_files / size_ok | **SUPERSEDE** | current lite/C-3' eligibility の構造問題。V2 では autonomy profile の問題として扱い、Delivery Loop の成立条件にしない |
| #1197 no-task startup circularity | **SUPERSEDE + REGRESSION** | V2 Plan-first bootstrap が解消すべき構造的回帰 fixture として保持。旧経路の局所修正を V2 core に持ち込まない |

### Adjacent / distribution / harness prerequisites

| Issue | Class | V2 treatment |
|---|---|---|
| #1232 ai-dev plugin resources | **DEFER / SEPARATE** | ai-dev Stable の配布品質問題。V2 のために ai-dev public contract を変更しない |
| #1144 enforcement distribution | **DEFER / PREREQUISITE** | V2 plugin E2E 前に必要。ただし Delivery state machine の設計と分離 |
| #1135 AI-owned lane / hook friction | **DEFER / INPUT** | Harness usability / governance friction の Evidence として利用。V2 core contractへ直結させない |
| #911 Intent-to-Execution Context Contract | **ADAPT / DEFER** | Context boundary と handoff の設計入力。Delivery MVP の critical path から外し、Phase 1 Architecture で gap analysis |

### Completed legacy assets

| Asset | Class | V2 treatment |
|---|---|---|
| #871〜#873 | **LEGACY EVIDENCE** | Plan-first / C-3' binding / PR convergence の成功・失敗 pattern を再利用。V2 正本にはしない |
| #917 | **LEGACY EVIDENCE** | GitHub collector / intent-receipt / reconciler の pattern を adapter 設計へ再利用 |

## 5. Document / code asset migration

### KEEP as philosophy / evidence

- `docs/ai/ai-loop/design-philosophy.md`
  - maker/checker separation
  - deterministic adjudication
  - fail-safe defaults
  - self-protection / Human-owned boundary
- `docs/workflows/ai-loop/run-evidence-contract.md`
- `docs/workflows/ai-loop/delivery-state-machine.md`
- `docs/workflows/ai-loop/review-feedback-loop.md`
- `docs/workflows/ai-loop/loop-safety-gates.md`
- existing RunEvidence / intent-receipt / PR convergence fixtures

These are inputs to V2 design; they are not automatically V2 canon.

### ADAPT

- `docs/workflows/ai-loop/loopspec.md`
  - special user-authored LoopSpec から、Plan Package から導出される internal `LoopContract` へ再設計
- `scripts/ai-loop/` state / verifier / evidence implementations
  - monolithic cycle ではなく Contract / State / Verify / Decide / Diagnose / Repair / Replan / Evidence へ責務分離
- `ai-loop-cycle` skill
  - V2 orchestration を単一巨大 skill として再現しない。役割・adapter境界を再設計

### SUPERSEDE as V2 identity

- C-3' eligibility を ai-loop の中心定義とする構造
- `lite` / `size_ok` が Delivery Loop の実行可能性を決める構造
- `AUTO_APPROVED` を loop success と同一視する構造
- user-facing ai-loop command が user-facing ai-dev command を直接 chain する構造

### PRESERVE / DO NOT MUTATE during Phase 0

- `ai-dev-workflow` public command/skill contract
- Human C-3 behavior in ai-dev
- `PR_CREATED` terminal contract in ai-dev
- C-4 / merge Human ownership
- HO / approval / permission / security first principles

## 6. V2 artifact budget

Phase 1 では正本 artifact を無制限に増やさない。初期候補を以下に限定する。

1. `LoopContract`
2. `RunState`（Phase 0.1: `harness_manifest_ref` を additive に追加）
3. `VerificationResult`
4. `FailureRecord`
5. `RunEvidence`（Phase 0.1: `harness_manifest_ref` を additive に追加。event projection として再定義）
6. `HarnessImprovementCandidate`（Phase 0.1: evaluation plan digest を additive に追加）
7. `HarnessExperimentResult`（Phase 0.1: `baseline_manifest_ref` / `candidate_manifest_ref` を additive に追加）
8. `PromotionDecision`
9. `HarnessManifest`（Phase 0.1 で追加。独立 artifact とする根拠は [`harness-manifest.md`](./harness-manifest.md) §5）

各 artifact の責務境界は [`artifact-responsibilities.md`](./artifact-responsibilities.md)。新 artifact を追加する Plan は、既存 artifact へ additive に表現できない理由を North Star review で説明する。

## 7. Phase 0 exit criteria

- [x] V2 North Star の専用 namespace を作成
- [x] `ai-dev-workflow` Stable / unchanged 方針を固定
- [x] Legacy ai-loop Freeze policy を固定
- [x] Delivery Loop と Evolution Loop の責務を分離
- [x] Skill / Agent / Flow / Verifier を Evolution の正式対象に含める
- [x] Reuse Before Create / simplification を原則化
- [x] Human-owned / active-run immutability を固定
- [x] 主要 ai-loop Issue を KEEP / ADAPT / SUPERSEDE / DEFER / LEGACY EVIDENCE に分類
- [x] V2 初期 artifact budget を固定
- [x] Human C-4 で Phase 0 docs PR を merge（PR #1273、2026-09-05）
- [ ] North Star / migration docs の独立レビュー — **PENDING**。実装 Agent 自身のレビューは独立レビューに数えない（Independence Level I0。[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §4）。別 context / role の checker による I1 以上の記録を要する

### Phase 0.1 exit criteria（#1275 / Canon Hardening）

- [ ] Lifecycle State / Terminal Outcome / Stop Reason / Policy Verdict の 4 軸 taxonomy を正本化（[`taxonomy.md`](./taxonomy.md)）
- [ ] HarnessManifest の責務・最低フィールド・RunEvidence binding・Runtime Activation 6 段階を定義（[`harness-manifest.md`](./harness-manifest.md)）
- [ ] Evaluation Trust Boundary / Independence Level / `INCONCLUSIVE` / pre-registration を invariant 化（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md)）
- [ ] artifact 責務分離 / RunEvidence = event projection / RunState revision CAS を固定（[`artifact-responsibilities.md`](./artifact-responsibilities.md)）
- [ ] Initial Plan Verification / Plan Gate を Delivery canonical flow へ追加（`north-star.md` §2 / §9 / §17）
- [ ] #870 / #894 / #869 / #874 / #916 / #1025 を GitHub 上で rebaseline
- [ ] Phase 0.1 docs PR の別 context / role によるレビューと Human C-4

Phase 0 の独立レビューと Phase 0.1 の全項目が満たされるまで Phase 1 実装を開始しない。Phase 0.1 の PR は MERGE_READY で停止し、Phase 1 へ自動的に進まない。

## 8. Next phase

Phase 1 は実装ではなく **V2 Architecture / Contract design** から開始する。

最初に決めるもの:

- LoopContract schema / semantic contract
- Delivery State Machine（[`taxonomy.md`](./taxonomy.md) の 4 軸を前提）
- Verifier pipeline / blocking rule
- Decision Engine / Progress / Stop reason
- Repair vs Replan
- RunState（revision CAS）/ RunEvidence（event projection）/ HarnessManifest binding
- Evaluation Trust Boundary の機械層（protected surface 定義・Independence Level の surface 別 threshold）
- ai-dev adapter boundary
- 本 Phase 0.1 の negative example を `tests/extras/` fixture 化（[`taxonomy.md`](./taxonomy.md) §8 / [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §7）

Evolution 実装は Delivery E2E (`FAIL -> Diagnose -> Repair -> PASS -> MERGE_READY` + `NO_PROGRESS -> STOP`) の成立後に開始する。
