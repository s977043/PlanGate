# TASK-0116 EXECUTION TODO

## 🤖 Agent タスク

- [ ] **T-01**: 既存 release 関連 docs / commands / scripts 把握、PocketEitan Phase 5 参照 (owner=agent / Risk=low / 🚩 既存資産マップ)
- [ ] **T-02**: `scripts/check-tag-main-parity.sh` (POSIX sh、`^{commit}` peel) (owner=agent / Risk=medium / depends_on=T-01 / 🚩 比較動作)
- [ ] **T-03**: `docs/release-process.md` Iron Law + 検証フロー (owner=agent / Risk=low / depends_on=T-02 / 🚩 Human 運用可能)
- [ ] **T-04**: `.claude/rules/responsibility-classes.md` §publish 責務分界 link 追記 (owner=agent / Risk=medium / depends_on=T-03 / 🚩 maintenance window 経由)
- [ ] **T-05**: `tests/extras/ta-18-tag-main-parity.sh` fixture 3 case (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-18 全 PASS)
- [ ] **T-06 (stretch)**: `bin/plangate doctor` 統合 (owner=agent / Risk=medium / depends_on=T-02 / 🚩 C-3 判断)
- [ ] **T-07**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..6 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行、stretch AC-7 採否決定)
- [ ] **H-02**: T-04 + T-06 (stretch) のため maintenance window 発行 (`scripts/check-tag-main-parity.sh` は新規ファイルで Hardening Override 対象外)
- [ ] **H-03**: C-4 + merge
- [ ] **H-04**: 次回 release で実運用 (Iron Law 適用)
