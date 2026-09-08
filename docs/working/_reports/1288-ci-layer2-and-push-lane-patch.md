# #1288 段 3 — CI 層 2 の追加と、drift-check が push で走らない構造欠陥の是正（`git apply` 可能形 patch / **Human 適用**）

> 測定基点: **`origin/main` = `c12edc6f`**（#1305 の再同期 `d805aba0` と #1308 の curated 保護を含む）/ 2026-09-09。
> 本書は **v2**。v1（PR #1307 で提示した patch）はマージ後の敵対レビューで **major 2 件**が実測検出され、そのままでは CI が即 FAIL する状態だった。§9 に是正内容を記録する。
> 位置づけ: **既存ギャップの是正**。`.github/workflows/**` は Hardening Override 対象のため **AI は patch 提示まで・適用は Human-owned**。
> 本セッションで AI が編集した repo 内ファイルは**本ファイル 1 本のみ**。workflow の実編集と全検証は `git clone --no-hardlinks --no-local` で作った **repo 外複製**（`/tmp/pg1288c` / `/tmp/pg1288e`）で行い、patch は `git diff` で取り出した（`sed` 手加工なし）。
> 先行調査の正本: [`1288-codex-skills-drift-and-ci-patch.md`](./1288-codex-skills-drift-and-ci-patch.md)（層 1 / 層 2 の設計・全数照合・正否判定）。本書はその **§6 patch を現行 main 向けに設計し直したもの**。

---

## 0. 結論先行

| 項目                           | 結論                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **先行書 §6 patch の適用状態** | **未適用だが、採用しない**。fwd rc=0 / rev rc=1（＝当たるが入っていない）。ただし独立 workflow `codex-skills-drift.yml` を新設する設計で、**層 1 は段 1（#1226 PATCH-B）が既存 `sync-plugin-plangate.yml` に入れた検査と重複**する。§1                                                                                                |
| **本書の patch（v2）**         | 既存 `sync-plugin-plangate.yml` を 1 ファイル改修（**+86 / -4**、`@ c12edc6f`）。(a) PR レーンに**層 2** を追加、(b) **push(main) レーンに `.codex/skills` 再同期＋bot 出力 gate＋自動 PR** を追加、(c) `paths` に installer を**両側対称**で追加。§3                                                                                 |
| **構造欠陥（2）の実体**        | `drift-check` job は `if: github.event_name == 'pull_request'`。`sync` job は **plugin レーンしか再生成しない**。よって `.codex/skills` は push(main) 側に**検知も是正も無い**。2026-09-08 に main へ drift が入って CI が緑のままだった経路はこれ。§2                                                                                |
| **採った是正**                 | push レーンを「赤くする」のではなく、**plugin レーンと同じ既存パターン（bot が是正 PR を出し merge は Human-owned / C-4）** を `.codex` にも適用。加えて bot 出力自体に **installer 非依存の byte 照合**を掛ける（bot の PR は `GITHUB_TOKEN` 由来のため `pull_request` workflow を起動しないという GitHub の既知仕様への手当て）。§4 |
| **v1 からの是正 2 点**         | (major-1) 層 2 / push レーンの述語から **`agents/openai.yaml` を除外**し、installer 呼び出しを **`--json`** にした。(major-2) bot 出力 gate の対象集合を層 1 と同一（**`SKILL.md` + `references/*.md`**）にした。§9                                                                                                                   |
| **ta-71 KNOWN-GAP**            | patch 適用後も **27 passed / 0 failed**（未適用ベースラインと同数）。TC-20 / TC-22 は `sync-paths-known-gap-1249.flag` の `GAP-DECL` と**完全一致**を維持。§6                                                                                                                                                                         |
| **positive control**           | 層 2 は 3 クラス（内容改竄 / skill 内余剰 / 孤児 skill dir）、bot 出力 gate は **3 クラス**（`SKILL.md` 改竄 / installer no-op / **`references/*.md` 改竄**）、`Check for changes` は両値をサンドボックス実測で確認。§5                                                                                                               |

---

## 1. 先行書 §6 patch の適用状態（実測）

抽出（先行書 §6.1 と同じ marker 規則）:

```sh
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1288-codex-skills-drift-and-ci-patch.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/p1288.patch
```

| 方向 | コマンド                                | 実測 rc                                                                        | 判定         |
| ---- | --------------------------------------- | ------------------------------------------------------------------------------ | ------------ |
| fwd  | `git apply --check /tmp/p1288.patch`    | **0**                                                                          | 当たる       |
| rev  | `git apply --check -R /tmp/p1288.patch` | **1**（`.github/workflows/codex-skills-drift.yml: No such file or directory`） | 入っていない |

**判定: 未適用（stale ではない）。** それでも本書は **採用しない**。理由:

- 先行書 §6.3 末尾が既に指摘しているとおり、**層 1 は #1226 PATCH-B と役割が重複**する。PATCH-B は段 1（`f455a7b7`）で `sync-plugin-plangate.yml` の `drift-check` job に「Verify .codex/skills mirrors .agents/skills canon (#1226)」として**適用済み**。同じ照合を 2 workflow で回すことになる。
- 先行書 §6.3 が示す最小構成は「**PATCH-B（層 1）＋ 本 patch の層 2 ステップだけ**」。本書はそれを採り、さらに §2 の構造欠陥を同一ファイルで塞ぐ。
- 独立 workflow を新設すると `paths` 集合が 2 箇所に分裂し、`.codex/skills/**` の起動条件がどちらに属するか将来ずれる。段 1 で `.codex/skills/**` は既に `sync-plugin-plangate.yml` の両 `paths` に入っている（実測）。

---

## 2. 構造欠陥（2）— drift-check は push で走らない

```text
jobs.drift-check.if : github.event_name == 'pull_request'      ← PR でしか走らない
jobs.sync.if        : github.event_name != 'pull_request'      ← push(main) / workflow_dispatch
```

`sync` job のステップは `check-codex-skill-spec.sh --warn-only`（presence のみ・warn）/ `sync-plugin-plangate.sh`（**plugin レーンだけ**）/ 差分検出 / PR 作成。
**`.codex/skills` を再生成するステップは 1 つも無い。**

| レーン       | plugin/plangate                                     | .codex/skills（段 1 適用後・本 patch 適用前） |
| ------------ | --------------------------------------------------- | --------------------------------------------- |
| pull_request | drift-check が block                                | **層 1 が block**（段 1 で追加済み）          |
| push(main)   | sync が再生成 → 差分あれば **bot が是正 PR**（C-4） | **検知も是正も無し**                          |

したがって main に `.codex` drift が入ると **main の CI は緑のまま**になる。これが 2026-09-08 の実発生経路。

### 現 main の drift（SHA 付き測定値）

> **契約値ではなく測定値**（[`working-context.md`](../../../.claude/rules/working-context.md) 「運用で増える値を契約値として書かない」）。
> 下記は `origin/main` = **`c12edc6f`** 時点の repo 外複製での実測であり、以後の push で変わる。

| 測定                    | コマンド                                                                                              | 実測（`@ c12edc6f`）                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **正本との drift**      | `sh scripts/install-plangate-skills-to-codex.sh --force` → `git status --porcelain -- .codex/skills/` | **空**（drift なし）                                                                                           |
| `rm -rf` を伴う再生成後 | `rm -rf .codex/skills && sh ... --force` → 同上                                                       | `M .codex/skills/plan-normalization/agents/openai.yaml`（porcelain の先頭 1 桁は空白）の **1 件のみ**（curated 値が消えるため。§9 major-1） |

v1 が書いていた「11 ファイルの drift」は **`d805aba0`（PR #1305）でマージ済み**であり、`c12edc6f` では成立しない。

---

## 3. 本書の patch が変える 3 点

| #   | 変更                                                                                                                                            | 対象              |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| (a) | `drift-check` に **層 2**（`rm -rf .codex/skills` → `--force --json` 再生成 → `git status --porcelain`（`agents/openai.yaml` 除外）が空）を追加 | PR レーン         |
| (b) | `sync` に **`.codex/skills` 再生成 + bot 出力の byte 照合 + 差分判定の拡張 + commit/PR 本文の拡張**                                             | push(main) レーン |
| (c) | `on.push.paths` / `on.pull_request.paths` の**両方**へ `scripts/install-plangate-skills-to-codex.sh` を追加                                     | 起動条件          |

(c) を両側対称に入れるのは ta-71 TC-22（push / pull_request の `paths` 集合一致）を壊さないため。既宣言の非対称は `ASYM push-only CHANGELOG.md` の 1 件のみで、これは維持される（§6 実測）。
`plugin/plangate/assets/**`（installer の assets 出所）は既存の `plugin/plangate/**` に**包含済み**のため追加しない。

**層 1 と層 2 は互いを代替しない**（先行書 §5.2）: 層 1 は `cmp` のみで **installer 非依存**、層 2 は installer 依存だが `assets/` / skill 内余剰ファイル / 孤児ディレクトリまで見る。両方を PR レーンに並べる。

---

## 4. (2) の是正設計 — 採った案・棄却した案・新しい穴

### 採った案: push レーンを「赤くする」のではなく「bot が是正 PR を出す」

`.codex` を **plugin レーンと同じ既存パターン**に載せる。push(main) で再生成し、差分があれば同じ `Create PR if changed` ステップが 1 本の PR にまとめて出す。merge は Human-owned（C-4）。

**「push で赤くなったとき誰が直すのか」への答え**: 誰も直さない構造にしない。**bot が是正 PR を用意し、Human が merge する。**

**ただし `sync` job が失敗しうる経路は 1 つ残る**（v1 はここを書いていなかった）: `Verify regenerated tree matches canon` が rc=1 のとき `sync` job は落ち、`Create PR if changed` に到達しない（＝main の CI が赤・是正 PR 無し）。この gate は **正本 `.agents/skills/**` と installer 出力の byte 一致だけ**を見るので、**FAIL しうるのは installer が壊れている（または改竄された）ときに限られる**。その場合の担当は **直前に `scripts/install-plangate-skills-to-codex.sh` を変更した PR の作者**（`paths` に installer を入れた (c) により、その PR は PR レーンの層 1 / 層 2 でも同時に赤くなる）。drift そのもので赤くなることはない（drift は `changed=true` に落ちて bot PR になる）。

### 棄却した案

| 案                                                   | 棄却理由                                                                                                                                                                                                                                  |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `drift-check` の `if:` を push でも走るよう変える    | 同 job には **plugin レーンの drift-check も入っている**。push(main) では `sync` job が是正 PR を出すまで plugin は必ず drift しているので、**その PR が merge されるまで main が構造的に赤**になる。設計上の正常動作を失敗として報告する |
| push 用に新しい job を立てて FAIL させる             | main が赤くなるだけで是正手段が無い。担当も定義できない                                                                                                                                                                                   |
| 先行書 §6 の独立 workflow をそのまま採用             | 層 1 が段 1 と重複し、`paths` 集合が 2 箇所に分裂（§1）                                                                                                                                                                                   |
| 書き込み権限を持つ **新規** job を追加して再生成する | `contents: write` / `pull-requests: write` を持つ job が 2 つに増える。既存 `sync` job を拡張すれば**権限クラス（job に付与する permission の集合）は増えない**。ただし**特権実行される入力の面は 1 本増える**（下記）                    |

### 権限クラスと「特権実行される面」の区別

(b) は `scripts/install-plangate-skills-to-codex.sh` を **`contents: write` / `pull-requests: write` を持つ `sync` job で実行**する。(c) はその installer を push / PR 両 `paths` に加える。`actions/checkout` の `persist-credentials` は既定 true。

- **権限クラス**（job に宣言する permission の集合・job 数）: **増えない**
- **特権実行される script の面**: `sync-plugin-plangate.sh` の 1 本から **2 本に増える**

かつ installer は **Hardening Override 対象パス一覧に含まれない**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) の 12 カテゴリに `scripts/*.sh` は入らない）。したがって**この昇格面の追加自体は HO ゲートを通らない**。installer への変更は C-4 レビューでのみ止まる。これは本 patch が新規に作った性質であり、緩和していない。

### この是正が作りうる新しい穴と、塞いだ根拠

| 穴                                                                                                                                                       | 塞いだか   | 根拠                                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **bot の PR が CI で検査されない**（`GITHUB_TOKEN` 由来のイベントは workflow を起動しない）→ 改竄された installer の出力がそのまま main 行きの PR になる | **塞いだ** | 再生成の直後に **installer 非依存の byte 照合**（canon の `SKILL.md` **と `references/*.md`** ↔ mirror）を bot 出力へ掛けるステップを追加。positive control 3 クラスで実測（§5.2）                                                                                            |
| `rm -rf .codex/skills` を **書き込み権限のある job** で実行 → installer が途中失敗すると「大量削除 PR」になる                                            | **塞いだ** | `rm -rf` と installer は**同一ステップ**。GitHub Actions の既定シェルは `bash -eo pipefail` で、installer が非ゼロなら**そのステップで job が失敗**し、後続の commit / PR 作成ステップは実行されない。`--json` 経路でも installer 本体の `set -eu` は生きている（§9 major-1） |
| 差分判定が `git diff` のままだと、再生成で**新規に生えたファイル（`??`）を取りこぼす**                                                                   | **塞いだ** | `.codex` 側は `git status --porcelain -- .codex/skills/`（`agents/openai.yaml` 除外）で判定（`M` / `D` / `??` の 3 クラス）。両値の実測は §5.3                                                                                                                                |
| **bot が curated な `agents/openai.yaml` を生成値へ差し戻す PR を出す**（`fef879df` の退行の再導入）                                                     | **塞いだ** | `Check for changes` / `git add -A` の両方で `:(exclude).codex/skills/*/agents/openai.yaml` を指定。実測: `git add -A` 後の `git diff --cached --name-only` が空、`git status` には unstaged の `M` として openai.yaml が残る（＝stage されていない）                                        |
| `paths` を触ることで ta-71 TC-20 / TC-22 の KNOWN-GAP 台帳が壊れる                                                                                       | **塞いだ** | 追加は両側対称の 1 パターンのみ。宣言済み gap 集合を 1 件も被覆しない。実測 27 passed / 0 failed（§6）                                                                                                                                                                        |
| 再生成が非冪等なら push のたびに PR が出る（ノイズ）                                                                                                     | **塞いだ** | 先行書 §2.2 で `--force` の冪等性を実測。本書でも「無改竄 → `changed=false`」を **`c12edc6f` 上で**実測（§5.3）。v1 はここが `changed=true` に恒常成立していた（§9 major-1）                                                                                                  |

### 残る穴（塞いでいない / 完全性を主張しない）

- **CI は advisory**（required status check ではない）。赤でもマージできる。#928
- **bot の PR が merge されない間、main は緑のまま drift を抱える**。plugin レーンと同じ性質。ただしその間、`.agents/skills/**` / `.codex/skills/**` / installer に触る**後続 PR は層 1 / 層 2 で赤くなる**ため、drift は次の関連 PR で必ず表面化する（帰責先がずれるという副作用は残る）
- **`agents/openai.yaml` はどの層も byte 照合していない**（層 1 は生成物として除外、層 2 / push レーンは curated 保護のため除外）。**curated 運用の代償として、この 1 ファイル種別の偽造は CI で検出されない**。塞ぐには installer 側の curated 台帳化（§8）が要る
- **installer 自体の改竄**: PR レーンでは層 1、push レーンでは bot 出力 gate が **`SKILL.md` 40 件 + `references/*.md` 3 件**について installer 非依存に主張する。`assets/` と skill 内余剰ファイルは層 2 のみが見る（＝installer 改竄下では検出手段が無い）。先行書 §8 と同じ
- **正本 `.agents/skills/**` そのものの改変**（HO 外 / #1263）・**Codex 実セッション 1 周**（fixture では測れない挙動）は本 patch の対象外

---

## 5. positive control と実適用テスト（repo 外複製で実測）

複製の作り方: `git clone --no-hardlinks --no-local <repo> /tmp/pg1288e`（HEAD = **`c12edc6f`**）。
各ステップは workflow から `yaml.safe_load` で `run` を抽出し、**GitHub Actions の既定シェルと同じ**
`bash -eo pipefail` に渡して実行した（`--check` 単独ではなく実走）。

### 5.1 層 2（`Regenerate .codex/skills and require zero diff (#1288)`）

| 入力                                                                                               | 期待 | 実測                                                    |
| -------------------------------------------------------------------------------------------------- | ---- | ------------------------------------------------------- |
| 現 main（`c12edc6f`）そのまま（negative control）                                                  | PASS | **rc=0** — `.codex/skills/ matches the generated tree.` |
| 内容改竄 + skill 内余剰ファイル + 孤児 skill dir を**同時に**コミット（positive control 3 クラス） | FAIL | **rc=1** — 下記 3 行                                    |

```text
 M .codex/skills/plan-review-gate/SKILL.md          <- 内容改竄
 D .codex/skills/plan-review-gate/SURPLUS.md        <- skill 内の余剰ファイル
 D .codex/skills/zz-orphan/SKILL.md                 <- 正本に無い skill ディレクトリ
```

v1 との差: v1 の述語は `agents/openai.yaml` を除外していなかったため、**negative control でも rc=1** になった（§9 major-1）。

### 5.2 bot 出力 gate（`Verify regenerated tree matches canon (installer-independent)`）

このステップは **installer を変異させて**検出力を実証した（「0 件だった」ではなく、壊したら落ちることの実測）。
変異は installer の call site（`cp` の直後）に注入し、`Regenerate .codex/skills` → 本 gate の**順で 2 ステップとも実走**した。

| installer の状態                                                                                   | `Regenerate` の rc | **v1 gate の rc**（`SKILL.md` のみ） | **v2 gate の rc**（`SKILL.md` + `references/*.md`） | v2 の `::error::` 件数 |
| -------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------ | --------------------------------------------------- | ---------------------- |
| 正規（negative control）                                                                           | 0                  | 0                                    | **0**                                               | 0                      |
| 変異 1: `cp "$skill_file" "$target_skill_file"` の直後に 1 行注入                                  | 0                  | 1                                    | **1**                                               | 40                     |
| 変異 2: installer を `#!/bin/sh` + `exit 0`（no-op 化）                                            | 0                  | 1                                    | **1**                                               | 43                     |
| **変異 3: `cp "$rf" "$dst_refs/..."` の直後に 1 行注入（`references/*.md` だけを不誠実にコピー）** | 0                  | **0 ← 素通り**                       | **1**                                               | 3                      |

変異 3 の実測出力（v2）:

```text
::error::.codex/skills/review-gate/references/ui-ux-lane.md differs from canon .agents/skills/review-gate/references/ui-ux-lane.md after regeneration -- installer output is not a faithful copy
::error::.codex/skills/skill-creator/references/design-principles.md differs from canon ...
::error::.codex/skills/skill-creator/references/review-default.md differs from canon ...
```

同じツリーに v1 の gate ループ（`for _c in .agents/skills/*/SKILL.md`）を当てると **rc=0**（＝素通り）を実測した。これが §9 major-2 の positive control。

**重要**: 変異 1 / 2 / 3 とも `Regenerate` ステップ自体は **rc=0 で通る**。
gate が無ければ bot はこの出力をそのまま commit し、**PR は `pull_request` workflow を起動しない**（`GITHUB_TOKEN` 由来）ため
誰にも検査されずに C-4 へ届く。この経路のうち **`SKILL.md` と `references/*.md` の 2 種別**を本 gate が塞ぐ（`agents/openai.yaml` / `assets/` は塞がない。§4 残る穴）。

### 5.3 `Check for changes`（述語が両値を取ることの確認）

`GITHUB_OUTPUT` を一時ファイルに向けて実走し、書き込まれた値を読んだ。

| 入力                                                                      | 実測            |
| ------------------------------------------------------------------------- | --------------- |
| `c12edc6f` そのまま（`rm -rf` + 再生成後。`agents/openai.yaml` のみ `M`） | `changed=false` |
| `.codex/skills/working-context/SKILL.md` を 1 行改竄                      | `changed=true`  |

片値しか観測していない述語を「動く」と書かないための対照。v1 は 1 行目が **`changed=true` に恒常成立**していた（§9 major-1）。

### 5.4 curated `openai.yaml` が bot PR に載らないこと

```text
$ git add -A -- .codex/skills/ ':(exclude).codex/skills/*/agents/openai.yaml'
$ git diff --cached --name-only
（空）
$ git status --porcelain -- .codex/skills/
 M .codex/skills/plan-normalization/agents/openai.yaml     ← unstaged のまま
```

### 5.5 patch の適用状態（本 patch v2 / `@ c12edc6f`）

| 方向                                                   | 実測 rc                                                                | 判定         |
| ------------------------------------------------------ | ---------------------------------------------------------------------- | ------------ |
| `git apply --check /tmp/1288-layer2-pushlane.patch`    | **0**                                                                  | 当たる       |
| `git apply --check -R /tmp/1288-layer2-pushlane.patch` | **1**（`patch failed: .github/workflows/sync-plugin-plangate.yml:16`） | 入っていない |

`git apply --numstat`: `86  4  .github/workflows/sync-plugin-plangate.yml`

---

## 6-pre. patch（`git apply` 用）

抽出（#1104 / #1226 / #1278 / 先行書 §6.1 と同じ marker 規則）。
**先行書の `sed -e '1d' -e '$d'` 2 回方式は使わない**: 本 repo の markdown formatter が
fence の長さを正規化し marker 前後に空行を入れるため、落とす行数が版によって変わる。
下記は fence 長・空行に依存せず、marker 内の fence 内側だけを取り出す:

```sh
awk 'BEGIN{q=sprintf("%c",96)} /^<!-- PG-PATCH-BEGIN -->$/{b=1;next} /^<!-- PG-PATCH-END -->$/{exit} b && substr($0,1,1)==q{f=!f;next} f' \
  docs/working/_reports/1288-ci-layer2-and-push-lane-patch.md \
  > /tmp/1288-layer2-pushlane.patch
git apply --check /tmp/1288-layer2-pushlane.patch
git apply --numstat /tmp/1288-layer2-pushlane.patch    # 86  4  .github/workflows/sync-plugin-plangate.yml
```

<!-- PG-PATCH-BEGIN -->

```diff
diff --git a/.github/workflows/sync-plugin-plangate.yml b/.github/workflows/sync-plugin-plangate.yml
index a872da40..207c7353 100644
--- a/.github/workflows/sync-plugin-plangate.yml
+++ b/.github/workflows/sync-plugin-plangate.yml
@@ -16,6 +16,7 @@ on:
       - 'scripts/ai-loop/**'
       - 'scripts/_ai_loop_link_rewrite.py'
       - 'scripts/sync-plugin-plangate.sh'
+      - 'scripts/install-plangate-skills-to-codex.sh'
       - 'plugin/plangate/**'
   pull_request:
     paths:
@@ -27,6 +28,7 @@ on:
       - 'scripts/ai-loop/**'
       - 'scripts/_ai_loop_link_rewrite.py'
       - 'scripts/sync-plugin-plangate.sh'
+      - 'scripts/install-plangate-skills-to-codex.sh'
       - 'plugin/plangate/**'
   workflow_dispatch:
 
@@ -111,6 +113,40 @@ jobs:
           done
           exit "$rc"
 
+      # 層 2: .codex/skills/ を丸ごと再生成し、commit 済みツリーとの差分ゼロを要求する (#1288)。
+      # 直前の層 1 が見ない assets/・skill ディレクトリ内の余剰ファイル・孤児
+      # ディレクトリまでが 1 つの述語で落ちる (M / D / ?? の 3 クラス)。
+      # 2 層は互いを代替しない: 層 1 は installer 非依存 (cmp のみ) なので installer が
+      # no-op へ改竄されても主張が立ち、層 2 は installer 依存だが対象範囲が広い。
+      #
+      # agents/openai.yaml を述語から除外する理由 (#1288 / 実測):
+      #   直前の層 1 のコメントと同じく、本ファイルは frontmatter を正規化して
+      #   生成されるため byte 比較の対象外。加えて plan-normalization の値は curated
+      #   (手置き) で `# plangate:curated` マーカーにより保護されるが、マーカーは
+      #   ファイル内にあるため rm -rf で消える。除外しないと本ステップは無改竄の
+      #   main でも恒常 FAIL する (実測: ` M .codex/skills/plan-normalization/agents/openai.yaml`)。
+      #   マーカーに削除耐性を与える案 (台帳方式) は installer 側の変更のため本 patch の範囲外。
+      #
+      # --json を付ける理由 (#1288 / 実測): installer の非 JSON 経路の最終コマンドは
+      #   `[ "$curated_count" -gt 0 ] && printf ...` で、curated マーカーを 1 件も見つけないと
+      #   rc=1 を返す。直前の rm -rf でマーカーごと消えるためこの経路では必ず rc=1 になり、
+      #   bash -eo pipefail 下で述語に到達する前にステップが落ちる。--json 経路の最終コマンドは
+      #   printf なので rc=0 で、installer 本体の set -eu による真の失敗検出はそのまま残る。
+      #
+      # 注: installer は python3 があるときだけ openai.yaml の short_description を 64 文字へ
+      # 切り詰めるが、本ステップは openai.yaml を除外するためこの依存は述語に影響しない。
+      - name: Regenerate .codex/skills and require zero diff (#1288)
+        run: |
+          rm -rf .codex/skills
+          sh scripts/install-plangate-skills-to-codex.sh --force --json >/dev/null
+          out=$(git status --porcelain -- .codex/skills/ ':(exclude).codex/skills/*/agents/openai.yaml')
+          if [ -n "$out" ]; then
+            echo "::error::.codex/skills/ が生成結果と一致しません。ローカルで 'sh scripts/install-plangate-skills-to-codex.sh --force' を実行し、結果をコミットしてください。"
+            echo "$out"
+            exit 1
+          fi
+          echo ".codex/skills/ matches the generated tree."
+
   sync:
     if: github.event_name != 'pull_request'
     permissions:
@@ -130,10 +166,54 @@ jobs:
       - name: Run sync script
         run: sh scripts/sync-plugin-plangate.sh
 
+      # push(main) レーンにも .codex/skills の再同期を置く (#1288)。
+      # drift-check job は `if: github.event_name == 'pull_request'` のため push では走らず、
+      # sync job は plugin レーンしか面倒を見ていなかった。結果として main に .codex の drift が
+      # 入っても main の CI は緑のままだった (2026-09-08 に実発生)。
+      # ここでは push レーンを「赤くする」のではなく、plugin レーンと同じ既存パターン
+      # ＝ bot が是正 PR を出し、merge は Human-owned (C-4) で解消する。
+      # --json / openai.yaml 除外の理由は drift-check 側の層 2 と同じ (#1288)。
+      - name: Regenerate .codex/skills
+        run: |
+          rm -rf .codex/skills
+          sh scripts/install-plangate-skills-to-codex.sh --force --json >/dev/null
+
+      # bot が作る PR は GITHUB_TOKEN 由来のため pull_request workflow を起動しない
+      # (GitHub の既知仕様)。つまり drift-check は bot 自身の出力を検査しない。
+      # そこで再生成の直後に installer 非依存の byte 照合 (層 1 の中核) を bot 出力へ掛ける。
+      # 対象集合は層 1 と同一 (SKILL.md と references/*.md)。SKILL.md だけを見ると
+      # references/*.md だけを不誠実にコピーする改竄が素通りする (#1288 実測の変異 3)。
+      - name: Verify regenerated tree matches canon (installer-independent)
+        run: |
+          rc=0
+          for _d in .agents/skills/*/; do
+            _n=$(basename "$_d")
+            for _c in "${_d}SKILL.md" "${_d}references"/*.md; do
+              [ -f "$_c" ] || continue
+              _b=$(basename "$_c")
+              case "$_c" in
+                *references/*) _m=".codex/skills/$_n/references/$_b" ;;
+                *) _m=".codex/skills/$_n/$_b" ;;
+              esac
+              if [ ! -f "$_m" ]; then
+                echo "::error::$_m missing after regeneration (canon: $_c)"
+                rc=1
+              elif ! cmp -s "$_c" "$_m"; then
+                echo "::error::$_m differs from canon $_c after regeneration -- installer output is not a faithful copy"
+                rc=1
+              fi
+            done
+          done
+          exit "$rc"
+
       - name: Check for changes
         id: diff
         run: |
-          if git diff --quiet -- plugin/plangate/; then
+          # .codex/skills は再生成前に rm -rf しているため、未追跡の新規ファイルも拾える
+          # git status --porcelain で判定する (git diff では ?? が落ちる)。
+          # agents/openai.yaml は curated 運用のため除外する (層 2 と同じ理由 / #1288)。
+          # 除外しないと push のたびに手置き値を差し戻す bot PR が出る。
+          if git diff --quiet -- plugin/plangate/ && [ -z "$(git status --porcelain -- .codex/skills/ ':(exclude).codex/skills/*/agents/openai.yaml')" ]; then
             echo "changed=false" >> "$GITHUB_OUTPUT"
           else
             echo "changed=true" >> "$GITHUB_OUTPUT"
@@ -149,10 +229,12 @@ jobs:
           git config user.email "github-actions[bot]@users.noreply.github.com"
           git checkout -b "$branch"
           git add plugin/plangate/
-          git commit -m "chore(plugin): .claude/ → plugin/plangate/ 自動同期"
+          # openai.yaml は curated 運用のため stage しない (再生成で手置き値が戻っている)。
+          git add -A -- .codex/skills/ ':(exclude).codex/skills/*/agents/openai.yaml'
+          git commit -m "chore(plugin): plugin/plangate/ ・ .codex/skills/ を正本へ自動同期"
           git push origin "$branch"
           gh pr create \
             --base main \
             --head "$branch" \
-            --title "chore(plugin): plugin/plangate/ 自動同期" \
-            --body "push to main をトリガーに \`scripts/sync-plugin-plangate.sh\` が .claude/ との差分を検出しました。merge は Human-owned (C-4)。"
+            --title "chore(plugin): plugin/plangate/ ・ .codex/skills/ 自動同期" \
+            --body "push to main をトリガーに \`scripts/sync-plugin-plangate.sh\` / \`scripts/install-plangate-skills-to-codex.sh --force\` が正本との差分を検出しました。merge は Human-owned (C-4)。"
```

<!-- PG-PATCH-END -->

## 6. ta-71 KNOWN-GAP の非破壊確認（実測 / `@ c12edc6f`）

| 状態                           | コマンド                                  | passed | failed | rc  |
| ------------------------------ | ----------------------------------------- | ------ | ------ | --- |
| patch 未適用（pristine clone） | `sh tests/extras/ta-71-ci-static-lint.sh` | **27** | **0**  | 0   |
| patch 適用後（サンドボックス） | 同上                                      | **27** | **0**  | 0   |

適用後の TC-20 / TC-22 / TC-23 の判定行（実測抜粋）:

```text
[PASS] TC-20 sync の入力集合が CI paths: に未被覆（KNOWN-GAP #1249 の宣言と完全一致するため受理 / patch 適用後は flag を削除すること）
[TC-22] 片側のみ: push-only:CHANGELOG.md
[PASS] TC-22 push / pull_request の paths: が非対称（KNOWN-GAP #1249 の宣言と完全一致するため受理）
[PASS] TC-23 sync の REPO_ROOT 参照と静的入力表が両方向で一致
```

`tests/fixtures/sync-paths-known-gap-1249.flag` は**変更不要**（宣言と実 gap 集合は一致したまま）。
TC-08 / TC-09（actionlint）も同じ 27 件に含まれており、改修後の workflow は actionlint を通っている。

YAML の機械確認（`yaml.safe_load`）:

```text
push paths == pr paths ?  False
push-only  ['CHANGELOG.md']      ← GAP-DECL の ASYM 宣言と一致
pr-only    []
drift-check steps: Checkout / Verify plugin/plangate is in sync with sources / Verify .codex/skills mirrors .agents/skills canon (#1226) / Regenerate .codex/skills and require zero diff (#1288)
sync steps      : Checkout / Codex skill spec check / Run sync script / Regenerate .codex/skills / Verify regenerated tree matches canon (installer-independent) / Check for changes / Create PR if changed
```

---

## 7. 適用手順（Human / repo root）

> **前提条件は「件数」ではなく「述語」で確認すること。** 本書執筆時点（`c12edc6f`）で main に drift は無いが、
> 適用時点では変わりうる。手順 1 は **`git status --porcelain -- .codex/skills/` が空になるまで**繰り返す。

```sh
# 0) 作業ブランチ
git fetch origin && git checkout -b fix/1288-ci-layer2 origin/main

# 1) 再同期（先行書 §7）— porcelain が空になるまで
sh scripts/install-plangate-skills-to-codex.sh --force
git status --porcelain -- .codex/skills/     # 空なら手順 2 へ。非空なら下記 2 行を実行して再確認
git add -A .codex/skills/
git commit -m "fix(codex): .codex/skills を生成元 .agents/skills へ再同期 (#1288)"

# 2) patch 抽出と適用（Hardening Override 対象 = Human-owned）
awk 'BEGIN{q=sprintf("%c",96)} /^<!-- PG-PATCH-BEGIN -->$/{b=1;next} /^<!-- PG-PATCH-END -->$/{exit} b && substr($0,1,1)==q{f=!f;next} f' \
  docs/working/_reports/1288-ci-layer2-and-push-lane-patch.md \
  > /tmp/1288-layer2-pushlane.patch
git apply --check /tmp/1288-layer2-pushlane.patch   # rc=0 を確認してから
git apply /tmp/1288-layer2-pushlane.patch
git add .github/workflows/sync-plugin-plangate.yml
git commit -m "ci(#1288): .codex/skills の層 2 検査を追加し、push レーンの検知欠落を塞ぐ"

# 3) 適用後の自己検査（CI と同じ述語 + KNOWN-GAP 台帳）
rm -rf .codex/skills
sh scripts/install-plangate-skills-to-codex.sh --force --json >/dev/null
git status --porcelain -- .codex/skills/ ':(exclude).codex/skills/*/agents/openai.yaml'   # 空であること
sh tests/extras/ta-71-ci-static-lint.sh       # 27 passed / 0 failed
```

> 手順 3 で `rm -rf` を伴う再生成をローカルで行うと、curated な
> `.codex/skills/plan-normalization/agents/openai.yaml` が生成値へ戻る（`# plangate:curated`
> マーカーがファイル内にあり `rm -rf` で消えるため）。**この 1 ファイルはコミットしないこと。**

---

## 8. スコープ外・残存（手を出していない・報告のみ）

- **curated 保護に削除耐性が無い**（本 patch が回避しているだけで塞いでいない）: `# plangate:curated` マーカーは**保護対象ファイル自身の中**にあるため、`rm -rf .codex/skills` で消える。結果として `--force` は手置き値を生成値で上書きする（実測 §2）。**台帳方式**（保護対象パスを installer 外の一覧ファイルに持つ）なら削除耐性を持てるが、`scripts/install-plangate-skills-to-codex.sh` の変更になり本 patch の範囲を超える。別 PBI。
- **installer が curated 0 件のとき rc=1 を返す**（#1308 由来 / 本セッションの新規検出）: 非 JSON 経路の最終コマンドが `[ "$curated_count" -gt 0 ] && printf ...` のため、curated マーカーを 1 件も見つけないと**成功しているのに rc=1** になる。`rm -rf` 後は必ずこの状態になる。本 patch は `--json`（最終コマンドが `printf`）で回避したが、**installer 側の修正が本筋**（末尾に `:` か `if` 文を置く 1 行）。CI 以外の呼び出し元（`bin/plangate doctor` 等）が rc を見ていれば同じ誤検出を受ける。
- **`.codex/skills/.system/`**（`.gitignore` 済の実行時ディレクトリ）: CI の fresh checkout には出現しないが、**ローカルで層 2 を手動実行すると `??` として偽陽性になりうる**。CI 前提の述語であることに注意。
- **先行書 §9 の Human 判断 5 件**: v1 は「本 patch はいずれにも依存しない」と書いていたが**事実に反する**（§9 major-1）。本 patch（v2）は **判断 4（`openai.yaml` を層 1 側でも照合するか）を「照合しない」側で先取りして固定する**。`fef879df` および #1308 の curated 保護と同じ向きだが、Human が逆を選ぶ場合は本 patch の除外指定 3 箇所を外し、curated 保護の削除耐性（上記台帳方式）を先に入れる必要がある。残る 4 件（`plan-review-gate` の再同期可否 / required status check 化 / 4 skill の「同梱 `references/`」表現）には依存しない。
- **未マージ PR の存在**により本書は PR を作らない（commit + push まで）。

---

## 9. v1 からの是正（マージ後の敵対レビュー指摘 / PR #1307 コメント）

| ID           | 指摘                                                                                                                                    | v1 の実体                                                                                                                                                                                                                                       | v2 の是正                                                                                                                                                       | 実測での解消確認                                                                                                                 |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **major-1**  | 層 2 の述語が `agents/openai.yaml` で恒常的に非空になり、適用すると PR レーン恒常赤 / push レーン毎回 bot PR                            | `git status --porcelain -- .codex/skills/` が `rm -rf` 後に必ず `M .../plan-normalization/agents/openai.yaml`（unstaged）を返す（#1308 の curated マーカーはファイル内にあり `rm -rf` で消えるため、マーカー導入後も**非空のまま**。`c12edc6f` で再実測） | 述語・`Check for changes`・`git add` の 3 箇所に `:(exclude).codex/skills/*/agents/openai.yaml` を指定。層 1 の除外理由（生成物）と同じ根拠を引く               | 層 2 negative control **rc=0**（§5.1）/ `Check for changes` = **`changed=false`**（§5.3）/ `git add -A` 後の staged が空（§5.4） |
| **major-1b** | （派生 / 本セッションの新規検出）`rm -rf` 後は installer が **rc=1** を返し、`bash -eo pipefail` 下で述語に到達する前にステップが落ちる | installer 非 JSON 経路の最終コマンドが `[ "$curated_count" -gt 0 ] && printf ...`                                                                                                                                                               | installer 呼び出しを `--force --json >/dev/null` に変更（最終コマンドが `printf` で rc=0。`set -eu` による真の失敗検出は維持）                                  | `Regenerate` ステップ **rc=0**（§5.1 / §5.2 全 4 ケース）                                                                        |
| **major-2**  | bot 出力 gate が `references/*.md` を見ておらず、変異 3 が素通りする                                                                    | ループが `for _c in .agents/skills/*/SKILL.md`                                                                                                                                                                                                  | 層 1 と**同一のループ**（`for _c in "${_d}SKILL.md" "${_d}references"/*.md`）に置換。新しいロジックは追加していない                                             | 変異 3 で **rc=1 / `::error::` 3 件**（§5.2）。同じツリーで v1 ループは rc=0                                                     |
| minor        | 「現 main に 11 ファイルの drift」                                                                                                      | `f455a7b7` 時点の値をそのまま契約値として記載                                                                                                                                                                                                   | §2 に **SHA 付き測定表**として書き直し（`c12edc6f` では drift なし）。§7 手順 1 の前提条件を「`git status --porcelain -- .codex/skills/` が空になるまで」に置換 | —                                                                                                                                |
| minor        | 「main に対して失敗する CI を作らない」                                                                                                 | gate ステップが `sync` job を失敗させうる点に触れていない                                                                                                                                                                                       | §4 に「**FAIL しうるのは installer 破損時のみ**」と限定し、担当（installer を変更した PR の作者）を明記                                                         | —                                                                                                                                |
| info         | 「権限クラスは増えない」                                                                                                                | 特権実行される script の面が増える点に触れていない                                                                                                                                                                                              | §4 に「権限クラス」と「特権実行される入力の面」の区別を新設。installer が HO 対象外である点も明記                                                               | —                                                                                                                                |
| —            | §8「Human 判断 5 件のいずれにも依存しない」                                                                                             | 事実に反する                                                                                                                                                                                                                                    | **取り下げ**。§8 に「判断 4 を先取りして固定する」と明記                                                                                                        | —                                                                                                                                |
