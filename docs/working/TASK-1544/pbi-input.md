# PBI INPUT PACKAGE: Growth Harness L1 — retro seed 下書き生成器（#1544）

## Context / Why

Growth Harness（`docs/ai/growth-harness.md`）の L1「観測」は、WF-06 retro が opt-in 既定 OFF のため
入力量が不足している。#1573 で「opt-in 済み run に限り WF-05 handoff の既知課題から seeds 下書きを作る」
手順は `docs/workflows/06_retro.md` と `docs/ai/retro-phase.md` §1-a に書かれた。しかし、
その手順を実行するコードは無い（`scripts/` と `bin/` で `retro_enabled` を参照する実行コードは 0 件。
2026-10-26 にオーガナイザーが実測）。

このため #1544 の AC2「下書き生成が `retro_enabled: true` の run に限定されることを検査で確認できる」と
AC3「`confirmed_by` が空の下書きが seeds に追記されない」は、docs の文言を grep するテストでしか確認できない。
文言の grep は実装を何も壊さなくても通る（素通りの）テストになる。
Human の決定（2026-10-26）:「下書き生成を実装する」方針で進める。

### Bounded Discovery

- 既存の手順: `docs/workflows/06_retro.md`「handoff 既知課題からのドラフト作成（#1544）」の手順 1〜5
- 既存の近い実装: `scripts/improvement_seed_delta.py`（#1545。seeds を読む側）と、その検査 `tests/extras/ta-116-improvement-seed-delta.sh`
- seeds のスキーマ正本: `docs/ai/retro-phase.md` §2

## What（Scope）

### In scope

- 最小の下書き生成器 `scripts/retro_seed_draft.py`（python3 標準ライブラリのみ）
  - `draft`: `retro_enabled: true` かつ C-3 APPROVED の run に限り、handoff §2「既知課題一覧」から
    §2 スキーマの下書きを stdout（または seeds 以外の指定パス）に出す。`confirmed_by` は空欄。seeds には書かない
  - `append`: `confirmed_by` が入った下書きだけを seeds の末尾に追記する。既存の内容は変更しない
- 機械検査 `tests/extras/ta-118-retro-seed-draft.sh`（mktemp の sandbox 上の fixture で実行する）
- `06_retro.md` の「検査観点（手動・現時点では自動化済みと主張しない）」を、生成器と TA-118 の参照に更新する

### Out of scope

- opt-in source の追加、retro の既定 ON 化、mode 連動（retro-phase 提案 A。HO）
- `bin/plangate` へのサブコマンド追加（HO）
- `/ai-dev-workflow TASK-XXXX retro` の CLI 経路
- L2 digest の生成（#1545 の領域）
- `confirmed_by` を AI が埋める経路（作らない）

## 受入基準

- AC-1: `draft` は `retro_enabled: true` かつ `approvals/c3.json` の `c3_status == "APPROVED"` の run だけで下書きを出す。
  false / キーなし / C-3 未承認 / c3.json なし では、何も出さずに非ゼロで終了する
- AC-2: `draft` はどの入力でも `improvement-seeds.md` を変更しない（出力先に seeds を指定されたら拒否する）
- AC-3: `append` は `confirmed_by` が空、またはプレースホルダ（`<human>` 等）の下書きを拒否する。拒否したときは seeds のバイト列が変わらない
- AC-4: `append` は confirm 済みの下書きを末尾に 1 エントリだけ追記する。既存の内容はバイト単位で変わらない
- AC-5: 上の各 AC は TA-118 の TC で検査し、変異注入（ゲート除去 / confirmed_by 検査除去 / 上書き化）でそれぞれ FAIL することを確かめる

## Notes from Refinement

- 2026-10-26 Human 決定: grep だけの検査は AC2/AC3 の充足とみなさない。下書き生成器を実装する
- c3.json / approvals/ は Human が発行する。AI は作らない

## Estimation Evidence

### Risks

- 下書き生成器が c3.json を読むため、承認トークンを扱うコードになる（読むだけで、書かない）
- seeds は L2（#1545）の入力。追記の形式が §2 から外れると、L2 の検査が落ちる

### Unknowns

- U-1: c3.json の `plan_hash` は plan.md に束縛されており、pbi-input.md の `retro_enabled` 行は束縛されていない。C-3 の後に pbi-input を書き換えた場合は検出できない（残存リスクとして明記する）

### Assumptions

- pbi-input の opt-in は 1 行の `retro_enabled: true` で表す（YAML front matter または本文の行。retro-phase.md §1 の記法に従う）
