# Evaluation Trust Boundary — Candidate は自分を裁く authority を変更できない

> **Status**: Phase 0.1 canon（#1275）
> **North Star**: [`north-star.md`](./north-star.md) §5 / §6 / §13 / §14 / §15
> **Role**: Evolution Loop の invariant を固定する。Candidate の採用評価に使う authority を Candidate 自身の変更対象から切り離し、Independence Level と Promotion Decision の値域を定義する。

## 1. Invariant

> **Candidate cannot modify the authority that judges the candidate.**

Harness Improvement Candidate は、**自分の採用評価中**に次を変更できない。

| Protected authority        | 内容                                                          |
| -------------------------- | ------------------------------------------------------------- |
| Evaluation Harness | paired replay / activation check / grader / **stable meta-verifier** / **HarnessManifest 生成器・canonical 化器** / **`protected_surfaces` 定義** |
| Sealed / held-out fixtures | 提案時に未使用の regression set。Candidate 作成前に ID を固定 |
| Promotion Policy           | PASS / FAIL / INCONCLUSIVE の判定規則                         |
| Acceptance Threshold       | Candidate 作成前に固定した閾値・trial 数・metrics             |
| Protected Gate             | Verifier pipeline の blocking 規則、Stop / Escalation policy  |
| Human-owned Boundary       | C-4 / Merge / HO / Policy / Permission / First Principles     |

適用規則:

- Candidate の `allowed_paths` が上記のいずれかを含む場合、その Candidate は **通常の paired evaluation で PASS にできない**。`DENIED`（Policy Verdict）または Human escalation。
- 「Verifier を改善する Candidate」「Eval を改善する Candidate」「Test strategy を改善する Candidate」は正当な改善対象（North Star §11）だが、**その Candidate 自身の変更後 Verifier / Eval で自分を評価してはならない**（§3）。

## 2. #916 との接続

Issue #916（判定基盤 carve-out の arbiter 機械強制）は、Legacy C-3' arbiter が自分の判定基盤（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**` / `docs/ai/ai-loop/**` / ai-loop-cycle Skill）を auto-approve 経路で改変しうる構造的盲点を塞ぐ局所 Issue として起票された。

V2 ではこれを **本 invariant の Legacy 実例**として位置づける。

| #916 の要素                                                  | V2 での一般化                                                                                                                                                     |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| carve-out glob（escalate 固定パス集合） | Protected authority の path 集合。機械可読な 1 正本（`protected_surfaces`）として HarnessManifest の `verifier_set_sha` / `policy_profile_sha` が指す定義に含める。**交差判定には baseline Manifest（または evaluation plan digest に固定した定義）の `protected_surfaces` を使い、candidate Manifest 側の定義は判定に用いない**（candidate が自分を保護集合から外す経路を塞ぐ） |
| `changed_files` が carve-out に一致 → `HUMAN_ESCALATED`      | Candidate `allowed_paths` ∩ protected authority ≠ ∅ → Policy Verdict `DENIED` または `HUMAN_REQUIRED`（fail-closed）                                              |
| 規範層のみの防御                                             | 機械層（Policy Gate）+ 規範層 + Human C-4 の多層防御                                                                                                              |
| ho-paths.md の HO 一覧だけを読む単一経路（#906 / #978 統合） | protected surface の解決元を `explicit / downstream / bundled_template` として保持し、雛形フォールバックを escalate（#916 移管 AC を継承）                        |

Issue #916 の実装は Legacy arbiter への機械層配線として進めてよい（Legacy freeze の「security fix / migration support」に該当）。V2 の Policy Gate は同じ protected surface 定義を再利用する。

## 3. Verifier / Eval を変更する Candidate の評価

Candidate が Verifier / Eval / Test strategy を変更する場合、評価は次で行う。**Candidate 自身の変更後 Verifier の出力だけを根拠にしない。**

| 手段                                    | 何を証明するか                                                                                                                |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **stable meta-verifier**                | Candidate 作成前から存在する、Candidate の `allowed_paths` 外の Verifier。変更後 Verifier の出力の妥当性を検査する            |
| **known mutants**                       | 既知の欠陥を注入した artifact 群。変更後 Verifier が baseline と同等以上に検出できることを示す（検出力の退行を防ぐ）          |
| **sealed positive / negative fixtures** | Candidate 作成前に ID を固定した「通すべき入力」「落とすべき入力」。変更後 Verifier の false positive / false negative を測る |
| **baseline detection power**            | baseline Verifier の known mutants に対する検出率。Candidate はこれを下回ってはならない（critical regression condition）      |

原則:

- 「変異注入で検出力を実証する」（新規テストは旧実装 + 変異で FAIL を確認する）を Verifier Candidate の必須条件にする。
- Verifier Candidate が sealed fixture を「更新」することは Trust Boundary 違反。fixture の更新は別 Candidate・別評価。

### 後退の終端（無限後退の接地）

「meta-verifier を変える Candidate は誰が評価するか」「sealed fixture を更新する Candidate は誰が評価するか」「HarnessManifest 生成器を変える Candidate は誰が評価するか」は、いずれも **Evaluation Harness そのものの変更**である。これらは通常の paired evaluation の対象外とし、**Independence Level I4（Human + machine independent evidence）でのみ採用する**。ここが後退の終端であり、North Star §3 / §15 の Human-owned Promotion に接地する。Manifest 生成器が Candidate の対象に含まれると identity 偽装（同一 `harness_id` の詐称・`INCONCLUSIVE` の回避）が可能になるため、生成器は protected authority に含める。

## 4. Independence Level

「独立レビュー」を `same model / separate context` の一語で表さない。独立度を段階化し、surface ごとに最低 Level を要求できるようにする。

| Level  | 定義                                                   | 独立性                                            |
| ------ | ------------------------------------------------------ | ------------------------------------------------- |
| **I0** | same context（作成者自身の同一会話内セルフレビュー）   | 独立性なし。self-review としてのみ有効            |
| **I1** | same model / separate context + role + run             | context 汚染を排除。同一 model の系統的盲点は残る |
| **I2** | separate model                                         | model の系統的盲点を分散                          |
| **I3** | separate model + deterministic oracle / sealed fixture | 機械的根拠で LLM 判断を裏付ける                   |
| **I4** | Human + machine independent evidence                   | Human-owned 判断と機械 evidence の両方            |

原則:

- **Verifier / Gate / Policy / protected Flow の変更は、通常の Prompt / Context / Skill instruction 変更より高い Level を要求する**。Phase 1 で surface ごとの最低 Level を確定するが、少なくとも Verifier / Gate / Policy は **I3 以上**、Human-owned boundary に触れるものは **I4** を要求する方向で固定する。
- I0 は Promotion Decision の根拠にならない。
- 「実装 Agent 自身のレビュー」を Independent Review 完了と記録しない（Phase 0 の exit criteria の扱いと同じ。[`phase0-migration.md`](./phase0-migration.md) §7）。
- 同一 Model でも context / role / run を分離すれば I1（North Star §5）。model の系統的盲点が問題になる surface では I2 以上。

## 5. Promotion Decision

Harness Candidate の評価結果を PASS / FAIL の二値にしない。

| Decision       | 意味                                                                          |
| -------------- | ----------------------------------------------------------------------------- |
| `PASS`         | 事前固定した evaluation plan のすべての条件を満たし、critical regression が 0 |
| `FAIL`         | いずれかの条件を満たさない、または critical regression が 1 以上              |
| `INCONCLUSIVE` | 評価が成立しない。判定を下せる evidence が揃わない                            |

`INCONCLUSIVE` になる条件（例）:

- baseline / candidate の `harness_manifest_ref` が取れない（identity 不明）
- Activation Check で `fired` 以上の evidence が無い
- Verifier unavailable / grader unavailable
- trial 数が事前固定値に満たない
- fixture が sealed でなかった（Candidate 作成後に変更された）

原則:

- `INCONCLUSIVE` は `FAIL` ではないが、**`PASS` 側へ倒さない**。Promotion Ready にならない。
- `INCONCLUSIVE` の理由は Stop Reason と同様に evidence refs 付きで記録し、Evolution input にする。

## 6. 事前固定（pre-registration）

Candidate の実装を始める**前**に、evaluation plan を固定する。

| 固定する項目                  | 内容                                                     |
| ----------------------------- | -------------------------------------------------------- |
| fixture IDs                   | sealed / held-out set の ID 一覧                         |
| task profile                  | 評価に使う task の種別（探索 / 定型修正 / …）            |
| trial count                   | 非決定的挙動に対する試行回数。単発で足りる場合はその理由 |
| metrics                       | 何を測るか（North Star §14 / §18）                       |
| threshold                     | 採用閾値                                                 |
| critical regression condition | 1 件でも出たら FAIL にする条件                           |

原則:

- **結果を見てから評価条件を緩めない**。閾値・fixture・trial 数の変更は新しい evaluation plan = 新しい評価。
- evaluation plan の digest を HarnessImprovementCandidate に持たせ、HarnessExperimentResult が同じ digest を参照していることを Promotion Evaluator が検査する。

## 7. Negative examples（V2 として invalid）

| ケース                                                               | 期待される扱い                                                                  |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Candidate の `allowed_paths` に sealed fixture のパスが含まれる      | Policy Verdict `DENIED` または `HUMAN_REQUIRED`。paired evaluation を開始しない |
| Verifier を変更した Candidate を、変更後 Verifier の PASS だけで採用 | invalid。stable meta-verifier / known mutants / sealed fixtures が必須          |
| baseline と candidate の Manifest identity が取れないまま比較        | `INCONCLUSIVE`                                                                  |
| trial 数を結果を見てから減らす                                       | invalid。新 evaluation plan として再評価                                        |
| 実装 Agent の I0 セルフレビューを Independent Review として記録      | invalid                                                                         |
