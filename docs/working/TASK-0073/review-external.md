---
task_id: TASK-0073
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3 外部レビュー — TASK-0073（F2）

high-risk のため V-3 必須。Codex 実行。Gemini は出力不全（skill 競合警告のみ・
実質レビューなし）→ Codex 主体で判定（P4 同様の前例運用）。

## 判定: Codex=REJECT(Critical2/Major4) → fix-loop

## Critical（修正必須）

| # | 指摘 | 修正方針 |
|---|------|---------|
| CR-1 | EH-9 が文字列包含のみで回避可能（`git -c .. commit` / `command git` / `env=x git commit` / `git -C path` / `gh pr merge` / `sh -c 'git commit'` / alias）。「決定論・回避不能」契約未達 | git 起動の堅牢トークン検出（env 前置/`command`/`-c`/`-C` 許容 + commit/push サブコマンド）+ `gh ... merge`/`gh repo sync` 追加。alias は解決不能なため残存制約として明記し exec 後検証（二段目）を fail-closed バックストップに |
| CR-2 | `PLANGATE_HOOK_CMD` env 優先は偽装可能。PreToolUse 信頼境界は stdin JSON 実 tool input であるべき | hook 文脈では **stdin JSON を正本**、env は CLI テスト専用に降格（stdin 優先順へ並べ替え） |

## Major

| # | 指摘 | 修正 |
|---|------|------|
| MJ-1 | fail-open: todo.md メタ→env の機械配線が差分に無く宣言漏れで無効化 | 配線契約を明記（orchestrator が `delegation_commit_boundary` を読み env 注入）+ exec 後検証は todo.md メタを直接読む fail-closed バックストップ |
| MJ-2 | 認証三点チェックの実装・期待値ソース・停止条件が無く問題3 は NL 契約のまま | 最小決定論スクリプト `check-auth-preflight.sh` を新設（gh active / git config user / remote を検証、期待値ソースを定義） |
| MJ-3 | `no-commit` 宣言下 default=warn は弱い（問題2 を検知ログ付き許可で再発） | 宣言下は **default=block**（bypass のみ override）。warn は廃止 |
| MJ-4 | `emit_judgment` が JSON エスケープせず任意文字列埋め込み（将来 `$cmd` 混入で破壊） | reason を JSON エスケープ（jq -n --arg、無ければ手動エスケープ） |

## Minor

- grep fallback の JSON escape 脆弱性（EH-3 と同水準へ）
- audit log にコマンド全文 → command class + hash + task id に抑制（秘密漏洩防止）
- F1 統合 handoff に「統合時にどちらを正本/削除するか」明記

## 対応（fix-loop 完了）

- CR-1: EH-9 を堅牢化（`git -c`/`-C`/env 前置/`command git`/`gh pr merge`/
  `sh -c`/`git ci` を網羅 block）。alias 残存制約は exec 後検証で fail-closed
- CR-2: stdin JSON を正本化、env は CLI テスト fallback に降格
- MJ-1: 配線契約明記（orchestrator が todo.md メタ→env 注入、後検証は
  todo.md メタ直読の fail-closed）
- MJ-2: `check-auth-preflight.sh` 新設（gh active/git user.email/origin、
  PLANGATE_EXPECTED_GH_ACCOUNT 厳格一致、exit!=0 停止）
- MJ-3: 宣言下 default=block（warn 廃止）
- MJ-4: emit_judgment を JSON エスケープ（json_escape）
- Minor: audit log は command class+hash（全文非記録）、F1 統合の正本/削除側を
  handoff 明記
再 V-1: AC-1〜7 + CR/MJ/Minor 全 PASS、hook 66/0、CI lint 0。
