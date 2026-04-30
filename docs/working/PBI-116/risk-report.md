# Risk Report — PBI-116

> 親 PBI [`parent-plan.md`](./parent-plan.md) のリスクと緩和策。
> Risk Gate 通過のための材料。

## リスク一覧

| ID | Risk | Severity | Probability | Impact | Mitigation |
|----|------|----------|-------------|--------|-----------|
| R1 | Core Contract（PBI-116-01）の方針が他子 PBI と整合しない | high | medium | high | Phase 1 完了時の C-3 ゲート厳格化（C-2 Codex 必須）、整合確認後に Phase 2 着手 |
| R2 | Model Profile（PBI-116-02）の YAML schema が Prompt assembly（PBI-116-03）と乖離 | medium | medium | medium | PBI-116-03 設計時に PBI-116-02 schema を引用、merge_after で順序保証 |
| R3 | Structured Outputs（PBI-116-04）が既存 `schemas/` と矛盾 | medium | low | high | C-1 / C-2 で互換性確認、schema-validate を required check に追加 |
| R4 | `必ず` / `絶対` 削減で意図せず Iron Law を弱化 | high | medium | critical | Iron Law 7 項目を明示保持、削減対象は手順指定のみ。grep で hard mandate キーワードを除外確認 |
| R5 | Eval cases（PBI-116-05）依存が他 PBI 全完了で着手できない | medium | high | low | Phase 4 配置で他 5 PBI 完了後に着手、その分 buffer を見込む |
| R6 | Phase 2 並行実行時に worktree 設定不備 | low | medium | medium | `parallelization-plan.md` の worktree 運用方針に従い、各子 PBI で独立 branch + 独立 worktree |
| R7 | 子 PBI ごとの C-2 外部AIレビュー（Codex 等）の品質揺れ | medium | medium | medium | high-risk 子 PBI（PBI-116-01, PBI-116-03）は C-2 必須、standard は推奨 |
| R8 | v8.2 milestone までに完了しない（時間切れ） | medium | low | medium | Phase 2 並行で実時間短縮、各 phase 開始時に scope 削減検討 |
| R9 | parent-AC-7（既存 Gate 維持）が子 PBI 単位では検証困難 | medium | medium | high | Phase 4 (PBI-116-05) の eval cases に Gate 維持確認を必須項目として含める |
| R10 | Plugin 配布版（`plugin/plangate/`）との同期漏れ | medium | medium | medium | PBI-116-01 の `allowed_files` に plugin 側を含め、棚卸し対象を明示 |

## Severity 別の対応方針

### Critical / High リスク（R1, R4）

- **必須**: C-2 外部AIレビュー（Codex 推奨）
- **必須**: V-2 / V-3 多層防御
- **必須**: Phase 完了時に親レベルで整合確認

### Medium リスク（R2, R3, R5, R7, R8, R9, R10）

- C-2 外部AIレビューを推奨
- 各 phase 完了時に子 PBI ごとに Gap 確認

### Low リスク（R6）

- 通常の C-1 / C-3 / C-4 ゲートで対応

## Risk Gate（親計画ゲート時のチェック）

`.claude/rules/orchestrator-mode.md` 不変条件 1 「ChildExecAllowed」の `RiskGatePassed` 条件:

- [ ] `risk.level == "high"` の子 PBI に追加 approval が記録されている
  - PBI-116-01: high → 追加 approval 必要
  - PBI-116-03: high → 追加 approval 必要
- [ ] 緩和策が `risk.mitigation` に記載されている
  - 全 6 子 PBI で記載済み

## 監視ポイント

各 phase 完了時に以下をチェック:

1. **R1**: Phase 1 完了時、Core Contract が Phase 2/3 子 PBI の前提として機能するか doc レビュー
2. **R4**: Phase 1 完了時、`grep -rn "必ず\|絶対\|ALWAYS\|NEVER" CLAUDE.md AGENTS.md docs/ai/` で残存件数確認 → Iron Law 7 項目以外をゼロに
3. **R5**: Phase 3 完了時、Phase 4 着手前に他 5 子 PBI の handoff.md を読み eval 観点を確定
4. **R10**: Phase 1 完了時、`plugin/plangate/` 側の対応漏れがないか diff 確認

## エスカレーション基準

- High リスクが 2 件以上同時に発現 → 親 PBI 再計画
- Critical 課題が `open` で残存 → `parent:done` への遷移を block
- v8.2 milestone までに 2 phase 以上が遅延 → scope 削減（PBI-116-05 を分離して v8.3 に押し出す等）を検討
