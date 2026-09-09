# Instruction Debt 是正 patch（2026-09-09 / HO patch 文書）

> **これは patch 文書であり、実ファイルは変更していない。** 対象の `CLAUDE.md` /
> `.claude/rules/**` は Hardening Override（HO）対象のため、適用は **Human-owned**
> （[`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) /
> [`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md)）。

## 1. 概要

`instruction-debt-audit` で confirmed になった 3 件を、1 patch にまとめた
（主題: **承認境界と完了条件の明確化**）。hunk はファイルごとに分かれている。

| #   | 種別            | 対象                                 | 変更                                                                                                                   |
| --- | --------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| 1   | Authority debt  | `CLAUDE.md`                          | `<law>` 直後に「承認境界の適用順」を追加（既存 4 層はいずれも弱めない。順序だけを定義）                                |
| 2   | Context debt    | `.claude/rules/orchestrator-mode.md` | 冒頭に適用条件（親 PBI 分解時のみ / 機械強制は未実装）を追加。あわせて `CLAUDE.md` の rules 参照行を条件付き参照に調整 |
| 3   | Completion debt | `.claude/rules/working-context.md`   | ワークフロー図の直後に「PR 作成は完了ではない」を追加                                                                  |
| —   | 配布同期        | `plugin/plangate/rules/*.md`         | 上記 2・3 の plugin ミラー（`scripts/sync-plugin-plangate.sh` の同期対象）                                             |

- **base**: `756aa254bd5c266cd2e8730216ee31c83d873d8c`（`git ls-remote origin refs/heads/main` で実測した `origin/main`）
- **変更**: 5 ファイル / +43 −1
- **patch 本体の sha256**: `3313c0ca9b5c1d11e4bc15a7e4d6fdc88ccf87bf3b4c46ff16478c13bb51ff12`

## 2. 根拠（現 main で再確認済み）

| #   | evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | 実測             |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| 1   | 承認に関する記述が 4 層（`CLAUDE.md:42` 第1原則本体 / 同 但書 / `working-context.md:425` C-3 Autonomous APPROVE / `responsibility-classes.md:61` 自己設置 Gate 非緩和）あるが、**相互の優先順位が未定義**。`responsibility-classes.md:113` は「本 rule とユーザー指示が衝突した場合」＝ rule 対 user であり、rule 同士の precedence ではない                                                                                                                                  | 該当行を目視確認 |
| 2   | `.claude/rules/orchestrator-mode.md` は **194 行の常時ロード**。自己申告で未実装（`:3` Status=Specification / `:116` 将来的な Hook 実装で…想定 / `:134` 実装は本 PBI 範囲外）。`ChildExecAllowed` の実装は 0 件（`git grep -l` のヒットは全て doc）。`scripts/check-orchestrator-docs.sh` の TC-15/TC-16 は `grep -q 'ParentDone' .claude/rules/orchestrator-mode.md` 形式＝**doc に文字列があるかを見る自己参照**。実運用は `docs/working/PBI-116` の **1 ディレクトリのみ** | 全て実測         |
| 3   | `git grep -c "マージ可能" -- .claude/rules docs/ai/core-contract.md` → **0 件**（positive control として同じ範囲の `PR作成` は 3 件ヒットするので検査は空振りではない）。完了条件が memory 側にしか無く、memory を持たない runtime では PR 作成＝完了と宣言できてしまう                                                                                                                                                                                                       | 実測             |

## 3. patch

以下の marker 間を **awk で抽出**して適用する（`sed -e '1d' -e '$d'` は formatter の
fence 正規化で行数がずれるため使わないこと）。

<!-- PATCH-BEGIN: instruction-debt-2026-09-09 -->

````diff
diff --git a/.claude/rules/orchestrator-mode.md b/.claude/rules/orchestrator-mode.md
index 28ce732..a68c119 100644
--- a/.claude/rules/orchestrator-mode.md
+++ b/.claude/rules/orchestrator-mode.md
@@ -1,5 +1,10 @@
 # Rule: Orchestrator Mode Gate Conditions（正本）
 
+> **適用条件**: 親 PBI 分解（`docs/working/PBI-XXX/`）を扱うときだけ読む。単一 PBI の
+> 作業では本ルールは発火しない。**機械強制は未実装**（v1 は仕様定義のみ。
+> [`scripts/check-orchestrator-docs.sh`](../../scripts/check-orchestrator-docs.sh) は
+> doc に当該記述があるかを検査するものであり、不変条件そのものを強制しない）。
+>
 > **Status**: Specification（v1, 仕様策定のみ。実装による強制力は別 PBI）
 > 関連: [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) / Issue [#109](https://github.com/s977043/plangate/issues/109)
 > 役割: PlanGate Orchestrator Mode の Gate 条件と AI 自己完結禁止条項の **正本** を提供する
diff --git a/.claude/rules/working-context.md b/.claude/rules/working-context.md
index 97eefbd..badb8c6 100644
--- a/.claude/rules/working-context.md
+++ b/.claude/rules/working-context.md
@@ -30,6 +30,12 @@ Ready → In Progress
   → Done
 ```
 
+> **PR 作成は完了ではない。** CI 緑・レビュー完了（レビュアーが沈黙し
+> `unavailable` になった場合は
+> [`reviewer-silence-fallback.md`](../../docs/ai/reviewer-silence-fallback.md)
+> §3〜§4 に従い代替レビューを実施）・同時 open PR との衝突の事前検出まで
+> 進めて、初めて C-4 へ渡す。
+
 ## 本ルールの CLI 依存（`bin/plangate`）— 導入先での扱い（#1144）
 
 本ルールは plugin（読み物層）としても配布されるが、**plugin 配布物には
diff --git a/CLAUDE.md b/CLAUDE.md
index 50a0660..5ac490f 100644
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -6,7 +6,7 @@
 ## Claude Code 固有参照
 
 - エージェント / コマンド / スキル: `.claude/agents/` / `.claude/commands/` / `.claude/skills/`
-- 運用ルール: `.claude/rules/`（hybrid-architecture / orchestrator-mode 含む）
+- 運用ルール: `.claude/rules/`（hybrid-architecture 等は常時。orchestrator-mode は親 PBI 分解時のみ参照）
 - 共有スキル: `.agents/skills/`（Codex CLI と共用）
 - ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) / Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)
 - サブエージェント委譲プロトコル: [`docs/ai/subagent-delegation/README.md`](docs/ai/subagent-delegation/README.md)（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範 / PlanGateフロー接続。既存の C-3/C-4 ゲートおよび orchestrator-mode の Gate 不変条件は変更しない）
@@ -44,3 +44,23 @@ AI運用4原則
 第3原則： AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最優先で指示された通りに実行する。
 第4原則： AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。
 </law>
+
+### 承認境界の適用順（迷ったら上が勝つ）
+
+> 上記 4 原則および `.claude/rules/` の承認関連規定は、いずれも**弱めない**。
+> 本節が定めるのは**どれが先に効くかの順序だけ**である。
+
+1. **HO（Hardening Override）対象パス** — 例外なく Human 適用。C-3 承認や
+   `plan_hash` 一致があっても AI は編集しない（対象 12 カテゴリの正本:
+   [`.claude/rules/mode-classification.md`](.claude/rules/mode-classification.md)）
+2. **不可逆・対外操作** — merge / 強制 push / 削除 / tag・Release 等の対外公開は、
+   包括承認では足りず**個別に名指しで承認**を取る
+   （[`.claude/rules/responsibility-classes.md`](.claude/rules/responsibility-classes.md)）
+3. **自己設置 Gate** — AI が自ら「ここで再承認」と宣言したら、ユーザーの
+   **明示解除まで有効**（`/goal` や autonomy 指示は解除と見なさない）
+4. **サブコマンド承認**（第 1 原則の但書）— 起動したコマンドの**定義に書かれた
+   範囲内**のファイル生成・更新のみを許可とみなす。範囲外へは広げない
+5. 上記のいずれにも当たらなければ、第 1 原則どおり y/n を取る
+
+C-3 autonomous APPROVE（[`.claude/rules/working-context.md`](.claude/rules/working-context.md)）は
+5 の枠内の運用であり、1〜3 を上書きしない。
diff --git a/plugin/plangate/rules/orchestrator-mode.md b/plugin/plangate/rules/orchestrator-mode.md
index 28ce732..a68c119 100644
--- a/plugin/plangate/rules/orchestrator-mode.md
+++ b/plugin/plangate/rules/orchestrator-mode.md
@@ -1,5 +1,10 @@
 # Rule: Orchestrator Mode Gate Conditions（正本）
 
+> **適用条件**: 親 PBI 分解（`docs/working/PBI-XXX/`）を扱うときだけ読む。単一 PBI の
+> 作業では本ルールは発火しない。**機械強制は未実装**（v1 は仕様定義のみ。
+> [`scripts/check-orchestrator-docs.sh`](../../scripts/check-orchestrator-docs.sh) は
+> doc に当該記述があるかを検査するものであり、不変条件そのものを強制しない）。
+>
 > **Status**: Specification（v1, 仕様策定のみ。実装による強制力は別 PBI）
 > 関連: [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) / Issue [#109](https://github.com/s977043/plangate/issues/109)
 > 役割: PlanGate Orchestrator Mode の Gate 条件と AI 自己完結禁止条項の **正本** を提供する
diff --git a/plugin/plangate/rules/working-context.md b/plugin/plangate/rules/working-context.md
index 97eefbd..badb8c6 100644
--- a/plugin/plangate/rules/working-context.md
+++ b/plugin/plangate/rules/working-context.md
@@ -30,6 +30,12 @@ Ready → In Progress
   → Done
 ```
 
+> **PR 作成は完了ではない。** CI 緑・レビュー完了（レビュアーが沈黙し
+> `unavailable` になった場合は
+> [`reviewer-silence-fallback.md`](../../docs/ai/reviewer-silence-fallback.md)
+> §3〜§4 に従い代替レビューを実施）・同時 open PR との衝突の事前検出まで
+> 進めて、初めて C-4 へ渡す。
+
 ## 本ルールの CLI 依存（`bin/plangate`）— 導入先での扱い（#1144）
 
 本ルールは plugin（読み物層）としても配布されるが、**plugin 配布物には
````

<!-- PATCH-END: instruction-debt-2026-09-09 -->

## 4. Human 適用手順

`origin/main` = `756aa254` の clean な checkout で実行する。

````sh
# 1) marker 間を抽出（awk 方式。fence 行と、fence 前後の空行を落とす。
#    patch 本体に空行は 0 行、context の空行は " " 1 文字なので安全）
awk '/^<!-- PATCH-BEGIN: instruction-debt-2026-09-09/{f=1;next} /^<!-- PATCH-END: instruction-debt-2026-09-09/{f=0} f && !/^```/ && !/^$/' \
  docs/working/_reports/instruction-debt-2026-09-09-patch.md > /tmp/id-2026-09-09.patch

# 2) 中身の同一性を確認（この値と一致しなければ抽出が壊れている）
shasum -a 256 /tmp/id-2026-09-09.patch
# expected: 3313c0ca9b5c1d11e4bc15a7e4d6fdc88ccf87bf3b4c46ff16478c13bb51ff12

# 3) 事前チェック（--check 単独は検証ではないので、必ず 4) まで進めること）
git apply --check --verbose /tmp/id-2026-09-09.patch

# 4) 適用
git apply /tmp/id-2026-09-09.patch
git diff --numstat   # 期待: 5 ファイル / +43 -1

# 5) 事後の sync は不要（ミラーは patch に含まれている）。念のため冪等性だけ確認する
sh scripts/sync-plugin-plangate.sh   # 期待: "Sync complete — no changes"

# 6) 検査
sh scripts/check-orchestrator-docs.sh   # 期待: 20 passed, 0 failed
sh tests/extras/ta-71-ci-static-lint.sh # 期待: 27 passed, 0 failed
````

**`plugin/plangate/rules/*.md` は HO 対象外**なので、5) で差分が出た場合（base が
`756aa254` から進んでいた等）はその再同期分のみ AI が commit してよい。
`CLAUDE.md` / `.claude/rules/**` の適用は Human に固定。

## 5. 検証済み事項（base `756aa254` / repo 外の複製で実測）

| 検証                                                      | 結果                                                                             |
| --------------------------------------------------------- | -------------------------------------------------------------------------------- |
| forward `git apply --check`                               | rc=0                                                                             |
| reverse `git apply --check -R`（未適用ツリー）            | rc=1（＝未適用であることの確認）                                                 |
| `git diff --numstat`                                      | 5 ファイル / +43 −1                                                              |
| `sh scripts/check-orchestrator-docs.sh`                   | 20 passed, 0 failed                                                              |
| `sh tests/extras/ta-71-ci-static-lint.sh`                 | 27 passed, 0 failed                                                              |
| `markdownlint-cli2`（原本 cp と適用後 cp を同条件で比較） | 原本 14 issues / 2 files → 適用後 **14 issues / 2 files**（増減なし）            |
| `sh scripts/sync-plugin-plangate.sh`                      | 適用直後は 2 ファイル COPY → patch に取り込み済み。2 回目は "no changes"（冪等） |
| `python3 scripts/check-stale-skill-refs.py`               | OK（stale パス参照なし）                                                         |

## 6. 監査の提案文言から変更した箇所

| 箇所                                                                          | 変更                                                                                 | 理由                                                                                                                                                                                                                          |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| (1) 見出しレベル                                                              | `###` のまま、`<law>` の直後に配置                                                   | 直前の見出しが `##` なので MD001（heading-increment）に適合する                                                                                                                                                               |
| (1) 冒頭に「いずれも弱めない／順序だけを定める」の但書を追加                  | 追加                                                                                 | 「precedence を書いたことで下位層が上位層に吸収された」と誤読されるのを防ぐため（各層を弱めない、という要件の明文化）                                                                                                         |
| (1) 項目 2 の例示から `git push --force` の literal 表記を外し「強制 push」に | 表現変更                                                                             | 実害ではなく作業上の理由。EH-13 / コマンド検出系のガードが doc 中の literal に反応しうるため（[`feedback_eh13_markdown_heredoc_false_positive`](https://github.com/s977043/plangate) と同型の偽陽性回避）。意味は変えていない |
| (1) 末尾に「C-3 autonomous APPROVE は 5 の枠内」の 1 文を追加                 | 追加                                                                                 | 4 層のうち autonomous APPROVE だけが順位表に現れないと、どの段に属するのか読み取れないため                                                                                                                                    |
| (2) blockquote の位置                                                         | 「`## 位置付け` の前に独立した blockquote」→ **冒頭 blockquote の先頭に `>` で連結** | 独立配置は `MD028/no-blanks-blockquote` を新規発火させた（実測。連結後は baseline と同一の 14 件に戻る）                                                                                                                      |
| (3) 挿入位置                                                                  | 「`→ PR作成 🤖` の直後」→ **ワークフロー fence の直後**                              | `→ PR作成 🤖` は ```text fence の内側であり、そこに blockquote を差すと fence が壊れる                                                                                                                                        |
| (3) 文言                                                                      | 「bot が `unavailable` なら」→「レビュアーが沈黙し `unavailable` になった場合は」    | 参照先 [`docs/ai/reviewer-silence-fallback.md`](../../../docs/ai/reviewer-silence-fallback.md) §3.1 の発火条件は bot 固有ではなく「主レビュアーの quota / 不達 / 未導入」であるため                                           |

相対リンク `../../docs/ai/reviewer-silence-fallback.md` は `.claude/rules/` からの
相対として正しい（実ファイル存在・`§3` `§4` の実在を確認済み）。

## 7. スコープ外の気づき（手は入れていない）

1. **plugin ミラーの相対リンクは配布先で解決しない**: `plugin/plangate/rules/working-context.md`
   から見た `../../docs/ai/reviewer-silence-fallback.md` は `plugin/docs/...` を指し、
   `docs/**` は plugin の配布対象外。ただしこれは既存の `../../docs/orchestrator-mode.md`
   等と**同型の既存問題**であり、本 patch が新規に作った欠陥ではない（v8.21.0 #954 で
   扱われた「参照はあるが解決されない」構造の残り）。
2. **`docs/ai/reviewer-silence-fallback.md` §5 に未適用の Human 手順が残っている**:
   `scripts/apply-reviewer-silence-gate.sh` による `review-principles.md` / `gate-checks.md`
   への追記が未適用。本 patch は `working-context.md` を触るため衝突しないが、
   同じ #685 系の未適用手順として並存している。
3. **`scripts/check-orchestrator-docs.sh` の TC-15/TC-16 は自己参照検査**。doc に文字列が
   あるかしか見ておらず、不変条件の実装有無を検出しない。本 patch は「未実装である」旨を
   doc に明記するに留め、検査そのものは変更していない。
