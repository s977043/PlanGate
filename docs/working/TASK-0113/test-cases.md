# TASK-0113 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1 hook 検出 + exit 1 | TC-01, TC-02 |
| AC-2 設定可能 pattern | TC-03 |
| AC-3 対象ファイル設定可能 | TC-04 |
| AC-4 --auto-revert mode | TC-05 |
| AC-5 install テンプレ | TC-06 |
| AC-6 運用ガイド | TC-07 |
| AC-7 ta-15 unit test | TC-08 |
| AC-8 CI regression | TC-09 |

## ケース

| ID | 内容 | 手順 | 期待 |
|----|------|------|------|
| TC-01 | clean AGENTS.md commit OK | fixture clean AGENTS.md を `git add` → hook 実行 | exit 0 |
| TC-02 | claude-mem 挿入で block | fixture 挿入済 AGENTS.md → hook 実行 | exit 1 + 対処メッセージ |
| TC-03 | カスタム pattern (例 cursor-memory) 検出 | `.plangate-pollution-patterns.yaml` に追加 pattern → 該当 fixture | exit 1 |
| TC-04 | 対象ファイル拡張 (CLAUDE.md 追加) | yaml に CLAUDE.md 追加 → CLAUDE.md に汚染 fixture | exit 1 |
| TC-05 | `PLANGATE_POLLUTION_AUTO_REVERT=1` で自動 revert | env 設定 + 汚染 fixture → hook 実行 | exit 0 + `git checkout` 実行 log + fixture clean 化 |
| TC-06 | `templates/pre-commit.sample` 存在 + install スクリプト動作 | `sh scripts/install-pre-commit.sh` → `.git/hooks/pre-commit` 配置 | 該当 file 存在 + 実行可能 |
| TC-07 | 運用ガイド存在 + 主要セクション | `grep -E '## 検知\|## 対処\|## 設定\|## false positive\|## allowlist' docs/ai/ai-memory-pollution-guard.md` | 全該当 |
| TC-08 | ta-15 tests/run-tests.sh dispatcher 認識 | `sh tests/run-tests.sh` | TA-15 case 自動 discovery + 全 PASS |
| TC-09 | 既存 CI regression | `sh tests/run-tests.sh && sh tests/hooks/run-tests.sh` | 全 PASS |
| TC-10 | allowlist marker でスキップ | fixture に `<!-- plangate-pollution-allowlist:claude-mem-context -->` + 汚染 | exit 0 |

## エッジケース

- 空 staged diff: skip (exit 0)
- AGENTS.md が staged されていない場合 (他 file commit): skip
- `.plangate-pollution-patterns.yaml` 不在: 既定埋め込み pattern を使用
- pattern マッチを含む正規 doc (本 PBI 自体の README 等): allowlist marker で除外
