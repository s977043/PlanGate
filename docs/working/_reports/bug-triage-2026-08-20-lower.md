# bug backlog 棚卸し（番号下位 21 件 / 2026-08-20・差分検証版）

> **目的**: close できる issue を特定して backlog を減らす。
> **測定基点**: `origin/main` = `684949eca274ce469ed7b41a43f08e4b384f96f2`
> （`docs(release): CLAUDE.md の最新リリース節を v8.21.0 へ更新 (#1190)`）
> **依頼文の基点との差**: 依頼文は `ea1e2cc` を現 main としていたが、**取得時点の実測は `684949e`**（`ea1e2cc` の 1 commit 先。`#1190` が追加でマージされている）。本レポートは `684949e` を基点とする。
> **前回レポート**: [`bug-backlog-triage-2026-08-20.md`](./bug-backlog-triage-2026-08-20.md)（base = `2447bf8`）。本レポートは**その後の 11 commit に対する差分検証**であり、前回の分類は写していない（全 21 件について現 main で再測定した）。
> **本レポートは読み取りのみで作成した。** issue / PR への書き込み（コメント・close・ラベル・編集）は一切行っていない。

## 結論（先に）

**無条件に close 推奨できる issue（CLOSE-NOW）は 0 件。**
**ただし「あと 1 手」で close できる issue（CLOSE-AFTER-1）が 3 件**ある: **#863 / #866 / #960**。
3 件とも残っているのは **AI 側の実装ではなく Human の 1 アクション**（scope 判断 2 件・patch 適用 1 件）である。

前回（base `2447bf8`）から **分類が上がったのは #863 のみ**。`2447bf8..684949e` の 11 commit のうち、担当 21 件に触れたのは **#1182 / #1183（→ #863）** と **#1184（→ #954）** の 3 PR だけで、うち issue の AC を実際に前進させたのは **#863 の項目 3** である。

| 前回 → 今回 | issue | 理由 |
|---|---|---|
| PARTIAL / STALE → **CLOSE-AFTER-1** | **#863** | 項目 3 の**再ドリフト（宣言 12 vs 実測 13）が #1182 / #1183 で解消**。README は件数宣言を撤去し、再現コマンドの出力と一致する集合スナップショットへ置換された。現 main で再現コマンドを実行すると**宣言された 13 ファイルと完全一致**する。残るのは項目 4（HO パス）のみで、close 可否は**照会中の Human scope 判断 1 つ**に収束した。STALE も解消 |
| PARTIAL / STALE → **CLOSE-AFTER-1**（実質同じ） | **#866** | 前回も「条件付き可」。今回も同じ結論だが、`.codex` drift を**現 main で再測定して 33 件**であることを再確認した（前回と同値・悪化なし） |
| PARTIAL（変更なし・ただし最接近） | **#960** | 実体は前回と同じ（HO 6 ファイル未適用）。**CLOSE-AFTER-1 として明示的に格上げ**する — patch は main にあり、残るのは Human の適用 1 手のみ |
| PARTIAL → PARTIAL（**AC は前進したが close には届かず**） | **#954** | #1184 が `docs/ai/ai-loop/` `docs/workflows/ai-loop/` の正本 5 本 + plugin 生成物へ参照解決梯子を追加。ただしこれは **AC に載っていない追加スコープ**（#1163 系）で、未達 AC（AC-3 の `.codex` 再生成 / AC-5 marketplace 実測）は動いていない |

**残り 17 件は前回と同じ分類**。すべて現 main で 1 件ずつ再測定した結果であって、前回の写しではない。

### 分類別の件数と issue 集合

| 分類 | 件数 | issue |
|---|---:|---|
| **CLOSE-NOW** | **0** | — |
| **CLOSE-AFTER-1** | **3** | #863 / #866 / #960 |
| **PARTIAL** | **6** | #921 / #937 / #954 / #963 / #975 / #991 |
| **OPEN** | **12** | #942 / #947 / #956 / #978 / #982 / #984 / #990 / #994 / #997 / #1004 / #1009 / #1010 |
| **SUPERSEDED** | **0** | — |
| **STALE**（上記と**併存**。本文の是正が先に要る） | **7** | #866 / #947 / #956 / #990 / #994 / #1009 / #1010 |

> **#982 を PARTIAL でなく OPEN にした理由**: 前回は「PR #1160 で live 7/7 に注記済み」を根拠に PARTIAL としていたが、その注記は **全箇所が「#982 で未決」と自認している**内容であり、issue の核（`plangate ai-loop run` という案内が CLI に存在しない）を解消していない。`bin/plangate` に `ai-loop)` 分岐は **0 件**（実測）。「症状の注記」は AC 充足ではないため OPEN へ寄せた。**これは分類基準の変更であって main の後退ではない**。

### 対象集合の実測

```
$ gh issue list --repo s977043/plangate --label bug --state open --limit 100 \
    --json number --jq '.[].number' | sort -n
863 866 921 937 942 947 954 956 960 963 975 978 982 984 990 991 994 997 1004 1009 1010
1011 1018 1021 1044 1057 1081 1086 1093 1101 1102 1104 1105 1144 1151 1162 1165 1170 1178 1180
# → open bug は 40 件。うち番号下位 21 件は依頼文の列挙と完全一致（増減なし）。
```

**21 件すべてを扱った。扱えなかった issue は無い。**

---

## 1. サマリ表

| # | 分類 | 実行層 | 1 行根拠（現 main 実測） | close |
|---|---|---|---|---|
| **863** | **CLOSE-AFTER-1** | **LH** | 項目 1〜3 充足。再現コマンドが宣言スナップショット（1+10+2=13 ファイル）と**完全一致**。残 = 項目 4（HO 3 ファイル） | **Human の scope 回答 1 手で可** |
| **866** | **CLOSE-AFTER-1** / STALE | **LH** | 本文 3 案は 3 root blob 一致で充足。残 = コメント追加分（エスケープ）と `.codex` 追従（#956 従属） | **scope を本文 3 項目に限る判断で可** |
| **921** | PARTIAL | **L2** | `ta-61` の `_pending_migration` に **45 本**が現存。AC-1「0 件」に対し未達（extras 66 本中、契約利用 26 / 未移行 40） | 不可 |
| **937** | PARTIAL | **L2**+L3 | `pre-push.sample` に `check-branch-not-merged` は **0 件**（rc=1／陽性コントロール `set -` = 3 件）。呼び出し元ゼロのまま | 不可 |
| **942** | OPEN | **L3** | `.github/workflows/test.yml` の Checkout に `fetch-depth` の行が無い（`persist-credentials: false` のみ） | 不可 |
| **947** | OPEN / STALE | **L2** | 3 症状すべて現存: `ta-42:23/:61/:91`（TASK-T999 前掃除が TC-04 より後）/ `ta-25:857`（`[SKIP]` で `pass=$((pass + 1))`）/ `ta-54:118`（porcelain 絶対空） | 不可 |
| **954** | PARTIAL | **LH** | クラス A は **live 19/19 が梯子保有**（残 3 は削除済み rules の注記＝対象外）。**AC-3 の `.codex` 再生成が未達**（drift 33） | 不可 |
| **956** | OPEN / **STALE** | **LH** | `.agents/skills` ⇄ `.codex/skills` を blob 照合 → **共通 42 / drift 33**（本文は「2 件」）。汎用の drift 検出機構は CI に無い | 不可 |
| **960** | **CLOSE-AFTER-1** | **L3** | `17 項目` の残存は **HO 6 + plugin ミラー 5 + CHANGELOG 2 + working ログ**のみ。patch は `_reports/960-ho-patch.md` に既存 | **Human の patch 適用 1 手で可** |
| **963** | PARTIAL | **LH** | `/pg-check` のコマンド定義は **0 件**（`.claude/commands` / `plugin/plangate/commands` とも 6 本のみ）。`.claude/skills` 30 dir vs `.agents/skills` 40 dir で **欠落 15 / 余剰 5** | 不可 |
| **975** | PARTIAL | **L2** | `--all-events` の唯一のヒットは `:32` の「follow-up」コメント。`matcher_covers()` は `:156` に現存し、ヘッダ `⚠️ 既知の制約` も無修正 | 不可 |
| **978** | OPEN | **L2** | `source_kind` / `BUNDLED_TEMPLATE` / `HO_BOUNDARY_UNDEFINED` は `scripts/ai-loop/arbiter.py` に **0 hit**（ヒットは `docs/working/**` の計画文書のみ） | 不可 |
| **982** | OPEN | **LH** | `bin/plangate` に `ai-loop)` 分岐 **0 件**。「未決」注記が live 7 箇所に入っただけで入口は存在しない | 不可 |
| **984** | OPEN | **L2**+L3 | `check-settings-wiring.sh` の checks は **6 エントリ**（5 script + 1 引数）。example の PreToolUse は **8 ブロック**で、`check-approval-token-write.sh`（×2）と `check-git-destructive.sh` が未収載 | 不可 |
| **990** | OPEN / STALE | **L2** | 実行行の残存 **3 件**（`scripts/ai-dev-workflow:102,:129` / `scripts/apply-ui-v1-crossref.sh:41`）。本文の「残 1 件」は過小 | 不可 |
| **991** | PARTIAL | **L2** | `:381 _ai_loop_ref_base_count=$#` は 2 正本ディレクトリの**合算 1 本値**のまま。CB-2（片側全損の検出）未着手 | 不可 |
| **994** | OPEN / **STALE** | **L2** | **TC-33 検査(1) の違反検出集合が空であることを証明**: `FIXTURES_DIR:-` を持つ 26 本と `PG_HARNESS_SOURCED` を持つ 26 本が**同一集合**（差集合 = ∅）。本文の `:712-728` は現 main で `:804-808` | 不可 |
| **997** | OPEN | **L2** | `test_run_evidence.py:1160-1169` の TC-45 が `git status --porcelain -- docs/working/ai-loop-runs/` の**絶対空**を要求。誤 FAIL は現在も成立 | 不可 |
| **1004** | OPEN | **L2** | 規約 8 の例示（`tests/extras/README.md:169-197`）を検査器に通す機械検証はどこにも無い。TC-33 の走査対象は `tests/extras/ta-*.sh` のみで README を見ない | 不可 |
| **1009** | OPEN / STALE | **L2** | `sync-plugin-plangate.sh:380` の `set -- $_ai_loop_expected_refs`（未 quote）が原文のまま | 不可 |
| **1010** | OPEN / STALE | **L2** | `_t26_mk_refs_guard_sandbox`（`:552`）は `.md` 実ファイルのみを作る。本文の「30 TC」に対し `^# TC-` の見出しは **20** | 不可 |

### 実行層の凡例（依頼文の定義に準拠）

- **L1**（`.md` のみ・今すぐ着手可）: **0 件**。担当 21 件のうち「`.md` の編集だけで AC が閉じる」ものは無かった（§7 参照）
- **L2**（`.py` / `.sh` を書く → `PLANGATE_HOOK_TASK` セッションが要る）: **12 件** — #921 #937 #947 #975 #978 #984 #990 #991 #994 #997 #1004 #1009 #1010（#937 / #984 は L3 も併走）
- **L3**（HO 対象パス → AI は patch 提示まで・適用は Human）: **4 件** — #937（`bin/plangate` doctor 分）/ #942（`.github/workflows/test.yml`）/ #960（HO 6 ファイル）/ #984（`CLAUDE.md` + `.claude/settings.example.json`）
- **LH**（Human の設計判断が要る）: **6 件** — #863 #866 #954 #956 #963 #982

> **HO 判定は行番号で参照していない。** `scripts/hooks/check-plan-hash.sh` の **`_override=0` 直後の `case` ブロック（`esac` まで）** を現 main で読み、9 カテゴリ（`.claude/rules/*.md` / `.claude/settings{,.local,.example}.json` / `.claude/commands/**.md` / `.claude/agents/**.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows/*.{yml,yaml}` / `AGENTS.md`・`CLAUDE.md`）を実測した。
> **`scripts/templates/pre-push.sample` は HO 外**（#937 の主要作業は L2 であって L3 ではない）。

---

## 2. CLOSE-NOW の詳細

**CLOSE-NOW は 0 件。**

21 件について issue 本文の受入基準を 1 項目ずつ現 main と照合したが、**全項目 PASS に到達したものは無かった**。もっとも近いのは #863（4 項目中 3 項目充足）だが、項目 4 が明示的に AC に含まれているため CLOSE-NOW にはしていない（→ §3）。

> **依頼文が挙げた #1177（担当範囲外）の 87/87 充足**のような状態は、**担当 21 件には 1 件も存在しない**。番号下位帯は「古い分だけ直っている」のではなく、**古い分だけ Human 判断が滞留している**帯である（§6）。

---

## 3. CLOSE-AFTER-1 の詳細

### 3-1. #863 — CLI 依存スキルの graceful degradation

**その 1 手**: **Human が、issue の 2026-08-18 コメント C2（照会中・回答待ち）に回答する** — 「項目 1〜3 の充足をもって #863 を close し、項目 4（HO パス 3 ファイル）を新 issue へ切り出す」を選ぶ。**AI 側の追加作業は不要**（切り出し先の起票は AI が実行可能）。

#### 項目 1〜3 が充足していることの実測（close コメントにそのまま貼れる形）

```
# 測定基点: origin/main = 684949eca274ce469ed7b41a43f08e4b384f96f2

## 項目 3（plugin README の依存列挙）— 宣言と実測が一致する
$ git grep -l 'bin/plangate' origin/main -- \
    'plugin/plangate/commands/*.md' \
    'plugin/plangate/skills/*/SKILL.md' \
    'plugin/plangate/agents/*.md'
plugin/plangate/agents/setup-coordinator.md
plugin/plangate/agents/workflow-conductor.md
plugin/plangate/commands/plangate-setup.md
plugin/plangate/skills/ai-dev-exec/SKILL.md
plugin/plangate/skills/ai-dev-plan/SKILL.md
plugin/plangate/skills/ai-dev-verify/SKILL.md
plugin/plangate/skills/ai-loop-cycle/SKILL.md
plugin/plangate/skills/intent-classifier/SKILL.md
plugin/plangate/skills/local-exec-handoff/SKILL.md
plugin/plangate/skills/plan-review-gate/SKILL.md
plugin/plangate/skills/plangate-setup/SKILL.md
plugin/plangate/skills/skill-policy-router/SKILL.md
plugin/plangate/skills/working-context/SKILL.md
# → コマンド 1 / スキル 10 / エージェント 2 = 13 ファイル。
#   plugin/plangate/README.md のスナップショット一覧（commit 2447bf8 時点と明記）と
#   ファイル名の集合が完全一致する。
```

**前回（base `2447bf8`）は「README が 12 と宣言し実測 13」という再ドリフト状態だった。** PR **#1182**（`86d05f7`）/ **#1183**（`4ff26e5`）が **件数宣言そのものを撤去**し、`grep -rl 'bin/plangate' commands/*.md skills/*/SKILL.md agents/*.md` を「正」とし、その下に**測定 commit を明記した集合スナップショット**を置く形へ置換した。あわせて `docs/plangate-plugin-migration.md` の `Skills (37)` / `Commands (4)` / `Agents (23)` / `Rules (6)` という**件数見出しも全廃**され、「件数は契約値として扱わない」と本文に明記された。

> これは **「成長するディレクトリに絶対件数を書かない」規律の構造的適用**であり、#863 が指摘した不整合の再発経路そのものを塞いでいる。項目 3 は単に直っただけでなく、**同じ壊れ方をしなくなった**。

```
## 項目 1（degrade 手順の明記）— live な CLI 依存 skill に degrade 節がある
$ git grep -l 'bin/plangate' origin/main -- '.agents/skills/*/SKILL.md'
# → 10 skill。うち ai-loop-cycle の唯一のヒットは
#   「bin/plangate に ai-loop サブコマンドは存在しない」という否定文であり CLI 依存ではない
#   （= #982 の注記。カウント対象外とする理由が README にも明記済み）。

## 項目 2（PATH 解決形式への統一）— 残る bin/plangate 表記は 3 列表の 1 列目のみ
$ git show origin/main:.agents/skills/working-context/SKILL.md | sed -n '77,95p'
# → 「上流リポジトリの cwd / 導入先 + PATH あり / PATH に無い」の 3 列表。
#   相対パス形式が単独で命令されている箇所は無い。
```

#### 残る項目 4（close 後に切り出す内容）

```
$ git grep -n 'bin/plangate' origin/main -- .claude/agents/workflow-conductor.md
.claude/agents/workflow-conductor.md:545   （degrade / PATH 解決の注記なし）
.claude/agents/workflow-conductor.md:549   （同上）

$ git grep -n 'bin/plangate' origin/main -- .claude/commands/plangate-setup.md
.claude/commands/plangate-setup.md:7   （clone 案内はあるが degrade 節としては不十分）
.claude/commands/plangate-setup.md:23
.claude/commands/plangate-setup.md:25

$ git grep -c 'bin/plangate' origin/main -- .claude/agents/setup-coordinator.md
6   （:35 に「## bin/plangate 不在時のフォールバック」節あり = 3 ファイル中もっとも進んでいる）
```

3 ファイルとも HO（`.claude/agents/*.md` / `.claude/commands/*.md`）。**patch はまだ存在しない**（`docs/working/_reports/` に `863-*` は無い）。したがって「項目 4 まで #863 で持つ」を選ぶ場合は **AI の patch 作成 → Human 適用の 2 手**になり、CLOSE-AFTER-1 ではなくなる。**1 手で終わらせるなら scope を切る側を選ぶ必要がある。**

---

### 3-2. #866 — 正本宣言が三つ巴で矛盾

**その 1 手**: **Human が「close 条件を issue 本文の修正案 1〜3 に限る」と scope を確定する。**

#### 本文 3 案が充足していることの実測

```
# 測定基点: origin/main = 684949e
# 修正案 1・2（新版を .agents 正本へ反映 / sync で plugin へ伝播）
# 修正案 3（正本宣言行の是正）

$ for s in intent-classifier skill-policy-router; do
    for r in .agents/skills .claude/skills plugin/plangate/skills; do
      git rev-parse "origin/main:$r/$s/SKILL.md"; done; done

intent-classifier    .agents  9bd30492bb490e721527a1455aca7729835ccf70
intent-classifier    .claude  9bd30492bb490e721527a1455aca7729835ccf70
intent-classifier    plugin   9bd30492bb490e721527a1455aca7729835ccf70
skill-policy-router  .agents  f51d02780965b50900b3b18770476f1902453135
skill-policy-router  .claude  f51d02780965b50900b3b18770476f1902453135
skill-policy-router  plugin   f51d02780965b50900b3b18770476f1902453135
# → 本文が「三つ巴」と呼んだ 3 root は blob SHA が完全一致。版の矛盾は解消済み。
```

#### close 条件から外す必要があるもの（コメントで後から追加された scope）

1. **`.codex` 追従**（本文の「三つ巴」に含まれない 4 番目の root）

```
$ git rev-parse origin/main:.codex/skills/intent-classifier/SKILL.md
cf5df440732f19c646b85bbff1078ea545e7d299   ← 3 root と不一致
$ git rev-parse origin/main:.codex/skills/skill-policy-router/SKILL.md
c847b2cbf84cccdd581663e533125726477dc80e   ← 同上
```

2. **エスケープされたコードフェンス**（`.agents/skills/subagent-dispatch/SKILL.md`）

```
$ git show origin/main:.agents/skills/subagent-dispatch/SKILL.md | sed -n '68,75p'
\`\`\`mermaid
graph TD
  ...
\`\`\`
# → バックスラッシュエスケープが残り、mermaid ブロックとして描画されない。
```

**この 2 件は #956（`.codex` の去就）に従属する**。#956 が未裁定のまま `.codex` を触ると #956 の判断材料を壊すため、**#866 単独では解けない**。scope を本文 3 項目に切るのが構造的に正しい。

---

### 3-3. #960 — C-1 の項目数が「17」表記のまま実体 25

**その 1 手**: **Human が `docs/working/_reports/960-ho-patch.md` を HO 6 ファイルへ適用する**（patch は main に既存。AI 側の残作業は実質ゼロ）。

#### 残存が HO とミラーと歴史記録だけであることの全数照合

```
# 測定基点: origin/main = 684949e
$ git grep -lE '17[[:space:]]*項目' origin/main
```

live な正本のうち残っているのは以下の **6 + 5 + 2** のみ（他はすべて `docs/working/TASK-*/` の過去ログ）:

| 区分 | ファイル | 扱い |
|---|---|---|
| **HO（Human 適用が要る）6** | `.claude/rules/mode-classification.md` / `.claude/rules/working-context.md` / `.claude/commands/ai-dev-workflow.md` / `.claude/commands/README.md` / `.claude/agents/workflow-conductor.md` / `schemas/review-result.schema.json` | **patch 済・未適用** |
| plugin ミラー 5 | `plugin/plangate/rules/mode-classification.md` / `plugin/plangate/rules/working-context.md` / `plugin/plangate/commands/ai-dev-workflow.md` / `plugin/plangate/commands/README.md` / `plugin/plangate/agents/workflow-conductor.md` | 適用後に sync で自動追従 |
| 歴史記録 2 | `CHANGELOG.md` / `docs/changelog.md` | 据え置き（Human 確認済みの方針） |

**非 HO 層は完了済み**（陽性コントロール: `git grep -lE '25[[:space:]]*項目' origin/main` → `.agents/skills/plan-review-gate/SKILL.md` / `CLAUDE.md` / `README.md` 等がヒットし、grep 自体は起動している）。

> **注意（適用前に決めること）**: patch は `schemas/review-result.schema.json` の「phase 固有スコア（C-1 の 17 項目等、任意）」も対象に含む。**この「17」が契約値かどうか**は Human 判断だが、**patch が既に方針を含んでいる**ため、適用に同意すること自体がその判断になる。**適用しないなら patch を分割する必要がある**（現状は一体）。

---

## 4. PARTIAL / OPEN の残 AC（次の PBI の入力になる形で）

### #921 — extras の standalone 実行が内部 FAIL を exit code に反映しない（PARTIAL / L2）

**残 AC**:
1. **AC-1 / AC-2**: `tests/extras/ta-61-extra-contract.sh` の `_pending_migration()`（`:71`）に **45 本**が現存。ここが空になるまで AC-1「0 件」は達成しない
2. 母集団の実測: `tests/extras/ta-*.sh` は **66 本**、`PG_HARNESS_SOURCED` を持つのは **26 本**、持たないのは **40 本**（`_pending_migration` の 45 本とは母集団定義が違う — `ta-25` / `ta-26` / `ta-58` / `ta-59` / `ta-60` は allowlist に載りつつ既に契約シグナルを持つ）
3. **AC-6**: #914 AC-6 の代理判定を exit code ベースへ戻す + TASK-0914 handoff の V2 候補 close（**未確認**）

> 分割設計は PR #1051（`d86eef9`）で「案 B = 新 TASK ×3」として Human 裁定済み。**子 TASK の起票有無は未確認**（`docs/working/TASK-0921/slice2-split.md` が main にあることは確認したが、対応 issue 番号までは追っていない）。

### #937 — `check-branch-not-merged.sh` が誰にも呼ばれていない（PARTIAL / L2 + L3）

**残 AC**:
1. `scripts/templates/pre-push.sample` にガード呼び出しを追加（**HO 外なので AI が適用可能**。patch は `_reports/937-942-unwired-guard-patch.md` L48-54 に既存）
2. **適用後の発火実測**（patch 文書が「手順 4 を省略しないでください」と明記。`--dry-run` は該当経路を通らない）
3. `bin/plangate doctor` への検証項目追加（**L3**。HO）

**実行経路ゼロの全数確認**（現 main）:
```
$ git grep -c 'check-branch-not-merged' origin/main -- scripts/templates/pre-push.sample
（出力なし・rc=1）
$ git grep -c 'set -' origin/main -- scripts/templates/pre-push.sample
scripts/templates/pre-push.sample:3          ← 陽性コントロール。grep は起動している
```

> **責務判定の齟齬は現 main でも未解消**: patch 文書は適用を Human-owned と宣言しているが、`scripts/templates/pre-push.sample` は HO 9 カテゴリのいずれにも該当しない（`scripts/hooks/*.sh` のみが HO）。**AI が適用できるのか否かの確認が要る**（断定はしない）。

### #942 — AC-7 の差分 0 行検査が CI で一度も実行されていない（OPEN / L3）

**残 AC**:
1. `.github/workflows/test.yml` の Checkout に `fetch-depth` を指定（現状は `persist-credentials: false` のみ）
2. `ta-57` TC-14 の WARN 経路の是正
3. **Human 判断**: patch 文書第 2 部の「#942 の目的そのものを再検討すべき」提案の採否

### #947 — harness の中断耐性・会計・判定軸に 3 件の脆さ（OPEN / STALE / L2）

**残 AC（3 症状とも現存。行番号は現 main で再測定済み）**:
1. **ta-42**: `register_cleanup "$_t42_work"` は `:23`、`TASK-T999` を使う TC-04 は `:61`、`TASK-T999` ディレクトリの cleanup 登録は `:91` — **前掃除が使用より後**という順序は未修正
2. **ta-25**: `:857` で `[SKIP] TC-06 hmac_signature not yet in schema (HO patch unapplied — SKIP)` を出しつつ `pass=$((pass + 1))` — **skip を pass に会計している**
3. **ta-54**: `:118` の `git status --porcelain -- docs/workflows/ai-loop docs/ai/ai-loop` が絶対空を要求

> **本文の行番号はすべて stale**（本文 `ta-25:86` → 現 main `:857`）。§5 参照。

### #954 — 導入先で解決できない rules / docs 参照（PARTIAL / LH）

**達成済み（現 main で再測定）**:
- **クラス A**: `.agents/skills/**` で `rules/<name>.md` を参照するのは 22 ファイル、うち `${CLAUDE_PLUGIN_ROOT}/rules/` の梯子を持つのは **19**。差の 3 件（`context-packager` / `subagent-dispatch` / `subagent-team-design`）は本文を読むと**いずれも「旧 `plugin/plangate/rules/subagent-roles.md` は削除済み」という注記**であり live な参照ではない → **live 19/19 が充足**
- **クラス C**: 前回 PR #1154 で実残 0（本レポートでは再測定していない — §8 参照）

**残 AC**:
1. **AC-3 の `.codex` 側**: `.agents/skills` ⇄ `.codex/skills` の **drift 33 件**（共通 42 件中）。**#956 / #1086 の裁定に従属**
2. **AC-5**: marketplace 導入環境でクラス A / A' / C が実際に解決するかの 1 件実測（**未確認**）
3. **AC-4**: `sh tests/run-tests.sh` の baseline 維持（**未確認**。§8）

> **#1184（`10a7e23`）で追加されたもの**: `docs/ai/ai-loop/{arbiter-policy,ho-paths,related-specs}.md` / `docs/workflows/ai-loop/{agentic-six-stage-loop,loopspec}.md` の 5 本と plugin 側 `skills/ai-loop-cycle/references/` の生成物に、`.claude/rules/*.md` の 3 段解決梯子（導入先 → `${CLAUDE_PLUGIN_ROOT}/rules/` → 到達不能を明示）が追加された。**これは #954 の AC 表に無い追加スコープ**（#1163 の参照解決系）であり、**未達 AC を減らしていない**。commit message が `(#954)` を名乗っているため「#954 が前進した」と読めるが、**AC の観点では前進していない**点に注意。

### #956 — `.codex/skills/` に commit 済み drift、CI に検出機構が無い（OPEN / STALE / LH）

**残 AC**:
1. `.codex/skills` の drift 解消（**実測 33 件**。うち `plan-review-gate` のみ Human 判断依存、残り 32 件は再生成で片付く）
2. CI 検出機構の新設
3. **Human 判断**: `plan-review-gate` の独自節の去就（案 A/B/C。2026-08-02 に裁定 → 2026-08-19 コメントで案 A 推奨に**二転**し再回答なし）

**drift 33 件の全ファイル名**（`git ls-tree -r origin/main` の blob SHA 照合）:
```
acceptance-criteria-build/SKILL.md  acceptance-review/SKILL.md      ai-dev-brainstorm/SKILL.md
ai-dev-exec/SKILL.md                ai-dev-plan/SKILL.md            ai-dev-verify/SKILL.md
ai-loop-cycle/SKILL.md              architecture-sketch/SKILL.md    brainstorming/SKILL.md
codex-mvp-split/SKILL.md            context-load/SKILL.md           context-packager/SKILL.md
design-gate/SKILL.md                diff-audit/SKILL.md             edgecase-enumeration/SKILL.md
feature-implement/SKILL.md          intent-classifier/SKILL.md      known-issues-log/SKILL.md
local-exec-handoff/SKILL.md         manual-cloud-task/SKILL.md      nonfunctional-check/SKILL.md
plan-review-gate/SKILL.md           pr-decision/SKILL.md            ref-integrity-scan/SKILL.md
requirement-gap-scan/SKILL.md       review-gate/SKILL.md            review-gate/references/ui-ux-lane.md
risk-assessment/SKILL.md            skill-policy-router/SKILL.md    subagent-delegation-brief/SKILL.md
subagent-dispatch/SKILL.md          subagent-team-design/SKILL.md   working-context/SKILL.md
```
（`.agents/skills` 45 / `.codex/skills` 120 / 共通 42 / drift 33 / `.codex` に無い 3 = `README.md` + `skill-creator/assets/*` 2 件）

> **⚠️ 新規発見: リポジトリ内に #956 の前提と正面から矛盾する記述がある。**
> `tests/extras/ta-69-distribution-checks.sh` の Part 3 コメント（`:493-497`）が、**2026-08-18 の実測として**次を記録している:
> ```
> なぜ「4 root の内容一致」を assert しないか（実測 2026-08-18）:
>   .agents vs plugin : 39/39 一致（sync-plugin-plangate.sh が生成。CI が担保）
>   .agents vs .codex : 39 中 26 が **正当に相違**
>   .agents vs .claude: 24 中  8 が **正当に相違**
> 各 root は配布先ごとの適応を持つため、内容一致は不変条件として成立しない。
> ```
> つまり **「drift 33 件」を全部バグと数えてよいかがコードコメントで否定されている**。#956 の裁定は「33 件を直す」ではなく **「どの相違が正当でどれが追従漏れかを判別する規則を決める」** が本題である可能性が高い。**この矛盾は #956 の本文にもコメントにも記載されていない。**

### #963 — 同期導入で 11 ファイルが消えた（PARTIAL / LH）

**残 AC**:
1. **AC-4**: `/pg-check` が存在しない。`git ls-tree -r origin/main -- .claude/commands/ plugin/plangate/commands/` → 両者とも `README.md` / `ai-dev-workflow.md` / `ai-loop-workflow.md` / `codex-mvp-split.md` / `plangate-setup.md` / `working-context.md` の **6 本のみ**。にもかかわらず `review-gate/SKILL.md` の「### ステップ 1: `/pg-check` を実行して finding を収集する」が `.agents` / `.codex` / `plugin` の 3 root に残存（`docs/plugin-only-adoption.md` にも言及）。**Iron Law `NO MERGE WITHOUT TWO-STAGE REVIEW` の発火点が実行不能**
   - 決めること: コマンド定義を新設するか、SKILL.md のステップ 1 を実行可能な手順へ書き換えるか
2. **AC-6**: `.claude/skills` = **30 dir** vs `.agents/skills` = **40 dir**。差の内訳は **`.claude` に無い 15 件**（`ai-dev-brainstorm` / `ai-dev-exec` / `ai-dev-plan` / `ai-dev-verify` / `codex-mvp-split` / `context-packager` / `design-gate` / `evidence-ledger` / `local-exec-handoff` / `manual-cloud-task` / `plan-review-gate` / `pr-decision` / `review-gate` / `subagent-dispatch` / `working-context`）と **`.claude` にしか無い 5 件**（`hypothesis-logger` / `plan-quality-check` / `plan-quality-reviewer` / `plangate-working-discipline` / `pr-watch`）
   - **前回レポートの「10 件差」は net の差**（40−30）であり、**集合として見ると 15 欠落 + 5 余剰**。issue が求めた「同期対象にするか対象外と明記するか」を決めるには **net ではなく集合で議論する必要がある**

### #975 — `apply-claude-settings.sh` の matcher 部分集合で二重配線（PARTIAL / L2）

**残 AC**:
1. **AC-1**: `matcher_covers()`（`:156`）が偽になるケースで「既存ブロックの matcher に不足ツールだけ足す」設計へ変更。**ヘッダ `⚠️ 既知の制約` に「follow-up 扱い」と明記されたまま**（現 main で確認）
2. **AC-2**: `tests/extras/ta-59-apply-settings-merge.sh` に「settings.json 側 `"Edit"` / example 側 `"Edit|Write"`」fixture の TC を追加し、**修正前実装で FAIL することを変異注入で実証**（call site を壊す形で）
3. **AC-3**: `--all-events` opt-in フラグの実装。現 main での `--all-events` の唯一のヒットは `scripts/apply-claude-settings.sh:32` の「`--all-events` opt-in 化は follow-up」というコメント 1 件のみ

### #978 — 導入先に ho-paths.md が無いと fail-closed が発火しない（OPEN / L2）

**残 AC**:
1. `resolve_ho_patterns()` が `source_kind` を伴う構造（`HoPathsSourceKind{EXPLICIT, DOWNSTREAM, BUNDLED_TEMPLATE}`）を返す
2. `BUNDLED_TEMPLATE` 解決時の fail-closed 分岐 + reason code `HO_BOUNDARY_UNDEFINED`
3. **Human 判断**: downstream execution の識別手段（#1005 の Start gate 充足判定 / #916 へ統合するか）

**未実装の全数確認**:
```
$ git grep -n 'source_kind\|BUNDLED_TEMPLATE\|HO_BOUNDARY_UNDEFINED' origin/main
# → ヒットは docs/working/TASK-0978/pbi-input.md / TASK-1005/{plan,test-cases}.md のみ。
#   scripts/ai-loop/arbiter.py / plugin/plangate/skills/ai-loop-cycle/scripts/arbiter.py に 0 hit。
# 陽性コントロール:
$ git grep -n '_candidate_ho_paths_sources' origin/main -- plugin/plangate/skills/ai-loop-cycle/scripts/arbiter.py
:187  def _candidate_ho_paths_sources(cli_path: str | None) -> list[pathlib.Path]:
:214      for candidate in _candidate_ho_paths_sources(cli_path):
#   → 関数自体は現存し 3 段フォールバックのまま。grep は起動している。
```

### #982 — `plangate ai-loop run TASK-XXXX` が CLI に存在しない（OPEN / LH）

**残 AC**:
1. **Human 設計判断**: `ai-loop` を `bin/plangate` の正式サブコマンドにするか（案 A）、`/ai-loop-workflow` の引数仕様として確定するか（案 B）。`git show origin/main:bin/plangate | grep -c 'ai-loop)'` → **0**
2. `docs/workflows/ai-loop/execution-runbook.md` と `plan_package.py` の乖離是正
3. `derive_loopspec()` の本番呼び出し経路の新設 + テストで固定

> patch は `_reports/982-cli-entry-notation-patch.md` に既存だが、**案を選ばない形で着地している**（live 7 箇所が「#982 で未決」と自認）。**判断が下りるまで AI に着手余地は無い。**

### #984 — example 配線 3 本が checks に無い（OPEN / L2 + L3）

**残 AC**:
1. `scripts/check-settings-wiring.sh` の checks（`:61-66` の **6 エントリ**）へ 3 本を追加。未収載は **`check-approval-token-write.sh`（PreToolUse `Edit|Write` と `Bash` の 2 ブロック）** と **`check-git-destructive.sh`（PreToolUse `Bash`）**
   - 現 checks: `check-plan-exists.sh`(EH-1) / `check-c3-approval.sh`(EH-2) / `check-forbidden-files.sh`(EH-6) / `check-plan-hash.sh`(EH-3) / `${PLANGATE_HOOK_FILE:-}` 引数 / `check-delegation-commit-boundary.sh`(EH-9)
   - example の PreToolUse は **8 ブロック**（+ SessionStart 1 / PostToolUse 1 / Stop 1）
2. **EH-10 / EH-12 の採番確定**（Human）
3. doc drift 3 箇所の是正（**L3**: `CLAUDE.md` を含む）
4. **Human 判断**: 「#1092 Phase 2 として #1087 へ統合」と宣言されたが **#1087 は CLOSED**、かつ #984 の AC は 1 つも充足していない。**独立 PBI 化するか別の統合先を立てるか**

### #990 — `$var` の直後に全角文字（OPEN / STALE / L2）

**残 AC**:
1. 実行行 **3 件**の `${_n}` 化 — `scripts/ai-dev-workflow:102` / `:129`（いずれも `"TASK ID は $AI_DEV_TASK。"`。`ai_dev_prompt_gate()` / `ai_dev_prompt_exec()` 内で、`bin/plangate gate` / `exec` の**実走経路**）/ `scripts/apply-ui-v1-crossref.sh:41`（`count=$_n）`）
2. 検出機構の新設（現状ゼロ）

> patch は `_reports/990-multibyte-var-patch.md` に **3 箇所すべてを含む形で既存**。本文が「残 1 件」としているのは走査が `--include='*.sh'` で拡張子なしの `scripts/ai-dev-workflow` を取りこぼすため（§5）。

### #991 — mass-delete guard が片側正本の全損を検出しない（PARTIAL / L2）

**残 AC**:
1. **CB-2**: 正本ディレクトリ（`docs/workflows/ai-loop/` / `docs/ai/ai-loop/`）ごとに base/stale を分離集計する、または「正本ディレクトリ自体の非存在」を独立チェックとして追加。現状 `sync-plugin-plangate.sh:380-381` の `set -- $_ai_loop_expected_refs` / `_ai_loop_ref_base_count=$#` は **2 ディレクトリ合算の 1 本値**
2. 検出力を実証する負側テストを `ta-26` に追加（少数側を丸ごと消して guard が block すること／修正前実装では PASS してしまうこと）

> **CB-1 は着地済み**（`:363-375` の「保証範囲（plan 論点 C-2 で Human 承認済みの設計選択）」節に、**「少数側ディレクトリ（`docs/ai/ai-loop`）を丸ごと欠損させても stale <= base のままとなり、WARN なし・exit 0 で削除が通る（検出しない）」と明記**されている）。

### #994 — TC-33 検査(1) が移行済みファイルに対し空振り（OPEN / STALE / L2）

**残 AC**:
1. TC-33 検査(1) を「ファイル全体に `PG_HARNESS_SOURCED` が 1 度でも現れるか」ではなく **判別行そのもの**を対象にする
2. 契約移行済みファイル（`_extra-contract.sh` を source する形）も検査対象に含める

**新しい実測 — 検出集合が空であることの証明**（前回レポートより強い根拠）:

```
# 測定基点: origin/main = 684949e
# TC-33 検査(1) は 2 段の条件を通ったファイルだけを違反として報告する:
#   ta-26-plugin-sync.sh:806   grep -q 'FIXTURES_DIR:-'      → 持たなければ continue（走査対象外）
#   ta-26-plugin-sync.sh:808   ! grep -q 'PG_HARNESS_SOURCED' → 持たなければ違反
# したがって違反集合 = { FIXTURES_DIR:- を持つ } \ { PG_HARNESS_SOURCED を持つ }

$ FIXTURES_DIR:- を持つ tests/extras/ta-*.sh  = 26 本
$ PG_HARNESS_SOURCED を持つ tests/extras/ta-*.sh = 26 本
$ 2 つの集合は同一（差集合 = ∅）
# → TC-33 検査(1) が報告しうる違反は構造的に 0 件。
#   AC-9 の「単独判別への差し戻し」が起きても、差し戻したファイルが
#   PG_HARNESS_SOURCED という文字列をコメント等でどこかに 1 つでも持つ限り緑になる。
```

さらに、`tests/extras/ta-*.sh` **66 本のうち TC-33 が走査するのは 26 本**（40 本は `FIXTURES_DIR:-` を持たないため `:806` で `continue`）。**検査の射程が母集団の 4 割**である点も AC に書き込むべき。

### #997 — TC-45 が作業ツリーの dirty 状態で誤 FAIL（OPEN / L2）

**残 AC**:
1. `scripts/ai-loop/test_run_evidence.py` の `test_tc45_existing_arbiter_records_are_untouched`（`:1160-1169`）を **前後差分 / snapshot 方式**へ変更。現状は `_classify()` の後に `git status --porcelain -- docs/working/ai-loop-runs/` を実行し **`stdout.strip() == ""`（絶対空）**を要求
2. `docs/working/ai-loop-runs/` が運用出力先であることを踏まえた判定軸の明文化

> **誤 FAIL は現に成立している**（本セッションの作業ツリーに `docs/working/ai-loop-runs/` の untracked ファイルが存在する状態で開始した）。patch は `_reports/997-947c-porcelain-patch.md` に既存（#947 の ta-54 分と合冊）。

### #1004 — README 規約 8 の例示と TC-33 の抽出規則が機械的に担保されていない（OPEN / L2）

**残 AC**:
1. `tests/extras/README.md` の規約 8（`:169-197`）に置かれたコードブロックを、TC-33 の抽出規則（`_t26_unset_envs33()` = `ta-26:792-802`）へ実際に通す機械検証を追加
2. 現状 README を見る TC は TC-30 のキーワード grep のみで、**例示ブロックの構文を検査器に通す経路は存在しない**（TC-33 の走査対象は `"$PG_T26_ROOT/tests/extras/"ta-*.sh` の glob であり README を含まない）

### #1009 — 未 quote 展開で mass-delete guard が fail-open（OPEN / STALE / L2）

**残 AC**:
1. `scripts/sync-plugin-plangate.sh:380` の `set -- $_ai_loop_expected_refs`（**未 quote・原文のまま**）を、スペースを含むファイル名で壊れない形へ変更
2. `docs/working/TASK-0914/handoff.md` の River Review F-5 「accepted」判定の撤回

### #1010 — 経路1 guard の base 集計を弱める変異 2 種が通り抜ける（OPEN / STALE / L2）

**残 AC**:
1. `_t26_mk_refs_guard_sandbox`（`ta-26:552`）の src fixture に **symlink を含める**（現状は `.md` 実ファイルのみ生成するため、`nolink` 変異＝`:179` / `:204` の `[ -L "$_rf" ] && continue` を消す変異の注入先に触れない）
2. `basewiden` 変異（base 集計を広げる変異）を検出する負側 TC の追加
3. **#1011 V3-02（symlink 除外を受容のまま close するか揃えるか）の Human 判断に従属** — #1010 の `nolink` fixture は `[ -L ]` 除外の存在を pin する方向、V3-02 は除外を外す方向で**逆向き**

---

## 5. STALE の是正案

| issue | 本文の記述 | 現 main の実測 | 是正案 |
|---|---|---|---|
| **#866** | 「**三つ巴**」（3 root） | **4 root**（`.codex` が漏れている）。行数「新版 153 / 旧版 150」も実体と乖離 | 「三つ巴」→「4 root」。行数の絶対値を撤去し「`.agents` を正本とし 4 root の blob 一致で判定」という**相対 AC** へ |
| **#947** | `ta-25-approval-token-guard.sh:86` | **`:857`** | 記号アンカーへ置換（`[SKIP] TC-06 hmac_signature` の行 / `register_cleanup` / TC 名）。ta-42 `:23/:61/:91`、ta-54 `:118` は現 main で再確認済み |
| **#956** | 「commit 済みの乖離が **2 件**」 | **drift 33 件**（共通 42 中）。かつ `ta-69:493-497` が「`.agents` vs `.codex` は 39 中 26 が**正当に相違**」と実測記録している | ① 件数を契約値にせず「`.agents` ⇄ `.codex` の blob 比較で drift 0」または「**正当な相違と追従漏れを判別する規則**」へ書き換える ② **`ta-69` のコメントとの矛盾を本文に明記する**（これが無いと「33 件全部を直す」という誤った scope で着手される） |
| **#990** | 「残存箇所（全数走査）… **残 1 件**」「異常時にしか通らない」 | **実行行 3 件**。うち 2 件は `bin/plangate gate` / `exec` の実走経路 | 走査コマンドを `git grep -nP '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' origin/main -- scripts/ tests/ bin/` へ差し替える（本文の `--include='*.sh'` は拡張子なしの `scripts/ai-dev-workflow` を構造的に取りこぼす）。「異常時のみ」の深刻度評価も撤回する |
| **#994** | `ta-26-plugin-sync.sh:712-728` | **`:804`（loop）/ `:806`（`FIXTURES_DIR:-` ゲート）/ `:808`（whole-file grep）**。`_t26_unset_envs33()` は `:792` | 記号アンカーへ置換。**あわせて「検出集合が空である」という §4 の証明を本文に載せる**（現在の本文は「空振りしうる」という可能性の記述にとどまり、証明になっていない） |
| **#1009** | 「main = 起票時点」で実測 | `:380` は原文のまま（ずれなし）だが、`TASK-0914/handoff.md` の F-5 accepted 記述の行位置は要再確認 | 基点 commit を更新。`set -- $_ai_loop_expected_refs` という**文字列**をアンカーにする |
| **#1010** | 「**30 TC** を通り抜ける」「`L198` / `L200` / `L215`」 | `^# TC-` の見出しは **20**。base glob / `[ -L ]` / `_mass_delete_blocked` 呼び出しは `:179` / `:204` / `:218`（経路1）・`:381` / `:395`（経路2） | 「30 TC」→「現行 `ta-26` の全 TC」と**量化子で**書き直す。行番号を `_t26_mk_refs_guard_sandbox` / `_mass_delete_blocked` / TC 名へ置換 |

> **共通の構造**: 7 件中 4 件（#866 / #956 / #990 / #1010）が **絶対件数を issue 本文に書いたことによる陳腐化**である。`docs/plangate-plugin-migration.md` と `plugin/plangate/README.md` が #1182 / #1183 で件数宣言を全廃したのと同じ処方が、**issue 本文にも要る**。

---

## 6. 依存グラフ — 何が決まらないと何が動かないか（依存は双方向で数える）

### 6-1. クラスタ A: `.codex/skills` の去就（最大のボトルネック）

```
#1086（担当範囲外）「.codex/skills 120 ファイルを untrack するか」← Human の名指し承認（不可逆）
  │
  ├──▶ #956  .codex drift 33 件の是正方式が決まらない
  │      │  ※ #956 には独立の Human 判断がもう 1 件ある:
  │      │    plan-review-gate 独自節の去就（案 A/B/C。一度裁定 → 二転し再回答なし）
  │      │
  │      ├──▶ #954 AC-3（.codex 再生成）が完了しない
  │      │      ◀── 逆向き: #954 が「クラス A/C の正本是正」を先に完了させたことで、
  │      │           #956 で再同期すべき内容が確定した（#954 → #956 へ入力を供給）
  │      │
  │      └──▶ #866 の残件（.codex 追従 + エスケープ是正）
  │             ◀── 逆向き: #866 の scope を本文 3 項目に切ると
  │                  #956 への従属が外れ、#866 は #956 を待たずに close できる
  │
  └──▶ #1170（担当範囲外）.codex 追従を CI に載せるか
```

**双方向の実体**: #1086 → #956 → {#954, #866} は「判断待ち」の一方向依存だが、**#866 → #1086 の逆向き依存もある** — #866 が「4 root モデル」を前提に close 条件を立てると、`.claude/skills/subagent-dispatch/` が存在しない（root 間で名前集合が非対称）という事実が #1086 の untrack 判断に影響する。**#866 の scope 判断を先に下ろすと #1086 の材料が 1 つ減る。**

### 6-2. クラスタ B: mass-delete guard の設計（担当 21 件のうち 4 件が絡む）

```
#1011 V3-04（担当範囲外・_mass_delete_blocked の数値検証）
  ├──▶ #991 CB-2   ┐ 3 件とも同じ関数契約（_mass_delete_blocked）の上に載る。
  ├──▶ #1009       │ 先に V3-04 を入れると 3 件が同じ土台で書ける。
  └──▶ #1010       ┘ ◀── 逆向き: #1010 の負側 fixture が無いと V3-04 の
                        検出力を実証できない（#1011 → #1010 の依存も成立）

#1011 V3-02（symlink 除外の方向）← Human
  └──◀▶ #1010 と **相互に矛盾**する方向を向いている
        （#1010 の nolink fixture は [ -L ] 除外の存在を pin、V3-02 は除外を外す）
        → どちらかが決まるまで両方とも着手すると手戻りになる（真の相互依存）

#991 CB-2 ──▶ #1009 Phase 3 へ移管するか（Human）
       ◀── #1009 の未 quote 修正が入ると base 集計の実装が変わるため、
            CB-2 の分離集計設計は #1009 の後に書くほうが安い（逆向き依存）
```

### 6-3. クラスタ C: extras の実行契約（担当 21 件のうち 4 件が対象ファイル重複）

```
#921 Slice 2（残 45 本の移行）← 分割設計は PR #1051 で Human 裁定済み（案 B = 新 TASK ×3）
  ├──◀▶ #947   ta-25 / ta-42 / ta-54 はいずれも _pending_migration の 45 本に含まれる
  │             （#947 を先に直すと #921 の移行対象が変わり、#921 を先に進めると
  │               #947 の修正箇所が移動する = 真の相互依存）
  ├──◀▶ #994   TC-33 の走査対象（FIXTURES_DIR:- を持つ 26 本）は #921 の移行で減る。
  │             #921 が全件移行すると TC-33 の走査対象は 0 本になり検査が完全に空振りする
  │             → **#994 を直さずに #921 を完遂すると検査が無音で死ぬ**（重要）
  └──◀▶ #1004  規約 8 の例示は #921 の契約移行後の形を反映していない
                （#1004 を直す前に #921 の最終形が要る / #921 の README 更新に #1004 が要る）
```

> **この相互依存が本レポートで最も実務的に重要**: **#921 と #994 は同時に扱わないと、片方が他方を無効化する。** #921 が `_pending_migration` を空にすると `FIXTURES_DIR:-` を持つ extras が消え、TC-33 の走査対象がゼロになる。TC-33 は「対象 0 本でも `_t26_viol33` が空なので PASS」する構造（`ta-26:821` の判定は `[ -n "$_t26_hset33" ] && [ -z "$_t26_viol33" ] && [ -z "$_t26_incl33" ]`）なので、**緑のまま検出力を失う**。

### 6-4. クラスタ D: HO patch の適用（判断ではなく**適用**のみ待ち）

| issue | patch | 適用で close するか |
|---|---|---|
| **#960** | `_reports/960-ho-patch.md`（HO 6 ファイル） | **する**（→ §3-3） |
| #984 | `_reports/984-wiring-check-gap-patch.md` | しない（#1087 CLOSED 問題が残る） |
| #942 | `_reports/937-942-unwired-guard-patch.md` 第 2 部 | しない（目的の再検討提案が未裁定） |
| #937 | `_reports/937-942-unwired-guard-patch.md` 第 1 部 | しない（発火実測 + doctor 追加が残る） |
| #990 | `_reports/990-multibyte-var-patch.md` | 検出機構が残る（**ただし対象は HO 外。AI が適用可能**） |
| #997 | `_reports/997-947c-porcelain-patch.md` | **HO 外。`PLANGATE_HOOK_TASK` セッションがあれば AI が適用可能** |

### 6-5. Human 判断待ちの一覧（何の判断か）

| issue | 待っている判断 | 待ち時間 |
|---|---|---|
| **#863** | 項目 1〜3 で close して項目 4 を切り出すか、本 issue で項目 4 まで持つか（**照会中・2026-08-18 から回答なし**） | 2 日 |
| **#866** | close 条件を本文 3 項目に限るか、コメント追加分まで含めるか | — |
| **#956** | `plan-review-gate` 独自節の去就（案 A/B/C。**2026-08-02 裁定 → 2026-08-19 に案 A 推奨で二転し再回答なし**） | 1 日 |
| **#954** | AC-3 の `.codex` 部分を #956 へ正式移管するか（移管するなら**移管先 AC を #956 本文に明記**すること — #984 の前例を繰り返さないため） | — |
| **#960** | `schemas/review-result.schema.json` の「17」が契約値か（**patch に方針が含まれているため、適用への同意がそのまま判断になる**） | — |
| **#963** | `/pg-check` を復元するか記述是正するか / `.claude/skills` の 15 欠落・5 余剰を同期対象にするか対象外宣言するか | — |
| **#982** | `ai-loop` を `bin/plangate` の正式サブコマンドにするか（live 7 箇所が「未決」と自認） | — |
| **#984** | **#1087 が CLOSED なのに AC 未達** → 独立 PBI 化か別統合先か + EH-10 / EH-12 の採番 | — |
| **#937** | `scripts/templates/pre-push.sample` への適用が本当に Human-owned か（**HO 外なので AI 適用可能に見える**） | — |
| **#942** | patch 文書第 2 部の「#942 の目的そのものを再検討すべき」提案の採否 | — |
| **#978** | #916 へ統合するか独立で進めるか + #1005 の Start gate 充足判定 | — |
| **#921 / #947 / #994 / #1004** | 4 件を統合するか分けるか（§6-3 の相互依存。**分けると #921 が #994 を無効化する**） | — |

---

## 7. L1 の着手順

**担当 21 件に L1（`.md` のみで AC が閉じる）は 0 件だった。**

前回レポートは #863 項目 3 を L1（Tier 1 の 1 位）としていたが、**その作業は #1182 / #1183 で完了済み**である。残る #863 項目 4 は `.claude/agents/*.md` / `.claude/commands/*.md` = **HO パスの `.md`** であり、拡張子は `.md` でも **EH-3 は `HARDENING_OVERRIDE` で rc=2** を返すため L1 ではなく L3 になる。

### 代わりに: 費用対効果順の着手順（L1 が空なので L2 / L3 / LH を横断して並べる）

| 順 | issue | 層 | 作業 | なぜこの順か |
|---:|---|---|---|---|
| 1 | **#863** | LH | Human が照会に回答（項目 1〜3 で close + 項目 4 を新 issue へ） | **コスト 0 で backlog が 1 減る**。AI 側の作業は既に終わっている。回答が「項目 4 まで持つ」なら順位 5 へ落ちる |
| 2 | **#960** | L3 | Human が `960-ho-patch.md` を適用 → sync でミラー 5 件追従 | **本レポート中もっとも「詰まりを外せば進む」度合いが高い**。AI 側残作業ゼロ |
| 3 | **#866** | LH | Human が scope を本文 3 項目に確定 | コスト 0。ただし `.codex` 残件の追跡先を同時に決める必要がある（#956 へ） |
| 4 | **#997** | L2 | TC-45 を前後差分 / snapshot 方式へ | **もっとも独立**（他 issue への依存が実質ない）。誤 FAIL が**現に成立している**。patch も既存。HO 外 |
| 5 | **#990** | L2 | 実行行 3 箇所の `${_n}` 化 + 検出機構 | `bin/plangate gate` / `exec` の**実走経路**。patch 既存。HO 外。1 ファイル 2 箇所 + 1 ファイル 1 箇所 |
| 6 | **#921 + #994 + #1004 + #947** | L2 | **4 件を 1 PBI として扱う** | §6-3 のとおり **分けると #921 が #994 の検出力を無音で殺す**。統合が構造的に正しい。ただし規模が大きく Human の scope 承認が要る |
| 7 | **#937** | L2 | `pre-push.sample` へガード呼び出しを適用 + 発火実測 | **HO 外なので AI が適用できる可能性が高い**（patch 文書の Human-owned 宣言に根拠が書かれていない）。まず責務の確認が要る |
| 8 | **#1009 → #991 CB-2** | L2 | 未 quote 修正 → 分離集計 | §6-2 の逆向き依存により **#1009 が先**のほうが安い |
| 9 | **#975** | L2 | `--all-events` opt-in + `matcher_covers` 設計変更 + 変異注入 TC | 独立度は高いが、`SessionStart` の `gh-pin-account.sh` 既定適用（#1151 と同根）に触れるため設計判断が混じる |
| 10 | **#978 / #984 / #982 / #963 / #942 / #954 / #956 / #1010** | LH / L3 | — | **Human 判断が先**。AI 側に着手余地なし |

> **順位 1〜3 は Human の 3 アクションで backlog が 3 件減る。** 21 件の棚卸しで AI が新たに書けるコードより、この 3 アクションのほうが効果が大きい。

---

## 8. 測定方法と限界

### 8-1. 測定の規律

- **すべての測定で ref を明示**した: `git show origin/main:<path>` / `git grep <pat> origin/main -- <path>` / `git ls-tree -r origin/main -- <path>` / `git rev-parse origin/main:<path>`。**作業ツリーの `ls` / `grep` は「実測」として扱っていない**
- **行番号アンカーは stale 化している前提**で扱い、issue 本文の `file:NN` は現 main で全件再確認した（結果は §5）
- **量化子の主張は全数照合してから書いた**（`.codex` drift は 42 blob を 1 件ずつ照合、`plugin` の CLI 依存は 3 glob の全ヒットを列挙、`17 項目` の残存は全ヒットを区分した）
- **空出力を「0 件」の証拠にしていない**。`#937` の 0 件には `set -` = 3 件、`#960` の非 HO 層 0 件には `25 項目` のヒット、`#978` の 0 hit には `_candidate_ho_paths_sources` のヒットを陽性コントロールとして添えた
- **`git log --grep "#N"` を zsh のループで回さなかった**（前回レポート §9-2 の事故を踏まえ、issue 取得はすべて `python3` 経由の `subprocess` で行った）

### 8-2. 実行を避けたもの（意図的な限界）

安全指示に従い、以下は**一切実行していない**:
- `sh <任意の .py>`（#1169 / #1177）
- `scripts/sync-plugin-plangate.sh` / `scripts/install-plangate-skills-to-codex.sh` / `scripts/apply-*.sh --apply`
- `sh tests/run-tests.sh`（`ta-42` / `ta-09` が実リポジトリの `docs/working/` に書き込むため）
- issue / PR への書き込み操作

**結果として、次は「未確認」であり PASS とも FAIL とも扱っていない**:
- 各 issue の「`sh tests/run-tests.sh` が baseline（453 passed）を維持」系 AC（#954 AC-4 ほか）。**そもそもこの AC は環境で 452/453/454 に分岐するため絶対件数では達成不能**（前回レポート §8-8）
- 変異注入による検出力の実証（#1010 AC-3 / #994 の修正後検証）。本レポートの #994 は**構造証明**（集合の差が空）であって変異実走ではない
- marketplace 実環境での skill 参照解決（#954 AC-5）
- #954 クラス C の残 0 件（前回 PR #1154 の実測を**再検証していない** — 今回は AC-3 が未達で結論が変わらないため、クラス C の再測定は行っていない）
- #921 Slice 2 の子 TASK が起票済みかどうか（`slice2-split.md` が main にあることは確認したが、対応 issue 番号を追っていない）

### 8-3. worktree 隔離ガードによる制約と回避方法

worktree 隔離エージェントのコマンド検証により、以下が拒否された:

| 拒否されたもの | 回避方法 |
|---|---|
| `mkdir -p <dir> && for n in ...; do gh issue view $n > <dir>/$n.json; done`（ループ + リダイレクト + `&&` 連結） | **issue ごとに個別取得**し、一括保存をやめた。件数が多い照会は `python3` の `subprocess` で 1 コマンドにまとめた |
| `git grep -n ']\(\.\./\.\./\.\./docs/'`（括弧が unbalanced で `git grep` 自体が rc=128） | パターンを `python3` 側で組み立てるか、括弧を含まない部分文字列へ分割 |

**1 コマンド 1 目的に分割**する方針で全測定を完了できた。**測定を諦めた項目は無い。**

### 8-4. 扱えなかった issue

**なし。21 件すべてを扱った。**

---

## 9. スコープ外で見つけた問題（手は出していない・報告のみ）

### 9-1. `ta-69` のコメントが #956 / #954 AC-3 / #1170 の前提を否定している

`tests/extras/ta-69-distribution-checks.sh:493-497` が「`.agents` vs `.codex` は 39 中 26 が**正当に相違**」「各 root は配布先ごとの適応を持つため、内容一致は不変条件として成立しない」と**実測付きで記録**している。一方 #956 / #1170 / #954 AC-3 は「drift = 追従漏れ」を前提に書かれている。**どちらかが誤っている。**

**どの issue にもこの矛盾が書かれていない**ため、#1086 の裁定が「untrack する / しない」の二択で議論され、**「正当な相違と追従漏れを判別する規則」という第 3 の選択肢が検討されていない**。#1086 の判断材料として本節を提示する価値がある。

### 9-2. #921 の完遂が #994 の検査を無音で殺す

§6-3 に書いたとおり、`ta-26` TC-33 の走査対象は `FIXTURES_DIR:-` を持つ extras（現在 26 本）であり、#921 の移行が完了するとこれが 0 本になる。TC-33 の判定式（`ta-26:821`）は `[ -n "$_t26_hset33" ] && [ -z "$_t26_viol33" ] && [ -z "$_t26_incl33" ]` で、**走査対象 0 本でも `_t26_hset33`（run-tests.sh の unset 集合）が非空である限り PASS** する。

**「AC を達成すると検査が緑のまま死ぬ」という構造**であり、#921 / #994 のどちらの本文にも書かれていない。

### 9-3. `docs/plangate-plugin-migration.md` の版番号参照が正しく直っている（好例）

`#1183` で `対象バージョン: plugin 8.11.0` → `` `plugin/plangate/.claude-plugin/plugin.json` の `version`（正はこのファイル。本文に転記しない）`` へ変更された。**これは #863 の是正の副産物だが、#960（「17」の複写）/ #956（「2 件」）/ #1010（「30 TC」）が抱えているのと同じクラスの問題への処方**である。他の issue の是正案としてこの書式を流用できる。

### 9-4. `#984` の「統合先が CLOSED」問題は現 main でも未解決

前回レポート §5-2 の指摘（#984 は「#1087 へ統合」と宣言されたが #1087 は CLOSED で AC は 1 つも未達）は、`2447bf8..684949e` の 11 commit で**一切触れられていない**。**#984 のコメントも 2026-08-14 が最後**で、統合先の再検討が行われた形跡がない。

### 9-5. `#997` の誤 FAIL は本セッションでも観測された

本レポート作成セッションの開始時点で、作業ツリーの `docs/working/ai-loop-runs/` に untracked ファイルが 3 件存在した（`20260813T051733Z-c553a58.json` / `20260814T001114Z-f76155e.json` / `20260814T004007Z-3ccea39.json`）。**この状態で `test_run_evidence.py` の TC-45 を走らせれば必ず FAIL する。** #997 は理論上の懸念ではなく現に発火する状態にある（作業ツリー由来の観測なので `origin/main` では測れない — 出典を明示する）。
