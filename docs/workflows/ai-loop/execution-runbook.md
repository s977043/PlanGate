# execution-runbook — L2 裁定エンジン PoC 実行手順

> 適用ドメイン: ai-loop-workflow（docs/workflows/ai-loop/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）
> 実装本体: [`scripts/ai-loop/arbiter.py`](../../../scripts/ai-loop/arbiter.py)
> テスト: [`scripts/ai-loop/test_arbiter.py`](../../../scripts/ai-loop/test_arbiter.py)

---

## 1. 目的

`docs/workflows/ai-loop/decision-table.md` / `flow-detect.md` / `lite-criteria.md` /
`docs/ai/ai-loop/ho-paths.md` に定義された flow→detect→escalate 判断ロジックを、
`scripts/ai-loop/arbiter.py`（L2 裁定エンジン PoC）を用いて 1 サイクル実行する
手順を定義する。

**制約（絶対）**: 本エンジンは PlanGate 本番フロー（WF-00〜WF-07・`bin/plangate`・
`scripts/hooks/`）から一切呼ばれない**隔離 PoC**である。W チェック（Model A/B/C/D
の verdict）の**品質そのもの**は L1（本 runbook を実行する呼び出し側）の責務であり、
`arbiter.py`（L2）は入力された verdict を決定論ロジックで裁定するのみで、verdict
自体の正しさを検証しない。

---

## 2. 1 サイクルの手順

**前提**: 本サイクルは **C-1 PASS・C-2 完了済み**であることを起点とする
（C-3' ゲートとしての位置づけ。[`00_concept.md`](./00_concept.md) §3 参照）。

### (1) 変更ファイルリスト取得

```sh
git diff --name-only <base>...<head>
```

対象コミット（`target_sha`）の変更ファイル一覧を取得する。

### (2) Model A / Model B による W チェック（サブエージェント 2 体・独立実行）

- **Model A**（順方向・設計妥当性）: 変更が「正しく作られているか」を検証する
  サブエージェントを起動し、`approve` / `reject` の verdict を得る
- **Model B**（逆方向・adversarial）: 変更が「どう壊れるか」を検証する
  サブエージェントを、Model A とは**独立**に起動し、`approve` / `reject` の
  verdict を得る
- Model B が `reject` の場合、reject 理由から `reject_category` を決定論
  マッピング（[`flow-detect.md`](./flow-detect.md) §3.2.1）に照合可能な
  カテゴリ文字列で記録する（`ho_path_contact` / `permission` / `irreversible` /
  `security_break` / `public_api` / `data_integrity` / `migration` /
  `auth_change` / `logic` / `performance` / `test_shortage` / `documentation` /
  `format` / `naming` のいずれか。一致しない場合は分類器側で `critical` 扱いに
  フォールバックされる）
- severity=minor/low の不一致時は Model C（セキュリティ・認証・権限観点）/
  Model D（後方互換・データ整合観点）も同様に独立起動する
  （[`flow-detect.md`](./flow-detect.md) §3.3）

### (3) `arbiter.py` へ入力し裁定を得る

Model A/B（必要なら C/D）の verdict と、boundary/lite/class 判定に必要な
情報を JSON にまとめ、`arbiter.py` へ渡す。

```sh
python3 scripts/ai-loop/arbiter.py --input /path/to/input.json
# または stdin 経由:
echo '{...}' | python3 scripts/ai-loop/arbiter.py
```

入力 JSON のフィールド仕様は [`arbiter.py`](../../../scripts/ai-loop/arbiter.py)
モジュール docstring および [`decision-table.md`](./decision-table.md) §2・§5 を
正本とする。

### (4) decision record を保存

`arbiter.py` の stdout（decision record JSON）を、以下の命名規則で保存する。

> **正本性の注記**（[`decision-table.md`](./decision-table.md) §5 PoC スコープと整合）:
> `AUTO_APPROVED` の record のみが **provenance 刻印**（正本）。
> `HUMAN_ESCALATED` / `BLOCKED` の record は **audit record（暫定）**であり、
> 正式な audit trail の定義は Phase 3 以降で行う。

```text
docs/working/ai-loop-runs/<UTC日時: YYYYMMDDTHHMMSSZ>-<sha7>.json
```

```sh
mkdir -p docs/working/ai-loop-runs
python3 scripts/ai-loop/arbiter.py --input /path/to/input.json \
  > "docs/working/ai-loop-runs/$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD).json"
```

保存した decision record は次回以降の監査・L4 学習（[`review-feedback-loop.md`](./review-feedback-loop.md)）
の入力となる。

### (5) exit code に応じた分岐

| exit code | decision          | 動作                                                                                                                       |
| --------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `0`       | `AUTO_APPROVED`   | 自動承認として扱う。provenance 刻印（正本）を保存して 1 サイクル完了                                                       |
| `2`       | `HUMAN_ESCALATED` | **停止して人間へ escalate**。audit record（暫定）の `w_check` / `boundary_check` / `lite_check` を提示し、人間の判断を仰ぐ |
| `3`       | `BLOCKED`         | ブロックとして扱う。当該変更を採用しない。audit record（暫定）を保存し、理由（stderr の裁定サマリ）を記録する              |
| `1`       | （入力エラー）    | 入力 JSON の不備。stderr の理由メッセージに従い入力を修正して再実行する                                                    |

### (6) 強化セルフレビュー（PR 作成前・必須）

`AUTO_APPROVED`（exit code `0`）で exec / L-0 / V 系が完了した後、PR 作成前に
**強化セルフレビュー**を実施する（merge-ready 責務の担保。
[`00_concept.md`](./00_concept.md) §3.4 参照）:

1. **宣言↔実差分の整合検証**: plan の Files to Touch と
   `git diff --name-only <base>...HEAD` を突合し、宣言外の変更がゼロであることを確認する
   （宣言外変更あり → exec 差し戻し or C-3' 再裁定）
2. self-review スキル（Phase 1〜13 全観点）を実行する
3. [`plan-review-readiness-gate.md`](../../ai/plan-review-readiness-gate.md)
   §7/§8 観点を通す
4. [`review-feedback-loop.md`](./review-feedback-loop.md) §2 で過去に還元済みの
   観点（過去の CI 失敗・AI レビュー指摘から抽出されたチェック項目）を通す

全観点 PASS を確認してから PR を作成する。FAIL がある場合は exec へ差し戻す。

### (7) PR 後の CI / AI レビュー指摘対応ループ（merge-ready まで）

PR 作成後、以下を **merge-ready 到達まで**繰り返す:

1. CI 実行結果を確認する。FAIL があれば修正し再度 (6) を通してから push する
2. **コンフリクトを確認する**（`gh pr view <n> --json mergeable` が `CONFLICTING`）。
   スタック PR の前段 squash マージ起因の場合は、固有コミットのみを
   `git rebase --onto origin/main <旧base> <branch>` で main に載せ替え、
   三点照合（`git branch -vv`・SHA 同定）のうえ `--force-with-lease` で push する。
   push 直後の mergeable は再計算中の場合があるため数十秒後に再確認する
3. CI/PR 時の AI レビュー指摘を確認する。各指摘について
   **採用して修正**するか、**理由付きで不採用とする**かを記録する
4. 対応内容（採用/不採用・理由）は
   [`review-feedback-loop.md`](./review-feedback-loop.md) §2 の L4 学習閉ループへ
   還元し、次回の強化セルフレビュー（手順 (6)）で事前に捕捉されるようにする
5. **収束ルール**: 対応ラウンド上限は 3。超過時は human escalate
   （[`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §7 escalate 予算
   と接続）。新規指摘が minor / info のみになった時点で、記録を条件に
   merge-ready 判定へ進んでよい（[`00_concept.md`](./00_concept.md) §3.3）
6. **DoD**: CI 全 job green **かつ** AI レビュー指摘がゼロ、または全件対応完了
   （採用/理由付き不採用の記録あり）で merge-ready と判定し、C-4（人間の
   merge 承認、Human-owned 固定）待ちに遷移する

### Scheduling 判断表（次アクション優先順位）

> 本節は issue #709（6 層自己改善ループ: Generate → Evaluate → Remember →
> Schedule → Optimize → Recurse）AC-5 / AC-6 に対応する。**Schedule**
> （1 ラウンドの観測結果から「次に何をするか」を選ぶ独立責務）の PoC 定義
> であり、手順 (5) の exit code 分岐・手順 (7) の収束ルールを**再定義せず**、
> 両者を判断材料として使う判断表を追加する。上位の 6 層モデルとの対応関係の
> 正本は [`adaptive-production-loop.md`](./adaptive-production-loop.md) を参照。

手順 (7) の PR 後ループにおいて、1 ラウンドの観測結果（CI 結果 / コンフリクト
有無 / AI レビュー指摘 / severity 分類）から次に取るアクションを、以下の優先
順位で選択する。上位の条件に該当すればそれを実行し、該当しない場合のみ
下位へ進む。

| 優先順位 | 次アクション                    | 選択条件                                                                                                                      | 参照                                                                                                                    |
| -------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 1        | **fix CI**                      | CI が FAIL している                                                                                                           | 手順 (7)-1                                                                                                              |
| 2        | **address AI review**           | CI は green だが未対応の AI レビュー指摘がある                                                                                | 手順 (7)-3                                                                                                              |
| 3        | **re-run enhanced self-review** | fix CI / address AI review で差分に変更を加えた                                                                               | 手順 (6) 強化セルフレビュー                                                                                             |
| 4        | **update suppression**          | AI レビュー指摘が誤検知と判定され、理由付き不採用として登録する対象である                                                     | [`review-feedback-loop.md`](./review-feedback-loop.md) §5 登録済み suppression                                          |
| 5        | **escalate to human**           | 対応ラウンド上限超過、または severity=critical/major の不一致、または boundary=touches-HO / policy 還元 / C-4 merge に該当    | 手順 (7)-5・[`flow-detect.md`](./flow-detect.md) §4.1・[`ho-paths.md`](../../ai/ai-loop/ho-paths.md)                    |
| 6        | **stop・block**                 | Model A/B（必要なら C/D）が合意でブロック、またはサーキットブレーカー発火、または human escalate の結果として不採用が確定した | [`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §4.1・§4.3・§8・[`decision-table.md`](./decision-table.md) §5 |

**retry / round 上限**: 手順 (7)-5 の収束ルール（対応ラウンド上限 3）をそのまま
継承し、本判断表はこの上限を緩和・変更しない。優先順位 1〜4 の実行 1 巡
（CI 修正・AI レビュー対応の 1 往復）を 1 ラウンドと数える。

**queue 対象**: Schedule が扱うキューは以下の 4 種類とする。優先順位表は
主に「current PR loop」内の順序制御であり、他 3 キューは非同期・低頻度で
処理してよい。

| キュー               | 内容                                                                                           | 処理タイミング                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| current PR loop      | 手順 (7) の CI / AI レビュー対応そのもの                                                       | 即時（優先順位 1〜3）                                                                              |
| review feedback loop | [`review-feedback-loop.md`](./review-feedback-loop.md) §2 の L4 学習閉ループへの還元           | PR ごとに 1 回、手順 (7)-4 のタイミングで投入                                                      |
| memory hygiene       | decision record（`docs/working/ai-loop-runs/*.json`）・suppression 登録の重複 / 陳腐化の棚卸し | 非同期・低頻度（本 PoC では実施手順を定義せず、実施要否のみをキューに積む。具体化は Phase 4 以降） |
| suppression update   | [`review-feedback-loop.md`](./review-feedback-loop.md) §5 への誤検知パターン追記               | 優先順位表 4「update suppression」実行時                                                           |

**自動継続できる条件 / human escalate へ切り替える条件**:

| 条件                                                                          | 判定                                                                                                                                    |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| exit code `0`（`AUTO_APPROVED`）かつ CI green かつ AI レビュー指摘なし/対応済 | 自動継続可（merge-ready 判定へ、手順 (7)-6）                                                                                            |
| CI FAIL または未対応 AI レビュー指摘あり、かつ対応ラウンドが上限（3）内       | 自動継続可（優先順位 1〜4 を実行）                                                                                                      |
| 対応ラウンド上限（3）超過                                                     | **human escalate 固定**（手順 (7)-5）                                                                                                   |
| severity=critical/major の W チェック不一致                                   | **human escalate 固定**（[`flow-detect.md`](./flow-detect.md) §4.1）                                                                    |
| boundary=touches-HO                                                           | **human escalate 固定**（W チェック結果に関わらず。[`ho-paths.md`](../../ai/ai-loop/ho-paths.md)）                                      |
| policy（auto-approve 条件・裁定ルール）への還元が必要と判定                   | **human escalate 固定**（第0の承認境界。[`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §6）                                  |
| C-4（merge）到達                                                              | **human escalate 固定**（Human-owned。本ドキュメント §4・[`working-context.md`](../../../.claude/rules/working-context.md) C-4 ゲート） |

boundary=touches-HO / policy 還元 / C-4 merge の 3 条件は、対応ラウンド数や
severity 分類の結果にかかわらず**常に** human escalate へ切り替える絶対条件
であり、Schedule はこれらを自動継続候補として扱わない（AC-6）。

**stop・block 条件**:

- Model A/B（必要なら C/D）が揃って `reject` で合意した場合
  （[`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §4.1・§4.3
  「合意 → ブロック」）
- サーキットブレーカーが発火した場合（[`decision-table.md`](./decision-table.md) §5）
- human escalate の結果、人間が当該変更の不採用を判断した場合（audit record
  を保存し、当該変更は採用せずに 1 サイクルを終了する。手順 (5) `BLOCKED`
  相当）

stop・block は「次のアクションを選ばない」終端状態であり、当該サイクルは
ここで完結する（Recurse へは進めず、次サイクルへの入力は
[`adaptive-production-loop.md`](./adaptive-production-loop.md) の Recurse 条件
に従う）。

> **不変条件（AC-6 / AC-7）**: 本判断表がどのように次アクションを選んでも、
> **policy 制定・boundary=touches-HO・C-4（merge）の 3 点は Human-owned
> 固定のまま変更しない**。Schedule はサイクルの進行順序を決める責務に
> 留まり、承認境界そのものを自己変更・自己承認する経路を持たない。

---

## 3. 検証可能性 4 条件への適合

[`orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) §検証可能性
の 4 条件に対する `arbiter.py` の適合状況:

| 条件                 | 適合内容                                                                                                                                                                   |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **冪等性**           | 同一入力 JSON に対し `decision` は常に同一（`ProvenanceSchemaTests.test_auto_approve_provenance_fields` で検証。`timestamp` のみ実行毎に変化するが裁定結果には影響しない） |
| **明示的失敗**       | 入力エラー（exit code 1）は必ず理由メッセージを stderr に出力する（`[arbiter] 入力エラー: <理由>`）                                                                        |
| **トレーサビリティ** | boundary 判定で HO パターンに一致した場合、一致パス・パターン・分類を理由サマリ（stderr）に含める                                                                          |
| **テスト可能性**     | `test_arbiter.py`（59 ケース）で decision table 全 priority・severity 全分類・C/D 全パターン・AC-8 安全側・boundary 全パターン・ho-paths.md との drift を機械的に検証可能  |

---

## 4. 制約の明記

- 本エンジンは PlanGate 本番フロー（WF-00〜WF-07・`bin/plangate`・
  `scripts/hooks/`）から一切呼ばれない**隔離 PoC**である
  （[`docs/ai/ai-loop/phase3-impact-report.md`](../../ai/ai-loop/phase3-impact-report.md) §b.1
  トリガー 1 の判断記録を参照）
- W チェック（Model A/B/C/D）の verdict 品質は **L1（本 runbook を実行する
  呼び出し側）の責務**。`arbiter.py`（L2）は入力された verdict の内容が
  正しいかどうかを検証しない（決定論ロジックの適用のみ）
- boundary=touches-HO は W チェック結果・severity 分類・C/D 裁定の**すべて
  をスキップする絶対条件**（[`ho-paths.md`](../../ai/ai-loop/ho-paths.md) 判定ルール）
- provenance の `issued_by` は自己申告であり、署名等の発行元検証機構は
  本 PoC のスコープ外（[`phase3-impact-report.md`](../../ai/ai-loop/phase3-impact-report.md) §d
  リスク 5、issue #420 EH-3 発行元検証と同型の未解決課題）

---

## 5. 関連ドキュメント

- [`docs/workflows/ai-loop/decision-table.md`](./decision-table.md) — Decision table・provenance schema・CB
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — flow→detect→escalate 動作フロー
- [`docs/ai/ai-loop/ho-paths.md`](../../ai/ai-loop/ho-paths.md) — boundary=touches-HO 判定の正本
- [`docs/ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) — Arbiter L0 policy
- [`docs/ai/ai-loop/phase3-impact-report.md`](../../ai/ai-loop/phase3-impact-report.md) — 分離トリガー条件・判断記録
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) — CB-1 事後 reject / CI・AI レビュー指摘対応を L4 学習へ還元する閉ループ
- [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) — 検証可能性 4 条件の正本
- [`docs/workflows/ai-loop/00_concept.md`](./00_concept.md) §3 — PlanGate フロー共通化と C-3 置換（C-3'）・merge-ready 責務範囲の正本
- [`docs/workflows/ai-loop/adaptive-production-loop.md`](./adaptive-production-loop.md) — 6 層自己改善ループ（Generate → Evaluate → Remember → Schedule → Optimize → Recurse）の正本。本 runbook の Scheduling 判断表はこの Schedule 層の PoC 実装
- [`docs/ai/plan-review-readiness-gate.md`](../../ai/plan-review-readiness-gate.md) — 強化セルフレビュー §7/§8 観点の参照元
- [`.claude/skills/ai-loop-cycle/SKILL.md`](../../../.claude/skills/ai-loop-cycle/SKILL.md) — 本 runbook の 1 サイクルを実行する手順スキル（Model A/B/C/D 委託プロンプト定型）
- [`.claude/skills/pr-watch/SKILL.md`](../../../.claude/skills/pr-watch/SKILL.md) — 手順 (7) の CI/AI レビュー指摘対応ループの監視・対応定型
