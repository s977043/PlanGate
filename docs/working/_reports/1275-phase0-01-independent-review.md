# Phase 0 / Phase 0.1 canon 独立レビュー記録（R1: I1 ×2 / R2: I1）

> **これは何か**: ai-loop V2 の Phase 0 / Phase 0.1 canon（`docs/ai/ai-loop-v2/` 7 本）に対する独立レビューの**証跡**。
> `phase0-migration.md` §7 の exit criteria「別 context / role の checker による I1 以上の記録」に対応する。
>
> **なぜ artifact にするか**: 従前の「独立レビュー実施済み」という記録は **commit message にしか存在せず**、
> その commit の `Claude-Session` trailer が実装セッションと**同一 session id** だった。
> [`evaluation-trust-boundary.md`](../../ai/ai-loop-v2/evaluation-trust-boundary.md) §4 は
> 「実装 Agent 自身のレビューを Independent Review 完了と記録しない」と定めており、
> 当時の証跡では **I0 と I1 を区別できなかった**。同じ失敗を繰り返さないため、
> **対象 SHA / reviewer role / 独立性の根拠 / 指摘と採否 / 残存脅威モデル**を artifact に固定する。

## ラウンド構成

本 artifact は **2 ラウンド**の記録である（[`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater「敵対レビューのラウンド設計と収束判定」に従う）。

| ラウンド | 節         | 対象差分                 | role                                     | Independence Level | 是正           |
| -------- | ---------- | ------------------------ | ---------------------------------------- | ------------------ | -------------- |
| **R1**   | §0〜§4     | canon 7 本 @ `2950d358`  | docs 整合（A）/ 敵対（B）の 2 本         | I1 ×2              | PR #1300       |
| **R2**   | §5         | `2950d358..62e4ab93`     | **R1 の是正そのものを疑う**              | I1                 | PR #1301       |

収束判定・回避クラス台帳・打ち切りの残存脅威モデルは §6 / §7。

## 0. レビュー条件（R1 の両レビュー共通）

| 項目                  | 値                                                                                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`reviewed_at_sha`** | **`2950d35837b7fd8aa6b8d9061159ec1058717560`**（`origin/main`。両レビュアーが着手時に独立に実測して一致）                                                     |
| 対象                  | `docs/ai/ai-loop-v2/` の 7 本（README / north-star / phase0-migration / taxonomy / harness-manifest / evaluation-trust-boundary / artifact-responsibilities） |
| 実施日                | 2026-09-07                                                                                                                                                    |
| Independence Level    | **I1**（same model / separate context + role + run。`evaluation-trust-boundary.md` §4 の定義に照らす）                                                        |
| I2 でない理由         | 同一 model。model の系統的盲点は分散していない                                                                                                                |
| I3 でない理由         | 決定論的 oracle / sealed fixture を持たない（Phase 0.1 は仕様のみで実行可能物が無い）                                                                         |

**重点対象に指定した差分**（過去に一度もレビューが当たっていなかった範囲）:

| 差分                               | 内容                                                                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `2d2fcba2..e4c96201`               | River Review 指摘 4 件の**是正そのもの**（是正を検査したレビューが存在しなかった）                                             |
| `a211e03f1..4d5c9e198`             | PR #1284 の最終 1 行                                                                                                           |
| PR #1284 の `north-star.md` +44/−7 | Phase 0 canon を**後から改変**した分。Phase 0 の当初レビュー対象に含まれない                                                   |
| `362c575a`（PR #1295）             | docs 整合レビュアーが**自ら追加**（north-star §18 / harness-manifest §4 を変更しており、依頼時の重点範囲に含まれていなかった） |

## 1. レビュー A — docs 整合

**role**: 正本間の一貫性・参照健全性・量化子・機械検証の実効性
**context 分離の根拠**: 対象 doc の実装・編集を一切行っていない別 run。plan / 実装意図の内部状態を持たず、artifact のみを入力にした

### 指摘

| ID        | Sev   | 内容                                                                                                                                                                                                                                                                 | 採否                                                           |
| --------- | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| A-MAJOR-1 | major | exit criteria の 6 項目が「PR #1276 で充足」を根拠にするが、直下の行が「#1276 のレビューは未了」と記録する自己参照。特に「**GitHub 上で** rebaseline」は issue body の編集であり **docs PR のマージでは原理的に達成できない**証跡の種別誤り（事実としては 6/6 充足） | **採用**・是正済                                               |
| A-MAJOR-2 | major | PENDING の独立レビューに**対象 SHA が無い**。canon は baseline 以降 4 回変わっており（`1e95e8a6` / `9e5c0b05` / `4b3c0976` / `362c575a`）、記録しても次の改変で無言に失効する                                                                                        | **採用**・`reviewed_at_sha` 欄を新設                           |
| A-MINOR-1 | minor | `taxonomy.md` §8 の除外フィルタが行頭アンカー付きパスなので、`git grep <rev>` すると出力が `<rev>:docs/…` になり**除外が空振り**する                                                                                                                                 | **採用**・`--full-name` + `(^\|:)` アンカー                    |
| A-MINOR-2 | minor | §6 の禁止例 5 件のうち 1 件（`outcome: HUMAN_ESCALATED` + `stop_reasons: []`）に検査が無い。**§3 の中核規則**なのに未検査                                                                                                                                            | **採用**・grep で検査不能である旨と Phase 1 fixture 送りを明記 |
| A-MINOR-3 | minor | `INCONCLUSIVE` 条件に `influenced_decision` 例外（Verifier / Gate 改善）が未反映                                                                                                                                                                                     | **採用**                                                       |
| A-MINOR-4 | minor | 「Legacy schema は拡張しない」が無条件で、freeze policy の例外条項と食い違う                                                                                                                                                                                         | **採用**・「§2 の freeze 例外を除く」を追記                    |
| A-MINOR-5 | minor | `harness-manifest.md` の Activation 含意規則が**二重否定で読解不能**                                                                                                                                                                                                 | **採用**・肯定形へ書き換え                                     |
| A-INFO-1  | info  | 重点差分（River Review 是正 4 件 / #1284 / #1295）は**新しい穴を作っていない**。§8 のフィルタ限定・`protected_surfaces` を baseline Manifest 側に固定した是正・§15 の緩和明記はいずれも意図どおり効いている                                                          | 記録のみ                                                       |

### 確認して問題が無かった項目（抜粋）

§12→§15 の委譲の受け皿は塞がっている／`§N` 委譲先は**全件実在**／外部参照パス 16 本すべて実在／**行番号アンカー 0 件**（記号アンカーのみ）／Activation 6 段階の語彙が 2 文書で完全一致／Independence Level の値域が一致／artifact budget 9 = 9／4 軸の値域に混同 0 件／Legacy freeze 宣言の 3 文書整合／`taxonomy.md` §8 の positive control が 4 行を検出（空振りでない）。

### 総合判定

**Phase 1 設計へ進める状態にある**（critical 0 / major 2 はいずれも canon の**内容**ではなく**充足記録と対象固定の様式**に関するもの）。

## 2. レビュー B — 敵対

**role**: 「この canon のまま Phase 1 実装へ進むべきでない根拠」を探す側
**context 分離の根拠**: 本 context に Phase 0 / 0.1 の実装履歴・plan・PR 作業は含まれない。canon 本文は `git show` で初めて読み込んだ

### 指摘

| ID    | Sev          | 内容                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | 採否                                                               |
| ----- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| B-C-1 | **critical** | 保護集合との交差判定の入力が **Candidate の `allowed_paths`（宣言値）**。Legacy #916 は `changed_files`（観測値）だったのが V2 一般化で置換され、**「実差分と照合する」規定は canon 全体で 0 件**。`allowed_paths` を過少申告した Candidate が交差判定を素通りでき、**「Candidate cannot modify the authority that judges the candidate」が自己申告依存で迂回できる**。north-star §6 と正面から矛盾。塞ぎ方も非対称（保護集合から自分を外す経路は塞いだが、変更範囲の過少申告は塞いでいない） | **採用**・是正済（下記 §3）                                        |
| B-C-2 | major        | Protected Gate に限定詞が無く、字義通りなら**あらゆる Verifier blocking 規則の変更が DENIED** になり §3 の手続きが死文化する。逆に読めば §3 が生きるが、その限定はどこにも無い。**Phase 1 実装者はどちらも本文に忠実に実装できる**                                                                                                                                                                                                                                                            | **採用**                                                           |
| B-C-3 | major        | 4 軸 taxonomy は Delivery Run スコープで定義されているのに、Policy Verdict が Evolution の Candidate 評価に転用されている。north-star §5「Delivery と Evolution は同じ state / gate / success condition で表現しない」に抵触。「Candidate 評価 Run が Lifecycle State / Terminal Outcome を持つか」も未定義                                                                                                                                                                                   | **採用**                                                           |
| B-C-4 | major        | **canon 自身が、canon の定める独立度の下限を満たしていない**。`evaluation-trust-boundary.md` §1 は `protected_surfaces` 定義と HarnessManifest 生成器を Protected authority に列挙し、§3 は「Evaluation Harness そのものの変更は I4 でのみ採用する」と定めるが、canon 7 本はまさにその定義そのものなのに exit criteria は **I1 以上**しか要求していない                                                                                                                                       | **Human 判断へ**（AI が決めない。`phase0-migration.md` §7 に明記） |
| B-C-5 | major        | Legacy freeze の**判定主体が無い**。実例で破綻 — 同じ #916 が `taxonomy.md` では「変更しない」、`evaluation-trust-boundary.md` では「進めてよい」                                                                                                                                                                                                                                                                                                                                             | **採用**・判定主体と手順を新設し両側を接続                         |
| B-C-6 | minor        | `artifact-responsibilities.md` が「正本は event stream」と宣言した **RunEvent stream が artifact budget 9 件に含まれていない**。Phase 1 が budget 外の 10 件目を定義せざるを得ない                                                                                                                                                                                                                                                                                                            | **採用**・budget 10 件目として追加                                 |
| B-C-7 | minor        | §8 の positive control が §6 の禁止例 5 件中 4 件しか覆わない（A-MINOR-2 と同一）                                                                                                                                                                                                                                                                                                                                                                                                             | **採用**（A-MINOR-2 に統合）                                       |
| B-C-8 | info         | `artifact-responsibilities.md` の「pattern 検出（North Star §17）」の §17 は "Release boundaries" で**受け皿ではない**／exit criteria の rebaseline 証跡の artifact 誤り（A-MAJOR-1 と同一）／`cost_metrics.anyOf[0]` は `additionalProperties` 未設定の開いた object なので「Legacy schema にはフィールドを足せない」という一般化は厳密には成り立たない（結論＝拡張しない、は別の理由で維持）                                                                                                | **採用**（参照張り替え）                                           |

### 攻めきって問題が無かった項目（抜粋）

candidate が**自分を保護集合から外す経路**は塞がれている（`protected_surfaces` を baseline Manifest 側に固定）／「決定論的 FAIL を LLM PASS で上書きしない」が 3 文書で一致／`§N` 委譲先は全件実在／artifact budget 9 = 9／Phase 0 / 0.1 の未充足項目は `[ ]` で**正直に** PENDING と申告されている。

### 総合判定

**条件付きで進める** — B-C-1 / B-C-2 / B-C-3 を Phase 1 設計の入口で解消し、B-C-4 / B-C-5 を明示することが条件。

## 3. 採否の結果（本 PR での是正）

| 指摘                             | 是正内容                                                                                                                                                                                                                                                                                                                                                    |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B-C-1                            | 交差判定の入力を **`allowed_paths`（宣言）と実差分（観測）の両方**にし、**実差分 ⊆ `allowed_paths` の検証を必須**化。超過は交差の有無に**かかわらず** fail-closed（`DENIED` / `HUMAN_REQUIRED`）、差分が取れない場合は `INCONCLUSIVE`。#916 表の右列も観測値を含む形へ修正し「Legacy #916 の観測値入力を V2 で失わない」と明記。negative example 3 行を追加 |
| B-C-2                            | Protected Gate に「**この Candidate を裁く評価系に参加する**」限定を明示。参加判定は評価 plan に固定した verifier set 基準、判定不能は参加扱い（fail-closed）。**緩和防止として**「削除・緩和・適用範囲縮小は参加有無に関わらず north-star §15 の Human Gate 必須」を併記                                                                                   |
| B-C-3                            | `taxonomy.md` に Evolution Loop への適用範囲を新設 — Lifecycle State / Terminal Outcome は**適用しない**、Stop Reason は語彙のみ共用、Policy Verdict は**適用する**（根拠つき）。State / Outcome の要否は **Phase 1 で確定**と明記                                                                                                                          |
| B-C-5                            | freeze policy に**判定主体**（提案 = AI / 承認 = Human C-3 / 適用確認 = Human C-4）と判定手順、**両解釈可能なら不許可側が既定**（fail-closed）を新設。#916 を実例として記載し、`taxonomy.md` 側の「変更しない」を「V2 taxonomy を Legacy 実装へ逆輸入しない」の意に限定して両文書を接続                                                                     |
| A-MAJOR-1 / A-MAJOR-2 / minor 群 | 本文の該当箇所を是正（詳細は PR 本文）                                                                                                                                                                                                                                                                                                                      |
| **B-C-4**                        | **未決**。`phase0-migration.md` §7「Human 判断事項（未決 / AI が決めない）」に選択肢 (a) I4 へ引き上げ / (b) 明示的例外化 + 実装時 I4 移行条件、を記載                                                                                                                                                                                                      |

## 4. R1 が守らないもの（R1 時点の残存脅威モデル）

> 2 ラウンド通算の残存脅威モデルは §7。本節は **R1 時点**の記録として残す（R2 の実施により「同一 model の系統的盲点」の一部は §6 の台帳へ具体化された）。

- **I2 ではない**。同一 model の系統的盲点は残る。特に「4 軸の直交性そのものが正しいか」という設計判断は、同系 model が生成した文書を同系 model が読んでいるため独立していない。**I2（別 model）で 1 周する価値は残っている**。
- **実行可能物が無い**。決定論的 oracle・sealed fixture による検証は不可能（Phase 0.1 は仕様のみ）。B-C-1 / B-C-2 は「Phase 1 実装者が誤読しうる」ことの論証であって、誤読が実際に起きることの実証ではない。
- **実装コードは 2 ファイルしか読んでいない**（north-star §18 の主張の裏取り目的）。Legacy 実装と V2 canon の意味論的整合は未検査。
- **機械検証は grep のみ**。`tests/` の fixture・CI ゲートは実行していない。「V2 namespace に禁止語彙が無い」は**その 3 パターンに対してのみ** 0 件で、散文・表セル内の同種の混同は検出範囲外。
- **Phase 0.1 の内容的妥当性（4 軸が実装に耐えるか）は Phase 1 設計でしか検証されない**。本レビューが言えるのは「canon が相互に矛盾していないか」まで。
- **多層防御の 1 層**。承認境界の最終保証は Human C-4 と `check-plan-hash.sh` の HO 判定であり、本レビューはそれを代替しない。
- **充足の宣言は Human-owned**。本 artifact は exit criteria が要求する「I1 以上の記録」の**候補**であって、充足の宣言そのものではない。

## 5. R2 — 是正そのものを疑うラウンド

### 5-0. レビュー条件

| 項目                   | 値                                                                                                                                                                          |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **対象 SHA（範囲）**   | **`2950d358..62e4ab93`**（R1 指摘の是正差分 = PR #1300、merged 2026-09-07T13:49:20Z / merge commit `62e4ab935b49a0560d5ce48a5b73e9ff289be4e9`）                            |
| 対象ファイル           | `docs/ai/ai-loop-v2/` 6 本（artifact-responsibilities / evaluation-trust-boundary / harness-manifest / north-star / phase0-migration / taxonomy）+ `_reports/` 2 本 + dispatch-template |
| **role**               | **是正そのものを疑う**（[`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater「2 ラウンド目以降の焦点」— ①是正が実は効いていない箇所 ②是正が新たに生んだ穴 ③fail-closed 化が正常系を壊していないか） |
| 実施日                 | 2026-09-07                                                                                                                                                                |
| **Independence Level** | **I1**（same model / separate context + role + run）                                                                                                                       |
| 是正                   | **PR #1301**（merged 2026-09-07T21:33:15Z / merge commit `f8f1e8b85982642a467bdce712daedce65568c23`）                                                                     |

**レビュアー自身による独立性の申告（そのまま記録する）**: 本差分は **Evaluation Harness の定義そのもの**であり、[`evaluation-trust-boundary.md`](../../ai/ai-loop-v2/evaluation-trust-boundary.md) §3 が「Evaluation Harness そのものの変更は I4 でのみ採用する」と定めている。**したがって R2 レビューは、canon が自ら課す I3 / I4 の下限を満たしていない**。R2 は exit criteria が要求する I1 は満たすが、canon 自身の基準では不足である — この非対称は [`phase0-migration.md`](../../ai/ai-loop-v2/phase0-migration.md) §7「Human 判断事項」の未決（B-C-4）と**同一の構造**であり、R2 の実施によって解消されない。

### 5-1. 指摘（major 4 / minor 4）— いずれも採用・PR #1301 で是正

| ID       | Sev   | 内容                                                                                                                                                                                                                                                                                                        | 是正（#1301）                                                                                                                                                                                              |
| -------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **R2-1** | major | **C-1（B-C-1 の是正）に「実差分」の供給元の定義が無い**。誰が・何を base に・どう算出するかが未定義なら、Candidate 側が出した値を実差分として受け取れてしまい、**観測値が宣言値の別名に退化**する（B-C-1 で塞いだはずの自己申告依存が復活する）                                                            | `evaluation-trust-boundary.md` §1 に **「実差分の供給元（definition）」** を新設 — 算出主体 = **Evaluation Harness 側**（Candidate 側でない）/ base = **baseline HarnessManifest の `source_commit`** / 算出方法は evaluation plan に固定し **Candidate が選べない** / 取得不能は `INCONCLUSIVE`、**取得できたが信頼できない場合は fail-closed**（`DENIED` / `HUMAN_REQUIRED`）。実差分算出器を Protected authority に追加 |
| **R2-2** | major | **C-2（B-C-2 の是正）が参照する「§6 に固定した verifier set」が §6 に存在しなかった**。受け皿が無いため、Candidate が verifier set を狭く書けば「自分を裁く評価系に参加しない」ことになり、**Protected Gate の適用外へ落とせた**                                                                          | §6 の固定項目に **`verifier set` / `baseline manifest ref`** を追加し、**固定の主体の表**を新設（両項目は **Evaluation Harness 側が固定・Candidate 提案者は単独で決められない**）。baseline より狭い set は判定可能値として扱わず欠落分は参加扱い（fail-closed）。欠落時の安全側の倒し方も明記 |
| **R2-3** | major | **C-5（freeze 例外の Human C-3）が既存の C-3 Autonomous APPROVE で迂回できた**。canon 内に `autonomous` の言及は **0 件**、かつ実例 #916 の対象 `scripts/ai-loop/arbiter.py` は **HO 9 カテゴリ外**のため、既存ルールだけでは AI が自分の freeze 例外を自己承認できる余地が残っていた                     | `phase0-migration.md` §2 に **「freeze 例外の承認は autonomous APPROVE の対象にしない」** を新設。`.claude/rules/working-context.md` を**変更・緩和せず**、freeze 例外という限定領域に**追加の制約を課す**形（HO 対象である `.claude/rules/` は canon から変更しない）                                     |
| **R2-4** | major | **§8 の検査 pathspec が cwd 相対**で、サブディレクトリから実行すると対象が `docs/docs/ai/ai-loop-v2`（不在）になり、**positive control ですら 0 件 / `exit=1`** になる。A-MINOR-1 で出力側（`--full-name`）は直したが**入力側が残っており、検査全体が沈黙**しうる                                        | pathspec を **`:/` 付き**（repo root 基準）へ。「出力側と入力側の両方を root 基準に固定する。片方だけでは検査が沈黙する」を明記し、**positive control をサブディレクトリからも実走して 4 行出ることを確認する**ことを規約化 |
| R2-5     | minor | `artifact-responsibilities.md` §7 の引用が **North Star §11 / §6 を指していたが、実体は §19 Non-goals / §12**（節番号誤り）                                                                                                                                                                                | 参照を §19 Non-goals / §12 / `phase0-migration.md` §6 へ張り替え                                                                                                                                          |
| R2-6     | minor | **委譲先が受け皿でない 2 例目**（B-C-8 の §17 誤りと同型）。`taxonomy.md` §1 が `phase0-migration.md` §8 へ「Candidate 評価 Run の State / Outcome の要否」を委譲していたが、**§8 に該当項目が無かった**                                                                                                  | §8 に **「Candidate 評価 Run（Evolution Loop）の進行・終端表現」** を追加し、`taxonomy.md` §1 の委譲先を項目名まで明示                                                                                    |
| R2-7     | minor | **Policy Verdict の写像規則との衝突**。§5 は `HUMAN_REQUIRED` に State `WAITING_HUMAN` / Outcome `HUMAN_ESCALATED` / Stop Reason `HUMAN_REJECTED` の写像を内蔵するが、§1 は Evolution に State / Outcome を適用しない。Evolution は `HUMAN_REQUIRED` を実際に使うため、**その後の待ち状態と終端を表す語が無い** | `taxonomy.md` §1 に **「既知の衝突（Phase 0.1 時点で未解消）」** を追加し、**disclosed な未決**として §8 へ送る（Delivery の値を Evolution へ暫定流用しない旨を明記）                                     |
| R2-8     | minor | 「承認 record に **additive** に刻む（既存の optional フィールドと同じパターン）」が **schema 波及を伴う**。`schemas/c3-prime.schema.json` は top-level `additionalProperties: false` で必須 14 / optional 1 のため、追加は **schema 変更 + 受理器 + fixture** に波及する                                | §7-3 に波及範囲の注記を追加し、「束縛 hash は既存機構でそのままかかる」は **Plan Package 側**の記述であって**承認 record 側には及ばない**ことを明記。波及範囲の確定は Phase 1 へ                          |

### 5-2. R1 と R2 の関係 — 新しいクラスではなく、同一クラスの再発

R2 が出した major 4 件は、**R1 が検出した「宣言依存」クラスの新しいインスタンス**であって、新しい回避クラスではない。

- R1 の B-C-1 は「保護集合との交差判定の入力が Candidate の `allowed_paths`（宣言値）だけ」という**宣言依存**を検出した。
- その是正は「実差分（観測値）も入力にする」だったが、**R2-1 が示したとおり「実差分」の供給元が未定義**だった。供給元が無い観測値は宣言値の別名にしかならない。
- さらに **R2-2 は、C-2 の是正が `verifier set` という新しい宣言依存を導入していた**ことを示した。`allowed_paths` を塞いだ直後に、**別の宣言値で同じ迂回が成立していた**。
- R2-3 も同型である（承認の主体を AI 自身に置き換える経路 = 「誰が裁くか」を被審査側が決める）。

つまり **R2 は「是正が別の形で同じ穴を再生産していないか」を見たラウンド**であり、その結果は「再生産していた」だった。§7-quater の定義に照らすと、**同型の再検出は収束の妨げにならない**（是正漏れとして直す）。

## 6. 回避クラス台帳（追記専用 / R1・R2 通算）

> 形式は [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater「回避クラス台帳」に従う。以後、**新しいクラスを見つけたら塞いだうえで 1 行追加する**（既存行は書き換えない）。

| クラス                                                                                          | 代表例（最小再現）                                                                                                                                                                                                       | 検出ラウンド | 是正                                                                                                                                    | 前ラウンドが見つけられなかった理由                                                                                                                                                                                                                                                                                        |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **宣言依存**（判定の入力に Candidate の宣言値を使い、観測値と照合しない）                       | Candidate が `allowed_paths` に `docs/` だけを申告し、実際は `protected_surfaces` 定義を変更する。交差判定は宣言値だけを見るので素通りする                                                                                | R1（B-C-1）  | 交差判定の入力を **`allowed_paths`（宣言）と実差分（観測）の両方**にし、実差分 ⊆ `allowed_paths` を必須検証。超過は fail-closed（#1300） | —（初検出）                                                                                                                                                                                                                                                                                                              |
| **宣言依存**（同上・**観測値の供給元が未定義**という形態）                                      | 「実差分」の算出主体が未定義なので、Candidate 側の実装が出した値を実差分として受け取れる。**観測値の欄に宣言値が入る**                                                                                                    | R2（R2-1）   | §1 に「実差分の供給元（definition）」を新設。算出主体 = Evaluation Harness 側 / base = baseline Manifest / 信頼できなければ fail-closed（#1301） | **R1 は canon の「記述」を見て、そこに実差分への言及が 0 件であることを検出した。R2 は「その是正が実際に穴を塞ぐか」を見た。** 記述として「実差分と照合する」と書けば R1 の指摘は満たされてしまうため、R1 の検査モデル（記述の有無）では**供給元の欠落を原理的に検出できない**。是正が入って初めて「この観測値はどこから来るのか」が問える |
| **宣言依存**（同上・**別フィールドへの移動**という形態）                                        | Candidate が evaluation plan の `verifier set` に「自分を裁かない」集合を書き、Protected Gate の限定条件（評価系に参加する Gate）から外れる                                                                              | R2（R2-2）   | §6 に `verifier set` / `baseline manifest ref` を追加し、**固定の主体を Evaluation Harness 側**に明記。狭い set は判定可能値にしない（#1301） | **R1 の是正が導入したフィールドなので、R1 の時点では存在しなかった。** 加えて R1 は「`allowed_paths` という特定フィールド」を疑ったのであって「宣言値を判定入力に使う構造」を疑っていない。同じクラスの別インスタンスは、是正後の本文を読み直さないと現れない                                                        |
| **承認主体の入れ替え**（Human Gate を、AI が自己承認できる既存規定で迂回する）                  | freeze 例外を含む Plan を、`working-context.md` の C-3 Autonomous APPROVE で AI が自己承認する。対象が HO 9 カテゴリ外（例 `scripts/ai-loop/arbiter.py`）なら既存ルール上は成立する                                       | R2（R2-3）   | §2 に「freeze 例外の承認は autonomous APPROVE の対象にしない」を新設（既存ルールを緩めず追加制約）（#1301）                              | **R1（B-C-5）は「freeze の判定主体が無い」ことを検出し、是正で「承認 = Human C-3」を置いた。R1 はそこで止まっている。** 「置いた Human Gate を既存の別ルールが自動で満たしてしまわないか」は、Gate を置いた**後**にしか問えない検査である（canon 内の `autonomous` 言及 0 件という実測も、Gate 設置後に初めて意味を持つ） |
| **検査の沈黙**（検査コマンドが対象を取れず 0 件を返し、それが PASS と読める）                   | `docs/` から `git grep … -- docs/ai/ai-loop-v2` を実行すると対象は `docs/docs/…`（不在）。**positive control すら 0 件 / `exit=1`**                                                                                       | R2（R2-4）   | pathspec を `:/` 付きへ。**positive control をサブディレクトリからも実走**することを規約化（#1301）                                     | **R1（A-MINOR-1）は同じ検査の「出力側」（`--full-name` / 除外アンカー）を直しており、入力側（pathspec の cwd 相対解決）を見ていない。** R1 は repo root からのみ実走して 4 行の検出を確認したため、**cwd を変えるという次元が検査モデルに入っていなかった**。是正後の同じコマンドを別 cwd で走らせて初めて出る               |

**読み取り**: R2 が出した 5 行のうち 3 行は「宣言依存」クラスの**再発**、残り 2 行（承認主体の入れ替え / 検査の沈黙）は **R1 の是正が置いた Gate・検査そのものを対象にしたときにだけ現れる**。いずれも **R1 と同じ層をもう一度見ただけでは出ない**。

## 7. 打ち切りの判断と残存脅威モデル（2 ラウンド通算）

### 7-1. 収束判定

[`review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater は収束条件を **「新しい回避クラス / 失敗クラスが出なくなったか」** と定め、**「指摘ゼロ」を収束条件にしない**、**同型の再検出は収束の妨げにならない**としている。これに照らすと:

- R2 の major 4 件のうち **3 件は R1 と同一クラス（宣言依存）の再検出**であり、**是正漏れとして直した**。
- 残り 2 クラス（承認主体の入れ替え / 検査の沈黙）は、**R1 の是正が存在して初めて評価対象になった**もので、R1 の検査モデルでは原理的に出せない。
- **毎ラウンド新しいクラスが出続けている状態ではない**（R2 の主収穫は既知クラスの再発潰し）。§7-quater が言う「設計モデルそのものを疑うとき」には当たらない。

以上より **R2 をもって本 2 ラウンドを打ち切る**。ただし下記のとおり**完全性は主張しない**。

### 7-2. 残存脅威モデル（守るもの / 守らないもの）

**守らないもの**:

- **I2（別 model）が未実施**。R1・R2 とも same model であり、**同一 model の系統的盲点は排除できない**。特に **「宣言依存の第 3 の形態を同一 model が再生産していないか」** は、同じ model が是正を書き同じ model が検査している以上、本 2 ラウンドでは判定できない。§6 の台帳が示すとおり、このクラスは 2 度とも「是正が別の宣言値へ移動する」形で再発しており、**3 度目が無いことの根拠は無い**。
- **canon 自身が要求する I3 / I4 に未達**。[`evaluation-trust-boundary.md`](../../ai/ai-loop-v2/evaluation-trust-boundary.md) §3 は Evaluation Harness そのものの変更を **I4 でのみ採用する**と定めるが、本 2 ラウンドは I1 である。これは [`phase0-migration.md`](../../ai/ai-loop-v2/phase0-migration.md) §7「Human 判断事項」の**未決 C-4 と同じ構造**であり、レビューを重ねても解消しない（**Human 判断でしか解けない**）。
- **Phase 1 実装の妥当性は未検証**。R1・R2 の対象は**すべて設計文書**であり、実行可能物が無い。「Phase 1 実装者が誤読しうる」ことの論証であって、誤読が起きないことの実証ではない。fail-closed 規定が正常系（採用すべき Candidate）を過剰に落とさないかも、実装が無い以上測っていない。
- **fixture が原理的に検出できる範囲を超えていない**。§7-quater の分担表に照らすと、本 2 ラウンドは「ロジック・分岐・境界値」に相当する層までで、**実 API 形状・タイミング由来の失敗は未検証**。

**保証の主体（本レビューが代替しないもの）**:

| 保証                                       | 主体                                                                                                    |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| exit criteria 充足の**宣言**と merge       | **Human C-4**（[`1275-phase0-01-evidence-audit.md`](./1275-phase0-01-evidence-audit.md) §3 の定義に従う） |
| 承認境界の最終保証                         | Human C-4 + `check-plan-hash.sh` の Hardening Override 判定                                              |
| 規定が実装に耐えるかの検証                 | **Phase 1 の fixture 化**（`tests/extras/` / [`taxonomy.md`](../../ai/ai-loop-v2/taxonomy.md) §8 / [`evaluation-trust-boundary.md`](../../ai/ai-loop-v2/evaluation-trust-boundary.md) §7） |
| canon への要求 Independence Level の確定   | **Human 判断**（`phase0-migration.md` §7「Human 判断事項」・未決）                                       |

**本レビューは多層防御の 1 層である。**
