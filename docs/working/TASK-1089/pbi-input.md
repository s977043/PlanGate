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
| **apply スクリプト**（正規の適用手段） | `scripts/apply-eh3-ho-always.sh` | AI 作成・`--dry-run` のみ実行 / **`--apply` は Human** |
| 参考 patch（人間が読むための差分） | `docs/working/TASK-1089/patches/check-plan-hash.ho-always.patch` | AI 作成 / 単独適用は非推奨 |
| 回帰テスト | `tests/extras/ta-65-eh3-ho-task-context.sh` | AI-owned（非 HO） |
| KNOWN-GAP 宣言 | `tests/fixtures/eh3-known-gap-1089.flag` | AI 作成 / **apply が削除** |
| 正本追補 | `docs/ai/hook-enforcement.md` / `docs/ai/ho-change-workflow.md` / `plugin/plangate/rules/mode-classification.md` | AI-owned（非 HO） |
| 実測証跡 | `docs/working/TASK-1089/evidence/`（全スクリプトが `<repo_root>` 引数で再現可能） | AI-owned |

## 受入基準 と 実測結果

| AC | 内容 | 結果 | 証跡 |
|----|------|------|------|
| AC-1 | TASK 設定時に HO 9 カテゴリすべてが block | ✅ patch 適用後 9/9 rc=2 | `evidence/ho-matrix-patched.txt` |
| AC-2 | 判定 call site を壊すと同じテストが FAIL | ✅ 変異 **6 種すべて rc=1 で kill**（#1089 の再発 M4 を含む） | `evidence/mutation-results.txt` |
| AC-3 | TASK 未設定時の block（rc=2）が不変 | ✅ 9/9 rc=2 維持 | `evidence/ho-matrix-*.txt` |
| AC-4 | 非 HO パスの plan_hash 検証が現行と同判定 | ✅ 19 ケース中、差分は意図した HO 1 行のみ | `evidence/nonreg-*.txt` |
| AC-5 | 追加テストが CI 実行ログに現れる | 🔸 PR 作成後に要確認（本 worktree では PR 未作成） | — |
| AC-6 | `sh tests/run-tests.sh` が rc=0 | ✅ 未適用 / 適用済の**両方**で rc=0 | `evidence/run-tests-unpatched.txt` / `evidence/run-tests-patched.txt` |
| AC-7 | 「常時 block」記述と実装条件の整合（不能なら制限として明記） | ✅ 制限を `docs/ai/hook-enforcement.md` に明記 + 正本の行番号アンカーを記号アンカー化 + 正規化の穴を TC-07 で固定 | 同ファイル EH-3 節 / `evidence/anchor-resolution-results.txt` |

## 適用手順（Human-owned）

```sh
# 1. 差分確認（既定が dry-run。書き込みは一切しない）
sh scripts/apply-eh3-ho-always.sh --dry-run

# 2. 適用（Human-owned）— 次の 3 つを 1 オペレーションで行う
#    (1) scripts/hooks/check-plan-hash.sh の HO 判定を task_id 分岐の前へ移動
#    (2) .claude/rules/mode-classification.md の行番号アンカー L124-134 を記号アンカー化
#    (3) tests/fixtures/eh3-known-gap-1089.flag（KNOWN-GAP 宣言）を削除
sh scripts/apply-eh3-ho-always.sh --apply

# 3. 適用後の検証（mode=fixed に切り替わることを確認）
sh tests/extras/ta-65-eh3-ho-task-context.sh </dev/null
sh tests/run-tests.sh
```

- **冪等**（2 回目以降は `already applied` で no-op）/ **アンカー検証**（base から
  drift していたら exit 1・部分適用なし）/ **引数 strict 検証**（未知引数は exit 1）
- **`patch -p1` は使わない**。fuzz とオフセット探索により、承認境界の判定ブロックが
  意図しない位置へ無言で挿入されうる。参考 patch を単独で使う場合は
  `git apply --check` を必須とする（patch 冒頭に base commit と適用前 sha256 を記録）
- **CI 側の env 設定は不要**。`ta-65` の既定期待値は「TASK 文脈でも block」であり、
  gap の受理は flag の存在という明示 opt-in にのみ依存する。したがって適用後に
  実装が元の構造へ戻れば CI が RED になる（#1089 の再発検知）

## 挙動差分の正確な内訳（PR 本文用）

| 種別 | 件数 | 内容 |
|------|------|------|
| **rc の変化** | **1** | HO パス × TASK 文脈: rc=0 → **rc=2**（本 PBI の目的） |
| **理由文字列・監査ログ分類の変化** | **2** | (a) no-task + HO + `STRICT=1`: `Usage:`（**監査ログなし**）→ `HARDENING_OVERRIDE`（**ログ 1 行追加**） (b) `.claude/rules/plan.md`: `VIOLATION: plan.md edited without TASK context` → `HARDENING_OVERRIDE`。**いずれも rc は 2 のまま**で、より具体的な理由に変わる安全側 |

`docs/working/_audit/hook-events.log` を `VIOLATION` 分類で集計している分析が
あれば (b) の影響を受ける（`HARDENING_OVERRIDE` へ移る）。

## Notes / 既知の制限

- `.claude/settings*.json` は Claude Code の self-mod ガード（harness 層）でも
  守られるため EH-3 が抜けても編集不可。**残る 8 カテゴリに同等の別ガードは
  未確認**（`check-forbidden-files.sh` は HO を守らないことを実測済み）。
- **適用後も「常時 block」は文字どおりには成立しない**: `docs/../CLAUDE.md`（`..` 未解決）/
  `CLAUDE.MD`（大小文字）/ `"CLAUDE.md "`（末尾空白）は通過する。**未適用 main の
  no-task 経路でも同じ挙動**であり本 PBI が作った穴ではない。`ta-65` TC-07 が
  KNOWN-GAP として固定しており、塞いだ時点で RED になる。**別 PBI 候補**。
- **行番号アンカー**: `L124-134` を引いて HO 該当性を判定していた 3 ファイルのうち、
  非 HO 2 ファイルは本 PR で記号アンカーへ置換済み。HO 側
  （`.claude/rules/mode-classification.md`）は apply スクリプトが同時に置換する
  （patch 適用と同一オペレーション）。過去 PBI の docs 内の同記述は
  **当時の記録**であり変更しない。
