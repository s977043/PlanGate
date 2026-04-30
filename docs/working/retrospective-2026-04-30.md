# 振り返り 2026-04-30: doc-audit 2026-04-28（PR #123）

> 対象: PR [#123](https://github.com/s977043/plangate/pull/123) — `docs: 2026-04-28 ドキュメント整備（v8.2 整合性 / Rule 5 遵守 / 索引修正）`
> ブランチ: `docs/audit-2026-04-28`（マージ済み）
> 期間: 2026-04-28〜2026-04-30

## サマリ

v8.2 リリース後のドキュメント整備として **Phase A（読取専用監査）→ Phase B（修正適用）** の二段階アプローチを実施し、9 コミットを 1 PR に集約してマージ完了。CI（Markdown lint / plangate CLI tests）は両方 PASS。

| 区分 | 件数 | 結果 |
|------|------|------|
| Critical | 4 | 全件適用 |
| Major | 4 | 全件適用 |
| Minor | 4 | 2 件適用 / 2 件は監査誤検出により対応不要 |
| Info | 3 | I-3 を方針 A として M-4 に統合 |

## Keep（うまくいったこと）

### K-1. 監査と修正の二段階分離が機能した
Phase A（読取専用、4 並列 Explore agent）で punch list を確定 → ユーザー判断 → Phase B（修正）の流れにより、**着手前に範囲が明確化**され、途中で迷子にならずに済んだ。punch list を `docs/working/_audit/2026-04-28-doc-audit.md` に書き出したことで、修正の根拠が常に参照できた。

### K-2. severity 順のバッチコミットで PR が読みやすくなった
Critical → Major → Minor の順に 9 コミットを切ったことで、レビュー時に「重要度の高い変更から順に確認できる」構造になった。1 バッチ = 1 コミット = 1 punch list ID の対応が PR 本文の表とも一致して分かりやすい。

### K-3. handoff.md の遡及作成テンプレが再現可能だった
完了済 PBI 3 件（TASK-0017/0018/0019）の handoff.md を status.md / PR メタデータから機械的に再構成できた。「**遡及不能な項目は明示的に省略**」という方針も、後続の同様作業で踏襲可能。

## Problem（課題・反省）

### P-1. 監査エージェントに誤検出が含まれた
Phase A の Explore エージェントが以下を誤検出していた:
- m-1: `docs/plangate.md` に「v7 では」表現あり → **実際は該当なし**
- m-2: `.claude/skills/README.md` に setup-team 未掲載 → **実際は掲載済み**
- m-3 重複指摘: `.agents/skills/README.md` のセクション重複 → **実際は重複なし**

**原因**: Explore エージェントが「読み取り範囲」を抜粋的に報告するため、行番号や周辺コンテキストの再確認が不十分だった。

**対策**: 監査結果は punch list 確定前に **手元で grep / read による再検証** を 1 ステップ挟む（次回フロー追加）。

### P-2. M-4 の判断が punch list 提出時点で曖昧だった
「Agent 定義の "PlanGate" 言及 24 件」を Rule 3 / Rule 4 違反扱いするか否かの判断を Phase A では結論づけられず、Phase B 着手前にユーザー判断を仰いだ。

**対策**: 監査エージェントに「**判断保留項目**」を明示的に分類させるプロンプトに改善。今回は方針 A を採用し、`hybrid-architecture.md` に補足として明文化したため、次回以降は誤検出として扱える。

### P-3. gh auth account 切り替えで PR 作成が一度失敗した
作業開始時のアクティブアカウントが `kominem-unilabo` のままで、PR 作成が collaborator 権限エラーで失敗。auto-memory に記録された「GitHub アカウント切り替え」メモで原因即特定し復旧したが、**着手前に `gh auth status` を確認する手順が抜けていた**。

**対策**: メモリ記載通り「plangate 作業開始時に `gh auth switch -u s977043` を必ず実行」する hook 化を検討（別 PBI）。

## Try（次にやること）

### T-1. punch list 検証ステップの自動化
Phase A の punch list 確定前に、各 finding を機械的に再検証する Bash コマンド集を audit 結果ファイル末尾に同梱する（grep / ls / wc -l 等）。手動でも 5 分で再現できる構造にする。

### T-2. handoff 必須化の事前検出スクリプト
Rule 5 違反（完了済 PBI で handoff.md 欠落）を CI で機械検出する。現状は監査時に発覚するため後手対応になっており、事前検出に切り替える。

### T-3. Orchestrator Mode の実運用ケース第一号として EPIC #116 を扱う
EPIC #116「最新実行モデル対応」+ P1 6 件は親子 PBI 構造の自然な candidate。本振り返りと並行して `docs/working/PBI-116/parent-plan-draft.md` の素案作成を進める（別 PR）。

## メトリクス

| 指標 | 値 |
|------|---|
| 計画コミット数（B1〜B11 + audit + PR） | 9 |
| 計画外コミット | 0 |
| 監査誤検出率 | 2/12 = 17%（minor 領域） |
| Phase A 所要時間 | 約 10 分（4 並列 Explore） |
| Phase B 所要時間 | 1 セッション内で完了 |
| CI 通過 | 100%（Markdown lint / plangate CLI tests） |
| C-4 ゲート | APPROVE / 即マージ |

## 関連リンク

- PR: https://github.com/s977043/plangate/pull/123
- 監査結果: [`docs/working/_audit/2026-04-28-doc-audit.md`](_audit/2026-04-28-doc-audit.md)
- 方針 A 整理: `.claude/rules/hybrid-architecture.md` の補足セクション
- handoff 遡及作成例: `docs/working/TASK-0017/handoff.md` ほか 2 件
