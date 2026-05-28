# TASK-0119 EXECUTION TODO

## 🤖 Agent タスク
- [ ] **T-01**: TASK-0113 pre-commit 構造 + 共通 dispatcher 可否確認 (owner=agent / Risk=low)
- [ ] **T-02**: scripts/hooks/check-git-add-scope.sh (HO) (owner=agent / Risk=medium / depends_on=T-01)
- [ ] **T-03**: docs/ai/git-add-scope-guard.md (owner=agent / Risk=low / depends_on=T-02)
- [ ] **T-04**: tests/extras/ta-22-git-add-scope.sh (owner=agent / Risk=low / depends_on=T-02)
- [ ] **T-05**: handoff + V-1 (owner=agent / Risk=low / depends_on=全完了)

## 👤 Human タスク
- [ ] **H-01**: C-3 ゲート
- [ ] **H-02**: (opt-in) install + C-4 + merge
