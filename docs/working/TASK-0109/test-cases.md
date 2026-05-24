# TASK-0109 テストケース定義

> Source: pbi-input.md (AC) / plan.md / Generated: 2026-05-22

## 受入基準 → TC マッピング

| AC | TC IDs |
|----|--------|
| AC-1: `bin/plangate review --reviewer codex` で実 review 実行 + review-external.md 追記 | TC-01, TC-02 |
| AC-2: .codex/hooks/ 配線で Codex 経由 Edit/Write が EH-1/EH-2/EH-3 を尊重 | TC-03, TC-04, TC-05, **TC-05b** |
| AC-3: docs/rfc/provider-codex.md 存在 + Status: Implemented + 正本ポインタ | TC-06 |
| AC-4: README Provider 表で Codex 行が「完全対応 / exec 既定」のまま | TC-07 |
| AC-5: 既存テスト regression なし (CLI 101/0 + Hook 79/0) | TC-08 |
| AC-6: docs/index.md/README の Requirements 表で Codex CLI 用途が新規実装と一貫 | TC-09 |

## テストケース一覧

### CX-1 (CLI review wiring)

| ID | 前提 | 入力 | 期待 | 種別 |
|----|------|------|------|------|
| TC-01 | fake codex CLI (mock) を PATH に置く | `bin/plangate review TASK-XXXX --phase c2 --reviewer codex` | review-external.md に追記、exit 0 | unit |
| TC-02 | gemini case が並存 | `PLANGATE_EXTERNAL_REVIEWER=gemini bin/plangate review ...` | 既存 gemini 動作不変 | regression |

### CX-2 (.codex/hooks 配線)

| ID | 前提 | 入力 | 期待 | 種別 |
|----|------|------|------|------|
| TC-03 | `.codex/hooks/plangate-eh1-plan.sh` 経由で非 plan ファイル Edit (PLANGATE_HOOK_TASK 未設定、no plan.md) | hook 起動 | exit 2 (EH-1 block) | unit |
| TC-04 | C-3 APPROVED の TASK 文脈で hook 起動 | EH-2 経由 Edit | exit 0 (skip) | unit |
| TC-05 | EH-3 配線が Codex 経由で発火することを **codex CLI fixture stub** で deterministic 検証 (R-codex#3: manual integration は補助) | `tests/hooks/codex-adapter-test.sh` で stub codex 経由 `bin/plangate review` 実行、plan_hash mismatch で block 確認 | block exit + 補助として実 codex でも smoke 確認 |
| **TC-05c (R-gemini#1 CRITICAL)** | `bin/plangate review --reviewer codex` 実行時に `--sandbox read-only` フラグが付与されることを検証 | `grep -nE 'sandbox.+read-only' bin/plangate` + stub codex で argv ログ確認 | read-only sandbox 付与 確認 |
| **TC-05d (R-gemini#2/3)** | `timeout` 600s wrap + `--output-last-message` 利用を検証 | `grep -nE 'timeout.*codex\|output-last-message' bin/plangate` | 両方 該当 |
| **TC-05b** | `.codex/hooks/plangate-eh3-hash.sh` 経由で plan_hash mismatch ファイル Edit | hook 起動 | exit 2 (EH-3 block、承認境界実行正本が Codex 経由でも尊重) | unit |

### CX-3 + Provider 表整合

| ID | 検証 | コマンド | 期待 |
|----|------|---------|------|
| TC-06 | `docs/rfc/provider-codex.md` 実在 + Status: Implemented + .codex/.codex-cloud/scripts/codex-local.sh 等への正本ポインタ含む | `test -f docs/rfc/provider-codex.md && grep -c 'Status.*Implemented\|\.codex' docs/rfc/provider-codex.md` | exit 0 + grep 該当 |
| TC-07 | README.md / README_en.md の Provider 表で Codex 行が PR #290 反映状態を維持 | `grep -E 'Codex CLI.*完全対応' README.md` | 該当 1 件 (PR #290 表記) |

### 回帰 + Requirements 整合

| ID | 検証 | コマンド | 期待 |
|----|------|---------|------|
| TC-08 | 既存テスト regression なし | `sh tests/run-tests.sh && sh tests/hooks/run-tests.sh` | 101+α/0 + 79+α/0 PASS |
| TC-09 | Requirements 表 (#311 で導入済) の Codex CLI 記述が CX-1 wiring 後も整合 | `grep -c "Codex CLI" docs/index.md README.md README_en.md` | 各 1 件以上 |

### Edge cases

- TC-10: CX-1 で codex CLI 未インストール時 → 既存 gemini case 同等の error メッセージ + exit code
- TC-11: CX-2 hook adapter で stdin が非 tty (CI 環境) でも動作
- TC-12: CX-1 review prompt に日本語/UTF-8 文字含む長い plan.md でも codex exec が正常応答 (smoke test, optional)
