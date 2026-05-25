# TASK-0110 review-external (C-2 proactive 外部レビュー集約)

> 追記専用・差分管理用。R-NNN は指摘 ID。reflected_in = 確定反映コミット。

## Sources

- C-2 proactive (2026-05-25): Codex (設計妥当性レーン) + Gemini (コードベース整合レーン)

## 集約 (R-001..R-006)

| ID | Lane | Severity | 内容 | reflected_in | status |
|----|------|----------|------|--------------|--------|
| R-001 (codex#1) | 設計 | major | H-02 適用 timing と AC-3 (apply 後 CI PASS) の衝突 — merge 後 apply だと PR は CI 通らない。**設計選択固定**: Human が PR ブランチで --apply 実行 → 変更を同一 PR にコミット → CI 通った後 merge | _本コミット_ | reflected |
| R-002 (codex#2) | 設計 | major | AC-4 byte-equal except 2 field の実装契約未明確 (JSON parse→dump で key order/spacing 変わるリスク) → **既存行 JSON object を読み、key 順維持で acknowledged_by/at だけ置換/追加する raw-line-preserving 方式**を plan/test-cases に明記 | _本コミット_ | reflected |
| R-003 (codex#3) | 設計 | minor | --apply の Human 実行証跡 (commit message に "applied by <human-name>" 等) 明示要 | _本コミット_ | reflected |
| R-004 (codex#4) | 設計 | minor | 監査ログ一括変更 CLI のため、mode=light でも C-3 同期固定 (非同期降格なし) を plan に明記 | _本コミット_ | reflected |
| R-005 (gemini#1) | コードベース | minor | acknowledged_at は ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`) 統一 | _本コミット_ | reflected |
| R-006 (gemini#2) | コードベース | minor | dry-run で `event: EH-3_SKIP` 優先スキャン (将来拡張堅牢性) | _本コミット_ | reflected |

## 判定サマリ

| Reviewer | 判定 | 内訳 |
|----------|------|------|
| Codex (設計妥当性) | CONDITIONAL | major 2 + minor 2 |
| Gemini (コードベース整合) | APPROVE | minor 2 |

## 反映方針

`.claude/rules/working-context.md` #234-C に従い、本コミットで plan / todo / test-cases / review-self を **1 回確定反映**。
