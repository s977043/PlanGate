# TASK-0113 EXECUTION TODO

> Source: plan.md / Mode: standard

## 🤖 Agent タスク

### Phase 1: 準備
- [ ] **T-01**: 既存 `scripts/hooks/check-*` パターン把握 + `tests/hooks/` test patterns 確認 (owner=agent / Risk=low / 🚩 既存資産マップ)

### Phase 2: 実装
- [ ] **T-02**: `scripts/hooks/check-ai-memory-pollution.sh` (POSIX sh, staged diff scan, exit 1 on match) (owner=agent / Risk=medium / depends_on=T-01 / 🚩 検出 + exit 1)
- [ ] **T-03**: `.plangate-pollution-patterns.yaml` 既定設定 + `schemas/pollution-patterns.schema.json` (owner=agent / Risk=low / depends_on=T-02 / 🚩 schema valid)
- [ ] **T-04**: `templates/pre-commit.sample` + `scripts/install-pre-commit.sh` (owner=agent / Risk=low / depends_on=T-02 / 🚩 install 後 hook 発火)

### Phase 3: ドキュメント + 検証
- [ ] **T-05**: `docs/ai/ai-memory-pollution-guard.md` 運用ガイド (owner=agent / Risk=low / depends_on=T-04 / 🚩 Human が読んで対処可能)
- [ ] **T-06**: `tests/extras/ta-15-pollution-guard.sh` (fixture 4 case) (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-15 全 PASS)

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
