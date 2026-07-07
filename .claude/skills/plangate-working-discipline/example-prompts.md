# 使用例プロンプト

Claude Code で PlanGate working discipline を使うための短いプロンプト例。
いずれも「計画固定 → リスク可視化 → 承認判定 → 検証 → 記録」を強制する形。

## 1. 新規機能の実装前計画

```text
/plangate-working-discipline を適用して、<機能名> の実装計画を作って。
実装はまだしない。Plan Phase の全項目（特に Non-goals / Risk Areas /
Verification Method / Expected Diff）を埋めて、Approval Gate 判定まで出して。
```

## 2. 既存コードの修正

```text
<ファイル/機能> の <問題> を修正したい。まず既存設計（該当ファイルと参照元）を
読んで Existing Design Fit を確認し、Expected Diff を宣言してから修正して。
宣言外のファイルに触れる必要が出たら止めて報告して。
```

## 3. リファクタリング

```text
<対象> のリファクタを計画して。動作を変えない制約で、変更前後で同じ検証
（test / typecheck）が通ることを完了条件にする。差分が <N> ファイルを超える
見込みなら分割案を先に出して。Approval Gate 判定必須。
```

## 4. バグ修正

```text
<バグの症状> を調査して。まず再現手順と観測された証拠を確定し（推測で原因を
断定しない）、根本原因 → 最小修正 → 回帰検証の順で。修正前に「なぜ既存テストで
捕まらなかったか」も記録して。
```

## 5. PR レビュー

```text
PR #<N> を review-gate-template.md の観点でレビューして。差分に存在しない
コードへの推測指摘はしない。指摘には severity を付け、「変更範囲外だが
セキュリティ上見逃せないもの」だけ範囲外指摘を許可する。
```

## 6. 仕様レビュー

```text
<仕様書/plan> をレビューして。要件との整合・未検証の前提・Unknowns の
洗い出しを重点に。「この仕様のままで実装に入ってよいか」を
approved / needs_revision / blocked / rejected で判定して。
```

## 7. セキュリティ影響のある変更

```text
<変更内容> はセキュリティに影響する可能性がある。Approval Gate を先に通し、
Requires Human Approval / Risk Level / Safe Alternative を提示して。
承認が出るまで実装しない。dry-run や差分プレビューの準備までは進めてよい。
```

## 8. 長期タスクの引き継ぎ

```text
<TASK-ID> を引き継ぐ。まず plan-memory（および作業コンテキスト）を読んで、
Accepted Decisions / Rejected Options / Open Questions を要約して。
記載の完了系情報は鵜呑みにせず、PENDING-VERIFY 項目と「宣言と実態の乖離」が
ないかを実測で確認してから次の一手を提案して。
```

## 9. /compact 前の引き継ぎメモリ作成

```text
/compact する前に plan-memory を更新して。特に: 却下した案と理由・
未解決リスク・次の一手・検証コマンド。未確定の完了系記述には
PENDING-VERIFY を前置して。この memory だけ読めば作業を再開できる状態にして。
```

## 10. サブエージェント利用判断

```text
<タスク> をサブエージェントに委託すべきか判断して。判断基準: 複雑さ（1 コンテキストで
持ちきれないか）・独立性（他作業と分離できるか）・並列性（同時実行の利益があるか）。
委託する場合は派遣プロンプト（役割・SSOT・既知の事実・却下済み仮説・制約・
出力形式）を作り、委託しない場合はその理由を 1 行で。
委託しても結果は自分で検証してから採用して。
```
