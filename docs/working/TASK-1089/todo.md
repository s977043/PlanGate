# EXECUTION TODO — TASK-1089 (#1089)

> Owner 記号: 🤖 = AI-owned / 👤 = Human-owned
> `rollback:` は全タスクに記載（mode=high-risk のため必須）

## 🤖 準備

- [x] **T-01** 9 カテゴリ × TASK 有無の迂回を再現する（owner=agent / Risk=low）
  - 🚩 9/9 で rc=2→rc=0 を確認できなければ issue の前提を再検討
  - rollback: 不要（読取のみ）
- [x] **T-02** 現行構造が意図的かを `git log` / TASK-0106 plan で確認（owner=agent / Risk=low）
  - 🚩 **意図的だった場合は即停止して報告**（SC-1）
  - rollback: 不要（読取のみ）

## 🤖 実装

- [x] **T-03** hook 変換の設計と参考 patch 生成（owner=agent / Risk=high / depends_on=T-02）
  - 🚩 `git apply --check` が通ること / 差分が「移動のみ」であること
  - rollback: `docs/working/TASK-1089/patches/` を削除（HO 実体は未変更）
- [x] **T-04** apply スクリプト作成（owner=agent / Risk=high / depends_on=T-03）
  - 🚩 冪等 / `--dry-run` 既定 / 引数 strict / アンカー検証 の 4 性質を実測
  - rollback: `git rm scripts/apply-eh3-ho-always.sh`（未実行なら実体影響なし）
- [x] **T-05** KNOWN-GAP flag 作成（owner=agent / Risk=low / depends_on=T-04）
  - rollback: `git rm tests/fixtures/eh3-known-gap-1089.flag`
- [x] **T-06** 回帰テスト `ta-65` 作成（owner=agent / Risk=medium / depends_on=T-05）
  - 🚩 未適用で green / 適用後も green / 再発で RED を実測
  - rollback: `git rm tests/extras/ta-65-eh3-ho-task-context.sh`
- [x] **T-07** 正本の記号アンカー化（非 HO 2 ファイル）（owner=agent / Risk=medium）
  - 🚩 適用前後で同じ 9 カテゴリブロックへ解決すること
  - rollback: `git checkout -- docs/ai/ho-change-workflow.md plugin/plangate/rules/mode-classification.md`
- [x] **T-08** `docs/ai/hook-enforcement.md` に既知制限 + 退役条件（owner=agent / Risk=low）
  - rollback: `git checkout -- docs/ai/hook-enforcement.md`

## 🤖 検証

- [x] **T-09** 非回帰マトリクス（plan_hash 全経路 / no-task / maintenance / BYPASS / 順序エッジ）（owner=agent / Risk=high / depends_on=T-03）
  - 🚩 **意図した 1 行以外の rc 差があれば停止**（SC-2/SC-3）
  - rollback: 不要（読取のみ）
- [x] **T-10** 変異注入 6 種で kill を実証（owner=agent / Risk=medium / depends_on=T-06）
  - 🚩 **#1089 の再発（M4）が kill されること**が本 PBI の要
  - rollback: 不要（読取のみ）
- [x] **T-11** `sh tests/run-tests.sh` を**未適用**ツリーで実行（owner=agent / Risk=low）
  - rollback: 不要（読取のみ）
- [x] **T-12** `sh tests/run-tests.sh` を**適用済み**サンドボックスで実行（owner=agent / Risk=low / depends_on=T-04）
  - 🚩 適用後にスイート全体が壊れないこと
  - rollback: 不要（サンドボックス。実リポジトリ不変）

## 🤖 完了

- [x] **T-13** plan / todo / test-cases / review-self を発行（owner=agent / Risk=low）
  - rollback: `git rm docs/working/TASK-1089/{plan,todo,test-cases,review-self}.md`
- [ ] **T-14** handoff.md 発行（owner=agent / Risk=low / depends_on=C-4）
  - rollback: `git rm docs/working/TASK-1089/handoff.md`

## 👤 Human タスク（依存関係あり）

- [ ] **H-1 (C-3)**: 本 plan と patch の承認（**Standard・同期。autonomous APPROVE 不可**）
  - depends_on: T-13
- [ ] **H-2 (C-4)**: PR レビュー（PR 作成は本ワーカーの scope 外）
- [ ] **H-3 (HO 適用)**: `sh scripts/apply-eh3-ho-always.sh --dry-run` → `--apply`
  - depends_on: H-2（マージ後）
  - 🚩 適用後に `sh tests/extras/ta-65-eh3-ho-task-context.sh </dev/null` が
    `mode=fixed` で PASS すること / `sh tests/run-tests.sh` が rc=0
  - rollback: `git checkout -- scripts/hooks/check-plan-hash.sh .claude/rules/mode-classification.md tests/fixtures/eh3-known-gap-1089.flag`

## ⚠️ 依存関係

- T-04 → T-05 → T-06（flag の存在を前提に期待値ロジックが決まる）
- T-06 → T-10（テストがないと変異で kill できない）
- T-13 → H-1（plan なしに C-3 は成立しない）
- H-2 → H-3（**マージ前に HO を適用しない**。PR には HO 実体を含めない）
