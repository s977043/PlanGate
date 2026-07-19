# HO Apply Approval — TASK-0872 PR-2

> Hardening Override 対象ファイルへの適用は **Human-owned**（AI は patch 生成・
> sandbox 実適用テストまで）。本書は適用対象・検証結果・適用コマンドを提示する。
> 責務分類正本: `.claude/rules/responsibility-classes.md`（HO 常時 block）。

## 適用対象（HO・4 ファイル）

| # | ファイル | 変更 | 適用方法 | patch/完成形 |
|---|---------|------|---------|-------------|
| 1 | `bin/plangate` | validate / exec preflight に c3-prime 受理分岐（`_plangate_c3_dispatch`）追加。legacy grep 経路は非変更 | `git apply` または `cp` | `patches/bin-plangate.patch`（89+/43-）または `patches/bin-plangate.new`（完成形） |
| 2 | `.claude/commands/ai-loop-workflow.md` | `run` 入口を Plan-first（TASK-XXXX 必須）へ改訂 | 同上 | `patches/ai-loop-workflow-claude.patch` / `.new` |
| 3 | `plugin/plangate/commands/ai-loop-workflow.md` | 同上（sync 対・byte 同一） | `cp` | `patches/ai-loop-workflow.plugin.new` |
| 4 | `schemas/c3-prime.schema.json` | 新設（cross-field 制約込み） | `cp` | `patches/c3-prime.schema.json`（完成形） |

## AI 実施済みの検証（sandbox 実適用テスト）

`bin/plangate` を scratchpad に完全構造の sandbox を組んで実際に叩き、全 exit code を実測（推測でない）:

| シナリオ | 実測 exit | 期待 |
|---------|----------|------|
| legacy c3.json validate（実 TASK-0872） | 0 | 0（非退行） |
| legacy c3.json exec | 0 | 0（非退行） |
| c3-prime 正常 validate | 0 | 0（受理） |
| c3-prime 正常 exec | 0 | 0（受理） |
| c3-prime artifact 改竄 validate | 1 | 1（stale reject） |
| c3-prime artifact 改竄 exec | 1 | 1（reject） |

`patches/bin-plangate.patch` は `git apply --check` clean 通過を確認済み。
`schemas/c3-prime.schema.json` は正側 record PASS + 負側 4 パターン（c3_status 混入 /
未知 approval_kind / snapshot 欠落 / AUTO_APPROVED+reject cross-field）reject を
jsonschema で実測済み。

## 適用コマンド（Human 実行）

```sh
cd <repo root>
# 1. bin/plangate
git apply docs/working/TASK-0872/patches/bin-plangate.patch
#    または: cp docs/working/TASK-0872/patches/bin-plangate.new bin/plangate && chmod +x bin/plangate

# 2. commands（.claude + plugin 同期）
cp docs/working/TASK-0872/patches/ai-loop-workflow.claude.new .claude/commands/ai-loop-workflow.md
cp docs/working/TASK-0872/patches/ai-loop-workflow.plugin.new plugin/plangate/commands/ai-loop-workflow.md

# 3. schema 配置
cp docs/working/TASK-0872/patches/c3-prime.schema.json schemas/c3-prime.schema.json

# 4. 検証（適用後）
sh scripts/sync-plugin-plangate.sh            # drift 0 確認
sh tests/run-tests.sh                          # TA-55 の HO 全鎖テストが SKIP→PASS へ
python3 scripts/ai-loop/c3prime_verify.py --help 2>/dev/null || true
```

## 適用後に自動で有効化されるもの

- `tests/extras/ta-55` の `[SKIP] bin/plangate に c3-prime 配線なし` が
  `[PASS] HO 適用後: bin/plangate validate が c3-prime を受理` に切り替わる
- `scripts/schema_mapping.py` の F-8 dispatch が実 schema を得て、c3-prime c3.json を
  `c3-prime.schema.json` で検証（TA-05 F-8 テストは schema 実在で SKIP へ切替）

## 適用しない場合の安全性（fail-closed）

未適用の間、c3-prime artifact は `bin/plangate` の legacy grep 経路で `c3_status`
不在により **FAIL**（受理されない）。schema-validate も #887 F-8 により
schema 不在で **ERROR**。いずれも安全側で、Shadow Config は発生しない。
