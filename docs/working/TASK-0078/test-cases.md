---
task_id: TASK-0078
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0078

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5 |
| AC-6 | TC-6 |
| AC-7 | TC-7 |

## テストケース
- **TC-1**: core-contract §5-bis に capability/認証三点/commit境界(EH-9)/配線契約/exec後検証/direct-mode/統制不変/delegation_unavailable が網羅存在（grep 突合）
- **TC-2**: execute.md に F2 プリフライト本文・Error taxonomy 本文の重複が無い（§5-bis 参照のみ）
- **TC-3**: execute.md に「#245 マージ後…統合する」暫定ノートが存在しない
- **TC-4**: `git diff main -- scripts/hooks/` が空（スクリプト不変）
- **TC-5**: execute.md→core-contract §5-bis リンクが有効・参照切れなし
- **TC-6**: `sh tests/hooks/run-tests.sh` 78 passed/0 failed（挙動不変回帰）
- **TC-7**: TASK-0073 handoff の既知課題が「§5-bis 統合完了」に更新されている

## エッジケース
- E1: §5-bis 内の表/箇条書きが Markdown 構造として壊れていない（lint）
- E2: execute.md Stop rules は exec 文脈で残るが詳細は §5-bis を指す（情報重複でなく参照）
- E3: 他 doc からの execute.md/§5-bis 参照が壊れない（grep 横断）
