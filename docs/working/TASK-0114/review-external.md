# TASK-0114 review-external (C-2 individual proactive)

> 個別 C-2 proactive review (2026-05-27): Codex + Gemini

## 判定サマリ

| Reviewer | 判定 | 内訳 |
|----------|------|------|
| Codex | **CONDITIONAL** | major 2 + minor 3 |
| Gemini | **CONDITIONAL APPROVE** | minor 2 + info 1 |

## 集約 (R-001..R-008)

| ID | Lane | Sev | 内容 |
|----|------|-----|------|
| R-001 (codex) | 設計/可読性 | major | AC-1 と AC-3 protected branch 既定値矛盾 (AC-1: main/master/release/*、AC-3: main master) |
| R-002 (codex) | 設計/拡張性 | major | release/* glob match 仕様を remote branch 名ベースで明文化 |
| R-003 (codex) | セキュリティ | minor | local hook bypass 可能、P-2 (GitHub branch protection) との責務分界明記 |
| R-004 (codex) | テスト | minor | --no-verify bypass は fixture では検証不可、TC-09 を integration test or doc 確認に分離 |
| R-005 (codex) | パフォーマンス | minor | POSIX sh + case 判定の軽量設計が適切 |
| R-006 (gemini) | コードベース | minor | install スクリプトの冪等性 (同一 hook なら .bak skip) |
| R-007 (gemini) | コードベース | minor | POSIX sh glob 時のクォート扱い (case 右辺 unquoted) |
| R-008 (gemini) | コードベース | info | ブランチ削除 (local_sha=0...0) の扱い再確認 |

## 反映方針 (次 PR)

- AC-1/AC-3 protected branch list 既定値統一 (R-001)
- release/* glob 仕様明文化 (R-002)
- TC-09 を integration test に分離 (R-004)
- install.sh 冪等性 + glob クォート扱いを実装規約に追加 (R-006/R-007)
