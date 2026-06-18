# EXECUTION PLAN — TASK-0134 (#571)

## Goal
`_review_parallel` に `--progress` opt-in のライブ進捗表示（完了/失敗の逐次出力）を最小スコープで追加。既存挙動は完全後方互換。

## Constraints / Non-goals
- 最小スコープ: `_review_parallel` のみ。exec 並列横展開は将来。
- フル UI・token/sec はスコープ外（privacy）。
- `bin/plangate` は HO → AI 編集せず apply-script + 人間適用。

## Approach Overview（Codex 設計相談）
1. 各子プロセス起動時に **pid を保持**（または完了時に `done_NNN` sentinel を touch）し、`wait` 前のポーリングで **子の終了を検出してから** status_NNN を読む。子終了を検出後に status が空/欠落なら `failed`（未完了で status 未作成の状態とは区別する＝R-001）。新規完了の都度 `[done X/N] provider ok|failed` を出力。最後に `wait` で回収（collect は不変）。
2. `--progress` フラグ（cmd_review の引数解析）で opt-in。未指定時は従来出力を 1 文字も変えない。
3. status 破損/欠落 → `failed` 表示（安全側）。出力先 stdout・非 fail-fast（全完了待つ）。

## Work Breakdown
- **S1** cmd_review に `--progress` 引数解析を追加し `_review_parallel` へ伝播する apply-script + patch を**生成**（AI は適用しない）/ Owner: agent / Risk: 引数解析の既存互換 / 🚩HO
- **S2** `_review_parallel` の wait 前に status ポーリング + 逐次表示ロジックの patch を生成 / Owner: agent / Risk: ポーリングの busy-loop / 🚩HO
- **S3** 後方互換テスト（--progress 無しで既存出力一致）の test 手順を test-cases に定義 / Owner: agent

## Files / Components to Touch
- `bin/plangate`（**HO → apply-script 経由・人間適用**。`_review_parallel` L1644-1854 + cmd_review 引数解析）

## Testing Strategy
- 機械: `--progress` 有/無の出力 diff（無し=既存一致）、reviewer 2本 stub での `[done X/N]` 出現確認、status 破損時 failed 表示
- レビュー: privacy（出力に token/sec/抜粋が無い）、POSIX sh 互換
- doctor / 既存 review テストの回帰

## Risks & Mitigations（内容 / 検証手段 / Fallback）
- R1 HO 適用漏れ / doctor + apply-script 未適用なら V-1 PASS にしない / apply-script 再提示
- R2 ポーリングの busy-loop で CPU 浪費 / `sleep 1` 間隔 + 完了時即 break / 間隔調整
- R3 既存出力破壊（後方互換違反）/ --progress 未指定時の diff テスト / 差分が出たら opt-in 分岐を見直す

## Metrics Evidence
- 対象「変更関数」: 実数 2（cmd_review 引数解析 + _review_parallel）/ 見積もり 2 / ratio 1.0 → 採用。

## Questions / Unknowns
- exec 並列への横展開 → 本 PBI スコープ外（_review_parallel で実証後、別 PBI で検討）。

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 1（bin/plangate）だが HO・承認境界 → **最低 high-risk 強制**
- 受入基準数: 5 → standard
- 変更種別: CLI 実行系・承認境界（bin/plangate）→ high-risk
- リスク: 中（後方互換・POSIX 互換・privacy）
- **最終判定**: high-risk（lite_eligible=false・人間 C-3 必須・autonomous APPROVE 不可。bin/plangate は HO → exec で AI 編集せず apply-script + 人間適用）
