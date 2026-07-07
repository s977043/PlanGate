# PlanGate Loop

標準ループ。各フェーズは**入力 / 出力 / チェック項目 / 停止条件 / 人間確認が必要な条件**を持つ。
停止条件に該当したら先へ進まず、指定のフェーズへ戻るか人間へ返す。

## 0. Intake

ユーザー要求を整理する。

- **入力**: ユーザーの依頼文・関連 issue・既存 memory
- **出力**: 要求の一文要約 / 種別（実装・修正・調査・レビュー）/ 成功の定義（仮）
- **チェック項目**:
  - [ ] 要求を一文で言い直せるか
  - [ ] 「完了」が観測可能な形で言えるか（仮でよい）
  - [ ] 同じ要求を扱う並行作業がないか（実測必須:
    `gh pr list --search "<キーワード/issue番号>" --state all` で open/merged PR、
    `git log --oneline --all --grep "<issue番号>"` で既存コミット、
    `git branch -a | grep -i "<キーワード>"` で未マージの並行開発ブランチを確認）
- **停止条件**: 要求が複数解釈できる → 解釈候補を提示して確認。並行作業が既に完了 → 重複と報告して終了
- **人間確認**: 解釈の分岐がゴールを変える場合

## 1. Plan

作業計画を作る。

- **入力**: Intake 出力・既存設計（実コードを読む）・plan-memory
- **出力**: Goal / Non-goals / Scope / Constraints / Existing Design Fit / Risk Areas /
  Assumptions / Unknowns / Required Files / Expected Diff / Verification Method /
  Rollback Plan / Human Approval Required Conditions
- **チェック項目**:
  - [ ] Verification Method が具体コマンド・具体観測で書けている
  - [ ] 検証コマンドを**実機で試行済み**（PASS する入力・FAIL する入力の両方向。原則 12）
  - [ ] Risk Areas に不可逆操作・共有状態・承認境界への接触が列挙されている
  - [ ] Expected Diff が要求に 1:1 で紐づいている（説明できない差分予定がない）
- **停止条件**: Verification Method が書けない → 調査タスクへ分割。Unknowns が Goal に影響 → 調査先行
- **人間確認**: Non-goals の境界が事業判断を含む場合

## 2. Review

計画をレビューする。

- **入力**: Plan 出力
- **出力**: [review-gate-template.md](./review-gate-template.md) 準拠のレビュー結果
- **チェック項目**: 要件整合 / 既存設計整合 / 過剰実装 / セキュリティ / データ破壊 /
  テスト容易性 / 保守性 / 代替案比較 / 未検証の前提
- **停止条件**: `needs_revision` → Plan へ戻る（改訂は**追記方式** — 旧版は監査記録として不変。
  `needs_revision`→改訂→再レビューは**ラウンド上限 3**、超過で人間へ）。`blocked` → 不足情報の取得へ。`rejected` → Intake へ戻る
- **人間確認**: レビューで承認境界・セキュリティ・データ破壊の懸念が出た場合

## 3. Approval

承認が必要な変更か判定する。

- **入力**: Review 済み計画
- **出力**: [approval-gate-template.md](./approval-gate-template.md) 準拠の判定
  （Requires Human Approval: yes / no + Risk Level + Safe Alternative）
- **チェック項目**: データ削除 / schema 変更 / 認証認可 / 課金 / 外部 API / 本番設定 /
  CI/CD / 大規模リファクタ / 依存追加 / 不可逆変更 のいずれかに該当するか
- **停止条件**: `yes` かつ承認未取得 → **実行せず承認要求を提示して停止**
- **人間確認**: 判定が `yes` の場合すべて。判定に迷う場合も `yes` に倒す

## 4. Execute

承認済み計画に沿って作業する。

- **入力**: 承認済み計画（approved の記録）
- **出力**: 差分（Expected Diff の範囲内）
- **チェック項目**:
  - [ ] 変更が Expected Diff の宣言内に収まっている
  - [ ] 既存の命名・設計・責務分離に合わせた
  - [ ] エラーを握りつぶしていない
  - [ ] stage は明示パスで行い、コミット前に staged 内容を確認した
- **停止条件**: 前提が崩れた（想定外の既存実装・計画外ファイルへの波及）→ **実装を止めて Plan へ戻る**。
  同じ失敗が 3 回続いた → 別アプローチを勝手に始めず人間へ返す
- **人間確認**: 宣言外の変更が必要と判明した場合（スコープ変更）

## 5. Verify

観測可能な方法で検証する。

- **入力**: 差分・Plan の Verification Method
- **出力**: [verification-report-template.md](./verification-report-template.md) 準拠のレポート
- **チェック項目**:
  - [ ] 計画時の Verification Method をすべて実行したか（未実行は未実行と記録）
  - [ ] 失敗した検証を隠していないか
  - [ ] 宣言（Expected Diff）と実差分を突合したか
- **停止条件**: Failed Checks あり → Execute へ戻る（3 回で人間へ）。
  検証手段がない項目 → Manual Verification として人間へ明示
- **人間確認**: complete 判定でも、人間が確認すべき項目（UI・外部影響）が残る場合

## 6. Remember

判断・失敗・未解決事項を記録する。

- **入力**: 本ループの全出力
- **出力**: [plan-memory.md](./plan-memory.md) の更新
- **チェック項目**:
  - [ ] 却下した案と理由を残したか
  - [ ] 時点記録（計画ラウンド・decision record）を遡及編集していないか（修正は事後注記で）
  - [ ] 未確定の完了系記述に PENDING-VERIFY を付けたか
  - [ ] 次のセッションが 5 分で状況把握できるか
- **停止条件**: なし（ただし記録なしで次の作業に進まない）
- **人間確認**: 不要

## 7. Next Action

次の一手を決める。

- **入力**: Verify の残リスク・Remember の Open Questions
- **出力**: 優先度付き次アクション（P0/P1/P2 + owner: AI / Human）
- **チェック項目**:
  - [ ] 次の一手は「いま最もリスクが高い場所」か
  - [ ] Human にしかできない項目を AI 側タスクに混ぜていないか
- **停止条件**: 実行可能なタスクがすべて Human 待ち → 待ち状態と解除条件を報告して停止
- **人間確認**: 次の一手が新しいスコープを開く場合
