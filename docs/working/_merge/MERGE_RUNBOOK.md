# マージ手順書 — フィードバック対応 PR #242〜#250（2026-05-17）

> 全 PR: CI 100% pass / MERGEABLE / CLEAN / 非ドラフト。
> 残ゲート: ruleset「Protect default branch」の承認レビューのみ（AI バイパス禁止＝
> ユーザーが GitHub Web で formal review/admin override）。
> **逐次マージで 3 箇所の競合が確実に発生**するため本手順書で順序と解決方針を固定。

## 推奨マージ順と競合マップ

| 順 | PR | 主変更 | 後続との競合 | 競合解決方針 |
|----|----|--------|------------|-------------|
| 1 | #242 | .codex/agents/*.toml | なし | そのまま |
| 2 | #243 | check-plan-hash.sh / **tests/hooks/run-tests.sh** | #246 と run-tests.sh | #243 を先、#246 マージ前に #246 ブランチを update（#243 の P4d テストブロックを残し EH-9 ブロックを後段に併存）|
| 3 | #245 | **core-contract.md / execute.md / 04** + conductor / ai-dev-workflow | #246 と core-contract/execute.md/04 | #245 を先（§5-bis 正本を確立）。#246 は §5-bis 参照側 |
| 4 | #246 | **core-contract.md / execute.md / 04** / hook-enforcement / EH-9 / auth-preflight / **run-tests.sh** | #243(run-tests.sh) #245(core-contract/execute/04) | マージ前に `gh pr update-branch 246`→競合を解決: ①run-tests.sh=#243のP4dブロック + #246のEH-9/auth-preflightブロックを**両方併存** ②core-contract.md=#245 §5-bis の後に #246 の Decision-rule 行を追加 ③execute.md=#245 capability preflight 節の後に #246 F2 プリフライト節（既に F2 は「#245 マージ後 §5-bis 統合」と handoff 明記済→統合は別 follow-up）④04=両方の完了条件行を併存 |
| 5 | #247 | bin/plangate / design-ui-addendum.md | なし | そのまま |
| 6 | #248 | **working-context.md** / retro-phase / 06_retro / README(workflows) | #249 と working-context.md | #248 を先（improvement-seeds 節追加）。README(workflows) は #248 のみ |
| 7 | #249 | **working-context.md** / review-principles.md / ai-dev-plan.sh | #248(working-context.md) | マージ前に `gh pr update-branch 249`→working-context.md: #248 の improvement-seeds 節と #249 の C-2差分管理節は**別セクションで併存**（競合は隣接ハンク。両方残す）|
| 8 | #250 | docs/working のみ（実装変更なし） | なし | そのまま（計画パッケージ・C-4 doc レビュー） |

## 競合が起きる具体ファイルと併存方針（要点）

1. **tests/hooks/run-tests.sh**（#243→#246）: 両者とも EH 追加。**順序: P4d(TC-1〜13) → EH-9 → auth-preflight を直列併存**。削除し合わない。
2. **docs/ai/core-contract.md**（#245→#246）: #245=§5-bis 実行環境不変条件、#246=Decision-rule 1 行（委譲境界/認証）。**§5-bis を残し Decision-rule 行を追加**（独立追記・論理競合なし）。
3. **docs/ai/contracts/execute.md**（#245→#246）: #245=capability preflight 節、#246=F2 プリフライト節。**両節併存**。F2 側は「#245 マージ後 §5-bis へ統合」と handoff 既知課題に明記済 → 統合は別 follow-up PBI。
4. **docs/workflows/04_build_and_refine.md**（#245→#246）: 各々が完了条件に1行追加。**両行併存**。
5. **.claude/rules/working-context.md**（#248→#249）: #248=improvement-seeds 節、#249=C-2差分管理節。**別セクション併存**（隣接ハンク競合のみ・内容は独立）。

## マージ後 follow-up（別 PBI / 要ユーザー操作）

- TASK-0070 AC-8 wiring 手動 sed（.claude/settings*.json・self-mod ガードで AI 不可）
- F2 §5-bis 統合（execute.md F2 節を #245 §5-bis 配下へ移設・重複削除）
- EH-9 wiring 手動（.claude/settings*.json PreToolUse 追加）
- F4 retro CLI / F5-AD 実装 PBI 起票（AC-8〜13 継承）
- TASK-0071 S1+S2 exec（#242/#243 マージ後に着手可）

## AI 制約（遵守事項）

- マージ・admin override・別アカウント承認・ruleset 改変は **行わない**（sockpuppet 禁止）
- `gh pr update-branch <n>` による競合事前解決は、各 PR の**先行 PR マージ確定後**に実施（未マージ状態での投機的 rebase はしない）
