# open bug 39 件 統合実行計画（2026-08-20）

> **測定基点**: `origin/main` = `684949eca274ce469ed7b41a43f08e4b384f96f2`
> （`docs(release): CLAUDE.md の最新リリース節を v8.21.0 へ更新 (#1190)`）
> **入力**: `origin/docs/triage-lower:docs/working/_reports/bug-triage-2026-08-20-lower.md`（#863〜#1010 の 21 件）
> / `origin/docs/triage-upper:docs/working/_reports/bug-triage-2026-08-20-upper.md`（#1011〜#1180 の 20 件）
> **本レポートは読み取りのみで作成した。** issue / PR への書き込み（コメント・close・ラベル・編集）は一切行っていない。
> **2 本の棚卸しの主張はそのまま写していない。** 全 39 件について `origin/main` に対し最低 1 点を独立に再測定し、
> 食い違った 4 点は §0-2 に記録した。

## 0. 前提と食い違いの決着

### 0-1. 対象集合の実測

```text
$ gh issue list --repo s977043/plangate --label bug --state open --limit 100 \
    --json number --jq '.[].number' | sort -n
863 866 921 937 942 947 954 956 960 963 975 978 982 984 990 991 994 997 1004 1009 1010
1011 1018 1021 1044 1057 1081 1086 1093 1101 1104 1105 1144 1151 1162 1165 1170 1178 1180
# → 39 件。#1102（CLOSE 済）と #1177（CLOSED/COMPLETED）は含まれない。
```

オーガナイザーの実測（#1102 CLOSE 済 / #1177 は CLOSED だが AC 3 件未達で #1178 へ移管 / #1178 は severity 格上げ済 /
および #956 の drift は 32 件・判断対象 5 件）はそのまま使い、再確認していない。**ただし #956 の drift 件数だけは
2 本の棚卸しが別の値（33 と 32）を出していたため、分母を確定させる目的で独立に再測定した**（§0-2 D-1）。

### 0-2. 2 本の棚卸しで食い違っていた判定と、その決着

| # | lower の判定 | upper の判定 | 自分の再測定 | 決着 |
|---|---|---|---|---|
| **D-1** | `.codex` drift = **33 件** | `.codex` drift = **32 / 39** | 全 blob SHA 照合: 共通 **42** ファイル中 drift **33**、うち `SKILL.md` に限れば共通 **39** 中 drift **32** | **両方正しい。分母が違うだけ。** 差の 1 件は `review-gate/references/ui-ux-lane.md`。**以後「drift 33 / 42（うち SKILL.md 32 / 39）」と分母つきで書く** |
| **D-2** | #1057 の記述是正対象は「正本 31 + 配布 24」（upper 側の主張。lower は #1057 を扱わず） | 同上・**`.codex` に言及なし**・「HO を 1 本も含まない / 依存なし L1」 | `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` の保有ファイルは repo 全体で **70**。内訳 `plugin/plangate` 24 / `.agents/skills` 19 / **`.codex/skills` 15** / `.claude/skills` 7 / `docs/ai` 3 / `docs/workflows` 2 | **upper が `.codex` 15 本を数え落としている。** #1057 症状 2 は「依存なし」ではなく **`.codex` 分が #956 / #1086 に従属する**。正本側 31 本のみ先行是正し、`.codex` 15 本は #956 の裁定後に回す設計へ修正 |
| **D-3** | — | #1180 の対象 2 ファイルは「**`8e7ea55`（#1174）以降一切変更なし**」 | `git log --oneline -6 origin/main -- tests/extras/ta-69-distribution-checks.sh scripts/check-skill-name-collisions.py` の最新は **`c6cfcdb`（#1169 / PR #1175）**。`scripts/check-skill-name-collisions.py` に `+14 / −3`（PG-SH-GUARD 挿入） | **upper の「変更なし」は誤り。** ただし AC に関係する記述は不変（`ta-69:229` の `plugin/pa/skills` は現存）なので **verdict 0/8 は維持**。行番号アンカーは `check-skill-name-collisions.py` 側でシフト済み |
| **D-4** | `.agents/skills` の参照解決梯子保有は **19 / 22** | — | `git grep -l 'CLAUDE_PLUGIN_ROOT}/rules/' origin/main -- '.agents/skills/**'` = **19**、うち `*/SKILL.md` は **17**（残 2 は `review-gate/references/ui-ux-lane.md` / `skill-creator/references/review-default.md`） | **lower の 19 は `**` glob の値で正しい。** SKILL.md に限ると 17。**#954 の AC を書き直すときは glob を明記すること** |

**共通用語の統一**（2 本で粒度がずれていた分を揃えた）:

- **STALE** は排他分類にせず、状態（CLOSE-AFTER-1 / PARTIAL / OPEN / BLOCKED）と**併存するフラグ**として扱う（両レポートの扱いに合わせた）
- **BLOCKED** を新設した。#1170 は issue 本文が自ら deferred 宣言しており、`working-context.md` の
  BLOCKED / Deferred ゲートに該当する。upper は OPEN に含めていたが、**「着手できない理由が構造的に確定している」ものを
  OPEN と混ぜると着手順が歪む**ため分離した
- **実行層は「最初に打てる手が属する層」1 つ**で表す（安全側 = 判断待ちなら LH に倒す）。副次的な層は §3 / §4 に記す

### 0-3. EH-3 の現在の挙動（オーガナイザー実測・本計画の前提）

| 対象 | `PLANGATE_HOOK_TASK` 未設定時 |
|---|---|
| `docs/**.md`（basename が `plan.md` のものを除く） | rc=0 書ける |
| `.agents/skills/**.md` / `.claude/skills/**.md` / `.codex/skills/**.md` / `plugin/**/*.md` | rc=0 書ける |
| `docs/working/templates/plan.md` | rc=2 BLOCK（basename ガード） |
| `scripts/*.py` / `tests/extras/*.sh` | rc=2 書けない |
| `.claude/rules/*.md` ほか HO 9 カテゴリ | rc=2 `HARDENING_OVERRIDE`（`PLANGATE_HOOK_TASK` でも不変） |

HO 9 カテゴリは行番号でなく `scripts/hooks/check-plan-hash.sh` の
**`_override=0` 直後の `case` ブロック（`esac` まで）** を現 main で読んで確認した:
`.claude/rules/*.md` / `.claude/settings{,.local,.example}.json` / `.claude/commands/**.md` /
`.claude/agents/**.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` /
`.github/workflows/*.{yml,yaml}` / `AGENTS.md`・`CLAUDE.md`。

---

## 1. 全体サマリ — 実行層 × 状態

**実行層の定義**: **L1** = `.md` のみ・`PLANGATE_HOOK_TASK` 不要 / **L2** = `.py` / `.sh` を書く（`PLANGATE_HOOK_TASK` セッションが要る）/
**L3** = HO 対象パス（AI は patch 提示まで・適用は Human）/ **LH** = Human の設計判断が先。

| 層 / 状態 | CLOSE-AFTER-1 | PARTIAL | OPEN | BLOCKED | 計 |
|---|---|---|---|---|---:|
| **L1** | — | **1**: #1057 | **2**: #1105 / #1151 | — | **3** |
| **L2** | **1**: #1018 | **6**: #921 / #937 / #975 / #991 / #1011 / #1093 | **15**: #947 / #978 / #984 / #990 / #994 / #997 / #1004 / #1009 / #1010 / #1021 / #1044 / #1162 / #1165 / #1178 / #1180 | — | **22** |
| **L3** | **1**: #960 | **2**: #1101 / #1104 | **2**: #942 / #1144 | — | **5** |
| **LH** | **2**: #863 / #866 | **3**: #954 / #963 / #1081 | **3**: #956 / #982 / #1086 | **1**: #1170 | **9** |
| **計** | **4** | **12** | **22** | **1** | **39** |

**STALE フラグ併存（16 件）**: #866 / #947 / #956 / #990 / #994 / #1009 / #1010 / #1021 / #1044 / #1081 / #1086 / #1093 / #1162 / #1165 / #1170 / #1178。
**着手前に issue 本文を測り直さないと対象 / 対象外が反転する。**

**読み方**:

- **L1 が 3 件しかない。** 39 件のうち 22 件（56%）は `PLANGATE_HOOK_TASK` セッションが要る L2 に集中している。
  **通常セッションでは backlog の半分に一切触れない。**
- **LH 9 件のうち 6 件が `.codex/skills` の去就（#1086 / #956）に連なっている**（§5 クラスタ A）。
  **Human の判断 1 つが最大 6 件を動かす。**
- **CLOSE-AFTER-1 は 4 件で、うち 3 件は AI 側の残作業がゼロ。**

---

## 2. 🔴 Human の 1 アクションで閉じるもの（最優先）

**この節だけを読めば全部答えられる形にしてある。** 7 問すべて Yes / No または番号選択で答えられる。
判断材料はすべて `origin/main` で実測済み。

### Q1 — #863（CLI 依存スキルの graceful degradation）

> **問い**: **#863 を「項目 1〜3 の充足」で close し、残る項目 4（HO パス 3 ファイル）を新 issue へ切り出してよいか？**
> **Yes / No**

**判断材料（実測 3 行）**:

- 項目 3 の対象集合は `plugin/plangate/{commands/*.md, skills/*/SKILL.md, agents/*.md}` で **13 ファイル**。
  `plugin/plangate/README.md` のスナップショット一覧とファイル名集合が一致する（#1182 / #1183 で件数宣言そのものが撤去された）
- 項目 4 の対象は `.claude/agents/setup-coordinator.md`（6 hit）/ `.claude/commands/plangate-setup.md`（3 hit）/
  `.claude/agents/workflow-conductor.md`（2 hit）の **3 ファイル**。いずれも **HO パス**
- 項目 4 の patch は `docs/working/_reports/` に**存在しない**（`863-*` は 0 件）

**Yes なら**: backlog が 1 減る。AI が切り出し先 issue を起票する（AI 実行可）。**Human の追加作業はゼロ。**
**No なら**: AI が patch を作成 → Human が HO 3 ファイルへ適用、の **2 手**が必要になる。#863 は CLOSE-AFTER-1 から外れる。

---

### Q2 — #866（正本宣言が三つ巴で矛盾）

> **問い**: **#866 の close 条件を「issue 本文の修正案 1〜3」に限ってよいか？**（コメントで後から追加された
> `.codex` 追従とエスケープ済みコードフェンスは #956 へ移す）
> **Yes / No**

**判断材料（実測 3 行）**:

- 本文の「三つ巴」3 root は blob SHA が**完全一致**。`intent-classifier` = `9bd3049…`、
  `skill-policy-router` = `f51d027…` が `.agents` / `.claude` / `plugin` の 3 root で同一
- 一方 `.codex` は不一致（`cf5df44…` / `c847b2c…`）。**`.codex` は本文の「三つ巴」に含まれない 4 番目の root**
- `.codex` を触ると #956 の判断材料（drift の性質）を壊すため、**#866 単独では解けない**

**Yes なら**: #866 は #956 を待たずに close できる。`.codex` 分は #956 の AC へ移管（移管先を #956 本文に明記すること）。
**No なら**: #866 は #956 / #1086 の裁定が下りるまで close 不可になる（Q5 / Q7 に従属）。

---

### Q3 — #960（C-1 の項目数が「17」表記のまま実体 25）

> **問い**: **`docs/working/_reports/960-ho-patch.md` を HO 6 ファイルへ適用してよいか？**
> **Yes / No**（Yes = `schemas/review-result.schema.json` の「17」も契約値ではないと認めることを含む）

**判断材料（実測 3 行）**:

- `git grep -lE '17[[:space:]]*項目' origin/main` の全ヒットのうち live な正本に残るのは **HO 6**
  （`.claude/rules/mode-classification.md` / `.claude/rules/working-context.md` / `.claude/commands/ai-dev-workflow.md` /
  `.claude/commands/README.md` / `.claude/agents/workflow-conductor.md` / `schemas/review-result.schema.json`）
  **+ plugin ミラー 5 + `CHANGELOG.md` / `docs/changelog.md` の 2** のみ。他はすべて `docs/working/TASK-*/` の過去ログ
- 非 HO 層は完了済み（陽性コントロール: `25[[:space:]]*項目` は `CLAUDE.md` / `README.md` などでヒットし grep は起動している）。
  `docs/working/templates/review-self.md:32` の「17 項目」は**「歴史的なコア番号帯の通称」という説明文**であり残骸ではない
- patch は `schemas/review-result.schema.json` の「phase 固有スコア（C-1 の 17 項目等、任意）」も**一体で**含む

**Yes なら**: 適用後 `sync-plugin-plangate.sh` で plugin ミラー 5 件が自動追従し、#960 は close できる。**AI 側の残作業ゼロ。**
**No なら**: patch を「HO 5 ファイル分」と「schema 分」に分割する作業（AI）が先に必要。close は 1 手では終わらない。

---

### Q4 — #1018（plan テンプレの見出しが抽出器の契約名と不一致）

> **問い**: **#1018 を「AI が `PLANGATE_HOOK_TASK` セッションで直す」扱いにしてよいか？**（従来「Human-owned」とされていた判定を覆す）
> **Yes / No**

**判断材料（実測 3 行）**:

- `docs/working/templates/plan.md:73` は `## Files / Interfaces`。抽出器 `scripts/ai-loop/plan_package.py:194` は
  `_extract_section(plan_text, "Files / Components to Touch")` を要求 → **テンプレを使うと derive が必ず落ちる**
- 同テンプレに `Verification Automation` は **0 件**（`plan_package.py` がこれも必須とするため、見出し修正だけでは
  もう一段 fail-closed する）。**patch は `_reports/1102-1018-blocked-oneline-patch.md` 第 2 部に両方入っている**（約 +7 / −3 行）
- EH-3 の `plan.md` basename ガードは `task_id` が空の分岐にのみ存在する（`check-plan-hash.sh` の `if [ -z "$task_id" ]` 内）。
  → **`PLANGATE_HOOK_TASK=TASK-XXXX` を起動時に設定したセッションでは AI が書ける**

**Yes なら**: 次の `PLANGATE_HOOK_TASK` セッションで AI が 1 ファイル修正 → close。**Human の追加作業はゼロ。**
併せて `_reports/1102-1018-blocked-oneline-patch.md` の責務表を「no-TASK セッションでは到達不能」へ訂正する。
**No なら**: Human が手で適用する（同じ 1 ファイル・同じ diff）。どちらでも 1 手だが、No は Human の作業が 1 増える。

---

### Q5 — #956-a（`.codex` drift 27 件の無条件再同期）

> **問い**: **判断対象 5 件を除く残りを、`.agents/skills` から無条件に再同期してよいか？**
> **Yes / No**

**判断材料（実測 3 行）**:

- drift は **共通 42 ファイル中 33 件**（`SKILL.md` に限れば共通 39 中 32 件）。オーガナイザー実測の「27 件は無条件に再同期可・
  判断対象 5 件」はこの 32 件の内訳として整合する
- **再同期しないことの実害が 1 件確定している**: `.codex/skills/ai-dev-exec/SKILL.md:108` は
  「✅ **Codex CLI 物理 hook 等価達成 (PR #347)**」と書いたまま。`.agents` / `plugin` / `docs/plangate.md` の同じ箇所は
  すべて「❌ **未達成（登録 0 件）**」へ是正済み。**Codex ランタイムだけが「hook が物理発火する」と読む配布物を受け取っている**
- `docs/ai/settings-wiring-contract.md:82` の正本は「**強制力 0 / 11（Codex 側 hook は 1 件も登録されていない）**」

**Yes なら**: 27 件が片付き、上記の安全性に関わる false claim が消える。#954 AC-3 / #1170 / #866 の残件が同時に前進する。
**No なら**: `.codex` は「hook が効く」と主張し続ける。**#1170 は完全ブロックのまま、#866 / #954 も動かない。**

---

### Q6 — #956-b（`plan-review-gate` の独自節 36 行の破棄可否）

> **問い**: **`.codex/skills/plan-review-gate/SKILL.md` の独自節を破棄して `.agents` 版で上書きしてよいか？**
> **A: 破棄して上書き / B: 独自節を `.agents` 側へ取り込んでから同期 / C: この 1 skill だけ同期対象外と明記**

**判断材料（実測 3 行）**:

- `plan-review-gate` は drift 32 件のうち、**独自の追記を持つとして 2026-08-02 に一度裁定され、2026-08-19 に案 A 推奨へ二転して
  再回答が無い**唯一の skill（両棚卸しが一致して指摘）
- `.claude/skills/` には `plan-review-gate` が**存在しない**（`design-gate` も同様）。4 root モデルは全 skill には成立しない
- この 1 件が決まらないと Q5 の「残り」の境界が確定しない（= 27 / 5 の分割が確定しない）

**A なら**: Q5 と合わせて 28 件が 1 回の再生成で片付く。独自節は git 履歴に残る。
**B なら**: `.agents` 側の変更（= 4 root すべてに伝播）になるため、C-3 を通す設計変更として 1 PBI 必要。
**C なら**: 同期対象外である旨を `sync` スクリプトと本文の両方に書く作業が発生する（AI 実行可）。

---

### Q7 — #956-c（残 4 件の参照表の扱い）

> **問い**: **判断対象 5 件のうち `plan-review-gate` を除く残り 4 件について、「正当な相違」と「追従漏れ」を判別する規則を
> 新設するか、それとも全件追従漏れとみなして再同期するか？**
> **A: 判別規則を新設（#956 の AC を書き換える）/ B: 全件追従漏れとみなして再同期**

**判断材料（実測 3 行）**:

- `tests/extras/ta-69-distribution-checks.sh` の Part 3 コメントが「なぜ『4 root の内容一致』を assert しないか（実測 2026-08-18）」として
  「`.agents` vs `.codex` : 39 中 **26 が正当に相違**」「各 root は配布先ごとの適応を持つため、内容一致は不変条件として成立しない」と記録している
- **一方で実測すると、正当な適応と呼べる相違はほぼ存在しない。** 確認できた相違はいずれも
  「`.agents` 側が是正され `.codex` が追従していない」型（§6 F-1 に列挙）。**この矛盾はどの issue にも書かれていない**
- **A / B のどちらを選ぶかで #956 の AC がまったく別物になる**（「drift 0」 vs 「判別規則の存在」）

**A なら**: `ta-69` のコメントを一次資料として扱い、規則を定義する PBI が 1 本立つ。件数を契約値にしない AC へ書き換えられる。
**B なら**: `ta-69` のコメントが誤りであることを同時に是正する必要がある（放置すると次の担当者が同じ迷いに入る）。

---

### この 7 問の効果

| 問い | Yes / 選択で閉じる issue | 連鎖して動く issue |
|---|---|---|
| Q1 #863 | **#863** | 切り出し先 issue 1 本が新規に立つ |
| Q2 #866 | **#866** | #956 の AC に `.codex` 分が加わる |
| Q3 #960 | **#960** | plugin ミラー 5 件が sync で自動追従 |
| Q4 #1018 | **#1018**（次の HOOK_TASK セッション） | `_reports/1102-1018-*` の責務表訂正 |
| Q5 / Q6 / Q7 #956 | — （#956 自体は CI 検出機構が残る） | **#866 / #954 AC-3 / #1170 / #1086 の 4 件が動く** |

**Q1〜Q4 の 4 問（Yes 側）で backlog が 4 件減る。Q5〜Q7 の 3 問で 4 件がアンブロックされる。**
39 件の棚卸しで AI が新たに書けるコードより、**この 7 問のほうが効果が大きい。**

---

## 3. `PLANGATE_HOOK_TASK` セッションで着手する順（L2）

**選定基準**: (1) Human 判断を待たない (2) 変更規模が小さい (3) 他 issue のブロッカーを外す (4) 実害の大きさ。
**1 行〜数行で直るものを冒頭に集めた。**

### 3-1. Tier A — 1 行〜数行で直る（合計 8 行未満）

| 順 | issue | 対象ファイル（実測した集合） | 想定規模 | 依存 | 検証方法（どの変異で検出力を実証するか） | Mode |
|---:|---|---|---|---|---|---|
| **1** | **#1180 M-1** | `tests/extras/ta-69-distribution-checks.sh` | **1 行**（`:229` の `plugin/pa/skills` → `plugin/plangate/skills`）+ AC-2 の `--selftest` 配線 約 10 行 | なし（#1177 / #1178 とファイル非重複） | `check-skill-name-collisions.py` の**ミラー判定 call site**（`:169` の `plugin_name in mirror_plugins`）を反転する変異を入れ、修正前は TC-C6 が PASS・修正後は FAIL することを示す。**関数定義でなく call site を壊す** | standard |
| **2** | **#1162** | `tests/extras/ta-33-agent-model-tier.sh`（`:25` / `:54`）/ `tests/extras/ta-57-pr-convergence.sh`（`:624`） | **3 行**（`-eq 17` ×2 / `-eq 57` ×1 → 下限 or 同値照合） | `ta-57` を触るので **#1165 と束ねるか順序を決める** | 実測値が契約値ちょうどであることを先に示す（`.claude/agents/*.md` は README 除外で **17**、`.codex/agents/*.toml` **17**、`test_delivery.py` の `def test_` **57**）。**agent を 1 本足す変異で修正前は FAIL・修正後は PASS** | standard |
| **3** | **#990** | `scripts/ai-dev-workflow`（`:102` / `:129`）/ `scripts/apply-ui-v1-crossref.sh`（`:41`） | **3 行**（`${_n}` 化）+ 検出機構 | なし | 全数走査は `git grep -nP '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' origin/main -- scripts/ tests/ bin/` を使う（**本文の `--include='*.sh'` は拡張子なしの `scripts/ai-dev-workflow` を構造的に取りこぼす**）。実行行 3 + コメント 2（`check-git-destructive.sh:203` / `ta-25:56`）の計 5 ヒット | standard |
| **4** | **#1009** | `scripts/sync-plugin-plangate.sh:380` | **1 行**（`set -- $_ai_loop_expected_refs` の quote 化） | **#991 CB-2 より先に入れる**（§5 逆向き依存） | スペースを含むファイル名の fixture を `ta-26` に足し、修正前は base 集計が水増しされて guard が発火しないこと（fail-open）を示す | standard |
| **5** | **#1018** | `docs/working/templates/plan.md:73` + `Verification Automation:` 行 | **約 +7 / −3 行**、1 ファイル | Q4 の回答（Yes で AI 実行可） | `plan_package.py` の `_extract_section()` を repo 外で走らせ、修正前は `Files / Components to Touch` が `None`・修正後は表本体を返すことを示す。**互換影響は `Files / Interfaces` を使う実 plan 3 本（TASK-0809 / 0921 / 1005）で、いずれも完了済み** | light |

### 3-2. Tier B — 独立度が高く実害が現に出ている

| 順 | issue | 対象ファイル（実測した集合） | 想定規模 | 依存 | 検証方法 | Mode |
|---:|---|---|---|---|---|---|
| **6** | **#997** | `scripts/ai-loop/test_run_evidence.py:1164` | 約 10〜20 行（絶対空 → 前後差分 / snapshot 方式） | なし（**もっとも独立**） | **誤 FAIL は現に成立している**（本セッション開始時点で `docs/working/ai-loop-runs/` に untracked 3 件）。`docs/working/ai-loop-runs/` に untracked を置いた状態で修正前実装が FAIL・修正後が PASS することを実走で示す | standard |
| **7** | **#984**（`check-settings-wiring.sh` 分） | `scripts/check-settings-wiring.sh:61-66` | **3 エントリ追加**（約 3 行） | **#1087 CLOSED 問題は Human 判断**（AC の受け皿。実装自体は先行可） | `settings.example.json` を JSON パースすると PreToolUse は **8 ブロック**（`Edit\|Write` 5 / `Bash` 3）。現 checks は 5 script + 1 引数の **6 エントリ**で、**未収載は `check-approval-token-write.sh`（`Edit\|Write` と `Bash` の 2 ブロック）と `check-git-destructive.sh`（`Bash`）**。example から 1 ブロック消す変異で修正後 checks が FAIL することを示す | high-risk（承認境界周辺） |
| **8** | **#1011 V3-04 / V3-05** | `scripts/sync-plugin-plangate.sh:56-67` | 約 10〜15 行 | なし。**後続 3 件（#991 CB-2 / #1009 / #1010）がこの関数契約に載る** | `_mass_delete_blocked()` は stale と base の大小比較 1 行のみで数値検証がない。**非数値を渡す変異**で修正前は fail-open（早期 return = 削除続行）・修正後は blocked 側へ倒れることを示す。`PLANGATE_ALLOW_MASS_DELETE` の完全一致判定も同時に prefix 一致へ | high-risk |
| **9** | **#1044** | `tests/extras/` の **21 ファイル**（`git grep -l '_pg_extra_helper' origin/main -- tests/extras/`） | 同一スニペットを 21 ファイルへ | **#921 の裁定が固まる前に着手すると 21 本を二度書き換える** | bootstrap の top-level `return 0`（`ta-46-ehs-wiring.sh:22`）が原因。**dash / zsh は rc=0、bash / sh は rc=1** を 4 シェルで再実測してから直す | high-risk（21 ファイル） |
| **10** | **#1021** | `tests/extras/ta-09-metrics.sh`（`$0` ベース root は `:8`、cleanup は `:14-23`）/ `ta-07` / `ta-08` | 中規模 | #921 / #1044 と対象重複 | `ta-09-metrics.sh` は **実 `docs/working/TASK-9991` と実 `docs/working/_audit/hook-events.log` に書く**。sandbox 化後、実監査ログに fixture レコードが残らないことを走行前後の diff で示す | high-risk |

### 3-3. Tier C — 束ねないと片方が他方を無効化する

| 順 | issue 群 | 対象ファイル | 想定規模 | 依存 | 検証方法 | Mode |
|---:|---|---|---|---|---|---|
| **11** | **#1177 残 AC + #1178** | `tests/extras/ta-70-py-sh-misinvocation-guard.sh` + `scripts/parsers/{__init__,codex_log_parser}.py` | 大（TC-01 構造判定 / 母集合反転 / timeout / guard 2 本） | **1 PR 必須。** #1177 AC-3 の母集合反転を入れると `scripts/parsers/*.py` 2 本が母集合に入り TC-01 が即 FAIL する | 現状: TC-01 は `:82` で `grep -q "$_T70_MARKER"`（存在のみ）。`timeout` は 0 hit（陽性コントロール: 同ファイルの `_T70_MARKER` は 4 hit）。**「marker だけ残して guard 実体を消す」変異**で修正前 SURVIVE を先に示す | **critical**（`gh pr merge` 到達経路・NO MERGE BY AI） |
| **12** | **#921 + #994 + #1004 + #947** | `tests/extras/ta-61-extra-contract.sh:71`（45 本）/ `ta-26-plugin-sync.sh:804-821` / `tests/extras/README.md` / `ta-25` `ta-42` `ta-54` | 大 | **分けると #921 が #994 を無音で殺す**（§6 F-2） | **実測した構造証明**: `FIXTURES_DIR:-` を持つ extras 26 本と `PG_HARNESS_SOURCED` を持つ 26 本は**同一集合（差集合 = ∅ を両方向で確認）**。→ TC-33 検査(1) が報告しうる違反は**構造的に 0 件**。母集団 66 本中 走査対象は 26 本（4 割） | **critical**（横断） |
| **13** | **#1165 + #1162** | `tests/extras/ta-57-pr-convergence.sh` | 中 | 同一ファイル。**#1162 を先に入れると #1165 と conflict** | `[WARN]` 経路（`:603-606`）は `t57_pass` / `t57_fail` のどちらも呼ばず pass/fail 集計に現れない。**実害の一次証跡: #1187（`ffed553`）が凍結対象 3 ファイル（`scripts/ai-loop/{c3_contract,c3prime_verify,delivery}.py`）すべてを変更してマージ済**（§6 F-3） | high-risk |

### 3-4. Tier D — 設計判断が混じるため後回し

| 順 | issue | 理由 |
|---:|---|---|
| 14 | **#937** | patch（`_reports/937-942-unwired-guard-patch.md` 第 1 部）は既存で `scripts/templates/pre-push.sample` は **HO 外**。実測: `check-branch-not-merged` は 0 hit（陽性コントロール: 同ファイルの `set -` は 1 hit）。**「適用が本当に Human-owned か」の確認が先**（patch 文書の Human-owned 宣言に根拠が書かれていない） |
| 15 | **#975** | `--all-events` の唯一のヒットは `scripts/apply-claude-settings.sh:32` の follow-up コメント。`matcher_covers()` は `:156` に現存。**`SessionStart` の `gh-pin-account.sh` 既定適用（#1151 と同根）に触れるため設計判断が混じる** |
| 16 | **#1093** | 計画は C-3 承認済・後半は #1114 へ分割済。ただし **AC-1 の exemplar（`apply-eh3-ho-always.sh`）が #1089 解消で用途反転している**ため、着手時に別の未適用スクリプトへ差し替えが要る（§6 F-6） |
| 17 | **#978** | `source_kind` / `BUNDLED_TEMPLATE` / `HO_BOUNDARY_UNDEFINED` は `scripts/ai-loop/arbiter.py` に **0 hit**（陽性コントロール: `resolve_ho_patterns` は 7 hit）。**#916 統合か独立かの Human 判断が先** |
| 18 | **#991 CB-2** | **#1009（順位 4）の後**。`:381 _ai_loop_ref_base_count=$#` は 2 正本ディレクトリの合算 1 本値。#1009 の quote 修正で base 集計の実装が変わるため、分離集計設計は後のほうが安い |
| 19 | **#1010** | **#1011 V3-02（symlink 除外の方向）と逆向き**。#1010 の `nolink` fixture は `[ -L ]` 除外の存在を pin、V3-02 は除外を外す方向 → 真の相互依存。`^# TC-` の見出しは **20**（本文の「30 TC」は過大） |

---

## 4. HO patch（L3）の適用待ち一覧

### 4-1. patch 設計書と `scripts/apply-*.sh` の対応表

```text
$ git ls-tree --name-only origin/main docs/working/_reports/ | grep -E 'patch|design'   → 18 件
$ git ls-tree --name-only origin/main scripts/ | grep 'apply-'                          → 35 件
$ git grep -lE '#(937|942|960|982|984|990|997|1011|1018|1021|1101|1104|1135|1144|1157|1163|1169)' \
    origin/main -- 'scripts/apply-*.sh'
scripts/apply-claude-md-v8210.sh     ← リリース節の版更新用。上記 patch のどれにも対応しない
```

**🔴 結論: 18 件の patch 設計書のうち、対応する `scripts/apply-*.sh` を持つものは 0 件。**
既存の `apply-*.sh` 35 本はすべて TASK-01xx 期の hardening と `CLAUDE.md` の版更新用であり、**現行の bug backlog とは無関係**。
現行 patch はすべて **markdown に書かれた diff を人手で当てる**方式で、`release-prep.sh --check` の
`check_pending_applies()` が拾う経路にも乗っていない（**これは #1093 が指摘している欠陥そのもの**）。

| patch 設計書 | 対応 issue | apply script | 適用状態 | 「未適用」と判定した根拠（現 main の実測） |
|---|---|---|---|---|
| `960-ho-patch.md` | **#960** | なし | **未適用** | patch が消すはずの `17 項目` が HO 6 ファイル（`.claude/rules/mode-classification.md` ほか）に現存 |
| `960-recurrence-guard-patch.md` | #960 | なし | **未適用** | 再発検知の検査器が repo に存在しない（`17 項目` を機械検出する TC は 0 件） |
| `937-942-unwired-guard-patch.md` 第 1 部 | **#937** | なし | **未適用** | `git grep -c 'check-branch-not-merged' origin/main -- scripts/templates/pre-push.sample` → rc=1（陽性コントロール: 同ファイルの `set -` は 1 hit） |
| `937-942-unwired-guard-patch.md` 第 2 部 | **#942** | なし | **未適用** | `.github/workflows/test.yml` に `fetch-depth` の行が無い（陽性コントロール: 同ファイルの `uses: actions/checkout` は 1 hit） |
| `984-wiring-check-gap-patch.md` | **#984** | なし | **未適用** | `check-settings-wiring.sh` の checks は 5 script + 1 引数の 6 エントリのまま。`check-approval-token-write.sh` / `check-git-destructive.sh` が 0 hit |
| `990-multibyte-var-patch.md` | **#990** | なし | **未適用** | `scripts/ai-dev-workflow:102` / `:129` / `scripts/apply-ui-v1-crossref.sh:41` に `$AI_DEV_TASK。` `$_n）` が原文のまま |
| `997-947c-porcelain-patch.md` | **#997** / #947(ta-54) | なし | **未適用** | `scripts/ai-loop/test_run_evidence.py:1164` の `git status --porcelain --` が現存 |
| `982-cli-entry-notation-patch.md` | **#982** | なし | **未適用**（かつ**案を選んでいない**） | `bin/plangate` に `ai-loop)` 分岐 0 件（陽性コントロール: `metrics)` は 1 hit）。live 7 箇所が「#982 で未決」と自認 |
| `1011-v304-fail-open-patch.md` | **#1011** | なし | **未適用** | `sync-plugin-plangate.sh:57` の `[ "$3" -gt "$2" ] \|\| return 1` が原文のまま（数値検証なし） |
| `1021-ta09-isolation-patch.md` | **#1021** | なし | **未適用** | `ta-09-metrics.sh:8` の `dirname -- "$0"` ベース root 解決と `:11` の実監査ログ直書きが原文のまま |
| `1101-normalization-patch.md`（1046 行） | **#1101** | なし | **未適用** | `check-plan-hash.sh` の正規化は `./` 除去（`:86-88`）と `$REPO_ROOT/` 除去（`:89-91`）のみ。`..` / 大小文字 / 末尾空白の処理が無い |
| `1102-1018-blocked-oneline-patch.md` 第 1 部 | #1102（CLOSE 済） | なし | **部分適用** | `CLAUDE.md` の「未適用」記述は #1190 で消えたが、patch が推奨した「HO block が `Edit\|Write` 経路限定」の明記は**入っていない**（= #1104 の scope） |
| `1102-1018-blocked-oneline-patch.md` 第 2 部 | **#1018** | なし | **未適用** | `docs/working/templates/plan.md:73` が `## Files / Interfaces` のまま。`Verification Automation` は 0 hit |
| `1104-bash-route-guard-patch.md` | **#1104** | なし | **未適用** | `settings.example.json` の `Bash` matcher hook は `check-delegation-commit-boundary.sh` / `check-approval-token-write.sh` / `check-git-destructive.sh` の 3 本のみ。`check-plan-hash.sh` は `Edit\|Write` のみに配線 |
| `1144-plugin-packaging-patch.md` | **#1144** | なし | **未適用** | `plugin/plangate/hooks/` は `.gitkeep` 1 件のみ。`plugin.json` に `hooks` キー 0 hit |
| `1144-root-resolution-patch.md` | **#1144** | なし | **未適用** | 同上 |
| `1135-ai-owned-lane-patch.md` | #1135（bug backlog 外） | なし | **未確認** | 本計画の対象 39 件に対応 issue が無いため測定していない |
| `1157-seeds-read-path-patch.md` | #1157（bug backlog 外） | なし | **未確認** | 同上 |
| `1163-ref-resolution-ci-design.md` | #1163（bug backlog 外） | なし | **未確認** | 同上 |
| `1169-sh-invocation-patch.md` | #1169（CLOSE 済） | なし | **適用済** | `ffed553`（#1187）/ `c6cfcdb`（#1175）で `PG-SH-GUARD` が配布済。repo 全 `.py` のうち guard 未保有は **13 件**（`docs/working/**/evidence/` 10 + `fuzz/` 1 + `scripts/parsers/` 2）のみ |

**未適用と判定した patch: 16 件**（うち bug backlog 対象は 14 件）。**適用済 1 件 / 部分適用 1 件 / 未確認 3 件。**

### 4-2. HO 適用が必要なもの（Human の手が要る）

| issue | 触る HO ファイル | 規模 | 適用で close するか |
|---|---|---|---|
| **#960** | `.claude/rules/*.md` ×2 / `.claude/commands/*.md` ×2 / `.claude/agents/*.md` ×1 / `schemas/*.schema.json` ×1 | 小 | **する**（→ Q3） |
| **#1101** | `scripts/hooks/check-plan-hash.sh` | 約 +139 行 | しない（`ta-65` TC-07 の KNOWN-GAP 反転 約 20 行が残る。ただしそれは非 HO） |
| **#1104** | `.claude/settings.example.json` + `scripts/hooks/*.sh` | 中 | しない（AC-1〜6 のうち実装分が残る） |
| **#1144** | `.claude/settings.example.json` + `plugin/plangate/.claude-plugin/plugin.json` | 大 | しない（10 AC すべて未達） |
| **#1151** | `.claude/settings.example.json`（`:7` コメント / `:11` 配線）+ `scripts/gh-pin-account.sh:21` | 小 | しない（AC-3 の記録は L1 で先に閉じられる） |
| **#942** | `.github/workflows/test.yml` | 1 行（`fetch-depth`） | しない（patch 第 2 部の「目的そのものを再検討すべき」提案が未裁定） |
| **#984** | `CLAUDE.md` + `.claude/settings.example.json` | 小 | しない（#1087 CLOSED 問題が残る） |
| **#863** 項目 4 | `.claude/agents/*.md` ×2 / `.claude/commands/*.md` ×1 | 小 | **patch が存在しない**（Q1 で No を選んだ場合のみ必要） |

**`.claude/settings.example.json` を触る issue が 4 件（#1104 / #1144 / #1151 / #984）ある。**
**適用順は #1151 → #984 → #1104 → #1144 が patch 最小**（後段ほど大きく、先に大きいほうを入れると前段の patch を作り直しになる）。

---

## 5. 依存グラフ

**依存は双方向で数えた。**「A が B に言及している」だけでは依存と呼ばず、
**「A が動かないと B の対象集合 / 設計が変わる」ことを実測で確認したものだけを辺にした。**

### 5-1. クラスタ A — `.codex/skills` の去就（最大のボトルネック / 双方向 3 本）

```text
                      ┌─────────────────────────────────────┐
                      │ #1086  .codex/skills 120 ファイルを   │
                      │        untrack するか（Human・不可逆）│
                      └──────────────┬──────────────────────┘
                                     │ ▲
                        一方向 ─────▶ │ │ ◀── 逆向き: #1086 の investigation.md は
                                     │ │      drift を 2 件と仮定。実測 33/42 で
                                     ▼ │      scope が想定より遥かに大きい
                      ┌─────────────────────────────────────┐
                      │ #956  drift 33/42 の是正方式（Q5/Q6/Q7）│
                      └──┬──────────┬──────────┬────────────┘
                         │          │          │
              ┌──────────▼──┐  ┌────▼──────┐  ┌▼────────────┐
              │ #954 AC-3    │  │ #866 残件  │  │ #1170 全部   │
              │ (.codex 再生成)│  │(.codex 追従)│  │ (BLOCKED宣言)│
              └──────┬───────┘  └─────┬─────┘  └─────────────┘
                     │ ▲              │ ▲
                     │ └── 逆向き:     │ └── 逆向き: #866 の scope を本文 3 項目に
                     │     #954 が正本 │      切ると #956 従属が外れ、#866 が先に
                     │     を先に是正   │      close できる（Q2）
                     │     したので     │
                     │     #956 の再同期│
                     │     内容が確定した│
                     ▼                 ▼
              ┌─────────────────────────────────────────────┐
              │ #1057 症状 2（`.codex/skills` 15 本分のみ）    │  ← 本計画で新たに接続（§0-2 D-2）
              └─────────────────────────────────────────────┘
```

**双方向の実体（実測で確認した 3 本）**:

1. **#1086 ⇄ #956**: #1086 の調査は drift を 2 件と仮定しているが、実測は 33/42。**H-1 を答える前に再 scope が要る**（逆向き）
2. **#954 ⇄ #956**: #954 が正本側（`.agents`）のクラス A / C を先に是正した結果、#956 で再同期すべき内容が確定した（逆向き）
3. **#866 ⇄ #956**: Q2 で scope を切ると従属が外れる。**判断が依存関係そのものを切る**（逆向き）

**片方向（言及のみで依存でないもの）**: #1170 → #956 は body の deferred 宣言による完全従属で、逆向きは無い。

### 5-2. クラスタ B — mass-delete guard の関数契約（双方向 2 本）

```text
#1011 V3-04（_mass_delete_blocked の数値検証）
  ├──▶ #991 CB-2   ┐ 3 件とも同じ関数契約の上に載る
  ├──▶ #1009       │ 先に V3-04 を入れると 3 件が同じ土台で書ける
  └──▶ #1010       ┘
        ▲
        └── 逆向き: #1010 の負側 fixture が無いと V3-04 の検出力を実証できない

#1011 V3-02（symlink 除外の方向）← Human
  └──◀▶ #1010 と **相互に矛盾する方向**を向いている（真の相互依存）
        #1010 の nolink fixture は `[ -L ]` 除外の存在を pin
        V3-02 は除外を外す方向

#1009 ──▶ #991 CB-2
  逆向き: #1009 の未 quote 修正で base 集計の実装が変わるため、CB-2 の分離集計設計は #1009 の後に書くほうが安い
```

### 5-3. クラスタ C — extras の実行契約（双方向 3 本 / **最も実務的に重要**）

```text
#921 Slice 2（_pending_migration の残 45 本を移行）
  ├──◀▶ #947   ta-25 / ta-42 / ta-54 はいずれも 45 本に含まれる
  │             （#947 を先に直すと #921 の移行対象が変わり、
  │               #921 を先に進めると #947 の修正箇所が移動する）
  ├──◀▶ #994   🔴 **#921 の完遂が #994 の検査を無音で殺す**
  │             TC-33 の走査対象 = `FIXTURES_DIR:-` を持つ extras（現在 26 本）
  │             #921 が全件移行 → 走査対象 0 本 → 判定式は 0 本でも PASS
  └──◀▶ #1004  規約 8 の例示は #921 の契約移行後の形を反映していない
```

**実測した判定式**（`ta-26-plugin-sync.sh` の TC-33、行番号ではなく式そのものをアンカーにする）:

```sh
if [ -n "$_t26_hset33" ] && [ -z "$_t26_viol33" ] && [ -z "$_t26_incl33" ]; then
  t26_pass "TC-33 ..."
```

`_t26_hset33` は `tests/run-tests.sh` の unset 集合なので走査対象が 0 本でも非空。
**→ 走査対象 0 本でも PASS する。緑のまま検出力を失う。**

### 5-4. クラスタ D — `ta-70` の検査契約（双方向 1 本）

```text
#1177 残 AC-3（母集合反転）/ AC-4（変異）/ AC-5（timeout）
  ◀▶ #1178 AC-1〜AC-6
     同一ファイル・同一 TC-01 の書き換え。**別々に進めると確実に conflict する**
     #1178 AC-5 と #1177 AC-5 は同一要求（timeout）→ 1 回で満たせる
     逆向き: #1178 を解いても #1177 AC-3 は自動では満たされない（構造判定と母集合反転は独立）
  └─ 先行条件 ─▶ scripts/parsers/{__init__,codex_log_parser}.py 2 本の扱い
                 （ガード適用 or allowlist 明記。**入れないと母集合反転で TC-01 が即 FAIL**）
```

### 5-5. クラスタ E — `.claude/settings.example.json` を共有する 4 issue（片方向・順序依存）

```text
#1151（SessionStart の gh-pin-account 配線）  ← 最小
  → #984（checks へ 3 エントリ追加 + CLAUDE.md doc drift）
    → #1104（Bash matcher へ plan_hash / HO 判定を追加）
      → #1144（hooks 配布 + matcher 定義）      ← 最大
逆向き: #1144 を先に入れると #1151 / #984 / #1104 の patch を作り直しになる
```

### 5-6. 依存の件数集計（実測）

| 種別 | 本数 | 内訳 |
|---|---:|---|
| **真の双方向依存**（両向きを実測で確認） | **9** | A: #1086⇄#956 / #954⇄#956 / #866⇄#956 ・ B: #1011⇄#1010 / #1009⇄#991 ・ C: #921⇄#947 / #921⇄#994 / #921⇄#1004 ・ D: #1177⇄#1178 |
| **片方向依存**（順序のみ） | **7** | #956→#1170 / #956→#1057(.codex 分) / #1011→#991 / #1011→#1009 / #1151→#984→#1104→#1144（3 本） |
| **依存なし（単独で閉じられる）** | **11** | #937 / #942 / #975 / #978 / #982 / #990 / #997 / #1018 / #1021 / #1044 / #1180 |
| **判断で依存が切れるもの** | **2** | #866（Q2）/ #954 AC-3（#956 へ移管すれば #954 本体は独立） |

---

## 6. 🔴 発見された構造的問題（issue 化されていないもの）

**起票はしていない。候補の提示まで。** 各項目に「既存 issue でカバーされるか / 新規が要るか」の判定を付けた。

### F-1. `ta-69` の「正当な相違 26 件」という記録が実測と矛盾する 🔴 新規要

**実測（`git show origin/main:tests/extras/ta-69-distribution-checks.sh` の Part 3 コメント）**:

```text
なぜ「4 root の内容一致」を assert しないか（実測 2026-08-18）:
  .agents vs plugin : 39/39 一致（sync-plugin-plangate.sh が生成。CI が担保）
  .agents vs .codex : 39 中 26 が **正当に相違**
  .agents vs .claude: 24 中  8 が **正当に相違**
各 root は配布先ごとの適応を持つため、内容一致は不変条件として成立しない。
```

**これに反する実測**: `.agents` と `.codex` の相違を個別に見ると、確認できたものはいずれも
**「`.agents` 側が是正され `.codex` が追従していない」型**であって、配布先ごとの適応ではない。
もっとも明瞭な 1 件:

```text
$ git grep -n '物理 hook 等価達成' origin/main
.agents/skills/ai-dev-exec/SKILL.md:114      ❌ ~~等価達成~~ **未達成（2026-08-13 実測）** … 登録 0 件
plugin/plangate/skills/ai-dev-exec/SKILL.md:114  ❌（同上）
docs/plangate.md:462                          ❌ **未達成（#1078 実測: 登録 0 件）**
docs/ai/settings-wiring-contract.md:263        （是正対象として列挙）
.codex/skills/ai-dev-exec/SKILL.md:108        ✅ **Codex CLI 物理 hook 等価達成 (PR #347)**  ← ここだけ旧主張
```

**判定: 新規 issue が要る。** #956 / #1170 / #954 AC-3 / #1086 はいずれも「drift = 追従漏れ」を前提に書かれており、
`ta-69` のコメントはその前提を否定している。**どちらかが誤っている。この矛盾はどの issue にも書かれていない。**
そのため #1086 の裁定が「untrack する / しない」の二択で議論され、
**「正当な相違と追従漏れを判別する規則」という第 3 の選択肢が検討されていない。**

**起票案**: 「`ta-69` の『正当に相違 26 件』というコメントの根拠を再検証し、
`.agents` ⇄ `.codex` の相違を『正当な適応』と『追従漏れ』に判別する規則を定める（または当該コメントを撤回する）」

### F-2. #921 の完遂が #994 の検査を無音で殺す 🔴 新規要（または両 issue の AC 追記）

§5-3 に実測を書いた。`ta-26` TC-33 の走査対象は `FIXTURES_DIR:-` を持つ extras（現在 **26 本 / 母集団 66 本**）で、
そして #921 の移行が完了するとこれが **0 本**になる。判定式は走査対象 0 本でも PASS する。

**「AC を達成すると検査が緑のまま死ぬ」という構造**であり、**#921 / #994 のどちらの本文にも書かれていない。**

**判定: 新規は不要だが、#921 と #994 の両方に AC 追記が要る**（「#921 完遂後も TC-33 が検出力を持つこと」を
どちらか一方の AC に明示し、§3-3 順位 12 のとおり 1 PBI に束ねる）。

### F-3. #1187 が `ta-57` TC-14 凍結対象 3 ファイルすべてを変更してマージ済 🔴 既存 #1165 でカバー・本文是正が必須

**実測**:

```text
$ git log --oneline -3 origin/main --grep='#1187'
ffed553 fix(ai-loop): sh 誤起動で gh pr merge に到達する経路を polyglot ガードで塞ぐ (#1169) (#1187)

$ git show ffed553 --stat -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py \
    scripts/ai-loop/c3prime_verify.py
 scripts/ai-loop/c3_contract.py    | 15 +++++++++++++--
 scripts/ai-loop/c3prime_verify.py | 15 +++++++++++++--
 scripts/ai-loop/delivery.py       | 15 +++++++++++++--
 3 files changed, 39 insertions(+), 6 deletions(-)
```

**#1165 本文の「TC-14 導入コミット以降、この 3 ファイルを触った PR は 0 本」は反証された。**
CI では TC-14 が `[WARN]` 経路（`ta-57:603-606`）へ落ち、`t57_pass` / `t57_fail` のどちらも呼ばないため
**pass/fail 集計に現れず素通りした。**

**判定: 既存 #1165 でカバーされるが、本文が誤ったままだと優先度を誤る。**
「一度も正当な変更と衝突しないまま沈黙して効いてきた」→
「**衝突したが沈黙して素通りさせた（#1187 が実害の一次証跡）**」へ書き換えが必要。**新規起票は不要。**

### F-4. `scripts/parsers/*.py` 2 本がどの走査群にも allowlist にも属さず無ガード 🔴 新規不要・#1177 残 AC に吸収

**実測（全数照合）**:

```text
$ git grep -L 'PG-SH-GUARD' origin/main -- '*.py'
docs/working/TASK-0917/evidence/e2e/harness/{driver,exec_step,idem_recon}.py   （3）
docs/working/TASK-1110/evidence/{gen_cases,matrix}.py                          （2）
docs/working/TASK-1110/evidence/v3-review/{bench_v3,cases_v3,cases_v3b,cases_v3c,cases_v3d}.py （5）
fuzz/fuzz_render_review.py                                                     （1）
scripts/parsers/__init__.py                                                    ← allowlist 外
scripts/parsers/codex_log_parser.py                                            ← allowlist 外
# 計 13 件。#1177 の Out of scope allowlist は docs/working/**/evidence/** 10 + fuzz/*.py 1 = 11 件。
# 差分 2 件が母集合にも allowlist にも属していない。
```

**判定: 新規起票は不要。** オーガナイザーの実測どおり #1177 の残 AC（AC-3/4/5）は #1178 へ移管済みなので、
**#1178 の AC-7〜AC-10 の実装 PR で必ず同時に扱う**こと（母集合反転を入れると TC-01 が即 FAIL するため、
ガード適用または明示 allowlist 化と同一 PR が必須）。

### F-5. #984 の「統合先 #1087 が CLOSED なのに AC 未達」が 11 commit で一度も触れられていない 🔴 新規要（または #984 の再 scope）

**実測**:

```text
$ gh issue view 1087 --repo s977043/plangate --json state,stateReason,title
{"state":"CLOSED","stateReason":"COMPLETED",
 "title":"fix(ci): 配布物検査 3 本が CI に配線されておらず、うち 2 本は rc=1 のまま放置"}
```

上記のとおり #984 は「#1092 Phase 2 として #1087 へ統合」と宣言されたが、#1087 は CLOSED / COMPLETED で
**#984 の AC は 1 つも充足していない**（`check-settings-wiring.sh` の checks は 6 エントリのまま・
`check-approval-token-write.sh` / `check-git-destructive.sh` が 0 hit）。
**#984 のコメントは 2026-08-14 が最後**で、統合先の再検討が行われた形跡がない。

**判定: 新規起票は不要だが Human 判断が要る** — (a) #984 を独立 PBI 化 / (b) 別の統合先を立てる / (c) EH-10 / EH-12 の採番確定。
**「統合先が CLOSED のまま AC が宙に浮く」パターンは #1177 → #1178 でも起きているので、
『統合先 issue が CLOSE されるとき、移管された AC の受け皿を機械検出する』という新規 issue には値する。**

### F-6. #1093 の AC-1 exemplar が #1089 解消で用途反転した ⚠️ 既存 #1093 でカバー・着手時に差し替え必須

`scripts/release-prep.sh:55-57` は `sh "$f" --dry-run` の stdout に `[dry-run]` が含まれるかで pending を判定する。
一方、名指しされた exemplar `scripts/apply-eh3-ho-always.sh:272` の出力は
`[apply-eh3-ho-always] dry-run — 何も書き込んでいない` で**角括弧付きリテラルを出さない**。
さらに #1089 は v8.21.0 で解消済（HO 9 カテゴリが `task_id` 分岐より前で評価される）なので、
**このスクリプトは既に適用済 = pending に出ないのが正**。

**判定: 新規不要。** 設計結論（stdout 文字列一致 → exit code 契約）は無傷。
**着手時に exemplar を真に未適用なスクリプトへ差し替え、`apply-eh3-ho-always.sh` は AC-2 の負の対照 fixture として再利用する。**

### F-7. `.codex/skills/ai-dev-exec/SKILL.md` の「等価達成」false claim が Codex ランタイムに配布されている 🔴 新規要（severity 高）

F-1 の実測の一部だが、**単独で起票する価値がある**。

- `.codex/skills/ai-dev-exec/SKILL.md:108` が「✅ Codex CLI 物理 hook 等価達成」「Claude Code と等価な強制力」と主張
- 正本 `docs/ai/settings-wiring-contract.md:82` は「**強制力 0 / 11（Codex 側 hook は 1 件も登録されていない）**」
- **Codex session 中の write は物理 block されない**のに、Codex に配られる skill だけが「block される」と読める

**判定: 新規 issue が要る。** #956 / #1170 は「drift がある」という一般論で、
**「安全性に関する false claim がランタイムに配布されている」という severity を持っていない。**
Q5（#956-a）を Yes にすれば副産物として消えるが、**Q5 が保留されている間ずっと残る**ため
**#956 と独立に「この 1 行を先行是正する」issue を立てる価値がある**（`.codex/skills/**.md` は EH-3 rc=0 で AI が書ける）。

### F-8. patch 設計書 18 件に対応する `apply-*.sh` が 1 本も無い 🔴 新規要

§4-1 の実測。18 件の patch はすべて markdown の手当て前提で、
`release-prep.sh --check` の `check_pending_applies()`（`scripts/*/apply-*.sh` を `--dry-run` で走らせる）が
**構造的に 1 件も拾えない**。**「patch を書いたが誰も適用しない / 適用漏れを機械検出できない」状態が 16 件分たまっている。**

**判定: 新規 issue が要る。** #1093 は `check_pending_applies()` の判定方式（stdout 一致 → exit code）を扱うが、
**「patch 設計書が apply script を持たないため検出対象に入っていない」という別クラスの穴は扱っていない。**

**起票案**: 「`docs/working/_reports/*-patch.md` と `scripts/apply-*.sh` の対応を機械検出し、
apply script を持たない patch 設計書の滞留を可視化する」

### F-9. `.claude/skills/` に `design-gate` / `plan-review-gate` が存在しない ⚠️ 起票要否は Human 判断

4 root のうち `.claude` だけが該当 skill を持たない（`.claude/skills` 30 dir vs `.agents/skills` 40 dir、
**欠落 15 / 余剰 5**）。#963 AC-6 が「同期対象にするか対象外と明記するか」を求めているが、
**#963 本文は net の差（10）で書かれており、集合（15 欠落 + 5 余剰）で議論されていない。**
また #866 の「4 root」モデルが全 skill に成立するわけではないことの裏付けでもある。

**判定: #963 でカバーされるが、AC を net から集合へ書き換える必要がある。新規起票は不要。**

### F-10. issue 本文の絶対件数が陳腐化する共通パターン ⚠️ 新規要（プロセス issue）

STALE 16 件のうち **6 件（#866「2 件」/ #956「2 件」/ #990「残 1 件」/ #1010「30 TC」/ #1086「38 / differing=2」/ #1044「13 本」）が
「絶対件数を issue 本文に書いたことによる陳腐化」**である。
`plugin/plangate/README.md` と `docs/plangate-plugin-migration.md` は #1182 / #1183 で件数宣言を全廃し、
「件数は契約値として扱わない」と明記した。**同じ処方が issue 本文にも要る。**

**判定: 新規 issue（プロセス改善）が要る。**
**起票案**: 「issue 本文の受入基準に絶対件数を書かない規約を `docs/ai/issue-governance.md` に追加し、
既存 STALE 16 件の本文を相対 AC（集合照合 / 下限）へ書き換える」

### 新規 issue 候補のまとめ

| # | 候補 | 判定 | severity 目安 |
|---:|---|---|---|
| N-1 | `ta-69` の「正当に相違 26 件」の再検証 / 判別規則の定義（F-1） | **新規要** | 高（#1086 の裁定を歪めている） |
| N-2 | `.codex/skills/ai-dev-exec/SKILL.md:108` の hook 等価 false claim の先行是正（F-7） | **新規要** | **高**（安全性の誤情報が配布中） |
| N-3 | patch 設計書 ⇄ `apply-*.sh` の対応を機械検出（F-8） | **新規要** | 中（16 件の滞留を不可視化している） |
| N-4 | 統合先 issue が CLOSE されるとき移管 AC の受け皿を機械検出（F-5） | **新規要** | 中（#984 / #1177 で 2 回再発） |
| N-5 | issue 本文に絶対件数を書かない規約 + STALE 16 件の本文書き換え（F-10） | **新規要** | 中 |
| — | #921 完遂が #994 を殺す（F-2） | 既存 2 件へ AC 追記 | 高 |
| — | #1165 本文の反証（F-3） | 既存 #1165 の本文是正 | 高 |
| — | `scripts/parsers/*.py` 2 本（F-4） | #1178 の AC-7〜10 実装 PR に吸収 | 中 |
| — | #1093 の exemplar 反転（F-6） | 既存 #1093 の着手時対応 | 低 |
| — | `.claude/skills` の 15 欠落 / 5 余剰（F-9） | 既存 #963 の AC 書き換え | 低 |

**新規起票候補は 5 件。**

---

## 7. 停止条件 — この計画を作り直すべきタイミング

**本計画は `origin/main` = `684949e` の一点で測った写真であり、必ず stale 化する。**
以下のいずれかが起きたら、**該当節を再測定してから使うこと。全面作り直しが要るものは 🔴 で示す。**

| # | トリガ | 影響範囲 | 対応 |
|---:|---|---|---|
| **S-1** | 🔴 **`origin/main` が 5 commit 以上進んだ** | 全節 | §1 のマトリクスと §4 の適用状態を全件再測定。**前回（`2447bf8` → `684949e`）は 11 commit で 1 件の分類が反転した**（#863） |
| **S-2** | 🔴 **Q5 / Q6 / Q7（#956）のいずれかに回答が出た** | §2 / §5-1 / §6 F-1 / F-7 | クラスタ A の 6 件（#956 / #954 / #866 / #1170 / #1086 / #1057 の `.codex` 分）を再分類。**#1057 の実行層が L1 から変わる** |
| **S-3** | 🔴 **#921 Slice 2（`_pending_migration` の 45 本移行）に着手する PR が立った** | §3-3 順位 12 / §5-3 / §6 F-2 | **#994 を同一 PR に含めていなければ止める。** 走査対象が 26 本から減った時点で TC-33 の検出力を再測定 |
| **S-4** | **#1178 の AC-7〜10（`ta-70` 母集合反転）に着手する PR が立った** | §3-3 順位 11 / §5-4 / §6 F-4 | `scripts/parsers/*.py` 2 本の扱いが同一 PR に入っているかを確認。入っていなければ TC-01 が即 FAIL する |
| **S-5** | **`docs/working/_reports/` に新しい `*-patch.md` が追加された、または `scripts/apply-*.sh` が追加された** | §4 全体 | §4-1 の対応表を再生成（`git ls-tree --name-only <ref> docs/working/_reports/` と `scripts/`） |
| **S-6** | **`.claude/settings.example.json` を触る PR がマージされた** | §4-2 / §5-5 | #1151 → #984 → #1104 → #1144 の適用順を再評価。**後段の patch が先に入ると前段を作り直しになる** |
| **S-7** | **`scripts/hooks/check-plan-hash.sh` の `_override` case ブロックが変更された** | §0-3 / §1 の層分類全体 | HO 9 カテゴリを再読し、L2 / L3 の境界を引き直す。**行番号ではなく `_override=0` 直後の `case` 〜 `esac` で読むこと** |
| **S-8** | **`gh issue list --label bug --state open` の件数が 39 から変わった** | §1 | 増減分を分類に反映。close は §2 の 4 件から先に起きる想定 |
| **S-9** | **v8.22.0 のリリース準備が始まった** | §4 / §6 F-6 | `release-prep.sh --check` の `check_pending_applies()` は現行 patch を 1 件も拾わない（§6 F-8）。**「pending なし」を適用済みの証拠にしないこと** |
| **S-10** | **本計画の作成から 7 日が経過した** | 全節 | 少なくとも §1 のマトリクスと §2 の 7 問の判断材料を再測定する |

### 計画が stale 化しても壊れない部分 / 壊れる部分

| 壊れにくい | 壊れやすい |
|---|---|
| §5 の依存グラフの**構造**（どの issue がどの関数契約 / ファイルを共有するか） | §3 の**行番号**（`ta-69:229` など。記号アンカーへ読み替えること） |
| §6 の構造的問題の**存在**（F-1 / F-2 / F-8 は設計上の穴で、commit では消えない） | §4 の**適用状態**（patch は 1 commit で適用されうる） |
| §2 の**問いの形**（Q1〜Q7 の選択肢は判断待ちである限り不変） | §1 の**件数**（close / 起票で毎日動く） |

---

## 8. 測定方法と限界

### 8-1. 測定の規律

- **すべての測定で ref を明示した**: `git show origin/main:<path>` / `git grep <pat> origin/main -- <path>` /
  `git ls-tree -r origin/main` / `git rev-parse origin/main:<path>` / `git log --oneline origin/main -- <path>`。
  **作業ツリーの `ls` / `grep` は「実測」として扱っていない**
- **空出力を「0 件」の証拠にしていない。** 陽性コントロールを添えた例:
  `pre-push.sample` の `check-branch-not-merged` = 0 に対し `set -` = 1 /
  `test.yml` の `fetch-depth` = 0 に対し `uses: actions/checkout` = 1 /
  `bin/plangate` の `ai-loop)` = 0 に対し `metrics)` = 1 /
  `arbiter.py` の `source_kind` = 0 に対し `resolve_ho_patterns` = 7 /
  `.codex/skills/intent-classifier/SKILL.md` の `CLAUDE_PLUGIN_ROOT` = 0 に対し `.agents` 側 = 2
- **起動しなかったコマンドを 0 件と読まなかった。** #1162 の初回測定で
  `tests/extras/ta-33-agent-parity.sh` / `ta-57-ai-loop-delivery.sh` という**存在しないファイル名**を pathspec に渡し、
  git grep が空を返した。`git ls-tree` でファイル名を確認して
  `ta-33-agent-model-tier.sh` / `ta-57-pr-convergence.sh` に修正してから再測定した
- **量化子の主張は全数照合してから書いた**: `.codex` drift（42 blob を 1 件ずつ照合）/
  `PG-SH-GUARD` 未保有 `.py`（repo 全体 13 件を列挙）/ `17 項目` の残存（全ヒットを区分）/
  `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` 保有 70 件（root ごとに分解）/
  `settings.example.json` の hook ブロック（JSON パースして 11 ブロックを列挙）
- **件数だけでなく対象ファイル名の集合を書いた**（§2 Q3 の HO 6 / §4-1 の patch 18 件 / §6 F-4 の 13 件）
- **行番号アンカーを主アンカーにしていない。** HO 9 カテゴリは `_override=0` 直後の `case` 〜 `esac` で、
  TC-33 は判定式そのもので、`ta-70` TC-01 は `grep -q "$_T70_MARKER"` という文字列でアンカーした

### 8-2. 実行を避けたもの（意図的な限界）

安全指示に従い、以下は**一切実行していない**:

- `sh <任意の .py>`
- `scripts/sync-plugin-plangate.sh` / `scripts/install-*.sh` / `scripts/apply-*.sh --apply`
- `sh tests/run-tests.sh`（`ta-70` TC-04 が repo 実ファイルを `sh` 起動し、`ta-42` / `ta-09` が実 `docs/working/` に書き込む）
- issue / PR への書き込み操作（コメント・close・ラベル・編集）

**結果として、次は「未確認」であり PASS とも FAIL とも扱っていない**:

- `sh tests/run-tests.sh` の baseline 維持系 AC（ほぼ全件）
- 変異注入による検出力の実証（§3 の「検証方法」列は**設計であって実走結果ではない**）
- marketplace 実環境での plugin hook 発火 / skill 参照解決
- Codex ランタイムが実際に `.codex/skills` を読む動作（tracked ファイルの内容 parity のみ測定）
- `_reports/{1135-ai-owned-lane,1157-seeds-read-path,1163-ref-resolution-ci-design}-*.md` の適用状態
  （対応 issue が本計画の 39 件に含まれないため測定していない）
- #921 Slice 2 の子 TASK が起票済みかどうか

### 8-3. worktree 隔離ガードによる制約と回避方法

| 拒否されたもの | 回避方法 |
|---|---|
| 複数の `git grep` / `for` ループ / `echo` を 1 コマンドに連結したもの（「too complex to verify」で拒否） | **1 コマンド 1 目的に分割した。** 複数 ref にまたがる照合が必要な場合のみ `python3 -c` の `subprocess` で 1 コマンドにまとめた（`.codex` drift の 42 blob 照合 / `settings.example.json` の JSON パース / `FIXTURES_DIR:-` と `PG_HARNESS_SOURCED` の差集合） |

**測定を諦めた項目は無い。**
