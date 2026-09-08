# #1288 段 3 — CI 層 2 の追加と、drift-check が push で走らない構造欠陥の是正（`git apply` 可能形 patch / **Human 適用**）

> 測定基点: **`origin/main` = `f455a7b7`**（HO patch 段 1 = #1278 / #1234 / #1226 + PATCH-C 適用後）/ 2026-09-08。
> 位置づけ: **既存ギャップの是正**。`.github/workflows/**` は Hardening Override 対象のため **AI は patch 提示まで・適用は Human-owned**。
> 本セッションで AI が編集した repo 内ファイルは**本ファイル 1 本のみ**。workflow の実編集と全検証は `git clone --no-hardlinks --no-local` で作った **repo 外複製**（`/tmp/pg1288`）で行い、patch は `git diff` で取り出した（`sed` 手加工なし）。
> 先行調査の正本: [`1288-codex-skills-drift-and-ci-patch.md`](./1288-codex-skills-drift-and-ci-patch.md)（層 1 / 層 2 の設計・全数照合・正否判定）。本書はその **§6 patch を現行 main 向けに設計し直したもの**。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **先行書 §6 patch の適用状態** | **未適用だが、採用しない**。fwd rc=0 / rev rc=1（＝当たるが入っていない）。ただし独立 workflow `codex-skills-drift.yml` を新設する設計で、**層 1 は段 1（#1226 PATCH-B）が既存 `sync-plugin-plangate.yml` に入れた検査と重複**する。§1 |
| **本書の patch** | 既存 `sync-plugin-plangate.yml` を 1 ファイル改修（**+61 / -4**）。(a) PR レーンに**層 2** を追加、(b) **push(main) レーンに `.codex/skills` 再同期＋自動 PR** を追加、(c) `paths` に installer を**両側対称**で追加。§3 |
| **構造欠陥（2）の実体** | `drift-check` job は `if: github.event_name == 'pull_request'`。`sync` job は **plugin レーンしか再生成しない**。よって `.codex/skills` は push(main) 側に**検知も是正も無い**。2026-09-08 に main へ drift が入って CI が緑のままだった経路はこれ。§2 |
| **採った是正** | push レーンを「赤くする」のではなく、**plugin レーンと同じ既存パターン（bot が是正 PR を出し merge は Human-owned / C-4）** を `.codex` にも適用。加えて bot 出力自体に **installer 非依存の byte 照合**を掛ける（bot の PR は `GITHUB_TOKEN` 由来のため `pull_request` workflow を起動しないという GitHub の既知仕様への手当て）。§4 |
| **ta-71 KNOWN-GAP** | patch 適用後も **27 passed / 0 failed**（未適用ベースラインと同数）。TC-20 / TC-22 は `sync-paths-known-gap-1249.flag` の `GAP-DECL` と**完全一致**を維持。§6 |
| **positive control** | 層 2 は 3 クラス（内容改竄 / skill 内余剰 / 孤児 skill dir）、bot 出力 gate は 2 クラス（installer が不誠実なコピーを吐く / installer が no-op）、`Check for changes` は両値をサンドボックス実測で確認。§5 |

---

## 1. 先行書 §6 patch の適用状態（実測）

抽出（先行書 §6.1 と同じ marker 規則）:

```sh
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1288-codex-skills-drift-and-ci-patch.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/p1288.patch
```

| 方向 | コマンド | 実測 rc | 判定 |
|---|---|---|---|
| fwd | `git apply --check /tmp/p1288.patch` | **0** | 当たる |
| rev | `git apply --check -R /tmp/p1288.patch` | **1**（`.github/workflows/codex-skills-drift.yml: No such file or directory`） | 入っていない |

**判定: 未適用（stale ではない）。** それでも本書は **採用しない**。理由:

- 先行書 §6.3 末尾が既に指摘しているとおり、**層 1 は #1226 PATCH-B と役割が重複**する。PATCH-B は段 1（`f455a7b7`）で `sync-plugin-plangate.yml` の `drift-check` job に「Verify .codex/skills mirrors .agents/skills canon (#1226)」として**適用済み**（実測: 同 workflow 65〜112 行相当）。同じ照合を 2 workflow で回すことになる。
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

| レーン | plugin/plangate | .codex/skills（段 1 適用後・本 patch 適用前） |
|---|---|---|
| pull_request | drift-check が block | **層 1 が block**（段 1 で追加済み） |
| push(main) | sync が再生成 → 差分あれば **bot が是正 PR**（C-4） | **検知も是正も無し** |

したがって main に `.codex` drift が入ると **main の CI は緑のまま**になる。これが 2026-09-08 の実発生経路。

> 補足: 現 `origin/main` には先行書 §1.3 の **11 ファイルの drift が残っている**（サンドボックス実測。再同期コミットは未マージブランチ `fix/1288-codex-resync` 上にあり main には入っていない）。

---

## 3. 本書の patch が変える 3 点

| # | 変更 | 対象 |
|---|---|---|
| (a) | `drift-check` に **層 2**（`rm -rf .codex/skills` → `--force` 再生成 → `git status --porcelain` が空）を追加 | PR レーン |
| (b) | `sync` に **`.codex/skills` 再生成 + bot 出力の byte 照合 + 差分判定の拡張 + commit/PR 本文の拡張** | push(main) レーン |
| (c) | `on.push.paths` / `on.pull_request.paths` の**両方**へ `scripts/install-plangate-skills-to-codex.sh` を追加 | 起動条件 |

(c) を両側対称に入れるのは ta-71 TC-22（push / pull_request の `paths` 集合一致）を壊さないため。既宣言の非対称は `ASYM push-only CHANGELOG.md` の 1 件のみで、これは維持される（§6 実測）。
`plugin/plangate/assets/**`（installer の assets 出所）は既存の `plugin/plangate/**` に**包含済み**のため追加しない。

**層 1 と層 2 は互いを代替しない**（先行書 §5.2）: 層 1 は `cmp` のみで **installer 非依存**、層 2 は installer 依存だが `agents/openai.yaml` / `assets/` / 余剰ファイルまで見る。両方を PR レーンに並べる。

---

## 4. (2) の是正設計 — 採った案・棄却した案・新しい穴

### 採った案: push レーンを「赤くする」のではなく「bot が是正 PR を出す」

`.codex` を **plugin レーンと同じ既存パターン**に載せる。push(main) で再生成し、差分があれば同じ `Create PR if changed` ステップが 1 本の PR にまとめて出す。merge は Human-owned（C-4）。

**「push で赤くなったとき誰が直すのか」への答え**: 誰も直さない構造にしない。**bot が是正 PR を用意し、Human が merge する。** main に対して失敗する CI を作らないので「常時赤 → 赤を無視する」状態にならない。

### 棄却した案

| 案 | 棄却理由 |
|---|---|
| `drift-check` の `if:` を push でも走るよう変える | 同 job には **plugin レーンの drift-check も入っている**。push(main) では `sync` job が是正 PR を出すまで plugin は必ず drift しているので、**その PR が merge されるまで main が構造的に赤**になる。設計上の正常動作を失敗として報告する |
| push 用に新しい job を立てて FAIL させる | main が赤くなるだけで是正手段が無い。担当も定義できない |
| 先行書 §6 の独立 workflow をそのまま採用 | 層 1 が段 1 と重複し、`paths` 集合が 2 箇所に分裂（§1） |
| 書き込み権限を持つ **新規** job を追加して再生成する | `contents: write` / `pull-requests: write` を持つ job が 2 つに増える。既存 `sync` job を拡張すれば権限クラスは増えない |

### この是正が作りうる新しい穴と、塞いだ根拠

| 穴 | 塞いだか | 根拠 |
|---|---|---|
| **bot の PR が CI で検査されない**（`GITHUB_TOKEN` 由来のイベントは workflow を起動しないという GitHub の既知仕様）→ 改竄された installer の出力がそのまま main 行きの PR になる | **塞いだ** | 再生成の直後に **installer 非依存の byte 照合**（canon `SKILL.md` ↔ mirror `SKILL.md`）を bot 出力へ掛けるステップを追加。positive control 2 クラスで実測（§5） |
| `rm -rf .codex/skills` を **書き込み権限のある job** で実行 → installer が途中失敗すると「大量削除 PR」になる | **塞いだ** | `rm -rf` と installer は**同一ステップ**。GitHub Actions の既定シェルは `bash -eo pipefail` で、installer が非ゼロなら**そのステップで job が失敗**し、後続の commit / PR 作成ステップは実行されない |
| 差分判定が `git diff` のままだと、再生成で**新規に生えたファイル（`??`）を取りこぼす** | **塞いだ** | `.codex` 側は `git status --porcelain -- .codex/skills/` で判定（`M` / `D` / `??` の 3 クラス）。両値の実測は §5 |
| `paths` を触ることで ta-71 TC-20 / TC-22 の KNOWN-GAP 台帳が壊れる | **塞いだ** | 追加は両側対称の 1 パターンのみ。宣言済み gap 集合を 1 件も被覆しない（`docs/**` テンプレ・`marketplace.json` は無関係）。実測 27 passed / 0 failed（§6） |
| 再生成が非冪等なら push のたびに PR が出る（ノイズ） | **塞いだ** | 先行書 §2.2 で `--force` の冪等性を実測。本書でも「無改竄 → `changed=false`」を実測（§5） |

### 残る穴（塞いでいない / 完全性を主張しない）

- **CI は advisory**（required status check ではない）。赤でもマージできる。#928
- **bot の PR が merge されない間、main は緑のまま drift を抱える**。plugin レーンと同じ性質。ただしその間、`.agents/skills/**` / `.codex/skills/**` に触る**後続 PR は層 1 / 層 2 で赤くなる**ため、drift は次の関連 PR で必ず表面化する（帰責先がずれるという副作用は残る）
- **層 2 は `python3` に依存**（installer が `openai.yaml` の `short_description` を 64 文字へ切り詰める分岐）。`ubuntu-latest` は同梱。ランナー変更時は偽陽性になる。層 1 はこの依存を持たない
- **installer 自体の改竄**: PR レーンでは層 1 が `SKILL.md` 40/40 について主張し、push レーンでは bot 出力 gate が同じ主張をする。`agents/openai.yaml` / `assets/` / `*.md` 以外の偽造は層 2 のみが見る（＝installer 改竄下では検出手段が無い）。先行書 §8 と同じ
- **正本 `.agents/skills/**` そのものの改変**（HO 外 / #1263）・**Codex 実セッション 1 周**（fixture では測れない挙動）は本 patch の対象外

---
## 5. positive control と実適用テスト（repo 外複製 `/tmp/pg1288` で実測）

複製の作り方: `git clone --no-hardlinks --no-local <repo> /tmp/pg1288`（HEAD = `f455a7b7`）。
各ステップは workflow から `yaml.safe_load` で `run` を抽出し、**GitHub Actions の既定シェルと同じ**
`bash -eo pipefail -c` に渡して実行した（`--check` 単独ではなく実走）。

### 5.1 層 2（`Regenerate .codex/skills and require zero diff`）

| 入力 | 期待 | 実測 |
|---|---|---|
| 現 main そのまま（drift 11 件） | FAIL | **rc=1** — `M` 11 件を列挙（`SKILL.md` 10 + `plan-normalization/agents/openai.yaml`） |
| 再同期をコミットした状態（negative control） | PASS | **rc=0** — `.codex/skills/ matches the generated tree.` |
| 内容改竄 + skill 内余剰ファイル + 孤児 skill dir を**同時に**コミット（positive control 3 クラス） | FAIL | **rc=1** — 下記 3 行 |

```text
 M .codex/skills/plan-review-gate/SKILL.md          <- 内容改竄
 D .codex/skills/plan-review-gate/SURPLUS.md        <- skill 内の余剰ファイル
 D .codex/skills/zz-orphan/SKILL.md                 <- 正本に無い skill ディレクトリ
```

同じ状態で段 1 の層 1（`Verify .codex/skills mirrors ... (#1226)`）は再同期後 **rc=0** を返す
（＝述語は入力によって値が変わる。恒真 FAIL ではない）。

### 5.2 bot 出力 gate（`Verify regenerated SKILL.md matches canon (installer-independent)`）

このステップは **installer を変異させて**検出力を実証した（「0 件だった」ではなく、壊したら落ちることの実測）。
変異は installer の call site ではなく **installer 本体**（`scripts/install-plangate-skills-to-codex.sh`）に注入し、
`Regenerate .codex/skills` -> 本 gate の**順で 2 ステップとも実走**した。

| installer の状態 | `Regenerate` の rc | gate の rc | gate の出力（抜粋） |
|---|---|---|---|
| 正規（negative control） | 0 | **0** | （エラーなし） |
| 変異 1: 各 `SKILL.md` に 1 行注入（不誠実なコピー） | 0 | **1** | `::error::.codex/skills/working-context/SKILL.md differs from canon ... -- installer output is not a faithful copy`（40 件） |
| 変異 2: `#!/bin/sh` + `exit 0`（no-op 化） | 0 | **1** | `::error::.codex/skills/working-context/SKILL.md missing after regeneration (canon: ...)`（40 件） |

**重要**: 変異 1 / 変異 2 とも `Regenerate` ステップ自体は **rc=0 で通る**。
gate が無ければ bot はこの出力をそのまま commit し、**PR は `pull_request` workflow を起動しない**（`GITHUB_TOKEN` 由来）ため
誰にも検査されずに C-4 へ届く。この経路は本 gate だけが塞いでいる。

### 5.3 `Check for changes`（述語が両値を取ることの確認）

`GITHUB_OUTPUT` を一時ファイルに向けて実走し、書き込まれた値を読んだ。

| 入力 | 実測 |
|---|---|
| 再同期済み（差分なし） | `changed=false` |
| `SKILL.md` を 1 行改竄してコミット -> `Regenerate` 後 | `changed=true` |

片値しか観測していない述語を「動く」と書かないための対照。

### 5.4 patch の適用状態（本 patch）

| 方向 | 実測 rc | 判定 |
|---|---|---|
| `git apply --check /tmp/1288-layer2-pushlane.patch` | **0** | 当たる |
| `git apply --check -R /tmp/1288-layer2-pushlane.patch` | **1**（`patch failed: .github/workflows/sync-plugin-plangate.yml:16`） | 入っていない |

`git apply --numstat`: `61  4  .github/workflows/sync-plugin-plangate.yml`

---

## 6-pre. patch（`git apply` 用）

抽出（#1104 / #1226 / #1278 / 先行書 §6.1 と同じ marker 規則。marker 行と fence 行を 2 行ずつ落とす）:

````sh
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1288-ci-layer2-and-push-lane-patch.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1288-layer2-pushlane.patch
git apply --check /tmp/1288-layer2-pushlane.patch
git apply --numstat /tmp/1288-layer2-pushlane.patch
````

<!-- PG-PATCH-BEGIN -->
`````diff
diff --git a/.github/workflows/sync-plugin-plangate.yml b/.github/workflows/sync-plugin-plangate.yml
index a872da40..2437280c 100644
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
 
@@ -111,6 +113,26 @@ jobs:
           done
           exit "$rc"
 
+      # 層 2: .codex/skills/ を丸ごと再生成し、commit 済みツリーとの差分ゼロを要求する (#1288)。
+      # 直前の層 1 が見ない生成物 (agents/openai.yaml)・assets/・skill ディレクトリ内の
+      # 余剰ファイルまで 1 つの述語で落ちる (M / D / ?? の 3 クラス)。
+      # 2 層は互いを代替しない: 層 1 は installer 非依存 (cmp のみ) なので installer が
+      # no-op へ改竄されても主張が立ち、層 2 は installer 依存だが対象範囲が広い。
+      # 注: installer は python3 があるときだけ openai.yaml の short_description を 64 文字へ
+      # 切り詰める。python3 を持たないランナーへ変えると本ステップは偽陽性になる
+      # (ubuntu-latest は同梱)。層 1 はこの依存を持たない。
+      - name: Regenerate .codex/skills and require zero diff (#1288)
+        run: |
+          rm -rf .codex/skills
+          sh scripts/install-plangate-skills-to-codex.sh --force >/dev/null
+          out=$(git status --porcelain -- .codex/skills/)
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
@@ -130,10 +152,44 @@ jobs:
       - name: Run sync script
         run: sh scripts/sync-plugin-plangate.sh
 
+      # push(main) レーンにも .codex/skills の再同期を置く (#1288)。
+      # drift-check job は `if: github.event_name == 'pull_request'` のため push では走らず、
+      # sync job は plugin レーンしか面倒を見ていなかった。結果として main に .codex の drift が
+      # 入っても main の CI は緑のままだった (2026-09-08 に実発生)。
+      # ここでは push レーンを「赤くする」のではなく、plugin レーンと同じ既存パターン
+      # ＝ bot が是正 PR を出し、merge は Human-owned (C-4) で解消する。main を常時赤にすると
+      # 赤が無視されるようになるうえ、main に対して失敗する CI を直す担当が定義できない。
+      - name: Regenerate .codex/skills
+        run: |
+          rm -rf .codex/skills
+          sh scripts/install-plangate-skills-to-codex.sh --force >/dev/null
+
+      # bot が作る PR は GITHUB_TOKEN 由来のため pull_request workflow を起動しない
+      # (GitHub の既知仕様)。つまり drift-check は bot 自身の出力を検査しない。
+      # そこで再生成の直後に installer 非依存の byte 照合 (層 1 の中核) を bot 出力へ掛ける。
+      # installer が no-op / 改竄されていれば、PR を作る前にここで落ちる。
+      - name: Verify regenerated SKILL.md matches canon (installer-independent)
+        run: |
+          rc=0
+          for _c in .agents/skills/*/SKILL.md; do
+            _n=$(basename "$(dirname "$_c")")
+            _m=".codex/skills/$_n/SKILL.md"
+            if [ ! -f "$_m" ]; then
+              echo "::error::$_m missing after regeneration (canon: $_c)"
+              rc=1
+            elif ! cmp -s "$_c" "$_m"; then
+              echo "::error::$_m differs from canon $_c after regeneration -- installer output is not a faithful copy"
+              rc=1
+            fi
+          done
+          exit "$rc"
+
       - name: Check for changes
         id: diff
         run: |
-          if git diff --quiet -- plugin/plangate/; then
+          # .codex/skills は再生成前に rm -rf しているため、未追跡の新規ファイルも拾える
+          # git status --porcelain で判定する (git diff では ?? が落ちる)。
+          if git diff --quiet -- plugin/plangate/ && [ -z "$(git status --porcelain -- .codex/skills/)" ]; then
             echo "changed=false" >> "$GITHUB_OUTPUT"
           else
             echo "changed=true" >> "$GITHUB_OUTPUT"
@@ -149,10 +205,11 @@ jobs:
           git config user.email "github-actions[bot]@users.noreply.github.com"
           git checkout -b "$branch"
           git add plugin/plangate/
-          git commit -m "chore(plugin): .claude/ → plugin/plangate/ 自動同期"
+          git add -A .codex/skills/
+          git commit -m "chore(plugin): plugin/plangate/ ・ .codex/skills/ を正本へ自動同期"
           git push origin "$branch"
           gh pr create \
             --base main \
             --head "$branch" \
-            --title "chore(plugin): plugin/plangate/ 自動同期" \
-            --body "push to main をトリガーに \`scripts/sync-plugin-plangate.sh\` が .claude/ との差分を検出しました。merge は Human-owned (C-4)。"
+            --title "chore(plugin): plugin/plangate/ ・ .codex/skills/ 自動同期" \
+            --body "push to main をトリガーに \`scripts/sync-plugin-plangate.sh\` / \`scripts/install-plangate-skills-to-codex.sh --force\` が正本との差分を検出しました。merge は Human-owned (C-4)。"
`````
<!-- PG-PATCH-END -->

## 6. ta-71 KNOWN-GAP の非破壊確認（実測）

| 状態 | コマンド | passed | failed | rc |
|---|---|---|---|---|
| patch 未適用（pristine clone） | `sh tests/extras/ta-71-ci-static-lint.sh` | **27** | **0** | 0 |
| patch 適用後（サンドボックス） | 同上 | **27** | **0** | 0 |

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
drift-check steps: Checkout / Verify plugin/plangate ... / Verify .codex/skills mirrors ... (#1226) / Regenerate .codex/skills and require zero diff (#1288)
sync steps      : Checkout / Codex skill spec check / Run sync script / Regenerate .codex/skills / Verify regenerated SKILL.md matches canon (installer-independent) / Check for changes / Create PR if changed
```

---

## 7. 適用手順（Human / repo root）

> **順序を守ること。** 現 `origin/main` には先行書 §1.3 の **11 ファイルの drift** が残っている。
> patch を先に当てると `.agents/skills/**` / `.codex/skills/**` / installer に触る次の PR で
> **層 1 / 層 2 が即 FAIL** する。**「1. 再同期 → 2. patch」の順**、または**同一 PR で両方**行うこと。
> 再同期は 4 skill の記述を退行させる（先行書 §2.4 / §9-5 の Human 判断）。

```sh
# 0) 作業ブランチ
git fetch origin && git checkout -b fix/1288-ci-layer2 origin/main

# 1) 再同期（先行書 §7）
sh scripts/install-plangate-skills-to-codex.sh --force
git status --porcelain -- .codex/skills/     # 11 ファイルが M で出ることを確認
git add -A .codex/skills/
git commit -m "fix(codex): .codex/skills を生成元 .agents/skills へ再同期 (#1288)"

# 2) patch 抽出と適用（Hardening Override 対象 = Human-owned）
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1288-ci-layer2-and-push-lane-patch.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1288-layer2-pushlane.patch
git apply --check /tmp/1288-layer2-pushlane.patch   # rc=0 を確認してから
git apply /tmp/1288-layer2-pushlane.patch
git add .github/workflows/sync-plugin-plangate.yml
git commit -m "ci(#1288): .codex/skills の層 2 検査を追加し、push レーンの検知欠落を塞ぐ"

# 3) 適用後の自己検査（CI と同じ述語 + KNOWN-GAP 台帳）
rm -rf .codex/skills && sh scripts/install-plangate-skills-to-codex.sh --force >/dev/null
git status --porcelain -- .codex/skills/      # 空であること
sh tests/extras/ta-71-ci-static-lint.sh       # 27 passed / 0 failed
```

---

## 8. スコープ外（手を出していない・報告のみ）

- **`origin/main` に残る 11 ファイルの drift**: 再同期は §7 手順 1（Human または `PLANGATE_SKIP_REASON` 付きセッション）。本セッションでは repo 内で installer を実行していない。
- **先行書 §9 の Human 判断 5 件**（`plan-review-gate` の再同期可否 / required status check 化 / `openai.yaml` の層 1 対応 / 4 skill の「同梱 `references/`」表現）は未決のまま。本 patch はいずれにも依存しない。
- **`.codex/skills/.system/`**（`.gitignore` 済の実行時ディレクトリ）: CI の fresh checkout には出現しないが、**ローカルで層 2 を手動実行すると `??` として偽陽性になりうる**。CI 前提の述語であることに注意。
- **未マージ PR #1305** の存在により本書は PR を作らない（commit + push まで）。
