# RFC: `plangate decompose` CLI Command

| 項目 | 値 |
|------|---|
| **Status** | **Draft** |
| **Author** | TASK-0038 (s977043 / Claude) |
| **Created** | 2026-04-28 |
| **Related** | Issue [#109](https://github.com/s977043/plangate/issues/109) / [`docs/orchestrator-mode.md`](../orchestrator-mode.md) |
| **Implementation** | **Out of scope of TASK-0038（実装は別 PBI）** |

## Summary

`plangate decompose <PBI-id>` は、親 PBI を子 PBI 群に分解するための CLI コマンドである。本 RFC はインターフェイス仕様、期待動作、実装方針 2 案を提案する。**本 PBI（TASK-0038）の範囲は仕様策定のみで、実装は後続 PBI で行う。**

## Motivation

PlanGate Orchestrator Mode では親 PBI を子 PBI に分解するフローが必要になる（[`docs/workflows/orchestrator-decomposition.md`](../workflows/orchestrator-decomposition.md) 参照）。手動運用も可能だが、以下のいずれかの自動化が望ましい:

- ファイル雛形の生成（`parent-plan.md` / `dependency-graph.md` / `parallelization-plan.md` / `integration-plan.md` / `children/` ディレクトリ）
- 既存 `pbi-input.md` から子 PBI 候補の **提案**
- 子 PBI YAML の schema validation

## CLI 仕様（提案）

### 基本形

```bash
plangate decompose <PBI-id> [options]
```

### 引数

| 引数 | 必須 | 説明 |
|------|------|------|
| `<PBI-id>` | ✅ | 親 PBI ID（例: `PBI-123`）。`docs/working/PBI-XXX/` ディレクトリのキー |

### Options

| Option | 値 | デフォルト | 説明 |
|--------|----|----------|------|
| `--input <path>` | path | `docs/working/<PBI-id>/pbi-input.md` | 親 PBI の入力ファイル |
| `--output <dir>` | path | `docs/working/<PBI-id>/` | 出力ディレクトリ |
| `--mode <mode>` | string | `manual` | `manual` / `assisted` / `auto` |
| `--children <count>` | int | （指定なし）| 期待する子 PBI 数（assisted/auto モードでのヒント）|
| `--dry-run` | flag | false | ファイル生成せず提案のみ表示 |
| `--validate` | flag | false | 既存 `children/*.yaml` の schema 検証のみ実施 |

### 動作モード

#### `--mode manual`（最小実装）

- ファイル雛形のみ生成（テンプレートからコピー）
- 内容は手動で記入
- 実装が最も単純、決定論的
- POSIX sh で完結可能

```text
$ plangate decompose PBI-123 --mode manual
Created: docs/working/PBI-123/parent-plan.md
Created: docs/working/PBI-123/dependency-graph.md
Created: docs/working/PBI-123/parallelization-plan.md
Created: docs/working/PBI-123/integration-plan.md
Created: docs/working/PBI-123/children/  (empty, fill manually)
Next: edit parent-plan.md and add children/PBI-123-NN.yaml
```

#### `--mode assisted`（推奨実装）

- 雛形生成 + `pbi-input.md` の構造解析（heading / list 抽出）
- ヒューリスティックで子 PBI 候補を提案
- 候補は YAML で出力するが `state: planned`、人間が確認・修正前提
- LLM 不使用、ローカル決定論

```text
$ plangate decompose PBI-123 --mode assisted
Analyzed: docs/working/PBI-123/pbi-input.md
Detected 3 candidate boundaries (heading-based heuristic):
  - PBI-123-01: 権限判定サービス（domain layer）
  - PBI-123-02: middleware 適用（application layer）
  - PBI-123-03: admin UI（presentation layer）
Created: children/PBI-123-01.yaml (review and edit)
Created: children/PBI-123-02.yaml
Created: children/PBI-123-03.yaml
Created: parent-plan.md (with auto-filled Children table)
Next: review children/*.yaml and approve via parent-c3
```

#### `--mode auto`（拡張実装）

- 外部 LLM（Claude / Gemini / Codex 等）による高品質な子 PBI 提案
- 既存 `bin/plangate review` の provider 機構を再利用
- 環境変数: `PLANGATE_DECOMPOSE_PROVIDER=claude|gemini|codex`
- LLM 出力をそのまま採用せず、必ず `--dry-run` でプレビュー → 人間承認 → 書き込み

```text
$ PLANGATE_DECOMPOSE_PROVIDER=claude plangate decompose PBI-123 --mode auto --dry-run
[provider=claude] generating decomposition proposal ...
Proposed 4 children:
  - PBI-123-01: ...
  - ...
Run without --dry-run to write files (after review).
```

## 実装方針 2 案

### 案 A: ローカル決定論（recommended for v2）

**特徴**:

- POSIX sh + python3（YAML 検証用）のみ
- LLM 呼び出しなし
- `--mode manual` と `--mode assisted` まで対応
- CI で再現可能、テスト容易

**Pros**:

- 既存 `bin/plangate` と同じ依存範囲
- 動作が予測可能
- ネットワーク不要

**Cons**:

- 提案の質はヒューリスティック止まり
- ドメイン的な妥当性は人間判断が必須

### 案 B: 外部 LLM 補助（recommended for v3）

**特徴**:

- `--mode auto` を担当
- 既存 `bin/plangate review` の provider abstraction を踏襲
- LLM 出力 → schema validation → 人間レビュー必須

**Pros**:

- 提案品質の上限が高い
- 大規模 PBI で人間の認知負荷が下がる

**Cons**:

- LLM 依存、再現性が低い
- コスト発生（API 課金）
- セキュリティレビュー必須（コードベース全体を渡すため）

### 推奨: 段階導入

| Phase | 実装範囲 |
|-------|---------|
| Phase 1（最小）| `--mode manual` のみ。雛形コピー機能 |
| Phase 2 | `--mode assisted`。heading-based ヒューリスティック |
| Phase 3 | `--validate` 機能（YAML schema validation）|
| Phase 4 | `--mode auto`。LLM provider 統合 |

各 Phase は別 PBI として起票する。

## 既存 `bin/plangate` との整合性

| 既存コマンド | `decompose` との関係 |
|------------|--------------------|
| `plangate init <ticket>` | 単一 PBI 用。`decompose` は親 PBI 用の上位互換 |
| `plangate validate` | 子 PBI の Workflow DSL 検証。`decompose --validate` は YAML schema 検証で **観点が異なる** |
| `plangate review` | 既存 LLM provider 機構。`decompose --mode auto` で再利用 |
| `plangate exec` | 子 PBI 単位で実行。`decompose` 後に各子 PBI で起動する想定 |
| `plangate status` | 単一 PBI 用。親 PBI 用に拡張するか別コマンド `plangate parent-status` を新設するかは未決定 |

### 非破壊性

`decompose` は **既存コマンドを変更しない**。新規追加のみで成立する。

## 期待される副作用と保護

| 副作用 | 保護策 |
|-------|-------|
| 既存ファイル上書き | `--force` がない限りエラー終了 |
| 大量ファイル生成 | `--dry-run` 推奨、Phase 1 では `--mode manual` のみ |
| LLM 呼び出しコスト | `--mode auto` のみ、明示的 opt-in |

## Test plan（実装 PBI 用、参考）

- `plangate decompose --help` が usage 表示
- `plangate decompose PBI-999 --mode manual` が雛形を生成
- `plangate decompose PBI-999 --mode manual` を再実行すると既存ファイル保護でエラー
- `plangate decompose PBI-999 --validate` が空ディレクトリでエラー、有効 YAML で PASS
- `--dry-run` がファイルを書き込まない
- `--mode auto` 未対応 provider で明示的なエラー

## Open questions

- **OQ-1**: GitHub Issue sub-issue API との連携（親 PBI Issue から子 PBI Issue を auto-create するか）
- **OQ-2**: `plangate status` の親 PBI 拡張 vs 新コマンド `plangate parent-status` の選択
- **OQ-3**: `--mode auto` での provider 出力フォーマットの標準化

これらは実装 PBI で確定する。

## Migration / Backward compatibility

- 既存コマンドは変更しない
- `decompose` は新規コマンドとして追加
- 既存 `docs/working/TASK-XXXX/` 構造は維持。orchestrator は `docs/working/PBI-XXX/` を別途使用

## References

- [`docs/orchestrator-mode.md`](../orchestrator-mode.md) — Orchestrator Mode 仕様正本
- [`docs/workflows/orchestrator-decomposition.md`](../workflows/orchestrator-decomposition.md) — 分解 Workflow
- [`docs/schemas/child-pbi.yaml`](../schemas/child-pbi.yaml) — 子 PBI YAML schema
- [`docs/rfc/provider-gemini-cli.md`](./provider-gemini-cli.md) — 既存 provider 機構の参考
- Issue [#109](https://github.com/s977043/plangate/issues/109) — 親 Issue
