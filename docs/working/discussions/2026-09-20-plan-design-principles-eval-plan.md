# Plan Design Principles 運用評価計画

- Issue: #1337 / predecessor: #1335, PR #1336
- Status: evaluation protocol v2。実モデルによるpaired実行は未実施。
- 対象: ai-dev-plan の設計判断。production、承認境界、C-1定義は変更しない。
- baseline: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- candidate: `4b3f4017ad6c2a64813524ec8567a289f722cb45`
- 比較版はSHA固定。評価途中でmain追従版へ差し替えない。

## 1. 評価成果物とVisibility

評価知識を1ファイルへ混在させない。

| Artifact | Role | Generator visibility |
| --- | --- | --- |
| `2026-09-20-plan-design-principles-eval-inputs.md` | 8ケースのPBI入力 | **visible** |
| `2026-09-20-plan-design-principles-eval-rubric.md` | expected behavior / failure / scoring | **hidden** |
| `2026-09-20-plan-design-principles-eval-ledger.md` | 実行条件・48 run・blind scoring台帳 | execution operator / reviewer |
| 本文書 | orchestration / stop / completion boundary | operator |

**重要**: repositoryに4文書が共存していることと、generatorが4文書を読めることは別。実行時はisolated workspace / allowed-read policyを使い、generatorへrubricをmountしない。rubricを読めたrunはcontaminatedとして除外する。

## 2. 評価仮説

#1335により、candidateではbaselineと比べて次が改善する可能性がある。

1. 現在必要な設計へ収束し、根拠のないabstractionを減らす
2. Contract / InvariantをAC・Existing Behavior・Domain Rule・Architecture Constraint・Measured Evidenceへtraceする
3. change typeに適したVerification/TDDを選ぶ
4. Failure / Compatibility等のConditional Guidanceを必要時のみ発火する
5. B-2の2〜3案比較を維持する
6. light taskで空section・無関係test・過剰な設計説明を増やさない

これは**仮説**であり、原則が文書に存在するだけでは効果ありと判定しない。

## 3. ai-dev-plan契約との整合

各PDPケースは generator input 文書内で以下のPBI情報を持つ。

- Context / Why
- In scope / Out of scope
- Acceptance Criteria
- Evidence
- Unknowns
- Assumptions

実行時は対象variantの `ai-dev-plan/SKILL.md` と、**同じrepo SHAのbundled references / rules**を使用する。

### B-1

本pilotはpaired conditionを固定するため非対話で行う。

- 入力から解決できる質問はEvidenceとして扱う
- 追加確認が必要なら Questions / Unknowns に記録
- 人間から追加回答を注入しない
- Blocking UnknownでPlan確定不能なら、その停止判断自体を出力へ残す
- 不足をfixture外の推測で埋めない

### B-2

2〜3案の実質的trade-off比較を維持する。lightを理由に比較そのものを省略しない。記述密度はtaskに合わせてよい。

### B-3

対象Skillが要求する `plan.md / todo.md / test-cases.md` の契約に従う。評価の主対象はPlan設計判断とTest Case traceだが、todo生成を勝手に省略してSkill契約を変えない。

### Metrics Evidence

synthetic fixtureから実数を取得できない項目は「未取得 / 非該当 / 追加調査必要」とする。架空のgrep件数や測定値を作ることはFAIL候補。

## 4. Paired execution

- 8ケース × baseline/candidate × 3 trial = **48 generation**
- 各generationは独立コンテキスト
- 同一model ID / effort / input / budget / timeout / tool policy
- generator input bytesはbaseline/candidate共通
- trial順はledgerのmatrixどおりvariant先行を交互にする
- networkは原則off
- raw outputを加工せず保存しhashを取る
- baselineへcandidate-only文書を補完しない
- candidateへbaselineとは異なる追加説明を渡さない

### Identity / Activation

installedだけではactivation証明にならない。

各runで:
- repo SHA
- skill path/hash
- loaded references path/hash
- resolution failure
- outputでPrinciples/Skillが判断へ影響した位置
を記録する。

variant identityまたはactivationが確認できないpairは、効果比較を `INCONCLUSIVE` とする。

## 5. Blind review

reviewerはgeneratorと別担当にする。

1. raw outputを匿名IDへ変換
2. baseline/candidate名を隠す
3. reviewerへ generator input + reviewer-only rubric を渡す
4. axisごとに PASS / FAIL / NOT_APPLICABLE / INCONCLUSIVE
5. evidence位置と理由を記録
6. variant identityを採点完了後に開示
7. 不一致があればadjudicatorと理由を残す

generatorの自己評価は採用判定に使わない。

## 6. Pair-level judgment

rubricの固定規則に従い、各caseを以下へ分類する。

- **Improvement signal**
- **Regression**
- **No demonstrated difference**
- **INCONCLUSIVE**

3 trialはpilot診断であり、統計的有意差・一般化された効果を主張しない。

重大回帰が1件でもあればcandidateを「改善済み」とは扱わない。

## 7. 既存PlanGateBench / eval-runnerとの関係

既存 `PlanGateBench` は代表task pattern固定、`scripts/eval-runner.py` / `bin/plangate eval` は完成TASKの既存評価を担う。

本pilotは **plan生成時のsemantic design judgment** をpaired比較する補助評価であり、既存runnerの代替ではない。

禁止:
- plan-only出力を完成TASKに見せるため偽 `handoff.md` / `c3.json` を作る
- 既存eval schemaへ未定義rubric fieldを無理に追加する
- runnerの自己申告由来評価を独立したsemantic証明として扱う

正式に完了したTASKを用いる後続dogfoodingでは、既存evalへ接続してよい。

参照:
- [Plan Design Principles](../../ai/plan-design-principles.md)
- [PlanGateBench](../../ai/plangatebench.md)
- [既存eval-runner](../../ai/eval-runner.md)
- [実行契約](../../ai/core-contract.md)

## 8. Start gate

以下が揃うまで48 generationを開始しない。

- [ ] generator inputs凍結
- [ ] reviewer rubric凍結
- [ ] ledger / run matrix凍結
- [ ] baseline/candidate SHA確認
- [ ] model ID / effort固定
- [ ] input/output token budget固定
- [ ] timeout固定
- [ ] tool/network policy固定
- [ ] isolated generator workspaceの手段確認
- [ ] raw output保存先確認
- [ ] independent reviewer確認
- [ ] skill/reference hash取得方法確認

揃わない場合は `INCONCLUSIVE_NOT_RUN`。未実行をPASSへ変換しない。

## 9. 実行順

1. 本PRでprotocol/input/rubric/ledgerをレビューして凍結
2. 実行環境とbudgetを確定
3. 48 generation
4. blind scoring
5. pair-level comparison
6. #1337へ結果とraw evidenceを記録
7. Improvement / Regression / No difference / Inconclusive に応じて次施策決定

評価途中で#1335 candidate SHAを変えない。

#960、#933/#810/#867のproduction変更は本pilotへ混ぜない。

## 10. Completion boundary

**本PRのmerge = #1335の効果証明ではない。**

本PRで完了するもの:
- fixed generator input
- hidden reviewer rubric
- paired run ledger
- contamination / identity / activation / missing-data contract
- 実行順とstop条件

#1337をcloseするには、原則として:
1. 48 generationのraw evidence
2. blind scoring
3. pair-level judgment
4. missing/contaminated runの明示
5. 次施策の決定
が必要。

実行環境が恒常的に確保できない場合は、AC自体をHuman判断で再スコープし、未実行のままcloseしない。

## 11. Review log

### 2026-09-23 review

検出して反映:
- **Major**: input / expected behavior / failures / rubric が同一ファイルにありgenerator contaminationしうる
  - → generator input / reviewer rubricを物理分離
- **Major**: run manifestが文章だけで、48runのidentity/activation/contaminationを追跡できない
  - → ledger template + 24 paired matrix追加
- **Major**: synthetic短文が `ai-dev-plan` のPBI INPUT契約へ十分接続されていない
  - → 全8ケースを Context/Scope/AC/Evidence/Unknown/Assumption 形式へ正規化
- **Medium**: B-1を対話実施するとpair条件がずれる
  - → non-interactive contract、Question/Unknownとして記録
- **Medium**: Metrics Evidenceを無理に満たそうと架空実測を作る余地
  - → unavailable/non-applicableを明示し架空値禁止
- **Medium**: repo内でファイル分離してもgeneratorがread可能ならblind性が無い
  - → isolated workspace / allowed-readをstart gateへ追加

現時点のblocking finding:
- protocol文書化については **なし**
- model paired executionについては **実行環境・model/budget/reviewer未確定のため未開始**
