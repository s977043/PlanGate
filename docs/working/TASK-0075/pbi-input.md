---
task_id: TASK-0075
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0075

> F4: opt-in 終端 Retro フェーズ（run 完了時に振り返りドラフト自動生成・
> append-only ログ化・承認境界維持）
> 起源（field feedback）: #235（関連: #228 テンプレ / #200 集計 / #231 judge）

## Context / Why

PlanGate に run（PBI/TASK）完了後の振り返りを「ワークフロー終端フェーズ」
として確実に実行する仕組みが無い。#228（Outcome Review テンプレ）は認知
負荷観点で自動生成を意図的に先送り、結果「振り返りが人間トリガー依存＝
忘れる」運用ギャップが残る（field evidence: #234 の run で振り返りは人間が
明示依頼するまで一切起動しなかった）。最も学びが多い失敗 run の知見が死蔵し、
#200 の期間集計の入力（各 run の構造化振り返り）が継続蓄積されない。

handoff（引き継ぎ）と outcome review（改善学習）は #228 で役割分担済みだが、
**後者の実行を保証する手段が無い**。これを opt-in 終端フェーズで埋める。

## What — Scope

### In scope

- **新フェーズ `R`（Retro）** をワークフロー終端（V-x 後・handoff 後）に定義
  （workflow 定義 + execution-sequence + README 反映）
- **opt-in 起動**: 明示フラグでのみ発火（既定 OFF。初学者の認知負荷を増やさない）。
  発火条件の正本を定義（既存に正式 Level 体系が無いため、本 PBI で
  opt-in フラグ方式を正本化。Level 連携は将来拡張）
- エージェントは **#228 固定 5 評価項目でドラフトのみ自動生成**
  （目的達成可否 / 失敗・手戻り / 次回再利用すべき判断 / 効いた skill・gate・
  artifact / 1人運用で負荷が高かった箇所）。**スコアリングはしない**
  （#231 judge と責務非重複）
- 出力は handoff と別の **append-only `improvement-seeds.md`** に蓄積
  （run をまたいで構造化累積。配置・スキーマを定義）
- **人間が 1 行で confirm / skip**（承認境界を撤廃しない＝自動はドラフトのみ、
  確定は人間。PlanGate「人間判断点を固定」原則維持）
- #200 期間集計が `improvement-seeds.md` を入力源に吸い上げる接続点を定義

### Out of scope

- LLM-as-a-Judge 自動評価（#231）
- 期間集計・sprint report 生成（#200 本体）
- skill / playbook の自動更新・自動昇格（OSS で危険・明示対象外）
- 既定 ON / 全 run 強制発火（opt-in 限定厳守）
- #228 テンプレ自体の再定義（本 PBI は #228 を実行フェーズ化し #200 へ給餌
  する接続層。テンプレ仕様は #228 に従う）
- F1/F2/F3/F5

## Acceptance Criteria

- [ ] AC-1: 新フェーズ `R`（Retro）がワークフロー終端（handoff 後）に定義され、execution-sequence/README に反映される
- [ ] AC-2: opt-in 起動の正本（明示フラグ・既定 OFF・発火条件）が定義され、既定では発火しない
- [ ] AC-3: ドラフトは #228 固定 5 項目で生成され、スコアリング（良し悪し判定）をしない（#231 と責務非重複が明記）
- [ ] AC-4: 出力は append-only `improvement-seeds.md`（配置・スキーマ定義、run またぎ累積）
- [ ] AC-5: 人間 confirm/skip 1 行で確定し、自動なのはドラフトのみ（承認境界維持が明文化）
- [ ] AC-6: #200 期間集計が improvement-seeds.md を入力源にする接続点が定義される
- [ ] AC-7: #228 を再定義せず参照する（テンプレ仕様は #228 準拠と明記）
- [ ] AC-8: 既存 workflow 定義 / doc 整合性に回帰がない（既定 OFF で既存 run 挙動不変）

## Notes from Refinement

- #228 との両立: 自動なのはドラフトのみ・人間 confirm/skip・opt-in 限定で
  初学者無影響・Markdown 出力・スコアリングなし（#231 へ委譲）
- 正式 Level 体系は未実装 → 本 PBI は opt-in フラグ方式を正本化（Level 連携は将来）
- F2/F3 と同じく「人間判断点を固定／ゲート回避させない」思想と一貫
- workflow 定義変更のため mode は high-risk 想定

## Estimation Evidence

**Risks**: workflow 終端フェーズ追加（定義変更）。既定 ON 化や強制発火は
#228 設計判断と衝突 → opt-in 厳守・既定 OFF を不変条件化
**Unknowns**: opt-in フラグの具体形（env / config / pbi-input メタ / コマンド
オプション）→ C-3 判断。improvement-seeds.md スキーマ粒度 → C-3
**Assumptions**: ドラフトのみ自動・確定は人間で承認境界維持。Mode 想定: high-risk
