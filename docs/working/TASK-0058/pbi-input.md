# PBI INPUT PACKAGE: TASK-0058 / Issue #169 セッション C

> Source: [#169 残 Hook 実装](https://github.com/s977043/plangate/issues/169)
> Mode: **critical**（実行 block を伴うが既存 8 hook の 3 mode 設計を踏襲）

## Context / Why

#169 EPIC のセッション C として **EH-7 + EHS-1** の 2 hook を実装。セッション A/B と同じ 3 mode 設計を踏襲、8/10 → **10/10 hooks** に到達して #169 を完走させる。残課題（GitHub branch protection 自動連携）は本 PBI scope 外、別 PBI 候補として明示。

## What

### In scope
- `scripts/hooks/check-merge-approvals.sh`（EH-7、CLI）: マージ前に c3.json + c4-approval.json の両 APPROVED を確認
- `scripts/hooks/check-v3-review.sh`（EHS-1、CLI、mode 連携）: standard 以上 mode で V-3 review 不在を warn / block、light/ultra-light は skip
- `tests/hooks/run-tests.sh` に EH-7 + EHS-1 = 9 件追加（33 → 42 件 PASS）
- fixture: `both-approvals/`, `v3-review-exists/` 等
- `docs/ai/hook-enforcement.md` Status v4 → **v5（10/10 hooks Done）**

### Out of scope（別 PBI 候補）
- GitHub branch protection / ruleset の自動操作（EH-7 の上位拡張）
- C-2 vs V-3 の review-external.md 共通利用問題（本 PBI ではどちらでも検出）

## Acceptance Criteria

- AC-1: EH-7 が両 APPROVED で PASS、片方でも欠損で warn / strict 時 exit 1 / bypass で exit 0
- AC-2: EHS-1 が standard / high-risk / critical で必須化、light / ultra-light で skip
- AC-3: hook 単体テストが **42 件 PASS**（33 → 42、+9）
- AC-4: tests/run-tests.sh が **24 件 PASS** 維持
- AC-5: hook-enforcement.md Status v4 → v5、10/10 hooks Done を明記
- AC-6: **PR 本文に `closes #169`** を含めて #169 auto-close
- AC-7: 既存 8 hook の挙動無変更
