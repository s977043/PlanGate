# #543 Plan Review Gate 判定連携 — 設計ノート（#544 Phase2）

> **Status**: 設計ノート（2026-06-15）。実装は #551（Loop 戦略 rev.3）merge 後。
> **位置づけ**: #544 Loop 安全制御の **Phase2（Gate 化・強制実装）**。#544/#551 が「明文化」、#543 が「強制」。
> **関連**: #527（Enforcement Integrity）/ #487（Risk Budget）/ #493（計画修正）

---

## 1. 役割（rev.3 と一貫）

- **#544/#551**: plan に Loop Scope / Stop / Resume / Replan Triggers（機械値）/ Revert / Loop Attempts を**記述**（ソフト強制）
- **#543（本設計）**: その**充足と外部レビュー結果**を入力に、**進行可否を判定し止める・通す**（hard 強制）

PlanGate の責務はレビューそのものでなく「レビュー結果で進行可否を判定」（#543 原文）。

## 2. 入力（外部レビュー結果スキーマ・#543 原文）

```text
Decision: go | revise_plan | human_approval_required | no_go
Risk: low | medium | high
Blocking Issues / Non-Blocking Suggestions / Do Not Touch /
Required Plan Changes / Verification Required / Stop-Work Conditions /
Final Implementation Instruction
```

## 3. 判定マッピング（plan→approve→exec への接続）

| 外部 Decision | PlanGate C-3 判定 | 挙動 |
|--------------|-------------------|------|
| `go` | APPROVED 候補（他条件次第） | exec 可 |
| `revise_plan` | CONDITIONAL | Required Plan Changes を反映→再判定（既存 R-NNN 集約フローに乗せる） |
| `human_approval_required` | 人間 C-3 強制（autonomous APPROVE 無効化） | mode-classification の HO 同様の格上げ |
| `no_go` | REJECTED | plan 再生成 |

- **Risk=high** → 最低 high mode・autonomous APPROVE 不可（mode-classification と整合）。
- **Stop-Work Conditions** → #544/#551 の **機械トリガー**（変更ファイル2倍/+5・連続失敗3回・反復3回・plan外波及・AC変更）に**マッピング**し、exec 中に実行層（codex-guarded.sh / doctor）が監視。発火で Replan/停止。
- **Verification Required** → plan の Verification Automation に必須注入。
- **Do Not Touch** → 既存 `forbidden_files`（EH-6 / check-forbidden-files.sh）に接続。

## 4. 充足チェックの強制化（#544 Phase1 → Phase2）

- Phase1（#544）: C-1 拡張で「Replan Triggers に機械トリガー1つ以上」「Stop/Resume 記入」を**検出**（未記入で WARN）
- Phase2（#543）: 上記未充足で **C-3 承認不可（strict Gate）**。`bin/plangate exec` が拒否。

## 5. 既存資産への接続

| 接続先 | 役割 |
|--------|------|
| `external-reviewer-interface.md` / `.plangate-reviewers.yaml` | 外部レビュー結果の取り込み規約（#227） |
| `c3-approval.schema.json` | Decision→c3_status マッピングの schema 拡張（gate_checks 拡張 or 新フィールド） |
| EH-3 / check-plan-hash | 確定 plan の hash 固定（既存） |
| EH-6 / forbidden_files | Do Not Touch の強制 |
| codex-guarded.sh / doctor | Stop-Work Conditions（機械トリガー）の実行層監視（#550/#527 と共有） |

## 6. 段階
1. #551 merge（rev.3 正本化）
2. 外部レビュー結果スキーマ → c3.json/judgment への mapping 設計確定（本ノート）
3. schema 拡張 + 充足チェック strict 化（HO: working-context/schema）
4. Stop-Work=機械トリガーの実行層実装（#550/#527 と共通基盤）

## 7. 未決
- [ ] Decision→c3_status の schema 表現（新フィールド vs gate_checks 拡張）
- [ ] 機械トリガー実行層（codex-guarded.sh / doctor）の #550 との共通化範囲
- [ ] human_approval_required の autonomous 無効化を mode-classification 正本に追記するか
- [ ] 外部レビュー未取得時の安全側（unavailable → strict 側に倒す）

## 8. 一行サマリ
> #543 = 外部レビュー結果（Decision/Risk/Stop-Work）を C-3 判定に接続し #544 の充足を強制する Phase2 Gate。Stop-Work は #544/#551 の機械トリガーへ、実行層監視は #550/#527 と共通化。
