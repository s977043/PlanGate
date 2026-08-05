---
task_id: TASK-0970
artifact_type: review-self
schema_version: 1
status: final
verdict: PASS
created_by: independent-reviewer
---

# TASK-0970 セルフレビュー結果（C-1）

> レビュー日: 2026-08-05
> レビュアー: plan 非作成者（独立レビュアー）
> レビュー対象: `plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md`（branch `docs/970-plan` = `0d19440`）
> 基点: `origin/main` = `a952872`
> Mode: `standard`（フル評価。簡易版は用いない）
> C-1 項目数: **25**（`grep -c '^### C1-' docs/working/templates/review-self.md` の実測値）
> 判定: **PASS** — critical=0, major=0, minor=3
>
> **【初回マーカーは STALE・無効】** 初回レビュー時の受理マーカーは
> `plan=sha256:bcc5daeb…70508` を指していたが、C-2 指摘（R-001〜R-004）の 1 回確定反映により
> `plan.md` が変更され `plan_hash` が更新されたため **無効**である。受理器が誤って拾わないよう
> マーカー行そのものは削除した。**有効なマーカーは §簡易 C-1 再実行（C-2 反映後・head `f8c4217`）に 1 本だけ存在する**。

## サマリー

| result | 件数 |
|--------|------|
| PASS | 20 |
| WARN | 3 |
| FAIL | 0 |
| N/A | 2 |

WARN 3 件はいずれも severity **minor**（[`review-principles.md`](../../../.claude/rules/review-principles.md) §3）。
critical / major はゼロであり、同 §4 の Auto-approve 条件を満たす。
したがって総合判定は **PASS**、ai-loop の `gates.c1` へ渡す値は **`PASS`** とする。

WARN は plan を修正させる性質のものではなく（承認後の plan 編集は `plan_hash` を無効化する）、
**C-2 レビュー／C-3' 実行者への申し送り事項**として §実質論点の検証 に記録する。

## 実質論点の検証（独立実測）

> 本節は C-1 定型 25 項目の外側で、依頼された 7 論点を実コード・実行で裏取りした記録。
> 各項目の PASS/WARN 判定の根拠として下位の C1-XX 項目から参照する。

### 論点 1: lite 4 軸の妥当性（AC-8 安全側の遵守）

[`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md) §2 の 4 軸に照らす。

| 軸 | plan 申告 | 独立検証 | 判定 |
|----|----------|---------|------|
| `size_ok` | true | 実装差分は 2 ファイル（`scripts/sync-plugin-plangate.sh` の 1 行削除 + `tests/extras/ta-26-plugin-sync.sh` の TC 追加）で、その限りでは `SIZE_OK_MAX_FILES`=2 以内。**ただし arbiter へ渡す `changed_files` の組み方に依存する（下記 W-1）** | **WARN** |
| `no_new_design` | true | `scripts/sync-plugin-plangate.sh` L189-226 の guard 構造は #914 で導入済み。本 PBI は L206 の 1 行削除のみで関数・変数・制御フローの新設ゼロ。妥当 | PASS |
| `follows_pattern` | true | 既存 TC-26〜TC-34 は `_t26_mk_refs_guard_sandbox`（`tests/extras/ta-26-plugin-sync.sh` L527-556）+ `mktemp -d` + `register_cleanup` の同型。TC-35 も同型を宣言し、ヘルパーのシグネチャ非変更を制約化している。妥当 | PASS |
| `reversible` | true | 1 行削除 + TC 1 本追加。`git revert` 一発で復元可能。lite-criteria §2 の不可逆操作例（外部公開 / データ削除 / 課金 / 破壊的マイグレーション）を一切含まない。妥当 | PASS |

**判定不能な軸を true に倒してはいない**（AC-8 安全側は形式上守られている）。
ただし `size_ok` については以下の WARN がある。

#### W-1（minor / `size_ok` 申告と `changed_files` の接続前提が未確定）

- `.claude/skills/ai-loop-cycle/SKILL.md` L39-42 は `changed_files` の決定を
  「**計画時（exec 前の C-3' 裁定）: plan の Files to Touch を使う**／再裁定時:
  `git diff --name-only <base>...HEAD` の実差分を使う」と規定している。
- 本 plan の `## Files / Components to Touch` から `extract_allowed_paths()` が抽出する値を
  独立に実行した結果は **3 要素**:
  `['scripts/sync-plugin-plangate.sh', 'tests/extras/ta-26-plugin-sync.sh', 'docs/working/TASK-0970/**']`
- `scripts/ai-loop/arbiter.py` L438-443 `machine_size_check()` は `len(changed_files) <= 2`
  の単純比較であり、`docs/working/**` 等を除外する実装は存在しない
  （`grep -n "docs/working" scripts/ai-loop/arbiter.py scripts/ai-loop/collector.py` = arbiter 側 0 件）。
- したがって SKILL.md の既定どおり Files to Touch をそのまま渡すと実数 3 となり、
  申告 `size_ok=true` は priority 1.9（`arbiter.py` L985-990）で `HUMAN_ESCALATED` に倒れる。
  plan L97-99 は「#3 は `changed_files` の実装差分計上からは除く」と自己宣言しているが、
  この上書きを許す規定は lite-criteria / SKILL.md / arbiter のいずれにも存在しない。
- 再裁定時（実装後・PR 前）は `git diff --name-only origin/main...HEAD` に
  `docs/working/TASK-0970/` 配下の plan / todo / test-cases / pbi-input / review-self /
  review-external / status / handoff が必ず含まれるため、実数は確実に 2 を超える。

**安全性への影響**: 不一致は必ず **escalate 方向（fail-closed）** に働き、fail-open は生じない。
このため major ではなく minor と判定する。

**是正案（plan は修正しない。C-3' 実行者向けの申し送り）**:

1. C-3' 入力を組む際、`changed_files` を実装 2 パスに限定するなら、
   その根拠（plan L97-99 の自己宣言を採用する旨）を run 記録に明記する。
2. 根拠を提示できない／解釈が割れる場合は **AC-8 安全側に従い `size_ok=false` を申告**し、
   priority 1.9 ではなく priority 2 の lite 判定で escalate を受容する。
3. どちらの経路でも安全側に倒れるため、plan 差し戻しは不要。

### 論点 2: `extract_allowed_paths()` の抽出結果に禁止領域の混入がないか

独立実行（`scripts/ai-loop/plan_package.py` を import して `extract_allowed_paths(plan.md)` を評価）:

```text
PATH_RE: `([^`\s]+/[^`\s]+)`
allowed: ['scripts/sync-plugin-plangate.sh', 'tests/extras/ta-26-plugin-sync.sh', 'docs/working/TASK-0970/**']
```

- `docs/ai/ai-loop/ho-paths.md` の HO 表は **21 行**（backtick 開始のテーブル行を grep で計数した実測値）。
  上記 3 パスはいずれのパターンにも一致しない（`scripts/hooks/**` ではなく `scripts/` 直下、
  `tests/**` は HO 表に不在、`docs/ai/*.md` はトップレベル md のみ）。
- plan L101-112 の「変更しない領域」は backtick を付けずに列挙されており、
  `_PATH_RE` が誤って拾わない書き方になっている（実測で混入 0 を確認）。
- **混入 0 件。オーガナイザー実測と一致。PASS**。
- info: `docs/working/TASK-0970/**` は HO パターン `**/approvals/*.json` を包含しうる
  （`docs/working/TASK-0970/approvals/c3.json`）。`boundary_check()` は `changed_files` 基準のため
  宣言のみでは境界侵害にならないが、exec 中に当該ディレクトリへ approval token を作らないこと。

### 論点 3: `Verification Automation:` 行の書式適合

- 要求書式（`scripts/ai-loop/plan_package.py` L216-218）:
  `re.search(r"Verification Automation:\s*`([^`]+)`", plan_text)`
- plan L128: `- Verification Automation: \`sh tests/extras/ta-26-plugin-sync.sh && sh tests/run-tests.sh\``
  → 合致する。`&&` 分割で `deterministic` 2 件（各 `expect_exit: 0`）が派生する。
- `derive_loopspec()` を実際に実行したところ、失敗理由は
  `presence: review-self.md が存在しない` / `presence: review-external.md が存在しない` の 2 件のみで、
  **`Verification Automation` / `Goal` / `Files to Touch` 由来のエラーは 0 件**。
  本ファイル（review-self.md）と C-2 の review-external.md が揃えば派生可能。**PASS**（fail-closed 化しない）。

### 論点 4: rollout-policy §2 carve-out 非該当の確認記録

- 正本（`docs/workflows/ai-loop/rollout-policy.md` §2 判定基盤 carve-out）の 3 系統:
  ① `scripts/ai-loop/**` ② `docs/workflows/ai-loop/**`・`docs/ai/ai-loop/**`
  ③ `.agents/skills/ai-loop-cycle/**`・`.claude/skills/ai-loop-cycle/**`
- plan L235-246 に 3 系統すべての突合表があり、実装対象（`scripts/` 直下 / `tests/extras/`）が
  いずれにも該当しないことを記録している。正本の記述と一致。**PASS**。
- plan は配布派生（`plugin/plangate/**`）を Non-goals（L111）へ明示的に置いており、
  carve-out の「正本のみ触る」原則とも整合する。

### 論点 5: AC-2 変異注入の検出力（論理検証）

前提として実コードを実測確認した:

| 事実 | 実測箇所 |
|------|---------|
| コピーループの `-L` 除外 | `scripts/sync-plugin-plangate.sh` L179 |
| src 側 base 集計の `-L` 除外 | 同 L200 |
| dst 側 stale 集計の `-L` 除外（削除対象） | 同 L206 |
| guard 呼び出し | 同 L215 |
| 削除ループ（`-L` 除外なし・`[ -f ]` のみ） | 同 L216-224 |
| guard 発火条件 `stale > base` と WARN 書式 `base=$2 / stale=$3` | 同 L56-67 |
| guard 発火時の終端 `exit 3` | 同 L589-597 |
| ヘルパー引数（`<dir> <src_n> <stale_n> <skill> [mirror\|empty]`）と mirror 既定 | `tests/extras/ta-26-plugin-sync.sh` L527-556 |

- **M-1（必須）**: L206 の `[ -L "$_rf" ] && continue` を復元＝修正前実装。
  TC-35 fixture（src 通常 3 / dst = mirror 3 + 通常 stale 3 + 解決可能 symlink 2 = 8 件）では
  `base=3` / `stale=3` となり `3 > 3` が偽 → guard 非発火 → 削除ループは `-L` 除外を持たず
  `[ -f ]` が真の symlink も削除 → **5 件削除・rc=0**。TC-35 の期待 ①`rc=3` ②`base=3 / stale=5`
  ③`DELETE skipped for ...` ④残存 8 件がすべて崩れる。**期待 FAIL は成立する（空振りでない）**。
- **M-2（任意）**: stale 集計ループから `[ -f "$_rf" ] || continue` を削除すると、
  ダングリング `dangling-1.md` が集計へ入り `stale=6` となり、副次検査の文字列一致
  （`base=3 / stale=5` 不変）が崩れる。**成立**。
- **`-e` 緩和が空振りという記録**: POSIX の `-e` / `-f` はいずれも symlink を解決してから判定するため、
  ダングリング symlink では両方 false。plan / test-cases が「M-2 を存在判定の削除に差し替えた」
  実測記録（test-cases L81-85）は仕様と整合する。**空振り変異を乖離帯に入れずに差し替えた点は適切**。
- **M-X（非検出の明示）**: 削除ループへ `-L` を追加する誤修正は guard 発火帯 fixture では検出できない旨を
  test-cases L91 に明記し、代替担保（Constraints での固定 + AC-1 差分レビュー）と V2 候補化を記録済み。
  既知の限界を隠していない。**PASS**。
- 期待値の書式は実コードの WARN 文言（L61/L64）と逐語一致しており、文字列一致検査が空振りしない。

### 論点 6: AC-1 の削除ループ側担保が手動レビュー依存である旨の明示

- plan L175（AC 表 AC-1）に **太字**で「削除ループ側の条件式は guard 発火帯の fixture では
  結果に現れないため、この部分のみ手動レビュー依存であることを明示する（非発火帯の対称性 TC は V2 候補）」と記載。
- test-cases L52（担保しない範囲）/ L91（M-X）/ L108（E-2）にも重複して記録。
- **PASS**（minor の自己申告として適切に表面化している）。

### 論点 7: issue の AC 4 件の TC マップ

`gh issue view 970` の Acceptance Criteria 4 件と plan / test-cases を逐語照合:

| issue AC | plan 受入基準 | TC |
|----------|--------------|----|
| AC-1 集計集合と削除集合の厳密一致 | 同文（plan L175） | TC-35 + 差分レビュー |
| AC-2 symlink stale fixture の TC 追加・修正前実装で FAIL | 同文（L176） | TC-35 + M-1 |
| AC-3 既存 ta-26 全 TC が PASS 維持 | 同文（L177） | TC-R |
| AC-4 `sh tests/run-tests.sh` が baseline 維持 | 同文（L178） | TC-B |

- 既存 TC 数の実測（`grep -c 't26_pass "TC-' tests/extras/ta-26-plugin-sync.sh`）= **30**。plan の申告と一致。
- **漏れなくマップ済み。PASS**。
- info: AC-3/AC-4 の期待値「31 PASS / 538 passed」は TC-35 が `t26_pass` 行 1 本であることを前提にしている。
  副次検査を別 pass 行として実装すると 32 / 539 にずれる。Replan Trigger **RT-4**（総テスト数が
  baseline+1 と一致しない）が検出するため致命ではない。

### Mode 判定の妥当性（依頼事項）

[`mode-classification.md`](../../../.claude/rules/mode-classification.md) の判定ロジック
「定量の各軸で最大 → 定性の各軸で最大 → 高い方」を独立に再計算した:

| 区分 | 軸 | 値 | 帯 |
|------|----|----|----|
| 定量 | 変更ファイル数 | 2 | light（1-2） |
| 定量 | 受入基準数 | 4 | **standard**（3-5） |
| 定量 | タスク数 | 10（A-1〜A-10） | **standard**（5-10） |
| 定性 | 変更種別 | バグ修正 | light |
| 定性 | リスク | 低（fail-closed 方向のみ） | light |
| 定性 | 影響範囲 | 当該 guard に閉じる | light |
| 定性 | ロールバック | 容易（`git revert`） | light |

定量最大 = standard / 定性最大 = light → 高い方 = **standard**。plan の判定と一致し、**妥当**。
例外ルール（セキュリティ / DB スキーマ / 公開 API 破壊 / 承認境界周辺 9 カテゴリ）はいずれも非該当
（HO 表 21 行との突合で確認）。`lite=true` と `standard` の両立も規定どおり
（`lite_eligible=false` の強制は HO 接触と `critical` のみ）。

## Plan チェック（7項目 + AEE 2項目 / #544 Phase1）

### C1-PLAN-01: 受入基準網羅性

- **result**: PASS
- **category**: plan
- **finding**: issue #970 の AC 4 件が plan 受入基準（L173-178）へ逐語で写され、todo の A-5/A-6/A-7/A-8/A-9 と test-cases の TC-35 / M-1 / TC-R / TC-B へ全件マップされている。網羅漏れなし。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-02: Unknowns処理

- **result**: PASS
- **category**: plan
- **finding**: `## Questions / Unknowns` の 3 件はいずれも「C-3' で確認したい論点」であり、plan 本文（論点 A の比較表 L54-74 / 論点 B L76-81 / Non-goals L44-46）に解決方針と根拠が明記されている。pbi-input の Unknowns は「なし」と明示。未解決の空欄はない。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御

- **result**: WARN
- **category**: plan
- **finding**: Non-goals 4 件と「変更しない領域」8 件が明示され、スコープクリープの兆候はない。ただし W-1 のとおり、`changed_files` から `docs/working/TASK-0970/**` を除外して数えるという plan 独自の計上規約（L97-99）が lite-criteria / ai-loop-cycle SKILL / arbiter のいずれにも裏付けを持たない。スコープ宣言と機械検証の接続が未確定。
- **evidence_ref**: 本ファイル §実質論点 1（W-1）に独立実測を記録
- **impacted_files**: [`docs/working/TASK-0970/plan.md`]
- **suggested_action**: plan は修正せず（承認後の編集は `plan_hash` を無効化する）、C-3' 入力作成時に `changed_files` を実装 2 パスに限定する根拠を run 記録へ明記する。提示できない場合は AC-8 安全側に従い `size_ok=false` を申告して escalate を受容する。
- **owner**: agent（C-3' 実行者）
- **resolved**: false

### C1-PLAN-04: テスト戦略

- **result**: PASS
- **category**: plan
- **finding**: Unit（該当なしの理由付き）/ Integration（TC-35 + 既存 TC-26〜34 の非退行）/ E2E（`tests/run-tests.sh` baseline）/ Edge cases 3 件 / 変異注入（AC-2 必須）/ Verification Automation まで具体化されている。clean env と `</dev/null` の実行条件も明記（L130-131）。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-05: Work Breakdown Output

- **result**: WARN
- **category**: plan
- **finding**: plan.md に `## Work Breakdown` 節が存在しない（節一覧を実測。Goal / Constraints / Approach Overview / Files to Touch / Testing Strategy / Risks / Questions / Loop Scope / Stop / Resume / Replan / 受入基準 / Mode 判定 / ai-loop run との関係）。[`working-context.md`](../../../.claude/rules/working-context.md) の plan.md 構成要件（各 Step に Output / Owner / Risk / 🚩チェックポイント）は todo.md の A-1〜A-10 が実質的に満たしている（Output / depends_on / 🚩 / rollback を各タスクに記載）が、plan.md 単体では Step ごとの Output を追えない。
- **evidence_ref**: —
- **impacted_files**: [`docs/working/TASK-0970/plan.md`]
- **suggested_action**: 機械要件（`plan_package.py` が必須とするのは Goal / Files to Touch / Verification Automation の 3 節のみ）には抵触しないため、本 run では todo.md を Work Breakdown の正本として扱う旨を C-3' 記録へ 1 行残す。次回以降の plan では `## Work Breakdown` 節を置く。
- **owner**: agent
- **resolved**: false

### C1-PLAN-06: 依存関係

- **result**: PASS
- **category**: plan
- **finding**: todo の A-2〜A-10 に `depends_on` が設定され、`## ⚠️ 依存関係` 節で「A-5 は A-4（C-3' 承認）完了まで着手不可」「A-7 は A-6 完了後に意味を持つ」「H-1 は Human-owned 固定」が補強されている。循環・逆順なし。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-07: 動作検証自動化

- **result**: PASS
- **category**: plan
- **finding**: plan L128 に `Verification Automation:` 行があり、コード span 内は `sh tests/extras/ta-26-plugin-sync.sh && sh tests/run-tests.sh`。`plan_package.py` L216-218 の正規表現に合致することを実行で確認（§実質論点 3）。`derive_loopspec()` は本ファイル + review-external.md の presence が揃えば派生可能。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-08-AEE: Stop Condition 記入（#544 Phase1）

- **result**: PASS
- **category**: plan
- **finding**: `## Stop Condition`（L153-155）に「Files to Touch 内 / Verification Automation exit 0 / AC-1〜4 全 PASS / 残課題は handoff」の 4 条件が記入済み。`## Resume Condition` も併記されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-09-AEE: Replan Triggers 機械値（#544 Phase1）

- **result**: PASS
- **category**: plan
- **finding**: RT-1（実装差分 > 2 ファイル）/ RT-3（同一原因の failed > 0 が 3 回連続）/ RT-4（総テスト数が baseline+1 と不一致）が数値閾値を持つ機械値。RT-2 / RT-5 は条件式として判定可能。1 つ以上の要件を充足。
- **evidence_ref**: —
- **impacted_files**: []

## Plan 品質追加チェック（Superpowers 由来 / #581）

### C1-SUP-PLAN-01: No Placeholders Rule

- **result**: PASS
- **category**: plan
- **finding**: 4 ファイルに対し `TBD|TODO|後で実装|必要に応じて|適切に|いい感じに|Task N と同様` を grep した結果、ヒットは `todo.md:1` の見出し文字列 `EXECUTION TODO` のみ（プレースホルダではない）。ファイルパス・コマンド・期待結果はすべて具体値（`L206` / `base=3 / stale=5` / `rc=3` / `31 PASS` / `538 passed`）で与えられている。
- **evidence_ref**: —
- **impacted_files**: []
- **failure_policy**: standard のため重大な曖昧表現は FAIL 相当だが、該当なし。

### C1-SUP-PLAN-02: Task Sizing Rules

- **result**: PASS
- **category**: plan
- **finding**: A-1〜A-10 は各々が独立に approve/reject 可能な単位。変更対象ファイル（A-5: sync スクリプト / A-6: ta-26）、検証コマンド（`sh -n` / `--dry-run` / 変異注入 / Verification Automation）、期待結果（syntax OK / guard 非発火 / FAIL 実測 / exit 0）、依存関係が各タスクに具体化されている。
- **evidence_ref**: —
- **impacted_files**: []
- **failure_policy**: high-risk/critical ではないため FAIL 適用外。該当する不備もなし。

## ToDo チェック（6項目）

### C1-TODO-08: タスク粒度

- **result**: PASS
- **category**: todo
- **finding**: 10 タスク。実装系（A-5 の 1 行削除 / A-6 の TC 1 本追加）は数分粒度。A-2/A-3/A-4（C-1 / C-2 / C-3'）は 2〜5 分を超えるがゲート単位として分割不能であり、ai-loop の 1 サイクル構造（`execution-runbook.md` §2）に対応する正当な単位。責務混在なし。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-09: depends_on設定

- **result**: PASS
- **category**: todo
- **finding**: A-1 を除く全タスクに `depends_on` が明示され、H-1 は `depends_on: A-8`。`## ⚠️ 依存関係` 節が Plan-first 束縛（A-5 は A-4 承認後）を再掲している。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-10: チェックポイント設定

- **result**: WARN
- **category**: todo
- **finding**: A-2/A-3/A-4/A-5/A-6/A-7/A-8 と H-1 に 🚩 checkpoint がある。一方 A-10（`handoff.md` 発行 → PR 作成）に checkpoint がなく、[`execution-runbook.md`](../../workflows/ai-loop/execution-runbook.md) §2-(6) が **PR 作成前に必須**と定める強化セルフレビュー（宣言↔実差分の突合 / diff-audit / plan-review-readiness-gate / review-feedback-loop / 実践主張の出典検証）が todo 上に現れていない。runbook 側の規定で手順としては担保されるが、todo だけを見て実行すると飛ばしうる。
- **evidence_ref**: —
- **impacted_files**: [`docs/working/TASK-0970/todo.md`]
- **suggested_action**: todo は修正せず、C-3' 実行者が A-10 の直前に runbook §2-(6) の 5 観点を実施し、結果を status.md へ記録する。
- **owner**: agent
- **resolved**: false

### C1-TODO-11: Iron Law遵守

- **result**: PASS
- **category**: todo
- **finding**: 実装タスク A-5 は「A-4（C-3' 承認）完了まで着手不可（Plan-first 束縛）」と明記され、承認前コード実行の経路がない。H-1（merge）は Human-owned 固定・`NO MERGE BY AI` を明示。スコープ逸脱は「Files to Touch の範囲内に限定、逸脱時は停止」（L84）+ RT-5（HO 該当時は即停止）で二重に塞がれている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-12: 完了条件

- **result**: PASS
- **category**: todo
- **finding**: 各タスクに Output または 🚩 checkpoint の形で完了条件が記述されている（A-1: baseline 件数の記録 / A-5: 1 行削除差分 + syntax OK / A-8: exit 0 かつ baseline+1 / A-9: AC-1〜4 の突合）。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-RB: rollback（戻し手順）

- **result**: PASS
- **category**: todo
- **finding**: Mode = standard のため必須ではないが、A-1〜A-10 の **全 10 タスク**に `rollback:` が記載されている（読取のみのタスクは「不要」と明示）。実装タスクは `git checkout -- <file>` で具体化。
- **evidence_ref**: —
- **impacted_files**: []

## テストケースチェック（3項目）

### C1-TEST-13: 受入基準→テストケース網羅性

- **result**: PASS
- **category**: test
- **finding**: test-cases L18-25 の AC→TC マッピング表で AC-1〜4 の 4/4 が TC-35 / TC-35+M-1 / TC-R / TC-B に紐づく。issue 側 AC との逐語一致も確認済み（§実質論点 7）。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-14: テストケースの具体性

- **result**: PASS
- **category**: test
- **finding**: 「正しく動作する」式の抽象記述がなく、すべて値レベル。期待は `rc = 3` / 出力に `base=3 / stale=5` / `DELETE skipped for skills/skill-A/references` / dst 残存 8 件（副次検査は 9 件）/ TC-R = 31 PASS 0 FAIL / TC-B = 538 passed。期待文字列は実コードの WARN 書式（`scripts/sync-plugin-plangate.sh` L61/L64）と逐語一致することを独立に確認した。fixture 件数（mirror 3 + stale 3 + symlink 2 = 8）もヘルパー仕様（`tests/extras/ta-26-plugin-sync.sh` L527-556）と整合する。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-15: エッジケースの考慮

- **result**: PASS
- **category**: test
- **finding**: E-1〜E-5（解決可能 symlink / ダングリング symlink / dst symlink の basename が src に存在 / src 側 symlink / symlink 0 件の通常構成）を担保手段付きで列挙。加えて「検出できない変異（M-X）」を独立の表として明示し、代替担保と V2 候補化まで記録している。既知の限界を隠さない点を高く評価する。
- **evidence_ref**: —
- **impacted_files**: []

## B-1/B-2チェック（2項目）

### C1-B1B2-16: B-1確認質問

- **result**: PASS
- **category**: plan
- **finding**: plan 冒頭の `## 前提の実測（B-1 / 裏取り済み）`（L7-21）で行番号・TC 数・baseline・該当 symlink 件数を実測により確定させ、曖昧さを解消している。独立検証でも L179/L200/L206/L215/L216-224 と TC 数 30 が実測どおりであることを確認した。pbi-input の Unknowns は「なし」と明示。
- **evidence_ref**: —
- **impacted_files**: []

### C1-B1B2-17: B-2アプローチ比較

- **result**: PASS
- **category**: plan
- **finding**: 論点 A で A-1（集計側から `-L` を外す）と A-2（削除ループへ `-L` を追加）を表で比較し、採用理由 3 点・不採用理由 3 点を記録。src 側 `-L`（L200）を維持する判断も理由付きで併記されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SEC-01: 秘密情報 非接触（#578）

- **result**: N/A
- **category**: plan
- **finding**: 変更対象は plugin 同期スクリプトと POSIX sh のテストのみ。`.env` / APIキー / トークン / 個人パス / ローカル設定に触れる設計を含まない。fixture はすべて `mktemp -d` の sandbox 内で生成される。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離（#578）

- **result**: PASS
- **category**: plan
- **finding**: Non-goals に #921（exit code 伝播）・経路2 / `sync_dir`・src 側 `-L`・guard 閾値の見直しを分離。pbi-input Out of scope に `tests/extras/README.md` のドリフトを「別 issue 候補」として分離。test-cases では非発火帯の対称性 TC を V2 候補へ回している。RT-5 で HO 接触時の即停止も規定。
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠（#579・is_ui_task 時のみ）

- **result**: N/A
- **category**: plan
- **finding**: `is_ui_task = false`（POSIX sh スクリプトとシェルテストのみ。UI 成果物なし）。
- **evidence_ref**: —
- **impacted_files**: []

## ai-loop への引き渡し

| 項目 | 値 |
|------|----|
| `gates.c1` | **`PASS`** |
| C-1 項目数（テンプレート実測） | 25 |
| critical / major / minor | 0 / 0 / 3 |
| 受理マーカー（初回・**現在は STALE / 削除済み**） | `plan=sha256:bcc5daeb…70508` を指していた。有効なマーカーは §簡易 C-1 再実行 を参照 |
| plan_hash 照合 | 本レビュー時点の `plan.md` sha256 と一致（plan を変更していないため stale 化しない） |

`plan_package.check_evidence()` は C-1 の受理値を `("PASS",)` のみに限定しており
（`scripts/ai-loop/plan_package.py` L112）、マーカー行は行頭アンカー + 完全文法で
ちょうど 1 回であることが要求される。本ファイルはこれを満たす。

**次工程への申し送り（C-2 / C-3' 実行者向け・優先度順）**:

1. **W-1**: C-3' 入力の `changed_files` をどう組むかを先に確定する。実装 2 パスに限定する根拠を
   run 記録に残せないなら `size_ok=false` を申告する（AC-8 安全側）。いずれの経路でも安全側に倒れる。
2. **C1-TODO-10 WARN**: PR 作成前に `execution-runbook.md` §2-(6) の強化セルフレビュー 5 観点を実施する。
3. **C1-PLAN-05 WARN**: 本 run では todo.md を Work Breakdown の正本として扱う旨を記録する。
4. **info**: AC-3/AC-4 の期待値（31 PASS / 538 passed）は TC-35 が `t26_pass` 行 1 本である前提。
   副次検査を別行にすると RT-4 が発火する。

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| — | 自動修正なし（本 C-1 は独立レビューであり、plan / todo / test-cases / pbi-input を一切変更していない） | — |

---

## 簡易 C-1 再実行（C-2 反映後・head `f8c4217`）

> 再実行日: 2026-08-05
> レビュアー: 初回と同一の独立レビュアー（plan 非作成者）
> 対象: `origin/docs/970-plan` head `f8c4217`（初回 `3f1196c` + C-2 反映コミット）
> 実測基点: `origin/main` = `4448420`（`git rev-parse origin/main` で実測）
> 契機: C-2（`review-external.md`）が critical 0 / major 1（R-001）で `request-changes` となり、
> R-001〜R-004 を 1 回確定反映 → `plan_hash` 変化 → 初回マーカーが stale 化したため
> 範囲: [`working-context.md`](../../../.claude/rules/working-context.md)「C-2 指摘の差分管理」(3) の
> **簡易 C-1**。全 25 項目の再実行ではなく、反映の影響を受ける項目に限定する

C1-VERDICT: PASS plan=sha256:a32d837fbd4208bce7c556e27f22f0cb6ea3ab3a88c9d28a7b8d25a3f259b1a1

### 再実行サマリー

| 再評価項目 | 初回 | 今回 | 判定 |
|-----------|------|------|------|
| 1. `size_ok` の WARN 解消（旧 C1-PLAN-03） | WARN | **PASS** | **解消** |
| 2. R-002 / R-003 の反映妥当性 | — | **PASS** | 新規 |
| 3. 反映の副作用（AC / TC / lite / scope） | — | **PASS** | 新規 |
| 4-a. C1-PLAN-05（Work Breakdown 節の不在） | WARN | WARN | 継続 |
| 4-b. C1-TODO-10（A-10 の強化セルフレビュー checkpoint） | WARN | WARN | 継続 |
| 5. `Verification Automation:` 行の書式 | PASS | **PASS** | 維持 |

**更新後の総合判定**: **PASS** — critical=0, major=0, **minor=2**（初回 3 → 1 件解消）。
`gates.c1` へ渡す値は **`PASS`**。

### 1. `size_ok` の WARN 解消（初回 WARN の主対象）

`plan_package.extract_allowed_paths()` と `arbiter` の各判定を**自分で再実行**した:

```text
allowed_paths / changed_files: ['scripts/sync-plugin-plangate.sh',
                                'tests/extras/ta-26-plugin-sync.sh']  len=2
SIZE_OK_MAX_FILES = 2
machine_size_check = True
check_allowed_paths = (True, [])
boundary_check       = ('clean', [])
```

- Files to Touch の 3 行目（`docs/working/TASK-0970/**`）が削除され、**機械抽出は 2 件**になった。
- したがって `.claude/skills/ai-loop-cycle/SKILL.md` の規定どおり「計画時 = plan の Files to Touch」を
  そのまま `changed_files` に渡しても `machine_size_check = True`。申告 `size_ok=true` と実数が
  **正本の手順どおりに一致**する（plan 側の自作 carve-out に依存しない）。
- 初回 WARN の本質（「申告者自身がフィルタした集合を機械ガードへ渡す」構造）が構造的に除去された。
  plan L216 の lite 表の根拠も「Files to Touch から機械抽出される `changed_files` は 2 件」という
  検証可能な記述に置き換わっている。
- 残る 3 軸（`no_new_design` / `follows_pattern` / `reversible`）は初回 PASS のまま。`no_new_design` の
  根拠に「直上コメント文言の追従」が追記されたが、コメント変更は関数・制御フローの新設ではないため判定は不変。

**判定: PASS（WARN 解消）**。

> info（残存する既知の性質・plan の記述と矛盾しない）: 再裁定時（実装後・PR 前）に
> `git diff --name-only <base>...HEAD` を使う場合は作業コンテキストが差分へ入るため、実数は 2 を超え
> `size_ok=true` 申告は priority 1.9 で escalate する。plan は主張を「計画時の `changed_files`」に
> 明示的に限定しており、この点で不正確な断定はしていない。再裁定を行う場合は `size_ok=false` を申告すること。

### 2. R-002 / R-003 の反映妥当性（独立実測）

**R-002（baseline の記号化 + 基点更新）**:

| 検証 | 実測 | 結果 |
|------|------|------|
| `origin/main` = `4448420` か | `git rev-parse origin/main` = `4448420cb48261aefa9fd274e498f140ab5e4cf7` | 一致 |
| 対象 2 ファイルが `a952872` と `4448420` で同一か | `git diff --stat a952872 4448420 -- <2 ファイル>` = 空 | 同一（plan の行番号実測値は不変） |
| L206 が `-L` 行、L195-196 が該当コメントか（`4448420` 時点） | `git show 4448420:scripts/sync-plugin-plangate.sh` で該当行を直接確認 | 一致 |
| 絶対値の残存 | plan / todo / test-cases / pbi-input に `537` / `538` / `539` の残存 **0 件** | 記号化は徹底されている |
| `a952872` の残存 2 箇所 | plan L6（両 commit で同一である旨の確認記録）/ pbi-input L20（sandbox 実測再現の取得基点） | いずれも「baseline 件数」ではなく履歴参照であり、上記の同一性確認により有効 |

記号化は plan（前提の実測表 / Testing Strategy / AC-4）・test-cases（ヘッダ / TC-B）・pbi-input（AC-4）・
todo（A-1 Output / A-8 checkpoint）の **全箇所で一貫**しており、取り残しはない。

> info（部分記号化の妥当性）: `sh tests/run-tests.sh` の passed 数のみを記号化し、AC-3 / TC-R の
> 「31 PASS」（ta-26 単体）は絶対値のまま残っている。これは**適切**である。R-002 が検出した環境差の原因である
> `TC-17 not a git repo` の SKIP は `tests/extras/ta-13-plangate-setup.sh:159-170` にあり、
> `tests/extras/ta-26-plugin-sync.sh` の TC-17（L346-365「README.md を src/dst 対称に除外」）とは別物で、
> ta-26 は全 TC が sandbox 完結のため環境非依存。既存 30 本も `grep -c 't26_pass "TC-'` で実測確認済み。

**R-003（コメント追従）**: `scripts/sync-plugin-plangate.sh` の L195-196 を `4448420` 時点で直接読み、
review-external の引用（「集計にはコピーループと同一の `[ -L ]` 除外を入れる（R-351 / 論点 D'-2。
集計定義と実削除条件の非対称は『N 件と数えて M 件消す』guard 無効化を招く）」）と**逐語一致**することを確認した。
L206 削除後にこのコメントが実装と正反対になるという指摘は妥当であり、再発ベクタの指摘として正しい。

反映は **3 箇所で整合**している:

| 箇所 | 記述 |
|------|------|
| Constraints（plan L35-37） | 「集計ループ 1 行の削除 + 直上コメント（L195-196）の追従（同一ファイル・同一 hunk）」 |
| Files to Touch #1（plan L95） | 「1 行を削除（L206）+ 直上コメント L195-196 を実装へ追従（同一 hunk / R-003）」 |
| todo A-5 Output | 「同 hunk の L195-196 コメントを『削除ループと同一条件で集計する（`-L` 除外は入れない）』へ書き換える」 |

**判定: PASS**（両指摘とも反映が事実に基づき、記述箇所間で矛盾しない）。

### 3. 反映の副作用（AC / TC / lite / scope が壊れていないか）

| 観点 | 検証 | 結果 |
|------|------|------|
| `check_allowed_paths()` の scope 逸脱 | `changed_files`（2 件）が `allowed_paths`（同 2 件）に完全一致 → `(True, [])` を実行で確認 | 逸脱なし |
| `boundary_check()` | `('clean', [])`。HO 表 21 行のいずれにも一致せず、初回判定から不変 | 不変 |
| AC-1 / AC-2 | 変更なし。コメント追従は削除ループに触れないため AC-1 の「削除ループ無改変」制約と両立する | 破壊なし |
| AC-3（31 PASS） | ta-26 は環境非依存（上記 info）。TC-R の期待値は有効 | 破壊なし |
| AC-4 | 記号化により「A-1 実測値 +1」へ統一。todo A-8 checkpoint も同期して更新済み | 整合 |
| 変異注入 M-1 / M-2 | M-1 は L206 の復元、M-2 は存在判定の削除であり、いずれもコメント文言に依存しない。初回の論理検証（期待 FAIL 成立）はそのまま有効 | 不変 |
| RT-1（実装差分 > 2 で再計画） | コメント追従は同一ファイル同一 hunk のためファイル数は 2 のまま。plan も「RT-1 に影響しない」と明記 | 整合 |
| Mode 判定 | 変更ファイル数 2 / 受入基準 4 / タスク 10 は不変 → `standard` のまま妥当 | 不変 |
| 作業コンテキストの書込み可否 | R-001 の実測（`scripts/ai-loop/check_exec_boundary.py` は実行系トークンの AST 検査であり `allowed_paths` によるファイル書込み制御ではない）を確認。Files to Touch から外しても status / handoff の生成は阻害されない | 副作用なし |

**判定: PASS**（新規の FAIL 要因は生じていない）。

### 4. 初回の残 WARN 2 件の現況

| ID | 現況 | 判定 |
|----|------|------|
| C1-PLAN-05（Work Breakdown 節） | plan の第 2 レベル見出しを再列挙したが `## Work Breakdown` は**依然として不在**（Goal / Constraints / Approach Overview / Files to Touch / 変更しない領域 / Testing Strategy / Risks / Questions / Loop Scope / Stop / Resume / Replan / 受入基準 / Mode 判定 / ai-loop run との関係）。todo.md A-1〜A-10 が実質を満たす点も不変 | **WARN 継続**（機械要件には非抵触。本 run では todo.md を Work Breakdown の正本として扱う旨を C-3' 記録へ残す） |
| C1-TODO-10（A-10 の checkpoint） | todo A-10 は `handoff.md` 発行 → PR 作成のままで 🚩 checkpoint がなく、`execution-runbook.md` §2-(6) の強化セルフレビュー 5 観点は todo 上に現れていない | **WARN 継続**（runbook 側の規定で手順としては担保。C-3' 実行者が A-10 直前に実施し status.md へ記録すること） |

いずれも C-2 の反映対象外（R-006 が todo の規約ずれを info で acknowledged したのみ）であり、
反映によって悪化してもいない。severity は minor のままで総合判定を PASS から動かさない。

### 5. `Verification Automation:` 行の書式（再確認）

`derive_loopspec('docs/working/TASK-0970', 'TASK-0970', maker, checker)` を実行し、**成功**を確認した
（初回は `review-self.md` / `review-external.md` の presence 未充足で失敗していたが、両ファイルが揃ったため通過）:

```text
derive OK
det: [{'cmd': 'sh tests/extras/ta-26-plugin-sync.sh', 'expect_exit': 0},
      {'cmd': 'sh tests/run-tests.sh', 'expect_exit': 0}]
scope: {'allowed_paths': ['scripts/sync-plugin-plangate.sh',
                          'tests/extras/ta-26-plugin-sync.sh']}
```

`plan_package.py` L216-218 の正規表現に合致し、LoopSpec が決定論的に派生する。**PASS**。

### 更新後の ai-loop への引き渡し

| 項目 | 値 |
|------|----|
| `gates.c1` | **`PASS`** |
| 有効な受理マーカー | `plan=sha256:a32d837f…9b1a1`（本節冒頭に **1 本のみ**。初回の stale マーカーは削除済み） |
| マーカー実測 | `plan_package._C1_MARKER_RE` の完全マッチ **1 件** / `_C1_PREFIX_RE` の行数 **1 件**（一致 = fail-closed に落ちない） |
| plan_hash 照合 | 本ファイルのマーカー値が現 `plan.md` の sha256 と一致（`check_evidence` の stale 判定を通過） |
| critical / major / minor | 0 / 0 / **2** |
| 新規に生じた問題 | **なし**（FAIL 該当なし） |

**C-3' 実行者への申し送り（更新版・優先度順）**:

1. **計画時の C-3' 入力**は Files to Touch をそのまま `changed_files`（2 件）として渡してよい。
   実測で `machine_size_check=True` / `check_allowed_paths=(True, [])` / `boundary_check='clean'` を確認済み。
   **実装後の再裁定を行う場合のみ** `size_ok=false` を申告すること（作業コンテキストが差分に入るため）。
2. **C1-TODO-10 WARN**: PR 作成前に `execution-runbook.md` §2-(6) の強化セルフレビュー 5 観点を実施する。
3. **C1-PLAN-05 WARN**: 本 run では todo.md を Work Breakdown の正本として扱う旨を記録する。
4. **info**: AC-3 の「31 PASS」は TC-35 が `t26_pass` 行 1 本である前提。副次検査を別行にすると RT-4 が発火する。
