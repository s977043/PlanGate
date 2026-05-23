# TASK-0109 EXECUTION PLAN

> Source: pbi-input.md / GitHub issue #315 / Mode: **standard**
> Generated: 2026-05-22 / Codex 優先順確認 (2026-05-22): TASK-0108 → 0109

## Goal

Codex provider の「実用上は全面利用可」を **「完璧対応」** へ引き上げる。本セッションの 4+ ラウンド Codex dogfooding 実証を制度化し、外部 OSS 利用者が Codex 主導で導入する場合の **CLI 経路・hook 配線・公式 RFC** を整備。

## Constraints / Non-goals

### Constraints
- **承認境界不変**: `bin/plangate` 改修は既存挙動・既存テストを破壊しない (`PLANGATE_IMPL_AGENT:-codex` / `PLANGATE_EXTERNAL_REVIEWER:-codex` 既定不変)
- **既存テスト維持**: `tests/run-tests.sh` 101/0 + `tests/hooks/run-tests.sh` 79/0 PASS
- **後方互換**: 既存 `scripts/ai-dev-workflow` / `scripts/codex-local.sh` ラッパとの責務分界を破らない
- **dogfooding 実証ベース**: 本セッションの Codex レビュー実行パターン (`codex exec --skip-git-repo-check`) を CLI 内部実装の正本とする

### Non-goals
- Codex Cloud (codex-cloud) 連携の機能追加
- `.codex/agents/` subagent 内容追加・改修（既存 22 個で十分）
- Codex API モデル/エンドポイント変更

## Approach Overview

3 改善項目を **段階実装** (互いに依存度があるため): CX-1 (CLI wiring) → CX-2 (.codex/hooks 配線) → CX-3 (RFC)。CX-1 は gemini case と対称構造で `codex exec` 直接呼出。CX-2 は `.cursor/hooks/` の plangate-eh1/eh2 patterns を参照。CX-3 は既存 RFC 構造踏襲、CX-1/CX-2 完了後に references を含めて最終形にする。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 Checkpoint |
|---|------|--------|-------|------|--------------|
| 1 | **準備**: `.cursor/hooks/` 構造把握 + `bin/plangate` review コードパス確認 + 既存 codex case (placeholder) 抽出 | 調査メモ | AI | low | 既存資産マップ完成 |
| 2 | **CX-1 (CLI wiring)**: `bin/plangate review` の `codex` case を `codex exec --skip-git-repo-check` 直接呼出に実装。プロンプトは task の plan + review-external.md に流し、stdout を review-external.md に追記。gemini case 構造踏襲 | `bin/plangate` (review 関数内 codex case) | AI | medium | `bin/plangate review TASK-XXXX --phase c2 --reviewer codex` で実 review 生成 + 既存 gemini case regression なし |
| 3 | **CX-2a (hook adapter 設計)**: `.cursor/hooks/cursor-adapter.sh` pattern を参考に `.codex/hooks/codex-adapter.sh` (or 同等経路) 設計。`scripts/codex-local.sh` ラッパとの責務分界文書化 | `.codex/hooks/codex-adapter.sh` (新規) + `.codex/README.md` 更新 (責務分界明示) | AI | **high** (承認境界相当) | EH-1/EH-2 を Codex から呼ぶ際の block/skip 動作確認 |
| 4 | **CX-2b (hook 配線)**: `.codex/hooks/plangate-eh1-plan.sh` / `plangate-eh2-c3.sh` / `plangate-eh3-hash.sh` を Cursor 版 (`.cursor/hooks/`) を翻訳して追加。本 hook が `scripts/hooks/check-plan-exists.sh` / `check-c3-approval.sh` / `check-plan-hash.sh` を呼び出す形式（EH-3 配線で承認境界実行正本も Codex 経由で尊重） | `.codex/hooks/plangate-eh1-plan.sh` / `plangate-eh2-c3.sh` / `plangate-eh3-hash.sh` (新規) | AI | high | smoke test: Codex 経由 Edit で EH-1 block / C-3 通過後 skip / EH-3 hash mismatch block |
| 5 | **CX-3 (provider-codex RFC)**: `docs/rfc/provider-codex.md` 新規。既存 RFC (provider-cursor.md) 構造踏襲、CX-1/CX-2 完成後の正本ポインタ集約 (`.codex/`, `scripts/ai-dev-workflow`, `scripts/codex-local.sh`, `docs/codex-cloud/`, 新 hooks/) | `docs/rfc/provider-codex.md` (新規) | AI | low | RFC が既存 3 RFC と structure 整合 |
| 6 | **テスト**: CLI review codex case test + hook adapter test を tests/extras/ + tests/hooks/ に追加 | `tests/extras/ta-13-codex-review.sh` (新規) / `tests/hooks/codex-adapter-test.sh` (新規) | AI | medium | 既存 tests/run-tests 101/0 + tests/hooks 79/0 維持、新規 TC 全 PASS |
| 7 | **handoff + V-1** | TASK-0109/handoff.md | AI | low | AC-1..6 全 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `bin/plangate` | CX-1 review 関数 codex case 本実装 |
| `.codex/hooks/codex-adapter.sh` | 新規 (CX-2a) |
| `.codex/hooks/plangate-eh1-plan.sh` | 新規 (CX-2b) |
| `.codex/hooks/plangate-eh2-c3.sh` | 新規 (CX-2b) |
| `.codex/hooks/plangate-eh3-hash.sh` | 新規 (CX-2b) |
| `.codex/README.md` | 責務分界追記 (CX-2a) |
| `docs/rfc/provider-codex.md` | 新規 (CX-3) |
| `tests/extras/ta-13-codex-review.sh` | 新規 (CX-1 検証) |
| `tests/hooks/codex-adapter-test.sh` | 新規 (CX-2 検証) |
| `tests/hooks/run-tests.sh` | dispatcher 追記 (新規 test の呼び出し) |
| `docs/working/TASK-0109/handoff.md` | WF-05 |

## Testing Strategy

- **Unit (CLI)**: CX-1 codex case を mock (`codex exec` を fake) で実行、review-external.md 追記確認
- **Unit (hook adapter)**: CX-2 EH-1/EH-2 を fixture 経由でテスト、cursor-adapter-test.sh 構造踏襲 (PASS 79 件の枠内)
- **Integration**: 実 codex CLI 環境でのみ動作確認 (CI 非対応・docs/note で明示)、ローカル開発者向け
- **回帰**: 既存 `tests/run-tests.sh` 101/0 + `tests/hooks/run-tests.sh` 79/0 PASS
- **Lint**: markdownlint + shellcheck (新規 sh ファイルに対して)

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| **CX-1 codex exec の長時間応答 / CLI timeout** | medium | 既存 gemini case 構造を踏襲、timeout は呼び出し側責任で wrapping、`--timeout` 等の codex CLI オプション活用 |
| **CX-2 hook adapter の承認境界破壊** | **high** | 既存 `scripts/hooks/check-plan-exists.sh` / `check-c3-approval.sh` を**そのまま呼び出す**形式に限定、独自ロジックを追加しない |
| **CX-2 `scripts/codex-local.sh` ラッパとの責務分界曖昧化** | medium | `.codex/README.md` に責務分界表を追加 (codex-local.sh = auth 管理ラッパ / codex-adapter.sh = hook 呼出 bridge) |
| **CI 非対応の integration test が手動でしか検証できない** | low | docs/note で明示、ローカル開発者向けの自動検出 (`bin/plangate doctor` で `codex` CLI 有無検出済) で十分 |
| **CX-3 RFC の Status 表現が他 RFC と不整合** | low | provider-cursor.md / provider-gemini-cli.md / provider-opencode.md と structure 完全踏襲 |

## Questions / Unknowns

- **CX-2 hook 起動経路**: `codex` CLI 自体に hook 機構があるか、`codex-local.sh` 経由でラップするか → **要 Phase 1 調査**で確定 (T-01 で .cursor/hooks/ pattern 確認後決定)
- **CX-1 review prompt の組み立て**: gemini case と同等で十分か、Codex 特化の prompt 改善余地あるか → **gemini case 構造踏襲を仮採用**、改善余地は本 PBI 完了後の follow-up
- **CX-3 RFC の Status**: "Implemented (v8.10.0)" or "Implemented (本 PBI)" → **本 PBI 完了 commit の merged バージョンを Status に記載** (TASK-0106 patterns)

## Mode 判定

**standard** (`high-risk` 候補も検討)

- 変更ファイル数: 8-10
- 受入基準数: 6 → standard
- 変更種別: CLI 追加 + hook 配線追加 + RFC + テスト
- リスク: **中-高** (CX-2 hook adapter のみ高、CX-1/CX-3 は中-低)
- ロールバック: 容易 (各項目 additive)
- 影響範囲: Codex 経由利用者のみ、Claude Code 既定経路は不変

→ standard で進行、CX-2 着手時に critical hook 改修と判明したら mode 昇格を C-3 再確認
