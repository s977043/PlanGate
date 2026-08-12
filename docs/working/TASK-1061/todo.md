# EXECUTION TODO — TASK-1061（S-2 / S-3 スライス）

> plan: `docs/working/TASK-1061/plan.md` / test-cases: `docs/working/TASK-1061/test-cases.md`
> Mode: `standard`

## 🤖 Agent タスク

### 準備

- [x] T-01 ベースライン `sh tests/run-tests.sh` を実行し既存 FAIL 数を記録する（owner: agent / rollback: 不要 = 読取のみ）
  - 🚩 既存 FAIL > 0 なら **即停止して報告**（SC-3）
- [x] T-02 skill 名 `subagent-delegation-brief` の衝突を 3 集合で再確認する（owner: agent / rollback: 不要）

### 実装（TDD）

- [x] T-03 `tests/extras/ta-63-outcome-contract.sh` を先に作成する（owner: agent / depends_on: T-01 / rollback: `rm tests/extras/ta-63-outcome-contract.sh`）
  - `tests/extras/README.md`「新規ファイル checklist」7 項目に準拠
  - 🚩 実装前に standalone 実行して **FAIL することを確認**（RED）
- [x] T-04 `scripts/check-outcome-contract.sh` を実装する（owner: agent / depends_on: T-03 / rollback: `rm scripts/check-outcome-contract.sh`）
  - 判定は `outcome-contract.md` §6 の項目 3・4・5 のみ。項目 1・2 は実装しない
  - 🚩 T-03 のテストが GREEN になる
- [x] T-05 `.agents/skills/subagent-delegation-brief/SKILL.md` を作成する（owner: agent / depends_on: なし / rollback: `rm -r .agents/skills/subagent-delegation-brief`）
  - 🚩 契約本文（8 要素表 / OUTCOME 定義表）を複製していない
- [x] T-06 `.claude/skills/subagent-delegation-brief/SKILL.md` を T-05 と同一内容で作成する（owner: agent / depends_on: T-05 / rollback: `rm -r .claude/skills/subagent-delegation-brief`）
  - 🚩 `diff` が exit 0

### 検証

- [x] T-07 `sh tests/extras/ta-63-outcome-contract.sh </dev/null`（standalone / rc=0）（owner: agent / rollback: 不要）
- [x] T-08 `sh tests/run-tests.sh`（harness / 既存 FAIL 数から増えていない）（owner: agent / rollback: 不要）
- [x] T-09 `python3 scripts/check-skill-name-collisions.py`（衝突 0）（owner: agent / rollback: 不要）
- [x] T-10 負側 7 ケースを個別に実行し、すべて非ゼロ exit であることを実測する（owner: agent / rollback: 不要）
- [x] T-11 **ドッグフーディング**: 本 PBI の完了報告自身を `check-outcome-contract.sh` に通す（owner: agent / rollback: 不要）

### 完了

- [x] T-12 `status.md` に C-3 判定・実行結果・計画からの変更点を記録する（owner: agent / rollback: 不要）
- [x] T-13 commit + push（`feat/1061-delegation-brief`。**PR は作成しない**）（owner: agent / rollback: `git push --delete origin feat/1061-delegation-brief`）
  - 🚩 push 前に current branch を verify

## 👤 Human タスク

- [ ] H-01 **C-3 相当の事後確認** — 本スライスは `standard` + 受入基準 5 件 + 影響範囲が plan Files 内のため、
      `working-context.md`「C-3 Autonomous APPROVE 判定マトリクス」に従い AI が autonomous APPROVE 済み。
      Human は事後に妥当性を確認する（拒否時は 4 ファイル削除で完全にロールバック可能）
- [ ] H-02 **C-4 PR レビュー** — PR は本タスクで作成していない。PR 作成後に実施

## ⚠️ 依存関係

- T-03 → T-04（RED → GREEN の順序を崩さない）
- T-05 → T-06（正本 → ミラーの順序。逆にすると正本側が派生になる）
- T-04 / T-06 → T-07〜T-11
- H-01 は T-13 の後（事後確認）
