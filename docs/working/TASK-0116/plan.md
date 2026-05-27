# TASK-0116 EXECUTION PLAN

> Source: pbi-input.md / Issue #354 / Mode: **standard**
> Generated: 2026-05-26

## Goal

PlanGate workflow に **NO RELEASE WITHOUT TAG-MAIN PARITY** Iron Law と機械検証 script を追加し、tag-main mismatch を構造的に防ぐ。`scripts/check-tag-main-parity.sh` の機械検証で release 直前の人間オペレーションを支援。

## Constraints / Non-goals

- 既存 release skill の本体改修なし (follow-up)
- AI 自律 tag push 禁止 (TASK-0114 P-1 と整合)
- `.claude/rules/` 追記は Hardening Override 経由

## Approach Overview

PocketEitan `.claude/commands/release.md` Phase 5 の最小ポート + PlanGate 既存 `.claude/rules/responsibility-classes.md` §publish 責務分界 への統合。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01 調査**: 既存 release 関連 docs / `.claude/commands/` / scripts 把握、PocketEitan 実装パターン参照 | 調査メモ | AI | low | 既存資産マップ |
| 2 | **T-02 script**: `scripts/check-tag-main-parity.sh` (POSIX sh、引数 tag、`^{commit}` peel、exit 0/1) | scripts/check-tag-main-parity.sh | AI | medium | tag/main 比較動作 |
| 3 | **T-03 doc**: `docs/release-process.md` (新規 or 既存追記) Iron Law + 検証フロー + 失敗時 `-f` 貼り替え手順 | docs/release-process.md | AI | low | Human 運用可能 |
| 4 | **T-04 rule link**: `.claude/rules/responsibility-classes.md` §publish 責務分界 に検証手順 link 追記 | .claude/rules/responsibility-classes.md | AI | medium (Hardening Override) | maintenance window 経由 + markdownlint |
| 5 | **T-05 test**: `tests/extras/ta-18-tag-main-parity.sh` fixture 3 case (一致/不一致/tag 不在) | tests/extras/ta-18-tag-main-parity.sh | AI | low | ta-18 全 PASS |
| ~~T-06 (stretch)~~ | ~~bin/plangate doctor 統合~~ | — | — | **本 PBI から除外** | V2 候補に降格 (Codex 9 PBI review 反映、bin/plangate は HO で改修コスト高) |
| 7 | **T-07 handoff + V-1** | handoff.md | AI | low | AC-1..6 PASS (AC-7 任意) |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `scripts/check-tag-main-parity.sh` | 新規 (POSIX sh) |
| `docs/release-process.md` | 新規 or 既存追記 |
| `.claude/rules/responsibility-classes.md` | 追記 (**Hardening Override**) — TASK-0115 (INC P-3) が編集する section と同 file。**順序**: TASK-0115 が先 (Bash 連結 error guard) → 本 PBI が後 (publish 責務分界 link 追記) で衝突回避 (Codex 9 PBI review 反映) |
| ~~bin/plangate~~ | ~~stretch~~ | **削除**: V2 候補に降格 (HO 改修コスト高、機械検証 script で代替可) |
| `tests/extras/ta-18-tag-main-parity.sh` | 新規 |
| `docs/working/TASK-0116/handoff.md` | WF-05 |

## Testing Strategy

- Unit: fixture tmp git repo で tag/main 比較 (3 case)
- Integration: 実 PlanGate repo の最新 tag で動作確認 (read-only)
- 回帰: tests/run-tests.sh + tests/hooks/run-tests.sh
- markdownlint + shellcheck

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| 既存 release skill と重複定義 | low | 本 PBI は Iron Law + 検証 script のみ、skill 改修は follow-up |
| force push (`git push -f`) 濫用 | medium | 検証失敗時のみ + Human オペレーション固定 + 監査ログ docs に明示 |
| Hardening Override 対象改修が EH-3 で block | high | C-3 APPROVED + maintenance window (TASK-0106/0112/0115 で実証済) |
| lightweight tag vs annotated tag 揺れ | low | `^{commit}` peel で吸収、TC-03 で確認 |

## Mode 判定 (Codex 9 PBI review 反映)

**standard** (lite_eligible=false)

- 変更ファイル数: 5 (新規 + 既存追記、stretch AC-7 削除)
- 受入基準数: **6** (旧 stretch AC-7 削除済)
- 変更種別: script + docs + rule (bin/plangate なし)
- リスク: 中 (Hardening Override 対象 `.claude/rules/` を含む)
- ロールバック: 容易
- 影響範囲: release プロセス全般、AI 自律 tag は元々禁止のため AI 行動への影響限定

→ **standard** 確定。`.claude/rules/responsibility-classes.md` 改修は TASK-0112 例外ルールに該当する見込みだが、本 PBI 内では TASK-0115 (INC P-3) と同 file への追記順序で衝突回避 (TASK-0115 が先)。

**TASK-0115 との重複整理 (Codex review 反映)**:
- TASK-0115 (INC P-3): `.claude/rules/responsibility-classes.md` に「Bash 連結コマンド error guard」セクション追加
- 本 PBI (TASK-0116): 同 file の §「対外公開アーティファクト publish 責務分界」に検証手順 link 追記
- **順序**: TASK-0115 が先で base section 確立、本 PBI が後で link 追加 (rebase 不要、conflict なし設計)
