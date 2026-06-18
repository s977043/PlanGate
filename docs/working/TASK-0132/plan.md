# EXECUTION PLAN — TASK-0132 (#566)

## Goal
plugin 専用の intent-classifier / skill-policy-router を本体（`.claude/skills/`）正本へ移し、mode-classification.md との重複を解消し、WF-00 に advisory 配線する。初回は advisory に限定し強制化はしない。

## Constraints / Non-goals
- 初回は **advisory のみ**（gate 機械強制は別 PBI）。
- bin/plangate 実装配線は初回スコープ外（将来 thin entrypoint）。
- GatePolicy schema 厳密化はスコープ外。
- #565 / #567 と独立。

## Approach Overview（Codex 設計相談）
1. **正本移動**: `.claude/skills/{intent-classifier,skill-policy-router}/SKILL.md` を新設（plugin から移植）、plugin 側は mirror として残す（hybrid Rule: .claude 正本・plugin export）。
2. **重複解消**: skill-policy-router の Mode別ポリシー表を削除 → `mode-classification.md` フェーズ適用マトリクス + lite_eligible を単一正本として参照。
3. **advisory 配線**: `docs/workflows/00_*`（WF-00）に「依頼→intent-classifier→mode判定(lite_eligible含む)→skill-policy-router→GatePolicy→ai-dev-plan 前段」を advisory フローとして記述。

## Work Breakdown
- **S1** `.claude/skills/intent-classifier/SKILL.md` 正本新設（plugin 内容を移植・本体向け） / Owner: agent / Risk: 重複定義 / 🚩
- **S2** `.claude/skills/skill-policy-router/SKILL.md` 正本新設 + **Mode別ポリシー表を mode-classification 参照に置換** / Owner: agent / Risk: 参照リンク切れ
- **S3** plugin 側 2 スキルを mirror として整合（export 注記 or 同期）/ Owner: agent / Risk: drift
- **S4** WF-00 に advisory 配線を文書化 / Owner: agent / Risk: 既存 WF との不整合
- **S5** lite_eligible 責務（classifier/mode/router 分界）を明記 / Owner: agent

## Files / Components to Touch
- `.claude/skills/intent-classifier/SKILL.md`（新規・AI 可：skills は override 外）
- `.claude/skills/skill-policy-router/SKILL.md`（新規・AI 可）
- `plugin/plangate/skills/{intent-classifier,skill-policy-router}/SKILL.md`（mirror・AI 可）
- `docs/workflows/00_*.md`（WF-00 advisory・AI 可）
- 参照のみ: `.claude/rules/mode-classification.md`（編集しない＝単一正本のまま参照）

## Testing Strategy
- 機械: `.claude/skills` 正本と plugin mirror の diff 一致、router に Mode別表が残っていないことの grep、WF-00 に advisory フロー記述の grep
- レビュー: hybrid-architecture 正本/export 方向の整合、mode-classification との重複ゼロ
- doctor / markdownlint

## Risks & Mitigations（内容 / 検証手段 / Fallback）
- R1 router 表削除で参照先不明瞭 / mode-classification への明示リンク + grep / リンク不備なら追補
- R2 正本/mirror drift / diff 検証 / 不一致なら同期
- R3 advisory が既存 WF と二重手順化 / WF-00 を入口の advisory に限定し既存 phase を変えない / 競合時は advisory を注記レベルに留める

## Metrics Evidence
- 対象「移動対象スキル」: 実数 2（intent-classifier, skill-policy-router）/ 見積もり 2 / ratio 1.0 → 採用。

## Questions / Unknowns（Codex Q4・planning で詰める）
- intent 7分類を本体契約に固定 vs 暫定 → 初回は暫定（advisory）として導入、固定は強制化 PBI で。
- GatePolicy JSON schema の正本置き場 → 初回スコープ外（schema 化は別 PBI）。
- plugin export 同期手順の自動化 → 初回は手動 mirror + 注記。

## Mode判定

**モード**: critical

**判定根拠**:
- 変更ファイル数: 5+（skills×2 新設 + mirror×2 + WF-00）→ high〜critical
- 変更種別: 横断的（ワークフロー入口・正本構造・router/mode の責務再配置）→ critical
- 影響範囲: planning 入口フロー全体に波及しうる → critical
- リスク: 高（正本移動・重複解消）
- **最終判定**: critical（`lite_eligible=false`・人間 C-3 必須・autonomous APPROVE 不可・C-2 複数観点推奨）。初回スコープを advisory に絞りリスク低減。
