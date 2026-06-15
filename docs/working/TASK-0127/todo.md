# EXECUTION TODO: TASK-0127

## 🤖 Agent タスク

### 準備
- [ ] T01 既存 `scripts/*.py` の引数処理・出力規約パターンを確認 — Owner: agent / depends_on: - / files: scripts/_paths.py, scripts/baseline-snapshot.py
- [ ] T02 C-3 対象 7 種 MD のファイル名定数を確定 — Owner: agent / depends_on: T01 / files: scripts/render_review.py

### 実装
- [ ] T03 `render_review.py` CLI 骨格（引数: --task / --work-dir / --out、欠落ファイルskip） — Owner: agent / depends_on: T02 / files: scripts/render_review.py 🚩
- [ ] T04 簡易 Markdown→HTML: 見出し・段落・水平線 — Owner: agent / depends_on: T03 / files: scripts/render_review.py
- [ ] T05 GFM 表のレンダリング — Owner: agent / depends_on: T04 / files: scripts/render_review.py 🚩
- [ ] T06 チェックボックス（- [ ] / - [x]）+ 箇条書き/番号リスト — Owner: agent / depends_on: T04 / files: scripts/render_review.py 🚩
- [ ] T07 コードブロック（```）+ インライン（code/strong/em/link）エスケープ — Owner: agent / depends_on: T04 / files: scripts/render_review.py
- [ ] T08 自己完結 HTML テンプレート（CSS インライン）+ 目次アンカー生成 — Owner: agent / depends_on: T05,T06,T07 / files: scripts/render_review.py
- [ ] T09 存在しない TASK 指定時の明示エラー・非ゼロ終了 — Owner: agent / depends_on: T03 / files: scripts/render_review.py
- [ ] T10 `apply-task-0127-render.sh`: cmd_render 関数注入（冪等・--dry-run・アンカー検証） — Owner: agent / depends_on: T03 / files: scripts/apply-task-0127-render.sh 🚩
- [ ] T11 apply-script に dispatch `render)` 行 + help 追記を含める — Owner: agent / depends_on: T10 / files: scripts/apply-task-0127-render.sh
- [ ] T12 ドキュメント追記（render 使い方） — Owner: agent / depends_on: T08 / files: docs/

### 検証
- [ ] T13 render_review.py unit（表/チェックボックス/コード/欠落 fixture） — Owner: agent / depends_on: T08 / files: evidence/test-runs/
- [ ] T14 既存 TASK で integration（7種集約・目次アンカー・外部参照ゼロ） — Owner: agent / depends_on: T08 / files: evidence/verification/ 🚩

### 完了
- [ ] T15 status.md / handoff.md 更新、apply-script の dry-run 出力を evidence 保存 — Owner: agent / depends_on: T13,T14 / files: docs/working/TASK-0127/

## 👤 Human タスク
- [ ] H01 C-3: plan 承認（c3.json APPROVED 発行） — Owner: human / depends_on: C-1
- [ ] H02 apply-task-0127-render.sh を dry-run → 適用（bin/plangate 反映） — Owner: human / depends_on: T11 ⚠️ AI 実行不可（HO）
- [ ] H03 C-4: PR レビュー — Owner: human / depends_on: PR

## ⚠️ 依存関係
- H02（HO 適用）は T11 完了後・PR とは独立に人間が実行可能だが、機能の動作確認（render コマンド経由）は H02 後でないと完結しない
