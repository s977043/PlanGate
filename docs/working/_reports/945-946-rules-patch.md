# #945 / #946 — `.claude/rules` 是正設計（patch 設計書）

> **本書は AI-owned の成果物（patch 提示）である。**
> 対象の `.claude/rules/*.md` は **Hardening Override 対象 9 カテゴリ**であり、
> **AI は本 PR で 1 行も編集していない**（変更は本ファイル 1 つのみ）。
> 適用は **Human-owned**。適用手順は §7 を参照。
>
> - 由来: 両 issue とも #917（PR #941 / `docs/working/TASK-0917/`）の実走
> - 対象が同じ（`.claude/rules/*.md`）・effort が同程度のため **1 patch 設計書 + 1 PR** に集約
> - Mode: `.claude/rules/*.md` は HO 対象 → **`lite_eligible=false` + Standard C-3 同期固定**

## 1. 測定条件

| 項目 | 値 |
|------|---|
| 測定 ref | `origin/main` = `1e629fb9541a6b3f2dfd93fbc2cef0a2542bf0b8` |
| 測定日 | 2026-08-24 |
| 測定方法 | `git show origin/main:<path>` / `git grep <pat> origin/main -- <glob>`（作業ツリーの `ls` / `grep -r` は使わない） |

以下の件数はすべて **上記 ref 時点の測定値**であり、契約値ではない。

## 2. issue 本文の主張の、現 main での成否

issue の行番号アンカーは転記せず、現 main で再測定した。

| # | issue 本文の主張 | 現 main での成否 | 実測 |
|---|-----------------|----------------|------|
| 945-a | `working-context.md` に `INDEX` の言及はある | **成立** | `git show origin/main:.claude/rules/working-context.md \| grep -n INDEX` → 5 件（L44 / L89 / L97 / L297 / L300）。陽性コントロール: 同ファイルの `current-state` は 7 件 |
| 945-b | 「役割分担」表に `INDEX.md` の行が無い＝更新タイミングが未規定 | **成立** | 表の行は `current-state.md` / `status.md` / `handoff.md` の 3 行のみ |
| 945-c | 生成規定は「plan 完了時に自動生成」のみ | **成立** | L44 のディレクトリ構造コメントのみ |
| 945-d | `docs/working/templates/` に **INDEX テンプレート自体が不在** | **不成立（反証）** | `docs/working/templates/INDEX.md` は **存在する**。追加コミットは `8af75c8`（PlanGate v6）で、issue が測定基準にした `ff46761` 時点でも存在（`git cat-file -e ff46761:docs/working/templates/INDEX.md` → rc=0）。**本設計はテンプレートを新設せず既存を改訂する** |
| 945-e | 「現在フェーズ」の値域が `status.md` と揃っていない | **成立（issue 本文に無い追加所見）** | `templates/INDEX.md` は `{brainstorm \| plan \| C-1 \| C-2 \| C-3待ち \| exec \| done}`、`templates/status.md` は `{plan / exec / review / verify / done}`。**2 つのテンプレートで値域が既に食い違っている** |
| 945-f | 完了資産に発行時点 SHA の欄が無い | **成立** | `templates/handoff.md` の frontmatter / メタ yaml とも `issued_at`（日付のみ）で、commit SHA 欄は `v1_release` のみ |
| 946-a | `review-principles.md` に「ラウンド」の記述が 0 件 | **成立** | `git show origin/main:.claude/rules/review-principles.md \| grep -n -E "ラウンド\|round\|R1\|R2"` → rc=1（0 件）。陽性コントロール: 同ファイルの `Severity` は 4 件 |
| 946-b | 同ファイルは §2〜4 と §7-bis のみ | **概ね成立（要補正）** | `## ` 見出しは 1 / 2 / 3 / 4 / 5 / 6 / 7 / 7-bis / **7-ter** / 8 の 10 個。issue 本文が触れていない **§7-ter（外部レビュー実行不可時の記録 / #463）** が存在する。新節はその直後・§8 の直前に置く |
| 946-c | 参考実装 `docs/working/TASK-0917/` の「**plan** の T-45 / T-46」 | **不成立（反証）** | T-45 / T-46 は `plan.md` ではなく **`todo.md`** に存在（`git grep -n "T-45" origin/main -- docs/working/TASK-0917/`）。`plan.md` には T-45 の文字列が無い。**本設計の参照先は `todo.md` に補正した** |

## 3. 設計方針（制約の遵守）

| 制約 | 本設計での扱い |
|------|--------------|
| 既存正本を重複定義しない | §2〜4（5 観点 / Severity / 判定基準）は**一切変更しない**。#946 の追加は §7-ter と §8 の**間に新節を挿入するのみ**（diff の hunk は `@@ -94,6 +94,87 @@` の 1 つだけ＝94 行目より前に触れていないことが差分で確認できる） |
| 承認境界を弱めない | C-3 / C-4 / merge / HO の扱いに一切触れていない。追加するのは「索引の鮮度」と「レビューのラウンド設計」のみ |
| 件数を契約値にしない | #946 は「**下限** 2 ラウンド」とし上限を定めない。「N ラウンド実施」を plan の契約値として書かないことを明記。#945 も「commit 数 / ファイル数を契約値として書かない」を明記 |
| #946 の収束判定は回数でなくクラスで | 「**新しい回避クラス / 失敗クラスが出なくなったか**」と定義。「指摘ゼロ」を明示的に否定。毎ラウンド新クラスが出続ける場合は「打ち切りどきではなく設計モデルを疑うとき」と規定 |
| 完全性を主張しない締め方 | 「打ち切り方（完全性を主張しない）」節で **残存脅威モデル**（守るもの / 守らないもの）・**多層防御の 1 層**であること・保証の主体を、実装 docstring と運用 doc の**両方**に書くことを要求 |
| #945 は役割分担表に行を足す形 | 表に `INDEX.md` 行を追加し、**更新イベント表**（6 イベント）と**鮮度の担保手段**（値域の統一・判定の転記・正本の優先順・発行時点 SHA・stale 機械検出）を新設サブ節に置く |
| 新規ファイルを作らない | **新規ファイル追加はゼロ**（§8）。`templates/INDEX.md` は既存のため改訂のみ。`plan.md` という basename のファイルも作っていない |

## 4. 受入基準（AC）対応表

差分がどの AC を充足するかの 1 対 1 対応。

### #945

| AC | 内容 | 充足する差分 | 判定 |
|----|------|------------|------|
| **AC-1** | 役割分担表に `INDEX.md` の行があり、更新タイミングが規定されている | `.claude/rules/working-context.md`: 見出しを `INDEX.md / current-state.md / status.md / handoff.md の役割分担` に改め、表の先頭に `**INDEX.md**` 行を追加（更新タイミング欄 = 「plan 完了時に生成し、以降はフェーズ遷移のたびに更新」）。加えて新サブ節「INDEX.md（L0 索引）の鮮度契約」1 の**更新イベント表**（plan 生成 / C-3 承認 / plan 確定反映・再編集 / exec 完了・V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除 の 6 行） | 充足 |
| **AC-2** | 「現在フェーズ」の値域が定義され、`status.md` / `handoff.md` の総合判定と矛盾しないことが明記 | 同節 2: 値域を 1 行の `text` ブロックで定義（`INDEX.md` / `status.md` 共通）。加えて (a) 総合判定は判定語を**そのまま転記**し要約・丸めない、(b) 判定の正本は `handoff.md` §1 > `status.md` > `INDEX.md`、(c) WARN / FAIL / 条件付き PASS は**その語のまま**書く、を規定 | 充足 |
| **AC-3** | WF-05 完了資産に発行時点 SHA を明記するか、コミット後に更新する工程のいずれかが規定 | 同節 3: `issued_at_commit` の明記 **または** 完了資産コミット後の再測定工程のいずれかを必須と規定（両方でも可）。併せて「運用で増える値を契約値として書かない」を明記 | 充足 |
| **AC-4** | テンプレートが AC-1〜AC-3 に追従 | `templates/INDEX.md`: 更新契約の注記 + 値域を AC-2 の一覧へ差し替え + 転記・正本優先順の注記。`templates/status.md`: 現在フェーズ値域を `INDEX.md` と統一 + `issued_at_commit` 行 + 測定値注記。`templates/handoff.md`: frontmatter と メタ yaml に `issued_at_commit` 追加 + 測定値注記 | 充足 |
| **AC-5** | INDEX が stale な TASK を機械検出できる／少なくとも検出方法が doc に書かれている | 同節 4 に検出スクリプト（`status.md` より古い commit でしか `INDEX.md` が更新されていない TASK を列挙）を掲載。**実走で検証済**: `checked=26 / stale_candidates=13`（ref `1e629fb`。0 件でも全件でもない＝空振りでないことの陽性コントロール）。CLI 化は issue の Out of scope のため行わない（AC-5 の「少なくとも検出方法が doc に書かれている」を満たす） | 充足（doc 記載 + 実走検証。CLI 化は範囲外） |

### #946

| AC | 内容 | 充足する差分 | 判定 |
|----|------|------------|------|
| **AC-1** | 「敵対レビューのラウンド設計」節があり、ラウンド数の下限が Mode と紐づいて規定 | `.claude/rules/review-principles.md` に新節 `## 7-quater. 敵対レビューのラウンド設計と収束判定`。「適用範囲とラウンド数の下限」表で `high-risk` / `critical` → 下限 2、`standard` かつ外部作用層・承認境界・セキュリティ境界に触れる → 下限 2、`ultra-light` / `light` かつ非該当 → 下限なし。判定不能時は安全側（該当扱い） | 充足 |
| **AC-2** | 2 ラウンド目以降の焦点が「前ラウンドの是正を疑う」と明記 | 「2 ラウンド目以降の焦点」節: 冒頭で「新しい穴を探すのではなく**前ラウンドの是正そのものを疑う**」と明記し、3 観点（是正が効いていない箇所 / 是正が生んだ新しい穴 / fail-closed 化が正常系を壊していないか）を列挙 | 充足 |
| **AC-3** | 収束判定が「新クラスが出なくなったか」として定義（「指摘ゼロ」ではない） | 「収束判定」節: 「**「指摘ゼロ」を収束条件にしない**」と明示的に否定し、「新しい回避クラス / 失敗クラスが出なくなったか」と定義。同型の再検出は収束を妨げないこと、新クラスが出続けるなら設計モデルを疑うことを規定。加えて**回避クラス台帳**（追記専用・「前ラウンドが見つけられなかった理由」必須）を規定 | 充足 |
| **AC-4** | 打ち切り時に完全性を主張しないこと・残存脅威モデルの明示が求められている | 「打ち切り方（完全性を主張しない）」節: 残存脅威モデル（守るもの / 守らないもの）の列挙、多層防御の 1 層であることと保証の主体、記載先は実装 docstring と運用 doc の**両方**（片方だけにしない）を要求 | 充足 |
| **AC-5** | 既存の 5 観点 / Severity / 判定基準が変更されていないことを差分で確認 | `review-principles.md` の差分は **`@@ -94,6 +94,87 @@` の 1 hunk のみ・削除 0 行**。§2（13 行目〜）/ §3（21 行目〜）/ §4（30 行目〜）は hunk 範囲外で**一切変更されていない**ことが差分そのもので確認できる。新節本文にも「§2〜4 を変更しない」旨を明記 | 充足（差分で機械確認可能） |
| **AC-6** | TASK-0917 を適用例として参照でき、次に外部作用層を作る PBI が plan 段階でラウンド数を決められる | 「適用例」節: `docs/working/TASK-0917/`（#917 / PR #941）と `todo.md` の T-45 / T-46、`review-external.md` / `handoff.md` §4 を参照。参照先の実在は測定済（§2 の 946-c）。「plan 段階で本節と当該 TASK を参照してラウンド数を決めること」を明記 | 充足（issue 本文の「plan の T-45/T-46」は `todo.md` へ補正） |

## 5. 変更対象ファイル一覧

| # | ファイル | 種別 | 由来 |
|---|---------|------|------|
| 1 | `.claude/rules/working-context.md` | **既存改訂**（HO 対象・Human 適用） | #945 |
| 2 | `plugin/plangate/rules/working-context.md` | 既存改訂（生成物ミラー・§9） | #945 |
| 3 | `.claude/rules/review-principles.md` | **既存改訂**（HO 対象・Human 適用） | #946 |
| 4 | `plugin/plangate/rules/review-principles.md` | 既存改訂（生成物ミラー・§9） | #946 |
| 5 | `docs/working/templates/INDEX.md` | 既存改訂 | #945 AC-4 |
| 6 | `docs/working/templates/status.md` | 既存改訂 | #945 AC-4 |
| 7 | `docs/working/templates/handoff.md` | 既存改訂 | #945 AC-4 |

**新規ファイル追加: 0 件**（§8）。

## 6. 差分（unified diff）

以下をそのまま `git apply` できる（検証結果は §7）。

````diff
diff --git a/.claude/rules/working-context.md b/.claude/rules/working-context.md
--- a/.claude/rules/working-context.md
+++ b/.claude/rules/working-context.md
@@ -96,13 +96,78 @@
 
 **フォールバック**: INDEX.md が存在しない場合（旧形式チケット）→ L1 から開始（status.md を直接読む = 従来動作）。
 
-### current-state.md / status.md / handoff.md の役割分担
+### INDEX.md / current-state.md / status.md / handoff.md の役割分担
 
 | ファイル | 役割 | 目安行数 | 更新タイミング |
 |---------|------|---------|--------------|
+| **INDEX.md** | L0 索引（「今どのフェーズで、次に何を読むか」の入口） | ~40行 | plan 完了時に生成し、**以降はフェーズ遷移のたびに更新**（下記「INDEX.md（L0 索引）の鮮度契約」1 の更新イベント表） |
 | current-state.md | 「今どこにいて、次に何をするか」のスナップショット | ~20行 | タスク完了ごとに上書き |
 | status.md | フェーズ履歴・完了記録のアーカイブ | 制限なし | フェーズ遷移・セッション終了時に追記 |
 | **handoff.md** | WF-05 完了時の引き継ぎパッケージ（完了資産） | 制限なし | WF-05 完了時に 1 回生成 |
+
+#### INDEX.md（L0 索引）の鮮度契約（#945）
+
+`INDEX.md` は Progressive Disclosure の **L0 = セッション開始時に最初に読む 1 ファイル**
+であり、ここが実態から乖離すると次セッションが誤った地点から再開する。生成規定
+（plan 完了時）だけでは以降の更新契約が無いため、以下を規約とする。
+
+**1. 更新イベント**（いずれかが起きたら、同じ作業単位のうちに `INDEX.md` を更新する）
+
+| イベント | `INDEX.md` で更新する項目 |
+|---------|------------------------|
+| plan / todo / test-cases 生成 | 生成（現在フェーズ・次のアクション・ファイルマップ・変更ファイル一覧） |
+| C-3 承認（APPROVED / CONDITIONAL / REJECTED / AUTONOMOUS APPROVED） | 現在フェーズ・次のアクション・承認成果物の状態 |
+| plan の確定反映・再編集 | `approvals/` 配下の `c3.json` の `plan_hash` 整合状態（再承認の要否） |
+| exec 完了 / V-1 判定確定 | 現在フェーズ・総合判定（下記 2 に従う） |
+| WF-05 handoff 発行 | 現在フェーズ = `done`・発行時点 SHA（下記 3） |
+| BLOCKED 化 / 解除 | 現在フェーズ = `BLOCKED`（`blocker` / `unblock_condition` の詳細は status.md 側） |
+
+**2. 「現在フェーズ」の値域と、総合判定を矛盾させないこと**
+
+現在フェーズの値域（`INDEX.md` / `status.md` 共通。この一覧以外の語を使わない）:
+
+```text
+brainstorm | plan | C-1 | C-2 | C-3 待ち | exec | verify（L-0 / V-1〜V-4）| PR 作成済 | C-4 待ち | done | BLOCKED
+```
+
+- `INDEX.md` に V-1 等の**総合判定を書く場合は `status.md` / `handoff.md` の判定語を
+  そのまま転記する**。INDEX 側で独自に要約・丸めない（WARN / 条件付き PASS を PASS と
+  書かない）。
+- 判定の正本は **`handoff.md` §1 > `status.md` > `INDEX.md`** の順。**`INDEX.md` は
+  索引であって判定の正本ではない**。矛盾を検出したときに是正するのは `INDEX.md` 側。
+- 判定が WARN / FAIL / 条件付き PASS のときは `INDEX.md` にも**その語のまま**書く。
+  「最初に読む 1 ファイルだけが不都合な事実を落とす」状態を作らない。
+
+**3. WF-05 完了資産（handoff.md / status.md）の鮮度**
+
+完了資産は「WF-05 完了時に 1 回生成」であるため、**その生成物自身をコミットした時点で
+commit 数・変更ファイル数・未 push ブランチ数といった実測値が古くなる**。次のいずれかを
+必須とする（両方でもよい）。
+
+- **発行時点の commit SHA を明記する**（テンプレートの `issued_at_commit`）。記載した
+  実測値は**その SHA 時点の値**であることを併記する。
+- 完了資産をコミットしたあとに実測値を再測定して更新する工程を取る。
+
+いずれの場合も、commit 数 / ファイル数のような**運用で増える値を契約値として書かない**
+（C-4 レビュアーが見る HEAD とは必ずずれる）。SHA を添えた**測定値**として書く。
+
+**4. stale の機械検出**
+
+CLI / hook 化（`bin/plangate` への追加）は本規約の範囲外。検出は次のワンライナで行う
+（`status.md` より古い commit でしか `INDEX.md` が更新されていない TASK を列挙する）:
+
+```sh
+for d in docs/working/TASK-*/; do
+  [ -f "$d/INDEX.md" ] && [ -f "$d/status.md" ] || continue
+  i=$(git log -1 --format=%ct -- "$d/INDEX.md")
+  s=$(git log -1 --format=%ct -- "$d/status.md")
+  [ -n "$i" ] && [ -n "$s" ] && [ "$i" -lt "$s" ] && echo "STALE-CANDIDATE: $d"
+done
+```
+
+これは**候補抽出**であり、stale の確定は内容照合で行う（更新時刻だけで断定しない）。
+併せて `INDEX.md` の「現在フェーズ」が `status.md` フェーズ履歴の**最終行**および
+`handoff.md` §1 の総合判定と一致するかを照合する。
 
 ### handoff（WF-05 完了資産 / Rule 5）
 
diff --git a/plugin/plangate/rules/working-context.md b/plugin/plangate/rules/working-context.md
--- a/plugin/plangate/rules/working-context.md
+++ b/plugin/plangate/rules/working-context.md
@@ -96,13 +96,78 @@
 
 **フォールバック**: INDEX.md が存在しない場合（旧形式チケット）→ L1 から開始（status.md を直接読む = 従来動作）。
 
-### current-state.md / status.md / handoff.md の役割分担
+### INDEX.md / current-state.md / status.md / handoff.md の役割分担
 
 | ファイル | 役割 | 目安行数 | 更新タイミング |
 |---------|------|---------|--------------|
+| **INDEX.md** | L0 索引（「今どのフェーズで、次に何を読むか」の入口） | ~40行 | plan 完了時に生成し、**以降はフェーズ遷移のたびに更新**（下記「INDEX.md（L0 索引）の鮮度契約」1 の更新イベント表） |
 | current-state.md | 「今どこにいて、次に何をするか」のスナップショット | ~20行 | タスク完了ごとに上書き |
 | status.md | フェーズ履歴・完了記録のアーカイブ | 制限なし | フェーズ遷移・セッション終了時に追記 |
 | **handoff.md** | WF-05 完了時の引き継ぎパッケージ（完了資産） | 制限なし | WF-05 完了時に 1 回生成 |
+
+#### INDEX.md（L0 索引）の鮮度契約（#945）
+
+`INDEX.md` は Progressive Disclosure の **L0 = セッション開始時に最初に読む 1 ファイル**
+であり、ここが実態から乖離すると次セッションが誤った地点から再開する。生成規定
+（plan 完了時）だけでは以降の更新契約が無いため、以下を規約とする。
+
+**1. 更新イベント**（いずれかが起きたら、同じ作業単位のうちに `INDEX.md` を更新する）
+
+| イベント | `INDEX.md` で更新する項目 |
+|---------|------------------------|
+| plan / todo / test-cases 生成 | 生成（現在フェーズ・次のアクション・ファイルマップ・変更ファイル一覧） |
+| C-3 承認（APPROVED / CONDITIONAL / REJECTED / AUTONOMOUS APPROVED） | 現在フェーズ・次のアクション・承認成果物の状態 |
+| plan の確定反映・再編集 | `approvals/` 配下の `c3.json` の `plan_hash` 整合状態（再承認の要否） |
+| exec 完了 / V-1 判定確定 | 現在フェーズ・総合判定（下記 2 に従う） |
+| WF-05 handoff 発行 | 現在フェーズ = `done`・発行時点 SHA（下記 3） |
+| BLOCKED 化 / 解除 | 現在フェーズ = `BLOCKED`（`blocker` / `unblock_condition` の詳細は status.md 側） |
+
+**2. 「現在フェーズ」の値域と、総合判定を矛盾させないこと**
+
+現在フェーズの値域（`INDEX.md` / `status.md` 共通。この一覧以外の語を使わない）:
+
+```text
+brainstorm | plan | C-1 | C-2 | C-3 待ち | exec | verify（L-0 / V-1〜V-4）| PR 作成済 | C-4 待ち | done | BLOCKED
+```
+
+- `INDEX.md` に V-1 等の**総合判定を書く場合は `status.md` / `handoff.md` の判定語を
+  そのまま転記する**。INDEX 側で独自に要約・丸めない（WARN / 条件付き PASS を PASS と
+  書かない）。
+- 判定の正本は **`handoff.md` §1 > `status.md` > `INDEX.md`** の順。**`INDEX.md` は
+  索引であって判定の正本ではない**。矛盾を検出したときに是正するのは `INDEX.md` 側。
+- 判定が WARN / FAIL / 条件付き PASS のときは `INDEX.md` にも**その語のまま**書く。
+  「最初に読む 1 ファイルだけが不都合な事実を落とす」状態を作らない。
+
+**3. WF-05 完了資産（handoff.md / status.md）の鮮度**
+
+完了資産は「WF-05 完了時に 1 回生成」であるため、**その生成物自身をコミットした時点で
+commit 数・変更ファイル数・未 push ブランチ数といった実測値が古くなる**。次のいずれかを
+必須とする（両方でもよい）。
+
+- **発行時点の commit SHA を明記する**（テンプレートの `issued_at_commit`）。記載した
+  実測値は**その SHA 時点の値**であることを併記する。
+- 完了資産をコミットしたあとに実測値を再測定して更新する工程を取る。
+
+いずれの場合も、commit 数 / ファイル数のような**運用で増える値を契約値として書かない**
+（C-4 レビュアーが見る HEAD とは必ずずれる）。SHA を添えた**測定値**として書く。
+
+**4. stale の機械検出**
+
+CLI / hook 化（`bin/plangate` への追加）は本規約の範囲外。検出は次のワンライナで行う
+（`status.md` より古い commit でしか `INDEX.md` が更新されていない TASK を列挙する）:
+
+```sh
+for d in docs/working/TASK-*/; do
+  [ -f "$d/INDEX.md" ] && [ -f "$d/status.md" ] || continue
+  i=$(git log -1 --format=%ct -- "$d/INDEX.md")
+  s=$(git log -1 --format=%ct -- "$d/status.md")
+  [ -n "$i" ] && [ -n "$s" ] && [ "$i" -lt "$s" ] && echo "STALE-CANDIDATE: $d"
+done
+```
+
+これは**候補抽出**であり、stale の確定は内容照合で行う（更新時刻だけで断定しない）。
+併せて `INDEX.md` の「現在フェーズ」が `status.md` フェーズ履歴の**最終行**および
+`handoff.md` §1 の総合判定と一致するかを照合する。
 
 ### handoff（WF-05 完了資産 / Rule 5）
 
diff --git a/.claude/rules/review-principles.md b/.claude/rules/review-principles.md
--- a/.claude/rules/review-principles.md
+++ b/.claude/rules/review-principles.md
@@ -94,6 +94,87 @@
 
 C-2 / V-3 の外部 AI レビューが**実行不可**（CLI 未導入・API 不達・quota 超過等）の場合の記録規約は [`docs/ai/external-reviewer-interface.md`](../../docs/ai/external-reviewer-interface.md) §10 を正本とする。「指摘なし」と「実行不可」を区別し、`unavailable` は理由・代替観点・未充足リスクを必須記録（`verdict` は WARN、空欄は FAIL）。
 
+## 7-quater. 敵対レビューのラウンド設計と収束判定（#946 / TASK-0917 由来）
+
+> 本節は **§2〜4（5 つのレビュー観点 / Severity 4 段階 / 判定基準）を変更しない**。
+> ラウンド設計はそれらの**上に載る実施設計**であり、「何を見るか」ではなく
+> 「何回・どの焦点で回し、いつ打ち切るか」だけを定める。
+> レビュアーの体制（レーン数・エージェント選定）は本節の範囲外
+> （`codex-multi-agent` / サブエージェント委譲プロトコルの領域）。
+
+### 適用範囲とラウンド数の下限
+
+| 対象 | ラウンド下限 |
+|------|------------|
+| Mode = `high-risk` / `critical` | **2 ラウンド以上**を plan に含める |
+| Mode = `standard` で、**外部作用層**（外部コマンド実行 / ネットワーク / push・merge 等の不可逆操作）・**承認境界**・**セキュリティ境界**に触れる | **2 ラウンド以上**を plan に含める |
+| Mode = `ultra-light` / `light` で、上記の境界に触れない | 下限なし（1 ラウンドで足りる） |
+
+- ここで定めるのは**下限**であり、上限は定めない。実施回数は下記の収束判定で決まる。
+  「N ラウンド実施」を固定の契約値として plan に書かない。
+- 該当するかどうかが判定不能・不確実な場合は**該当扱い**（下限を課す側）にする
+  （[`mode-classification.md`](./mode-classification.md) の安全側推定と一貫）。
+
+### 2 ラウンド目以降の焦点
+
+2 ラウンド目以降は「新しい穴」を探すのではなく、**前ラウンドの是正そのものを疑う**:
+
+1. **是正が実は効いていない箇所** — 同じ目的を別の形で達成できる経路（別名・別経路・
+   別ノード種別など）が残っていないか
+2. **是正によって新たに生まれた穴** — 前ラウンドの修正が導入した分岐・例外・
+   後方互換パス
+3. **fail-closed 化が正常系を壊していないか** — 防御の追加が可用性・実行時間の側に
+   別の穴を開けていないか
+
+### 収束判定
+
+**「指摘ゼロ」を収束条件にしない。** 収束判定は
+**「新しい回避クラス / 失敗クラスが出なくなったか」**とする。
+
+- 前ラウンドで出たクラスの**同型の再検出**は収束の妨げにならない（是正漏れとして直す）。
+- 毎ラウンド**新しいクラス**が出続けるなら、それは打ち切りどきではなく
+  **設計モデルそのものを疑うとき**（検査の粒度・前提が対象領域と合っていない）。
+
+#### 回避クラス台帳（追記専用）
+
+各ラウンドで出たクラスを表で残し、以後**新しいクラスを見つけたら塞いだうえで 1 行追加**する。
+
+| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
+|-------|------------------|------------|------|--------------------------------|
+| <クラス名> | <最小再現> | R<n> | <差分 / commit> | <前ラウンドの検査モデルの構造的な限界> |
+
+「前ラウンドが見つけられなかった理由」は**必須**。ここが埋まらない指摘は、ラウンドを
+分けた意味が無い（同じ層をもう一度見ただけ）。
+
+### 打ち切り方（完全性を主張しない）
+
+打ち切る際は**完全性を主張せず**、以下を明記する:
+
+- **残存脅威モデル**: 「守るもの / 守らないもの」を列挙する
+- 本検査が**多層防御の 1 層**であること、および保証の主体（例: runtime allowlist /
+  C-4 Human レビュー / branch protection）
+- 記載先は**実装側**（module docstring 等、コードを読む人が最初に見る場所）と
+  **運用 doc** の両方。片方だけにしない
+
+### fixture と実環境の役割分担
+
+実環境 1 周は「証跡づくり」ではなく、**fixture が原理的に検出できない型の検出手段**である:
+
+| 手段 | 検出できるもの | 検出できないもの |
+|------|--------------|----------------|
+| fixture（手書き） | ロジック・分岐・境界値・回帰 | 実 API のレスポンス形状 / 非同期処理の登録タイミング / 実操作の rc |
+| 実環境 1 周 | 上記の実測 | 網羅（実行した経路だけ） |
+
+**どちらか一方で他方を代替しない。** 実環境 1 周を省く場合は、「実 API 形状・
+タイミング由来の失敗は未検証」と残存脅威モデルに明記する。
+
+### 適用例
+
+`docs/working/TASK-0917/`（#917 / PR #941）。`todo.md` の T-45 / T-46 で外部作用層に
+2 ラウンドを要求し、R2 / R3 でそれぞれ前ラウンドが構造的に見られなかったクラスの
+critical を検出した実走記録（`review-external.md` / `handoff.md` §4）。次に外部作用層を
+作る PBI は、plan 段階で本節と当該 TASK を参照してラウンド数を決めること。
+
 ## 8. レビューの優先順位
 
 1. **Critical**: セキュリティ脆弱性、データ損失のリスク、システムダウンの可能性
diff --git a/plugin/plangate/rules/review-principles.md b/plugin/plangate/rules/review-principles.md
--- a/plugin/plangate/rules/review-principles.md
+++ b/plugin/plangate/rules/review-principles.md
@@ -94,6 +94,87 @@
 
 C-2 / V-3 の外部 AI レビューが**実行不可**（CLI 未導入・API 不達・quota 超過等）の場合の記録規約は [`docs/ai/external-reviewer-interface.md`](../../docs/ai/external-reviewer-interface.md) §10 を正本とする。「指摘なし」と「実行不可」を区別し、`unavailable` は理由・代替観点・未充足リスクを必須記録（`verdict` は WARN、空欄は FAIL）。
 
+## 7-quater. 敵対レビューのラウンド設計と収束判定（#946 / TASK-0917 由来）
+
+> 本節は **§2〜4（5 つのレビュー観点 / Severity 4 段階 / 判定基準）を変更しない**。
+> ラウンド設計はそれらの**上に載る実施設計**であり、「何を見るか」ではなく
+> 「何回・どの焦点で回し、いつ打ち切るか」だけを定める。
+> レビュアーの体制（レーン数・エージェント選定）は本節の範囲外
+> （`codex-multi-agent` / サブエージェント委譲プロトコルの領域）。
+
+### 適用範囲とラウンド数の下限
+
+| 対象 | ラウンド下限 |
+|------|------------|
+| Mode = `high-risk` / `critical` | **2 ラウンド以上**を plan に含める |
+| Mode = `standard` で、**外部作用層**（外部コマンド実行 / ネットワーク / push・merge 等の不可逆操作）・**承認境界**・**セキュリティ境界**に触れる | **2 ラウンド以上**を plan に含める |
+| Mode = `ultra-light` / `light` で、上記の境界に触れない | 下限なし（1 ラウンドで足りる） |
+
+- ここで定めるのは**下限**であり、上限は定めない。実施回数は下記の収束判定で決まる。
+  「N ラウンド実施」を固定の契約値として plan に書かない。
+- 該当するかどうかが判定不能・不確実な場合は**該当扱い**（下限を課す側）にする
+  （[`mode-classification.md`](./mode-classification.md) の安全側推定と一貫）。
+
+### 2 ラウンド目以降の焦点
+
+2 ラウンド目以降は「新しい穴」を探すのではなく、**前ラウンドの是正そのものを疑う**:
+
+1. **是正が実は効いていない箇所** — 同じ目的を別の形で達成できる経路（別名・別経路・
+   別ノード種別など）が残っていないか
+2. **是正によって新たに生まれた穴** — 前ラウンドの修正が導入した分岐・例外・
+   後方互換パス
+3. **fail-closed 化が正常系を壊していないか** — 防御の追加が可用性・実行時間の側に
+   別の穴を開けていないか
+
+### 収束判定
+
+**「指摘ゼロ」を収束条件にしない。** 収束判定は
+**「新しい回避クラス / 失敗クラスが出なくなったか」**とする。
+
+- 前ラウンドで出たクラスの**同型の再検出**は収束の妨げにならない（是正漏れとして直す）。
+- 毎ラウンド**新しいクラス**が出続けるなら、それは打ち切りどきではなく
+  **設計モデルそのものを疑うとき**（検査の粒度・前提が対象領域と合っていない）。
+
+#### 回避クラス台帳（追記専用）
+
+各ラウンドで出たクラスを表で残し、以後**新しいクラスを見つけたら塞いだうえで 1 行追加**する。
+
+| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
+|-------|------------------|------------|------|--------------------------------|
+| <クラス名> | <最小再現> | R<n> | <差分 / commit> | <前ラウンドの検査モデルの構造的な限界> |
+
+「前ラウンドが見つけられなかった理由」は**必須**。ここが埋まらない指摘は、ラウンドを
+分けた意味が無い（同じ層をもう一度見ただけ）。
+
+### 打ち切り方（完全性を主張しない）
+
+打ち切る際は**完全性を主張せず**、以下を明記する:
+
+- **残存脅威モデル**: 「守るもの / 守らないもの」を列挙する
+- 本検査が**多層防御の 1 層**であること、および保証の主体（例: runtime allowlist /
+  C-4 Human レビュー / branch protection）
+- 記載先は**実装側**（module docstring 等、コードを読む人が最初に見る場所）と
+  **運用 doc** の両方。片方だけにしない
+
+### fixture と実環境の役割分担
+
+実環境 1 周は「証跡づくり」ではなく、**fixture が原理的に検出できない型の検出手段**である:
+
+| 手段 | 検出できるもの | 検出できないもの |
+|------|--------------|----------------|
+| fixture（手書き） | ロジック・分岐・境界値・回帰 | 実 API のレスポンス形状 / 非同期処理の登録タイミング / 実操作の rc |
+| 実環境 1 周 | 上記の実測 | 網羅（実行した経路だけ） |
+
+**どちらか一方で他方を代替しない。** 実環境 1 周を省く場合は、「実 API 形状・
+タイミング由来の失敗は未検証」と残存脅威モデルに明記する。
+
+### 適用例
+
+`docs/working/TASK-0917/`（#917 / PR #941）。`todo.md` の T-45 / T-46 で外部作用層に
+2 ラウンドを要求し、R2 / R3 でそれぞれ前ラウンドが構造的に見られなかったクラスの
+critical を検出した実走記録（`review-external.md` / `handoff.md` §4）。次に外部作用層を
+作る PBI は、plan 段階で本節と当該 TASK を参照してラウンド数を決めること。
+
 ## 8. レビューの優先順位
 
 1. **Critical**: セキュリティ脆弱性、データ損失のリスク、システムダウンの可能性
diff --git a/docs/working/templates/INDEX.md b/docs/working/templates/INDEX.md
--- a/docs/working/templates/INDEX.md
+++ b/docs/working/templates/INDEX.md
@@ -1,6 +1,9 @@
 # TASK-XXXX INDEX
 
 > 最終更新: YYYY-MM-DD HH:MM
+> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
+> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
+> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。
 
 ## チケット概要（1-2文）
 
@@ -8,7 +11,12 @@
 
 ## 現在のフェーズ
 
-{brainstorm | plan | C-1 | C-2 | C-3待ち | exec | done}
+{brainstorm | plan | C-1 | C-2 | C-3 待ち | exec | verify（L-0 / V-1〜V-4）| PR 作成済 | C-4 待ち | done | BLOCKED}
+
+> 値域は `status.md` と共通（正本: `.claude/rules/working-context.md`）。
+> V-1 等の**総合判定をここに書く場合は `status.md` / `handoff.md` の判定語をそのまま転記する**。
+> INDEX 側で要約・丸めない（WARN / 条件付き PASS を PASS と書かない）。
+> 判定の正本は `handoff.md` §1 > `status.md` > 本ファイル。矛盾時に是正するのは本ファイル側。
 
 ## 次のアクション
 
diff --git a/docs/working/templates/status.md b/docs/working/templates/status.md
--- a/docs/working/templates/status.md
+++ b/docs/working/templates/status.md
@@ -1,8 +1,15 @@
 # TASK-XXXX 作業ステータス
 
 > 最終更新: YYYY-MM-DD HH:mm
-> 現在フェーズ: {plan / exec / review / verify / done}
+> 現在フェーズ: {brainstorm | plan | C-1 | C-2 | C-3 待ち | exec | verify（L-0 / V-1〜V-4）| PR 作成済 | C-4 待ち | done | BLOCKED}
 > モード: {ultra-light / light / standard / high-risk / critical}
+> 発行時点 SHA (issued_at_commit): {完了資産として発行した時点の commit SHA}
+
+> 現在フェーズの値域は `INDEX.md` と共通（正本: `.claude/rules/working-context.md`）。
+> 本ファイルに書く commit 数 / 変更ファイル数 / 未 push ブランチ数は
+> **`issued_at_commit` 時点の測定値**であり契約値ではない
+> （完了資産自身のコミットで必ずずれる）。SHA を書かない場合は、完了資産を
+> コミットしたあとに再測定して更新すること。
 
 ## フェーズ履歴
 
diff --git a/docs/working/templates/handoff.md b/docs/working/templates/handoff.md
--- a/docs/working/templates/handoff.md
+++ b/docs/working/templates/handoff.md
@@ -4,6 +4,7 @@
 schema_version: 1
 status: final
 issued_at: YYYY-MM-DD
+issued_at_commit: <発行時点の commit SHA>
 author: qa-reviewer
 v1_release: ""
 ---
@@ -21,8 +22,15 @@
 related_issue: <issue URL>
 author: qa-reviewer
 issued_at: YYYY-MM-DD
+issued_at_commit: <発行時点の commit SHA>
 v1_release: <コミット SHA or タグ>
 ```
+
+> `issued_at_commit` は**本 handoff を発行した時点の commit SHA**。本文に書く
+> commit 数 / 変更ファイル数 / 未 push ブランチ数は**その SHA 時点の測定値**であり、
+> HEAD の値とは一致しない（完了資産自身のコミットで必ずずれる）。SHA を書かない場合は、
+> 完了資産をコミットしたあとに再測定して更新すること
+> （正本: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」3）。
 
 ## 1. 要件適合確認結果
 
````

## 7. 適用手順と検証記録

### 適用手順（Human-owned）

```sh
# 1) 本 PR がマージされた main（または本 PR のブランチ）で patch を取り出す
#    差分は本ファイル §6 のコードブロックそのもの
# 2) 適用可否を確認する（ファイルは一切変更されない）
git apply --check /path/to/945-946.patch
# 3) 適用する
git apply /path/to/945-946.patch
# 4) plugin ミラーが正本と一致していることを確認する（§9）
sh scripts/sync-plugin-plangate.sh
git diff --quiet -- plugin/plangate/ && echo "plugin in sync"
```

### 検証記録（AI 実測）

| 検証 | コマンド | 結果 |
|------|---------|------|
| patch 適用可否 | `git apply --check patch.diff` | **rc=0** |
| 適用範囲 | `git apply --check --stat patch.diff` | rc=0 / 7 files changed, 319 insertions(+), 4 deletions(-) |
| **負のコントロール** | 先頭 hunk header を `@@ -96,13 +96,78 @@` → `@@ -96,12 +96,78 @@` に改変して `git apply --check` | **rc=128**（`error: corrupt patch at line 84`）。rc=0 が空振りでないことの確認 |
| hunk header 検算 | 全 hunk の旧行数 = context + 削除 / 新行数 = context + 追加 | `difflib.unified_diff` が生成し、`git apply --check` rc=0 で機械確認（手加工なし） |
| §945 AC-5 スクリプト実走 | 本書 §6 の diff に含まれる検出スクリプトを ref `1e629fb` で実行 | rc=0 / `checked=26 stale_candidates=13` |
| 参照先の実在（#946 適用例） | `git ls-tree --name-only origin/main docs/working/TASK-0917/` | `handoff.md` / `review-external.md` / `todo.md` すべて存在。`handoff.md` に `## 4. 妥協点` 存在 |

**patch は手加工していない。** 対象ファイルを scratchpad に複製 → 複製側だけを編集 →
`difflib.unified_diff` で生成 → `git apply --check` で検証、という手順を取った。
**`.claude/rules/` 配下は本作業中に一度も書き込んでいない**（`git diff --name-only origin/main...HEAD`
が本ファイル 1 件であることで確認できる）。

## 8. 新規ファイル追加の有無（Human 判断材料）

**新規ファイル追加は 0 件。** 7 ファイルすべてが既存ファイルの改訂である。

- issue #945 の Suggested files は「INDEX テンプレートが**無ければ**新設」としていたが、
  `docs/working/templates/INDEX.md` は現 main に**存在する**（§2 の 945-d）。
  したがって**新設せず既存を改訂**する設計にした。
- `plan.md` という basename のファイルは作成していない（EH-3 の block 対象を回避）。

## 9. plugin ミラーへの伝播

**同期スクリプトは実行していない。** allowlist / 対象ディレクトリの宣言を読んで判定した。

| 観点 | 実測 |
|------|------|
| 同期対象ディレクトリ | `scripts/sync-plugin-plangate.sh` の `for _dir in agents rules commands; do sync_dir "$CLAUDE_DIR/$_dir" "$PLUGIN_DIR/$_dir" "$_dir"; done` に **`rules` が含まれる** |
| 対象ファイルの選び方 | `sync_dir` は `"$_src"/*.md` などの **glob 総なめ**（ファイル単位の allowlist ではない）。`README.md` のみ除外 |
| ミラーの現況 | `plugin/plangate/rules/` に 6 ファイル。`working-context.md` / `review-principles.md` とも **正本と byte 一致**（shasum: `843f68f7…` / `4344bc76…`、両側同値） |
| **結論** | `.claude/rules/*.md` の改訂は **自動追従する**（次回 sync 実行時にコピーされる） |

### ただし、同じ PR で mirror も更新する必要がある

`.github/workflows/sync-plugin-plangate.yml` の **`drift-check` ジョブ**（`pull_request` 時）は
`sh scripts/sync-plugin-plangate.sh` を実行したうえで `git diff --quiet -- plugin/plangate/` を
必須にしている。したがって **`.claude/rules/` だけを変更した PR は drift-check で FAIL する**。

このため本 patch には **`plugin/plangate/rules/` 側の同一 hunk を最初から含めてある**
（§5 の #2 / #4）。patch を適用したあとに `sh scripts/sync-plugin-plangate.sh` を走らせても
**no-op** になる（差分ゼロ）。

`docs/working/templates/` は plugin の配布対象外（`sync-plugin-plangate.sh` が `docs/` から
同期するのは ai-loop 関連ディレクトリと `docs/schemas/` のみ）。**テンプレート改訂は
plugin へ伝播しない = 伝播作業は不要**。

## 10. 未確定として残したもの

| # | 内容 | 状態 |
|---|------|------|
| U-1 | 適用後の C-3 判定（HO 対象のため `lite_eligible=false` + Standard 同期 C-3 固定） | **未確定**。Human が判断する領域であり本書は patch 提示まで |
| U-2 | #945 AC-5 の「機械検出」を CLI / CI に昇格するか | **未確定**。issue の Out of scope（`bin/plangate` への CLI 追加）に該当するため本 patch では doc 記載 + 実走検証にとどめた。CI 化するなら別 PBI |
| U-3 | §6 の stale 検出で挙がった 13 件の TASK が**実際に** stale かどうか | **未検証**。スクリプトは候補抽出であり内容照合をしていない。issue #945 の Non-goals（過去 TASK の一括是正）に該当するため本 patch の範囲外 |
| U-4 | 現在フェーズ値域の統一が既存 TASK ディレクトリの記述と衝突しないか | **未検証**。既存 `INDEX.md` / `status.md` は `verify` / `C-3待ち` 等の旧表記を含みうる。新値域は**今後の記述**に対する規約であり、過去分の一括是正は行わない（#945 Non-goals と一貫） |
| U-5 | `docs/working/_reports/` は markdownlint CI の glob 対象外（`README.md` / `CHANGELOG.md` / `docs/index.md` / `docs/workflows/**/*.md` 等のみ）。`.claude/rules/` も対象外 | **確定（対象外）**。本書および patch 後の rules に lint CI は発火しない |

## 11. スコープ外の報告事項（手を出していない）

| # | 内容 |
|---|------|
| S-1 | `templates/INDEX.md` と `templates/status.md` で「現在フェーズ」の値域が既に食い違っていた（issue 本文に記載が無い所見）。本 patch で統一するが、**これは #945 AC-2 の範囲内**として扱った |
| S-2 | issue #946 本文の「plan の T-45 / T-46」は現 main で不成立（実体は `todo.md`）。**issue 本文の訂正は行っていない**（本書 §2 に記録するにとどめる） |
| S-3 | issue #945 本文の Suggested files「INDEX テンプレートが無ければ新設」は現 main で前提が不成立（テンプレートは存在する）。**issue 本文の訂正は行っていない** |
