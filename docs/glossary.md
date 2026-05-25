# PlanGate 用語クイックリファレンス

PlanGate ドキュメントで頻出する略号の一覧。初見の方はこのページをブックマーク推奨。

## ゲート / 承認境界 (C-X)

| 略号 | 名称 | 説明 |
|------|------|------|
| **C-1** | セルフレビュー | 17 項目チェック (Plan 7 + ToDo 5 + TestCases 3 + 結合 2)。AI 自身が plan/todo/test-cases を構造的に検証。 |
| **C-2** | 外部 AI レビュー | gemini / codex 等の外部モデルが指摘 R-NNN を付与。`bin/plangate review --phase c2` |
| **C-3** | 人間承認ゲート（plan） | C-1/C-2 を踏まえ人間が APPROVED / CONDITIONAL / REJECT 三値で判定。`approvals/c3.json` 発行。 |
| **C-4** | 人間承認ゲート（PR） | GitHub 上で PR レビュー。APPROVE / REQUEST CHANGES / REJECT 三値。 |

## 検証フェーズ (V-X)

| 略号 | 名称 | 適用 mode | 説明 |
|------|------|----------|------|
| **V-1** | 受け入れ検査 | 全 mode | test-cases.md 各 AC を機械的に PASS/FAIL 突合 |
| **V-2** | コード最適化 | high-risk / critical | 動作不変で可読性・効率性改善 |
| **V-3** | 外部モデルレビュー | standard 以上 | 5 観点 + Severity 判定、R-NNN 採番 |
| **V-4** | リリース前チェック | critical のみ | ドキュメント整合 / マイグレーション / セキュリティ |

## Workflow フェーズ (WF-XX)

| 略号 | 名称 | 旧呼称 |
|------|------|--------|
| **WF-01** | Brainstorm | A: PBI INPUT PACKAGE |
| **WF-02** | Requirement Expansion | A→B 中間 |
| **WF-03** | Solution Design | B: Plan + ToDo + Test Cases |
| **WF-04** | Build & Refine | D: Agent 実行 (exec) |
| **WF-05** | Verify & Handoff | V-1〜V-4 + handoff |

## Hook 識別子 (EH-X)

PlanGate の PreToolUse hook 群 (`scripts/hooks/check-*.sh` + `.claude/settings.json` または `.codex/hooks.json` で配線)。

| 略号 | 役割 | 発火条件 |
|------|------|---------|
| **EH-1** | plan-exists | plan.md 存在検証 |
| **EH-2** | c3-approval | c3.json APPROVED 検証 |
| **EH-3** | plan_hash | C-3 承認後の plan.md 改竄検知 |
| **EH-6** | forbidden_files | scope 越境禁止 |
| **EH-8** | metrics-privacy | events.ndjson の Forbidden field 検出 |
| **EH-9** | delegation-commit-boundary | 委譲時の commit 境界違反検出 |
| **EH-10** | self-set-gate-enforcement | AI 自己設置 Gate の Hook 強制（[RFC Draft](rfc/ai-self-set-gate-hook-enforcement.md)）|

## モード分類 (5 段階)

| 略号 | 名称 | 対象例 |
|------|------|--------|
| **ultra-light** | 超低 | typo / 設定値変更 / コメント修正 |
| **light** | 低 | バグ修正 / 1 ファイル小修正 |
| **standard** | 中 | 小機能追加 / 数ファイル変更 |
| **high-risk** | 高 | 機能追加 / 複数レイヤー変更 |
| **critical** | 超高 | アーキテクチャ変更 / 横断的リファクタ |

詳細: [`.claude/rules/mode-classification.md`](https://github.com/s977043/PlanGate/blob/main/.claude/rules/mode-classification.md)

## 派生属性

| 属性 | 説明 |
|------|------|
| `lite_eligible` | C-3 を非同期降格してよいかの真偽属性。`C-1 PASS` & `C-2 critical/major=0` & light/standard 相当でのみ true 候補。critical mode は原則 false (AC-11)。判定不能は安全側 false (AC-8)。 |
| **Hardening Override** | AI 改変不可ファイル群 (`.claude/settings*.json` / `.claude/rules/*.md` / `.claude/agents/*.md` / `.claude/commands/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `AGENTS.md` / `CLAUDE.md` 等)。Human-owned 適用のみ。 |

## 指摘 ID

| ID | 用途 |
|----|------|
| **R-NNN** | C-2 / V-3 外部レビューで採番する指摘 ID。`review-external.md` に追記専用集約。反映コミットに `Refs: R-NNN` |

## 関連

- 全体像: [PlanGate ガイド](plangate.md)
- 段階的導入: [Staged Adoption Guide](staged-adoption-guide.md)
- 設定契約: [settings-wiring-contract.md](ai/settings-wiring-contract.md)
