# TASK-0120 EXECUTION TODO

## 🤖 Agent タスク
- [ ] **T-01**: SessionStart gh-pin-account hook 実装場所 + 責務確認 (owner=agent / Risk=low)
- [ ] **T-02**: scripts/gh-s977043.sh (auth switch + 冪等) (owner=agent / Risk=low / depends_on=T-01)
- [ ] **T-03**: docs/ai/github-account-pinning.md (owner=agent / Risk=low / depends_on=T-02)
- [ ] **T-04**: tests/extras/ta-23-gh-account-pin.sh (owner=agent / Risk=low / depends_on=T-02)
- [ ] **T-05**: handoff + V-1 (owner=agent / Risk=low / depends_on=全完了)

## 👤 Human タスク
- [ ] **H-01**: C-3 ゲート
- [ ] **H-02**: C-4 + merge
