# PBI INPUT PACKAGE: TASK-0048 / Issue #157

> Source: [#157 [EPIC] Hook enforcement 実装 — plan 未承認 block / forbidden_files 違反 block](https://github.com/s977043/plangate/issues/157)
> Mode: **critical**

## Context / Why

v8.3.0 で `docs/ai/hook-enforcement.md` に Hook 強制項目（EH-1〜EH-7 / EHS-1〜EHS-3）を仕様化したが、**実装が未着手**。Iron Law / scope discipline / approval discipline をハード強制する仕組みが存在しない。本 PBI で実装層を Claude Code Hook + CLI ツールに落とし込む。

## What

### In scope
- `scripts/hooks/check-c3-approval.sh`（EH-2: plan / C-3 未承認 exec block、PreToolUse hook）
- `scripts/hooks/check-handoff-elements.sh`（EHS-2: handoff 必須 6 要素チェック、CLI）
- `scripts/hooks/check-fix-loop.sh`（EHS-3: V-1 fix loop 上限超過 escalation、CLI）
- `.claude/settings.example.json`（opt-in 設定例、実 settings.json への反映は PR 後の手動操作）
- `tests/hooks/run-tests.sh`（hook 単体テスト、12 件）
- `tests/run-tests.sh` への TA-06 統合
- `docs/ai/hook-enforcement.md` を **Status: v2 / Implementation: Done** に更新（実装済 hook の説明、未実装の Spec の明示）
- bypass 条件 Spec 化（環境変数 `PLANGATE_BYPASS_HOOK=1` + 監査 log）

### Out of scope
- 全 EH-1〜EH-7 + EHS-1 の実装（次回 PBI に分割）
- Codex / Gemini 側 wrapper（本 PBI は Claude Code Hook + 共通 CLI のみ）
- Hook 違反の自動修正

## Acceptance Criteria

- AC-1: c3.json 不在時に Edit / Write / Bash が block される（PreToolUse、strict mode 有効時）
- AC-2: handoff.md 必須 6 要素欠落時に CLI で WF-05 完了が block される（strict mode 有効時）
- AC-3: fix loop 5 回超過時に CLI で ABORT escalation が走る（strict mode 有効時）
- AC-4: 各 hook が `tests/hooks/run-tests.sh` で PASS する（12 件全 PASS）
- AC-5: bypass 条件（`PLANGATE_BYPASS_HOOK=1`）が Spec 化されている + 監査 log 記録
- AC-6: `docs/ai/hook-enforcement.md` が「Implementation: Done」に更新されている
- AC-7: 既存ワークフロー（`/ai-dev-workflow`）が新 hook 下で正常動作する（default = warning モードで作業妨害なし）

## Notes

- 推奨 mode: **critical**（実行ブロックを伴うハード強制、誤検出時のリカバリ手段必須）
- 依存: なし（v8.3.0 仕様は単独実装可）
- 関連: `.claude/rules/hybrid-architecture.md`「強制力の軸」セクション
- **3 モード設計**:
  - default（warning のみ、continue:true）
  - `PLANGATE_HOOK_STRICT=1`（block）
  - `PLANGATE_BYPASS_HOOK=1`（escape）
- AC-1〜AC-3 の "block される" は **strict mode 有効時** の挙動として実装（誤検出による作業妨害リスクの軽減と両立）
