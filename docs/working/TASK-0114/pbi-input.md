# TASK-0114 PBI INPUT PACKAGE

> 出自: [INC-2026-05-26-001](../incidents/2026-05-26-empty-commit-direct-push.md) Prevention P-1
> 関連: PR #359

## Context / Why

INC-2026-05-26-001 で AI が main 直接 push (empty commit 49448c5) を実施。Prevention P-1 として **pre-push hook template** で main / master / release branch への直接 push を physical block する仕組みを PlanGate 標準テンプレとして提供する。

`.git/hooks/` は repo にコミット不可のため、`scripts/templates/pre-push.sample` + `scripts/install-pre-push.sh` で Human が opt-in 配置する形式。TASK-0113 (#355 pre-commit hook) と並列構造。

## What (Scope)

### In scope

> **R-001 / R-002 反映**: protected branch 既定値を AC-1 と AC-3 で統一 (`main master release/*`)、`release/*` glob は remote branch 名ベース。


- `scripts/templates/pre-push.sample` (新規) — protected branch を `main`/`master`/`release/*` で設定可能
- `scripts/install-pre-push.sh` (新規) — Human opt-in 配置スクリプト
- `docs/ai/direct-push-prevention.md` (新規) — 運用ガイド
- `tests/extras/ta-17-pre-push-guard.sh` (新規) — fixture test
- 既存 TASK-0113 templates/install パターンと一貫した設計
- protected branch list 設定 (環境変数 `PLANGATE_PROTECTED_BRANCHES` で override 可)。**glob 判定は remote branch 名 (refs/heads/ を除いた部分) に対して `case` で実施**、`release/*` は `case` の glob として扱う (R-002 反映)。`set -f` (noglob) を適用してから `for pattern in $PLANGATE_PROTECTED_BRANCHES` 展開でファイルシステム glob 暴発を防止 (Gemini bot 指摘 #1)

### Out of scope

- GitHub branch protection 設定 (P-2、Human-owned GitHub admin)
- `.claude/rules/` 追記 (P-3、TASK-0115 で別 PBI)
- 全リポジトリへの自動配信 (各 repo Human opt-in)

## 受入基準

- AC-1 (R-001 反映): `scripts/templates/pre-push.sample` (POSIX sh) が protected branch (**既定: `main` `master` `release/*`**) への push を exit 1 + 明確なメッセージで block。AC-1 と AC-3 で同じ既定値を使う
- AC-2: `scripts/install-pre-push.sh` で `.git/hooks/pre-push` 配置可能 (既存 hook がある場合 `.bak` 保持)
- AC-3 (R-001 反映): `PLANGATE_PROTECTED_BRANCHES` 環境変数 (space-separated) で protected list override 可能 (**既定値は AC-1 と統一: `main master release/*`**)
- AC-4: `docs/ai/direct-push-prevention.md` で運用ガイド (install / unprotect 手順 / bypass 方法 (緊急時 `--no-verify`))
- AC-5: `tests/extras/ta-17-pre-push-guard.sh` fixture 5 case: protected push block / feature branch push OK / `--no-verify` bypass OK / 既存 hook 退避 / override env 動作
- AC-6: 既存 tests/run-tests.sh + tests/hooks/run-tests.sh regression なし
- AC-7: markdownlint + shellcheck PASS

## Notes from Refinement

- AI が `.git/hooks/` を repo にコミットできないため、template + install script 方式は唯一の選択肢
- emergency bypass: `git push --no-verify` (慣行に準拠)
- TASK-0113 (pre-commit hook) と同じ template ディレクトリ構造で並列化
- P-2 (GitHub branch protection) と組み合わせで repo-wide + local の二段構え

## Estimation

### Risks
- false positive で feature branch push が block → mitigation: protected list を明確化、override env 提供
- 既存 hook 衝突 → mitigation: `.bak` 保持 + install スクリプトで明示警告
- `--no-verify` で容易 bypass → 仕様 (緊急時の脱出弁)、監査は GitHub branch protection P-2 と組み合わせ

### Unknowns
- 各プロジェクトの release branch 命名揺れ (`release/*` / `prod` / `production` 等) → 設定 override で吸収

### Assumptions
- git pre-push hook が機能する環境
- POSIX sh / `read` で stdin parsing 可能
