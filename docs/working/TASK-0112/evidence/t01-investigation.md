# TASK-0112 T-01 investigation (read-only)

> 実施: 2026-05-27 / Mode: read-only / C-3 前可
> 目的: mode-classification.md 例外ルール拡張の追記前提を実数で確定

## 1. 既存例外ルール 3 種 (.claude/rules/mode-classification.md L44-48)

```text
**例外ルール**:
- セキュリティ関連の変更 → 最低でも「中」
- データベーススキーマ変更 → 最低でも「高」
- 公開 API の破壊的変更 → 最低でも「超高」
```

→ **本 PBI で「承認境界周辺の変更 → 最低でも『高』」を 4 番目に追加**。

## 2. Hardening Override 対象パス (`scripts/hooks/check-plan-hash.sh` L106/122/136)

10 パターン: `.claude/settings*.json` / `.claude/rules/` / `.claude/agents/` / `.claude/skills/` / `.claude/commands/` / `scripts/hooks/` / `scripts/_*.py` / `bin/plangate` / `schemas/` / `.github/workflows/` (+ `AGENTS.md` / `CLAUDE.md`)

新例外ルールの対象パス一覧と完全一致させる ＝ single source of truth。

## 3. working-context.md AC-10 / AC-8 参照箇所 (L313 / L321-324)

- L313: AC-8 安全側 (判定不能 → 同期)
- L321-324: AC-10 Hardening Override (Shadow Config / 承認境界 / 責務4分類 / Critical Infra → lite_eligible=false + 同期 C-3 強制)

→ 本 PBI の新例外ルールは working-context.md と **相互参照のみ** (重複定義しない)。

## 4. TASK-0106 retrospective 由来の提案文言 (L56, L87, L96)

```text
- 「承認境界周辺は最低 high-risk」 (Try 項目)
- 「mode-classification.md 例外ルールに承認境界周辺を追加」 (新規 PBI 候補)
- mode-classification.md 例外ルール拡張 RFC (Owner: AI)
```

→ TASK-0106 R-012 retrospective Try アクションの構造化。

## 5. 監査ログ一括変更例 (TASK-0110)

監査ログ位置: `docs/working/_audit/` (skip-decision-log.jsonl, hook-events.log 等)。

→ 「監査ログ一括変更 CLI」も承認境界相当として最低「高」 (TASK-0110 #301 が代表例) を例外ルールに追記。

## 6. 規模メトリクス検証 (TASK-0117 #351 先行適用)

| 項目 | plan 見積もり | 実数 | 比率 |
|------|--------------|------|------|
| 変更ファイル数 | 1 + handoff | 2 | 1.0〜2.0 倍 |
| 受入基準数 | 6 | 6 | 1.0 倍 |
| Mode | light | light 維持 | — |

TASK-0117 (#351) 判定基準「1〜3 倍」→ 採用、Mode 降格不要。

## 7. T-01 結論

### 確定事項

1. 既存例外ルール 3 種を破壊せず additive change
2. 対象パス 10 種は `scripts/hooks/check-plan-hash.sh` の `HARDENING_OVERRIDE` パターンと完全一致 (single source of truth)
3. working-context.md AC-10 / AC-8 と相互参照のみ
4. TASK-0106 retrospective Try アクションを構造化
5. 監査ログ一括変更 CLI も例外ルール対象として明示 (TASK-0110 例示)

### T-02 (exec、c3.json APPROVED + maintenance window 後) 着手内容

`.claude/rules/mode-classification.md` の「例外ルール」セクション (L44-48) に以下を追加:

```markdown
- **承認境界周辺の変更 → 最低でも「高」**（TASK-0106 Retrospective 由来）
  - 対象パス（Hardening Override 対象と一致）:
    - `.claude/settings*.json` / `.claude/rules/` / `.claude/agents/` / `.claude/skills/` / `.claude/commands/`
    - `scripts/hooks/` / `scripts/_*.py`（hook 補助スクリプト）
    - `bin/plangate`
    - `schemas/`
    - `.github/workflows/`
    - `AGENTS.md` / `CLAUDE.md`
  - 上記パスに touch する PBI は **`lite_eligible=false` 強制 + Standard C-3 同期固定**（[`working-context.md`](./working-context.md) C-3 条件付き降格 §AC-10 Hardening Override と整合）
  - 監査ログ（`docs/working/_audit/`）の **データ一括変更** CLI も承認境界相当として扱い、最低「高」（例: TASK-0110 skip-decision-log 一括 acknowledge）
- **自動推定の安全側**: 上記例外条件のいずれかが該当不確実な場合は**該当扱い**（mode を引き上げる側）にする（[`working-context.md`](./working-context.md) AC-8 安全側不変条件と一貫）
```

### 残作業 (c3.json APPROVED + maintenance window 後)

T-02 (mode-classification.md 追記) → T-03 (handoff + V-1) → PR → C-4 → merge。
