# TASK-0871 T-01/T-02 — 矛盾一覧の確定監査（before 実測）+ HO 対象パス突合

- 実測日時: 2026-07-19（exec ワーカー）
- 実測環境: worktree `/.claude/worktrees/agent-add453a14f99d3467`（base = origin/main `e4fa976`）
- 目的: plan 付録 A（D-1〜D-12）の rg 再実測（付録 B 6 コマンド全実行・**T-04 実装前の before 値**）と、
  T-02 = HO 対象パス突合（`scripts/hooks/check-plan-hash.sh` case 文との照合）
- C-3 承認確認（Stop Condition 突合）: `approvals/c3.json` は branch
  `docs/task-0871-c3-approval`（commit `2f9fe83`・origin push 済）に
  `c3_status: "APPROVED"` / `plan_hash: sha256:e4679ad0…` で実在。worktree の
  `docs/working/TASK-0871/plan.md` の SHA256 実測 `e4679ad065257eb3b3c04662b2766b56b52dcedc390b89d5052a7a24468ec33b`
  と**一致**（exec 着手可）。
- issue #871 原文の独立照合ログ（C-2 R-001 対応）:
  [`issue-871-fetch.log`](./issue-871-fetch.log)（`gh issue view 871 --json body -q .body`・exit_code=0）

## 1. 付録 B rg 6 コマンド実測（before）

全コマンド exit code 0（マッチあり）。

### CMD1: 独立 PoC / 隔離 PoC 表現の残数

```sh
rg -n "独立 PoC|独立PoC|隔離 PoC" docs/workflows/ai-loop/ docs/ai/ai-loop/ .claude/commands/ .agents/skills/ai-loop-cycle/ .claude/skills/ai-loop-cycle/
```

**合計 8 件 / 5 ファイル**:

| ファイル | 件数 | 行 |
|---------|------|----|
| `docs/workflows/ai-loop/00_concept.md` | 3 | L15, L59（隔離 PoC）, L69（独立 PoC） |
| `docs/workflows/ai-loop/execution-runbook.md` | 2 | L38, L261（隔離 PoC） |
| `.claude/skills/ai-loop-cycle/SKILL.md` | 1 | L22（隔離 PoC） |
| `.agents/skills/ai-loop-cycle/SKILL.md` | 1 | L30（隔離 PoC） |
| `docs/ai/ai-loop/phase3-impact-report.md` | 1 | L73（隔離 PoC スクリプト・歴史記録文脈） |

### CMD2: terminal state 表記揺れ（MERGE_READY / merge-ready）

```sh
rg -n "MERGE_READY|merge-ready" docs/workflows/ai-loop/ docs/ai/ai-loop/ docs/ai/core-contract.md .claude/commands/ai-loop-workflow.md .agents/skills/ai-loop-cycle/SKILL.md .claude/skills/ai-loop-cycle/SKILL.md .claude/skills/pr-watch/SKILL.md
```

**合計 41 件 / 11 ファイル**（`docs/ai/core-contract.md` と `.claude/commands/ai-loop-workflow.md` は 0 件）:

| ファイル | 件数 | うち `MERGE_READY` 表記 |
|---------|------|------------------------|
| `docs/workflows/ai-loop/00_concept.md` | 9 | 0（全て merge-ready） |
| `docs/workflows/ai-loop/execution-runbook.md` | 9 | 1（L208） |
| `docs/workflows/ai-loop/adaptive-production-loop.md` | 7 | 1（L92） |
| `docs/workflows/ai-loop/loopspec.md` | 4 | 0 |
| `docs/workflows/ai-loop/agentic-six-stage-loop.md` | 3 | 3（L50, L62 + 参照 L201 は merge-ready） |
| `docs/ai/ai-loop/design-philosophy.md` | 3 | 0 |
| `docs/ai/ai-loop/hotl-merge-entry-criteria.md` | 2 | 0 |
| `docs/ai/ai-loop/concept.md` | 1 | 0 |
| `.claude/skills/ai-loop-cycle/SKILL.md` | 1 | 0 |
| `.agents/skills/ai-loop-cycle/SKILL.md` | 1 | 0 |
| `.claude/skills/pr-watch/SKILL.md` | 1 | 0 |

### CMD3: 裁定状態と Delivery 状態の同列列挙

```sh
rg -n "AUTO_APPROVED.*(merge-ready|MERGE_READY)|（merge-ready.*AUTO_APPROVED" docs/workflows/ai-loop/ docs/ai/ai-loop/
```

**合計 4 件 / 3 ファイル**:

| ファイル | 行 | 判定 |
|---------|----|------|
| `docs/workflows/ai-loop/adaptive-production-loop.md` | L70 | **同列列挙（要是正 = D-5 本体）**: Stop 行が裁定 3 値 + merge-ready + round limit exceeded を terminal state として同列列挙 |
| `docs/workflows/ai-loop/agentic-six-stage-loop.md` | L50, L62 | 区別済み（`MERGE_READY`（DoD 状態）と注記あり） |
| `docs/ai/ai-loop/design-philosophy.md` | L237 | 区別を定義している側（語彙集） |

### CMD4: C-3' の出現ファイルと件数

```sh
rg -c "C-3'" docs/workflows/ai-loop/*.md docs/ai/ai-loop/*.md .claude/commands/ai-loop-workflow.md docs/ai/core-contract.md
```

**12 ファイル・計 37 件**（`.claude/commands/ai-loop-workflow.md` / `docs/ai/core-contract.md` は 0 件 = D-4 のとおり実行契約に C-3' 経路が現れない）:

00_concept 9 / adaptive 6 / design-philosophy 6 / execution-runbook 3 /
stop-rollback 3 / concept.md 3 / agentic-six-stage-loop 2 / loopspec 1 /
decision-table 1 / flow-detect 1 / asset-inventory 1 / unknown-discovery 1

### CMD5: 「適用ドメイン（Phase 1）」注記の重複

```sh
rg -c "適用ドメイン（Phase 1）" docs/workflows/ai-loop/ docs/ai/ai-loop/ .agents/skills/ai-loop-cycle/ .claude/skills/ai-loop-cycle/
```

**15 ファイル・計 17 件**（= D-8 の反復埋め込み実測）:

docs/workflows/ai-loop/ 配下 11 ファイル各 1（00_concept / adaptive / decision-table /
execution-runbook / flow-detect / lite-criteria / loop-safety-gates / loopspec /
review-feedback-loop / stop-rollback / agentic-six-stage-loop）+
docs/ai/ai-loop/（design-philosophy 1 / arbiter-policy 1）+
`.agents/skills/ai-loop-cycle/SKILL.md` 2 + `.claude/skills/ai-loop-cycle/SKILL.md` 2

### CMD6: 5 責務語彙（ai-loop Delivery / ai-loop Evolution）の定義箇所

```sh
rg -n "ai-loop Delivery|ai-loop Evolution" docs/
```

**ヒットは `docs/working/TASK-0871/` 配下（plan / pbi-input / test-cases / review-external / evidence）のみ**。
ai-loop 本体 docs（`docs/workflows/ai-loop/` / `docs/ai/ai-loop/`）には **0 件** = D-12（Evolution 列欠落）の実測裏付け。

## 2. 付録 A D-1〜D-12 との突合結果

| # | 付録 A の内容 | 実測結果 | 判定 |
|---|--------------|---------|------|
| D-1 | 00_concept §1「独立 PoC」と恒久定義の混在 | CMD1: 00_concept L69 に「独立 PoC」現存 | **再現・T-04 で解消** |
| D-2 | 「Phase 1: 導入先適用」節が恒久定義と同居 | 00_concept L8-64 に現存 | **再現・T-03/T-04 で分離** |
| D-3 | core-contract §1-bis に merge-ready 終点言及なし | CMD2: core-contract 0 件 | **再現・T-06（後続）** |
| D-4 | core-contract に C-3' 経路が現れない | CMD4: core-contract 0 件 | **再現・T-06（後続）** |
| D-5 | adaptive §4 Stop の同列列挙 | CMD3: adaptive L70 に現存 | **再現・T-05（後続）** |
| D-6 | 区別正本が design-philosophy §5 に分散 | CMD3: design-philosophy L237 が区別を定義 | **再現・T-04 で正本へ、語彙集の扱いは TC-09/EC-5** |
| D-7 | MERGE_READY / merge-ready の 2 表記混在 | CMD2: 41 件中 `MERGE_READY` 5 件・残り merge-ready（同一概念） | **再現・T-04 で `MERGE_READY` に正規化** |
| D-8 | Phase 1 注記の反復埋め込み | CMD5: 15 ファイル 17 件 | **再現・正本参照化は T-04〜T-07** |
| D-9 | C-3 系経路の二重定義（00_concept §3.5 / working-context） | 00_concept L197-202 §3.5 現存 | **再現・T-04 で役割分界を明記** |
| D-10 | Phase 番号衝突（deploy 0/1 vs 構築 2/3） | 00_concept L62-63 の注記現存 | **再現・T-03 移設時に整理** |
| D-11 | command の PoC 表現混在 | command L5 現存（HO 対象・本ワーカー編集禁止） | **再現・T-07（後続・Human 適用）** |
| D-12 | 責務表に Evolution 列なし | CMD6: ai-loop 本体 docs 0 件 | **再現・T-04 で 5 責務表に追加** |

付録 A との不一致: **0 件**（12/12 再現）。

## 3. T-03 Stop Condition 用の移設元 before 値

```sh
rg -c "touches-HO|NO MERGE BY AI|判定不能" docs/workflows/ai-loop/00_concept.md
# => 5（ファイル全体）
```

行内訳: L32（判定不能→false）/ L51（NO MERGE BY AI）/ L53（判定不能→false）/
L201（touches-HO・§3.5 = Phase 1 節**外**）/ L275（touches-HO・関連ドキュメント一覧 = Phase 1 節**外**）。

**移設対象 =「Phase 1: 導入先適用」節（L8-64）内の 3 件**（L32 / L51 / L53）。
L201 / L275 は恒久定義・参照一覧であり移設対象外（00_concept に残置）。
→ T-03 完了時、`rollout-policy.md` は `NO MERGE BY AI` ≥1・`判定不能` ≥2 を含み、
かつ HO escalate 条件として `touches-HO` を明示すること（欠落 0 件の判定基準）。

## 4. T-02: HO 対象パス突合（読取のみ）

照合元: `scripts/hooks/check-plan-hash.sh` L124-134 の Hardening Override case 文
（9 カテゴリ: `.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md`（サブディレクトリ含む）/
`.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` /
`.github/workflows/*.y(a)ml` / `AGENTS.md`・`CLAUDE.md`）。

本 TASK の touch 予定ファイル（plan「Files / Components to Touch」）との突合:

| touch 予定ファイル | HO case 文マッチ | 判定 |
|--------------------|------------------|------|
| `docs/workflows/ai-loop/00_concept.md` | なし | HO 外（AI 編集可） |
| `docs/workflows/ai-loop/rollout-policy.md`（新設） | なし | HO 外 |
| `docs/workflows/ai-loop/*.md`（周辺 6 本） | なし | HO 外 |
| `docs/ai/core-contract.md` | なし | HO 外（ただし CLAUDE.md 参照系 = 🚩 Human diff 確認。T-06 後続） |
| `.claude/commands/ai-loop-workflow.md` | **`.claude/commands/*.md` に一致** | **HO 該当（唯一）**。EH-3 常時 block・適用は Human（H-02） |
| `.agents/skills/ai-loop-cycle/SKILL.md` | なし（`.agents/` はパターン外） | HO 外 |
| `.claude/skills/ai-loop-cycle/SKILL.md` | なし（`.claude/skills/` はパターン外 — mode-classification R-003/R-006 注記と一致） | HO 外（AI 編集可・plan Q5 確定どおり） |
| `docs/ai/ai-loop/*.md`（spec 層 3 本） | なし | HO 外 |
| `plugin/` 同梱 references | なし | HO 外（sync スクリプト経由のみ） |

**結論**: HO 該当は `.claude/commands/ai-loop-workflow.md` の 1 件のみ（plan R-1 の想定どおり）。
S6/T-07 の適用方式 = AI は diff 提示まで・適用判断は Human（H-02）で確定。
本ワーカー（T-01〜T-04）は同ファイルおよび `docs/ai/core-contract.md` に触れない。

---

## 5. T-10: 用語監査 after 実測（PR-1 ブランチ `docs/task-0871-canonical`・2026-07-19）

> **解釈上の前提**: PR-1 ブランチは plan「2 PR 分割構成」により **T-05（周辺 6
> docs 整合 = commit `e8f42f0`）を含まない**。周辺 docs（six-stage / adaptive /
> flow-detect / stop-rollback / loopspec / execution-runbook）の残置は
> **PR-2 で解消予定の期待どおりの値**である。

| CMD | before（§1・T-01） | after（PR-1） | 差分と残置の採否理由 |
|-----|-------------------|---------------|---------------------|
| CMD1 独立/隔離 PoC | 8 件/5 ファイル | 5 件/3 ファイル | 00_concept 3→0・SKILL 両版 2→0（解消）。残置: rollout-policy 2（Phase 0 の**歴史記録として verbatim 移設した文言**・恒久定義でない — 採用）/ execution-runbook 2（**PR-2 対象**）/ phase3-impact-report 1（歴史レポート・plan の走査対象だが編集対象外 — 残置採用） |
| CMD2 MERGE_READY/merge-ready | 41 件/11（MERGE_READY 5） | 49 件/12 | 00_concept 9→19（全て `MERGE_READY` 正規化済み・定義正本化で増加は仕様）/ core-contract 0→1（T-06 追記）。周辺 docs の merge-ready 旧表記は **PR-2 対象** |
| CMD3 同列列挙 | 4 件（要是正 = adaptive L70） | 4 件 | adaptive L70 の是正は **PR-2（e8f42f0）対象**。他 3 件は区別を定義/注記する側で是正不要（before と同判定） |
| CMD4 C-3' 定義箇所 | 12 ファイル 37 件（command/core-contract 0） | 15 ファイル 45 件 | 00_concept 9→20（正本集約・仕様どおり増）/ **command 0→1・core-contract 0→1**（D-4 解消: 実行契約と入口に C-3' への参照が現れた）/ rollout-policy 3（新設・参照のみ） |
| CMD5 適用ドメイン注記 | 15 ファイル 17 件 | 12 ファイル 12 件 | 00_concept・SKILL 両版（各2）・command 分は解消。残 12 件中 workflows 配下 10 件は **PR-2 対象**、design-philosophy / arbiter-policy の各 1 件は spec 層「参照化 or 採否記録」対象（TC-09/TC-12 の確定に委ねる — 本 PR では未編集のまま残置） |
| CMD6 5 責務語彙（本体 docs） | 0 件 | 00_concept 8 件 | D-12 解消（5 責務表 + Delivery/Evolution 区別が正本に存在） |

## 6. T-08a N-2: sync スクリプト stale コメント「17 本」の採否記録

`scripts/sync-plugin-plangate.sh` L196 のコメント「workflows 10 本 + spec 6 本 +
ho-paths.md = 17 本」は rollout-policy.md 追加後の実態（workflows 11 本）と
乖離するが、**本 PR では編集しない（不採用）**。理由:

1. PR-1 の編集ファイル実数を 10 に保つ（Replan 後の上限 12 に対する余裕確保。
   スクリプト touch は sync workflow の path トリガにも該当し波及が読みにくい）
2. コメントのみの乖離で動作影響ゼロ（references/ 同期は glob 駆動・数値は使われない）
3. 数値レス化は別途軽微修正（#877 系 chore）で対応可能

## 7. T-11: sync dry-run 差分ゼロの最終確認（PR-1）

T-08a commit（`970c226`）後に `sh scripts/sync-plugin-plangate.sh --dry-run` を
再実行 → **「Sync complete — no changes」・exit 0（差分ゼロ）**。
sync 生成物は期待 4 本と完全一致（期待外への波及 0 件・PR-2 対象 references
への巻き込みなし = e8f42f0 未包含のため周辺 docs は main のまま）。

## 8. T-11 追記: T-12 所見 2 反映後の sync 再確認（2026-07-19）

独立レビュー #1（`independent-review-1.md`・矛盾 0 件 PASS）の参考所見 2
（SKILL 両版 Step 5 の小文字 merge-ready）を `MERGE_READY` 表記へ統一
（意味変更なし・該当 2 行のみ）した後、`sh scripts/sync-plugin-plangate.sh` を
再実行（COPY: skills/ai-loop-cycle/SKILL.md の 1 本のみ波及・期待どおり）。
続けて `--dry-run` 再確認 → **「Sync complete — no changes」・exit 0（差分ゼロ維持）**。
