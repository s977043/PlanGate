# V-3 外部モデルレビュー結果（Codex）

> 実施日: 2026-04-20
> レビュアー: Codex (GPT-5 系)
> 対象: PR #35 実装差分（docs/workflows/ 配下 6 ファイル）
> モード: full（V-3 必須）

## 総合判定
**判定**: CONDITIONAL

5 phase の骨格、実行シーケンス、Rule 1 の state 形式は概ね成立しており、`docs/workflows/` 自体は後続サブの起点として十分読める。一方で、親 PBI で合意した Skill 境界を超える追加 Skill 名の持ち込み、README の PlanGate 対応表における主担当表現の揺れ、markdown lint 完了を裏づける CI / 再現可能証拠の不足が残っており、C-4 前に補正した方が安全。

## 受入基準 充足度チェック
| 受入基準 | 実装充足 | 根拠 |
| --- | --- | --- |
| 1. 5 ファイル存在 | ✅ | `docs/workflows/01_context_bootstrap.md`〜`05_verify_and_handoff.md` が存在。実ファイル確認済み。 |
| 2. 必須 6 項目 | ✅ | 各 phase に `目的 / 入力 / 完了条件 / 呼び出す Skill / 主担当 Agent / 次 phase への引き継ぎ` がある（例: `docs/workflows/01_context_bootstrap.md:5-38`、同様に 02〜05）。 |
| 3. Rule 1 準拠 | ✅ | 完了条件は state 形式で統一され、完了条件セクションに手順語は見当たらない（`docs/workflows/01_context_bootstrap.md:16-21`、`02_requirement_expansion.md:15-21`、`03_solution_design.md:15-22`、`04_build_and_refine.md:15-20`、`05_verify_and_handoff.md:15-21`）。 |
| 4. README + 対応表 | ✅ | `docs/workflows/README.md:45-63` に PlanGate 既存フェーズ対応表がある。 |
| 5. 実行シーケンス明示 | ✅ | `docs/workflows/README.md:33-42` に親 PBI 合意の 7 ステップ実行シーケンスがある。 |
| 6. 既存整合 | ⚠️ 部分充足 | レイヤー分離の方向性は `docs/plangate.md:78-94`、`docs/plangate-v6-roadmap.md:15-16` と整合するが、README は B / PR 作成の主担当を `spec-writer` と記し、親 PBI の `workflow-conductor 経由` 記述と揺れている（`docs/workflows/README.md:52,62`、`docs/working/TASK-0021/pbi-input.md:257-260`）。 |
| 7. lint | ⚠️ 証拠不足 | 受入基準上は必須（`docs/working/TASK-0022/pbi-input.md:72`）だが、現行 CI は `docs/workflows/**` を lint 対象に含めていない（`.github/workflows/ci.yml:27-34`）。`docs/working/TASK-0022/status.md:43` の「0 error」だけでは独立再現根拠として弱い。 |

## Rule 1 準拠の実装レベル検証
完了条件の文体は 5 phase とも state 形式で揃っており、Workflow に具体手順は書かれていない。Skill / Agent 名の記述も phase から見れば「どこへ委譲するか」の列挙に留まっており、各 Skill / Agent の中身まで書き込んではいない。

一方で、委譲先の列挙が親 PBI の合意範囲を超えて増えている点は Rule 1 そのものではなく、アーキテクチャ境界の問題として残る。親 PBI は Skill 層を 10 個で定義しているが（`docs/working/TASK-0021/pbi-input.md:59-72`）、phase 定義では `constraint-extract`、`definition-of-done`、`domain-modeling`、`implementation-plan`、`scaffold-generate`、`local-review`、`refactor-pass`、`test-matrix-check`、`handoff-package` など追加名が導入されている（`docs/workflows/01_context_bootstrap.md:25-27`、`03_solution_design.md:26-29`、`04_build_and_refine.md:24-27`、`05_verify_and_handoff.md:25-28`）。

## artifact クラスの設計妥当性
`context / requirements / design / handoff` は命名と payload の対応が素直で、後続 sub issue でも使い回しやすい。`README` の全体表（`docs/workflows/README.md:25-31`）と各 phase の引き継ぎ欄も基本的に整合している。

弱いのは `known-issues` で、クラス名に対して payload が「動作コード / 自己レビュー / 妥協点 / コミット履歴」まで広がっている点である（`docs/workflows/README.md:30`、`docs/workflows/04_build_and_refine.md:35-36`）。WF-05 側がこの artifact を機械的に扱うなら、`known-issues` という名前だけでは実体を想起しづらい。

## PlanGate 対応表の正しさ
対応表は A / B / C-1 / C-2 / C-3 / D / L-0 / V-1 / V-2 / V-3 / V-4 / PR 作成 / C-4 の 13 項目を省略せず並べており、レイヤー分離の説明も読みやすい（`docs/workflows/README.md:45-68`）。WF-04 を D、WF-05 を V 系〜handoff に対応させる整理も大筋で妥当。

ただし、主担当の欄は正本に寄せ切れていない。README は B を `spec-writer`、PR 作成を `spec-writer / conductor` としているが（`docs/workflows/README.md:52,62`）、親 PBI は B を `workflow-conductor 経由` と記し（`docs/working/TASK-0021/pbi-input.md:257-260`）、PlanGate 本体も B は `/ai-dev-workflow ... plan`、exec 以降を `workflow-conductor` が制御すると説明している（`docs/plangate.md:172-177,195-206`）。このままだと「PlanGate の誰がどこまで担うか」の読み替えで揺れが残る。

## Severity 付き指摘（最大 8 件）
| ID | Severity | 箇所 | 指摘 | 推奨対応 |
| --- | --- | --- | --- | --- |
| V3-01 | major | `docs/workflows/01_context_bootstrap.md:25-27`, `03_solution_design.md:26-29`, `04_build_and_refine.md:24-27`, `05_verify_and_handoff.md:25-28` | 親 PBI が定義した Skill 10 個（`docs/working/TASK-0021/pbi-input.md:59-72`）を超える追加 Skill 名が導入されている。#23 は Workflow 定義タスクであり、#24 の Skill 境界をこの PR で実質拡張している。 | phase では親 PBI の 10 Skill に揃えるか、追加 Skill を許容するなら親 PBI / #24 のスコープを先に更新して合意差分を解消する。 |
| V3-02 | major | `docs/workflows/README.md:52,62` | PlanGate 対応表の B / PR 作成の主担当が `spec-writer` ベースになっており、親 PBI の `workflow-conductor 経由` 記述および PlanGate 本体の説明と揺れている。対応表は読者の読み替え基準になるので、ここが揺れると運用像も揺れる。 | B / PR 作成の主担当表現を正本に合わせて一本化する。少なくとも README、親 PBI、`docs/plangate.md` の三者で同じ語を使う。 |
| V3-03 | major | `docs/working/TASK-0022/pbi-input.md:72`, `docs/working/TASK-0022/plan.md:95-100,132-133`, `.github/workflows/ci.yml:27-34` | 受入基準 7 の「markdown lint が通る」は独立再現できない。計画上は CI と同じ設定で lint するとしているが、現行 CI は `docs/workflows/**` を対象にしておらず、読める証拠は `status.md:43` の自己申告のみ。 | `docs/workflows/**/*.md` を CI の markdown lint 対象に追加するか、少なくともローカル lint 実行ログを evidence として残し、独立再現可能にする。 |
| V3-04 | minor | `docs/workflows/README.md:30`, `docs/workflows/04_build_and_refine.md:35-36` | artifact クラス `known-issues` の名前に対して payload が広すぎる。実際にはコード差分・自己レビュー・妥協点・コミット履歴まで含み、クラス名だけで内容を推測しにくい。 | `known-issues` を維持するなら必須セクションを明記する。名前を見直せるなら `build-result` 系への改名も検討する。 |

## C-4 推奨アクション
`CONDITIONAL` を推奨する。C-4 前に最低限やるべきことは 3 点で、1) 親 PBI と Skill 名の境界を揃える、2) README の B / PR 作成の主担当表現を正本に合わせる、3) `docs/workflows/**` を対象にした markdown lint の再現可能証拠を残す。これが揃えば、本 PR は最終承認に進める。

---

## CONDITIONAL 対応サマリ（2026-04-20）

| ID | Severity | 対応 |
|---|---|---|
| V3-01 | major | phase の「呼び出す Skill」を親 PBI 正規 10 Skill に限定。WF-01 から `constraint-extract` / `definition-of-done`、WF-03 から `domain-modeling` / `implementation-plan`、WF-04 から `scaffold-generate` / `local-review` / `refactor-pass`、WF-05 から `test-matrix-check` / `handoff-package` を削除 |
| V3-02 | major | README 対応表の B の主担当を `workflow-conductor 経由（内部で spec-writer が生成）`、PR 作成を `workflow-conductor が制御` に修正。親 PBI / `docs/plangate.md` との表現を一本化 |
| V3-03 | major | `.github/workflows/ci.yml` の markdown lint globs に `docs/workflows/**/*.md` を追加。加えて `docs/working/TASK-0022/evidence/markdown-lint-log.txt` にローカル実行ログ（`0 error`）を保存し独立再現可能に |
| V3-04 | minor | WF-04 の「次 phase への引き継ぎ」セクションに `known-issues` artifact の必須セクション（動作コード差分 / 自己レビュー / 明示的な既知課題 / コミット履歴）を明記 |

## 対応後判定

- Skill 境界: ✅ 親 PBI 10 Skill に完全整合
- 主担当表現: ✅ README / 親 PBI / PlanGate 本体で一貫
- lint 独立再現: ✅ CI 対象化 + ローカル実行ログ evidence
- known-issues payload: ✅ 必須セクション明記

**C-4 推奨**: APPROVE 相当（CONDITIONAL の 3 major + 1 minor 全対応完了）。
