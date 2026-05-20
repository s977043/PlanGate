# TASK-0106 review-external（C-2 相当 + V-3 外部レビュー集約）

> 追記専用・差分管理用。R-NNN は指摘 ID。reflected_in = 確定反映コミット。

## Sources

- C-2 相当 (2026-05-20): Codex (設計妥当性レーン) / Gemini (コードベース整合レーン)
  - 委任: 本セッション内
  - 結論: Codex=REJECT / Gemini=CONDITIONAL APPROVE

## 監査表

| ID | Lane | Severity | 内容 | reflected_in | status |
|----|------|----------|------|--------------|--------|
| R-001 | 設計妥当性 | **critical** | AC-5（AI 自己付与不可）が pbi-input「Human 実行のみ」と plan「AI 起動可」で矛盾。CLI で AI が maintenance.json を生成できれば AC-5 違反 | _本コミット_ | reflected |
| R-002 | 両レーン | **major** | one-shot atomicity が tmp+rename だけでは並行 hook 両方未消費読み通過のリスク。os.replace / lock / CAS / fail-closed を明示要 | _本コミット_ | reflected |
| R-003 | コードベース | **critical/major** | Hardening Override 対象が不足。`bin/plangate` / `schemas/*.schema.json` / `.github/workflows/*.yml` / `AGENTS.md` / `CLAUDE.md` / `.claude/commands/*.md` / `.claude/agents/*.md` も常時 block 対象に追加すべき | _本コミット_ | reflected |
| R-004 | 設計妥当性 | major | 後方互換（既存 30 分窓「任意 path PASS」）vs Hardening Override（常時 block）の境界が plan で未定義 | _本コミット_ | reflected |
| R-005 | 設計妥当性 | major | TC-20（既存有効窓上書き）が「拒否 or --force」未決定。承認窓の上書きは境界操作のため C-3 前に仕様固定 | _本コミット_ | reflected |
| R-006 | コードベース | major | `bin/plangate doctor --json` 反映（`scripts/doctor_check.py` 更新）が Work Breakdown に未言及 | _本コミット_ | reflected |
| R-007 | 設計妥当性 | minor | AC-8（runner 統合）の検証 TC が「テスト導入そのもの」で ID なし。TC-23 として追加要 | _本コミット_ | reflected |
| R-008 | 設計妥当性 | minor | 「短い TTL 既定」と「既定 30 分」が混在。既定値とハード上限を分離明記 | _本コミット_ | reflected |
| R-009 | コードベース | minor | strict JSON 抽出パターン (#282/TASK-0105) を新設フィールド (`allowed_paths`/`one_shot`/`consumed_at`) 読出にも適用 | _本コミット_ | reflected |
| R-010 | コードベース → 設計妥当性 | (AC 候補) | `maintenance start` は既存有効ファイルがあれば `--force` なしでは上書き拒否（AC-X、本 PBI で **AC-9** として正式採用） | _本コミット_ | reflected |
| R-011 | コードベース → 設計妥当性 | (AC 候補) | 新設 one-shot / path scope 判定も **env 経由では有効化不可**（ファイル存在を正本）（AC-Y、本 PBI で **AC-10** として正式採用） | _本コミット_ | reflected |
| R-012 | 設計妥当性 | info | issue #289 本文を Codex 環境でネットワーク非到達。本指摘は PR #299 5 ファイル + repo rules に限定したレビュー（網羅性は確認済） | – | acknowledged |

## 反映方針（1 回確定反映）

`.claude/rules/working-context.md` の review-external 差分管理（TASK-0076 F5-C / #234-C）に従い、本コミットで pbi-input / plan / test-cases を **1 回だけ確定反映**。各反映箇所のコミットメッセージに `Refs: R-NNN` を付す。簡易 C-1 を本セッション内で再実行し、改訂版で C-3 ゲート再提出可能とする。
