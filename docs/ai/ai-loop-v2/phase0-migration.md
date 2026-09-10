# ai-loop V2 Phase 0 — Freeze / Migration Matrix

> **Status**: Phase 0 **MERGED**（PR #1273・Human C-4 DONE）/ Independent Review **DONE（R1 I1 ×2 + R2 I1 / `reviewed_at_sha` = `f8f1e8b8`。§7 が正本）** / Phase 0.1 **CANON_HARDENING**（#1275）
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

### 判定主体と判定手順

許可・不許可の列挙だけでは、同じ変更が「security fix」とも「V2 専用 verifier の本実装」とも読める。**どちらに当たるかを誰がどの手順で決めるかを次に固定する。**

| 役割         | 担当                | 責務                                                                                                        |
| ------------ | ------------------- | ----------------------------------------------------------------------------------------------------------- |
| 分類の提案   | AI（Plan 作成者）   | 当該変更が上記のどの許可カテゴリに当たるか、および「V2 側で実装しない理由」を **Plan に明示**する            |
| 例外の承認   | **Human（C-3 ゲート）** | freeze 例外の可否を裁定する。**AI は自分の Plan の freeze 例外を自分で承認できない**（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §1 と同じ趣旨） |
| 適用の確認   | Human（C-4）        | merge 時点で、実差分が承認した例外カテゴリの範囲に収まっているかを確認する                                   |

判定手順:

1. Plan に **freeze 例外の申告**（対象 Legacy 資産 / 許可カテゴリ / V2 側で実装しない理由 / 範囲）を書く。
2. Human が C-3 で可否を裁定する。**分類が両解釈可能なときは不許可側（V2 で実装する）を既定**とする（fail-closed）。
3. 承認した例外カテゴリと範囲を、当該 Plan と本 §2 の実例表に残す。

判定不能・未申告の変更は Legacy に入れない。

#### freeze 例外の承認は autonomous APPROVE の対象にしない

上表の「例外の承認 = Human（C-3 ゲート）」は、**AI が C-3 を自己承認する経路を含まない**。`.claude/rules/working-context.md` の **C-3 Autonomous APPROVE**（自律実行指示下で、mode が standard 以下かつ Hardening Override 対象パスを含まない場合に AI が C-3 を自己承認できる規定）は、**本 §2 の freeze 例外には適用しない**。

- 理由: 本 §2 の承認は「AI は自分の Plan の freeze 例外を自分で承認できない」を前提に置いている（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §1 と同じ趣旨）。autonomous APPROVE を許すと、この前提が承認主体の入れ替えによって成立しなくなる。
- 対象 Legacy 資産が **Hardening Override 9 カテゴリに含まれない場合でも同じ**。実例 #916 の対象 `scripts/ai-loop/arbiter.py` は HO の `scripts/hooks/*.sh` に当たらないため既存ルールだけでは autonomous APPROVE の適用余地があるが、本節によりその余地を V2 canon 側で閉じる。
- 本節は `.claude/rules/working-context.md` の規定を**変更・緩和しない**。既存ルール（AC-10 Hardening Override 優先を含む）はそのまま働き、本節は freeze 例外という限定領域に**追加の制約を課す**のみである（緩める方向の例外を作らない）。`.claude/rules/` は Hardening Override 対象であり、本 canon から変更しない。

### 実例: #916

| 論点         | 判定                                                                                                                                                              |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 対象         | Legacy C-3' arbiter への carve-out 機械層配線（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §2）                                              |
| 許可カテゴリ | **security fix / migration・compatibility support**。arbiter が自分の判定基盤を auto-approve 経路で改変しうる構造的盲点を塞ぐため                                 |
| 不許可カテゴリに当たらない理由 | 配線するのは **Legacy arbiter の既存 escalate 経路への carve-out 適用**であり、V2 の Policy Gate / Evaluation Trust Boundary の**本実装ではない**。V2 側は同じ protected surface 定義を再利用するだけで、Legacy 実装を V2 正本にしない |
| 承認         | 本 §2 の判定手順に従い Human C-3 で裁定する（未裁定のまま着手しない）                                                                                            |

[`taxonomy.md`](./taxonomy.md) §7 の「C-3' arbiter の Legacy 実装は変更しない」は **V2 taxonomy を Legacy 実装へ逆輸入しない**（語彙・state 機械の書き換えをしない）という意味であり、本 §2 が定める freeze 例外（security fix 等）を禁じるものではない。2 つの記述はこの限定で読む。

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
10. `RunEvent stream`（Phase 0.1 で追加。[`artifact-responsibilities.md`](./artifact-responsibilities.md) §3 が「正本は event stream。RunEvidence は再生成可能なキャッシュ」と宣言しており、**budget 外に置くと Phase 1 が正本を budget 外 artifact として定義せざるを得なくなる**ため budget に含める。V2 RunEvent 型の定義は Phase 1。Legacy schema へ V2 event 型を追加しない点は同 §3）

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
- [x] North Star / migration docs の独立レビュー — 別 context / role の checker による **I1 以上の記録**を得た（実装 Agent 自身のレビューは独立レビューに数えない = Independence Level I0。[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §4）
  - `reviewed_at_sha`: **`f8f1e8b85982642a467bdce712daedce65568c23`** — 記録: [`docs/working/_reports/1275-phase0-01-independent-review.md`](../../working/_reports/1275-phase0-01-independent-review.md)（**R1 / R2 の 2 ラウンドを含む**）
  - 充足の根拠: **R1**（`2950d358` / I1 ×2 = docs 整合・敵対 / 2026-09-07）→ 是正 **PR #1300**（merged 2026-09-07、merge commit `62e4ab93`）→ **R2**（`2950d358..62e4ab93` / I1 / R1 の**是正そのものを疑う** role）→ 是正 **PR #1301**（merged 2026-09-07、merge commit `f8f1e8b8`）。Human C-4 = Human による merge 操作（[`1275-phase0-01-evidence-audit.md`](../../working/_reports/1275-phase0-01-evidence-audit.md) §3 の定義）は #1300 / #1301 の両方で完了している
  - 収束判定と打ち切りの根拠（回避クラス台帳 / 残存脅威モデル）は記録 §6 / §7。**完全性は主張しない**（I2 未実施 / canon 自身が要求する I3・I4 に未達 / Phase 1 実装の妥当性は未検証）

### 独立レビュー記録の要求（`reviewed_at_sha`）

canon は Phase 0 baseline 以降も更新されるため、「独立レビュー済み」は **どの SHA を見たレビューか**と対で記録しないと意味を持たない（本節の Baseline は**作成時 baseline** であってレビュー済み SHA ではない）。

- 独立レビューを記録する際は、**レビュー対象の commit SHA を `reviewed_at_sha` に必ず書く**。SHA の無いレビュー記録は exit criteria を充足しない。
- 記録後に canon が更新された場合、`reviewed_at_sha` と HEAD の差分が**レビュー範囲外**であることを明示する（差分がレビュー対象の主張に触れるなら再レビュー）。
- `README.md` / `north-star.md` の Status 行の「Independent Review PENDING」表記は索引であり、充足判定の正本は本節の `reviewed_at_sha` 欄とする。
- **`reviewed_at_sha` = `f8f1e8b8` 以降の差分（レビュー範囲外の明示）**: 本節の充足記録（チェックボックス・充足の根拠・本ノート）と [`docs/working/_reports/1275-phase0-01-independent-review.md`](../../working/_reports/1275-phase0-01-independent-review.md) の R2 記録追記のみ。**canon の規定内容そのものは変更していない**ため再レビューを要さない。以後 canon の規定を変更した場合は、その差分がレビュー範囲外であることを本欄に追記するか、再レビューを行う。

  **追記（2026-09-10）**: 上記の記載は `283caea6`（#1321）で stale になった。`f8f1e8b8` 以降に canon 7 本へ入った変更は、実測で次の 2 commit である。

  ```sh
  git log --oneline f8f1e8b8..origin/main -- \
    docs/ai/ai-loop-v2/README.md docs/ai/ai-loop-v2/north-star.md \
    docs/ai/ai-loop-v2/phase0-migration.md docs/ai/ai-loop-v2/taxonomy.md \
    docs/ai/ai-loop-v2/harness-manifest.md \
    docs/ai/ai-loop-v2/evaluation-trust-boundary.md \
    docs/ai/ai-loop-v2/artifact-responsibilities.md
  # 283caea6 (#1321) / b1217b41 (#1302)
  ```

  | commit | canon への変更 | レビュー範囲外の理由 |
  | --- | --- | --- |
  | `b1217b41`（#1302） | 本節の充足記録 + R2 記録追記 | 上記のとおり規定内容は不変 |
  | `283caea6`（#1321） | `README.md` に **+5 −3**。索引行 1 本（`loop-graph-harness.md` への導線）と、Loop / Graph / Harness の責務分離を述べる 1 文の追記 | **索引と要約であって規定ではない**。追加された [`loop-graph-harness.md`](./loop-graph-harness.md) 自身が「canon ではなく従属する解釈ガイド」と自己宣言しており、**canon 7 本には加えない**。したがって再レビューを要さない |
  | 本 PR（#1275 決着記録） | 本節「Human 判断事項」に決着（選択肢 (b)）と I4 移行条件を追記 | **レビュー範囲外にしない**。規定の追加にあたるため、本節の I1 要求（上記「決定」で例外として明示した水準）の対象とし、本 PR 自身が I1 レビューと Human C-4 を経る。merge 後に本表へ merge commit SHA を追記する |

### Phase 0.1 exit criteria（#1275 / Canon Hardening）

各項目の根拠は、その項目が**何によって達成されるか**で書き分ける（docs の新規作成は docs PR のマージで達成できるが、GitHub 上の Issue body 更新は docs PR のマージでは原理的に達成できない）。

- [x] Lifecycle State / Terminal Outcome / Stop Reason / Policy Verdict の 4 軸 taxonomy を正本化（[`taxonomy.md`](./taxonomy.md)）（根拠: PR #1276 で当該 docs を追加）
- [x] HarnessManifest の責務・最低フィールド・RunEvidence binding・Runtime Activation 6 段階を定義（[`harness-manifest.md`](./harness-manifest.md)）（根拠: PR #1276 で当該 docs を追加）
- [x] Evaluation Trust Boundary / Independence Level / `INCONCLUSIVE` / pre-registration を invariant 化（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md)）（根拠: PR #1276 で当該 docs を追加）
- [x] artifact 責務分離 / RunEvidence = event projection / RunState revision CAS を固定（[`artifact-responsibilities.md`](./artifact-responsibilities.md)）（根拠: PR #1276 で当該 docs を追加）
- [x] Initial Plan Verification / Plan Gate を Delivery canonical flow へ追加（`north-star.md` §2 / §9 / §17）（根拠: PR #1276 で `north-star.md` を更新）
- [x] #870 / #894 / #869 / #874 / #916 / #1025 を GitHub 上で rebaseline（根拠: **6 issue の body 更新を確認**（2026-09-05 / #1275）。docs PR のマージでは達成されない証跡種別であり、PR #1276 を根拠にしない）
- [x] Phase 0.1 docs PR の別 context / role によるレビューと Human C-4
  - `reviewed_at_sha`: **`f8f1e8b85982642a467bdce712daedce65568c23`** — 記録: [`docs/working/_reports/1275-phase0-01-independent-review.md`](../../working/_reports/1275-phase0-01-independent-review.md)（**R1 / R2 の 2 ラウンドを含む**）
  - **(a) 別 context / role によるレビュー**: R1（I1 ×2 / `2950d358`）と R2（I1 / `2950d358..62e4ab93` / 是正そのものを疑う role）。R2 は §7-quater が求める「2 ラウンド目以降の焦点」に沿い、major 4 + minor 4 を検出して #1301 で是正済み
  - **(b) Human C-4**: [`1275-phase0-01-evidence-audit.md`](../../working/_reports/1275-phase0-01-evidence-audit.md) §3 で確定した定義（**Human による merge 操作**。独立性は別項目 = I1 以上のレビュー artifact で担保）に照らし、#1300 / #1301 の merge をもって**充足**
  - 本項の充足は**既にマージ済みの #1300 / #1301** を根拠にする。記録を更新する PR 自身のマージを充足根拠にしない

Phase 0 の独立レビューと Phase 0.1 の全項目が満たされるまで Phase 1 実装を開始しない。Phase 0.1 の PR は MERGE_READY で停止し、Phase 1 へ自動的に進まない。

### Human 判断事項（2026-09-10 決着 / 選択肢 (b) を採用）

**canon docs 自体に要求する Independence Level を I1 のままにするか、I4 へ引き上げるか。**

#### 決定（2026-09-10 / Human）

**選択肢 (b) を採用する。** canon 7 本は「**それを強制する実行系をまだ持たない仕様文書**」であることを理由に、独立レビュー要求 **I1** を [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §3（Evaluation Harness そのものの変更は I4 でのみ採用する）の **明示的な例外**として認める。

- **§3 の規定そのものは変更しない。** 本例外は §3 を弱めるものではなく、**canon 7 本の独立レビュー要求という 1 点にのみ**及ぶ。`protected_surfaces` / Protected authority / Promotion Decision の値域など §1〜§5 の規定内容には及ばない。
- 例外は**期限ではなく条件で切れる**（下記「I4 移行条件」）。日付での自動失効は置かない。

**なぜ現時点で例外が成り立つか（例外の根拠）**:

- §3 の I4 要求は「Candidate が**自分を裁く評価系を変えて採用判定を動かす**」ことを防ぐためのものである。裁定を実行する主体（paired replay / grader / stable meta-verifier / HarnessManifest 生成器 / 実差分算出器）が repo に存在しない間は、canon 7 本の変更によって動かせる**採用判定が存在しない**。したがって §3 が防ごうとしている実害が、この期間には発生しない。
- 現時点で canon 7 本を強制する実行系は無い（下記 M-1 / M-2 / M-3 の実測がすべて baseline）。この期間の canon 変更を守っているのは **Human C-4 merge と I1 レビュー**であり、これは §3 が想定する「評価系の自己改変」経路ではない。
- ただしこれは「**I1 で十分である**」という主張ではなく「**I4 が防ぐ対象がまだ存在しない**」という主張である。対象が現れた時点で例外は成り立たなくなる（下記）。

#### I4 移行条件（例外が切れる条件・判定可能）

M-1 / M-2 / M-3 の **いずれか 1 つでも baseline から動いた時点**で本例外は失効し、**以後の canon 7 本の規定変更は I4（Human + machine independent evidence）を要求する**。「実装が入ったら」という主観判定ではなく、下記コマンドの出力が baseline と一致するか否かで測る。

| ID      | 条件（何が入ったら例外が切れるか）                                                            | baseline（`9f1b9f63` 実測）                  |
| ------- | --------------------------------------------------------------------------------------------- | -------------------------------------------- |
| **M-1** | canon 由来の schema が `schemas/` に入る（HarnessManifest / LoopContract / RunState）         | 出力なし                                     |
| **M-2** | V2 実行系の namespace が repo に出現する（`scripts/ai-loop-v2` / `bin/ai-loop-v2`）           | 出力なし                                     |
| **M-3** | canon 固有語彙が実行系ファイル（`scripts` / `bin` / `schemas` / `.github/workflows`）に現れる | `scripts/ai-loop/corpus_hash.py` の 1 本のみ |

判定コマンド（3 条件を一括で測る）:

```sh
echo "== M-1 =="; ls schemas/ | grep -Ei 'harness|loop-contract|run-state|runstate' || echo "(none)"
echo "== M-2 =="; ls -d scripts/ai-loop-v2 bin/ai-loop-v2 2>/dev/null || echo "(none)"
echo "== M-3 =="; git grep -lE 'HarnessManifest|harness_id|distribution_digest|protected_surfaces|independence_level|LoopContract' -- scripts bin schemas .github/workflows | sort
```

判定規則:

- **M-3 の baseline 1 本（`scripts/ai-loop/corpus_hash.py`）は Legacy 側の説明コメントであって canon の強制ではない**ため baseline に含める。新たに現れたファイルが説明コメントのみであると判断する場合は、その根拠を本欄に追記したうえで baseline を更新してよい。**判断できない場合は失効側（I4 要求）に倒す**（fail-closed。安全側は「例外を切る」側である）。
- M-3 の語彙から `RunEvidence` を意図的に外している。Legacy の RunEvidence 実装（#874 / `scripts/ai-loop/run_evidence.py` 他）が既に存在し、常時ヒットして検出力を失うためである。Legacy `scripts/ai-loop/**` は §2 freeze policy 下にあり、canon 7 本の強制ではない。
- **失効は遡及しない。** Phase 0 / Phase 0.1 の充足記録（I1）は当時の規定に照らして有効なまま残す。失効時点で必要なのは、(1) **その後の** canon 規定変更に I4 を課すこと、(2) Phase 1 の exit criteria に「canon 7 本の I4 レビュー」を 1 項目として立てること、の 2 つである。
- 再測定のタイミングは、**§8 の Phase 1 Architecture / Contract design 着手時に 1 回**、および **canon 7 本を変更する PR ごと**。
- 本決定は #1275 の close 条件を満たすためのものであり、失効時に必要な作業は follow-up issue として別途起票する（本 §7 は起票先の番号を後追いで記載してよい）。

#### 経緯（決着前の記録・そのまま保存する）

> 以下は決着前（2026-09-10 より前）の記述であり、**上記「決定」に置き換わっている**。当時の論点を追えるように改変せず残す。

- [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §1 は `protected_surfaces` 定義と HarnessManifest 生成器を Protected authority に列挙し、同 §3「後退の終端」は **Evaluation Harness そのものの変更は I4 でのみ採用する**と定めている。
- 本 §7 の canon 7 本（`README.md` / `north-star.md` / `phase0-migration.md` / `taxonomy.md` / `harness-manifest.md` / `evaluation-trust-boundary.md` / `artifact-responsibilities.md`）は、まさにその Evaluation Harness の**定義そのもの**である。にもかかわらず上記 exit criteria は **I1 以上**しか要求していない（自分が課す基準の最低段を自分に適用している）。
- 取りうる選択肢: (a) canon docs の独立レビュー要求を **I4** へ引き上げる / (b) canon docs は「実装されていない仕様文書」として**明示的に例外**とし、その根拠と、実装が入る時点で I4 へ移行する条件を書く。
- **本項は Human 判断（AI は決めない）**。決着するまで、上記 exit criteria の I1 要求は**暫定**であり、充足しても本項の未決を解消しない。
- **2 ラウンド（R1 / R2）を経ても本項は未決のまま**である。R2 のレビュアー自身が「本差分は Evaluation Harness の定義そのものであり、canon が自ら課す I3 / I4 の下限を本レビューは満たしていない」と申告しており（[記録](../../working/_reports/1275-phase0-01-independent-review.md) §5-0 / §7-2）、**ラウンドを重ねても解消しない構造**である。上の exit criteria 2 項目のチェックは「**暫定の I1 要求**を満たした」ことの記録であって、本項を決着させたものではない。

## 8. Next phase

Phase 1 は実装ではなく **V2 Architecture / Contract design** から開始する。

最初に決めるもの:

- LoopContract schema / semantic contract
- Delivery State Machine（[`taxonomy.md`](./taxonomy.md) の 4 軸を前提）
- **Candidate 評価 Run（Evolution Loop）の進行・終端表現** — Lifecycle State / Terminal Outcome を持つか否か、持つ場合の値域。および `HUMAN_REQUIRED` 後の待ち状態を Evolution 側でどう表すか（[`taxonomy.md`](./taxonomy.md) §1 が本項へ委譲している）
- Verifier pipeline / blocking rule
- Decision Engine / Progress / Stop reason
- Repair vs Replan
- RunState（revision CAS）/ RunEvidence（event projection）/ HarnessManifest binding
- Evaluation Trust Boundary の機械層（protected surface 定義・Independence Level の surface 別 threshold）
- ai-dev adapter boundary
- 本 Phase 0.1 の negative example を `tests/extras/` fixture 化（[`taxonomy.md`](./taxonomy.md) §8 / [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §7）

Evolution 実装は Delivery E2E (`FAIL -> Diagnose -> Repair -> PASS -> MERGE_READY` + `NO_PROGRESS -> STOP`) の成立後に開始する。
