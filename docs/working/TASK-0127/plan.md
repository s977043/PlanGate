# EXECUTION PLAN: TASK-0127

C-3 人間レビュー用 HTML 出力オプション（`bin/plangate render`）

## Goal

C-3 対象の 7 種 Markdown を 1 枚の自己完結 HTML に集約し、ブラウザで横断把握できる出力コマンドを提供する。MD が読みづらい / ファイルが多い / ブラウザで見たい、という利用者の声を解消する。

## Constraints / Non-goals

- **Constraints**
  - `bin/plangate` は Hardening Override 対象 → AI は直接編集せず apply-script を作り **人間が適用**
  - `scripts/render_review.py` は **Python 標準ライブラリのみ**（新規 pip 依存ゼロ）
  - 生成 HTML は **自己完結**（外部 CDN / 外部ファイル参照なし）
- **Non-goals（V2）**
  - ローカル HTTP サーバ / ライブリロード（`serve`）
  - PDF 出力、mermaid 図描画
  - 外部 MD ライブラリ採用
  - C-3 承認操作（c3.json 発行）の UI 化

## Approach Overview

`bin/plangate render <TASK-XXXX> [--html]` → `scripts/render_review.py` を呼び出し → C-3 対象 7 種 MD のうち存在するものを読み、目次付き 1 ページ HTML を `docs/working/<TASK>/<TASK>-c3-review.html` に出力。生成後は出力パスを表示するのみ（ブラウザ自動起動なし）。

レンダリングは Python 標準ライブラリのみの簡易 Markdown→HTML 変換器を `render_review.py` 内に実装する（見出し / 段落 / GFM 表 / チェックボックス / コードブロック / インライン強調・コード・リンク）。

### アプローチ比較（B-2）

| 案 | 構成 | Pros | Cons | 採否 |
|----|------|------|------|------|
| **A（採用）** | `render_review.py`（標準ライブラリ簡易パーサ）+ bin/plangate apply-script | 依存ゼロ・自己完結・HO 適用分離が明確 | 簡易パーサの対応記法が限定的（保守は局所） | ✅ |
| B | 外部 `markdown`+`pygments` 採用 | 高品質レンダリング | pip 依存追加・versioning-stability 適合確認が別途必要・ユーザー意向に反する | ✗ |
| C | Shell + vendored marked.js 埋め込み | 生成時 Python 不要 | 3rd-party JS を repo に vendor・ユーザーは Python OK 表明 | ✗ |

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | `render_review.py` 実装（引数: work_dir / task_id / 出力先、7 種 MD 読込・欠落スキップ） | scripts/render_review.py | agent | M | 🚩 簡易パーサの記法網羅 |
| S2 | 簡易 Markdown→HTML 変換（見出し/段落/表/チェックボックス/コード/インライン） | （S1 内） | agent | M | 🚩 GFM 表・チェックボックス |
| S3 | 自己完結 HTML テンプレート（CSS インライン・目次アンカー生成） | （S1 内） | agent | L | |
| S4 | `bin/plangate` 用 apply-script（`cmd_render` 関数 + dispatch `render)` 注入、冪等・--dry-run 対応） | scripts/apply-task-0127-render.sh | agent | M | 🚩 既存 dispatch アンカー整合 |
| S5 | help テキスト追記分も apply-script に含める | （S4 内） | agent | L | |
| S6 | ドキュメント追記（render コマンドの使い方） | docs（既存ページに追記 or 新規） | agent | L | |
| S7 | テスト（test-cases.md 全件） | evidence/test-runs/ | agent | M | 🚩 V-1 突合 |
| H1 | apply-script を人間が dry-run → 適用 | bin/plangate 反映 | human | M | 🚩 HO 適用 |

## Files / Components to Touch

- 新規: `scripts/render_review.py`（AI 実装）
- 新規: `scripts/apply-task-0127-render.sh`（AI 作成 / 人間適用）
- 変更（apply-script 経由・人間適用）: `bin/plangate`（`cmd_render` + dispatch + help）
- 追記: ドキュメント（`docs/` 配下、render 使い方）

## Testing Strategy

- **Unit**: `render_review.py` の Markdown→HTML 変換を、表・チェックボックス・コードブロック・欠落ファイルの各入力で検証（fixture を使った Python 実行）
- **Integration**: 既存 TASK ディレクトリ（例: TASK-0126）に対し render を実行し、7 種のうち存在分が 1 ページに集約され目次アンカーが機能することを確認
- **Verification**: 生成 HTML をブラウザ（または curl で grep）で開き、外部参照ゼロ（`http://` / `https://` の src/href が CSS/JS に無い）を確認
- **エラー系**: 存在しない TASK 指定で明示エラー・非ゼロ終了

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| 標準ライブラリのみで GFM 表/チェックボックスのレンダリング品質が不足 | 対応記法を明示スコープ化（test-cases で固定）、未対応記法は raw テキストにフォールバック |
| bin/plangate dispatch の構造変更でアンカー不一致 | apply-script はアンカー grep 検証 + 冪等 + --dry-run、不一致時は ERROR で停止 |
| HO 適用を AI が誤って実行 | apply-script は AI が dry-run のみ、実適用は human（メモリ feedback-ho-apply-script-no-ai-exec 準拠） |

## Metrics Evidence

| 指標 | 実数 | 見積もり | ratio | 判定 |
|------|------|---------|-------|------|
| レンダリング対象 MD 種別数 | 7（固定リスト: pbi-input/plan/todo/test-cases/review-self/review-external/handoff） | 7 | 1.0 | 採用（「全件」系の曖昧スコープなし・固定集合） |
| touch する HO ファイル | 1（bin/plangate） | 1 | 1.0 | 採用（apply-script + 人間適用で対応） |

固定集合のため repo-wide 実数取得は不要。対象は working-context.md 定義の C-3 アーティファクト 7 種。

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 新規2 + bin/plangate + docs ≈ 4 → standard 相当
- 受入基準数: 8 → standard〜high
- 変更種別: 機能追加（新コマンド）+ **承認境界周辺（bin/plangate に touch）** → **最低 high 強制**（mode-classification.md 例外ルール）
- リスク: 中（HO 適用フローを伴う）
- **最終判定**: high-risk（`lite_eligible=false` / Standard C-3 同期固定 / Hardening Override 優先）
