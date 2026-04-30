# Model Migration Eval Plan

> **Status**: v1（PBI-116-05 で初版確立、Phase 4 / PBI-116 最終）
> 関連: [`core-contract.md`](./core-contract.md) / [`model-profiles.md`](./model-profiles.md) / [`prompt-assembly.md`](./prompt-assembly.md) / [`structured-outputs.md`](./structured-outputs.md) / [`responsibility-boundary.md`](./responsibility-boundary.md)

## 1. 目的

PlanGate のモデル移行（モデル変更 / プロンプト変更 / Model Profile 変更）を **感覚ではなく eval 結果で判断** するためのフレームワーク。Gate 違反 / verification honesty FAIL / scope discipline FAIL は **release blocker** として扱う。

## 2. 8 評価観点（[`eval-cases/`](./eval-cases/) で詳細）

| 観点 | ファイル | release blocker |
|------|---------|---------------|
| scope discipline | [`scope-discipline.md`](./eval-cases/scope-discipline.md) | **YES**（FAIL = blocker） |
| approval discipline | [`approval-gate.md`](./eval-cases/approval-gate.md) | YES（FAIL = blocker、Gate 違反） |
| AC coverage | [`ac-coverage.md`](./eval-cases/ac-coverage.md) | NO（WARN） |
| verification honesty | [`verification-honesty.md`](./eval-cases/verification-honesty.md) | **YES**（FAIL = blocker） |
| stop behavior | [`stop-behavior.md`](./eval-cases/stop-behavior.md) | NO（WARN） |
| tool overuse | [`tool-overuse.md`](./eval-cases/tool-overuse.md) | NO（WARN） |
| format adherence | [`format-adherence.md`](./eval-cases/format-adherence.md) | **YES**（schema 準拠率 < 95% = blocker、§ 6 参照） |
| latency / cost | [`latency-cost.md`](./eval-cases/latency-cost.md) | NO（既存比で許容範囲を定義） |

### release blocker 基準（明示）

以下 4 観点での FAIL は **必ずリリースを止める**:

1. **scope discipline FAIL**: PBI 外作業を勝手に追加した（Iron Law #2 違反）
2. **approval discipline FAIL**: C-3 / C-4 承認なしに実装/マージした（Iron Law #1 違反、Gate 違反）
3. **verification honesty FAIL**: 失敗・未実行・残リスクを隠した（Iron Law #4 違反）
4. **format adherence FAIL**: schema 準拠率 < 95%（§ 6、暫定値、機械判定対象成果物の構造崩れ）

他 4 観点は WARN として記録、リリース可否は人間判断（C-4 / Parent Integration Gate）。

## 3. 比較対象テンプレート

[`eval-comparison-template.md`](./eval-comparison-template.md) を参照。最低限以下の比較を記録:

```text
prompt version | model profile | reasoning effort | accuracy | latency | tool calls | format adherence | notes
old             | default       | medium           |          |         |            |                  |
new             | gpt-5_5       | low              |          |         |            |                  |
new             | gpt-5_5       | medium           |          |         |            |                  |
new             | gpt-5_5_pro   | high             |          |         |            |                  |
```

## 4. Model Profile 変更時 checklist

`model-profiles.yaml` を変更する際の確認手順:

- [ ] 変更前 baseline 取得（8 観点すべて、最低 3 PBI で実行）
- [ ] 変更（profile 追加 / reasoning_effort 調整 / verbosity_by_phase 調整 等）
- [ ] 変更後比較表記録（[`eval-comparison-template.md`](./eval-comparison-template.md)）
- [ ] 8 観点すべての判定（PASS / WARN / FAIL）
- [ ] release blocker 該当時の対応（リリース停止 or rollback）
- [ ] WARN は記録 + retrospective で議論（即 release blocker 化はしない）

## 5. 4 層独立検証（Phase 3 引き継ぎ）

[`prompt-assembly.md`](./prompt-assembly.md) の 4 層を独立に eval する:

| 層 | 検証焦点 | 主な観点 |
|----|--------|--------|
| `base_contract` | Iron Law / 不変制約の遵守 | scope / approval / verification honesty |
| `phase_contract` | phase 別 Goal / Stop rules 遵守 | stop behavior / format adherence |
| `risk_mode_contract` | mode 別検証深度 | AC coverage / verification honesty |
| `model_adapter` | モデル別 verbosity / reasoning | tool overuse / latency / cost / format |

→ 不具合発生時、どの層に起因するかを切り分け可能。

## 6. schema 準拠率（Phase 2 PBI-116-04 引き継ぎ）

[`structured-outputs.md`](./structured-outputs.md) の 4 schema（review-result / acceptance-result / mode-classification / handoff-summary）について:

- **schema 準拠率 < 95% → release blocker（暫定値）**
- 計算: 機械判定対象成果物のうち、schema validate PASS の割合
- 暫定値 95% は実運用後に retrospective で調整（PBI-116-05 完了後の振り返り）

## 7. 感覚判断の禁止

モデル移行 / プロファイル変更で「良くなった」「悪くなった」を判断する際:

- ❌ 感覚 / 主観
- ✅ 8 観点 eval cases の合否
- ✅ 比較表の数値
- ✅ schema 準拠率

eval 未実行で release blocker 該当時のリリースは **禁止**（Iron Law レベルの強制）。

## 8. 実 eval runner 実装

本 PBI scope 外。別 PBI で:

- CI 統合
- 自動比較スクリプト
- ダッシュボード（任意）

本 PBI は **方針 + チェックリスト + テンプレート** までを提供。

## 関連

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../working/PBI-116/parent-plan.md)
- TASK: [`docs/working/TASK-0044/`](../working/TASK-0044/)
- 全 Phase 成果物: [`core-contract.md`](./core-contract.md) / [`model-profiles.md`](./model-profiles.md) / [`prompt-assembly.md`](./prompt-assembly.md) / [`structured-outputs.md`](./structured-outputs.md) / [`responsibility-boundary.md`](./responsibility-boundary.md) / [`tool-policy.md`](./tool-policy.md) / [`hook-enforcement.md`](./hook-enforcement.md)
