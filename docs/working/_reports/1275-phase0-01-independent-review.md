# Phase 0 / Phase 0.1 canon 独立レビュー記録（I1 ×2）

> **これは何か**: ai-loop V2 の Phase 0 / Phase 0.1 canon（`docs/ai/ai-loop-v2/` 7 本）に対する独立レビューの**証跡**。
> `phase0-migration.md` §7 の exit criteria「別 context / role の checker による I1 以上の記録」に対応する。
>
> **なぜ artifact にするか**: 従前の「独立レビュー実施済み」という記録は **commit message にしか存在せず**、
> その commit の `Claude-Session` trailer が実装セッションと**同一 session id** だった。
> [`evaluation-trust-boundary.md`](../../ai/ai-loop-v2/evaluation-trust-boundary.md) §4 は
> 「実装 Agent 自身のレビューを Independent Review 完了と記録しない」と定めており、
> 当時の証跡では **I0 と I1 を区別できなかった**。同じ失敗を繰り返さないため、
> **対象 SHA / reviewer role / 独立性の根拠 / 指摘と採否 / 残存脅威モデル**を artifact に固定する。

## 0. レビュー条件（両レビュー共通）

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

## 4. このレビューが守らないもの（残存脅威モデル）

- **I2 ではない**。同一 model の系統的盲点は残る。特に「4 軸の直交性そのものが正しいか」という設計判断は、同系 model が生成した文書を同系 model が読んでいるため独立していない。**I2（別 model）で 1 周する価値は残っている**。
- **実行可能物が無い**。決定論的 oracle・sealed fixture による検証は不可能（Phase 0.1 は仕様のみ）。B-C-1 / B-C-2 は「Phase 1 実装者が誤読しうる」ことの論証であって、誤読が実際に起きることの実証ではない。
- **実装コードは 2 ファイルしか読んでいない**（north-star §18 の主張の裏取り目的）。Legacy 実装と V2 canon の意味論的整合は未検査。
- **機械検証は grep のみ**。`tests/` の fixture・CI ゲートは実行していない。「V2 namespace に禁止語彙が無い」は**その 3 パターンに対してのみ** 0 件で、散文・表セル内の同種の混同は検出範囲外。
- **Phase 0.1 の内容的妥当性（4 軸が実装に耐えるか）は Phase 1 設計でしか検証されない**。本レビューが言えるのは「canon が相互に矛盾していないか」まで。
- **多層防御の 1 層**。承認境界の最終保証は Human C-4 と `check-plan-hash.sh` の HO 判定であり、本レビューはそれを代替しない。
- **充足の宣言は Human-owned**。本 artifact は exit criteria が要求する「I1 以上の記録」の**候補**であって、充足の宣言そのものではない。
