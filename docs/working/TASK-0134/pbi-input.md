# PBI INPUT PACKAGE — TASK-0134 (#571)

## Context / Why
Gemma Cookbook apps/concurrent 取り込み検討の**唯一の実質ギャップ**。PlanGate の可視化（metrics/status/timeline/render）は全て事後・静的で、並列レビュー実行**中**のライブ進捗が無い。`bin/plangate` の `_review_parallel` は各 reviewer を `&` 起動し `status_NNN` に exit code を書くが、`wait` で一括待機するため完了/失敗が逐次見えない。

## What (Scope)
### In scope（Codex 相談で最小確定）
- `_review_parallel` に `--progress` opt-in 時の逐次進捗表示を追加（`wait` 前に status_NNN ポーリング → `[done X/N] provider ok|failed`）
- 既存 collect/assemble ロジックは不変（wait は回収用に残す）
- 出力先 stdout（既存 "Starting reviewer" と同ストリーム・--progress 時のみ）

### Out of scope
- フル dashboard UI / Rich Live TUI
- token/sec・throughput（metrics-privacy 違反）
- exec 並列への横展開（将来・別 PBI）
- llama-server / file-based 通信等デモ固有要素

## 受入基準
- AC-01: `--progress` 指定時、各 reviewer 完了の都度 `[done X/N] provider ok|failed` が出力される
- AC-02: `--progress` 未指定時は既存出力と完全に同一（後方互換）
- AC-03: collect/assemble 結果（R-NNN 集約・decision-log parallel_review）が従来と不変
- AC-04: 進捗表示は provider 名・完了数・ok/failed のみ（token/sec/出力抜粋を含まない＝privacy遵守）
- AC-05: 子終了検出後に status ファイル破損/欠落なら `failed`（未完了で未作成の状態と区別・Refs R-001）
- AC-06: 引数互換（併用順序・未知オプション従来エラー・progress 漏れなし・Refs R-002）

## Estimation Evidence
- Risks: `bin/plangate` は HO → AI 編集不可・apply-script + 人間適用。POSIX sh 互換必須。
- Unknowns（Codex Q4）: 出力先(stdout/stderr) / fail-fast 有無 / exec 横展開 → 本 PBI は _review_parallel・stdout・非fail-fast に確定。
- Mode 見込み: **high-risk**（承認境界 `bin/plangate`・HO）。lite_eligible=false・人間 C-3 必須・autonomous 不可。
