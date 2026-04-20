# V-3 完成度 外部レビュー（Codex 全体）

## 総合判定
CONDITIONAL。9 件の受入基準はすべて文書上で満たされ、v7 の 3 層ハイブリッドも実運用に足る粒度まで落ちています。  
ただし、v5 互換の主要文書が `release-manager` を前提にしている一方で、現行の Agent 群にその定義が見当たらず、フル/critical 系の経路がまだ完全には閉じていません。

## 観点別評価

### 1. 受入基準充足度（9 項目）

| AC | 判定 | 根拠 |
|---|---|---|
| 1. Workflow 5 phase が定義されている | OK | `docs/workflows/README.md:11-31` で WF-01〜WF-05 の目的/入出力/成果物を定義。各 phase ファイル `docs/workflows/01_context_bootstrap.md:1-36` 〜 `05_verify_and_handoff.md:1-71` で完了条件・呼び出す Skill・主担当 Agent まで明記。 |
| 2. Skill 10 個が定義されている | OK | `docs/workflows/skill-mapping.md:7-40` で 10 Skill のカテゴリ/Phase/出力を整理。実体も `.claude/skills/context-load/SKILL.md:1-28` 〜 `.claude/skills/known-issues-log/SKILL.md:1-28` まで揃っており、全 Skill に入力/出力/想定 phase がある。 |
| 3. Agent 5 体が定義されている | OK | `.claude/agents/orchestrator.md:1-82`、`requirements-analyst.md:1-40`、`solution-architect.md:1-35`、`implementation-agent.md:1-40`、`qa-reviewer.md:1-54` で責務・委譲関係・tools が定義済み。 |
| 4. Solution Design phase（WF-03）が独立している | OK | `docs/workflows/03_solution_design.md:1-32` で WF-03 を単独 phase として定義し、`docs/working/templates/design.md:1-124` で design artifact の 7 セクションを固定。 |
| 5. Verify & Handoff phase（WF-05）が毎回必須出力 | OK | `docs/workflows/05_verify_and_handoff.md:1-71` で WF-05 を `handoff.md` 必須化。`docs/working/templates/handoff.md:1-109` が要件適合/既知課題/V2 候補/妥協点/引き継ぎ/テスト結果を強制。 |
| 6. Rule 1〜5 が明文化されている | OK | `.claude/rules/hybrid-architecture.md:7-15` に 5 ルールを集約し、適用先と違反検出まで定義。 |
| 7. CLAUDE.md / Skill / Hook の境界ルールが明文化されている | OK | `.claude/rules/hybrid-architecture.md:52-68` と `docs/plangate-v7-hybrid.md:99-113` で、案件固有=CLAUDE.md / 再利用=Skill / 強制=Hook を二重に明示。 |
| 8. v5/v6 文書との整合が取れている | OK | `docs/plangate.md:1-20` で v5 の統制層を維持し、`docs/plangate-v7-hybrid.md:16-35` で v5/v6 を置換せず opt-in 拡張と定義。 plugin 側のデュアル運用も `docs/plangate-plugin-migration.md:16-25` と `docs/working/TASK-0016/evidence/runtime-verification.md:17-23` で裏付けあり。 |
| 9. 実行シーケンスがドキュメント化されている | OK | `docs/plangate-v7-hybrid.md:134-144` と `docs/workflows/execution-sequence.md:17-57` で orchestrator → requirements-analyst → qa-reviewer → solution-architect → implementation-agent → qa-reviewer → orchestrator を明示。 |

### 2. 逆輸入改善点の達成度（4 件）

| 改善点 | 達成度 | 根拠 |
|---|---|---|
| Review 観点が Skills になった | 達成 | `docs/workflows/skill-mapping.md:11-20,24-30` で `nonfunctional-check` / `edgecase-enumeration` / `acceptance-review` / `known-issues-log` を独立 Skill 化。`qa-reviewer.md:22-26` でも直接呼び出しが定義済み。 |
| solution-architect が独立 phase になった | 達成 | `docs/workflows/03_solution_design.md:1-32` と `docs/working/templates/design.md:1-124` により、WF-03 が plan から独立した設計 phase として成立。 |
| Verify & Handoff が標準 phase になった | 達成 | `docs/workflows/05_verify_and_handoff.md:1-71` と `docs/working/templates/handoff.md:1-109` で、handoff が毎回必須の完了資産として固定。 |
| 責務ベース subagent 化 | 達成 | `docs/plangate-v7-hybrid.md:75-83` と `docs/workflows/execution-sequence.md:7-57` で 5 Agent の責務分離と遷移が揃っている。 |

### 3. 実行シーケンス動作可能性

この runtime sequence は、現行の Agent / Skill / Workflow 定義だけで実行可能です。`orchestrator` は `Agent` tool を持ち、WF-01/05 の遷移と handoff 発行まで責務化されており、`requirements-analyst`、`solution-architect`、`implementation-agent`、`qa-reviewer` もそれぞれ必要な Skill と責務を持っています (`.claude/agents/orchestrator.md:14-45`、`requirements-analyst.md:12-40`、`solution-architect.md:12-30`、`implementation-agent.md:12-40`、`qa-reviewer.md:12-54`)。  
加えて、`implementation-agent` が参照する `self-review` も `.claude/skills/self-review/SKILL.md:1-20` で既に存在しているため、WF-04 内の自己レビューも現状定義で回せます。

Concrete gaps:
- `/Users/user/Documents/GitHub/plangate/docs/workflows/README.md:59-63` は V-4 を `release-manager` に割り当てていますが、`/Users/user/Documents/GitHub/plangate/.claude/agents/README.md:33-40` と `/Users/user/Documents/GitHub/plangate/docs/working/TASK-0025/evidence/existing-agents-inventory.md:5-36` には該当 Agent がありません。full/critical モードを追うと、ここでローカル定義の行き先が欠けます。
- `/Users/user/Documents/GitHub/plangate/docs/workflows/README.md:49-63` と `/Users/user/Documents/GitHub/plangate/docs/workflows/execution-sequence.md:71-79` は legacy の `workflow-conductor` / `spec-writer` と v7 の `orchestrator` / `requirements-analyst` を並置していますが、どちらを優先して使うべきかの単一ルールがありません。混在運用では、初回実行時に誤って旧経路を踏むリスクがあります。

### 4. v5/v6/v7 共存設計

v5 は `docs/plangate.md:1-20` で現行の統制層として残っており、v7 は `docs/plangate-v7-hybrid.md:16-35,148-166` で opt-in 拡張として扱われています。さらに `docs/plangate-plugin-migration.md:16-25` と `docs/working/TASK-0016/evidence/runtime-verification.md:17-23` により、legacy `.claude/` と plugin の dual-run が成立しているため、TASK-0016 の plugin 化と衝突していません。  
残る注意点は、legacy の V-4 系だけが `release-manager` にぶら下がって見えることです。これは v7 との直接競合ではなく、v5 フル経路の説明不足として残っています。

### 5. 既存 Agent 18 体との共存

`docs/working/TASK-0025/evidence/existing-agents-inventory.md:5-42` が、既存 18 Agent と新 5 Agent の関係を整理しています。とくに `implementer` vs `implementation-agent` は「TDD 実装」から「小単位自己レビューを含む責務ベース実装」への整理、`workflow-conductor` vs `orchestrator` は「PlanGate 特化のフェーズ制御」から「hybrid 実行層の総責任者」への再分離として、責務の重なりを明示したうえで legacy 共存に落としています。  
このため、名称衝突はあっても機能衝突は限定的です。ただし、既存ファイルが legacy として温存される前提なので、混在運用時は `CLAUDE.md` か entry doc でどちらの経路を使うかを明示しておく必要があります。

### 6. Developer Experience

`docs/plangate-v7-hybrid.md` を最初に開く新規エンジニアには、アーキテクチャの全体像、5 phase、10 Skill、5 Agent、境界ルール、実行シーケンスが 1 ファイルで見えるため、入口としてはかなり良いです。  
一方で、実際に 1 周回すには `docs/workflows/README.md`、`execution-sequence.md`、`skill-mapping.md`、5 つの phase ファイル、`design.md` / `handoff.md` テンプレートを跨ぐ必要があり、legacy v5/v6 との切り替え条件も別ファイルに散っています。初見では迷いにくいが、最短で実行するにはまだ少し索引が足りません。

## Severity 付き指摘一覧（最大 10 件）

| ID | Severity | 箇所 | 指摘 | 推奨対応 |
|---|---|---|---|---|
| H-01 | major | `/Users/user/Documents/GitHub/plangate/docs/workflows/README.md:59-63` / `/Users/user/Documents/GitHub/plangate/docs/working/TASK-0025/evidence/existing-agents-inventory.md:5-36` | V-4 を `release-manager` に割り当てているが、現行の `.claude/agents` 定義と inventory に `release-manager` が存在しない。full/critical 経路を辿ると、説明上の行き先が欠けている。 | V-4 が外部/legacy 前提なら明記し、該当 Agent の所在をリンクするか、README から除外して「optional / external dependency」として扱う。 |
| H-02 | minor | `/Users/user/Documents/GitHub/plangate/docs/workflows/README.md:49-63` / `/Users/user/Documents/GitHub/plangate/docs/workflows/execution-sequence.md:71-79` | legacy の `workflow-conductor` / `spec-writer` と v7 の `orchestrator` / `requirements-analyst` が並存しているが、どの条件でどちらを使うかの単一ルールがない。 | entry doc か README に「v5 継続時は legacy、v7 採用時は hybrid」を 1 段落で追加する。 |

## 運用時のリスク（3 件以内）

- full/critical モードを README どおりに辿ったチームが、`release-manager` の行き先で止まる可能性がある。実装そのものは進んでも、完了判定の説明が欠けるためレビュー前に不安定になる。
- legacy `workflow-conductor` と v7 `orchestrator` を混ぜて使うチームでは、plan 生成と WF-01〜WF-05 実行の境界を取り違えやすい。結果として、`plan.md` と `design.md` / `handoff.md` の責務が曖昧になる。
- 新規参入者は v7 文書を先に読むと迷いにくいが、実運用で必要な補助テンプレートや legacy 互換説明は別文書にあるため、初回の作業開始までに数回のクロスリファレンスが必要になる。

## 次のアクション推奨

1. `/Users/user/Documents/GitHub/plangate/docs/workflows/README.md` で `release-manager` を legacy / external / optional のどれかに分類し、所在があるならその定義へリンクする。
2. `/Users/user/Documents/GitHub/plangate/docs/plangate-v7-hybrid.md` か `/Users/user/Documents/GitHub/plangate/docs/workflows/README.md` に、「v5 継続」「v7 opt-in」「legacy と hybrid の使い分け」を 5 行程度で追加する。
3. `/Users/user/Documents/GitHub/plangate/docs/plangate-v7-hybrid.md` の冒頭に、初回導線として読む順番（この 1 ファイル → `docs/workflows/README.md` → `execution-sequence.md` → テンプレート）を 1 行で置く。
