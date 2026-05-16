---
task_id: TASK-0070
artifact_type: review-external
schema_version: 1
status: done
---

# V-3 外部レビュー — TASK-0070

## レビュア: Gemini (gemini CLI)

対象: scripts/hooks/check-plan-hash.sh P4(d) 差分。
判定（初回）: **REJECT (Requires Fix)** — critical 2 / major 2 / info

| # | Severity | 指摘 | 対応 |
|---|----------|------|------|
| 1 | critical | macOS 大文字小文字非区別: `PLAN.md` が case パターン回避し OS 上は plan.md 改変可能 | 修正: 末尾空白除去 + `tr A-Z a-z` 正規化。TC-9 で回帰 |
| 2 | critical | `sed` 貪欲マッチが「最後の file_path」を拾い偽プロパティ注入で plan.md 判定回避 | 修正: jq で `.tool_input.file_path` 正規抽出を優先、fallback は grep -o 先頭一致。TC-11/TC-13 で回帰 |
| 3 | major | `_stdin=$(cat)` が stdin 消費。後続ツールと共有時に破壊の懸念 | env(`PLANGATE_HOOK_FILE`)/`$2` を最優先（既存設計）、stdin は最終手段に限定。残留懸念は既知課題化 |
| 4 | major | `./plan.md` / 末尾空白のパス表記揺れ | 末尾空白除去で対応（TC-10）。`./plan.md` は `*/plan.md` で既にマッチ（TC-12） |
| 5 | info | 巨大 stdin のメモリ/ARG_MAX | 影響軽微（printf builtin）。受容 |

## 修正後の検証

- `sh tests/hooks/run-tests.sh`: **60 passed / 0 failed**
- 追加回帰: TC-9（大文字）/ TC-10（末尾空白）/ TC-11（注入デコイ）/ TC-12（./）/ TC-13（正規 file_path 優先）
- `dash -n` PASS

critical/major（1,2,4）すべて修正・回帰テスト化。3 は設計上 env/$2 優先で実害低、
handoff 既知課題に記載。**修正反映により CONDITIONAL → 解消見込み（C-4 で最終確認）**。

## Codex

PR #242（Codex toml 修正）未マージのため Codex マルチエージェント未実行。
PR #242 マージ後に補完レビュー推奨（非ブロッキング）。
