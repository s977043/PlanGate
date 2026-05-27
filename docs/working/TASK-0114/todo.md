# TASK-0114 EXECUTION TODO

## 🤖 Agent タスク

- [ ] **T-01**: TASK-0113 template/install pattern + git pre-push 仕様確認 (owner=agent / Risk=low / 🚩 パターン把握)
- [ ] **T-02 (R-002/R-007)**: `scripts/templates/pre-push.sample` (POSIX sh、case 右辺 unquoted で glob、protected branch block、AC-1 既定 main master release/*) (owner=agent / Risk=medium / depends_on=T-01 / 🚩 protected push 検出 + release/* glob)
- [ ] **T-03 (R-006)**: `scripts/install-pre-push.sh` (`.bak` 保持、**冪等性**: 既存 hook と同一内容なら .bak skip) (owner=agent / Risk=low / depends_on=T-02 / 🚩 install 後 hook 発火 + 冪等性)
- [ ] **T-04**: `docs/ai/direct-push-prevention.md` 運用ガイド (owner=agent / Risk=low / depends_on=T-03 / 🚩 Human 運用可能)
- [ ] **T-05**: `tests/extras/ta-17-pre-push-guard.sh` fixture 5 case (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-17 全 PASS)
- [ ] **T-06**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..7 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行)
- [ ] **H-02**: (opt-in) `sh scripts/install-pre-push.sh` で hook 配置
- [ ] **H-03**: C-4 + merge
