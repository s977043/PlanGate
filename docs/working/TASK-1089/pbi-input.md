# TASK-1089 / #1089: EH-3 Hardening Override が TASK 文脈で発火しない

## Context / Why

`PLANGATE_HOOK_TASK` が設定されていると、EH-3（`scripts/hooks/check-plan-hash.sh`）の
Hardening Override（HO）block が **9 カテゴリすべてで発火しない**。HO は
「c3 + plan_hash 承認があっても AI 編集不可・常時 block」が正本の宣言だが、
実際に常時 block されるのは `PLANGATE_HOOK_TASK` 未設定時のみ。

`PLANGATE_HOOK_TASK` は `plan.md` 編集の正規経路であり、**PlanGate 作業中の
セッションこそ HO 保護がゼロ**になる。`check-forbidden-files.sh` は HO パスを
守らないため、**EH-3 が唯一の HO ガード**である。

## 原因（実測で確認）

| # | 事実 | 根拠 |
|---|------|------|
| 1 | HO 判定（`_override` case 文）が `if [ -z "$task_id" ]` の内側にある | `grep -n` で HO 判定 L123 > task 分岐 L83 |
| 2 | TASK 設定時は plan_hash 検証パスへ抜け、HO 判定を一度も通らない | 実測 9/9 で `rc=2 → rc=0` |
| 3 | plan_hash 検証パスは plan.md 不在 / c3.json 不在 / plan_hash 未記録のいずれでも `exit 0` | `evidence/nonreg-before-unpatched.txt` T1–T3 |

### 現行構造の由来（`git log` 確認 / SC-1 判定 = 非該当）

HO 判定は `baaa9a5`（TASK-0106 / #289「EH-3 in-session skip 改善」）で導入された。
`docs/working/TASK-0106/plan.md` の記述は
「**判定順序は maintenance 判定より前**（R-020）」「Hardening Override を
デフォルト ON」「maintenance 窓内でも常時 block（R-003）」であり、
**順序の議論は maintenance 判定との相対位置に閉じている**。
TASK 文脈で HO を無効化する意図は plan / commit message のどこにも存在しない。

→ **現行構造は意図的ではなく、TASK-0106 の設計スコープ（no-task の
maintenance 経路）から漏れた未考慮領域**。issue #1089 の前提は成立する。

## What

### In scope

- HO 判定を `task_id` 分岐より **前** で評価する patch（**適用は Human-owned**）
- TASK 設定時にも HO が発火することの回帰テスト（`tests/extras/`・非 HO）
- 非 HO 正本（`docs/ai/hook-enforcement.md`）への既知制限の明記

### Out of scope

- HO 9 カテゴリの内容変更（追加・削除）
- `PLANGATE_HOOK_TASK` の運用変更
- `.claude/settings*.json` の変更（Human-owned）
- `.claude/rules/mode-classification.md` の変更（HO パス）

## 成果物

| 種別 | パス | 責務 |
|------|------|------|
| patch | `docs/working/TASK-1089/patches/check-plan-hash.ho-always.patch` | AI 作成 / **Human 適用** |
| 回帰テスト | `tests/extras/ta-65-eh3-ho-task-context.sh` | AI-owned（非 HO） |
| 正本追補 | `docs/ai/hook-enforcement.md` EH-3 節 | AI-owned（非 HO） |
| 実測証跡 | `docs/working/TASK-1089/evidence/` | AI-owned |

## 受入基準 と 実測結果

| AC | 内容 | 結果 | 証跡 |
|----|------|------|------|
| AC-1 | TASK 設定時に HO 9 カテゴリすべてが block | ✅ patch 適用後 9/9 rc=2 | `evidence/ho-matrix-patched.txt` |
| AC-2 | 判定 call site を壊すと同じテストが FAIL | ✅ 変異 4 種すべて rc=1 で kill | `evidence/mutation-results.txt` |
| AC-3 | TASK 未設定時の block（rc=2）が不変 | ✅ 9/9 rc=2 維持 | `evidence/ho-matrix-*.txt` |
| AC-4 | 非 HO パスの plan_hash 検証が現行と同判定 | ✅ 19 ケース中、差分は意図した HO 1 行のみ | `evidence/nonreg-*.txt` |
| AC-5 | 追加テストが CI 実行ログに現れる | 🔸 PR 作成後に要確認（本 worktree では PR 未作成） | — |
| AC-6 | `sh tests/run-tests.sh` が rc=0 | ✅ | `evidence/run-tests.txt` |
| AC-7 | 「常時 block」記述と実装条件の整合（不能なら制限として明記） | ✅ 制限として `docs/ai/hook-enforcement.md` に明記 | 同ファイル EH-3 節 |

## patch 適用手順（Human-owned）

```sh
# 1. 差分確認
git apply --stat docs/working/TASK-1089/patches/check-plan-hash.ho-always.patch
git apply --check docs/working/TASK-1089/patches/check-plan-hash.ho-always.patch

# 2. 適用
git apply docs/working/TASK-1089/patches/check-plan-hash.ho-always.patch
#    （patch -p1 < ... でも可。実適用検証済み）

# 3. 適用後の検証（fixed 期待に切り替わることを確認）
sh tests/extras/ta-65-eh3-ho-task-context.sh </dev/null
sh tests/run-tests.sh
```

適用後は CI に `PG_T65_EXPECT=fixed` を設定すると、HO 判定が再び
task 分岐の内側へ戻る退行を FAIL として検出できる。

## Notes / 既知の制限

- `.claude/settings*.json` は Claude Code の self-mod ガード（harness 層）でも
  守られるため EH-3 が抜けても編集不可。**残る 8 カテゴリに同等の別ガードは
  未確認**（`check-forbidden-files.sh` は HO を守らないことを実測済み）。
- 本リポジトリの HO 変更標準フロー（`docs/ai/ho-change-workflow.md`）は
  patch ではなく **冪等な apply スクリプト**（`scripts/apply-*.sh`、非 HO）を
  推奨している。本 PBI は担当スコープの制約により patch 形式で提出した。
  apply スクリプト化は follow-up 候補（P1）。
