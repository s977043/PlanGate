# Plan Design Principles — Implementation Review Record

Date: 2026-09-17
Issue: #1335
Branch: `docs/1335-plan-design-principles`

## Purpose

#1335 の Plan Design Principles を実装へ落とす過程で行った、計画見直し・複数視点レビュー・修正判断を記録する。

本記録は規範の正本ではない。

- 規範の正本: `docs/ai/plan-design-principles.md`
- 実行規範: `.agents/skills/ai-dev-plan/SKILL.md`
- 本記録: 実装途中の判断、却下案、修正理由、残存リスク

## Review Perspectives

次の視点で実装差分を再レビューした。

1. Architecture / responsibility boundary
2. TDD / verification quality
3. AI agent behavior / anti-overengineering
4. light / ultra-light の運用負荷
5. C-1 governance / #960 との整合
6. #810 Unknown Discovery / #867 Knowledge Delta との責務重複
7. plugin / Codex / install.sh distribution
8. existing workflow contract compatibility
9. independent review の維持

## Findings and Decisions

### 1. Review checklist を知識の正本にしない — PASS

Plan Design Principles → ai-dev-plan → plan/test artifact → Review という責務分離を維持した。

Review に残すのは actual diff / behavior / evidence を見ないと判定できない項目であり、logic correctness、claim-vs-actual、actual security defect、scope leakage 等を Plan Guidance へ移していない。

### 2. TDD を Always RED First にしない — PASS after correction

初期案では RED → GREEN が強く残っていたため、変更タイプ別の事前証拠へ修正した。

- new behavior: RED → minimum implementation → GREEN → Refactor
- bug fix: regression RED → fix → GREEN
- behavior-preserving refactor: characterization/existing tests GREEN → refactor → behavior preservation GREEN
- docs/config/generated artifact: deterministic baseline → change → deterministic validation

上位ルールは「必ずRED」ではなく「変更前に適切な証拠を持ち、変更後に同じ契約を再検証する」。

### 3. Contract / Invariant を AI が発明するリスク — PASS after correction

`Contract / Invariant Requires Source` を追加した。

Contract / Invariant は次の最低1つへ trace する。

- Acceptance Criterion
- Existing Behavior
- Domain Rule
- Architecture Constraint
- Measured Evidence

テストや抽象化を正当化するために後付けで発明することは禁止した。

### 4. Test trace と expected value source の混同 — PASS after correction

`test-cases.md` で次を分離した。

- Trace: なぜこのテストが存在するか
- Expected value source: なぜその期待値が正しいか

Verification Trace の種別は AC / Contract / Invariant / Regression / Conditional Requirement。

### 5. test-cases.md の肥大化 — FIXED

初期実装では各 Test Case に Trace Type / Trace ID / Source を繰り返していた。

これはケース数に比例して出力が増え、Mode-aware Output と矛盾するため修正した。

現在は `Verification Trace` 表を正とし、各 Test Case は `Trace ID` だけを参照する。

これにより traceability を保ちつつ重複を減らした。

#936 の「テストケース生成量制御」は #960 に統合済みであるため、本PRでは新規C-1削減項目やmode別件数制限を実装しない。

### 6. C-1 項目追加と #960 の衝突 — FIXED

初期実装では `plan.md` のローカル C-1 Self Review Checklist に次の新規項目を追加していた。

- Minimum Sufficient Design
- Contract / Invariant source trace
- change-type-aware Verification Strategy

#960 で C-1 の数・適用範囲が未解決のため、完了前レビューで削除した。

判断結果は Approach Comparison / Recommended Approach / Change Type / Verification Strategy / Plan Review Readiness に保持し、C-1 の新規 check ID・項目数変更は行わない。

### 7. #810 / #867 との責務重複 — PASS

#1335 では以下を再実装しない。

- #810: Unknown Discovery の分類・Blocking Unknown gate
- #867: Knowledge Delta / Characterization Test / Preparatory Refactoring の詳細契約

#1335 は上位設計原則として参照し、必要時に既存/予定責務へ接続するだけとした。

### 8. Distribution strategy — REPLANNED

初期計画:

```text
docs/ai/plan-design-principles.md
  -> references/plan-design-principles.md
  -> plugin/Codex/install.sh
```

実装調査で、既存 `ai-dev-plan/SKILL.md` 自体がすでに全配布経路へ同期されることを確認した。

新しい bundled reference と sync allowlist を増やすより、詳細正本を1つに保ち、Plan生成に必要な最小規範を Skill の実行サマリとして配布する方が Minimum Sufficient Design に合うと判断した。

採用:

```text
docs/ai/plan-design-principles.md   # detailed canonical source
        ↓ semantic alignment
.agents/skills/ai-dev-plan/SKILL.md # executable summary
        ↓ existing sync
plugin / install.sh / Codex
```

Skill summary が保持すべき契約:

1. 6 Core Principles
2. `Extensibility < Simplicity unless current evidence requires extensibility`
3. Contract / Invariant Requires Source
4. change-type-aware TDD
5. Trace と expected value source の分離
6. Mode-aware Output

全文一致ではなく、実行に必要な規範の semantic alignment を維持する。

### 9. Distribution link resolvability — FIXED

テンプレートから `docs/ai/plan-design-principles.md` だけを直接リンクすると、plugin/Codex導入先では `docs/**` が存在せずリンクが成立しない。

そのためテンプレートは配布可能な `ai-dev-plan/SKILL.md` の `Plan Design Principles` 節を実行規範として参照し、詳細正本の上流パスは説明として併記する形へ変更した。

### 10. Derived plugin artifacts — ALIGNED

次の派生物を正本テンプレートと同じ意味差分へ同期した。

- `plugin/plangate/skills/ai-dev-plan/SKILL.md`
- `plugin/plangate/skills/ai-dev-plan/references/plan-template.md`
- `plugin/plangate/skills/ai-dev-plan/references/test-cases.md`

`SKILL.md` は `.agents` と同一 content blob であることを確認した。

plan/test template は distribution 時のリンク変換を考慮した内容にした。

### 11. ultra-light / light で B-2 を省略する案 — FIXED

初期テンプレート案では、ultra-light / light で実質的な設計選択がない場合に Approach Comparison を省略できる記述を入れていた。

しかし現行 `ai-dev-plan` / `scripts/ai-dev-plan.sh` / Plan creation process は、B-2 を **2〜3案の trade-off 比較**として要求している。

#1335 は既存workflow contractそのものを変更するIssueではないため、この緩和はスコープ越境と判断した。

最終判断:

- B-2 の2〜3案比較はmodeにかかわらず維持する
- ultra-light / lightでは各セルを短くし、追加説明を増やさない
- mode-awareにするのは**記述密度**であり、既存必須ステップの有無ではない
- B-2自体をmode-awareにする必要が出た場合は、別途workflow contractとして検討する

## Multi-perspective Review Result

| Perspective | Result | Notes |
| --- | --- | --- |
| Architecture | PASS | Principles / Guide / Artifact / Review の責務分離を維持 |
| TDD | PASS after fix | 変更タイプ別 evidence へ修正 |
| AI anti-overengineering | PASS | Current-Need Trace / sourced Contract を導入 |
| light/ultra-light | PASS after fix | B-2は維持し記述密度のみ縮小、Trace重複削減 |
| Test volume | PASS with boundary | #936/#960 の件数制御へ越境しない |
| C-1 governance | PASS after fix | 新規 check ID / C-1項目追加を行わない |
| #810/#867 overlap | PASS | 詳細責務は再実装しない |
| Existing workflow contract | PASS after fix | B-2 mandatory contractを維持 |
| Distribution | PASS after replan | 既存 Skill sync を再利用 |
| Review independence | PASS | actual correctness/evidence は Review に残す |

## Known Limitations / Follow-up

- #960 が解決するまで、C-1 に新規 check ID を追加しない。
- #810 / #867 / #933 が `plan.md` 正本へ入る際は、この変更と競合しないよう rebase 後に意味差分を再確認する。
- `docs/ai/plan-design-principles.md` と Skill summary は全文一致ではないため、将来 Principle を追加・削除する際は summary の必須契約を同一PRで確認する。
- B-2 のmode別省略は本PRでは導入しない。必要性が実運用で確認された場合はworkflow contractとして別途扱う。
- 実行環境から GitHub host への直接 clone ができず、ローカルで `sync-plugin-plangate.sh` を実走できなかった。PR CI の drift check を最終的な deterministic verification として確認する。

## Completion Decision

完了前レビューで見つかったMajor / Medium findingは修正済み。

PR CI / drift check とPR差分レビューで新しい blocking finding が無ければ #1335 の実装を完了可能と判断する。失敗があればPlanへ戻って修正する。
