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
      （init 前 finalize → stderr 診断 + exit 4）+ ヘッダコメント正本参照の更新。
      **F-3 検査の挿入位置は `_PG_EXTRA_ORIGINAL_RC=$?`（現 `_extra-contract.sh:116`）の
      直後で固定**（前に入れると `[ -z … ]` が `$?` を潰し rc 伝播 TC-06 が壊れる / R-011）
      （owner: agent / depends_on: T-03 / rollback: `_extra-contract.sh` の当該 hunk revert） 🚩
- [ ] T-05: bootstrap の全対象（**実測母数 14** = 層 A 12 + ta-61 本体 + ta-61 fixture 複製。
      件数は契約値でない — AC-4 は marker 由来で導出）を
      Mode resolution v2 ブロックへ同型置換。**T-04 と同一 commit**（述語分裂の中間状態禁止）
      （owner: agent / depends_on: T-04 / rollback: `git checkout origin/main -- tests/extras/` 後に T-03 の TC を再適用） 🚩
- [ ] T-06: 述語機械照合 TC-35 を ta-61 へ**新設**（bootstrap 2 行 × **marker 由来の
      動的導出**リスト・行頭空白正規化・**絶対件数を assert しない** + helper 変数消費形の
      分離照合 / R-005）+ TC-32（init 前 finalize → exit 4 + 診断）追加
      + **fixture 4 本（`tc01.sh` `:383` / `tc01b.sh` `:410` / `tc21.sh` `:582` /
      `tc26-runner.sh` `:631`）へ `_pg_extra_direct=0` を明示設定**（harness 模擬だけでなく
      **standalone 期待の `tc01b.sh` にも入れる** — 入れないと TC-01b/01c が空振り PASS 化し
      HR-4 の検出力が消える / R-001・R-002）+ **TC-37 新設**（AC-8: `_pg_extra_direct` 未設定
      fixture = 0 件の静的検査）+ **TC-30b 追加**（`_pg_extra_direct=0` を export しても
      層 A は standalone = 無条件代入の pin / R-008）+ **`tests/extras/README.md` 規約 8 へ
      1 行追記**（トップレベル設定必須 / R-012・Q-2 決着）
      （owner: agent / depends_on: T-05 / rollback: ta-61 と README の当該 hunk revert）

### 検証

- [ ] T-07: green 確認 — TC-30/30b/31/32/35/37 PASS + ta-61 全 TC PASS + フルスイート rc=0 +
      層 A 12 本の清浄 env standalone 実行（AC-3 / AC-7 / AC-8）
      （owner: agent / depends_on: T-06 / rollback: 不要（読取のみ）） 🚩
- [ ] T-08: 変異注入（AC-5 (b)）— (a) M-1: case 行（call site）除去変異で TC-30/31 が
      dash で FAIL（kill）、(b) M-2: helper を変数消費から独自判定へ退行させる変異で
      TC-31 が **zsh を含めて** FAIL（zsh FUNCTION_ARGZERO 問題の恒久検出 / F-1）、
      (c) M-3: F-3 検査除去変異で TC-32 が FAIL、
      **(d) M-4（新規 / R-001）: helper の 3 env 述語を `PG_HARNESS_SOURCED` 単独へ
      退行させる変異で TC-01b / TC-01c が FAIL（kill）** — fixture 更新前はこの変異が
      生存する（＝ HR-4 検出力喪失の証明）ため、T-06 の fixture 更新と対で実施する。
      ログを `evidence/test-runs/mutation-*.log` へ
      （owner: agent / depends_on: T-07 / rollback: 変異は sandbox 複製上でのみ実施し本体に触れない） 🚩
- [ ] T-09: 4 シェル最終マトリクス（dash/zsh/bash/sh × 実測 1/2 シナリオ）実測 →
      AC-1 / AC-2a〜2d evidence。**各シェルの実体と測定ホストを併記**
      （`ls -l /bin/sh` / `$BASH_VERSION` / `dash --version` / `zsh --version` / `uname -a`。
      CI 実体 dash と `sh` の対応を evidence から復元可能にする / R-009）
      （owner: agent / depends_on: T-07 / rollback: 不要（読取のみ））

### 完了

- [ ] T-10: status.md / current-state.md 更新 + handoff 素材整備。必須要素:
      (1) TASK-0921 既知課題 2 / 2-bis 対応表、
      (2) **「#1044 で塞いだ範囲 = bootstrap 系 13 本 + helper、未塞ぎ = 5 本
      （`ta-25`/`ta-26`/`ta-58`/`ta-59`/`ta-60`・2 env AND・Slice 2 へ）」の行**（R-006）、
      (3) 旧 handoff「14 箇所」と新分母の差異注記（F-5）
      （owner: agent / depends_on: T-08, T-09 / rollback: 不要（docs のみ））
- [ ] T-11: **`docs/working/TASK-0921/handoff.md` 既知課題 2 / 2-bis へ追記**（AC-9 / R-003）—
      本 PR による解消、および **変異 evidence 18 本の HEAD 整合失効 + 後継が本 PBI の
      M-1〜M-4（superseded）** を 1 行で記載。TASK-0921 の **plan.md は編集しない**
      （承認済み歴史文書）。TC-38 が V-1 でこの追記を静的確認する
      （owner: agent / depends_on: T-08 / rollback: 当該追記行を revert（追記のみ・既存行は編集しない））

## 👤 Human タスク

- [ ] H-01: **C-3 ゲート**（high-risk = 人間必須）。併せて以下を裁定:
      - **Q-1 (1)**: F-3 init 前 finalize の方式（exit 4 fail-closed 案 vs harness 保護案）
      - **Q-1 (2)**: 上記が前者の場合、**Constraints R-024 に carve-out を設けること自体の
        可否**（方式選択とは別レイヤの論点 / R-007）
      - **Q-3**: AC 分割（AC-2 → AC-2a〜2d）で AC 行数が 12 となり定量表では critical 帯
        （11+）に触れる件（実質要件数は 9）。**high-risk 維持の追認 or critical への
        引き上げ**（R-004 の副作用）
      - ⚠️ **本 C-3（`approve TASK-1044` / `c3.json` 発行）は C-2 確定反映の完了後に行うこと**。
        反映前に承認すると C-2 REJECT の plan を承認した状態になる
- [ ] H-02: C-4 PR レビュー（GitHub 上）

## ⚠️ 依存関係

- T-03 以降のすべては H-01（C-3 APPROVED + Q-1 / Q-3 裁定）後に開始（exec ゲート）
- T-04/T-05 は同一 commit（原子性）
- **T-06 の fixture 更新と T-08 (d) の M-4 は対**（更新なしでは M-4 が生存し、
  更新の有効性を証明できない）
- T-11 は T-08 完了後（superseded 宣言の根拠 = M-1〜M-4 の実測が揃ってから追記する）
- H-02 は V 系完了 + PR 作成後
