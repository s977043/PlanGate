# C-2 外部レビュー — TASK-1093 (#1093)

> 対象: `origin/plan/1093-release-prep-detector`（head = `de8d714`）の Plan Package
> （`pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `evidence/*`）
> レビュア: 外部 C-2（2 レーン: 設計妥当性 / コードベース整合）
> 実施基準: [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md)
>   §2 5 観点 / §3 Severity 4 段階 / §4 判定基準 / §7-bis 2 レーン責務契約
> 実施日: 2026-08-15 / 比較 base = `origin/main` (`0385457`)
> 本ファイルは **追記専用集約**。plan / todo / test-cases は本レビューでは編集していない。

## 判定

**C2-VERDICT: REJECT**（critical=0 / **major=5** / minor=5 / info=3）

§4 の判定基準に従い `major >= 1` のため Auto-approve 不可。
うち **R-001 / R-002 は「plan の是正案が新しい穴を作る」クラス**、
**R-003 / R-004 は「本 PBI が閉じると宣言した穴が別経路で開き直る」クラス**であり、
C-3 前の plan 修正を推奨する（実装後の是正では AC の意味が変わるため）。

---

## 指摘一覧

### R-001 [major] `unknown` に脱出経路が無く、probe が書けない script が出た時点でリリースが恒久ブロックになる

- **レーン**: 設計妥当性
- **観点**: 拡張性 / 保守性
- **根拠（実測）**:
  - `plan.md` の 4 値表: `unknown`（probe 対象が無い / 評価不能 / 台帳に行が無い）→ **NG**。
    `ack` の記述は **`pending` にのみ**適用（「`pending` かつ `ack=#NNNN` → WARN」）。
    `unknown` に対する ack / 例外の定義が **plan・test-cases のどこにも無い**。
  - `SC-1` は「probe を実測で書けない script は `unknown` に倒し、握りつぶさず報告」と規定。
    つまり **SC-1 発火 = 恒久 NOT READY** で、解消手順が未定義。
  - 実際に probe が書けない script が存在する。**内容一致（`cmp -s` / `diff -q`）を
    「適用済み」の定義に持つ script が 4 本**:

    ```
    $ grep -ln "cmp -s\|diff -q" scripts/apply-*.sh
    scripts/apply-ai-loop-workflow-command.sh
    scripts/apply-precompact-guard.sh
    scripts/apply-reviewer-silence-gate.sh
    scripts/apply-subagent-delegation-wiring.sh
    ```

    `apply-ai-loop-workflow-command.sh` の適用済み判定は
    `if [ -f "$DST" ] && cmp -s "$SRC" "$DST"` = **2 ファイルの内容同値**であり、
    台帳の `probe_target` + `probe_expr`（単一ファイルに対する marker 評価）では
    **表現できない**。
- **推奨対応**:
  1. 台帳スキーマに **`probe_kind`（`marker` / `file-equal` / `order` 等）** を導入し、
     少なくとも `file-equal`（2 パス比較）を表現可能にする。
  2. それでも表現不能な script のための **`unknown` の運用出口**を plan に明記する
     （例: `unknown` + Human 承認済み `defer=#NNNN` は WARN、承認が無い `unknown` は NG）。
     出口を作らない設計なら「SC-1 が出たら release を止め Human が解消するまで進めない」
     と**明示的に受容**し、todo に Human タスクとして立てる。
  3. AC / TC を 1 本追加（`probe_kind` 未対応 script が存在するときの期待挙動）。

### R-002 [major] probe が「marker 文字列の有無」である限り、旧実装と同じ「表現を測る」クラスの穴が残る（かつ probe 品質を検証する TC が無い）

- **レーン**: コードベース整合
- **観点**: 保守性 / 可読性
- **根拠（実測）**:
  - `test-cases.md` の 穴(b) 行: 「script の stdout を見ず **対象ファイルの実装 marker** を probe」。
    実際に例示されている marker は**コメント行**である:

    ```
    $ grep -n "EHS-2 (TASK-0146" bin/plangate
    2248:  # EHS-2 (TASK-0146 / #527): --verify で handoff.md の 6 要素を検査
    ```

    実装本体を消してコメントだけ残す / コメントを別ファイルへコピーする、で
    **`applied` の偽陽性**が成立する。旧実装（stdout の文字列一致）と
    **同じ「表現を測る」クラス**であり、issue #1093 が禁じた
    「検出ロジックを書き換えた」を受入基準にしない、の趣旨に抵触しうる。
  - **負の対照（AC-2）が 34 本中 1〜2 本しか無い**: TC-04 / TC-05 は
    `apply-eh3-ho-always.sh` のみ、TC-06 は `apply-task-0146-ehs23-wiring.sh` のみ。
    「全 script の probe が正しい」という主張を支える TC が存在しない。
  - 変異注入 MUT-1〜5 はいずれも **検出器側の call site** を壊す変異で、
    **probe の妥当性**（marker だけ残して実装を壊す）を kill する変異が無い。
- **推奨対応**:
  1. 台帳に **probe 品質規約**を明記（marker は**実行されるコード行**に置く / コメント専用
     marker を禁止、または `probe_kind=order|structure` を優先）。
  2. **MUT-6 を追加**: 「`probe_target` の実装本体だけを壊し marker は残す」変異で
     当該 script が `pending`（または `unknown`）になることを実証する。
  3. AC-2 の負の対照を **1 本ではなく「適用済みと判定される全 script のうち抽出 N 本」**
     に広げる（件数は下限で書き、絶対値を契約にしない）。

### R-003 [major] cross-check 経路が「script を実行しない」という設計前提と矛盾し、(a) fail-open / (c) 環境依存が同経路で開き直る

- **レーン**: 設計妥当性
- **観点**: セキュリティ / 保守性
- **根拠（実測）**:
  - `plan.md` Approach 1: 「検出器は **script を実行せず**、probe を対象ファイルへ評価して」。
  - `plan.md` Approach 3: 「契約に適合する script は台帳 probe と突き合わせて **cross-check**」。
    cross-check の対象は `PLANGATE-APPLY-STATUS: applied|pending` という **stdout 1 行**であり、
    取得するには **script を実行するしかない**（静的検出のつもりなのか実行なのかが
    plan からは一意に決まらない）。
  - 実行するなら、本 PBI が閉じると宣言した (a) ERROR 時の扱い・(c) 実行環境差・
    無限ループ / タイムアウト・副作用が **再導入**される。にもかかわらず
    `test-cases.md` の cross-check TC は **TC-16（status と probe の不一致）1 本のみ**で、
    「実行が rc≠0」「出力が無い」「タイムアウト」の TC が無い。
  - `todo.md` T-07 は「現状 0 本適合＝経路が死んでいないことをテストで担保」とあり、
    **本番では 1 本も通らない経路**に対して例外挙動が未定義のまま残る。
- **推奨対応**:
  1. cross-check が **静的（ファイル内の契約宣言を読む）か動的（実行）か**を plan で確定する。
  2. 動的なら実行ガード（rc 捕捉 / timeout / 出力 0 行 → `unknown`）を仕様化し、
     TC を 3 本追加（rc≠0 / 出力なし / timeout）。**AC-4・AC-5 を cross-check 経路にも適用**する。
  3. 静的にするなら、契約の記述を「stdout に 1 行出力」ではなく
     「script 内に宣言行を持つ」へ変更する（実行不要になり (a)(c) を再導入しない）。

### R-004 [major] `ack`（リリースブロック抑止トークン）が AI 編集可能パスに置かれ、かつ ack 挙動の TC が 1 本も無い

- **レーン**: 設計妥当性 / コードベース整合
- **観点**: セキュリティ / 保守性
- **根拠（実測）**:
  - `plan.md`「既存 pending の扱い」: `pending` + `ack=#NNNN` → **WARN・READY を阻まない**。
    すなわち `ack` は **リリースゲートを解除する承認トークン**。
  - その置き場所 `scripts/apply-registry.tsv` は **Hardening Override 対象外**（実測）:

    ```
    $ sed -n '94,105p' scripts/hooks/check-plan-hash.sh
    _override=0
    case "$_norm_target" in
      .claude/rules/*.md) _override=1 ;;
      .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
      ... bin/plangate / scripts/hooks/*.sh / schemas/*.schema.json / .github/workflows/* / AGENTS.md|CLAUDE.md
    esac
    ```

    `scripts/*.tsv` は 9 カテゴリのいずれにも該当せず、**AI が書き換えても hook は block しない**。
    唯一の防御は `SC-2`（規範層）のみで、本 repo で過去に問題化した
    「AI が人間承認トークンを代理発行する」クラスと同型。
  - **ack の TC が存在しない**: `test-cases.md` で ack に触れるのは E-06（不正形式 → `unknown`）だけ。
    「`pending`+`ack` が WARN として**必ず表示**される」「READY を阻まないが不可視化しない」
    という plan の中核主張を実証する TC が無い。
- **推奨対応**:
  1. TC を 2 本追加: (i) `pending`+`ack=#NNNN` → **rc=0 かつ出力に script 名と issue 番号が必ず出る**、
     (ii) `ack` 付き行が 1 行増えたとき `git diff` に 1 行として現れる（監査可能性）。
  2. `ack` の**発行元**を明示（C-3 承認記録 / `decision-log.jsonl` への記録を必須化）。
  3. 可能なら `ack` の対象 issue が **OPEN であること**を検査に加える（close 済み ack の永久化を防ぐ）。

### R-005 [major] 新規 `tests/extras/ta-67-*.sh` が既存の extras 実行契約（ta-61 が機械強制）に一切言及しておらず、そのままでは AC-7（`run-tests.sh` rc=0）を自ら壊す

- **レーン**: コードベース整合
- **観点**: 保守性
- **根拠（実測）**:
  - `tests/extras/ta-61-extra-contract.sh` は **`ta-*.sh` 全件**に対し契約を強制する:

    ```
    $ grep -n "_T61_GLOB\|MARKER_ERE\|TC-09\|TC-10" tests/extras/ta-61-extra-contract.sh
    48:_T61_GLOB='ta-*.sh'
    218:_T61_MARKER_ERE='^[[:space:]]*#[[:space:]]*PG_EXTRA_CAPABILITY:[[:space:]]*(standalone-capable|harness-only)[[:space:]]*$'
    233: TC-09: marker count is $_t61_n (want exactly 1 in first 20 lines)
    252: TC-10: init capability ... != marker
    ```

    要求は最低限: 先頭 20 行に `# PG_EXTRA_CAPABILITY:` を**ちょうど 1 個** /
    `_extra-contract.sh` の `pg_extra_contract_init <basename> <capability>` /
    末尾 `pg_extra_contract_finalize` / rc 層 0/1/2/3 / standalone・harness 両対応 /
    7 env の unset / `register_cleanup` 利用。
    `_pending_migration` は**既存ファイル向けの移行期 allowlist**であり、新規ファイルは対象外＝
    **新規 ta-67 は初日から full 準拠が必要**。
  - `plan.md` / `todo.md`（T-11）/ `test-cases.md` に `PG_EXTRA_CAPABILITY` /
    `_extra-contract.sh` / rc 層への言及が **0 件**。
  - AC-7 は `sh tests/run-tests.sh` rc=0 を要求するため、非準拠 ta-67 を置いた瞬間に
    **ta-61 が FAIL し AC-7 が落ちる**（CI 経路も `.github/workflows/test.yml:28 run: sh tests/run-tests.sh`、
    `on: pull_request` で発火）。
- **推奨対応**:
  1. `todo.md` T-11 の 🚩 に「`tests/extras/README.md` + `ta-61` 契約準拠（marker / init /
     finalize / rc 層 / standalone 両対応）」を追加。
  2. `test-cases.md` に TC を 1 本追加: 「ta-67 単体を standalone 実行して rc 契約を満たす」
     + 「`ta-61` が ta-67 を covered set として PASS する」。

---

### R-006 [minor] `release-prep.sh` の `vX.Y.Z` 経路に rc 握り潰しが残る（同一ファイル・同一クラスの fail-open）

- **レーン**: コードベース整合 / 観点: 保守性
- **根拠（実測）**: `scripts/release-prep.sh:125` — `run_checks || true`。
  `sh scripts/release-prep.sh v8.21.0` は **NOT READY でも rc=0** で終わる。
  plan の Goal は「緑が出たときに『本当に適用待ちが無い』と言える構造」だが、
  この経路は「緑（rc=0）」を無条件に返す。plan / test-cases に言及なし。
- **推奨対応**: scope 内なら `--check` と同じ rc 伝播に揃える（または「意図的に継続する」旨を
  plan の Non-goals に明記して曖昧さを消す）。

### R-007 [minor] AC-6 の負の主張（TC-12「リリース前節に無い」）が空振りになる

- **レーン**: 設計妥当性 / 観点: 保守性
- **根拠（実測）**: `grep -rn "sync-plugin-installed" docs/` の結果、
  `docs/release-process.md` には **`sync-plugin-installed.sh` も `release-prep.sh` も元から 1 件も無い**
  （ヒットは `scripts/release-prep.sh` 本体・`docs/changelog.md`・
  `docs/working/_merge/v8.20.0-release-runbook.md:387` のみ）。
  つまり TC-12 の「前節に無い」は変更前から真であり、**退行を検出できない**。
  一方、実運用で手順 8 として列挙している `docs/working/_merge/*-release-runbook.md` は
  移設対象に含まれていない。
- **推奨対応**: TC-12 の負の主張を「`scripts/release-prep.sh` の `run_checks()` から
  `sync-plugin-installed` 参照が 0 件」（実際に変化する対象）に変更し、
  runbook テンプレ側の記載更新を scope に含めるか Non-goals に明記する。

### R-008 [minor] `scope=local` → `n/a` により、通常 checkout で現在唯一報告されている settings 配線の未適用シグナルが消える

- **レーン**: コードベース整合 / 観点: 保守性
- **根拠（実測）**: `.claude/settings.json` は untracked（`.gitignore:14`）。
  現行実装では通常 checkout で `apply-precompact-guard.sh` が pending 相当で NG を出すが、
  新設計では 3 本（`apply-claude-settings.sh` / `apply-precompact-guard.sh` /
  `apply-eh-git-destructive-guard.sh`）が**両環境で常に `n/a`**。
  AC-5（環境同値）としては正しいが、repo には既に専用検出器
  `scripts/check-settings-wiring.sh`（`bin/plangate doctor --check-settings` から委譲）が存在し、
  plan はそこへの導線に一切触れていない。
- **推奨対応**: `n/a (local)` 行の理由表示に
  「配線の検査は `bin/plangate doctor --check-settings`」を含める（1 行で解決、責務も既存正本に一致）。

### R-009 [minor] `docs/ai/ho-change-workflow.md` の既存 apply script 契約と新契約が衝突する

- **レーン**: コードベース整合 / 観点: 可読性
- **根拠（実測）**: 同ファイル「標準フロー」2 に既に契約がある —
  「**冪等**: 既適用ならスキップ / **`--dry-run`**: unified diff プレビュー /
  **引数 strict 検証**: `--dry-run` 以外の引数は exit 1 / **アンカー検証**: 挿入位置が
  見つからなければ exit 1」。
  plan Step 6 の新契約「`--dry-run`（および引数なし）は非破壊・**`rc=0`**」は、
  既存の「アンカー不在なら exit 1」と**同一文書内で矛盾**する
  （既適用 script は現に rc=1 を返す。例: `evidence/apply-dryrun-matrix.txt` の
  `apply-claude-md-v8190.sh|rc=1` / `apply-task-0146-ehs23-wiring.sh|rc=1`）。
  また既存の「`--dry-run` 以外の引数は exit 1」は `--apply` を持つ現行 script 群と既に不整合。
- **推奨対応**: 新契約の追記時に**既存箇所を同時に整理**し、rc 規約を 1 か所に統合する
  （追記だけして矛盾を残さない）。plan の Step 6 に「既存記述との整合を取る」を明記。

### R-010 [minor] sandbox 複製コストが CI の job timeout に対して無計画

- **レーン**: 設計妥当性 / 観点: パフォーマンス
- **根拠（実測）**: `du -sh docs scripts tests bin .claude` → `docs` だけで **18M**（計 ~22M）。
  test-cases は repo 複製 sandbox を TC-01 / TC-05 / TC-07 / TC-08 / TC-09（×2）/ TC-15 / TC-16 /
  MUT-1〜5 で使用＝**十数回**。`.github/workflows/test.yml` の job は `timeout-minutes: 10`。
- **推奨対応**: sandbox は `scripts/` + `tests/` + `bin/` + `.claude/`（`docs/` 除外）の
  最小サブツリー複製にする、または 1 回の複製を使い回す方針を Testing Strategy に明記。

---

### R-011 [info] 穴 (b) のもう 1 つの実例 `apply-ai-loop-workflow-command.sh` の期待 verdict が未定義

- **レーン**: 設計妥当性
- **根拠（実測）**: issue #1093 は穴 (b) の実例を **2 本**挙げている
  （`apply-ai-loop-workflow-command.sh` = 差分が逆方向・適用すると退行、
  `apply-task-0146-ehs23-wiring.sh` = 無条件ヘッダ）。
  plan は AC-3 / TC-06 で後者のみを扱い、前者は「Out of scope（別 issue）」。
  新判定でこれが `pending` になるなら「適用すると退行する項目を pending と報告し続ける」
  状態が温存され、READY を通すには `ack`（＝Human 判断・SC-2）が必要になる。
  R-001 とも連動（`cmp -s` 型で probe が書けない）。
- **推奨対応**: 期待 verdict（`pending` + `ack=<別 issue>` / `unknown`）を plan に 1 行で明記し、
  U-1 の Human 判断項目に**名指しで**含める（現状 U-1 は「新規可視化される pending」の総称）。

### R-012 [info] 「34」が Work Breakdown / evidence に絶対値として残る

- **根拠（実測）**: `plan.md` Step 1 🚩「34 本全数であることを `ls | wc -l` と同値照合」、
  Step 2「34 行の probe 記述」、`todo.md` T-01 / T-04、`evidence/apply-dryrun-matrix.txt` は 34 行。
  実測でも現在 34 本（`ls scripts/apply-*.sh | wc -l` → 34）。
  TC-14 が `comm -3` の集合同値で書かれている点は**適切**で、契約値化は回避できている。
  ただし plan / todo の 🚩 が「34」を判定条件として書いており、
  apply script が増えた瞬間に**チェックポイントの文言が誤り**になる。
- **推奨対応**: 🚩 を「`ls scripts/apply-*.sh` の集合と台帳の集合が `comm -3` で空」に統一し、
  数値は evidence 内の**測定値（測定日付き）**としてのみ残す。

### R-013 [info] 現行 `--check` の副作用懸念は棄却（反証済み）

- **根拠（実測）**: 現行 `check_pending_applies()` は 34 本を実行するため副作用を疑ったが、
  `scripts/apply-claude-settings.sh` は `--dry-run` 時に
  `[ "$DRY" -eq 1 ] && { printf '[apply] --dry-run: コピーせず\n'; exit 0; }` で
  書き込み前に離脱しており、`.claude/settings.json` を生成しない。
  よって「現行 `--check` が settings を書き込む」という懸念は**成立しない**。
  なお新設計は script 実行そのものを廃するため、この面では厳密に改善（R-003 の cross-check を除く）。

---

## 良かった点（維持を推奨）

- **穴 (a)(b)(c)(d) + NG-2 が AC / TC に 1:1 でマップされている**（`test-cases.md` の対応表）。
  issue の 4 穴すべてに対応 TC がある。
- **AC-1 の実証を履歴合成に頼らず HEAD 実機で成立させた**（R-4 緩和）。
  実測でも裏取り可能: `grep -c "P-NNN" .claude/rules/working-context.md` → 0、
  `grep -c "Stop Condition\|Resume Condition\|Replan Trigger" .claude/rules/working-context.md` → 0
  ＝ `apply-rnnn-c4-extension.sh` / `apply-task-0130-working-context.sh` は真に未適用。
- **TC-04 の前提（`apply-eh3-ho-always.sh` は HEAD で適用済み）が正しい**。
  `scripts/hooks/check-plan-hash.sh` の `_override=0` ブロック（94 行目付近）は
  `if [ -z "$task_id" ]` より**前**にあり、#1089 は適用済み。
- **行番号アンカーの不使用**: plan / test-cases を `L[0-9][0-9]` で grep → **0 件**。
  `check_pending_applies()` / `_override=0` 直後の `case` ブロックという**記号アンカー**で参照しており、
  `mode-classification.md` の注意（行番号アンカー禁止 / #1089）に準拠。
- **絶対件数の契約化回避**: TC-13（`run-tests.sh` は rc のみ・件数は記録）/ TC-14（集合同値）は
  過去の実害（無関係 PR の CI 破壊）を正しく踏まえている。
- **Mode 判定 high-risk と付随要求が一貫**: `lite_eligible=false` / C-2 必須 /
  人間 C-3（autonomous 不可）が plan と `todo.md` H-1 で一致。HO 判定も実測と一致
  （`scripts/release-prep.sh` / `scripts/apply-registry.tsv` / `tests/extras/*` / `docs/**` は
  HO 9 カテゴリに非該当）。

## 反証を試みて棄却した指摘候補

| 候補 | 棄却理由（実測） |
|------|----------------|
| 「`n/a (local)` は AC-5 を満たさない / 抜け道」 | `.claude/settings.json` は `.gitignore:14` で untracked。tracked 限定は AC-5 の解として妥当。ただし signal 消失は R-008（minor）として残した |
| 「現行 `--check` が `.claude/settings.json` を書き込む副作用がある」 | `apply-claude-settings.sh` の `--dry-run` 早期 exit を確認し**棄却**（R-013） |
| 「台帳カバレッジ照合は CI で強制されない」 | `tests/extras/ta-*.sh` は `tests/run-tests.sh` が source し、`.github/workflows/test.yml:28` が `on: pull_request` で実行。**TC-14 は CI 強制される**ため棄却。ただし `release-prep.sh --check` 自体は CI 未配線（下記 info 参照） |
| 「plan が CI 配線（HO）を前提にしている」 | plan の Files 表は `.github/workflows/*` を「触らない」と明記。CI 配線を前提とする AC は無く**棄却** |
| 「行番号アンカーが使われている」 | `L[0-9][0-9]` grep → 0 件。**棄却** |
| 「`34` が契約値として TC に埋まっている」 | TC-14 は `comm -3` の集合同値。契約値化は無し。plan/todo の 🚩 文言のみ → info（R-012）へ格下げ |

> 補足（info）: `release-prep.sh --check` は **どの workflow からも呼ばれていない**
> （`grep -rn "release-prep" .github/` → 0 件）。したがって本 PBI の判定強化は
> 「Human がリリース時に手で走らせたとき」にのみ効く。plan はこれを主張していないため
> 指摘化しないが、台帳 drift の検出が CI 側（TC-14）に閉じている点は handoff の既知課題に残すのが望ましい。

## 監査表

| R-NNN | severity | lane | status | reflected_in | notes |
|-------|----------|------|--------|--------------|-------|
| R-001 | major | 設計妥当性 | open | — | `unknown` に出口が無く SC-1 発火＝恒久 NOT READY。`cmp -s` 型 4 本は probe 表現不能 |
| R-002 | major | コードベース整合 | open | — | marker=コメントで偽陽性。probe 品質の変異（MUT-6）と負の対照の拡張が必要 |
| R-003 | major | 設計妥当性 | open | — | cross-check が実行を要し (a)(c) が再導入。静的/動的の確定 + ガード TC 3 本 |
| R-004 | major | 設計妥当性 | open | — | `ack` は非 HO パスの承認トークン。ack 挙動の TC が 0 本 |
| R-005 | major | コードベース整合 | open | — | ta-61 extras 実行契約に未言及。非準拠なら AC-7 が自壊 |
| R-006 | minor | コードベース整合 | open | — | `release-prep.sh:125` の `run_checks \|\| true` |
| R-007 | minor | 設計妥当性 | open | — | TC-12 の負の主張が空振り。runbook 側が未カバー |
| R-008 | minor | コードベース整合 | open | — | `n/a (local)` 行に `doctor --check-settings` 導線を |
| R-009 | minor | コードベース整合 | open | — | ho-change-workflow.md の既存契約と rc 規約が矛盾 |
| R-010 | minor | 設計妥当性 | open | — | sandbox 複製 ~22M × 十数回 vs `timeout-minutes: 10` |
| R-011 | info | 設計妥当性 | open | — | `apply-ai-loop-workflow-command.sh` の期待 verdict 未定義 |
| R-012 | info | 設計妥当性 | open | — | 🚩 の「34」を集合同値表現へ |
| R-013 | info | コードベース整合 | rejected | — | 反証済み（現行 `--dry-run` に副作用なし） |

## 検証コマンド（再現用）

```sh
# 対象取得
git fetch origin plan/1093-release-prep-detector
git diff --stat origin/main..origin/plan/1093-release-prep-detector   # 7 files, +602

# R-001
grep -ln "cmp -s\|diff -q" scripts/apply-*.sh                          # 4 本
# R-002
grep -n "EHS-2 (TASK-0146" bin/plangate                                # コメント行
# R-004
sed -n '94,105p' scripts/hooks/check-plan-hash.sh                      # HO 9 カテゴリに .tsv 無し
# R-005
grep -n "_T61_GLOB\|MARKER_ERE" tests/extras/ta-61-extra-contract.sh
grep -n "run-tests" .github/workflows/test.yml                         # :28
# R-006
grep -n "run_checks" scripts/release-prep.sh                           # :125 || true
# R-007 / R-008
grep -rn "sync-plugin-installed" docs/ scripts/
grep -n "settings" .gitignore                                          # :14 untracked
# R-010
du -sh docs scripts tests bin .claude                                  # docs 18M
# 良かった点の裏取り
grep -c "P-NNN" .claude/rules/working-context.md                       # 0（真に未適用）
git show origin/plan/1093-release-prep-detector:docs/working/TASK-1093/plan.md | grep -c "L[0-9][0-9]"  # 0
```

## C-3 への申し送り

- **REJECT の主因は R-001 / R-003 / R-005**（設計上の未定義 + 既存契約の未参照）。
  いずれも **plan / test-cases の修正で解消可能**で、実装をやり直す性質ではない。
- 反映は [`working-context.md`](../../../.claude/rules/working-context.md) の順序に従い
  **(1) 本ファイルに R-NNN 集約（済） → (2) 1 回確定反映（`Refs: R-NNN`）→ (3) 簡易 C-1 →
  (4) 人間が確定後 plan_hash で `c3.json` 発行 → (5) exec**。
- U-1（初期 ack の是非）は **R-004 / R-011 と併せて**判断されたい
  （ack は本 PBI 唯一のリリースゲート解除経路であり、発行元の定義が未確定）。
