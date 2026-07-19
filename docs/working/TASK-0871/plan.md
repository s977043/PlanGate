# EXECUTION PLAN — TASK-0871 正本定義統合・PoC 制約分離

> 対象 issue: [#871](https://github.com/s977043/plangate/issues/871) / 親 EPIC: [#870](https://github.com/s977043/plangate/issues/870)
> 起草: 2026-07-19（plan 起草ワーカー）。C-3 は同期・Human 必須（high-risk）。

## Goal

PlanGate Core / ai-dev / ai-loop Delivery / ai-loop Evolution / Human Gate の
5 責務と terminal state（`PR_CREATED` / `MERGE_READY` / `MERGED`）、および
C-3 / C-3' 経路を定義する**単一正本文書を確定**し、Phase 1 PoC の rollout
policy（lite / clean / reversible）を**別レイヤーへ分離**する。既存文書
（command / skill / 00_concept / six-stage / adaptive / Core Contract）の参照を
新正本へ整合させ、責務・terminal state の重複定義を削減する。

## Constraints / Non-goals

- **Non-goals**（issue #871 準拠）: C-3' arbiter / PR controller の実装、lite 適用
  範囲の拡大、C-4 / merge の自動化、文書階層全体の一括移動・改名
- **#866 は本 TASK のスコープ外・別トラック**: intent-classifier /
  skill-policy-router の skills 正本三つ巴矛盾（#866）はドメインが skills sync
  機構側で、修正経路も sync スクリプト設計判断を伴う。AC-9「同じ責務の複数
  正本が残っていない」の判定対象は **ai-dev / ai-loop のアーキテクチャ・責務
  定義文書に限定**する
- 承認境界は不動: NO MERGE BY AI / HO 接触 escalate / C-2 2 レーン契約
  （review-principles §7-bis）は変更しない
- PlanGate 本番フロー WF-00〜07 は不変（ai-loop は Phase 1 のまま）
- `.claude/commands/ai-loop-workflow.md` は HO 対象パス。編集 diff は AI が
  用意するが、適用可否は Human C-3 / HO 運用（HO 常時 block）に従う

## Metrics Evidence（事前メトリクス検証 / B-1→B-2 mandatory gate）

- 対象「参照整合をとるべき文書」の実数取得:
  - `rg -l "C-3'" docs/workflows/ai-loop/*.md` → **9 ファイル**（実測 2026-07-19）
  - `rg -l "MERGE_READY|merge-ready"` → 00_concept / adaptive / six-stage /
    execution-runbook / loopspec / `.agents/skills/ai-loop-cycle/SKILL.md` の **6 ファイル**
  - AC-10 名指し対象: command 1 + skill 1 + docs 3 + core-contract 1 = **6 ファイル**（編集必須）
  - 参照追従が必要になり得る周辺: flow-detect / stop-rollback / loopspec /
    execution-runbook / unknown-discovery / design-philosophy ≈ **6 ファイル**（参照 1 行の追従のみ）
- AI 見積もり: 編集 8〜12 ファイル / 実数（必須 6 + 追従 ≤6）= **最大 12**
- ratio ≈ 1.0〜1.5（< 3 倍）→ **採用**。ratio 分は Risks R-2 に記録
- **C-2 反映後の再計算（R-007/R-008 取り込み）**: 編集必須 = AC-10 名指し 6 +
  rollout-policy 新設 1 + `.claude/skills/ai-loop-cycle/SKILL.md` 1 = **8**。
  条件付き（採否理由記録のみで編集ゼロになり得る）= 周辺 docs ≤4 +
  design-philosophy 1 + `docs/ai/ai-loop/` spec 層 3 = **≤8**。見込み 8〜16 で
  **上限 12 を超過し得る** → Replan Trigger（>12 で follow-up 分割）を発動基準
  とし、超過時は条件付き群（参照 1 行追従・採否記録系）を第 2 PR へ分割する
- sync 対象確認: `scripts/sync-plugin-plangate.sh` 実在（実測）
- **Replan 再計算（2026-07-19 Replan Trigger 発動・Human 判断）**: exec 実測で
  手編集 11 ファイル（docs/working 除外）に達し、CI
  `.github/workflows/sync-plugin-plangate.yml` の drift-check が
  `docs/workflows/ai-loop/**` 等を touch する PR に「sync 実行後差分ゼロ」を
  強制（#842 R-005 fail-closed）するため **sync 生成物は各 PR に同梱必須**
  （sync 後回し分割は不可）。手編集 11 + sync 生成物で上限 12 を超過見込み →
  Replan Trigger を原則どおり発動し **2 PR 分割**へ改訂（Human 判断
  2026-07-19: カウント除外の逸脱は不承認・plan 分割で対応）。
  sync 対象マッピング実測（`scripts/sync-plugin-plangate.sh` L95-99 dir loop /
  L103-114 skills loop / L153-200 ai-loop references 同期）:
  - `docs/workflows/ai-loop/*.md`（glob 全件）→ `plugin/plangate/skills/ai-loop-cycle/references/<同名>.md`（1:1・リンク変換つき）
  - `.agents/skills/ai-loop-cycle/SKILL.md` → `plugin/plangate/skills/ai-loop-cycle/SKILL.md`
  - `.claude/commands/ai-loop-workflow.md` → `plugin/plangate/commands/ai-loop-workflow.md`
  - `docs/ai/core-contract.md` / `.claude/skills/ai-loop-cycle/SKILL.md` は **sync 対象外**（plugin に対応物なし・実測）
  - **PR-1 実数見込み = 手編集 6 + sync 生成物 4 = 10（≤ 12 ✓）**
  - **PR-2 実数見込み = 手編集 6 + sync 生成物 6 = 12（≤ 12 ✓・上限ちょうど）**

## Approach Overview — 正本の指定方針（選択肢比較）

| 観点 | A案: 新設単一正本（`docs/workflows/ai-loop/architecture.md` 新規作成、既存は参照へ） | B案: `00_concept.md` を昇格・再構成（正本節を確定し、Phase 1 制約を新設 `rollout-policy.md` へ分離） | C案: `docs/ai/core-contract.md` へ責務表を追加（実行契約に統合） |
|------|------|------|------|
| AC-5（invariant / rollout 分離） | ◎ 構造として最も明快 | ◎ 分離先を新設 1 ファイルに限定 | △ core-contract が肥大、rollout の置き場が別途必要 |
| AC-9（複数正本の解消） | ○ ただし 00_concept との役割再定義が必要（正本が一時的に 2 つ見える移行期リスク） | ◎ 既存の事実上の正本を正本と宣言するだけで二重化しない | △ 00_concept との二重定義がむしろ増える |
| 既存参照リンクへの影響 | △ 全参照元の張り替えが必要（12 ファイル規模） | ◎ 参照先パス不変。Non-goals「一括移動・改名」と整合 | △ workflow 層→契約層への依存方向が逆転（hybrid-architecture Rule 1 と摩擦） |
| plugin sync（references 同梱） | △ 同梱物 1 件追加 + 参照張り替え | ○ 既存同梱ファイルの中身更新 + rollout-policy 1 件追加 | △ core-contract は plugin references 非同梱で導入先から見えない |
| HO 接触量 | 同等（command / core-contract の参照更新は全案共通） | 同等 | 大（core-contract 本体を大改変） |
| 実装コスト | 高 | **中** | 中〜高 |

**推奨: B案**。`docs/workflows/ai-loop/00_concept.md` を「ai-dev / ai-loop
アーキテクチャ・責務定義の単一正本」として明示昇格し、§冒頭〜§3 を
「恒久 invariant（5 責務 + terminal state + C-3/C-3' 経路）」として再構成する。
Phase 1 の適用制限（現行の冒頭「Phase 1: 導入先適用」節・lite/clean/reversible
の rollout 条件）は新設 `docs/workflows/ai-loop/rollout-policy.md` へ移し、
00_concept からは参照のみとする。他文書（command / skill / six-stage /
adaptive / core-contract）は正本参照 + 自文書責務（索引 / 実行手順 / 上位概念 /
実行契約）に限定する。これは design-philosophy §7.1 の「一括再編回避」と
issue Non-goals（一括移動・改名の禁止）に整合し、AC-9 を「正本宣言 + 重複削減」
で満たす最小変更経路である。

### 正本に確定する内容（EPIC #870 の統合定義を転記・確定）

| レイヤー | 責務 | AI 責務の終点 |
|---|---|---|
| PlanGate Core | artifact / gate / validation / evidence / stop rule | 実行プロファイルへ提供 |
| ai-dev | PBI → Plan → C-1/C-2/C-3 → exec / verify → PR | `PR_CREATED` |
| ai-loop Delivery | C-3' → CI / review / repair | `MERGE_READY` |
| ai-loop Evolution | completed runs → candidate → experiment → improvement PR | 改善 PR の `MERGE_READY` |
| Human | 例外 C-3、HO / policy / first principles、C-4 / merge | `MERGED` |

- terminal state: `PR_CREATED`（ai-dev の AI 責務終点・判定主体 = ai-dev）/
  `MERGE_READY`（ai-loop Delivery の DoD 状態・判定主体 = ai-loop の DoD 判定。
  CI green + AI レビュー全件対応の AND）/ `MERGED`（Human C-4 のみが到達させる）
- 裁定状態（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED` = arbiter 3 値）と
  Delivery 状態（`MERGE_READY` 等）を別の語彙群として区別する（AC-6）
- C-3' = eligible run（lite / clean / no-merge / gates 充足）の**標準自動経路**、
  Human C-3 = **escalate 経路**（touches-HO / lite=false / 判定不能 / W 不一致
  重大時）。判定主体: C-3' = arbiter（decision table priority 0〜6）、
  escalate 先 = Human（AC-4）
- ai-loop は ai-dev の Plan / exec / verify を再実装せず共通利用（AC-3）
- **C-3' と WF-00〜07 不変の両立規定（R-006 反映）**: 正本に「PlanGate 本番
  フロー（WF-00〜07）の C-3 は常に Human・pre-exec のまま不変」「C-3' は
  ai-loop Delivery（eligible run）に限る**別経路**であり、PlanGate C-3 を
  置換しない」を**順序図付き**で規定する（両経路の入口分岐 → C-3 / C-3' →
  exec → terminal state を 1 つの図で示す）。検証は TC-04 の拡張
  （core-contract / WF 対応表の不変性確認）で行う
- 内側 Delivery Loop（1 run: Request → MERGE_READY）と外側 Evolution Loop
  （completed runs → candidate → experiment → improvement PR）を区別（AC-7）
- active run は開始時の harness を最後まで保持し自己変更しない。改善は別
  TASK / Plan / PR で行う（AC-8）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 | rollback |
|------|------|--------|-------|------|-----|---------|
| S1 | 矛盾一覧の確定監査（付録 A を rg で再実測し evidence 化） | `evidence/verification/terminology-audit.md` | agent | 低 | - | 不要（読取のみ） |
| S2 | `rollout-policy.md` 新設（Phase 1 適用制限・lite/clean/reversible・auto-approve 方針を 00_concept から移設。**設計前提 = 汎用表現で verbatim 配布・雛形注記ヘッダ機構なし — Q6 C-3 確定**） | `docs/workflows/ai-loop/rollout-policy.md` | agent | 中 | - | `git revert`（新規 1 ファイル削除） |
| S3 | `00_concept.md` 再構成（正本宣言 + 5 責務表 + terminal state 定義 + C-3/C-3' 経路 + Delivery/Evolution 区別 + harness 自己変更禁止 + Phase 1 節を rollout-policy 参照へ置換） | 更新版 00_concept.md | agent | 高 | 🚩 S3 完了時に diff 提示・Human 確認 | `git revert`（単一 commit に閉じる） |
| S4 | 周辺 docs 整合（six-stage / adaptive / flow-detect 等の terminal state・責務記述を正本参照へ。重複定義の削減） | 更新版各 docs | agent | 中 | - | `git revert` |
| S5 | Core Contract 整合（§1-bis へ「ai-loop 実行プロファイル時の AI 責務終点 = merge-ready、C-4/merge は Human 固定」の参照追記。実行契約の骨格は不変） | 更新版 core-contract.md | agent | 高 | 🚩 HO 隣接（CLAUDE.md 参照系）。diff 提示・Human 確認 | `git revert` |
| S6 | command / skill 整合（`.claude/commands/ai-loop-workflow.md` と `ai-loop-cycle` SKILL の「独立 PoC」「本番承認フロー非適用」表現を「恒久定義は正本参照 + 適用制限は rollout-policy 参照」へ） | 更新版 command / SKILL | agent（**HO パス: 適用は Human C-3 / HO 運用に従う。AI は diff 提示まで**） | 高 | 🚩 HO 接触。Human 承認なしに commit しない | `git revert` + HO 運用（Human 手適用分は Human が戻す) |
| S7 | plugin sync 整合（`sh scripts/sync-plugin-plangate.sh` dry-run 差分ゼロ確認。references 同梱関係を正本に明記） | dry-run ログ（evidence） | agent | 中 | - | 不要（検証のみ。差分があれば sync 実行を C-3 承認範囲で） |
| S8 | Verification（link check / rg 用語監査 / AC-1〜10 突合） | `evidence/verification/` 一式 | agent | 低 | - | 不要 |
| S9 | 独立レビュー（maker と別コンテキストで責務境界・C-3/C-3'・terminal state 矛盾 0 件確認） | review 記録 | agent（別コンテキスト）+ human | 中 | 🚩 矛盾 >0 なら S3〜S6 へ差し戻し | 不要 |

依存: S1 → S2 → S3 → (S4 ∥ S5 ∥ S6) → S7 → S8 → S9。
速く学べる順: S1（事実確定）→ S2/S3（正本確定）を先行し、周辺追従（S4〜S6）は
正本確定後に並列化。クリティカルパスは S3。

### 2 PR 分割構成（Replan 2026-07-19・Human 承認済み）

CI drift-check（#842 R-005 fail-closed: `docs/workflows/ai-loop/**` 等 touch 時に
sync 後差分ゼロを強制）により sync 生成物は各 PR 同梱必須。以下に分割する:

| PR | 内容 | 手編集ファイル | sync 生成物（plugin/） | 合計 |
|----|------|---------------|----------------------|------|
| **PR-1（正本確定・本 TASK の主 PR）** | S1〜S3 + S5 + S6 + S7a | `docs/workflows/ai-loop/rollout-policy.md`（新設）/ `00_concept.md` / `docs/ai/core-contract.md` / `.claude/skills/ai-loop-cycle/SKILL.md` / `.agents/skills/ai-loop-cycle/SKILL.md` / `.claude/commands/ai-loop-workflow.md`（HO patch・**H-02 承認済み**）= 6 | `skills/ai-loop-cycle/references/rollout-policy.md`（新規）/ `references/00_concept.md` / `skills/ai-loop-cycle/SKILL.md` / `commands/ai-loop-workflow.md` = 4 | **10 ≤ 12** |
| **PR-2（周辺追従・follow-up）** | S4 + S7b（T-05 = commit `e8f42f0` の内容） | six-stage / adaptive / flow-detect / stop-rollback / loopspec / execution-runbook = 6 | `references/` 同名 6 本 | **12 ≤ 12** |

- **ブランチ構成**: PR-1 = 現 worktree から T-05 commit（`e8f42f0`）を除いた
  cherry-pick 構成 / PR-2 = `e8f42f0` + 対応 sync（**実施はオーケストレーター**）
- S7（plugin sync）は **S7a（PR-1 分）/ S7b（PR-2 分）に分割**。
  S8〜S9（検証・独立レビュー）および TC-11（sync dry-run 差分ゼロ）は
  **PR ごとに実施・成立**させる
- PR-2 は PR-1 merge 後に作成する（正本参照リンクの解決順を保証）

## Stop Condition / Replan Triggers（C-1 F-1 反映 / C1-LOOP-01/02）

### Stop Condition（即停止・機械値 + 判定手段 / R-004 反映）

| 条件 | 機械値 | 判定コマンド / 証跡パス（入力元） | 動作 |
|------|--------|----------------------------------|------|
| 独立レビュー（TC-13）の矛盾指摘 | **> 0 件** | `evidence/verification/independent-review-<N>.md`（連番 artifact）の指摘表の行数を実測 | 停止し S3〜S6 へ差し戻し（S9 🚩 と同一） |
| HO 対象ファイル（T-07）の diff が Human 未承認 | 承認記録の未存在 | `docs/working/TASK-0871/approvals/ho-apply-approval.md`（H-02 の承認記録）— `ls` で存在確認。未存在 = 未承認 | T-07 停止・V-1 を PASS にしない（EC-1 と同一） |
| C-3 承認なし | `decision != "APPROVED"` | `jq -r .decision docs/working/TASK-0871/approvals/c3.json`（ファイル未存在も未承認扱い） | T-03〜T-08 着手禁止（Iron Law #1） |
| 安全側不変条件の移設欠落 | rg 突合で欠落 **≥ 1 件** | `rg -c "touches-HO\|NO MERGE BY AI\|判定不能→false" docs/workflows/ai-loop/rollout-policy.md` を移設元 00_concept（変更前 `git show origin/main:...`）と件数突合 | 停止し S2/S3 を修正（R-4 / EC-4） |

### Replan Triggers（plan 再生成・C-3 再承認へ戻る・機械値 + 判定手段 / R-004 反映）

| トリガ | 機械値 | 判定コマンド / 証跡パス（入力元） | 動作 |
|--------|--------|----------------------------------|------|
| 編集ファイル実数が上限超過 | **> 12 ファイル（PR 単位で判定）** | `git diff --name-only origin/main...HEAD \| grep -v '^docs/working/' \| wc -l`（PR ブランチごと） | 停止し follow-up PR 分割へ replan（R-2）。**2026-07-19 発動済み → 2 PR 分割へ改訂（Work Breakdown「2 PR 分割構成」）** |
| sync dry-run 差分が正本外へ波及 | 波及 **≥ 1 ファイル** | `sh scripts/sync-plugin-plangate.sh` dry-run 出力のファイル一覧を本 plan「Files / Components to Touch」節（allowlist）と突合し、一覧外の検出数を数える | 停止し scope 再判定・replan（R-5 / Iron Law #2） |
| 独立レビュー差し戻しが 2 巡しても矛盾 > 0 | **2 巡超過** | `ls docs/working/TASK-0871/evidence/verification/independent-review-*.md \| wc -l` が **> 2** かつ最新 artifact の矛盾 > 0 | plan へ差し戻し・Human C-3 再承認 |

## Files / Components to Touch

- `docs/workflows/ai-loop/00_concept.md`（正本昇格・再構成）
- `docs/workflows/ai-loop/rollout-policy.md`（**新設**）
- `docs/workflows/ai-loop/agentic-six-stage-loop.md` / `adaptive-production-loop.md`
  / `flow-detect.md` / `stop-rollback.md` / `loopspec.md` / `execution-runbook.md`
  （参照整合・重複削減。差分が出るもののみ）
- `docs/ai/core-contract.md`（§1-bis 参照追記・小差分）※CLAUDE.md 参照系
- `.claude/commands/ai-loop-workflow.md`（**HO 対象**・小差分）
- `.agents/skills/ai-loop-cycle/SKILL.md`（適用ドメイン記述の参照化）
- `docs/ai/ai-loop/design-philosophy.md`（EC-5 / D-6 の解消先候補: §5 語彙集と
  新正本の状態語彙定義の二重化解消。touch 要否は TC-09/EC-5 の確定結果次第
  — 語彙集を参照化する場合のみ小差分。C-1 F-2 反映）
- `.claude/skills/ai-loop-cycle/SKILL.md`（**repo ローカル実行版・`.agents` 版と
  別内容で並存**。L21-22 に Phase 1 制限直書きあり。HO 対象外・AI 編集可。
  取り扱い方針は Q5 参照。R-007 反映）
- `docs/ai/ai-loop/` の plugin 同梱 spec 層（`concept.md`〔L56 に merge-ready
  責務表〕/ `asset-inventory.md` / `hotl-merge-entry-criteria.md` — sync の
  `_ai_loop_spec_files` 対象）: **編集必須ではなく「参照化 or 採否理由記録」
  対象**として TC-09 / TC-12 の走査範囲に含める（R-008 反映）
- `plugin/` 同梱 references（sync スクリプト経由でのみ更新）

## Testing Strategy

- **doc 検証**: markdownlint / リンクチェック（相対パス・アンカー）
- **用語監査（機械）**: 付録 A の rg コマンド群で旧定義・矛盾表現の残数を計測し、
  残す場合は採否理由を evidence に記録
- **sync 検証**: `sh scripts/sync-plugin-plangate.sh` dry-run 差分ゼロ
- **独立レビュー**: maker と別コンテキストのレビューで矛盾 0 件（test-cases TC-13）
- 詳細 AC→TC マッピングは `test-cases.md`

## Risks & Mitigations（内容 / 検証手段 / Fallback）

- **R-1 HO 接触**: `.claude/commands/ai-loop-workflow.md` は HO 対象で AI 適用
  不可の運用がある / 検証: check-plan-hash.sh の HO パターンと突合 / Fallback:
  当該ファイルのみ Human 適用 or 明示承認フローに分離した commit にする
- **R-2 編集ファイル数の膨張**（見積 8〜16〔C-2 反映後再計算・Metrics Evidence 参照〕 → 実測で 12 超過の恐れ）/ 検証: S1 の
  再実測で確定 / Fallback: 参照 1 行追従に留まる周辺 docs は別 follow-up PR に分割
  / **顕在化・対応済み（2026-07-19）**: 手編集 11 + sync 生成物同梱必須（CI
  drift-check #842 R-005）で超過見込みが確定し Replan Trigger 発動。Fallback
  どおり 2 PR 分割（Work Breakdown「2 PR 分割構成」= PR-1: 10 / PR-2: 12、
  いずれも ≤ 12）へ plan 改訂した
- **R-3 core-contract の改変が実行契約を揺らす** / 検証: 追記は §1-bis への
  参照 1 段落に限定し Iron Law / Stop rules は不変を diff で確認 / Fallback:
  core-contract 変更を落とし、正本側から一方向参照のみにする（AC-10 は参照
  整合で満たす）
- **R-4 「独立 PoC」語彙の削除が Phase 1 の安全側制約を弱めて見える** / 検証:
  rollout-policy.md に不変条件（HO escalate / NO MERGE BY AI / lite AC-8）を
  そのまま移設し rg で欠落ゼロ確認 / Fallback: 00_concept に安全側不変条件の
  要約表を残す
- **R-5 plugin sync 差分の巻き込み**（正本更新と同期漏れ）/ 検証: S7 dry-run /
  Fallback: sync 実行を同一 PR に含め差分ゼロを CI evidence 化

## Questions / Unknowns（C-3 で確定）

- Q1: `rollout-policy.md` の配置は `docs/workflows/ai-loop/` でよいか
  （代替: `docs/ai/ai-loop/`）
- Q2: core-contract §1-bis への追記は「参照 1 段落」で足りるか、責務表の
  併記まで行うか
- Q3: S6 の HO 対象ファイルは本 PR に含めるか、Human 適用の別 commit に
  分離するか
- Q4（C-1 F-3 / C-2 R-002 反映）— **確定: 承認済み（2026-07-19 C-3 / Human
  APPROVE）**。AC-9 の監査対象限定（ai-dev / ai-loop アーキ文書に限定・#866 は
  別トラック）を Human が C-3 で明示承認した。TC-09 は本承認を前提に PASS 判定
  可能。issue #871 への scope 注記コメントはオーガナイザーが実施（承認結果の
  evidence 記録は todo T-13 のとおり）
- Q5（C-2 R-007 反映）— **確定（2026-07-19 C-3）**:
  `.claude/skills/ai-loop-cycle/SKILL.md`（repo ローカル実行版）は**本 TASK で
  新正本へ整合させる**。T-07 で `.agents` 版と併せて編集し（HO 外・AI 編集可）、
  TC-14 で機械検証する。ファイルが別であるため #866 の Non-goals 除外は流用
  しない
- Q6（C-2 R-009 反映）— **確定（2026-07-19 C-3）**: `rollout-policy.md` は
  **汎用の書き方で作成し verbatim 配布**する（雛形注記ヘッダ機構は追加しない）。
  これを S2 / T-03（rollout-policy 新設）の**設計前提**とする — 本文は導入先で
  もそのまま読める汎用表現（plangate 本体固有の文脈依存表現を持ち込まない）
- Q7 — **確定（2026-07-19 Human 判断・Replan）**: plugin sync 生成物を
  Replan Trigger の編集ファイル実数カウントから**除外する逸脱は不承認**。
  原則どおり Replan Trigger を発動し、**2 PR 分割**（Work Breakdown
  「2 PR 分割構成」）で上限 12 以内に収めて対応する
- 進捗記録（status 反映・2026-07-19）: **T-04 diff / T-06 diff は Human 🚩
  承認済み**。**H-02（HO 対象 `.claude/commands/ai-loop-workflow.md` への
  patch 適用判断）も承認済み**（patch =
  `evidence/ho-patch/ai-loop-workflow.md.patch`・`git apply --check` exit 0。
  適用オペレーション自体は Human 実施待ち）

## Mode 判定

**モード**: **high-risk**

**判定根拠**:
- 定量: 変更ファイル数 8〜12（6-15 帯）→ high / 受入基準数 10（6-10 帯）→ high
  / タスク数見込み 11〜15 → high
- 定性: 変更種別 = ワークフロー定義・責務境界の再定義（アーキ整理）→
  high〜critical 相当だが、実体は文書再構成で実行系コード変更なし → high /
  影響範囲 = ai-loop 文書群 + command + core-contract（複数レイヤー波及）→ high
- **例外ルール（決定打）**: 承認境界周辺の変更 → 最低でも「高」
  （mode-classification 正本）。touch 対象に `.claude/commands/*.md`（HO 9
  カテゴリ該当）および `CLAUDE.md` 参照系の `docs/ai/core-contract.md` を含む
- doc-light は**適用不可**（除外条件「承認境界周辺の `.md` を変更」に該当）
- **最終判定**: high-risk（定量 high・定性 high・例外ルール high の一致）

**lite_eligible = false**（Hardening Override 対象パス touch により強制。
mode-classification AC-10 / working-context AC-10）。
**C-3 は同期・Human 必須**（autonomous APPROVE 不可: high-risk かつ HO 対象
パス含みのため判定マトリクス上 ❌）。C-3' / ai-loop 経路も適用しない
（承認境界周辺・本番フロー文書のため）。

## 付録 A: 矛盾・語彙揺れ一覧（下書き / S1 で evidence 化）

読了文書: 00_concept.md / agentic-six-stage-loop.md（§1〜4）/
adaptive-production-loop.md（§1〜6）/ decision-table.md /
`.claude/commands/ai-loop-workflow.md` / `docs/ai/core-contract.md` /
`.agents/skills/ai-loop-cycle/SKILL.md` / issue #870・#871。

| # | 種別 | 内容 | 該当箇所 |
|---|------|------|---------|
| D-1 | 責務矛盾 | 00_concept §1「PlanGate と並立する**独立 PoC**」vs EPIC #870/#871 の恒久定義「ai-loop は ai-dev を内包し共通利用」。独立 PoC は rollout 段階の記述であり恒久アーキと混在 | 00_concept.md L69 / #870 統合定義 |
| D-2 | 層の混在 | 00_concept 冒頭「Phase 1: 導入先適用」節（rollout policy）が §1〜3 の恒久定義と同一文書・同一階層に同居（issue #871 の背景そのもの） | 00_concept.md L8-64 |
| D-3 | 責務欠落 | core-contract §1-bis「PlanGate ワークフローの責務は PR 作成と C-4 承認まで」— ai-loop 実行プロファイル時の AI 責務終点（merge-ready）への言及なし | core-contract.md §1-bis |
| D-4 | C-3 固定表現 | core-contract §3「approve-wait = C-3 ゲート判断が c3.json に APPROVED」/ Iron Law #1・#7 は Human C-3 前提の表現のみで、C-3' 経路（eligible run の標準自動経路）が実行契約に現れない | core-contract.md §3/§4 |
| D-5 | 状態語彙の同列扱い | adaptive-production-loop §4 Stop contract が「AUTO_APPROVED / HUMAN_ESCALATED / BLOCKED / merge-ready / round limit exceeded」を同列の terminal state として列挙（裁定状態と Delivery 状態の区別＝AC-6 の対象） | adaptive-production-loop.md §4 |
| D-6 | 区別正本の分散 | 裁定状態と DoD 状態の区別は six-stage §2.1 が「design-philosophy.md §5 語彙集で明示済み」と外部委譲 — 区別の正本が 00_concept でなく design-philosophy 側にある | agentic-six-stage-loop.md §2 Gate 行 |
| D-7 | 表記揺れ | `MERGE_READY`（#870/six-stage）と `merge-ready`（00_concept §3.3 / adaptive §5）の 2 表記が同一概念に混在（6 ファイルで実測） | rg 実測（付録 B） |
| D-8 | 適用制限の重複定義 | 「適用ドメイン（Phase 1）」注記が ai-loop 全 12 docs + command + SKILL に反復埋め込み（rollout policy 分離後は正本参照 1 行へ削減すべき重複） | docs/workflows/ai-loop/*.md 冒頭 |
| D-9 | 経路二重定義 | 00_concept §3.5「C-3 Autonomous APPROVE（#353）/ 条件付き降格（F5-AD）の完全機械化」と working-context の同名機構（Human 側正本）— C-3 系の経路が working-context / 00_concept の 2 箇所で定義され、「通常経路 = どちらか」が文書間で未固定（AC-4 対象） | 00_concept.md §3.5 / working-context.md |
| D-10 | Phase 番号衝突 | 00_concept 注記どおり deploy Phase 0/1 と構築 Phase 2/3 の番号系が同居（既知・注記済みだが rollout-policy 分離時に解消余地） | 00_concept.md L62-63 |
| D-11 | command の PoC 表現 | `.claude/commands/ai-loop-workflow.md`「低リスク帯限定・PoC。本番承認フローには適用しない」— 恒久定義（対をなす入口）と Phase 1 制約が同一文に混在 | command L5 |
| D-12 | Evolution Loop 未定義 | ai-loop Evolution（外側 Loop・改善 PR の MERGE_READY）は EPIC #870 と #869 にのみあり、現行 ai-loop docs の責務表（00_concept §2）に列がない（AC-1/AC-7 gap） | 00_concept.md §2 |

## 付録 B: 用語監査コマンド例（Verification 対応）

> 走査範囲は C-2 R-007/R-008 反映で `.claude/skills/` と `docs/ai/ai-loop/` を含む。

```sh
# 独立 PoC 表現の残数（正本確定後は rollout-policy 参照へ置換されているべき）
rg -n "独立 PoC|独立PoC|隔離 PoC" docs/workflows/ai-loop/ docs/ai/ai-loop/ .claude/commands/ .agents/skills/ai-loop-cycle/ .claude/skills/ai-loop-cycle/

# terminal state 表記揺れ（MERGE_READY / merge-ready の使い分けが正本定義どおりか）
rg -n "MERGE_READY|merge-ready" docs/workflows/ai-loop/ docs/ai/ai-loop/ docs/ai/core-contract.md .claude/commands/ai-loop-workflow.md .agents/skills/ai-loop-cycle/SKILL.md .claude/skills/ai-loop-cycle/SKILL.md .claude/skills/pr-watch/SKILL.md

# 裁定状態と Delivery 状態の同列列挙が残っていないか
rg -n "AUTO_APPROVED.*(merge-ready|MERGE_READY)|（merge-ready.*AUTO_APPROVED" docs/workflows/ai-loop/ docs/ai/ai-loop/

# C-3' 経路の定義箇所（正本 1 箇所 + 参照のみになっているか）
rg -c "C-3'" docs/workflows/ai-loop/*.md docs/ai/ai-loop/*.md .claude/commands/ai-loop-workflow.md docs/ai/core-contract.md

# Phase 1 適用ドメイン注記の重複（正本参照 1 行化の進捗）
rg -c "適用ドメイン（Phase 1）" docs/workflows/ai-loop/ docs/ai/ai-loop/ .agents/skills/ai-loop-cycle/ .claude/skills/ai-loop-cycle/

# 5 責務語彙の定義箇所（PlanGate Core / ai-dev / ai-loop Delivery / Evolution / Human）
rg -n "ai-loop Delivery|ai-loop Evolution" docs/
```
