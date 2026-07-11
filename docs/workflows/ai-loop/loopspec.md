# LoopSpec — ループ実行境界の宣言構造

> 適用ドメイン（Phase 1）: ①plangate 本体 = docs/workflows/ai-loop/ 配下のみ（dogfooding 域・本番フロー WF-00〜07 非適用）
> ②導入先リポジトリ = ho-paths 確定 + LoopSpec scope.allowed_paths 宣言を前提に適用可
> 対応 issue: [#726](https://github.com/s977043/plangate/issues/726)（4層エンジニアリングモデル・LoopSpec 提案）
> 準拠する第一原理（`docs/ai/ai-loop/design-philosophy.md` §2）:
> **I-1**（承認境界の不可侵）・**I-4**（安全側デフォルト）・
> **I-6**（停止できないループはループではない）・**I-9**（宣言↔実差分の二段 detect）
> 本書は §8 トリアージ（design-philosophy.md）で「追記・新規ファイル」と仕分け済みの
> issue #726 LoopSpec 部分を配置するものであり、4層モデル自体の採否判断は
> design-philosophy.md §3 を正本とし再定義しない。

---

## 1. 目的

「ループを回す」という指示だけでは、何が closed loop で何が単なる polling かを
機械的に区別できない（design-philosophy.md I-6）。LoopSpec は、ai-loop-workflow 上で
**1 つのループ実行の境界を宣言する構造**であり、以下を強制する:

- goal・stopping rule・memory・escalation を**宣言必須**にする（宣言なき反復を拒否）
- maker と checker を**構造的に分離**する（I-2 の LoopSpec 上の実装点）
- 宣言（LoopSpec）と実行（arbiter 裁定・PR 差分）を**別物**として扱う（I-9 二段 detect の前提）

LoopSpec は **arbiter.py への入力そのものではない**。LoopSpec は「このループを何のために・
どこまでの権限で回すか」の宣言であり、各サイクルの裁定入力（decision-table.md §2 の
4 軸: boundary/lite/verdict/class）は LoopSpec 宣言の範囲内で毎サイクル別途生成される。
LoopSpec 自体を裁定エンジンが直接消費するわけではない。

---

## 2. LoopSpec YAML 構造

```yaml
loop:
  name: string # 必須。ループの一意識別子（kebab-case）
  trigger:
    type: manual | issue_created | pr_opened | scheduled # 必須
    detail: string # 任意。scheduled 時の cron 等、type の補足
  goal:
    description: string # 必須。このループで達成する目的（自然文）
    exit_criteria_ref:
      string # 必須。merge-ready 到達条件の参照先
      # （00_concept.md §3.3 の DoD、または個別 plan の AC）
  context:
    include: # 必須（最低1件）。持ち込む情報の種類（internal（正本・生成 memory 由来）専用）
      - string # 例: related_issue / design_docs / diff / test_results
    exclude: # 必須（空配列可、ただし明示は必須）
      - string # 例: stale_tool_outputs / irrelevant_history
    external_sources: # 必須（空配列可、ただし明示は必須）
      - string # 例: "issue#NNN 本文" / "PR#NNN コメント" / "外部レビュー生テキスト"
  scope:
    allowed_paths: # 必須（最低1件）。このループ実行が変更してよいパス（glob）
      - string # 例: "docs/ai/ai-loop/**"。宣言外への変更は exec 差し戻し（I-9）
        # boundary 自己判定の根拠には ho-paths.md「原則 1（Phase 1 定義 / #807）」を
        # 引用する（旧「Phase 0 限定の例外」は #739 で置換済み・引用しない）
  actors:
    maker: string # 必須。生成側の識別子（例: implementation_agent）
    checker: string # 必須。maker と異なる主体でなければならない（I-2）
  verification:
    deterministic: # 必須（最低1件）。機械検証コマンド（構造化 — F-18/Run-006）
      - cmd: string # 純粋なシェルコマンド（注記・期待値を混ぜない。そのまま実行可能）
        expect_exit: int # 任意。期待 exit code（既定 0）
        note: string # 任意。人間可読の注記（期待値の要点・AC 対応。実行には使わない）
    review: # 必須（最低1件）。裁定・レビュー観点
      - string # 例: requirements_fit / architecture_consistency / security_risk
  stopping_rule:
    terminal_state_ref:
      string # 必須。参照先固定: decision-table.md（AUTO_APPROVED /
      # HUMAN_ESCALATED / BLOCKED の3値）
    round_limit_ref:
      string # 必須。参照先固定: execution-runbook.md §2-(7) Scheduling 判断表（上限3）
      # LoopSpec 内で数値を再定義しない（正本の断片化防止）
  memory:
    write: # 必須（最低1件）。書き込む記録の種類
      - string # 例: decision_record / rejected_options / unresolved_risks
    ref:
      string # 必須。decision record の実体正本の参照先
      # （保存の正本: execution-runbook.md §2-(4) / L4 学習側: review-feedback-loop.md）
  escalation:
    touches_ho: unconditional # 固定値。touches-HO は無条件 escalate（I-1/I-8、変更不可）
    budget_ref: string # 必須。参照先固定: arbiter-policy.md §7（escalate 予算）
```

---

## 3. フィールド定義（必須 / 任意 / 既定値）

| フィールド                                      | 必須/任意                 | 既定値（未指定時）                                                   | 説明                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ----------------------------------------------- | ------------------------- | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `loop.name`                                     | 必須                      | なし（欠落は起票拒否）                                               | ループの一意識別子                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `loop.trigger.type`                             | 必須                      | なし                                                                 | `manual` / `issue_created` / `pr_opened` / `scheduled` の4値                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `loop.trigger.detail`                           | 任意                      | 空                                                                   | scheduled 時の実行条件補足                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `loop.goal.description`                         | 必須                      | なし                                                                 | 自然文での目的記述                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `loop.goal.exit_criteria_ref`                   | 必須                      | なし（**安全側**: 未指定は closed loop 扱い不可＝polling 扱い、I-4） | merge-ready 到達条件の参照先                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `loop.context.include`                          | 必須（1件以上）           | なし                                                                 | 持ち込む情報の種類の列挙                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `loop.context.exclude`                          | 必須（0件可だが明示必須） | 空配列でも明示要                                                     | stale 情報の除外を宣言的に強制する（黙示の「見せない」を許さない）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `loop.context.external_sources`                 | 必須（0件可だが明示必須） | 空配列でも明示要                                                     | 外部入力由来の出典を**別リストで明示宣言**する（exclude と同じ「黙示を許さない」I-4 型）。**転記規律**: external_sources の内容は memory（`decision_record` / `plan_memory` / `run_frictions` — `loop.memory.write` の値表記と一致）へ**直接転記せず、出典つき引用（URL/ID + 引用範囲）として記録する**（F-14 の証跡規律に接続。W チェック Model B の検査対象）。**internal / external の判定に迷う場合は external 側に倒す（I-4）**。過去の run 記録・frictions に出典つき引用として記録済みの外部テキストは internal（生成 memory 由来）として扱ってよいが、生テキストの再持ち込みは external として再宣言する。同一情報源を exclude と external_sources の両方に書いた場合は **exclude が優先**（見せない > 見せるが隔離） |
| `loop.scope.allowed_paths`                      | 必須（1件以上）           | なし（欠落は受理拒否・I-4）                                          | このループ実行が変更してよいパスの glob 列挙。enforcement: maker への Expected Diff 指示 + 統合検証の `git diff --name-only` 突合。**boundary（touches-HO 判定）は本フィールドと独立に全変更へ適用** — allowed_paths に HO パスを書いても escalate は免れない（I-1）。glob の表記は ho-paths.md の既存慣習（`dir/**` 等）に従う                                                                                                                                                                                                                                                                                                                                                                                               |
| `loop.actors.maker`                             | 必須                      | なし                                                                 | 生成側識別子                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `loop.actors.checker`                           | 必須                      | なし（**maker と同一値は不可**。I-2 違反として拒否）                 | 検証側識別子                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `loop.verification.deterministic`               | 必須（1件以上）           | なし                                                                 | 構造化された機械検証コマンドの列挙（下記 3 サブフィールド）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `loop.verification.deterministic[].cmd`         | 必須                      | なし                                                                 | 純粋なシェルコマンド。そのまま実行可能・注記や期待値を混ぜない。F-12/F-14 規律（実機事前検証・証跡）は本フィールドに適用                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `loop.verification.deterministic[].expect_exit` | 任意                      | 0                                                                    | 期待 exit code。**count ≥ N 型の判定は cmd 内で exit code に畳み込む**（例: `test "$(grep -cF x f)" -ge 2`。`grep -c` 単体は件数 1 でも exit 0 になる footgun に注意）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `loop.verification.deterministic[].note`        | 任意                      | 空                                                                   | 人間可読注記（AC 対応の説明）。実行には使わない                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `loop.verification.review`                      | 必須（1件以上）           | なし                                                                 | レビュー観点列挙                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `loop.stopping_rule.terminal_state_ref`         | 必須                      | なし                                                                 | decision-table.md への参照固定                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `loop.stopping_rule.round_limit_ref`            | 必須                      | なし                                                                 | execution-runbook.md §2-(7) への参照固定（数値の再定義禁止）                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `loop.memory.write`                             | 必須（1件以上）           | なし                                                                 | 保存する記録種別                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `loop.memory.ref`                               | 必須                      | なし                                                                 | execution-runbook.md §2-(4)（decision record 保存の正本）への参照固定。L4 学習側は review-feedback-loop.md                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `loop.escalation.touches_ho`                    | 固定値 `unconditional`    | `unconditional`（変更不可）                                          | I-1/I-8 に基づく絶対条件。LoopSpec が上書きすることは許容しない                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `loop.escalation.budget_ref`                    | 必須                      | なし                                                                 | arbiter-policy.md §7 への参照固定                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

cost cap フィールドは設けない — enforcement 不在の宣言フィールドを作らない（#749 で enforcement 設計と同時に検討する）。

**external_sources 規律の残余リスク（既知の限界）**: 本機構は宣言された external_sources のみを対象とする。宣言し忘れた外部入力（exec 中の web / gh 読取等）は本機構の検査対象外であり、maker の誠実申告と checker の突合という多層防御を前提とする（F-17 と同族の限界。完全な遮断は L3 のサンドボックス設計で扱う）。checker の機械的検査は逐語（または高一致率）コピーの検出に限られる。**言い換え転記**（意味を保ち字面を変えた転記）と、引用再利用か再フェッチかの provenance の真偽は checker では判別できず、**maker の誠実申告に依存する**（F-17 と同族の限界）。本機構は「宣言と逐語検査で捕捉できる汚染」を減らすものであり、それ以上の保証を主張しない。

**安全側デフォルト（I-4 の適用）**: 上記「必須」フィールドが欠落・空・判定不能な LoopSpec は
**closed loop として受理せず、Arbiter 統治外での実行も許可しない**（human へ差し戻す）。
「scheduled repetition（polling）として実行してよい」という意味では**ない** —
分類（design-philosophy.md §5）は polling 相当だが、扱いは差し戻し一択である。

deterministic の各コマンドは、計画時に**実機で PASS/FAIL 両方向**（PASS する入力と FAIL する入力の双方）の挙動を確認してから AC に採用する。環境差 — BSD/GNU 等 — でサイレントに空を返す・ハードエラーになるコマンドの混入を防ぐ（実例: Run-003 R1/R2・Run-004 R1）。

ログ・台帳系の AC は厳密形を用いる — ID 収録は表行限定（行頭 `^\| ID` 一致）、
append-only の不変検証は**基準コミット比の削除行ゼロ**（部分一致・ステージング依存の
偽陽性を防ぐ。F-28）。

Round 改訂で deterministic の AC を変更した場合は、文章宣言だけで置換せず、
機械可読な consolidated deterministic ブロック（最終確定 AC）を新節として追記し、
maker・検証者はそのブロックのみを実行する（旧ブロックの遡及編集はしない —
監査記録不変。実例: Run-012 R3 C 指摘 / Run-013）。
PASS 方向の実測は AC の閾値・条件そのもの（要求する件数・複合条件を満たす入力）で
行う（要求水準未満のサンプルでの PASS 申告は事前検証にならない。実例: Run-012 F-29）。

grep -F 型 AC の PASS 方向事前検証は、**実際の挿入フォーマット**（行折り返し・
インデントを含む最終挿入形そのもの）で行う（サンプル文字列の形式差がアンカー句を
跨ぐことによる偽 PASS/偽 FAIL を防ぐ — F-39。Run-018 exec の AC-2 一時 FAIL が実例）。

件数上限・件数一致型の AC（`wc -l` 等の集計結果を test で比較する形）は、
**前段コマンドの成功**を `&&` で担保してから集計する（前段が失敗すると空出力 = 0 件
として偽 PASS する silent pass を防ぐ — F-41。Run-020 AC-4 への外部レビュー指摘が
起点・実害未発生のうちの予防的正本化）。

AC の転記は**実行履歴からのコピー**とする — 実測に使ったコマンド文字列を
そのまま `cmd` へ転記し、手書き整形・等価に見える別形への書き換え（例:
`test` 比較を `diff` 形へ）をしない。転記形は実行形と乖離した時点で未検証に
戻る（実例: Run-015 F-35 — `| diff - /dev/stdin <<<` への手書き変換が
here-string の stdin 上書きにより常時 exit 0 の検証不能形となった）。
同規律は AC コマンドに限らず、**出典 ID・commit SHA・ファイルパス・issue/PR 番号
等の機械的参照値全般**に適用する — 記憶からの手書き転記を禁じ、実測出力
（API 応答・コマンド出力）からコピーする（実例: Run-016 R2 — 実在しない
レビューコメント ID の手書き転記を W チェック Model B が検出。F-37）。

また、『実機で確認した』という申告には**実行出力（コマンドと結果）の貼付**を必須とする。証跡のない事前検証申告は未検証として扱う（実例: Run-004 R1 — 申告のみで未検証だった AC が W チェックで exit 2 を実機再現され虚偽と判明）。

本規律は構造化後の `cmd` フィールドに適用される（`note` は実行対象外）。

---

## 4. 記入例（ai-loop PoC の docs-only ループ）

```yaml
loop:
  name: docs-only-typo-fix-loop
  trigger:
    type: issue_created
    detail: "labels: docs-only かつ ai-loop-eligible"
  goal:
    description: "docs/ 配下の typo・リンク切れを検知し修正 PR を作る"
    exit_criteria_ref: "00_concept.md §3.3（merge-ready = DoD 状態）"
  context:
    include:
      - related_issue
      - design_docs
      - diff
      - test_results
    exclude:
      - stale_tool_outputs
      - irrelevant_history
    external_sources: []
  scope:
    allowed_paths:
      - "docs/**"
  actors:
    maker: implementation_agent
    checker: review_agent
  verification:
    deterministic:
      - cmd: "markdownlint docs/**/*.md"
        expect_exit: 0
        note: "全 docs 配下の markdownlint エラー 0 件"
      - cmd: 'test "$(scripts/check-links.sh docs/ | grep -cF ''BROKEN'')" -eq 0'
        expect_exit: 0
        note: "リンク切れ 0 件（count 型は cmd 内 test で exit code に畳み込み）"
    review:
      - requirements_fit
      - architecture_consistency
  stopping_rule:
    terminal_state_ref: "decision-table.md（AUTO_APPROVED/HUMAN_ESCALATED/BLOCKED）"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write:
      - decision_record
      - rejected_options
      - unresolved_risks
    ref: "execution-runbook.md §2-(4)（L4 学習側: review-feedback-loop.md）"
  escalation:
    touches_ho: unconditional
    budget_ref: "arbiter-policy.md §7"
```

---

## 5. 「LoopSpec を満たさない反復は closed loop と呼ばない」

design-philosophy.md I-6 は closed loop の定義を
`adaptive-production-loop.md §4` の 1 サイクル contract（**Goal / Evaluate / Stop /
Memory / Schedule / Boundary** の6要素）に一本化している。LoopSpec は、この6要素を
**実行前に宣言として書き下す** ための構造であり、両者は以下のように対応する
（contract 自体を再定義するものではない）。

| adaptive-production-loop.md §4 contract                | LoopSpec 上の対応フィールド                                                                      |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Goal（merge-ready 到達条件が明示）                     | `loop.goal.description` + `loop.goal.exit_criteria_ref`                                          |
| Evaluate（C-1/C-2/C-3'/CI/AI review/DoD の判定点）     | `loop.verification.deterministic` + `loop.verification.review`                                   |
| Stop（terminal state がある）                          | `loop.stopping_rule.terminal_state_ref` + `loop.stopping_rule.round_limit_ref`                   |
| Memory（decision record 等の保存）                     | `loop.memory.write` + `loop.memory.ref`                                                          |
| Schedule（次アクションの優先順位・retry 上限）         | `loop.stopping_rule.round_limit_ref`（Budget は Stop/Schedule に内包。design-philosophy.md I-6） |
| Boundary（policy/HO/C-4 merge を AI が自己変更しない） | `loop.escalation.touches_ho`（固定値）+ `loop.escalation.budget_ref`                             |

したがって: **LoopSpec の必須フィールドが1つでも欠落・空である反復は、
adaptive-production-loop.md §4 の contract を満たさない ＝ closed loop ではなく
scheduled repetition（polling）である**（design-philosophy.md §5 語彙集）。

`loop.actors.maker` と `loop.actors.checker` が同一主体を指す LoopSpec は、
6要素を満たしていても I-2（maker-checker 分離）違反として別途拒否する
（closed loop の要件と maker-checker 分離は独立した必要条件であり、
片方を満たしても他方の違反を免れない）。

---

## 6. provenance schema との整合注記

LoopSpec と `decision-table.md` §5 の provenance schema は**別レイヤーの記録**であり、
統合や置換の対象ではない。

|          | LoopSpec             | provenance（decision-table.md §5）  |
| -------- | -------------------- | ----------------------------------- |
| 時点     | ループ開始前の宣言   | 各サイクルの裁定確定時に刻印        |
| スコープ | 1 ループ全体の境界   | 1 回の裁定（auto-approve 等）の根拠 |
| 変更頻度 | ループ定義変更時のみ | サイクルごとに新規生成              |
| 正本     | 本書                 | decision-table.md §5                |

対応点は `policy_ref`（provenance）が LoopSpec のどの宣言に基づくかを追跡できることのみで、
LoopSpec 自体が provenance フィールドを持つ設計にはしない（二重定義の回避、
design-philosophy.md §7「同じ問いに2つのファイルが答えてはならない」に従う）。
将来 LoopSpec を機械検証する場合は、`policy_ref` の値として `loop.name` を採用する
運用を推奨するに留める（本書は仕様であり、実装は別途）。

---

## 7. issue #726 AC との対応（充足マッピング）

本書で直接定義しなかった #726 の論点は、以下の既存正本で充足または follow-up とする:

| #726 の論点                          | 充足先                                                                                                                                                                   |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Handoff Artifact テンプレート        | PlanGate 既存の handoff 正本（`.claude/rules/working-context.md` Rule 5 / `docs/working/templates/handoff.md`）を参照。LoopSpec では再定義しない                         |
| no-progress detector                 | 実体は Scheduling 判断表の「同型指摘の再発 → Optimize 送り」+ ラウンド上限 3（`execution-runbook.md` §2-(7)）。独立した detector 化は follow-up 候補（効果測定後に判断） |
| deterministic / LLM judge の使い分け | `loop.verification.deterministic`（機械検証）と `loop.verification.review`（裁定・レビュー観点）の二分で表現。judge 側の詳細正本は W チェック（`flow-detect.md` §3）     |

## 8. 関連ドキュメント

- [`../../ai/ai-loop/design-philosophy.md`](../../ai/ai-loop/design-philosophy.md) — 第一原理（I-1〜I-9）・語彙集・§8 トリアージ正本
- [`adaptive-production-loop.md`](./adaptive-production-loop.md) §4 — 1 サイクル contract 正本（closed loop の定義）
- [`decision-table.md`](./decision-table.md) §5 — provenance schema 正本
- [`execution-runbook.md`](./execution-runbook.md) §2-(7) — Scheduling 判断表・ラウンド上限（正本値）
- [`flow-detect.md`](./flow-detect.md) — maker/checker 分離（W チェック）の判定フロー正本
- [`review-feedback-loop.md`](./review-feedback-loop.md) — decision record の実体正本
- [`../../ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §7 — escalate 予算正本
- issue [#726](https://github.com/s977043/plangate/issues/726) — 本書の起点
