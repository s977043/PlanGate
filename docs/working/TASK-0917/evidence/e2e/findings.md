# TASK-0917 T-35: fixture E2E との差異（実 PR 実走で判明したこと）

**結論: 実装の欠陥は 1 件も検出されなかった**（実 REST 形状の drift ゼロ /
写像・pre-check・rc 検査はいずれも実環境で意図どおり動作）。
一方で **fixture が模していない実データ形状が 3 件**、
**実 PR では原理的に検証できない領域が 3 件**あり、以下に記録する。

Severity は `.claude/rules/review-principles.md` §3 に従う。

## A. fixture が模していない実データ形状（実装は正しく処理した）

### F-1 origin URL が SSH host alias 形式（info）

| 項目 | 内容 |
|------|------|
| 実測 | `git ls-remote --get-url origin` → `git@github-s977043:s977043/PlanGate.git` |
| fixture | `test_gh_exec.py` の `_push_handler` は `git@github.com:{REPO}.git` 形のみ |
| 挙動 | `_origin_matches()` は `:` 区切りの suffix 一致で判定するため **host alias 付きでも True**。実走で事前検査 3 を正常通過 |
| 含意 | 複数アカウントを SSH config の alias で分ける実環境でも壊れないことが実証された。fixture 側に alias 形の case を 1 本足すと回帰を守れる（**改善提案・任意**） |

### F-2 `merge-base --is-ancestor` が rc=1 ではなく rc=128 を返す経路（info）

| 項目 | 内容 |
|------|------|
| 実測 | 存在しない SHA を `expected_parent_sha` に渡すと `git merge-base --is-ancestor` が **rc=128**（`fatal: Not a valid object name`）。`push_pr_head()` は `returncode != 0` で `Denied(PRECHECK)` |
| fixture | `test_executor.py:729` に `ancestor_rc=128` の case あり（`is_ancestor()` の 3 値判定側）。`push_pr_head()` 側は「不明」と「祖先でない」を区別しない実装のため実害なし |
| 挙動 | fail-closed で正しい（push に到達しない） |

### F-3 `required_status_checks` が実質 1 件しかない（info）

| 項目 | 内容 |
|------|------|
| 実測 | `repos/s977043/PlanGate/rules/branches/main` の `required_status_checks` は `[{"context": "Markdown lint"}]` の **1 件のみ**。一方 check-run は 7 件走る |
| fixture | `test_collector.py:466` は複数 rule の union を検証（fixture の方が厚い） |
| 含意 | `missing_required_checks()` の実効カバレッジは本番 repo では 1 件分。`required_checks_empty` は積まれなかったが、**必須 check 集合が薄いことは判定強度の実力値**として認識しておくべき。実装の不具合ではなく repo 設定側の事実 |

### 付随して実データで裏付けられたこと（差異ではない）

- `pull_request` ruleset の **`dismiss_stale_reviews_on_push: false`** を実測で確認。
  `executor.NOTIFY_TEMPLATE` が「`dismiss_stale_reviews_on_push: false` の実測に
  基づく明示通知」と書いている前提が、実 ruleset で正しいことを確認した。
- `pulls/{n}` の `mergeable` は生 JSON では **boolean `true`**。
  `normalize_mergeable()` が `MERGEABLE` へ写像（fixture と同形）。
- `pulls/{n}/reviews` は review ゼロのとき **`[]`（空配列）**。
  `_parse_json_stream()` は空文字列のみを ValueError にするため素通り。
- `checks[].sha` は 7 件すべて head と一致。stale check の混入は無かった。

## B. 実 PR で「実際に起きた」ことの確認（fixture では構成でしか作れない）

### F-4 R-019 の `status != "completed"` → `conclusion` 写像が実タイミングで発火（info / 最大の収穫）

push 直後（Step 4 の collect 2 回目）に取得した実 check-run:

| name | 生 `status` | 生 `conclusion` | 写像後 `conclusion` |
|------|-----------|----------------|-------------------|
| `plangate CLI tests` | `in_progress` | **`null`** | `in_progress` |
| `Analyze (python)` | `in_progress` | **`null`** | `in_progress` |
| 他 4 件 | `completed` | `success` | `success` |

- 写像が無ければ `validate_snapshot()` は `checks[].conclusion` に `str` を
  要求するため **`SnapshotError`（`invalid_snapshot`）** に落ちていた。
- fixture（`test_collector.py:755` / `:769`）は同じ形を**手書きで**作っており
  写像自体は unit test 済みだが、「実際の非同期 check 登録タイミングで
  `conclusion=null` を掴む」ことは実走で初めて実証された。
  **この写像は dead code ではない**。
- 結果 `assess()` は `WAITING_FOR_CHECKS` へ正しく倒れた。

### F-5 check-run の集合が head ごと・時刻ごとに変化する（info）

| タイミング | check 件数 | 差分 |
|-----------|----------|------|
| 旧 head `fe0abc6…`（run 1） | 7 | — |
| 新 head `7b22922…` push 直後（run 2） | **6** | `CodeQL` が未登録 |
| 同 head・約 1 分後（run 3） | 7 | `CodeQL` が遅れて登録 |

- 実装は `_checks_are_settled()` ゲートにより「pending が残る間は
  `required_checks_missing` を積まない」ため、**必須 check が未登録の瞬間を
  誤って missing と断じることはなかった**（実測でも当該フラグはゼロ）。
- 逆に言えば「必須 check がまだ 1 本も登録されていない head」では
  `checks_at_head` が空 → `WAITING_FOR_CHECKS` へ倒れる設計に依存している。
  今回はそこまで極端な状態は観測されなかった。

## C. 実 PR では原理的に検証できなかった領域

### F-6 `push_pr_head()` 事前検査 2（`baseRefName` 不一致）は実 PR で到達不能（info）

- 事前検査 2 が単独で発火するには `headRefName == baseRefName` の PR が
  必要だが、GitHub は同一 branch 間の PR を作れないため**実 PR では作れない**。
- 負検証で `branch="main"` を渡すと、事前検査 2 の**手前**（事前検査 1 の
  `gh pr view main` が rc=1）で `Denied` になる。結果として
  「`main` へは push されない」ことは実環境で担保されているが、
  **経路は事前検査 1 であって 2 ではない**。事前検査 2 の実行時挙動は
  fixture（`test_gh_exec.py` `PushPreCheckTests`）でしか確認できない。

### F-7 `git push` の**失敗パス**（rc != 0）は未実証（minor）

- R2 B2-1 で是正された「push の rc を検査する」は、本実走では
  **成功パス（rc=0 → `pushed=True`）のみ**確認できた。
- reject / 認証失敗 / ネットワーク断を実 PR で意図的に起こすには
  禁止操作（protected branch への push 等）が必要なため実行していない。
- fixture（`_push_handler(push_rc=...)`）が失敗パスを担保している。
  **実環境での失敗パス実証は残課題**（V2 候補: probe 用に一時的に
  ruleset で push を拒否する branch を用意する等）。

### F-8 Collector の失敗系（rate limit / 403 / shallow clone / record 破損）は未観測（minor）

- 3 回の collect すべてで `escalation_flags` は **空**だった。
  `pull_fetch_failed` / `check_runs_fetch_failed` / `required_checks_*` /
  `changed_files_unavailable` / `findings_unavailable` /
  `allowed_paths_empty` / `record_unreadable` はいずれも実 API では
  発火しなかった。
- したがって **AC-6 の「Executor が積んだ理由コードが次 run snapshot へ
  伝播する」経路は本実走では未実証**（`executor.apply_escalation_flags()` は
  今回呼ばれていない。Executor が flag をゼロ件しか積まなかったため）。
  fixture E2E（`ta-57`）が担保している経路である。

## D. 実装ではなく運用上のギャップ

### F-9 repair commit の生成主体が Executor の外にある（info）

- `ExecContext.repair_commit_sha` は「呼び出し側（exec レーン）が実測して渡す」
  契約であり、Executor は commit を作らない（設計どおり・publish のみが責務）。
- 本実走でも `git add` / `git commit` はハーネス（人手）で行った。
- 含意: 「実 PR 1 周」を無人で回すには **commit を生成する exec レーン**が
  別途必要。本 PBI の scope 外だが、AC-4 の「1 周」を自動化する際の
  接続点として明示しておく。

### F-10 `repair_ci` intent は `assess()` から自然発生しなかった（info）

- 実 PR の CI は全 `success` であり `CHECKS_FAILED` に到達しないため、
  `repair_ci` action は `delivery._action()`（実物のコンストラクタ）で
  組み立て、`assess()` が書くのと**同一形状**の intent を record へ追記した。
- `executor.verify_action_id()` が `True` を返したことで、
  「捏造されない導出 `action_id`」の完全性検査が実データで機能することは
  確認できている。
- ただし **「`assess()` が発行した action をそのまま Executor へ渡す」経路**は
  本実走では通っていない（intent の形状一致で代替）。

## E. 検証済み（差異なし）の項目

| 検証項目 | 結果 |
|---------|------|
| REST GET 4 本の endpoint が allowlist を通る | PASS 4/4 rc=0 |
| 読み取り系 git 2 本が allowlist を通る | PASS 2/2 rc=0 |
| `checks[]` / `review` / `mergeable` / `required_checks` / `raw_check_runs` の各フィールド | PASS 全て期待どおり充填 |
| `verify_raw_evidence()` / `verify_snapshot_evidence()` の照合 | PASS フラグゼロ（不整合なし） |
| `allowed_paths` の plan.md 抽出 | PASS 21 件・`plan_deviation` 誤発火なし |
| 実行順序 (1) comment → (2) pre-check → (3) push → (4) receipt | PASS spawn ledger で実証 |
| push argv に `+` / `--force*` / `--delete` が現れない | PASS `git push origin HEAD:refs/heads/<branch>` のみ |
| receipt が subprocess を起動しない | PASS ledger に現れない |
| 冪等（receipt 済み action の再要求なし） | PASS `already_receipted` / spawn 0 回 |
| Reconciler の intent ↔ receipt 突合 | PASS 1:1 / pending 0 / orphan 0 |
| 禁止操作が allowlist の補集合として塞がれる | PASS merge / review / close 等は本実走で組み立てても実行してもいない |
