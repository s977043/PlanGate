---
name: ai-loop-cycle
description: "ai-loop-workflow の 1 サイクル（C-3' 裁定）を実行する。Use when: 「ai-loop で回して」「C-3' 裁定を実行」「arbiter で裁定して」「ai-loop 初回実走」。恒久定義（責務・terminal state・C-3' 経路）の正本 = docs/workflows/ai-loop/00_concept.md、適用制限（Phase 1 rollout eligibility）の正本 = docs/workflows/ai-loop/rollout-policy.md。"
---

# ai-loop-cycle

[`execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) に定義された
1 サイクル（変更対象ファイル取得 → W チェック → `arbiter.py` 裁定 → record 保存 → 分岐後の行動）を
実行するための手順スキル。判定ロジック・provenance スキーマの正本は runbook 側にあり、本スキルは
それらを実行するための **委託プロンプト定型** と **手順の要約** のみを持つ（二重定義しない）。

## 前提

- **C-1 PASS・C-2 完了済み**であること（[`execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) §2 前提）。
  本サイクルは C-3' ゲートの位置づけであり、C-1/C-2 未完了の変更には使わない。
  この C-1 の実施結果（`PASS`）を Step 1 の入力 `gates.c1` にそのまま渡す（#780 Slice B）。
- 対象は **lite 帯候補の変更**（[`lite-criteria.md`](../../../docs/workflows/ai-loop/lite-criteria.md) §2 の
  4 軸を満たしうる変更）。high-risk / critical 相当や boundary=touches-HO が明らかな変更には使わない
  （使っても flow フェーズで即 human escalate になる）。
- 適用制限（Phase 1 rollout eligibility）は
  [`rollout-policy.md`](../../../docs/workflows/ai-loop/rollout-policy.md) を正本とする
  （導入先適用の前提 2 条件 = ho-paths の導入先確定 + LoopSpec `scope.allowed_paths` 宣言）。
  恒久定義（責務・terminal state・C-3'/Human C-3 経路）の単一正本は
  [`00_concept.md`](../../../docs/workflows/ai-loop/00_concept.md)。本サイクルは PlanGate 本番フロー
  （`bin/plangate`・`scripts/hooks/`・WF-00〜07 の Human C-3）からは呼ばれない（不変）。

## Step 0: breakdown-gate による粒度判定（#780 Slice B）

[`breakdown-gate`](../breakdown-gate/SKILL.md) スキルでタスク粒度を判定する
（理想 / 許容 / 分割必須の 3 段階）。判定結果を `gates.breakdown` へ変換する:

- 理想 / 許容 → `"pass"`
- 分割必須 → `"pass"` 以外の値（例 `"split-suggested"`）。arbiter は priority 1.7
  で human escalate する（分割してから再度サイクルへ）

## Step 1: 入力の組み立て

`changed_files` を決定する:

- **計画時**（exec 前の C-3' 裁定）: plan の Files to Touch を使う
- **再裁定時**（実装後・PR 前の再確認）: `git diff --name-only <base>...HEAD` の実差分を使う

lite 4 軸（[`lite-criteria.md`](../../../docs/workflows/ai-loop/lite-criteria.md) §2）を
それぞれ根拠つきで宣言する。**いずれかの軸が判定不能なら false**（AC-8 安全側、虚偽宣言禁止）。

- `size_ok`: 変更規模が light 相当以下か（ファイル数 1〜2 目安）。**申告するが、
  arbiter が `changed_files` の実ファイル数で機械検証する**（`SIZE_OK_MAX_FILES`=2。
  実ファイル数が 2 を超えて `size_ok=true` を申告すると priority 1.9 で human
  escalate。#780 Slice C）
- `no_new_design`: 新規設計がないか（既存構造の枠内か）
- `follows_pattern`: 既存パターンを踏襲しているか（ミラー実装か）
- `reversible`: 可逆か（`git revert` 一発等、機械的な巻き戻し手順があるか）

`class` は `merge` を含む変更なら `"merge"`（即 human escalate）、含まなければ `"no-merge"`。
`target_sha` は対象コミットの SHA。`allowed_paths` は LoopSpec の `scope.allowed_paths`
宣言をそのまま渡す（#809）。

`gates`（任意・#780 Slice B）は plan 品質ゲート（priority 1.7）の入力。**Step 0**
（breakdown-gate スキルで粒度判定）の verdict を `gates.breakdown` に
（`理想`/`許容` → `"pass"`、`分割必須` → それ以外の値、例 `"split-suggested"`。
`"pass"` 以外はすべて未充足扱い）、**Step 1**（C-1 実施結果）を `gates.c1` に
（`"PASS"` のみ通過。`FAIL`/未実施はそれ以外の値）設定する。**gates 自体を
省略した場合も入力エラーにはならないが、priority 1.7 で human escalate に
倒れる**（後方互換・安全側。以前の auto-approve 経路を壊さないためには
gates を両方 `"PASS"`/`"pass"` で渡す必要がある）。

`run`（任意）は `run_id`（`run-NNN` 連番）・`round_index`（**初回呼び出し=1**、再試行ごとに +1。1 起点。metrics は round_index==1 を初回 sentinel に first_pass 判定するため 0 起点不可）・`task_id`（対象 PBI）を刻む。省略可だが、省略すると metrics 集計対象外（legacy）になる。

`production` / `plan_package`（任意・TASK-0872）: **Plan-first 正式入口（`ai-loop run TASK-XXXX`）から開始した production run では両方を必ず入力に含める**。`plan_package.py`（arbiter.py と同ディレクトリ）で Plan Package（pbi-input / plan / todo / test-cases + C-1/C-2 evidence）の presence・evidence 判定・hash を検証して `plan_package` ブロックを組み立て、`production: true` を宣言する。`production: true` で `plan_package` が欠落・構造不正なら priority 1.6 で escalate、reviewer snapshot 三つ組不一致・`source_sha != target_sha` は priority 1.65 で blocked（フィールド契約・stale 規則・LoopSpec 派生マッピングの正本 = `c3-prime-contract.md`）。LoopSpec は同モジュールの `derive_loopspec()` で Plan Package から決定論派生する（手入力しない）。非 production の PoC 実験 run では両フィールドとも省略可（既存挙動不変・additive）。

入力 JSON の例:

```json
{
  "changed_files": ["docs/workflows/ai-loop/example.md"],
  "allowed_paths": ["docs/workflows/ai-loop/example.md"],
  "lite": {
    "size_ok": true,
    "no_new_design": true,
    "follows_pattern": true,
    "reversible": true
  },
  "class": "no-merge",
  "verdicts": {
    "model_a": "approve",
    "model_b": "approve",
    "reject_category": null,
    "model_c": null,
    "model_d": null
  },
  "target_sha": "abc1234",
  "gates": {
    "c1": "PASS",
    "breakdown": "pass"
  },
  "run": {
    "run_id": "run-022",
    "round_index": 1,
    "task_id": "TASK-XXXX"
  }
}
```

## Step 2: W チェック（サブエージェント 2 体・独立並列）

Model A / Model B を Agent ツールで **独立に**（相手の結論を見せずに）並列起動する。
返答は `verdict` / `reject_category`（reject 時のみ）/ `理由` の 3 行 raw 指定で受け取る。

### Model A（順方向・設計妥当性）委託プロンプト定型

```text
対象: <changed_files>（target_sha: <target_sha>）
役割: 変更が「正しく作られているか」を検証する。
観点: 設計妥当性・受入基準（AC）網羅・スコープ整合。計画中の『検証済み』申告には**証跡（実行出力の貼付）**があるか確認し、なければ未検証として扱う。
他モデルの結論は見せない・参照しない。

出力形式（常に3行、raw）:
verdict: approve | reject
reject_category: none (approve時) | ho_path_contact | permission | irreversible |
  security_break | public_api | data_integrity | migration | auth_change |
  logic | performance | test_shortage | documentation | format | naming (reject時)
理由: <1〜3文>
```

### Model B（逆方向・adversarial）委託プロンプト定型

```text
対象: <changed_files>（target_sha: <target_sha>）
役割: 変更が「どう壊れるか」を検証する（adversarial）。
観点: 失敗モード・境界値・悪用経路・想定外の入力。加えて、LoopSpec の external_sources に列挙された出典について、memory 書込物（decision record・plan-memory・frictions・run 記録への追記分）の diff を対象に、当該出典の内容がコピーされている箇所を探し、出典（URL / issue・PR 番号）の併記がない転記があれば違反として指摘する。検出できるのは逐語（高一致率）コピーのみ — 言い換え転記・provenance の真偽は判別できず maker の誠実申告に依存する（限界の自己開示）。
他モデルの結論は見せない・参照しない。

出力形式（常に3行、raw）:
verdict: approve | reject
reject_category: none (approve時) | ho_path_contact | permission | irreversible |
  security_break | public_api | data_integrity | migration | auth_change |
  logic | performance | test_shortage | documentation | format | naming (reject時)
理由: <1〜3文>
```

`reject_category` は [`flow-detect.md`](../../../docs/workflows/ai-loop/flow-detect.md) §3.2.1
のカテゴリマッピング表に照合可能な文字列で記録する。一致しないカテゴリは分類器側で `critical`
（human escalate）にフォールバックされる。

**reject_category は enum の英小文字値をそのまま（verbatim）返させる。和訳・言い換え・自由記述は禁止**（例: 『ロジック変更』ではなく `logic`）。非一致は分類器が critical 扱いになる（安全側）ため裁定は壊れないが、意図しない escalate を生む。

## Step 3: `arbiter.py` へ入力し裁定を得る

```sh
python3 scripts/ai-loop/arbiter.py --input /path/to/input.json
# または stdin 経由:
echo '{...}' | python3 scripts/ai-loop/arbiter.py
```

| exit code | decision          | 動作                                                                              |
| --------- | ----------------- | --------------------------------------------------------------------------------- |
| `0`       | `AUTO_APPROVED`   | 自動承認。provenance 刻印（正本）を保存                                           |
| `2`       | `HUMAN_ESCALATED` | **停止して人間へ escalate**（`w_check` / `boundary_check` / `lite_check` を提示） |
| `3`       | `BLOCKED`         | 当該変更を不採用。理由（stderr の裁定サマリ）を記録                               |
| `1`       | 入力エラー        | stderr の理由に従い入力 JSON を修正して再実行                                     |

分岐表・severity 分類・優先順位ロジックの正本は
[`execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) §2(5) および
[`decision-table.md`](../../../docs/workflows/ai-loop/decision-table.md)。本スキルはこれを
再定義しない。

## Step 4: record の保存

```sh
mkdir -p docs/working/ai-loop-runs
python3 scripts/ai-loop/arbiter.py --input /path/to/input.json \
  > "docs/working/ai-loop-runs/$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD).json"
```

- `AUTO_APPROVED` の record のみ **provenance 刻印（正本）**
- `HUMAN_ESCALATED` / `BLOCKED` の record は **audit record（暫定）**
  （[`execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) §2(4) 注記）

## Step 5: 分岐後の行動

- **exit 0（AUTO_APPROVED）**: exec → 強化セルフレビュー
  （diff-audit スキル全観点 + [`plan-review-readiness-gate.md`](../../../docs/ai/plan-review-readiness-gate.md) §7/§8）
  → PR 作成 → CI/AI レビュー指摘対応ループ（pr-watch 相当、`MERGE_READY` まで）
- **exit 2（HUMAN_ESCALATED）**: **停止して人間へ**。`w_check` / `boundary_check` / `lite_check` の
  内容を提示し、人間の判断を仰ぐ。AI が自己解決してはならない
- **exit 3（BLOCKED）**: 当該変更を採用しない。理由を audit record に記録して終了
- **severity=minor/low の不一致のみ**、Model C（セキュリティ・認証・権限観点）/
  Model D（後方互換・データ整合観点）の委託プロンプト定型で再裁定する
  （[`flow-detect.md`](../../../docs/workflows/ai-loop/flow-detect.md) §3.3）。
  委託プロンプトは Model A/B と同じ 3 行 raw 形式・独立起動を踏襲し、観点のみ以下に差し替える:
  - Model C: 「セキュリティ・認証・権限の観点で、この変更が悪用・権限昇格・認証バイパスを
    許さないかを検証する」
  - Model D: 「後方互換性・データ整合性の観点で、この変更が既存の契約やデータ状態を
    壊さないかを検証する」

  C/D の verdict を得たら、**Step 1 の入力 JSON の `verdicts.model_c` /
  `verdicts.model_d` に設定し（`reject_category` は Model B のものを保持）、
  `arbiter.py` を再実行**する（Step 3〜4 を繰り返す）。C/D 裁定を経た record には
  `w_check.severity` / `w_check.model_c` / `w_check.model_d` が刻印される
  （[`decision-table.md`](../../../docs/workflows/ai-loop/decision-table.md) §5）。

## Step 5.5: exec 差分への rubric grader

AUTO_APPROVED → exec 完了後・PR 作成前に、maker と独立の sonnet サブエージェント
（grader）へ exec 差分を委託する（W チェックと同じ maker≠grader・独立文脈方式）。
入力 = maker 差分 + 計画の Goal/確定文言。

### rubric 5 項目（review-principles §2 からの docs-run 翻訳）

以下の表は maker がそのまま SKILL.md に転記する確定版（Round 2 改訂 1）。
定義の正本は [`review-principles.md`](../../rules/review-principles.md) §2 のままで、
本表はそれを再定義せず docs-run に適用可能な fail 条件へ翻訳したものである。

| #   | 基準（review-principles §2 からの docs-run 翻訳） | fail 条件（判定可能形）                                                                                       |
| --- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | **正確性・正本整合**（保守性/可読性由来）         | 差分中のファイルパス・コマンド・参照リンクに実在しないものが 1 つ以上ある、または参照正本と矛盾する記述がある |
| 2   | **要件適合**（計画との 1:1）                      | 計画の Goal・確定文言に対し宣言外の変更、または要求要素の欠落がある                                           |
| 3   | **文体・構造踏襲**（可読性由来）                  | 追記が既存文書の見出し階層・表形式・文体から逸脱している                                                      |
| 4   | **境界安全**（セキュリティ由来）                  | 承認境界・HO 境界・停止規則を弱める/緩和する記述を含む                                                        |
| 5   | **重複定義回避**（拡張性/保守性由来）             | 既存正本に定義済みの規範を参照でなく再定義している                                                            |

（パフォーマンス観点は docs-run では該当稀のため基準 1 に「実行例の到達性」として包含。
5 観点との対応は各行に明記し重複定義しない — 定義の正本は review-principles §2 のまま）

### grader 委託プロンプト定型（W チェック定型の形式踏襲）

```text
対象: <changed_files>（maker 差分）
役割: この差分を上記 rubric 5 項目で採点する。
計画: <計画 Goal / 確定文言>
観点: rubric 5 項目（本節の表）。各項目を pass/fail で判定する。

出力形式（常に3行、raw）:
verdict: pass | fail
failed_criteria: <fail とした項目番号を列挙（例: 2,4） or なし>
feedback: <1〜3文>
```

判定ブロック（上記 3 行）に**続けて、基準ごとの証跡ブロックを別掲**する（行数自由・
判定ブロックの 3 行 raw 形式とは別領域）:

- **fail とする基準ごとに、差分からの引用（行）を必須添付する。引用のない fail は無効**
  とし、maker は再試行前に grader へ差し戻せる
- pass にも基準ごとに 1 行の根拠を証跡ブロックへ書く（全 5 行。「問題なし」のみは不可）
- `feedback:` 行自体は 1 行に収める（複数論点はセミコロン区切り。詳細は証跡ブロックへ）

### 再試行ループ

- `verdict: fail` → feedback（引用込み）を添えて maker に再試行を委託する。**上限 2 回**
- 上限超過 → `HUMAN_ESCALATED` として扱い、**grader の全出力（引用込み）を人間へ提示**
  （false-fail 連鎖を人間が判断可能にする）
- grader 出力は decision record と同様、run 記録へ全文貼付する（監査可能性）

## 禁止事項

- lite 宣言の虚偽（判定不能を `true` 側に倒す）
- W チェック結果の改変（Model A/B/C/D の verdict を都合よく書き換える）
- touches-HO の迂回（boundary 判定を回避する目的でのファイル分割・命名変更）
- escalate の自己解決（exit 2 を人間に提示せず AI 単独で処理を続行する）

## 関連ドキュメント

- [`docs/workflows/ai-loop/execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) — 1 サイクル手順の正本
- [`docs/workflows/ai-loop/lite-criteria.md`](../../../docs/workflows/ai-loop/lite-criteria.md) — lite 4 軸・AC-8 安全側
- [`docs/workflows/ai-loop/flow-detect.md`](../../../docs/workflows/ai-loop/flow-detect.md) — W チェック・severity 分類・C/D 裁定
- [`docs/workflows/ai-loop/decision-table.md`](../../../docs/workflows/ai-loop/decision-table.md) — Decision table・provenance schema
- [`scripts/ai-loop/arbiter.py`](../../../scripts/ai-loop/arbiter.py) — 入力 JSON 仕様（docstring）
- [`docs/ai/plan-review-readiness-gate.md`](../../../docs/ai/plan-review-readiness-gate.md) — 強化セルフレビュー §7/§8 観点
