---
task_id: TASK-0044
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-04-30
author: qa-reviewer
v1_release: ""
covers_parent_ac:
  - parent-AC-5
---

# Handoff Package — TASK-0044 (PBI-116-05 / Issue #121)

## メタ情報

```yaml
task: TASK-0044
related_issue: https://github.com/s977043/plangate/issues/121
parent_pbi: PBI-116 (Issue #116)
author: qa-reviewer
issued_at: 2026-04-30
v1_release: ""  # PR マージ後に SHA を記入
covers_parent_ac:
  - parent-AC-5  # eval cases / 比較表 / 合格基準
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: model migration eval plan ドキュメント化 | PASS | `docs/ai/eval-plan.md`（102 行、9 セクション、TC-1） |
| AC-2: 8 観点 eval case 存在 | PASS | `docs/ai/eval-cases/*.md` 8 ファイル（TC-2、scope-discipline / approval-gate / ac-coverage / verification-honesty / stop-behavior / tool-overuse / format-adherence / latency-cost） |
| AC-3: 比較対象テンプレート | PASS | `docs/ai/eval-comparison-template.md`（59 行、TC-3） |
| AC-4: release blocker 基準明記 | PASS | eval-plan.md § 6 + verification-honesty / scope-discipline / format-adherence で release blocker 明示（TC-4） |
| AC-5: Model Profile 変更時 checklist | PASS | eval-plan.md § 4 にチェックリスト記載（TC-5） |
| AC-6: 感覚ではなく eval 結果で判断 | PASS | eval-plan.md § 7「感覚判断の禁止」+ § 1 冒頭明示（TC-6） |
| AC-7: 4 層独立検証方針 | PASS | eval-plan.md § 5 で base_contract / phase_contract / risk_mode_contract / model_adapter の 4 層を eval 観点に紐付け（TC-7） |
| AC-8: schema 準拠率 eval 対象化 | PASS | eval-plan.md § 6「schema 準拠率 < 95% → release blocker（暫定値）」（TC-8） |

**総合**: 8/8 AC PASS（9 TC 中 8 PASS / 1 WARN）
**WARN の扱い**: TC-E1 行数チェック（eval-plan.md 102 行が目標 50 行を超過）。8 観点を網羅するための必要最小限と判断、V1 として許容。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| 自動 eval runner が未実装（手動 eval 前提） | minor | accepted | Yes（PBI-117 候補） |
| 比較表テンプレートに対応する実測ベースライン未取得 | minor | open | Yes |
| eval-cases の各 detection スクリプトは概念のみ（実装は別 PBI） | minor | accepted | Yes |
| 行数超過（eval-plan.md 102 行 / 全体 537 行） | info | accepted | No（必要最小） |

**Critical 課題**: なし。リリース可。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|---------|
| 自動 eval runner（reasoning_token / latency / tool call 集計） | 本 PBI は基盤定義のみ | High | （新規）|
| 実運用ベースライン取得（v8.2 baseline 測定） | 比較対象を確立する初回測定 | High | （新規）|
| 各 eval-case の detection script 実装（grep / jq / schema validate） | 概念から自動チェックへ | Medium | （新規）|
| 外部ダッシュボード構築（Grafana / Looker 等） | 継続観測の可視化 | Low | — |
| 全モデル / provider の網羅比較 | 範囲拡大、コスト次第 | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| ドキュメントのみ（runner 実装なし） | 自動 eval runner 同梱 | PBI-116 EPIC のスコープが「最新モデル対応の基盤整備」であり、runner 実装は次 sprint に分割するのが妥当。Phase 1〜3 と整合 |
| 8 観点を独立 file に分割 | eval-plan.md に統合 | 各観点を独立に拡張できるよう保守性優先（latency-cost を後追加した経緯あり） |
| C-2 スキップ（C-1 のみ） | Codex C-2 実施 | standard mode + doc-only + Phase 1〜3 同パターン踏襲のため省略可と判断（review-external.md 記録） |
| schema 準拠率 95% を暫定値と明示 | 確定値で固定 | 実運用ベースライン未取得のため retrospective で調整可能なように暫定値とした |
| Gemini 指摘 EX で 7→8 観点に拡張 | 7 観点で確定 | latency / cost も移行判断に必須との指摘を受け入れ、release blocker 該当外として追加 |

## 5. 引き継ぎ文書

### 概要

PBI-116（最新実行モデル対応 EPIC）の **Phase 4（最終子 PBI）**。モデル移行を「感覚」ではなく「eval 結果」で判断するための **8 観点フレームワーク** を定義した。`docs/ai/eval-plan.md`（正本）+ `eval-cases/` 配下 8 ファイル（観点別詳細）+ `eval-comparison-template.md`（比較表）の 3 層構成。

8 観点のうち **scope discipline / approval discipline / verification honesty / format adherence(schema 準拠率 < 95%)** を **release blocker** として位置付け、それ以外（AC coverage / stop behavior / tool overuse / latency-cost）は WARN レベル。

### 触れないでほしいファイル

- `docs/ai/eval-plan.md`: 正本。観点追加 / release blocker 基準変更は別 PBI で議論
- `docs/ai/eval-cases/*.md`: 各観点の正本。新観点追加時は eval-plan.md § 2 と同期更新
- `docs/ai/model-profiles.yaml`（PBI-116-02 成果物）: 本 PBI スコープ外、forbidden_files
- `docs/ai/prompt-assembly.md`（PBI-116-04 成果物）: 本 PBI スコープ外、forbidden_files

### 次に手を入れるなら

**推奨される次のステップ**:
1. **PBI-116 Parent Integration Gate（👤 人間判断）** — PBI-116-05 マージ後、親 PBI 完了承認
2. **v8.2 baseline 取得 PBI** を新規起票し、本 eval framework での初回測定を実施
3. **eval runner 実装 PBI** を新規起票（reasoning_token / latency / tool call 集計の自動化）
4. **schema validation CI 統合** — schema 準拠率 < 95% 時に release block する hook 実装

**避けるべきアンチパターン**:
- eval 結果の主観解釈（「だいたい良さそう」で release blocker をスキップ）
- baseline 未取得のまま新モデル比較（基準なき比較は無意味）
- 8 観点のうち 1 つでも省略（`format adherence` を「軽微」と判断するなど）

### 参照リンク

- 親 PBI: https://github.com/s977043/plangate/issues/116
- 子 Issue: https://github.com/s977043/plangate/issues/121
- pbi-input.md: `docs/working/TASK-0044/pbi-input.md`
- plan.md: `docs/working/TASK-0044/plan.md`
- review-self.md: `docs/working/TASK-0044/review-self.md`
- status.md: `docs/working/TASK-0044/status.md`
- 関連（Phase 1-3 成果）: `docs/ai/core-contract.md` / `model-profiles.yaml` / `responsibility-boundary.md` / `prompt-assembly.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Doc structure (TC-1〜TC-8) | 8 | 8 | 0 | 100% |
| Edge case (TC-E1, TC-E2) | 2 | 1 | 0 / 1 WARN | — |
| Unit / Integration / E2E | — | — | — | — (doc-only PBI) |

**WARN の詳細**: TC-E1（行数チェック）— 8 観点を網羅するため必要最小限の超過（102 行 / 目標 50 行）。受入基準は満たすため V1 として許容。

**verification evidence**: `docs/working/TASK-0044/evidence/verification.md`

---

## PBI-116 EPIC 全体での位置付け

| Phase | PBI | 状態 | 主成果物 |
|-------|-----|------|--------|
| Phase 1 | PBI-116-01 | done | core-contract.md / Iron Law 7 / CLAUDE.md / AGENTS.md スリム化 |
| Phase 2 | PBI-116-02 | done | model-profiles.yaml（4 profiles）+ schema |
| Phase 2 | PBI-116-04 | done | responsibility-boundary / tool-policy / hook-enforcement / structured-outputs（4 schemas） |
| Phase 2 | PBI-116-06 | done | （Phase 2 統合） |
| Phase 3 | PBI-116-03 | done | prompt-assembly.md / contracts/ × 7 / adapters/ × 4 |
| **Phase 4** | **PBI-116-05** | **本 PBI** | **eval-plan.md / eval-cases/ × 8 / eval-comparison-template.md** |

PBI-116-05 完了 → PBI-116 全 6 子 PBI 完了 → **Parent Integration Gate（👤 user）** が最終ゲート。
