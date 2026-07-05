# サブエージェント委譲プロトコル — サンプルと検証手順

> **Status**: Specification（v1）
> 親: [#710](https://github.com/s977043/plangate/issues/710) サブエージェント委譲プロトコルをPlanGate運用に組み込む
> 対応子 Issue: [#716](https://github.com/s977043/plangate/issues/716) サブエージェント委譲プロトコルのサンプルと検証手順を追加する
> 関連（同ディレクトリ）: [README.md](./README.md)（正本入口・全体像、#711）/ [outcome-contract.md](./outcome-contract.md)（OUTCOME 契約、#712）/ [dispatch-template.md](./dispatch-template.md)（派遣プロンプト必須8要素、#713）/ [behavior-norms.md](./behavior-norms.md)（行動規範、#714）/ [plangate-flow-integration.md](./plangate-flow-integration.md)（委譲タイミング、#715）

## 0. このファイルの位置づけ

[`outcome-contract.md`](./outcome-contract.md) §7 には最終報告フォーマット単体のサンプル（派遣プロンプトなし）がすでにある。本ファイルはその発展形として、[`dispatch-template.md`](./dispatch-template.md) の 4-A（調査）/ 4-B（実装）/ 4-C（レビュー）バリアントを**具体的な値で埋めたフル派遣プロンプト**と、それに対応する**サブエージェントの最終報告**をペアで示す（outcome-contract.md §8 の予告どおり「派遣プロンプト込みのフルサンプル」を担当）。

登場する `TASK-0221` は本ファイル専用の**架空の PBI**であり、実在環境や特定の実在 issue に依存しない（#716 注意点「サンプルは実在環境に依存しすぎない」）。ただし PlanGate の実在する用語（WF フェーズ、C-3 ゲート、`.claude/rules/*.md` 等の Hardening Override パス）はそのまま使い、抽象的すぎて使えない例にはしない。

## 1. サンプル1: 調査タスク（4-A、フロー #1「Plan 作成時の追加調査」相当）

### 1.1 派遣プロンプト（必須8要素すべて充足）

```markdown
## 役割・タスク

あなたは `plangate` リポジトリの調査エージェントです。項目ID: TASK-0221-T1。
タスク名: V-1 受け入れ検査で断続的に失敗する `tests/hooks/check-plan-hash.test.sh`
の原因調査。

## モデル格上げ理由

失敗が断続的（100% 再現しない）であり、ログ比較・タイミング要因の切り分けなど
複数候補からの推奨判断を要するため、判断系モデルで実行する。

## 最初に読むもの（順に）

1. `docs/working/TASK-0221/pbi-input.md`（本調査の背景・過去の失敗ログ抜粋）
2. `scripts/hooks/check-plan-hash.sh`（対象 hook 本体）
3. `tests/hooks/check-plan-hash.test.sh`（対象テスト）

## 既知の事実・確定済み結論・却下済み仮説

- 確定済み: 直近 20 回の CI 実行のうち 3 回で `check-plan-hash.test.sh` が失敗し、
  いずれも `plan_hash` 比較の直前で fail している（実測済み、CI ログ添付：
  `docs/working/TASK-0221/evidence/ci-run-{1201,1194,1187}.log`）
- 確定済み: ローカル環境（macOS / Linux 双方）では再現しない
- 却下済み仮説: 「テストの記述順序が原因」ではない（同一順序で成功しているケース
  があることを確認済み）
- 却下済み仮説: 「`plan_hash` の計算アルゴリズム自体のバグ」ではない
  （アルゴリズム自体は 500 回のローカル再現テストで一致している）

## タスク（順序付き）

1. 3 件の失敗ログを比較し、共通するタイミング・環境要因（並列実行数、キャッシュ
   ヒット有無、直前に実行された job 等）を特定する
2. CI 設定（`.github/workflows/ci.yml`）の該当 job 定義を確認し、疑わしい共有
   リソース（一時ファイルパスの衝突、環境変数の競合等）がないか調べる
3. 再現条件の仮説を1つに絞り、再現用の最小手順（またはなぜ最小手順が作れないか）
   を提示する（決定・修正は行わない）

## 制約

- read-only。ファイルの新規作成・編集は行わない（ログの分析結果は本文で報告する）
- 対象 worktree: 該当なし（読み取りのみ）
- 触ってはいけないもの: `.github/workflows/*.yml`・`scripts/hooks/*.sh`
  （Hardening Override 対象。読むことは可、書くことは禁止）
- 禁止操作: CI の再実行トリガー、外部への調査結果の共有
- ソフト上限: 15 ステップ相当

## 出力形式

- 成果物: 原因調査サマリ（本報告に記載。ログ引用箇所を明示）
- 要判断事項: 再現条件の確定に追加調査が必要な場合は P1、CI 全体を止めるべき
  緊急度であれば P0 として提示
- 最終行: `OUTCOME: success|partial|failure`

## 行動規範

軽量版（[behavior-norms.md](./behavior-norms.md) §軽量版）。真因調査が長期化する
場合はフル版に切替える。
```

### 1.2 サブエージェントの最終報告（`OUTCOME: partial`）

```text
3 件の CI 失敗ログに共通するのは「並列 job 数が 4 以上のときのみ発生」という
タイミング要因であり、一時ファイルパスの衝突が濃厚である。ただし再現手順の
確立には至っていない。

成果物: 原因調査サマリ（本報告）

## 発見事項
- 3 件すべてで並列 job 数が 4 以上のタイミングに発生（並列 3 以下では 0 件）
- `check-plan-hash.sh` が `mktemp` を使わず固定パス `/tmp/plan_hash.tmp` へ
  書き込んでいる箇所を発見（`scripts/hooks/check-plan-hash.sh:47`）。並列実行
  時に複数 job が同一パスへ同時書き込みし競合している可能性が高い

## 要判断事項
- [P1] 固定パスを `mktemp` ベースに変更する修正が必要そうだが、
  `scripts/hooks/*.sh` は Hardening Override 対象のため、修正は本タスク
  （read-only 調査）の範囲外。別途 apply-script 経由の対応が必要
- [P2] 再現手順を CI 上で安定させるには並列 job 数を意図的に 4 以上に固定した
  再現専用 workflow を追加する余地がある（今回は調査のみのためスコープ外）

## 検証結果
- ログ比較（3 件）: 実行済み（並列度と失敗の相関を確認）
- 固定パス書き込み箇所の grep: 実行済み（`grep -n mktemp\|/tmp/ scripts/hooks/check-plan-hash.sh`）
- 実際の並列競合の再現: 未実行（CI 再実行はタスクの禁止操作に該当するため）

OUTCOME: partial
```

## 2. サンプル2: レビュータスク（4-C、`review=true`、フロー #3「Approval 前のリスク監査」相当）

### 2.1 派遣プロンプト（必須8要素すべて充足）

```markdown
## 役割・タスク

あなたは `plangate` リポジトリのレビュー/監査エージェントです。
description: "TASK-0221 plan.md の Approval 前リスク監査 review=true"。
項目ID: TASK-0221-T2。タスク名: `docs/working/TASK-0221/plan.md` の C-3 直前
リスク監査。

## モデル格上げ理由

表面的なチェックカバレッジ確認ではなく、故障確率に基づく Severity 判断と
見落としリスクの特定を要するため、判断系モデルで実行する。

## 最初に読むもの（順に）

1. `.claude/rules/review-principles.md`（5観点 / Severity定義 / 判定基準）
2. `docs/working/TASK-0221/plan.md`（レビュー対象の計画本体）
3. `docs/working/TASK-0221/review-self.md`（C-1 セルフレビュー結果、既実施分）

## 既知の事実・確定済み結論・却下済み仮説

- 確定済み: C-1（セルフレビュー）は PASS 済み（17項目、`review-self.md` 参照）
- 確定済み: 本 PBI は `scripts/hooks/check-plan-hash.sh` の固定パス書き込みを
  `mktemp` ベースへ修正する変更を含む（Hardening Override 対象パス）
- 却下済み仮説: 「plan の変更ファイル数だけで risk レベルを判定する」方針は
  不採用（定性基準も併用する。`.claude/rules/mode-classification.md` 参照）

## タスク（順序付き）

1. plan.md の Work Breakdown が受入基準を網羅しているか確認する
2. Hardening Override 対象パスへの変更が `mode-classification.md` の
   「承認境界周辺の変更 → 最低でも high」ルールに従って mode 判定されているか
   確認する
3. 5 観点（可読性・拡張性・パフォーマンス・セキュリティ・保守性）で
   Severity 分類する（critical/major は根拠を示す。推測で断定しない）

## 制約

- read-only。修正は行わず指摘のみ
- 対象 worktree: 該当なし
- 禁止操作: plan.md への直接修正、外部への指摘内容の共有
- ソフト上限: 15 ステップ相当

## 出力形式

- 成果物: Severity 別指摘一覧（`.claude/rules/review-principles.md` 準拠）
- 要判断事項: critical は P0、major は P1 として明示
- 最終行: `OUTCOME: success|partial|failure`

## 行動規範

フル版（[behavior-norms.md](./behavior-norms.md) §フル版）。リスク監査のため。
```

### 2.2 サブエージェントの最終報告（`OUTCOME: success`、指摘ありでも success）

> `review=true` タスクは「依頼されたレビュー作業自体が完了していれば success」
> （[outcome-contract.md](./outcome-contract.md) §1.3 / §4.3）。指摘の重大さは
> P0/P1/P2 の要判断事項として分離する。

```text
description: "TASK-0221 plan.md の Approval 前リスク監査 review=true"

plan.md のリスク監査を完了し、major 1 件・minor 1 件を発見した。mode 判定は
妥当（high-risk）だが、ロールバック手順が一部欠落している。

成果物: レビュー結果（本報告に記載）

## 発見事項（レビュー成果物）
- [major] `scripts/hooks/check-plan-hash.sh` 修正タスクに `rollback:` の記載が
  無い。`mode-classification.md` の Hardening Override 対象パス変更は
  high-risk 相当が確定しており、`working-context.md` の todo.md 規約
  「必須=high-risk/critical の実装タスク」に抵触する
- [minor] Work Breakdown の Step 3（テスト追加）に推奨モデル（複雑度に応じた
  サブエージェント選定）の記載がない

## 要判断事項
- [P1] rollback 手順を plan.md / todo.md に追記してから C-3 へ進めるべきか、
  C-3 CONDITIONAL として反映後に進めるかの方針決定
- [P2] Step 3 への推奨モデル記載は必須ではないため、追記するかは任意判断

## 検証結果
- 受入基準網羅性の確認: 実行済み（plan.md の Work Breakdown を pbi-input.md の
  受入基準と突合、欠落なし）
- mode 判定の妥当性確認: 実行済み（Hardening Override 対象パスを含むため
  high-risk 判定は `mode-classification.md` の例外ルールに整合）
- rollback 記載の網羅性確認: 実行済み（該当タスクに記載なしを確認）

OUTCOME: success
```

## 3. サンプル3: 実装タスク（4-B、フロー #4「Execution 中の限定実装」相当）

### 3.1 派遣プロンプト（必須8要素すべて充足）

```markdown
## 役割・タスク

あなたは `plangate` リポジトリの実装エージェントです。項目ID: TASK-0221-T3。
タスク名: `check-plan-hash.sh` の固定パス書き込みを `mktemp` ベースへ修正。

## モデル格上げ理由

CI の並列実行タイミングに依存する競合修正であり、単純な機械的置換ではなく
既存の呼び出し元（複数箇所）への影響確認を伴うため。

## 最初に読むもの（順に）

1. `docs/working/TASK-0221/plan.md` の Work Breakdown Step 2（本タスク該当箇所）
2. `dispatch/task-003-brief.md`（Target Files / Spec / Existing Tests / Constraints）

## 既知の事実・確定済み結論・却下済み仮説

- 確定済み: 原因は `scripts/hooks/check-plan-hash.sh:47` の固定パス
  `/tmp/plan_hash.tmp` への書き込み（TASK-0221-T1 調査結果、
  `docs/working/TASK-0221/evidence/task-001-report.md` 参照）
- 却下済み仮説: 「並列実行数を CI 設定で 3 以下に制限する」対処は不採用
  （CI 全体のスループット低下を招くため、根本原因の修正を優先する方針が
  plan.md で確定済み）

## タスク（順序付き）

1. `task-003-brief.md` の Spec（`mktemp` を用いた一時パス生成へ置換、
   後始末の `trap` 追加）を満たす実装を行う
2. `tests/hooks/check-plan-hash.test.sh` を含む既存テストを実行し GREEN を
   確認する
3. `dispatch/task-003-report.md` に実行コマンド・結果・変更サマリを記録する

## 制約

- write可。対象は `task-003-brief.md` の Target Files のみ
  （`scripts/hooks/check-plan-hash.sh` 本体は Hardening Override 対象だが、
  本タスクは C-3 で承認済みの `apply-script` 経由修正であり、直接編集ではなく
  `scripts/apply-task-0221-check-plan-hash-fix.sh` の**作成**に限定する）
- 対象 worktree: `.claude/worktrees/task-0221-t3` 配下のみ書き込み可
- 触ってはいけないもの: `scripts/hooks/check-plan-hash.sh` 本体への直接
  Write/Edit（HO 常時 block。apply-script の生成のみ許可）
- 禁止操作: `git push` / PR 作成（依頼元が行う）
- ソフト上限: 15 ステップ相当

## 出力形式

- 成果物: `dispatch/task-003-report.md` の絶対パス
- 要判断事項: 設計上の疑問が生じた場合は実装を止めて P0 として報告
- 最終行: `OUTCOME: success|partial|failure`

## 行動規範

フル版（[behavior-norms.md](./behavior-norms.md) §フル版）。複数ファイルへの
影響確認を伴う実装のため。
```

### 3.2 サブエージェントの最終報告（`OUTCOME: failure`）

```text
`check-plan-hash.sh` は Hardening Override 対象であり、apply-script 経由でも
実行段階での自己適用（dry-run 実行）が self-mod ガードの対象になるかが
brief 内で未確定だったため、apply-script の作成のみ完了し実装は着手できていない。

成果物: `dispatch/task-003-report.md`（作成済み。apply-script の草案を含む）
着手できなかった理由: `task-003-brief.md` に「apply-script の実行主体
（AI か Human か）」の明記がなく、[`ho-change-workflow.md`](../ho-change-workflow.md)
の「AI は apply スクリプトを --dry-run なしで実行してはならない」原則に従うと
書きかけの apply-script を実行検証（--dry-run）してよいかの判断が付かなかった

## 要判断事項
- [P0] `scripts/apply-task-0221-check-plan-hash-fix.sh` の `--dry-run` 実行を
  本サブエージェントが行ってよいか（実行結果の確認のみで、実適用は別途 Human
  が行う）の方針確認をお願いしたい
- [P1] 上記が承認された場合、`--dry-run` 出力の差分レビューは誰が行うか
  （本サブエージェント継続 or 別レビューエージェント）の確認

## 検証結果
- apply-script の作成: 実行済み（`dispatch/task-003-report.md` に草案を記載）
- apply-script の --dry-run 実行: 未実行（P0 の方針確認待ちのため意図的に保留）
- 既存テスト `tests/hooks/check-plan-hash.test.sh`: 未実行（apply 前のため
  対象コードが未変更、実行しても差分検知不能なためスコープ外と判断）

OUTCOME: failure
```

> この失敗は「実装の技術的な行き詰まり」ではなく「派遣プロンプトの要素6
> （制約）に実行主体の明記が欠けていた」ことに起因する。[§5](#5-オーケストレータ受け入れ確認チェックリスト適用例) で
> 受け入れ確認を適用し、[§6](#6-sendmessage-追指示の例p0-解消後) で `SendMessage` 追指示の例を示す。

## 4. P0 / P1 / P2 要判断事項サンプル一覧

上記 3 サンプルから、優先度別の要判断事項を一覧化する（[outcome-contract.md](./outcome-contract.md) §2 の定義に対応）。

| 優先度             | 出典                           | 内容                                                         | オーケストレータの扱い                                              |
| ------------------ | ------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------------- |
| P0                 | サンプル3（実装、failure）     | apply-script の `--dry-run` 実行主体が未確定                 | ユーザーへ即座にエスカレーション。後続作業を進めない                |
| P1                 | サンプル1（調査、partial）     | 固定パス修正は HO 対象のため apply-script 経由の別対応が必要 | 次フェーズ（実装タスクの起票）に進む前にユーザー確認                |
| P1                 | サンプル2（レビュー、success） | rollback 手順追記を C-3 前にするか CONDITIONAL 反映にするか  | C-3 に進む前にユーザー確認                                          |
| P0 相当の解消後 P1 | サンプル3（実装、failure）     | `--dry-run` 出力の差分レビュー担当の確認                     | P0 解消（§6）後、次の追指示に含めて確認                             |
| P2                 | サンプル1（調査、partial）     | 再現専用 workflow の追加                                     | 記録のみ。即時のブロッカーにしない（handoff / known-issues 転記可） |
| P2                 | サンプル2（レビュー、success） | Step 3 への推奨モデル記載                                    | 記録のみ。任意判断                                                  |

## 5. オーケストレータ受け入れ確認チェックリスト適用例

[outcome-contract.md §6](./outcome-contract.md#6-オーケストレータ受け入れ確認チェックリスト) の 5 項目を、サンプル3（`OUTCOME: failure`）の報告に適用した例。

| #   | 確認項目                                 | サンプル3への適用結果                                                         |
| --- | ---------------------------------------- | ----------------------------------------------------------------------------- |
| 1   | 要求された成果物があるか                 | PASS — `dispatch/task-003-report.md` の絶対パスが明記されている               |
| 2   | 制約違反がないか                         | PASS — HO 対象への直接 Write/Edit を行わず、apply-script 作成のみに留めている |
| 3   | `OUTCOME` が最終行にあるか               | PASS — `OUTCOME: failure` が最終行、表記ゆれなし                              |
| 4   | 要判断事項が P0/P1/P2 で分類されているか | PASS — `[P0]` `[P1]` が明示されている                                         |
| 5   | テスト・検証結果が明示されているか       | PASS — 実行済み/未実行の別が理由付きで記載されている                          |

**判定**: 5 項目すべて PASS。ただし P0 が含まれるため、[`outcome-contract.md`](./outcome-contract.md#6-オーケストレータ受け入れ確認チェックリスト) の運用に従い、オーケストレータはユーザーへ**即座にエスカレーション**する（受け入れ確認 PASS と P0 エスカレーションは独立した扱いであり、PASS でも P0 があればブロッカーとして報告する）。

## 6. `SendMessage` 追指示の例（P0 解消後）

[`plangate-flow-integration.md`](./plangate-flow-integration.md) §4.1 の条件（`OUTCOME: partial`/`failure` で不足分がスコープ変更を伴わず明確、前提の制約を変更しない）に合致するため、新規 spawn ではなく同一サブエージェントへの `SendMessage` 追指示を選ぶ例。

```markdown
## 前回タスクの完了状態（要約）

TASK-0221-T3: apply-script の作成は完了。`--dry-run` 実行主体が未確定のため
実装は保留（`OUTCOME: failure`）。ユーザー確認の結果、`--dry-run` 実行は
サブエージェントが行ってよい（実適用は Human が別途実施）と方針確定した。

## 追加タスク（順序付き）

1. 作成済みの `scripts/apply-task-0221-check-plan-hash-fix.sh` を
   `--dry-run` で実行し、差分を確認する
2. 差分が Spec（`mktemp` ベースへの置換 + `trap` 追加）と一致するか確認する
3. `dispatch/task-003-report.md` に `--dry-run` 出力を追記する

## 変更・追加された制約（あれば）

- `--dry-run` の実行のみ許可（引数なしでの適用実行は禁止。実適用は Human）
- それ以外は前回と同一

## 出力形式

- 前回と同様。最終行に `OUTCOME: success|partial|failure` を再掲する
```

## 7. 検証観点対応表（#716 検証観点 → 本ファイルでの充足箇所）

| #   | 検証観点（#716）                                     | 充足箇所                                                                                                                    |
| --- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| 1   | 必須8要素が揃っているか                              | §1.1 / §2.1 / §3.1 の各派遣プロンプトが [dispatch-template.md §2](./dispatch-template.md#2-必須8要素) の 8 要素をすべて含む |
| 2   | サブエージェントが会話履歴なしで作業できるか         | 各サンプルの「最初に読むもの」「既知の事実」で自己完結している（前提となる会話を参照しない）                                |
| 3   | 既知の事実と却下済み仮説が渡されているか             | §1.1 / §2.1 / §3.1 いずれも「既知の事実・確定済み結論・却下済み仮説」を空欄にしていない                                     |
| 4   | 成果物の場所が明確か                                 | 各報告の「成果物」欄にファイルパスを明記（§1.2 は本文、§2.2 は本文、§3.2 はファイルパス）                                   |
| 5   | 要判断事項が優先度付きで返るか                       | §4 の一覧表参照。全報告で `[P0]`/`[P1]`/`[P2]` を使用                                                                       |
| 6   | 最終行に `OUTCOME` があるか                          | §1.2 `partial` / §2.2 `success` / §3.2 `failure` の 3 種を実演                                                              |
| 7   | `review=true` の使いどころが分かるか                 | §2（レビュータスク）で `description` に `review=true` を明記し、指摘ありでも `OUTCOME: success` になる理由を注記            |
| 8   | オーケストレータが作業をなぞらず受け入れ確認できるか | §5（受け入れ確認チェックリスト適用例）でオーケストレータが実装・調査本体を再実行せず 5 項目の判定のみ行うことを実演         |

## 8. 関連

- [README.md](./README.md) — 配置 ADR・オーケストレータ責務・全体索引（#711）
- [outcome-contract.md](./outcome-contract.md) — OUTCOME / P0-P1-P2 / 検証状態・受け入れ確認チェックリスト正本（#712）
- [dispatch-template.md](./dispatch-template.md) — 派遣プロンプト必須8要素・バリアント別テンプレート（#713）
- [behavior-norms.md](./behavior-norms.md) — 行動規範 軽量版・フル版（#714）
- [plangate-flow-integration.md](./plangate-flow-integration.md) — PlanGate フローとの接続タイミング（#715）
