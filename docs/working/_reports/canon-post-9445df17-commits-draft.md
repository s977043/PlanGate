# canon 7 本: `9445df17` より後に merge された commit の判定材料（下書き）

> **測定基点**: `origin/main` = `95e0cd45471e963fa7a67a85bf97a38f2b564f11` / 2026-11-23
> **位置づけ**: **判断材料であって裁定ではない。** 本書の「規定変更の候補」と独立性の読みはすべて AI の読みであり、確定したものではない。「事後 I4 か例外扱いか」の欄は空欄のままにしてある。裁定は Human が行う。
> **対象**: `9445df17`（TASK-1408 の分岐元）より後に canon 7 本へ触れた first-parent commit。`3331e5c4..9445df17` の 4 commit は issue #1643 の範囲で、判定材料は [`1643-canon-post-expiry-commits-draft.md`](./1643-canon-post-expiry-commits-draft.md) にある。本書はその範囲外の観察 1（同書 §5）を扱う。
> **前提**:
>
> - non-normative（規定変更ではない）と確定できるのは Human だけで、C-4 で対象を名指しして承認する。判断できなければ規定変更として扱う（`.github/PULL_REQUEST_TEMPLATE.md` の canon チェック項目、`phase0-migration.md` §7「例外の失効」の non-normative の判定 :358）。
> - LLM のレビュアーは non-normative を確定できない。本書の読みもこれに従い、「候補」として書く。
> - 独立性は `evaluation-trust-boundary.md` §4 の表（:96〜102）に従って読む。I1 は「same model / separate context + role + run」で定義されており、**別アカウントは要件ではない**。同じアカウントからの投稿であることだけを理由に不適格とはしない。context・role・run が判別できないものは「独立性は未確認」と書く。

## 0. canon 7 本と I4 の最低要件

正本は `docs/ai/ai-loop-v2/phase0-migration.md` §7（「独立レビュー記録の要求」のコマンド例 :225〜233 と、「経緯」に列挙された 7 本 :373）。

- `docs/ai/ai-loop-v2/README.md`
- `docs/ai/ai-loop-v2/north-star.md`
- `docs/ai/ai-loop-v2/phase0-migration.md`
- `docs/ai/ai-loop-v2/taxonomy.md`
- `docs/ai/ai-loop-v2/harness-manifest.md`
- `docs/ai/ai-loop-v2/evaluation-trust-boundary.md`
- `docs/ai/ai-loop-v2/artifact-responsibilities.md`

失効: §7「例外の失効（記録: TASK-1408）」（:334〜）によると、例外は 2026-09-29（UTC）に失効した。以後、canon 7 本の規定変更には I4 が要る。

§7「以後の I4 の最低要件」（:357）。本書の判定表はこの 3 点で列を分ける。

1. **R1 独立レビュー**: `reviewed_at_sha` に固定した独立レビュー。作成者と別の context で実施し、水準（I1 / I2 など）を記録する。
2. **R2 機械証跡**: 固定 commit で再現できるコマンドと出力で、作成者の外で再実行したもの。CI 緑だけでは足りない。
3. **R3 Human C-4**。

## 1. 対象 commit の列挙

```sh
git log --first-parent --format='%H %ad %an | %s' --date=iso-strict 9445df17..origin/main -- \
  docs/ai/ai-loop-v2/README.md docs/ai/ai-loop-v2/north-star.md \
  docs/ai/ai-loop-v2/phase0-migration.md docs/ai/ai-loop-v2/taxonomy.md \
  docs/ai/ai-loop-v2/harness-manifest.md \
  docs/ai/ai-loop-v2/evaluation-trust-boundary.md \
  docs/ai/ai-loop-v2/artifact-responsibilities.md
```

出力（exit 0）:

```text
8a68990765044b2e65f82df14541dcf40d84f04b 2026-11-13T08:19:21+09:00 mine_take | docs(TASK-1408): #1650 merge 後の記録を追従する (#1653)
90047151b5997a9634948b41441ad39ee6aaabb4 2026-11-13T07:38:50+09:00 mine_take | docs(ai-loop-v2): canon I1 例外の失効を記録し I4 へ移行する（TASK-1408） (#1650)
ae56b75f00f748e133c958b75f8ec67dcb853125 2026-11-13T06:55:24+09:00 mine_take | docs: #1649 適用後の EH-3 no-task 記述を同期する (#1652)
```

**先行値との照合**: 3 commit と PR 番号は、1643 下書き §5 の範囲外の観察 1 と依頼時の先行値（`ae56b75f` #1652 / `90047151` #1650 / `8a689907` #1653）と**一致した**。`--first-parent` を外しても同じ 3 本だった（3 本とも squash で、親は 1 本）。

## 2. merge 主体と review

`gh pr view <PR> --json mergedBy,reviews,mergedAt,author,body,mergeCommit,headRefOid`（3 件とも exit 0）。会話コメントは `gh pr view <PR> --json comments` で読んだ。

| PR | mergeCommit | mergedAt (UTC) | author | mergedBy | reviews（state / 投稿者） | APPROVED 数 | 会話コメントのレビュー |
| --- | --- | --- | --- | --- | --- | --- | --- |
| #1652 | `ae56b75f` | 2026-11-12T21:55:25Z | `s977043` | `s977043` | COMMENTED / `copilot-pull-request-reviewer`（quota 超過で未実行） | **0** | `chatgpt-codex-connector` の summary（commit `f21bddd0` = head、指摘なし）。投稿は 21:55:29Z で **merge の 4 秒後** |
| #1650 | `90047151` | 2026-11-12T22:38:51Z | `s977043` | `s977043` | COMMENTED / `copilot-pull-request-reviewer`（quota 超過で未実行） | **0** | (a) `s977043` 名義の「exact-head レビュー（head `5dae38c0`）: NOT_OK」（2026-11-12T17:38:41Z）。(b) `chatgpt-codex-connector` の summary（commit `5631e140` = 最終 head、指摘なし、22:28:45Z で merge の約 10 分前） |
| #1653 | `8a689907` | 2026-11-12T23:19:22Z | `s977043` | `s977043` | COMMENTED / `copilot-pull-request-reviewer`（quota 超過で未実行） | **0** | `chatgpt-codex-connector` の summary（commit `ec387380` = head、指摘なし）。投稿は 23:19:28Z で **merge の 6 秒後** |

- 3 件とも author = mergedBy = `s977043`。**同じアカウントであることだけでは、Human 操作かどうかも、レビューの独立性も判定しない**（前提を参照）。GitHub 上の記録からは、merge 操作の主体（Human か、Human のアカウントで動く AI か）も、`s977043` 名義のコメントを書いた context・role・run も判別できない。
- 3 PR とも本文は `.github/PULL_REQUEST_TEMPLATE.md` の節（Validation の canon チェック項目を含む）を使っていない。canon チェック項目は #1650 自身が追加したものなので、#1652 の merge 時点（#1650 の 43 分前）では main のテンプレートにまだ無かった。

## 3. commit ごとの差分と AI の読み

### 3-1. `ae56b75f`（#1652）docs: #1649 適用後の EH-3 no-task 記述を同期する

- 変更 canon（`git show --stat`）: `phase0-migration.md` +1 −1 のみ。canon 外は `docs/ai/hook-enforcement.md`、`docs/workflows/ai-loop/rollout-policy.md`、`plugin/plangate/skills/ai-loop-cycle/references/rollout-policy.md`。
- 差分の要約: §4 Issue migration matrix の Autonomy / policy 表、#1197 の行（現行 :121）の説明欄の末尾に 1 文を追記した。分類（**SUPERSEDE + REGRESSION**）は変えていない。
- **AI の読み（候補）: 状態の記録の追記（non-normative の候補）**。ただし確定は Human が C-4 で名指しして行う。判断できなければ規定変更として扱う。
- 根拠行:
  - `+| #1197 no-task startup circularity | **SUPERSEDE + REGRESSION** | … 旧経路の局所修正を V2 core に持ち込まない。旧経路には #1649 で暫定の案 B を適用済みだが、V2 では引き続き bootstrap で解消する |`
  - 前半の「旧経路には #1649 で暫定の案 B を適用済み」は Legacy 側の事実の記録。後半の「V2 では引き続き bootstrap で解消する」は、同じ行の既存文「V2 Plan-first bootstrap が解消すべき構造的回帰 fixture として保持」の言い直しと読める。
- 裁定のときに考慮しうる事実:
  - migration matrix は「V2 で何をどう扱うか」の分類表であり、説明欄の文言が分類の解釈に影響するか（実質的に規定か）は AI では判定できない。「暫定の案 B」を Legacy に入れたことが §2 freeze policy の例外に当たるかは本書の論点外（#1649 の扱い）。
  - PR 本文の確認は `sh tests/extras/ta-26-plugin-sync.sh → 47 passed / 0 failed` のみで、作成者による実行。

### 3-2. `90047151`（#1650）docs(ai-loop-v2): canon I1 例外の失効を記録し I4 へ移行する（TASK-1408）

- 変更 canon（`git show --stat`）: `phase0-migration.md` +39 のみ（削除 0）。canon 外は `.github/PULL_REQUEST_TEMPLATE.md` +1 と `docs/working/TASK-1408/` 配下 29 ファイル。
- 差分の要約:
  - §7 に小節「例外の失効（記録: TASK-1408）」を新設（現行 :334〜366）。失効日時と一次証拠（#1402）、M-1〜M-3 の 3 時点の実測、baseline を更新しないこと、遡及しないこと、`3331e5c4..9445df17` の 4 commit を #1643 に分離すること、**再測定の規則の終了**、**以後の I4 の最低要件**、**non-normative の判定は Human だけが C-4 で名指しして確定する**、I4 の充足記録の置き場所、#1329 の残指摘 4 件の裁定表。
  - §8 に小見出し「Phase 1 exit criteria」を新設し、未チェックの 2 項目（#1643 の Human 裁定、`9445df17` より後の canon 規定変更がすべて I4 で採用されていること。「例外は置かない」）を追加。
- **AI の読み（候補）: 規定変更**（3 件のうち差分が最も大きい）
- 根拠行:
  - `+- **以後の I4 の最低要件**: (1) \`reviewed_at_sha\` に固定した独立レビュー。… (2) 機械証跡は、固定 commit で再現できるコマンドと出力で、作成者の外で再実行したもの。CI 緑だけでは足りない。(3) Human C-4。`（I4 の充足条件を新たに定めている）
  - `+- **non-normative の判定**: 変更が規定変更でないと確定できるのは Human だけで、C-4 で対象を名指しして承認する … LLM のレビュアーは確定できない。判断できない場合は規定変更として扱う。`（判定主体の規則を新設している）
  - `+- **再測定の終了**: … 記録と再測定の規則はここで終了し、以後は I4 証跡で判定する。`（既存 §7 判定規則 :331 の再測定時機を終了させている）
  - `+- [ ] \`9445df17\` より後の canon 7 本の規定変更が、すべて I4（§7 の最低要件）で採用されている。例外は置かない`（Phase 1 の exit criteria を追加している）
- 裁定のときに考慮しうる事実:
  - 本 commit は本書の判定表が使う I4 の最低要件そのものを導入した commit である。**自分が導入した要件で自分を測ることになる**点は、Human が裁定のときに考慮しうる。
  - 本 commit の canon 差分は、TASK-1408 の canon commit `e5573cc8`（親 `9445df17`）の追記と一致する。`git diff 6d1f7a6b 5631e140 -- docs/ai/ai-loop-v2` の差分は #1652 の 1 行（main の取り込みで入ったもの）だけで、`git diff 5631e140 90047151` は空（squash の tree は PR head `5631e140` と同一）。
  - PR head `5631e140` は「Merge branch 'main' into docs/TASK-1408-plan」（committer = `GitHub`、2026-11-12T22:28:37Z。下記の裁定を status.md に記録した `5f05ffa6` の 54 秒後）。一方、`docs/working/TASK-1408/status.md:24` と `handoff.md:62` は「Human 裁定（2026-11-13）により main を取り込まず、照合点は evidence head `6d1f7a6b` に固定」と記録している。照合点を `6d1f7a6b` に固定したことと、PR head で main を取り込んだことは両立しうるが、**記録の文言（main を取り込まず）と branch の実際（取り込んだ）が一致していない**。誰が取り込み操作をしたかは GitHub 上から判別できない。

### 3-3. `8a689907`（#1653）docs(TASK-1408): #1650 merge 後の記録を追従する

- 変更 canon（`git show --stat`）: `README.md` +1 のみ。canon 外は `docs/working/TASK-1408/` の `INDEX.md` / `handoff.md` / `status.md`。
- 差分の要約: 冒頭の Status ブロックに 1 行を追加した（現行 :4）。
- **AI の読み（候補）: 索引（Status 行）の追記（non-normative の候補）**。ただし確定は Human が C-4 で名指しして行う。判断できなければ規定変更として扱う。
- 根拠行:
  - `+> **Canon exception**: I1 例外は 2026-09-29（UTC）に失効した（[\`phase0-migration.md\`](./phase0-migration.md) §7、TASK-1408）。以後の canon 7 本の規定変更は I4 を要する`
  - §7 :220「`README.md` / `north-star.md` の Status 行の … 表記は索引であり、充足判定の正本は本節の `reviewed_at_sha` 欄とする」。追加行は §7 :336〜337 の内容の要約で、新しい規則を加えていないと読める。
- 裁定のときに考慮しうる事実:
  - PR 本文に「canon 本文と `.github/PULL_REQUEST_TEMPLATE.md` は変更しない」とある。`README.md` は canon 7 本の 1 本なので、**PR 本文の記述と差分が字面では食い違う**（「canon 本文」が `phase0-migration.md` を指すつもりだった可能性はあるが、本書では判断しない）。
  - PR 本文に「テストは実行していない（docs のみ）」とある。

## 4. 既存の I4 証跡（§7 の最低要件ごと）

### 4-1. #1652 / #1653

| 要件 | #1652 | #1653 |
| --- | --- | --- |
| R1 独立レビュー（`reviewed_at_sha` 固定・別 context・水準の記録） | **無**。`reviewed_at_sha` と水準の記録は PR 本文・review・コメントのいずれにも無い。Codex connector の summary は head SHA を持つが、merge の 4 秒後の投稿で、水準の記録も無い | **無**。同上。Codex connector の summary は merge の 6 秒後の投稿 |
| R2 機械証跡（固定 commit で再現・作成者の外で再実行） | **無**。PR 本文の ta-26 の結果は作成者の実行で、作成者の外での再実行の記録は無い | **無**。PR 本文に「テストは実行していない」 |
| R3 Human C-4 | **未確認**。merge の事実はある（mergedBy = `s977043`）。Human の操作かどうかは GitHub 上から判別できず、Human C-4 と記した記録も見つからなかった | **未確認**。同上 |

### 4-2. #1650（TASK-1408 の記録との照合）

`docs/working/TASK-1408/handoff.md:41`（1408-AC-6 = WARN）は「I4 の機械証跡は未充足。… I4 を充足とみなすかは Human の判断であり、本表では判定しない」と書き、:47 と :49 も I4 の充足を宣言していない。以下は TASK-1408 配下（handoff.md / status.md / review-external.md / `evidence/independent-rerun.txt`）と PR #1650 のコメントを、§7 の最低要件に 1 つずつ照らしたもの。

| 要件 | 記録の所在 | AI の読み |
| --- | --- | --- |
| R1 `reviewed_at_sha` | `status.md:87` = `6d1f7a6b5ff52cda320e7ed99fdb9ad0ccf3a311`（記録者: 独立 worker（T-10））。handoff.md メタ情報の `evidence_head` も同値 | **有**。canon の追記は `6d1f7a6b` の時点で merge 後と同一（§3-2）。`6d1f7a6b` より後の canon 差分は #1652 の 1 行のみで、これは #1652 側の差分 |
| R1 別 context での実施 | `status.md:92`「独立 worker（作成者ではない Claude サブエージェント）/ 2026-11-12 08:36」。PR #1650 のコメント (a) は `s977043` 名義で `6d1f7a6b` での check.sh 再実行（rc=0）を報告。exec レビュー X-R1〜X-R5 は「オーガナイザーが実施」（`review-external.md:108〜110`）で、対象は下書き clone の `80e49220`（転記後の SHA ではない） | **独立性は未確認**。別 context と記録されているが、context・role・run の分離はリポジトリと GitHub 上からは機械的に確かめられない（`evaluation-trust-boundary.md` §4-1 :122 の「機械的に確認できない独立性は `verified` とせず … assertion として区別する」と同じ扱い）。コメント (a) も同様 |
| R1 水準の記録 | `status.md:94` = **I1**（記録者: 作成者（canon 定義との照合のみ））。C-2 R3 には Codex（I2）の記録があるが（`review-external.md:74`）、対象は plan であり canon commit ではない。Codex connector の summary（コメント (b)、`5631e140`）は separate model の自動レビューだが、水準の記録は無い | **有（I1 と記録）**。ただし水準の欄は作成者が記入している。コメント (a) の指摘 9 も「T-10 は I1。AC-6 を I4 に近づける材料にはならない」と書いている |
| R2 機械証跡 | `evidence/check.sh` / `measure.sh`（sha256 は `status.md:88〜89`）。T-10 の再実行出力 `evidence/independent-rerun.txt`（REPRO-CHECK 11 項目と TC 全件 exit=0、rc=0）。陽性対照 rc=3。コメント (a) にも `6d1f7a6b` での再実行 rc=0 の報告 | **未確認**。固定 commit での再現手順と、作成者以外とされる実行の記録はある。ただし handoff.md:41 自身が「I4 の機械証跡は未充足」と書き、`status.md:101` の残存脅威モデルは「改ざん」を守らないものとしている。再実行者の独立性も R1 と同じく未確認 |
| R3 Human C-4 | handoff.md:42（1408-AC-7 = PASS）「Human が C-4 で PR #1650 を merge した」、`status.md` のフェーズ履歴の最終行（07:38 done） | **未確認**。merge の事実はある（mergedBy = `s977043`、`mergedAt` 2026-11-12T22:38:51Z）。Human の操作と記録されているが、GitHub 上の記録からは判別できない |

## 5. 判定表（下書き）

「事後 I4 か例外扱いか」の列は **Human が裁定する欄で、空欄のままにしてある**。AI は記入しない。既存の I4 証跡の列は §4 の要約で、「有」「無」「未確認」は AI の読みである。

| commit | PR | 変更した canon | 規定変更の候補（AI の読み） | 根拠 | R1 独立レビュー | R2 機械証跡 | R3 Human C-4 | 事後 I4 か例外扱いか（**Human 裁定**） |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `ae56b75f` | #1652 | `phase0-migration.md` §4（#1197 の行、+1 −1） | 状態の記録の追記（non-normative の候補。確定は Human が C-4 で名指し） | 分類は不変。Legacy の事実と既存文の言い直し（§3-1） | 無 | 無 | 未確認 | |
| `90047151` | #1650 | `phase0-migration.md` §7（失効の記録）・§8（Phase 1 exit criteria）、+39 | 規定変更 | I4 の最低要件・non-normative の判定主体・再測定の終了・Phase 1 exit criteria を新設（§3-2） | `reviewed_at_sha` は有。水準は I1 と記録。独立性は未確認 | 未確認（handoff は未充足と記載） | 未確認（handoff は Human C-4 と記載） | |
| `8a689907` | #1653 | `README.md` Status 行（+1） | 索引の追記（non-normative の候補。確定は Human が C-4 で名指し） | Status 行は索引（§7 :220）。§7 の失効記録の要約（§3-3） | 無 | 無 | 未確認 | |

## 6. 本書で行っていないこと・範囲外の観察

- **行っていないこと**: 3 件の裁定、non-normative の確定、独立性の確定、I4 証跡の作成、canon 本文・`phase0-migration.md`・TASK-1408 配下・既存レポートの変更、issue と PR へのコメント。`docs/working/TASK-1408/evidence/` の check.sh は再実行していない（本書は記録の有無を照らしただけ）。
- **範囲外の観察 1**: #1650 は canon 外の `.github/PULL_REQUEST_TEMPLATE.md` も変更している。このパスは Hardening Override の対象カテゴリ外だが、canon の I4 要求を PR ごとに自己申告させる項目そのものである。本書の論点（canon 7 本の I4）とは別で、判定していない。
- **範囲外の観察 2**: 1643 下書き（#1657）の §1-2 には、#1447 / #1487 の `s977043` 名義の review を「author と同じアカウント」を理由に独立レビューの証跡から除外する記述が残っている。是正は PR #1658（本書の測定時点で OPEN）で扱われている。本書は #1658 の是正後の読み方（独立性は未確認）に合わせた。
- **範囲外の観察 3**: 本書の測定のために、PR #1650 の head（`5631e140`）を `git fetch origin pull/1650/head` で取得した（origin には何も書いていない）。上記の比較は SHA で書いてあるので、この fetch をすれば誰でも再現できる。
