# TASK-1197 TEST CASES（C-3 CONDITIONAL / c3.json 未発行）

共通条件: `git init` + linked worktree の mktemp sandbox。`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_FILE` / `PLANGATE_SKIP_REASON` / `PLANGATE_BYPASS_HOOK` を unset。入力は `{"hook_event_name":"PreToolUse","tool_name":<tool>,"tool_input":{"file_path":<path>}}`。

期待 block は rc=2 + `plan.md edited without TASK context`、期待 allow は rc=0 + `PLAN_CREATE_ALLOW`。検証コマンドは特記なき限り `sh tests/extras/ta-NN-eh3-plan-create.sh`（CI では `sh tests/run-tests.sh` 経由）。期待値の出所は Human 方針、issue AC、または既存実装で、規約由来のものはない。

## 受入基準 → テストケース マッピング

| 受入基準 | テストケース | 備考 |
| --- | --- | --- |
| AC-1 | TC-D01 | doc |
| AC-2 | TC-D02 | doc |
| AC-3 | TC-05, TC-06, TC-07, TC-M01 | 変異注入 |
| AC-4 | TC-D03, TC-04 | 許可条件の明示 + 禁止の明文化 |

## Verification Trace

| Trace Type | 内容 | Source / Evidence | テストケース |
| --- | --- | --- | --- |
| AC | AC-1〜4 | issue #1197 | 上表 |
| Invariant | INV-01: 既存 plan.md は no-task で変更不可 | Human 方針、既存 TC-P06 | TC-02, TC-03 |
| Invariant | INV-02: 判定不能は block | `mode-classification.md` 安全側 | TC-E01〜E05 |
| Contract | CONTRACT-01: STRICT は no-task 一律 block | hook コメント | TC-14 |
| Regression | REG-01: linked worktree での block（#1277） | ta-80 | TC-06, TC-11 |
| Regression | REG-02: 表記揺れ迂回（#1101） | ta-65 | TC-09 |
| Conditional | CR-01: 非機能（ハング不可） | #1101 Step 7 | TC-E06 |

## テストケース一覧

| ID | 前提 | tool / 対象 | 期待 | Trace | 変更前との差 |
|---|---|---|---|---|---|
| TC-01 | TASK-A に plan も approvals も履歴もない | Write `docs/working/TASK-A/plan.md` | allow | 方針 | 変更前は block（**差分を示す主ケース**） |
| TC-02 | plan あり | Write 同パス | block | INV-01 | 対照 |
| TC-03 | plan あり | Edit 同パス | block | INV-01 | 対照 |
| TC-04 | plan なし | Edit 同パス、MultiEdit 同パス（MultiEdit は settings の matcher 外。hook の直接実行でのみ測定） | block | AC-4 | 対照 |
| TC-05 | plan なし、`approvals/c3.json` が正常 JSON | Write | block | AC-3 | 変異 M1 で差が出る |
| TC-06 | plan なし、他の linked worktree に c3.json | Write | block | AC-3, REG-01 | 変異 M2 で差が出る |
| TC-07 | plan なし、壊れた c3.json / 空の `approvals/` 内ファイル | Write | block | AC-3 | 変異 M1 で差が出る |
| TC-08 | plan を commit 後に削除 | Write | block | 方針 | 変異 M4 で差が出る |
| TC-08b | approvals を `git stash -u` で退避 | Write | block | 方針 | plain `rev-list` では素通りする |
| TC-08c | 側枝で approvals を追加削除し、`--no-ff` merge 後に branch 削除 | Write | block | 方針 | plain `rev-list` では素通りする |
| TC-08d | approvals を `stash -u` で退避後、さらに stash して `stash@{1}` へ押し下げる | Write | block | 方針 | `--reflog` 除去で差が出る |
| TC-08e | 未 merge の側枝で approvals を commit し、枝を削除 | Write | block | 方針 | `--reflog` 除去で差が出る |
| TC-08f | plan の履歴あり、hook の cwd がサブディレクトリ | Write | block | 方針 | `top` または cwd 固定の除去で差が出る |
| TC-08g | `--depth 1` の clone で、切り捨てた履歴にだけ plan がある | Write | block | R3-1 | shallow 判定の除去で差が出る |
| TC-09 | plan なし | `.//docs/working/TASK-A/./plan.md`, `TASK-B/../TASK-A/plan.md` | 正規形が条件を満たすなら allow、字句不一致や `..` 残りは block。結果を実測で固定 | REG-02 | 許可境界の確認 |
| TC-10 | plan なし | `docs/plan.md`, `docs/working/PBI-1/plan.md`, `docs/working/TASK-A/x/plan.md` | block | 方針 | 変異 M6 で差が出る |
| TC-11 | linked worktree 内、条件充足 | Write（`.claude/worktrees/<n>/` 配下と repo 外の両方） | allow | REG-01 | 変更前は block |
| TC-11b | worktree root の祖先に symlink がある（`pwd -P` で正規化しない mktemp パス）、条件充足 | Write | allow | R2-4 | 全パス字句比較の再導入で差が出る |
| TC-12 | plan なし | `task-a/plan.md`, `TASK-A/PLAN.md`, 全角 `ＴＡＳＫ-A` | block | 方針 | 変異 M6 で差が出る |
| TC-13 | plan が dangling symlink（移動先に plan なし）、親 dir が別 TASK への symlink（移動先に plan なし。main と linked worktree の両方） | Write | block | 方針 | 変異 M7 で差が出る |
| TC-14 | 条件充足、`PLANGATE_HOOK_STRICT=1` | Write | block | CONTRACT-01 | 対照 |
| TC-15 | 条件充足、maintenance.json あり | Write | block | doc-light の優先順 | 対照 |
| TC-16 | TC-01 の allow 後 | 監査ログ、skip log、`check-skip-acknowledged.sh` | event が記録され rc=0 | 方針 | 新規 |
| TC-17 | `TASK-Ab` に履歴あり（case-insensitive FS） | Write `TASK-aB/plan.md` | block | 方針 | `:(icase)` 除去で差が出る |

## Edge Cases

| ID | 分類 | 入力 | 期待（fail-closed） |
|---|---|---|---|
| TC-E01 | 異常系 | stdin なし、`PLANGATE_HOOK_FILE` で対象指定（Codex / 手実行形） | block（tool_name 不明） |
| TC-E02 | 異常系 | jq 不在 | block |
| TC-E03 | 異常系 | git 不在 / git 失敗 / 非 git ディレクトリ | block |
| TC-E04 | 異常系 | python3 不在 | block |
| TC-E05 | 異常系 | payload の tool_name が空・null・数値 | block |
| TC-E06 | 非機能 | `rev-list` が timeout を超えるよう差し替えた git | ハングせず block |
| TC-E07 | 境界 | パスが存在しない prunable worktree が混在 | 残りを走査し allow、skip 件数を監査ログに記録。**残存脅威として明示** |
| TC-E08 | 異常系 | 監査ログまたは skip log が read-only（各 1 回）、許可ブロック内で想定外エラー | rc=2（rc=1 にしない） |
| TC-E09 | 境界 | locked でパスが読めない worktree | block |

## 変異注入

各変異は関数本体でなく call site を壊し、対応 TC の FAIL を確認する。

| ID | 変異 | 検出 TC |
|---|---|---|
| TC-M01（M1） | 当該 worktree のトークン検査を除去 | TC-05, TC-07（**AC-3 の実証**） |
| M2 | 他 worktree 走査を除去 | TC-06 |
| M3 | `lexists` 検査を除去 | TC-02 |
| M4 | 履歴検査を除去 | TC-08 |
| M5 | tool_name 検査を除去 | TC-03, TC-04 |
| M6 | パスの厳密一致を除去 | TC-10, TC-12 |
| M7 | 字句 / 物理の一致と symlink 検査を除去 | TC-13 |
| M8 | git 失敗時を allow へ変更 | TC-E03 |
| M9 | STRICT / maintenance 検査を除去（条件 1） | TC-14, TC-15 |
| M10 | common dir 検査を除去（条件 4。残す場合のみ） | 別 repo を指す TC を exec で追加 |
| M11 | 監査記録を除去（条件 8） | TC-16 |
| M12 | timeout を除去 | TC-E06 |
| M13a | `--full-history` のみ除去 | TC-08b または TC-08c（実測で固定） |
| M13b | `:(icase)` のみ除去 | TC-17 |
| M13c | `--reflog` のみ除去 | TC-08d, TC-08e |
| M14 | prunable skip の監査件数を除去、または注記なしも skip | TC-E07 |
| M15 | 書き込み失敗時の rc=2 を除去 | TC-E08 |
| M16 | locked の block を skip へ変更 | TC-E09 |
| M17 | shallow 判定を除去 | TC-08g |
| M18 | `lstat` の入力を解決前パスから `_phys_target` へ変更 | TC-13 |

## ドキュメント検証

| ID | 検証 | 期待 |
|---|---|---|
| TC-D01 | `rollout-policy.md` に起動条件の節がある | `grep -F` で節見出し 1 件以上（positive control: 既存見出しを同時に検出） |
| TC-D02 | no-task 挙動 3 分岐（作成 / 再起動案内 + escalate / `gates.c1` の虚偽申告禁止）の記述 | 目視 + 語の `grep -F` |
| TC-D03 | CLI、Bash、BYPASS、消して再作成の禁止と #1104 open の記述 | 同上 |

## Convention Evidence

該当なし。

## 自動化可否

| テストケース | 自動化 | 理由 / 代替手段 |
|---|---|---|
| TC-01〜16, E, M | 可 | — |
| 実 Claude Code の Write payload | 不可 | H-02 後に実 Write 1 回で `PLAN_CREATE_ALLOW` を確認し evidence に保存 |
| TC-D02 の意味判定 | 一部不可 | C-4 で目視。語の grep は意味を保証しないと明記 |

## 検証結果（V-1 で記入）

未実施。
