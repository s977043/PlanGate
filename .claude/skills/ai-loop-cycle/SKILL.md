---
name: ai-loop-cycle
description: "ai-loop-workflow の 1 サイクル（C-3' 裁定）を実行する。Use when: 「ai-loop で回して」「C-3' 裁定を実行」「arbiter で裁定して」「ai-loop 初回実走」。適用ドメインは docs/workflows/ai-loop/ 配下のみで、PlanGate 本番フロー（WF-00〜WF-07）には適用しない。"
---

# ai-loop-cycle

[`execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) に定義された
1 サイクル（変更対象ファイル取得 → W チェック → `arbiter.py` 裁定 → record 保存 → 分岐後の行動）を
実行するための手順スキル。判定ロジック・provenance スキーマの正本は runbook 側にあり、本スキルは
それらを実行するための **委託プロンプト定型** と **手順の要約** のみを持つ（二重定義しない）。

## 前提

- **C-1 PASS・C-2 完了済み**であること（[`execution-runbook.md`](../../../docs/workflows/ai-loop/execution-runbook.md) §2 前提）。
  本サイクルは C-3' ゲートの位置づけであり、C-1/C-2 未完了の変更には使わない。
- 対象は **lite 帯候補の変更**（[`lite-criteria.md`](../../../docs/workflows/ai-loop/lite-criteria.md) §2 の
  4 軸を満たしうる変更）。high-risk / critical 相当や boundary=touches-HO が明らかな変更には使わない
  （使っても flow フェーズで即 human escalate になる）。
- 適用ドメインは `docs/workflows/ai-loop/` 配下のみ。PlanGate 本番フロー（`bin/plangate`・
  `scripts/hooks/`）からは呼ばれない隔離 PoC である。

## Step 1: 入力の組み立て

`changed_files` を決定する:

- **計画時**（exec 前の C-3' 裁定）: plan の Files to Touch を使う
- **再裁定時**（実装後・PR 前の再確認）: `git diff --name-only <base>...HEAD` の実差分を使う

lite 4 軸（[`lite-criteria.md`](../../../docs/workflows/ai-loop/lite-criteria.md) §2）を
それぞれ根拠つきで宣言する。**いずれかの軸が判定不能なら false**（AC-8 安全側、虚偽宣言禁止）。

- `size_ok`: 変更規模が light 相当以下か（ファイル数 1〜2 目安）
- `no_new_design`: 新規設計がないか（既存構造の枠内か）
- `follows_pattern`: 既存パターンを踏襲しているか（ミラー実装か）
- `reversible`: 可逆か（`git revert` 一発等、機械的な巻き戻し手順があるか）

`class` は `merge` を含む変更なら `"merge"`（即 human escalate）、含まなければ `"no-merge"`。
`target_sha` は対象コミットの SHA。

入力 JSON の例:

```json
{
  "changed_files": ["docs/workflows/ai-loop/example.md"],
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
  "target_sha": "abc1234"
}
```

## Step 2: W チェック（サブエージェント 2 体・独立並列）

Model A / Model B を Agent ツールで **独立に**（相手の結論を見せずに）並列起動する。
返答は `verdict` / `reject_category`（reject 時のみ）/ `理由` の 3 行 raw 指定で受け取る。

### Model A（順方向・設計妥当性）委託プロンプト定型

```text
対象: <changed_files>（target_sha: <target_sha>）
役割: 変更が「正しく作られているか」を検証する。
観点: 設計妥当性・受入基準（AC）網羅・スコープ整合。
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
観点: 失敗モード・境界値・悪用経路・想定外の入力。
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
  （self-review スキル全観点 + [`plan-review-readiness-gate.md`](../../../docs/ai/plan-review-readiness-gate.md) §7/§8）
  → PR 作成 → CI/AI レビュー指摘対応ループ（pr-watch 相当、merge-ready まで）
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
