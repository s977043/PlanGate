---
task_id: TASK-0050
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 170
---

# Handoff: TASK-0050 / Issue #170 — tests/extras/ 分離

## メタ情報

```yaml
task: TASK-0050
related_issue: https://github.com/s977043/plangate/issues/170
author: qa-reviewer
issued_at: 2026-05-01
v1_release: <PR マージ後に SHA>
```

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1: `sh tests/run-tests.sh` 21/21 PASS 維持 | PASS | `Results: 21 passed, 0 failed` を確認 |
| AC-2: extras/*.sh 追加で完結 | PASS | run-tests.sh は base test + loader、TA-04〜07 が `tests/extras/ta-NN-*.sh` に移動 |
| AC-3: README に追加手順明示 | PASS | `tests/extras/README.md` に命名規約 / source 規約 / 追加手順 / 例 / 関連リンクの 5 セクション |

**総合**: **3 / 3 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 |
|------|---------|------|
| extras 内の関数定義が他 extras に漏れる（共通 namespace）| info | accepted（運用で衝突回避）|
| glob ソート順序が一部の古い shell で不安定 | info | accepted（`ta-NN-` プレフィクスで自然順序、bash/zsh/dash で動作確認済）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|--------|
| extras を関数定義中心の構造に再設計（namespace 分離）| 関数衝突回避 | Low |
| `tests/extras/_common.sh` 共通ヘルパ | DRY 化（現状 `run_pr_link_fixture` 等が ta-04 内に閉じている）| Low |

## 4. 妥協点

| 選択 | 諦めた代替 | 理由 |
|------|-----------|------|
| source 方式（同一プロセス）| sub-process 起動 | `pass` / `fail` カウンタを直接更新できる、最小変更 |
| `ta-NN-*.sh` 命名 | 番号なし命名 | glob ソートで実行順序を担保 |
| extras/README.md は単一 file | 各 extras に doc 分散 | 追加手順を 1 箇所で管理 |

## 5. 引き継ぎ文書

### 概要

`tests/run-tests.sh` の末尾領域コンフリクト問題（retrospective 2026-05-01 P-2）を解消するため、TA-04〜07 を `tests/extras/ta-NN-*.sh` に分離。本体は base test（TA-01〜03）+ extras loader にスリム化。後続 PBI でテスト追加するときは `tests/extras/` にファイルを置くだけで本体編集不要 → コンフリクト源根絶。

主要成果:
- `tests/extras/` 新設、TA-04〜07 を 4 ファイルに分離（内容無変更）
- `tests/run-tests.sh` を loader 化
- `tests/extras/README.md` で命名規約 + 追加手順 + 例を文書化
- 21 件 PASS 維持

### 触れないでほしいファイル

- `tests/extras/*.sh` の冒頭コメント: source される前提を明示しているため
- `tests/run-tests.sh` の loader ブロック: glob 順序が tests 順序を決定する

### 次に手を入れるなら

- 新 PBI でテスト追加: `tests/extras/ta-NN-<name>.sh` を追加するだけ
- アンチパターン: `tests/run-tests.sh` 末尾領域に直接挿入（衝突再発）

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| Integration（loader 経由）| 21 | 21 | 0 / 0 |

検証コマンド: `sh tests/run-tests.sh` → `Results: 21 passed, 0 failed`
