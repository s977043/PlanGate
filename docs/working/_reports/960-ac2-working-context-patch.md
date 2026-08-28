# #960 AC-2 — `working-context.md` の C-1 項目列挙を正本参照へ是正する L3 patch

> 作成日: 2026-08-26
> 対象 issue: #960（C-1 セルフレビュー項目数の 4 変種問題）
> 測定基点: `origin/main` = **`afb96a1`**（受理条件は**すべて `afb96a1` に対して
> 実測し直している**。patch の初回生成は `7333818` 上で行ったが、両 commit 間で対象
> 3 ファイルに差分ゼロであることも実測済み。§4-0 参照）
> 責務: **本 PR は patch の提示のみ。`.claude/rules/*.md` は Hardening Override
> 対象のため適用は Human-owned**（[責務 4 分類](../../../.claude/rules/responsibility-classes.md)）。

## 1. 何が残っていたか

`.claude/rules/working-context.md` の `### review-self.md（セルフレビュー結果）` 節
（`origin/main` で 304〜311 行。行番号は移動しうるため記号アンカー
`### review-self.md（セルフレビュー結果）` で再測定すること）は、
本文が「**以下を含める**」であり、**C-1 チェック項目の中身の列挙**である。

しかしその列挙は **7 + 5 + 3 = 15 項目**しか挙げておらず、正本
`docs/working/templates/review-self.md` の **全 25 項目**に対し **10 項目欠落**していた。

| 欠落していた ID | 区分 | 個数 |
|---|---|---:|
| `C1-PLAN-08-AEE` / `C1-PLAN-09-AEE` | Plan（#544 Phase1） | 2 |
| `C1-SUP-PLAN-01` / `02` | Plan 品質追加（#581） | 2 |
| `C1-TODO-RB` | ToDo（rollback） | 1 |
| `C1-B1B2-16` / `17` | B-1/B-2 結合 | 2 |
| `C1-SEC-01` | セキュリティ（#578） | 1 |
| `C1-SCOPE-DISC-01` | スコープ規律（#578） | 1 |
| `C1-UI-01` | UI（#579） | 1 |
| **合計** | | **10** |

しかも残る **15 は #960 が列挙した 4 変種（15 / 17 / 20 / 25）の 1 つ**そのものであり、
issue #960 が潰そうとした「項目数の直書きが正本と乖離する」構造がこの節に残存していた。

### 実測（正本側）

```console
$ git show origin/main:docs/working/templates/review-self.md | grep -c '^### C1-'
25
```

`C1-SUP-PLAN-01` / `C1-TODO-RB` / `C1-B1B2-16` / `C1-SCOPE-DISC-01` は
`C1-[A-Z]+-[0-9]+` に一致しないため、**ID の形を仮定した正規表現では取りこぼす**。
上記のとおり接頭辞 `### C1-` のみで数えている。

## 2. 是正の型 — 同ファイル群の中に既に正解がある

`.claude/rules/mode-classification.md` は既に「総数は正本参照・部分集合は ID 明示」の形:

```text
| C-1 | 全項目チェック（正本: docs/working/templates/review-self.md） | Plan 項目（`C1-PLAN-01`〜`07`）のみ |
```

新しい様式を発明せず、**この型に揃えた**。すなわち:

- **総数（25 等）を直書きしない** — 正本節へのリンクに置き換える
- **区分は正本の ID で列挙する** — 「何が含まれるか」という元の情報量は落とさない

### 是正前

```text
### review-self.md（セルフレビュー結果）

フェーズC-1（Prompt 2）で生成。以下を含める:

- Planチェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化
- ToDoチェック（5項目）: タスク粒度、depends_on設定、チェックポイント設定、Iron Law遵守、完了条件
- TestCasesチェック（3項目）: 受入基準との紐付き、Edge case網羅、自動化可否
- 判定: PASS / WARN / FAIL + 指摘事項
```

### 是正後

```text
### review-self.md（セルフレビュー結果）

フェーズC-1（Prompt 2）で生成。**チェック項目の正本は
[`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)
の「C-1 チェック項目数（正本）」節**であり、本節は項目数を再定義しない。
以下の区分で構成される（各区分は正本の ID で示す。総数は正本を参照すること）:

- Plan チェック: `C1-PLAN-01`〜`07` + `C1-PLAN-08-AEE` / `09-AEE`
- Plan 品質追加（Superpowers 由来 / #581）: `C1-SUP-PLAN-01` / `02`
- ToDo チェック: `C1-TODO-08`〜`12` + `C1-TODO-RB`
- TestCases チェック: `C1-TEST-13`〜`15`
- B-1/B-2 結合: `C1-B1B2-16` / `17`
- セキュリティ（#578）: `C1-SEC-01`
- スコープ規律（#578）: `C1-SCOPE-DISC-01`
- UI（#579・`is_ui_task` 時のみ）: `C1-UI-01`
- 判定: PASS / WARN / FAIL + 指摘事項
```

区分と ID は正本 `docs/working/templates/review-self.md` の「C-1 チェック項目数（正本）」
表の行と 1:1 対応させている（同表の 8 区分をそのまま写像）。

## 3. patch 本文

配布ミラー `plugin/plangate/rules/working-context.md` は上流と**バイト同一**であり
（`diff` で実測、§4-6）、片方だけ直すと `sync-plugin-plangate.sh` が drift を検出する
（§4-7 の陽性コントロールで実証）。よって **1 つの patch に両ファイルを含めている**。

````diff
diff --git a/.claude/rules/working-context.md b/.claude/rules/working-context.md
index 97eefbd..e629963 100644
--- a/.claude/rules/working-context.md
+++ b/.claude/rules/working-context.md
@@ -303,11 +303,19 @@ confirmed_by）。人間 confirm 済のみ追記。#200 期間集計の入力源
 
 ### review-self.md（セルフレビュー結果）
 
-フェーズC-1（Prompt 2）で生成。以下を含める:
-
-- Planチェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化
-- ToDoチェック（5項目）: タスク粒度、depends_on設定、チェックポイント設定、Iron Law遵守、完了条件
-- TestCasesチェック（3項目）: 受入基準との紐付き、Edge case網羅、自動化可否
+フェーズC-1（Prompt 2）で生成。**チェック項目の正本は
+[`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)
+の「C-1 チェック項目数（正本）」節**であり、本節は項目数を再定義しない。
+以下の区分で構成される（各区分は正本の ID で示す。総数は正本を参照すること）:
+
+- Plan チェック: `C1-PLAN-01`〜`07` + `C1-PLAN-08-AEE` / `09-AEE`
+- Plan 品質追加（Superpowers 由来 / #581）: `C1-SUP-PLAN-01` / `02`
+- ToDo チェック: `C1-TODO-08`〜`12` + `C1-TODO-RB`
+- TestCases チェック: `C1-TEST-13`〜`15`
+- B-1/B-2 結合: `C1-B1B2-16` / `17`
+- セキュリティ（#578）: `C1-SEC-01`
+- スコープ規律（#578）: `C1-SCOPE-DISC-01`
+- UI（#579・`is_ui_task` 時のみ）: `C1-UI-01`
 - 判定: PASS / WARN / FAIL + 指摘事項
 
 ### review-external.md（外部AIレビュー結果 / 指摘の追記専用集約）
diff --git a/plugin/plangate/rules/working-context.md b/plugin/plangate/rules/working-context.md
index 97eefbd..e629963 100644
--- a/plugin/plangate/rules/working-context.md
+++ b/plugin/plangate/rules/working-context.md
@@ -303,11 +303,19 @@ confirmed_by）。人間 confirm 済のみ追記。#200 期間集計の入力源
 
 ### review-self.md（セルフレビュー結果）
 
-フェーズC-1（Prompt 2）で生成。以下を含める:
-
-- Planチェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化
-- ToDoチェック（5項目）: タスク粒度、depends_on設定、チェックポイント設定、Iron Law遵守、完了条件
-- TestCasesチェック（3項目）: 受入基準との紐付き、Edge case網羅、自動化可否
+フェーズC-1（Prompt 2）で生成。**チェック項目の正本は
+[`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)
+の「C-1 チェック項目数（正本）」節**であり、本節は項目数を再定義しない。
+以下の区分で構成される（各区分は正本の ID で示す。総数は正本を参照すること）:
+
+- Plan チェック: `C1-PLAN-01`〜`07` + `C1-PLAN-08-AEE` / `09-AEE`
+- Plan 品質追加（Superpowers 由来 / #581）: `C1-SUP-PLAN-01` / `02`
+- ToDo チェック: `C1-TODO-08`〜`12` + `C1-TODO-RB`
+- TestCases チェック: `C1-TEST-13`〜`15`
+- B-1/B-2 結合: `C1-B1B2-16` / `17`
+- セキュリティ（#578）: `C1-SEC-01`
+- スコープ規律（#578）: `C1-SCOPE-DISC-01`
+- UI（#579・`is_ui_task` 時のみ）: `C1-UI-01`
 - 判定: PASS / WARN / FAIL + 指摘事項
 
 ### review-external.md（外部AIレビュー結果 / 指摘の追記専用集約）
````

## 4. 受理条件の実測結果

検証は `origin/main` を checkout した**隔離 worktree**（`git worktree add --detach`）で実施。

### 4-0. base 追随の確認

作業中に `origin/main` が `7333818` → `afb96a1` へ進んだ（別セッションの
PR #1245 が同じ 2 ファイルに 27 行ずつ追加し、対象節が 279 行付近から 304 行付近へ移動）。
**受理条件はすべて `afb96a1` を checkout し直した worktree で測り直している。**

| # | コマンド | 結果 |
|---|---|---|
| 0-a | `git diff --stat 7333818 afb96a1 -- .claude/rules/working-context.md plugin/plangate/rules/working-context.md docs/working/templates/review-self.md` | **出力なし**（対象 3 ファイルは両 commit 間で無変更） |
| 0-b | `git rev-parse HEAD`（検証 worktree） | `afb96a18e8cc7e0522187a7ab68e4245b62f3138` |
| 0-c | `grep -c '^### C1-' docs/working/templates/review-self.md`（`afb96a1`） | **25** |

### 4-1〜4-5. patch の当たり判定・可逆性・検出力（すべて `afb96a1` 上）

| # | 検証 | コマンド | 期待 | 実測 |
|---|---|---|---|---|
| 1 | 未適用で当たる | `git apply --check <patch>` | rc=0 | **rc=0** ✅ |
| 2 | 未適用で reverse は当たらない | `git apply --check --reverse <patch>` | rc≠0 | **rc=1** ✅（`error: patch failed: ...:303` / `patch does not apply`） |
| 3 | **変異注入**（文脈行 `### review-external.md（...）` を `### MUTATED-HEADING` に改変） | `git apply --check <mutated>` | rc≠0 | **rc=1** ✅ |
| 4 | 実適用 | `git apply <patch>` | rc=0 | **rc=0**、`git status --porcelain` で 2 ファイル `M` ✅ |
| 5 | 適用後 reverse が当たる | `git apply --check --reverse <patch>` | rc=0 | **rc=0** ✅ |

3 の変異が no-op でなかったことは `cmp -s <patch> <mutated>` が差分ありを返すことで確認済み
（no-op なら「検出力あり」の主張が空振りになるため）。

### 4-6. 適用後に repo 自身の検査器を実走

| 検査器 | コマンド | 実測 |
|---|---|---|
| stale ref | `python3 scripts/check-stale-skill-refs.py` | **rc=0** / `OK: 65 ファイルを検査し stale パス参照なし`（WARN **0 件**。`INFO: 7 件は gitignore 対象パスのため除外` は適用前と同一の恒常出力） |
| plugin 同期 | `sh scripts/sync-plugin-plangate.sh --dry-run` | **rc=0** / `[sync-plugin] Sync complete — no changes`（上流とミラーが整合） |
| ミラー一致 | `diff <(sed -n '304,322p' .claude/rules/working-context.md) <(sed -n '304,322p' plugin/plangate/rules/working-context.md)` | **差分なし** |

> `sync-plugin-plangate.sh --dry-run` は `afb96a1` 時点で 1 回あたり数分かかる
> （`scripts/_ai_loop_link_rewrite.py` をファイル毎に起動するため）。応答が返らないのは
> ハングではない。`sh -x` で当該 `python3` 呼び出しの列挙を確認済み。

適用前の baseline も同一コマンドで取得: `check-stale-skill-refs.py` は
**rc=0 / 同一メッセージ**（＝本 patch は stale ref を増やしても減らしてもいない）。

### 4-7. 陽性コントロール（空の出力を「0 件」の証拠にしない）

`sync-plugin-plangate.sh --dry-run` は **drift の有無に関わらず rc=0** を返す
（判定は標準出力の文言）。この検査器が実際に drift を検出できることを 2 通りで実証した。

| 陽性コントロール | 操作 | 出力 |
|---|---|---|
| PC-1 | ミラー末尾に `DRIFT-PROBE` 行を追記 | `[sync-plugin][dry-run] WOULD COPY: rules/working-context.md` / `Sync complete — **changes detected**` |
| PC-2 | **上流のみ patch 適用・ミラー未適用** | `WOULD COPY: rules/working-context.md` / `Sync complete — **changes detected**` |

**PC-2 が「ミラーも同じ patch に含める必要がある」の直接証拠**である。
両ファイル適用後に再実行すると `Sync complete — no changes` に戻ることも実測済み。

### 4-8. markdownlint

| 対象 | 適用前 | 適用後 |
|---|---|---|
| `.claude/rules/working-context.md` + `plugin/plangate/rules/working-context.md` | **rc=1 / error 20 件** | **rc=1 / error 20 件** |

**exit 0 にはならないが、これは本 patch 起因ではない。** 適用前後の error 行から
行番号を落として `diff` した結果 **完全一致（LINT-DELTA-ZERO）**。生の出力での差分は
**行番号のシフトのみ**（実測: 是正節より前の違反は差 `0`、後ろの違反は差 `+8`＝本 patch の
純増行数。差の集合は `{0, 8}` のみ）で、ルール ID・件数・対象行の内容は
完全一致（MD032 blanks-around-lists ×18 / MD012 no-multiple-blanks ×2、いずれも
本節の外にある既存違反）。**本 patch が導入した新規違反は 0 件。**

なお `.claude/rules/**` は **CI の markdownlint globs に含まれていない**
（`.github/workflows/ci.yml` の `Lint Markdown` step の globs は
`README.md` / `CHANGELOG.md` / `.github/PULL_REQUEST_TEMPLATE.md` /
`CODE_OF_CONDUCT.md` / `CONTRIBUTING.md` / `SECURITY.md` / `docs/index.md` /
`docs/pages/explanation/product/philosophy.md` /
`docs/pages/guides/governance/oss-governance.md` / `docs/workflows/**/*.md`）ため、
この既存 20 件は CI を落とさない。**本 patch は CI 状態を変えない。**

> この 20 件自体は #960 のスコープ外の既存課題であり、本 patch では触っていない
> （承認境界パスの `.md` に無関係な整形差分を混ぜないため）。

## 5. 適用手順（Human-owned）

`.claude/rules/*.md` は **Hardening Override 対象パス**
（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) の対象パス一覧）であり、
AI は c3 承認があっても編集できない。以下は **人間が実行**する。

```sh
cd /path/to/plangate
git fetch origin
git checkout -b fix/960-ac2-working-context origin/main

# 本ファイルの §3 の diff を 960-ac2.patch として保存したうえで
git apply --check 960-ac2.patch   # rc=0 を確認してから
git apply 960-ac2.patch

# 検証（いずれも rc=0 / 下記の文言を確認）
python3 scripts/check-stale-skill-refs.py          # OK: ... stale パス参照なし
sh scripts/sync-plugin-plangate.sh --dry-run       # Sync complete — no changes

git add .claude/rules/working-context.md plugin/plangate/rules/working-context.md
git commit -m "fix(rules): working-context.md の C-1 項目列挙を正本参照へ是正（数の直書きを撤去）"
```

### `sync-plugin-plangate.sh` の追加実行は不要

本 patch は **上流と配布ミラーの両方を同一内容で変更している**ため、適用直後の
`--dry-run` は `Sync complete — no changes` を返す（§4-6 実測）。
したがって適用後に `sync-plugin-plangate.sh`（非 dry-run）を改めて走らせる必要はない。
**ただし §3 の diff のうち上流側だけを適用した場合は drift が残る**（§4-7 PC-2）ので、
必ず 2 ファイルとも適用すること。

### 適用時の注意

- 行番号（`@@ -303,11 +303,19 @@`）は base が進むと動く。`git apply --check` が
  rc≠0 になったら記号アンカー `### review-self.md（セルフレビュー結果）` で
  現在位置を再測定し、patch を作り直す。
- 適用は `.claude/rules/` への変更なので、承認境界周辺の変更として
  **Mode は最低「高」・`lite_eligible=false`・同期 C-3 固定**である。

## 6. 残存する既知の未解決（本 patch のスコープ外）

- `.claude/rules/working-context.md` / 配布ミラーの既存 markdownlint 違反 20 件
  （MD032 ×18 / MD012 ×2）。CI 対象外のため放置しても CI は落ちないが、
  別 PBI での整形が望ましい。
- 本 patch は #960 の **AC-2 のみ**を扱う。#960 の他 AC の充足状況は判定していない。

Refs: #960
