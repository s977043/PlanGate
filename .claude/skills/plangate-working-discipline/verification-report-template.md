# Verification Report

検証レポートのテンプレート。**「やったこと」と「確認できたこと」を分ける**のが目的。
未実行・失敗・スキップを隠した時点でレポートは無効。

```markdown
# Verification Report — <TASK-ID / 変更名>

## Executed Commands

<実際に実行したコマンドを実行順に。実行していないものをここに書かない>

| コマンド | 結果（exit code / 要約） |
| -------- | ------------------------ |

## Passed Checks

<成功した検証。何を確認できたかを 1 行ずつ>

- <検証項目>: PASS（<証拠: 出力の要点・件数・SHA>）

## Failed Checks

<失敗した検証。失敗を隠さない。0 件なら「なし」と明記>

- <検証項目>: FAIL（<エラー要約> → 対応: <修正した / 未対応>）

## Skipped Checks

<計画にあったが実行しなかった検証と、その理由>

- <検証項目>: SKIP（理由: <環境不足 / 対象外 / 時間>）

## Manual Verification

<自動検証できず、人間の確認が必要な項目>

- [ ] <確認項目>（確認方法: <手順>）

## Evidence

<一次証跡へのポインタ。ログ抜粋・スクリーンショット・CI URL・
宣言（Expected Diff）と実差分の突合結果>

## Remaining Risks

<検証でカバーできていないリスク。「検証した範囲」の境界を明示する>

## Completion Judgment

complete / partial / not_complete

## Reason

<判定理由。complete は「Passed が完了条件を満たし、Failed=0、
Skipped/Manual が完了条件に影響しない」場合のみ。
検証結果のない完了主張は partial に格下げする>
```

## 判定基準

| 判定           | 条件                                                                      |
| -------------- | ------------------------------------------------------------------------- |
| `complete`     | 完了条件に対応する検証がすべて Pass。Failed = 0。残る Manual は完了条件外 |
| `partial`      | 一部 Pass だが、未実行/失敗/Manual 待ちが完了条件に残る                   |
| `not_complete` | 完了条件の中核が Fail、または検証がほぼ未実行                             |

## OUTCOME 契約との対応（サブエージェント委譲時）

サブエージェント委譲では `docs/ai/subagent-delegation/outcome-contract.md` の
`OUTCOME: success / partial / failure`（最終行厳格フォーマット）が**最終判定の正本**。
本レポートの Completion Judgment は報告本文の判定であり、以下で対応させる:

| Completion Judgment | OUTCOME |
| --- | --- |
| complete | success |
| partial | partial |
| not_complete | failure |

両者が食い違う報告は不正とする（どちらかに合わせて修正してから提出）。

## 運用ルール

- 検証コマンドは**プロジェクトに実在するもののみ**。存在しないコマンドの実行を
  装わない・勝手に新設しない（必要なら「検証手段の不在」を Remaining Risks に書く）。
- 過去に実行した結果を今回の証拠に流用しない（実行日時と対象 SHA を紐づける）。
- Failed を修正した場合は該当検証を**再実行**してから Passed に移す。
