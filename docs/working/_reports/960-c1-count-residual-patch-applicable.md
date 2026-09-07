# #960 残存分 — C-1 の「項目数」ではなく「**番号範囲**」で実体とずれている 2 箇所（機械適用可能な patch）

> 測定基点: **`origin/main` = `b3565b2`**（PR #1283 マージ後）/ 2026-09-07。以下の実測値はすべてこの ref に対するもの。
> 関連: issue #960 / 既適用の先行分 [`960-ho-patch-applicable.md`](./960-ho-patch-applicable.md)（PR #1227 で適用済）/ [`960-ac2-working-context-patch.md`](./960-ac2-working-context-patch.md) / 書式の先例 [`1278-log-event-fail-closed-patch-applicable.md`](./1278-log-event-fail-closed-patch-applicable.md)（同じ marker 規則・同じ §構成）
> 対象: **Hardening Override 対象 2 ファイル**（`.claude/rules/*.md` / `.claude/commands/*.md`）。AI は編集できないため **適用は Human-owned**。
> 本書で AI が作成・変更したのは本ファイルと、同 PR の非 HO `.md` 3 本（§0 の表）のみ。`.claude/` / `scripts/` / `bin/` / `schemas/` / `.github/` / `tests/` は **1 バイトも変更していない**。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **#960 の「数」は解決済み** | `17 項目` / `15 項目` という**総数の表記**は非 HO 分（PR #1118）・HO 分（PR #1119 → #1227 適用）・退行分（PR #1138）で潰れている。本 PR 時点の残存は **数ではなく番号範囲** |
| **残存の型** | `C1-PLAN-01`〜`07` / `C1-PLAN-01〜C1-B1B2-17` という **ID 範囲**での言及。範囲が実体とずれていれば「17 項目」と書くのと同じ欠陥（issue #960 の主題と同型） |
| **残存 2 箇所（HO・本書の対象）** | ① `.claude/rules/mode-classification.md:170` の light 適用範囲 `Plan 項目（C1-PLAN-01〜07）のみ` — 実体の Plan 区分は **9**（`08-AEE` / `09-AEE` を落とす）。issue #960「決めるべきこと 2（mode 別適用）」の未処理分であり、[`bug-backlog-triage-2026-08-20.md`](./bug-backlog-triage-2026-08-20.md) の残件 4 と同一 ② `.claude/commands/ai-dev-workflow.md:227-255` の **C-1 手順そのものが 17 項目しか列挙していない**（`(7項目)` / `(5項目)` / `(3項目)` / `(2項目)` の 4 見出し + 連番 1〜17 + `check_id: C1-PLAN-01〜C1-B1B2-17`）。C-1 を実行する側の指示が正本 25 項目のうち **8 項目を構造的に落とす** |
| **①②の違い** | ① は「範囲表記の誤り」、② は「**手順の欠落**」。② の方が実害が大きい（#544/#578/#579/#581 で入れた 8 項目が C-1 実行時に評価されない） |
| **既に別 patch 文書がある残存（本書では重複させない）** | `.claude/rules/working-context.md` の `review-self.md（セルフレビュー結果）` 節が `Planチェック（7項目）/ ToDoチェック（5項目）/ TestCasesチェック（3項目）` と列挙している件は [`960-ac2-working-context-patch.md`](./960-ac2-working-context-patch.md) が扱う。**`b3565b2` 時点で未適用**（Human 適用待ち）。本書と対象ファイルが重ならないため順序不問 |
| **非 HO 分（本 PR で是正済）** | `examples/sample-task/review-self.md`（サマリー `PASS 17` に対し実体 15 項目）/ `examples/README.md`（`17-point self-review result`）/ `docs/plangate-v6-roadmap.md:158`（`C-1の15項目レビュー`） |
| **patch 対象** | `.claude/rules/mode-classification.md`（+1 / -1）、`.claude/commands/ai-dev-workflow.md`（+20 / -5）。**計 2 ファイル / 2 hunk**（`git apply --numstat` 実測） |
| **検証** | repo root で `git apply --check` **rc=0**（§6）。適用後の残存検査は positive control 付きで実走（§6） |

---

## 1. 実測（`b3565b2`）

### 正本の実数

```text
$ grep -c '^### C1-' docs/working/templates/review-self.md
25

$ grep -o '^### C1-[A-Z0-9]*' docs/working/templates/review-self.md | sort | uniq -c
   2 ### C1-B1B2
   9 ### C1-PLAN
   1 ### C1-SCOPE
   1 ### C1-SEC
   2 ### C1-SUP
   3 ### C1-TEST
   6 ### C1-TODO
   1 ### C1-UI
```

Plan 区分の 9 = `C1-PLAN-01`〜`07` + `C1-PLAN-08-AEE` + `C1-PLAN-09-AEE`（`C1-SUP-PLAN-01` / `02` は正本の表で **別区分「Plan 品質追加」**）。

### 残存 ①: `.claude/rules/mode-classification.md:170`

```text
| C-1 | 全項目チェック（正本: [`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)） | Plan 項目（`C1-PLAN-01`〜`07`）のみ |
```

左セルは PR #1227 で「17項目チェック」→「全項目チェック（正本: …）」に是正済み。**右セル（light の簡易版）の範囲だけが未是正**で、`C1-PLAN-08-AEE`（Stop Condition）/ `C1-PLAN-09-AEE`（Replan Triggers）を落とす。`:153` のフェーズ適用マトリクスは既に「△（Plan 項目のみ）」と数を持たない形に是正済みで、範囲の正本はこの `:170` 側にしかない。

### 残存 ②: `.claude/commands/ai-dev-workflow.md:227-255`

`:227` は「以下をチェック（項目定義の正本: `docs/working/templates/review-self.md`）」と正本を指しているが、**続く列挙が 17 項目で閉じている**:

| 行 | 見出し | 列挙 | 正本の対応区分 |
|---|---|---|---|
| `:229` | `**Planチェック（7項目）**:` | 1〜7 | Plan（実体 **9**） |
| `:238` | `**ToDoチェック（5項目）**:` | 8〜12 | ToDo（実体 **6**） |
| `:245` | `**TestCasesチェック（3項目）**:` | 13〜15 | TestCases（3・一致） |
| `:250` | `**B-1/B-2チェック（2項目）**:` | 16〜17 | B-1/B-2 結合（2・一致） |
| `:255` | — | `check_id付き構造化形式: C1-PLAN-01〜C1-B1B2-17` | 25 項目のうち 17 の連番帯のみ |

落ちている 8 項目: `C1-PLAN-08-AEE` / `C1-PLAN-09-AEE` / `C1-SUP-PLAN-01` / `C1-SUP-PLAN-02` / `C1-TODO-RB` / `C1-SEC-01` / `C1-SCOPE-DISC-01` / `C1-UI-01`。

`:255` の `C1-PLAN-01〜C1-B1B2-17` は加えて **ID が連番であるという誤った前提**を与える。正本テンプレート自身が「`C1-[A-Z]+-[0-9]+` 前提の正規表現は取りこぼす」と注意している形（`C1-PLAN-08-AEE` / `C1-TODO-RB` / `C1-SCOPE-DISC-01`）と矛盾する。

---

## 2. 方針

| 設計判断 | 理由 |
|---|---|
| ① は範囲を**正本の区分名 + 現行 ID** の二段で書く | 「Plan 区分のみ」という**意味**を正本に預け、ID は現行値として括弧内に置く。項目追加時に括弧内だけがずれ、意味は壊れない |
| ② は 17 項目の列挙を**消さず**、コア帯外 8 項目を追記する | 既存 17 行の文言は正本と一致しており、消すと差分が大きく C-4 レビューが読めない。**欠落を足す**方が最小かつ検証しやすい |
| ② の 4 見出しに「コア帯」を付す | `(7項目)` を残したまま 8 項目を足すと「Plan は 7」と「Plan は 9」が同一節に並ぶ。`(コア帯 7 項目)` にすれば両立する |
| ② に「総数を契約値として複写しない」注記を足す | 正本テンプレートの同趣旨の注記と揃える。#960 の再発防止（本文直書きをやめる）に対応 |
| **正本テンプレートの項目は 1 つも増減しない** | 本 issue は数と表記の整合であり、実体を変える PBI ではない（#960 Non-goals） |
| `plugin/plangate/` ミラー 2 件は本 patch に含めない | `plugin/plangate/rules/mode-classification.md` / `plugin/plangate/commands/ai-dev-workflow.md` は同期生成物。適用後に `sh scripts/sync-plugin-plangate.sh` で追従させる（§5 手順 4） |

---

## 3. 残存脅威モデル（完全性を主張しない）

### 守るもの（本 patch 適用後）

- light モードの C-1 適用範囲が正本の Plan 区分（9 項目）と一致する。
- `/ai-dev-workflow plan` の C-1 手順が正本 25 項目すべてを列挙する。
- `check_id` が連番であるという誤った前提を与えない。

### 守らないもの

| 残存 | 内容 | 保証の主体 |
|---|---|---|
| **light に `C1-SUP-PLAN-01` / `02` を含めるか** | 正本の表では「Plan」と「Plan 品質追加」が別区分。本 patch は **Plan 区分のみ**（9）とし、Plan 品質追加 2 を light に含めない | **Human 判断**（§7.1） |
| **数の再発** | 本 patch は 2 箇所を直すだけで、新しい直書きを機械的に止めない。#960 AC「再発防止策」は [`960-recurrence-guard-patch.md`](./960-recurrence-guard-patch.md) が扱い、そこでは「弱すぎ かつ 広すぎ」で一度棄却されている | 未解決（§7.2） |
| **`docs/working/` の過去成果物** | `TASK-*` / `discussions/` / `_prompts/` / `retrospective-*` の「17 項目」は履歴として残す（#960 Out of scope） | 意図的 |
| **`C1-UI-01` の条件付き適用** | `is_ui_task` のときのみ有効。「25 項目」と書いても常に 25 個判定されるわけではない。本 patch は列挙に条件を併記するに留める | 正本テンプレート |
| **手順の列挙と正本の二重管理** | ② の列挙は写しであり、正本が変われば再びずれる。注記で「正本に対して判定せよ」と書くのは規範層の担保にすぎない | C-4 Human レビュー / §7.2 |

本検査は「表記の整合」1 層のみを扱う。C-1 が実際に 25 項目を評価したかの検証（実行層）は本書の範囲外。

---

## 4. 適用しない選択肢と、その棄却理由

| 案 | 内容 | 棄却理由 |
|---|---|---|
| A | ② の 17 項目列挙を丸ごと削り「正本テンプレートを読め」に置換 | 差分が大きく、コマンドの可読性が落ちる。正本が別リポジトリ（plugin 導入先）で解決できない場合に手順が空になる |
| B | ① の light を「全 25 項目」に引き上げる | light の定義変更＝挙動変更であり #960 の scope 外（数と表記の整合ではない） |
| C | 正本テンプレートを 17 項目に戻す | #960 Non-goals（後発追加は #544/#578/#579/#581 で意図的に入った） |

---

## 5. patch（`git apply` 可能）

patch 本体は下の **`<!-- PG-PATCH-BEGIN -->` / `<!-- PG-PATCH-END -->` に挟まれた fenced block**。
抽出は marker 基準で行う（fence ラベルで探すと本節の説明文中の fence 自身に誤ヒットする）。

````sh
# repo root で実行（Human-owned: HO パスへの書き込み）
# 注意: サブディレクトリで git apply すると patch のパスが cwd の外を指し、
#       何も適用せず成功したように見える。必ず repo root で実行すること。
cd "$(git rev-parse --show-toplevel)"

sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/960-c1-count-residual-patch-applicable.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/960-residual.patch

git apply --check /tmp/960-residual.patch && git apply /tmp/960-residual.patch
git diff --stat   # 2 files changed, 21 insertions(+), 6 deletions(-)
````

（`sed` を 2 回通すのは marker 行と fence 行を外側から 1 組ずつ落とすため。先例 1104 / 1278 と同じ規則。）

<!-- PG-PATCH-BEGIN -->
```diff
diff --git a/.claude/rules/mode-classification.md b/.claude/rules/mode-classification.md
--- a/.claude/rules/mode-classification.md
+++ b/.claude/rules/mode-classification.md
@@ -167,7 +167,7 @@
 | フェーズ | 通常版 | 簡易版 |
 |---------|--------|--------|
 | plan 生成 | Goal + Constraints + Work Breakdown + Testing Strategy + Risks | Goal + 変更内容 + 確認方法 |
-| C-1 | 全項目チェック（正本: [`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)） | Plan 項目（`C1-PLAN-01`〜`07`）のみ |
+| C-1 | 全項目チェック（正本: [`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)） | 正本テンプレートの **Plan 区分のみ**（現行 `C1-PLAN-01`〜`07` + `C1-PLAN-08-AEE` / `C1-PLAN-09-AEE`。範囲の正本は同テンプレートの「Plan」行であり、項目は増減しうる） |
 | C-3 | 全ドキュメントレビュー | 差分のみ確認（plan 不要なため） |
 | V-1 | test-cases.md 全件突合 | 変更箇所の動作確認のみ |
 
diff --git a/.claude/commands/ai-dev-workflow.md b/.claude/commands/ai-dev-workflow.md
--- a/.claude/commands/ai-dev-workflow.md
+++ b/.claude/commands/ai-dev-workflow.md
@@ -226,35 +226,50 @@
 1. `plan.md` + `todo.md` + `test-cases.md` + `pbi-input.md` を読み込む
 2. 以下をチェック（項目定義の正本: `docs/working/templates/review-self.md`）:
 
-**Planチェック（7項目）**:
+**Planチェック（コア帯 7 項目）**:
 1. 受入基準網羅性 — 全受入基準に対してVerificationが書かれているか（必須）
 2. Unknowns処理 — 放置されていないか、質問として明文化されているか（必須）
 3. スコープ制御 — Out of scopeへ踏み込みそうな箇所がないか（必須）
 4. テスト戦略 — Unit/Integration/E2E/Edge casesが妥当か（必須）
 5. Work Breakdown Output — 各Stepに具体的な成果物があるか（必須）
 6. 依存関係 — 移行・ロールバックが必要なのに欠けていないか（必須）
 7. 動作検証自動化 — テストコードだけでなく動作検証手段が具体的か（必須）
 
-**ToDoチェック（5項目）**:
+**ToDoチェック（コア帯 5 項目）**:
 8. タスク粒度 — 各タスクが2〜5分で完了できる粒度か（必須）
 9. depends_on設定 — 依存関係が明示されているか（必須）
 10. チェックポイント設定 — 各StepにToDo更新タイミングが設定されているか（推奨）
 11. Iron Law遵守 — 承認前コード実行・スコープ逸脱の危険がないか（必須）
 12. 完了条件 — 各タスクに完了条件が記述されているか（推奨）
 
-**TestCasesチェック（3項目）**:
+**TestCasesチェック（コア帯 3 項目）**:
 13. 受入基準との紐付き — 全受入基準に対してテストケースがあるか（必須）
 14. Edge case網羅 — 境界値・異常系が設計されているか（必須）
 15. 自動化可否 — 手動テストのみでなく自動化できるか（推奨）
 
-**B-1/B-2チェック（2項目）**:
+**B-1/B-2チェック（コア帯 2 項目）**:
 16. B-1確認質問 — PBI INPUTの曖昧な箇所を確認質問で解消したか、または曖昧さがないことを確認したか（必須）
 17. B-2アプローチ比較 — 2案以上のアプローチを比較し、推薦案の選定理由を明記したか（必須）
 
+**コア帯外の項目（上記 1〜17 の連番に含まれない。正本テンプレート順）**:
+18. `C1-PLAN-08-AEE` — Stop Condition 記入（#544 Phase1）
+19. `C1-PLAN-09-AEE` — Replan Triggers 機械値（#544 Phase1）
+20. `C1-SUP-PLAN-01` — No Placeholders Rule
+21. `C1-SUP-PLAN-02` — Task Sizing Rules
+22. `C1-TODO-RB` — rollback（戻し手順）
+23. `C1-SEC-01` — 秘密情報 非接触（#578）
+24. `C1-SCOPE-DISC-01` — 発見事項の予防的分離（#578）
+25. `C1-UI-01` — UI デザインシステム準拠（#579・`is_ui_task` 時のみ）
+
+> 上記の列挙は本コマンド作成時点の写しであり、**項目の正本は
+> `docs/working/templates/review-self.md`**。判定は常に正本テンプレートの全項目に対して行う
+> （実測: `grep -c '^### C1-' docs/working/templates/review-self.md`）。項目は追加 PBI で
+> 増減するため、総数を本文へ契約値として複写しないこと。
+
 3. 各項目にPASS / WARN / FAILを判定
-4. `docs/working/templates/review-self.md` のschemaに従い `review-self.md` を生成（check_id付き構造化形式: C1-PLAN-01〜C1-B1B2-17）
+4. `docs/working/templates/review-self.md` のschemaに従い `review-self.md` を生成（check_id付き構造化形式。check_id は正本テンプレートの見出し ID と一致させる。`C1-PLAN-08-AEE` / `C1-TODO-RB` / `C1-SCOPE-DISC-01` のように**連番でない ID** を含むため、`C1-[A-Z]+-[0-9]+` 前提の正規表現で列挙しないこと）
    - FAIL時は `evidence/c1-review/{check_id}.md` にエビデンスを保存し、evidence_ref で参照
    - サマリーテーブル（PASS/WARN/FAIL件数）と自動修正ログテーブルを含める
 5. FAILがある場合はplan/todo/test-casesを自動修正してから次のステップへ
 6. `status.md` を更新（フェーズC-1完了を記録）
 7. `current-state.md` を更新（フェーズを `C-1` に、進捗を更新）
```
<!-- PG-PATCH-END -->

### 適用後にやること

1. `npx markdownlint-cli2 .claude/rules/mode-classification.md .claude/commands/ai-dev-workflow.md` を通す
2. `sh scripts/sync-plugin-plangate.sh` で `plugin/plangate/rules/mode-classification.md` / `plugin/plangate/commands/ai-dev-workflow.md` を追従させる（**手編集しない**）
3. §6 の残存検査（positive control 付き）を再実行し、①② が消えていることを確認する
4. `docs/ai/issue-governance.md` §9 に従い、適用 PR に `Refs: #960` を書く

---

## 6. 検証済みであること / 未検証であること

| 項目 | 状態 |
|---|---|
| 正本の実数 25（区分内訳 9/2/6/3/2/1/1/1） | ✅ 実測（§1） |
| 残存 2 箇所の行番号・現在の文言 | ✅ 実測（§1。`b3565b2`） |
| repo root で `git apply --check` rc=0 | ✅ 実測 |
| 残存検査 grep の **positive control** | ✅ 実測（既知の陽性＝本 patch 適用前の 2 行が検出されること） |
| 非 HO 分 3 ファイルの markdownlint | ✅ 実測（同 PR） |
| **適用後の実 `/ai-dev-workflow plan` 1 周** | ❌ **未検証**。列挙が増えたことで C-1 が実際に 25 項目を出力するかは、実セッション 1 周でしか測れない |
| `tests/run-tests.sh` 全体走行 | ❌ 未実施（本ワーカーの実行制約。本 patch は `.md` のみで、hook / CLI の挙動には非接触） |

### 残存検査（positive control 付き）

`git grep -E` は `\s` / `\b` を解釈しないため `-P` を使う。

**広い検査（`C1-PLAN-01`〜… の範囲表記すべて）は使えない**: 実測すると 16 件ヒットし、そのうち
12 件は `docs/working/templates/review-self.md:22,32` / `docs/ai-driven-development.md:578` /
`docs/plangate.md:128` とその plugin ミラーという **「17 とは何だったか」の正しい歴史的説明**である。
広い検査は False Positive で埋まって使えないため、**欠陥のある 2 つの文言そのもの**を検査する:

```sh
git grep -nP '(Plan 項目（`C1-PLAN-01`〜`07`）のみ|構造化形式: C1-PLAN-01〜C1-B1B2-17)' -- '*.md'
```

| 実測 | 結果 |
|---|---|
| **positive control**（本 patch 適用前・`b3565b2`） | **7 件**ヒット = ① `.claude/rules/mode-classification.md:170` / ② `.claude/commands/ai-dev-workflow.md:255` / それぞれの plugin ミラー 2 件 / `docs/working/_reports/960-{ho-patch,ho-patch-applicable,ac2-working-context-patch}.md` の **patch 文書内の引用 3 件** |
| **negative control** | `git grep -nP 'C1-ZZZZ-99' -- '*.md'` → rc=1（0 件）。検査器が常に 0 件を返しているわけではないことの確認 |
| **適用 + `sh scripts/sync-plugin-plangate.sh` 後の期待値** | **`docs/working/_reports/960-*.md` の patch 文書内引用のみ**（本書を含む）。正本 4 件が 0 になること |

patch 文書内の引用（`docs/working/_reports/960-*.md`）は diff の `-` 側として旧文言を保持する必要があるため
**恒久的に除外**する。検査で除外するときは `| grep -v '^docs/working/_reports/'` を付ける。

---

## 7. Human 判断事項（本 patch では扱わない）

### 7.1 light の C-1 適用範囲に「Plan 品質追加」2 項目を含めるか

正本テンプレートは「Plan」（9）と「Plan 品質追加（Superpowers 由来 / #581）」（2）を別区分にしている。
本 patch は **Plan 区分のみ（9）** とした（現状の「Plan 項目のみ」の素直な解釈）。
`C1-SUP-PLAN-01`（No Placeholders）/ `02`（Task Sizing）は light でも効きうる性質なので、
含める判断もありうる。含める場合は右セルを「Plan 区分 + Plan 品質追加（現行 11 項目）」に変える。
**挙動（light で実施する項目）が変わるため、#960 の scope 外の Human 決定。**

### 7.2 数の再発防止（#960 AC の最後の 1 件）

[`960-recurrence-guard-patch.md`](./960-recurrence-guard-patch.md) の機械検査案は「弱すぎて目的を外し、かつ広すぎて実用にならない」として棄却されている。
本書の §6 の検査は**番号範囲**に絞った狭い検査であり、総数の直書き全般は依然として捕まえられない。
実効性のある案は「正本テンプレート以外での **総数の直書きを禁止**し、`grep -c` の実測コマンドを書かせる」規約化だが、
mode 別マトリクスは具体数が要る場面があるため、例外の切り方を Human が決める必要がある。
