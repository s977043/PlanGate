# TASK-0113 review-external (C-2 proactive 外部レビュー集約)

> 追記専用・差分管理用。

## Sources

- C-2 proactive (2026-05-26): Codex (設計妥当性レーン) + Gemini (コードベース整合レーン)

## 判定サマリ

| Reviewer | 判定 | 内訳 |
|----------|------|------|
| Codex (設計妥当性) | **REJECT** | major 2 + minor 4 |
| Gemini (コードベース整合) | **CONDITIONAL APPROVE** | **CRITICAL 1** + major 2 + minor 1 |

## 集約 (R-001..R-010)

| ID | Lane | Sev | 内容 | reflected_in |
|----|------|-----|------|--------------|
| R-001 (codex) | 設計 | major | `scripts/hooks/` は Hardening Override 対象。mode を standard → **high-risk** に補正、C-3 packet に承認境界対象であることを明記 | _本コミット_ |
| R-002 (codex) | 設計 | major | `--auto-revert` が `git checkout -- <file>` 固定だと、対象ファイルの **unstaged な人間編集まで破棄**するリスク。**unstaged diff がある場合は auto-revert せず block、または staged index のみ復元する方式** に変更 + TC で unstaged 併存ケース | _本コミット_ |
| R-003 (codex) | 設計 | minor | POSIX sh で YAML 読みは未定義 → **python3 (既存依存) で読む。YAML 不在時は埋め込み JSON 既定 pattern で fallback** | _本コミット_ |
| R-004 (codex) | 設計 | minor | allowlist marker 適用範囲未定義 → **pattern id 単位 + 対象ファイル単位** (同一ファイル内で marker があれば該当 pattern のみ無効化) | _本コミット_ |
| R-005 (codex) | 設計 | minor | TC に巨大 README / binary / rename / deleted file を追加 (hook の skip 条件明確化) | _本コミット_ |
| R-006 (codex) | 設計 | info (good) | 既存 EH 層 (PreToolUse) と git pre-commit 層分離は妥当 | acknowledged |
| **R-007 (gemini)** | コードベース | **CRITICAL** | `tests/extras/ta-15-codex-hook-bridge.sh` が既存 (#347) で連番衝突。**ta-16-pollution-guard.sh に rename 必須** | _本コミット_ |
| R-008 (gemini) | コードベース | major | `templates/` ルート直下が既存しない。**`scripts/templates/`** に変更 (既存パターンに整合) | _本コミット_ |
| R-009 (gemini) | コードベース | major | hook が単なる exit 1 のみだと PreToolUse 経路で JSON 不返答 → エラー。**git pre-commit 専用に scope 限定** (PreToolUse 経路は本 PBI scope 外と pbi-input に明記) | _本コミット_ |
| R-010 (gemini) | コードベース | minor | schema 命名: `schemas/plangate-pollution-patterns.schema.json` に統一 (既存命名規約整合) | _本コミット_ |

## 反映方針

`.claude/rules/working-context.md` #234-C に従い、本コミットで pbi-input / plan / todo / test-cases / review-self を **1 回確定反映**。Gemini CRITICAL (ta-15 衝突) を最優先で解消。Codex major 2 件 (mode 高昇格 / auto-revert 安全化) を反映、PreToolUse 経路の混在を pbi-input で scope 整理。
