# TASK-0113 PBI INPUT PACKAGE

> Issue: [#355](https://github.com/s977043/plangate/issues/355)
> Codex 推奨優先順 C (2026-05-26): AI memory 自動挿入検知 hook
> 経緯: PocketEitan で claude-mem 自動挿入を 5 リリース連続で手動 revert していた実害ベースの提案。本セッションでも AGENTS.md の同事象を観察。

## Context / Why

`AGENTS.md` などの SSoT ドキュメントに AI memory ツール (claude-mem 等) が context を **自動挿入** する事象が複数プロジェクト (PocketEitan、PlanGate) で観察されている。挿入は format/commit 等のタイミングで起き、セッションごとに内容が変動するため:

- diff が出続けてレビュー雑音
- SSoT が動的化して整合性破壊
- 誤って commit すると repo に session ノイズ混入

PlanGate 標準テンプレに **pre-commit hook** を含めて、検知 (および任意で自動 revert) する機構を提供する。

## What (Scope)

### In scope

- `scripts/hooks/check-ai-memory-pollution.sh` (新規) — pre-commit (and PreToolUse 経路) で検知
- 検知対象パターンを YAML/JSON 設定可能 (`.plangate-pollution-patterns.yaml` or 既定パターン埋め込み)
- 検知時の対処法メッセージ (`git checkout -- <file>`) を表示
- `--auto-revert` mode (opt-in、既定 OFF) — `git checkout -- <file>` を hook 内で実行
- 対象ファイルも `AGENTS.md` 固定でなく `CLAUDE.md` / `DESIGN.md` / `README.md` 等を設定可能
- 既定パターン: `<claude-mem-context>` (PocketEitan + PlanGate 実害ベース)
- `.husky/` か git pre-commit テンプレ 1 種を提供
- doc: `docs/ai/ai-memory-pollution-guard.md` 運用ガイド

### Out of scope

- claude-mem 本体の改修
- 既存 `.claude/settings.json` hooks との配線 (本 PBI は git レベル hook、PreToolUse は別 PBI)
- AGENTS.md の content lint (本 PBI は「自動挿入 pattern 検知」のみ)

## 受入基準

- AC-1: `scripts/hooks/check-ai-memory-pollution.sh` (新規) が pre-commit で実行され、staged diff に `<claude-mem-context>` を検出すると exit 1 + 対処メッセージ
- AC-2: 検知パターンを YAML/JSON 設定可能 (既定: `<claude-mem-context>`)
- AC-3: 対象ファイルパターン設定可能 (既定: `AGENTS.md`、追加可: `CLAUDE.md`/`DESIGN.md`/`README.md`)
- AC-4: `--auto-revert` mode (環境変数 `PLANGATE_POLLUTION_AUTO_REVERT=1` で有効化) で `git checkout -- <file>` を自動実行 + log 出力
- AC-5: `.git/hooks/pre-commit` または `.husky/pre-commit` のテンプレを `templates/` に提供 (Human が `scripts/install-pre-commit.sh` 等で配置)
- AC-6: `docs/ai/ai-memory-pollution-guard.md` で運用ガイド (検知/対処/設定 method/false positive 対応)
- AC-7: `tests/extras/ta-15-pollution-guard.sh` で fixture (claude-mem 挿入済 AGENTS.md / clean AGENTS.md / カスタム pattern) を unit test
- AC-8: markdownlint + tests/run-tests.sh + tests/hooks/run-tests.sh 全 PASS

## Notes from Refinement

- 既存 12/12 EH hook (Claude Code PreToolUse) とは異なる層 (git pre-commit) で動作
- `--auto-revert` は opt-in 既定 OFF (誤検知時のリスク回避、運用者が明示有効化)
- false positive 対応: `<!-- plangate-pollution-allowlist:claude-mem-context -->` のような marker で個別許可
- 関連 memory: PocketEitan `feedback_pr_template_case_flip.md` (5 リリース手動 revert ベース)

## Estimation

### Risks

- false positive で正規の `<claude-mem-context>` が block される → mitigation: allowlist marker + 設定可能 pattern
- pre-commit hook の install 漏れで効かない → mitigation: `bin/plangate doctor` に pre-commit 配置検証を追加 (out of scope なら follow-up)
- 既存 husky / pre-commit 配置との衝突 → mitigation: template 提供のみ、配置は Human 操作

### Unknowns

- 他 AI memory ツールの patterns (例: cursor-memory 等) → 設定可能化で吸収
- repo 全体スキャンの性能 → staged diff のみ走査で十分 (commit のみ走査)

### Assumptions

- git pre-commit が機能する環境 (CI 含む)
- claude-mem 等は staged 差分に挿入する (pre-commit が拾えるタイミング)
