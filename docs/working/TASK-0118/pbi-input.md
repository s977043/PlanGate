# TASK-0118 PBI INPUT PACKAGE

> Issue: [#352](https://github.com/s977043/plangate/issues/352)
> Codex 推奨優先順 A (2026-05-28): #352 codex-mvp-split を PBI 化
> 出自: PocketEitan で 2 例の MVP 分割を Codex 相談で実施、属人化解消

## Context / Why

PlanGate A フェーズ (PBI INPUT PACKAGE 作成) に着手する前段で、**規模 L 以上の機能は最小 MVP (Phase 1) を Codex に選定相談する** プロセスを標準化する。

属人化された質問テンプレを skill / command 化し、Phase 分割設計を再現可能にする。

PocketEitan で 2 例実証済:
- 例文音読カード (規模 L、4 Phase に分割) → v0.16.0
- TASK-srs-unification (規模 standard〜full、2 Phase) → v0.15.0

## What (Scope)

### In scope

- **`.claude/commands/codex-mvp-split.md`** (新規) — Claude Code slash command
- **`.agents/skills/codex-mvp-split/SKILL.md`** (新規) — Codex / 他 provider 共用 skill
- 質問テンプレ標準化:
  - 背景 / 質問 / 工数感 (S/M/L) / 判断材料 3 軸 (ユーザ価値 / 実装独立性 / 次フェーズ拡張性)
- 採用後の **Phase 分割表** を PBI INPUT PACKAGE 必須要素に追加
- TASK-0117 (#351 事前メトリクス検証) との接続: 規模見積もりで L 以上判定 → 本 skill 起動
- `docs/ai/codex-mvp-split.md` 運用ガイド
- `tests/extras/ta-21-codex-mvp-split.sh` (skill 構造検証 + テンプレ含有確認)

### Out of scope

- Codex への自動 dispatch (本 skill は質問テンプレ提供のみ、Codex 起動は Human / CLI 側)
- L 未満の規模での自動起動 (現状: Human 判断 or TASK-0117 規模判定で起動推奨)

## 受入基準

- AC-1: `.claude/commands/codex-mvp-split.md` (slash command 形式) 新規
- AC-2: `.agents/skills/codex-mvp-split/SKILL.md` (frontmatter + Read First + 入出力規約) 新規
- AC-3: 質問テンプレに 4 選択肢 (A/B/C/D) + 工数感 (S/M/L) + 判断材料 3 軸 含む
- AC-4: 採用後の Phase 分割表 template が PBI INPUT PACKAGE に追加される旨を `docs/working/templates/pbi-input.md` で記述 (or 該当 doc)
- AC-5: TASK-0117 (#351) 事前メトリクス検証で「規模 L 以上」判定された場合、本 skill 起動推奨を skill / doc に明記
- AC-6: 既存実例 ≥ 2 件 (PocketEitan 例文音読カード / TASK-srs-unification) を doc に literal text で記載
- AC-7: `tests/extras/ta-21-codex-mvp-split.sh` で skill 構造を機械検証 (該当セクション grep)
- AC-8: markdownlint + 既存テスト regression なし

## Notes from Refinement

- `.claude/commands/` も `.agents/skills/` も Hardening Override 対象なので C-3 APPROVED + Human-owned patch 設計 (TASK-0112 と同方針)
- 質問テンプレは PocketEitan 実装を最小ポート (案 A/B/C/D + 工数 S/M/L + 判断 3 軸)
- TASK-0117 との連携は相互参照のみ (重複定義なし、AND 関係)

## Estimation

### Risks
- LLM 解釈依存のソフトルール (本 skill は質問テンプレ提供のみ、回答品質は Codex 次第) → mitigation: 質問テンプレで 3 軸明示
- L 規模判定が曖昧 → mitigation: TASK-0117 事前メトリクス検証と連携

### Unknowns
- `.agents/skills/` 配下に置くか `.claude/commands/` 配下か → T-01 で確定 (両方推奨)

### Assumptions
- PocketEitan PR #371 (`.claude/commands/codex-mvp-split.md`) を参考実装として利用可能 (外部 repo)
- TASK-0117 (#351、merged) の事前メトリクス検証で「実数 / 見積もり ≥ 3 倍」判定が L 規模相当
