# TEST CASES: TASK-0127

## 受入基準 → テストケース マッピング

| AC | テストケース |
|----|------------|
| AC-01 | TC-01 |
| AC-02 | TC-02, TC-03 |
| AC-03 | TC-04 |
| AC-04 | TC-05, TC-06, TC-07 |
| AC-05 | TC-08 |
| AC-06 | TC-09 |
| AC-07 | TC-10 |
| AC-08 | TC-11 |

## テストケース一覧

### TC-01: HTML 生成（正常系）
- 前提: 7 種 MD が揃った TASK ディレクトリ
- 入力: `render_review.py --task TASK-XXXX`（または bin 経由 `render TASK-XXXX --html`）
- 期待: `docs/working/TASK-XXXX/TASK-XXXX-c3-review.html` が生成され、終了コード 0
- 種別: integration

### TC-02: 7 種集約
- 前提: 7 種すべて存在
- 入力: render 実行
- 期待: 生成 HTML に 7 セクション（pbi-input/plan/todo/test-cases/review-self/review-external/handoff）がすべて含まれる
- 種別: integration

### TC-03: 欠落ファイルのスキップ
- 前提: review-external.md と handoff.md が無い TASK ディレクトリ
- 入力: render 実行
- 期待: エラーにならず、存在する 5 種のみ集約。欠落分は目次に出さない（または「未生成」と明示）
- 種別: unit/integration

### TC-04: 目次アンカー遷移
- 前提: 複数 MD 存在
- 入力: 生成 HTML を確認
- 期待: 先頭目次の各リンク href="#..." が対応セクションの id と一致
- 種別: unit

### TC-05: GFM 表レンダリング
- 入力: パイプ区切り表を含む MD
- 期待: `<table><thead><tr><th>...` 構造に変換される
- 種別: unit

### TC-06: チェックボックス
- 入力: `- [ ]` / `- [x]` を含む MD
- 期待: `<input type=checkbox>`（disabled、checked 反映）としてレンダリング
- 種別: unit

### TC-07: コードブロック / インライン
- 入力: ``` フェンス・インライン `code`・**strong**・[link](url)
- 期待: `<pre><code>` / `<code>` / `<strong>` / `<a>` に変換、HTML 特殊文字はエスケープ
- 種別: unit

### TC-08: 自己完結（外部参照ゼロ）
- 入力: 生成 HTML
- 期待: `src="http`/`href="http` を持つ script/link/style が無い（CSS は inline、JS 無しまたは inline のみ）
- 種別: verification

### TC-09: Python 依存ゼロ
- 入力: `python3 scripts/render_review.py`（venv なし・標準のみ）
- 期待: ImportError なく実行完了。`import` が標準ライブラリのみ
- 種別: unit

### TC-10: bin/plangate は apply-script 経由
- 入力: scripts/apply-task-0127-render.sh --dry-run
- 期待: diff が表示され、本体は未変更。AI は実適用しない（human 適用）
- 種別: verification

### TC-11: 存在しない TASK
- 入力: `render_review.py --task TASK-9999`（ディレクトリ無し）
- 期待: 明示エラーメッセージ + 非ゼロ終了
- 種別: unit

## エッジケース
- 空の MD ファイル（0 バイト）→ 見出しのみのセクション、クラッシュしない
- 巨大表 / ネストリスト → 最低限崩れず raw fallback
- MD 内の `<` `>` `&` → エスケープされ HTML 注入されない（XSS 防止）
