# EXECUTION TODO — TASK-0896

> plan: [`plan.md`](./plan.md) / Mode: high-risk（rollback 必須）
> L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準（AC-1〜8）を再掲し、Files to Touch 8 ファイルに作業範囲を固定する [Owner: agent] [depends_on: -] [files: -]
  - rollback: 不要（読取のみ）
- [ ] 🚩 T-2: ベースライン実測 — 4 系テスト（test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / run-tests 411）を実行し `evidence/test-runs/step0-baseline.log` に記録。期待値と不一致なら即停止 [Owner: agent] [depends_on: T-1] [files: docs/working/TASK-0896/evidence/test-runs/step0-baseline.log]
  - rollback: 不要（読取・記録のみ）

### 実装フェーズ Step 1: 定数集約（コミット a）

- [ ] 🚩 T-3: `c3_contract.py` 新設 — API docstring（層区分明記）+ 契約定数（ARTIFACTS / VALID_DECISIONS / VALID_VERDICTS / SNAPSHOT_KEYS + REQUIRED_KEYS 系〔record 用 REQUIRED_KEYS・OPTIONAL_KEYS / 入力ブロック用 PLAN_PACKAGE_REQUIRED_KEYS〕Refs: R-001）のみ定義。arbiter への sys.path 操作は追加しない（Refs: R-008） [Owner: agent] [depends_on: T-2] [files: scripts/ai-loop/c3_contract.py]
  - rollback: ファイル削除（`git rm`）
- [ ] 🚩 T-4: `test_c3_contract.py` 新設 — 定数値の契約固定テスト（既存 3 ファイルの値と byte 同一 assert を含む移行テスト）を書き、RED→GREEN 確認 [Owner: agent] [depends_on: T-3] [files: scripts/ai-loop/test_c3_contract.py]
  - rollback: ファイル削除
- [ ] 🚩 T-5: 3 消費者の定数 import 置換（arbiter.py / plan_package.py / c3prime_verify.py・ローカル定義削除）→ 4 系テスト green 確認 → コミット a [Owner: agent] [depends_on: T-4] [files: scripts/ai-loop/arbiter.py, scripts/ai-loop/plan_package.py, scripts/ai-loop/c3prime_verify.py]
  - rollback: `git revert <コミット a>`

### 実装フェーズ Step 2: hash 統合（コミット b）

- [ ] 🚩 T-6: test_c3_contract.py に hash 境界値テスト追加（空 dict / キー順序非依存 / 1 byte 改変検出）→ RED 確認 [Owner: agent] [depends_on: T-5] [files: scripts/ai-loop/test_c3_contract.py]
  - rollback: `git revert <コミット b>`
- [ ] 🚩 T-7: `sha256_of_file` / `canonical_hash` を c3_contract.py に実装 → GREEN 確認 [Owner: agent] [depends_on: T-6] [files: scripts/ai-loop/c3_contract.py]
  - rollback: `git revert <コミット b>`
- [ ] 🚩 T-8: plan_package.py `_sha256_of` / c3prime_verify.py `_sha256` / 両者の canonical hash 式を import 置換 → 4 系テスト green → コミット b [Owner: agent] [depends_on: T-7] [files: scripts/ai-loop/plan_package.py, scripts/ai-loop/c3prime_verify.py]
  - rollback: `git revert <コミット b>`

### 実装フェーズ Step 3: 三つ組照合コア（コミット c）

- [ ] 🚩 T-9: test_c3_contract.py に trio 境界値テスト追加（キー欠落 / 空値 / 型不一致 / 三つ組不一致 / **余剰キーの strict・lenient 両側固定** / **理由リストの順序 assert + 代表文言回帰**〔Refs: R-004〕/ **I/O 封じ純粋性テスト**〔Refs: R-003〕）→ RED 確認 [Owner: agent] [depends_on: T-8] [files: scripts/ai-loop/test_c3_contract.py]
  - rollback: `git revert <コミット c>`
- [ ] 🚩 T-10: `check_snapshot_trio(container, reviewers, strict_keys)` を c3_contract.py に実装（理由文字列リスト返却・I/O なし）→ GREEN 確認 [Owner: agent] [depends_on: T-9] [files: scripts/ai-loop/c3_contract.py]
  - rollback: `git revert <コミット c>`
- [ ] 🚩 T-11: arbiter `plan_package_check` の snapshot 検査部を置換(tuple 変換・strict_keys=False)+ c3prime_verify 置換(strict_keys=True・`_fail(先頭)`)。残置 = c3prime 側: verdict 語彙 / 独立性 / AUTO_APPROVED 整合 / **reviewers ちょうど 2 者**〔R-005〕、arbiter 側: PLAN_PACKAGE 構造検査 / **source_sha vs target_sha 照合**〔R-006〕→ 4 系テスト + 偽造 14 パターン reject 不変を確認 → コミット c（exec 時は「arbiter 置換→検証」「c3prime 置換→検証」の 2 サブに分割・C-1 WARN-1 対応） [Owner: agent] [depends_on: T-10] [files: scripts/ai-loop/arbiter.py, scripts/ai-loop/c3prime_verify.py]
  - rollback: `git revert <コミット c>`

### 実装フェーズ Step 4: sync 整合（コミット d）

- [ ] 🚩 T-12: sync-plugin-plangate.sh の copy for リスト + delete 保護 case へ c3_contract.py / test_c3_contract.py 追加 + **ta-55 へ `python3 scripts/ai-loop/test_c3_contract.py` 実行 1 行追記**〔R-010〕→ `sh scripts/sync-plugin-plangate.sh` 実行（**a〜c 途中での sync 実行禁止**〔R-009〕） [Owner: agent] [depends_on: T-11] [files: scripts/sync-plugin-plangate.sh, tests/extras/ta-55-c3prime-accept.sh, plugin/plangate/skills/ai-loop-cycle/scripts/]
  - rollback: `git revert <コミット d>` + sync 再実行
- [ ] 🚩 T-13: sync 2 回目 no-op（`git diff --quiet -- plugin/plangate/`）+ ta-30 実測 PASS（TC-07/08/09）→ コミット d [Owner: agent] [depends_on: T-12] [files: -]
  - rollback: 不要（検証のみ）

### 検証フェーズ

- [ ] 🚩 T-14: Verification Automation 全実行（test_c3_contract + 既存 3 系 + run-tests 411）→ `evidence/test-runs/` に記録 [Owner: agent] [depends_on: T-13] [files: docs/working/TASK-0896/evidence/test-runs/]
  - rollback: 不要
- [ ] 🚩 T-15: 敵対レビュー 1 ラウンド以上（複数エージェント・観点: 検証強度 weakening / strict_keys fail-open / import 失敗 fail-closed）→ disposition 記録（AC-8）。major 以上は是正 → 再レビュー [Owner: agent] [depends_on: T-14] [files: docs/working/TASK-0896/evidence/]
  - rollback: 是正コミットは各 Step の revert 単位に従う
- [ ] 🚩 T-16: AC-1〜8 の全確認（test-cases.md 突合） [Owner: agent] [depends_on: T-15] [files: -]
  - rollback: 不要

### 完了フェーズ

- [ ] 🚩 T-17: status.md / current-state.md 最終更新 [Owner: agent] [depends_on: T-16] [files: docs/working/TASK-0896/status.md, docs/working/TASK-0896/current-state.md]
  - rollback: 不要

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases の人間レビュー（exec 前ゲート・**論点 1: #873 との実装順の確定** / 論点 2: EPIC #870 への追記コメント要否） [Owner: human]
- [ ] C-4: PR レビュー・承認（GitHub 上） [Owner: human]

## ⚠️ 依存関係

- Agent 実装（T-3 以降）→ Human C-3 APPROVED（c3.json）後に exec 開始
- PR 作成 → Human C-4 承認後にマージ
- コミット a→b→c→d は直列（各コミットで green 維持が前提）
