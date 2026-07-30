# PBI INPUT PACKAGE — TASK-0917

> Issue: [#917](https://github.com/s977043/plangate/issues/917)（enhancement / ai-loop / **priority:P0**）
> 由来: [#873](https://github.com/s977043/plangate/issues/873)（PR #905 / TASK-0873）の正式 plan で **V2 送りとした実 PR 収束系**の実装
> EPIC: [#870](https://github.com/s977043/plangate/issues/870) の Child Issues に登録済み・**close blocker**（「Epic の E2E 実走はこれ無しで成立しない」— EPIC 本文）
> 作成: 2026-07-30（**main `b306b12` で実測**。行番号は目安であり記号アンカー〔関数名・定数名・テスト名〕を正とする）
> レビュー: [`review-external.md`](./review-external.md) に 2 レーン（敵対 + River Review）の指摘 `R-001`〜`R-016` を集約し**全件反映済み**（critical 1 / major 9）

## Context / Why

[#873](https://github.com/s977043/plangate/issues/873) で **MERGE_READY 状態機械の判定エンジン V1**（`scripts/ai-loop/delivery.py`）が完成し main に実在する。しかしこれは **純判定器**であり、`assess()` は「次に何をすべきか」を `actions`（intent）として返すだけで、**それを実 PR に対して実行する主体が存在しない**。

したがって EPIC #870 が要求する `PR → CI/review repair → 最新 head 再評価 → MERGE_READY` の**実 PR 収束が成立していない**。EPIC の close 条件 3（「一つの代表 TASK で E2E 実走記録がある」）は本 PBI なしには物理的に満たせない。

### 実測による裏取り（main `b306b12`）

| 主張 | 実測方法 | 結果 |
|------|---------|------|
| `delivery.py` は外部作用を一切持たない純判定器 | `grep -cE "subprocess\|requests\|urllib\|os.system\|gh pr merge\|merge_pull_request" scripts/ai-loop/delivery.py` | **0 件**。ファイル I/O は `--task-dir` 配下の `record.jsonl` と `--snapshot` の読み取りのみ |
| テストは green | `python3 scripts/ai-loop/test_delivery.py`（repo root 起点） | **`Ran 57 tests ... OK`**（exit 0）。※ TASK-0873 handoff は「51 テスト」と記載しており **stale**。正は **57** |
| `required_checks[]` ⊇ 照合が未実装 | `grep -rn "required_check" scripts/ai-loop/*.py docs/workflows/ai-loop/delivery-state-machine.md` | 実装 **0 件**。doc §4（L61）が「required check 集合の機械束縛（`required_checks[]` フィールドと ⊇ 照合）は **V2 候補**。Phase 1 の後段防衛は C-4 Human レビュー + branch protection」と明記 |
| `ci_failure_taxonomy` の供給元が存在しない | `grep -rn "ci_failure_taxonomy"` | `delivery.py` が `snapshot.get()` で**読むだけ**（L317/321/349）。`code` / `flaky` / `environment` を判定して詰める実装はリポジトリ内に皆無 |
| action の実行者が存在しない | `tests/extras/ta-56-delivery.sh` | 「実 PR/gh consumer は V2 — **実行と再評価入力の供給のみ模す**」とコメントされたテスト用スタブのみ |
| merge は Human-owned | `.claude/rules/responsibility-classes.md` | 「Human-owned … C-3 / C-4 ゲート判断、**merge**、権限操作」 |
| ⚠️ **既存 hook（EH-9）は本 PBI の実行面を守れない** | `scripts/hooks/check-delegation-commit-boundary.sh` L62-65 / `.claude/settings.json` の hooks キー / 同 hook L9 コメント | **3 重に不成立**（R-001）: ①`PLANGATE_DELEGATION_NOCOMMIT != 1` なら L62-65 で即 `allow` して **L106 の merge 判定に到達しない** ②実効 `.claude/settings.json` の hooks は `SessionStart` / `PostToolUse` / `Stop` の **3 本のみで `PreToolUse` に未配線**（`settings.example.json` には配線あり = settings drift）③PreToolUse は **Bash ツールの command 文字列のみ**を見るため、Python から `subprocess.run(["gh","pr","merge",...])` を呼ぶ形は検知できない（hook が見るのは `python3 .../executor.py` だけ。argv list は `"gh pr merge"` の部分文字列に一致しない）|
| ⚠️ **branch protection 側の後段防衛も承認を強制していない** | `gh api repos/s977043/plangate/rulesets/14939019` / `.../branches/main/protection` | ruleset の pull_request rule は **`required_approving_review_count: 0`** / `dismiss_stale_reviews_on_push: false` / `require_last_push_approval: false`（`required_review_thread_resolution: true` のみ有効）。classic branch protection は **404 Branch not protected**。required status checks は **`Markdown lint` 1 件のみ**。doc §4 が言う「Phase 1 の後段防衛は C-4 Human レビュー + branch protection」のうち **branch protection 側は実質機能していない**（R-005）|

## What（Scope）

### In scope（issue #917 の In scope を継承）

1. **GitHub Collector**: 実 PR から **head SHA 束縛付き**で CI check / review thread / mergeability を取得し、`delivery.py` の `validate_snapshot()` が要求する snapshot JSON を生成する（required checks・review thread・mergeability を**同一 head SHA に束縛**する）
2. **Action Executor**: `assess()` が返す `actions`（intent）を実 PR に対して実行する
3. **Reconciler**: 実行結果を `delivery.py receipt` で受理記録し、intent → 実行 → receipt の整合を取る（冪等性の担保）
4. **`required_checks[]` の ⊇ 照合**: 部分登録 green を機械拒否する（River Review RV-2 / doc §4 が V2 候補としていた項目）
   - ⚠️ **実装層は plan 冒頭で確定する（U-3・Out of scope との緊張関係）**: doc §4 は「`required_checks[]` **フィールド**と ⊇ 照合」と書いており、素直に読むと snapshot スキーマ拡張 =`validate_snapshot()` / `assess()` の変更を含意する。しかし本 PBI の Out of scope は「判定規則を変更しない」であり **AC-7（`STATES` / `TRANSITIONS` / `PRIORITY_ORDER` 差分ゼロ）と正面衝突しうる**。**第一候補は Collector 側の pre-check（`assess()` 呼び出し前に snapshot を拒否）に限定する**案。`delivery.py` 本体へ分岐を足す案を採る場合は Out of scope の改訂と AC-7 の緩和が必要になるため、**plan の冒頭で決着させてから実装に入る**
5. **raw check evidence 検証**: snapshot 供給者責務を機械検証へ昇格する（Phase 1 の信頼境界の解消）
   - ⚠️ **定義が正本に存在しない**（R-008）: この語はリポジトリ内で `delivery-state-machine.md` §4 の「raw check evidence への束縛は V2 候補」という一言のみで、**何を raw evidence とし何と照合するかの定義がない**。本 pbi では暫定的に「**GitHub API から取得した check-run の生レスポンス（`id` / `head_sha` / `conclusion` / `completed_at`）を snapshot に同梱し、`checks[]` の各要素がその生値から導出されたものであることを機械照合する**」と定義し **AC-9** を与える
   - **plan の第一論点**: 本 PBI の負荷（新規 3 コンポーネント + E2E 基盤）を踏まえ、(a) 上記定義で AC-9 込みで実施する / (b) **V2 送りにして Out of scope へ移す**（doc §4 が元々 V2 候補としている）の 2 案を比較して決着させる。**pbi 段階では issue の In scope を勝手に削らず (a) を既定**とする
6. **実 test repository による repair E2E 実走**

### Out of scope（issue #917 の 3 項目 + 本 pbi で追加した 2 項目）

- **merge 実行**（NO MERGE BY AI / rollout-policy §5 不変。`check-delegation-commit-boundary.sh` の `gh pr merge` block も不変）
- **`delivery.py` 判定エンジン本体の判定規則変更**（`STATES` / `TRANSITIONS` / `PRIORITY_ORDER` は不変。**入力供給と出力実行の外側 2 層を足すのみ**）
- disposition `evidence_ref` の内容真正性検証（C-4 責務として #873 §5 で明文化済み。必要なら別 issue）
- **PR の承認状態・存在・履歴を変える操作すべて**（approve / close / reopen / ready / force push / branch 削除。R-002 の包括ルール。個別列挙は merge 境界表を参照）
- Run Evidence の正規化・Evolution Loop 接続（**#874 / #869 の担当**。本 PBI は「実 PR 収束」まで）
  - ※ この 1 項目は **issue #917 では「依存 / 位置づけ」節に「#874 Run Evidence 契約と provenance 連携」として記載**されているもので、Out of scope として明示したのは本 pbi による判断（R-009）

### 触ってはいけないファイル（TASK-0873 handoff より・実測）

| ファイル | 理由 |
|---------|------|
| `scripts/ai-loop/c3prime_verify.py` / `c3_contract.py` | #872 / #896 の**承認境界受理器**。`delivery.py` は import 再利用のみ。改変すると受理契約が壊れる |
| `docs/workflows/ai-loop/delivery-state-machine.md` の `<!-- contract:begin/end -->` ブロック | `python3 scripts/ai-loop/delivery.py contract` の emit と **byte 一致必須**（`tests/extras/ta-56-delivery.sh` が `cmp -s` で機械検証）。**手編集禁止**・変更は emit で再生成 |

## 受入基準

> issue #917 の受入基準は本文で「**（案・plan 段階で確定）**」と明記されている。以下は案 AC-1〜6 を継承しつつ、実測で判明した事項を反映して**検証可能性を上げたもの**。plan で最終確定する。

- **AC-1**: Collector が生成する snapshot が **head SHA に束縛**され、`checks[].sha` / `review.sha` が `head_sha` と一致することを検証する。**不一致時の扱いは正本 doc §4 に従う**（R-003）:
  - `docs/workflows/ai-loop/delivery-state-machine.md` §4 は「**checks と head の SHA 不整合 → stale として `WAITING_FOR_CHECKS`（成功扱いにしない）**」と定めており、`delivery.py` も `checks_at_head` フィルタ + `WAITING_FOR_CHECKS` でそのとおり実装済み。**AC-1 が `HUMAN_ESCALATED` を要求すると正本と矛盾し AC-7（判定規則不変）に違反する**
  - **Collector の pre-check 失敗は snapshot を破棄・例外 exit してはならない**。破棄すると `assess()` が呼ばれず `record.jsonl` に state entry が一切残らないため、#894 の no-progress / repeated-failure 検知（AC-6）が「何も起きていない run」と区別できなくなる
  - **判定規則を変えずに escalate へ倒せる既存経路は `escalation_flags` に理由コードを積んで `assess()` を通すこと**（`delivery.py` が `escalation_flags` 非空を最優先で escalate する）。pre-check 失敗（AC-1 / AC-2 の両方）はこの経路に寄せる
- **AC-2**: **`required_checks[]` ⊇ 照合**により、部分登録 green（required check が未登録のまま「全 success」に見える瞬間の snapshot）が `MERGE_READY` にならない。負側テストで固定する
- **AC-3**: Executor の外部作用が **intent → 実行 → receipt → reconcile** の系で**冪等**（同一 `action_id` の再実行で二重作用しない）。`action_id` は `delivery.py` の既存生成規則（`c3_contract.canonical_hash(payload)`）を**変更せず**利用する
- **AC-4**: 実 test repository で **repair E2E が通る**（CI 失敗 → repair → 最新 head 再評価 → MERGE_READY の 1 周）。**合格基準を機械化できる形に落とす**（現状の「1 周通った」は目視判定で、外部 GitHub 依存の非決定性（レート制限・登録タイミング）と相まって再現性のない one-off 実行を既成事実化しうる — R-014）:
  - 使用する test repository を**名前で確定**する（誰が用意するか・本番リポジトリと分離されているか）
  - E2E は `tests/extras/` 配下の**固定シナリオスクリプト**として実装し、**実行ログを `evidence/e2e/` へ保存**する
  - CI 常設は要求しない（外部依存のため）。**手動実行手順 + 証跡記録**をもって PASS とする
- **AC-5**: **破壊的操作を実行する経路が存在しない**。既存 hook / branch protection は当てにできない（実測裏取り表 R-001 / R-005）ため、**in-process の allowlist で強制する**（R-001 / R-002）:
  - Executor の外部コマンド実行を**単一の gh 実行ラッパに集約**し、そこで**許可サブコマンドの allowlist**（例: `pr view` / `pr comment` / `api` の GET / head ブランチへの通常 push）を強制する。**禁止は deny リストではなく allowlist の補集合として自動的に成立させる**（列挙漏れを構造的に塞ぐ）
  - **禁止に含まれるべき操作**（deny 列挙は allowlist の妥当性検証用）: `gh pr merge` / **`gh pr review --approve`** / `gh pr close` / `gh pr reopen` / `gh pr ready` / `git push --force*` / branch 削除（`git push --delete` / `gh api -X DELETE .../refs/...`）/ `gh api` の非 GET メソッド全般
  - **既存の禁止トークン走査は用途を限定して使う**: 「**gh 実行ラッパ以外のモジュールが `subprocess` を import しない**」ことの検査に使う。`test_tc18_pure_verdict_source` と同じトークン集合（`subprocess` / `os.system` / `urllib` / `socket` / `http.client` / `requests` / `gh pr merge` / `merge_pull_request`）を Executor へ**そのまま**適用すると `gh` を呼べず In scope 2 と両立しないため、集合をそのまま流用しない
  - 負側テスト: allowlist 外のサブコマンドを渡すとラッパが**拒否して exit 非 0** になること
- **AC-6**: **#894 Loop Control Contract**（budget / no-progress / repeated-failure）との接続点を統合テストで固定する
  - ⚠️ **#894 は未着手**（pbi-input のみ存在・enum / reason code が未確定）。「未確定の相手との接続点をどう固定するか」は plan の論点（下記 U-5）
- **AC-7**（追加）: `delivery.py` の判定規則が**不変**であること。**定数単位ではなくファイル単位で固定する**（R-006: 定数だけを見ると `validate_snapshot()` / `assess()` 本体へ後方互換な分岐を足しても AC が鳴らず、Out of scope を破っても通ってしまう）:
  - `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py` が **0 行**
  - 既存 **57 テスト**が全 PASS（`python3 scripts/ai-loop/test_delivery.py`・repo root 起点）
  - contract ブロックが `delivery.py contract` の emit と **byte 一致**（`ta-56-delivery.sh` の `cmp -s`）
- **AC-8**（追加）: `ci_failure_taxonomy` の**供給元が機械的に特定できる**こと（現在リポジトリに実装が存在しないため、決めずに実装すると `repair_ci` が発行できず常に `HUMAN_ESCALATED` に落ちる）。**「明示された」だけでは分類の正しさを何も保証しないため、以下の 2 点で固定する**（R-014）:
  - `docs/workflows/ai-loop/delivery-state-machine.md` の該当節に**供給主体名を 1 文で明記**する
  - 供給を担う**モジュール境界（関数名 / クラス名）が特定でき**、`code` / `flaky` / `environment` の分類に対する**単体テストが存在する**こと

- **AC-9**（追加 / In scope 5 に対応）: snapshot に **check-run の生レスポンス**（`id` / `head_sha` / `conclusion` / `completed_at`）が同梱され、`checks[]` の各要素が**その生値から導出されたことを機械照合**できる。改竄・捏造された `checks[]`（生値と不整合）を負側テストで拒否する
  - ⚠️ In scope 5 を V2 送りにする判断（上記）を採る場合、本 AC も同時に取り下げる

## Notes from Refinement

### 接続先インターフェース（Collector / Executor が満たすべき契約・実測）

```python
def assess(snapshot: dict, entries: list, plan_hash: str | None = None) -> dict
# 戻り値: {state, actions, new_entries, reasons, record（MERGE_READY 時のみ）}
```

CLI:

- `delivery.py assess --task-dir <dir> --snapshot <path> --now <ISO8601> --expected-sha <sha>`（4 つ必須・欠落は exit 2）
- `delivery.py receipt --task-dir <dir> --action-id <id> --result-ref <str> --now <ISO8601>`（4 つ必須）
- `delivery.py contract`（引数なし。contract JSON を stdout）

#### Collector が生成すべき snapshot の必須キー（`validate_snapshot()` 実測・全件必須）

| キー | 制約 |
|------|------|
| `task_id` | `TASK-[0-9]{4}` 完全一致 |
| `pr_number` | `int`（bool 除外） |
| `head_sha` | hex 7〜40 文字 |
| `source_sha_ancestry` | `True` / `False` / `None` のみ |
| `mergeable` | enum `("MERGEABLE", "CONFLICTING", "UNKNOWN")`（**未知値は fail-closed**） |
| `checks` | `list[dict]`。各要素 `{name: str, sha: hex7-40, conclusion: str}` |
| `review` | `dict` `{state: str, sha: hex7-40}` |
| `findings` | `list[dict]`。`{id, finding_type, severity ∈ (critical/major/minor/info), disposition: null or {kind ∈ (adopted/rejected), ...}}` |
| `changed_files` / `allowed_paths` | `list[str]` |
| `escalation_flags` | `list` |
| `dod_evaluated` | `bool` |
| `conflict_resolution` | **省略可**。存在するなら `dict`（内部キー `base_sha` / `head_sha` / `result_sha` の三点が揃わないと CONFLICT のまま） |

#### ⚠️ snapshot キー × 供給元マップ（R-004 / plan の必須前提）

`validate_snapshot()` の必須 13 キーのうち **GitHub PR API から取れるのは 5 つだけ**。残りの供給元を決めないと Collector の関数シグネチャすら書けず、「Collector = gh 呼び出し」という矮小化に落ちる。

| キー | 供給元 | 本 PBI の scope |
|------|--------|----------------|
| `pr_number` / `head_sha` / `mergeable` / `checks` / `review` | **GitHub API** | **In scope**（Collector が取得） |
| `source_sha_ancestry` | **git 実測**（base への祖先関係） | **In scope**（Collector が git で判定） |
| `task_id` | ai-loop 実行コンテキスト（`--task-dir` 由来） | **In scope**（呼び出し時に束縛） |
| `allowed_paths` | **plan / c3 contract**（GitHub にはない）。`EXEC_RETURN`（最優先分岐）を駆動する load-bearing 入力 | **plan で確定**（c3.json / plan package からの読み出し経路が要る） |
| `findings[]`（`id` / `finding_type` / `severity` / `disposition`） | **AI レビュー層の出力**。`REVIEW_REPAIR` と `MERGE_READY` の両方を駆動する load-bearing 入力。**`disposition` の `repair_commit` / `evidence_ref` を誰がいつ書き戻すかが未定義** | **plan で確定**（U-10） |
| `dod_evaluated` | ai-loop 制御層（DoD 評価の完了フラグ） | **plan で確定**（U-10） |
| `escalation_flags` | ai-loop 制御層 + **Collector の pre-check 失敗理由**（AC-1 参照） | **In scope**（AC-1 の経路として使う） |
| `ci_failure_taxonomy`（必須キーではないが実質必須） | 未実装。**AC-8 で供給主体を確定させる** | **In scope**（AC-8） |

**`validate_snapshot()` では検証されないが `assess()` が参照する実質仕様**（Collector が満たさないと動かない）:

- `ci_failure_taxonomy`: enum `("code", "flaky", "environment")`。`failed` チェックがあるときのみ評価され、**未知値/欠落は `HUMAN_ESCALATED`**（→ AC-8）
- `checks[].conclusion`: 3 群 allowlist（`CHECK_FAILED` / `CHECK_PENDING` / `CHECK_NONBLOCKING`）。allowlist 外は `unknown_checks` として `HUMAN_ESCALATED`

#### Executor が実行すべき action_kind（実測・6 種）

`repair_ci` / `resolve_conflict` / `repair_review` / `record_disposition` / `feedback_loop_referral` / `dod_reevaluate`

**`comment` / `re-request review` 相当の action_kind は存在しない**。Executor が PR コメントを打つ必要があるなら、既存 action の payload で表現できるか / 新 action_kind が必要かを plan で判定する（新設は判定規則の変更に踏み込むため Out of scope との境界に注意）。

#### Reconciler が依拠する冪等性の仕組み（実測）

- `record_path(task_dir)` = `<task_dir>/delivery/record.jsonl`（**append-only**。`append_entries()` は既存 `entry_id` と照合して重複を skip、削除・上書きなし）
- `receipt` サブコマンドは対象 `action_id` の `kind=="intent"` entry が**存在しなければ exit 2**（= 「記録なき実行は受理しない」/ intent 先行必須）
- 次回 `assess()` で **receipt 済みの action は `actions` から除外**され、未 receipt は**再要求**される（`test_tcE5_intent_without_receipt_rerequested` で固定）

### 実装方式の前例: 「gh 呼び出しは判定層から分離する」

`scripts/ai-loop/discovery.py` が同型の設計前例を持つ（実測）: `gh issue list --json ...` **相当の JSON をファイル入力として受けるだけで gh を直叩きしない**（「ネットワーク非依存・決定論・テスト可能」と明記）。

→ Collector も **①ネットワーク I/O 層（gh 呼び出し）と ②snapshot 組み立て・検証層を分離**し、②を純関数にしてテスト可能にするのが既存慣習に沿う。

### 再利用できる既存資産（実測）

| 資産 | 再利用ポイント |
|------|--------------|
| `scripts/verify-pr-merged.sh` | `gh pr view --json state,mergedAt,mergeCommit` の**三点照合で fail-closed 判定**する作法。単一フィールドを信じない設計思想が AC-1 の head SHA 束縛と同型 |
| `scripts/gh-s977043.sh` / `gh-pin-account.sh` | gh の active account 強制切り替え（認証 drift 対策）。Collector / Executor も噛ませる |
| `scripts/hooks/check-delegation-commit-boundary.sh` | `gh pr merge` / `gh repo sync` の**コマンド文字列マッチ block**（L106）。AC-5 の静的ガードとして直接活用 |
| `delivery.py` の enum 定義 | `MERGEABLE_VALID` / `CHECK_FAILED` / `CHECK_PENDING` / `CHECK_NONBLOCKING` / `SEVERITY_VALID` / `DISPOSITION_KINDS` が **Collector の出力スキーマの正本**。変換表として直接 consume する |
| `tests/extras/ta-56-delivery.sh` | **#917 の直接の前身スタブ**（「実行と再評価入力の供給のみ模す」）。この模擬部分を実装に置き換えるのが自然な導線。禁止トークン走査パターンも AC-5 に転用可。**なお同ファイル L29 のコメントに「51 テスト」という stale な数字が残っている**（正は 57）ため、plan の todo に 1 行の是正タスクを含める |

### 依存ライブラリの方針

- `scripts/` 配下の Python は **stdlib only**（`json` / `pathlib` / `re` / `sys` / `argparse`。`from __future__ import annotations` + 型注釈あり）
- `requirements/` には **`schema-validate.txt` のみ**存在し、CI（`.github/workflows/schema-validate.yml`）向けに **pip の SHA-256 hash pin** で運用されている（Scorecard Pinned-Dependencies 対応）
- → **`gh` CLI をサブプロセス経由で呼ぶ方式なら外部依存の追加は不要**。`requests` / `PyGithub` 等を入れる場合は上記 hash pin の枠組みに乗せる必要がある（方式選定は U-2）

### merge 境界（Executor がしてよいこと / してはいけないこと）

| してよい（allowlist に載せる） | してはいけない（allowlist の補集合） |
|---------|--------------|
| CI 失敗に対する repair commit の **通常 push**（PR head ブランチ宛） | `gh pr merge` の発行 |
| PR へのコメント投稿（`gh pr comment`） | **`gh pr review --approve`**（下記の理由により最重要） |
| `gh pr view` / `gh api` の **GET** による状態取得 | `gh pr close` / `gh pr reopen` / `gh pr ready` |
| receipt の記録・reconcile | `git push --force*`（force-with-lease を含む）|
| head SHA 束縛付き snapshot の再取得 | branch 削除（`git push --delete` / `gh api -X DELETE .../refs/...`）|
| — | `gh api` の**非 GET メソッド全般**（allowlist で個別許可したもの以外）|
| — | `MERGE_READY` から先の状態遷移（`MERGED` 状態は `STATES` に**存在しない**）|
| — | `delivery.py` の判定規則（`PRIORITY_ORDER` / `STATES`）の変更 |
| — | disposition `evidence_ref` の内容真正性検証（C-4 責務）|

> **⚠️ `gh pr review --approve` を禁止する理由（R-002）**: `delivery.py` は `review_ok = review["state"] == "approved" and review["sha"] == head`（L290）で判定しており、**approve は `MERGE_READY` 到達の load-bearing 入力**。加えて本 PBI は `scripts/gh-s977043.sh` / `gh-pin-account.sh`（active account の強制切り替え）を Collector / Executor に噛ませる方針であり、**account を pin できる主体は PR 作成者と別アカウントで自 PR を approve でき、`review.state == "approved"` を自力で成立させられる**（= sockpuppet 承認。`.claude/rules/` の sockpuppet 禁止と正面衝突する）。リポジトリ側にこれを止めるガードは**存在しない**（`grep -rn "pr review --approve" scripts/hooks/*.sh` = 0 件・`.claude/settings.json` の `permissions.deny` = 0 件・実測）。

**包括ルール**: 上記の列挙に漏れがあっても塞がるよう、Out of scope に「**PR の承認状態・存在・履歴を変える操作すべて**」を含める（下記 Out of scope 参照）。

`.claude/rules/responsibility-classes.md`: 「Human-owned … C-3 / C-4 ゲート判断、**merge**、権限操作」。

### HO / carve-out の二重構造（**混同しないこと**）

| 機構 | #917 の該当性 | 帰結 |
|------|-------------|------|
| **HO 9 カテゴリ**（`.claude/rules/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows/*` / `CLAUDE.md` / `AGENTS.md` / `.claude/settings*.json` / `.claude/commands/*.md` / `.claude/agents/*.md`） | **非該当**（`scripts/ai-loop/**` は含まれない。`check-plan-hash.sh` の case 文を grep して確認） ただし **E2E 用に `.github/workflows/*` を新設・変更する場合はその分だけ HO 該当**（Human patch 分離が必要） | 通常の Mode 判定 |
| **rollout-policy §2 判定基盤 carve-out**（対象は ① `scripts/ai-loop/**` / ② `docs/workflows/ai-loop/**` ・ `docs/ai/ai-loop/**` / ③ `.agents/skills/ai-loop-cycle/**` ・ `.claude/skills/ai-loop-cycle/**` の 3 項目）| **該当**（本 PBI の成果物は **①② に一致**。③ は変更対象外） | ai-loop の auto-approve 対象に**なり得ない**（escalate 固定）。ただし現状これは**規範層のみ**で機械強制は #916 待ち |

### 自己適用の運用影響

本 PBI の差分は carve-out ①② に該当するため、**ai-loop で自走させる場合は escalate 固定**（Human C-3 相当が必須）。#916 の機械強制が入るまでは規範層の遵守（実行者が escalate する責務）で担保する。

### Mode 見込み: critical

- 定量: **新規コンポーネント 3 つ**（Collector / Executor / Reconciler）+ テスト + E2E 基盤 + doc 更新 + plugin 配布同期（`sync-plugin-plangate.sh` の whitelist は **L345 のコピー元 for ループと L355 の `case` 許可判定の 2 箇所**にあり、**片方だけの追加は sync drift になる** — R-011）→ 触るファイルは **10 本超**が見込まれる
- 受入基準 **8 件**（AC-1〜8）→ high 帯（6-10）
- 定性が支配的:
  - **リポジトリに初めて「外部作用を実行する層」を導入する**（現状 ai-loop は全て純判定器 + ファイル I/O のみ）
  - 実 GitHub API への書き込み（repair push / comment）を伴い、**副作用の巻き戻しが容易でない**
  - E2E に**実 test repository** が必要で、認証・レート制限・後片付けの設計を新規に起こす
- **前例**: 接続先を作った **TASK-0873 は Mode=critical**（`docs/working/TASK-0873/plan.md` L197 / L205「critical（定量・定性の最大値）。V-4 実行対象・人間 C-3 詳細レビュー必須」）。本 PBI はそれに外部作用を足す上位互換のリスクを持つ
- **判定: critical**（`lite_eligible=false` / 人間 C-3 詳細レビュー必須 / **V-4 リリース前チェック実行対象**）。段階的ロールバック計画を plan で必須とする

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| Executor が誤って `gh pr merge` を発行する | **NO MERGE BY AI 原則の違反**（最重大） | AC-5。既存 hook（`check-delegation-commit-boundary.sh` L106）+ 禁止トークン走査を Collector/Executor/Reconciler の全パスへ適用。負側テストで固定 |
| Collector が head SHA 束縛を破り、古い head の check 結果で MERGE_READY になる | 未検証コードが merge 可能状態と誤判定される | AC-1。`checks[].sha` / `review.sha` を `head_sha` と照合し不一致は fail-closed |
| `required_checks[]` ⊇ 照合を入れずに部分登録 green を通す | push 直後の非同期登録の隙間で「全 success」が honest に成立し MERGE_READY になる（doc §4 が名指しで警告） | AC-2 の負側テスト |
| `ci_failure_taxonomy` の供給元を決めずに実装 | `repair_ci` が発行できない / 未知値で常に `HUMAN_ESCALATED` に落ちる | AC-8 で供給元を明示させる |
| 実 test repository の E2E が副作用を残す（テスト PR / branch のゴミ） | リポジトリ汚染・レート制限消費 | plan で後片付け手順とテスト用リポジトリの分離を設計する（U-1） |
| `delivery.py` の判定規則に手を入れてしまう | #873 の 57 テストと contract ブロックが破綻し、承認境界の契約が壊れる | AC-7（差分ゼロ + 57 テスト PASS + contract byte 一致）。`c3prime_verify.py` / `c3_contract.py` は import のみ |
| 外部依存（`requests` 等）を追加して stdlib only 慣習を崩す | pip hash pin の運用コスト増・Scorecard 影響 | U-2 で `gh` サブプロセス方式との比較。既存 `requirements/schema-validate.txt` の hash pin 枠組みに乗せる場合のコストを見積もる |
| `action_id` の生成規則を変えてしまう | 既存 receipt が全て無効化され冪等性が崩れる | AC-3。`c3_contract.canonical_hash(payload)` を**変更せず利用**する（実装は U-6 に転記済み）|
| **Executor の repair push が人間の C-4 承認を stale のまま残す**（実測: ruleset の `dismiss_stale_reviews_on_push: false` / `require_last_push_approval: false`） | **承認済みコードと merge されるコードが不一致になる**。`delivery.py` は `review.sha == head` を要求するので ai-loop 内部の判定は守られるが、**merge を実行するのは人間**で GitHub UI 上は「approved のまま」に見える = AI が人間の承認の下でコードを差し替える経路が開く | repair push 時に Executor が **既存 approve の dismiss または明示通知コメントを必須発行**し、その実行を receipt に記録する（R-005）。plan で「dismiss を Executor に許すか（= 承認状態の変更に踏み込む）／通知のみに留めるか」を決着させる |
| GitHub API のレート制限・一時障害で Collector が不完全な snapshot を返す | 部分的な check 情報で誤判定（best case は escalate、worst case は誤 MERGE_READY） | 取得失敗は **fail-closed**（例外を握り潰さず escalate へ倒す）。retry / backoff の実装方針を U-2 の方式選定と併せて決める。**リポジトリ内に既存の backoff 実装は無い**（実測）ため新規設計になる |

### Unknowns

- **U-1**: **E2E の実現方式**。「実 test repository」を新設するか、GitHub API の record/replay mock を作るか。認証・レート制限・後片付けの扱いも含めて決める
  - ⚠️ **前提の訂正（R-007）**: 当初「mock / fixture 化の前例はリポジトリ内に無い」と書いたが**不正確**。JSON fixture 注入の前例は **`scripts/ai-loop/test_discovery.py` の `_issue()`（L27）**（`gh issue list --json ...` と同形の dict を生成）と **`ta-56-delivery.sh` の snapshot 自前生成**に**存在する**。**新規なのは check-run / review-thread の GraphQL レスポンスの record/replay のみ**。「ゼロから設計」という前提は選択肢を「実 test repository 新設」（最もコストとリスクが高い側）へ不当にバイアスさせるため訂正する
- **U-2**: **GitHub API へのアクセス方式**（`gh` CLI サブプロセス vs `requests` / GraphQL 直叩き）。review thread の取得は GraphQL が必要になりやすく、`gh api graphql` の raw JSON 処理が煩雑になる可能性。stdlib only 慣習との兼ね合いで判断する
- **U-3**: **⊇ 照合をどの層で行うか**（Collector 内の pre-check か、`delivery.py` への機能追加か）。第一候補は前者（In scope 4 の注記参照）
  - ✅ **取得元は解消済み（実測・R-010）**: classic Branch Protection API（`gh api repos/s977043/plangate/branches/main/protection`）は **404 Branch not protected** で使えない。**ruleset API が正**: `gh api repos/s977043/plangate/rulesets` → `id=14939019 "Protect default branch"`、required checks は `gh api repos/s977043/plangate/rulesets/14939019` の `.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context` から取得（現状 `["Markdown lint"]` の 1 件）。**この読み取りには repo admin 相当の権限が必要**（実行主体を問わず）
- **U-4**: **`ci_failure_taxonomy` の判定主体**（Collector が CI ログから分類するか、別コンポーネント／人間が与えるか）。`code` / `flaky` / `environment` の判別は自動化難度が高い
- **U-5**: **AC-6（#894 接続点）をどう固定するか**。#894 は pbi-input のみで enum / reason code が未確定。issue #917 本文は「#894(a) 契約確定後の着手が**効率的**」という**弱い表現**（blocker とは書いていない）だが、AC-6 は接続点の統合テスト固定を要求しており**表現と要求にギャップがある**。plan で (a) AC-6 を「接続点の I/F だけ先に固定し値は #894 で埋める」に緩める / (b) #894(a) の一部確定を待つ / (c) AC-6 を本 PBI から外して #894 側へ移す の 3 案を比較する
- ~~U-6~~ **解消済み（実測・R-012）**: `c3_contract.canonical_hash()` の実装は以下（`scripts/ai-loop/c3_contract.py` L71-74）。

  ```python
  canon = json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")
  return "sha256:" + hashlib.sha256(canon).hexdigest()
  ```

  キー順序 = `sort_keys=True`（アルファベット順）/ separators = `(",", ":")`（空白なし最小形）/ エンコーディング = UTF-8 / prefix = `"sha256:"`。**Reconciler が同一 `action_id` を再計算する場合はこの関数をそのまま import して再利用し、独自実装しない**（`delivery.py` の `action_id()` も同関数をラップしているだけ）
- **U-10**: snapshot キーのうち **GitHub 由来でないもの**（`allowed_paths` / `findings[]` / `dod_evaluated`）の供給経路。とくに **`findings[]` の `disposition`（`repair_commit` / `evidence_ref`）を誰がいつ書き戻すか**が未定義。`findings[]` は `REVIEW_REPAIR` と `MERGE_READY` の両方を駆動する load-bearing 入力であり、これが決まらないと Collector のシグネチャが確定しない（R-004）
- **U-7**: Executor が PR コメントを打つ必要がある場合、既存 6 種の action_kind で表現できるか。新 action_kind の追加は `delivery.py` の変更＝Out of scope に触れる
- **U-8**: **Executor の実行主体をどこに置くか**（人間のローカル実行 / GitHub Actions / ai-loop 自走）。carve-out ①② により **ai-loop 自走は escalate 固定**（規範層）であり、当面は「`gh` 認証済みの手元環境から人間が起動する」運用にならざるを得ないと見込まれるが、pbi では確定していない。CI で動かす場合は `gh` の認証情報（token 権限スコープ）の設計が別途必要。**加えて `required_checks[]` の取得（U-3）には repo admin 相当の権限が必要**（実行主体を問わず・実測）
- ~~U-9~~ ✅ **解消済み（実測・R-010）**: ruleset の `conditions.ref_name.include = ["~DEFAULT_BRANCH"]` = 保護は **default branch のみ**。したがって PR head ブランチへの repair push は可能。ただし **`RULE deletion` / `RULE non_fast_forward` も default branch にのみ効く**ため、**head ブランチの force push / 削除を止める platform 層のガードは存在しない**（→ AC-5 の allowlist で in-process に塞ぐ必要がある）

### Assumptions

- `delivery.py` の V1 判定エンジン（`assess()` / `validate_snapshot()` / `action_id()` / `record.jsonl` の append-only 契約）が **main で安定**していること（`b306b12` で 57 テスト OK を実測）
- TASK-0873 の handoff に記載された「触れないでほしいファイル」（`c3prime_verify.py` / `c3_contract.py` / contract ブロック）が現在も有効であること
- merge が Human-owned であること（`responsibility-classes.md`）と `check-delegation-commit-boundary.sh` の block が不変であること
- #874（Run Evidence 契約）は本 PBI の**下流**であり、本 PBI は evidence の正規化を行わない
