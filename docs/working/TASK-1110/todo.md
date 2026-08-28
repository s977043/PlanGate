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

### V-3 反映（2 巡目 / `review-external.md` REJECT を受けて）

- [x] **T-11** `review-external.md` / `evidence/v3-review/` を取り込み、R-001 を
  自前の harness で独立再現（OLD/NEW 比較で真の陽性喪失を確認）
  - depends_on: なし / Owner: agent / rollback: 不要（読取・検証のみ）
- [x] **T-12**（R-001 / critical）`_redirect_writes_token()` の fail-closed に
  **切り詰めクラス**を追加 + 終端文字集合から `#` を除去
  - depends_on: T-11 / Owner: agent
  - 🚩 23 ケースが rc=2 へ復帰 / **ケース A〜E と境界 13 が退行しない**こと
  - rollback: `git checkout -- scripts/check-approval-token-write.sh`
- [x] **T-13** `T1110-TC-06`〜`TC-10` を追加（切り詰め / 語中 `#` / レーン一致 /
  改行畳み込み / 診断値持ち越し）+ 引用が先の後ろに来る負の対照
  - depends_on: T-12 / Owner: agent / 🚩 `f922442` に当てると RED になること
  - rollback: `git checkout -- tests/extras/ta-25-approval-token-guard.sh`
- [x] **T-14**（R-002 / R-005）**レーン内部の分類を壊す変異** `M-3`〜`M-6` を追加
  - depends_on: T-13 / Owner: agent / 🚩 4 種すべてが実 TC の FAIL で kill されること
  - rollback: T-13 と同じ
- [x] **T-15**（R-003）反転 2 件を pbi-input / plan / test-cases へ明示宣言し、
  TASK-1023 AC-04 上書きを Human C-3 の判断事項として起票
  - depends_on: なし / Owner: agent
  - ⚠️ **TASK-1023 側の資料は書き換えない**（C-3 承認後の follow-up）
  - rollback: `git checkout -- docs/working/TASK-1110/`
- [x] **T-16**（R-002 / R-004）evidence の全称主張をスコープ付きへ是正 /
  `T1045-TC-19` に SC-6 との関係を追記
  - depends_on: T-14 / Owner: agent / rollback: T-15 と同じ
- [x] **T-17** 簡易 C-1 再実行 → `review-self-2.md`
  - depends_on: T-12〜T-16 / Owner: agent / rollback: 不要

## 👤 Human タスク

- [ ] **H-01 C-3 ゲート**（exec 前ゲート）: mode = high-risk のため **人間 C-3 必須**。
  本ワーカーは `c3.json` を**発行しない**
  - **判断事項**: `T1023-TC-09` の反転 = **TASK-1023 AC-04 を redirect レーンに限り
    上書き**してよいか（不承認なら反転を撤回し、redirect レーンでも「トークン読取 +
    別ファイル書込」を block する分岐を戻す。その場合ケース A 相当の誤検出が一部復活する）
- [ ] **H-03 handoff 発行の順序**: C-3 承認 → V-1 完了の後に `handoff.md` を発行する
  （V-3 R-006。未承認のまま完了資産を出さない）
  - ⚠️ 依存: T-03 以降の実装は C-3 承認を前提とする。本 run はオーガナイザーの
    指示に基づく先行実装であり、`c3.json` 未発行のまま PR レビューへ回す
- [ ] **H-02 C-4 ゲート**（PR レビュー / merge）: merge は Human-owned 固定

## ⚠️ 依存関係

- T-03（RED）→ T-04（GREEN）: 先に TC が FAIL することを見てから実装する
- T-08 は T-06 の GREEN を前提（baseline が PASS でないと kill 判定が無効）
- H-01 / H-02 は AI が代行しない（承認境界）
