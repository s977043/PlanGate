# PBI INPUT PACKAGE — TASK-0041 (PBI-116-06 / Issue #122)

> Status: C-1 完了 / C-2 Codex 待ち / Child C-3 待ち
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Phase 2 / Codex 戦略採用順序の **2 番目**
> Issue: [#122 Tool Policy / Hook enforcement 境界を最新モデル向けに整理する](https://github.com/s977043/plangate/issues/122)
> Mode: standard
> Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)

## Context / Why

最新モデル向けにプロンプトを短くする際、すべての制約を自然文プロンプトで維持しようとすると、指示が再び肥大化する。

PlanGate では、**モデルに判断させるべきもの**と、**Hook / CLI / runtime で決定論的にブロックすべきもの**を分ける必要がある。C-3 承認なし exec 禁止、scope 外ファイル編集禁止、検証ログなし PR 禁止のような不変条件は、プロンプトよりも tool policy / Hook enforcement に寄せる方が安全で保守しやすい。

本 PBI では、PlanGate の最新モデル対応に合わせて、**プロンプト・tool policy・Hook・CLI の責務境界**を整理する。**境界定義のみ**（実 Hook 実装は別 PBI）。

## What

### In scope

1. **責務境界の整理**

   | Layer | 責務 |
   |-------|------|
   | Prompt | 目的、成功条件、判断基準、不明点の扱い、報告形式 |
   | Tool Policy | phase ごとに利用可能なツールを制限 |
   | Hook | 破ってはいけない不変条件を決定論的にブロック |
   | CLI / validate | 成果物、承認状態、plan_hash、検証証拠を検査 |

2. **Phase 別 allowed tools の定義**（interface-preflight 準拠）

   | Phase | allowed tools |
   |-------|--------------|
   | plan | read / search のみ |
   | approve-wait | no write tools |
   | exec | edit / test / build allowed |
   | review | read / test / diff のみ |
   | handoff | read / write docs のみ |

3. **Hook enforcement 候補の整理**

   - `plan.md` がない状態で production code 編集 → ブロック
   - C-3 承認なしで `exec` → ブロック
   - 承認後に `plan.md` が改変 → ブロック
   - `test-cases.md` なしで V-1 進行 → ブロック
   - 検証ログなしで PR 作成 → ブロック
   - scope 外ファイル編集検知 → 停止

4. **Model Profile との接続**（PBI-116-02 で定義済の `tool_policy` / `validation_bias` を参照）

   - `tool_policy: narrow` → 限定 tool セット
   - `tool_policy: allowed_tools_by_phase` → phase 別射影（本 PBI で定義）
   - `tool_policy: expanded` → 拡張 tool セット
   - `validation_bias: strict` → 追加 Hook 強制条件

### Out of scope

- すべての Hook 実装（境界定義のみ、実装は別 PBI）
- GitHub Actions 連携の実装
- Provider runtime の全面刷新
- C-3 / C-4 の人間承認フロー削除
- `tool_policy` 値域の定義（→ PBI-116-02 で済）

## 受入基準

- [ ] AC-1: Prompt / Tool Policy / Hook / CLI validate の責務境界が `docs/ai/responsibility-boundary.md` に整理されている
- [ ] AC-2: Phase 別 allowed tools が `docs/ai/tool-policy.md` に定義されている（5 phase）
- [ ] AC-3: Hook enforcement で強制すべき不変条件が `docs/ai/hook-enforcement.md` に一覧化されている（最低 6 件）
- [ ] AC-4: Model Profile（PBI-116-02）の `tool_policy` 値ごとの phase_allowed_tools 射影が定義されている
- [ ] AC-5: `validation_bias: strict` 時の追加 Hook 条件が定義されている
- [ ] AC-6: プロンプトで強制するものと runtime で強制するものが明示的に区別されている
- [ ] AC-7: C-3 承認前実装禁止、scope 外編集禁止、検証証拠なし完了禁止が維持されている（Iron Law 整合）

## Notes from Refinement

- **Phase 2 戦略**: Codex 相談で確定（PR #136）
- **着手順序**: 本 TASK は Phase 2 の 2 番目（PBI-116-02 完了を前提）
- **境界限定**: 実 Hook 実装は本 PBI scope 外
- **接続合意**: 02 (`tool_policy` 値域) → 06 (本 TASK、phase 別射影 + Hook 条件)

## Estimation Evidence

### Risks

| ID | Risk | Severity | Mitigation |
|----|------|---------|----------|
| L1 | tool_policy 値域が PBI-116-02 と乖離 | medium | interface-preflight.md 準拠、PBI-116-02 完了済を前提 |
| L2 | Hook enforcement 候補が現状のフックと衝突 | low | 既存 `.claude/settings.json` の hooks を参照確認 |
| L3 | 「境界定義のみ」が曖昧で実装に踏み込んでしまう | medium | plan.md で「実装禁止」を明記、Stop rule 設定 |
| L4 | Plugin 配布版（`plugin/plangate/rules/*-gate.md`）と乖離 | medium | Plugin 限定 rules は v8.1 ガードレールとして既存、本 PBI は ai/* に新規配置 |

### Unknowns

- Q1: Hook enforcement の実装方法（CLI / hook script / hub plug-in）どれを採用？
  - A1: 本 PBI 範囲外（境界定義のみ）。実装方法は別 PBI で決定
- Q2: `validation_bias: strict` の追加 Hook 条件をどこまで定義するか？
  - A2: 最低 3 条件（検証ログ必須 / scope 外検知 / 承認改竄検知）。詳細は別 PBI
- Q3: Plugin 限定 rules（v8.1）と本 PBI の関係？
  - A3: 本 PBI は ai/* レベルで一般化、Plugin 限定 rules は配布形態固有として共存

### Assumptions

- PBI-116-02 (Model Profile) が tool_policy / validation_bias 値域を定義済（前提）
- Hook 実装は別 PBI（本 PBI は境界定義のみ）
- 既存 `.claude/settings.json` の hooks 機構と矛盾しない
- doc-only PBI（実装コード変更なし）

## Parent PBI との関係

| 親 AC | 本 PBI でのカバー |
|------|-----------------|
| parent-AC-6 | Tool Policy / Hook enforcement 境界整理（直接対応） |
| parent-AC-7 | C-3/C-4/scope discipline/verification honesty 維持 |

## 関連リンク

- 親計画: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- 子 PBI YAML: [`docs/working/PBI-116/children/PBI-116-06.yaml`](../PBI-116/children/PBI-116-06.yaml)
- Issue: https://github.com/s977043/plangate/issues/122
- Interface preflight: [`docs/working/PBI-116/interface-preflight.md`](../PBI-116/interface-preflight.md)
- 接続元 PBI-116-02: [`docs/working/TASK-0040/`](../TASK-0040/)
- Phase 1 成果: [`docs/ai/core-contract.md`](../../ai/core-contract.md)
