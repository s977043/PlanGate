# Codex CLI Guarded Execution

> **Status**: Stable
> **Review cadence**: As needed
> **Owner**: Maintainer

## 概要

`scripts/codex-guarded.sh` は、PlanGate の Hook 強制（EH-3/EH-6/EH-8）を Codex CLI セッションに適用するための guarded entrypoint です。Claude Code では `.claude/settings.json` の PreToolUse hooks が物理的に発火しますが、Codex CLI にはその仕組みがないため、このラッパースクリプトが同等の保護を pre-flight / post-flight の形で提供します。

詳細な provider 比較は [docs/rfc/provider-codex.md](../../rfc/provider-codex.md) を参照してください。

## 使い方

```bash
# 基本形: --task でタスク ID を指定する
scripts/codex-guarded.sh --task TASK-XXXX exec --full-auto

# 環境変数で指定する場合
PLANGATE_GUARDED_TASK=TASK-XXXX scripts/codex-guarded.sh exec --full-auto

# docs/working/TASK-XXXX/ 配下から実行する場合（自動検出）
cd docs/working/TASK-0123
../../scripts/codex-guarded.sh exec --full-auto
```

## 動作フロー

```
Pre-flight（fail-closed）
  1. bin/plangate validate $TASK   — plan_hash 整合性確認
  2. bin/plangate doctor --check-settings — settings タスクロック確認
  3. EH-8 metrics privacy — ステージ済みファイルのプライバシー確認
        ↓ いずれかが FAIL → exit 1（Codex は起動しない）
Codex セッション実行
        ↓
Post-flight（警告のみ・fail-closed ではない）
  4. plan.md のハッシュ変化検出（ドリフト警告）
  5. bin/plangate validate $TASK — セッション後の整合性確認
  6. docs/working/_audit/codex-guarded.log に記録
```

### exit codes

| コード | 意味 |
|--------|------|
| `0` | 正常完了 |
| `1` | pre-flight 失敗（Codex は起動していない）|
| `2` | post-flight でドリフト検出（Codex は完了したが plan_hash が変化）|

## eh-bridge.sh の役割

`.codex/hooks/eh-bridge.sh` は、Codex CLI の PreToolUse hook イベント（Edit / Write / apply_patch）を受け取り、PlanGate の `scripts/hooks/*.sh` に橋渡しするアダプターです。

### 仕組み

1. Codex が Edit/Write/apply_patch を呼び出す直前に、`.codex/hooks.json` の設定に従って `eh-bridge.sh` が呼ばれる
2. `eh-bridge.sh` は stdin の JSON から対象ファイルパスを抽出し、`PLANGATE_HOOK_FILE` / `PLANGATE_HOOK_TASK` に設定して指定 PlanGate hook を実行する
3. 結果を Codex の `hookSpecificOutput.permissionDecision`（`allow` / `deny`）として返す

```bash
# 直接呼び出す場合の例（デバッグ用）
echo '{"tool":"Edit","tool_input":{"file_path":"docs/working/TASK-0099/plan.md"}}' \
  | .codex/hooks/eh-bridge.sh check-plan-hash.sh
```

### 配線されている EH

| EH | hook スクリプト | 目的 |
|----|----------------|------|
| EH-1 | `check-scope-boundary.sh` | forbidden_files ガード |
| EH-2 | `check-plan-exists.sh` | plan 未作成時のブロック |
| EH-3 | `check-plan-hash.sh` | plan_hash 整合性（承認境界） |
| EH-6 | `check-forbidden-files.sh` | HO 対象パスへの書き込み禁止 |
| EH-9 | `check-settings-wiring.sh` | settings wiring 契約確認 |

詳細な配線定義は [`.codex/hooks.json`](../../../.codex/hooks.json) を参照してください。

## codex-guarded.sh との違い

| 観点 | `codex-guarded.sh` | `eh-bridge.sh` |
|------|-------------------|----------------|
| タイミング | セッション開始前 / 終了後 | 各ツール呼び出し前（物理フック） |
| 強制力 | pre/post-flight の wrap | Codex の PreToolUse で発火 |
| 対象 | セッション全体 | 個別の Edit/Write/apply_patch |
| 設定 | スクリプトを直接呼ぶ | `.codex/hooks.json` で配線 |

`codex-guarded.sh` は **セッションレベルの整合性保護**、`eh-bridge.sh` は **ツール呼び出しレベルの物理フック**として、二層で保護を提供します。

## 既知の制約

- `codex-guarded.sh` の post-flight はドリフトを「検出」するのみで、Codex セッション中の書き込みを物理的に止めることはできません。物理的な pre-write 強制は `eh-bridge.sh` / `.codex/hooks.json` による配線が担います。
- `eh-bridge.sh` は `python3` が必要です（ファイルパス抽出に使用）。

## 関連ドキュメント

- [RFC: PlanGate × Codex CLI Provider Integration](../../rfc/provider-codex.md)
- [`.codex/hooks.json`](../../../.codex/hooks.json)
- [scripts/hooks/](../../../scripts/hooks/)
- [docs/ai/settings-wiring-contract.md](../../ai/settings-wiring-contract.md)
