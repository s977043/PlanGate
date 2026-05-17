---
task_id: TASK-0071
artifact_type: handoff
schema_version: 1
status: done
---

# HANDOFF — TASK-0071 Governance Hardening（親 PBI / D-1 全スライス完了）

> Rule 5 集約。D-1 で S1+S2 / S3 / S4 の3分割を C-3 決定し、各スライスを
> 別実装 PBI として完遂・全マージ済。本 handoff は親 PBI の最終集約。

## 1. 要件適合確認結果（スライス別）

| スライス | 実装 PBI / PR | 内容 | 判定 |
|---------|--------------|------|------|
| **S1+S2** | TASK-0080 / #254（MERGED `526470a`）| Shadow Config 恒久対処: wiring 契約正本 + 冪等 apply script + `doctor --check-settings` + V-1/handoff タスクロック + CI settings-drift required | ✅ V-1〜V-4 全 PASS |
| **S4** | TASK-0081 / #256（MERGED `8822a33`）| 責務4分類正本（`responsibility-classes.md`: AI/Human/CI/Workflow-owned）+ hybrid から参照 | ✅ V-1〜V-3 全 PASS |
| **S3** | TASK-0082 / #257（MERGED `1c097a4`）| EH-3 承認ファイル方式メンテモード + SKIP_REASON 例外申請 + CI skip-ack required | ✅ V-1〜V-4 全 PASS |

親 PBI 受入: 「AI 不可侵領域（settings 自己改変 / merge）+ EH-3 バイパス
常態化」を構造的に解消する、が **全スライス完了で達成**。

## 2. 既知課題一覧

- AC-8/EH-9 wiring の **実適用**はユーザー操作（`sh scripts/apply-claude-settings.sh`・
  self-mod ガード。#254 で 1 コマンド化済）。doctor/CI/タスクロックで未適用は機械検出
- skip-ack / settings-drift の **required 化は GitHub ruleset 設定**（Human-owned）
- 各スライスの V2 候補: maintenance.json 改竄検知 / #213 Plan Health 連携 /
  schema runtime 検証 / skip-decision-log の #200 連携（各 handoff 参照）

## 3. V2 候補

- TASK-0071 S3 マージ後の skip-ack ruleset required 化（Human-owned）
- 責務4分類の機械検出（AI-owned 誤帰属の lint 警告）
- F5-AD（#253 済）/ Hardening Override の TASK-0071 機械接続（responsibility-classes
  で概念定義済・実装は別 PBI 候補）

## 4. 妥協点

- D-1 で 3 分割（S1+S2 先行・S3 設計重め・S4 締め）。承認境界は撤廃せず
  強化のみ。settings 適用は AI 不可を恒久受容し「script+検証+ロック」で構造解消
- Gemini CLI の V-3 出力不全/クラッシュが頻発 → Codex 主体運用を前例化

## 5. 引き継ぎ文書（5分サマリ）

本セッション通底の構造摩擦（settings 自己改変ガード下の Shadow Config /
EH-3 バイパス常態化 / AI 不可侵領域の責務曖昧）を、TASK-0071 Governance
Hardening として計画（#244）→ D-1 3分割 → S1+S2(#254) / S4(#256) /
S3(#257) を全実装・全マージで恒久対処。各スライスは正規 PlanGate フル
フロー（C-1/C-2/C-3/V-1/V-3/V-4）+ multi-agent 外部レビュー fix-loop を完走。
TASK-0071 はこれをもって完全クローズ。

## 6. テスト結果サマリ

- 全スライス: hook 78/0・CLI 64/0・各 V-1〜V-4 PASS（マージ済 PR で実証）
- CI: settings-drift / skip-ack required job 追加・全 green
- 既存挙動: 完全 additive / 非破壊（既存 5mode・C-3三値・doctor 12項目・
  P4(d)/plan.md 保護 すべて不変）
