# TASK-XXXX 作業ステータス

> 最終更新: YYYY-MM-DD HH:mm
> 現在フェーズ: {brainstorm | plan | C-1 | C-2 | C-3 待ち | exec | verify（L-0 / V-1〜V-4）| PR 作成済 | C-4 待ち | done | BLOCKED}
> モード: {ultra-light / light / standard / high-risk / critical}
> 発行時点 SHA (issued_at_commit): {完了資産として発行した時点の commit SHA}

> 現在フェーズの値域は `INDEX.md` と共通（正本: `.claude/rules/working-context.md`）。
> 本ファイルに書く commit 数 / 変更ファイル数 / 未 push ブランチ数は
> **`issued_at_commit` 時点の測定値**であり契約値ではない
> （完了資産自身のコミットで必ずずれる）。SHA を書かない場合は、完了資産を
> コミットしたあとに再測定して更新すること。

## フェーズ履歴

> **日時は `YYYY-MM-DD HH:mm`（分まで）必須**（#463）。日付のみ・時刻欠落は不可。

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| YYYY-MM-DD HH:mm | A: PBI INPUT | 作成完了 |
| YYYY-MM-DD HH:mm | B: plan 生成 | plan/todo/test-cases 生成 |
| YYYY-MM-DD HH:mm | C-3 Gate | APPROVED / CONDITIONAL / REJECTED |
| YYYY-MM-DD HH:mm | D: exec | 実装完了 |
| YYYY-MM-DD HH:mm | V-1 | PASS / FAIL / WARN |

## 全体構成（PR 一覧）

| PR | ブランチ | 状態 |
|----|---------|------|
| #NNN | feat/task-xxxx | OPEN / MERGED |

## 残タスク

- [ ] {タスク}

## 計画からの変更点

- {リネーム・削除・設計変更などの差分}

## V 系ステップ進捗

| ステップ | 結果 |
|---------|------|
| L-0 | — |
| V-1 | — |
| V-2 | — |
| V-3 | — |
| V-4 | — |

## 次の作業（Claude Code プロンプト）

{コンテキスト・背景・具体的タスクを含む次回用プロンプト}
