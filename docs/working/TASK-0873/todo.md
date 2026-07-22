# EXECUTION TODO — TASK-0873

> plan: [`plan.md`](./plan.md) / test-cases: [`test-cases.md`](./test-cases.md)
> Mode: critical（rollback 記載必須）。L-0〜V-4・PR 作成は workflow-conductor 制御のため含めない。

## 🤖 Agentタスク

### 準備フェーズ

- [ ] 🚩 T-1: Scope/受入基準（AC-1〜12 + fixture 10）を再掲し作業範囲を固定 [Owner: agent] [depends_on: -] [files: -] rollback:不要
- [ ] T-2: 参照実装の契約点を確認（c3prime_verify.py の public 関数 / ta-55 の sandbox 生成様式 / c3-prime-contract §7） [Owner: agent] [depends_on: T-1] [files: -] rollback:不要

### 正本 doc フェーズ

- [ ] 🚩 T-3: delivery-state-machine.md 骨子（サブステート 7 + 終端 2・状態定義） [Owner: agent] [depends_on: T-2] [files: docs/workflows/ai-loop/delivery-state-machine.md] rollback: ファイル削除
- [ ] T-4: Scheduling 判断表（優先度 1〜8）との正規化マッピング表 + MERGE_READY record 契約（AC-11 の 6 フィールド）+ 冪等キー規約を追記 [Owner: agent] [depends_on: T-3] [files: 同上] rollback: git restore
- [ ] T-5: c3-prime-contract.md §7 へ正本リンク 1 行 additive 追記 [Owner: agent] [depends_on: T-4] [files: docs/workflows/ai-loop/c3-prime-contract.md] rollback: git restore（additive 1 行のみ）

### 実装フェーズ（TDD: RED → GREEN → REFACTOR）

- [ ] 🚩 T-6: test_delivery.py — 契約 emit（決定論）・NO MERGE（MERGED 遷移不在）のテスト記述（doc↔contract 整合は ta-56 側 = R-012） [Owner: agent] [depends_on: T-4] [files: scripts/ai-loop/test_delivery.py] rollback: ファイル削除
- [ ] T-7: test_delivery.py — fixture 10 対応の遷移テスト（TC-01〜10）記述 [Owner: agent] [depends_on: T-6] [files: 同上] rollback: git restore
- [ ] T-8: test_delivery.py — 手 mutate 偽造/欠落/stale 系 + 冪等（同 snapshot 2 回）+ 境界（round=3/4）記述 [Owner: agent] [depends_on: T-7] [files: 同上] rollback: git restore
- [ ] T-9: テスト実行し FAIL 確認（RED） [Owner: agent] [depends_on: T-8] [files: -] rollback:不要
- [ ] 🚩 T-10: delivery.py — TRANSITIONS 定義 + `contract` サブコマンド（JSON emit） [Owner: agent] [depends_on: T-9] [files: scripts/ai-loop/delivery.py] rollback: ファイル削除
- [ ] T-11: delivery.py — c3-prime 入口再検証（c3prime_verify import・AUTO_APPROVED 以外 BLOCK・legacy exit 10 も BLOCK・stderr 捕捉 = R-009） [Owner: agent] [depends_on: T-10] [files: 同上] rollback: git restore
- [ ] T-12: delivery.py — assess 判定エンジン（head SHA 束縛 / taxonomy / disposition / 逸脱 / conflict 三点照合 / round 上限 / 優先度 3 recurse 復帰 / 7=candidate・8=MERGE_READY 分離 = R-002/R-003 / snapshot 検証不能値 fail-closed = R-006） [Owner: agent] [depends_on: T-11] [files: 同上] rollback: git restore
- [ ] T-13: delivery.py — record 永続（append 型・stable action ID + intent/receipt 2 段 = R-005・MERGE_READY record 6 フィールド・raw log 禁止 = R-014） [Owner: agent] [depends_on: T-12] [files: 同上] rollback: git restore
- [ ] T-14: テスト実行し PASS 確認（GREEN） [Owner: agent] [depends_on: T-13] [files: -] rollback:不要

### E2E / 配布フェーズ

- [ ] 🚩 T-15: ta-56-delivery.sh — sandbox 実走（最小アクション実行スタブで PR_CREATED→repair→MERGE_READY 反復 = R-004 / resume 冪等 / 禁止 import + merge シンボル走査 = R-007 / unittest 本体実行 / doc↔contract 整合 = R-012） [Owner: agent] [depends_on: T-14] [files: tests/extras/ta-56-delivery.sh] rollback: ファイル削除
- [ ] T-16: `sh tests/run-tests.sh` クリーン 1 回実行 exit 0 確認 [Owner: agent] [depends_on: T-15] [files: -] rollback:不要
- [ ] T-17: sync-plugin-plangate.sh 列挙 +2（copy/delete 保護） + sync 実行 + 2 回目 no-op + `git diff --quiet plugin/` [Owner: agent] [depends_on: T-16] [files: scripts/sync-plugin-plangate.sh, plugin/plangate/] rollback: git restore -- scripts/sync-plugin-plangate.sh plugin/

### 検証フェーズ

- [ ] 🚩 T-18: 敵対レビュー R1（複数エージェント・偽造耐性/fail-closed 観点）→ 是正 [Owner: agent] [depends_on: T-17] [files: evidence/] rollback: 是正 commit 単位で git revert
- [ ] 🚩 T-19: 敵対レビュー R2（R1 是正後の深掘り — #889 教訓: 1 ラウンドでは表層のみ）→ critical/major ゼロ収束まで [Owner: agent] [depends_on: T-18] [files: evidence/] rollback: 同上
- [ ] T-20: 受入基準 AC-1〜12 全確認（test-cases.md 突合） [Owner: agent] [depends_on: T-19] [files: -] rollback:不要

### 完了フェーズ

- [ ] T-21: コミット整理（1 コミット 1 種類・Refs 付き） [Owner: agent] [depends_on: T-20] [files: -] rollback: git reset（push 前のみ）
- [ ] T-22: status.md / current-state.md 最終更新 [Owner: agent] [depends_on: T-21] [files: status.md, current-state.md] rollback:不要

## 👤 Humanタスク

- [ ] C-3: Plan/ToDo/Test Cases の人間レビュー（critical 詳細・C-3 論点 5 件の明示判断・c3.json 発行） [Owner: human]
- [ ] C-4: PR レビュー・承認・マージ（GitHub 上） [Owner: human]

## ⚠️ 依存関係

- Agent 実装（T-3 以降）→ **Human C-3 APPROVED（c3.json）後に exec 開始**
- PR 作成 → Human C-4 承認後にマージ（NO MERGE BY AI）
- #896 並行: c3_contract.py が先に merge された場合は Replan Trigger（import 前提変更）で判断
