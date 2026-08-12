# PBI INPUT PACKAGE — TASK-1061

> 対象 issue: [#1061](https://github.com/s977043/plangate/issues/1061)
> 親 EPIC: [#1035](https://github.com/s977043/plangate/issues/1035)（HOITL → HOTL 移行トラック）
> 作成: 要件分析担当（サブエージェント委譲・独立視点）/ 2026-08-13
> 起票根拠となった実測は 2026-08-12 のオーケストレータセッション

## 0. 結論（先出し）

**issue #1061 の課題認識（適用機構が無く 8 要素と OUTCOME 契約が脱落する）は妥当だが、根拠として挙げられた 実測 1（skill がセッションから invoke できない）は誤りである。** 本 PBI は issue の In scope をそのまま実装せず、**実測に基づいて再定義する**。

| # | issue の主張 | 実測結果 | 帰結 |
|---|---|---|---|
| 実測 1 | `.claude/skills/subagent-dispatch/` が無いため Skill ツールで呼べない | **誤り（2 点）**: ①正本は `.agents/skills/subagent-dispatch/` で**実在する** ②`plangate:subagent-dispatch` として**本セッションから invoke 成功**（実行済み） | AC-1 を「配置」から「**中身の接続**」へ書き換え |
| 実測 2 | Agent / Task を matcher にした hook が 0 本 | **正しい**（`.claude/settings.example.json` の matcher は `Edit\|Write` / `Bash` / `Edit\|Write\|MultiEdit` のみ、9 箇所） | 維持。ただし後述のとおり **より適した hook イベントが存在する** |
| 実測 3 | 要素 4 / 要素 7 の脱落が stall と照合コストを生んだ | 事象は起票者の一次観測。**本 PBI では反証不能**（後述 E） | AC-7 を「防げたかの検証」から「**再発検出可能な形の資産化**」へ書き換え |
| 実測 4 | 規約はあるが適用機構が無い | 妥当 | 維持 |

**真の問題は配置ではなく、次の 4 つである。**

1. **接続の欠落**: `subagent-dispatch` skill は「ロール別分配・依存グラフ」の skill であり、本文に **必須 8 要素も OUTCOME も 1 語も出てこない**（実行して全文確認済み）。委譲プロトコル（`docs/ai/subagent-delegation/`）への導線が skill 層に存在しない。
2. **機械検証の不在**: `outcome-contract.md` §6 が 5 項目のチェックリストを**判定基準込みで**定義済みなのに、判定するのは人間（オーケストレータ）の目視だけ。
3. **`.claude/skills/` の同期外れ**: skills の同期は `.agents/skills/` → `plugin/plangate/skills/` の 1 方向で、**`.claude/skills/` はどの同期経路にも入っていない**。結果 `.agents` にあって `.claude` に無い skill が **15 件**、逆に `.claude` にしか無い skill が **5 件**（実測）。検出手段は現状ゼロ。
4. **hook 層の可能性が未評価**: Claude Code には **`SubagentStart` / `SubagentStop` という専用 hook イベントが存在する**（issue はこれを知らずに PreToolUse matcher だけを検討している）。

---

## 1. Context / Why

### 1.1 背景

サブエージェント委譲プロトコル（必須 8 要素 / OUTCOME 契約 / オーケストレータ責務チェックリスト）は #710〜#716 で整備され、正本は `docs/ai/subagent-delegation/` 配下 6 ファイル・計 1425 行として存在する（実測: `wc -l`）。関連 issue #710 / #711 / #713 はすべて CLOSED。

しかし **委託の瞬間にこれらが読まれる導線が無い**。オーケストレータは毎回テンプレートを記憶で再構成し、要素が脱落している。

### 1.2 起票根拠（2026-08-12 セッション / 起票者の一次観測）

| 指標 | 値 |
|---|---|
| AI 同士の往復 | 約 29 回（TASK-1044: 14 / TASK-1045: 11 / TASK-1036: 4） |
| 人間を待った回数 | 4 回 |
| 最終レビューラウンドでも major が出た PBI | 3 / 3 |
| うちオーケストレータの是正指示が新しい穴を作った | 2 件 |

**人間はボトルネックではない**（29 : 4）。ボトルネックは AI 側のレビュー収束ループであり、その一因が「1 ラウンド目で防げたはずの失敗」である。

### 1.3 却下済み仮説（再提案しない）

| 仮説 | 却下理由 |
|---|---|
| 人間の承認がボトルネック | AI 往復 29 : 人間 4。承認は 1 バッチで出ている |
| ai-loop の適用帯を広げれば AI カバレッジが上がる | 重い 3 PBI では最終ラウンドまで major が出続けた。#1035 の「品質起因 escalate ゼロ」は軽い帯の実測であり外挿不能 |
| #1059（`changed_files` の分母定義）が本丸 | 除外だけでは帯は実質化しない（TASK-1036 の実コード相当は 3 本 > `SIZE_OK_MAX_FILES=2`）。起票者が訂正済み |

---

## 2. 調査結果（実測・本 PBI の前提）

すべて本 worktree（`origin/main` = 288207d 基点）で実行した実測値。**未実測の項目は明示的に「未検証」と記す。**

### A. skill の invoke 可否

| 項目 | 実測 |
|---|---|
| `.agents/skills/subagent-dispatch/` | **存在する**（skills の正本。CLAUDE.md「共有スキル: `.agents/skills/`（Codex CLI と共用）」） |
| `plugin/plangate/skills/subagent-dispatch/SKILL.md` | 存在する。`.agents` 側との差分 **0**（`diff` exit 0） |
| `.claude/skills/subagent-dispatch/` | 存在しない（issue の記述どおり） |
| **セッションからの invoke** | **`Skill` ツールで `plangate:subagent-dispatch` を実行し全文取得に成功**。実体は installed plugin cache（`~/.claude/plugins/cache/plangate/plangate/8.18.0/skills/subagent-dispatch`） |

**frontmatter 要件**（`.claude/skills/` 側の実測サンプル 3 件）: `---` で囲んだ `name:` と `description:` の 2 キーのみ。`description` に「Use when: … / Do not use when: …」を含める運用（`plangate-working-discipline` / `codex-multi-agent` / `subagent-team-design` すべてこの形）。`plugin` 側 `subagent-dispatch` も同じ 2 キー構成。**追加の必須キーは無い**。

**ただし invoke 経路には version lag がある**: plugin skill の実体は **リリース済みバージョンの cache（8.18.0）** であり、リポジトリ HEAD ではない。自己言及的で頻繁に iterate するガバナンス skill を plugin 経路だけに置くと、**編集しても次リリースまで反映されない**。これは「呼べない」とは別クラスの実害であり、`.claude/skills/` に置く動機として**issue の主張より強い**。

### B. 同期方向と正本

`scripts/sync-plugin-plangate.sh` の実測（L24, L149-162）:

```
SKILLS_DIR = $REPO_ROOT/.agents/skills      ← 同期元（正本）
　　　↓ cp <name>/SKILL.md（+ references/）
plugin/plangate/skills/<name>/SKILL.md      ← 同期先
```

- skills の**正本は `.agents/skills/`**。`plugin/` は派生。CI（`.github/workflows/sync-plugin-plangate.yml`）が drift 検出し PR を自動作成する。
- **`.claude/skills/` はこの同期経路に一切含まれない。** スクリプト全体を `skills` で grep しても `.claude/skills` への言及は 0 件。

3 集合の実測差分:

| 比較 | 件数 | 内訳 |
|---|---|---|
| `.agents` (38) − `.claude` (28) | **15** | ai-dev-brainstorm / ai-dev-exec / ai-dev-plan / ai-dev-verify / codex-mvp-split / context-packager / design-gate / evidence-ledger / local-exec-handoff / manual-cloud-task / plan-review-gate / pr-decision / review-gate / **subagent-dispatch** / working-context |
| `.claude` − `.agents` | **5** | hypothesis-logger / plan-quality-check / plan-quality-reviewer / plangate-working-discipline / pr-watch |
| `.agents` − `plugin` | **0** | 完全一致 |
| `plugin` − `.agents` | **0** | 完全一致 |

**「plugin にあるが `.claude/` に無い」は subagent-dispatch 単独の事故ではなく、15 件規模の恒常ドリフト。** #963 の逆方向欠落を検出する手段は `.agents`↔`plugin` については CI で既にあるが、**`.claude/skills/` については存在しない**。

隣接資産: `scripts/check-skill-name-collisions.py`（#692・多重定義検出）と `scripts/check-stale-skill-refs.py`（#691・stale パス参照検出）は既に `.claude/skills` と `plugin/*/skills` を走査対象にしている。**欠落検出（片側にしか無い）は両者ともカバーしていない**ため、追加は既存パターンの自然な延長になる。

### C. hook 配線の可否 — **issue の前提より広い**

Claude Code 公式ドキュメント（`code.claude.com/docs/en/hooks.md` / `tools.md`）を照会した結果:

| 項目 | 結果 | 検証状態 |
|---|---|---|
| サブエージェント起動ツールの正式名 | **`Agent`**（`"matcher": "Agent"` は有効） | 検証済み（docs） |
| 専用 hook イベント | **`SubagentStart` / `SubagentStop` が存在する** | 検証済み（docs） |
| matcher のサブエージェント指定 | `"matcher": "Explore\|Plan\|custom-agent"` のようにエージェント名で絞れる | 検証済み（docs） |
| `SubagentStart` / `SubagentStop` の JSON 入力スキーマ | 公式 docs に未掲載 | **未検証** |
| `SubagentStop` がサブエージェントの最終報告本文を受け取れるか | **未検証**（受け取れなければ OUTCOME の hook 検証は不可能） | **未検証** |
| PreToolUse が `Agent` ツールでも発火するか（`SubagentStart` と排他か） | **未検証** | **未検証** |
| PreToolUse の block と理由のモデルへの返却 | exit 2 で block。exit 0 + JSON の `permissionDecision: deny` / `permissionDecisionReason` で構造化理由を返せる | 検証済み（docs） |

**issue の B 案（hook）は成立しうるが、issue が想定した「PreToolUse に `Agent` matcher」ではなく `SubagentStart` / `SubagentStop` が本命である。** ただし **入力スキーマが未検証のため、実装前に実機プローブが必須**（後述 Step 0）。

### D. OUTCOME 機械検証の配置

`hybrid-architecture.md`「CLAUDE.md / Skill / Hook の境界ルール」に照らした判定:

| 層 | 強制力 | この用途への適合 |
|---|---|---|
| CLAUDE.md | ソフト | 既に導線 1 行あり（`docs/ai/subagent-delegation/README.md` へのリンク）。**これでも脱落した**ので不足 |
| Skill | ソフト（LLM が呼び出し） | **チェックリストの提示**には適する。呼ばれなければ効かない |
| Hook | ハード（harness が実行） | **「絶対に通さない」に該当。ただし設定は Human-owned** |

**結論: 3 層すべてに置き、責務を分ける。**

- **検証ロジック本体は `scripts/check-outcome-contract.sh`（非 HO・AI-owned）** に置き、stdin または引数のテキストを判定して exit code を返す純関数にする。これにより ①オーケストレータが手で叩く ②hook から呼ぶ ③CI/テストから叩く の**3 経路すべてで同一実装を共有**できる。
- **hook 配線（`SubagentStop` → 上記スクリプト）は patch 提示までが AI-owned**、適用は Human-owned（`.claude/settings.json` は HO 9 カテゴリ）。
- **skill は「委託前に読む」導線**を担う（検証ではなく生成側）。

`scripts/hooks/*.sh` は HO パスなので、**hook 本体を `scripts/hooks/` に置くと本 PBI が HO 変更になる**。`scripts/check-*.sh` は非 HO（既存 17 本が実在）なので、そちらに置けば AI-owned のまま実装できる。**この配置差は本 PBI の実現可能性を左右するので必ず守る。**

### E. AC-7（stall 事例で検証）の実現可能性 — **不可能**

issue の AC-7 は「TASK-1036 の stall 事例を入力として、要素 4 を含む派遣プロンプトなら防げたかを検証可能な形で記録する」。

**反実仮想（counterfactual）の behavioral proof は取得できない。** 理由:

1. stall はライブのサブエージェントセッションで起きた非決定的事象で、同一条件の再実行ができない。
2. 「要素 4 があれば防げた」を示すには、要素 4 の有無だけを変えた 2 条件の実験が必要だが、LLM の応答は非決定的で、n=1 の再実行は証拠にならない。
3. 「防げた」の反証責任を満たそうとすると本 PBI が実験計画に化け、スコープが崩壊する。

**したがって AC-7 は「検証」を要求しない形に書き換える**（後述 AC-7'）。証明できないことを AC に書くと、exec が「PASS したことにする」圧力を受ける — これは `feedback_verify_then_report` / 「実測していないことを確認したと書かない」に反する構造なので、**AC の側を直すのが正しい**。

---

## 3. What（Scope）

### In scope

| # | 項目 | 責務 |
|---|---|---|
| S-1 | **実機プローブ**: `SubagentStart` / `SubagentStop` の JSON 入力スキーマを実測し、サブエージェント報告本文が hook から見えるかを確定する。結果を `evidence/` に記録 | AI-owned |
| S-2 | **`.claude/skills/subagent-delegation/` の新規作成**（`.agents/skills/` を正本として作成し同期対象に載せる）。必須 8 要素チェックリスト + OUTCOME 契約 + 受け入れ確認 5 項目への導線を本文に持つ | AI-owned |
| S-3 | **`scripts/check-outcome-contract.sh`**: `outcome-contract.md` §6 の項目 3・4・5 を判定。負側テスト込み | AI-owned |
| S-4 | **`tests/extras/ta-NN-outcome-contract.sh`**: 既存 `_extra-contract.sh` 規約に準拠した回帰テスト | AI-owned |
| S-5 | **`.claude/skills/` 欠落検出**: `.agents/skills/` との片側欠落を検出する仕組み（S-1 の結果に依存しない独立スライス） | AI-owned |
| S-6 | **hook 配線 patch の提示**（適用手順・動作検証手順・rollback 込み） | AI が patch 作成 / **Human が適用** |
| S-7 | 同期方向の明文化（`.agents/skills/` = 正本 / `plugin/` = 派生 / `.claude/skills/` の位置付け） | AI-owned |

### Out of scope

- **`.claude/settings.json` の実適用**（Human-owned・HO）
- 委譲判断基準（`codex-multi-agent` の Iron Law）の変更
- 8 要素・OUTCOME 契約の**内容**の変更（本 PBI は適用機構であって規約改定ではない）
- **既存 `subagent-dispatch` skill の改名・統廃合**（責務が別。§4 の命名衝突参照）
- **`.claude/skills/` に欠けている残り 14 件の一括同期**（本 PBI では検出まで。一括同期は別 PBI）
- #963（plugin から消えて実体の無い 11 ファイル）の復旧
- #868（model × effort × role ルーティング）
- 承認境界の緩和（NO MERGE BY AI / C-4 / HO 適用不可はすべて不変）
- レビューラウンド数の削減そのもの

---

## 4. 設計上の争点（exec 前に決着が要る）

### 4.1 命名衝突 — issue の In scope をそのまま実装できない

issue は「`.claude/skills/subagent-dispatch/` の配置」を In scope に挙げるが、これは **2 つの正本と衝突する**。

1. **`subagent-dispatch` は別責務**。実際に invoke して全文を読んだ結果、内容は「ロール割当・依存グラフ・並列判定・`dispatch/` ファイル授受」であり、**必須 8 要素も OUTCOME も 1 語も含まない**。ここに委譲プロトコルを混ぜると単一責務が壊れる（`hybrid-architecture.md` Rule 2）。
2. **`README.md` §2.3 が候補 B（`.claude/skills/subagent-delegation/`）を明示的に不採用としている。** 理由は「既存 skill と同層で密集し混乱を招く」「ミラー同期負担」「正本を手順層に置くのは責務境界と不整合」。

**ただし同 §2.3 には逃げ道が明記されている**: 「将来『**派遣プロンプト生成の薄い実行入口 skill**』を additive に追加する余地はあり」。

→ **本 PBI はこの明記された余地に正確に収まる形にする**: 正本は `docs/ai/subagent-delegation/` のまま動かさず、skill は**正本を参照するだけの薄い実行入口**とし、**契約本文を skill に複製しない**（複製すると二重正本になり drift する）。名前は `subagent-dispatch` と衝突しない別名にする。

### 4.2 skill を置く場所（`.claude/skills/` か `.agents/skills/` か）

- `.agents/skills/` に置けば同期経路に乗り `plugin/` へ自動反映されるが、**`.claude/skills/` には来ない**（B の実測）。
- `.claude/skills/` に置けば HEAD が即反映されるが、**同期対象外なので `plugin/` にも `.agents/` にも来ない**。
- → **両方に置く必要があり、その二重管理こそが S-5（欠落検出）を必須にする理由**。二重管理を「運用で気をつける」で済ませない。

**どちらも HO 9 カテゴリ外**（`check-plan-hash.sh` L123-134 の case 文を実測。`skills` の言及 0 件。`.claude/rules` / `settings*.json` / `commands` / `agents` / `scripts/hooks` / `bin/plangate` / `schemas` / `workflows` / `AGENTS.md`・`CLAUDE.md` の 9 種のみ）。よって **AI-owned で作成・編集可能**。

### 4.3 skill は「呼ばれなければ効かない」

skill は `hybrid-architecture.md` の分類で**ソフト強制**。「委託前に読む」導線を作っても、読まずに委託すれば脱落は再発する。

**したがって skill 単独では本 PBI の目的（脱落防止）を達成できない。** 達成度は以下の順で上がる:

| 手段 | 強制力 | 依存 |
|---|---|---|
| skill（S-2） | ソフト | オーケストレータが呼ぶこと |
| 検証スクリプト手動実行（S-3） | ソフト | オーケストレータが叩くこと |
| `SubagentStop` hook 配線（S-6） | **ハード** | S-1 のプローブ結果 + Human 適用 |

**S-1 で「`SubagentStop` が報告本文を受け取れない」と判明した場合、ハード強制の経路は消える。** その場合の代替は「オーケストレータ側の `SubagentStart` で派遣プロンプト本文を検査し、要素 4 / 要素 7 の欠落を block する」— 入力側の強制であり、出力側（OUTCOME）は検証できない。**この分岐は AC に織り込む。**

---

## 5. 受入基準（AC）

issue の AC を実測に基づき書き換えた版。**issue 側 AC からの変更点を明示する。**

| # | 受入基準 | issue からの変更 |
|---|---|---|
| **AC-1'** | `SubagentStart` / `SubagentStop` の JSON 入力スキーマを実機で取得し、**サブエージェント報告本文が hook から参照可能か否かを YES/NO で確定**して `evidence/` に記録する。取得できなかった場合も「未取得」と理由を記録する（推測での断定は FAIL） | **新規**（issue に無い。他 AC の前提） |
| **AC-2'** | 委譲プロトコルの**薄い実行入口 skill** が `.claude/skills/` と `.agents/skills/` の**両方**に配置され、`Skill` ツールで invoke できることが実証される（invoke ログを evidence に残す）。名前は `subagent-dispatch` と衝突しない | issue AC-1 の「`subagent-dispatch` を配置」を**別名の新規 skill**へ変更（§4.1） |
| **AC-3'** | skill 本文から必須 8 要素・OUTCOME 契約・受け入れ確認 5 項目へ**リンクで**到達でき、要素 4 と要素 7 の記入欄が明示される。**契約本文を skill に複製していない**ことを確認する（二重正本の防止） | issue AC-2 に「複製しない」制約を追加 |
| **AC-4'** | `scripts/check-outcome-contract.sh` が `outcome-contract.md` §6 の項目 3・4・5 を判定する。**負側テスト**（`Outcome:` 小文字 / `OUTCOME:success` スペースなし / 複数出現 / 最終行でない / `OUTCOME : success` コロン前スペース / 末尾に空行以外が続く）で**すべて非ゼロ exit を返す**ことを実証する。**変異注入**（判定条件を 1 つ壊すと該当テストが FAIL する）で検出力を実証する | issue AC-3 に**変異注入**と負側 2 ケース（コロン前スペース・末尾残留）を追加 |
| **AC-5'** | `.claude/skills/` と `.agents/skills/` の**片側欠落を検出する仕組み**が実装され、現時点で**片側欠落 20 件（`.agents` のみ 15 / `.claude` のみ 5）を検出する**。件数は下限または同値照合で書き、絶対値を契約にしない | issue AC-6 を「#963 の逆方向」から**実際の 3 集合構造**に基づき具体化 |
| **AC-6'** | `.claude/skills/` が HO 9 カテゴリ外であることを `check-plan-hash.sh` の case 文（正本）で確認し、AI-owned で配置可能な根拠が記録される | issue AC-4 と同じ（実測済み・§4.2） |
| **AC-7'** | hook 配線 patch が提示され、**適用は Human-owned** と明記される。patch には ①適用手順 ②適用後の動作検証手順 ③rollback 手順 が含まれる。**AC-1' が NO だった場合は入力側（`SubagentStart`）強制の patch に切り替え、その旨と限界を記録する** | issue AC-5 に rollback と**AC-1' の結果による分岐**を追加 |
| **AC-8'** | 同期方向が明文化される: `.agents/skills/` = skills の正本 / `plugin/plangate/skills/` = `sync-plugin-plangate.sh` による派生 / `.claude/skills/` = Claude Code セッション用の別集合（同期経路外・AC-5' で監視） | issue AC-6 の前半を実測どおりに訂正（issue は「`plugin/` ↔ `.claude/`」と書くが、実際の同期は `.agents/` → `plugin/`） |
| **AC-9'** | TASK-1036 の stall 事例が `examples.md` に**負例（要素 4 欠落サンプル）として追加**され、要素 4 に何を書くべきだったか（`ta-61` の per-file ループが新規 extras を standalone 実行し `timeout 180` を FAIL 扱いにする）が明記される。**「防げたか」の反実仮想検証は行わない**（§2-E により実現不能。その旨を handoff の妥協点に記録する） | issue AC-7 を**実現可能な形へ書き換え**（最重要の変更） |

### Non-goals（不変確認）

- 承認境界の緩和（NO MERGE BY AI / C-4 / HO 適用不可）
- サブエージェントの model / effort 選択の自動化
- レビューラウンド数の削減そのもの

---

## 6. Notes from Refinement（本分析で決まったこと）

1. **issue の 実測 1 は誤りであり、修正コメントを issue に残すこと**（起票根拠が 1 つ崩れても課題自体は成立するが、根拠を放置すると後続が誤前提で設計する）。
2. **`.claude/skills/` に置く動機は「呼べないから」ではなく「plugin 経路は release cache 固定で HEAD が反映されないから」**。動機が変わると AC も変わるので、この差は plan に明記する。
3. **skill は薄い入口に徹する**。契約本文は `docs/ai/subagent-delegation/` のまま。複製したら drift する。
4. **検証ロジックは `scripts/check-*.sh`（非 HO）に置く**。`scripts/hooks/` に置くと HO になり本 PBI が Human 適用待ちで止まる。
5. **hook 強制は S-1 のプローブ結果に依存する条件付き成果物**。プローブ前に AC を確定させない。
6. **AC-7 の反実仮想検証は放棄する**。証明不能なことを AC にすると exec が偽 PASS を出す圧力になる。

---

## 7. Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|---|---|---|---|
| R-1 | `SubagentStop` が報告本文を受け取れず、OUTCOME のハード強制が不可能 | 本 PBI の主目的の半分が達成不能 | S-1 を Step 0 に置き、**結果が出るまで S-6 を着手しない**。NO なら入力側強制へ切替（AC-7'） |
| R-2 | skill を `.claude/` と `.agents/` に二重配置し、drift する | 委譲プロトコルの説明が 2 通りになる | S-5（欠落検出）を同一 PBI 内に入れる。内容は薄い入口に限定し drift 面積を最小化 |
| R-3 | 命名が既存 `subagent-dispatch` / `subagent-driven-development` / `subagent-team-design` と混同される | エージェントが誤った skill を呼ぶ | `check-skill-name-collisions.py` を実行して衝突ゼロを確認。`description` の「Use when / Do not use when」で棲み分けを明示 |
| R-4 | hook 配線 patch が Human 適用待ちのまま塩漬けになり、Shadow Config 化する | 「配線済みのつもり」で脱落が続く | `working-context.md` の settings タスクロック準拠。**未適用を handoff に BLOCKED として記録**し、`unblock_condition` を書く |
| R-5 | 本 PBI 自体が「オーケストレータの規律」を扱う自己言及的 PBI であり、設計者の盲点が入る | 同じ脱落が仕組みにも入る | 本 pbi-input は独立サブエージェントが作成済み。plan / C-2 も別視点で回す |
| R-6 | `.claude/skills/` の 15 件欠落を検出した結果、スコープが一括同期へ膨張する | PBI が肥大化 | 本 PBI は**検出まで**。一括同期は Out of scope として別 issue 化 |

### Unknowns

| ID | 未解決 | 解消手段 |
|---|---|---|
| U-1 | `SubagentStart` / `SubagentStop` の入力 JSON スキーマ（**未検証**） | S-1 の実機プローブ |
| U-2 | PreToolUse が `Agent` ツールでも発火するか（`SubagentStart` と排他か）（**未検証**） | S-1 の実機プローブ |
| U-3 | `.claude/skills/` の 15 件欠落が意図的な取捨選択か、単なる放置か（**未検証**） | git log / 関連 issue の調査。意図的なら AC-5' は「検出して差分を許容リストで説明できる」形にする |
| U-4 | 本 PBI の hook を配線したとき、既存 9 本の hook と発火順・パフォーマンスで干渉しないか（**未検証**） | patch 提示時に検証手順として含める |

### Assumptions

| ID | 前提 | 崩れたら |
|---|---|---|
| A-1 | skills の正本は `.agents/skills/`（`sync-plugin-plangate.sh` L24 の実測に基づく） | 同期スクリプトが変わったら AC-8' を再確認 |
| A-2 | `.claude/skills/` と `.agents/skills/` はどちらも HO 9 カテゴリ外 | `check-plan-hash.sh` の case 文が変わったら本 PBI は Human 適用待ちになる |
| A-3 | `outcome-contract.md` §6 の 5 項目のうち、機械判定できるのは 3・4・5 のみ（1「成果物があるか」・2「制約違反がないか」はタスク依存で汎用判定不能） | 1・2 も判定したいなら派遣プロンプト側に期待成果物の宣言欄が要る（別 PBI） |

---

## 8. Mode 判定（提案）

**提案モード: `high-risk`**（`lite_eligible = false` / **Standard・同期 C-3 固定**）

| 判定軸 | 値 | モード |
|---|---|---|
| 変更ファイル数 | 概算 6〜9（skill × 2 配置 + check スクリプト + テスト + 欠落検出 + docs 2〜3 + patch） | 高 |
| 受入基準数 | 9 | 高 |
| 変更種別 | 機構追加（doc のみではない。実行系スクリプト + テストを含む → **変更種別 = code**） | 高 |
| 影響範囲 | 全サブエージェント委譲に波及。hook 配線を含めば harness 挙動そのもの | 高 |
| ロールバック | 計画的に必要（hook 配線は Human 適用・rollback 手順必須） | 高 |

**例外ルールの適用**: 本 PBI は `.claude/settings.json`（HO 9 カテゴリ）への patch を成果物に含む。実ファイルには触れないが、`mode-classification.md` の「**自動推定の安全側**: 例外条件の該当が不確実なら該当扱い（Mode を引き上げる側）」に従い、**承認境界周辺の変更として最低「高」**とする。これにより `lite_eligible=false` 強制 + Standard・同期 C-3 固定（AC-10 Hardening Override と整合）。

**doc-light は適用不可**（差分に `.md` 以外＝`scripts/*.sh` / `tests/extras/*.sh` を含むため、除外条件に該当）。

---

## 9. Suggested files（実測に基づく訂正版）

| ファイル | issue の記載 | 本 PBI の判断 |
|---|---|---|
| `.claude/skills/<新名>/SKILL.md` | `.claude/skills/subagent-dispatch/`（plugin から同期） | **別名の新規 skill**。同期元は `.agents/skills/`（plugin ではない） |
| `.agents/skills/<新名>/SKILL.md` | 記載なし | **追加必須**（正本側。ここに置かないと `plugin/` へ届かない） |
| `scripts/check-outcome-contract.sh` | あり | そのまま（非 HO を確認済み） |
| `tests/extras/ta-NN-outcome-contract.sh` | 記載なし | **追加必須**（`tests/extras/` は 61 ファイルの既存規約。`_extra-contract.sh` を source する） |
| `.claude/skills` 欠落検出（`scripts/` 配下） | 記載なし | **追加**（AC-5'。`check-skill-name-collisions.py` / `check-stale-skill-refs.py` と同層・同パターン） |
| `docs/ai/subagent-delegation/README.md` §3 | あり | 機械化状況を追記 |
| `docs/ai/subagent-delegation/examples.md` | 記載なし | **追加**（AC-9' の負例） |
| `.claude/settings.json` への patch | あり | **`SubagentStop`（または `SubagentStart`）** を対象にする。issue の「PreToolUse matcher」想定は S-1 の結果次第で不採用 |

---

## 10. 要判断事項

### P0（これが決まらないと先に進めない）

- **[P0-1] issue #1061 の 実測 1 が誤りである点を、issue 本文に訂正コメントとして残すか。** 残さない場合、後続レビュアーが誤前提（「skill は呼べない」）で本 PBI を評価し、AC-2' の変更を「スコープ逸脱」と誤判定するおそれがある。
- **[P0-2] S-1（`SubagentStart` / `SubagentStop` の実機プローブ）を本 PBI の Step 0 として認めるか。** プローブは `.claude/settings.json` への一時的な hook 追加を要する可能性があり、その場合 **Human 適用が前提**になる。認めない場合、hook 強制（S-6 / AC-7'）は本 PBI から Out of scope に落とし、skill + 手動検証スクリプトのみ（＝ソフト強制のみ）に縮退する。**この分岐で PBI の価値が大きく変わる。**
- **[P0-3] 新規 skill の名前**。`subagent-dispatch` は使用不可（責務衝突・§4.1）。候補: `subagent-delegation-brief` / `dispatch-prompt-builder` / `delegation-contract`。命名は `check-skill-name-collisions.py` で衝突ゼロを確認したうえで人間が確定する。

### P1（exec 中に決めてよいが記録が要る）

- **[P1-1]** `.claude/skills/` に欠けている 15 件を、本 PBI では「検出のみ」に留める方針でよいか（一括同期は別 issue 化）。
- **[P1-2]** `check-outcome-contract.sh` の入力インターフェース（stdin / ファイルパス引数 / 両対応）。hook から呼ぶ場合と手動で叩く場合で最適解が異なる。
- **[P1-3]** 検証スクリプトの出力形式（人間可読テキスト / JSON）。#230（Gate Event Normalization）と将来接続するなら JSON が有利。

### P2（V2 候補）

- **[P2-1]** `outcome-contract.md` §6 の項目 1・2（成果物の有無 / 制約違反）の機械判定。派遣プロンプト側に「期待成果物」「禁止操作」の構造化宣言欄を設ければ照合可能になる。
- **[P2-2]** 派遣プロンプト**生成側**の 8 要素 lint（要素 4 が空欄なら警告）。本 PBI は出力側（OUTCOME）が主眼。
- **[P2-3]** #230 events への `delegation_dispatched` / `delegation_reported` 追加によるラウンド数の実測。「1 ラウンド目の品質が上がったか」を後から測れるようにする。

---

## 11. 参照

- Issue: [#1061](https://github.com/s977043/plangate/issues/1061) / 親 EPIC [#1035](https://github.com/s977043/plangate/issues/1035)
- 関連: [#963](https://github.com/s977043/plangate/issues/963)（同期の逆方向欠落）/ [#928](https://github.com/s977043/plangate/issues/928)（PreToolUse 未配線）/ [#946](https://github.com/s977043/plangate/issues/946)（敵対レビューのラウンド設計）/ [#868](https://github.com/s977043/plangate/issues/868)（委譲ルーティング）/ [#692](https://github.com/s977043/plangate/issues/692)（skill 多重定義検出）/ [#691](https://github.com/s977043/plangate/issues/691)（stale ref 検出）
- 正本: `docs/ai/subagent-delegation/`（README / outcome-contract / dispatch-template / behavior-norms / plangate-flow-integration / examples）
- ルール: `.claude/rules/hybrid-architecture.md`（CLAUDE.md / Skill / Hook の境界）/ `.claude/rules/mode-classification.md`（HO 9 カテゴリ・doc-light 除外条件）/ `.claude/rules/responsibility-classes.md`（AI / Human / CI / Workflow-owned）
- 実測対象: `scripts/sync-plugin-plangate.sh` L24・L149-162 / `scripts/hooks/check-plan-hash.sh` L123-134 / `.claude/settings.example.json` / `tests/extras/_extra-contract.sh`
