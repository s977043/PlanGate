# canon 7 本: I1 例外の失効後に merge された commit の判定材料（下書き）

> **測定基点**: `origin/main` = `9d55ae5dc22dcfb0865f3f3f97110a88814a686e` / 2026-11-23
> **位置づけ**: **判断材料であって裁定ではない。** 本書の「規定変更の候補」はすべて AI の読みであり、確定したものではない。事後 I4 か例外扱いかの欄は空欄のままにしてある。裁定は Human が行う。
> **対象**: issue #1643 の AC-1（4 commit の差分と merge 主体を一次情報で再測定）と、AC-2・AC-3 の判定表の下書き。
> **前提**:
>
> - non-normative（規定変更ではない）と確定できるのは Human だけで、C-4 で対象を名指しして承認する。判断できなければ規定変更として扱う（`.github/PULL_REQUEST_TEMPLATE.md` の canon チェック項目、`phase0-migration.md` §7「例外の失効」の non-normative の判定）。
> - LLM のレビュアーは non-normative を確定できない。本書の読みもこれに従い、「候補」として書く。

## 0. canon 7 本と失効の正本

正本は `docs/ai/ai-loop-v2/phase0-migration.md` §7（「独立レビュー記録の要求」のコマンド例と、「経緯」に列挙された 7 本）。

- `docs/ai/ai-loop-v2/README.md`
- `docs/ai/ai-loop-v2/north-star.md`
- `docs/ai/ai-loop-v2/phase0-migration.md`
- `docs/ai/ai-loop-v2/taxonomy.md`
- `docs/ai/ai-loop-v2/harness-manifest.md`
- `docs/ai/ai-loop-v2/evaluation-trust-boundary.md`
- `docs/ai/ai-loop-v2/artifact-responsibilities.md`

失効: §7「例外の失効（記録: TASK-1408）」によると、例外は 2026-09-29（UTC）に失効した。一次証拠は PR #1402 の `mergeCommit` = `3331e5c4`、`mergedAt` = 2026-09-29T00:01:17Z。以後、canon 7 本の規定変更には I4 が要る。

## 1. AC-1: 再測定

### 1-1. 対象 commit の列挙

```sh
git log --first-parent --format='%H %ad %an | %s' --date=iso-strict 3331e5c4..9445df17 -- \
  docs/ai/ai-loop-v2/README.md docs/ai/ai-loop-v2/north-star.md \
  docs/ai/ai-loop-v2/phase0-migration.md docs/ai/ai-loop-v2/taxonomy.md \
  docs/ai/ai-loop-v2/harness-manifest.md \
  docs/ai/ai-loop-v2/evaluation-trust-boundary.md \
  docs/ai/ai-loop-v2/artifact-responsibilities.md
```

出力（exit 0）:

```text
a3c9146d59e18b420137aec5ec360c923e2e9ff0 2026-10-05T09:48:23+09:00 mine_take | docs(ai-loop): make capability changes re-evaluation triggers (#1487)
0122d6f91c8c9987c59b028c74d8d491ea1c7719 2026-10-04T22:05:11+09:00 mine_take | docs(ai-loop-v2): converge Runtime Evidence RFC and Production Feedback guide (#1447)
6d62636050d89fe9cf6423780bea1f5a76d746d5 2026-10-04T14:31:04+09:00 mine_take | Merge pull request #1441 from s977043/docs/ai-loop-v2-bounded-requirement-discovery
a6d1ea5f59b7dc03e6a99a07256e7140f0ee58e1 2026-09-29T09:04:39+09:00 mine_take | docs(plan): #1392 V2 RunState CAS / atomic snapshot plan (#1406)
```

**issue 記載値との照合**: commit 4 件と PR 番号は issue #1643 の記載（`a6d1ea5f` #1406 / `6d626360` #1441 / `0122d6f9` #1447 / `a3c9146d` #1487）と**一致した**。

補足（issue と食い違いではないが、裁定のときに知っておくとよい事実）:

- **#1441 は squash ではなく merge commit**（`6d626360`、親 2 本）。`--first-parent` を外すと、#1441 の branch 側の個別 commit 25 本も canon に触れたものとして列挙される。下記の差分は `git diff 6d626360^1 6d626360`（第 1 親との差分 = main に入った差分）で測った。
- **#1406 の `mergedAt` は 2026-09-29T00:04:39Z** で、失効時刻（#1402 の 00:01:17Z）の **3 分 22 秒後**。PR の作成・レビューは失効の前に進んでいた可能性があるが、本書では merge 時刻の事実だけを記録し、失効前の扱いになるかどうかは判断しない（Human の裁定事項）。
- 測定範囲の終点 `9445df17` より後にも、canon に触れた first-parent commit が 3 本ある（`ae56b75f` #1652 / `90047151` #1650 / `8a689907` #1653。`git log --first-parent 9445df17..origin/main -- <canon 7 本>`）。issue #1643 の範囲外であり、本書では扱わない（§5 を参照）。

### 1-2. merge 主体と review

`gh pr view <PR> --json mergedBy,reviews,mergedAt,mergeCommit,author,reviewDecision`（4 件とも exit 0）:

| PR | mergeCommit | mergedAt (UTC) | author | mergedBy | reviewDecision | reviews（state / 投稿者） | APPROVED 数 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| #1406 | `a6d1ea5f` | 2026-09-29T00:04:39Z | `s977043` | `s977043` | （空） | COMMENTED / `copilot-pull-request-reviewer`（quota 超過で未実行） | **0** |
| #1441 | `6d626360` | 2026-10-04T05:31:04Z | `s977043` | `s977043` | （空） | COMMENTED / `copilot-pull-request-reviewer`（quota 超過で未実行） | **0** |
| #1447 | `0122d6f9` | 2026-10-04T13:05:12Z | `s977043` | `s977043` | （空） | COMMENTED / `s977043`（"Final convergence review"）、COMMENTED / copilot（quota 超過で未実行） | **0** |
| #1487 | `a3c9146d` | 2026-10-05T00:48:24Z | `s977043` | `s977043` | （空） | COMMENTED / copilot（quota 超過で未実行）、COMMENTED / `s977043`（"Final review (loop 3)"） | **0** |

- 4 件とも **author = mergedBy = `s977043`**、APPROVED の review は **0 件**。issue 記載の値と一致した。
- #1447 と #1487 には `s977043` 名義の COMMENTED review がある。author と同じアカウントからの投稿だが、`evaluation-trust-boundary.md` §4 の Independence Level は context・role・run の分離で定義されており（I1 = same model / separate context + role + run）、別アカウントでの投稿は要件ではない。同一アカウントであることだけでは不適格と言えない。一方、どの context・role・run で書かれたかは GitHub 上の情報からは判別できていないので、**独立性は未確認**として記録する。なお I4 は Human と機械の独立証跡の両方を要する（§4 の I4 行）ので、この review だけで I4 を満たすことにはならない。
- #1487 の commit には `Co-authored-by: GPT-5.6 Sol <noreply@openai.com>` の trailer がある。
- I4 の機械証跡（固定 commit で再現でき、作成者の外で再実行したコマンドと出力）は、4 PR の review・本文・commit のいずれにも、本測定では見つからなかった（PR 本文とコメントは今回は読んでいない。§5 を参照）。

## 2. commit ごとの差分と AI の読み

### 2-1. `a6d1ea5f`（#1406）docs(plan): #1392 V2 RunState CAS / atomic snapshot plan

- 変更 canon（`git show --numstat`）: `artifact-responsibilities.md` +7 −1 / `taxonomy.md` +1 −1。他の 9 ファイルは `docs/working/TASK-1392/`（canon 外）。
- 差分の要約:
  - `artifact-responsibilities.md` §4（RunState revision CAS の「原則」）: CAS 失敗の記録について、3 つの場合（記録の上限・終端の予約枠・終端後）は**記録せず `STATE_CONFLICT` を返すだけでよい**とする例外を追加。さらに次の 5 項目を追加: RunState は論理 artifact で、event stream から導出してよい / CAS の比較値に stream の位置を含めてよい / 応答を失ったときの回復は orchestrator の責務 / 止めた Run は halt marker で止めたままにし、外すのは Human だけ / 読み出しは耐久性が確定した状態だけを返す（OS の前提つき）。テスト表に「遷移を伴わない記録の再送 → `STATE_CONFLICT`」の 1 行を追加。
  - `taxonomy.md` の Stop Reason 表: `STATE_CONFLICT` の定義を「revision CAS 失敗」から「CAS 失敗（revision または stream の位置が古い）」に広げた。
- **AI の読み（候補）: 規定変更**
- 根拠行:
  - `+- CAS の失敗は Stop Reason \`STATE_CONFLICT\` として記録し、RunEvent に残す。ただし、記録そのものが Run を壊しうる場合は記録せずに \`STATE_CONFLICT\` を返すだけにしてよい。`（既存の原則に例外を加えている）
  - `+- **止めた Run は、再起動をまたいで止まったままにする**。… marker を外すのは Human だけ（同上）。`（新しい Human-owned の権限を定めている）
  - `+| \`STATE_CONFLICT\` | RunState の CAS 失敗（revision または stream の位置が古い。並行 resume 等） | RunState store |`（Stop Reason の値域の定義を変えている）
- 裁定のときに考慮しうる事実: 追加した項目のうち 4 項目に「2026-09-25 Human 決定」「2026-09-28 Human 決定」などの注記がある。ただしこれは本文中の記載であって、I4 の証跡（`reviewed_at_sha` / 独立レビュー / 機械証跡）にはあたらない。

### 2-2. `6d626360`（#1441）Merge pull request #1441 docs/ai-loop-v2-bounded-requirement-discovery

- 変更 canon（`git diff --numstat 6d626360^1 6d626360`）: `north-star.md` +104 −2 / `artifact-responsibilities.md` +115 −2 / `evaluation-trust-boundary.md` +15 −0。canon 外は `.claude/rules/working-context.md`、`docs/working/templates/` ほか、合わせて 11 ファイル。
- 差分の要約:
  - `north-star.md`: §1 に用語 2 つ（Bounded Discovery / Traceability Chain）を定義。§2 の Delivery canonical flow で、`Request` と `Plan` の間に `Bounded Discovery` の段を挿入。AI が PBI を作成できること、claim provenance の 3 分類（observed / reported / inferred）、PBI の Admission / Materialization の分離と値域（`materialize | no_action | discover_more` と `update_existing | link_only | create_new`）、application timing と target layer の 2 軸、`harness` は `follow_up` に固定、を追加。§3 に「Review readiness / Quality acceptance / Mutation authority are separate」の節を新設。§6 に「Evidence class / live-shadow trust boundary」の節を新設。§9 の Replan の対象に Goal / Problem / Requirement semantics を加えた。§19 Non-goals に 1 行、§21 の確認項目に 3 行を追加。
  - `artifact-responsibilities.md` §7: 見出しを変更。保持先の表に 6 行を追加。claim class の表、Circular provenance の禁止、acceptance basis の規則を追加。「Feedback-to-PBI admission / materialization」「Generated PBI application path」「Shadow evaluation / write authority boundary」「Live-shadow Evidence ownership」の 4 小節を新設。
  - `evaluation-trust-boundary.md`: §4-1「PBI materialization shadow evaluation の独立性」を新設（maker actual と reviewer expected の分離、`verified` にしてよい条件、Evidence class を昇格させない）。
- **AI の読み（候補）: 規定変更**（4 件のうち差分が最も大きい）
- 根拠行:
  - `+  -> Bounded Discovery (adaptive depth; may be minimal)`（canonical flow に段を挿入している）
  - `+\`target layer = harness\` は North Star §10 のため **常に \`follow_up\`** とし、Active Run の Harness identity を変更する \`replan_current\` は許可しない。`（新しい禁止規則）
  - `+### 4-1. PBI materialization shadow evaluation の独立性`（`evaluation-trust-boundary.md` は §3 で I4 を要求する Evaluation Harness の定義そのものであり、そこに節を新設している）
  - `+\`review_ready=true\` 相当の projection があっても、write / close / suppress / merge authority を暗黙に付与しない。`（authority の境界を定めている）

### 2-3. `0122d6f9`（#1447）docs(ai-loop-v2): converge Runtime Evidence RFC and Production Feedback guide

- 変更 canon（`git show --numstat`）: `README.md` +2 −1 のみ。他の 2 ファイル（`docs/ai/ai-loop-v2/production-feedback-loop.md` 新規 340 行、`docs/rfc/runtime-evidence-feedback-loop.md` 新規 1115 行）は canon 7 本に含まれない。
- 差分の要約: `README.md` の参照順の一覧に `production-feedback-loop.md` を 5 番目として追加し、既存の 5 番目（Phase 1 以降の文書）を 6 番目に繰り下げた。
- **AI の読み（候補）: 索引のみ（non-normative の候補）**。ただし確定は Human が C-4 で名指しして行う。判断できなければ規定変更として扱う。
- 根拠行:
  - `+5. [\`production-feedback-loop.md\`](./production-feedback-loop.md) — Production signal / Runtime Evidence / event-triggered Agent Work の接続ガイド。**non-canon かつ provider-neutral**`
  - `-5. Phase 1 以降で作る Architecture / Contract / State / Verification 文書` → `+6. …`（番号の繰り下げのみ）
  - 追加された文書は冒頭で自己宣言している: `> **Status**: ai-loop V2 design guide（non-canon）。正本は [\`north-star.md\`](./north-star.md) と companion canon。`
- 裁定のときに考慮しうる事実:
  - 失効前の前例として、`283caea6`（#1321、`README.md` への索引 1 行と要約 1 文）を §7 の表が「索引と要約であって規定ではない」と扱い、再レビューを求めなかった。ただしこれは**失効前の I1 例外の下での判断**であり、失効後の「non-normative は Human が C-4 で名指しして確定する」規則をこの前例だけで満たすことはできない。
  - README の参照順は「V2 の Issue / Plan / PR は次の順に参照する」と書かれた節にある。参照順への追加が読み手の解釈に影響するか（実質的に規定か）は、AI では判定できない。

### 2-4. `a3c9146d`（#1487）docs(ai-loop): make capability changes re-evaluation triggers

- 変更 canon（`git show --numstat`）: `north-star.md` +25 −1 のみ。
- 差分の要約: §12（Simplification）に小節「Model / Runtime change is a re-evaluation trigger」を新設した。内容は、Model / Runtime の major update は再評価の Trigger であって簡素化の Permission ではないこと、同じ更新後 Model / Runtime / Effort で WITH / WITHOUT の paired ablation を行うこと、条件が欠けるときは `INCONCLUSIVE` にすること。§14 の 1 文に、baseline と candidate の双方で更新後の Model / Runtime / Effort を固定する要件を加えた。
- **AI の読み（候補）: 規定変更**
- 根拠行:
  - `+Model / Runtime の major update は、既存 Harness の前提が変わったことを示す **再評価 Trigger** として扱う。能力向上そのものを、… 削除・無効化・適用範囲縮小を許可する Permission にはしない。`
  - `+activation 未確認、paired case 不足、sample 不足、必要 Evidence の欠測がある場合は \`INCONCLUSIVE\` とし、簡素化の根拠へ昇格させない。`
  - `-Harness 改善は baseline と candidate を同一 fixture / task で比較する。` → `+… Model / Runtime の能力変化を契機に簡素化を評価する場合も、baseline / candidate の双方で更新後の Model / Runtime / Effort を固定する。`（Evolution evaluation の比較条件を追加している）

## 3. 判定表（下書き）

「事後 I4 か例外扱いか」の列は **Human が裁定する欄で、空欄のままにしてある**。AI は記入しない。

| commit | PR | 変更 canon | 規定変更の候補（AI の読み） | 根拠 | 事後 I4 か例外扱いか（**Human 裁定**） | 事後 I4 の場合に必要な証跡 |
| --- | --- | --- | --- | --- | --- | --- |
| `a6d1ea5f` | #1406 | `artifact-responsibilities.md` §4 / `taxonomy.md` Stop Reason 表 | 規定変更 | CAS 失敗の記録に例外を追加 / halt marker と Human のみが外す権限を新設 / `STATE_CONFLICT` の定義を拡張（§2-1） | | §4 の最低要件を参照 |
| `6d626360` | #1441 | `north-star.md` §1・§2・§3・§6・§9・§19・§21 / `artifact-responsibilities.md` §7 / `evaluation-trust-boundary.md` §4-1 | 規定変更 | canonical flow に段を挿入 / PBI の値域と禁止規則を新設 / Evaluation Trust Boundary に節を新設（§2-2） | | §4 の最低要件を参照 |
| `0122d6f9` | #1447 | `README.md`（参照順の一覧） | 索引のみ（non-normative の候補。確定は Human が C-4 で名指し） | 参照順への 1 行追加と番号の繰り下げのみ。追加した文書は non-canon と自己宣言（§2-3） | | §4 の最低要件を参照（Human が non-normative と確定した場合は不要） |
| `a3c9146d` | #1487 | `north-star.md` §12・§14 | 規定変更 | Trigger は Permission ではない原則、paired ablation の条件、`INCONCLUSIVE` の条件を新設（§2-4） | | §4 の最低要件を参照 |

## 4. 事後 I4 とする場合の最低要件（`phase0-migration.md` §7 から転記）

§7「例外の失効」の「以後の I4 の最低要件」による。commit ごとに次の 3 点が要る。

1. **`reviewed_at_sha` に固定した独立レビュー**。作成者とは別の context で実施し、水準（I1 / I2 など）を記録する。対象 commit（または該当する canon の差分範囲）を含む SHA を `reviewed_at_sha` に書く。
2. **固定 commit で再現できる機械証跡**。コマンドと出力を残し、作成者の外で再実行したもの。CI が緑であるだけでは足りない。
3. **Human C-4**。

I4 の充足記録をどこに置くかは §7 の規定（`docs/working/TASK-1408/handoff.md`）と、issue #1643 の AC-5（Phase 1 exit の確認項目から参照できること）に従う。置き場所は Human が決める。

## 5. 本書で行っていないこと・範囲外の観察

- **行っていないこと**: 4 件の裁定、non-normative の確定、I4 証跡の作成、canon 本文と `phase0-migration.md` の変更、issue と PR へのコメント。4 PR の本文と会話コメント（review 以外）は読んでいない。PR 本文に I4 相当の記録があるかどうかは未確認。
- **範囲外の観察 1**: 測定範囲の終点 `9445df17` より後に、canon に触れた first-parent commit が 3 本ある（`ae56b75f` #1652 / `90047151` #1650 / `8a689907` #1653）。issue #1643 の範囲（`3331e5c4..9445df17`）の外にあるため判定していない。これらに I4 が要るかどうかは別途の確認事項。
- **範囲外の観察 2**: #1441 は canon 外の `.claude/rules/working-context.md` も変更している（`git diff --stat 6d626360^1 6d626360`）。このパスは Hardening Override の対象カテゴリ（`.claude/rules/*.md`）にあたる。本書の論点（canon 7 本の I4）とは別の境界であり、判定していない。
