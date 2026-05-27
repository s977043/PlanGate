# TASK-0109 T-01 investigation (hook 起動経路ハードゲート)

> 実施: 2026-05-28 / Mode: read-only / 結論: **CX-2 既達**

## 結論サマリ

| 元 plan の前提 | T-01 検証結果 |
|--------------|--------------|
| CX-2 hook 起動経路未確定、要 Phase 1 調査 | **✅ PR #347 で既に実装済**、CX-2 全配線完了 |
| EH-3 は Cursor 翻訳ではなく新規設計 | **`.codex/hooks/eh-bridge.sh` で実装済** (汎用 bridge) |
| `scripts/codex-local.sh` の現状 (`exec codex`) は fan-out 不能 | **不要**: Codex CLI native `hooks.json` で実装済 |

## 1. T-01 (a): `.cursor/hooks/` 構造 + bin/plangate review コードパス

- `.cursor/hooks.json` 存在、PreToolUse に EH-1/EH-2 配線
- `.cursor/hooks/plangate-eh1-plan.sh` / `plangate-eh2-c3.sh` 存在
- `bin/plangate` review 関数 (L1542-1570): `codex` case が **placeholder のまま** (CX-1 未実装)

```sh
codex)
  printf 'info: codex external review not yet wired — writing placeholder\n'
  result="[codex review placeholder — configure PLANGATE_EXTERNAL_REVIEWER=gemini to use Gemini CLI]"
  ;;
```

## 2. T-01 (b): Codex CLI native hook 機構

**結論**: ✅ **存在する** (PR #347 で実装完了)

- `.codex/hooks.json` (PreToolUse spec: https://developers.openai.com/codex/hooks)
- 5 hook 配線済 (Cursor 版より充実):
  - EH-1 check-plan-exists.sh (apply_patch|Edit|Write)
  - EH-2 check-c3-approval.sh
  - **EH-3 check-plan-hash.sh** (元 plan が「新規設計要」と想定したが、汎用 bridge で対応済)
  - EH-6 check-forbidden-files.sh
  - EH-9 check-delegation-commit-boundary.sh (Bash matcher)
- `.codex/hooks/eh-bridge.sh` (汎用 bridge、PlanGate `scripts/hooks/<name>.sh` を呼ぶ):
  - JSON stdin から tool_input.file_path を Python で抽出
  - `PLANGATE_HOOK_FILE` / `PLANGATE_HOOK_TASK` を set して既存 hook 起動
  - 終了 code / stdout JSON を Codex の `{hookSpecificOutput: {permissionDecision}}` 形式に変換
  - Reference: Claude bridge `scripts/hooks/cursor-adapter.sh` (前例)

## 3. T-01 (c): scripts/codex-local.sh 現状

```sh
#!/bin/sh
# (33 行、auth 管理 + exec codex)
# ...
exec codex "$@"
```

**fan-out 構造への変更は不要** — Codex CLI 自体が native hooks.json をサポートしているため、ラッパ層での bridge は不要。

## 4. T-01 (d): EH-3 設計

元 plan は「Cursor 版に EH-3 不在のため新規設計要」と想定したが、実際は:

- **`.codex/hooks/eh-bridge.sh` が汎用 bridge** で、EH-1/EH-2/EH-3/EH-6/EH-9 すべて同じ仕組みで動作
- EH-3 は `scripts/hooks/check-plan-hash.sh` (既存) を bridge 経由で呼ぶ
- 新規設計不要、`eh-bridge.sh` 経由で既存 hook を再利用

## 5. T-01 (e): scripts/codex-local.sh fan-out 可能性

不要 (#3 で結論済)。

## 6. CX-2 既達認定

| 要素 | plan 想定 | 実態 |
|------|----------|------|
| Codex CLI hook 機構 | 「未確定」 | ✅ `.codex/hooks.json` 配線済 |
| EH-1/EH-2 配線 | 「Cursor 版翻訳」 | ✅ eh-bridge.sh で対応済 |
| EH-3 配線 | 「新規設計要」 | ✅ 同上 (汎用 bridge) |
| shim symlink 解決 | `CDPATH= cd -- ... && pwd` | ✅ 採用済 (`.codex/hooks/eh-bridge.sh` L26) |
| 既存テスト | (なし) | ✅ `tests/extras/ta-15-codex-hook-bridge.sh` 既存 |

→ **CX-2 (Step 3a/3b) は Out of scope に格上げ**。

## 7. 残作業 (scope 縮小済)

| Step | 状態 | 内容 |
|------|------|------|
| ~~CX-2a (hook adapter 設計)~~ | ✅ DONE via PR #347 | `.codex/hooks/eh-bridge.sh` |
| ~~CX-2b (hook 配線)~~ | ✅ DONE via PR #347 | `.codex/hooks.json` |
| **CX-1 (CLI wiring)** | ⏳ TODO | `bin/plangate review` codex case を実装 |
| **CX-3 (provider-codex RFC)** | ⏳ TODO | `docs/rfc/provider-codex.md` 新規 |
| **test** | ⏳ TODO | CX-1 test (codex stub fixture) |
| handoff | ⏳ TODO | Rule 5 |

## 8. 規模メトリクス検証 (TASK-0117 #351 適用)

| 項目 | plan 見積もり | T-01 実数 | 比率 | 判定 |
|------|--------------|----------|------|------|
| 変更ファイル数 | 8-10 | **4-5** (bin/plangate, docs/rfc/provider-codex.md, tests/extras/ta-NN, handoff) | **0.5 倍** | < 1 → Mode 1 段下げ候補 |
| 受入基準数 | 6 | 3-4 残 (CX-2 既達分除外) | — | scope 縮小済 |
| Mode | standard | **light 寄り**だが安全側 standard 維持 | — | scope 縮小だが承認境界周辺 (.codex/) のため standard |

**判定基準**: 0.5 倍 → Mode 1 段下げ候補だが、bin/plangate 改修 = 承認境界周辺で TASK-0112 例外ルール該当の見込み → **standard 維持** (安全側、TASK-0117 AC-8 一貫)。

## 9. CX-1 実装方針 (T-02 詳細)

```sh
codex)
  if ! command -v codex >/dev/null 2>&1; then
    printf 'error: codex CLI not found. Install: https://github.com/openai/codex\n' >&2
    return 1
  fi
  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT
  if ! timeout 600 codex exec --skip-git-repo-check --sandbox read-only \
      --output-last-message "$tmpfile" "$prompt" 2>&1; then
    printf 'error: codex exec failed or timeout\n' >&2
    return 1
  fi
  result=$(cat "$tmpfile")
  ;;
```

R-005/R-006/R-007 (Gemini CRITICAL `--sandbox read-only` / `timeout` / `--output-last-message`) すべて実装。

## 10. 残作業 (本 PBI 完了まで)

- T-02 CX-1: bin/plangate codex case 実装 (上記方針)
- T-05 CX-3: docs/rfc/provider-codex.md (provider-cursor.md 構造踏襲)
- T-06 test: tests/extras/ta-20-codex-review.sh (codex fixture stub)
- T-07 handoff
