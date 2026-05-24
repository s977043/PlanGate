# TASK-0106 Retrospective (PBI 振り返り)

> Codex 提案順位 A (handoff 振り返り) として実施 (2026-05-24)。
> 本 PBI の完了プロセスから抽出した教訓を、将来の同類 PBI と
> harness improvement に還元する。

## 1. PBI サマリ

- **Issue**: #289 「EH-3 in-session skip の運用性改善」
- **Mode**: standard → 実態は **high-risk 相当** (承認境界周辺、L1-L4 多層防御)
- **PR**: #307 (実装) / #308 (フォローアップ)
- **期間**: 着手〜マージ完了 (本セッション内 1 日)
- **外部レビュー**: **4 ラウンド** Codex+Gemini parallel (合計 R-001..R-031 / 31 指摘)
- **C-3 判定**: Human APPROVED (R-012 best-effort 設計 を Human 明示承認)
- **AC**: AC-1..AC-13 全 PASS
- **テスト**: ta-12 14 case 追加 (tests/run-tests.sh 68→82)

## 2. KPT

### Keep (続ける)

- **Codex + Gemini 並列 4 ラウンド外部レビュー**: 31 指摘のうち critical/major 級が
  ラウンド進行で減少 (R1→R4)。Codex は仕様/設計穴、Gemini はコード品質/race
  condition で相補的に機能した
- **review-external.md R-NNN 監査表 + reflected_in 列**: 反映漏れを機械検出可能化。
  squash/rebase 耐性あり (`.claude/rules/working-context.md` #234-C 通り運用)
- **L1-L4 best-effort 多層防御 + 監査ログ**: R-012 で「完全防御は別 PBI」と
  Human 明示承認を取り、scope creep を防止
- **flock + fstat/stat inode 比較 + os.replace atomic RMW**: race condition
  対応として Gemini R-031 までで品質が漸近収束
- **`--sandbox read-only` (Codex 経由) の徹底**: review 用 codex プロセスが
  ファイル改変できない原則を本 PBI で学習、TASK-0109 で標準化に昇格 (好循環)

### Problem (課題)

- **plan 段階の C-2 を経ずに exec 着手で 4 ラウンド外部レビューが発生**:
  事前 proactive C-2 をやっていれば R-001..R-010 級は plan で吸収できた可能性
- **Mode 判定が標準だったが実態は high-risk**: 承認境界周辺の 12/12 hook と
  L1-L4 を扱うため、自動 mode 推定の不確実性が露呈 (`lite_eligible` AC-8
  「判定不能→Standard」は機能、しかし Standard も実態と乖離)
- **tty mock 不可で TC-09/TC-20/TC-26a-d/TC-32 が CI 自動化未対応**:
  K-1/K-2 として残った。`expect`/`pexpect` 採用は別 PBI (V2-B)
- **plan_hash mismatch (R-002 等)** が exec 中盤で複数回発生し fixup commit が
  膨らんだ: c3.json APPROVED 後の plan 修正は再承認を要する原則は守ったが、
  事前に確定反映を 1 回で済ませる規律が緩んだ
- **AI 自己発行リスク (R-012 critical)**: Codex が「AI が自分で maintenance
  window を発行できる構造」を発見、user 直接の最終承認で best-effort 多層
  に決着。**AI 自己設置 Gate を /goal で自己解釈解除しないルール**を memory
  feedback_self_imposed_reapproval_gate として残した (重要学習)

### Try (次に試す)

- **C-2 proactive を C-3 直前の必須プラクティスに格上げ**: TASK-0108/0109 で
  既に試行 (#322/#323) → 効果検証後 `.claude/rules/` に標準化候補
- **mode 自動推定の補正**: 承認境界 (`scripts/hooks/`, `.claude/settings*.json`)
  に触れる PBI は **最低 high-risk** ルールを `mode-classification.md` 例外
  ルールに追加検討 (現行は「セキュリティ関連→最低 中」のみ)
- **plan 確定反映の 1-shot 規律**: working-context.md #234-C の「1 回確定反映」
  原則を C-2 集約時のチェックリストとして review-self.md テンプレートに
  明示追加
- **tty mock CI 自動化 (V2-B)**: K-1/K-2 を別 PBI 起票するか、`expect`/`pexpect`
  を tests/extras/ に導入し ta-12 系を CI 化
- **AI 自己設置 Gate 再承認非緩和の機械化**: `.claude/rules/responsibility-classes.md`
  に既に明文化済 (本セッションで追加)。Hook で AI 自己発行を 100% block
  する RFC 検討

## 3. AI harness improvement (#200) 用の問い

- [x] **C-3 CONDITIONAL/REJECTED 増加要因**: TASK-0106 は APPROVED 一発だが、
  R-012 で実質 CONDITIONAL 相当の Human 設計判断要求が発生。
  **plan 品質**: R-001..R-031 のうち 7 件が plan 段階での見落とし (race
  condition, target_file 正規化, EH-3 maintenance valid 順序 等)
- [x] **C-4 REQUEST_CHANGES**: 該当なし (PR #307/#308 共に Human APPROVE)
- [x] **V-1 first pass rate**: AC-1..AC-13 全 PASS (first pass)。test-cases 精度
  は高く、exec 手順も TDD で順調
- [x] **fix loop**: 外部レビュー 4 ラウンドで fix loop 4 回相当。EHS-3
  escalation は発火せず (上限内)
- [x] **hook violation 傾向**: EH-3 違反は本 PBI 改修対象自体。他 hook (EH-1/
  EH-2/EH-8) 違反なし
- [x] **Keep Rate**: handoff.md / R-NNN 監査表 / L1-L4 設計が再利用候補
- [x] **latency / cost**: 1 日内完了で許容範囲、4 ラウンド外部レビューが
  最大 cost 因
- [x] **次の harness improvement PBI 候補**:
  - V2-A: AI 自己付与完全構造保証 PBI (R-012)
  - V2-B: tty mock CI 自動化 (K-1/K-2)
  - V2-C: maintenance.json append-only audit リング
  - **新規候補**: mode-classification.md 例外ルールに「承認境界周辺は最低
    high-risk」追加

## 4. 次アクション

| アクション | Owner | 期限 | 関連 PBI 候補 |
|-----------|-------|------|--------------|
| TASK-0108/0109 で C-2 proactive 効果検証 | AI | exec 完了後 | 標準化 PBI 候補 |
| V2-A/B/C を #277 (M-2 V2 backlog) に追記検討 | Human | 次 sprint | #277 |
| mode-classification.md 例外ルール拡張 RFC | AI | 提案のみ | 新規 PBI 候補 |
| AI 自己設置 Gate Hook 化 RFC | AI | 提案のみ | 新規 PBI 候補 (R-012 follow-up) |

## 5. メモ: R-NNN 集約統計

| ラウンド | Codex | Gemini | 合計 | 主要 severity |
|----------|-------|--------|------|--------------|
| R1 | R-001..R-008 | R-009..R-013 | 13 | critical 1 (R-012) + major 5 |
| R2 | R-014..R-019 | R-020..R-022 | 9 | major 3 |
| R3 | R-023..R-026 | R-027..R-029 | 7 | major 2 + minor 5 |
| R4 | (passing) | R-030..R-031 | 2 | major 1 (R-031 inode race) |

ラウンド進行で critical/major 級が漸近的に減少 → 4 ラウンド設計が妥当だったと
事後的に確認。
