# EXECUTION PLAN: TASK-0056 / Issue #169 セッション A

> Mode: **critical**（実行 block 伴うが既存パターン踏襲で慎重実装）

## Goal

#169 残 7 hook のうち plan / plan_hash 系の 2 件（EH-1 + EH-3）を実装。`check-c3-approval.sh` の 3 mode 設計を踏襲することでパターン一貫性 + 既存挙動への影響ゼロを担保。

## Approach

### EH-1: plan.md 存在チェック
- `PLANGATE_HOOK_TASK` で対象 TASK を明示（false-positive 防止）
- `docs/working/$TASK/plan.md` 不在で warn / strict 時 block
- `check-c3-approval.sh` の structure を直接踏襲（emit_judgment / log_event ヘルパは個別定義、共通化は v2 候補）

### EH-3: plan_hash 改竄検知
- `approvals/c3.json` の `plan_hash` を grep + sed で抽出
- `sha256sum` / `shasum -a 256` で plan.md の現 hash を計算
- 一致なら PASS、不一致なら warn / strict 時 exit 1
- bypass で常時 exit 0、監査ログに `BYPASS` 記録

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `scripts/hooks/check-plan-exists.sh` | 新規 |
| `scripts/hooks/check-plan-hash.sh` | 新規 |
| `tests/hooks/run-tests.sh` | 編集（fixture 追加 + EH-1 5 件 + EH-3 4 件）|
| `.claude/settings.example.json` | 編集（PreToolUse に 2 hook 追加）|
| `docs/ai/hook-enforcement.md` | 編集（Status v2 → v3、§ 4 表更新）|
| `docs/working/TASK-0056/*` | 新規 |

## Mode判定

**critical**

判定根拠:
- 変更ファイル数: 6 → high-risk
- 受入基準数: 7 → high-risk
- **変更種別: 実行 block を伴うハード強制（critical）**
- リスク: 誤検出 = AI 作業全体停止、ただし既存 EH-2 パターン踏襲 + default warning モードで段階的緩和 → 中
- ロールバック: 容易（PR revert + settings 削除）→ 中
- **最終判定**: critical（影響範囲広 + 慎重実装必要）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| EH-1 が PLANGATE_HOOK_TASK 未設定時に false-positive | 未設定時は SKIP（false-positive guard）、既存 EH-2 と同パターン |
| EH-3 の sha256 計算が遅い（大 plan.md） | sha256sum / shasum で OS native、実用上問題なし |
| EH-3 で c3.json plan_hash が「sha256:...」prefix 必須 | grep + sed パターンで正規化、無 prefix は SKIP 扱い |
| 実 .claude/settings.json への登録で本セッションの作業が止まる | example のみ提供、自己適用しない（既存方針踏襲）|
| set -e + command substitution で test が止まる | tests/extras/README に記録した書法（`&&/||` で exit code 捕捉）を使用 |

## 確認方法

- `sh tests/hooks/run-tests.sh` → **21 件 PASS**
- `sh tests/run-tests.sh` → **24 件 PASS**（loader 経由で hook tests 含む）
- `grep "Status.*v3" docs/ai/hook-enforcement.md` → ヒット
- `.claude/settings.example.json` の PreToolUse に 3 hook 並ぶ
