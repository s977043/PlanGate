# bug backlog 棚卸し — 番号上位 20 件（2026-08-20 / upper）

> **目的**: 「既に main で解消しているのに open のまま残っている issue」を実測で特定し、backlog を減らせる分を切り出す。
> **測定基点**: `origin/main` = `684949eca274ce469ed7b41a43f08e4b384f96f2`（`docs(release): CLAUDE.md の最新リリース節を v8.21.0 へ更新 (#1190)`）
> **本レポートは読み取りのみで作成した。** issue / PR への書き込み（コメント・close・ラベル・編集）は一切行っていない。

## 0. 依頼時の想定との差分（先に明示）

### 0-1. 測定基点が 1 コミット進んでいた

依頼文の基点は `ea1e2cc` だったが、取得時点の実測は **`684949e`**（`ea1e2cc` の 1 つ先、PR #1190）。

```
$ git log --oneline ea1e2cc..origin/main
684949e docs(release): CLAUDE.md の最新リリース節を v8.21.0 へ更新 (#1190)
```

**この 1 コミットが判定を 1 件ひっくり返した。** #1190 は `CLAUDE.md` の最新リリース節を書き換えており、**#1102 の全 AC がこれで充足した**（§2）。オーガナイザーから「#1102 は未解消（`grep -c '#1089.*未適用'` = 1）」という実測を受領していたが、それは `ea1e2cc` 時点の測定であり、**`684949e` では 0 になる**。

### 0-2. #1177 は既に CLOSED（ただし AC 未達）

```
$ gh issue view 1177 --repo s977043/plangate --json state,stateReason,closedAt
state=CLOSED  stateReason=COMPLETED  closedAt=2026-08-20T03:02:35Z
```

担当範囲 20 件のうち **#1177 だけが open ではない**。したがって `--label bug --state open` の実測集合は **19 件**。

```
$ gh issue list --repo s977043/plangate --state open --label bug --limit 100 --json number
（40 件。うち担当範囲に該当するのは 19 件 = 1177 を除く全て）
```

**20 件すべてを扱った。** #1177 は close 済みだが、依頼範囲に含まれるため **AC 照合を行い「PREMATURE CLOSE」として §4-0 に記載**した。

### 0-3. オーガナイザーから受領した前提の検証結果

| 受領した前提 | 本レポートの実測結果 |
|---|---|
| #1177 は CLOSE-NOW（87/87 ガード済） | **誤り。AC は 7 つあり充足は AC-1/2/6/7 の 4 件。AC-3/4/5 が未達**（オーガナイザー自身が訂正済み。§4-0 で独立に再測定） |
| #1177 の AC-3 未実施 / AC-5 timeout 0 件 | **正しい**（独立に再測定して一致） |
| #1178 未修正（TC-01 が marker 文字列のみ） | **正しい**（§4-6） |
| #1180 M-1 未修正（`ta-69` に `plugin/pa/skills` が 3 箇所） | **正しい**。`tests/extras/ta-69-distribution-checks.sh` の `:204` / `:216` / `:229`（TC-C6 = `:229`）。**行番号は現 main でも正確**（stale ではない） |
| #1102 未解消（`CLAUDE.md` に該当記述 1 件） | **`684949e` では成立しない。0 件**（§0-1 / §2） |

## 1. サマリ表

**分類別の件数**

| 分類 | 件数 | issue |
|---|---:|---|
| **CLOSE-NOW** | **1** | #1102 |
| **CLOSE-AFTER-1** | **1** | #1018 |
| **PARTIAL** | **6** | #1011 / #1057 / #1081 / #1093 / #1101 / #1104 |
| **OPEN** | **11** | #1021 / #1044 / #1086 / #1105 / #1144 / #1151 / #1162 / #1165 / #1170 / #1178 / #1180 |
| **PREMATURE CLOSE**（close 済だが AC 未達 / 実質 PARTIAL） | **1** | #1177 |
| **SUPERSEDED** | **0** | — |
| **STALE**（上記と**併存**。本文の是正が先に要る） | **10** | #1021 / #1044 / #1081 / #1086 / #1093 / #1162 / #1165 / #1170 / #1177 / #1178 |

> **STALE を排他分類にしない理由**: 10 件はいずれも「バグ自体は残存」かつ「issue 本文の前提が現 main と食い違う」の二重状態である。片方に潰すと情報が落ちる。

**実行層の凡例**: **L1** = `.md` のみ・即着手可 / **L2** = `.py` / `.sh` を書く（`PLANGATE_HOOK_TASK` セッションが要る）/ **L3** = HO 対象パス（AI は patch 提示まで・適用は Human）/ **LH** = Human の設計判断が要る

| # | 分類 | 層 | 1 行根拠（実測） | close 可否 |
|---|---|---|---|---|
| **1011** | PARTIAL / — | L2（V3-02 は LH） | `sync-plugin-plangate.sh:57` の fail-open・`:58` の全経路 override が base 以降無変更。V3-06 のみ TC-13 の出力照合化で解消済 | 不可 |
| **1018** | **CLOSE-AFTER-1** | L1（要 HOOK_TASK） | テンプレ見出しが `## Files / Interfaces`（`:73`）のまま。**patch が main に同梱済**（`_reports/1102-1018-blocked-oneline-patch.md` 第 2 部） | **あと 1 手** |
| **1021** | OPEN / STALE | L2 | `ta-09-metrics.sh:8` の `$0` ベース root 解決・`:14-23` の cleanup 片手落ちが起票時から無変更。`PG_HARNESS_SOURCED` は ta-07/08/09 で 0 件 | 不可 |
| **1044** | OPEN / STALE | L2 | 4 シェル再実測で **dash rc=0 / zsh rc=0 / bash rc=1 / sh rc=1**（起票時と同値）。適用先は 13 → **21 本**へ拡大 | 不可 |
| **1057** | **PARTIAL** | L1（症状2）/ LH | `plugin/plangate/` に `bin` なし（10 dir 全数列挙）。ただし症状 3 は #1160 で記述是正済・提案 4 は README:36 で充足 | 不可 |
| **1081** | PARTIAL / STALE | LH → L1/L3 | Slice 2（frontmatter quote）は 4 root 完了・validator error 0。Slice 1 は `Skills (45)` に `README` + 同名 3 件が露出したまま | 不可 |
| **1086** | OPEN / **STALE** | LH → L1/L2 | `.codex/skills` は 39 SKILL.md / 120 ファイルが tracked のまま。**本文の `differing=2` は実測 32/39** | 不可 |
| **1093** | **PARTIAL** / STALE | L2 | `check_pending_applies()`（`release-prep.sh:55-57`）が `[dry-run]` 文字列一致 + `2>/dev/null \|\| true` のままで **7 AC 全滅**。ただし計画は C-3 承認済・#1114 へ分割済 | 不可 |
| **1101** | **PARTIAL** | L3 | 正規化は `./` と `$REPO_ROOT/` のみ（`:85-90`）。4 変換クラスが再現。**patch 設計 1046 行が #1156 で main 着地済** | 不可 |
| **1102** | **CLOSE-NOW** | — | `git show origin/main:CLAUDE.md \| grep -c '#1089.*未適用'` → **0**。#1190 で解消 | **可** |
| **1104** | PARTIAL | L3 | AC-7（`hook-enforcement.md` §0.1 matcher 表）のみ達成。`Bash` matcher を持つ hook 3 本のいずれも `plan.md` / HO を見ない | 不可 |
| **1105** | OPEN | L1+L3+LH | `bin/plangate:1028` の C-3 出力文言が未変更。`docs/ai` / `docs/workflows` / `.claude` に `1105` の hit 0 | 不可 |
| **1144** | OPEN | L3+L2+LH | `plugin/plangate/hooks/` は `.gitkeep` のみ。`plugin.json` に `hooks` キーなし。`CLAUDE_PLUGIN_ROOT` 参照 **0/17**。**#1188 の同期後も不変** | 不可 |
| **1151** | OPEN | L3（+LH） | `settings.example.json:11` が今も `gh-pin-account.sh` を配線、`:7` のコメントと `gh-pin-account.sh:21` の既定値に上流個人名 | 不可 |
| **1162** | OPEN / STALE | L2 | 件数契約 `ta-33:25` / `ta-33:54` / `ta-57:624` が `-eq` のまま、**3 件とも実測値＝契約値で装填状態** | 不可 |
| **1165** | OPEN / **STALE** | L2 | TC-14 の 3 ファイル凍結（`ta-57:570`）・`[WARN]` 無音経路・`read_json` 不在すべて未着手。**本文の「触った PR は 0 本」を #1187 が反証** | 不可 |
| **1170** | OPEN / STALE | LH → L2 | `.codex/skills` の 4 skill が #1159 未追従（`CLAUDE_PLUGIN_ROOT}/rules/` が 0/4）・`ai-loop-cycle` が #982 未追従。**#956 の判断待ちで着手不可** | 不可 |
| **1177** | **PREMATURE CLOSE** | L2 | ガードは 87/87 で AC-1/2 充足。**AC-3（母集合反転）/ AC-4 / AC-5（timeout）が未達のまま `COMPLETED` で close** | — |
| **1178** | OPEN / STALE | L2 | TC-01 は依然 `grep -q "$_T70_MARKER"`（`:82`）。**#1187 の 3 群拡張は false green を悪化させた**（§6-1） | 不可 |
| **1180** | OPEN | L2（AC-4 は LH） | `ta-69` / `check-skill-name-collisions.py` は #1174 以降**一切変更なし**。8 AC 全滅。M-1 は 1 行で直るが残り 7 件 | 不可 |

### 表の読み方

- **close 推奨が「不可」でも、AI が今すぐ動かせるものはある**（§7）。close できないことと着手できないことは別。
- **分類に `/ STALE` が付くものは、着手前に本文を測り直さないと対象/対象外が反転する**（§5）。

## 2. CLOSE-NOW の詳細 — #1102

**唯一の CLOSE-NOW。** PR #1190（`684949e`、merged 2026-08-20T02:07:20Z）で `CLAUDE.md` の最新リリース節が v8.21.0 へ書き換えられ、`#1089` を「未適用」とする記述が消滅した。

| AC | 判定 | 根拠 |
|---|---|---|
| AC-1: 「#1089 が未解消」と読める記述が残っていない | **PASS** | `grep -c '#1089.*未適用'` → 0（陽性コントロール付き） |
| AC-2: タグと main の区別が明示 | **PASS（前提が消滅）** | **v8.21.0 タグ自体に #1089 の是正が入った**ため tag/main の乖離が無い。史実は `README.md:87` に保存 |
| AC-3: 存在しないファイルへの操作指示が残っていない | **PASS** | `apply-eh3-ho-always.sh` の hit 0 / flag は不在 |
| AC-4: README / README_en / hook-enforcement.md / CHANGELOG と矛盾しない | **PASS** | 全 hit が「是正済み」側で一致・`AGENTS.md` は hit 0 |
| AC-5: `sh tests/run-tests.sh` rc=0 | **PASS（CI 代理）** | PR #1190 の `statusCheckRollup` = ALL CHECKS NON-FAILING（markdownlint 含む） |

### close コメントにそのまま貼れる形

```markdown
`origin/main` = `684949eca274ce469ed7b41a43f08e4b384f96f2` で全 AC を実測し、**解消を確認したため close** します。
是正は PR #1190（`docs(release): CLAUDE.md の最新リリース節を v8.21.0 へ更新`）で入りました。

## AC-1: 「未適用」記述の消滅

    $ git show origin/main:CLAUDE.md | grep -c '#1089.*未適用'
    0     # rc=1

**空振り検査でないことの陽性コントロール**（同一パイプライン・存在するパターン）:

    $ git show origin/main:CLAUDE.md | grep -c 'v8.21.0'
    2     # rc=0

4 ファイル横断でも 0 件:

    $ git grep -n '未適用' origin/main -- CLAUDE.md AGENTS.md README.md README_en.md
    （出力なし / rc=1）

## AC-2: タグと main の区別

v8.21.0 **タグ自体に #1089 の是正が入った**ため、tag/main の乖離は解消しています。
タグの中身で確認（ancestry ではなく内容で判定）:

    $ git show v8.21.0:scripts/hooks/check-plan-hash.sh | grep -n '_override'
    94:_override=0
    ...
    104:  AGENTS.md|CLAUDE.md) _override=1 ;;
    106:if [ "$_override" = "1" ]; then

= HO 9 カテゴリが task_id 分岐より **前** で評価される（#1089 是正形）。
史実としての区別は `README.md:87` に保存されています:
「**EH-3 の HO 迂回（#1089）はタグ時点では未解消 / v8.21.0 で解消**」

## AC-3: 存在しないファイルへの操作指示

    $ git ls-tree origin/main tests/fixtures/ | grep -i 1089
    （出力なし / rc=1 = 不在）

    $ git show origin/main:CLAUDE.md | grep -c 'apply-eh3-ho-always'
    0

`CLAUDE.md:16` の現行文は「適用済みのため …flag は削除」という**事実の記述**で、
`apply-eh3-ho-always.sh --apply` の案内と flag 削除指示は除去済みです。

## AC-4: 他ドキュメントとの整合

    $ git grep -n '1089' origin/main -- AGENTS.md README.md README_en.md docs/ai/hook-enforcement.md
    README.md:81, README.md:87, README_en.md:81, README_en.md:87,
    docs/ai/hook-enforcement.md:199, :214, :252

いずれも「是正済み」側で一致（`hook-enforcement.md:199` = `#1089 是正済み・9043536`、
`:252` = `HO は #1089 是正済みのため保護は維持される`）。`AGENTS.md` は hit 0。

## AC-5: テスト

PR #1190 の `statusCheckRollup` = **ALL CHECKS NON-FAILING**（markdownlint 含む / merged 2026-08-20T02:07:20Z）。

**未解消の HO 正規化の穴は #1101 で別途追跡中**（本 issue とは別物・混同しないこと）。
```

### close 時に併記すべき残件（AC 外・情報として）

`CLAUDE.md` の現行文は **「HO block が `Edit|Write` 経路限定である」ことに触れていない**。`_reports/1102-1018-blocked-oneline-patch.md` 第 1 部が推奨した記述方針 3 の一部が入っていない。これは **#1104 の scope**（Bash 経路のガード不在）なので #1102 の AC ではないが、close コメントで #1104 へのポインタを残すのが妥当。

## 3. CLOSE-AFTER-1 の詳細 — #1018

**あと 1 手**: `docs/working/templates/plan.md` の見出しを抽出器の契約名へ揃える。

| 項目 | 内容 |
|---|---|
| **誰が** | **AI 可**（下記セッション条件付き）。従来「Human-owned」とされていたが、これは **`PLANGATE_HOOK_TASK` 未設定セッションに限った話** |
| **何を** | `## Files / Interfaces` → `## Files / Components to Touch` へ変更 + `Verification Automation:` 行の追加 + 見出し名が契約であることの注記 |
| **どのファイルに** | `docs/working/templates/plan.md` |
| **何行** | **見出しは `:73` の 1 行**（`:221` / `:255` は本文中の言及で、追従は任意）+ `Verification Automation:` 行の新設。patch 設計では **約 +7 / −3 行** |
| **patch の所在** | `docs/working/_reports/1102-1018-blocked-oneline-patch.md` **第 2 部**（diff・検証手順・注意点まで記載済み） |

### 実測

```
$ git show origin/main:docs/working/templates/plan.md | grep -n '^## ' | grep Files
73:## Files / Interfaces

$ git show origin/main:scripts/ai-loop/plan_package.py | grep -n 'Files / Components to Touch'
181:    """plan.md 本文の `## Files / Components to Touch` からパスを抽出する純関数。
194:    section = _extract_section(plan_text, "Files / Components to Touch")
224:            ["derive: `## Files / Components to Touch` からパスを抽出できない"])
```

**issue 本文の行番号 `171/184/214` は stale**（+10 行シフトして `181/194/224`）。

**抽出器側は正常**（陽性コントロール）: scratchpad に `git show origin/main:` で取り出して実行したところ、`_extract_section(t, 'Files / Interfaces')` は表本体を返し、`'Files / Components to Touch'` は `None` を返した。**見出し名だけが原因**と確定。

### ⚠️ 「1 手」と言い切れない留保が 2 点ある（実測に基づく）

1. **`Verification Automation:` 行がテンプレに 0 件**（`grep -c 'Verification Automation'` → 0）。`plan_package.py:226-235` がこれを必須としているため、**見出しを直しても derive はもう一段 fail-closed する**。したがって厳密には「見出し + `Verification Automation:` 行」の 2 要素を同一 patch で入れる必要がある（patch 設計は両方を含む）。
2. **basename が `plan.md` のため EH-3 が発火する**。ただし実測の結果、**basename ガードは `task_id` が空の分岐にのみ置かれている**:

```
$ git show origin/main:scripts/hooks/check-plan-hash.sh | sed -n '119,131p'
if [ -z "$task_id" ]; then
  ...
  case "$_tf_lc" in
    */plan.md|plan.md)
      ... exit 2
```

→ **`PLANGATE_HOOK_TASK=TASK-XXXX` を起動時に設定したセッションでは SKIP (exit 0) となり AI が書ける。**
`_reports/1102-1018-blocked-oneline-patch.md` の「#1018 は AI が構造的に到達できない / Human-owned」という記述は、**「no-TASK セッションでは到達不能」へ書き換えるべき**（責務表の誤り）。

### 互換リスク（実測）

`Files / Interfaces` を使っている実 plan は **3 本**: `docs/working/TASK-0809/plan.md` / `TASK-0921/plan.md` / `TASK-1005/plan.md`。いずれも完了済み PBI なので、テンプレ変更が既存 plan を壊すことはない。

## 4. PARTIAL / OPEN の残 AC

### 4-0. #1177 — PREMATURE CLOSE（close 済だが AC-3/4/5 未達）

**`stateReason=COMPLETED` で閉じられているが、7 AC 中 3 件が未充足。**

| AC | 判定 | 実測 |
|---|---|---|
| AC-1 `scripts/ai-loop/*.py` 30 本にガード | **PASS** | 母集合 30 / ガード 30（集合一致） |
| AC-2 plugin ミラー追従 | **PASS**（件数は 28 でなく **30**） | blob SHA + basename で突合 → **30/30 byte 同一** |
| **AC-3 母集合を `git ls-files -- '*.py'` − allowlist へ反転** | **FAIL** | `ta-70:65` `_T70_DIRS='scripts scripts/ai-loop plugin/plangate/skills/ai-loop-cycle/scripts'`、`:79 / :92 / :104 / :121` はいずれも 3 glob をハードコード列挙 |
| **AC-4 変異注入で AC-3 を実証** | **FAIL** | AC-3 未着手のため成立し得ない |
| **AC-5 `ta-70` に timeout** | **FAIL** | `git grep -n 'timeout' origin/main -- tests/extras/ta-70-py-sh-misinvocation-guard.sh` → 出力なし・rc=1（陽性コントロール: 同ファイルへの `grep -c 'TC-0'` → 35） |
| AC-6 `__doc__` 保全 | **PASS（静的）** | `git grep -l '^__doc__ = """' origin/main -- 'scripts/ai-loop/*.py' \| wc -l` → 30/30。`compileall` 自体は `__pycache__` を書くため未実行 |
| AC-7 絶対件数を契約値にしない | **PASS** | `ta-70:84` は `-ge 20` の floor のみ。`-eq` は 0 件 |

**ガード適用の全数（3 群 = 87/87）**:

```
$ git ls-tree -r origin/main --name-only -- scripts | grep '\.py$' | grep -c '^scripts/[^/]*\.py$'   → 27
$ git grep -l 'PG-SH-GUARD' origin/main -- 'scripts/*.py' | grep -c '^origin/main:scripts/[^/]*\.py$' → 27
$ git ls-tree -r origin/main --name-only -- scripts/ai-loop | grep -c '\.py$'                          → 30
$ git grep -l 'PG-SH-GUARD' origin/main -- 'scripts/ai-loop/*.py' | wc -l                              → 30
$ git ls-tree -r origin/main --name-only -- plugin/plangate/skills/ai-loop-cycle/scripts | grep -c '\.py$' → 30
$ git grep -l 'PG-SH-GUARD' origin/main -- 'plugin/plangate/skills/ai-loop-cycle/scripts/*.py' | wc -l  → 30
```

**AC-3 未実施の実害（ファイル名の集合）**: 全 `.py` から 3 走査群を差し引くと 13 件。issue の Out of scope allowlist は `docs/working/**/evidence/**` 10 件 + `fuzz/*.py` 1 件 = 11 件。**差分 2 件が allowlist にも母集合にも属していない**:

```
scripts/parsers/__init__.py
scripts/parsers/codex_log_parser.py

$ git grep -l 'PG-SH-GUARD' origin/main -- 'scripts/parsers/*.py'
（出力なし・rc=1）   ※陽性コントロール: 同パターンで scripts/ai-loop/*.py は 30 件ヒット
```

**緩和材料（実測・推測ではない）**: `codex_log_parser.py` の冒頭 40 行にバッククォート / `$(` は 0 件、shebang も無い。**現時点で即時のコマンド置換 payload は無い。** ただし「母集合の外にある」構造欠陥は残り、将来の追記で無防備に発火しうる。

> **本 issue 自身の教訓（「PR の射程が issue の欠陥クラスを覆っているかを機械検出できない」）が、本 issue の close 判定でそのまま再発している。**

**残作業の受け皿**（Human 判断）: (a) #1177 を reopen / (b) #1178 に AC-3/4/5 を吸収 / (c) 新規 issue。**§6-2 の理由から (b) を推奨。**

### 4-1. #1011 — PARTIAL（V3-06 のみ解消）

**済**: V3-06（`ta-26:325-335` が rc ではなく standalone サマリ行 `grep -q 'TA-26 standalone: .* 0 failed'` を見る形に変更済。コメントに是正理由まで明記）／V3-02 は「安全側＝過剰 block に倒れるため許容 / #970 Non-goal」と `:198-200` に**意図的受容として明記**。

**残 AC**:
1. **V3-04**: `_mass_delete_blocked`（`sync-plugin-plangate.sh:57` の `[ "$3" -gt "$2" ] || return 1`）に数値検証を追加し、不正入力時は WARN + `guard_fired=1` + blocked 側へ倒す
2. **V3-05**: `PLANGATE_ALLOW_MASS_DELETE`（`:58`）をラベル prefix 一致で受ける（`=1` の全経路互換は維持）。現状 4 箇所（`:58 / :61 / :64 / :607`）すべて prefix 一致なし
3. 上記 2 件の**変異注入 TC**（call site を壊す形で kill を実証）
4. **V3-02 の方向決定（Human）**: 受容のまま close するか揃えるか ← **#970 / #1009 との整合が先**

**実測**: `git diff a2a02b9 origin/main -- scripts/sync-plugin-plangate.sh` → guard 関数（`:56-67`）/ 経路1（`:175-231`）に一切変更なし。

### 4-2. #1057 — PARTIAL（症状 3 と提案 4 が解消）

**済**:
- **症状 3 の誤導記述**: `plugin/plangate/skills/ai-loop-cycle/SKILL.md:88` が「`bin/plangate` に `ai-loop` サブコマンドは存在しない — `plangate ai-loop run …` は失敗する。CLI 入口を設けるか否かは issue #982 で未決」と明記（`43fb05e` / PR #1160）
- **提案 4**: `plugin/plangate/README.md:36` に「Plugin 単体導入時は PATH に無いため、リポジトリ clone と PATH への追加が必要」+ 一時的追加コマンドを明記（#863 / PR #1182・#1183）

**残**:
1. **症状 2（提案 3）= L1・最大の実害**: `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` 手順が正本 **31 ファイル**（`.agents/skills/` 19 / `.claude/skills/` 7 / `docs/ai/ai-loop/` 3 / `docs/workflows/ai-loop/` 2）に残存。配布側 24 本は `sync-plugin-plangate.sh` が再生成するため**直接編集しない**。**HO 対象パスは 1 本も含まれない**
2. **症状 1 = LH**: 「`bin/plangate` を `plugin/plangate/bin/` として配布するか、clone+PATH 前提を維持するか」。現状は後者が README:36 に明文化済なので、「提案 4 で解決」と扱うか「提案 1 を採る」かの二択
3. **症状 3 = #982 へ委譲済**（#982 は OPEN）

**実測**: `plugin/plangate/` の第 1 階層は `.claude-plugin / .codex-plugin / agents / assets / commands / hooks / README.md / rules / scripts / skills` の 10 件。**`bin` なし。**

### 4-3. #1081 — PARTIAL（Slice 2 完了・Slice 1 未着手）

**済（Slice 2）**: frontmatter quote が **4 root すべて**で完了（`.claude` / `.agents` / `.codex` / `plugin` の `plangate-setup/SKILL.md` が `description: "…"`）。`claude plugin validate --strict` の **error = 0**（warning 7 件はいずれも frontmatter 不在の `agents/README.md` + `commands/*.md` 6 本）。再発防止に `tests/extras/ta-64-skill-frontmatter.sh` が main に存在。

**残 AC（Slice 1 が丸ごと）**:
1. **AC-1**: `README` が Skills 一覧に露出（`Skills (45)` の**先頭**が `README`）
2. **AC-2**: 同名衝突 3 件（`codex-mvp-split` / `plangate-setup` / `working-context`）が各 2 回ずつ出る。`plugin/plangate/commands/*.md` 6 件と `plugin/plangate/skills/*/SKILL.md` 39 件で **39 + 6 = 45**（報告値と一致）
3. **AC-3**: description が見出し流用（本セッションの skill 一覧に `- ai-dev-workflow: /ai-dev-workflow` `- README: Slash Commands` として実在）
4. **AC-4**: slash 起動の非回帰実測
5. **AC-6**: `sync --dry-run` = `no changes`（**未確認** — 同期スクリプトは実行禁止）

**未決（Human）**: 案 (a) rename/remove / (b) 3 名の一本化 / (c) `plugin.json` に `commands` 宣言。**U-2（`commands` 宣言で Skills 数から分離されるか）は未検証で、成立すれば最安**。U-1（衝突時の勝者）も未検証。

### 4-4. #1093 — PARTIAL（計画は承認済・実装ゼロ）

**7 AC すべて FAIL。** `check_pending_applies()` は issue の記述と**バイト同一**:

```
$ git show origin/main:scripts/release-prep.sh | grep -n 'dry-run'
55:    out="$(sh "$f" --dry-run 2>/dev/null || true)"
57:      *"[dry-run]"*) pending="$pending $(basename "$f")" ;;
72:  out="$(sh "$ROOT/scripts/sync-plugin-installed.sh" --dry-run 2>/dev/null || true)"
```

名指しされた exemplar は角括弧付きリテラルを出さない:

```
$ git show origin/main:scripts/apply-eh3-ho-always.sh | grep -n 'dry-run'
272:    print("[apply-eh3-ho-always] dry-run — 何も書き込んでいない。適用は --apply（Human-owned）")
```

**「PARTIAL」とした理由**: 計画が C-3 承認済で、後半スライスが **#1114（OPEN）** へ正式分割されている（`TASK-1093/status.md`: `2026-08-18 07:07 | C-3 裁定（Human）| 案 B: 2 分割`）。AI 側の残作業は実装のみ。

**残 AC**: AC-1〜AC-6（`check_pending_applies()` の exit code 契約化 + `check_plugin_cache_sync` を `run_checks()` から外す + 新規 `tests/extras/ta-NN-*.sh`）/ AC-7（baseline 再測定）。

### 4-5. #1101 — PARTIAL（patch 設計完了・適用待ち）

**4 変換クラスすべて再現。** 正規化は `./` と `$REPO_ROOT/` 除去のみ（`check-plan-hash.sh:85-90`）で、`..` / 大小文字 / 末尾空白は未処理。`_override` case ブロック（`:95-105`）の逐語レプリカを repo 外で実行:

```
[bin/plangate]          override=1
[bin/../bin/plangate]   override=0   ← 迂回
[CLAUDE.MD]             override=0   ← 迂回
[CLAUDE.md ]            override=0   ← 迂回
[docs/../CLAUDE.md]     override=0   ← 迂回
```

> hook 本体を直接実行しなかった理由: `:29-31` の `log_event()` が `$AUDIT_LOG` へ `>>` 追記する（= repo への書き込み）。case ブロックの逐語レプリカは glob 意味論として厳密に等価。

**残**: `_reports/1101-normalization-patch.md`（1046 行・RiverReview 7 巡で rev9 収束）の適用（**Human-owned / HO パス**、約 +139 行）+ `ta-65` TC-07 の KNOWN-GAP 固定の反転（約 20 行・非 HO）。**AI 側の設計作業は完了。**

### 4-6. #1178 — OPEN（0/6 AC）

| AC | 判定 | 現在の行番号 |
|---|---|---|
| AC-1 TC-01 を marker 文字列一致 → **構造判定**へ | **FAIL** | `:82` `grep -q "$_T70_MARKER" "$_t70_f"` — 存在のみ |
| AC-2 TC-04 実走ゲートを連言へ | **FAIL（部分前進）** | `:117` に `_t70_emptydir` が #1187 で追加。**TC-02 の `_t70_late` は連言に入っていない**、構造チェックも無い |
| AC-3 診断照合をガード固有の一意トークンへ | **FAIL** | `:127` は依然 `grep -q 'python3'`。**走査対象 87/87 がファイル本体に `python3` を含む** = 受理面が母集合全体 |
| AC-4 TC-02 / TC-03 の vacuous PASS を塞ぐ | **FAIL** | `:96` / `:108` はどちらも単独条件のまま |
| AC-5 `sh` 起動に timeout | **FAIL** | `timeout` の hit 0（陽性コントロール付き）。`:125` に上限なし |
| AC-6 「marker のみ・guard 実体なし」変異で SURVIVE を先に示す | **FAIL** | #1187 が記録する変異は「guard を外す（marker ごと除去）」「dir を隠す」の 2 種のみ |

**MN の状態**: MN-1（`__pycache__` 汚染を TC-05 が検出しない）未修正 / MN-2（`:198 rm -rf` → `:200 finalize` の順・`:146` で `register_cleanup` 済＝冗長。1 行削除で適合）未修正 / MN-3（`__doc__` 凍結）解決済。

### 4-7. #1180 — OPEN（0/8 AC・完全な未着手）

`git log --oneline origin/main -8 -- tests/extras/ta-69-distribution-checks.sh scripts/check-skill-name-collisions.py` → 最新は `8e7ea55`（#1174）。**#1183〜#1190 の 10 マージは本 issue の対象ファイルを一切触っていない。**

| AC | 判定 | 実測 |
|---|---|---|
| AC-1 TC-C6 fixture を `plugin/plangate/skills` へ | **FAIL** | `:204` / `:216` / **`:229`（TC-C6）** が `plugin/pa/skills` のまま。**issue の行番号は現 main でも正確** |
| AC-2 `--selftest` を `tests/extras/` から起動 | **FAIL** | `check-skill-name-collisions.py --selftest` の呼び出しは **docs と自身の docstring のみ**。テスト起動は 0 件（陽性コントロール: `ta-64-skill-frontmatter.sh:72` が `--selftest` を起動している別スクリプトの例） |
| AC-3 TC-C12 を `_t69_assert_defs` で包む | **FAIL** | C9/C3/C8/C4/C5/C6/C7/C10/C11 は包まれるが **TC-C12（`:305-311`）だけ未包含** |
| AC-4 ミラー判定を provenance ベースへ | **FAIL** | `:113 DEFAULT_MIRROR_PLUGINS = frozenset({"plangate"})` / `:169 return plugin_name in mirror_plugins`。`provenance` / `plugin.json` は 0 hit |
| AC-5 `doctor` から `--mirror-plugin` へ到達 | **FAIL** | `doctor_check.py` の `subprocess.run` は引数固定・env フォールバックなし |
| AC-6 マッチ 0 件時の警告 | **FAIL** | 未マッチ検出も警告出力も無い |
| AC-7 docs に REPO_ROOT 常時走査を明記 | **FAIL** | `docs/ai/skill-collision-detection.md` に `REPO_ROOT` の hit 0（陽性コントロール: 同ファイルは 305 行実在、`mirror-plugin` は 4 hit） |
| AC-8 すべて SURVIVE を先に示す | **FAIL** | AC-1〜7 未着手 |

**M-1 は厳密に 1 行**（`:229` の `plugin/pa/skills` → `plugin/plangate/skills`）だが、**残り 7 AC があるため CLOSE-AFTER-1 ではない**。issue 本文自身が「M-1 は 1 行なので先行して切り出す価値がある」と述べており、**AC-1 + AC-2 を先行 PR に切り出すのが妥当**（AC-2 は M-1 で失われた条件④を pin する唯一の資産）。

### 4-8. その他 OPEN の残 AC（要点のみ）

- **#1021**: AC-1/2/3/5 が FAIL。`ta-09-metrics.sh:8` の `$0` root・`:14-23` の cleanup 片手落ち・`:186-198` の fixture here-doc すべて無変更（**issue の行番号は今も正確**）。`PG_HARNESS_SOURCED` は ta-07/08/09 で 0 件（陽性コントロール: `ta-45-c3-mode-config.sh:3` にはある）。最終変更は `4d1f2ff`（2026-06-10）で起票より前
- **#1044**: bootstrap（`ta-46:9-25`）の top-level `return 0`（`:22`）が原因。4 シェル実測は起票時と同値
- **#1086**: 6 AC 全 FAIL。`.codex/skills` = 39 SKILL.md / 120 ファイル tracked、`.agents/skills` と**名前集合が完全一致**。`.gitignore` は `.codex/skills/.system/` のみ除外。`ta-69:506` は 4 root の frontmatter parity を見るだけで二重 root 検出ではない
- **#1104**: AC-7 のみ PASS。`Bash` matcher を持つ hook は `check-delegation-commit-boundary.sh` / `check-approval-token-write.sh` / `check-git-destructive.sh` の 3 本で、いずれも `plan.md` / HO を見ない。`check-plan-hash.sh` は `.tool_input.file_path` のみ参照（`.tool_input.command` は 0 hit）。再利用候補 `_strip_nonwrite_redirects`（`check-approval-token-write.sh:228` 定義 / `:321` 適用）は実在
- **#1105**: 5 AC すべて未達。`cmd_approve`（`bin/plangate:2347`）本体に `review|c1|c2|mtime|newer|stale|fresh|draft` の hit 0
- **#1144**: 10 AC すべて未達。配布 scripts は `.gitkeep` + `install-plangate-skills.sh` の 2 件のみ。`settings.example.json` の `timeout` = 0 に対し `.codex/hooks.json` は 5（非対称が継続）。`install.sh:105` は `for dir in agents skills commands rules` の 4 dir のまま
- **#1151**: `settings.example.json` の SessionStart ブロックは **`:5-15`**（`:7` のコメントに `s977043`、`:11` に配線）。`gh-pin-account.sh:21` は `DESIRED_USER=${PLANGATE_GH_USER:-s977043}`。**他 10 配線に上流固有前提が無いことを全数確認したが、repo に記録されていない**（AC-3 の成果物が無い）
- **#1162**: 件数契約 4 箇所すべて未是正、**3 件とも実測値＝契約値でちょうど装填状態**（`.claude/agents/*.md` = 17 / `.codex/agents/*.toml` = 17 / `test_delivery.py` の `def test_` = 57）。`read_json` は 0 hit（陽性コントロール: `json.loads` は 16 ファイルで hit）
- **#1165**: 7 AC すべて未達。`UNVERIFIED` の hit 0（陽性コントロール: 同ファイルの `WARN` は `:603-606` の 4 行）。`[WARN]` 経路は `t57_pass` / `t57_fail` のどちらも呼ばず、**pass/fail 集計に現れない**
- **#1170**: 本文の 2 主張はいずれも実測どおり（`.codex` の `CLAUDE_PLUGIN_ROOT}/rules/` = 0/4、`ai-loop-cycle` の #982 記述 = 0）。ただし**本 issue は body で「v8.21.0 では是正しない / #956 の判断後に決める」と明示的に deferred 宣言**しており、`working-context.md` の **BLOCKED / Deferred ゲート**に該当（`blocker`=`.codex/skills` の二重 root 方針、`owner`=human、`unblock_condition`=#956 の (a)/(b) 判断確定）

## 5. STALE の是正案

### 5-1. #1165 — 本文の中核主張を #1187 が反証した（**最重要**）

| 本文 | 現 main |
|---|---|
| 「TC-14 導入コミット `ff46761`（2026-07-31）以降、この 3 ファイルを触った PR は **0 本**」 | **誤り。#1187 が凍結対象 3 ファイルすべてを変更してマージ済** |

```
$ git show ffed553 --stat | grep -E 'c3_contract|c3prime_verify|delivery\.py'
 .../skills/ai-loop-cycle/scripts/c3_contract.py    | 15 ++++-
 .../skills/ai-loop-cycle/scripts/c3prime_verify.py | 15 ++++-
 .../skills/ai-loop-cycle/scripts/delivery.py       | 15 ++++-
 scripts/ai-loop/c3_contract.py                     | 15 ++++-
 scripts/ai-loop/c3prime_verify.py                  | 15 ++++-
 scripts/ai-loop/delivery.py                        | 15 ++++-
```

**是正案**: 「**#1187 が凍結対象 3 ファイルを変更したが、CI では TC-14 が `[WARN]` 経路へ落ちたため検出されずマージされた**」へ書き換える。

> **これは B-2（`[WARN]` false green）の実害が発生済みであることの一次証跡であり、#1165 の優先度を上げる材料になる。** 「一度も正当な変更と衝突しないまま沈黙して効いてきた」という本文の評価は、**実際には「衝突したが沈黙して素通りさせた」**が正しい。

**行番号アンカーの是正**（`8e7ea55`/#1185 と #1187 が周辺を動かした）: `:568` → **`:570`** / `:608-612` → **`:610-614`** / `:600-605` → **`:603-606`** / `c3_contract.py:7-14` の docstring → **`:13-26`**（#1187 が先頭に PG-SH-GUARD 10 行を挿入し `__doc__ = """…"""` 形式へ）/ `sync-plugin-plangate.sh:428`・`:440` → **`:431`・`:443`**（集合は 30 本へ拡大）。

### 5-2. #1178 — 行番号が全滅・母集合の根拠が変わった

**行番号**（#1187 が `ta-70` を 66 行書き換え）: `:62`（TC-01 grep）→ **`:82`** / `:97`（TC-04 ゲート）→ **`:117`** / `:106`（`sh` 起動）→ **`:125`** / `:107`（`python3` 判定）→ **`:127`**。

**「`python3` の語を含む `scripts/*.py` は 56 件」→ 母集合が変わったため無効。** 現在は **走査対象 87 件のうち 87 件（100%）が `python3` を含む**。**AC-3 の根拠はむしろ強化された**（診断判定が母集合全体を無条件に受理する）。

**基点**: `2447bf8` → `684949e`。

### 5-3. #1180 — STALE 要素なし

issue 本文の実測（行番号 `171/192/204/216/229`、`check-skill-name-collisions.py:113` / `:169`）は**すべて現 main でそのまま再現**した。**この issue は測定が正確に書かれている**（他 issue の手本になる）。

### 5-4. #1170 — 「他 3 root はいずれも 1」が 2 skill について誤り

```
$ git ls-tree -r --name-only origin/main | grep -E '(^|/)skills/(design-gate|intent-classifier|plan-review-gate|skill-policy-router)/SKILL.md$'
.agents/skills/{design-gate,intent-classifier,plan-review-gate,skill-policy-router}/SKILL.md
.claude/skills/{intent-classifier,skill-policy-router}/SKILL.md      ← design-gate / plan-review-gate が無い
.codex/skills/{design-gate,intent-classifier,plan-review-gate,skill-policy-router}/SKILL.md
plugin/plangate/skills/{design-gate,intent-classifier,plan-review-gate,skill-policy-router}/SKILL.md
```

**是正案**: 「`design-gate` / `plan-review-gate` は `.claude` に存在せず、`.agents` と `plugin` の 2 root が 1、`.codex` が 0」。
**射程**: 系統ごとの是正では追いつかない（新しい系統が入るたび再発する）。**タイトルを「`.codex/skills` 全体が再生成されていない」へ寄せる**のが妥当。

### 5-5. #1086 — 2 つの実測値が陳腐化

| 本文 | 現 main |
|---|---|
| `.codex/skills` = **38** / 差分は `subagent-delegation-brief` のみ | **39 / 39・名前集合は完全一致**（PR #1084 で解消） |
| `differing=2`（`ai-loop-cycle` / `plan-review-gate`） | **39 中 32 が乖離** |

**drift の性質（重要）**: `.agents/skills` は **#954/#1158 の波（構造上必ず空振りする plugin root 段の除去）を受けたが `.codex/skills` は受けていない**。つまり stale ミラーは **#954 が意図して削除した参照解決手順を今も配っている**。これは本文の主張②（同名衝突の勝者が不定）を**実害として強化する**材料。

**是正案**: 件数を契約値にせず「`.agents/skills` ⇄ `.codex/skills` の blob 比較で drift 0」という**相対 AC** へ書き換える。

### 5-6. #1093 — AC-1 の exemplar が用途反転した

本文の「`apply-eh3-ho-always.sh` … 適用するまで HO ガードは無効」は **#1089 が v8.21.0 で解消済のため誤り**。同スクリプトは**既に適用済**なので、pending に**出ないのが正**。

**是正案**: AC-1（偽陰性）の exemplar を**別の真に未適用なスクリプトへ差し替え**、`apply-eh3-ho-always.sh` は **AC-2 の負の対照 fixture** として再利用する。設計結論（stdout 文字列一致 → exit code 契約）は**この staleness の影響を受けない**。

### 5-7. #1081 — Out of scope の 1 主張が反証された

本文は `agents/README.md` / `commands/*.md` の frontmatter 欠落を「README は定義体ではない = **validator-only**」としているが、`claude plugin details` は `Agents (18) …, README, …` を返し、本セッションの agent 一覧にも `plangate:README: Agent from plangate plugin` が実在する。

**是正案**: 「`agents/README.md` も Agents 一覧に露出しており、`commands/README.md` と同じクラスの junk である（AC-1 の対象に含める）」。

### 5-8. #1021 / #1044 — 過小 scope（本文の母数が実態と合わない）

- **#1021**: 「規約 8 無ガードは 13 本」— 前回棚卸しの全数照合では **40 本**（`FIXTURES_DIR` に触れる母集団に限った数と読める）。**Out of scope の規模見積りの更新が要る**。加えて `_reports/1021-ta09-isolation-patch.md` は**実監査ログ汚染**を別の実害として挙げており、**AC に「実監査ログに fixture レコードを残さない」を追加すべき**
- **#1044**: 「層 A 12 本 + ta-61 に複製」→ 現在の blast radius は **21 本**（`git grep -l '_pg_extra_helper' origin/main -- tests/extras/` → 21）。**修正は 21 ファイルへの同一スニペット適用**になる

## 6. 依存グラフ（双方向で数える）

### 6-1. 🔴 #1178 の verdict — #1187 の「3 群拡張」は false green を**悪化させた**

効果を 2 つに分離して読む必要がある。

**(a) `_t70_emptydir`（空 glob 検出）= 真の改善だが射程が狭い**

`ta-70:65-74` が 3 群それぞれの glob 展開件数を数え、`:84` / `:117` の連言に入れている。「glob が丸ごと空振りして母集合 0 でも緑」という**別クラス**の false green を塞ぐ実在の改善。

ただし **`_T70_DIRS` は `_t70_emptydir` の算出と `:85` の PASS メッセージにしか使われていない**。TC-01 / TC-02 / TC-03 / TC-04 は `:79` / `:92` / `:104` / `:121` で**同じ 3 glob を独立にハードコード再列挙**している。つまり:

- `_T70_DIRS` から 1 行消しても**母集合は縮まない**（その群の空振り検査だけが黙って無効化される）
- **4 箇所の重複が drift しうる**（新しい群を TC-01 に足して `_T70_DIRS` に足し忘れる、等）

そして **#1178 の欠陥クラス（marker あり・guard 実体なし）に対して `_t70_emptydir` は何の効果も無い。**

**(b) 母集合 27 → 87 への拡張 = blast radius を 3.2 倍にした（悪化）**

- TC-01 の**成立確率**そのものは、この欠陥クラスに対しては**中立**。TC-01 は母集合上の全称限量なので、母集合を増やすことは「marker が**無い**」欠陥には厳格化になる。しかし「**marker は有るが guard 実体が無い**」欠陥に対しては、母集合の大小に関わらず TC-01 は必ず PASS する
- **変わったのは帰結の重さ。** TC-01 は単なる弱い assert ではなく、`ta-70:115-117` のコメントが明示するとおり **「実ファイルを本当に `sh` 起動する破壊的テスト（TC-04）」の安全前提条件**である。母集合が 27 → 87 になったことで、**この不十分なゲートの背後で実走される実ファイルが 3.2 倍**になった
- **新たに実走対象へ入った 60 件には、`gh` / `git` を実行する唯一の境界 `scripts/ai-loop/gh_exec.py` とその配布ミラーが含まれる**。#1187 のコミットメッセージ自身が「stub サンドボックスで 30 件を `sh` 起動: 修正前 `gh` 12 回 + `git` 3 回発火（うち `gh_exec.py` 単体で 6 回）」と記録している。**false green 成立時の被害が「`.codex/skills` が書き換わる」から「`gh pr merge` / `gh pr review --approve` に到達しうる（NO MERGE BY AI の迂回）」へ格上げされた**
- **ミラー群が二重実行を生む**。`scripts/ai-loop/*.py` と配布ミラーは blob SHA まで一致（30/30）。`scripts/ai-loop/` に marker だけ持つ未ガードファイルを 1 本足すと、sync により**同一欠陥が 2 パスから 2 回 `sh` 実行される**
- 診断判定も薄まっていない: AC-3 の受理面は 27/27 → **87/87 が `python3` を含む**ので、**TC-04 は未ガードファイルをほぼ確実に PASS 判定する**
- **timeout が無い**（AC-5）。87 ファイルを `sh` 起動する経路に上限が無いので、暴走は block ではなく**ハング**になる

> **総合: 母集合拡張は「検査が守れていない領域」を減らした一方で、「検査が守れていないと信じて破壊的実行する領域」を 3 倍にし、その中に merge 境界を入れた。#1178 の観点では悪化。AC-1（構造判定）と AC-5（timeout）の優先度は #1187 のマージによって上がった。**

### 6-2. `tests/extras/ta-70-*.sh` に 3 issue の残作業が集中している

```
#1177 AC-3（母集合反転）/ AC-4（変異）/ AC-5（timeout）  ─┐
#1178 AC-1〜AC-6                                        ─┴─→ 同一ファイル・同一 TC-01 の書き換え
```

- **必ず 1 本の PR に束ねること。** 別々に進めると確実に conflict する
- **#1177 AC-3 を入れると `scripts/parsers/{__init__,codex_log_parser}.py` 2 本が母集合に入り、guard 未適用のため TC-01 が即 FAIL する** → 母集合反転とガード適用（または明示 allowlist 化）を**同一 PR に含めることが必須**
- **#1178 AC-5 と #1177 AC-5 は同一要求**（timeout）。重複しているので 1 回で満たせる
- **逆向き**: #1178 を解いても #1177 の AC-3 は自動では満たされない（構造判定と母集合反転は独立の変更）

### 6-3. Human 判断待ちのクラスタ（判断 1 つで複数 issue が動く）

```
【クラスタ A】.codex/skills の去就 ── 担当範囲で最大のボトルネック
  #1086 「.codex/skills 120 ファイルを untrack するか（案 A′）」  ← Human 判断 H-1（不可逆）
    ├─ 決まらないと ─→ #1170（body が明示的に「#956 の判断後」と deferred 宣言・完全ブロック）
    └─ 決まらないと ─→ #956（範囲外だが #1086 の前提条件）
  ※ 逆向き: #956 の drift 判断が付かないと #1086 の untrack が安全でない
     （#1086 の investigation.md は drift を 2 件と仮定しているが実測 32 件。
       H-7 の scope が調査時の想定より遥かに大きい → H-1 を答える前に再 scope が要る）

【クラスタ B】ta-70 の検査契約
  #1177 AC-3/4/5 ⇄ #1178 AC-1〜6   ← 双方向（同一 TC を書き換える）
    └─ 先行条件 ─→ scripts/parsers/*.py 2 本の扱い（ガード適用 or allowlist 明記）
  ※ Human 判断: #1177 を reopen / #1178 へ AC 吸収 / 新規 issue の 3 択

【クラスタ C】ta-57 の凍結契約
  #1165 B-1（TC-14 の射程限定）
    ├─ 従属 ─→ #1165 B-3（read_json 集約。c3_contract.py が凍結対象なので B-1 が先）
    └─ 同一ファイル ─→ #1162 AC-03（ta-57:624 の -eq 57）
  ※ 逆向き: #1162 を先に入れると ta-57 に触るため #1165 と conflict
     → 1 PR に束ねるか #1162 を先に完了させる
  ※ #1187 が凍結対象 3 ファイルを素通りでマージした事実が B-2 の実害証跡

【クラスタ D】settings.example.json を共有する 3 issue
  #1151（SessionStart の gh-pin-account 配線削除）  ← 最小
  #1144（hooks 配布 + matcher 定義）               ← 最大
  #1104（Bash matcher の追加）
  ※ 3 件とも同一ファイルを触る。#1151 → #1104 → #1144 の順が patch 最小
  ※ 逆向き: #1144 を先に入れると #1151 / #1104 の patch を作り直しになる

【クラスタ E】HO パスへの patch 適用（判断ではなく **適用** のみ待ち）
  #1101 patch 設計 1046 行が main 着地済（rev9）→ Human 適用で AI 側完了
  #1104 patch 設計あり（_reports/1104-bash-route-guard-patch.md）
  #1144 patch 設計あり（_reports/1144-{plugin-packaging,root-resolution}-patch.md）
```

### 6-4. 単独で閉じられるもの（依存なし）

**#1018** / **#1021** / **#1044**（ただし #921 の裁定が固まる前に着手すると 21 本を二度書き換える）/ **#1105** / **#1180**（#1178 / #1177 とファイルが重ならない）/ **#1093**（実装側は fixture ベースで先行可能。実スクリプト証明のみ #1114 従属）

## 7. L1 の着手順（費用対効果順）

**選定基準**: (1) Human 判断を待たない (2) 他 issue のブロッカーを外す (3) 変更範囲が閉じている (4) 実害の大きさ。

### Tier 0 — 今すぐ close できる（作業ゼロ）

| 順 | issue | 作業 | 理由 |
|---:|---|---|---|
| **0** | **#1102** | **close コメントを貼るだけ**（§2 に貼り付け可能な形で用意） | **AC 全充足。backlog が確実に 1 件減る唯一の項目** |

### Tier 1 — `.md` のみ・Human 判断ゼロ

| 順 | issue | 作業 | なぜこの順か |
|---:|---|---|---|
| 1 | **#1018** | `docs/working/templates/plan.md` の見出し + `Verification Automation:` 行（+7/−3 行） | **正式入口 `derive_loopspec()` が「テンプレを使うと必ず落ちる」状態の解消**。patch は main に同梱済。1 ファイル・依存なし。**要 `PLANGATE_HOOK_TASK` セッション**（basename が `plan.md` のため） |
| 2 | **#1057** 症状 2 | 正本 31 ファイルの `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` 手順を `installed_plugins.json` 経由へ | **HO 対象パスを 1 本も含まない**（`.claude/skills/` は override パターン外）。配布側 24 本は sync が再生成するので触らない。導入先で常に失敗する手順の除去 |
| 3 | **#1105** AC-3/AC-4 | 解決方式 3 案の比較表 + 推奨を `docs/ai/` へ | issue 自身が「解決方式は C-3 で人間が決める」と scope を切っているので、**AI が案を書くこと自体が前進**。AC-2（`bin/plangate:1028`）は L3 で分離 |
| 4 | **#1151** AC-3 | 「他 10 配線に上流固有前提が無い」ことの全数確認結果を repo に記録 | 本レポートで測定済み（`:7` のコメントと `:11` の配線の 1 箇所のみ）。**記録するだけで AC-3 が閉じる**。AC-1 の patch は L3 |

### Tier 2 — `PLANGATE_HOOK_TASK` セッションがあれば即着手可

| 順 | issue | 作業 | なぜこの順か |
|---:|---|---|---|
| 5 | **#1180** AC-1 + AC-2 | `ta-69:229` の 1 語修正 + `--selftest` の tests/extras 配線 | **1 行で検出力が復活**。AC-2 は「M-1 で失われた条件④を pin する唯一の資産」なのでセットで効く。他 issue とファイル衝突なし |
| 6 | **#1162** | 件数契約 3 箇所を `-eq` から下限 / 同値照合へ | **3 件とも実測値＝契約値でちょうど装填状態** = 無関係な PR の CI を落とす時限爆弾。**他の全作業のノイズを減らす**。ただし `ta-57` を触るので #1165 と束ねる判断が要る |
| 7 | **#1177+#1178** | `ta-70` の母集合反転 + TC-01 構造判定 + timeout + `scripts/parsers/*.py` 2 本 | **1 PR に束ねること必須**（§6-2）。**merge 境界（NO MERGE BY AI）に関わる**ので実害の重さは最大だが、変更範囲が広く設計判断も 1 つ含むのでこの順 |
| 8 | **#1011** V3-04 | `_mass_delete_blocked` の数値検証（不正入力時 blocked 側へ） | **現 3 呼び出し元はすべて算術で数値を作るため挙動不変**で入る。後続（#991 CB-2 / #1009 / #1010）がこの関数契約に依存 |
| 9 | **#1021** | `ta-09/07/08` に規約 8 の判別 + standalone fallback + cleanup 分岐 | 実監査ログ汚染が継続中。ただし #921 / #1044 と対象が重なるので着手順の調整が要る |

### Tier 3 — Human の 1 アクションで完了に最接近（**費用対効果は最上位**）

| issue | 状態 | 必要な Human アクション |
|---|---|---|
| **#1101** | patch 設計 1046 行が main 着地済（RiverReview 7 巡 rev9）。**AI 側の残作業は実質ゼロ** | `_reports/1101-normalization-patch.md` §3 の hunk を `scripts/hooks/check-plan-hash.sh` へ適用（§6 手順 4 の `hits`=0 検証つき） |
| **#1086** | 調査 561 行 + 外部レビュー 306 行が main 着地済。推奨は案 (A′) | **H-1: `.codex/skills` 120 ファイルの untrack を承認するか**。**この判断 1 つで #1170 が動く** |
| **#1177** | ガードは 87/87 適用済。AC-3/4/5 だけが残る | **reopen / #1178 へ AC 吸収 / 新規 issue の 3 択**を決める |

### 7-1. この順で進めたときに外れるブロッカー

- **#1102 を close**（順位 0）すると、**全セッションに配られていた誤った前提が消える**（既に #1190 で解消済なので、close は追認）
- **#1162（順位 6）** は「無関係な PR の CI を落とす時限爆弾」の除去なので、**他の全作業のノイズを減らす**
- **#1086 の H-1 判断**が下りると **#1170 が完全にアンブロックされる**（#1170 は body で自ら deferred 宣言している）
- **#1011 V3-04（順位 8）** を先に入れると、#991 CB-2 / #1009 / #1010 が同じ関数契約の上に載せられる

## 8. スコープ外で見つけた問題（手は出していない・報告のみ）

### 8-1. `scripts/parsers/` 2 本がどの走査群にも allowlist にも属していない

`scripts/parsers/__init__.py` / `scripts/parsers/codex_log_parser.py` は `PG-SH-GUARD` を持たず、#1177 の Out of scope allowlist（11 件）にも入っていない。**現時点でバッククォート / `$(` は冒頭 40 行に 0 件なので即時の payload は無い**が、母集合の外にあるため将来の追記で無防備に発火しうる。**#1177 AC-3 を実装する PR で必ず同時に扱うこと。**

### 8-2. `.claude/skills/` に `design-gate` / `plan-review-gate` が存在しない

4 root のうち `.claude` だけが 4 skill 中 2 skill しか持たない（§5-4）。既存 issue に該当が見当たらない。**#866 の「4 root」モデルが全 skill に成立するわけではない**ことの追加事例。起票の要否は Human 判断。

### 8-3. `ta-70` TC-04 に timeout が無い（非機能軸の穴）

87 ファイルを `sh` で順次起動する経路に上限が無い。**ガードが壊れたときの失敗モードは「block」ではなく「ハング」**になる。#1177 AC-5 / #1178 AC-5 として追跡されてはいるが、**#1187 で母集合が 3.2 倍になったことで期待所要時間も 3.2 倍になっている**点は issue に書かれていない。

### 8-4. `ta-70` の走査対象が 4 箇所に重複ハードコードされている

`_T70_DIRS`（`:65`）と TC-01/02/03/04 の glob（`:79` / `:92` / `:104` / `:121`）が独立に同じ 3 群を列挙している。**片方だけ更新すると黙って drift する**。#1177 AC-3 の母集合反転で構造的に解消されるが、反転しない場合は単一定義化だけでも価値がある。

### 8-5. #1093 の AC-1 exemplar が #1089 の解消で用途反転した

§5-6 のとおり。**issue の設計結論は無傷だが、着手時に exemplar を差し替えないと AC-1 が構造的に達成不能**（既に適用済のスクリプトを「未適用の例」として使っているため）。

### 8-6. `_reports/1102-1018-blocked-oneline-patch.md` の責務判定に誤りがある

「#1018 は AI が構造的に到達できない / Human-owned」は **`PLANGATE_HOOK_TASK` 未設定セッションに限った話**（§3）。EH-3 の basename ガードは `task_id` が空の分岐にのみ存在する。**責務表を「no-TASK セッションでは到達不能」へ書き換えるべき**。

## 9. 測定方法と限界

### 9-1. 測定の規律

- **すべての測定で ref を明示**した（`git show origin/main:<path>` / `git grep <pat> origin/main -- <path>` / `git ls-tree -r origin/main`）。共有 checkout は stale なため、作業ツリーの `ls` / `grep` は「実測」として扱っていない
- **行番号アンカーは stale 化している前提**で扱い、記号（関数名 / 変数名 / TC 名）で再特定してから現在の行番号を報告した
- **すべての「0 件」に陽性コントロールを添えた**（例: `ta-70` の `timeout` = 0 に対し同ファイルの `TC-0` = 35 件）
- **量化子の主張は全数照合してから書いた**（87/87 のガード適用、31 ファイルの `CLAUDE_PLUGIN_ROOT` 手順、21 本の `_pg_extra_helper`、4 root の skill 名集合）
- **件数だけでなく対象ファイル名の集合を書いた**（`scripts/parsers/*.py` 2 本、`Files / Interfaces` を使う 3 plan、`.claude` に不在の 2 skill）
- **`git log --grep "#N"` を zsh のループで回していない**（前回の棚卸しで `#N` が配列添字と解釈されコマンドが起動しなかった事故を踏まえ、1 パターン 1 コマンドで実行）

### 9-2. 実行を避けたもの（意図的な限界）

安全指示に従い、以下は**一切実行していない**:

- `sh <任意の .py>`（docstring がコマンド置換として評価される。#1169 / #1177）
- `scripts/sync-plugin-plangate.sh` / `scripts/install-plangate-skills-to-codex.sh` / `scripts/apply-*.sh --apply`
- `sh tests/run-tests.sh`（**`ta-70` TC-04 が repo 実ファイルを `sh` 起動する破壊的ハーネス**であり、`ta-42` / `ta-09` が実 `docs/working/` に書き込む）
- `python3 -m compileall`（`__pycache__` を repo に書く）
- issue / PR への書き込み操作（コメント・close・ラベル・編集）

**結果として、次は「未確認」であり PASS とも FAIL とも扱っていない**:

- 各 issue の「`sh tests/run-tests.sh` が baseline を維持」系 AC（**ほぼ全件**）— ただし実装差分がゼロの issue では新規 FAIL を生む変更自体が存在しない
- 変異注入による検出力の実証（#1177 AC-4 / #1178 AC-6 / #1180 AC-1 / #1011 / #1101 AC-3〜6）。**コード読解による構造判定にとどまる**
- marketplace 実環境での plugin hook 発火・skill 参照解決（#1144 AC-1 / #1057 の切り分け節）
- Codex ランタイムが実際に `.codex/skills` を読む動作（#1170 / #1086 AC-1/AC-2）— tracked ファイルの内容 parity のみ測定

### 9-3. 例外的に実行したもの（安全を確認した上で）

- **`check-plan-hash.sh` の `_override` case ブロックの逐語レプリカ**（#1101）: hook 本体は `log_event()` が `$AUDIT_LOG` へ `>>` 追記するため直接実行せず、case ブロックのみを repo 外で再現。glob 意味論としては厳密に等価
- **`plan_package.py` の `_extract_section()`**（#1018）: `git show origin/main:` で scratchpad へ取り出し、repo 外で純関数として実行。陽性コントロール（`Files / Interfaces` は表本体を返す）付き
- **`ta-46-ehs-wiring.sh` の bootstrap**（#1044）: sandbox に helper を置かずに展開し 4 シェルで実行

### 9-4. 扱えなかった issue

**なし。20 件すべてを扱った。** うち #1177 は既に CLOSED だが、依頼範囲に含まれるため AC 照合を行い §4-0 に記載した。
