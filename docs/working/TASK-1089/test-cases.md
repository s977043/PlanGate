# テストケース定義 — TASK-1089 (#1089)

## 受入基準 → テストケース マッピング

| AC | 内容 | 対応 TC | 自動化 |
|----|------|--------|--------|
| AC-1 | TASK 設定時に HO 9 カテゴリすべてが block | `ta-65` TC-01 / TC-01b / TC-02、`evidence/ho-matrix-patched.txt` | ✅ |
| AC-2 | 判定 call site を壊すと FAIL（空振りでない） | `evidence/mutation-mutate.sh` M1〜M6 | ✅ |
| AC-3 | TASK 未設定時の block（rc=2）が不変 | `ta-65` TC-03、非回帰マトリクス N1-N7 | ✅ |
| AC-4 | 非 HO パスの plan_hash 検証が現行と同判定 | `ta-65` TC-04、`evidence/nonreg-*.txt` T1-T9 | ✅ |
| AC-5 | 追加テストが CI ログに現れる | GitHub Actions（PR 作成後・**本ワーカー scope 外**） | 👤 |
| AC-6 | `sh tests/run-tests.sh` rc=0（未適用 / 適用後の両方） | `evidence/run-tests-unpatched.txt` / `run-tests-patched.txt` | ✅ |
| AC-7 | 「常時 block」記述と実装条件の整合（不能なら制限として明記） | `ta-65` TC-01b（正本由来パス）/ TC-07（正規化 KNOWN-GAP）/ `hook-enforcement.md` | ✅ |

## テストケース一覧

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| TC-00 | — | hook の `_override=0` 直後 case 文 | 1 件以上のカテゴリを導出（件数は固定しない） | Unit |
| TC-00b | flag あり + 実装 fixed | — | **FAIL**（stale KNOWN-GAP 宣言） | Unit |
| TC-01 | mode=fixed | HO 全カテゴリ × `PLANGATE_HOOK_TASK` あり | 全件 rc=2 + `HARDENING_OVERRIDE` | Unit |
| TC-01 | mode=gap（flag あり） | 同上 | 全件 rc=0（KNOWN-GAP を明示出力） | Unit |
| TC-01b | 任意 | **正本 `mode-classification.md` 由来**のパス | mode に応じて全件一致（実装と正本の乖離を検出） | Unit |
| TC-02 | 任意 | stdin JSON `{"tool_input":{"file_path":"CLAUDE.md"}}` + TASK | mode に応じた rc | Unit |
| TC-03 | 任意 | HO 全カテゴリ × TASK 未設定 | 全件 rc=2 + `HARDENING_OVERRIDE`（両 mode 共通） | Unit |
| TC-04 | 任意 | 非 HO パス × TASK あり × 6 状態 | plan.md 不在/c3.json 不在/plan_hash 未記録 → rc=0 SKIP、一致 → rc=0 PASS、mismatch → rc=0 WARNING、mismatch+STRICT → **rc=1 BLOCK** | Unit |
| TC-05 | 任意 | `PLANGATE_BYPASS_HOOK=1` + HO + TASK | rc=0 `BYPASS`（優先順不変） | Unit |
| TC-06 | 任意 | HO 近傍の非 HO 10 件（`.claude/skills/` `scripts/_*.py` `docs/AGENTS.md` 等）× 両文脈 | `HARDENING_OVERRIDE` を出さない / TASK 文脈で rc≠2 | Unit（否定表明） |
| TC-07 | 任意 | `docs/../CLAUDE.md` / `CLAUDE.MD` / `"CLAUDE.md "` / `bin/../bin/plangate` | block されない（KNOWN-GAP を固定。塞いだら RED） | Unit（既知ギャップ固定） |

## 変異注入（AC-2 / 空振り検査でないことの証明）

| ID | 変異内容 | 期待 |
|----|---------|------|
| M1 | 適用後に `if [ "$_override" = "1" ]` → `"9"`（判定 call site 破壊） | ta-65 rc=1 |
| M2 | 適用後に HO カテゴリを 1 件削除（`bin/plangate`） | ta-65 rc=1（TC-01b が正本と乖離を検出） |
| M3 | 適用後に HO カテゴリを改名（`.claude/rules/*.md` → `NOPE.md`） | ta-65 rc=1 |
| **M4** | **適用後に hook を元構造へ revert（#1089 の再発）** | **ta-65 rc=1** |
| M5 | patch のみ手動適用し flag を残す（stale 宣言） | ta-65 rc=1 |
| M6 | 未適用のまま `PG_T65_EXPECT=fixed` で pin | ta-65 rc=1 |
| 対照 | 未適用（flag あり） / 適用済（flag なし） | いずれも rc=0 |

## apply スクリプト（`docs/ai/ho-change-workflow.md` 要件）

| ID | 入力 | 期待 |
|----|------|------|
| A1 | `--bogus` / `--dry-run --apply` | exit 1（引数 strict 検証） |
| A2 | 引数なし / `--dry-run` | exit 0 + **3 ファイルすべて未変更**（既定 dry-run） |
| A3 | base から drift した hook + `--apply` | exit 1 + **部分適用なし**（アンカー検証） |
| A4 | `--apply` 2 回 / 適用後 `--dry-run` | exit 0 + `already applied`（冪等） |

## エッジケース

| ケース | 期待 |
|-------|------|
| no-task + HO + `PLANGATE_HOOK_STRICT=1` | rc=2（理由文字列は `Usage:` → `HARDENING_OVERRIDE` に変化・**監査ログが増える方向**） |
| `.claude/rules/plan.md`（HO かつ plan.md 名） | rc=2（理由が plan.md BLOCK → HARDENING_OVERRIDE に変化） |
| target 空 + TASK あり / なし | 現行と同一（rc=0 SKIP / rc=2 SKIP 拒否） |
| `./` 前置 / 絶対パス / サブディレクトリ | 正規化されて HO 判定に乗る（TC-01 の 15 パターンに包含） |
