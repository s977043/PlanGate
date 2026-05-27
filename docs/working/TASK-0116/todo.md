# TASK-0116 EXECUTION TODO

## 🤖 Agent タスク

- [ ] **T-01**: 既存 release 関連 docs / commands / scripts 把握、PocketEitan Phase 5 参照 (owner=agent / Risk=low / 🚩 既存資産マップ)
- [ ] **T-02 (R-001/R-004)**: `scripts/check-tag-main-parity.sh` (POSIX sh、冒頭で `git fetch origin main` (stale 防止)、`^{commit}` peel (annotated/lightweight 両対応)) (owner=agent / Risk=medium / depends_on=T-01 / 🚩 fetch + 比較動作)
- [ ] **T-03 (R-002)**: `docs/release-process.md` Iron Law + 検証フロー + 失敗時 `--force-with-lease` + ref 明示貼り替え手順 (Human 操作 + 監査ログ + 再確認段階フロー) (owner=agent / Risk=low / depends_on=T-02 / 🚩 Human 運用可能、--force-with-lease 明記)
- [ ] **T-04 (R-003)**: `.claude/rules/responsibility-classes.md` §publish 責務分界 link 追記 (**owner=human (PR patch)**, Risk=medium / depends_on=T-03 / 🚩 Human-owned patch、TASK-0112 と同方針)
- [ ] **T-05 (R-004)**: `tests/extras/ta-18-tag-main-parity.sh` fixture **5 case** (一致/不一致/tag 不在/annotated peeling/lightweight peeling) (owner=agent / Risk=low / depends_on=T-02 / 🚩 ta-18 全 5 case PASS)
- [ ] ~~T-06 stretch~~ (本 PBI から削除、V2 候補に降格 / Codex 9 PBI review 反映)
- [ ] **T-07**: handoff.md + V-1 (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..6 PASS)

## 👤 Human タスク

- [ ] **H-01**: C-3 ゲート (`approvals/c3.json` 発行) — stretch AC-7 削除済、scope 確定
- [ ] **H-02**: T-04 + T-06 (stretch) のため maintenance window 発行 (`scripts/check-tag-main-parity.sh` は新規ファイルで Hardening Override 対象外)
- [ ] **H-03**: C-4 + merge
- [ ] **H-04**: 次回 release で実運用 (Iron Law 適用)
