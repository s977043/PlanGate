# TASK-0110 EXECUTION TODO

> Source: plan.md / Mode: light / Generated: 2026-05-25

## 🤖 Agent タスク

### Phase 1: 準備
- [ ] **T-01**: skip-decision-log.jsonl の schema 把握 + check-skip-acknowledged.sh 読解 + entry 件数/サンプル抽出 (owner=agent / Risk=low / 🚩 既存資産マップ完成)

### Phase 2: 実装
- [ ] **T-02 (R-002/R-005)**: `scripts/batch-acknowledge-skip-decisions.py` 新規。**raw-line-preserving 方式** (line-by-line で 2 field のみ既存 key 順維持で置換/追加)。**ISO 8601 UTC**。atomic RMW (.bak + os.replace) (owner=agent / Risk=medium / depends_on=T-01 / 🚩 dry-run/apply 両動作 + byte-equal except 2 field 機械検証)

### Phase 3: 検証
- [ ] **T-03**: `tests/extras/ta-14-skip-acknowledge.sh` 新規 (fixture jsonl 3 case) + tests/run-tests.sh dispatcher 追記 (owner=agent / Risk=low / depends_on=T-02 / 🚩 tests/run-tests.sh PASS + 新 case 全 PASS)
- [ ] **T-04**: 実 log で dry-run 実行 → evidence/dry-run-result.md に reason 分布保存 (owner=agent / Risk=low / depends_on=T-02 / 🚩 148 record 全件検出)

### Phase 4: 完了
- [ ] **T-05**: `docs/ai/skip-acknowledge-cli.md` Human 適用ガイド作成 (owner=agent / Risk=low / depends_on=T-04 / 🚩 Human が読んで適用可能)
- [ ] **T-06**: handoff.md (Rule 5 必須 6 要素) + V-1 (test-cases 全件突合) (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..7 PASS)

## 👤 Human タスク

- [ ] **H-01**: **C-3 ゲート** — plan/todo/test-cases/review-self.md 確認 → APPROVE/CONDITIONAL/REJECT → `approvals/c3.json` 発行
- [ ] **H-02 (R-001/R-003)**: **PR ブランチで適用** — `python3 scripts/batch-acknowledge-skip-decisions.py --apply --acknowledged-by s977043` をローカルで実行 → 変更を同一 PR にコミット (commit message に `applied by s977043 (TASK-0110 H-02)`) → push → CI "SKIP_REASON 追認" PASS 確認 → C-4 承認 → merge (AI 不可)
- [ ] **H-03**: 適用後 CI で "SKIP_REASON 追認" PASS 確認
- [ ] **H-04**: **C-4 ゲート (PR レビュー)** + **merge** (Human-owned 固定)

## ⚠️ 依存関係

- T-02..T-06 は H-01 (C-3) 通過後にのみ着手可
- T-01 (read-only 調査) は C-3 前可
- H-02 (適用) は本 PBI の merge 後に Human が実行

## 完了条件

全 T + handoff 6 要素 + AC-1..7 PASS + 既存テスト regression なし
