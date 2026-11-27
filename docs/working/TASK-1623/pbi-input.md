# PBI INPUT PACKAGE: ai-loop v2 limits.py の byte 系 3 定数と I-11 byte 検査（#1623）

> 作成: 2026-11-26（AI）。provenance: GitHub issue s977043/PlanGate#1623 本文（2026-11-03 追記 2 件を含む）、TASK-1393 plan Rev2.10、TASK-1392 plan、TASK-1391 スライス A（`6756a597`）、critical path レポート「2026-11-25 更新」、別セッションの下書き（exec-1391 worktree の `docs/working/TASK-1623/plan.md`、未コミット・読み取りのみ）。承認ではない。

## Context / Why

TASK-1393 plan Rev2.9（R-091）で、`scripts/ai-loop-v2/limits.py` の byte 系 3 定数（`MAX_DECISION_EVENT_BYTES` / `DECISION_FIXED_OVERHEAD` / `ENVELOPE_OVERHEAD`）と I-11 の byte 検査が本 follow-up に移った。V2 `decision_made` の最悪ケース event 構造が repo に無く、「計算前に数値を書かない」（TASK-1393 plan.md:343）を守れないため。#1392 の terminal reserve（TASK-1392 plan.md:293）と #1391 P1B-7 の append 再検査がこの値を参照する。

### Bounded Discovery

- Existing Work Check: PR #1635（`docs/working/TASK-1393/evidence/byte-bound-review-2026-11-03.md`）が escape の反例（71 文字 ASCII ID 16 件で 6,845 byte）を記録済み。byte 定数の値は未確定。
- 2026-11-26 Human 決定 H-10: append 時の byte 再検査は #1391 後半で実装し、#1623 を先にマージする。

## What（Scope）

### In scope

- `limits.py` に byte 系 3 定数を追加（最悪ケース event を組み立て、`canonical_bytes` で測り、切り上げて fixture 固定）
- I-11 の byte 部分の検査（旧 DI-45 / DC-13 相当）
- #1392 の terminal reserve がこの値を参照できることの契約 fixture
- `test_no_byte_constants` を最大 event・境界・reserve 接続の検査へ置き換え（削除だけで green にしない）

### Out of scope

- #1391 の append 再検査本体（H-10 により #1391 後半）
- #1392 の reserve 実装本体（#1392 exec）
- #1393 core（PF-1〜PF-8）全体
- 許可文字種を無言で狭めること

## 受入基準

（issue 本文のまま。変更しない）

- AC-1: 最悪ケース event の組み立てと byte 計算が fixture テストで再現できる
- AC-2: I-11 が上限超過の入力を `DecisionInputError` にする

派生（plan で検証項目に分解。AC の追加ではない）: AC-1a 3 定数の導出根拠が残る / AC-1b escape・最大桁・任意 field を含む / AC-2a 上限ちょうどは受理 / AC-3（Scope 由来）#1392 reserve が同じ定数を参照できる。

## Notes from Refinement

- I-11 は TASK-1393 plan.md:180 で `make_decision_input` 内の検査と定義され、`DecisionInputError` も #1393 core が導入する（plan.md:57 / :149）。main には未実装（plan.md 参照「前提の実測検証」）。
- H-10 と下書きの結論「先行マージ不可」が衝突する。順序は Human が決める（plan.md「Questions / Unknowns」）。

## Estimation Evidence

### Risks

- 構造未確定のまま定数を固定すると、#1391 マージ時に drift し #1392 の「terminal は必ず書ける」保証が偽になる
- escape を数えず `n × 74` を流用すると過小評価（#1635）

### Unknowns

- U-1 マージ順（H-10 と AC-2 の両立）
- U-2 `run_id` 文法・revision 桁・`MAX_EVENTS_PER_RUN`（暫定 2048）の確定主体
- U-3 `stop_reasons` の重複可否と最大組、`verdicts` の件数・キー長を保証する経路

### Assumptions

- serializer は `run_event.canonical_bytes`（sort_keys / separators / ensure_ascii=False）で確定済み
- slice A（`6756a597`）の `DECISION_REQUIRED_KEYS` / `DECISION_OPTIONAL_KEYS` が #1391 PR まで変わらない（変われば Replan）
