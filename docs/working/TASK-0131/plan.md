# EXECUTION PLAN — TASK-0131 (#565)

## Goal
todo.md の各実装タスクに「タスク粒度のロールバック手順」を表現する規約を追加し、high-risk / critical mode で必須化する。戻し手順が plan.md Risks に散在する現状を、タスク単位で参照可能にする。

## Constraints / Non-goals
- 新規 `docs/working/templates/todo.md` は作らない（working-context / skill との三重正本化を避ける / Codex 助言 A-3）。
- `mode-classification.md` の既存ロールバック定性基準は変更しない（参照のみ）。
- `plan.md` Risks 構造は改変しない（責務分界で整理）。
- #566 / #567 は対象外。

## Approach Overview（Codex 設計相談 d: 組合せ を採用）
1. **正本の責務宣言** → `.claude/rules/working-context.md`（HO 対象 → AI 編集せず apply-script を生成し人間が適用）
2. **生成規約** → `ai-dev-plan` SKILL の「todo.md 規約」に `rollback:` インラインキーと mode 別必須を追記（正本 `.agents/` + 正規ミラー `.codex/` `plugin/plangate/`。override 外のため AI 編集可）
3. **欠落検出** → C-1 セルフレビュー（`plan-quality-check` skill / `review-self.md` テンプレ）に「high-risk/critical で rollback 欠落 → FAIL」を追加（override 外）
4. **表現** → 既存1行形式を維持し `rollback:` を追加。長手順のみ直下補助ブロック許可。

## Work Breakdown
- **S1** working-context.md に rollback 規約（責務分界 D + mode 別必須 C）を追記する apply-script + patch を**生成**（AI は適用しない）
  - Output: `scripts/apply-task-0131-rollback.sh`（または patch） / Owner: agent / Risk: HO 適用漏れ / 🚩HO（人間適用）
- **S2** ai-dev-plan SKILL「todo.md 規約」に `rollback:` キー + mode 別必須 + 補助ブロック許可を追記（`.agents/` 正本 → `.codex/` `plugin/plangate/` 同期）
  - Output: 3 ファイル差分 / Owner: agent / Risk: ミラー drift / 🚩 正本→ミラー同期検証
- **S3** `plan-quality-check` skill（および `review-self.md` テンプレ）に rollback 欠落検出項目を追加
  - Output: skill/テンプレ差分 / Owner: agent / Risk: 既存17項目との重複
- **S4** 記入サンプル追加（本 TASK の todo.md 自体をドッグフーディング例にする）
  - Output: todo.md の rollback 記入例 / Owner: agent / Risk: なし

## Files / Components to Touch
- `.claude/rules/working-context.md`（**HO → apply-script 経由・人間適用**）
- `.agents/skills/ai-dev-plan/SKILL.md` + `.codex/skills/ai-dev-plan/SKILL.md` + `plugin/plangate/skills/ai-dev-plan/SKILL.md`（AI 編集可）
- `.claude/skills/plan-quality-check/SKILL.md`（AI 編集可）
- `docs/working/templates/review-self.md`（C-1 テンプレ・AI 編集可）

## Testing Strategy
- Unit/機械: `grep` で 3 ミラー間の `rollback:` 規約一致を検証、markdownlint、`bin/plangate doctor`
- Integration: 本 TASK todo.md に rollback 記入 → `bin/plangate validate TASK-0131` 整合
- Verification: C-1 セルフレビューで rollback 欠落検出ロジックが high-risk で発火することを手動確認

## Risks & Mitigations（内容 / 検証手段 / Fallback）
- R1 HO 適用漏れで working-context 正本だけ未反映 / doctor + grep 突合 / apply-script 未適用なら V-1 を PASS にしない（settings タスクロックと同型）
- R2 ai-dev-plan 正本とミラーの drift / grep 3 ファイル一致検証 / 不一致なら同期し直す
- R3 C-1 への項目追加で既存チェックと重複・誤検出 / 既存17項目を読み差分のみ追加 / 過検出時は条件を high-risk/critical に限定

## Metrics Evidence
- 対象「ai-dev-plan SKILL ミラー全件」: 実数 4（`find` 実測）/ 見積もり 3 / ratio 1.33 → 採用、Risks R2 に記録。うち `.claude/worktrees/agent-ae384a6baedaaef08/` 1 件は worktree 残骸で同期対象外、正規ミラーは 3。

## Questions / Unknowns
- working-context.md の rollback 規約を「役割表」に足すか新規節にするか → apply-script 生成時に最小差分で決定。

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 6（working-context + skill×3 + plan-quality-check + review-self）→ high
- 受入基準数: 4 → standard
- 変更種別: 承認境界周辺（`.claude/rules/*.md` = HO 対象）→ **最低 high-risk 強制**（mode-classification 例外ルール）
- リスク: 中〜高（正本/ミラー整合・HO 適用）
- **最終判定**: high-risk（`lite_eligible=false`・Standard 同期 C-3 固定・autonomous APPROVE 不可・人間 C-3 必須）
