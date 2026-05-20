# TASK-0106 C-1 セルフレビュー（v3 / R-012〜R-020 反映後）

> Source: pbi-input.md (v3) / plan.md (v3) / todo.md (v3) / test-cases.md (v3) / review-external.md
> Updated: 2026-05-20 (R-012〜R-020 確定反映後の簡易再 C-1)
> 反映コミット: 本コミット（Refs: R-012..R-020）

## 判定: **PASS（CONDITIONAL APPROVE 候補）** — best-effort 設計を明示した上で C-3 ゲート再提出可能

外部レビュー v2 で検出された **critical 1**（R-012: AI 自己付与不可の構造保証
が成立していない）+ major 5 + minor 3 を `review-external.md` に R-012〜R-020
として集約し、本コミットで 1 回確定反映。

**R-012 の取扱い（重要）**: 「AI が呼べる CLI で AI 自己付与を構造的に不可能
にする」は原理的に困難であるため、本 PBI では **多層 best-effort 防御
（L1-L4）+ 全試行の監査ログ記録** で AI 自己付与を阻む方針を採用し、完全な
構造保証は **別 PBI に分割** することを **明示** した（pbi-input/plan/AC/TC
に反映）。この方針自体の妥当性は C-3 ゲート（Human）で判断される。

## Plan チェック（7 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜AC-10、TC-01〜TC-31（+ TC-26a/b/c/d で 35 件）対応 |
| C1-PLAN-02 | Unknowns 処理 | PASS | 全 Unknowns 確定。R-012 は best-effort 明示で取扱い確定 |
| C1-PLAN-03 | スコープ制御 | PASS | Hardening Override 10 パターン全 todo 化（R-015 解消）、Override 判定順序明文化（R-020）、構造保証は別 PBI 分割（R-012 明示） |
| C1-PLAN-04 | テスト戦略 | PASS | Unit (L1-L4 各層) / Hook / Integration / E2E / Backward compat / Runner 統合 / 回帰、計 35 件 |
| C1-PLAN-05 | Work Breakdown Output | PASS | T-04 を多層防御 + 監査ログ込みに、T-05 を flock 必須化、T-06 を 10 パターン明示に拡張（R-012/R-015/R-017） |
| C1-PLAN-06 | 依存関係 | PASS | T-03→T-04（多層防御）→T-05（flock+os.replace）→T-06（10 パターン Override）→T-07a/b（doctor）→T-08..T-12 |
| C1-PLAN-07 | 動作検証自動化 | PASS | 全 TC 自動化可、L1-L4 各層の reject + 監査ログ + race fail-closed を unit/integration で検証 |

## ToDo チェック（5 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TODO-01 | タスク粒度 | PASS | T-01〜T-12（high-risk 範囲内） |
| C1-TODO-02 | depends_on 設定 | PASS | T-03→T-04→T-05→T-06→T-07a/b、T-10 (CLI 自己付与防止) は critical 並走 |
| C1-TODO-03 | チェックポイント | PASS | T-04: L1-L4 各 reject + 監査 / T-05: flock + os.replace + race / T-06: 10 パターン block + 順序 |
| C1-TODO-04 | Iron Law 遵守 | PASS | maintenance dogfooding（実装後）+ PLANGATE_HOOK_TASK 設定 |
| C1-TODO-05 | 完了条件 | PASS | 全 T + handoff 6 要素 + AC-1..AC-10 + テスト件数維持 |

## TestCases チェック（3 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TC-01 | 受入基準との紐付き | PASS | AC-9→TC-20 修正済（R-014）、AC-5→TC-25/TC-26a/b/c/d で多層防御を網羅 |
| C1-TC-02 | Edge case 網羅 | PASS | TC-14〜TC-31 + TC-26a/b/c/d 計 22 件、TTL 既定 5 分整合（R-013）、Override 表現整合（R-016） |
| C1-TC-03 | 自動化可否 | PASS | 全 TC 自動化可。L3 ppid heuristic は CI 環境で再現可能、L4 nonce は環境変数で注入可能 |

## 指摘事項（C-1 v3）

**残 critical: 0**（R-012 は best-effort 明示で取扱い確定。完全保証は別 PBI に
分割するため本 PBI 内の blocker としない。C-3 判定では「multi-layer best-effort
+ audit という設計判断そのものの是非」を Human が評価）。

**残 major: 0** / **残 minor: 0**

## C-1 自己採点

| 観点 | 採点 (0-100) |
|------|------------|
| 受入基準網羅 | 98 |
| スコープ制御 | 96 (R-012 best-effort 明示・別 PBI 分割表明) |
| リスク識別 | 97 (race を flock 必須化で構造排除) |
| テスト戦略 | 96 (L1-L4 各層を個別 TC 化、監査ログ TC 追加) |
| **総合** | **97** |

**APPROVE 候補（CONDITIONAL 含む）**: critical/major/minor 0、R-012 の方針判断
を Human に委ねる構造で再提出可能。

## C-2 / V-3 監査

詳細は `review-external.md`（R-001〜R-020、reflected_in=本コミット）。
全指摘 reflected で監査トレース整合。

## 推奨される C-3 ゲート判定

**CONDITIONAL APPROVE 候補**: R-012 の best-effort 設計判断を Human が APPROVE
すれば exec 着手可能。REJECT の場合は別 PBI 分割（運用性向上のみ / 構造保証）
への再構成が次手。

## 次フェーズ

- **C-3 ゲート (Human-owned)**: `approvals/c3.json` 発行
- C-3 APPROVED 後に AI exec 着手
