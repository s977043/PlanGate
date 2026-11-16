# TASK-1651 外部レビュー結果（C-2）

> 対象: PR #1654 head `02c79e00`（plan-draft.md / todo.md / test-cases.md / pbi-input.md）
> 出典: https://github.com/s977043/PlanGate/pull/1654#issuecomment-6840825865
> 判定: APPROVE（critical 0 / major 0 / minor 3 / info 1）
> C-3 で Human の明示確認が必要: D-1（`project_root` の出力を契約として認めるか）

## 指摘

| R | sev | 要旨 | 是正案 |
|---|-----|------|-------|
| R-001 | minor | AC-1 は doctor JSON 全般を対象にしているように読めるが、TC-7 が再帰検査するのは hooks scope だけ。v8.6.0 scope の例外文字列（`could not run collision check: {exc}`）には REPO 以外の絶対パスが入りうるが、検出できない | AC-1 の対象を「hooks scope の JSON」と明記し、検出できない範囲を残存脅威に書く |
| R-002 | minor | M-3 の期待値が test-cases / plan Task 5 / todo T-5 の 3 か所で食い違っている | 「M-1/M-2 は TC-7、M-3 は TC-7b（TC-03）が FAIL」に揃える |
| R-003 | minor | 「Linux では M-1 を再現できない」は不正確。CI の checkout は `/home/runner/...` なので、`isabs` と D-3 のどちらでも検出できる | 「Linux での実行は CI に依存する。検出ロジックは OS に依存しない」に直す |
| R-004 | info | ta-10:317 付近で assert のメッセージが `2>/dev/null` に捨てられている | T-5 では stderr を evidence に保存する |

事前調査（レビュアー記載）: U-1 hooks scope の detail はすべて相対パスの固定文言。U-2 `PLANGATE_PROJECT_ROOT_SOURCE` の値は `flag` / `env` / `cwd-git` / `cli-root` の識別子のみ（`bin/plangate:30-48`）。exec の T-1 で実出力により再確認する。

## 監査表（追記専用）

| R-NNN | status | reflected_in | notes |
|-------|--------|--------------|-------|
| R-001 | reflected | 本反映コミット（`Refs: R-001`） | pbi-input AC-1 / test-cases AC 表 / plan-draft「残存脅威」節 |
| R-002 | reflected | 本反映コミット（`Refs: R-002`） | test-cases 変異表 / plan-draft Task 5 / todo T-5 |
| R-003 | reflected | 本反映コミット（`Refs: R-003`） | plan-draft Testing Strategy / test-cases M-1 / review-self C1-PLAN-07 |
| R-004 | reflected | 本反映コミット（`Refs: R-004`） | todo T-5 / plan-draft Task 5 |
