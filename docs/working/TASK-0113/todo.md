# TASK-0113 EXECUTION TODO

> Source: plan.md / Mode: standard

## 🤖 Agent タスク

### Phase 1: 準備
- [ ] **T-01**: 既存 `scripts/hooks/check-*` パターン把握 + `tests/hooks/` test patterns 確認 (owner=agent / Risk=low / 🚩 既存資産マップ)

### Phase 2: 実装
- [ ] **T-02 (R-002/R-003/R-009)**: `scripts/hooks/check-ai-memory-pollution.sh` (POSIX sh + python3 sub-process for YAML、git pre-commit 専用、--auto-revert は unstaged diff 検出時 block) (owner=agent / Risk=**high** / depends_on=T-01 / 🚩 検出 + unstaged 保護 + exit 1)
- [ ] **T-03 (R-010)**: `.plangate-pollution-patterns.yaml` 既定設定 + `schemas/plangate-pollution-patterns.schema.json` (命名整合) (owner=agent / Risk=low / depends_on=T-02 / 🚩 schema valid)
- [ ] **T-04 (R-008)**: `scripts/templates/pre-commit.sample` + `scripts/install-pre-commit.sh` (owner=agent / Risk=low / depends_on=T-02 / 🚩 install 後 hook 発火)

### Phase 3: ドキュメント + 検証
- [ ] **T-05**: `docs/ai/ai-memory-pollution-guard.md` 運用ガイド (owner=agent / Risk=low / depends_on=T-04 / 🚩 Human が読んで対処可能)
- [ ] **T-06 (R-007 CRITICAL / R-005)**: `tests/extras/ta-16-pollution-guard.sh` (fixture 7 case: clean/claude-mem/カスタム/allowlist/巨大/binary/rename/deleted/unstaged 併存) (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-16 全 PASS)

### Phase 4: 完了
- [ ] **T-07**: handoff.md (Rule 5 必須 6 要素) + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..8 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] **H-02**: (opt-in) `scripts/install-pre-commit.sh` 実行で pre-commit hook 配置
- [ ] **H-03**: C-4 ゲート + merge

## ⚠️ 依存関係

- T-02..T-07 は H-01 (C-3) 通過後にのみ着手可
- T-01 (read-only) は C-3 前可
- H-02 は本 PBI merge 後の opt-in 操作

## 完了条件

全 T + handoff + AC-1..8 PASS + 既存テスト regression なし + markdownlint pass
