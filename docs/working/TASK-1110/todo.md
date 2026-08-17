# EXECUTION TODO — TASK-1110 (#1110)

## 🤖 Agent タスク

### 準備

- [x] **T-01** 現状実測（A〜E + 境界 18 ケース）を evidence へ固定
  - depends_on: なし / Owner: agent / 🚩 A が rc=2（誤検出）であること
  - rollback: 不要（読取のみ）
- [x] **T-02** 既存 TA-25 の TC 一覧と `_t25_mutate` ハーネスの構造を把握
  - depends_on: なし / Owner: agent / rollback: 不要（読取のみ）

### 実装

- [x] **T-03**（RED）`T1110-TC-*` を `tests/extras/ta-25-approval-token-guard.sh` に追加
  - depends_on: T-01, T-02 / Owner: agent
  - 🚩 原本 guard で新規 TC が FAIL すること（RED の確認）
  - rollback: `git checkout -- tests/extras/ta-25-approval-token-guard.sh`
- [x] **T-04**（GREEN）`_redirect_writes_token()` 新設 + redirect レーンの相関化
  - depends_on: T-03 / Owner: agent
  - 🚩 `sh -n` 通過 / 新規 TC が PASS / 既存 block 系 TC が期待値不変で PASS
  - rollback: `git checkout -- scripts/check-approval-token-write.sh`
- [x] **T-05** BLOCK メッセージへ `redirect_target=` を追加
  - depends_on: T-04 / Owner: agent / 🚩 `rule=file-redirect` 表記は維持（既存 T1045-TC-08）
  - rollback: T-04 と同じ

### 検証

- [x] **T-06** `sh tests/extras/ta-25-approval-token-guard.sh` を個別実行し rc=0
  - depends_on: T-04, T-05 / Owner: agent
  - ⚠️ **フルスイート（`tests/run-tests.sh`）は実行しない**（ta-61 入れ子 / 並走妨害）
  - rollback: 不要（検証のみ）
- [x] **T-07** A〜E の修正後 rc を実測し、修正前後の対比表を evidence へ
  - depends_on: T-04 / Owner: agent / rollback: 不要（検証のみ）
- [x] **T-08** 変異 M-1 / M-2 を **call site** に適用 →FAIL 確認→復元→PASS 確認
  - depends_on: T-06 / Owner: agent
  - 🚩 空振り（PASS のまま）なら TC の欠陥として正直に記録する
  - rollback: mutant は tmp 上のコピーのみ。原本は変更しない

### 完了

- [x] **T-09** Plan Package（plan / todo / test-cases / review-self）と status を確定
  - depends_on: T-08 / Owner: agent / rollback: 不要
- [x] **T-10** commit + push（`fix/1110-eh13-redirect-correlation`）
  - depends_on: T-09 / Owner: agent
  - ⚠️ コミットメッセージに承認トークンの literal を書かない（#1110 の誤検出を自ら踏むため）。
    `git commit -F <file>` を用い、literal を避けた本文にする
  - rollback: `git reset --hard <前の SHA>`（push 前）

## 👤 Human タスク

- [ ] **H-01 C-3 ゲート**（exec 前ゲート）: mode = high-risk のため **人間 C-3 必須**。
  本ワーカーは `c3.json` を**発行しない**
  - ⚠️ 依存: T-03 以降の実装は C-3 承認を前提とする。本 run はオーガナイザーの
    指示に基づく先行実装であり、`c3.json` 未発行のまま PR レビューへ回す
- [ ] **H-02 C-4 ゲート**（PR レビュー / merge）: merge は Human-owned 固定

## ⚠️ 依存関係

- T-03（RED）→ T-04（GREEN）: 先に TC が FAIL することを見てから実装する
- T-08 は T-06 の GREEN を前提（baseline が PASS でないと kill 判定が無効）
- H-01 / H-02 は AI が代行しない（承認境界）
