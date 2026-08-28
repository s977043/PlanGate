# EXECUTION PLAN — TASK-1180（#1180 M-1 carve-out）

## Goal

`tests/extras/ta-69-distribution-checks.sh` の TC-C6 fixture を是正し、
`check-skill-name-collisions.py` の**条件④ `_same_intra_root_path` に対する検出力を回復**する。
回復は変異注入（M2b）で機械的に実証する。

## Constraints / Non-goals

- **Constraints**
  - 変更は `tests/extras/ta-69-distribution-checks.sh` の 1 ファイル 1 行に閉じる
  - 本番コード（`scripts/check-skill-name-collisions.py`）は commit しない
    （変異は検証中に一時適用し、`git checkout --` で戻す）
  - 件数契約を新設しない（#1087 AC-9。`-eq` の新規追加をしない）
- **Non-goals**
  - #1180 の AC-2〜AC-8（selftest 配線 / TC-C12 前提ガード / provenance ベースのミラー判定 /
    doctor からの `--mirror-plugin` 到達 / docs 追補）

## Approach Overview

「fixture の部分更新によって TC が**別の理由で**通るようになった」型の退行なので、
修正そのものは 1 語だが、**修正が検出力を回復したことの証明**が本体である。
そのため issue AC-8 の規律に従い、`_same_intra_root_path` を無効化する変異 M2b を
修正前後の両方に当てて、SURVIVE → KILL の遷移を実測する。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 修正前 baseline 測定 | ta-69 = 27 passed / 0 failed | agent | 低 | 🚩 |
| S2 | 変異 M2b を現行実装へ適用し ta-69 実行 | TC-C6 が **PASS（SURVIVE）**= 検出力ゼロの証拠 | agent | 低 | 🚩 |
| S3 | TC-C6 fixture を 1 語修正 | `plugin/plangate/skills` | agent | 低 | |
| S4 | 変異 M2b 適用下で ta-69 実行 | TC-C6 が **FAIL（KILL）** | agent | 低 | 🚩 |
| S5 | 変異を revert し ta-69 実行 | 27 passed / 0 failed | agent | 低 | 🚩 |
| S6 | full suite（`tests/run-tests.sh`）で回帰なしを確認 | 実行ログ | agent | 中 | 🚩 |
| S7 | W チェック → arbiter 裁定 → PR 作成 | ai-loop record + PR | agent | 低 | 🚩 |
| S8 | C-4（PR レビュー / merge） | — | **human** | — | 🚩 |

## Files / Components to Touch

- `tests/extras/ta-69-distribution-checks.sh`（**唯一の commit 対象**・:229 の 1 語）
- `scripts/check-skill-name-collisions.py`（**変異注入の一時適用のみ・commit しない**）

## Testing Strategy

- **Unit / Integration**: `bash tests/extras/ta-69-distribution-checks.sh`（standalone 経路）
- **回帰**: `bash tests/run-tests.sh`（harness 経路で sourced されることの確認を含む）
- **Verification Automation**: 変異注入（M2b = `_same_intra_root_path` を常に True）による
  検出力の機械実証。修正前 SURVIVE / 修正後 KILL の 2 点測定で契約する
  （固定件数ではなく**遷移**を契約値にする）

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| 変異を戻し忘れて本番コードを汚染する | S5 で `git checkout --` 実行後に `git diff --name-only` で実測確認 |
| :204 / :216 まで一括置換して TC-C4 / TC-C5 の意図を壊す | 対象を :229 に限定し、置換後に diff 1 行を確認 |
| 他者の未 commit 変更（`skip-decision-log.jsonl`）を巻き込む | commit 時に対象ファイルのみ明示 add、`git diff --cached` で検証 |

## Questions / Unknowns

なし（issue にレビュアーの実測値があり、本セッションで再現済み）。

## Mode判定

**モード**: `light`

**判定根拠**:
- 変更ファイル数: 1 → 超低〜低
- 受入基準数: 4 → 中
- 変更種別: テスト fixture の是正（バグ修正相当）→ 低
- リスク: 低（本番コード不変・`git revert` 一発で可逆）
- 影響範囲: 当該テストファイルのみ
- Hardening Override 対象パス: **非該当**（`tests/**` は HO 9 カテゴリに含まれない）
- **最終判定**: `light`（受入基準数のみ中だが、実体は 1 行修正 + その実証）

## 検討したアプローチ（B-2）

| 案 | 内容 | 評価 |
|----|------|------|
| **案 A（採用）**: TC-C6 の fixture を `plugin/plangate/skills` に是正 | 条件④を測る対を「repo-local ⇄ export 先 plugin」で作り直す | ✅ 1 語・既存 TC-C3 / TC-C8 と同じパターン・可逆。issue のレビュアーが実測済み |
| 案 B: 条件④専用の新規 TC（TC-C6b）を追加し TC-C6 は据え置き | 既存 TC を触らずに検出力を足す | ❌ TC-C6 が「非 export plugin」で rc=1 になる重複 TC（TC-C10 と同義）として残り、名称（`same name at non-mirrored paths`）と実測内容の乖離が固定化する |
| 案 C: `--selftest` の配線（#1180 AC-2）で条件④を pin する | selftest は条件④を kill できる | ❌ 単独では TC-C6 の乖離が残る。AC-2 は別スライスで実施予定であり、本 carve-out の 1 行と独立 |

**選定理由**: 案 A は退行の原因（fixture の部分更新漏れ）を直接戻すもので、
新規設計を持ち込まず既存 2 TC のパターンを踏襲する。案 C は補完関係にあり排他ではない。

## Stop Condition（停止条件）

以下のいずれかに該当したら **exec を停止して人間へ escalate** する:

- 変更ファイル数が **2 を超えた**時点（本 PBI は 1 ファイル契約）
- `tests/extras/` 以外に commit 対象が発生した時点
- 修正後に ta-69 の **failed が 1 件でも残った**時点（TC-C6 の変異テストを除く）
- `arbiter.py` が `HUMAN_ESCALATED`（exit 2）/ `BLOCKED`（exit 3）を返した時点

## Replan Triggers（再計画トリガー / 機械値）

| トリガー | 機械値 | 対応 |
|---------|-------|------|
| 変更ファイル数の超過 | `git diff --name-only origin/main \| wc -l` > `1` | 再計画（スコープ再分割） |
| full suite の失敗 | `tests/run-tests.sh` の failed > `0` | 再計画（原因切り分け） |
| 変異が KILL されない | 修正後 M2b 適用時の TC-C6 が PASS | 再計画（fixture の是正内容が誤り） |
| W チェックの reject | `verdicts` に `reject` が `1` 件以上 | reject_category に応じて再計画 or escalate |
