# EXECUTION TODO — TASK-0872

> plan: [`plan.md`](./plan.md) / Mode: critical（人間 C-3 必須・HO は Human patch 適用）
> L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない。

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準（AC-1〜11・9 シナリオ）を再掲し、作業範囲を PR-1/PR-2 スライスに固定する [Owner: agent] [depends_on: -] [files: -] rollback:不要
- [ ] T-2: `docs/workflows/ai-loop/c3-prime-contract.md` を新設し、c3-prime フィールド契約を確定する（required/optional・型・stale 条件・#873 共有 + C-2 反映 5 点: reviewer snapshot 必須化[R-004] / source_sha 不一致=BLOCK 固定・target_sha との関係定義[R-003/R-011] / serialization 制約[R-009] / LoopSpec 派生の全数マッピング表[R-012] / legacy 併存時の受理優先順[EC-5]）[Owner: agent] [depends_on: T-1] [files: docs/workflows/ai-loop/c3-prime-contract.md] rollback: ファイル削除

### PR-1 実装フェーズ（TDD: RED → GREEN → REFACTOR）

- [ ] 🚩 T-3: `test_plan_package.py` に presence 検証（シナリオ 1,2）・hash 整合（シナリオ 3）・冪等（シナリオ 9）の RED テストを記述 [Owner: agent] [depends_on: T-2] [files: scripts/ai-loop/test_plan_package.py] rollback: ファイル削除
- [ ] T-4: テスト実行し FAIL を確認 [Owner: agent] [depends_on: T-3] [files: -] rollback:不要
- [ ] 🚩 T-5: `plan_package.py` を最小実装（presence / artifact_hashes / plan_package_hash / LoopSpec 決定論的派生 / c3-prime dict 組み立て。fail-closed）[Owner: agent] [depends_on: T-4] [files: scripts/ai-loop/plan_package.py] rollback: ファイル削除
- [ ] T-6: `test_plan_package.py` 全 PASS を確認 [Owner: agent] [depends_on: T-5] [files: -] rollback:不要
- [ ] 🚩 T-7: `test_arbiter.py` に `plan_package` ブロック必須化・presence gate（AC-4: gates.c1 単独では通過不可）・provenance 刻印 + reviewer snapshot 照合（AC-5 / R-004）・W チェック不一致 escalate（シナリオ 4）・**valid Package + approve/approve → c3-prime record 生成（シナリオ 5 の PR-1 Unit / R-005）**・C-1/C-2 × 欠落/FAIL/stale 表駆動 6 ケース（R-002）・timestamp 固定注入での byte 同一（R-010）の RED テストを追加 [Owner: agent] [depends_on: T-6] [files: scripts/ai-loop/test_arbiter.py] rollback: `git restore -- scripts/ai-loop/test_arbiter.py`
- [ ] T-8: テスト実行し新規分 FAIL・既存分 PASS を確認 [Owner: agent] [depends_on: T-7] [files: -] rollback:不要
- [ ] 🚩 T-9: `arbiter.py` の入力契約拡張 + presence gate + provenance 刻印 + `approval_kind: c3-prime` 出力を実装 [Owner: agent] [depends_on: T-8] [files: scripts/ai-loop/arbiter.py] rollback: `git restore -- scripts/ai-loop/arbiter.py`
- [ ] 🚩 T-10: `test_arbiter.py` 全 PASS（既存 + 新規）を確認 — 後方互換の機械確認 [Owner: agent] [depends_on: T-9] [files: -] rollback:不要
- [ ] T-11: docs 4 本を更新（00_concept §3.4 位相明記 / loopspec Plan Package 派生節 / execution-runbook 手順 / decision-table presence gate 行）[Owner: agent] [depends_on: T-10] [files: docs/workflows/ai-loop/00_concept.md, docs/workflows/ai-loop/loopspec.md, docs/workflows/ai-loop/execution-runbook.md, docs/workflows/ai-loop/decision-table.md] rollback: `git restore -- docs/workflows/ai-loop/`
- [ ] T-11b: `scripts/schema_mapping.py` に approval_kind 判別の c3-prime.schema.json dispatch を追加（R-006）+ `scripts/sync-plugin-plangate.sh` の明示列挙へ plan_package.py / test_plan_package.py を追加（R-008）[Owner: agent] [depends_on: T-10] [files: scripts/schema_mapping.py, scripts/sync-plugin-plangate.sh] rollback: `git restore -- scripts/schema_mapping.py scripts/sync-plugin-plangate.sh`
- [ ] 🚩 T-12: ai-loop-cycle SKILL を改訂し、sync 整合を確認する（判定 = `sh scripts/sync-plugin-plangate.sh` 実行後 `git diff --quiet -- plugin/plangate/` が空 + `.agents` ↔ `plugin` の cmp 一致。`.claude` はリンク書換版のため 3-way byte 同一は要求しない / R-007）[Owner: agent] [depends_on: T-11, T-11b] [files: .agents/skills/ai-loop-cycle/SKILL.md, .claude/skills/ai-loop-cycle/SKILL.md, plugin/plangate/skills/ai-loop-cycle/SKILL.md] rollback: `git restore -- .agents/skills .claude/skills plugin/plangate/skills`

### PR-1 検証フェーズ

- [ ] 🚩 T-13: Verification Automation 実行（`python3 scripts/ai-loop/test_arbiter.py && python3 scripts/ai-loop/test_plan_package.py && sh tests/run-tests.sh && bin/plangate doctor`）[Owner: agent] [depends_on: T-12] [files: -] rollback:不要

### PR-2 フェーズ（HO・patch 生成まで agent / 適用は human）

- [ ] 🚩 T-14: `schemas/c3-prime.schema.json` patch 生成 + `python3 -c "import json; json.load(...)"` 検証（AI は適用しない）[Owner: agent] [depends_on: T-13] [files: docs/working/TASK-0872/patches/] rollback: patch 破棄
- [ ] 🚩 T-15: `bin/plangate` validate / exec preflight の c3-prime 両対応 patch 生成 + sandbox で dry-run 検証（legacy c3 経路無変更を diff で証明）[Owner: agent] [depends_on: T-14] [files: docs/working/TASK-0872/patches/] rollback: patch 破棄
- [ ] T-16: `.claude/commands/ai-loop-workflow.md`（+plugin sync 対）の run 入口 TASK-XXXX 必須化 patch 生成。**入口レベルの検証（TASK ID なし → W チェック未実行で停止 / TASK-XXXX あり → 後続へ進む）を T-18 の E2E に含める（R-001）** [Owner: agent] [depends_on: T-15] [files: docs/working/TASK-0872/patches/] rollback: patch 破棄
- [ ] 🚩 T-18: E2E fixture 作成 — `tests/extras/ta-NN-c3-prime.sh` + `tests/fixtures/<name>/` の既存パターン採用（run-tests.sh 自動 source・test.yml touch 不要 / R-013）。カバー: 入口 TASK ID 必須（R-001）/ valid Package → arbiter → c3-prime → validate PASS → preflight PASS / plan 1 byte 改変 → FAIL / **source_sha のみ変更 → BLOCK（R-003）**。TA-30 に plan_package テストの展開先自立 PASS を追加（R-008）[Owner: agent] [depends_on: T-15, T-16] [files: tests/extras/, tests/fixtures/] rollback: fixture 削除
  - 注: T-17 は欠番（C-2 R-013 反映で旧 T-17「CI 配線 patch」を本タスクへ統合した監査痕跡として番号を保持）

### 完了フェーズ

- [ ] T-19: 9 シナリオ × テスト ID 対応表を test-cases.md と突合し、evidence を保存 [Owner: agent] [depends_on: T-13, T-18] [files: docs/working/TASK-0872/evidence/] rollback:不要
- [ ] T-20: issue #872 / #870 へ実行コマンド・exit code・artifact・test log link をコメント（DoD）[Owner: agent] [depends_on: T-19, H-4] [files: -] rollback:不要

## 👤 Humanタスク

- [ ] 🚩 H-1: C-3 ゲート — plan/todo/test-cases + C-1/C-2 結果の三値判断（critical のため必須。Mode オーバーライド判断・Unknowns 2 件の方向確認を含む）[Owner: human] [depends_on: C-1/C-2 完了]
- [ ] 🚩 H-2: PR-1 の C-4 レビュー・マージ [Owner: human] [depends_on: T-13]
- [ ] 🚩 H-3: PR-2 HO patch の確認・適用（`ho-apply-approval` 方式）[Owner: human] [depends_on: T-16]
- [ ] 🚩 H-4: PR-2 の C-4 レビュー・マージ（CI green 確認込み）[Owner: human] [depends_on: H-3, T-18]

## ⚠️ 依存関係

- T-1〜T-13（PR-1）は H-1（C-3 APPROVED）後にのみ開始（`bin/plangate exec` が APPROVED c3.json を要求）
- PR-2（T-14〜）は PR-1 マージ（H-2)後に着手（c3-prime 出力形式が確定してから schema/受理側を固定）
- H-3 が得られない間、PR-2 は BLOCKED（blocker: HO patch 適用 / owner: human / unblock_condition: patch 適用 + doctor PASS）
