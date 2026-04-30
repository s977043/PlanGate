---
task_id: TASK-0041
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-04-30
author: Claude (PBI-116-06 exec)
v1_release: TBD (本 PR マージ後)
---

# TASK-0041 Handoff Package

> WF-05 Verify & Handoff の出力。PBI-116-06（Issue #122 Tool Policy / Hook enforcement 境界整理）。
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Codex 戦略順序 2 番目

## メタ情報

```yaml
task: TASK-0041
related_issue: https://github.com/s977043/plangate/issues/122
parent_pbi: PBI-116
covers_parent_ac: [parent-AC-6, parent-AC-7]
mode: standard
author: Claude
issued_at: 2026-04-30
exec_pr: TBD
```

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|---------|
| AC-1: 責務境界整理（4 layer） | PASS | `responsibility-boundary.md` § 2-5 |
| AC-2: phase 別 allowed tools | PASS | `tool-policy.md` § 2、6 phase × allowed/禁止 |
| AC-3: Hook 不変条件（6 件以上） | PASS | `hook-enforcement.md` § 2、EH-1〜EH-7 = 7 件 |
| AC-4: tool_policy 値ごとの射影 | PASS | `tool-policy.md` § 3、narrow / allowed_tools_by_phase / expanded |
| AC-5: validation_bias: strict 追加条件 | PASS | `hook-enforcement.md` § 3、EHS-1〜EHS-3 = 3 件 |
| AC-6: プロンプト vs runtime 強制の区別 | PASS | `responsibility-boundary.md` § 3、§ 5 |
| AC-7: 既存 Iron Law 維持 | PASS | C-3/C-4/scope/verification 各キーワード残存 |

**総合: 7/7 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補 |
|------|---------|------|---------|
| 実 Hook 実装は本 PBI scope 外 | info | accepted | Yes（別 PBI で `.claude/settings.json` hooks 追加 / CLI 実装）|
| EH-7（2 段階レビュー Hook）は GitHub branch protection と組み合わせ必要 | minor | accepted | Yes（Hook 実装 PBI で対応）|
| Plugin 配布版（`plugin/plangate/rules/*-gate.md`）との詳細マッピング未実施 | minor | accepted | Yes（Plugin 同期 PBI で対応）|
| EHS-1〜EHS-3 の閾値（fix loop 5 回 etc）は固定値、設定化なし | info | accepted | Yes（必要時に Model Profile に追加）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|------|
| 実 Hook 実装（`.claude/settings.json` / CLI / GitHub Actions） | 本 PBI は境界定義のみ | High（Phase 3 以降）|
| Plugin 限定 rules との詳細マッピング | v8.1 ガードレールとの責務分離明文化 | Medium |
| EHS の閾値設定化 | 固定値からプロファイル別へ | Low |
| Hook 通知文言の i18n | 日本語のみ | Low |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| Hook 7 件 + 追加 3 件で計 10 件に絞った | Iron Law 全項目を網羅した 20 件以上 | scope 限定（本 PBI は境界定義）+ 主要不変条件で十分 |
| `.claude/settings.json` 編集禁止 | 既存 hooks に直接追加 | forbidden_files で実装に踏み込まないため |
| Plugin 配布版との関係を「共存」と明示 | 統合 / 置換 | 配布形態固有のガードレール維持 |
| 実装方法を「別 PBI」に分離 | 本 PBI で簡易実装 | exec scope 内に収めつつ強制力定義のみ |

## 5. 引き継ぎ文書

### 概要

PBI-116-06 (#122 Tool Policy / Hook enforcement 境界整理) の exec 完了。3 つの新規ドキュメントで責務境界を確立:

- `docs/ai/responsibility-boundary.md`: 4 layer（Prompt / Tool Policy / Hook / CLI validate）の責務マトリクス + 判断基準 + 重複時の解釈
- `docs/ai/tool-policy.md`: 6 phase × allowed/禁止 tools + tool_policy 3 値域射影 + validation_bias 補正 + Plugin 限定との関係
- `docs/ai/hook-enforcement.md`: EH-1〜EH-7 不変条件 + EHS-1〜EHS-3 strict 追加条件 + 実装方法（別 PBI）

PBI-116-02 で確立した Model Profile（`docs/ai/model-profiles.yaml`）の `tool_policy` / `validation_bias` 値域を参照し、interface-preflight.md と完全整合。

### 触れないでほしいファイル

- `docs/ai/responsibility-boundary.md`: 4 layer 責務境界の正本。layer 追加/削除は別 PBI で
- `docs/ai/tool-policy.md`: phase 別 allowed tools の正本。値変更は eval 結果ベース
- `docs/ai/hook-enforcement.md`: EH 番号は固定（実装側からの参照キー）
- `.claude/settings.json` / `.claude/hooks/`: 本 PBI 範囲外、別 PBI で実装
- `plugin/plangate/rules/*-gate.md`: v8.1 ガードレール、共存（直接編集しない）

### 次に手を入れるなら

- **V2-1（High）**: 実 Hook 実装 PBI 起票（EH-1〜EH-7 + EHS-1〜EHS-3 を `.claude/settings.json` / CLI / GitHub Actions で実装）
- **V2-2（Medium）**: Plugin 限定 rules との詳細マッピング表（responsibility-boundary に追加）
- **V2-3（Low）**: EHS の閾値設定化、Hook 通知文言 i18n

### 参照リンク

- 親 PBI: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- Issue: https://github.com/s977043/plangate/issues/122
- Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)
- Phase 1 成果（基盤）: [`docs/ai/core-contract.md`](../../ai/core-contract.md)
- 接続元 PBI-116-02 (Model Profile): [`docs/working/TASK-0040/handoff.md`](../TASK-0040/handoff.md) / [`docs/ai/model-profiles.md`](../../ai/model-profiles.md)
- C-1 / C-2 / Child C-3: [`review-self.md`](./review-self.md) / [`review-external.md`](./review-external.md) / [`approvals/c3.json`](./approvals/c3.json)

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| 自動（grep / wc） | 7 | 7 | 0 | 高 |
| doc-review | 3 | 3 | 0 | 高 |
| 手動 E2E | — | — | — | 該当なし |

**FAIL / SKIP の詳細**: なし
**注**: 単体テストは doc-only PBI のため対象外。実 Hook 実装は別 PBI のため runtime テストは scope 外。
