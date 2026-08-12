# EXECUTION TODO — TASK-1044

> plan: `plan.md` / mode: **high-risk**（実装タスクは rollback 必須）
> L-0〜V-4 / PR 作成は workflow-conductor が自動制御するため含めない。

## 🤖 Agent タスク

### 準備

- [ ] T-01: pre-fix evidence 採取 — 現 HEAD で実測 1（helper 欠落）/ 実測 2（helper 存在）の
      4 シェルマトリクスを `evidence/test-runs/pre-fix-shell-matrix.log` へ記録
      （owner: agent / depends_on: なし / rollback: 不要（読取のみ）） 🚩
- [ ] T-02: ta-61 全 TC + フルスイート `sh tests/run-tests.sh` の baseline 実測
      （owner: agent / depends_on: T-01 / rollback: 不要（読取のみ））

### 実装（TDD）

- [ ] T-03: ta-61 へ TC-30（env 漏出 + helper 欠落 + dash 直接実行 → rc=1）/
      TC-31（env 漏出 + helper 存在 + dash 直接実行 → standalone 契約有効: summary 出力 +
      rc 契約）を追加し、**現実装で red を確認**（AC-5 (a)）
      （owner: agent / depends_on: T-02 / rollback: ta-61 の追加 TC hunk を revert） 🚩
- [ ] T-04: helper `_pg_extra_resolve_mode` を**変数消費形**（`${_pg_extra_direct:-1}` を
      消費・関数内で `$0` を再評価しない / F-1）へ変更 + F-3 明示検査
      （init 前 finalize → stderr 診断 + exit 4）+ ヘッダコメント正本参照の更新
      （owner: agent / depends_on: T-03 / rollback: `_extra-contract.sh` の当該 hunk revert） 🚩
- [ ] T-05: bootstrap 14 箇所（層 A 12 + ta-61 本体 + ta-61 fixture 複製）を
      Mode resolution v2 ブロックへ同型置換。**T-04 と同一 commit**（述語分裂の中間状態禁止）
      （owner: agent / depends_on: T-04 / rollback: `git checkout origin/main -- tests/extras/` 後に T-03 の TC を再適用） 🚩
- [ ] T-06: 述語機械照合 TC-35 を ta-61 へ**新設**（bootstrap 2 行 × 14 箇所・行頭空白
      正規化 + helper 変数消費形の分離照合）+ TC-32（init 前 finalize → exit 4 + 診断）追加
      + harness 模擬 fixture（tc01.sh 等）へ `_pg_extra_direct=0` 明示設定
      （owner: agent / depends_on: T-05 / rollback: ta-61 の当該 hunk revert）

### 検証

- [ ] T-07: green 確認 — TC-30/31/32 PASS + ta-61 全 TC PASS + フルスイート rc=0 +
      層 A 12 本の清浄 env standalone 実行（AC-3 / AC-7）
      （owner: agent / depends_on: T-06 / rollback: 不要（読取のみ）） 🚩
- [ ] T-08: 変異注入（AC-5 (b)）— (a) M-1: case 行（call site）除去変異で TC-30/31 が
      dash で FAIL（kill）、(b) M-2: helper を変数消費から独自判定へ退行させる変異で
      TC-31 が **zsh を含めて** FAIL（zsh FUNCTION_ARGZERO 問題の恒久検出 / F-1）、
      (c) M-3: F-3 検査除去変異で TC-32 が FAIL。ログを `evidence/test-runs/mutation-*.log` へ
      （owner: agent / depends_on: T-07 / rollback: 変異は sandbox 複製上でのみ実施し本体に触れない） 🚩
- [ ] T-09: 4 シェル最終マトリクス（dash/zsh/bash/sh × 実測 1/2 シナリオ）実測 → AC-1/AC-2 evidence
      （owner: agent / depends_on: T-07 / rollback: 不要（読取のみ））

### 完了

- [ ] T-10: status.md / current-state.md 更新 + handoff 素材（TASK-0921 既知課題 2 / 2-bis
      対応表を含む）整備
      （owner: agent / depends_on: T-08, T-09 / rollback: 不要（docs のみ））

## 👤 Human タスク

- [ ] H-01: **C-3 ゲート**（high-risk = 人間必須）。併せて **Q-1 裁定**
      （F-3 init 前 finalize: exit 4 fail-closed 案 vs harness 保護案）
- [ ] H-02: C-4 PR レビュー（GitHub 上）

## ⚠️ 依存関係

- T-03 以降のすべては H-01（C-3 APPROVED + Q-1 裁定）後に開始（exec ゲート）
- T-04/T-05 は同一 commit（原子性）
- H-02 は V 系完了 + PR 作成後
