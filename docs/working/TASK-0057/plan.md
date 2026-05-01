# EXECUTION PLAN: TASK-0057 / Issue #169 セッション B

> Mode: **critical**

## Goal

EH-4 / EH-5 / EH-6 の 3 hook を実装し、5/10 → 8/10 hooks 到達。既存 3 mode パターン踏襲で慎重実装、誤検出時の作業妨害を最小化。

## Approach

### EH-4: check-test-cases.sh（CLI）
- 引数または `PLANGATE_HOOK_TASK` で対象 TASK
- `docs/working/$TASK/test-cases.md` 不在で warn（default）/ exit 1（strict）

### EH-5: check-verification-evidence.sh（CLI）
- evidence/ 配下に verification.md / v1-acceptance-result.md / etc. のいずれかの存在を find で確認
- 不在で warn / exit 1

### EH-6: check-forbidden-files.sh（PreToolUse + CLI）
- `PLANGATE_HOOK_TASK` + `PLANGATE_HOOK_FILE` で対象を明示（false-positive guard）
- `docs/working/PBI-*/children/*.yaml` から `id: $TASK` を grep で逆引き
- python3 で YAML から `forbidden_files` / `allowed_files` を抽出 + fnmatch で glob 突合
- マッチで continue:false（strict）/ WARNING（default）/ continue:true（bypass）

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `scripts/hooks/check-test-cases.sh` | 新規 |
| `scripts/hooks/check-verification-evidence.sh` | 新規 |
| `scripts/hooks/check-forbidden-files.sh` | 新規（python3 委譲）|
| `tests/hooks/run-tests.sh` | 編集（fixture + 12 件追加）|
| `tests/fixtures/hooks/{test-cases-exists,evidence-ok,forbidden-parent}/` | 新規 |
| `.claude/settings.example.json` | 編集（EH-6 PreToolUse 追加）|
| `docs/ai/hook-enforcement.md` | 編集（Status v3 → v4、§ 4 表更新）|
| `docs/working/TASK-0057/*` | 新規 |

## Mode判定

**critical**（既存 EH パターン踏襲、ロールバック容易、3 mode 設計で誤検出緩和）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| EH-6 の YAML parse が壊れる（独自 mini-parser）| 既存 child-pbi.yaml schema との整合 + fixture でテスト、複雑構造は v2 で PyYAML 委譲 |
| EH-6 glob が `**` を完全サポートしない | fnmatch + path prefix の二重突合、十分実用 |
| EH-4 / EH-5 の判定基準（候補ファイル名）が固定 | 候補リストは hook 内で明示、追加は今後の運用知見で拡張 |
| set -e + python3 invocation | command substitution の exit code 捕捉パターン使用 |

## 確認方法

- `sh tests/hooks/run-tests.sh` → 33 件 PASS
- `sh tests/run-tests.sh` → 24 件 PASS
- `grep "Status.*v4" docs/ai/hook-enforcement.md` ヒット
- `grep "8/10 hooks" docs/ai/hook-enforcement.md` ヒット
