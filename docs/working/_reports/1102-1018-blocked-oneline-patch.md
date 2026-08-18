# #1102 + #1018 patch — **AI が到達できない 1 行修正 2 件**（**Human 適用**）

> 対象: `CLAUDE.md`（HO 対象パス）/ `docs/working/templates/plan.md`（basename が `plan.md` のため EH-3 が block）
> 測定基点: `origin/main` = `1e33b57` / 2026-08-18

## なぜ 2 件をまとめるか

**どちらも 1 行の修正で、どちらも AI が構造的に到達できません。** 阻害要因は異なりますが、**「規模ではなくパスで塞がれている」**という点で同型です。

| issue | 対象 | 阻害要因 |
|---|---|---|
| **#1102** | `CLAUDE.md` | **HO 9 カテゴリ**（`AGENTS.md` / `CLAUDE.md`） |
| **#1018** | `docs/working/templates/plan.md` | **basename が `plan.md`** → EH-3 の plan.md ガードが発火 |

**#1018 はテンプレートであり承認成果物ではありません**が、EH-3 は basename で判定するため区別されません（**#927 に「非対称 C」として報告済み**）。

---

# 第 1 部: #1102 — `CLAUDE.md` が**全セッションに誤った前提を配っている**

## 問題

`CLAUDE.md:16` は現在もこう書いています:

```
**既知の未解消ギャップ: EH-3 の HO 迂回（#1089）は patch と回帰テストのみ同梱し
hook 本体は未適用**（適用は `sh scripts/apply-eh3-ho-always.sh --apply` = Human-owned。
適用後は `tests/fixtures/eh3-known-gap-1089.flag` を削除すること）。
```

**これは事実に反します。**

### 実測（現 main）

| 主張 | 実測 |
|---|---|
| 「hook 本体は未適用」 | ❌ **PR #1097（`9043536`）で適用済み** |
| 「適用後は flag を削除すること」 | ❌ **`tests/fixtures/eh3-known-gap-1089.flag` は既に不在** |

```
$ git log --oneline origin/main --grep='1089'
9043536 fix(governance): EH-3 の Hardening Override を task_id 文脈に依存せず評価する (#1089) (#1097)

$ git show origin/main:tests/fixtures/eh3-known-gap-1089.flag
fatal: path ... does not exist
```

**記述が自分で定めた「適用済みの証拠」（flag の不在）が既に成立しています。** つまり **stale であるだけでなく自己矛盾**しています。

## なぜ最優先か

**`CLAUDE.md` は全 AI セッションの context に自動ロードされます。**

| 読者 | 誤読の結果 |
|---|---|
| **AI セッション** | 「**HO は現在素通りする**」と信じる。**HO 対象ファイルの編集を試みる**判断に傾く |
| Human | **既に不要な `apply-eh3-ho-always.sh --apply` を実行しようとする**（`--apply` は HO パスを書き換える**破壊的操作**） |
| 導入者 | v8.20.0 のリリースノートとして読み、main の状態を誤認 |

`README.md` / `README_en.md`（PR #1100 で「タグ時点では未解消 / main では #1097 で是正済み」へ是正済み）と **現在 main で矛盾**しています。

## 差分

`CLAUDE.md:16` の該当箇所を置き換えます。

```diff
-**既知の未解消ギャップ: EH-3 の HO 迂回（#1089）は patch と回帰テストのみ同梱し hook 本体は未適用**（適用は `sh scripts/apply-eh3-ho-always.sh --apply` = Human-owned。適用後は `tests/fixtures/eh3-known-gap-1089.flag` を削除すること）。
+**EH-3 の HO 迂回（#1089）は v8.20.0 タグには未収録のまま出荷したが、main では PR #1097 で是正済み**（`PLANGATE_HOOK_TASK` 設定時も HO 9 カテゴリが block される）。**ただし `Edit|Write` 経路に限る** — **`Bash` 経路にはガードが存在せず #1104 で追跡中**。正規化の不足（`..` / 大小文字 / `//` / `/./` / repo root 跨ぎ）は **#1101** で追跡中。
```

### 記述方針の根拠

1. **タグと main を区別する** — PR #1100 が `README` に対して採った形と揃えます（片方だけだとどちらかの読者が誤解します）
2. **`apply-eh3-ho-always.sh --apply` の案内と flag 削除の指示を削除** — **既に適用済みの patch を再適用させる危険**があります
3. **`Edit|Write` 限定であることを明示** — **#1104**（Bash 経路にガードなし）を踏まえ、**「HO は常時 block」という過大宣言を作らない**

> **3 は本セッションで確立した規範**です。PR #1106 が `hook-enforcement.md` に対して同じ書き分けを入れています。**`CLAUDE.md` だけが「常時 block」と読める状態を残さない**でください。

## 検証

```sh
# 1. stale 記述が残っていないこと
grep -c '未適用' CLAUDE.md                    # 期待: 0（#1089 文脈で）
grep -c 'eh3-known-gap-1089.flag' CLAUDE.md   # 期待: 0

# 2. 経路の限定が書かれていること
grep -cF 'Edit|Write' CLAUDE.md               # 期待: 1 以上
grep -c '#1104' CLAUDE.md                     # 期待: 1 以上

# 3. README / hook-enforcement.md と矛盾しないこと
grep -n 'PR #1097 で是正済み' README.md README_en.md
grep -n '#1104' docs/ai/hook-enforcement.md
```

---

# 第 2 部: #1018 — テンプレートから生成した plan が**必ず fail-closed する**

## 問題

```
docs/working/templates/plan.md:73   ## Files / Interfaces
scripts/ai-loop/plan_package.py     "Files / Components to Touch" を 3 箇所で参照
```

**テンプレートだけが外れ値**です。正本は `Files / Components to Touch` 側です:

| 参照元 | 見出し |
|---|---|
| `.claude/rules/working-context.md:187` | `Files / Components to Touch` |
| `scripts/ai-dev-plan.sh:168` | 同 |
| `scripts/ai-loop/plan_package.py` | 同（`_extract_section` が完全一致で探す） |
| `scripts/ai-loop/test_plan_package.py` | 同（fixture 5 箇所） |
| **`docs/working/templates/plan.md:73`** | **`Files / Interfaces`** ❌ |

## 影響

**テンプレートから素直に生成した `plan.md` は、Plan-first 正式入口（`bin/plangate ai-loop run TASK-XXXX`）の `derive_loopspec()` で必ず fail-closed します**（`extract_allowed_paths()` が空を返すため）。

> これは **#927 の「非対称 C」（ai-loop を起動できない）と地続き**です。本セッションで ai-loop を 3 回試み、3 回とも帯外で終わっています。

## 差分

```diff
-## Files / Interfaces
+## Files / Components to Touch
+
+> **見出しを変更しないこと。** ai-loop の Plan-first 入口が
+> `derive_loopspec()` → `extract_allowed_paths()` でこの見出し名を**完全一致で探す**。
+> 変えると `allowed_paths` が空になり **fail-closed** する（#1018）。
+> 正本: `.claude/rules/working-context.md` の「plan.md（EXECUTION PLAN）」節 /
+> 抽出器: `scripts/ai-loop/plan_package.py`
```

**同ファイル内の他 2 箇所**（`:221` / `:255`）も同じ語を使っています:

```diff
-- hidden dependency が見つかり、Work Breakdown または Files / Interfaces が変わる
+- hidden dependency が見つかり、Work Breakdown または Files / Components to Touch が変わる
```

```diff
-- [ ] TaskごとのFiles / Interfaces / Steps / Completion Criteriaが具体的
+- [ ] Taskごとの Files / Components to Touch / Steps / Completion Criteria が具体的
```

## 検証

```sh
# 1. 残存 0 件
grep -c 'Files / Interfaces' docs/working/templates/plan.md     # 期待: 0

# 2. 抽出器が実際に拾えること（**本 patch の主目的**）
python3 - <<'PY'
import sys; sys.path.insert(0, "scripts/ai-loop")
from plan_package import extract_allowed_paths
text = open("docs/working/templates/plan.md").read()
print("extracted:", extract_allowed_paths(text))
PY
#    期待: 空リストでない（テンプレの表に実パスが無ければ、
#          実 plan での確認に切り替える）

# 3. 実 plan での確認
#    既存の docs/working/TASK-*/plan.md のうち
#    `## Files / Components to Touch` を持つものを 1 本通す
```

### ⚠️ 手順 2 が空リストを返す場合

テンプレートの表は**プレースホルダ**なので、抽出器が実パスを見つけられない可能性があります。**その場合は「見出しが一致するようになった」ことまでを確認し、実 plan で最終検証**してください。**「空リストだから失敗」と即断しないこと。**

---

## 責務

| 作業 | 担当 |
|---|---|
| patch の作成・実測・検証手順 | **AI-owned**（本書） |
| **`CLAUDE.md` への適用** | **Human-owned**（HO 9 カテゴリ） |
| **`docs/working/templates/plan.md` への適用** | **Human-owned**（EH-3 の basename ガード） |

## この 2 件が示すこと（ハーネスへの示唆）

**どちらも 1 行の修正で、危険性はゼロに近い**にもかかわらず、**AI が構造的に到達できません**。

- **#1102** は HO 対象なので**設計どおり**です（`CLAUDE.md` は AI が自己改変してはならない）
- **#1018 は設計の副作用**です。テンプレートは承認成果物ではないのに、**basename マッチで巻き込まれています**

**#1018 のようなケースは、EH-3 の判定を「パス」ではなく「役割」に寄せれば解消します**（#927 の C-3 案 / #1104 の議論と同根）。

Refs #1102 / #1018 / #927 / #1104 / #1092
