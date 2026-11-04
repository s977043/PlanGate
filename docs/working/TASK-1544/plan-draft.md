# TASK-1544 Implementation Plan（下書き。`PLANGATE_HOOK_TASK=TASK-1544` のセッションで plan.md へ移す）

> EH-3 が TASK context なしの plan.md 書き込みを block したため、本文をこのファイルに置いている。
> plan.md へ移した後に本ファイルは削除する。c3.json の plan_hash は plan.md に対して発行すること。

## Goal

`retro_enabled: true` かつ C-3 APPROVED の run だけで handoff の既知課題から seeds 下書きを作り、
`confirmed_by` が入った下書きだけを seeds に追記する最小の生成器を実装する。
あわせて、その制約を実行して検査する TC（TA-118）を置く。

## Context

pbi-input.md を参照。#1573 で手順は docs に入ったが、実行コードが無いため AC2/AC3 は機械検査できない。

## Scope

### In Scope

- `scripts/retro_seed_draft.py`（新規）
- `tests/extras/ta-118-retro-seed-draft.sh`（新規）
- `docs/workflows/06_retro.md` の「検査観点」節の更新（手動 → 生成器と TA-118 の参照）

### Out of Scope

pbi-input.md「Out of scope」のとおり（opt-in source の追加・既定 ON・HO パスの変更・CLI 経路・L2）。

## Global Constraints

- HO 対象パスは編集しない。本計画の変更ファイル 3 件はいずれも HO 12 カテゴリ（`mode-classification.md`）に該当しない。
  `scripts/hooks/` ではなく `scripts/` 直下。`bin/plangate`・`schemas/`・`.claude/` は触れない
- c3.json / approvals/ は読むだけ。作らない、書かない
- 生成器は `confirmed_by` を埋めない（引数でも環境変数でも埋める経路を作らない）
- python3 標準ライブラリのみ。PG-SH-GUARD（#1169）を `improvement_seed_delta.py` と同じ形で先頭に置く

## 前提の実測検証（#786）

| 前提 | 実測 |
|------|------|
| 実行コードが無い | `grep -rn retro_enabled scripts bin` → 0 件（2026-10-26 オーガナイザー実測） |
| handoff §2 の見出し | `docs/working/templates/handoff.md:47` `## 2. 既知課題一覧`（表形式） |
| seeds スキーマ | `docs/ai/retro-phase.md` §2（見出し `## <date> — <task_id>` + 5 項目 + `confirmed_by`） |
| c3.json の判定キー | `c3_status`（既存 c3.json の大半が `"c3_status": "APPROVED"`） |
| テスト番号 | `tests/extras` の最大は ta-117。open PR に extras の ta 追加なし（2026-10-26 `gh pr list` で確認）→ 118 |

## Questions / Unknowns（#786）

- U-1（pbi-input の改変は c3 の plan_hash に束縛されない）: 本 PBI では解消しない。生成器の docstring の残存脅威モデルに書く
- seeds の 5 項目は handoff から機械的に決められない。下書きでは「未確認」と書き、既知課題の行を `失敗・手戻り` の候補として列挙する（06_retro.md 手順 3 と同じ扱い）

## Approach Comparison

| 案 | 内容 | 採否 |
|----|------|------|
| A | `bin/plangate retro-draft` サブコマンド | 不採用（`bin/plangate` は HO） |
| B | `scripts/retro_seed_draft.py` 単体 + extras TC | **採用** |
| C | docs 文言の grep のみ | 不採用（Human 決定 2026-10-26。素通りの検査になる） |

### Recommended Approach

案 B。ゲート判定・下書き出力・confirm 済みの追記の 3 つだけを 1 ファイルに持つ。これで AC2/AC3 を実行して検査できる。L2 連携や CLI 化は後続に回す。

## Change Type / Verification Strategy

new behavior。TDD（TA-118 を先に書き、生成器が無い状態で FAIL を確かめてから実装する）と、変異注入。

## Files / Interfaces

| ファイル | 種別 | HO |
|---------|------|----|
| `scripts/retro_seed_draft.py` | 新規 | 非該当 |
| `tests/extras/ta-118-retro-seed-draft.sh` | 新規 | 非該当 |
| `docs/workflows/06_retro.md` | 更新 | 非該当 |

CLI:

```text
python3 scripts/retro_seed_draft.py draft  --task-dir <docs/working/TASK-XXXX> [--out <path>]
python3 scripts/retro_seed_draft.py append --task-dir <docs/working/TASK-XXXX> --draft <path> --seeds <path>
```

終了コード: 0 = 成功 / 2 = 引数・入力の形式エラー / 3 = opt-in 不成立で停止（出力なし）/ 4 = confirm 未了で追記を拒否。

ゲート（`draft` と `append` の両方で判定する）:

1. `<task-dir>/pbi-input.md` に、行全体が `retro_enabled: true` に一致する行がある（前後の空白は許す。`true` 以外の値・コメント中の記述は不成立）
2. `<task-dir>/approvals/c3.json` が JSON として読め、`c3_status == "APPROVED"`

## Work Breakdown

### Task 1: TA-118 を先に書く（RED）

- Files: `tests/extras/ta-118-retro-seed-draft.sh`（run-tests.sh から `set -eu` で source。`register_cleanup` で一時パスを登録）
- Steps: fixture 生成関数 → test-cases.md の TC → 生成器が無い状態で実行して FAIL を記録
- Completion: 生成器が無い状態で TA-118 の TC が FAIL し、harness 全体はハングしない
- Rollback: ファイル削除

### Task 2: 生成器を実装する（GREEN）

- Files: `scripts/retro_seed_draft.py`
- Steps: ゲート関数 → handoff §2 表の抽出 → 下書きの整形 → append（confirmed_by の検査、ゲートの再判定、末尾への追記、既存内容の前方一致検証）
- Completion: TA-118 全 PASS。追記後の fixture が `scripts/improvement_seed_delta.py` の検査で正規形として通る
- Rollback: ファイル削除

### Task 3: 変異注入

- test-cases.md「変異注入計画」M-1〜M-4 を 1 つずつ注入し、該当 TC の FAIL を記録して戻す（commit しない）
- Rollback: `git checkout -- scripts/retro_seed_draft.py`

### Task 4: docs の更新

- Files: `docs/workflows/06_retro.md`（検査観点節を TA-118 参照にし、手順に CLI を添える。retro-phase.md は変更しない）
- Completion: リンク切れなし。opt-in source の記述は増えていない
- Rollback: `git checkout -- docs/workflows/06_retro.md`

## Verification Plan

- `sh tests/run-tests.sh`（harness 経由）で TA-118 全 PASS、既存の FAIL を増やさない（main で同じテストを流して対照）
- TA-118 単体の実行 / 変異注入 M-1〜M-4 / `python3 -m py_compile scripts/retro_seed_draft.py`

### レビューレーン計画（#786）

- C-2: 設計妥当性レーン 1 本 + コードベース整合レーン 1 本（seeds の読み手 `improvement_seed_delta.py` との形式整合）
- V-3: 承認トークン（c3.json）を読むコードのため、review-principles §7-quater に従い 2 ラウンドを下限とする（安全側）

## Replan Triggers

- 変更ファイルが 3 件を超える / HO 対象パスの変更が必要になる / seeds の §2 スキーマ変更が必要になる / TA-118 の実行時間が 30 秒を超える

## Stop Condition

- 上の Replan Trigger のいずれか
- EH-3 が `.md` 以外の書き込みを block した場合。exec は `PLANGATE_HOOK_TASK=TASK-1544` を付けた再起動の後に行う

## Human Approval Boundary

- C-3: Human が `docs/working/TASK-1544/approvals/c3.json` を発行する（AI は作らない）
- C-4 / merge: Human-owned

## Mode判定

**モード**: standard

- 変更ファイル数: 3 → standard
- 受入基準数: 5 → standard
- 変更種別: 小機能追加（新規スクリプト + テスト） → standard
- リスク: 中（承認トークンを読む。書かない） → standard
- HO 対象パス: なし（3 件とも 12 カテゴリ外） → 例外ルール非該当
- **最終判定**: standard。承認トークンを読むため V-3 は 2 ラウンドを下限とする（安全側）
