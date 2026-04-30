# PBI INPUT PACKAGE: TASK-0045 / Issue #159

> Source: [#159 PR close キーワード自動検証 CI（T-6 / 子 PBI auto-close 漏れ防止）](https://github.com/s977043/plangate/issues/159)
> Mode: **light**

## Context / Why

PBI-116 EPIC で **5 件の子 issue（#117 / #118 / #119 / #120 / #122）が PR 経由で auto-close されず手動 close を要した**。原因は exec PR の本文に `closes #N` キーワードを含めていなかったこと（retrospective F-4）。PR テンプレに手作業の歯止めは入れたが、機械検証 CI が未実装。次の親 PBI EPIC で同じ漏れを防ぐために CI 統合する。

## What

### In scope

- `.github/workflows/check-pr-issue-link.yml` を新設し PR 本文を機械検証
- 検証ロジックは `scripts/check-pr-issue-link.sh`（POSIX sh）に分離してテスト可能化
- `tests/fixtures/check-pr-issue-link/` に pass / warn / skip 各 1 件以上の fixture
- PR テンプレ `.github/PULL_REQUEST_TEMPLATE.md` の Linked Issue セクションと整合
- `docs/schemas/child-pbi.yaml` に optional `related_issue:` フィールドを追記（前方互換）

### Out of scope

- 既存 PR の遡及検証
- close 後の re-open 自動化
- 強制 block（warning のみ）

## Acceptance Criteria

- AC-1: `.github/workflows/check-pr-issue-link.yml` が PR で trigger される
- AC-2: closing keyword なし PR で warning（comment / label）が出る
- AC-3: 子 PBI YAML 編集を含む PR で期待 issue（YAML の `related_issue:`）↔ closing keyword 整合チェックが動く
- AC-4: `chore` / `documentation` label 付き PR は skip される
- AC-5: 既存 PR テンプレ（`.github/PULL_REQUEST_TEMPLATE.md`）の Linked Issue セクションと整合
- AC-6: テスト fixture（pass / warn / skip 各 1 件以上）が存在し `tests/run-tests.sh` で検証される

## Notes

- 推奨 mode: **light**（1 ワークフロー追加 + 軽量 fixture、既存挙動への影響なし）
- skip marker: PR 本文に `<!-- skip-issue-link-check -->` を含めれば skip
- 子 PBI YAML への `related_issue:` 遡及追加は本 PBI の必須範囲外（schema 拡張のみ）
