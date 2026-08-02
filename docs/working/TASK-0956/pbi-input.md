# PBI INPUT PACKAGE — TASK-0956

> Issue: [#956](https://github.com/s977043/plangate/issues/956)（bug / area:workflow / **priority:P2**）
> 検出契機: [#943](https://github.com/s977043/plangate/issues/943) の修正作業（PR [#955](https://github.com/s977043/plangate/pull/955)）。ワーカーが同期スクリプト実行時に検出し、スコープ外として除外
> 関連: [#954](https://github.com/s977043/plangate/issues/954)（26 skill の参照解決不能。同じ `.agents/skills/` → 派生の同期構造に依存する）
> 作成: 2026-08-02（**main `cda229b` で実測**。同期スクリプトを実走し、結果を revert して測定）

## Context / Why

`.codex/skills/` は `.agents/skills/`（正本）からの同期生成物だが、
**CI に drift 検出が無い**ため commit 済みの乖離が残り続けている。

構造原因: [`.github/workflows/sync-plugin-plangate.yml`](../../../.github/workflows/sync-plugin-plangate.yml)
の `drift-check` job（L37-57）は **`plugin/plangate/` 側しか検証しない**（L52 の
`git diff --quiet -- plugin/plangate/`）。`.codex/skills/` は誰も検査しないため、
**正本更新漏れも派生への直接編集も無言で残り続ける**。

### 実測による裏取り（main `cda229b`・2026-08-02）

同期スクリプトを素で実走し、`git checkout -- .codex/` で復元して測定した
（作業ツリーは実行前後とも clean を確認済み）。

| # | 主張 | 実測方法 | 結果 |
|---|------|---------|------|
| 1 | **drift はちょうど 2 件** | `sh scripts/install-plangate-skills-to-codex.sh`（引数なし・exit 0） | `installed_count=2` / `skipped_count=36` / `total_processed=38`。更新されたのは **`ai-loop-cycle` と `plan-review-gate` のみ**。`git diff --stat` = **2 files changed, 9 insertions(+), 42 deletions(-)** |
| 2 | 同期は SKILL.md の verbatim コピー | 38 skill 中 36 本が `cmp -s` で byte 一致 | 変換なし。**差分 = そのまま drift** |
| 3 | 実行後の副作用は 2 ファイルのみ | 実行後の `git status --porcelain` | `M .codex/skills/ai-loop-cycle/SKILL.md` / `M .codex/skills/plan-review-gate/SKILL.md` の 2 行だけ。**`agents/openai.yaml` / `assets/` の再生成差分は発生しない**（既に同期済） |
| 4 | **`ai-loop-cycle` は更新漏れ**（意図的分岐ではない） | `git log` の最終更新日 | 正本 = **2026-07-20 `721edcb`（#886 / TASK-0872 Plan Package 束縛層）**、派生 = **2026-07-11 `0050ece`（#820）**。**正本の方が新しく、#881（07-19）・#886（07-20）の 2 回の更新が派生へ伝播していない** |
| 5 | `ai-loop-cycle` の差分内容 | `diff .agents/... .codex/...` | 4 hunk。①`description`（正本は「同梱 references/00_concept.md が正本」、派生は旧文言）②適用制限節（同上）③**`plan_package` 段落まるごと欠落**（TASK-0872 の `production` / `plan_package` 契約・priority 1.6/1.65）④`MERGE_READY` が派生では `merge-ready` 表記。**いずれも正本の新規追記が届いていない形**で、派生独自の情報は 1 つも無い |
| 6 | **`plan-review-gate` は派生への直接編集** | `git log` + `git log -S` | 正本 = **2026-05-24 `b86a649`（#327）**、派生 = **2026-06-22 `d144ac4`**。派生の方が新しい。36 行の節「C-1 追加品質ゲート: Plan 実行可能性」を追加したのは **`d144ac4`**（`git log -S'C-1 追加品質ゲート: Plan 実行可能性'` で特定） |
| 7 | 当該 36 行は**リポジトリ内で唯一** | `grep -rln 'C-1 追加品質ゲート'`（`.git` 除く） | ヒットは `.codex/skills/plan-review-gate/SKILL.md` **1 ファイルのみ**。正本にも `.claude/skills/` にも `plugin/` にも存在しない = **削除すれば内容が失われる** |
| 8 | 36 行の中身と既存正本の重複度 | `docs/ai/plan-review-readiness-gate.md` を照合 | **「No Placeholders Rule」は部分的に既存**（同 doc L54 が `TBD` / `TODO` / `必要に応じて` / プレースホルダ未置換 → `needs_revision` を規定）。一方 **「Task Sizing Rules」（独立検証可能な成果物 / reviewer 単独 approve 可能な粒度 / setup・config・docs の帰属）に相当する正本は見当たらない** → 取り込み価値は Task Sizing 側にある |
| 9 | **CI の検査範囲は `plugin/plangate/` のみ** | `.github/workflows/sync-plugin-plangate.yml` L52 | `git diff --quiet -- plugin/plangate/` のみ。`.codex/` は対象外 |
| 10 | **workflow の trigger paths に `.codex/**` が無い** | 同 L9-28 | `on.push.paths` / `on.pull_request.paths` はいずれも `.claude/**` / `.agents/skills/**` / `docs/*/ai-loop/**` / `scripts/*` / `plugin/plangate/**`。**`.codex/**` を含まない** → job を足すだけでは「`.codex/` だけを直接編集した PR」で発火しない（本件 `d144ac4` と同型の事故を再び取り逃す） |
| 11 | 既存の codex 向け検査は block できない | 同 L72-73 | `sh scripts/check-codex-skill-spec.sh --warn-only` は **`sync` job（`if: github.event_name != 'pull_request'`）にのみ存在**し、しかも `--warn-only`（同スクリプト L6「`--warn-only` 時は常に 0」）。**PR では走らず、走っても落ちない**。かつ内容は `agents/openai.yaml` の**仕様**チェックであり drift 検査ではない |
| 12 | 既存テストも drift を見ていない | `tests/extras/ta-30-install-skills.sh` L37 | 「リポジトリの `.codex/skills` を上書きする事故を防ぐ」ため **一時ディレクトリに対して**インストーラを検証している。commit 済み `.codex/skills/` の drift は対象外 |
| 13 | required check は 1 本のみ | `gh api repos/s977043/plangate/rulesets/14939019` | rules = `deletion` / `non_fast_forward` / `pull_request` / `required_status_checks`。required は **`["Markdown lint"]` の 1 件のみ**（issue の Non-goals 記載と一致） |
| 14 | **`plugin/plangate/` 側は 0 drift** | `.agents/skills/*/SKILL.md` と `plugin/plangate/skills/*/SKILL.md` を全 38 本 `cmp` | **38/38 一致**。CI 検査がある側は実際に守られており、**「検査の有無」が drift の有無と対応している**（構造原因の裏取り） |
| 15 | test baseline は **452**（issue の 453 ではない） | `sh tests/run-tests.sh`（本 worktree） | **452 passed / 0 failed**（exit 0）。差分 1 件の原因は `tests/extras/ta-13-plangate-setup.sh` **L162 の `[ -d "$PG_T13_ROOT/.git" ]`** で、**git worktree では `.git` がファイル（`gitdir:` ポインタ・85 bytes）**のため TC-17 が SKIP される |

### なぜ問題か（故障確率）

- **正本が正本でなくなる**: `plan-review-gate` は 2 ヶ月以上、派生にだけ品質ゲート
  36 行を持っていた。Codex 経由の利用者と Claude 経由の利用者で **C-1 の判定基準が違う**
- **更新が静かに落ちる**: `ai-loop-cycle` は TASK-0872 の Plan Package 束縛
  （`production` / `plan_package` / priority 1.6・1.65）を派生側が知らない。
  承認境界に関わる契約が片側にだけ入っている
- **検査の有無が結果に直結している**（実測 #14）。`plugin/` は 0 drift、`.codex/` は 2 drift。
  規範だけでは守られないことが同一リポジトリ内で実証されている

## What（Scope）

### In scope

1. **drift 2 件の判定と解消**
   - `ai-loop-cycle`: 正本更新漏れ（実測 #4・#5）→ **正本を正として派生を再生成**
   - `plan-review-gate`: 派生への直接編集（実測 #6・#7）→ **36 行を正本へ取り込むか
     削除するかを判定**し、根拠を残す（判断材料は実測 #8）
2. **構造対応: `.codex/skills/` の drift を CI で検出する**
   - 検査ロジック本体（AI-owned。`scripts/` 配下の shell / python を想定）
   - CI への配線（**`.github/workflows/**` は Hardening Override 対象** → 設計・patch
     提示までが AI-owned、適用は Human-owned）
   - **trigger paths に `.codex/**` を追加すること**（実測 #10。これが無いと
     `d144ac4` と同型の「派生だけを直接編集した PR」を取り逃す）
3. **空振り検査でないことの実証**（意図的に drift を注入した状態で検出を確認）
4. **回帰**: `sh tests/run-tests.sh` が **0 failed**（件数 baseline は AC-6 の注記を参照）

### Out of scope

- **`ai-dev-plan`**（#943 / PR #955 で対応済み。本 issue の作業時に混ぜない）
- **`plugin/plangate/` 側の drift-check**（既に `sync-plugin-plangate.yml` の
  `drift-check` job が担当。実測 #14 のとおり機能している）
- **`.codex/skills/` を生成物でなく正本に格上げすること**（生成関係は維持する）
- **同期スクリプト自体の再設計**（`scripts/install-plangate-skills-to-codex.sh` の
  ロジック変更。drift 検出のための読み取り利用は可）
- **drift 検出を merge blocker（required check）に昇格させること**
  （現状 required は `Markdown lint` 1 本のみ — 実測 #13。昇格は別途判断）
- **`.claude/skills/` の同名 skill**（29 個中 23 個が `.agents/skills/` と同名、
  うち 8 個が内容相違）。`.claude/skills/` は同期スクリプトのソースにも出力先にも
  含まれない**独立集合**であり（`sync-plugin-plangate.sh` L24 の `SKILLS_DIR` は
  `.agents/skills` のみ）、drift の定義が成立しない。**#954 の U-5 に記録済み**
- **`.agents/skills/` 側の参照解決問題 → [#954](https://github.com/s977043/plangate/issues/954) の担当**

## 受入基準

> issue #956 の AC-1〜6 を継承し、実測（trigger paths の欠落・baseline 差異）を
> 反映して精緻化。plan で最終確定する。

- **AC-1**: `ai-loop-cycle` の drift について、**正本更新漏れか意図的分岐かが判定され、
  根拠が記録されている**。判定根拠には **git log による前後関係**
  （正本 2026-07-20 `721edcb` > 派生 2026-07-11 `0050ece`）と
  **差分に派生独自の情報が含まれないこと**（実測 #5）を含める
- **AC-2**: `plan-review-gate` の `.codex/` 側 36 行について、**正本へ取り込むか
  削除するかが判定され、根拠が記録されている**。判定根拠には
  **既存正本 `docs/ai/plan-review-readiness-gate.md` との重複度**（実測 #8:
  No Placeholders は部分重複 / Task Sizing は正本に無い）を含める。
  取り込む場合は **`.agents/skills/plan-review-gate/SKILL.md`（正本）に入れ、
  派生 2 系統（`.codex/` / `plugin/`）を同期スクリプトで再生成**する
- **AC-3**: 上記 2 件の drift が解消し、
  **`sh scripts/install-plangate-skills-to-codex.sh` を素で実行しても
  `git status` が clean である**（現状は `installed_count=2` で 2 ファイルが変更される）
- **AC-4**: `.codex/skills/` の drift を検出する CI 検査が設計され、
  **`.github/workflows/` への patch が Human 適用可能な形で提示されている**。
  patch には **trigger paths への `.codex/**` 追加**を含む（実測 #10。
  含まないと直接編集経路を検出できず、本 issue の構造原因が残る）。
  提示形式は前例に倣う（[`docs/working/TASK-0872/patches/`](../TASK-0872/patches/) の
  `*.patch` + `*.new` + `ho-apply-approval.md` /
  [`docs/working/TASK-0871/approvals/ho-apply-approval.md`](../TASK-0871/approvals/ho-apply-approval.md)）
- **AC-5**: 検査が実際に drift を検出できることが、**意図的に drift を注入した状態で
  実証されている**（空振り検査でないこと）。実証は**負側 2 パターン**で行う:
  - (a) **正本を更新して派生を放置**（= `ai-loop-cycle` 型の更新漏れ）→ 検出
  - (b) **派生だけを直接編集**（= `plan-review-gate` 型 / `d144ac4` 型）→ 検出
  - 併せて **clean 状態で誤検出しない**（陽性・陰性の両側を固定する）
- **AC-6**: `sh tests/run-tests.sh` が **0 failed**。
  ⚠️ **passed 件数の baseline は環境依存**: issue は 453 とするが、
  本 worktree（main `cda229b`）の実測は **452 passed / 0 failed**（実測 #15）。
  したがって **「0 failed」+「作業開始時に同一環境で採った baseline と同値」**
  で判定し、453 という数字を literal に要求しない
- **AC-7（追加 / 責務境界）**: **AI が `.github/workflows/**` を直接編集していない**
  こと。`git diff origin/main --name-only` に `.github/workflows/` が含まれないこと
  を機械検査で固定する（Human が patch を適用した後の commit は別扱い）
- **AC-8（追加 / 非昇格の確認）**: 追加した検査が **required status check になっていない**
  こと（Non-goals の遵守）。`gh api repos/s977043/plangate/rulesets/14939019` の
  `required_status_checks` が `["Markdown lint"]` のままであることを確認する

## Notes from Refinement

### drift 2 件の性質（実測に基づく整理）

| skill | 種別 | 証拠 | 既定の解消方向 |
|---|---|---|---|
| `ai-loop-cycle` | **更新漏れ**（正本 → 派生の伝播失敗） | 正本 07-20 > 派生 07-11。差分 4 hunk すべてが正本側の新規追記で、派生独自情報はゼロ（実測 #4・#5） | **正本を正**として派生を再生成。判断コストは低い |
| `plan-review-gate` | **派生への直接編集** | 派生 06-22 > 正本 05-24。36 行を追加したのは `d144ac4`。同文言はリポジトリ内に他に存在しない（実測 #6・#7） | **取り込み / 削除の判断が必要**。Task Sizing 相当の正本は無く（実測 #8）、削除すると内容が失われる |

### 責務分界（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）

| 対象 | クラス | 根拠 |
|---|---|---|
| `.agents/skills/**`（正本編集） / `.codex/skills/**`（同期再生成） | **AI-owned** | HO 9 カテゴリ非該当（`scripts/hooks/check-plan-hash.sh` L124-134 の case 文で実測） |
| 検査スクリプト本体（`scripts/*.sh` / `scripts/*.py`。ただし `scripts/hooks/*.sh` を除く） | **AI-owned** | HO は `scripts/hooks/*.sh` のみ。`scripts/` 直下は対象外 |
| **`.github/workflows/*.yml` の適用** | **Human-owned** | HO 9 カテゴリに `.github/workflows/*.yml\|*.yaml` が明記。**maintenance 窓内でも常時 block**（同 hook L135-141） |
| required check への昇格 / ruleset 操作 | **Human-owned** | 権限操作。かつ本 PBI の Non-goals |
| PR マージ | **Human-owned** | C-4 |

### CI 検査の設計上の論点（plan で決着させる）

1. **配線先**: 既存 `sync-plugin-plangate.yml` の `drift-check` job を拡張するか、
   新規 workflow を立てるか。既存拡張なら **trigger paths への `.codex/**` 追加**が必須
   （実測 #10）。新規なら paths を最初から正しく書ける代わりに job が 1 本増える
2. **判定方法**: (a) 同期スクリプトを実行して `git diff --quiet -- .codex/` を見る
   （`plugin/` 側と同型・実装が簡単だが CI で書き込みが走る）/
   (b) 読み取りのみの比較スクリプトを別途書く（副作用ゼロだが同期ロジックの
   二重実装リスク）。**(a) が既存パターン踏襲**（`sync-plugin-plangate.yml` L51-56）
3. **`agents/openai.yaml` / `assets/` を検査対象に含めるか**。今回は差分ゼロだった
   （実測 #3）が、SKILL.md だけを見る検査だと frontmatter 由来の生成物 drift を見逃す
4. **`--warn-only` にしないこと**: 既存の `check-codex-skill-spec.sh` 呼び出しは
   `--warn-only` かつ PR で走らないため機能していない（実測 #11）。同じ轍を踏まない

### Mode 見込み: high-risk（plan で確定）

- **例外ルールが支配的**: `.github/workflows/*.yml` は **Hardening Override 対象 9 カテゴリ**
  に該当 → [`mode-classification.md`](../../../.claude/rules/mode-classification.md)
  「**承認境界周辺の変更 → 最低でも「高」**」が発動。
  併せて **`lite_eligible=false` 強制 + Standard C-3 同期固定**
  （[`working-context.md`](../../../.claude/rules/working-context.md) AC-10 Hardening Override）
- **定量**: 想定変更ファイルは **10〜14 本**
  （派生 2 + 正本 1 + 派生再生成 2 + 検査スクリプト 1 + テスト 1 +
  `tests/run-tests.sh` 登録 1 + patch 一式 3 + 判定記録 1〜2）→ **high 帯（6-15）**
- **受入基準**: 8 件（AC-1〜8）→ **high 帯（6-10）**
- **定性**: 変更種別は **code**（shell / CI yml を含む）→ **doc-light 不適用**。
  リスクは「検査が空振りする」「trigger paths 欠落で発火しない」に集中し、
  ロールバックは容易（検査追加は revert 可能・skill 内容は git で戻せる）
- **判定: high-risk**（`lite_eligible=false` / **人間 C-3 同期必須** /
  V-2・V-3 実行対象 / V-4 はスキップ）
- **critical へ引き上げる条件**（plan で該当したら再判定）:
  - AC-2 で 36 行の取り込みを決め、それが **他 skill や `docs/ai/` 正本の改訂へ波及**する
  - 変更ファイルが **16 本以上**になる
  - 検査を required check へ昇格させる方向へ Non-goals を改訂する

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| **trigger paths に `.codex/**` を足し忘れる** | job は追加されるが、`.codex/` だけを直接編集した PR では**発火しない**。`d144ac4` と同型の事故を再び取り逃し、「検査を入れた」という誤った安心が残る（**最重大**） | AC-4 で patch への `.codex/**` 追加を明示要求。AC-5(b)「派生だけを直接編集 → 検出」の負側テストで固定 |
| **検査が空振りする**（`--warn-only` / PR で走らない / 常に exit 0） | 既存 `check-codex-skill-spec.sh` と同じ状態になる（実測 #11） | AC-5 で陽性 2 パターン + 陰性 1 パターンの実証を必須化 |
| **AI が `.github/workflows/` を直接編集してしまう** | HO 違反（`check-plan-hash.sh` は maintenance 窓内でも block） | AC-7 の機械検査。patch + `.new` + `ho-apply-approval.md` の前例形式（TASK-0871 / TASK-0872 / TASK-0907）を踏襲 |
| **Human 適用待ちで PBI が長期 BLOCKED になる** | `.github/workflows/` の適用は Human-owned のため、AI 側の作業が終わっても完了できない | 「AI-owned 分の完了」と「Human 適用」を **status.md の BLOCKED（`blocker` / `owner` / `unblock_condition`）** で分離記録する。検査スクリプト本体はローカル実行可能な形で先に完成させる |
| **`plan-review-gate` の 36 行を安易に削除して内容が失われる** | Task Sizing Rules 相当の正本はリポジトリ内に存在しない（実測 #7・#8） | AC-2 で「重複度の照合結果」を判断根拠に含めることを必須化。削除する場合も **どの正本が代替するか**を明記 |
| **#954 と `.agents/skills/` を同時編集して conflict** | #954 は 27 skill / 28 ファイルを編集予定で、`plan-review-gate` も対象に含む（クラス A） | **実行順序を plan で確定**。本 PBI が先に `plan-review-gate` 正本を触るなら #954 が rebase する。#954 側の Risk 表にも相互参照済み |
| **同期スクリプトを CI で実行して書き込み副作用が出る** | ephemeral runner なので実害は小さいが、判定方法 (a) は「実行してから diff」であり fork PR の権限設計に注意 | 既存 `drift-check` job（`permissions: contents: read`）と同じ形にする |
| **baseline 件数の取り違えで AC-6 が誤判定される** | worktree では 452、main checkout では 453。数字を literal に要求すると常に FAIL / 常に PASS のどちらかになる | AC-6 に環境依存の注記と根拠（`ta-13` L162 の `[ -d .git ]`）を記載済み。**作業開始時に同一環境で baseline を採る** |

### Unknowns

- **U-1（最優先）**: **`plan-review-gate` の 36 行を取り込むか削除するか**。
  取り込む場合、置き場所は (a) `.agents/skills/plan-review-gate/SKILL.md` /
  (b) `docs/ai/plan-review-readiness-gate.md`（既存正本に統合）/ (c) 両方
  （skill は正本を参照）。**(b)/(c) を採ると #954 のクラス C 問題
  （`docs/**` は導入先で解決不能）に接続する**ため、#954 の方式決定と整合が要る
- **U-2**: **CI 検査の配線先**（既存 `sync-plugin-plangate.yml` の `drift-check` 拡張
  vs 新規 workflow）。既存拡張のほうが job 数を増やさないが、
  workflow 名が `sync-plugin-plangate` のままだと `.codex` を含む実態と名前が乖離する
- **U-3**: **検査対象の粒度**（`SKILL.md` のみ / `agents/openai.yaml` と `assets/` も含む /
  `.codex/skills/` 全体）。今回は SKILL.md 以外に差分が無かった（実測 #3）が、
  それは「現時点で一致している」だけで検査範囲の根拠にはならない
- **U-4**: **判定方法**（同期スクリプト実行 → `git diff` vs 読み取り専用比較）。
  前者は既存パターン踏襲だが CI で書き込みが走る
- **U-5**: **#954 との実行順序**。本 PBI は HO の Human 適用待ちが入るためリードタイムが
  読めない。#954 を先行させる場合、その PR が `.codex/` の drift 2 件を巻き込む
  （#954 側の U-4 に記録済み）
- **U-6**: **`ai-loop-cycle` の派生再生成が `.codex/` 側の運用に影響しないか**。
  正本が持つ `plan_package` / `production` 契約（TASK-0872）は
  `scripts/ai-loop/` の存在を前提にするが、**`.codex/skills/ai-loop-cycle/` には
  `scripts/` も `references/` も配られていない**（#954 の実測 #11）。
  「正本を正として同期する」ことで Codex 利用者が読めない参照を増やす可能性がある
- **U-7**: **過去に同型の drift が何回発生したか**（再発率）。本 PBI では
  現時点の 2 件しか測っていない。検査導入の費用対効果の根拠として履歴を数えるかは plan で判断

### Assumptions

- main `cda229b`（PR #955 マージ後）を作業の起点とする
- `.agents/skills/` が skill の唯一の正本で、`.codex/skills/` と
  `plugin/plangate/skills/` は同期生成物である
  （`scripts/install-plangate-skills-to-codex.sh` L25 / `scripts/sync-plugin-plangate.sh` L24 で実測）
- 同期スクリプトのロジックは本 PBI で変更しない（Out of scope）ため、
  「素で実行して clean」が drift ゼロの十分条件として使える
- HO 9 カテゴリ（`scripts/hooks/check-plan-hash.sh` L124-134）に
  `.github/workflows/*.yml` が含まれ、AI は適用できない
- required status check は `Markdown lint` 1 本のまま維持される（Non-goals）
- `sh tests/run-tests.sh` の baseline は **同一環境で作業開始時に採り直す**
  （worktree では 452 / main checkout では 453。AC-6 の注記参照）
