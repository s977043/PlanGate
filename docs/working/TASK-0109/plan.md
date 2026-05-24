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
- **🚨 CRITICAL (R-gemini#1)**: review 用 `codex exec` 呼出時は `--sandbox read-only` を必ず付与。review プロセスがファイル改変できないことを保証する
- **R-gemini#2**: `codex` CLI 自体に `--timeout` オプションはないため、shell `timeout` コマンドで wrap (デフォルト 600s)
- **R-gemini#3**: review 出力は `--output-last-message <file>` で純粋なレビュー内容のみをファイル出力し、stdout 解析の脆さを回避
- **R-gemini#5**: shim/symlink 経由でも repo root を正しく解決するため `CDPATH= cd -- "$(dirname -- "$0")" && pwd` パターンを採用

### Non-goals
- Codex Cloud (codex-cloud) 連携の機能追加
- `.codex/agents/` subagent 内容追加・改修（既存 22 個で十分）
- Codex API モデル/エンドポイント変更

## Approach Overview

3 改善項目を **段階実装**: **T-01 (Phase 1 調査) を CX-2 着手前のハードゲート化** (R-codex#1 反映)。CX-1 (CLI wiring) → **T-01 hook 発火経路調査・確定** → CX-2 (.codex/hooks 配線、経路確定後のみ) → CX-3 (RFC)。

**T-01 ハードゲート条件** (これを満たさない限り CX-2 は着手不可):
1. `codex` CLI native の hook 機構 (Cursor `hooks.json` 相当) が存在するか確認
2. 存在しない場合、`scripts/codex-local.sh` ラッパ経由で hook を fan-out する設計に切り替える (.codex/hooks/ 配置ではなく `scripts/codex-local.sh` への bridge 追加)
3. **EH-3 は「翻訳」ではなく「新規設計」**として扱う (R-codex#2)。`.cursor/hooks.json` には EH-1/EH-2 のみで EH-3 不在のため、`scripts/hooks/check-plan-hash.sh` の Codex 経路発火条件を新規に設計する
4. T-01 の結論は status.md / handoff.md に記録、不確定なまま CX-2 着手しない

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 Checkpoint |
|---|------|--------|-------|------|--------------|
| 1 | **準備 + 🚨 hook 発火経路ハードゲート (R-codex#1/2)**: (a) `.cursor/hooks/` 構造把握 + `bin/plangate` review コードパス確認、(b) **`codex` CLI native hook 機構の有無確定**、(c) 無ければ `scripts/codex-local.sh` 経由 bridge 設計、(d) EH-3 を新規設計として扱う設計メモ、(e) `scripts/codex-local.sh` の現状 (`exec codex`) を fan-out 構造に変更可能か実装可否確認 | 調査メモ + 経路確定 | AI | **high** (CX-2 全 step の前提条件) | hook 発火経路確定 (経路名・bridge 設計・EH-3 新規設計方針を全て status.md に記録) → 確定後のみ CX-2 着手可 |
| 2 | **CX-1 (CLI wiring)**: `bin/plangate review` の `codex` case を `timeout 600 codex exec --skip-git-repo-check --sandbox read-only --output-last-message <tmpfile>` で実装 (R-gemini#1/2/3)。プロンプトは task の plan + review-external.md に流し、tmpfile を review-external.md に追記。gemini case 構造踏襲。**Codex CLI 未インストール時の error handling 追加** (R-gemini#10) | `bin/plangate` (review 関数内 codex case) | AI | medium | `bin/plangate review TASK-XXXX --phase c2 --reviewer codex` で実 review 生成 + read-only sandbox 検証 + timeout 機能 + 既存 gemini case regression なし |
| 3 | **CX-2a (hook adapter 設計)**: `.cursor/hooks/cursor-adapter.sh` pattern を参考に `.codex/hooks/codex-adapter.sh` (or 同等経路) 設計。`scripts/codex-local.sh` ラッパとの責務分界文書化 | `.codex/hooks/codex-adapter.sh` (新規) + `.codex/README.md` 更新 (責務分界明示) | AI | **high** (承認境界相当) | EH-1/EH-2 を Codex から呼ぶ際の block/skip 動作確認 |
| 4 | **CX-2b (hook 配線、T-01 経路確定後のみ)**: EH-1/EH-2 は Cursor 版翻訳可、**EH-3 は新規設計** (R-codex#2: Cursor 版に EH-3 不在のため設計コピー不可)。bridge は T-01 で確定した経路に配置 (.codex/hooks/ or scripts/codex-local.sh fan-out)。本 bridge が `scripts/hooks/check-plan-exists.sh` / `check-c3-approval.sh` / `check-plan-hash.sh` を呼び出し、承認境界実行正本を尊重。**shim symlink 解決**: `CDPATH= cd -- "$(dirname -- "$0")" && pwd` パターン (R-gemini#5) | bridge scripts (新規・配置は T-01 確定) | AI | high | smoke test: Codex 経由 Edit で EH-1 block / C-3 通過後 skip / EH-3 hash mismatch block + shim 経由でも repo root 解決 |
| 5 | **CX-3 (provider-codex RFC)**: `docs/rfc/provider-codex.md` 新規。既存 RFC (provider-cursor.md) 構造踏襲、CX-1/CX-2 完成後の正本ポインタ集約 (`.codex/`, `scripts/ai-dev-workflow`, `scripts/codex-local.sh`, `docs/codex-cloud/`, 新 hooks/) | `docs/rfc/provider-codex.md` (新規) | AI | low | RFC が既存 3 RFC と structure 整合 |
| 6 | **テスト (R-codex#3)**: CLI review codex case test + hook adapter test を tests/extras/ + tests/hooks/ に追加。**TC-05 を wrapper 経由 deterministic 化**: codex CLI を fixture stub に差し替え、`bin/plangate review` 経由で EH-3 発火を deterministic 検証 (manual integration は補助のみ) | `tests/extras/ta-13-codex-review.sh` (新規) / `tests/hooks/codex-adapter-test.sh` (新規) | AI | medium | 既存 tests/run-tests 101/0 + tests/hooks 79/0 維持、新規 TC 全 PASS、TC-05 が wrapper stub で deterministic 実行 |
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
| `README.md` / `README_en.md` / `docs/index.md` | AC-4/AC-6 (Codex provider 表記更新、R-codex#4) |
| `docs/rfc/provider-codex.md` (Role Mapping 表追加, R-gemini#6) | CX-3 内に Codex Agent ↔ PlanGate Role mapping 表を含める |

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
| **🚨 review 用 codex プロセスがファイル改変する** | **CRITICAL** | `--sandbox read-only` 必須付与 (R-gemini#1)。Constraints / T-02 で固定 |
| **codex exec の応答が長時間で CI/local hang** | medium | shell `timeout 600` で wrap (R-gemini#2)。codex CLI に `--timeout` なし |
| **stdout 解析の脆さ (思考メッセージ混在)** | medium | `--output-last-message <file>` でクリーンなレビュー出力のみファイル化 (R-gemini#3) |
| **shim symlink 経由で repo root 誤検出** | medium | `CDPATH= cd -- "$(dirname -- "$0")" && pwd` (R-gemini#5) |
| **CX-2 hook 発火経路が未確定のまま実装着手** | **high** | T-01 をハードゲート化、経路確定まで CX-2 凍結 (R-codex#1) |
| **EH-3 を Cursor 翻訳と誤認** | high | Cursor 版に EH-3 不在のため新規設計として扱う (R-codex#2)。T-04 で明記 |
| **TC-05 manual のみで AC-2 検証が弱い** | medium | wrapper stub で deterministic 化 (R-codex#3)。T-06 で実装 |

## Questions / Unknowns

- **CX-2 hook 起動経路**: `codex` CLI 自体に hook 機構があるか、`codex-local.sh` 経由でラップするか → **T-01 ハードゲート化済** (R-codex#1 反映)。経路確定まで CX-2 凍結
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
