# TASK-0022 外部 AI レビュー結果（C-2 / Codex）

> 実施日: 2026-04-20
> レビュアー: Codex (GPT-5 系)
> モード: standard（17項目独立検証）
> 対象: `plan.md` / `todo.md` / `test-cases.md` / `review-self.md`

## 総合判定

**判定**: CONDITIONAL

骨格は妥当で、受入基準と成果物の対応も大きくは崩れていない。一方で、`plan.md` のモード判定が `mode-classification.md` と不整合で、`review-self.md` の全PASS判定はその前提を誤っている。加えて、Rule 1 の検証設計が語彙チェックに寄りすぎており、「完了条件」と「手順」の混同を十分に捕捉できていないため、修正後に C-3 へ進めるのが妥当。

## 17項目独立検証

| ID | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01 | PASS | `plan.md` の Step 2〜6 と `test-cases.md` の TC-1〜TC-7 で、受入基準 7件への対応先は一通り存在する。 |
| C1-PLAN-02 | PASS | `plan.md` の Questions / Unknowns に 3件の判断待ちが明示され、未確定事項を隠していない。 |
| C1-PLAN-03 | PASS | `plan.md` の Constraints / Non-goals は #24〜#28 の範囲外を明示しており、骨格定義にスコープを絞れている。 |
| C1-PLAN-04 | WARN | `plan.md` の Step 4 と `test-cases.md` の TC-3 は禁止単語 grep が中心で、Rule 1 の本質である「状態条件か / 手順記述か」の判定を十分に保証していない。 |
| C1-PLAN-05 | PASS | `plan.md` の各 Step に Output があり、Step 4/5 では evidence 出力先も固定されている。 |
| C1-PLAN-06 | PASS | `todo.md` の依存グラフは C-3 後に T-1 開始、T-3〜T-7 並行、T-8 以降直列という流れを明示している。 |
| C1-PLAN-07 | WARN | 自動化の記述はあるが、Rule 1 準拠確認の自動化が表層的で、`review-self.md` の「十分に自動化可能」という評価は強すぎる。 |
| C1-TODO-01 | WARN | `review-self.md` は「各タスク 30分〜2時間程度」として PASS にしているが、`docs/ai-driven-development.md` の「2-5分で完了する1アクション」原則とは整合しない。 |
| C1-TODO-02 | PASS | `todo.md` の Agent タスクは `depends_on` が揃っており、主要な前後関係は追える。 |
| C1-TODO-03 | PASS | 各タスクと総括表の両方に 🚩 があり、レビュー観点は明示されている。 |
| C1-TODO-04 | PASS | `todo.md` の Iron Law 遵守欄で、C-3 承認前に実行しないことと evidence 必須が定義されている。 |
| C1-TODO-05 | PASS | 完了条件は T-14 の `status.md` 更新まで含めて定義されており、実行完了の終点は明確。 |
| C1-TC-01 | PASS | `test-cases.md` 冒頭のマッピング表で、受入基準 7件と TC-1〜TC-7 の紐付けは成立している。 |
| C1-TC-02 | PASS | TC-E1〜TC-E4 で命名不整合、完了条件の文体、対応表粒度、行数ガードレールまで補足している。 |
| C1-TC-03 | PASS | 自動 / 手動の切り分け自体は明示されている。妥当性の不足は C1-PLAN-04/07 側の問題として扱う。 |
| C1-OVR-01 | PASS | `plan.md` / `todo.md` / `test-cases.md` は、README 作成・整合確認・lint 検証という主要成果物の対応関係で大きな齟齬はない。 |
| C1-OVR-02 | FAIL | `mode-classification.md` では「変更ファイル数 6」「受入基準数 7」「タスク数 14」はいずれも `full` 側であり、`plan.md` / `review-self.md` の `standard` 判定は基準不一致。 |

## Severity 付き指摘

| ID | severity | 箇所 | 指摘 | 推奨対応 |
|---|---|---|---|---|
| EX-01 | major | `plan.md` / Mode判定, `review-self.md` / C1-OVR-02, `.claude/rules/mode-classification.md` | `standard` 判定が基準表と一致していない。変更ファイル数 6、受入基準数 7、タスク数 14 はいずれも `full` 帯で、C-2 スキップ可・V-2 スキップという結論も連鎖的に誤る。 | `full` に再分類し、C-2 必須・V-2 実施前提で `plan.md` と `review-self.md` の記述を揃える。 |
| EX-02 | major | `plan.md` / Step 4, `test-cases.md` / TC-3・TC-E2, `review-self.md` / C1-PLAN-04・07 | Rule 1 準拠確認が禁止単語の非出現に寄りすぎており、「完了条件に見えるが実質手順」の混入を検出しにくい。 | 完了条件ごとに「状態記述 / 手順記述」をレビューする目視ルーブリックを追加し、TC-3 か TC-E2 をその判定基準に更新する。 |
| EX-03 | minor | `review-self.md` / C1-TODO-01, `todo.md` / T-3〜T-10, `docs/ai-driven-development.md` / タスク粒度の原則 | C-1 は todo 粒度を PASS としているが、自己根拠が「30分〜2時間」で、プロジェクトの 2-5分粒度ルールと噛み合っていない。 | C1-TODO-01 を WARN に落とすか、README 作成・整合確認など大きいタスクをさらに分割する。 |
| EX-04 | minor | `todo.md` / T-1, `docs/ai/project-rules.md` / ブランチ命名規則 | ブランチ名 `feat/workflow-phases-definition` は、repo で許可されている `feature/` `fix/` `docs/` `refactor/` `chore/` と一致しない。 | `docs/TASK-0022-workflow-phases-definition` など、既存命名規則に合わせた表記へ修正する。 |

## Rule 1 準拠チェック

現時点の `plan.md` / `todo.md` / `test-cases.md` そのものには、WF-01〜WF-05 の実装ノウハウを直接書き込む記述は多くないため、**直ちに Rule 1 違反と断定する箇所はない**。ただし、以下は検証設計として弱い。

- `plan.md` / Step 4
  完了条件の妥当性を「禁止単語がないこと」で代理判定している。
- `test-cases.md` / TC-3
  完了条件セクションの grep に閉じており、語彙を変えた手順記述を取り逃がす。
- `test-cases.md` / TC-E2
  目視確認はあるが、判定基準がレビューア依存で、`review-self.md` では十分に評価へ反映されていない。

結論として、**Rule 1 違反箇所が明白にあるというより、Rule 1 を守れていると証明する設計がまだ弱い**。

## モード判定の妥当性

`standard` 判定は妥当ではない。`mode-classification.md` の判定ロジックに従うと、少なくとも以下が `full` に該当する。

- 変更ファイル数: 6 (`docs/workflows/README.md` + phase 5件)
- 受入基準数: 7
- タスク数: 14
- 影響範囲: 後続 #24〜#28 の基盤

したがって、**別案ではなく基準どおり `full` が妥当**。オーバーライドは不要で、むしろ `standard` 側の記述を撤回すべき。

## Questions への第三者見解

1. Q1 完了条件の粒度
   完了条件は「状態」で止めるべきだが、親 PBI で固定済みの要素までは含めてよい。例えば WF-01 なら「対象範囲 / 使用可能技術 / 禁止事項 / 成果物定義が明文化されている」までは妥当で、書き方や手順まで踏み込むべきではない。
2. Q2 PlanGate 対応表の粒度
   README の対応表は A/B/C-1/C-2/C-3/D/L-0/V-1/V-2/V-3/V-4 まで全部並べる方がよい。WF は実行層、PlanGate は統制層という境界を見せる資料なので、後段フェーズを省くと「どこから先が Workflow の外か」が逆に曖昧になる。
3. Q3 次 phase 引き継ぎ artifact
   本 TASK ではテンプレート本文まで確定しなくてよいが、artifact の種類名は固定した方が後続に効く。少なくとも requirements / design / known-issues / handoff のようなクラス名はこの段階で合わせるのが妥当。

## 結論と C-3 推奨アクション

**C-3 推奨判定**: CONDITIONAL

以下を反映できれば APPROVE に寄せてよい。

1. `standard` を `full` に修正し、C-2 必須・V-2 実施前提に更新する。
2. Rule 1 検証を禁止単語チェックだけに依存しない形へ補強する。
3. 可能なら todo 粒度の自己評価とブランチ命名を repo ルールに合わせる。

参考集計: PASS 11 / WARN 5 / FAIL 1。骨格の再生成までは不要だが、現状の「全PASS」は維持できない。
