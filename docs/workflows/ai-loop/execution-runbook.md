# execution-runbook — L2 裁定エンジン PoC 実行手順

> 適用制限（Phase 1 rollout eligibility）の正本: [`rollout-policy.md`](./rollout-policy.md)
> 実装本体: [`scripts/ai-loop/arbiter.py`](../../../scripts/ai-loop/arbiter.py)
> テスト: [`scripts/ai-loop/test_arbiter.py`](../../../scripts/ai-loop/test_arbiter.py)

---

## 0. 導入先での開始手順（Phase 1）

導入先リポジトリで ai-loop-workflow を初めて回す際の手順（詳細は各正本を参照。
本節は要点のみ）:

1. **ho-paths を導入先で確定する**: 導入先プロジェクト自身の HO 境界を
   `docs/ai/ai-loop/ho-paths.md`（plugin 導入先は `references/ho-paths.md`）の
   雛形ヘッダ（同梱版に前置される「本ファイルは...配布時の参考例」注記）を
   参照しつつ、導入先固有のパス一覧として定義する。未確定のまま run を
   開始してはならない（規範。`arbiter.py` は `--ho-paths` 明示指定 → CWD →
   スクリプト位置基準の順で実行時解決し、未確定・パース結果 0 件時は
   全件 human escalate する fail-closed を実装済み — #809）
2. **LoopSpec に `scope.allowed_paths` を宣言する**: [`loopspec.md`](./loopspec.md)
   の既存必須フィールドで、当該 run の変更可能範囲を明示する
3. **初回 run は escalate 前提で回す**: 導入初回は W チェック・境界判定の
   実地確認を優先し、`HUMAN_ESCALATED` への降格を前提に運用する
   （auto-approve の到達は 2 回目以降の検証課題とする）

---

## 1. 目的

`docs/workflows/ai-loop/decision-table.md` / `flow-detect.md` / `lite-criteria.md` /
`docs/ai/ai-loop/ho-paths.md` に定義された flow→detect→escalate 判断ロジックを、
`scripts/ai-loop/arbiter.py`（L2 裁定エンジン PoC）を用いて 1 サイクル実行する
手順を定義する。

**制約（絶対）**: 本エンジンは PlanGate 本番フロー（WF-00〜WF-07・`bin/plangate`・
`scripts/hooks/`）から一切呼ばれない**隔離された実験実装**である（適用制限の正本 = [`rollout-policy.md`](./rollout-policy.md)）。W チェック（Model A/B/C/D
の verdict）の**品質そのもの**は L1（本 runbook を実行する呼び出し側）の責務であり、
`arbiter.py`（L2）は入力された verdict を決定論ロジックで裁定するのみで、verdict
自体の正しさを検証しない。

---

## 2. 1 サイクルの手順

**前提**: 本サイクルは **C-1 PASS・C-2 完了済み**であることを起点とする
（C-3' ゲートとしての位置づけ。[`00_concept.md`](./00_concept.md) §3 参照）。

### 確認カデンス（loop 内は自走・介入点は 2 つ / issue #782 P3）

ai-loop-workflow の哲学は「escalate まで自走・人間はループ上で監督」
（[`00_concept.md`](./00_concept.md) §3.3「人間の関与」行と整合）。
1 サイクル内（LoopSpec 作成 → W チェック → 裁定 → exec → grader）では
**逐次 y/n 確認を行わず自走**する。人間の介入ポイントは以下の **2 点のみ**:

- **(a)** `HUMAN_ESCALATED` に至った時（手順 (5) の arbiter 裁定のほか、
  手順 (5b) grader 再試行上限超過・手順 (7) Scheduling 判断表の escalate を含む）
- **(b)** merge（Human-owned 固定・手順 (7) DoD 後の C-4）

ただし HO パス接触・想定外のスコープ拡大を検知した場合は既存 Iron Law
（`docs/ai/core-contract.md`）に従い即停止する。

### (0) run 採番（起票時 + PR 作成直前の 2 点照合）

run 番号は**起票時**に `git fetch origin` 後、origin/main の
`docs/working/ai-loop-runs/` 一覧
（`git ls-tree --name-only origin/main docs/working/ai-loop-runs/`）と open PR の
使用中ブランチ・記録ファイル
（`gh pr list --state open --json headRefName --jq '.[].headRefName'`）を
照合し、最大番号 +1 を仮採番する。さらに **PR 作成直前に同じ照合を再実行**し、
並行 run による先取（同一パス add/add 衝突）を検出した場合は改番してから
PR を作成する（F-34: 同日 2 回の採番衝突 — Run-013→014→015 の二重改番が実害）。

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

**Plan-first production run（TASK-0872 / issue #872）**: `ai-loop run TASK-XXXX`
から開始した run では、入力 JSON に `production: true` と `plan_package` ブロック
（`scripts/ai-loop/plan_package.py` が presence / evidence / hash を検証して組み立てた
もの）を必ず含める。`production: true` で `plan_package` が欠落・構造不正なら
priority 1.6 で escalate、reviewer snapshot 不一致・source_sha ≠ target_sha は
priority 1.65 で blocked（契約正本: [`c3-prime-contract.md`](./c3-prime-contract.md)）。
再現検証（同一入力 → byte 同一 record）が必要な場合は `--timestamp` で刻印時刻を
固定注入できる。

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

摩擦 ID は台帳（[`run-001-frictions.md`](../../working/ai-loop-runs/run-001-frictions.md)）が単一権威。新しい F-NNN は台帳への
追記と同時にのみ発行する（run 記録・PR 本文のみでの新 ID 発行は不可 —
多セッション並行時の二重採番防止。F-34 と同根・2026-07-08 の F-35〜39 台帳欠落が実例）。
採番前に台帳の最大 ID を確認する（§2-(0) の run 採番照合と同型）。

### (5) exit code に応じた分岐

| exit code | decision          | 動作                                                                                                                       |
| --------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `0`       | `AUTO_APPROVED`   | 自動承認として扱う。provenance 刻印（正本）を保存して 1 サイクル完了                                                       |
| `2`       | `HUMAN_ESCALATED` | **停止して人間へ escalate**。audit record（暫定）の `w_check` / `boundary_check` / `lite_check` を提示し、人間の判断を仰ぐ |
| `3`       | `BLOCKED`         | ブロックとして扱う。当該変更を採用しない。audit record（暫定）を保存し、理由（stderr の裁定サマリ）を記録する              |
| `1`       | （入力エラー）    | 入力 JSON の不備。stderr の理由メッセージに従い入力を修正して再実行する                                                    |

### (5b) exec 差分 rubric チェック（grader 再試行ループ）

`AUTO_APPROVED`（exit code `0`）で exec 完了後・PR 作成前に、maker と独立の
sonnet サブエージェント（**rubric grader**）へ exec 差分を委託する
（手順詳細・rubric 5 項目・委託プロンプト定型は
[`ai-loop-cycle` SKILL.md](../../../.claude/skills/ai-loop-cycle/SKILL.md)
Step 5.5 を正本とし、本節では再定義しない）。

1. maker 差分 + 計画の Goal/確定文言を grader に入力する
2. grader は rubric 5 項目（正確性・正本整合 / 要件適合 / 文体・構造踏襲 /
   境界安全 / 重複定義回避）で判定し、`verdict: pass|fail` /
   `failed_criteria` / `feedback` を 3 行 raw で返す（fail は引用必須）
3. `verdict: fail` → feedback を添えて maker に再試行を委託する。**上限 2 回**
4. 上限超過 → `HUMAN_ESCALATED` として扱い、grader の全出力（引用込み）を
   人間へ提示して停止する
5. `verdict: pass` を確認してから (6) 強化セルフレビューへ進む

### (6) 強化セルフレビュー（PR 作成前・必須）

`AUTO_APPROVED`（exit code `0`）で exec / L-0 / V 系が完了した後、PR 作成前に
**強化セルフレビュー**を実施する（`MERGE_READY` 責務の担保。
[`00_concept.md`](./00_concept.md) §3.4 参照）:

1. **宣言↔実差分の整合検証**: plan の Files to Touch と
   `git diff --name-only <base>...HEAD` を突合し、宣言外の変更がゼロであることを確認する
   （宣言外変更あり → exec 差し戻し or C-3' 再裁定）
2. diff-audit スキル（旧 self-review、Phase 1〜13 全観点）を実行する
3. [`plan-review-readiness-gate.md`](../../ai/plan-review-readiness-gate.md)
   §7/§8 観点を通す
4. [`review-feedback-loop.md`](./review-feedback-loop.md) §2 で過去に還元済みの
   観点（過去の CI 失敗・AI レビュー指摘から抽出されたチェック項目）を通す
5. **実践事実の主張の出典検証**: 計画・run 記録・PR 本文中の「実践済み」「適用済み」等の
   実例主張が、**検証可能な出典**（run 記録・PR・実測出力のいずれか）に紐づくことを
   確認する（記録なき実践主張は削除する — F-38。Run-018 W チェック B の検出が実例）

全観点 PASS を確認してから PR を作成する。FAIL がある場合は exec へ差し戻す。

### (7) PR 後の CI / AI レビュー指摘対応ループ（MERGE_READY まで）

PR 作成後、以下を **`MERGE_READY` 到達まで**繰り返す。

この手順は [`adaptive-production-loop.md`](./adaptive-production-loop.md) の
6 層モデルにおける **Schedule** の実行点である。ただし Schedule は「次に何をするか」を
決めるだけであり、品質評価そのものは CI / AI review / DoD などの Evaluate 層に残す。

#### Scheduling 判断表

| 優先度 | 条件                                                  | 次アクション                                            | 次状態                |
| ------ | ----------------------------------------------------- | ------------------------------------------------------- | --------------------- |
| 1      | boundary=touches-HO / policy 変更 / irreversible 変更 | 停止して human escalate                                 | `HUMAN_ESCALATED`     |
| 2      | 対応ラウンド上限 3 超過                               | 停止して human escalate                                 | `HUMAN_ESCALATED`     |
| 3      | 同型指摘の再発                                        | `review-feedback-loop.md` へ還元し、Optimize 対象へ送る | recurse               |
| 4      | CI failed                                             | CI failure を調査・修正し、(6) を再実行して push        | continue              |
| 5      | merge conflict                                        | conflict 解消、三点照合、lease-protected push           | continue              |
| 6      | critical / major の AI review 指摘あり                | 採用して修正、または理由付き不採用を記録                | continue or escalate  |
| 7      | minor / info のみ                                     | 採用/不採用理由を記録し、DoD 判定へ進む                 | `MERGE_READY` candidate |
| 8      | CI green かつ AI review 全件対応済み                  | C-4 待ちへ遷移                                          | `MERGE_READY`         |

#### 実行手順

1. CI 実行結果を確認する。FAIL があれば修正し再度 (6) を通してから push する
2. **コンフリクトを確認する**（`gh pr view <n> --json mergeable` が `CONFLICTING`）。
   スタック PR の前段 squash マージ起因の場合は、固有コミットのみを
   `git rebase --onto origin/main <旧base> <branch>` で main に載せ替え、
   三点照合（`git branch -vv`・SHA 同定）のうえ lease-protected push で反映する。
   push 直後の mergeable は再計算中の場合があるため数十秒後に再確認する
3. **AI レビューの着弾を確認してから次へ進む**（PR 作成直後は未着弾のことがある —
   着弾前にマージ準備を完了扱いにすると、指摘未対応のままマージされ得る。F-27 の実害経路）。
   CI/PR 時の AI レビュー指摘を確認し、各指摘について**採用して修正**するか、
   **理由付きで不採用とする**かを記録する。**auto-merge は使用しない**
   （2026-07-07 Human 指示）。指摘対応完了（または指摘なしの確認）後に `MERGE_READY` 報告を
   行い、マージは Human が実行する（responsibility-classes: merge は Human-owned）。
4. 対応内容（採用/不採用・理由）は
   [`review-feedback-loop.md`](./review-feedback-loop.md) §2 の L4 学習閉ループへ
   還元し、次回の強化セルフレビュー（手順 (6)）で事前に捕捉されるようにする
5. **収束ルール**: 対応ラウンド上限は 3。超過時は human escalate
   （[`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §7 escalate 予算
   と接続）。新規指摘が minor / info のみになった時点で、記録を条件に
   `MERGE_READY` 判定へ進んでよい（[`00_concept.md`](./00_concept.md) §3.3）
6. **DoD**: CI 全 job green **かつ** AI レビュー指摘がゼロ、または全件対応完了
   （採用/理由付き不採用の記録あり）で `MERGE_READY` と判定し、C-4（人間の
   merge 承認、Human-owned 固定）待ちに遷移する
7. **conflict 解消時の同定規律**: rebase/merge の conflict 解消では、stage 番号
   （`:2:`/`:3:`）や ours/theirs のラベル理解に依存せず、
   **各側の内容の冒頭を実際に表示して同定してから**採用する。解消後は「維持すべき側の
   ファイルが、**その本来の比較基準**（main 側を維持したなら origin/main、
   自ブランチ側を維持したならマージ/リベース前の自コミット）と差分ゼロであること」を
   機械検証する（実例: Run-015 — ラベル依存の解決が inverted となり、
   内容表示による検証で自己検出・是正。F-36）

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
  `scripts/hooks/`）から一切呼ばれない**隔離された実験実装**である
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

### 実行系境界の多層防御 — D2-B は *補助*（TASK-0917 / #917）

手順 (7) を機械実行する Executor（`scripts/ai-loop/executor.py`）の外部作用は
`scripts/ai-loop/gh_exec.py` を**唯一の境界**とし、許可された `gh` サブコマンドの
in-process allowlist を `scripts/ai-loop/check_exec_boundary.py` が AST で機械強制する
（D2-A / AC-5）。**設計上の保証はこの層だけに依存する**。

既存の `scripts/hooks/check-delegation-commit-boundary.sh` と GitHub の branch
protection は **多層防御の補助**として併用してよいが、**設計はこれらに依存しない**。
補助に留める根拠（TASK-0917 plan R-001 / R-031 の 2026-07-31 実測）:

- hook は `PLANGATE_DELEGATION_NOCOMMIT != 1` のとき即 allow する（既定で無効）
- hook は Bash の command 文字列しか見ないため、Python プロセス内から発行される
  作用（本 Executor の経路）を原理的に捕捉しない
- `.claude/settings.json` は `PreToolUse` 未配線（`bin/plangate doctor` の
  `=== Hook Enforcement Wiring ===` が `[FAIL] PlanGate hooks not wired`）。
  配布テンプレ `.claude/settings.example.json` のトップレベルキーは
  `["_comment_", "_usage_", "hooks"]` で **`permissions` キー自体が存在しない**
  （= deny 設定 0 件）
- `.git/hooks/` に非 sample hook は 0 件（`scripts/install-pre-push.sh` 未適用）
- branch protection 側も `required_approving_review_count: 0` のため承認を
  強制していない（issue #928）

**Executor 実行ホストの前提条件**: Executor を回すホストでは
`sh scripts/install-pre-push.sh` を適用し、main 直接 push を技術層で block した
状態にしておくこと（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)
Defense in Depth / TASK-0114）。ただしこれも上記の意味で**補助**であり、AC-5 の
保証を肩代わりしない — 未適用のホストでも Executor 側の allowlist は同じ強度で働く。

---

## 5. 関連ドキュメント

- [`docs/workflows/ai-loop/adaptive-production-loop.md`](./adaptive-production-loop.md) — 6 層自己改善ループと Scheduling / Goal / Evaluate 分離の正本
- [`docs/workflows/ai-loop/decision-table.md`](./decision-table.md) — Decision table・provenance schema・CB
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — flow→detect→escalate 動作フロー
- [`docs/ai/ai-loop/ho-paths.md`](../../ai/ai-loop/ho-paths.md) — boundary=touches-HO 判定の正本
- [`docs/ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) — Arbiter L0 policy
- [`docs/ai/ai-loop/phase3-impact-report.md`](../../ai/ai-loop/phase3-impact-report.md) — 分離トリガー条件・判断記録
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) — CB-1 事後 reject / CI・AI レビュー指摘対応を L4 学習へ還元する閉ループ
- [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) — 検証可能性 4 条件の正本
- [`docs/workflows/ai-loop/00_concept.md`](./00_concept.md) §3 — PlanGate フロー共通化と C-3 置換（C-3'）・`MERGE_READY` 責務範囲の正本
- [`docs/ai/plan-review-readiness-gate.md`](../../ai/plan-review-readiness-gate.md) — 強化セルフレビュー §7/§8 観点の参照元
- [`.claude/skills/ai-loop-cycle/SKILL.md`](../../../.claude/skills/ai-loop-cycle/SKILL.md) — 本 runbook の 1 サイクルを実行する手順スキル（Model A/B/C/D 委託プロンプト定型）
- [`.claude/skills/pr-watch/SKILL.md`](../../../.claude/skills/pr-watch/SKILL.md) — 手順 (7) の CI/AI レビュー指摘対応ループの監視・対応定型
