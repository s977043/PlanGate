# open issue 全数棚卸しと実行計画（2026-08-24）

> **測定基点**: `origin/main` = `d5641b0`（`docs(reports): #1151 settings.example.json の上流固有配線 是正設計を追加 (#1202)`）
> **測定時刻**: 2026-08-24 19:47〜20:20
> **本レポートは読み取りのみで作成した。** issue への書き込みは #863 の close（下記 §5-1）を除き行っていない。
> **測定はすべて ref を明示した**（`git show origin/main:<path>` / `git grep <pat> origin/main` / `git ls-tree -r origin/main` / `gh api`）。共有 checkout の作業ツリーは使っていない。

---

## 0. 母集団と、前回計画との違い

### 0-1. 対象集合

| 区分 | 件数 | 備考 |
|---|---:|---|
| 棚卸し対象（開始時の open issue 全数） | **98** | bug 41 + 非 bug 57 |
| うち本棚卸しで close | 1 | #863（§5-1） |
| 棚卸し開始後に起票され、**追って棚卸し済み** | **5** | #1207 / #1208 / #1209 / #1210 / #1211（すべて 2026-08-24 11:00:57〜11:02:27Z・別セッション起票）→ **§9-3** |
| **測定終了時の open** | **102** | 98 − 1 + 5。**全 103 件を棚卸し済み**（#863 含む） |

未棚卸し 5 件の内容（**軽微ではない**）:

```text
1207  test(ci): ta-61 が extras 実行時間の 57% を占め、extras 追加ごとに 3 回分増える
1208  test(ci): ta-61 が自分の再帰実行で作った負荷により自分の timeout 180 を超過させる（偽 FAIL）
1209  test: ta-12 の cleanup が末尾 rm 依存で、中断時に実 _maintenance/maintenance.json（承認トークン）を残す
1210  test: ta-44 / ta-45 の rm -rf の変数未設定時に / を消しうる（SC2115）
1211  ci: actionlint の shellcheck 連携が 4 workflow で無限ハングする
```

**#1209 は承認トークン層、#1210 は不可逆削除**である。§6 Phase 0 が「承認境界の穴を最優先」と掲げているのに、承認トークン残留の #1209 が母集団外にある。**§10 の推奨順に従って着手すると、この 2 件は視界に入らない。**

**訂正の経緯**: 初版は「未棚卸し 2 件 / 測定終了時 99」と書いていた。**本計画は §8 に「#866 を open として質問した。原因は質問の直前に state を測らなかったこと」と自己記録しているが、その同型を母集団の締めで再発させた**（起票バッチの尾を数え切らずに確定した）。W チェック Model B が検出し、上表は訂正後の値である。

### 0-2. 前回計画（`bugfix-execution-plan-2026-08-20.md`）との差

| 観点 | 前回 | 本棚卸し |
|---|---|---|
| 対象 | **bug ラベル 39 件のみ** | **open issue 全数 98 件** |
| 非 bug 57 件 | **一度も棚卸しされていない** | 全数を実測 |
| 測定基点 | `684949e` | `d5641b0` |

**前回計画は 4 日で最低 3 箇所 stale 化していた。**本棚卸しは既存文書の主張を採用せず、各 issue で最低 1 点を再測定した。

| 前回計画の記述 | 現 main の実測 |
|---|---|
| #866 を open として掲載 | **2026-08-20 09:53Z に CLOSED/COMPLETED**（掲載時点で既に閉じていた可能性が高い） |
| Q5 の Yes 側根拠「`.codex/skills/ai-dev-exec/SKILL.md:108` が『✅ hook 等価達成』のまま」 | **3 root とも「❌ 未達成（登録 0 件）」へ是正済み**（PR #1194 が測定基点より後に merge） |
| #1180 M-1 を「1 行で直る最優先」 | **PR #1198 で解決済み**（`ta-69:229` は `plugin/plangate/skills`） |

> **教訓（本計画自身にも適用される）**: 棚卸し結果は数日で腐る。**着手前に対象 issue を 1 点測り直すこと**を各項目の前提とする。本計画も例外ではない。

---

## 1. 結論（先に読む）

### 1-1. **backlog は「close」では減らない**

98 件のうち **`CLOSE-NOW`（AI 側残作業ゼロで閉じられる）は 0 件**だった。6 バッチすべてで同じ結果である。

| verdict | 件数 | 内訳 |
|---|---:|---|
| `CLOSE-NOW` | **0** | — |
| `SUPERSEDED` | **1** | #1092 |
| `DUPLICATE` | **0** | — |
| `PROPOSAL-ONLY` | **6** | #920 #923 #980 #1002 #1015 #1098 |
| `BLOCKED` | **6** | #906 #1047 #1054 #1107 #1114 #1170 |
| `PARTIAL` | **19** | — |
| `OPEN` | **65** | — |
| （本棚卸しで close） | **1** | #863 |
| **計** | **98** | — |

> **集計方法**: この表と §2 のマトリクスは、**§9 の一覧表から機械的に数え直した値**である（ワーカー 6 本の集計を足し合わせた値ではない — 集計規約が揃っておらず食い違ったため）。

減らす手は 3 つしかない。

1. **実装する**（大半）
2. **`PROPOSAL-ONLY` 6 件を Discovery へ明示降格**する（open 件数の見かけを圧縮）
3. **`SUPERSEDED` #1092 を close または pointer 化**する

### 1-2. **bug 層と非 bug 層で欠陥の性質が逆**

| 層 | 件数 | 支配的な状態 |
|---|---:|---|
| bug ラベル | 41 | 実体はあるが **DoD 未達 / 検査が題目どおりの対象を見ていない** |
| 非 bug | 57 | **実体が無い**（非 bug 25 件バッチでは実装ゼロが 21/25） |

非 bug 層は「提案が実体化していない」方向に偏っており、close で減らせる余地はゼロだった。

### 1-3. **承認境界に、実測で確認できる穴が 3 系統ある**

本棚卸しでオーガナイザーが**自分で再現した**もの（伝聞ではない）。詳細は §3。

| 系統 | issue | 実測 |
|---|---|---|
| **表記の穴** | #1101 / #1107 | `bin/../bin/plangate` / `docs/../CLAUDE.md` / `CLAUDE.MD` が **rc=0 で素通り** |
| **経路の穴** | #1104 | 書き込みガード 5 本が `Edit\|Write` のみで **Bash 経路は素通り** |
| **repo-wide の穴** | #928 | main の ruleset が **承認 0 人・required check は `Markdown lint` 1 本のみ** |

**3 系統が同時に open である限り「HO は常時 block される」は成立しない。**

### 1-4. **配布物と正本の記述が実態と乖離している（false claim 3 件）**

| # | 記述 | 実態 |
|---|---|---|
| **#1078** | `CLAUDE.md:34`「EH-1/2/3/6/9 を Codex session 中に**物理発火**」 | `.codex/hooks.json` の top-level に `$schema_note` / `$note` が残り Codex パーサが**ファイル全体を破棄 → hook 登録 0 件** |
| **#984** | `CLAUDE.md:24`「物理配線 **6/12**」 vs `README.md:90`「物理配線は **11/12**」 | **同一リポジトリ内で相互矛盾** |
| **#960** | v8.21.0 リリースノート「C-1 を全 **25 項目**へ是正」 | live に「17 項目」が **12 ファイル**残存（HO 5 + plugin ミラー 5 + changelog 2） |

**CLAUDE.md は毎セッション読み込まれる。**#1078 と #984 は、誤情報を全セッションへ配り続けている。

### 1-5. **最大のボトルネックは実行層（L2）へのアクセス**

| 実行層 | 定義 | 件数 |
|---|---|---:|
| **L1** | `.md` のみ。`PLANGATE_HOOK_TASK` 不要 | **9** |
| **L2** | `.py` / `.sh` を書く。**`PLANGATE_HOOK_TASK` を設定した新規セッションが要る**。**`plan.md`（basename 一致）も同じ扱い**（下記） | **47** |
| **L3** | Hardening Override 対象。**AI は patch 提示まで・適用は Human** | **22** |
| **LH** | Human の設計判断が先 | **19** |
| — | 本棚卸しで close（#863） | 1 |

（層は §9 の `layer` 列の**先頭トークン**＝「最初に打てる手が属する層」で数えた。`L2+L3` は L2、`LH→L1` は LH、`L3(Slice1 は L1)` は L3 として計上している）

**L2 の 47 件は、通常セッションでは 1 件も触れない。** `PLANGATE_HOOK_TASK` は起動時固定で、実行中の `export` では効かない。**これが backlog 全体の最大の律速である。**

**`.md` の中でも `plan.md` だけは別扱い**（実測）。no-task セッションで `check-plan-hash.sh` に各パスを渡した結果:

```text
  rc=2  docs/working/TASK-9999/plan.md          ← BLOCK（basename ガード）
  rc=0  docs/working/TASK-9999/pbi-input.md
  rc=0  docs/working/TASK-9999/todo.md
  rc=0  docs/working/TASK-9999/test-cases.md
  rc=0  docs/working/_reports/x.md
```

実装は `check-plan-hash.sh` の `plan.md edited without TASK context (EH-3 bypass guard)`。**PBI の 4 成果物のうち 3 つは no-task で作れるが、`plan.md` だけ作れない。** `plan_hash` が計算できず C-3 を通せないため、**部分 PBI は実質使えない**。新規 PBI の立ち上げは丸ごと `PLANGATE_HOOK_TASK` セッション待ちになる。

### 1-6. **波及効果が最も大きい 1 件は #1135**

`docs/working/_reports/1135-ai-owned-lane-patch.md` に設計が着地済み。**AI-owned レーンを明示すれば、現在「patch 提示止まり」の 11 issue が AI から到達可能になる。**承認境界を変えない設計。ただし `scripts/hooks/check-plan-hash.sh` が HO なので**適用は Human**。

### 1-7. **patch は提示されているが、適用可能性の契約が無い**

**§1-1（backlog は close では減らない）と並ぶ、backlog が減らない構造原因の 1 つ。**
「patch 提示済み・適用待ち」で滞留している issue のほとんどは、**patch 文書に「そのとおり適用すれば所望の状態になる」ことを機械検査する手段が付いていない。** そのため Human も AI も、適用のたびに 6 ファイル前後を目で追って手編集するしかなく、着手コストが下がらない。

**欠けているのは形式ではなく契約である。** 適用可能性を保証する手段は 2 通りあり、どちらでもよい:

| 手段 | 適用可能性の検証方法 | 向いているもの |
|---|---|---|
| **unified diff 化** | `git apply --check` rc=0 かつ `git apply --check --reverse` rc≠0（＝適用可能かつ未適用） | 行単位の置換が主で、対象ファイルが安定しているもの |
| **冪等 apply スクリプト化** | `--dry-run` 既定で書き込みゼロ（前後 cksum 不変）/ 2 回目は `already applied` で rc=0 / 未知引数は rc=1 / **アンカー未検出なら全体 exit 1 かつ 1 バイトも書かない**（部分適用しない）/ 適用後の妥当性検査（`yaml.safe_load` / `actionlint` 等）/ 実 HO パスへの書き込みは `PLANGATE_APPLY_CONFIRM=1` 要求 | アンカー探索が要る・YAML/JSON の構造を保つ必要があるもの |

後者は本 repo に実績がある（`apply-ci-lint-wiring.sh` / `apply-workflow-hygiene.sh` / `apply-pr-issue-link-comment-removal.sh` が上記契約を TC で機械検査している）。**「unified diff へ変換せよ」という単一解には倒さない。**

#### 実測（`origin/main` = `9dc9cc6` / 2026-08-25 測定時点）

`docs/working/_reports/*-patch.md` を全数走査し、各文書からフェンス済みコードブロック（4 バッククォート / 3 バッククォート 両対応・再帰抽出）を取り出して `git apply --check` にかけた:

| 判定 | 本数 | 文書 |
|---|---:|---|
| `git apply --check` **rc=0**（`--reverse` はいずれも rc=1＝未適用） | **3** | `863-4-ho-patch` / `945-946-rules-patch` / `1151-settings-example-patch` |
| ファイルヘッダあり・**rc≠0** | **1** | `1144-plugin-packaging-patch`（`--- a/` は 2 行あるが hunk ヘッダが `@@ (bundled schema ブロックの直後 …)` のような自然文プレースホルダで、`git apply` は `No valid patches in input` を返す） |
| **ファイルヘッダ 0**（`--- a/` が 1 行も無い＝before/after スニペットや部分 hunk のみ） | **16** | `1011-v304-fail-open` / `1021-ta09-isolation` / `1101-normalization` / `1102-1018-blocked-oneline` / `1104-bash-route-guard` / `1135-ai-owned-lane` / `1144-root-resolution` / `1157-seeds-read-path` / `1169-sh-invocation` / `937-942-unwired-guard` / `960-ho` / `960-recurrence-guard` / `982-cli-entry-notation` / `984-wiring-check-gap` / `990-multibyte-var` / `997-947c-porcelain` |
| **計** | **20** | — |

**つまり適用可能性が何らかの形で保証されているのは 3 本のみ。残り 17 本は `git apply` もできない。**

対応する apply スクリプトも無い:

```console
$ git ls-tree -r origin/main --name-only -- scripts/ | grep -c '^scripts/apply-.*\.sh$'
38                      # 陽性コントロール: apply スクリプトは repo に 38 本ある

$ # 上記 16 本に対応する issue 番号（1011 1021 1101 1102 1104 1135 1144 1157
$ # 1169 937 960 982 984 990 997）を含む apply スクリプト
→ すべて 0 件

$ git grep -l -E '1011-v304-fail-open|1021-ta09-isolation|…|997-947c-porcelain' \
    origin/main -- scripts/ bin/
→ rc=1（0 件。patch 文書を参照する適用スクリプトは存在しない）
```

**保証する手段が無いわけではなく、この 17 本に適用されていない。**

#### コントロール

- **陽性（抽出器）**: 上表の 3 本が `git apply --check` rc=0 を返す。初版の抽出器は 4 バッククォートフェンス内の diff 文脈行（先頭が空白の ` ```sh `）を内側フェンスと誤認して `863-4-ho-patch` を取りこぼした。**フェンス認識を桁 0 限定に直して 3 本が揃うことを確認してから採用した。**
- **陽性（独立測定）**: 抽出器を通さない `git grep -c -- '--- a/' origin/main -- docs/working/_reports/` は 4 ファイルのみ（`1144-plugin-packaging`=2 / `1151-settings-example`=1 / `863-4-ho`=3 / `945-946-rules`=7、他に patch 文書でない `1163-ref-resolution-ci-design`=1）。**16 本にヘッダが無いことを抽出器と独立に確認している。**
- **陽性（grep 機構）**: 同じ `git grep -l` を `945-946-rules|863-4-ho` で撃つと rc=0 でヒットが返る（空出力が「0 件」ではなく grep 不発である可能性を排除）。
- **陰性**: `git grep -c -- 'ZZZ-NONEXISTENT-TOKEN-9x' origin/main -- docs/working/_reports/` → rc=1 / 0 件。

#### 影響する open issue（測定時点）

17 本が指す issue のうち **open は 14 件**: **#937 / #942 / #960 / #982 / #984 / #990 / #997 / #1011 / #1021 / #1101 / #1104 / #1135 / #1144 / #1157**。
（`#1102` / `#1169` は CLOSED/COMPLETED。`960-ho` と `960-recurrence-guard` は同じ #960、`1144-plugin-packaging` と `1144-root-resolution` は同じ #1144 を指す）

> **件数は契約値にしない。** patch 文書も apply スクリプトも運用で増える。上表はすべて `origin/main` = `9dc9cc6` を明示 ref にした**測定時点の値**であり、判定を再現するには同じ ref で走査コマンドごと再実行すること。なお §4 の #1114 行が記録する「`scripts/` 直下の `apply-*.sh` は 35」は、同じ ref・同じ glob での本測定では **38** だった（母集団 glob の書き方に依存する典型例。どちらも契約値にしない）。

---

## 2. verdict × 実行層 マトリクス

| 層 \ verdict | CLOSE-NOW | SUPERSEDED | PROPOSAL-ONLY | PARTIAL | OPEN | BLOCKED | 計 |
|---|---:|---:|---:|---:|---:|---:|---:|
| **L1** | 0 | 1 | 0 | 1 | 7 | 0 | **9** |
| **L2** | 0 | 0 | 0 | 10 | 34 | 3 | **47** |
| **L3** | 0 | 0 | 0 | 3 | 18 | 1 | **22** |
| **LH** | 0 | 0 | 6 | 5 | 6 | 2 | **19** |
| **—**（close 済） | 0 | 0 | 0 | 0 | 0 | 0 | **1** |
| **計** | **0** | **1** | **6** | **19** | **65** | **6** | **98** |

---

## 3. 棚卸しで確定した実害（オーガナイザーが自分で再現したもの）

**以下はワーカー報告の転記ではなく、一次ソースで再現した結果である。**

### 3-1. #1101 — Hardening Override が表記で外れる

sandbox へ展開した `check-plan-hash.sh` に対し、**`PLANGATE_HOOK_TASK=TASK-9999` を設定した状態**（＝TASK 文脈あり。plan 承認済みセッションが編集する場面）で `PLANGATE_HOOK_FILE` を変えて実行した結果:

```sh
SB=$(mktemp -d); git show origin/main:scripts/hooks/check-plan-hash.sh > "$SB/check-plan-hash.sh"
PLANGATE_HOOK_TASK=TASK-9999 PLANGATE_HOOK_FILE="<下表の値>" sh "$SB/check-plan-hash.sh"
```

```text
  rc=2  bin/plangate                              ← block（陽性コントロール）
  rc=0  bin/../bin/plangate                       ← 素通り
  rc=2  CLAUDE.md                                 ← block（陽性コントロール）
  rc=0  docs/../CLAUDE.md                         ← 素通り
  rc=0  CLAUDE.MD                                 ← 素通り（大小文字）
  rc=2  scripts/hooks/../hooks/check-plan-hash.sh ← block（陽性コントロール）
```

`_norm_target` の正規化は `./` 剥がしと `$REPO_ROOT/` 前置剥がしのみで、**`..` 解決も大小文字畳み込みも行わない**。**同じファイルを別表記で書けば HO が外れる。**陽性コントロール 3 本が rc=2 なので判定器自体は動いている。

> **env 前提の開示（W チェック Model A の指摘で追記）**: 上表は **TASK 文脈あり**の値である。`PLANGATE_HOOK_TASK` を設定しない素の env では `bin/../bin/plangate` は rc=2 になるが、**それは HO が発火したからではなく後段の「SKIP 拒否: SKIP_REASON 未設定」による**。`docs/../CLAUDE.md` と `CLAUDE.MD` の 2 行は env 条件によらず rc=0 である。**欠陥（HO が `..` と大小文字を解決しない）は両条件で成立する**が、行ごとに成立条件が異なる点を明示する。

### 3-2. #928 — repo-wide 層の保護が実質ない

`gh api repos/s977043/plangate/rulesets/14939019` の実測:

```text
  ruleset "Protect default branch" / target=branch / enforcement=active
  required_approving_review_count = 0
  dismiss_stale_reviews_on_push   = false
  require_last_push_approval      = false
  required checks = Markdown lint
```

**承認 0 人でマージでき、テストスイート（`test.yml` の `sh tests/run-tests.sh`）は required check に入っていない。**CI が赤でもマージは通る。NO MERGE BY AI を支えているのは規範層と AI 側 hook だけである。

### 3-3. #1078 — CLAUDE.md の「物理発火」が事実と異なる

```text
$ git show --stat f6e73b5        # PR #1194
 .codex/skills/ai-dev-exec/SKILL.md | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

$ .codex/hooks.json の top-level キー
['$schema_note', '$note', 'hooks']

$ git show origin/main:.codex/hooks.json | grep -c 'check-approval-token-write'
0

$ git show origin/main:CLAUDE.md | sed -n '34p'
- 物理 hook 配線: .codex/hooks.json + .codex/hooks/eh-bridge.sh — EH-1/2/3/6/9 を Codex session 中の apply_patch|Edit|Write|Bash に対し物理発火
```

**PR #1194 が変えたのは SKILL.md 1 ファイル 1 行だけ**で、配線・bridge・parse 拒否のいずれにも触れていない。`$` 始まりの注記キー 2 つが残っているため Codex のパーサ（`deny_unknown_fields`）は**ファイル全体を破棄**し、hook 登録は **0 件**である。

> ⚠️ **注記キーの単独除去 PR を作ってはならない。** `docs/ai/settings-wiring-contract.md` が「除去は `eh-bridge.sh` の I/O 契約修正と**同一 PR**で」と定めている。単独除去は「登録された ≠ 効いている」を再生産する（`eh-bridge.sh` は stdin を hook へ渡しておらず、パス解決も `scripts/hooks/` 固定で EH-13 の実体である `scripts/` 直下に到達しない）。

### 3-4. #984 — 同一リポジトリ内で数値が矛盾

```text
CLAUDE.md:24   ... Hook enforcement は 12/12 実装（物理配線 6/12 ...）
README.md:90   ... 12/12 hooks 実装済み（... 物理配線は 11/12（残り EH-7 のみ ...））
```

### 3-5. #960 — リリースノートが実態を先取りしている

テンプレ実体は **25 項目**（`docs/working/templates/review-self.md` の `^### C1-` が 25 件）。一方 live に「17 項目」が **13 ファイル**残存する:

```text
.claude/agents/workflow-conductor.md
.claude/commands/README.md
.claude/commands/ai-dev-workflow.md
.claude/rules/mode-classification.md
.claude/rules/working-context.md
schemas/review-result.schema.json          ← HO 9 カテゴリ（schemas/*.schema.json）
plugin/plangate/{agents/workflow-conductor.md, commands/README.md, commands/ai-dev-workflow.md,
                 rules/mode-classification.md, rules/working-context.md}
CHANGELOG.md / docs/changelog.md           ← 履歴・Out of scope
```

→ **HO は 6 ファイル**（`.claude/` 5 + `schemas/review-result.schema.json`）で、`960-ho-patch.md:3` の「対象: **Hardening Override 対象 6 ファイル**」と一致する。

**測定コマンド**（pathspec で絞らない / 表記ゆれを和集合で取る）:

```sh
{ git grep -l '17 項目' d5641b0; git grep -lE '17[[:space:]]*項目' d5641b0; } \
  | sed 's|^d5641b0:||' | sort -u | grep -v '^docs/working/'
# 陽性コントロール: 同条件の「25 項目」は 45 ファイル
```

**訂正の経緯**: 初版は「12 ファイル / HO 5」と書いていた。走査を `-- '*.md'` と `.md` に絞ったため **`schemas/review-result.schema.json` が構造的に脱落**し、§5-4 の「HO 6 ファイル」および patch 本体と自文書内で矛盾していた。**絞り込みで消した情報を「無い」と読む**型の誤りで、W チェック 2 体が**独立に同じ欠陥を検出**した。

**HO 6 ファイルが未適用**のまま、v8.21.0 のリリースノートが「是正済み」と書いている。patch は `docs/working/_reports/960-ho-patch.md` に既存で、**Human 裁定 Yes（2026-08-24）取得済み**。

### 3-6. #937 — patch 文書の責務宣言が過剰（AI が適用できる）

patch 文書が Human 適用とした理由を、**相手が述べた論点で読む**:

```text
$ git show origin/main:docs/working/_reports/937-942-unwired-guard-patch.md | sed -n '4p'
> AI は `.sh` / hook テンプレートを編集できない（EH-3 の no-task 経路が SKIP_REASON を要求）ため、…
```

**blocker は HO ではなく EH-3 の no-task 経路である。** 実際 HO 判定の `case` ブロックに `templates` は 0 ヒットで、`scripts/templates/pre-push.sample` は HO 9 カテゴリに含まれない。したがって本計画の層定義では **L2**（`PLANGATE_HOOK_TASK` セッションがあれば AI が適用できる）であり、Human-owned ではない。

**訂正の経緯**: 初版は「patch 文書の責務宣言が過剰」と断じ、その根拠に **HO 軸**を使っていた。相手が述べた理由（EH-3）に触れずに別の軸で反証した形で、W チェック Model B が「相手の論点に噛み合っていない」と指摘した。**結論（`PLANGATE_HOOK_TASK` 下なら AI 可）は変わらないが、根拠を EH-3 軸へ揃えた。patch 文書の記述は当時の no-task 前提では正しく、誤りではない。**

なお対象は **main 直接 push を技術層で止める pre-push テンプレート**（`responsibility-classes.md` の 3 層防御の技術層）であり、適用時は慎重に扱うこと。

---

## 4. 既存文書の stale 一覧（着手前に訂正が要るもの）

**issue 本文をそのまま読んで着手すると、存在しない作業を探すことになる。**

| 文書 | stale な記述 | 現 main の実測 |
|---|---|---|
| #1180 本文 | M-1「1 行で直る最優先」 | **PR #1198 で解決済み** |
| #1086 本文 | drift **2 件** | **33 件 / 39**（`.agents` vs `.codex` の SKILL.md blob 照合） |
| #956 本文 | drift **2 件** | 同上。ただし `.codex` は書式変換を経るため raw diff は測定軸として不適切 — **内容差 3 件は確定、総数は未確定** |
| #954 本文 | 「26 skill に残存」 | **クラス A / C とも 0 件**（`.codex` を除く） |
| #963 本文 | 「live 19 箇所 / 28 箇所が正本として名指し参照」 | 名指し参照は歴史注記へ置換済み。**残は AC-4 と AC-6 の 2 点** |
| #982 本文 | 「6 箇所で案内」 | live 9 箇所すべてが「#982 で未決」注記付きへ是正済み。**残は Human 裁定 1 回** |
| #961 本文 | stale branch **22 本** | **増えている**（`git ls-remote --heads origin` は測定時刻で変動: 20:00 時点 51 / 20:30 時点 48。**ref 固定できないので件数を契約値にしない**。#1207〜#1211 と同じく live 測定） |
| #1052 / #1053 | 「TASK-1044 の C-3 決着に BLOCKED」 | **TASK-1044 の承認記録は APPROVED で main に着地済み**（2026-08-12） |
| #1054 | 「TASK-1036 との順序を plan で明示」 | **#1036 は CLOSED/COMPLETED**（条件消化済み） |
| #1092 本文 | tracking 対象 **33 件** | 現 open bug は **40 件**。**集合が別物**（本人が 2026-08-15 に Phase 設計を自己撤回済み） |
| #1114 本文 | apply script「31 本前後」 | **増えている**（母集団 glob 依存: `scripts/` 直下の `apply-*.sh` は 35 / repo 全体の `apply-*.sh` は 42。**glob を書かない件数は検証不能なので契約値にしない**） |
| #1010 本文 | 「30 TC」 | **32 TC**（TC-35/36 追加。ただし AC 充足には無関係） |
| #936 本文 | C-1「17 項目」 | **25 項目**（主張自体は成立） |
| #1081 本文 | 「同型は 3 配布点のみ」 | **検出 B は repo 全体 0 件**（PR #1084 / `8f57e59` で是正済み） |
| #1093 本文 | 穴 (d) の例示スクリプト | 適用済みで**その 1 例は無効化**。検出器の構造欠陥 4 種は無変更 |
| `937-942-unwired-guard-patch.md` | #937 を「Human 適用」 | **HO 外＝AI 適用可**（§3-6） |
| **patch 文書 17 本**（§1-7 の内訳。`1011-v304-fail-open` / `1021-ta09-isolation` / `1101-normalization` / `1102-1018-blocked-oneline` / `1104-bash-route-guard` / `1135-ai-owned-lane` / `1144-plugin-packaging` / `1144-root-resolution` / `1157-seeds-read-path` / `1169-sh-invocation` / `937-942-unwired-guard` / `960-ho` / `960-recurrence-guard` / `982-cli-entry-notation` / `984-wiring-check-gap` / `990-multibyte-var` / `997-947c-porcelain`） | 「patch」「適用」と読める記述で、**そのまま適用できる成果物であるかのように示している** | **適用可能性の契約が無い**。`git apply --check` は rc≠0（うち 16 本は `--- a/` が 1 行も無く before/after スニペット・部分 hunk のみ、1 本は hunk ヘッダが自然文プレースホルダ）。対応する apply スクリプトも 0 件（repo に apply スクリプトは 38 本ある）。**着手時は「適用するだけ」ではなく「適用可能性の契約を与える」工数を見込むこと**（§1-7 / Phase -1） |

---

## 5. backlog を実際に減らす手

### 5-1. 済: #863 を close（2026-08-24）

Human 裁定「項目 1〜3 の充足で close し、項目 4 を新 issue へ切り出す」に基づき、**項目 2 の全 61 ヒットを 1 件ずつ分類して違反 0 件を証明**した上で close した。項目 4 は **#1203** へ切り出し済み（元 AC・split_reason・移管先 AC を明記）。

> **注**: 本棚卸しのワーカーは #863 の残作業を HO **2 ファイル**（`setup-coordinator.md` / `workflow-conductor.md`）と測り、`.claude/commands/plangate-setup.md` は PATH 注記 2 件で済んでいる可能性があるとした。**#1203 は 3 ファイルと書いている**ため、#1203 着手時に 1 ヒットずつの判定で確定させること。

### 5-2. `SUPERSEDED` 1 件 — #1092

後継 `docs/working/_reports/bugfix-execution-plan-2026-08-20.md`（基点 `684949e` / 39 件全数）が台帳を置き換えており、**本計画がさらにそれを置き換える**。#1092 本人が 2026-08-15 に Phase 設計を自己撤回済み。AC-1/2/3/5 は達成、残る価値は AC-4（統合 AC 対応表）のみ。

→ **close するか、本文を後継 pointer に置き換えるかの Human 判断**。

### 5-3. `PROPOSAL-ONLY` 6 件 — Discovery へ降格する候補

| # | 実体 | 既存 issue との重複 |
|---|---|---|
| **#920** | Phase 0 未着手 | 5 章すべてに対応先あり（State=#1025 / Evidence=#894 #874 / Builder-Blind Review=#894 / Circuit Breaker=#894 / Model Routing=#868） |
| **#923** | Phase 0 未着手 | Stop Contract=#894 / Snapshot=#1025 / failure layer=#874 / Trajectory=#908 |
| **#980** | 実装・schema ゼロ | #1035 L3 出口条件 |
| **#1002** | working dir すら無い | #1035 L3 出口条件 |
| **#1015** | `pbi-input.md` 1 ファイルのみ | #867 と Phase 0 が重複 |
| **#1098** | AC 20 件・Phase 6 段が 1 issue に同居。依存 4 件すべて OPEN | #868 #869 #910 #911 待ち |

**#920 と #923 は同型**（上位の整理で、実装は既存 issue へ分解される）。**1 つの「Phase 0 棚卸し PBI」に束ねれば 2 件同時に処理でき、SUPERSEDED 化できる可能性が高い**。ただし棚卸し未実施のため**現時点では断定できない**。

### 5-4. Human の 1 アクションで動くもの

| # | 問い | 状態 |
|---|---|---|
| **#960** | `960-ho-patch.md` を HO 6 ファイルへ適用してよいか | **Yes 裁定済み（2026-08-24）→ 適用待ち** |
| **#982** | 案 B 確定（CLI 入口は設けない）でよいか | **未裁定**。AC-1/AC-2 は実測充足済みで、残るのは「#982 で未決」という自己参照注記を解く 1 回の判断のみ |
| **#1197** | 案 A/B/C の選択 | **未裁定**。案 A なら L1・XS で本日中に閉じられる |
| **#1196** | 案 A（検出対象を生成元へ）/ 案 B（変換でパスを残す） | **未裁定**。案 B は生成物 23 本に波及 |
| **#1086** | `.codex/skills` 120 ファイルを untrack するか（a/b/c） | **未裁定**。§8 の順序警告を参照 |
| **#1062** | ta-62 の案 (a)/(b)/(c) | **未裁定**。案 (a) 試作は 773 passed **1 failed** |
| **#868** | role 正本の再建 vs #1125 の張り替え（方針衝突） | **未裁定**。issue コメントで「ご判断ください」で停止中 |
| **#1092** | close か pointer 化か | **未裁定**（§5-2） |
| **#927** | 3 案のうち案 3（現状維持＋文書明記）なら L1・XS | **未裁定** |

### 5-5. **最大の律速: `PLANGATE_HOOK_TASK` セッション**

**L2 の 47 件は通常セッションでは 1 件も触れない。** この env は起動時固定で、実行中の `export` では効かない。

**次のセッションを `PLANGATE_HOOK_TASK=TASK-XXXX` で起動することが、backlog 削減の単一で最大のレバー**である。

---

## 6. 実行順

**原則**: (1) 他 issue の停滞を解く順 (2) 承認境界の穴を塞ぐ順 (3) 1 PR で複数閉じられる束を優先。

### Phase -1 — patch 17 本に適用可能性の契約を与える（**Phase 0 の前提**）

§1-7 の実測どおり、**Phase 0 の #1101 / #1104 の patch は現状 `git apply` できず、対応する apply スクリプトも無い。** この Phase を飛ばすと、Phase 0 は「Human が patch 文書を読みながら HO ファイルを手編集する」作業になり、いま滞留している状態と同じところへ戻る。

**成果物は「適用形式の変換」ではなく「適用可能性を機械検査できる状態」。** 形式は文書ごとに 2 択（§1-7 の表）:

- **unified diff 化** — `git apply --check` rc=0 かつ `--reverse` rc≠0 を CI/手元で確認できること
- **冪等 apply スクリプト化** — dry-run 既定で書き込みゼロ / 冪等 / 未知引数 rc=1 / アンカー未検出で全体 exit 1（部分適用しない）/ 適用後の妥当性検査 / HO パスは `PLANGATE_APPLY_CONFIRM=1` 要求

| 順 | 対象 patch 文書 | 対応 issue | 備考 |
|---:|---|---|---|
| **-1a** | `1101-normalization` / `1104-bash-route-guard` | #1101 / #1104 | **Phase 0 の 1・2 の直接の前提。ここだけ先行させる価値がある** |
| **-1b** | `1135-ai-owned-lane` | #1135 | Phase 4 の前提（§1-6 の「11 issue が到達可能になる」は適用できて初めて効く） |
| **-1c** | 残り 14 本（`1011-v304-fail-open` / `1021-ta09-isolation` / `1102-1018-blocked-oneline` / `1144-plugin-packaging` / `1144-root-resolution` / `1157-seeds-read-path` / `1169-sh-invocation` / `937-942-unwired-guard` / `960-ho` / `960-recurrence-guard` / `982-cli-entry-notation` / `984-wiring-check-gap` / `990-multibyte-var` / `997-947c-porcelain`） | #937 / #942 / #960 / #982 / #984 / #990 / #997 / #1011 / #1021 / #1144 / #1157（#1102 / #1169 は CLOSED） | Phase 1〜3 に着手する順で随時。**まとめて 1 PR にしない**（対象ファイルが HO / 非 HO をまたぐ） |

**注意**: 変換そのものが HO 対象ファイルへの patch を生成する場合でも、**生成物は patch 文書側にとどまり HO ファイルは触らない**（適用は従来どおり Phase 0 以降・責務分界は不変）。件数（17 / 38）は §1-7 の測定時点の値であり契約値ではない。

### Phase 0 — 承認境界の穴（Phase -1 の次に優先）

3 系統が同時に open な限り「HO は常時 block される」は成立しない（§1-3）。

| 順 | # | 層 | 内容 | 備考 |
|---:|---|---|---|---|
| 1 | **#1101** | L3 | `_norm_target` の正規化強化（`..` 解決 / 大小文字 / 末尾空白） | patch 設計は `1101-normalization-patch.md`。**#1107 の blocker** |
| 2 | **#1104** | L3 | Bash 経路の書き込みコマンド解析器と 5 ガードの接続 | 設計は `1104-bash-route-guard-patch.md`。**#1101 より攻撃面が広い** |
| 3 | **#1107** | L3 | FS エイリアス経由（`pwd -P` 物理解決）| **#1101 マージ後**。案 A は #1101 の AC-11（fork 増加ゼロ）と衝突するため設計判断が要る |
| 4 | **#928** ②③ | Human | ruleset の承認要求・required check 追加 / approve ガード | ②は Human-owned 操作。③は hook patch 提示まで |

### Phase 1 — 記述が実態と乖離しているもの（毎セッションに誤情報が配られている）

| 順 | # | 層 | 内容 |
|---:|---|---|---|
| 5 | **#1078** | L3 | `CLAUDE.md` / `AGENTS.md` の「物理発火」訂正（patch は `TASK-1078/patches/` に用意済み）+ `eh-bridge.sh` の I/O 契約修正と注記キー除去を**同一 PR** |
| 6 | **#984** | LH→L2+L3 | `CLAUDE.md` 6/12 と `README.md` 11/12 の矛盾解消 + `checks` 3 本の昇格可否裁定 |
| 7 | **#960** | L3 | `960-ho-patch.md` の適用（**裁定 Yes 済み**）→ plugin ミラー 5 件が sync で自動追従 |

### Phase 2 — 1 PR で複数閉じられる束

| 束 | # | 層 | 根拠 |
|---|---|---|---|
| **B-1** | #933 + #934 + #936 | L1 | すべて plan / test-cases テンプレ + C-1 への必須節追加。effort S |
| **B-2** | #945 + #946 | L3 | 由来が同じ #917、対象が同じ `.claude/rules/*.md`、effort S。**Human patch を 1 回に** |
| **B-3** | #1162 + #1165 | L2 | `ta-57` を共有。**別 PR にすると衝突する** |
| **B-4** | #1009 + #1011 | L2 | 同一ファイル `sync-plugin-plangate.sh`。#1009 を先に |
| **B-5** | #920 + #923 | LH | Phase 0 棚卸しを 1 本にまとめ、SUPERSEDED 化を狙う |

### Phase 3 — 単独・最小・実害明確

| # | 層 | effort | 内容 |
|---|---|---|---|
| **#1018** | L2 | XS | plan テンプレの見出しを契約語へ。patch 完成済み。**裁定 Yes 済み** |
| **#937** | L2 | XS | 既存 patch を `pre-push.sample` へ適用（**AI 適用可** / §3-6） |
| **#942** | L3 | XS | `test.yml` に `fetch-depth: 0`。ただし AC-4（push-to-main では依然 vacuous）の扱いを先に確定 |
| **#1108** | L2 | S | `ta-45` TC-01 を no-task 経路で起動し判定を厳格化。**依存なし・変異注入まで 1 PBI で閉じられる** |
| **#913** | L3 | S | 旧「配下のみ」バナー 7 箇所を rollout-policy 参照へ。**エージェントが読むのは decision-table 側なので、旧バナーに従うと carve-out と正反対の判断をする** |
| **#1071** | L2 | S | apply script の guard 複製をやめる |
| **#990** | L2 | S | 全角文字による `set -u` unbound（実体 1 件）+ 検出テスト |
| **#1209 + #947** | L2 | S+M | **束ねる**。中断時に実 `docs/working/` へ残骸を残すクラス。`ta-12` に `register_cleanup` を入れ、`ta-42` の事前掃除順を直す |
| **#1210 + #1108** | L2 | XS+S | **束ねる**（どちらも `ta-45`）。`${var:?}` 化 + `ta-45:100` の `trap` を `register_cleanup` へ（`tests/extras/README.md` の「trap は使わない」に違反している） |
| **#1207 + #1208** | L2 | M | **束ねる**（`ta-61` の同一ループ）。#1208 は裁定が先 |

### Phase 4 — 波及効果最大（Phase 0 と並行可）

| # | 層 | 内容 |
|---|---|---|
| **#1135** | L3 | AI-owned レーンの明示。**現在「patch 提示止まり」の 11 issue が AI から到達可能になる**。承認境界は変えない設計。patch は `1135-ai-owned-lane-patch.md` に着地済み |
| **#1025** | L2 | **C-3 APPROVED が 2026-08-12 から 12 日寝ている**。実装ファイル 0 件。`PLANGATE_HOOK_TASK=TASK-1025` セッションで着手できる唯一の P0 |

---

## 7. 順序依存（守らないと手戻りする）

| 依存 | 内容 |
|---|---|
| **#994 → #921 Slice 2** | TC-33 の検出力を先に直さないと、差し戻し変異を素通りしたまま移行完了を宣言しうる |
| **#1101 → #1107** | #1101 の字句正規化が main に入るまで #1107 は測れない |
| **#1009 → #991 CB-2** | #1009 の quote 修正で base 集計の実装が変わる。分離集計設計は後の方が安い |
| **#1052 → #1053 → #1054** | #921 のサブスライスは直列 |
| **#916 → #906 / #978** | #916 が作る escalate-path 評価器に後 2 者が乗る。**統合案は 2026-08-12 に撤回済み** |
| **#908 → #909 → #910** | #869 配下は直列。#908 未着手のため 2 件が待ち |
| **#1093 → #1114** | #1114 が参照する `scripts/apply-registry.tsv` は #1093 の成果物で、main に未着地 |
| **#1025 → #1047** | #1047 の `last_error` 観測/仮説分離は**後付け困難**。#1025 exec の**前**に方針だけ決める |
| **#1086 ⇄ #956** | ⚠️ **下記の警告を参照** |

### ⚠️ #1086 と #956 の順序衝突

**#1086 の案 (a)（`.codex/skills` を gitignore + install 時生成）と、#956 の「無条件再同期」は互いに矛盾する**（削除予定のツリーを再同期することになる）。

2026-08-24 に Human は **#956 Q5=Yes（再同期する）/ Q6=B（`plan-review-gate` は `.agents` へ取り込んでから）/ Q7=B（全件追従漏れとみなす）** を裁定し、選択肢として提示された「先に #1086 を決める」は**採らなかった**。したがって再同期を先に進めるのが確定した方針である。

**ただし #1086 で (a) を選ぶ場合、再同期分は捨てることになる**点は記録しておく。

---

## 8. 本計画の限界（測っていないこと）

| 項目 | 理由 |
|---|---|
| `sh tests/run-tests.sh` の baseline | テスト実行は `docs/working/` に残骸を書き込む（#947 で実証済み）。**baseline 系 AC の充足は全件未確定** |
| #956 の drift 総数 | `.codex` は正本から書式変換を経て生成されるため raw diff は測定軸として不適切。**内容差 3 件は確定、総数は未確定** |
| #1086 のローダー側二重登録 | 隔離 `CODEX_HOME` での Codex ローダー実行が必要。repo 側の事実（120 ファイル tracked / drift 33）のみ実測 |
| #1081-A の「commands が Skills として登録される」機構 | `claude plugin details` の実行が必要で未再現。repo 側の事実（commands 6 本 / `plugin.json` に `commands` 未宣言 / 39+6=45）のみ実測 |
| #1057 の Marketplace 実体 | 導入先キャッシュ未確認。repo 側の配布物から間接に確認 |
| #920 / #923 の SUPERSEDED 断定 | 両 issue の Phase 0 が未実施。「既存 issue で代替可能」は推定であり一次照合による確定ではない |
| ~~#1207〜#1211 が母集団外~~ | **解消**。§9-3 で追って棚卸しした。**#1209 / #1210 は Phase 0 の優先順位を変えない**（#1209 は非 HO・時限・要中断・可視 / #1210 は現 main で到達経路なし）。#1209 は Phase 3 の先頭に #947 と束ねる |
| **#1207 の所要時間 / #1208 の並行度** | テスト実行が必要なため**未検証**。多重起動の**機序のみ**確認した |
| **§9 の 98 行の `verdict` / `layer` / `effort`** | **ワーカー 6 本の判定であり、オーガナイザーが 98 件すべてを一次照合したものではない**。オーガナイザーが自分で再現したのは §3 の 6 件と、各バッチから抜き取った数件のみ。§9 の個別行は**着手時に測り直す前提**である |
| §2 マトリクスの `—（close 済）` 行 | 全セル 0 で 計 1 と見えるのは、#863 の verdict `CLOSED` に対応する列を置いていないため。列和 97 + `CLOSED` 1 = 98 |

### 測定上の事故と自己訂正（記録）

- ワーカー 1 名が `git show $R:path` 形式を使い、**zsh がコロン以降をパラメータ修飾子として解釈**して別ファイルを読んでいた。これにより #1071 を一度「CLOSE-NOW」と誤判定した。リテラル ref（`git show 'origin/main:path'`）で再測定し訂正済み
- ワーカー 1 名が `case` パターンの誤りで #1081-B に「13 件の未 quote」を検出した。値のみを対象とする検出器で再測定した結果 **0 件**。誤検出のまま報告していれば逆の結論になっていた
- オーガナイザーが #866 を open として Human に質問した。**実際は 2026-08-20 に CLOSED 済み**で、しかも質問した内容と同じ判断で閉じられていた。原因は前回計画の issue 一覧を現在の open 集合として使い、**質問を出す直前に state を測らなかった**こと

---

## 9. 全 98 件一覧

> `verdict` / `layer` / `effort` は §0 の測定基点 `d5641b0` 時点。**着手前に必ず 1 点測り直すこと。**
> effort: XS=1〜3 行 / S=〜20 行 / M=〜100 行 / L=それ以上 / XL=EPIC 相当

### 9-1. bug ラベル（41 件）

| # | verdict | layer | effort | 残作業（要約） |
|---|---|---|---|---|
| 863 | **CLOSED**（本棚卸しで close） | — | — | 項目 4 は #1203 へ |
| 921 | PARTIAL | L2 | L | Slice 2（`_pending_migration` 45 本の移行） |
| 937 | OPEN | L2 | XS | 既存 patch を `pre-push.sample` へ適用（**AI 可**） |
| 942 | OPEN | L3 | XS | `test.yml` に `fetch-depth: 0`。AC-4 の扱いを先に確定 |
| 947 | OPEN | L2 | M | ta-42 事前掃除順 / ta-25 の SKIP を pass 加算しない / ta-54 を前後差分へ |
| 954 | PARTIAL | L2 | S | `.codex` 追従のみ（#956 と同時 close 可） |
| 956 | OPEN | L2+L3 | M | drift 解消 + `.codex/skills` を検査する CI |
| 960 | PARTIAL | L3 | XS | **裁定 Yes 済み**。HO patch 適用のみ |
| 963 | PARTIAL | L1+L2 | M | AC-4（`/pg-check` 不在）と AC-6（`.claude/skills` 10 本欠落） |
| 975 | OPEN | L2 | M | matcher 部分集合時の merge 設計 + `--all-events` opt-in |
| 978 | PARTIAL | L2 | M | 雛形フォールバックの fail-closed 化（AC-3 は実装済み） |
| 982 | PARTIAL | LH | XS | **Human 裁定 1 回**。docs は案 B 相当まで是正済み |
| 984 | OPEN | LH→L2+L3 | M | `checks` 3 本の昇格可否裁定 + doc 矛盾の解消 |
| 990 | OPEN | L2 | S | 全角文字の `set -u` unbound（実体 1 件）+ 検出テスト |
| 991 | PARTIAL | L2 | S | 正本ディレクトリごとの base/stale 分離集計 |
| 994 | OPEN | L2 | S | TC-33 検査(1) を行単位判定へ。**#921 Slice 2 より先** |
| 997 | OPEN | L2 | S | TC-45 を前後差分へ。**現 checkout で今 FAIL する** |
| 1004 | OPEN | L2 | M | 規約 8 のコードブロックを fixture 化して TC-33 へ |
| 1009 | OPEN | L2 | S | `set -- $_ai_loop_expected_refs` の quote 化 |
| 1010 | OPEN | L2 | S | src fixture に symlink / 非 .md を混ぜた TC |
| 1011 | OPEN | L2 | M | V3-02/04/05 の是正（V3-04 は patch 提示済み） |
| 1018 | OPEN | L2 | XS | **裁定 Yes 済み**。テンプレ見出しを契約語へ |
| 1021 | OPEN | L2 | S | ta-09 の standalone 隔離 + cleanup の rm 分岐 |
| 1044 | OPEN | L2 | S | bootstrap に直接実行判別。**dash/zsh で rc=0・bash/sh で rc=1** |
| 1057 | OPEN | LH | L | 症状 3 を #982 へ、hook 配布を #1144 へ寄せると scope が 1/3 |
| 1081 | PARTIAL | L2 | S | 検出 A のみ（B は 0 件で是正済み）。**B を切り離せば XS〜S** |
| 1086 | OPEN | LH | M | a/b/c 裁定。**drift は 2→33 件** |
| 1093 | OPEN | L2 | M | 適用待ち検出を exit code 契約へ |
| 1101 | OPEN | L3 | M | `_norm_target` 正規化。**§3-1 で再現済み** |
| 1104 | OPEN | L3 | L | Bash 経路の解析器と 5 ガードの接続 |
| 1105 | OPEN | LH | M | 事象の文書化 + 解決方式 3 案の比較 |
| 1144 | OPEN | L3 | L | 案 A（run-from-plugin）の適用。設計 patch 2 本は main に着地済み |
| 1151 | OPEN | L3 | M | patch 設計書（PR #1202 でマージ済み）の**適用** |
| 1162 | OPEN | L2 | S | 件数契約 3 箇所を下限/同値照合へ |
| 1165 | OPEN | L2 | M | 凍結リスト置換 + JSON 読込の単一定義化 |
| 1170 | BLOCKED | LH | S | blocker=#956/#1086。**是正内容自体は文言コピー 5 箇所** |
| 1178 | OPEN | L2 | M | ta-70 TC-01 の構造判定化ほか AC 全件 |
| 1180 | PARTIAL | L2 | M | M-2/M-3/M-4（**M-1 は解決済み**） |
| 1196 | OPEN | L2 | M | 案 A/B 裁定 → 実装。案 B は生成物 23 本に波及 |
| 1197 | OPEN | LH→L1 | XS〜L | **案 A なら L1 で本日中に閉じられる** |
| 1203 | OPEN | L3 | S | 11 ヒットの判定表 → patch → Human 適用 |

### 9-2. 非 bug（57 件）

| # | verdict | layer | effort | 残作業（要約） |
|---|---|---|---|---|
| 810 | OPEN | L1 | M | plan / review-self へ Unknown Discovery を additive 追加 |
| 811 | OPEN | L1(+L3) | M | Memory Promotion Gate 正本 + candidate テンプレ + append-only log |
| 867 | OPEN | L1 | M | plan テンプレへ Knowledge Delta 節。**#1015 と実施順を揃える** |
| 868 | OPEN | L3 | L | 3 層の契約導出 CI + tier 是正。**#1125 と方針衝突・裁定待ち** |
| 869 | OPEN | L2 | XL | 実質 EPIC。#908/#909/#910 が先行 |
| 870 | OPEN | L2 | XL | EPIC。未 close の子 10 件。**ツリー不整合 3 件が未是正** |
| 874 | PARTIAL | L2 | L | 契約層は main に実在。DoD は #869/#811 待ち |
| 894 | OPEN | L2 | L | Loop Control Contract（decision enum / budget / 12 fixture） |
| 906 | BLOCKED | L2 | M | blocker=#916 |
| 908 | OPEN | L2 | L | Run Evaluation Result schema + Trajectory rules v1 |
| 909 | OPEN | L2 | L | 初期 3 fixture へ expected contract manifest |
| 910 | OPEN | L2 | L | judge record の記録から |
| 911 | OPEN | L2 | XL | **#870 自身がクリティカルパス外と位置づけ。Gap analysis へ縮退が現実的** |
| 913 | OPEN | L3 | S | 旧バナー 7 箇所を rollout-policy 参照へ |
| 916 | OPEN | L2 | M | escalate-path 評価器の骨格 + carve-out glob の機械可読化 |
| 920 | PROPOSAL-ONLY | LH | XL | Phase 0 のみ。#923 と束ねる |
| 923 | PROPOSAL-ONLY | LH | XL | Phase 0 のみ。#920 と束ねる |
| 927 | OPEN | L2 | S | eligible 帯と C-2 必須の相互排他。**案 3 なら L1・XS** |
| 928 | PARTIAL | L3 | M | ②ruleset ③approve ガード。**§3-2 で再現済み** |
| 933 | OPEN | L1 | S | plan テンプレへ先行成果物の参照表。**#934 と同一 PR** |
| 934 | OPEN | L1 | S | test-cases テンプレへ出所欄 + Convention Evidence |
| 936 | OPEN | L1 | S | test-cases の制御軸 + C-1 へ削減側 1 項目 |
| 938 | OPEN | L3 | S | workflow-conductor へ待機/再開の役割 |
| 945 | OPEN | L3 | S | INDEX.md の更新規定。**#946 と同一 PR** |
| 946 | OPEN | L3 | S | 敵対レビューのラウンド設計と収束判定 |
| 961 | OPEN | LH | S | **stale branch は 50 本**。削除前にアーカイブ tag（現在 0 件） |
| 962 | OPEN | L3 | M | CLI の解決順（明示→env→cwd git root→CLI 位置） |
| 980 | PROPOSAL-ONLY | LH | XL | Phase 0-2 から |
| 981 | PARTIAL | L2 | M | 既存 c3-prime-contract への additive な差分定義のみ |
| 1002 | PROPOSAL-ONLY | LH | XL | 受入基準の実行可能化。ラベル未設定 |
| 1005 | PARTIAL | LH | L | Lane A の残 6 件 + 3 層 lifecycle の正本反映 |
| 1015 | PROPOSAL-ONLY | LH | L | Knowledge Placement Contract の正本化 |
| 1025 | PARTIAL | L2 | L | **exec のみ。C-3 APPROVED が 12 日寝ている** |
| 1029 | OPEN | L3 | M | reject 巻き戻しの CLI + invalidation の機械可読表現 |
| 1031 | OPEN | L3(Slice1 は L1) | S/M | **Slice 1 が即効性最上位** |
| 1032 | OPEN | L3 | M | close 側の統制（`types: closed` の workflow は 0 件） |
| 1035 | OPEN | L1 | XL | EPIC。**close 禁止**（配下完了ゼロ） |
| 1047 | BLOCKED | LH→L2 | S/M | blocker=#1025。**#1025 exec の前に方針だけ決める** |
| 1052 | OPEN | L2 | M | 層 B 前半 15 本の移行 |
| 1053 | OPEN | L2 | M | 層 B 後半 15 本（ta-31 の早期脱出 ×4） |
| 1054 | BLOCKED | L2 | M | blocker=#1052/#1053 |
| 1059 | OPEN | L2 | S | 分母除外 + `SIZE_OK_MAX_FILES` 値の再検証 |
| 1061 | PARTIAL | L2 | M | Subagent hook の入力スキーマ実機プローブ → 配線 patch |
| 1062 | PARTIAL | LH | M | 案 (a)/(b)/(c) 裁定。**案 (a) 試作は 1 failed** |
| 1071 | OPEN | L2 | S | apply script の guard 複製をやめる |
| 1077 | PARTIAL | LH | M | AC-3 / AC-6 の裁定。**Human マージは実績で 5→2 手** |
| 1078 | PARTIAL | L3 | L | **§3-3。patch 2 本は用意済み・未適用** |
| 1092 | **SUPERSEDED** | L1 | XS | close か pointer 化かの Human 判断 |
| 1098 | PROPOSAL-ONLY | LH | XL | 依存 4 件すべて OPEN。構想保持へ |
| 1103 | OPEN | L3 | M | doctor に jq / sed の必須検査 |
| 1107 | BLOCKED | L3 | M | blocker=#1101 |
| 1108 | OPEN | L2 | S | **本 15 件で最も着手コストが低い** |
| 1114 | BLOCKED | L2 | L | blocker=#1093 |
| 1124 | PARTIAL | LH | L | **規範追加だけで止まっている**（本文が明示的に禁じている状態） |
| 1135 | OPEN | L3 | M | **波及効果最大。patch 着地済み・Human 適用待ち** |
| 1157 | OPEN | L3 | M | 案 A〜D 裁定 → working-context へ適用 |
| 1163 | OPEN | L2 | L | 参照解決順の機械ゲート + CI 配線 |

---

### 9-3. 追加棚卸し（#1207〜#1211 / 5 件）

> §0-1 の「棚卸し開始後に起票された 5 件」を、**同じ規律で追って棚卸しした**（`origin/main` = `1e629fb`）。

| # | verdict | layer | effort | 残作業（要約） |
|---|---|---|---|---|
| 1207 | OPEN | L2 | M | `ta-61` の per-file ループが 1 本追加ごとに standalone を **3 起動**増やす。3 起動のいずれかをサンプリング化 / 差分化 / 独立 job 化 |
| 1208 | OPEN | LH→L2 | M | `ta-61:60` の `timeout 180` がハードコードで env override なし。直列化 / 同時実行上限 / timeout の負荷連動 / SKIP 降格 のいずれかを裁定 |
| 1209 | OPEN | L2 | S | `ta-12` が `register_cleanup` を持たず（実測 0 件・陽性コントロール `ta-25` は 5 件）、中断時に実 `_maintenance/maintenance.json` を残す |
| 1210 | OPEN | L2 | XS | `ta-44:129` / `ta-45:98` の `rm -rf "$var/$var"` を `${var:?}` 化。**実バグではなく防御的措置**（下記） |
| 1211 | PARTIAL | L2+L3 | L | actionlint の shellcheck 連携。回避（既定 OFF + `PG_LINT_TIMEOUT`）は main に着地済み。残るのは workflow の inline `run:` が誰にも lint されないギャップ |

#### #1209 / #1210 は Phase 0 の優先順位を変えるか → **変えない**

| 観点 | #1209 | #1210 | **Phase 0**（#1101 / #1104 / #1107） |
|---|---|---|---|
| 発火条件 | テストスイートを**中断**したときのみ | **到達経路なし** | AI の通常操作で常時 |
| 窓 | 最大 600 秒（`until=now+600`） | — | 恒久 |
| 対象 | **非 HO パスのみ**（HO 判定は maintenance より上で無条件 `exit 2`） | — | **HO 自体**を迂回 |
| 可視性 | untracked として `git status` に出る | — | 無音 |

**#1209 に実差分はある**（トークンが残ると、本来 `exit 2` の no-task 書き込みが `MAINTENANCE_SKIP exit 0` になる）。ただし **HO は貫通しない・時限・要中断・可視**の 4 点で Phase 0 より一段下。**Phase 3 の先頭に #947 と束ねて置く**（#947 の問題 1 と同じ「中断時に実 `docs/working/` へ残骸」クラスで、#947 の実害記述には #1210 の `ta-44` が作るディレクトリ名が名指しで含まれる）。

**#1210 は現 main で到達経路が存在しない**（実測）。`return 0`（SKIP）が `ta-44:73` / `ta-45:76` にあり、変数のリテラル代入は `:81-83` / `:81-82` と**後**にある。SKIP 時は `rm` 行に到達せず、到達する場合は変数が設定済み。最悪でも `/docs/working/TASK-T45` で `/` にはならない。**`${var:?}` 化は将来の退行に対する防御**である。

#### 束ねるべき組（co-edit 衝突）

| 束 | 理由 |
|---|---|
| **#1207 + #1208** | `ta-61` の**同一ループ**を触る。別 PR にすると衝突する |
| **#1209 + #947** | 同じ欠陥クラス（中断時に実 `docs/working/` へ残骸）。#947 の実害記述に #1210 の作るディレクトリ名が含まれる |
| **#1210 + #1108** | どちらも `ta-45` を触る |

**既存 98 件との厳密な重複はゼロ。** 同一クラスの既存 issue は #947 の 1 件のみ。

#### この 5 件で追加で判明したこと

- **#1207 の「12 起動増」は過小評価**。harness 実行では sandbox 内で `PG_T61_NO_RECURSE=1` 付きの `ta-61` がもう一度起動され、その nested 側も per-file ループを skip しないため、**約 2 倍**になる
- **#1211: PR #1205 の lint job は CI に配線されていない**。`git grep -l 'lint-workflows\.sh\|lint-shell\.sh' origin/main -- .github/workflows` = **0 件**（陽性コントロール: `runs-on` は 10 ファイル）。`.github/workflows/**` が HO のため `scripts/apply-ci-lint-wiring.sh` として **Human 適用待ち**。**ハングの実害は現時点ゼロだが、lint の恩恵もゼロ**

#### 未確定

- **#1207 の所要時間（681s / extras の 57%）** と **#1208 の並行度（6 プロセス / load 79）** は、テスト実行なしでは検証できない。**機序のみ確認**した（多重起動の構造は成立）

---

## 9-4. W チェック（C-3' round 1）の disposition

本計画は PR 作成前に **ai-loop の W チェック**（Model A = 順方向・設計妥当性 / Model B = 逆方向・adversarial）を、**互いの結論を見せずに独立並列**で通した。

| モデル | verdict | reject_category |
|---|---|---|
| Model A | `approve` | `none` |
| **Model B** | **`reject`** | **`documentation`** |

### 指摘と扱い（全件）

| 指摘 | 検出者 | 扱い | 反映先 |
|---|---|---|---|
| **母集団の全数主張が不成立**（未棚卸しは 2 件でなく **5 件**。測定終了時の open は 99 でなく **102**） | B | **採用** | §0-1 / §8 |
| **「17 項目」は 12 でなく 13 ファイル**。`schemas/review-result.schema.json` が pathspec `-- '*.md'` で構造的に脱落し、§3-5「HO 5」が §5-4「HO 6」および patch 本体と自文書内で矛盾 | **A と B が独立に検出** | **採用** | §3-5 |
| **§3-6 が EH-3 軸の主張を HO 軸で反証していた**（相手の論点に噛み合っていない） | B | **採用**（結論は不変・根拠を差し替え） | §3-6 |
| §3-1 の rc 表に **env 前提（TASK 文脈の有無）が未開示** | A | **採用** | §3-1 |
| §4 の #1114 / #961 の件数に **母集団 glob / 測定時刻が未記載**で検証不能 | A | **採用**（件数を契約値から外した） | §4 |
| §2 マトリクスの `—` 行が列和と合わない見え方 | A | **採用**（脚注で開示） | §8 |
| §9 の 98 行が**オーガナイザーの一次照合を経ていない**旨が未開示 | A | **採用** | §8 |
| 数値の時限爆弾化 | B | **問題なし**と判定（§9 冒頭の再測定指示・§4・§8 で回避されている） | — |
| §1 / §2 / §9 の内部整合 | **A と B が独立に全セル一致を確認** | **問題なし** | — |
| §3-2（#928 ruleset）/ §3-1 の構造 | A・B とも一次ソースで再現 | **問題なし** | — |

**Model B の reject は、いずれも本計画自身の測定ミスを突いたものであり、すべて採用した。**とくに母集団の指摘は、**本計画が §8 に自己記録した「#866 を測り直さずに扱った」失敗と同型の再発**である。

---

## 10. 次の一手（推奨）

1. **`PLANGATE_HOOK_TASK` セッションを起こす**（§5-5）— L2 の 47 件が動き出す
2. **#960 の HO patch を適用**（裁定済み・AI 側残作業ゼロ）
3. **#982 / #1197 / #1196 / #1086 / #1062 / #868 / #1092 / #927 の裁定**（§5-4）— 1 回の判断で複数が動く
4. **Phase 0（#1101 → #1104 → #1107 → #928）** — 承認境界の穴を塞ぐ
5. **#1135 の Human 適用** — patch 提示止まりだった 11 issue が AI から到達可能になる
