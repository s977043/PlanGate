# EXECUTION PLAN — TASK-1089 (#1089)

> EH-3 Hardening Override が `PLANGATE_HOOK_TASK` 設定時に 9 カテゴリすべてで
> 発火しない問題の是正。**HO パスの実適用は Human-owned**（AI は apply
> スクリプトと回帰テストまで）。

## Goal

`PLANGATE_HOOK_TASK` の有無に関わらず、Hardening Override 9 カテゴリが
EH-3 で常時 block される状態を、**Human が 1 コマンドで安全に到達できる形**で
提供し、**再発をテストで検知できる**ようにする。

## Constraints / Non-goals

- **Constraint**: `scripts/hooks/check-plan-hash.sh` / `.claude/rules/*.md` /
  `.github/workflows/*` は HO パス。**AI は編集しない**（apply スクリプト経由で
  Human が適用）
- **Constraint**: patch 未適用のまま main にマージされる。**CI を常時 RED に
  しない**こと
- **Non-goal**: HO 9 カテゴリの内容変更（追加・削除）
- **Non-goal**: `PLANGATE_HOOK_TASK` の運用変更
- **Non-goal**: `..` / 大小文字 / 末尾空白の正規化（別 PBI 候補。KNOWN-GAP として固定）
- **Non-goal**: 承認境界の緩和

## Approach Overview

1. 原因を実測で確定（HO 判定が `task_id` 分岐の内側）し、**現行構造が意図的か**を
   `git log` / TASK-0106 plan で確認する
2. **HO 判定を `task_id` 分岐の前へ移動**する（判定内容・9 カテゴリ・優先順は不変）
3. 適用は `docs/ai/ho-change-workflow.md` 標準フローに従い **apply スクリプト**
   （非 HO・冪等・`--dry-run` 既定・引数 strict 検証・アンカー検証）で行う
4. **回帰テストの既定期待値を「block される」側に置き**、既知ギャップの受理は
   tracked な flag ファイルによる明示 opt-in にする（再発を CI が検知する）
5. 正本の**行番号アンカーを記号アンカー化**する（移動で参照が壊れるため）

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | 原因の再現と意図性確認 | `evidence/ho-matrix-unpatched.txt` / `pbi-input.md` の由来節 | AI | low | 意図的なら停止して報告 |
| 2 | hook 変換の設計 + 参考 patch | `patches/check-plan-hash.ho-always.patch` | AI | **high**（承認境界） | 非 HO 経路の非回帰を実測するまで先へ進まない |
| 3 | apply スクリプト | `scripts/apply-eh3-ho-always.sh` | AI（実行は Human） | **high** | 4 性質（冪等/dry-run/引数/アンカー）を実測 |
| 4 | 回帰テスト | `tests/extras/ta-65-eh3-ho-task-context.sh` | AI | medium | 変異注入で kill を実証 |
| 5 | KNOWN-GAP 宣言 | `tests/fixtures/eh3-known-gap-1089.flag` | AI | low | 削除は apply スクリプトが行う |
| 6 | 正本整合（記号アンカー / 既知制限） | `docs/ai/ho-change-workflow.md` / `plugin/.../mode-classification.md` / `docs/ai/hook-enforcement.md` | AI | medium | 適用前後で同じブロックへ解決することを実測 |
| 7 | 証跡 | `evidence/*` | AI | low | すべて `<repo_root>` 引数で再現可能にする |

## Files / Components to Touch

| ファイル | 区分 | 変更 |
|---------|------|------|
| `scripts/apply-eh3-ho-always.sh` | 非 HO・新規 | 適用スクリプト |
| `tests/extras/ta-65-eh3-ho-task-context.sh` | 非 HO・新規 | 回帰テスト |
| `tests/fixtures/eh3-known-gap-1089.flag` | 非 HO・新規 | 既知ギャップ宣言（apply で削除） |
| `docs/ai/hook-enforcement.md` | 非 HO | EH-3 の既知制限 + 退役条件 |
| `docs/ai/ho-change-workflow.md` | 非 HO | 記号アンカー化 |
| `plugin/plangate/rules/mode-classification.md` | 非 HO | 記号アンカー化 |
| `docs/working/TASK-1089/**` | 非 HO | plan / patch / evidence |
| `scripts/hooks/check-plan-hash.sh` | **HO** | apply スクリプトが適用（**AI は触らない**） |
| `.claude/rules/mode-classification.md` | **HO** | apply スクリプトが適用（**AI は触らない**） |

## Testing Strategy

- **Unit（hook 挙動）**: `ta-65` が HO 全カテゴリ × TASK 有無 / stdin JSON /
  非 HO 近傍 / plan_hash 全経路 / BYPASS 優先順 を実測表明
- **Integration**: `sh tests/run-tests.sh` を**未適用ツリーと適用済みツリーの
  両方**で実行（適用後にスイート全体が壊れないことの確認）
- **Mutation**: `evidence/mutation-mutate.sh <repo_root>` が 6 変異で kill を実証
- **Verification Automation**: 証跡スクリプトはすべて `<repo_root>` を引数に取り、
  セッション固有パスに依存しない

## Risks & Mitigations

| リスク | 影響 | 緩和 |
|--------|------|------|
| 是正が新たな block 経路を作り開発が止まる | high | 非 HO 近傍 10 件の否定表明（TC-06）+ 非回帰 25 ケース比較 |
| 未適用のまま CI が常時 RED | high | KNOWN-GAP flag による明示 opt-in（既定 fixed でも flag 期間は green） |
| 適用したつもりで未適用（Shadow Config） | high | flag 残存＝ stale 宣言として FAIL / apply スクリプトが 3 操作を 1 単位で実行 |
| 行番号アンカーの stale 化 | **high** | 記号アンカー化 + 適用前後の解決一致を実測 |
| patch 単独適用の位置ズレ | medium | `git apply --check` 必須・`patch -p1` 非推奨を明記・base commit と sha256 を patch 冒頭に記録 |
| main の drift でアンカー不一致 | medium | apply スクリプトがアンカー検証に失敗したら exit 1（部分適用なし） |

## Questions / Unknowns

- **解決済**: 現行構造は意図的か → **非意図**（TASK-0106 の順序議論は maintenance
  との相対位置に閉じている）
- **未解決（別 PBI 候補）**: HO 9 カテゴリのうち `.claude/settings*.json` 以外の
  8 カテゴリに EH-3 以外の代替ガードがあるか（`check-forbidden-files.sh` は守らないことのみ実測）
- **未解決（別 PBI 候補）**: `..` / 大小文字 / 末尾空白の正規化

## Mode判定

**モード**: `high-risk`

**判定根拠**:

- 変更ファイル数: 9（新規 5 / 変更 4） → 高
- 受入基準数: 7 → 高
- 変更種別: 承認境界（Hardening Override）そのもの → **例外ルールにより最低「高」**
- リスク: 緩めれば穴、締めすぎれば開発停止 → 高
- **最終判定**: `high-risk` / **`lite_eligible=false`（AC-10 Hardening Override 優先）**
  / **Standard・同期 C-3 固定**（autonomous APPROVE 不可）
