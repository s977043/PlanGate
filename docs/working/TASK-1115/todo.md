# EXECUTION TODO — TASK-1115 (#1115)

## 🤖 Agent タスク

### 準備

- [x] **T-01** `origin/main`（`17cd044`）から `fix/1115-eh13-glob-bypass` を作成し、
  `git diff main --stat` で混入がないことを確認
  - rollback: `git branch -D fix/1115-eh13-glob-bypass`
- [x] **T-02** 是正前実測を採取（PreToolUse payload を stdin 供給 = 本番経路）。
  #1115 の 6 ケース + 他レーン + 誤検出負側 + shell 展開の中立名実測
  - Output: `evidence/before.txt` / `evidence/shell-expansion.txt`
  - rollback: 不要（読取のみ）
  - 🚩 **チェックポイント**: bypass の規則性が「ファイル名リテラルの崩し」で
    説明できることを確認

### 実装（TDD）

- [x] **T-03** RED: `ta-25` に T1115-TC-01〜07 を追加し、**失敗すること**を確認
  - rollback: `git checkout origin/main -- tests/extras/ta-25-approval-token-guard.sh`
- [x] **T-04** GREEN: `_may_expand_to_token_path` / `_cmd_may_target_token` を
  `scripts/check-approval-token-write.sh` に実装し、外側ゲート call site を
  差し替える（アンカー `# t1115-*` を付与）
  - rollback: `git checkout origin/main -- scripts/check-approval-token-write.sh`
  - 🚩 **チェックポイント**: 既存 T1023 / T1045 / T1110 TC が全件 PASS のまま

### 検証

- [x] **T-05** 変異 M-7〜M-11 を追加（レーン全体 1 + レーン内部 4）
  - rollback: `git checkout origin/main -- tests/extras/ta-25-approval-token-guard.sh`
  - 🚩 **チェックポイント**: 空振り変異があれば正直に記録する
- [x] **T-06** `sh tests/extras/ta-25-approval-token-guard.sh` を**個別実行**して
  rc=0 を確認（フルスイート `tests/run-tests.sh` は実行しない = ta-61 入れ子回避）
- [x] **T-07** 是正後実測表を採取し、before/after を突合
  - Output: `evidence/after.txt`
  - 🚩 **チェックポイント**: (a) #1115 6 ケースの是正、(b) 真の陽性を落として
    いない、(c) **#1110 が解消した誤検出が戻っていない**、の 3 点を明示

### 完了

- [x] **T-08** `review-self.md`（C-1）を作成
- [x] **T-09** commit + push（承認トークンのパス literal をメッセージに書かない）
  - rollback: `git push origin --delete fix/1115-eh13-glob-bypass`

## 👤 Human タスク

- [ ] **H-01** C-3 ゲート（**人間必須** / `high-risk` のため autonomous APPROVE 不可）
  - 依存: T-01〜T-08 完了
  - 本ワーカーは `approvals/c3.json` を**発行しない**
- [ ] **H-02** C-4 ゲート（PR レビュー / merge）

## ⚠️ 依存関係

- T-03（RED）→ T-04（GREEN）→ T-05（変異）→ T-06 → T-07
- H-01 は T-09 完了後。**exec は C-3 前に完了しているが、これはワーカー委託
  スコープ（Plan Package + 実装 + TC）の指示によるもの**であり、merge は
  H-02（Human-owned）に固定される。
