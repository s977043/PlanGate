# #960 HO 分 patch — C-1 項目数表記の是正（**Human 適用**）

> 対象: **Hardening Override 対象 6 ファイル**。AI は編集できないため、**本書の差分を Human が適用**する。
> 前提: **PR #1118（非 HO 分 24 ファイル）が先にマージされていること**（正本節が `docs/working/templates/review-self.md` に存在する必要がある）。
> 測定基点: `origin/docs/960-c1-item-count-nonho` = `4e21fe4` / 2026-08-18

## なぜ必要か

C-1 セルフレビューの項目数が **「17 項目」と宣言されているが実体は 25 項目**で、内訳（`Plan 7 + ToDo 5 + TestCases 3 + 結合 2`）は**構成要素のどれ一つとして実態と一致していません**。

```
$ grep -c '^### C1-' docs/working/templates/review-self.md
25
内訳: PLAN 9 / SUP-PLAN 2 / TODO 6 / TEST 3 / B1B2 2 / SEC 1 / SCOPE-DISC 1 / UI 1
```

「17」は歴史的なコア番号帯（`C1-PLAN-01`〜`C1-B1B2-17` の連番 17 個）の**通称**で、総数ではありません。現場は **15 / 17 / 20 / 25 の 4 通り**で回避しており、**「何項目やれば C-1 完了か」が実行者依存**になっています。

## 適用方針（PR #1118 と同じ）

1. **総数を再定義しない** — `docs/working/templates/review-self.md` の「C-1 チェック項目数（正本）」節を参照させる
2. **図・カタログ・表の見出しは数値を落とす**（drift 源を増やさない）
3. **「17」が歴史的コア帯の通称として意味を持つ文脈**は、数値を残して**通称であることを明記**
4. **総数を契約値として複写しない**

---

## 適用手順

```sh
# 1. PR #1118 がマージ済みであることを確認
git log --oneline origin/main | grep -q '17 項目' && echo "確認: #1118 系がマージ済み"

# 2. 下記 6 ファイルを編集（本書の差分どおり）

# 3. export ミラー 5 件を同期で追従させる
sh scripts/sync-plugin-plangate.sh

# 4. 検証
git grep -lE '17[[:space:]]*項目' | grep -vE '^docs/working/(TASK-|discussions/)'
#    期待: 歴史記録 2（CHANGELOG.md / docs/changelog.md）
#          + アーカイブ 1（docs/working/retrospective-2026-04-28.md）
#          + 正本の用語説明 1（docs/working/templates/review-self.md）
#          = 4 件のみ

sh scripts/sync-plugin-plangate.sh --dry-run   # rc=0 / drift なし
sh tests/run-tests.sh                          # 新規 FAIL がないこと
```

> ⚠️ **`git grep -lE '17\s*項目'` は使わないこと。** git の ERE では `\s` が空白クラスとして解釈されず、**`17 項目`（半角空白あり）を取りこぼします**（本 PBI で実際に発生し、scope を約半分に見誤りました）。**必ず `[[:space:]]` を使ってください。**

---

## 差分

### 1. `.claude/rules/mode-classification.md`（3 箇所）

**L98** — Lite ゲート構成の比較表

```diff
-| C-1 | 17 項目 | 17 項目（不変）|
+| C-1 | 全項目 | 全項目（不変）|
```

> ここは「**Lite でも C-1 を減らさない**」という規範が主題で、数値は本質ではありません。数値を持たせると項目追加のたびに drift します。

**L153** — フェーズ適用マトリクス

```diff
-| **C-1 セルフレビュー** | - | △（Plan 7項目のみ） | ○（17項目） | ○（17項目） | ○（17項目） |
+| **C-1 セルフレビュー** | - | △（Plan 項目のみ） | ○（全項目） | ○（全項目） | ○（全項目） |
```

**L170** — 簡易版の定義

```diff
-| C-1 | 17項目チェック | Plan 7項目（C1-PLAN-01〜07）のみ |
+| C-1 | 全項目チェック（正本: [`docs/working/templates/review-self.md`](../../docs/working/templates/review-self.md)） | Plan 項目（`C1-PLAN-01`〜`07`）のみ |
```

### 2. `.claude/rules/working-context.md`（1 箇所）

**L19** — ワークフロー図（code fence 内なのでリンクは効かない → 数値を落とす）

```diff
-  → C-1: セルフレビュー 🤖（17項目チェック）
+  → C-1: セルフレビュー 🤖（全項目チェック）
```

### 3. `.claude/commands/README.md`（1 箇所）

**L19**

```diff
-# Plan生成 → セルフレビュー（17項目）→ 外部AIレビュー（一括自動実行）
+# Plan生成 → セルフレビュー → 外部AIレビュー（一括自動実行）
```

### 4. `.claude/commands/ai-dev-workflow.md`（3 箇所）

**L14**

```diff
-- `TASK-XXXX plan` — フェーズB〜C-2: Plan + ToDo + Test Cases生成 → セルフレビュー（17項目）→ 外部AIレビュー → 指摘反映（一括自動実行）
+- `TASK-XXXX plan` — フェーズB〜C-2: Plan + ToDo + Test Cases生成 → セルフレビュー → 外部AIレビュー → 指摘反映（一括自動実行）
```

**L199**

```diff
-2. 以下の17項目をチェック:
+2. 以下をチェック（項目定義の正本: `docs/working/templates/review-self.md`）:
```

**L253**

```diff
-   - C-1結果（PASS/WARN/FAIL件数、17項目）
+   - C-1結果（PASS/WARN/FAIL件数、全項目）
```

### 5. `.claude/agents/workflow-conductor.md`（2 箇所）

**L262**

```diff
-| C-1 | - | △(7項目) | ○(17項目) | ○(17項目) | ○(17項目) |
+| C-1 | - | △(Plan 項目) | ○(全項目) | ○(全項目) | ○(全項目) |
```

**L471**

```diff
-| C-1 | diff-audit skill（17項目チェック） | plan + todo + test-cases + pbi-input |
+| C-1 | diff-audit skill（全項目チェック） | plan + todo + test-cases + pbi-input |
```

### 6. `schemas/review-result.schema.json`（1 箇所）

**L42** — `description` の散文

```diff
-      "description": "phase 固有スコア（C-1 の 17 項目等、任意）",
+      "description": "phase 固有スコア（C-1 の各項目等、任意）",
```

> **契約値ではないことを実測で確認済み**: 本 schema と `review-self.schema.json` に項目数を拘束する `minItems` / `const` は**存在せず**、`scripts/` / `tests/` / `bin/` / `.github/workflows/` から機械参照している箇所も**ありません**。したがって `description` の散文表現として安全に変更できます。

---

## 適用後に自動追従するもの（**手で編集しないこと**）

`sh scripts/sync-plugin-plangate.sh` が以下 5 件を再生成します。

```
plugin/plangate/rules/mode-classification.md
plugin/plangate/rules/working-context.md
plugin/plangate/commands/README.md
plugin/plangate/commands/ai-dev-workflow.md
plugin/plangate/agents/workflow-conductor.md
```

## 対象外（意図的に残す）

| ファイル | 理由 |
|---|---|
| `CHANGELOG.md` / `docs/changelog.md` | **歴史記録**。当時の記述として正しい |
| `docs/working/retrospective-2026-04-28.md` | アーカイブ性質 |
| `docs/working/templates/review-self.md` | **正本側の用語説明**（「17 は歴史的コア帯の通称」）そのもの |
| `docs/working/TASK-*` / `docs/working/discussions/` （100 ファイル） | 過去 PBI のアーカイブ |

## 責務

| 作業 | 担当 |
|---|---|
| 本 patch の作成・検証手順の提示 | **AI-owned**（本書） |
| **6 ファイルへの適用** | **Human-owned**（HO 対象パス） |
| 適用後の `sync` 実行・検証 | Human（または適用後のセッションで AI） |

Refs #960 / #1092
