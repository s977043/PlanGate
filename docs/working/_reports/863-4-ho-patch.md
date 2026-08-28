# #1203 / #863 項目4 — HO 3 ファイルの `bin/plangate` 表記 是正設計（patch 設計書）

> Issue: [#1203](https://github.com/s977043/plangate/issues/1203)（親: [#863](https://github.com/s977043/plangate/issues/863) 項目 4 = In scope 5「HO パスの差分提案」）
> 測定基準 ref: `origin/main` = `1e629fb9541a6b3f2dfd93fbc2cef0a2542bf0b8`（2026-08-24 実測）
> 作成者: AI（AI-owned）/ **適用は Human-owned**

## 0. 本書の位置づけと責務分界

対象 3 ファイルは [`mode-classification.md`](../../../.claude/rules/mode-classification.md) の
Hardening Override 9 カテゴリ（`.claude/commands/*.md` / `.claude/agents/*.md`）に該当する。
[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) に従い、
**AI は patch の設計・検証まで**を行い、**適用（`git apply`）は Human-owned** とする。

本書作成にあたり **対象 3 ファイルは 1 バイトも編集していない**。
patch は scratch の隔離コピー上で生成し、本 worktree に対しては
`git apply --check`（適用可否の検査のみ・ファイルは変更しない）で検証した。

| 項目 | 値 |
|------|-----|
| 本 PR で変更するファイル | `docs/working/_reports/863-4-ho-patch.md` の **1 件のみ** |
| 対象 3 ファイルの変更 | **なし**（`git status --porcelain` が空であることを実測） |
| patch の適用者 | Human（本 issue の follow-up として別途） |

## 1. 実測: `bin/plangate` ヒット数（`origin/main` = `1e629fb`）

再現コマンド（`git show` は glob 展開しないため path は 1 件ずつ明示する）:

```sh
git show origin/main:.claude/commands/plangate-setup.md   | grep -n 'bin/plangate'
git show origin/main:.claude/agents/setup-coordinator.md  | grep -n 'bin/plangate'
git show origin/main:.claude/agents/workflow-conductor.md | grep -n 'bin/plangate'
```

| ファイル | ヒット数 |
|---|---:|
| `.claude/commands/plangate-setup.md` | 3 |
| `.claude/agents/setup-coordinator.md` | 6 |
| `.claude/agents/workflow-conductor.md` | 2 |
| **計** | **11** |

> **鮮度注記**: `docs/working/TASK-0863/pbi-input.md` In scope 5 は「3 + 8 + 2 = **13 箇所**」と
> 記録するが、これは #863 起票時点の測定である。`origin/main` = `1e629fb` 実測では
> `setup-coordinator.md` が 6 で **計 11**。以降の判定はすべて `1e629fb` 実測値に基づく。
> 差分 2 件の消失経緯は本 PBI では追跡しない（**未確定**）。

## 2. 判定基準（#863 で確立済みの枠組みを踏襲）

#863 項目 2 の定義:

> 呼び出し表記の統一: `bin/plangate <cmd>` → `plangate <cmd>`（PATH 解決形式）。
> **PlanGate リポジトリ自身での実行を説明する文脈のみ `bin/plangate`（相対）を残してよい**が、
> その場合は「リポジトリルートで実行」を明記

`plugin/plangate/README.md`（#863 項目 4 で是正済み）の「カウント対象 / 対象外」定義:

- **カウント対象**: `commands/*.md` / `skills/*/SKILL.md` / `agents/*.md` の本文
- **カウント対象外**: 説明用ドキュメント内の言及、**HO（Hardening Override）パス指定および
  「本番フローから呼ばれない隔離 PoC」であることの明示**（= CLI 依存ではない）

既に是正済みの正本が採っている形（`.agents/skills/ai-dev-plan/SKILL.md` §CLI 呼び出し /
`.agents/skills/ai-dev-verify/SKILL.md` §CLI 呼び出し）:
**環境別対照表 + 「呼び出し表記は実行環境で変わる」の散文注記 + `TASK-XXXX` 解決先の注意**。
本 patch も同一の形を採る。

判定の分岐:

| 類型 | 判定 |
|------|------|
| 上流リポジトリ内での実行を明示している / HO パス指定などパスとしての言及 / 「clone した場合」の文脈 / 非存在の明示 / CLI のパス解決機構の説明 | **正当な残存** |
| 導入先が字義どおり実行する手順として `bin/plangate <subcommand>` を書いている（導入先の cwd に `bin/` は無いので失敗する） | **是正対象** |

## 3. AC-1: 全 11 ヒットの 1 件ずつの判定

| # | ファイル:行 | 該当行の逐語引用 | 類型 | 判定 |
|---|---|---|---|---|
| 1 | `.claude/commands/plangate-setup.md:7` | ``` `bin/plangate` CLI が必要です。Plugin 単体導入では PATH に含まれないため、未導入の場合は先に PlanGate リポジトリを clone してください: ``` | CLI 名の名指し。直後の `export PATH="$HOME/plangate/bin:$PATH"` で PATH に載るコマンド名は `plangate` であり、同一段落内で矛盾する | **是正対象** |
| 2 | `.claude/commands/plangate-setup.md:23` | ``` 2. `bin/plangate doctor --json` で不足項目を検知 ``` | 導入先が字義どおり実行する手順 | **是正対象** |
| 3 | `.claude/commands/plangate-setup.md:25` | ``` 4. ユーザー報告 → `bin/plangate doctor --json` 再実行で実体検証 ``` | 同上 | **是正対象** |
| 4 | `.claude/agents/setup-coordinator.md:35` | `## bin/plangate 不在時のフォールバック` | 節見出しの CLI 名。導入先で不在なのは `plangate`（PATH）であり `bin/plangate` ではない | **是正対象** |
| 5 | `.claude/agents/setup-coordinator.md:37` | ``` `bin/plangate doctor --json` を実行する前に `command -v bin/plangate` で存在確認する。不在の場合は doctor をスキップし、PlanGate フルリポジトリの clone が必要である旨と clone コマンド（`git clone https://github.com/s977043/plangate.git`）を案内して停止する（command not found でユーザーを放置しない）。 ``` | 実行手順。加えて `command -v bin/plangate` は**スラッシュを含む語を PATH 検索しない**ため、PATH 導入済み環境を「不在」と誤判定する二重の不整合 | **是正対象** |
| 6 | `.claude/agents/setup-coordinator.md:63` | `$ bin/plangate doctor --json` | Step 1 の実行手順 | **是正対象** |
| 7 | `.claude/agents/setup-coordinator.md:86` | `$ bin/plangate doctor --json` | Step 3 の実行手順 | **是正対象** |
| 8 | `.claude/agents/setup-coordinator.md:107` | `$ bin/plangate doctor --check-settings` | Step 4 の実行手順 | **是正対象** |
| 9 | `.claude/agents/setup-coordinator.md:165` | ``` - [`bin/plangate doctor`](../../bin/plangate): 単一検証源 ``` | 「関連」節のリポジトリ内**パスへのリンク**。実行手順ではなく、README 定義の「パスとしての言及」に該当 | **正当な残存** |
| 10 | `.claude/agents/workflow-conductor.md:545` | ``` 渡す（**等号形式必須**。例: `bin/plangate verify <TASK> --mode=<m> --profile=gpt-5_5_pro`。 ``` | conductor が実行する CLI 呼び出しの例 | **是正対象** |
| 11 | `.claude/agents/workflow-conductor.md:549` | ``` 従来どおり非発火（既存挙動不変）。**強制は CLI 側（`bin/plangate`）に閉じており、 ``` | 強制の所在（CLI 実体）を指す説明。実行手順ではない = CLI のパス解決機構／実体の説明 | **正当な残存** |

### 判定内訳

| 判定 | 件数 |
|------|---:|
| 是正対象 | **9** |
| 正当な残存 | **2**（#9 / #11） |
| **計** | **11** |

> **重要（AC の測り方）**: 本 patch 適用後も `grep -c 'bin/plangate'` は 3 ファイル合計で
> **11 のまま**である（2 + 7 + 2）。これは #863 項目 2 が「上流リポジトリ内実行の文脈では
> 残してよい」と定めているため、是正が「削除」ではなく「環境の明示を伴う書き分け」になるからである。
> **生の件数を AC の契約値にしてはならない**。受け入れは「導入先が字義どおり実行して失敗する
> `bin/plangate <subcommand>` が 0 件であること」で測る。適用後の残存 11 件は全て
> (a) 上流 cwd であることを併記した表記、(b) パス参照、(c) CLI 実体の説明 のいずれかである。

## 4. AC-3: degrade 手順の要否（内容で判定）

#863 項目 1 は「CLI 未導入時の degrade 手順を明記」。3 ファイルそれぞれについて内容で判定した。

### 4.1 実測（語の有無）

```sh
git show origin/main:.claude/agents/setup-coordinator.md  | grep -c 'CLI 未\|CLI 不在\|PATH\|導入先'   # → 0
git show origin/main:.claude/commands/plangate-setup.md   | grep -c 'PATH'                             # → 2
git show origin/main:.claude/agents/workflow-conductor.md | grep -c 'PATH\|導入先'                     # → 0
```

**陽性コントロール**（同じ grep が当該ファイルで実際に発火することの確認）:

```sh
git show origin/main:.claude/agents/setup-coordinator.md | grep -c '不在時のフォールバック'   # → 1
```

→ `setup-coordinator.md` の 0 は「grep が起動しなかった」ではなく**真の 0 件**である。

### 4.2 内容判定（語の有無では判定しない）

| ファイル | 現状 | degrade 手順は必要か | 根拠 |
|---|---|---|---|
| `.claude/agents/setup-coordinator.md` | 「bin/plangate 不在時のフォールバック」節が**存在する**（L35-37） | **必要**（既存節は不十分） | (a) 存在確認が `command -v bin/plangate` で、PATH 導入済み環境を誤って「不在」と判定する。(b) clone は案内するが **PATH 追加を案内していない**ので、案内どおりに clone しても次の手順が通らない。(c) 「clone しない」選択肢に対する代替手順が無い。(d) doctor の検査対象が cwd でなく CLI 本体位置である事実が書かれていない |
| `.claude/commands/plangate-setup.md` | clone + `export PATH` は**書かれている**（L7-10） | **必要**（部分的に不足） | 「CLI を導入しない場合どうするか」が無い。手順は clone を強制する形で、代替（手動チェックリスト）と「厳密な強制には CLI + hooks が必要」の明示が欠けている |
| `.claude/agents/workflow-conductor.md` | `PATH` / `導入先` の言及 **0 件**（実測） | **必要** | `--profile` 供給は CLI 呼び出しが前提。CLI 未導入の導入先では `verify` 自体が実行できず、strict profile の EHS-1/2/3 実 run 発火は成立しない。この degrade が書かれていないと「strict で検証済み」と誤記録されうる |

→ **3 ファイルすべてに degrade 手順が必要**。patch に含めた。

### 4.3 degrade 記述の根拠となる CLI 実測

`doctor` / `verify` に `--dir` 相当のオプションは無く、検査・処理対象は
**CLI 本体の位置**から解決される（cwd 非依存ではない）。

```sh
git show origin/main:bin/plangate | sed -n '165,190p'      # usage: doctor / verify に --dir 無し（validate / validate-schemas のみ --dir を持つ）
git show origin/main:bin/plangate | sed -n '385,395p'      # doctor --json → "$plangate_root/scripts/doctor_check.py"
git show origin/main:scripts/doctor_check.py | grep -n 'REPO_ROOT'   # → 40: from _paths import REPO_ROOT as REPO
git show origin/main:scripts/_paths.py | grep -n 'REPO_ROOT ='       # → 31: REPO_ROOT = Path(__file__).resolve().parents[1]
```

→ PATH 上の `plangate` を導入先で実行しても、`doctor` が検査するのは **その CLI が属する上流 clone** である。
これは `.agents/skills/ai-dev-verify/SKILL.md` の既存注記と同じ事実であり、patch でも同じ表現で明記する。

## 5. AC-2: unified diff（Human 適用用）

以下をそのままファイルへ保存して `git apply` する。**適用は Human-owned**。

```sh
# 例: 本書からブロックを抽出して保存したものを 863-4-ho.diff とする
git apply --check 863-4-ho.diff && git apply 863-4-ho.diff
```

<!-- markdownlint-disable -->

````diff
diff --git a/.claude/agents/setup-coordinator.md b/.claude/agents/setup-coordinator.md
index ab1cdb3..e52d286 100644
--- a/.claude/agents/setup-coordinator.md
+++ b/.claude/agents/setup-coordinator.md
@@ -32,9 +32,30 @@ settings.json の wiring 適用、`apply-claude-settings.sh` の実行、Hook 
 - Gate 保持（`doctor --check-settings PASS` まで完了不可）
 - 進捗の永続記録（status.md / decision-log.jsonl への append）
 
-## bin/plangate 不在時のフォールバック
+## CLI 不在時のフォールバック（導入先では既定）
 
-`bin/plangate doctor --json` を実行する前に `command -v bin/plangate` で存在確認する。不在の場合は doctor をスキップし、PlanGate フルリポジトリの clone が必要である旨と clone コマンド（`git clone https://github.com/s977043/plangate.git`）を案内して停止する（command not found でユーザーを放置しない）。
+**呼び出し表記は実行環境で変わる**。相対パス形式（`bin/plangate`）が成立するのは上流リポジトリ（`s977043/plangate`）を clone した cwd に居るときだけで、導入先には `bin/` が配置されない。導入先で PATH を通した場合のコマンド名は **`plangate`**（`bin/plangate` ではない）。
+
+存在確認は **`command -v plangate`（PATH 解決）と `[ -x ./bin/plangate ]`（上流 cwd）の両方**で行う。`command -v bin/plangate` はスラッシュを含む語を PATH 検索しない（相対パスのファイル確認になる）ため、PATH 導入済みの環境を「不在」と誤判定する。
+
+| 判定結果 | 実行する doctor |
+|---------|----------------|
+| `[ -x ./bin/plangate ]` が真（上流 cwd） | `bin/plangate doctor --json` |
+| PATH に `plangate` あり | `plangate doctor --json`（下記注意） |
+| どちらも無い（**既定**） | doctor をスキップし degrade 手順へ |
+
+> **注意: doctor の検査対象は cwd ではなく CLI 本体の位置で決まる。**
+> `doctor --json` は `scripts/doctor_check.py` へ委譲され、同スクリプトは
+> `_paths.REPO_ROOT`（= `bin/` の親）を検査対象とする。`doctor` に `--dir` 相当の
+> オプションは無いため、PATH 上の `plangate` を導入先で実行しても検査されるのは
+> **上流 clone 側**であり、導入先リポジトリではない。導入先の設定を確認する場合は
+> `.claude/settings.json` を直接読む。
+
+**degrade 手順（CLI 不在時）**: doctor をスキップし、次の 3 点を案内して停止する（command not found でユーザーを放置しない）。
+
+1. clone と PATH 追加: `git clone https://github.com/s977043/plangate.git ~/plangate && export PATH="$HOME/plangate/bin:$PATH"`
+2. 導入しない場合は [`plangate-setup`](../skills/plangate-setup/SKILL.md) Skill のチェックリストを手動突合で代替し、**「doctor で検証済み」と記録しない**
+3. ゲートの厳密な強制（EH-3 / plan_hash / presence gate）には CLI + hooks の導入が必要
 
 ## 対話フロー
 
@@ -60,7 +81,7 @@ else:
 ### Step 1: 初回検知（doctor --json）
 
 ```
-$ bin/plangate doctor --json
+$ plangate doctor --json      # 上流リポジトリの cwd では `bin/plangate doctor --json`
 → JSON 出力を取得
 → 不足項目 = [c for c in checks if c.ok == false]
 → 不足項目をユーザーに提示
@@ -83,7 +104,7 @@ $ bin/plangate doctor --json
 
 ユーザーが「やりました / 完了」と報告 →
 ```
-$ bin/plangate doctor --json
+$ plangate doctor --json      # 上流リポジトリの cwd では `bin/plangate doctor --json`
 → 再度抽出
 → 全 PASS → Step 4 へ
 → 残 FAIL → Step 2 に戻る（再提示）
@@ -104,11 +125,13 @@ doctor FAIL が解消できない場合（環境制約等）:
 ### Step 4: settings タスクロック確認（AC-12）
 
 ```
-$ bin/plangate doctor --check-settings
+$ plangate doctor --check-settings   # 上流リポジトリの cwd では `bin/plangate doctor --check-settings`
 → exit_code == 0 && stdout starts with "[check-settings] PASS:" → 次へ
 → 上記不成立 → V-1 / handoff 完了不可（ブロック）
 ```
 
+CLI 不在時は本ゲートを PASS にできない（上記「CLI 不在時のフォールバック」）。未検証のまま完了扱いにせず、degrade した事実を status.md に記録する。
+
 ### Step 5: 完了サマリ出力
 
 `status.md` 末尾に以下を**Bash heredoc 経由**で追記する:
diff --git a/.claude/agents/workflow-conductor.md b/.claude/agents/workflow-conductor.md
index 1377cbe..2508bd4 100644
--- a/.claude/agents/workflow-conductor.md
+++ b/.claude/agents/workflow-conductor.md
@@ -542,9 +542,18 @@ conductorはstatus.mdに以下のMarkdownセクションを管理する（YAML f
 
 strict profile（`model-profiles.yaml` の `validation_bias: strict`）で EHS-1/2/3 を
 実 run 発火させたい場合、conductor は V フェーズの CLI 呼び出しに `--profile=<key>` を
-渡す（**等号形式必須**。例: `bin/plangate verify <TASK> --mode=<m> --profile=gpt-5_5_pro`。
+渡す（**等号形式必須**。導入先 + PATH では `plangate verify <TASK> --mode=<m> --profile=gpt-5_5_pro`、
+上流リポジトリを clone した cwd では `bin/plangate verify <TASK> --mode=<m> --profile=gpt-5_5_pro`。
 `--mode` と同じく `--flag=value` 形式のみ受理し、スペース区切り `--profile <key>` は無視される）。CLI が
 `model-profiles.yaml` から `validation_bias` を解決し `PLANGATE_VALIDATION_BIAS` を
 内部 export する。env で明示注入済みならそれを尊重する。normal/lenient profile では
 従来どおり非発火（既存挙動不変）。**強制は CLI 側（`bin/plangate`）に閉じており、
 本補足は運用ガイドであって強制力を持たない**。
+
+> **注意: `verify` の `<TASK>` 位置引数は cwd ではなく CLI 本体の位置を基準に解決される。**
+> `verify` に `--dir` 相当のオプションは無いため、PATH 上の `plangate` を導入先で実行しても
+> 対象は導入先の `docs/working/` ではなく **その clone 側の `docs/working/`** になる。
+>
+> **CLI 未導入時の degrade**: 導入先で `verify` 自体が実行できないため、`--profile` 供給と
+> strict profile の EHS-1/2/3 実 run 発火はいずれも成立しない。V フェーズは手動レビューで
+> 代替し、**「strict profile で検証済み」とは記録しない**。
diff --git a/.claude/commands/plangate-setup.md b/.claude/commands/plangate-setup.md
index 048e937..c88909b 100644
--- a/.claude/commands/plangate-setup.md
+++ b/.claude/commands/plangate-setup.md
@@ -4,11 +4,22 @@ PlanGate の初期セットアップを対話的に実行する。
 
 ## 前提条件
 
-`bin/plangate` CLI が必要です。Plugin 単体導入では PATH に含まれないため、未導入の場合は先に PlanGate リポジトリを clone してください:
+`plangate` CLI が必要です。**呼び出し表記は実行環境で変わります**: 上流リポジトリ（`s977043/plangate`）を clone した cwd では `bin/plangate`、PATH を通した導入先では `plangate`（`bin/plangate` ではない）。Plugin 単体導入では CLI が同梱されないため、未導入の場合は先に PlanGate リポジトリを clone して PATH に追加してください:
 
     git clone https://github.com/s977043/plangate.git ~/plangate
     export PATH="$HOME/plangate/bin:$PATH"
 
+### CLI 未導入時の degrade
+
+CLI を導入しない場合、本コマンドの機械検証（`plangate doctor`）は実行できません。その場合は [`plangate-setup`](../skills/plangate-setup/SKILL.md) Skill のチェックリストを手動で突合し、**「doctor で検証済み」とは記録しない**でください。ゲートの厳密な強制（EH-3 / plan_hash / presence gate）には CLI + hooks の導入が必要です。
+
+> **注意: doctor の検査対象は cwd ではなく CLI 本体の位置で決まる。**
+> `doctor --json` は `scripts/doctor_check.py` へ委譲され、同スクリプトは
+> `_paths.REPO_ROOT`（= `bin/` の親）を検査対象とする。`doctor` に `--dir` 相当の
+> オプションは無いため、PATH 上の `plangate` を導入先で実行しても検査されるのは
+> **上流 clone 側**であり、導入先リポジトリではない。導入先の設定を確認する場合は
+> `.claude/settings.json` を直接読む。
+
 ## 引数
 
 なし（カレントディレクトリから TASK ID を動的解決する）。
@@ -20,9 +31,9 @@ PlanGate の初期セットアップを対話的に実行する。
 Agent が以下を順に実行する:
 
 1. TASK ID 動的解決
-2. `bin/plangate doctor --json` で不足項目を検知
+2. `plangate doctor --json` で不足項目を検知（上流リポジトリの cwd では `bin/plangate doctor --json`）
 3. Human-owned 操作の提示（実行はしない）
-4. ユーザー報告 → `bin/plangate doctor --json` 再実行で実体検証
+4. ユーザー報告 → `plangate doctor --json` 再実行で実体検証
 5. `status.md` 末尾に完了サマリを追記
 
 詳細仕様: [`docs/working/TASK-0107/contract-notes.md`](../../docs/working/TASK-0107/contract-notes.md)
````

<!-- markdownlint-enable -->

### 5.1 適用可否の検証記録（AC-2）

`origin/main` = `1e629fb` の worktree に対して実測（**ファイルは変更していない**。
`--check` は適用可否の検査のみを行う）:

| 検証 | コマンド | rc | 意味 |
|---|---|---:|---|
| 陽性（順方向） | `git apply --check /tmp/p1203.diff` | **0** | `1e629fb` に対して**適用可能** |
| 陰性（逆方向） | `git apply --check --reverse /tmp/p1203.diff` | **1** | 未適用状態であることの確認（既適用なら 0 になる）。3 ファイルとも `patch does not apply` |
| 変更ファイル数 | `git apply --stat /tmp/p1203.diff` | 0 | 3 files changed, **52 insertions(+), 9 deletions(-)** |
| 副作用なし | `git status --porcelain`（patch 検証後） | — | 対象 3 ファイルの変更**なし** |
| ラウンドトリップ | 本書の ` ```diff ` ブロックを機械抽出 → `git apply --check` | **0** | 抽出物は生成物と `diff` で**バイト一致**（`IDENTICAL`）。本書に貼った diff がそのまま適用可能であることの実測 |

hunk header の検算（旧行数 = context + 削除 / 新行数 = context + 追加）は
`git diff` による自動生成であり、上記 `--check` rc=0 が header 整合の機械的証明である
（header 不整合であれば `corrupt patch at line N` で rc≠0 になる）。

### 5.2 適用後の期待値

| ファイル | 適用前 `grep -c 'bin/plangate'` | 適用後 |
|---|---:|---:|
| `.claude/commands/plangate-setup.md` | 3 | 2 |
| `.claude/agents/setup-coordinator.md` | 6 | 7 |
| `.claude/agents/workflow-conductor.md` | 2 | 2 |
| **計** | **11** | **11** |

`setup-coordinator.md` が 6 → 7 に**増える**のは、環境別対照表（上流 cwd 行）と
`command -v bin/plangate` の誤用を名指しで戒める記述を追加したためである。
§3 の注記のとおり **生の件数は AC の契約値ではない**。適用後の残存 11 件はすべて
「上流 cwd を併記した表記 / パス参照 / CLI 実体の説明」であり、
**導入先が字義どおり実行して失敗する `bin/plangate <subcommand>` は 0 件**になる。

## 6. AC-5: plugin ミラーへの伝播

`scripts/sync-plugin-plangate.sh` を**実行せず**、宣言を読んで判定した。

```sh
git show origin/main:scripts/sync-plugin-plangate.sh | sed -n '20,24p'    # PLUGIN_DIR / CLAUDE_DIR の定義
git show origin/main:scripts/sync-plugin-plangate.sh | sed -n '144,146p'  # 同期対象ディレクトリの for ループ
git show origin/main:scripts/sync-plugin-plangate.sh | sed -n '73,95p'    # sync_dir のコピーループ
```

| 観点 | 実測結果 |
|---|---|
| 同期元 / 同期先 | `CLAUDE_DIR="$REPO_ROOT/.claude"` → `PLUGIN_DIR="$REPO_ROOT/plugin/plangate"` |
| 同期対象ディレクトリ | `for _dir in agents rules commands; do sync_dir "$CLAUDE_DIR/$_dir" "$PLUGIN_DIR/$_dir" "$_dir"; done` |
| ファイル単位の allowlist | **無し**。`sync_dir` は `"$_src"/*.md` 等を glob で全件走査する（`.py` の明示列挙 allowlist を持つのは `ai-loop/scripts` レーンのみで、`agents` / `commands` は対象外） |
| agents の変換 | `.md` は `_normalize_model` を通して model frontmatter を正規化してからコピー（本文は不変） |
| commands の変換 | 変換なしの `cp` |

**結論: 対象 3 ファイルはいずれも `agents` / `commands` の同期対象に含まれ、
patch 適用後に `sh scripts/sync-plugin-plangate.sh` を実行すれば
`plugin/plangate/{commands,agents}/` へ自動追従する。plugin 側の直接編集は不要。**

現状の一致確認（同期が実際に効いていることの実測）:

```sh
git show origin/main:plugin/plangate/commands/plangate-setup.md   | grep -c 'bin/plangate'   # → 3
git show origin/main:plugin/plangate/agents/setup-coordinator.md  | grep -c 'bin/plangate'   # → 6
git show origin/main:plugin/plangate/agents/workflow-conductor.md | grep -c 'bin/plangate'   # → 2
```

→ `.claude/` 側の 3 / 6 / 2 と**完全一致**。現時点で drift は無い。

## 7. Human への適用手順（Human-owned）

1. 本書 §5 の ` ```diff ` ブロックを `863-4-ho.diff` として保存する
2. `git apply --check 863-4-ho.diff` が rc=0 であることを確認する
   （base が `1e629fb` から動いている場合は 3-way `git apply --3way` か、本書の再生成を依頼する）
3. `git apply 863-4-ho.diff`
4. `sh scripts/sync-plugin-plangate.sh` で plugin ミラーへ伝播させる
5. HO パス変更のため **`lite_eligible=false` / Standard・同期 C-3 固定**
   （[`mode-classification.md`](../../../.claude/rules/mode-classification.md) 「承認境界周辺の変更 → 最低でも高」）

## 8. 未確定として残したもの

| # | 内容 |
|---|---|
| U-1 | `TASK-0863/pbi-input.md` の「13 箇所」と `1e629fb` 実測「11 箇所」の差分 2 件がいつ・どの PR で消えたかは追跡していない。本書は `1e629fb` 実測のみを根拠とする |
| U-2 | `setup-coordinator.md:165` の ``[`bin/plangate doctor`](../../bin/plangate)`` は「正当な残存」と判定したが、**リンク先 `../../bin/plangate` は plugin 導入先では解決しない**。`docs/**` / `bin/**` 参照の解決順注記（#954 のクラス C 是正）を本ファイルにも入れるべきかは本 PBI のスコープ外であり **未確定**（必要なら別 issue） |
| U-3 | `doctor --check-settings` は `scripts/check-settings-wiring.sh --target user` へ委譲されるため、`doctor --json` と違って user scope の settings を見る。CLI 不在時の degrade を「PASS にできない」と書いたが、user scope に限れば別手段で代替しうるかは検証していない **未確定** |
| U-4 | patch は base `1e629fb` に対してのみ `--check` rc=0 を実測している。Human が適用する時点で main が進んでいれば再検証が必要 |

## 9. 参照

- [#1203](https://github.com/s977043/plangate/issues/1203) / [#863](https://github.com/s977043/plangate/issues/863)
- [`docs/working/TASK-0863/pbi-input.md`](../TASK-0863/pbi-input.md) — In scope 5（本書が担う部分）
- [`plugin/plangate/README.md`](../../../plugin/plangate/README.md) — カウント対象 / 対象外の定義
- [`.agents/skills/ai-dev-plan/SKILL.md`](../../../.agents/skills/ai-dev-plan/SKILL.md) §CLI 呼び出し — 是正済みの環境別対照表の形
- [`.agents/skills/ai-dev-verify/SKILL.md`](../../../.agents/skills/ai-dev-verify/SKILL.md) §CLI 呼び出し / §CLI 不在時のフォールバック
- [`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) — AI-owned / Human-owned の分界
- [`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md) — Hardening Override 9 カテゴリ
