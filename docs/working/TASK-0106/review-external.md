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

## C-2 v2 再委任結果（2026-05-20 / Codex+Gemini）

v2 反映後の再レビュー。前回未解消の構造課題 + 新たに発生した整合ミスを検出。

| ID | Lane | Severity | 内容 | reflected_in | status |
|----|------|----------|------|--------------|--------|
| R-012 | 設計妥当性 | **critical** | AI 自己付与不可が構造保証になっていない: TTY 要求は agent 環境で疑似 TTY 割当可能、agent 判定・不可偽装条件が未定義。**多層 best-effort 防御 + 監査ログ + 明示的 best-effort 表明** へ設計変更（オプション B 採用） | _本コミット_ | reflected |
| R-013 | 設計妥当性 | major | TTL 矛盾: pbi-input「既定 5 分」vs TC-01「until=granted_at+1800（30 分）」 | _本コミット_ | reflected |
| R-014 | 設計妥当性 | major | AC-9 ↔ TC マッピング誤り: AC-9 (`--force` なし reject) → TC-20 にマップすべき。TC-28 は `--force` 成功系 | _本コミット_ | reflected |
| R-015 | 設計妥当性 | major | todo.md T-06 Hardening Override 縮退（3 パターンのみ明示、10 パターン要求と不整合） | _本コミット_ | reflected |
| R-016 | 設計妥当性 | major | TC-12「任意 path PASS」が plan「Override 対象除外」と文言衝突 | _本コミット_ | reflected |
| R-017 | コードベース | major | `os.replace` 単体では Read-Modify-Write race を防げず `fcntl.flock` を「検討余地」から「必須」に昇格 | _本コミット_ | reflected |
| R-018 | 設計妥当性 | minor | TC-22 UTF-8 制約が pbi-input.md に未明記 | _本コミット_ | reflected |
| R-019 | 設計妥当性 | minor | review-self.md「残 critical/major 0」主張が過大 → v3 で更新 | _本コミット_ | reflected |
| R-020 | コードベース | minor | Hardening Override 判定順序を明文化（maintenance 判定より**前**） | _本コミット_ | reflected |

### R-012 設計変更の要点（重要）

「AI が呼べる CLI で AI 自己付与を構造的に不可能にする」のは原理的に困難。本 PBI では:

1. **多層 best-effort 防御** を設計に組み込む:
   - L1: 対話 TTY 要求（`isatty(stdin)` チェック）
   - L2: 環境変数バリア（`CI`, `CLAUDE_AGENT`, `CURSOR_AGENT`, `PLANGATE_BYPASS_HOOK` 等の検出時 reject）
   - L3: プロセス系統 heuristic（parent process が claude/codex/cursor 等の AI agent 系統なら reject）
   - L4: 環境変数 `PLANGATE_MAINT_ACK` に対話で打鍵した nonce 一致を要求
2. **監査ログ強制**: 全 start 試行を `hook-events.log` に env snapshot + ppid + isatty 結果付きで記録（成功・失敗問わず）
3. **明示的 best-effort 表明**: pbi-input/plan に「構造的保証ではなく多層防御＋監査による検知可能性で AI 自己付与を阻む」と明記。**完全防御は別 PBI のスコープ**
