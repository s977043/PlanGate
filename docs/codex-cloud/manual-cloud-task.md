# Codex Cloud 手動Task実行ガイド

> 更新日: 2026-03-22
> 関連: `docs/codex-cloud/review-summary.md`

## 目的

Codex Cloud で `exec` 相当の実装作業を行うとき、GitHubコメント自動起動は使わず、人間が Cloud task を手動起動する。実行入力は tracked な handoff packet にまとめる。

## 前提

- 対象チケットの `docs/working/TASK-XXXX/` は人間の準備用ソースとして揃っている
- 実行時に Codex Cloud が読む tracked handoff packet は `.codex/manual-cloud-task.md` とする
- C-3（人間レビュー）が完了している
- スコープ外・未解決事項が packet に明記されている

## 起動前チェック

1. `CLAUDE.md` を確認する
2. `AGENTS.md` を確認する
3. `./scripts/ai-dev-workflow TASK-XXXX plan` で plan / review / handoff draft を最新化する
4. `docs/working/TASK-XXXX/` を人間が確認し、`status.md` に `## C-3 Gate: APPROVED` を記録する
5. `./scripts/ai-dev-workflow TASK-XXXX prepare-cloud` で `.codex/manual-cloud-task.md` を再生成する
6. `.codex/manual-cloud-task.md` に scope / open questions / verification expectations を書く
7. 検証方針として「修正箇所に絞った test / lint / typecheck を優先し、task完了時は人間に承認依頼を出す」ことを packet に明記する

## Cloud task に渡す指示テンプレート

以下をベースに、TASK番号と packet の内容だけ差し替える。

```text
Read this tracked packet first:
- .codex/manual-cloud-task.md

Use only the packet contents below as the execution source of truth:
- approved scope
- pasted plan summary
- pasted todo list
- pasted test cases
- pasted status notes
- open questions and explicit non-goals

This task is C-3 approved.

Rules:
- Execute only the approved scope
- Do not start any scope expansion without user approval
- Follow the packet todo order
- Update the packet or the linked status notes with evidence as tasks complete
- During implementation, prioritize tests and checks that cover the modified area
- If information is missing or contradictory, stop and surface the question

Deliverables:
- code changes
- updated packet notes
- targeted verification evidence for the modified area
- a handoff note requesting human approval for final completion
- concise summary of risks or concerns
```

## 実行後に人間が回収するもの

- 変更ファイル一覧
- `.codex/manual-cloud-task.md` の更新内容
- 実行した検証コマンドと結果
- 人間へ引き継ぐ承認依頼メモ
- 懸念事項の有無

## この運用でやらないこと

- `@codex exec` のような GitHubコメント起動
- GitHub Action 経由での `exec` 自動化
- C-3 未承認状態での Cloud task 起動

## 補足

- GitHub上の自動化は `@codex review` のみ採用する
- 手動Cloud task は workflow-conductor の責務を置き換えるものではなく、起動経路だけを人間主導にする
- `docs/codex-cloud/` は手順書とテンプレート置き場、`.codex/manual-cloud-task.md` は実行用の tracked packet
- Cloud task 内では修正箇所の検証を優先し、本完了の判断は人間レビューに委ねる
- `./scripts/ai-dev-workflow TASK-XXXX prepare-cloud` で tracked packet を再生成できる
- `./scripts/ai-dev-workflow TASK-XXXX sync-cloud` で Cloud task 後の status / todo 同期を半自動化できる
- `prepare-cloud` は `status.md` に `## C-3 Gate: APPROVED` がある場合のみ実行する
