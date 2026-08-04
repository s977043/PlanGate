# PBI INPUT PACKAGE — TASK-0928

> Issue: [#928](https://github.com/s977043/plangate/issues/928)（**priority:P1** / governance / area:workflow・OPEN）— 「fix(governance): 承認境界の技術層・repo-wide 層の穴 3 件（PreToolUse 未配線 / ruleset の後段防衛空洞 / approve ガード 0 件）」
> 作成: 2026-08-04（**main `7bf5f5c` で再実測**。実効 settings / 監査ログは同日の live checkout を読み取り実測 — 全件実コマンド。二次情報は不使用）
> 起票時実測: 2026-07-31・base `b45ab17`。**起票後に ① が部分解消（EH-9 / EH-12 配線 + EH-12 実 block 証跡）・③ に in-process 層（#941）が追加**された一方、**② ruleset と ③ セッション層は不変**。本 pbi-input は現状の再実測を正とする（下表）
> 関連: [#917](https://github.com/s977043/plangate/issues/917) / PR #941（実 PR 収束・in-process allowlist）/ PR #967（EH-12・`c25c022`）/ [#870](https://github.com/s977043/plangate/issues/870)（EPIC）/ 責務: `.claude/rules/responsibility-classes.md`（settings 適用・権限操作 = Human-owned）

## Context / Why

PlanGate の承認境界は「規範層 / 技術層 / repo-wide 層」の三段防御で設計されているが、issue #928 起票時（2026-07-31）の実測で技術層・repo-wide 層の 3 つの穴が確認された。起票後に状況が動いている:

- **技術層は部分回復**: 実効 `.claude/settings.json` に PreToolUse 2 本（EH-9 + EH-12）が配線され、EH-12 は main 上の破壊的 git 操作を**実際に 5 回 block した証跡**がある（下記・発火実績）
- **in-process 層が新設**: PR #941 の `scripts/ai-loop/gh_exec.py`（default-deny allowlist）により、ai-loop Executor 経路では `gh pr review --approve` / `gh pr merge` は**補集合として組み立て不能**になった。ただし同モジュールの docstring 自身が「**同一セッションの Bash や別プロセスからの gh は塞がらない**」と回避不能ギャップを明示している
- **残る穴は不変**: ② ruleset の後段防衛（approving count 0 / dismiss stale false）と ③ セッション層の approve ガード 0 件はそのまま。`scripts/ai-loop/delivery.py` の `review_ok = review["state"] == "approved" and review["sha"] == head`（L290 付近）も現存し、**approve は MERGE_READY 到達の load-bearing 入力のまま**

つまり「AI が自分の承認を自分で発行する経路（セッション層の `gh pr review --approve`）」と「approve を stale のまま残して差し替える経路（repo-wide 層）」は依然開いている。本 PBI はこの 2 層を issue の AC 7 個どおりに塞ぐ。

### 鮮度再実測（作成時点 main = `7bf5f5c`・2026-08-04）

| # | 項目 | 起票時実測（2026-07-31 / `b45ab17`） | 現在の実測（コマンド / 結果） | 判定 |
|---|------|------|------|------|
| ①-1 | 実効 `.claude/settings.json` の hooks | SessionStart / PostToolUse / Stop の 3 本のみ（PreToolUse 0） | 同 3 本 + **PreToolUse 2 本** = EH-9 `scripts/hooks/check-delegation-commit-boundary.sh`（matcher: Bash）+ EH-12 `scripts/check-git-destructive.sh`（matcher: Bash・`scripts/` ルート配置 = HO 外）。ファイル読取で実測（mtime 2026-08-02 15:01） | **部分解消** |
| ①-2 | doctor | `[FAIL] PlanGate hooks not wired (7/10 expected hook block(s) missing)` | full doctor: `[FAIL] PlanGate hooks not wired (6/11 expected hook block(s) missing from .claude/settings.json)`（分母 11 = live checkout の example に EH-12 追記があるため。tracked example は 10 block のまま）。`bin/plangate doctor --check-settings`: **FAIL rc=1・不足 5 件** = EH-1 plan-exists / EH-2 c3-approval / EH-6 forbidden-files / EH-3 plan-hash / EH-3 の `PLANGATE_HOOK_FILE` 引数（**EH-9 は充足**） | 部分解消（残 = EH-1/2/3/6 の 4 block + EH-3 引数 + approval-token-write ×2 block） |
| ①-3 | permissions | `permissions` は `{}`（deny 0 件） | `settings.json` はキー自体なし / `settings.local.json` は allow のみ / example はキーなし → **deny 0 件 不変**（3 ファイル全数を Python で JSON 実測） | 不変 |
| ①-4 | （追加実測）apply 経路 | 未実測 | `sh scripts/apply-claude-settings.sh --dry-run`（live）= `適用予定: ['(変更なし)']` rc=0。**merge 経路の実装は「EH-3 引数付与」と「EH-9 block 取込」の 2 点のみ**（スクリプト全文読解）→ 現状態（EH-1/2/3/6 欠落）からは追補されず、実実行時は適用後検証（`check-settings-wiring.sh --target user`）で FAIL rc=1 に到達する見込み〔コード読解・実実行は Human-owned のため未実施〕。**併せて L71 の出力文言 `[apply] 既に契約準拠（変更なし）` は changed が空のとき無条件に出るため、Human が最初の 1 行だけ見ると「準拠済み」と誤認しうる**（実際は直後の wiring 検証で FAIL rc=1）→ merge 経路拡張時の文言是正を plan の scope 候補とする（Risks「適用したのに未準拠」行に紐づく・inf-1） | **AC-1 は apply 1 回で PASS しない**（要スクリプト拡張） |
| ②-1 | ruleset `id=14939019` | `required_approving_review_count: 0` / `dismiss_stale_reviews_on_push: false` / `require_last_push_approval: false` / `required_review_thread_resolution: true` | `gh api repos/s977043/plangate/rulesets/14939019` → **全値不変**（`updated_at: 2026-05-16` のまま = 起票前から無変更）。required_status_checks = `Markdown lint`（integration_id 15368）1 件のみ・strict true / `conditions.ref_name.include = ["~DEFAULT_BRANCH"]` | **不変** |
| ②-2 | classic branch protection | 404 Branch not protected | `gh api repos/s977043/plangate/branches/main/protection` → **404 不変** | 不変 |
| ②-3 | （追加実測）bypass | issue 未記載 | `bypass_actors: [{actor_id: 5, actor_type: RepositoryRole, bypass_mode: always}]` / `current_user_can_bypass: always` → **count>=1 にしても admin ロールは常時バイパス可**（AC-3 の設計論点として plan へ送る） | 新規判明 |
| ③-1 | hooks の approve ガード | `grep -rn "pr review --approve" scripts/hooks/*.sh` = 0 件 | `grep -rn "pr review" scripts/hooks/*.sh` = **0 件（rc=1）不変**。EH-12 実体も精読: 検出 class は `git-reset-hard` / `git-push-force(-refspec)` のみで case 文が `git` トークンを必須とする → **`gh pr review --approve` は検出対象外（block しない）** | 不変 |
| ③-2 | delivery.py の approve 依存 | `review_ok = review["state"] == "approved" and review["sha"] == head` | `grep -n "review_ok" scripts/ai-loop/delivery.py` → L290 に同文で現存 | 不変（load-bearing のまま） |
| ③-3 | （起票後の新層）in-process | 存在せず | PR #941 の `scripts/ai-loop/gh_exec.py` = **argv 構造照合の default-deny allowlist**（「禁止は allowlist の補集合として自動成立する。`gh pr merge` / `gh pr review --approve` / `gh pr close` 等を個別に列挙して塞ぐ設計ではない」と docstring 明記）+ `executor.py` に「NO MERGE BY AI: 本モジュールは merge / approve / close を一切組み立てない」。同 docstring が「in-process allowlist は**この Python プロセス経由の作用しか守らない**。同一セッションの Bash や別プロセスからの `gh pr merge` は塞がらず」と明示 | 新層追加。**本 issue の対象＝セッション / repo 層の穴は不変** |

### 発火実績（EH-9 / EH-12・一次ログ実測）

live checkout の `docs/working/_audit/hook-events.log`（untracked・約 1.9MB）を hook 名フィールドで機械集計:

- **EH-12（check-git-destructive）**: **VIOLATION（block）5 件** + SKIP 1 + BYPASS 1。内訳: 2026-08-02T06:02Z に 4 件（`git-reset-hard` ×3 / `git-push-force` ×1 — 適用直後）、**2026-08-04T00:33:44Z に 1 件**（TASK-0874・`class=git-push-force-refspec`・branch=main）→ **実 block 証跡あり**（issue AC-2 が求める「配線したが発火しない状態」ではない）
- **EH-9（check-delegation-commit-boundary）**: 同ログに **0 行**。ただしスクリプト実体の読解により、EH-9 は境界未宣言（`PLANGATE_DELEGATION_NOCOMMIT` ≠ 1）時に**ログを書かず allow** する設計 → 0 行は「宣言下の違反・bypass が 1 件も無い」ことしか意味しない。**AC-2 の発火証跡は宣言環境での能動テストが必要**（EH-9 は `gh pr merge` / `gh repo sync` を violation とする実装を持つ — case 文で確認済み）

### issue 記載との差異（正誤・plan で採用する値）

| issue の記述 | 実測 | 扱い |
|---|------|------|
| 「`settings.example.json` には PreToolUse **8 本**が配線済み」 | `b45ab17` の tracked example は **7 本**（EH-1/2/3/6/9 + approval-token-write ×2。総 block 10 = 起票時 doctor 分母 10 と整合）。8 本になっているのは live checkout の example のみ（EH-12 追記・**未コミット**） | plan では tracked 7 本を正とし、EH-12 の契約 / example 追従は U-1 で確定 |
| 「doctor = 7/10 missing」 | 現在 **6/11**（分子減 = EH-9 配線済 / 分母増 = live example の EH-12 追記） | 現況値。AC-1 の PASS 条件（`--check-settings` rc=0）は不変 |
| 「`permissions` は `{}`（deny 0 件）」 | 現在はキー自体なし（deny 0 件は同義） | 同義として扱う |
| 「`scripts/hooks/check-delegation-commit-boundary.sh`（③ のガード追加先の候補）」 | 候補として有効（HO 対象）。ただし起票後の前例として **EH-12 = `scripts/` ルート配置（HO 外）+ apply スクリプト + Human 適用**方式が確立（PR #967） | ③ の実装先は U-2 で確定（両案とも適用は Human） |

## What（Scope）

### In scope（3 件・issue の構成を保持し現状を追記）

| # | 穴 | 現状（2026-08-04 再実測） | 残作業の性質 |
|---|----|------|------|
| ① | `.claude/settings.json` の PreToolUse 未配線（settings drift） | PreToolUse 2 本（EH-9・EH-12）配線済み。残り = **EH-1 / EH-2 / EH-3（+ `PLANGATE_HOOK_FILE` 引数）/ EH-6 + approval-token-write ×2** | `apply-claude-settings.sh` の merge 経路拡張（AI-owned・HO 外）→ Human 適用 1 回 → doctor PASS + EH-9 発火証跡（宣言環境の能動テスト） |
| ② | main ruleset の後段防衛空洞 | 全値不変（②-1）+ bypass_actors always が新規判明（②-3） | Human の権限操作 1 回。AI は変更値の提案・検証手順書・証跡テンプレの提示まで |
| ③ | `gh pr review --approve` を止めるガード 0 件 | セッション層 0 件不変。in-process 層（ai-loop Executor 経路のみ）は #941 で default-deny 化済み | ガード新設 + 負側テスト（回避経路含む）。実装先（HO 内 hook 拡張 vs EH-12 型 `scripts/` ルート + apply 方式）は plan で確定 |

### Out of scope（issue verbatim + 再実測補足）

- #917 の Collector / Executor / Reconciler 実装そのもの（**PR #941 でマージ済み**。本 issue は repo / セッション層のみ）
- `.claude/settings*.json` の**適用**（self-mod ガード対象 = Human-owned。AI は script / patch の提示まで）
- ruleset / branch protection の**変更実行**（権限操作 = Human-owned。本 pbi-input 作成でも読み取り API のみ使用）

### Non-goals（issue verbatim + 本 PBI の指示制約）

issue #928 の Non-goals 3 件（verbatim）:

- in-process の gh 実行 allowlist（**#917 の AC-5 が担当**。本 issue は repo / セッション層の防衛であり、レイヤーが異なる）— 再実測: `gh_exec.py` として実装済み
- `.git/hooks/` の pre-push guard 適用（issue の関連実測 = 非 sample hook 0 件。再実測でも `core.hooksPath` は main の `.git/hooks` を明示指定・中身は現在も **非 sample 0 件** = TASK-0114 の `scripts/install-pre-push.sh` 未適用のまま。同種の層欠落だが本 issue の AC には含めない）
- sockpuppet 禁止ルール自体の改訂（規範層は既に存在する。本 issue は機械層の話）

本 PBI 固有の指示制約（Notes「指示制約」節に詳細）:

- **AI は `gh pr review --approve`（短縮形・別経路含む）を実行しない・自己承認や Human review bypass を実装/設定しない**
- bypass_actors の変更・削除は AC 外（② の設計論点として Human 判断へ）
- C-3 は同期固定・autonomous APPROVE 不可

### Suggested files（再実測反映）

- `scripts/apply-claude-settings.sh`（① の merge 経路拡張 — **HO 対象外**・AI 編集可）
- `.claude/settings.json`（Human 適用のみ）
- `.claude/settings.example.json`（**HO 対象** — `check-plan-hash.sh` L126 に `.claude/settings.json|.claude/settings.local.json|.claude/settings.example.json` として明示列挙され EH-3 が常時 block。AI は patch 提示まで／適用は Human）/ `docs/ai/settings-wiring-contract.md`（HO 外・AI 編集可）。（**EH-12 追従の要否を plan で確定** — 現在 contract に EH-12 の記載 0 件・tracked example 未収載・live example に未コミット追記あり。`scripts/apply-eh-git-destructive-guard.sh` が example と settings の両方を patch する設計のため生じた状態。U-1 が Yes なら**必ず HO ファイル編集が発生する**）
- `scripts/hooks/check-delegation-commit-boundary.sh`（③ 候補・**HO 対象**）または EH-12 前例に倣う `scripts/` ルート新規 + apply スクリプト
- GitHub ruleset `id=14939019`（Web UI / API。Human-owned）

## 受入基準

> issue #928 の **AC 7 個**を 1:1 で保持し、検証方法と責務を付与。plan で最終確定する。

- **AC-1**: `bin/plangate doctor --check-settings` が PASS する（① の解消。`sh scripts/apply-claude-settings.sh` は Human が実行）。検証: 同コマンド rc=0（現在: FAIL rc=1・不足 5 件）。**前提: apply スクリプトの merge 拡張が先行**（①-4 実測どおり現行スクリプトは現状態から PASS に到達しない）。拡張は AI-owned・適用実行は Human-owned。**この merge 経路拡張は #914 の doctor PASS ブロッカー解消として本 PBI とは別ブランチで先行実施される（Human 承認済み・2026-08-04）**ため、本 PBI ではその成果を前提に AC-1 の適用・検証のみを扱う（スクリプト実装は本 PBI の scope 外）
- **AC-2**: PreToolUse 配線後、EH-9 が `gh pr merge` を含む Bash 呼び出しに対して**実際に発火する**ことを 1 件の実行証跡で確認する。検証: `PLANGATE_DELEGATION_NOCOMMIT=1` の宣言環境で `gh pr merge` 相当（dry・実 PR 非対象）を投入し、hook-events.log に EH-9 の VIOLATION 行が記録されることを確認、`evidence/` へ複製保存。補足: EH-9 は未宣言時に無記録 allow の設計（現在 0 行）のため、証跡は能動テストで取得する。EH-12 の実 block 証跡（VIOLATION 5 件）は取得済み — 発火実績節を evidence へ転記
- **AC-3**: main ruleset の `required_approving_review_count >= 1` かつ `dismiss_stale_reviews_on_push: true` になる（② の解消。両方セットが必須）。検証: 変更後の `gh api repos/s977043/plangate/rulesets/14939019` 実測。変更操作は Human-owned・AI は変更値提案と手順書まで。**設計論点（plan で明記必須）: bypass_actors（admin always）残置の扱いと、solo 運用（GitHub は PR author の self-approve 不可 + sockpuppet 禁止）下で count>=1 が merge 運用に与える影響**
- **AC-4**: ② の変更後、`gh api repos/s977043/plangate/rulesets/14939019` の実測値を証跡として記録する。検証: `docs/working/TASK-0928/evidence/` に API 生 JSON。**前置条件: 変更「前」の `gh api repos/s977043/plangate/rulesets/14939019` 生 JSON を先に `evidence/` へ保存する**（読み取りのみ＝AI 実行可）。本 pbi-input の ②-1 / ②-3 行は 4 パラメータ + bypass の要約であり `rules[]` 全体を含まないため、前後差分の突合には生 JSON が要る
- **AC-5**: `gh pr review --approve` / `gh pr review -a` を block するガードが 1 つ以上存在し、**負側テストで固定**されている（③ の解消）。検証: ガード実体 + 負側テストの PASS ログ。実装先が HO 対象（`scripts/hooks/*.sh` 等）の場合、AI は patch 設計 + **sandbox / clean worktree での実適用テスト**（TASK-0872 方式。`--check` 単独は検証と見なさない）+ 負側テストまでを担い、**適用は Human-owned**
- **AC-6**: AC-5 のガードが「Bash コマンド文字列」面だけでなく、**回避経路（`-a` 短縮形・フラグ割り込み・連続空白）**を通さないことをテストで示す。検証: 回避 3 経路 + 複数行コマンド（EH-12 が実害で得た教訓 = `head -1` による 2 行目以降欠落）を含むテストケース。参考実装: `gh_exec.py` の「短縮形は long 化せず即 deny」「未知フラグは即 deny」
- **AC-7**: 3 件それぞれについて、解消後の実測値が `docs/working/TASK-XXXX/evidence/` 配下に記録される。検証: `docs/working/TASK-0928/evidence/` に ①=doctor 出力 + hooks 実測 / ②=API JSON / ③=負側テストログ が揃う

## Notes from Refinement

### 責務分担（前提・`responsibility-classes.md` 準拠）

| 領域 | AI-owned | Human-owned |
|------|----------|-------------|
| ① settings 配線 | `apply-claude-settings.sh` の merge 拡張（HO 外。ただし #914 側で先行実施）・doctor 検証・AC-2 発火テスト設計・tracked `settings.example.json` / contract への EH-12 収載 **patch の作成**（U-1 が Yes の場合） | `sh scripts/apply-claude-settings.sh` の実行（self-mod ガードにより AI は settings を編集不可）／**tracked `.claude/settings.example.json` への EH-12 収載 patch の適用（U-1 が Yes の場合。同ファイルは HO 対象 = `check-plan-hash.sh` L126）** |
| ② ruleset | 変更値の提案・検証手順書・証跡テンプレ | ruleset 変更の実行（権限操作）。AC-3 の値と bypass_actors の扱いの最終判断 |
| ③ approve ガード | patch / スクリプト設計 + sandbox / clean worktree での実適用テスト + 負側テスト（AC-5 / AC-6） | HO パス（`scripts/hooks/*.sh` 案の場合）の適用。`scripts/` ルート + apply 方式（EH-12 前例）の場合も**配線適用は Human** |

### Mode 判定案（plan で確定）

- 対象が承認境界そのものであり、HO 対象パス（`scripts/hooks/*.sh` 候補・`.claude/settings*.json`）に接触 → 例外ルール「承認境界周辺の変更 → 最低でも高」適用で**最低 high-risk**・**`lite_eligible=false` 強制**・**同期 C-3 固定**・autonomous APPROVE 不可（`mode-classification.md` / `working-context.md` AC-10 Hardening Override）
- 定量: AC 7 個（high 帯）。変更ファイル数はスライスにより 3〜8 想定（standard〜high 帯）→ 総合 **high-risk**（スライス分割で定量が下がっても引き下げない）

### 指示制約（自己承認の不許可・Non-goals 明記事項）

- 本 PBI のいかなる作業でも、**AI は `gh pr review --approve`（短縮形・別経路含む）を実行しない・自己承認や Human review bypass を実装/設定しない**（sockpuppet 禁止・NO MERGE BY AI と一貫）。AC-5 / AC-6 の負側テストは sandbox 内の hook 入力シミュレーション（stdin JSON 注入等の既存テスト方式）で行い、**実 PR への approve 投入は行わない**
- bypass_actors の変更・削除は本 PBI の AC 外（② の設計論点として記録し Human 判断に委ねる）
- C-3 は同期固定。自律実行指示があっても autonomous APPROVE 不可（HO 接触のため）

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| `apply-claude-settings.sh` の merge 経路が現状態（部分配線）をカバーしない（①-4 で実測） | Human が apply を実行しても PASS せず「適用したのに未準拠」が続く。加えて L71 の `既に契約準拠（変更なし）` 出力が誤認を後押ししうる（inf-1） | merge 拡張（**#914 側で先行実施・Human 承認済み 2026-08-04**）で追補予定 block を `--dry-run` 提示してから Human 適用を依頼する。文言是正も同拡張の scope 候補（適用後検証 FAIL による誤認防止は現行でも有効） |
| live example の EH-12 追記が**未コミット**のまま存在 | ① の contract / example 追従 PR が当該 hunk を巻き込む・または上書きで消す（#956 と同型の drift） | U-1 で EH-12 の契約化を先に確定し、example への反映は 1 PR に閉じる。exec 直前に live diff を再実測 |
| AC-3（count>=1）が solo 運用と衝突（author self-approve 不可 + sockpuppet 禁止 + bypass always 残置） | 「merge が常に bypass 経由」になり後段防衛の実効性が名目化する / 運用が止まる | ② の提案書に bypass_actors の扱いと運用パス（誰が approve するか）を明記し Human 判断へ。値変更のみ先行しない |
| EH-9 の発火証跡が受動的には残らない（未宣言 allow は無記録） | AC-2 が「配線済みだが証跡なし」で滞留 | 宣言環境（`PLANGATE_DELEGATION_NOCOMMIT=1`）での能動テストを test-cases に組み込む |
| ③ 新ガードの HO patch / apply の Human 適用遅延 | ガード実体が repo にあるのに実効しない期間が生じる（EH-12 と同じ「apply 待ち」状態） | EH-12 前例の apply スクリプト + doctor 検査追加で「未適用」を機械可視化。status.md で BLOCKED（blocker / owner / unblock_condition）管理 |
| 並行 PR が hooks / settings 周辺を変更し実測が stale 化 | plan の前提が崩れる | exec 直前に本表の再実測（コマンドは各行に記載済み）を再走する |

### Unknowns

- **U-1**: ① の契約範囲 — EH-12 を `settings-wiring-contract.md` / tracked `settings.example.json` / `doctor --check-settings` の検査対象に含めるか（現在: contract 記載 0 件・tracked example 未収載・live example に未コミット追記・doctor full の分母には live example 経由で算入済み）。含めない場合も「apply で消えない」ことの保証（merge 拡張は既存 block を削除しない設計にする）は必須
- **U-2**: ③ の実装先 — (a) 既存 EH-9 `check-delegation-commit-boundary.sh` の拡張（HO・patch 提示 + Human 適用。ただし EH-9 は「宣言下のみ到達」設計のため常時ガードには構造変更が要る）/ (b) EH-12 前例の `scripts/` ルート新規 + apply スクリプト方式（AI 実装可・適用のみ Human）/ (c) 併用。issue の Suggested files は (a) を候補としつつ、起票後に (b) の前例が確立した
- **U-3**: AC-3 の具体値と bypass_actors・solo 運用の整合（Risks 3 行目。最終判断は Human）
- **U-4**: AC-2 の証跡取得の具体設計（宣言環境の能動テストを evidence 化する手順・実 PR 非対象の担保）
- **U-5**: ①〜③ のスライス分割と順序 — Human 操作 2 種（apply 実行 / ruleset 変更）を待つ間の Deferred / BLOCKED 管理、③ の負側テスト先行（TDD）の単位。**AC-1（EH-3 配線）と AC-5（HO patch 作業）の前後関係**も含めて確定する: AC-1 が PASS すると EH-3（`check-plan-hash.sh`・matcher `Edit|Write`）が配線され、以後 `scripts/hooks/*.sh`（L129）への Edit/Write は maintenance 窓内でも常時 block になる（L122-134）→ U-2 案 (a) を採ると AC-1 後は AC-5 の patch 作成・sandbox 検証の手順が変わる
- **U-6**: **ガード無効化ベクタの扱い**（AC-6 の回避 3 経路に含まれない実在ベクタ。AC 本文は変えず plan で対処方針を確定する）
  - **(i) `PLANGATE_BYPASS_HOOK=1` による全面 allow**: EH-9（`check-delegation-commit-boundary.sh` L55-59）と EH-12（`check-git-destructive.sh` L85-89）が共通で持つ最優先 bypass。しかも `hook-events.log` には 4 件の VIOLATION（最後が `2026-08-02T06:02:29Z`）の **1 秒後**に `2026-08-02T06:02:30Z BYPASS PLANGATE_BYPASS_HOOK=1 set` が記録されており、**発火直後に bypass された実績がある**。approve クラスのガードで bypass を無効化するか（他 hook との慣行差の是非）を論点化する
  - **(ii) `pr review` 文字列を含まない approve 経路**: `gh api repos/.../pulls/N/reviews -f event=APPROVE` / `gh graphql`（`addPullRequestReview`）は文字列面ガードを素通りする。#941 の `gh_exec.py` が graphql を allowlist から外した理由そのもの（in-process 層は対処済み・セッション層は未対処）。検出対象に含めるかを確定する
  - **(iii) ガード実体の改変耐性**: U-2 案 (b)（`scripts/` ルート = HO 外）で実装すると「AI の自己承認を止めるガード」を AI 自身が編集できる構造になる（HO 正本 `check-plan-hash.sh` の case 文には L129 の `scripts/hooks/*.sh` はあるが `scripts/*.sh` は**無い**ことを実測確認済み）。実装先の HO 内/外と改変耐性のトレードオフを確定する

### Assumptions

- 実効 `.claude/settings.json` は **untracked**（fresh clone / worktree には存在しない）。doctor 判定は環境依存であり、本実測は user の main checkout（settings mtime 2026-08-02 15:01）に基づく。worktree では「settings.json 不在（settings 未適用）」FAIL rc=1 を別途実測済み
- `docs/working/_audit/hook-events.log` は live checkout にのみ存在（untracked）。証跡として使う行は `evidence/` へ複製して固定する
- issue の AC 7 個は現状でも 1:1 で有効（① は残り 6 block + 発火証跡に縮小、② ③ は不変のため意図が陳腐化していない）
- ruleset 変更・settings 適用は本 PBI 期間中も Human 以外に発生しない（発生した場合は exec 直前の再実測で検出する）
- 本 pbi-input の作成では HO 対象パス・`.claude/settings*.json`・ruleset への書き込みを一切行っていない（読み取り・dry-run のみ）
