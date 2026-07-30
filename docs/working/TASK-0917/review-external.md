# 外部レビュー結果 — TASK-0917（pbi-input 段階）

> **追記専用**（`.claude/rules/working-context.md` §review-external.md）。既存エントリは編集・削除しない。
> 実施: 2026-07-30 / 対象: `docs/working/TASK-0917/pbi-input.md`（PR 作成前のローカルレビュー）
> 基点: main `b306b12`
> 注: 本ファイルは C-2（plan ゲート外部レビュー）ではなく **pbi-input 段階のレビュー**の記録。指摘 ID は同ルールの `R-NNN` 規約に従う。

## 実施レーン

| レーン | 担当 | 判定 |
|--------|------|------|
| 敵対的レビュー（claim-vs-actual 全数照合） | `explorer-agent` | **WARN**（critical 0 / major 3 / minor 2） |
| River Review（security + docs + adversarial） | `river-review` | **FAIL**（critical 1 / major 6 / minor 5 / info 1） |

**合計: critical 1 / major 9**。River Review が FAIL 判定を出したため、**PR 作成前に全件を反映**した。

## オーガナイザーによる裏取り（実測・critical と主要 major を全件確認）

| ID | 指摘 | 裏取りコマンド | 結果 |
|----|------|--------------|------|
| R-001 | 既存 hook（EH-9）が本 PBI の実行面を守れない | `sed -n '60,66p' scripts/hooks/check-delegation-commit-boundary.sh` / `python3 -c "json.load(...)['hooks'].keys()"` | **確認**。①L62-65 が `PLANGATE_DELEGATION_NOCOMMIT != 1` で即 `allow` → L106 に到達しない ②`.claude/settings.json` の hooks は `SessionStart` / `PostToolUse` / `Stop` の **3 本のみで PreToolUse に未配線** ③PreToolUse は Bash の command 文字列のみを見る |
| R-002 | `gh pr review --approve` が禁止列挙にない（approve は MERGE_READY の load-bearing 入力） | `grep -n "review_ok" scripts/ai-loop/delivery.py` / `grep -rn "pr review --approve" scripts/hooks/*.sh` | **確認**。L290 `review_ok = review["state"] == "approved" and review["sha"] == head`。禁止ガードは **0 件** |
| R-003 | AC-1 が正本 doc §4 と矛盾 | `grep -n "stale" docs/workflows/ai-loop/delivery-state-machine.md` | **確認**。§4 は「checks と head の SHA 不整合 → stale として **`WAITING_FOR_CHECKS`**（成功扱いにしない）」。`HUMAN_ESCALATED` ではない |
| R-005 | branch protection 側の後段防衛も承認を強制していない | `gh api repos/s977043/plangate/rulesets/14939019` / `.../branches/main/protection` | **確認**。`required_approving_review_count: 0` / `dismiss_stale_reviews_on_push: false` / `require_last_push_approval: false`。classic protection は **404 Branch not protected**。required check は `Markdown lint` 1 件のみ |
| R-007 | 「mock 前例なし」という U-1 の前提が不正確 | `grep -n "def _issue" scripts/ai-loop/test_discovery.py` | **確認**。L27 に fixture 生成関数が実在 |
| R-010 | `required_checks[]` の取得元は ruleset API（classic は使えない） | 上記 `gh api` 2 本 | **確認**。ruleset は 1 本のみ・`conditions.ref_name.include = ["~DEFAULT_BRANCH"]` |
| R-012 | `canonical_hash` の実装は今すぐ読める（U-6 は Unknown でない） | `grep -n "def canonical_hash" -A 10 scripts/ai-loop/c3_contract.py` | **確認**。L71-74 に実装（`sort_keys=True` / `separators=(",", ":")` / UTF-8 / `"sha256:"` prefix） |
| R-013 | `ta-56-delivery.sh` に「51 テスト」の stale コメント | `grep -n "51" tests/extras/ta-56-delivery.sh` | **確認**（L29） |

## 監査表（指摘 → 反映）

| ID | lane | severity | 概要 | status | notes |
|----|------|----------|------|--------|-------|
| R-001 | River | **critical** | 最重要リスク（Executor が `gh pr merge` を発行）の一次緩和として挙げた「既存 hook で block」が **3 重に不成立**（env gate / PreToolUse 未配線 / Bash 面のみで Python の `subprocess` を見ない）。かつ既存の禁止トークン走査をそのまま Executor に適用すると `gh` を呼べず In scope と両立不能、緩めると空振り | reflected | 実測裏取り表の該当行を事実へ訂正。**AC-5 を「in-process の gh 実行ラッパ + 許可サブコマンド allowlist」方式へ全面書き換え**（禁止は allowlist の補集合として自動成立させ列挙漏れを構造的に塞ぐ）。既存トークン走査は「ラッパ以外が `subprocess` を import しない」検査に用途限定 |
| R-002 | River | major | 禁止操作の列挙が `gh pr merge` のみで、**`gh pr review --approve`** / force push / branch 削除 / PR close / 非 GET api が抜けていた。approve は `MERGE_READY` の load-bearing 入力で、account pin できる主体は自 PR を approve でき **sockpuppet 承認**が成立する | reflected | merge 境界表を allowlist / 補集合の形へ再構成し全操作を列挙。Out of scope に**包括ルール**「PR の承認状態・存在・履歴を変える操作すべて」を追加 |
| R-003 | River | major | AC-1 が「不一致なら `HUMAN_ESCALATED`」を要求していたが、正本 doc §4 は `WAITING_FOR_CHECKS` と定めており **AC-7（判定規則不変）に違反**する。かつ「snapshot を拒否」する経路は `record.jsonl` に state entry を残さず **AC-6（#894 の no-progress 検知）と接続不能** | reflected | AC-1 を「正本に従う + pre-check 失敗は `escalation_flags` に理由コードを積んで `assess()` を通す（破棄・例外 exit を禁止）」へ修正 |
| R-004 | River | major | Collector の入力契約が未定義。`validate_snapshot()` の必須 13 キーのうち **GitHub API から取れるのは 5 つだけ**で、`allowed_paths`（`EXEC_RETURN` を駆動）・`findings[]`（`REVIEW_REPAIR` と `MERGE_READY` を駆動）・`dod_evaluated` 等の供給元が書かれておらず **plan が書けない** | reflected | **snapshot キー × 供給元マップ**（GitHub / git / plan-c3 / レビュー層 / ai-loop 制御層）を追加し、各キーの scope 帰属を明記。未確定分を **U-10** として明示 |
| R-005 | River | major | Executor の repair push が **人間の C-4 承認を stale のまま残す**（ruleset の `dismiss_stale_reviews_on_push: false` 実測）。承認済みコードと merge されるコードが不一致になる経路が Risks に未計上 | reflected | Risks に 1 行追加（一次緩和 = repair push 時に既存 approve の dismiss または明示通知コメントを必須発行し receipt に記録）。「後段防衛」の実測値も裏取り表へ記載 |
| R-006 | River | major | AC-7 が **定数単位**（`STATES` / `TRANSITIONS` / `PRIORITY_ORDER`）の差分ゼロしか課しておらず、`validate_snapshot()` / `assess()` 本体へ後方互換な分岐を足しても鳴らない = **Out of scope を破っても AC が通る** | reflected | AC-7 に**ファイル単位の差分ゼロ**（`git diff --stat origin/main -- delivery.py c3_contract.py c3prime_verify.py` = 0 行）を追加 |
| R-008 | River | major | In scope 5「raw check evidence 検証」に**定義も AC も Risk も無い**（正本にも「V2 候補」の一言だけ）。検証手段のない scope は exec で「やった / やってない」が判定不能 | reflected | 暫定定義（check-run の生レスポンスを同梱し `checks[]` の導出を機械照合）を与え **AC-9** を新設。あわせて「V2 送りにするか」を plan の第一論点として明記（**issue の In scope を pbi が勝手に削らない**方針で (a) 実施を既定にした） |
| R-009 | River | minor | 「issue #917 の Out of scope を継承」という見出しが不正確（#874 連携は issue では「依存 / 位置づけ」節にあり Out of scope ではない） | reflected | 見出しを「issue の 3 項目 + 本 pbi で追加した 2 項目」に変更し、該当行に注記 |
| R-010 | River | minor | U-3 / U-9 は ruleset 実測で閉じられる | reflected | 取得元（ruleset API の JSON パス・admin 権限要）と U-9（保護は default branch のみ・head ブランチの force push / 削除を止める platform ガードは無い）を解消済みとして転記 |
| R-011 | River | minor | `sync-plugin-plangate.sh` の whitelist は **L345 / L355 の 2 箇所**にあり、片方だけの追加は sync drift になる | reflected | Mode 見込みの記述を 2 箇所に具体化 |
| R-012 | 敵対 | major | U-6（`action_id` の正規化ルール）は `c3_contract.py` を読めば今すぐ解けるのに Unknown として先送りしていた | reflected | `canonical_hash` の実装（4 行）を転記して U-6 を解消。「Reconciler はこの関数を import して再利用し独自実装しない」と明記 |
| R-013 | 敵対 | minor | `ta-56-delivery.sh` L29 に「51 テスト」の stale コメントが残る（正は 57） | reflected | 再利用資産表に「plan の todo に 1 行の是正タスクを含める」旨を追記 |
| R-014 | 敵対 | major | AC-4 / AC-8 の検証基準が曖昧（「1 周通った」の目視判定 / 「明示される」だけで分類の正しさを保証しない） | reflected | AC-4 に test repository の名前確定・`tests/extras/` の固定シナリオ化・`evidence/e2e/` への証跡保存・手動実行手順を明記。AC-8 に供給主体名の明記 + モジュール境界の特定 + 分類の単体テストを要求 |
| R-015 | 敵対 | major | In scope 4（`required_checks[]` ⊇ 照合）と Out of scope（判定規則不変）/ AC-7 が衝突しうるのに In scope 側の記述が断定形だった | reflected | In scope 4 に「第一候補は Collector 側 pre-check に限定。`delivery.py` 本体へ分岐を足す案は Out of scope 改訂と AC-7 緩和が必要 → **plan 冒頭で決着**」を明記 |
| R-016 | 敵対 | minor | carve-out 表が ①② のみで ③ を欠く | reflected | 3 項目すべて記載し「本 PBI は ①② に該当・③ は変更対象外」と明示 |

## レビューが「問題なし」と確認した事項（再検証不要の記録）

- **claim-vs-actual**: 敵対レビューが 14 項目中 13 項目一致、River Review が 12 項目中 11 項目一致と判定。不一致はいずれも本監査表に計上済み（R-007 / R-016）
- **リンク健全性**: pbi が参照する **18 パスすべて実在**（MISS ゼロ）
- **issue AC の網羅性**: issue #917 の AC-1〜6 は**漏れなく** pbi に反映されている（AC-7 / AC-8 / AC-9 は pbi 独自の追加で、いずれも Out of scope の裏付け or 未定義事項の固定として整合的）
- **Mode = critical の妥当性**: ファイル数の検算（Collector / Executor / Reconciler の実装 + テスト = 6 / sync whitelist / doc / E2E シナリオ / plugin 追従 = **9〜12 本**）が pbi の「10 本超」見積りと整合。TASK-0873（接続先・critical）との一貫性も確認され「**過剰ではない**」と判定
- **U-2 / U-4 / U-5 / U-7 / U-8 は正当な plan 送り**（設計判断・外部依存の状態次第）

## 次アクション

1. ✅ 本ファイルへ R-NNN 集約
2. ✅ pbi-input への反映（critical 1 + major 9 + minor 6 の全件）
3. ✅ PR 作成 → C-4（Human レビュー・マージ）
4. ✅ マージ後に `PLANGATE_HOOK_TASK=TASK-0917` の専用セッションで plan 生成（**plan 冒頭の決着事項**: In scope 4 の実装層 / In scope 5 の去就 / AC-5 の allowlist 設計 / U-10 の supply chain）

---

## C-2 外部レビュー（plan 段階 / 2026-07-31）

> **追記専用**。ここでいう追記専用とは「**`R-NNN` 監査表エントリは不変**（編集・削除しない）」ことを指す。上記 `R-001`〜`R-016`（pbi-input 段階）の監査表エントリは一切変更していない一方、**pbi 段階節の「次アクション」欄のみ進捗マーカー（`⏳` → `✅`）を更新している**（進捗欄は監査対象の指摘記録ではないため。RR-05 で宣言と実態の乖離が指摘され本節で明確化）。
> 実施: 2026-07-31 / 対象: `docs/working/TASK-0917/plan.md` / `todo.md` / `test-cases.md`
> 基点: `origin/main` = `b45ab17` / ブランチ `task-0917-plan`
> 反映順序: `.claude/rules/working-context.md` §C-2 指摘の差分管理に従い **(1) 本ファイルへ R-NNN 集約 → (2) 1 回確定反映**。

### 実施レーン

| レーン | 読む対象 | 判定 |
|--------|---------|------|
| **River Review**（設計妥当性 + security + adversarial） | plan / todo / test-cases / pbi-input + 接続先実装（`delivery.py` / `plan_package.py` / `run-tests.sh`） | **FAIL**（critical 0 / major 10 / minor 4 / info 1） |
| **敵対的レビュー**（claim-vs-actual 全数照合） | plan の全主張 × 一次実測 | **WARN**（critical 0 / major 2 / minor 2 / info 2） |

**合計: critical 0 / major 12 / minor 6 / info 3**。River Review が FAIL 判定を出したため、**C-3 提出前に load-bearing な指摘を全件反映**した。

### オーガナイザーによる裏取り（load-bearing な指摘を全件一次実測）

| ID | 裏取りコマンド / 参照 | 実測結果 |
|----|---------------------|---------|
| R-017 | `grep -n "_path_allowed\|deviated\|cr_incomplete\|conflict_need" scripts/ai-loop/delivery.py` | **確認**。L234 `_path_allowed()` / L265-267 `deviated = [p for p in snapshot["changed_files"] if not _path_allowed(p, allowed)]` が `PRIORITY_ORDER` 2 位 `plan_deviation`（→ `EXEC_RETURN`）を駆動。`changed_files` を空で埋めると逸脱検知が**恒久 fail-open**。plan の D3 表に `changed_files` / `conflict_resolution` の行が**無い** |
| R-018 | `grep -n "review_ok" scripts/ai-loop/delivery.py` / REST `pulls/{n}/reviews` の実レスポンス | **確認**。L290 `review_ok = review["state"] == "approved"`（**小文字**）に対し REST の `state` は**大文字**（実測で `COMMENTED`）。同 endpoint は **配列**を返すが snapshot の `review` は単一 dict で縮約規則が無い |
| R-019 | `grep -n "CHECK_PENDING" scripts/ai-loop/delivery.py` / `validate_snapshot()` L144-147 | **確認**。`CHECK_PENDING = ("pending", "queued", "in_progress")` は check-run の **`status`** の値。`validate_snapshot()` は `checks[].conclusion` に `str` を要求（`None` 不可 → `invalid_snapshot`）。未完了 check-run の `conclusion` は null |
| R-020 | `sed -n '150,170p' tests/run-tests.sh` / `grep -n "test_plan_package" tests/extras/ta-5*.sh` | **確認**。`run-tests.sh` は python を一切呼ばず `if [ -d "$EXTRAS_DIR" ]` 直下の `for extra in "$EXTRAS_DIR"/ta-*.sh` で source するのみ。`test_plan_package.py` は ta-55 L39 / ta-56 L41 で `import plan_package, test_plan_package as tpp` と **fixture helper としてのみ** import され本体は未実行 |
| R-021 | `delivery.py` の `actions = [a for a in actions if a["action_id"] not in receipts]` / `test_tcE5_intent_without_receipt_rerequested` | **確認**。receipt 無しの intent は次 run で**再要求**される。plan の R-005 案②（コメント失敗を receipt に成功記録しない）と組み合わせると**同じ repair push が再実行**されうる |
| R-022 | `gh api repos/s977043/plangate/rules/branches/main --jq '[.[] \| select(.type=="required_status_checks") \| .parameters.required_status_checks[].context]'` | **確認**。→ `["Markdown lint"]` / **exit 0**。**ruleset id 不要**で実効ルールを取得できる。一方 plan が採っていた `rulesets/{id}` は `{id}` の解決手段が無く、一覧 `rulesets` は TC-29 の 4 endpoint allowlist 外で `Denied` |
| R-023 | `grep -o "AC-[0-9]" docs/working/TASK-0917/todo.md \| sort -u` | **確認**。**AC-6 が 1 度も出現しない**（AC-1〜5 / 7〜9 のみ）。plan の Step にも AC-6 割り当て無し。一方 test-cases は AC-6 に TC-12 / TC-13 を割り当て = **誰も書かないテスト** |
| R-024 | `python3` で `plan_package._extract_section` + `_PATH_RE` を実行 / `ls docs/workflows/ai-loop/` | **確認**。抽出 20 件に `docs/workflows/ai-loop/execution-runbook.md`（**実在**）が無い。`_path_allowed()` は末尾 `/` 以外**完全一致**のため runbook を編集した瞬間 `plan_deviation` → `EXEC_RETURN`。Step 11 の Output に **AC-9 の限界文が含まれていない** |
| R-025 | plan D2-A / TC-31 の記述 vs `pbi-input.md` AC-5 の列挙 | **確認**。plan / TC-31 は `subprocess` の import のみを検査対象にし `gh_exec.py` を除外 → **`gh_exec.py` 内の `os.system("gh pr merge 1")` を止めるものが設計上存在しない** |
| R-026 | `grep -n "def validate_snapshot" -A 45 scripts/ai-loop/delivery.py` | **確認**。`need()` は **12 キー**。`conflict_resolution` は `cr = snap.get(...)` / `if cr is not None and ...` の**任意キー**。常時出力すると `cr_incomplete` → `conflict_need = True` で**恒久 `CONFLICT`** |
| R-027 | `awk '/^## 4\./,/^## 5\./' docs/workflows/ai-loop/delivery-state-machine.md` | **確認**。§4 は「required check 集合の機械束縛は **V2 候補**。Phase 1 の後段防衛は C-4 Human レビュー + **branch protection**」= 本 PBI で stale 化する |
| R-028 | `grep -oE 'T-[0-9]+' todo.md \| sort -u \| wc -l` = **48**（当時）/ `sed -n '150,170p' tests/run-tests.sh` / `grep -rln "repair_commit\|dod_evaluated"` | **確認**。plan 本文の「実数 32」は誤り（`decision-log.jsonl` は 48 と正しく記録）。L155-160 は**コメント行**で実体は `if`/`for` の 2 行。producer grep の HIT には `tests/extras/ta-56-delivery.sh` と `plugin/plangate/...` の mirror も含まれる（**結論「producer 0 件」は不変**） |
| R-029 | `gh api --help` / `gh pr comment --help` | **確認**。`-F` は `gh api` では `--field`、`gh pr comment` では `--body-file` と**意味が異なる**。単一のグローバル正規化表は成立しない |
| R-030 | `grep -n "U-8" docs/working/TASK-0917/plan.md` | **確認**。plan が参照する Unknown は U-1 / U-3 / U-5 / U-7 / U-10 のみで **U-8 は不在**。`scripts/gh-s977043.sh` / `scripts/gh-pin-account.sh` も設計に現れない |
| R-031 | `python3 -c "import json;print(list(json.load(open('.claude/settings.json')).keys()))"` | **確認**。→ `['hooks']`。**`permissions` キー自体が存在しない**（plan の「`permissions` は `{}`」は不正確） |
| R-032 | `scripts/sync-plugin-plangate.sh` の drift-check CI | **確認**。CI は「sync 実行後に diff が無いこと」しか見ないため whitelist に足さなくても通る = **配布は必須ではなく選択**。配布すると `executor.py` / `gh_exec.py` が下流へ渡る |
| R-033 | `sed -n '25,32p' tests/extras/ta-56-delivery.sh` | **確認**。L27-29 は `python3 test_delivery.py` の**終了コードのみ**を見て「51 テスト」をハードコード出力する構造 |

### 監査表（指摘 → 反映）

| ID | lane | severity | 概要 | status | notes |
|----|------|----------|------|--------|-------|
| R-017 | River (M-1) | major | `changed_files` / `conflict_resolution` の供給元が D3 の表に無い。`changed_files` を空で埋めると `plan_deviation` が**恒久 fail-open** | reflected | plan D3 に 2 行追加。`changed_files` = 読み取り系 git allowlist の `git diff --name-only <base>...<head>`（新 endpoint を足さない）/ `conflict_resolution` = `resolve_conflict` receipt から三点再構成し**揃うときのみ出力**。test-cases に TC-35（正側）/ TC-36（空リスト fail-open 封じ）/ TC-37 を追加。todo T-25 に反映 |
| R-018 | River (M-2) | major | `review` の正規化・縮約規則が未定義（REST は**大文字**・**配列**、`delivery.py` は**小文字**・単一 dict） | reflected | plan D3 直後に「`review` の縮約規則」6 点を明記（head 束縛 / 最新 `submitted_at` / `DISMISSED` 除外 / `state.lower()` / 該当ゼロは `{"state":"none","sha":head_sha}` / `per_page` 明示の全件取得）。test-cases TC-01 に TC-01a/b/c を追加（大文字正規化 / 複数縮約 / **旧 head の APPROVED を採用しない**） |
| R-019 | River (M-3) | major | check-run の `status` → `conclusion` 写像が未定義。未完了 check の `conclusion` は null で `invalid_snapshot` に落ち、**AC-4 の 1 周が実 PR で回らない** | reflected | Approach Overview の check-runs 取得フィールドに `status` を追加し「`status != "completed"` のとき `conclusion = status`」を固定。test-cases に TC-39（`in_progress` → `WAITING_FOR_CHECKS` / 写像を外すと `invalid_snapshot` の変異注入）を追加。AC-4 マッピングにも TC-39 を追加 |
| R-020 | River (M-4) | major | 新規 unit test 6 本の実行導線が無く Stop Condition が**空振り**（`run-tests.sh` は python を呼ばない / `test_plan_package.py` は fixture helper として import されるだけ） | reflected | plan Step 8 / Verification Automation に **7 本**（新規 6 + `test_plan_package.py`）の `python3 .../test_*.py` を 1 モジュール 1 PASS 行で追加。**Stop Condition の下限を 430 → 437**（= 430 + 7）へ引き上げ、数え方を明記。todo T-33 / T-34 の Output・チェックポイントを更新 |
| R-021 | River (M-5) | major | 外部作用「後」・receipt「前」の中断で**二重作用**（AC-3 冪等と R-005 案②が衝突） | reflected | **裁定: 通知コメントを repair push より先に打つ**（コメント失敗なら push しない → 残骸は可逆な「余分なコメント 1 件」に限定）+ Executor の実行前 pre-check（`expected_parent_sha` が既に PR head の祖先なら skip）。plan に「外部作用の実行順序と二重作用の封じ込め」節を新設し **C-3 論点（Q3）に明示**。test-cases に TC-09b を追加、TC-E6 を順序前提へ更新。todo T-27 / T-28 に反映 |
| R-022 | River (M-6) | major | ruleset id の解決手段が無く、一覧 endpoint は allowlist 外。id 埋め込みは Q3 帰結（repo 設定非依存）と矛盾 | reflected | 取得元を **`repos/{o}/{r}/rules/branches/{base_ref}`** へ差し替え（GET 実証済み・exit 0 / `["Markdown lint"]`）。**複数ルールは union**。plan D1-A / Approach Overview / Metrics Evidence / test-cases TC-29 / todo T-25 をすべて差し替え。Q8 の未確認事項も追従 |
| R-023 | River (M-7) + 敵対 (F-04) | major | AC-6 に Work Breakdown Step / todo タスクが **0 件**（test-cases だけが TC-12 / TC-13 を割り当て = 誰も書かないテスト） | reflected | todo に **T-32「AC-6 接続点の統合テスト（TC-12 / TC-13）」** を新設（`files:` / `depends_on:` / `rollback:` 付き・T-31 直後）。plan Step 7 の Output / チェックポイントに AC-6 を明記。`grep -o "AC-[0-9]" todo.md` に AC-6 が現れることを確認 |
| R-024 | River (M-8) | major | 宣言した doc 更新先（`execution-runbook.md`）が Files / `allowed_paths` に無く、編集した瞬間 `plan_deviation`。Step 11 の Output に **AC-9 の限界文が欠落** | reflected | Files 表に `docs/workflows/ai-loop/execution-runbook.md` を **#19 として追加**（抽出対象＝21 件に）。Step 11 の Output を §4 **5 文**（AC-8 供給主体 / AC-5 scope 限界 / **AC-9 の限界** / R-027 の 2 文）へ更新。todo を T-41（§4）/ T-42（runbook）に分割。test-cases の AC-9 注記の記載先を「§4 / handoff / docstring」に統一 |
| R-025 | River (M-9) | major | AST 境界検査のトークン集合が pbi AC-5 から縮小され、`gh_exec.py` 内の `os.system` を止められない | reflected | 検査集合を `subprocess` / `os.system` / `os.popen` / `os.exec*` / `os.spawn*` / `urllib` / `socket` / `http.client` / `requests` / 動的 import へ拡張。`gh_exec.py` は「除外」ではなく**逆向きホワイトリスト検査**（`subprocess` のみ許可）へ変更。plan D2-A / test-cases TC-31 / todo T-4・T-5 を更新 |
| R-026 | River (M-10) + 敵対 (F-02) | major | 「必須 13 キー」は誤り（正: **12 + 任意 1**）。従うと `cr_incomplete` → **恒久 `CONFLICT`** | reflected | plan Step 5 チェックポイント + todo T-3 / T-25 の **計 3 箇所**を「必須 12 キー（+ 任意 `conflict_resolution`）」へ訂正し、「三点が揃うときのみ出力」をチェックポイント化。test-cases に TC-38（conflict 未発生時はキー自体を出さない）を追加。**`pbi-input.md` は main マージ済みのため編集せず**、plan 側に「pbi の 13 キーは誤り・本 plan を正とする」注記を追加 |
| R-027 | River (m-1) | minor | 正本 `delivery-state-machine.md` §4 が本 PBI で stale 化する | reflected | Step 11 / todo T-41 の §4 追記に 2 文追加（⊇ 照合は Collector pre-check として Phase 1 実装済み・フィールド化は V2 / branch protection は `required_approving_review_count: 0` のため後段防衛として当てにしない・issue #928 参照）→ §4 追記は**計 5 文** |
| R-028 | River (m-2) + 敵対 (F-01 / F-05) | minor | plan の実測値・相互参照のずれ 4 箇所 | reflected | ①Mode 判定のタスク数「実数 32」→ **実数 50**（`grep -oE 'T-[0-9]+' \| sort -u \| wc -l`。C-2 反映前は 48 で `decision-log.jsonl` と一致していた＝plan 本文だけが自己矛盾）②Risks の「todo T-30」→ **T-39**（T-30 は `reconciler.py` 実装）③Metrics Evidence の「L155-160 で glob 自動 source」→ **記号アンカー**（`$EXTRAS_DIR` の `for` glob source。L155-160 はコメント行）④producer grep の HIT 一覧に `ta-56-delivery.sh` と `plugin/` mirror を追記（**結論不変**）。あわせて触るファイル数 18 → **19**、Replan Trigger 23 → **24** を再計算 |
| R-029 | River (m-3) | minor | 短縮フラグ正規化がサブコマンド依存を無視（`-F` の意味が `gh api` と `gh pr comment` で異なる） | reflected | **正規化表を廃し「caller から短縮形は受け付けず即 deny・wrapper は常に long 形で argv を組み立てる」へ単純化**。plan の allowlist 手順 2. を書き換え、todo T-11 / T-16 と test-cases TC-24 を短縮形 deny 形へ更新（`-XPOST` / `--method=post` の分解ケースは残す） |
| R-030 | River (m-4) | minor | U-8（Executor の実行主体）が plan に無い | reflected | Questions / Unknowns に **9 件目**「Executor の実行主体 = `gh` 認証済みの手元環境（人間起動）に固定・CI 実行は scope 外」を追記。todo T-35 の前提に `gh auth status` / active account 確認を追加。`gh-s977043.sh` / `gh-pin-account.sh` は設計に組み込まない旨を明記 |
| R-031 | 敵対 (F-03) | minor | `permissions` は `{}` ではなく**キー不在** | reflected | plan D2-B 短所欄を「`permissions` キー自体が存在しない（トップレベルキーは `["hooks"]` のみ = deny 設定 0 件）」へ訂正 |
| R-032 | River (i-1) | info | plugin 配布同梱の可否が論点化されていない（drift-check CI は whitelist 未追加でも通る = 配布は選択） | reflected | **裁定: 配布する**（`delivery.py` 配布の前例と一貫・carve-out で保護）。ただし Questions / Unknowns に **10 件目**として「外部書き込み層（`executor.py` / `gh_exec.py`）を plugin 配布へ同梱してよいか」を **C-3 判断事項**として明記 |
| R-033 | 敵対 (F-06) | info | `ta-56-delivery.sh` のテスト件数ラベルがハードコードで将来また乖離する | reflected | 今回の scope は 51→57 の静的是正のまま。**V2 候補「件数ラベルの動的抽出」を Risks 末尾に 1 行 + todo T-50（handoff 記録）に追加** |

### レビューが「問題なし」と確認した事項（再検証不要の記録）

- **AC-7 baseline**: `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py` = **0 行**（本反映後も 0 行を実測）
- **`allowed_paths` 抽出の健全性**: `plan_package._extract_section` + `_PATH_RE` による抽出集合に `delivery.py` / `c3_contract.py` / `c3prime_verify.py` の**混入ゼロ**（不変 3 ファイルはバッククォート無しで記載する設計が機能している）
- **producer 0 件の結論**: HIT 一覧の補完（R-028）後も **producer は 0 件**で D3 の判断根拠は不変
- **Mode = critical / `lite_eligible=false`**: C-2 反映で規模がさらに増えた（19 ファイル / 50 タスク）ため判定は不変（引き下げ方向の指摘は 0 件）

### 次アクション

1. ✅ 本ファイルへ `R-017`〜`R-033` を集約
2. ✅ plan / todo / test-cases への **1 回確定反映**（本セッション）
3. ✅ **簡易 C-1 再実行**（反映後の plan / todo / test-cases に対する 25 項目チェック → 是正後 PASS。[`review-self.md`](./review-self.md)）
4. ✅ **Human C-3**（`approvals/c3.json` を `c3_status: APPROVED` で発行済み。Questions / Unknowns **10 件**の明示判断）
   - ⚠️ ただし下記 **River Review（PR 作成直前）** の反映で `plan.md` を再編集したため、**当該 `c3.json` の `plan_hash` は stale** となった。**C-3 再承認が必要**（`bin/plangate approve TASK-0917` を人間が再実行）

> ⚠️ `c3.json` の発行は **確定反映の後**（先に発行すると EH-3 が後続反映を mismatch 検知するため）。`bin/plangate exec` は APPROVED のみ受理する。

---

## River Review（PR 作成直前 / 2026-07-31）

> **追記専用**（`R-NNN` 監査表エントリは不変）。実施: 2026-07-31 / 対象: ブランチ `task-0917-plan` の差分（`plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md` / `INDEX.md` / `current-state.md` / `decision-log.jsonl`）
> 基点: `origin/main` = `b45ab17` / HEAD = `4ac6eff`
> 経緯: `.claude/rules/` の「PR 作成前は毎回セルフ + 複数エージェントレビュー / gh pr create 前に branch diff へ River Review をローカル実施」に従い、C-3 APPROVED **後・PR 作成前**に実施した追加レビュー。

**判定: FAIL**（critical 0 / **major 3** / minor 5 / info 2）

River Review が FAIL 判定を出したため、**PR 作成前に全件を処理**した。うち `plan.md` 本体の修正を要した 2 件（RR-02 / RR-03）に **`R-034` / `R-035`** を採番する。**`plan.md` を再編集したため `approvals/c3.json` の `plan_hash` は stale となり、C-3 再承認が必要**（`c3.json` は Human 承認トークンであり AI は作成・更新しない）。

### オーガナイザーによる裏取り（実測）

| ID | 裏取りコマンド / 参照 | 実測結果 |
|----|---------------------|---------|
| RR-02 / `R-034` | `grep -n "_past_repair_finding_types\|finding_type\|_resolved" scripts/ai-loop/delivery.py` / `grep -c findings docs/working/TASK-0917/todo.md` / `grep -c finding_type docs/working/TASK-0917/test-cases.md` | **確認**。L229-231 `_past_repair_finding_types()` は `repair_review` receipt 側の `finding_type` 集合を返し、L305 `recurrence` が snapshot 側 `findings[].finding_type` との**集合積**を取る。snapshot 側は Collector の変換アダプタ、receipt 側は Executor が供給するため**同一語彙でなければ積は常に空**＝`same_type_recurrence` が恒久 fail-open。`id` が run 間で不安定だと L195 `_resolved()` の disposition 突合が壊れ `unresolved_hard` が消えず `MERGE_READY` に到達しない。**todo の `findings` 出現 0 件 / test-cases の `finding_type` 出現 0 件**（タスクも TC も存在しない） |
| RR-03 / `R-035` | `grep -rn "^import subprocess\|^from subprocess\|import subprocess as" scripts/ai-loop/*.py` / `plan.md` の「argv 先頭要素 不変条件」1. | **確認**。現行ツリーは `import subprocess` のみ（`test_c3prime_verify.py:14` / `test_discovery.py:14` / `test_metrics.py:12`）で今は空振りしないが、不変条件は**属性呼び出し形**（`ast.Attribute(value=Name('subprocess'))`）を前提に書かれており、**exec で新規作成する test 6 本が `from subprocess import run` / `import subprocess as sp` を使うと照合をすり抜け検査器が clean を返す** |
| RR-04 | `review-self.md` の F-1 evidence 再現コマンド 1 を再実行 | **確認**。`TOTAL = 20` / `sys.executable 該当 = 17` / 違反 3（`test_c3prime_verify.py:42` / `test_discovery.py:530` / `test_discovery.py:559`）。本文の「21 箇所 / 18 箇所」は誤りだが**違反 3 箇所の内訳と裁定は不変** |
| RR-07 | `grep -n 'AI_LOOP_SCRIPTS_DIR/arbiter.py' scripts/sync-plugin-plangate.sh` / `grep -n 'arbiter.py\|test_arbiter.py' scripts/sync-plugin-plangate.sh` | **確認**。それぞれ **345 行 / 355 行**（現時点は一致）。ただし R-028 で `run-tests.sh` 側を記号アンカー化したのに sync-plugin 側 8 箇所（plan 4 / todo 2 / test-cases 2）は行番号のまま = 同型の stale 化リスクが残置 |
| RR-08 | `grep -n "skip-decision-log" scripts/hooks/check-plan-hash.sh` / `git check-ignore docs/working/_audit/skip-decision-log.jsonl` | **確認**。EH-3 は SKIP 判断のたび **tracked** ファイル `docs/working/_audit/skip-decision-log.jsonl` へ追記する。同ファイルは `allowed_paths` 21 件に**含まれない**ため、commit に混入すると `plan_deviation` → `EXEC_RETURN` を誘発する |
| info-1 | `python3 -c "…" docs/working/TASK-0917/decision-log.jsonl`（全 24 行の走査） | **反証**。「触るファイル数 18→19 / Replan Trigger >23→>24 の変更エントリが無い」は誤り。**24 行目のうち 21 行目**（`R-023 / R-024 反映で…`）に「Files は 18 → 19 本（`execution-runbook.md` 追加）、Replan Trigger は > 23 → > 24 へ再計算」が**既に記録済み**。よって重複エントリは追記しない |

### 監査表（指摘 → 反映）

| ID | severity | 概要 | status | notes |
|----|----------|------|--------|-------|
| RR-01 | major | `INDEX.md` が stale（現在フェーズ「C-1 待ち」/ `review-self.md`・`current-state.md`・`approvals/c3.json` が `⏳` / Questions「8 件」）で、C-1 PASS・C-2 反映・C-3 APPROVED の実態と乖離 | **fixed（オーガナイザーが `INDEX.md` を是正済み）** | 本ワーカーの担当スコープ外（再修正しない）。現在フェーズ / 各ファイル状態 / Questions 10 件へ更新済み |
| **RR-02** = **`R-034`** | major | `finding_type` の**語彙規則が未定義**で同型指摘の再発検知が fail-open。snapshot 側（Collector の変換アダプタ）と receipt 側（Executor の `repair_review`）が同一語彙でないと `_past_repair_finding_types()` の集合積が常に空になり `same_type_recurrence` が発火しない。`id` の決定論も未定義で `_resolved()` の disposition 突合が壊れうる。**todo に該当タスク 0 件 / test-cases に該当 TC 0 件**（実測） | reflected | `plan.md` D3 表の `findings[]` 行に語彙同一性 + `id` 決定論の 1 文を追加 / Step 6 チェックポイントに追記 / Metrics Evidence に実測 1 行追加 / **`todo.md` に T-51 を新設**（`files:` は既存 21 パス内の `collector.py` + `executor.py` + `test_reconciler.py` に収め `allowed_paths` を増やさない）/ **`test-cases.md` に TC-40 を新設**（正側 = `feedback_loop_referral` 発火 / 負側 = 語彙不一致で空振り / `id` 決定論）。AC 横断行に TC-40 を追加 |
| **RR-03** = **`R-035`** | major | AST 照合が **import 形を解決せず素通し**する。不変条件 1. は属性呼び出し形（`ast.Attribute(value=Name('subprocess'))`）前提で書かれており、exec で新規作成する test 6 本が `from subprocess import run` / `import subprocess as sp` を使うと照合をすり抜ける。plan 自身の「テストの単純除外は迂回路になる」という宣言目的が達成されない | reflected | `plan.md` の「argv 先頭要素 不変条件」1. に import 形解決 + 解決不能は fail-closed の 1 文を追加 / Testing Strategy の `test_check_exec_boundary.py` 行に追記 / `test-cases.md` TC-31 ③ に同文を反映 + **TC-31c を新設**（別名 `import subprocess as sp` / 直接 `from subprocess import run` / `check_output as co` の 3 形を変異注入して FAIL することを実証。解決を外すと 3 形とも clean になることも確認）。AC-5 マッピング行に TC-31c を追加 |
| RR-04 | minor | `review-self.md` の F-1 evidence の数値（「21 箇所 / 18 箇所」）が再現しない（実測 20 / 17） | reflected | **frozen な 25 項目判定表・指摘一覧・F-1 evidence 本文は編集せず**、末尾「C-1 指摘の是正記録」節に 1 行の訂正追記のみ（append-only 遵守） |
| RR-05 | minor | `review-external.md` の宣言（「追記専用」「`R-001`〜`R-016` は一切変更していない」）と実態の矛盾（pbi 段階節の「次アクション」2 行が `⏳`→`✅` に書き換わっている）。かつ C-2 節自身の次アクション 3./4. は完了済みなのに `⏳` のまま | reflected | C-2 節の宣言文を「**`R-NNN` 監査表エントリは不変**。pbi 段階節の『次アクション』欄のみ進捗マーカーを更新」へ明確化 + C-2 節の次アクション 3./4. を `✅` へ更新（4. には `plan_hash` stale・再承認要の注記を併記） |
| RR-06 | minor | C-2 / C-1 反映の追従漏れ 4 箇所 | reflected | ①`plan.md` L6「`R-001`〜`R-016` 全件反映済み」→ **`R-001`〜`R-035`** ②`plan.md` L7「B-2 比較（D1〜**D4**）」→ **D1〜D5**（D5 が実在）③Approach Overview「REST GET **3〜4 本**」→ **4 本**（todo T-25 / TC-29 は 4 endpoint で確定済み）④`test-cases.md` の **AC-3 マッピング行に `TC-09b` を追加**（TC-31b は AC-5 行に追加済みなのに TC-09b だけ非対称に漏れていた） |
| RR-07 | minor | 行番号アンカー `L345` / `L355` が 8 箇所そのまま（plan 4 / todo 2 / test-cases 2）。R-028 で `run-tests.sh` 側は記号アンカー化したのに sync-plugin 側だけ残置 = 同型の stale 化リスク | reflected | **8 箇所すべてに記号アンカーを併記**（for ループ = `for _f in "$AI_LOOP_SCRIPTS_DIR/arbiter.py" …` / case = `arbiter.py\|test_arbiter.py\|…) : ;;`）し、行番号は「2026-07-31 時点の**目安**」と明記。plan Step 10 に「exec では記号アンカーで grep して位置特定する」旨を 1 行追加 |
| RR-08 | minor | EH-3（`check-plan-hash.sh`）は SKIP 判断のたび tracked ファイル `docs/working/_audit/skip-decision-log.jsonl` へ追記する。同ファイルは `allowed_paths` 21 件の**外**であり、commit に混入すると `plan_deviation` → `EXEC_RETURN` を誘発する | reflected | `todo.md` **T-49（コミット整理）に 1 行追加** —「`docs/working/_audit/` への hook 由来追記は本 branch に含めず別 PR に分離する」。**`allowed_paths` を広げる方向の是正はしない**（AC-5 / scope を緩めるため） |
| info-1 | info | `decision-log.jsonl` に「触るファイル数 18→19 / Replan Trigger >23→>24」の変更エントリが無い | **invalid（実測で反証）** | 実測: `decision-log.jsonl` **21 行目**に既記録（「Files は 18 → 19 本…Replan Trigger は > 23 → > 24 へ再計算」）。**重複エントリは追記しない**。代わりに本 River Review の実施・`R-034` / `R-035` の裁定・`plan_hash` 無効化と再承認要を 3 エントリ追記した |
| info-2 | info | 生成物 `docs/working/TASK-0917/TASK-0917-c3-review.html` が untracked のまま残っている | reflected（方針明記） | **untracked のまま残す**（`bin/plangate render` で再生成可能）。`current-state.md` に「C-3 レビュー HTML は untracked（再生成可）。コミット時は `git add <path>` 明示で混入を防ぐ」を 1 行記載 |

### 次アクション

1. ✅ 本ファイルへ `RR-01`〜`RR-08` + info 2 件を集約（`R-034` / `R-035` を採番）
2. ✅ `plan.md` / `todo.md` / `test-cases.md` / `review-self.md`（是正記録節）/ `current-state.md` / `decision-log.jsonl` への **1 回確定反映**
3. ⏳ **Human による C-3 再承認**（`bin/plangate approve TASK-0917` を再実行し、**再編集後の `plan.md` の `plan_hash`** で `approvals/c3.json` を再発行）
4. ⏳ 再コミット → PR 作成 → C-4

> ⚠️ **`approvals/c3.json` は Human 承認トークン**であり、AI は作成・更新しない（`.claude/rules/responsibility-classes.md` / MEMORY `maintenance.json 発行元ギャップ`）。本反映では `c3.json` を**一切変更していない**（`git diff --stat HEAD -- docs/working/TASK-0917/approvals/c3.json` = 0 行で証明）。
