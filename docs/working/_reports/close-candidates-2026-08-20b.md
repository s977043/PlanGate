# close 候補の深掘り（2026-08-20b）— base `origin/main` = `e52118b`

> 目的: **open issue を実際に減らす**。close 候補 7 件（#863 / #866 / #960 / #1018 / #954 / #1078 / #1170）を
> **issue 本文の AC 単位**で `origin/main` の実体と照合し、close 可否を確定する。
>
> **前回（PR #1191 / #1192 / #1193）は base `684949e` で測ったもので、統合実行計画自身の停止条件 S-1
> （main が 5 commit 以上進んだ）が発火して stale**。本書は全項目を `e52118b` で再測定した。
>
> 測定原則: すべて `git show origin/main:<path>` / `git grep <pat> origin/main -- <path>` /
> `git ls-tree -r origin/main` で ref 明示。作業ツリーの `ls` / `grep` は使っていない。
> 空出力は必ず陽性コントロールで grep の起動を確認してから「0 件」と書いた。

---

## 1. サマリ

| issue | 分類 | 実行層 | close 可否 | 1 行根拠（`e52118b` 実測） |
|---|---|---|---|---|
| **#866** | **CLOSE-NOW** | — | ✅ **今すぐ close 可** | 3 root（`.agents` / `.claude` / `plugin`）の当該 2 SKILL.md が **blob 完全一致**（`9bd3049` / `f51d027`）、正本宣言も `.agents/skills/` に統一済み。三つ巴は解消 |
| **#960** | **CLOSE-AFTER-1** | **L3**（Human 適用） | あと 1 手 | 正本 16 件は残存 0。残るのは **HO 6 ファイル + そのミラー 5 + 履歴 2 = 13 件**のみで、patch は `_reports/960-ho-patch.md` に整備済み |
| **#1018** | **CLOSE-AFTER-1** | **L2**（`PLANGATE_HOOK_TASK` セッション） | あと 1 手 | テンプレは今も `## Files / Interfaces`（3 箇所）、抽出器は `Files / Components to Touch`。**実際に `extract_allowed_paths()` が `[]` を返すことを再現済み**。patch は `_reports/1102-1018-blocked-oneline-patch.md` 第 2 部に完備 |
| **#863** | **SCOPE-DECISION** | **L1**（残 1 ファイル）+ **L3**（切り出し分） | scope を絞れば close 可 | AC-1 / AC-2 / AC-3 前半は充足。**未充足は AC-3 後半（`plugin/plangate/skills/README.md` の 1 箇所）と AC-4（HO 3 ファイルの patch 未作成）**のみ |
| **#954** | **PARTIAL**（+ SCOPE-DECISION 提案） | **LH**（#956 の裁定） | ❌ | クラス A / A' / C は `.agents` と `plugin` で **残存 0**。未充足は **AC-3 の `.codex/skills`（クラス C 注記が 13 ファイル欠落）** と **AC-5（marketplace 実測）** |
| **#1078** | **PARTIAL** | **LH**（設計判断）+ L3 | ❌ | **AC-1 未充足**（`.codex/hooks.json` に `check-approval-token-write` は **0 件**）、**AC-2 未充足**（`.agents` vs `.codex` の SKILL.md 差分 **33 本**）、**AC-3 未充足**（`docs/release-process.md` に codex の語が 0 件）。充足は AC-4 のみ |
| **#1170** | **PARTIAL / BLOCKED** | **LH**（#956 = OPEN） | ❌ | issue 記載の 2 症状が**両方とも未解消のまま**（クラス A 梯子 0/4、ai-loop CLI 注記 0）。issue 本文自身が「#956 の判断待ち」と宣言しており、#956 は現在も OPEN |

**内訳**: CLOSE-NOW **1 件**（#866） / CLOSE-AFTER-1 **2 件**（#960 / #1018） / SCOPE-DECISION **1 件**（#863） / PARTIAL **3 件**（#954 / #1078 / #1170）。

**7 件すべてを扱った。** 扱えなかったものはない。

---

## 2. CLOSE-NOW — #866 の close コメント本文（そのまま投稿可）

> ### 実測により解消を確認したため close します（`origin/main` = `e52118b` / 2026-08-20）
>
> 本 issue の「正本宣言が三つ巴で矛盾」は、**修正案 1〜3 のすべてが充足**しています。
>
> #### 修正案 1: `.claude/skills/` の新版内容が `.agents/skills/` 正本へ反映されているか → ✅
>
> ```sh
> $ git diff --stat origin/main:.claude/skills/intent-classifier/SKILL.md \
>                   origin/main:.agents/skills/intent-classifier/SKILL.md
> （出力なし = 差分ゼロ）
>
> $ git diff --stat origin/main:.claude/skills/skill-policy-router/SKILL.md \
>                   origin/main:.agents/skills/skill-policy-router/SKILL.md
> （出力なし = 差分ゼロ）
> ```
>
> 「旧版（7 分類）」ではなく **新版（Intent 8 分類 + `exploratory`）** 側に揃っていることも実測しました。
>
> ```sh
> $ git grep -c 'exploratory' origin/main -- \
>     .agents/skills/intent-classifier/SKILL.md \
>     .agents/skills/skill-policy-router/SKILL.md \
>     plugin/plangate/skills/intent-classifier/SKILL.md
> origin/main:.agents/skills/intent-classifier/SKILL.md:3
> origin/main:.agents/skills/skill-policy-router/SKILL.md:2
> origin/main:plugin/plangate/skills/intent-classifier/SKILL.md:3
> ```
>
> ```sh
> $ git grep -n 'Intent 8 分類' origin/main -- .agents/skills/intent-classifier/SKILL.md
> origin/main:.agents/skills/intent-classifier/SKILL.md:186:intent-classifier は **Intent 8 分類のみ**を担う。…
> ```
>
> #### 修正案 2: sync で `plugin/plangate/skills/` へ伝播しているか → ✅
>
> **blob ハッシュが 3 root で完全一致**しています（内容一致より強い証拠です）。
>
> ```sh
> $ git ls-tree origin/main -- .agents/skills/intent-classifier/SKILL.md \
>     .claude/skills/intent-classifier/SKILL.md \
>     plugin/plangate/skills/intent-classifier/SKILL.md
> 100644 blob 9bd30492bb490e721527a1455aca7729835ccf70 .agents/skills/intent-classifier/SKILL.md
> 100644 blob 9bd30492bb490e721527a1455aca7729835ccf70 .claude/skills/intent-classifier/SKILL.md
> 100644 blob 9bd30492bb490e721527a1455aca7729835ccf70 plugin/plangate/skills/intent-classifier/SKILL.md
>
> $ git ls-tree origin/main -- .agents/skills/skill-policy-router/SKILL.md \
>     .claude/skills/skill-policy-router/SKILL.md \
>     plugin/plangate/skills/skill-policy-router/SKILL.md
> 100644 blob f51d02780965b50900b3b18770476f1902453135 .agents/skills/skill-policy-router/SKILL.md
> 100644 blob f51d02780965b50900b3b18770476f1902453135 .claude/skills/skill-policy-router/SKILL.md
> 100644 blob f51d02780965b50900b3b18770476f1902453135 plugin/plangate/skills/skill-policy-router/SKILL.md
> ```
>
> #### 修正案 3: 正本宣言行が実態（`.agents/skills/` が sync 正本）に是正されているか → ✅
>
> 起票時に問題だった「plugin 版が『正本: `.claude/skills/…`』と自己宣言」は消えています。
>
> ```sh
> $ git grep -n '正本（sync 元）' origin/main -- \
>     .agents/skills/intent-classifier/SKILL.md \
>     plugin/plangate/skills/intent-classifier/SKILL.md \
>     .agents/skills/skill-policy-router/SKILL.md \
>     plugin/plangate/skills/skill-policy-router/SKILL.md
> …:.agents/skills/intent-classifier/SKILL.md:8:> 正本（sync 元）: `.agents/skills/intent-classifier/SKILL.md`。`scripts/sync-plugin-plangate.sh` が
> …:plugin/plangate/skills/intent-classifier/SKILL.md:8:> 正本（sync 元）: `.agents/skills/intent-classifier/SKILL.md`。…
> …:.agents/skills/skill-policy-router/SKILL.md:8:> 正本（sync 元）: `.agents/skills/skill-policy-router/SKILL.md`。…
> …:plugin/plangate/skills/skill-policy-router/SKILL.md:8:> 正本（sync 元）: `.agents/skills/skill-policy-router/SKILL.md`。…
> ```
>
> 本文で挙がっていた論点「sync が `.claude/skills/` を読まない現行設計との整合」も、
> **「`.agents/skills/` を sync 正本とし、`.claude/skills/` は同内容を保つ」**で決着しています。
>
> #### 残る `.codex/skills` の drift は本 issue のスコープ外です
>
> `.codex/skills` 側の当該 2 ファイルは今も別 blob です。
>
> ```sh
> $ git ls-tree origin/main -- .codex/skills/intent-classifier/SKILL.md \
>     .codex/skills/skill-policy-router/SKILL.md
> 100644 blob cf5df440732f19c646b85bbff1078ea545e7d299 .codex/skills/intent-classifier/SKILL.md
> 100644 blob c847b2cbf84cccdd581663e533125726477dc80e .codex/skills/skill-policy-router/SKILL.md
> ```
>
> ただし本 issue が対象にしたのは `.claude/skills` / `.agents/skills` / `plugin/plangate/skills` の
> **三つ巴**であり、`.codex/skills` の drift は **#956 / #1170 が所有**しています。
> 正本側も「`.codex/skills/` は sync 対象外の配布先のため、正本更新時に同一内容を手動で追従させる」
> （`.agents/skills/intent-classifier/SKILL.md:10`）と明記済みです。
>
> **→ 本 issue の 3 項目は全充足のため close します。`.codex` の追従は #956 / #1170 で追跡。**

---

## 3. CLOSE-AFTER-1 の「1 手」

### 3-1. #960 — 「C-1 が 17 表記のまま実体 25」

**誰が**: Human（HO パスのため AI は編集不可）
**何を**: `docs/working/_reports/960-ho-patch.md` の差分を適用し、続けて `sh scripts/sync-plugin-plangate.sh` を実行
**どのファイルに / 何行**: **6 ファイル・11 箇所**（patch 本文の `### 1`〜`### 6`）

| # | ファイル | 残存箇所（`e52118b` 実測の行） |
|---|---|---|
| 1 | `.claude/rules/mode-classification.md` | L98 / L153 / L170（3） |
| 2 | `.claude/rules/working-context.md` | L19（1） |
| 3 | `.claude/commands/README.md` | L19（1） |
| 4 | `.claude/commands/ai-dev-workflow.md` | L14 / L199 / L253（3） |
| 5 | `.claude/agents/workflow-conductor.md` | L262 / L471（2） |
| 6 | `schemas/review-result.schema.json` | L42（1） |

適用後、sync が `plugin/plangate/{rules,commands,agents}` の **5 ミラー**を自動追従させる。

#### AC 照合

| AC | 判定 | 実測 |
|---|---|---|
| 正となる項目数の方針が決定・根拠が記録 | ✅ | `docs/working/templates/review-self.md:15` に `## C-1 チェック項目数（正本）` 節。「現行は **全 25 項目**」+ 区分別内訳表 + 「『17 項目』は歴史的なコア番号帯の通称」 |
| mode 別適用範囲が実体と整合 | ❌ | `.claude/rules/mode-classification.md:153` が今も `△（Plan 7項目のみ）` / `○（17項目）`。**HO patch の `### 1` が該当** |
| ② 正本 16 ファイルの表記統一 | ✅ | 下記の残存全数照合に `.agents/skills/**` / `docs/**`（changelog を除く）は 1 件も現れない。例: `.agents/skills/plan-review-gate/SKILL.md:42` は「正本とする（現行 全 25 項目）」へ是正済み |
| ③ 同期派生 12 ファイルが sync 経由で追従 | ⚠️ | 追従先のうち **5 件が未追従**だが、**原因は生成元（HO）が未適用だから**であり因果は正しい。HO 適用 + sync で同時に解消する |
| ① HO 対象の差分が Human 適用可能な形で提示 | ✅ | `docs/working/_reports/960-ho-patch.md`（適用手順・検証コマンド・drift を増やさない方針つき） |
| `docs/working/` が変更されていない | ✅ | 是正は `.agents/skills` / `docs/**` / テンプレート正本節に限定（テンプレート追加は方針そのもの） |
| 再発防止策が決定・記録 | ✅ | `docs/working/_reports/960-recurrence-guard-patch.md`。**変異注入で「最初の設計は退行を検出できなかった」ことまで記録**されている（`tests/extras/` への実装は未適用 = L2） |

**残存の全数照合**（件数だけでなく集合を列挙）

```sh
$ git grep -l -E '17[[:space:]]*項目|17項目' origin/main -- '*.md' ':!docs/working'
origin/main:.claude/agents/workflow-conductor.md
origin/main:.claude/commands/README.md
origin/main:.claude/commands/ai-dev-workflow.md
origin/main:.claude/rules/mode-classification.md
origin/main:.claude/rules/working-context.md
origin/main:CHANGELOG.md
origin/main:docs/changelog.md
origin/main:plugin/plangate/agents/workflow-conductor.md
origin/main:plugin/plangate/commands/README.md
origin/main:plugin/plangate/commands/ai-dev-workflow.md
origin/main:plugin/plangate/rules/mode-classification.md
origin/main:plugin/plangate/rules/working-context.md

$ git grep -n -E '17[[:space:]]*項目|17項目' origin/main -- ':!docs/working' ':!*.md'
origin/main:schemas/review-result.schema.json:42:      "description": "phase 固有スコア（C-1 の 17 項目等、任意）",
```

**= HO 6（md 5 + schema 1） + plugin ミラー 5 + 履歴 2（`CHANGELOG.md` / `docs/changelog.md`）= 13 件。**
履歴 2 件は patch 本文で **不改変**と決めているため、**HO 適用 + sync で残存は履歴 2 件のみになる**。

> ⚠️ patch 本文の警告どおり `\s` ではなく `[[:space:]]` を使っている。git の ERE は `\s` を空白クラスとして解釈せず、**半角空白入りの「17 項目」を取りこぼす**。

---

### 3-2. #1018 — plan テンプレの見出しが抽出器と不一致

**誰が**: AI（ただし `PLANGATE_HOOK_TASK` を設定して**起動した**セッションが必要）または Human
**何を**: `docs/working/_reports/1102-1018-blocked-oneline-patch.md` **第 2 部**の差分を適用
**どのファイルに / 何行**: `docs/working/templates/plan.md` の **3 箇所**

| 箇所 | 変更 |
|---|---|
| `## Files / Interfaces`（見出し） | → `## Files / Components to Touch` + 「見出しを変更しないこと」の契約注記 blockquote（5 行） |
| Replan Triggers 節の「Work Breakdown または Files / Interfaces が変わる」 | → `Files / Components to Touch` |
| C-1 Self Review Checklist の「TaskごとのFiles / Interfaces / Steps …」 | → `Files / Components to Touch` |

**なぜ AI が今すぐ着手できないか**: EH-3 は **basename で判定する**ため、`docs/working/templates/plan.md`
はテンプレート（＝承認成果物ではない）にもかかわらず plan.md ガードに巻き込まれる。**L2**。

**AC 照合**（本 issue は AC チェックリストを持たないため、症状・影響・方針の 3 点で照合）

| 項目 | 判定 | 実測 |
|---|---|---|
| 症状（テンプレの見出しが抽出器と不一致） | ❌ 未解消 | 下記 |
| 影響（テンプレ由来 plan が fail-closed する） | ❌ 未解消 | 下記（**実際に再現**） |
| 方針（A/B/C のいずれか + 契約の明文化） | ✅ 決定済み | patch は **案 A（テンプレを揃える）+ 契約注記の本文埋め込み**を採用し、正本と抽出器を名指ししている |

```sh
$ git show origin/main:docs/working/templates/plan.md | grep -n '^## '
16:## Goal
20:## Context
29:## Scope
41:## Global Constraints
48:## 前提の実測検証（#786）
58:## Questions / Unknowns（#786）
62:## Approach Comparison
73:## Files / Interfaces          ← ここ
80:## Work Breakdown
…

$ git grep -n 'Files / Components to Touch' origin/main -- scripts/ai-loop/plan_package.py
origin/main:scripts/ai-loop/plan_package.py:181:    """plan.md 本文の `## Files / Components to Touch` からパスを抽出する純関数。
origin/main:scripts/ai-loop/plan_package.py:194:    section = _extract_section(plan_text, "Files / Components to Touch")
origin/main:scripts/ai-loop/plan_package.py:224:            ["derive: `## Files / Components to Touch` からパスを抽出できない"])

$ git grep -c 'Files / Interfaces' origin/main -- docs/working/templates/plan.md
origin/main:docs/working/templates/plan.md:3
```

**抽出器を実物のまま読み込んで再現**（worktree HEAD = `e52118b` = `origin/main` を実測済み）:

```sh
$ python3 -c "import sys;sys.path.insert(0,'scripts/ai-loop');import plan_package as pp;\
t=open('docs/working/templates/plan.md').read();\
print('section=',pp._extract_section(t,'Files / Components to Touch'));\
print('paths=',pp.extract_allowed_paths(t));\
print('POSCTRL=',(pp._extract_section(t,'Files / Interfaces') or '')[:60])"
section= None
paths= []
POSCTRL= | ファイル | 操作 | 目的 | 公開インターフェース / 依存 |
```

**陽性コントロール**（3 行目）が空でないことで、`_extract_section()` 自体は正常に動作しており
**「見出し名が違うから拾えない」という因果が確定**している（空振り検出器ではない）。

> ⚠️ patch 本文の但し書きどおり、適用後に `extract_allowed_paths()` が空リストを返しても即断しないこと。
> テンプレの表はプレースホルダなので、**「見出しが一致するようになった」ことまでを確認し、実 plan で最終検証**する。

---

## 4. SCOPE-DECISION の提案

### 4-1. #863 — CLI 依存スキルの graceful degradation + 表記統一

**提案: AC-1 / AC-2 / AC-3 の充足をもって close し、AC-4（HO 3 ファイルの patch）を follow-up として切り出す。**

`docs/working/TASK-0863/pbi-input.md` が issue 本文を AC-1〜AC-6 に構造化しており、これを正本として照合した。

| AC | 判定 | 実測 |
|---|---|---|
| **AC-1** degrade 節（正本 9 本） | ✅ | 9 本すべてに「CLI 不在時のフォールバック」節または「CLI 呼び出し」節が存在。`ai-dev-plan:173` / `ai-dev-exec:116` / `ai-dev-verify:124` / `plan-review-gate:91` / `manual-cloud-task:76` / `ai-dev-brainstorm:80` は `### CLI 不在時のフォールバック（導入先では既定）`、`intent-classifier:76` は `### CLI 不在時の degrade`、`local-exec-handoff:69` / `working-context:75` は `## CLI 呼び出し`（3 環境の対応表 = fallback 列つき）、`skill-policy-router:130` は intent-classifier への正本ポインタ。**「ゲートの厳密な強制には CLI + hooks が必要」**も `intent-classifier:88` / `plan-review-gate:93` に明記 |
| **AC-2** 表記統一 | ✅（採用形が変わった） | 「全置換」ではなく **「上流リポジトリの cwd / 導入先で PATH / CLI 無し」の 3 列表**を各 skill に置く形を採用。残存 `bin/plangate` は**全数が意図的注記**（表の第 1 列 = 上流 cwd 列、または「`bin/plangate` ではない」という注意書き）であることを `git grep -n 'bin/plangate' origin/main -- '.agents/skills/*/SKILL.md'` の全 47 行で確認した |
| **AC-3 前半** plugin README の依存列挙 | ✅ | README の再現コマンドを ref 明示で実行し、**スナップショットと完全一致**（下記） |
| **AC-3 後半** `plugin/plangate/skills/README.md` の是正 | ❌ | **未充足**（下記） |
| **AC-4** HO 3 ファイルの patch 提示 | ❌ | **patch が存在しない**（下記） |
| **AC-5** sync dry-run 差分ゼロ | 未確認 | `sync-plugin-plangate.sh` は実行禁止のため未実測。ただし当該 skill 群の blob は `.agents` と `plugin` で一致している |
| **AC-6** `sh tests/run-tests.sh` PASS | 未確認 | 本調査では実行していない（テスト実行はスコープ外・時間的制約） |

#### AC-3 前半の実測（README の再現コマンドを ref 指定で実行）

```sh
$ git grep -l 'bin/plangate' origin/main -- \
    'plugin/plangate/commands/*.md' 'plugin/plangate/skills/*/SKILL.md' 'plugin/plangate/agents/*.md'
origin/main:plugin/plangate/agents/setup-coordinator.md
origin/main:plugin/plangate/agents/workflow-conductor.md
origin/main:plugin/plangate/commands/plangate-setup.md
origin/main:plugin/plangate/skills/ai-dev-exec/SKILL.md
origin/main:plugin/plangate/skills/ai-dev-plan/SKILL.md
origin/main:plugin/plangate/skills/ai-dev-verify/SKILL.md
origin/main:plugin/plangate/skills/ai-loop-cycle/SKILL.md
origin/main:plugin/plangate/skills/intent-classifier/SKILL.md
origin/main:plugin/plangate/skills/local-exec-handoff/SKILL.md
origin/main:plugin/plangate/skills/plan-review-gate/SKILL.md
origin/main:plugin/plangate/skills/plangate-setup/SKILL.md
origin/main:plugin/plangate/skills/skill-policy-router/SKILL.md
origin/main:plugin/plangate/skills/working-context/SKILL.md
```

**コマンド 1 / スキル 10 / エージェント 2** = `plugin/plangate/README.md:46-48` のスナップショット
（`plangate-setup` / `ai-dev-exec` `ai-dev-plan` `ai-dev-verify` `ai-loop-cycle` `intent-classifier`
`local-exec-handoff` `plan-review-gate` `plangate-setup` `skill-policy-router` `working-context` /
`setup-coordinator` `workflow-conductor`）と**集合が完全一致**。
README は「**正は再現コマンドの出力**」「**件数は契約値として扱わないでください**」と明記しており、
成長するディレクトリに絶対件数を固定しない形になっている（#1182 / #1183 の是正）。

#### AC-3 後半の未充足（＝これが「あと 1 手」の L1 分）

`.agents/skills/README.md` は是正済みだが、`plugin/plangate/skills/README.md` は**同じ blockquote を持っていない**。

```sh
$ git diff --stat origin/main:.agents/skills/README.md origin/main:plugin/plangate/skills/README.md
 {.agents => plugin/plangate}/skills/README.md | 44 ++++++++++-----------------
 1 file changed, 16 insertions(+), 28 deletions(-)

$ git grep -n 'bin/plangate' origin/main -- 'plugin/plangate/skills/README.md'
origin/main:plugin/plangate/skills/README.md:19:Codex CLI の標準入口は `./scripts/ai-dev-workflow …`。verify 系は `bin/plangate validate|review|eval|metrics TASK-XXXX` を併用する。
origin/main:plugin/plangate/skills/README.md:74:本リポジトリ自身の運用では同等機能を rules / workflow / bin/plangate が担うため
```

`.agents/skills/README.md` 側の対応箇所（L19 の直後）には次の blockquote がある:

> **上記 2 つの相対パス表記は、上流リポジトリ（`s977043/plangate`）を clone した cwd
> でのみ成立する**（`scripts/**` / `bin/**` は install / plugin / Codex のどの経路でも
> 導入先に配布されない）。導入先で PATH を通した場合のコマンド名は **`plangate`**
> （`bin/plangate` ではない）。**環境ごとの表記と CLI 不在時の degrade 手順は
> 各 skill の「CLI 呼び出し」節を正本とする**（ここでは再定義しない）。

**1 手（L1・AI が今すぐ着手可）**: `plugin/plangate/skills/README.md` の L19 直後に**この blockquote を逐語で追加**する（+7 行、削除 0）。
このファイルは pbi-input で「sync skip 対象の独立実体」と明記されており、**直接編集が正しい経路**。

#### AC-4 の未充足（＝切り出す follow-up）

HO 3 ファイルは今も相対パス表記のままで、degrade / PATH 注記を持たない。

```sh
$ git grep -n -i 'CLI 不在\|CLI が無い\|degrade\|PATH を通し' origin/main -- \
    .claude/commands/plangate-setup.md .claude/agents/setup-coordinator.md .claude/agents/workflow-conductor.md
（出力なし）

# 陽性コントロール（grep が起動していることの確認）
$ git grep -n 'bin/plangate' origin/main -- \
    .claude/commands/plangate-setup.md .claude/agents/setup-coordinator.md .claude/agents/workflow-conductor.md
origin/main:.claude/agents/setup-coordinator.md:35:## bin/plangate 不在時のフォールバック
origin/main:.claude/agents/setup-coordinator.md:37: … `command -v bin/plangate` で存在確認する。…
origin/main:.claude/agents/setup-coordinator.md:63,86,107,165
origin/main:.claude/agents/workflow-conductor.md:545,549
origin/main:.claude/commands/plangate-setup.md:7,23,25
```

patch も存在しない:

```sh
$ git ls-tree -r --name-only origin/main -- docs/working/TASK-0863
docs/working/TASK-0863/pbi-input.md          ← patches/ は無い
```

> **注意（前回判定との差）**: `setup-coordinator.md:35` は「`bin/plangate` 不在時のフォールバック」節を
> **既に持っている**。ただし内容は「clone を案内して停止」であり、**#863 が要求する
> 「PATH 解決名 `plangate` の併記」と「CLI 無しでの degrade 手順」ではない**。
> したがって AC-4 は未充足のままだが、**実害は 3 ファイル中もっとも小さい**。

#### 切り出す follow-up の内容（提案）

- タイトル案: `docs(agents): HO 3 ファイルの bin/plangate 表記に PATH 解決名と CLI 不在時の degrade を併記（#863 AC-4 の切り出し）`
- 対象: `.claude/commands/plangate-setup.md`（3 箇所）/ `.claude/agents/setup-coordinator.md`（8 出現・6 行）/ `.claude/agents/workflow-conductor.md`（2 箇所）
- 責務: **AI は patch 作成まで（AI-owned）/ 適用は Human-owned**（HO 9 カテゴリ）
- 適用後に `sh scripts/sync-plugin-plangate.sh` で `plugin/plangate/{commands,agents}` へ伝播
- **#960 の HO patch と同じ 3 ファイルのうち 2 つ（`commands/plangate-setup.md` は #960 対象外）に触るため、#960 の HO 適用と同一セッションでまとめるのが効率的**

---

### 4-2. #954 — 導入先で解決できない rules / docs 参照（クラス A / C）

**分類は PARTIAL。ただし scope を絞れば close 可能なので、その提案も併記する。**

| AC | 判定 | 実測 |
|---|---|---|
| **AC-1** クラス A のフォールバック順明記 | ✅ | 下記 |
| **AC-2** クラス C の解決方式決定 + 判断根拠 | ✅ | PR #1184 / #1195 の本文で「`ai-loop-cycle` 方式（bundled references）ではなくフォールバック明記」を採用した理由と、`docs/**` は sync の設計上 plugin 配布対象外のため **plugin root 段を書かない**（#1158 の是正を復活させない）ことが記録されている |
| **AC-3** 正本 `.agents/skills` を編集し `.codex/skills` と `plugin/plangate/skills` を同期スクリプト経由で再生成（手編集ゼロ） | ❌ | **`plugin` 側は充足だが `.codex/skills` が未追従**（下記）。さらに **PR #1194 は `.codex/skills/ai-dev-exec/SKILL.md` を手編集**しており「手編集ゼロ」に反する（PR 本文で意図的な先行是正と明記） |
| **AC-4** `sh tests/run-tests.sh` が baseline（453 passed / 0 failed）維持 | 未確認 | 本調査では実行していない |
| **AC-5** 3 クラスすべてを marketplace 経由の環境で 1 件以上実測 | 未確認 → 実質未充足 | marketplace 経由の実測証跡を `docs/working/` 配下に見つけられなかった。**「見つけられなかった」であり「存在しない」と断定はしない** |

**AC-1 の実測（クラス A）** — `.agents/skills` の rules 参照ファイル集合と、梯子を持つファイル集合が**完全一致**:

```sh
git grep -l -E '\.claude/rules/|\.\./\.\./rules/' origin/main -- '.agents/skills'   # 19 ファイル
git grep -l 'CLAUDE_PLUGIN_ROOT'                  origin/main -- '.agents/skills'   # 同一の 19 ファイル
```

集合（19）: `acceptance-review` / `ai-dev-brainstorm` / `ai-dev-exec` / `ai-dev-plan` / `ai-dev-verify` /
`breakdown-gate` / `codex-mvp-split` / `design-gate` / `diff-audit` / `intent-classifier` /
`local-exec-handoff` / `manual-cloud-task` / `plan-review-gate` / `plangate-setup` /
`review-gate/SKILL.md` / `review-gate/references/ui-ux-lane.md` /
`skill-creator/references/review-default.md` / `skill-policy-router` / `working-context`

`plugin/plangate/skills` 側の差（rules 参照はあるが `CLAUDE_PLUGIN_ROOT` を持たない 5 件）は
**すべて偽陽性**であることを 1 件ずつ確認した:

| ファイル | rules 参照の実体 | 判定 |
|---|---|---|
| `ai-loop-cycle/references/concept.md:106,119` | HO パス一覧の説明 / 「`.claude/rules/` は L0 契約正本」 | 参照解決の対象ではない |
| `ai-loop-cycle/references/review-feedback-loop.md:159` | 「`.claude/rules/` は gitignore 対象」という**誤解の記録** | 同上 |
| `ai-loop-cycle/scripts/{collector,gh_exec,test_arbiter}.py` | コメント内の出典表記 / テスト fixture の文字列 | 同上 |

**クラス A'（`../../rules/` 相対形式）**: `.agents` / `plugin` に残るのは
`acceptance-review/SKILL.md:192` と `diff-audit/SKILL.md:373` の **2 件のみ**で、
どちらも「この相対リンクは skills と rules が同一 root の場合のみ成立する」という**説明文**（＝是正済み）。

**AC-2 / クラス C の実測** — `.agents/skills` / `plugin/plangate/skills` ともに **violation 0**:

| root | `docs/**` 参照を持つ md | 注記あり | violation |
|---|---:|---:|---:|
| `.agents/skills/` | 23 | 22 + 1 | **0** |
| `plugin/plangate/skills/` | 41 | 41 | **0** |
| `.codex/skills/` | 23 | 10 | **13** |

> `.agents/skills/ref-integrity-scan/SKILL.md` は「参照解決順」等の定型語を持たないため素朴な検出器では
> violation に出るが、実体は `:110` に「**配布対象外**。上流リポジトリで作業する場合のみ解決する」と
> **より強い形で解決済み**。検出器側の偽陽性として除外した（陽性コントロールで grep 起動を確認済み）。

**AC-3 の未充足部分（`.codex/skills` のクラス C 注記が欠落している 13 ファイル・全数列挙）**

```text
.codex/skills/acceptance-criteria-build/SKILL.md
.codex/skills/architecture-sketch/SKILL.md
.codex/skills/context-load/SKILL.md
.codex/skills/edgecase-enumeration/SKILL.md
.codex/skills/feature-implement/SKILL.md
.codex/skills/known-issues-log/SKILL.md
.codex/skills/nonfunctional-check/SKILL.md
.codex/skills/pr-decision/SKILL.md
.codex/skills/ref-integrity-scan/SKILL.md
.codex/skills/requirement-gap-scan/SKILL.md
.codex/skills/risk-assessment/SKILL.md
.codex/skills/subagent-delegation-brief/SKILL.md
.codex/skills/subagent-team-design/SKILL.md
```

#### SCOPE-DECISION 提案（#954）

> **クラス A / A' / C の「正本 `.agents/skills` と配布物 `plugin/plangate/skills`」への適用完了をもって
> #954 を close し、`.codex/skills` への波及と marketplace 実測を切り出す。**

- 根拠 1: **#954 の In scope 表は「`install.sh` 経由 / plugin 経由」の 2 経路で書かれており、`.codex` 経路は表にない**。
  `.codex` が対象に入るのは AC-3 の 1 行だけで、issue の主題（3 クラスの参照解決）とは別問題。
- 根拠 2: **`.codex/skills` の drift は #956（OPEN）が裁定を所有**し、**#1170 が具体症状を追跡**している。
  #954 を `.codex` の裁定待ちで開けたままにすると、**判断 1 つで 3 issue が同時にブロックされ続ける**。
- 根拠 3: 正本側の「`.codex/skills/` は sync 対象外の配布先のため、正本更新時に同一内容を手動で追従させる」
  （`.agents/skills/intent-classifier/SKILL.md:10`）という運用宣言は既に入っており、**方針は決まっている**。
- 切り出す follow-up: **既存の #1170 に「クラス C 注記 13 ファイル」を追記**すれば足りる（新規起票不要）。
  AC-5（marketplace 実測）は**別の性質のタスク**（環境が要る受入検証）なので、新規起票を推奨。

#### AC-5 を切り出す場合の follow-up 案

- タイトル: `test(dist): クラス A / C の参照解決を marketplace 経由の実環境で実測する（#954 AC-5 の切り出し）`
- 内容: `claude plugin marketplace add s977043/plangate` した環境で、`${CLAUDE_PLUGIN_ROOT}/rules/<name>.md` が
  **実際に解決すること**、および `docs/**` 参照が**解決しないこと（＝明示して停止すること）**を 1 件ずつ確認
- 責務: 実環境が要るため **Human または実環境を持つセッション**

---

## 5. PARTIAL の残 AC

### 5-1. #1078 — EH-13 が `.codex/hooks.json` に未配線

| AC | 判定 | 実測 |
|---|---|---|
| **AC-1** Codex セッションで承認トークン書き込みが block される | ❌ | 下記 |
| **AC-2** `.agents/skills` と `.codex/skills` の差分が 0 + 機械検出手段 | ❌ | `git diff --stat` で **115 ファイル / +520 −492**、うち **SKILL.md 33 本に内容差分**。機械検出も未導入（`sync-plugin-plangate.sh` は `.codex` を対象外、`check-codex-skill-spec.sh` は `agents/openai.yaml` しか見ない = #1170 の実測と整合） |
| **AC-3** リリース工程に `.codex/skills` 同期を組み込む | ❌ | `git grep -n 'codex' origin/main -- docs/release-process.md` が **0 件**（陽性コントロール: `git grep -n 'install-plangate-skills-to-codex' origin/main -- docs/release-process.md scripts/release-prep.sh .github/workflows docs/working/_merge` は `docs/working/_merge/v8.21.0-release-runbook.md:90` の 1 件のみヒット = grep は起動している） |
| **AC-4** `settings-wiring-contract.md` §Codex CLI parity が実態と一致 | ✅ | `docs/ai/settings-wiring-contract.md:82` = `## Codex CLI parity (#336 / Gap 4) — ~~達成済~~ ~~部分達成（5 / 11 wiring）~~ **強制力 0 / 11（Codex 側 hook は 1 件も登録されていない）**`。軸 A/B/C の分離（`:121`）まで書かれている |
| **AC-5** `.claude` 側 hook 挙動が無傷 | ✅（自明） | `.codex` 側が未変更なので `.claude` に影響なし |
| **AC-6** `.codex/skills` を symlink にするか同期コピーのままにするかの判断と理由が記録 | ❌ | `git grep -rn 'symlink' origin/main -- docs/ai/settings-wiring-contract.md docs/release-process.md` が 0 件 |

#### AC-1 の実測（EH-13 の配線）

```sh
$ git grep -n 'check-approval-token-write' origin/main -- .codex/hooks.json .codex/hooks/eh-bridge.sh
（出力なし）

# 陽性コントロール
$ git grep -c 'check-approval-token-write' origin/main -- .claude/settings.example.json
origin/main:.claude/settings.example.json:2
```

`.codex/hooks.json` の `PreToolUse` に入っているのは `check-plan-exists` / `check-c3-approval` /
`check-plan-hash` / `check-forbidden-files`（`apply_patch|Edit|Write`）と
`check-delegation-commit-boundary`（`Bash`）の **5 本のみ**で、**EH-13 は不在**。

**さらに重い事実**: `.codex/hooks.json` は先頭に `$schema_note` / `$note` の 2 キーを持ち、
これが**ファイル全体の parse 拒否を招いて hook 登録数が 0** になっている（`settings-wiring-contract.md` の
「層 2 の但し書き」）。しかも `settings-wiring-contract.md:277` は
**「この行の除去自体が『単独除去は禁止』の対象」**と明記している。

**→ #1078 の残作業は「EH-13 を 1 行足す」ではなく、`.codex/hooks.json` の注記キーをどう扱うか（silent failure の除去）という設計判断を含む。実行層は LH。**

#### 今すぐできる部分是正（close には不足だが実害を減らす）

`CLAUDE.md:34` と `AGENTS.md:18` / `:48` に **false claim が残っている**:

```sh
$ git grep -n '物理 hook\|物理発火\|eh-bridge' origin/main -- CLAUDE.md AGENTS.md
origin/main:AGENTS.md:18:- **推奨ガード入口**: `scripts/codex-guarded.sh` (PR #343 / #347。… 物理 hook bridge を有効化)
origin/main:AGENTS.md:48:- 物理 hook: `.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` (EH-1/2/3/6/9 を Codex 側でも発火)
origin/main:CLAUDE.md:34:- 物理 hook 配線: … EH-1/2/3/6/9 を Codex session 中の `apply_patch|Edit|Write|Bash` に対し物理発火
```

**patch は既に整備済み**（`git apply` するだけ）:

```sh
$ git ls-tree -r --name-only origin/main -- docs/working/TASK-1078
docs/working/TASK-1078/evidence/codex-exec-spike.md
docs/working/TASK-1078/evidence/codex-payload-spike.md
docs/working/TASK-1078/evidence/hooks-list-raw.json
docs/working/TASK-1078/evidence/hooks-list-reverify.md
docs/working/TASK-1078/patches/AGENTS.md.codex-parity.patch
docs/working/TASK-1078/patches/CLAUDE.md.codex-parity.patch
docs/working/TASK-1078/status.md
```

**AGENTS.md は Codex セッションが読む側の正本のため実害が最大。** L3（Human 適用）。

---

### 5-2. #1170 — `.codex/skills` が #1164 / #1160 の是正に追従していない

**issue が挙げた 2 症状は両方とも未解消。**

```sh
# 症状 1（#1159 / PR #1164 のクラス A 梯子）
$ git grep -c 'CLAUDE_PLUGIN_ROOT}/rules/' origin/main -- \
    .codex/skills/design-gate/SKILL.md .codex/skills/intent-classifier/SKILL.md \
    .codex/skills/plan-review-gate/SKILL.md .codex/skills/skill-policy-router/SKILL.md
（出力なし = 4 本すべて 0 件）

# 陽性コントロール（他 root では 1 件ずつヒットする）
$ git grep -c 'CLAUDE_PLUGIN_ROOT}/rules/' origin/main -- \
    .agents/skills/{design-gate,intent-classifier,plan-review-gate,skill-policy-router}/SKILL.md \
    .claude/skills/{design-gate,intent-classifier,plan-review-gate,skill-policy-router}/SKILL.md
origin/main:.agents/skills/design-gate/SKILL.md:1
origin/main:.agents/skills/intent-classifier/SKILL.md:1
origin/main:.agents/skills/plan-review-gate/SKILL.md:1
origin/main:.agents/skills/skill-policy-router/SKILL.md:1
origin/main:.claude/skills/intent-classifier/SKILL.md:1
origin/main:.claude/skills/skill-policy-router/SKILL.md:1
```

> 注: `.claude/skills` に `design-gate` / `plan-review-gate` は**そもそも存在しない**
> （`git ls-tree -r --name-only origin/main -- .claude/skills | grep -E 'design-gate|plan-review-gate'` が 0 件）。
> **「0 件」は欠落ではなくメンバーシップの違い**であり、#1170 の症状ではない。

```sh
# 症状 2（#982 / PR #1160 の ai-loop CLI 誤読解消）
$ git grep -c 'ai-loop` サブコマンドは存在しない' origin/main -- \
    .agents/skills/ai-loop-cycle/SKILL.md .claude/skills/ai-loop-cycle/SKILL.md \
    .codex/skills/ai-loop-cycle/SKILL.md plugin/plangate/skills/ai-loop-cycle/SKILL.md
origin/main:.agents/skills/ai-loop-cycle/SKILL.md:1
origin/main:.claude/skills/ai-loop-cycle/SKILL.md:1
origin/main:plugin/plangate/skills/ai-loop-cycle/SKILL.md:1
（.codex は出力に現れない = 0 件）
```

**さらに本調査で 3 つ目の症状を検出**: クラス C（`docs/**` 参照の解決順注記）が
`.codex/skills` の **13 ファイル**で欠落している（§4-2 に全数列挙）。
これは #1195 が `.agents` / `plugin` に入れた是正が `.codex` に届いていないもので、**#1170 と同型**。

**残 AC / 実行層**: #1170 は本文自身が
「v8.21.0 では**是正しない**（`.codex/skills` の二重 root 登録は **#1086 / #956 の判断待ち領域**のため）」
「#956 の判断が付いた後に (a) `.codex` を同期対象に含める か (b) 検出ゲートを足す かを決める」
と宣言している。**#956 は現在も OPEN**（`fix(workflow): .codex/skills/ に commit 済み drift 2 件、CI に検出機構が無い`）。

**→ 実行層 LH。Human の判断内容は「(a) `.codex/skills` を `sync-plugin-plangate.sh` の同期対象に含めるか、(b) 同期はせず `.agents` との差分を検出するゲートを CI / doctor に足すか」の二択。**
この 1 つの判断で **#1170 / #954 AC-3 / #1078 AC-2 / #956 の 4 件が同時に動く。**

---

## 6. 前回判定から変わったもの

| issue | 前回（base `684949e`） | 今回（base `e52118b`） | 変化の理由 |
|---|---|---|---|
| **#866** | CLOSE-AFTER-1（「close 条件を本文 3 項目に限る判断」が必要） | **CLOSE-NOW** | **判定の訂正**。本文の修正案は 1〜3 の 3 項目しかなく、`.codex` は本文の対象範囲外。「3 項目に限る」は**新たな scope 判断ではなく本文どおりの読み**なので、Human の追加判断は不要と再評価した |
| **#954** | PARTIAL（「クラス A（#1184）とクラス C（#1195）が入った。AC 表と照合し直すこと」） | **PARTIAL 継続 + SCOPE-DECISION 提案を追加** | **e52118b で AC 表と照合し直した結果**、AC-1 / AC-2 は充足、未充足は AC-3 の `.codex` 分と AC-5 に絞り込めた。#1195 が `.codex` を意図的に触っていない（PR 本文で明言）ことも確認 |
| **#863** | CLOSE-AFTER-1（1 手 = scope 質問への回答） | **SCOPE-DECISION**（1 手 = scope 判断 **+ L1 の 1 ファイル修正**） | **前回未検出の未充足 AC を 1 件発見**。`plugin/plangate/skills/README.md` が `.agents/skills/README.md` の是正に追従しておらず、**AC-3 は前半のみ充足**だった。scope 判断だけでは close できない |
| **#960** | CLOSE-AFTER-1（残存 HO **6** + ミラー 5 + CHANGELOG 2） | **CLOSE-AFTER-1（変化なし。HO 6 + ミラー 5 + 履歴 2 = 13）** | 数値は一致。ただし**内訳の内訳が違う**: HO 6 は **md 5 + `schemas/review-result.schema.json` 1**。`*.md` だけを grep すると 5 件に見え、**1 件取りこぼす** |
| **#1018** | CLOSE-AFTER-1（`PLANGATE_HOOK_TASK` セッション） | **CLOSE-AFTER-1（変化なし）** | 加えて今回は**抽出器を実物のまま読み込んで `paths=[]` を再現**し、陽性コントロール（`Files / Interfaces` は拾える）まで取った |
| **#1078** | 前回の担当範囲外 | **PARTIAL**（AC 1/2/3/6 未充足・4/5 充足） | 新規照合。**#1194 は AC のどれも満たしていない** — 1 ファイル 1 行の false claim 是正であって、AC-1（EH-13 配線）でも AC-2（差分 0）でもない |
| **#1170** | 前回の担当範囲外 | **PARTIAL / BLOCKED**（#956 = OPEN） | 新規照合。**#1194 が触ったのは `.codex/skills/ai-dev-exec/SKILL.md` だけ**で、#1170 が名指しした 4 skill + `ai-loop-cycle` は未追従。**#1195 は `.codex` を一切触っていない**ため、`.codex` のクラス C 欠落が 13 件に増えた |

**#1194 / #1195 が close させた issue は 0 件。** どちらも `Refs #1078` / `Refs #954` であって `Closes` ではなく、
実測でも当該 issue の AC を 1 つも充足させていない（#1194 は false claim 1 行の先行是正、
また #1195 は #954 のクラス C を `.agents` / `plugin` で 0 件にしたが、AC-3 の `.codex` 分と AC-5 は残る）。

---

## 7. スコープ外で見つけた問題（手を出していない・報告のみ）

1. **セッションに読み込まれた `CLAUDE.md` が stale だった**
   本セッションの system context にロードされた `CLAUDE.md` は **v8.20.0 節**（「既知の未解消ギャップ: EH-3 の HO 迂回（#1089）は … hook 本体は未適用」）だが、
   `origin/main` の実体は **v8.21.0 節**で「適用済みのため `tests/fixtures/eh3-known-gap-1089.flag` は削除」と是正済み。

   ```sh
   $ git grep -n 'hook 本体' origin/main -- CLAUDE.md      # 0 件
   $ git show origin/main:CLAUDE.md | sed -n '14p'
   ## v8.21.0 参照解決順とガード迂回の是正（最新リリース機能）
   ```

   **#1102 は既に解消している。** ただし `_reports/1102-1018-blocked-oneline-patch.md` の**第 1 部は消化済み**なので、
   同 patch を Human に依頼するときは**第 2 部（#1018）だけ**を指すこと（**第 1 部の再適用は不要かつ有害**）。

2. **`.codex/hooks.json` の silent failure が「登録 0 件」の真因**
   EH-13 を足しても、`$schema_note` / `$note` の 2 キーが残る限り parse 拒否は解消しない。
   **#1078 AC-1 は「1 行追加」では達成できない。** `settings-wiring-contract.md:277` が
   「この行の単独除去は禁止」としているため、**注記キーの扱いを含む設計判断が先**。

3. **`docs/release-process.md` に codex の語が 1 件も無い**
   `.codex/skills` の同期はもちろん、Codex 経路全般がリリース工程の文書に存在しない。
   #1078 AC-3 / #1170 / #956 のいずれを解決するにも、**この文書に着地点が必要**。

4. **`schemas/review-result.schema.json:42` は `.md` 縛りの grep から漏れる**
   #960 の残存調査を `--include=*.md` や `-- '*.md'` で回すと **6 件中 1 件を落とす**。
   同種の「表記残存を数える」作業では pathspec を `*.md` に絞らないこと。

5. **`.claude/skills` に `design-gate` / `plan-review-gate` が存在しない**
   4 root（`.agents` / `.claude` / `.codex` / `plugin`）は**メンバーシップが揃っていない**。
   「4 root 同時是正」を件数で語ると、**存在しない root の 0 件を欠落と誤読する**リスクがある。

---

## 付録: 本書の測定で使ったコマンドと exit code

| # | コマンド | exit |
|---:|---|---:|
| 1 | `git rev-parse origin/main` → `e52118b6153352f7bcf1de7d1cca2026b6309330` | 0 |
| 2 | `git grep -l -E '\.claude/rules/\|\.\./\.\./rules/' origin/main -- '.agents/skills'` | 0 |
| 3 | `git grep -l 'CLAUDE_PLUGIN_ROOT' origin/main -- '.agents/skills'` | 0 |
| 4 | `git grep -l -E 'docs/(ai\|workflows\|pages\|plangate\|ai-driven)' origin/main -- '.agents/skills/**/*.md'` ほか 3 root | 0 |
| 5 | `git ls-tree origin/main -- <4 root>/intent-classifier/SKILL.md` | 0 |
| 6 | `git diff --stat origin/main:.agents/skills origin/main:.codex/skills` | 0 |
| 7 | `git grep -n 'check-approval-token-write' origin/main -- .codex/hooks.json .codex/hooks/eh-bridge.sh` | 1（0 件・陽性コントロールで grep 起動を確認） |
| 8 | `git grep -c 'check-approval-token-write' origin/main -- .claude/settings.example.json` → `2` | 0 |
| 9 | `git grep -l -E '17[[:space:]]*項目\|17項目' origin/main -- '*.md' ':!docs/working'` | 0 |
| 10 | `git grep -n -E '17[[:space:]]*項目\|17項目' origin/main -- ':!docs/working' ':!*.md'` | 0 |
| 11 | `python3 -c "… plan_package …"`（テンプレの抽出失敗を再現 + 陽性コントロール） | 0 |
| 12 | `git grep -c 'Files / Interfaces' origin/main -- docs/working/templates/plan.md` → `3` | 0 |
| 13 | `git grep -l 'bin/plangate' origin/main -- 'plugin/plangate/{commands,agents}/*.md' 'plugin/plangate/skills/*/SKILL.md'` | 0 |
| 14 | `git ls-tree -r --name-only origin/main -- docs/working/TASK-0863 / TASK-1078` | 0 |
| 15 | `gh issue view {863,866,954,960,1018,1078,1170,956} --repo s977043/plangate`（**読み取りのみ**） | 0 |

**書き込み操作は一切していない**（issue / PR へのコメント・close、`sync-plugin-plangate.sh`、
`install-plangate-skills-to-codex.sh`、`apply-*.sh --apply` のいずれも未実行）。
`sh <任意の .py>` も実行していない（#1169）。
