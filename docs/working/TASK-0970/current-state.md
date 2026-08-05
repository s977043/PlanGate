# CURRENT STATE — TASK-0970

- **今どこ**: exec 完了（A-1〜A-9 済み）。C-3' = `AUTO_APPROVED`（ai-loop run-028）。
- **実装**: `scripts/sync-plugin-plangate.sh` の dst 側 stale 集計から `[ -L ]` 除外を削除
  （+ 集計側コメント追従 + 削除ループ直上の相互注記）/ `tests/extras/ta-26-plugin-sync.sh` に
  **TC-35（集計 ⊋ 削除 を検出）+ TC-36（削除 ⊊ 集計 を検出）** を追加。差分 **2 ファイル**。
- **検証**: ta-26 32 passed（exit 0）/ `run-tests.sh` **540 passed 0 failed**（baseline 538 + 2）/
  変異注入 **M-1 → TC-35 のみ FAIL・M-1' → TC-36 のみ FAIL** を実測（双方向の検出力を証明）/
  `sh -n` rc=0。AC-1〜4 すべて PASS。
- **次に何をするか**: A-10（`handoff.md` 発行 → PR 作成）は **オーガナイザー担当**
  （rubric grader + 強化セルフレビューの後）。その後 H-1 の C-4 は **Human-owned 固定**。
- **ブロッカー**: なし。
- **注意**: `plan.md` / `pbi-input.md` / `review-self.md` / `review-external.md` は
  C-3' 裁定済みのため **変更しない**（plan_hash `sha256:a32d837f…` を無効化しない）。
