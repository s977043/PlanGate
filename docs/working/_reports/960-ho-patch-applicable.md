# #960 HO 分 patch — `git apply` 可能版（**Human 適用**）

> 本書は [`960-ho-patch.md`](./960-ho-patch.md) と**同一の是正内容**を、`git apply` で機械適用できる
> **unified diff** として提供する。意図・背景・対象外の判断根拠は元文書を正本とし、本書は**適用可能な形式**のみを担う。
> 対象: **Hardening Override 対象 6 ファイル**。AI は編集できないため、**適用は Human-owned**。
> 測定基点: `origin/main` = `9dc9cc6`（2026-08-25 実測）

## なぜ本書が必要か

元文書 `960-ho-patch.md` の差分は **3 バッククォートの diff フェンス**内に **before/after の行スニペット**（`-旧行` / `+新行` のみ）が
置かれているだけで、unified diff に必須の `--- a/` / `+++ b/` / `@@` ヘッダを持たない。実測:

```
$ git apply --check <元文書から抽出したブロック>
error: No valid patches in input
```

そのため元文書のままでは **Human が 6 ファイルを手作業で編集するしかない**。本書は同じ 11 箇所を
機械適用可能な unified diff にした（**内容は等価。新たな是正は追加していない**）。

## 適用手順

```sh
# 0. 前提: origin/main が 9dc9cc6 相当であること（差異があれば --check が失敗して検出される）
git fetch origin && git checkout -b fix/960-ho-item-count origin/main

# 1. 本書から diff を抽出（4 バッククォートの ```` ```diff ```` ブロック）
awk '/^````diff$/{f=1;next} /^````$/{f=0} f' \
  docs/working/_reports/960-ho-patch-applicable.md > /tmp/960-ho.patch

# 2. 適用前検査（rc=0 を確認してから適用する）
git apply --check /tmp/960-ho.patch && echo OK

# 3. 適用
git apply /tmp/960-ho.patch
git diff --stat        # 6 files changed, 11 insertions(+), 11 deletions(-)

# 4. export ミラー 5 件を同期で追従させる
sh scripts/sync-plugin-plangate.sh

# 5. 検証（元文書と同じ）
git grep -lE '17[[:space:]]*項目' | grep -vE '^docs/working/(TASK-|discussions/|_reports/)'
#    期待: CHANGELOG.md / docs/changelog.md / docs/working/retrospective-2026-04-28.md
#          / docs/working/templates/review-self.md の 4 件のみ

sh scripts/sync-plugin-plangate.sh --dry-run   # rc=0 / drift なし
sh tests/run-tests.sh                          # 新規 FAIL がないこと
```

> ⚠️ **`git grep -lE '17\s*項目'` は使わないこと**（git の ERE では `\s` が空白クラスにならず `17 項目` を取りこぼす）。
> 必ず `[[:space:]]` を使う。元文書と同じ注意。

## 差分（`git apply` 可能）

````diff
--- a/.claude/rules/mode-classification.md
+++ b/.claude/rules/mode-classification.md
@@ -95,7 +95,7 @@
 
 | 項目 | Standard（既定） | Lite（lite_eligible=true かつ opt-in 時） |
 |------|-----------------|------------------------------------------|
-| C-1 | 17 項目 | 17 項目（不変）|
+| C-1 | 全項目 | 全項目（不変）|
 | C-2 外部レビュー | 複数観点 | **1 本**（critical/major=0 要求・観点固定）|
 | C-3 | 同期（既定）| 同期（既定）。条件付き降格は working-context 参照 |
 
@@ -150,7 +150,7 @@
 |---------|------|---|---|---|------|
 | **brainstorm** | - | - | △（任意） | ○ | ○ |
 | **plan 生成** | - | △（簡易plan） | ○ | ○ | ○（詳細plan） |
-| **C-1 セルフレビュー** | - | △（Plan 7項目のみ） | ○（17項目） | ○（17項目） | ○（17項目） |
+| **C-1 セルフレビュー** | - | △（Plan 項目のみ） | ○（全項目） | ○（全項目） | ○（全項目） |
 | **C-2 外部AIレビュー** | - | - | - | ○ | ○（複数観点） |
 | **C-3 人間レビュー** | - | △（差分確認） | ○ | ○ | ○（詳細レビュー） |
 | **exec (TDD)** | 直接実装 | TDD | TDD | TDD + 並列 | TDD + 並列 + 段階的 |
@@ -167,7 +167,7 @@
 | フェーズ | 通常版 | 簡易版 |
 |---------|--------|--------|
 | plan 生成 | Goal + Constraints + Work Breakdown + Testing Strategy + Risks | Goal + 変更内容 + 確認方法 |
-| C-1 | 17項目チェック | Plan 7項目（C1-PLAN-01〜07）のみ |
+| C-1 | 全項目チェック（正本: [`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)） | Plan 項目（`C1-PLAN-01`〜`07`）のみ |
 | C-3 | 全ドキュメントレビュー | 差分のみ確認（plan 不要なため） |
 | V-1 | test-cases.md 全件突合 | 変更箇所の動作確認のみ |
 
--- a/.claude/rules/working-context.md
+++ b/.claude/rules/working-context.md
@@ -16,7 +16,7 @@
   → 0: Brainstorming 🤖👤（対話的な要件整理・設計書生成、任意）
   → A: PBI INPUT PACKAGE作成 👤
   → B: Plan + ToDo + Test Cases同時生成 🤖
-  → C-1: セルフレビュー 🤖（17項目チェック）
+  → C-1: セルフレビュー 🤖（全項目チェック）
   → C-2: 外部AIレビュー 🤖
   → C-3: 人間レビュー 👤（三値ゲート: APPROVE / CONDITIONAL / REJECT）
   → D: Agent実行 🤖（TDD）
--- a/.claude/commands/README.md
+++ b/.claude/commands/README.md
@@ -16,7 +16,7 @@
 # 作業コンテキストの保存（セッション終了時）
 /working-context save
 
-# Plan生成 → セルフレビュー（17項目）→ 外部AIレビュー（一括自動実行）
+# Plan生成 → セルフレビュー → 外部AIレビュー（一括自動実行）
 /ai-dev-workflow TASK-1234 plan
 
 # Agent実行（C-3承認後。多層防御検証 → PR作成まで自動）
--- a/.claude/commands/ai-dev-workflow.md
+++ b/.claude/commands/ai-dev-workflow.md
@@ -11,7 +11,7 @@
 $ARGUMENTS に以下の形式で渡される:
 
 - `TASK-XXXX brainstorm` — フェーズ0: Brainstorming（アイデア→設計書の対話的生成）
-- `TASK-XXXX plan` — フェーズB〜C-2: Plan + ToDo + Test Cases生成 → セルフレビュー（17項目）→ 外部AIレビュー → 指摘反映（一括自動実行）
+- `TASK-XXXX plan` — フェーズB〜C-2: Plan + ToDo + Test Cases生成 → セルフレビュー → 外部AIレビュー → 指摘反映（一括自動実行）
 - `TASK-XXXX exec` — フェーズD〜C-4: Agent実行 → 多層防御検証 → PR作成
 - `TASK-XXXX status` — 現在のフェーズと進捗を表示
 
@@ -196,7 +196,7 @@
 > ユーザー確認不要。plan/todo/test-cases生成後にそのまま実行する。
 
 1. `plan.md` + `todo.md` + `test-cases.md` + `pbi-input.md` を読み込む
-2. 以下の17項目をチェック:
+2. 以下をチェック（項目定義の正本: `docs/working/templates/review-self.md`）:
 
 **Planチェック（7項目）**:
 1. 受入基準網羅性 — 全受入基準に対してVerificationが書かれているか（必須）
@@ -250,7 +250,7 @@
 #### ステップ5: 最終結果の提示
 
 1. フェーズB〜C-2の全結果をユーザーにサマリ表示:
-   - C-1結果（PASS/WARN/FAIL件数、17項目）
+   - C-1結果（PASS/WARN/FAIL件数、全項目）
    - C-2結果（重要指摘件数、自動修正した内容）
    - 生成されたファイル一覧
 2. C-3（人間レビュー）の三値判断を案内:
--- a/.claude/agents/workflow-conductor.md
+++ b/.claude/agents/workflow-conductor.md
@@ -259,7 +259,7 @@
 | フェーズ | ultra-light | light | standard | high-risk | critical |
 |---------|-------------|-------|----------|------|----------|
 | plan 生成 | - | △ | ○ | ○ | ○ |
-| C-1 | - | △(7項目) | ○(17項目) | ○(17項目) | ○(17項目) |
+| C-1 | - | △(Plan 項目) | ○(全項目) | ○(全項目) | ○(全項目) |
 | C-2 | - | - | - | ○ | ○ |
 | C-3 | - | △ | ○ | ○ | ○ |
 | exec | 直接実装 | TDD | TDD | TDD+並列 | TDD+並列+段階的 |
@@ -468,7 +468,7 @@
 |-------------|--------|----------------|
 | brainstorm | brainstorming skill | ユーザー入力 + コードベース調査結果 |
 | plan生成 | project-planner agent | pbi-input.md全文 |
-| C-1 | diff-audit skill（17項目チェック） | plan + todo + test-cases + pbi-input |
+| C-1 | diff-audit skill（全項目チェック） | plan + todo + test-cases + pbi-input |
 | C-2 | 利用可能なサブエージェント | plan + todo + test-cases + review-self |
 | exec: 実装 | implementer agent（タスクごとに新規） | タスク詳細（抽出済み）+ テストケース（抽出済み）+ 既存パターン |
 | L-0: autofix/AI修正 | linter-fixer agent | リンター設定 + 違反一覧 + 該当コード |
--- a/schemas/review-result.schema.json
+++ b/schemas/review-result.schema.json
@@ -39,7 +39,7 @@
     },
     "score": {
       "type": "object",
-      "description": "phase 固有スコア（C-1 の 17 項目等、任意）",
+      "description": "phase 固有スコア（C-1 の各項目等、任意）",
       "properties": {
         "pass": { "type": "integer", "minimum": 0 },
         "warn": { "type": "integer", "minimum": 0 },
````

## 元文書 11 ブロックとの対応（11/11）

| 元ブロック # | 元文書の節 | 対象ファイル | 現 main の行 | 本書の該当 hunk | 一致 |
|---|---|---|---|---|---|
| 1 | 1. mode-classification L98 | `.claude/rules/mode-classification.md` | 98 | `@@ -95,7 +95,7 @@` | ✅ |
| 2 | 1. mode-classification L153 | `.claude/rules/mode-classification.md` | 153 | `@@ -150,7 +150,7 @@` | ✅ |
| 3 | 1. mode-classification L170 | `.claude/rules/mode-classification.md` | 170 | `@@ -167,7 +167,7 @@` | ✅ |
| 4 | 2. working-context L19 | `.claude/rules/working-context.md` | 19 | `@@ -16,7 +16,7 @@` | ✅ |
| 5 | 3. commands/README L19 | `.claude/commands/README.md` | 19 | `@@ -16,7 +16,7 @@` | ✅ |
| 6 | 4. ai-dev-workflow L14 | `.claude/commands/ai-dev-workflow.md` | 14 | `@@ -11,7 +11,7 @@` | ✅ |
| 7 | 4. ai-dev-workflow L199 | `.claude/commands/ai-dev-workflow.md` | 199 | `@@ -196,7 +196,7 @@` | ✅ |
| 8 | 4. ai-dev-workflow L253 | `.claude/commands/ai-dev-workflow.md` | 253 | `@@ -250,7 +250,7 @@` | ✅ |
| 9 | 5. workflow-conductor L262 | `.claude/agents/workflow-conductor.md` | 262 | `@@ -259,7 +259,7 @@` | ✅ |
| 10 | 5. workflow-conductor L471 | `.claude/agents/workflow-conductor.md` | 471 | `@@ -468,7 +468,7 @@` | ✅ |
| 11 | 6. review-result.schema.json L42 | `schemas/review-result.schema.json` | 42 | `@@ -39,7 +39,7 @@` | ✅ |

**11/11。落とした箇所はない。** 元文書の行番号は現 `origin/main`（`9dc9cc6`）で `git grep -n` により再測定し、
11 箇所すべてが元文書の記載どおりの行に存在することを確認済み（stale なし）。差分の合計は
`6 files changed, 11 insertions(+), 11 deletions(-)` で、置換 11 行と一致する。

### 意図的に触っていない隣接行（元文書と同じ扱い）

| 箇所 | 内容 | 理由 |
|---|---|---|
| `.claude/commands/ai-dev-workflow.md:201` | `**Planチェック（7項目）**:` | 元文書の差分対象外。実際に Plan 系は 7 項目帯なので誤りでない |
| `.claude/rules/working-context.md:216` | `- Planチェック（7項目）: …` | 同上 |

## 検証結果（本書作成時の実測 / worktree `docs/960-applicable-patch`）

| 検査 | コマンド | 期待 | 実測 |
|---|---|---|---|
| 陽性 | `git apply --check 960-ho.patch` | rc=0 | **rc=0** |
| 陰性（未適用の確認） | `git apply --check --reverse 960-ho.patch` | rc≠0 | **rc=1** |
| 変異注入（検出力） | hunk header `@@ -95,7 +95,7 @@` → `@@ -95,6 +95,7 @@` に改変して `--check` | rc≠0 | **rc=128 / `corrupt patch at line 12`** |
| round-trip | 本書から awk 抽出 → `git apply --check` | rc=0 | **rc=0** |

変異注入は「`--check` が実際に hunk を検査していること」の陽性コントロールである（改変すると必ず落ちる）。

## 責務

| 作業 | 担当 |
|---|---|
| 本 patch の生成・検証手順の提示 | **AI-owned**（本書） |
| **6 ファイルへの適用** | **Human-owned**（HO 対象パス） |
| 適用後の `sync` 実行・検証 | Human（または適用後のセッションで AI） |

> 本 PR では **HO 対象 6 ファイルを 1 行も変更していない**（変更は本書 1 ファイルのみ）。

Refs #960 / #1092
