---
task_id: TASK-0079
artifact_type: handoff
schema_version: 1
status: done
---

# HANDOFF — TASK-0079 (F5-AD 実装 / Lite分岐+C-3降格)

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 lite_eligible 内包 | PASS | mode-classification §lite_eligible（判定軸+自動推定+人間override・内包派生） |
| AC-2 Lite構成差分 | PASS | 「Lite ゲート構成 vs Standard」表 |
| AC-3 C-3降格 opt-in既定OFF | PASS | working-context #### C-3 条件付き降格（同期既定/非同期opt-in/降格条件） |
| AC-4 AC-8安全側 | PASS | 判定不能等→必ず Standard・同期（mode-classification + working-context 両記） |
| AC-5 AC-9 reject巻戻し具体 | PASS | working-context: ブランチ破棄/PR close/invalidation/監査/派生5項目 |
| AC-6 AC-10 Hardening Override | PASS | working-context: TASK-0071領域抵触で Lite/降格無効・最上位優先 |
| AC-7 AC-11/AC-12 | PASS | critical原則lite不可+例外人間C-3明示 / 外部1本 critical/major=0要求 |
| AC-8 既定OFF挙動不変 | PASS | 完全 additive（削除行 0）・既存5mode/C-3三値非破壊・hook 78/0・scripts不変 |
| AC-9 監査記録 | PASS | decision-log.jsonl(append-only)+status.md に降格/override/reject 記録 |

## 1-bis. V-3/V-4 結果（Codex 承認可 / V-4 全 PASS）

V-3 Codex=承認可（critical0/major0/minor1）。Gemini 出力不全→Codex 主体。
minor（critical Lite 例外と非同期降格の関係）を mode-classification に一文
反映。V-4 リリース前チェック（critical 必須）全 PASS（hook 78/0・additive
削除行0・既存非破壊・scripts不変・承認境界非撤廃・handoff6要素）。

## 2. 既知課題一覧

- AC-10 Hardening Override は TASK-0071（#244 OPEN）未マージのため**概念
  ルールとして実装**。TASK-0071 マージ後に機械判定へ接続（follow-up）。
- 自動推定は #213 Plan Health 未実装のため AC-8 安全側（判定不能→Standard）
  で成立。#213 実装時に自動推定精度を接続（follow-up）。
- mode-classification.md / working-context.md は CI markdownlint スコープ外。

## 3. V2 候補 / follow-up

- TASK-0071 マージ後の Hardening Override 機械判定接続
- #213 Plan Health 連携での lite_eligible 自動推定実装
- C-3 非同期降格の reject 巻き戻しの CLI/Hook 化（現状は手順定義）

## 4. 妥協点

- 設計は TASK-0077 C-3 APPROVED 確定。本 PBI は実装＝AC-8〜12 を rules に
  忠実反映。承認境界は不変（同期/非同期の選択肢化のみ・opt-in 既定 OFF）
- doc-enforced 実装（mode 判定は人間 override + 将来 Hook）。完全 additive
  で既存挙動を 1 bit も変えない

## 5. 引き継ぎ文書（5分サマリ）

#234-A/D の設計（TASK-0077 C-3 APPROVED）を実装。mode-classification に
`lite_eligible` 内包派生、working-context に C-3 条件付き降格（同期/非同期
opt-in・既定OFF）+ AC-9 reject巻戻し + AC-10 Hardening Override + 監査。
完全 additive・既存挙動不変・hook 78/0。承認境界は撤廃せず強度/同期性の
選択肢化のみ。残: V-3/V-4/C-4 + TASK-0071/#213 連携 follow-up。

## 6. テスト結果サマリ

- AC-1〜9 grep 検証: 全 PASS
- additive 検証: 削除行 0（既存5mode/C-3三値 非破壊）
- hook 回帰: 78 passed / 0 failed
- scripts/bin diff: 空（doc-enforced・コード不変）
