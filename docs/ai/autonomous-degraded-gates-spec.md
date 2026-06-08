# Autonomous / Degraded Gates — Specification

> **Status**: Specification（v1, 仕様策定のみ。実装による強制力は別 PBI）
> **Review cadence**: On change
> **Owner**: Governance
> 関連: issue [#487](https://github.com/s977043/plangate/issues/487)（提案2/3）/ [`core-contract.md`](./core-contract.md) §1-bis（責務範囲）/ [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md)（C-3 Autonomous APPROVE / 条件付き降格）/ [`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)（lite_eligible）

## 位置づけ

PlanGate 責務範囲（[`core-contract.md`](./core-contract.md) §1-bis = PR 作成〜C-4 承認まで）の**内側**で、可用性（CI 不能時）と自律性（低リスク自動承認）を高めるためのゲート拡張仕様。issue #487 提案2/3 を Gemini 相談（2026-06-08）の助言を踏まえて正本化する。

本ファイルは **仕様（不変条件・境界・機械チェック規則）の正本**。強制力（`bin/plangate` / hook / rules 実装）は HO パスのため別 PBI で導入する（[`orchestrator-mode.md`](../../.claude/rules/orchestrator-mode.md) と同じ Specification → 実装分離パターン）。

> **大原則（非緩和）**: 本仕様は「人間判断点を固定する」PlanGate の核を**弱めない**。自動化・縮退は **証明可能なときだけの例外**であり、既定ではない。判定不能なら必ず安全側（人間判断）にフォールバックする。

## 1. 提案3: C-4 自律承認拡張（trusted-autonomous）

新規 trusted モードは導入しない。既存 Risk Tier（C-3 Autonomous APPROVE）を **C-4 側へ最小拡張**する。

### 不変条件 `C4AutoApproveAllowed`

```text
C4AutoApproveAllowed =
  mode == ultra-light
  AND (C3AutonomousApproved OR C3Skipped)
                                    # ultra-light は mode-classification で C-3 をスキップ（C3Skipped）。
                                    # C-3 を通す運用なら autonomous APPROVE 済（C3AutonomousApproved）。
                                    # スキップの悪用（high-risk 偽装）は §3 Risk Tier Integrity が防ぐ。
  AND RiskTierIntegrityPassed       # §3 のガードレール検証 PASS（スキップ時の唯一の担保）
  AND CiAllGreen                    # 全 CI チェック success（縮退時は §2 に従う）
  AND NoHardeningOverridePath       # HO 対象パスを 1 つも含まない
  AND NoSchemaOrBreakingOrSecurity  # schema / 破壊的 / セキュリティ変更を含まない
```

**いずれか 1 つでも未充足 → C-4 は人間レビュー（従来どおり）。**

### 人間責務のシフト（剥奪ペナルティ）

- C-4 自律承認が許可された run では、人間の責務を **「PR 内容のレビュー」→「リスク分類が妥当だったかの事後監査」** にシフトする。
- 事後監査で**リスク分類 drift**（本来 high-risk を ultra-light と誤分類/偽装）を検知した場合、当該エージェント/セッションの **C-4 自律権限を剥奪**し、以降は人間 C-4 を強制する（Escalation）。
- 監査記録は `status.md` と `decision-log.jsonl`（JSON Lines）に append。最小スキーマ:
  - `{"event": "c4_auto_approved", "task": "<id>", "mode": "ultra-light", "ci": "green|degraded"}`
  - `{"event": "tier_drift_detected", "task": "<id>", "drift_from": "<declared_tier>", "drift_to": "<effective_tier>"}`

## 2. 提案2: CI 縮退モード（CI-degraded fallback）

CI（GitHub Actions）不能（課金停止・障害等）時に、**証拠を捏造できない仕組み**でローカル等価ゲートを許可する。docs 明文化だけでは不十分で、`bin/plangate`（HO）への CLI 実装を要する（別 PBI）。

### 不変条件 `DegradedMergeAllowed`

```text
DegradedMergeAllowed =
  CiUnavailableDetected             # CI が起動不能であることを検知
  AND ToolchainParityVerified       # bin/plangate doctor がローカル環境=CI 等価
                                    #   （lint/test/build ツールチェーンのバージョン一致）を検証
  AND LocalEquivalentGatesPassed    # ローカル等価コマンド（lint/typecheck/test/build）が全 PASS
  AND EvidenceLedgerRecorded        # ローカル PASS ログを evidence-ledger に強制記録
  AND BypassCiFlagExplicit          # BYPASS_CI フラグが明示的に立っている
```

**いずれか 1 つでも未充足 → マージゲートは開錠しない（従来どおり CI 待ち）。**

### 証拠の非捏造保証

- ローカル PASS ログは `evidence-ledger` へ**強制記録**（記録なしの BYPASS は無効）。
- `doctor` のツールチェーン等価検証を通らない環境（バージョン不一致）では BYPASS を拒否する。
- BYPASS_CI 使用は `decision-log.jsonl` に append（`ci_degraded_bypass` + toolchain 指紋）。

## 3. 横断ガード: Risk Tier Classification Integrity（最重要）

自動化・縮退の**最悪シナリオ = AI が面倒回避で High-risk を Ultra-light と偽装**すること。これを防ぐ最後の砦。

### ガードレール・スキーマ（ヒューリスティック判定）

AI のセルフ分類（mode 判定）に対し、以下を機械的に判定する独立スキーマを設ける。

| 判定軸 | 昇格トリガ（例） |
|--------|----------------|
| 変更ファイル数 | mode 申告の上限を超える |
| 影響範囲（依存グラフ） | 申告 scope 外への依存波及 |
| 機密/HO ファイル接触 | HO 対象パス・secret・schema に touch |

### 昇格（Escalation）ロジック

```text
EffectiveTier = max(SelfDeclaredTier, GuardrailHeuristicTier)
if EffectiveTier > SelfDeclaredTier:
    強制的に人間判断（C-3 / C-4）を要求する  # 自律パス・縮退を無効化
```

既存 [`mode-classification.md`](../../.claude/rules/mode-classification.md) の「自動推定の安全側」「Hardening Override」を土台に、本ガードを**昇格ロジック**として接続する（実装は別 PBI / HO）。

## 4. AI 自己完結禁止条項（実装は Human / 別 PBI）

| ID | 禁止アクション | 必須 |
|----|--------------|------|
| AD-1 | `C4AutoApproveAllowed` の判定実装を `bin/plangate` / hook（HO）に AI が直接配線 | Human-owned。AI は仕様・script 提供まで |
| AD-2 | `DegradedMergeAllowed`（BYPASS_CI）の実装 | 同上 |
| AD-3 | Risk Tier ガードレール・スキーマの hook 強制 | 同上 |

本仕様は **強制対象の正本定義**。実装層での強制力導入時に v2 とし、機械チェック実装・失敗メッセージ・bypass 条件を確定する。

## 5. 既存仕組みとの関係（重複回避）

| 既存 | 関係 |
|------|------|
| C-3 Autonomous APPROVE（#353）| 提案3 の C-3 側はこれでカバー済。本仕様は **C-4 側の最小拡張のみ** 追加 |
| C-3 条件付き降格（F5-AD・opt-in 既定 OFF）| 同期/非同期選択。本仕様の C-4 拡張も **opt-in 既定 OFF** とする |
| lite_eligible | Lite ゲート派生属性。Risk Tier の土台 |
| evidence-ledger | 提案2 の証拠記録先 |
| core-contract.md §1-bis | 本仕様は責務範囲（C-4 まで）の**内側**。リリース/公開には踏み込まない |
