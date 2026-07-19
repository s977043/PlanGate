# PBI INPUT PACKAGE — TASK-0872

> Issue: [#872](https://github.com/s977043/plangate/issues/872)（P0 / enhancement / area:workflow / governance）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870) ai-loop vNext
> 作成: 2026-07-20（issue #872 本文を正本に、2026-07-19 事前調査 + 本セッション実測調査を反映）

## Context / Why

現在の `/ai-loop-workflow run <説明>` は LoopSpec 作成から始まり、PlanGate の Plan 生成を起動しない。`ai-loop-cycle` は C-1 PASS / C-2 完了を前提にするが、arbiter 入力では `gates.c1` 等の**呼び出し側文字列を受け取るのみ**で、Plan Package や review evidence の実在・hash を検証しない。

実測で確定した現状ギャップ（2026-07-20 調査）:

- `scripts/ai-loop/arbiter.py`: 入力契約に `plan_hash` / `source_sha` が存在しない。commit 識別は `target_sha`（自由文字列・実在検証なし）のみ。`gates.c1` は `== "PASS"` の**純粋な文字列一致**（`plan_quality_check` L444-453）。provenance にも plan_hash は刻まれない
- C-3' decision record と `ai-dev exec` が要求する `approvals/c3.json` / `plan_hash` が**非接続**（arbiter.py は冒頭 docstring で「bin/plangate から一切呼ばれない隔離 PoC」と明記）
- `.claude/commands/ai-loop-workflow.md` の run 入口は自由文説明で TASK ID 必須でない
- `schemas/c3-approval.schema.json` は `additionalProperties:false` で evidence / source_sha 系フィールドなし
- `00_concept.md` §3.4 の `arbiter.py --verify-diff` は「Phase 3 実装予定」のまま未実装（言及 1 箇所のみ）
- ai-loop python テスト（test_arbiter.py 等）の CI 配線はゼロ（test.yml は shell テストのみ）

## What（Scope）

`ai-loop run TASK-XXXX` を Plan-first の唯一の正式入口とし、ai-dev が作成・レビューした Plan Package を C-3' の唯一の承認対象および exec 契約にする。

### Plan Package（同一 TASK 配下で扱う最小セット）

- `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md`
- C-1 review artifact / evidence
- C-2 review artifact / evidence

### In scope

1. `TASK-XXXX` を run の必須識別子にする
2. artifact 不足時は `ai-dev init/plan` 相当を起動または明示的に停止し、W チェックへ進めない
3. 4 成果物と C-1/C-2 artifact を構造検証する
4. LoopSpec を Plan Package から決定論的に派生させ、独立した計画として手入力しない
5. Plan Package hash、各 artifact hash、source SHA、allowed paths を固定する
6. W チェック A/B へ同一 Plan Package と必要な repository context を渡す
7. A/B の観点別判定、理由、evidence ref を構造化する
8. C-3' 結果を `ai-dev exec` が消費できる正式 `approvals/c3.json` 互換 artifact にする
9. Plan/source/artifact 変更時は承認を stale にし、再 C-1/C-2/C-3' を要求する

### Out of scope（Non-goals）

- ai-dev plan / exec / verify の再実装
- C-3' eligibility を全 mode へ拡大すること
- C-4 / merge 自動化
- C-1/C-2 レビュー品質そのものの再設計（#810 等を再利用）

## C-3' 最低出力（issue #872 指定の共有契約 — #873 との並行実装の前提）

```yaml
task_id: TASK-XXXX
decision: AUTO_APPROVED | HUMAN_ESCALATED | BLOCKED
approval_kind: c3-prime
source_sha: ...
plan_hash: sha256:...
artifact_hashes: {}
c1_evidence_ref: ...
c2_evidence_ref: ...
reviewers:
  model_a: {}
  model_b: {}
policy_ref: ...
issued_at: ...
```

## 受入基準（issue #872 verbatim）

- AC-1: `run <説明>` だけでは production-compatible run を開始できず、TASK ID が必須
- AC-2: 4 成果物のいずれかが欠ける場合、C-3' は `AUTO_APPROVED` にならない
- AC-3: C-1/C-2 evidence が欠ける、FAIL、stale の場合、C-3' は `AUTO_APPROVED` にならない
- AC-4: raw な `gates.c1=PASS` 文字列だけでは Plan 品質 gate を通過できない
- AC-5: Model A/B が同じ plan hash と source SHA を見たことを record から確認できる
- AC-6: W チェック不一致、判定不能、未知カテゴリは fail closed で Human へ escalate する
- AC-7: C-3' 承認 artifact を `bin/plangate validate TASK-XXXX` と exec preflight が受理する
- AC-8: plan.md または固定 artifact の 1 byte 変更で承認が stale になる
- AC-9: allowed paths 外、HO 接触、現行 eligibility policy 外は自動承認されない
- AC-10: LoopSpec と Plan の重複手入力がなく、派生結果の再現性がある
- AC-11: legacy C-3 human approval は後方互換を維持する

## 必須テストシナリオ（issue #872 verbatim）

1. artifact なし → Plan 生成または停止、W チェック未実行
2. C-1 なし / C-2 なし → escalate
3. artifact hash mismatch → block
4. W チェック approve/reject → escalate
5. valid Plan Package + approve/approve → C-3' artifact 生成
6. C-3' artifact → `validate` PASS → exec preflight PASS
7. 承認後 Plan 変更 → `validate` FAIL
8. HO / scope 外 → AUTO_APPROVED 不可
9. 同一入力 2 回 → decision と派生 LoopSpec が同一

## Definition of Done / Close 条件

- 上記 AC と 9 シナリオがすべて PASS
- 一つのコマンドで実行できる E2E fixture が CI へ登録されている
- 実装 PR が main へ merge 済み
- Issue コメントに実行コマンド、exit code、生成 artifact、test log への link がある
- #870 の DoD の Plan-first / C-3' 項目へ evidence link が反映されている

docs のみ、arbiter 単体 test のみ、手動で c3.json を書き換える運用では close しない。

## Notes from Refinement（事前調査で確定した設計方針・論点）

- **HO 4 カテゴリ touch → Mode = high-risk 確定・Human C-3 必須**: `schemas/*.schema.json` / `bin/plangate` / `.claude/commands/*.md` / `.github/workflows/*` に触れる。**HO / 非 HO のスライス分割（PR 分割）を推奨**（TASK-0871 の 2 PR 分割成功例を踏襲。CI drift-check の sync 同一 PR 強制を Metrics で先に見積もる）
- **c3-prime artifact schema + bin/plangate 受理が核心**。論点: 既存 `c3-approval.schema.json` 拡張 vs 別 schema（`c3-prime.schema.json`）新設 → 調査結果は `additionalProperties:false` + legacy 後方互換（AC-11）の観点から**別 schema 新設 + validate/preflight が両対応**が有力。plan で確定する
- **plan_hash の計算範囲**: 現行 4 箇所（c3 schema / approve / validate+preflight / EH-3 hook）はすべて **plan.md 単体** の sha256。#872 の「Plan Package hash」は別フィールド（`artifact_hashes` + package hash）として**加算**し、既存 plan_hash 契約は変えない（AC-11 後方互換）方向を plan で確定
- **presence gate と AUTO_APPROVED の関係明文化**: artifact 実在・hash 検証（新設 presence/integrity gate）が優先し、`gates.c1` 文字列は補助入力に降格（AC-4）
- **00_concept §3.4「Phase 3 --verify-diff」との位相整合**: 本 PBI の実装が §3.4 の予定記述とどう対応するかを plan で明示（実装するなら記述更新、しないなら位相を明記）
- **#873 との並行実装**: c3-prime artifact のフィールド契約（上記 YAML）を先に固定すれば `scripts/ai-loop/delivery.py`（#873）とコード競合ほぼ回避可。CI python テスト配線はどちらか先行・他方相乗り（本 PBI が先行なら本 PBI で配線）
- **LoopSpec は JSON Schema 未整備**（md 仕様のみ）。決定論的派生（In scope 4 / AC-10）の実装時に最小 schema 化を検討

## Estimation Evidence

### Risks

- HO 対象ファイル変更は AI 編集不可（常時 block）→ Human patch 適用フローが必要（TASK-0871 の `ho-apply-approval.md` 方式踏襲）
- arbiter.py の隔離 PoC 宣言（「bin/plangate から一切呼ばれない」）を跨ぐ設計変更 — 隔離の緩め方を誤ると Phase 1 rollout policy と矛盾する
- 既存 run record（3 世代分裂 / #874 調査）との互換。#874 RunEvidence 契約の供給元になるためフィールド契約の手戻りは高コスト

### Unknowns

- E2E fixture の CI 登録形式（新 workflow か test.yml 拡張か — CI yml は HO のため Human 適用）
- stale 判定の実装位置（arbiter 内 or validate 内 or 両方）

### Assumptions

- #810（Unknown Discovery / C-1 evidence キー契約）は未実装のまま進む — C-1 evidence は現行 review-self.md の存在 + 判定抽出で検証し、#810 の enum 確定後に強化（additive）
- Phase 1 rollout policy（導入先検証）は不変 — 本 PBI は plangate リポジトリ内の機構実装であり本番承認フロー WF-00〜07 は不変
