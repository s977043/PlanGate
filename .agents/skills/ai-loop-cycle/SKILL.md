---
name: ai-loop-cycle
description: "ai-loop-workflow の 1 サイクル（C-3' 裁定）を実行する。Use when: 「ai-loop で回して」「C-3' 裁定を実行」「arbiter で裁定して」「ai-loop 初回実走」。恒久定義（責務・terminal state・C-3' 経路）の正本 = 同梱 references/00_concept.md、適用制限（Phase 1 rollout eligibility）の正本 = 同梱 references/rollout-policy.md（導入先が独自正本を保持する場合はそちらを優先）。"
---

# ai-loop-cycle

> 本スキルは **bundled resources**（`references/`・`scripts/`）で自己完結する。
> スキルディレクトリ直下の `references/<name>.md` と `scripts/arbiter.py` を同梱し、
> 導入先が独自の正本（`docs/workflows/ai-loop/` 等）を別途保持している場合は
> そちらを優先すること。

本スキルに同梱される ai-loop ドキュメント（`references/` 配下。導入先で正本を
別途保持している場合はそちらを優先する）の `references/execution-runbook.md` に定義された
1 サイクル（変更対象ファイル取得 → W チェック → `arbiter.py` 裁定 → record 保存 → 分岐後の行動）を
実行するための手順スキル。判定ロジック・provenance スキーマの正本は runbook 側にあり、本スキルは
それらを実行するための **委託プロンプト定型** と **手順の要約** のみを持つ（二重定義しない）。
詳細な手順・分岐表は都度 `references/` を読みに行く（progressive disclosure。本 SKILL.md は
手順の要点のみを持ち、runbook 等の全文を転記しない）。

## 前提

- **C-1 PASS・C-2 完了済み**であること（`references/execution-runbook.md` §2 前提）。
  本サイクルは C-3' ゲートの位置づけであり、C-1/C-2 未完了の変更には使わない。
  この C-1 の実施結果（`PASS`）を Step 1 の入力 `gates.c1` にそのまま渡す（#780 Slice B）。
- 対象は **lite 帯候補の変更**（`references/lite-criteria.md` §2 の 4 軸を満たしうる変更）。
  high-risk / critical 相当や boundary=touches-HO が明らかな変更には使わない
  （使っても flow フェーズで即 human escalate になる）。
- 適用制限（Phase 1 rollout eligibility）は同梱 `references/rollout-policy.md` を正本とする
  （導入先が独自正本を保持する場合はそちらを優先）。導入先での適用は **①ho-paths の
  導入先確定 ②LoopSpec `scope.allowed_paths` 宣言** の 2 条件が前提。恒久定義
  （責務・terminal state・C-3'/Human C-3 経路）の正本は同梱 `references/00_concept.md`。
  本サイクルは導入先の本番承認フロー（ゲート・hook 等の統制機構）からは呼ばれない（不変）。
- **auto-approve 方針（Phase 1）**: lite 4 軸（`references/lite-criteria.md` §2）を
  申告制・AND・判定不能→false で満たせば、**実機能も `AUTO_APPROVED` 対象に含めてよい**
  （docs 級限定ではない）。`size_ok` は申告するが、arbiter が `changed_files` の
  実ファイル数で機械検証する（`SIZE_OK_MAX_FILES`=2。実ファイル数が 2 を超えて
  `size_ok=true` を申告すると priority 1.9 で human escalate。#780 Slice C）。
  他 3 軸（`no_new_design`/`follows_pattern`/`reversible`）は引き続き申告制のまま。
- **裁定記録・摩擦台帳の保存先は導入先プロジェクトで定義する**（本スキルは強制しない）。
  既定案として、導入先の作業ディレクトリ配下に run 単位の裁定 record 用サブディレクトリ
  （例: `<作業ディレクトリ>/ai-loop-runs/`）を設ける配置が参考になるが、導入先の
  ディレクトリ規約を優先すること。

## Step 0: breakdown-gate による粒度判定（#780 Slice B）

`breakdown-gate` スキル（同梱・または導入先の等価スキル）でタスク粒度を
判定する（理想 / 許容 / 分割必須の 3 段階）。判定結果を `gates.breakdown`
へ変換する:

- 理想 / 許容 → `"pass"`
- 分割必須 → `"pass"` 以外の値（例 `"split-suggested"`）。arbiter は priority 1.7
  で human escalate する（分割してから再度サイクルへ）

## Step 1: 入力の組み立て

`changed_files` を決定する:

- **計画時**（exec 前の C-3' 裁定）: plan の Files to Touch を使う
- **再裁定時**（実装後・PR 前の再確認）: `git diff --name-only <base>...HEAD` の実差分を使う

lite 4 軸（`references/lite-criteria.md` §2）をそれぞれ根拠つきで宣言する。**いずれかの軸が
判定不能なら false**（AC-8 安全側、虚偽宣言禁止）。

`allowed_paths` は LoopSpec の `scope.allowed_paths` 宣言をそのまま渡す（#809）。

- `size_ok`: 変更規模が light 相当以下か（ファイル数 1〜2 目安）。**申告するが、
  arbiter が `changed_files` の実ファイル数で機械検証する**（`SIZE_OK_MAX_FILES`=2。
  実ファイル数が 2 を超えて `size_ok=true` を申告すると priority 1.9 で human
  escalate。#780 Slice C）
- `no_new_design`: 新規設計がないか（既存構造の枠内か）
- `follows_pattern`: 既存パターンを踏襲しているか（ミラー実装か）
- `reversible`: 可逆か（`git revert` 一発等、機械的な巻き戻し手順があるか）

`class` は `merge` を含む変更なら `"merge"`（即 human escalate）、含まなければ `"no-merge"`。
`target_sha` は対象コミットの SHA。

`gates`（任意・#780 Slice B）は plan 品質ゲート（priority 1.7）の入力。**Step 0**
（breakdown-gate 判定）の verdict を `gates.breakdown` に（`理想`/`許容` → `"pass"`、
`分割必須` → それ以外の値。`"pass"` 以外はすべて未充足扱い）、**Step 1 の前提**
（C-1 実施結果）を `gates.c1` に（`"PASS"` のみ通過）設定する。**gates 省略も
入力エラーにはならないが、priority 1.7 で human escalate に倒れる**（後方互換・
安全側。以前の auto-approve 経路を壊さないためには gates を両方
`"PASS"`/`"pass"` で渡す必要がある）。

`run`（任意）は `run_id`（`run-NNN` 連番）・`round_index`（**初回呼び出し=1**、再試行ごとに +1。1 起点。metrics は round_index==1 を初回 sentinel に first_pass 判定するため 0 起点不可）・`task_id`（対象 PBI）を刻む。省略可だが、省略すると metrics 集計対象外（legacy）になる。

`production` / `plan_package`（任意・TASK-0872）: **Plan-first production run では両方を必ず入力に含める**（`ai-loop run TASK-XXXX` という CLI 入口として設計されたが、**`bin/plangate` に `ai-loop` サブコマンドは未実装**。現行の実行手順は `references/execution-runbook.md` §2 の `arbiter.py` 手動実行であり、CLI 入口を設けるか否かは issue #982 で未決）。`plan_package.py`（arbiter.py と同ディレクトリ）で Plan Package（pbi-input / plan / todo / test-cases + C-1/C-2 evidence）の presence・evidence 判定・hash を検証して `plan_package` ブロックを組み立て、`production: true` を宣言する。`production: true` で `plan_package` が欠落・構造不正なら priority 1.6 で escalate、reviewer snapshot 三つ組不一致・`source_sha != target_sha` は priority 1.65 で blocked（フィールド契約・stale 規則・LoopSpec 派生マッピングの正本 = `c3-prime-contract.md`）。LoopSpec は同モジュールの `derive_loopspec()` で Plan Package から決定論派生する（手入力しない）。非 production の PoC 実験 run では両フィールドとも省略可（既存挙動不変・additive）。

入力 JSON の例:

```json
{
  "changed_files": ["docs/example.md"],
  "allowed_paths": ["docs/example.md"],
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
観点: 失敗モード・境界値・悪用経路・想定外の入力。加えて、LoopSpec の external_sources に列挙された出典について、記録物（裁定 record・plan-memory・摩擦台帳・run 記録への追記分）の diff を対象に、当該出典の内容がコピーされている箇所を探し、出典（URL / issue・PR 番号）の併記がない転記があれば違反として指摘する。検出できるのは逐語（高一致率）コピーのみ — 言い換え転記・provenance の真偽は判別できず maker の誠実申告に依存する（限界の自己開示）。
他モデルの結論は見せない・参照しない。

出力形式（常に3行、raw）:
verdict: approve | reject
reject_category: none (approve時) | ho_path_contact | permission | irreversible |
  security_break | public_api | data_integrity | migration | auth_change |
  logic | performance | test_shortage | documentation | format | naming (reject時)
理由: <1〜3文>
```

`reject_category` は `references/flow-detect.md` §3.2.1 のカテゴリマッピング表に照合可能な文字列で
記録する。一致しないカテゴリは分類器側で `critical`（human escalate）にフォールバックされる。

**reject_category は enum の英小文字値をそのまま（verbatim）返させる。和訳・言い換え・自由記述は禁止**（例: 『ロジック変更』ではなく `logic`）。非一致は分類器が critical 扱いになる（安全側）ため裁定は壊れないが、意図しない escalate を生む。

## Step 3: `arbiter.py` へ入力し裁定を得る

```sh
python3 scripts/arbiter.py --input /path/to/input.json
# または stdin 経由:
echo '{...}' | python3 scripts/arbiter.py
```

（`arbiter.py` の配置は導入方法により異なる。本スキル同梱版は、スキルディレクトリ
直下の `scripts/arbiter.py` として同梱 `references/` と対になる形で配布される）

| exit code | decision          | 動作                                                                              |
| --------- | ----------------- | --------------------------------------------------------------------------------- |
| `0`       | `AUTO_APPROVED`   | 自動承認。provenance 刻印（正本）を保存                                           |
| `2`       | `HUMAN_ESCALATED` | **停止して人間へ escalate**（`w_check` / `boundary_check` / `lite_check` を提示） |
| `3`       | `BLOCKED`         | 当該変更を不採用。理由（stderr の裁定サマリ）を記録                               |
| `1`       | 入力エラー        | stderr の理由に従い入力 JSON を修正して再実行                                     |

分岐表・severity 分類・優先順位ロジックの正本は `references/execution-runbook.md` §2(5) および
`references/decision-table.md`。本スキルはこれを再定義しない。

## Step 4: record の保存

裁定 record（decision record）の保存先は**導入先プロジェクトで定義する**（本スキルは
配置を強制しない）。参考として、run 単位のディレクトリ（例: `<導入先の作業ディレクトリ>/
ai-loop-runs/`）へ、裁定日時とコミット SHA を含むファイル名で保存する運用が考えられる:

```sh
mkdir -p <導入先で定義した保存先>
python3 scripts/arbiter.py --input /path/to/input.json \
  > "<導入先で定義した保存先>/$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD).json"
```

- `AUTO_APPROVED` の record のみ **provenance 刻印（正本）**
- `HUMAN_ESCALATED` / `BLOCKED` の record は **audit record（暫定）**
  （`references/execution-runbook.md` §2(4) 注記）

## Step 5: 分岐後の行動

- **exit 0（AUTO_APPROVED）**: exec → 強化セルフレビュー（diff-audit スキル全観点 +
  導入先の plan-review readiness 相当の観点）→ PR 作成 → CI/AI レビュー指摘対応ループ
  （`MERGE_READY` まで）
- **exit 2（HUMAN_ESCALATED）**: **停止して人間へ**。`w_check` / `boundary_check` /
  `lite_check` の内容を提示し、人間の判断を仰ぐ。AI が自己解決してはならない
- **exit 3（BLOCKED）**: 当該変更を採用しない。理由を audit record に記録して終了
- **severity=minor/low の不一致のみ**、Model C（セキュリティ・認証・権限観点）/
  Model D（後方互換・データ整合観点）の委託プロンプト定型で再裁定する
  （`references/flow-detect.md` §3.3）。委託プロンプトは Model A/B と同じ 3 行 raw 形式・
  独立起動を踏襲し、観点のみ以下に差し替える:
  - Model C: 「セキュリティ・認証・権限の観点で、この変更が悪用・権限昇格・認証バイパスを
    許さないかを検証する」
  - Model D: 「後方互換性・データ整合性の観点で、この変更が既存の契約やデータ状態を
    壊さないかを検証する」

  C/D の verdict を得たら、**Step 1 の入力 JSON の `verdicts.model_c` /
  `verdicts.model_d` に設定し（`reject_category` は Model B のものを保持）、
  `arbiter.py` を再実行**する（Step 3〜4 を繰り返す）。C/D 裁定を経た record には
  `w_check.severity` / `w_check.model_c` / `w_check.model_d` が刻印される
  （`references/decision-table.md` §5）。

## Step 5.5: exec 差分への rubric grader

AUTO_APPROVED → exec 完了後・PR 作成前に、maker と独立の sonnet サブエージェント
（grader）へ exec 差分を委託する（W チェックと同じ maker≠grader・独立文脈方式）。
入力 = maker 差分 + 計画の Goal/確定文言。

### rubric 5 項目（レビュー 5 観点からの docs-run 翻訳）

以下の表は maker がそのまま SKILL.md に転記する確定版。定義の正本は導入先の
レビュー原則（5 観点: 可読性/拡張性/パフォーマンス/セキュリティ/保守性）にあり、
本表はそれを再定義せず docs-run に適用可能な fail 条件へ翻訳したものである。

| #   | 基準（レビュー 5 観点からの docs-run 翻訳） | fail 条件（判定可能形）                                                                                       |
| --- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | **正確性・正本整合**（保守性/可読性由来）   | 差分中のファイルパス・コマンド・参照リンクに実在しないものが 1 つ以上ある、または参照正本と矛盾する記述がある |
| 2   | **要件適合**（計画との 1:1）                | 計画の Goal・確定文言に対し宣言外の変更、または要求要素の欠落がある                                           |
| 3   | **文体・構造踏襲**（可読性由来）            | 追記が既存文書の見出し階層・表形式・文体から逸脱している                                                      |
| 4   | **境界安全**（セキュリティ由来）            | 承認境界・HO 境界・停止規則を弱める/緩和する記述を含む                                                        |
| 5   | **重複定義回避**（拡張性/保守性由来）       | 既存正本に定義済みの規範を参照でなく再定義している                                                            |

（パフォーマンス観点は docs-run では該当稀のため基準 1 に「実行例の到達性」として包含。
5 観点との対応は各行に明記し重複定義しない — 定義の正本は導入先のレビュー原則のまま）

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
- grader 出力は裁定 record と同様、run 記録へ全文貼付する（監査可能性。record 保存先は
  導入先プロジェクトで定義）

## 禁止事項

- lite 宣言の虚偽（判定不能を `true` 側に倒す）
- W チェック結果の改変（Model A/B/C/D の verdict を都合よく書き換える）
- touches-HO の迂回（boundary 判定を回避する目的でのファイル分割・命名変更）
- escalate の自己解決（exit 2 を人間に提示せず AI 単独で処理を続行する）

## 関連ドキュメント

本スキルは以下のドキュメント（本スキル同梱の `references/` 配下。導入先が
別途正本を保持する場合はそちらを優先）を前提として動作する:

- `references/execution-runbook.md` — 1 サイクル手順の正本
- `references/lite-criteria.md` — lite 4 軸・AC-8 安全側
- `references/flow-detect.md` — W チェック・severity 分類・C/D 裁定
- `references/decision-table.md` — Decision table・provenance schema
- `scripts/arbiter.py` — 入力 JSON 仕様（docstring）
- `references/ho-paths.md` — HO（Hardening Override）パス一覧（**プロジェクト固有・導入先で確定**）
- 導入先の強化セルフレビュー観点（存在する場合）
