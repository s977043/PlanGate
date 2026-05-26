# TASK-0116 PBI INPUT PACKAGE

> Issue: [#354](https://github.com/s977043/plangate/issues/354)
> 同系の governance hardening: INC-2026-05-26-001 / TASK-0114 (P-1) / TASK-0115 (P-3)

## Context / Why

annotated tag を打った後、tag が指す commit と `origin/main` の最新が一致しない事態が過去に発生 (s977043 memory `feedback_release_tag_collision_verify.md`、PocketEitan の `.claude/commands/release.md` Phase 5 で既に対策実装済)。

PlanGate workflow にも **NO RELEASE WITHOUT TAG-MAIN PARITY** Iron Law を追加し、tag push → 検証 → 不一致時 force update → 再検証 のフローを必須化する。

INC-2026-05-26-001 / TASK-0114 / TASK-0115 と同じ governance hardening 系列。

## What (Scope)

### In scope

- PlanGate workflow docs (`docs/workflows/` or `docs/release-process.md`) に Iron Law 追記
- `.claude/rules/responsibility-classes.md` §「対外公開アーティファクト publish 責務分界」に検証手順 link
- `scripts/check-tag-main-parity.sh` (新規) — `[ "$(git rev-parse <tag>^{commit})" = "$(git rev-parse origin/main)" ]` で機械検証
- `bin/plangate doctor` 統合 (option): 最新 tag vs main の整合確認
- `docs/ai/release-process.md` (新規 or 既存追記) — 検証フロー手順書 + 失敗時 `-f` 貼り替え手順
- `tests/extras/ta-18-tag-main-parity.sh` (新規) fixture test

### Out of scope

- 既存 release skill (`.claude/commands/release.md` 等) の本体改修 (本 PBI は Iron Law + 検証 script 追加のみ、skill 統合は follow-up)
- `git tag` 自動化 (Iron Law は AI 自律 tag を許可しない、Human オペレーション)

## 受入基準

- AC-1: `docs/release-process.md` (新規 or 既存) に **NO RELEASE WITHOUT TAG-MAIN PARITY** Iron Law が追加
- AC-2: `scripts/check-tag-main-parity.sh` (新規) で `git rev-parse <tag>^{commit}` vs `git rev-parse origin/main` の機械検証、不一致時 exit 1
- AC-3: `.claude/rules/responsibility-classes.md` §publish 責務分界 に本検証手順への link
- AC-4: 検証失敗時の `-f` 貼り替え手順が docs に明示 (Human オペレーション)
- AC-5: `tests/extras/ta-18-tag-main-parity.sh` fixture 3 case: 一致 / 不一致 / tag 不在
- AC-6: 既存テスト regression なし + markdownlint + shellcheck PASS
- AC-7: `bin/plangate doctor` で latest tag vs main の事後確認 section を追加 (任意、stretch goal)

## Notes from Refinement

- PocketEitan 実装 (`.claude/commands/release.md` Phase 5) を参考に最小ポート
- `.claude/rules/` 追記は Hardening Override 対象 → C-3 APPROVED + maintenance window
- `bin/plangate` 追記も Hardening Override 対象 → 同上 (AC-7 は stretch、必須化しない)
- annotated tag のオブジェクト SHA vs commit SHA の混同を `^{commit}` で吸収

## Estimation

### Risks

- 既存 release skill との重複定義 → mitigation: 本 PBI は Iron Law + 検証 script のみ、skill 改修は follow-up
- force push (`git push -f`) の濫用リスク → mitigation: 検証失敗時のみ + Human オペレーション固定 + 監査ログ
- ローカル test で実 tag/main を弄れない → mitigation: fixture tmp git repo で再現

### Unknowns

- doctor 統合 (AC-7) の要否 (stretch goal で C-3 判断)
- annotated tag 以外 (lightweight tag) の扱い (`^{commit}` で吸収するが test で確認)

### Assumptions

- `git rev-parse` の `^{commit}` peeling 仕様は不変
- release は Human-owned (tag push / GitHub Release create は AI 不可、TASK-0114 P-1 と整合)
