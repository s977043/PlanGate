# TASK-1608 EXECUTION TODO

> Mode: high-risk。実装タスクは `rollback:` 必須。

## 👤 Human

- [ ] H-1 C-3: plan / todo / test-cases の承認判断（Q-1〜Q-4 の回答を含む）。`approvals/c3.json` は Human が発行 — owner: human
- [ ] H-2 C-4: PR レビュー・merge — owner: human / depends_on: T-12

## 🤖 Agent

### 準備

- [ ] T-1 現行 seeds / digest の不可視文字・HTML コメント・setext・blockquote の有無を実測し `evidence/` に記録 — depends_on: H-1 / rollback: 不要（読取のみ）
- [ ] T-2 回帰ケース（TC-R4-02 / TC-R4-03 / TC-HTML-* / TC-BLK-* / TC-INV-* / TC-NEG-*）を追加し、RED / GREEN の内訳を記録 🚩 — depends_on: T-1 / rollback: テスト追加コミットを revert

### 実装

- [ ] T-3 入力正規化（utf-8-sig・CRLF→LF）とブロック状態機械（fenced / html / indented / atx / paragraph・list）を実装 — depends_on: T-2 / rollback: commit revert
- [ ] T-4 seed 意味解析を状態機械の出力へ載せ替え（見出しの正規形判定・守備範囲外の日付見出しの拒否）🚩 既存 22 件 PASS — depends_on: T-3 / rollback: commit revert
- [ ] T-5 digest 意味解析（`## 対象エントリ` 節の唯一性・索引行）を載せ替え — depends_on: T-3 / rollback: commit revert
- [ ] T-6 不可視文字の拒否（D-2）と否定値判定の字句境界（D-3）🚩 TC-INV / TC-NEG PASS — depends_on: T-4, T-5 / rollback: commit revert
- [ ] T-7 旧正規表現・`mask_code_blocks` の撤去、docstring 残存脅威モデル更新（PG-SH-GUARD 領域は不変）🚩 TC-STRUCT-01/02 — depends_on: T-6 / rollback: commit revert

### 検証

- [ ] T-8 unit / ta-116 / ta-70 / 現行データ（TC-INT-01〜03）をログ保存 🚩 7 / 5 不変 — depends_on: T-7 / rollback: 不要
- [ ] T-9 変異注入（状態遷移ごと）で検出力を実証 — depends_on: T-8 / rollback: 変異は commit しない
- [ ] T-10 敵対レビュー R1（新構造への回避）→ `review-external.md` 台帳 — depends_on: T-9 / rollback: 不要
- [ ] T-11 敵対レビュー R2（是正の有効性・新しい穴・正常系の破壊）→ 収束判定。同層新クラスが 2 連続なら停止して Q-1 再提示 🚩 — depends_on: T-10 / rollback: 不要

### 完了

- [ ] T-12 handoff.md（残存脅威モデルを含む）・status / INDEX 更新、PR を ready for review — depends_on: T-11 / rollback: 不要
