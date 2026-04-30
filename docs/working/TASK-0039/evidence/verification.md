# Verification — TASK-0039 Step 7

> 検証実施: 2026-04-30 / 本 PR (PR-B `feat/PBI-116-01-impl-pr-b`) 完了時点
> baseline: PR #131 マージ後 main `7cecb43`（[`baseline.md`](./baseline.md) 参照）

## TC-3 / TC-4: 行数削減（受入基準 AC-2 + 親 AC-8 対応）

| ファイル | baseline | 結果 | 削減率 | 目標 | 判定 |
|---------|---------|------|------|------|------|
| `CLAUDE.md` | 43 行 | **21 行** | **-51%** | 22 以下 | **PASS** |
| `AGENTS.md` | 61 行 | **29 行** | **-52%** | 30 以下 | **PASS** |

PR-A (#133 / `fa9be67`) で達成済。本 PR-B では維持確認のみ。

## TC-5: hard-mandate 残存検証（受入基準 AC-3 対応）

```bash
grep -rnE "必ず|絶対|ALWAYS|NEVER" CLAUDE.md AGENTS.md docs/ai/ .claude/ plugin/plangate/ .agents/skills/ 2>/dev/null | grep -v "worktrees" | wc -l
# Result: 21 件（全て Iron Law / AI 運用 4 原則 / 仕様明確化として保持判定）
```

### 残存 21 件の保持理由

| 区分 | 件数 | 例 |
|------|-----|-----|
| AI 運用 4 原則本文（CLAUDE.md / project-rules.md 正本） | 4 | 「必ず作業計画を報告」「絶対的に遵守」 |
| 開発ルール（main コミット禁止 / branch 必須）| 1 | project-rules.md L48 |
| Iron Law (`NEVER IMPLEMENTS` 等のテンプレ例) | 4 | prompt-engineer / workflow-conductor agents |
| Iron Law 相当（テスト回帰なし / 抑制順序 / ゲート停止 / テスト PASS 維持 / コードベース由来）| 8 | linter-fixer / workflow-conductor / code-optimizer / ai-dev-workflow.md |
| Hook 説明文（不変制約の概念）| 1 | hybrid-architecture.md L68 |
| 仕様明確化（confidence 反映 / Owner 明記）| 2 | intent-classifier SKILL / ai-dev-plan SKILL |
| Plugin 同期分（.claude/ → plugin/plangate/） | 1 | plugin/plangate/commands/ai-dev-workflow.md L316 |

→ **全件保持判定**。削減対象（手順指定の冗長表現）はゼロに到達。

### 削減対象（必須 7 + 推奨 1 + 表記統一 4 = 計 12 箇所）の対応結果

| Inventory 区分 | 対応件数 | 結果 |
|--------------|---------|------|
| 必須削減（手順指定の冗長表現） | 7 件 | **全件削減完了** |
| 推奨削減（言い換え可能） | 1 件 + 同期 2 件 = **3 件** | **全件削減完了** |
| 表記統一（「絶対ルール」→「Iron Law」） | 4 件（.claude + plugin） | **全件統一完了** |
| 個別レビュー要（agents 4 件） | 4 件 | **全件保持判定**（Iron Law 相当の表現で削減すべきでないと判断） |

## TC-7: 既存ゲート維持検証（受入基準 AC-5 対応）

```bash
grep -nE "C-3|C-4|scope discipline|verification honesty" docs/ai/core-contract.md
```

Result:
- `core-contract.md` Hard constraints セクションに Iron Law 7 項目（C-3 承認 / scope / verification honesty 等）が **MUST 相当として明示**
- 表 7 項目すべて「即停止」を hard constraint として記述

```bash
grep -E "core-contract" CLAUDE.md AGENTS.md
```

Result:
- `CLAUDE.md` L3: `> **実行契約**: docs/ai/core-contract.md ...`
- `AGENTS.md` L3: 同上

→ **Core Contract への入口からの到達性が確保されている** ✅

## TC-8: リンク到達性

PR-A (#133) で全件確認済。本 PR-B での新規追加・変更ファイル:
- `docs/ai-driven-development.md` （内容修正のみ、新規参照追加なし）
- `.claude/rules/working-context.md` / `plugin/plangate/rules/working-context.md` （内容修正のみ）
- `.claude/commands/ai-dev-workflow.md` / `plugin/plangate/commands/ai-dev-workflow.md` （Core Contract への参照追加 → ✅ 解決可能）
- `.claude/skills/self-review/SKILL.md` / `plugin/plangate/skills/self-review/SKILL.md` / `.agents/skills/self-review/SKILL.md` （文言変更のみ）

→ **新規リンク切れ 0 件**

## TC-E1: Iron Law 重複の整理

`docs/ai-driven-development.md` の Iron Law 6 項目（L102-109）と `docs/ai/core-contract.md` の Iron Law 7 項目の重複:

- ai-driven-development.md L479「絶対ルール」→「Iron Law（不可侵ルール）」に表記統一済
- ai-driven-development.md の 6 項目本文は **既存履歴として保持**（PR-B では削除しない）
- core-contract.md が **正本**、ai-driven-development.md は履歴的参照として共存
- 将来的な完全統合は V2 候補

## TC-E2: Plugin 配布版の同期確認

```bash
diff .claude/rules/working-context.md plugin/plangate/rules/working-context.md
```

両者は v8.1 ガードレール固有の差分を除いて同期済（hard-mandate 削減も両方適用）。

## TC-E3 / TC-E4: 手動 E2E（保留）

C-1 review-self.md / C-2 review-external.md で WARN（手動 E2E 自動化困難）として認識済。本 PR では実行せず、子 PR の C-4 ゲートでユーザー確認に委ねる。

- TC-E3: Codex CLI 起動確認 — 未実施
- TC-E4: Claude Code 起動確認 — 未実施

`evidence/verification.md` に未実施理由を明記（本ファイル）。

## 受入基準 6 項目の総合判定

| 受入基準 | TC | 判定 |
|---------|----|----|
| AC-1: Core Contract が outcome-first 形式で定義 | TC-1, TC-2 | ✅ PASS（PR #132） |
| AC-2: 常時ロード薄型化 | TC-3, TC-4 | ✅ PASS（PR #133、CLAUDE 21 / AGENTS 29） |
| AC-3: hard-mandate 限定 | TC-5 | ✅ PASS（残存 21 件すべて保持理由あり） |
| AC-4: phase の success criteria / stop rules | TC-6 | ✅ PASS（core-contract.md §3, §7） |
| AC-5: 既存ゲート維持 | TC-7 | ✅ PASS（Core Contract から MUST 相当で参照、入口から到達可能） |
| AC-6: plugin / .claude 整合 | TC-8 | ✅ PASS（新規リンク切れ 0 件、TC-E2 同期確認済） |

**総合判定: PASS（6/6）**

## メタ情報

| 項目 | 値 |
|------|---|
| 検証実施日時 | 2026-04-30 |
| 検証者 | Claude（自動）+ s977043（PR レビュー予定） |
| 検証コミット | 本 PR の最新 HEAD |
| 関連 evidence | `inventory.md` / `baseline.md` |
