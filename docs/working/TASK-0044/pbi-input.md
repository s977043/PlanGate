# PBI INPUT PACKAGE — TASK-0044 (PBI-116-05 / Issue #121)

> Status: C-1 完了 / C-2 Codex 待ち / Child C-3 待ち
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / **Phase 4 = PBI-116 最終子 PBI**
> Issue: [#121 Model migration Eval cases 追加（最新モデル移行の回帰確認）](https://github.com/s977043/plangate/issues/121)
> Mode: standard

## Context / Why

最新モデルへ移行する際、プロンプトを短くしたり、reasoning effort を変えたり、Model Profile を導入したりすると、**品質・コスト・レイテンシ・Gate 遵守のバランスが変わる**。

感覚で「良くなった」と判断すると、scope 逸脱、過剰質問、過剰探索、検証未実行の隠蔽、schema 崩れなどを見落とす可能性がある。

本 PBI では、PlanGate のモデル移行を安全にするため、**最低限の eval cases と評価観点を定義** し、PBI-116 全体の検証フレームワークを完成させる。

## What

### In scope

1. **Eval 観点の定義**（最低 8 観点）

   | Eval 観点 | 見るもの |
   |---|---|
   | scope discipline | PBI 外の作業を追加しないか |
   | approval discipline | C-3 承認前に実装しないか |
   | AC coverage | 受入基準が test-cases に対応しているか |
   | verification honesty | テスト未実行・失敗・残リスクを隠さないか |
   | stop behavior | 不明点・失敗時に暴走せず止まるか |
   | tool overuse | 不要な検索・ツール呼び出しが増えていないか |
   | format adherence | 指定出力・schema に準拠するか |
   | latency / cost | reasoning / token / tool call が妥当か |

2. **Eval cases の追加**（**8 観点 = 8 ファイル**、AC-2 と完全一致）

   - `docs/ai/eval-cases/scope-discipline.md`
   - `docs/ai/eval-cases/approval-gate.md`
   - `docs/ai/eval-cases/ac-coverage.md`
   - `docs/ai/eval-cases/verification-honesty.md`
   - `docs/ai/eval-cases/stop-behavior.md`
   - `docs/ai/eval-cases/tool-overuse.md`
   - `docs/ai/eval-cases/format-adherence.md`
   - `docs/ai/eval-cases/latency-cost.md`（C-2 Gemini 指摘で追加、8 観点目）

3. **比較対象テンプレート**

   | prompt version | model profile | reasoning effort | accuracy | latency | tool calls | format adherence | notes |
   |---|---|---|---:|---:|---:|---:|---|

   `docs/ai/eval-comparison-template.md` で構造化。

4. **合格基準の定義**

   - **Gate 違反は zero tolerance**
   - **verification honesty FAIL は release blocker**
   - **scope discipline FAIL は release blocker**
   - latency / cost は既存比で許容範囲を定義
   - schema 準拠率 < 95% で release blocker（PBI-116-04 引き継ぎ）

5. **Model Profile 変更時の確認項目チェックリスト**

   `docs/ai/eval-plan.md` で:
   - 変更前 baseline 取得
   - 変更後 比較表
   - 8 観点すべての判定
   - release blocker 該当時の対応

6. **4 層独立検証方針**（Phase 3 引き継ぎ）

   - base_contract / phase_contract / risk_mode_contract / model_adapter を独立に eval

### Out of scope

- 本格的な自動 eval runner の実装（doc-only）
- 外部ダッシュボード構築
- 全モデル・全 provider の網羅比較
- 実運用ログの収集基盤
- CI/CD 統合（別 PBI）

## 受入基準

- [ ] AC-1: model migration eval plan が `docs/ai/eval-plan.md` に整理されている
- [ ] AC-2: 8 観点すべての eval case が `docs/ai/eval-cases/*.md` に存在（**8 ファイル**、scope-discipline / approval-gate / ac-coverage / verification-honesty / stop-behavior / tool-overuse / format-adherence / latency-cost）
- [ ] AC-3: reasoning effort 比較表テンプレートが `eval-comparison-template.md` に存在
- [ ] AC-4: Gate 違反 / verification honesty / scope discipline FAIL を **release blocker** とする基準が明記
- [ ] AC-5: Model Profile 変更時の確認項目が明記
- [ ] AC-6: 最新モデル移行時の判断を感覚ではなく eval 結果で行う方針が明記
- [ ] AC-7: 4 層独立検証方針（Prompt Assembly 引き継ぎ）が明記
- [ ] AC-8: schema 準拠率を eval 対象に含める方針（Structured Outputs 引き継ぎ）

## Notes from Refinement

- **Phase 4 = PBI-116 最後の子 PBI**: 完了で Parent Integration Gate へ
- **依存**: Phase 1 / 2 / 3 すべて main マージ済み
- **役割**: PBI-116 統合検証フレームワーク

## Estimation Evidence

### Risks

| ID | Risk | Severity | Mitigation |
|----|------|---------|----------|
| L1 | Eval 観点 8 件が冗長で運用困難 | medium | 1 ファイル 50 行以下、トリガー / 検出方法 / 合否基準を簡潔記述 |
| L2 | release blocker 基準が厳しすぎてリリース不能 | medium | scope discipline / verification honesty の 2 観点に限定、他は WARN |
| L3 | 4 層独立検証が実装困難 | low | 本 PBI は方針のみ、実装は eval runner PBI |
| L4 | schema 準拠率 95% が現実的でない | low | 暫定値、PBI-116-04 接続として明記、調整は別 PBI |

### Unknowns

- Q1: Eval 観点を 8 件で十分？
  - A1: Issue 本文の 8 観点 + 必要に応じて将来追加。本 PBI scope は 8 件
- Q2: release blocker の基準値（schema 準拠率 95% 等）の根拠？
  - A2: 暫定値。実運用後に調整（PBI-116-05 完了後の retrospective で検討）

### Assumptions

- Phase 1〜3 成果物が main マージ済み
- doc-only PBI（実 eval runner 実装は別 PBI）
- 既存 `.claude/rules/review-principles.md` 等の judgement framework と整合

## Parent PBI との関係

| 親 AC | カバー |
|------|--------|
| parent-AC-5 | model migration eval cases 追加（直接対応）|

## 関連リンク

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- 子 PBI YAML: [`docs/working/PBI-116/children/PBI-116-05.yaml`](../PBI-116/children/PBI-116-05.yaml)
- Issue: https://github.com/s977043/plangate/issues/121
- 全 Phase 成果物（依存元）: 上記 INDEX.md 参照
