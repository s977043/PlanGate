---
task_id: TASK-0921
artifact_type: review-external
schema_version: 1
status: draft
verdict: WARN
reviewer_tool: claude-subagent-2lane
created_by: orchestrator
---

# TASK-0921 外部AIレビュー結果（C-2）

> レビュー実施日: 2026-08-05
> 対象: TASK-0921 / issue [#921](https://github.com/s977043/PlanGate/issues/921) / base `origin/main` = `516e2f7`
> 対象成果物: `plan.md` / `todo.md` / `test-cases.md`（+ 参照として `pbi-input.md` / `review-self.md`）
> 実施レーン: **設計妥当性レーン** / **コードベース整合レーン**（[`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis の 2 レーン責務契約に従う）
> 判定: 両レーンとも **CONDITIONAL** — critical=**0**, major=**11**（設計 6 + 整合 5）, minor=**6**, info=**3**

**本ファイルは追記専用（append-only）**。[`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) の `### review-external.md` 節に従い、C-2 と外部指摘を `R-NNN` として本ファイルへ集約する。計画本体（`plan.md` / `todo.md` / `test-cases.md`）への反映は**別ステップで 1 回だけ確定**する（本ファイル作成時点では計画本体を一切変更していない）。

## 外部レビュー実行可否（必須）

| 項目 | 内容 |
|------|------|
| **実行状態** | `executed`（両レーンとも実行済み） |
| **実行不可の理由** | 該当なし |
| **代替レビュー観点** | 該当なし |
| **未充足リスク** | 該当なし |

> 両レーンとも実行済みのため、[`docs/ai/external-reviewer-interface.md`](../../ai/external-reviewer-interface.md) §10 の `unavailable` には該当しない。finding は下記のとおり。

## サマリー

| severity | 件数 | R-NNN |
|----------|-----:|-------|
| critical | 0 | — |
| major | 11 | R-001〜R-006, R-012〜R-016 |
| minor | 6 | R-007〜R-010, R-017, R-018 |
| info | 3 | R-011, R-019, R-020 |
| **合計** | **20** | R-001〜R-020 |

### レーン別内訳

| レーン | verdict | critical | major | minor | info | R-NNN 範囲 |
|--------|---------|---------:|------:|------:|-----:|-----------|
| 設計妥当性レーン | CONDITIONAL | 0 | 6 | 4 | 1 | R-001〜R-011 |
| コードベース整合レーン | CONDITIONAL | 0 | 5 | 2 | 2 | R-012〜R-020 |

### 元 ID → R-NNN 対応表

| R-NNN | レーン | 元 ID |
|-------|--------|-------|
| R-001 | 設計妥当性 | R-001 |
| R-002 | 設計妥当性 | R-002 |
| R-003 | 設計妥当性 | R-003 |
| R-004 | 設計妥当性 | R-004 |
| R-005 | 設計妥当性 | R-005 |
| R-006 | 設計妥当性 | R-006 |
| R-007 | 設計妥当性 | R-007 |
| R-008 | 設計妥当性 | R-008 |
| R-009 | 設計妥当性 | R-009 |
| R-010 | 設計妥当性 | R-010 |
| R-011 | 設計妥当性 | R-011 |
| R-012 | コードベース整合 | F-1 |
| R-013 | コードベース整合 | F-2 |
| R-014 | コードベース整合 | F-3 |
| R-015 | コードベース整合 | F-4 |
| R-016 | コードベース整合 | F-5 |
| R-017 | コードベース整合 | F-6 |
| R-018 | コードベース整合 | F-7 |
| R-019 | コードベース整合 | F-8 |
| R-020 | コードベース整合 | F-9 |

## 設計妥当性レーン（R-001〜R-011）

> 読む: `plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md`。読まない: 実装コード（原則）。
> 主眼: plan の論理・受入基準網羅・スコープ整合。

### R-001 AC↔TC 写像が 2 本存在し全行不一致

- **severity**: major
- **該当**: `plan.md:354-359`（`### Success Criteria`）vs `test-cases.md:104-111`（`## Traceability`）
- **指摘**: **AC↔TC 写像が 2 本存在し全行不一致**。plan `- AC-3: TC-07/08/11` に対し test-cases は `AC-3 → TC-01, TC-14, TC-15`。issue AC-3 は「`sh tests/run-tests.sh` が回帰しない（source 経路で exit しない）」なので plan 側が誤対応。plan `- AC-5: TC-12` も無関係。plan の写像は TC-01〜13 しか参照せず **TC-14〜TC-18 が 1 つの AC にも紐づかない**。
- **是正案**: plan の `### Success Criteria` を削除し、test-cases の `## Traceability` を**単一正本**にする。

### R-002 最優先の実害経路が塞がらない（exit 3 の意味レイヤー不在）

- **severity**: major
- **該当**: `plan.md:317` / `test-cases.md:67`（TC-13）/ `test-cases.md:85`（TC-17）
- **指摘**: **最優先の実害経路が塞がらない**。pbi-input AC-2 (c)（`pbi-input.md:178`）は「前提未充足 SKIP 状態での rc が『検査していない』を表明する（例: exit 3）。**rc=0 は不可**」と明記。しかし `plan.md:317` は `normal standalone-capable全件rc0（prerequisite SKIPは0可、unexpected [FAIL]不可）`、TC-17 は `prerequisite が absent なら normal standalone exits 0`。`exit 3` の意味レイヤーは全 3 文書に不在。結果 `scripts/apply-eh3-doc-light.sh:68` が案内する `sh tests/extras/ta-39-eh3-doc-light.sh` は適用失敗時こそ早期 SKIP で rc=0 を返し続ける。
- **是正案**: rc 意味レイヤーに **exit 3 =「前提未充足＝検査していない」** を追加し `## Contract RC Table`（`test-cases.md:5-11`）へ 1 行追加。TC-17 を「prerequisite 不在 → **rc=3**」へ反転。`tests/extras/ta-43-*.sh:56` / `tests/extras/ta-44-*.sh:49` も同 TC の対象に含める。

### R-003 移行対象の起点集合が過小（層 0 の 4 本が落ちている）

- **severity**: major
- **該当**: `plan.md:69`, `plan.md:75`
- **指摘**: plan の移行対象の起点集合が過小。`ta-40` / `ta-58` / `ta-59` / `ta-60` が **plan・todo・test-cases に 0 ヒット**（pbi-input には各 3〜13 件）。`plan.md:75` の「standalone-capable が現在の **11 + ta-26** 以外に増えているか」に対し pbi-input 実測は層0=4（ta-26/58/59/60）+ 層A=12 = **16**。
  **注（重要）**: 当初「plan が初版 pbi-input 基準で件数を誤っている」と報告されたが、`plan.md:25` は「pbi-input 作成時は53、本backlog監査時は57」と**両方を認識**しており件数の点では劣化していない。**逸脱は層 0 の 4 本が起点集合から落ちている点に限る**。
- **是正案**: plan の Context / 前提の実測検証 / Questions を pbi-input 現行版へ同期。「既存伝播済み = ta-26 のみ」を**層 0 の 4 本**へ是正し、`ta-59` / `ta-60` の `[ "$fail" -eq 0 ] || exit 1` 形と `ta-26` の `[ "$fail" != "0" ]` 形が helper へ吸収されることを Task 5 に明記。

### R-004 Mode 判定が定量基準と矛盾し判定根拠セクションが存在しない

- **severity**: major
- **該当**: `plan.md:6`（frontmatter `mode: high-risk`）/ `todo.md:4`
- **指摘**: **Mode 判定が定量基準と矛盾し判定根拠セクションが存在しない**。plan 内で Mode 判定に関わるヒットは frontmatter `mode: high-risk` のみ。実変更は `ta-*.sh` **57 本**（実測）+ `run-tests.sh` + helper + 新 TA + README + `TASK-0914/handoff.md` ≈ **62 ファイル**で [`mode-classification.md`](../../../.claude/rules/mode-classification.md) 定量「16+ → critical」に該当。pbi-input 自身も「一括 = critical」「判定不能な間は安全側 = critical」（`pbi-input.md:202`）と明記。**D-5（スライス分割）は plan・todo・test-cases に 0 ヒットで未裁定**。
- **是正案**: `## Mode判定`（判定根拠つき）を新設。D-5 を裁定して (i) Slice 1 = 層A 12 + helper + 検査基盤 + README ≈ 15 本で high-risk 維持 / (ii) 一括なら **critical へ引き上げ** のいずれかを明記。

### R-005 todo.md に `rollback:` が 1 件も無い

- **severity**: major
- **該当**: `todo.md` 全体
- **指摘**: **`grep -c 'rollback' todo.md` = 0**（実測）。[`working-context.md`](../../../.claude/rules/working-context.md)「各タスクに `rollback:` を記載。**必須 = high-risk / critical の実装タスク**」に違反。plan 側の `Rollback` ヒットも `plan.md:288`（Task 3 のみ）と `plan.md:407`（C-1 チェック `[x] broad migrationのrollback/replanを定義` = 自己申告と実体の乖離）。
- **是正案**: T-01〜T-08 各々に `rollback:` を付与。特に T-04 / T-05 は「batch 単位 commit を `git revert <sha>` / 未 push なら `git reset --hard`」+「helper 導入前まで戻す場合は T-03 の revert が前提」の依存順を明記。

### R-006 TC-14 のファイル名ハードコードによる時限爆弾

- **severity**: major
- **該当**: `test-cases.md:71`（TC-14）
- **指摘**: **ファイル名ハードコードによる時限爆弾**。TC-14 = `executes a known file after ta-39`。pbi-input AC-4（`pbi-input.md:181`）は「`ls tests/extras/ta-*.sh | tail -1` が出力する最終ファイルの `[PASS]` が harness ログに現れる（**ファイル名をハードコードしない** — F-8）」と手段まで指定済み。
- **是正案**: TC-14 を「runtime に `ls tests/extras/ta-*.sh | tail -1` で決定した最終ファイルの `[PASS]` 出現を assert」へ書き換え。plan Task 6 の「後続 test marker が出ること」も同文言へ揃える。

### R-007 D-2（層 C＝空振り PASS 5 本）の裁定が未明文化

- **severity**: minor
- **該当**: `plan.md` / `todo.md` / `test-cases.md` 全体
- **指摘**: **D-2（層 C＝空振り PASS 5 本）の裁定が明文化されていない**（`層` / `D-2` / `空振り` の grep ヒット 0）。`ta-11` / `ta-38` は fallback を持たないため 2 値分類で harness-only に落ちて exit 2 で結果的に解決するが、pbi-input R-3 が「層 C を解決したと誤認する」を明示リスクに挙げている。
- **是正案**: plan の Scope に「D-2 = (c) 採用：層 C は fallback 非保持クラスとして harness-only に含め fail-fast で空振り PASS を塞ぐ」を 1 行追加。

### R-008 完了済み PBI の handoff 書き換え方法が未規定

- **severity**: minor
- **該当**: `plan.md:240` / `test-cases.md:111`
- **指摘**: **完了済み PBI の handoff 書き換え方法が未規定**。writeback 自体は issue AC-6 の明示要求で妥当だが、`アンカー` / `append` / `追記` の grep が 0 件で、pbi-input F-7 の「行番号でなく**記号アンカー**で指す」（`pbi-input.md:149`）が計画へ伝播していない。handoff は完了資産であり上書き削除は履歴の破壊。
- **是正案**: Files 表を「**append-only**：§3 V2 候補表の該当行の status を『CLOSED（#921 / PR #NNN, YYYY-MM-DD）』へ更新し行自体は削除しない」へ具体化。参照は §見出し + 行テキストの記号アンカーで指定し行番号を書かない。

### R-009 AC-5 / AC-6 に機械検査が無い

- **severity**: minor
- **該当**: `test-cases.md:110-111`
- **指摘**: **AC-5（README 規約）/ AC-6（writeback）に機械検査が無い**。いずれも人手 review 依存で Exit Criteria（`test-cases.md:115-119`）にも項目が無く、文書側だけ落ちても TC は全 PASS する。
- **是正案**: 契約 TA に「README が rc 0/1/2/3 の意味と capability marker 規約を含む」grep 検査を TC-19 として追加。AC-6 は handoff の該当行に CLOSED マーカーが存在することの grep を DoD へ。

### R-010 `tests/run-tests.sh` への helper source は不要な可能性が高い

- **severity**: minor
- **該当**: `plan.md:159-170`, `plan.md:236`, `plan.md:394`
- **指摘**: **`tests/run-tests.sh` への helper source は不要な可能性が高い**。plan は各 extras に defensive bootstrap を持たせる設計なので runner 側 source が無くても全経路で helper が解決する。にもかかわらず runner 変更は Human Approval Boundary を 1 件増やし、issue Out of scope「`tests/run-tests.sh` の変更」との緊張も生む。
- **是正案**: runner 変更を落として bootstrap 単独にできないか Task 3 で比較検証。落とせるなら Files 表から除去。残すなら「なぜ bootstrap だけでは不足か」を根拠付きで記載。

### R-011 Mutation Matrix が AC-7 の「修正前実装で FAIL」を実証していない

- **severity**: info
- **該当**: `test-cases.md:91-100`（Mutation Matrix）/ `pbi-input.md:184`（AC-7）
- **指摘**: pbi-input AC-7 は「**修正前実装で FAIL する**ことを実証」だが Mutation Matrix M-01〜M-06 は**修正後 helper への変異**であり別物。
- **是正案**: Verification Plan に「pre-fix HEAD（helper 導入前）で contract TA を実行し FAIL することの evidence」を 1 行追加。

## C-1 からの委譲事項の裁定

> `review-self.md:38`（C1-M3）が C-2 に投げた force-fail probe の 3 択に対する設計妥当性レーンの裁定。
> **これは指摘（R-NNN）ではなく裁定**であるため、監査表には含めず本セクションに全文を記録する。

### ① internal-only → 採用（必須）。追加条件「harness mode では probe を完全無視」

根拠: `tests/run-tests.sh` が unset するのは 7 env で `PG_EXTRA_CONTRACT_PROBE` / `PG_EXTRA_CONTRACT_TARGET` を含まない。汚染 shell から `sh tests/run-tests.sh` を叩くと suite 全体が理由不明に赤くなる。

ただし runner の unset 列に足す案は採らない（plan Task 3 が「runner の helper source 以外の diff が 0」を自ら制約しているため）。**helper 側で「harness mode なら probe 変数を読まない」と実装すれば runner 変更ゼロで同じ保証が得られる**。これは `plan.md:78` の未解決 Unknown への回答でもある（＝ unset 不要、helper 側で解決）。

### ② target 必須 → 採用（必須）。加えて「TARGET 未設定は no-op ではなく fail-closed」

no-op にすると契約 TA が TARGET を渡し損ねたとき「全ファイル rc=0 → probe が効いていないのに TC-12 が PASS」という**検査器自身の空振り**が起きる（本 PBI が潰そうとしている症状と同型）。

TC-12 の assert を **(a) probe なし → rc=0 / (b) probe あり × target 一致 → rc=1 の両方**を取り差分を要求する形へ強化する（(b) 単独では「元から常に rc=1」なファイルを検出できない）。

### ③ README 非公開 → 不採用。test section 限定を採用

理由:

1. probe は構造上 fail を**増やす方向にしか作用せず**成功偽装の経路がないため、秘匿に安全上の利得がない
2. 隠れた load-bearing な seam は腐る。本 repo は未文書の暗黙契約を Shadow Config として排除する設計思想を持つ
3. 本 PBI の AC-6 が README 規約 9 の追記を要求しており、rc 意味レイヤーと同じ場所に置くのが整合的

**README 必須記載事項**:

- test-only であること
- 失敗を増やすことしかできず抑止しないこと
- CI 設定・開発シェル・`.env` に設定してはならないこと
- harness mode では無視されること
- probe 由来の失敗は通常の `[FAIL]` と区別可能なメッセージで出力されること

## コードベース整合レーン（R-012〜R-020）

> 読む: 既存パターン該当箇所。読まない: plan の網羅性判定。
> 主眼: 「踏襲すべき既存パターン」との不整合検出。

### R-012（元 F-1）案 C の standalone finalizer trap を ta-45 が無条件に消す

- **severity**: major
- **該当**: `tests/extras/ta-45-c3-mode-config.sh:76`（`trap cleanup_t45 EXIT`）/ `tests/extras/ta-45-c3-mode-config.sh:224`（`trap - EXIT`）
- **指摘**: **案 C の standalone finalizer trap を ta-45 が無条件に消す**。合成実証: 制御群 rc=1 / ta-45 パターン rc=0（finalizer 未発火・`fail=1` が握り潰される）。plan の Replan Trigger #1・Questions は「top-level **`trap 0`**」と書いているが本 repo は全件 `trap ... EXIT` 表記（ta-07 / ta-09 / ta-24 / ta-28 / ta-45）で **`grep 'trap 0'` は 0 件**。exec 時にこの trigger が空振りし「競合なし」と誤結論する。
- **是正案**: (a) trigger の検出式を `^[[:space:]]*trap`（末尾スペースを含む）へ是正 (b) ta-45 の `trap -` / `trap` を helper API 経由に置換するか ta-45 を案 D（末尾 explicit finalize）扱いにする。`tests/extras/README.md` 規約 2 と整合させる。

### R-013（元 F-2）ta-26 TC-33 が helper 集約で FAIL か空振りのどちらかになる

- **severity**: major
- **該当**: `tests/extras/ta-26-plugin-sync.sh:743-791`（TC-33）
- **指摘**: TC-33 は「`FIXTURES_DIR:-` を含む各 `ta-*.sh`」に対し (1) `PG_HARNESS_SOURCED` の存在 (2) **そのファイル自身の inline `unset` 行**が run-tests.sh の 7 env 集合を包含、を静的検査する。plan Task 5 で 7 env unset を helper へ移すと **inline unset 残存 → TC-33 FAIL（フルスイート赤）/ `FIXTURES_DIR:-` ごと除去 → ループが `continue` して TC-33 が全件空振り（#914 AC-9 のゲートが無言で消失）** のどちらかになる。
- **是正案**: plan に「TC-33 の扱い」を明記。helper 集約するなら TC-33 の検査対象を helper 側へ差し替える AC を追加（空振り化を許容しない）。

### R-014（元 F-3）#914 が承認付きで棄却した共有 preamble 案の反転を認識していない

- **severity**: major
- **該当**: `docs/working/TASK-0914/handoff.md:98`（§4 妥協点）
- **指摘**: #914 は「共有 preamble ファイル `_standalone-preamble.sh`（E-1）」を**明示的に棄却**し理由を「共有ファイルは `ta-*.sh` glob 外の新規ファイルで extras 自己完結の慣習を崩す」と記録している（**Human C-3 承認済みの設計選択**）。TASK-0921 plan は同一ディレクトリの `tests/extras/_extra-contract.sh` を提案するが、**この先行決定の反転を認識も正当化もしていない**。Human Approval Boundary にも項目がない。
- **是正案**: plan の Approach Comparison / Human Approval Boundary に「#914 §4 で棄却された E-1 の反転」を明記し反転根拠を書く。

### R-015（元 F-4）ta-26 TC-13 が summary 書式に束縛 + probe env の再帰汚染

- **severity**: major
- **該当**: `tests/extras/ta-26-plugin-sync.sh:294-316`
- **指摘**:
  - (a) TC-13 は子プロセス出力を**リテラル `TA-26 standalone: .* 0 failed`** で grep する（rc ではなく summary 行で判定と明記）。plan Task 5 の footer helper 統合で summary 書式が変わると TC-13 が壊れる。TC-18 は「summary equivalent」としか書かず**書式が ta-26 の TC-13 に機械的に束縛されている事実**が未記載。
  - (b) TC-13 は `PG_T26_NO_RECURSE=1` で自己再帰する。`PG_EXTRA_CONTRACT_PROBE` / `PG_EXTRA_CONTRACT_TARGET` は env として子へ継承されるため TARGET=ta-26 の force-fail probe が子でも発火し親の判定を汚す（rc は 1 のまま = TC-12 が誤った理由で PASS する masking）。
- **是正案**: (a) helper summary は `TA-<NN> standalone: N passed, M failed` 書式を維持する制約を Global Constraints へ (b) probe env に再帰ガード（finalize で probe env を unset / 子へ伝播させない）を設計へ追加。

### R-016（元 F-5）ta 番号が重複し test-id が一意でない

- **severity**: major
- **該当**: `tests/extras/ta-14-codex-guarded.sh` / `tests/extras/ta-14-skip-acknowledge.sh`
- **指摘**: **ta 番号が重複**（実測: `uniq -d` が `ta-14` の 1 件）。plan の `<test-id>` / `PG_EXTRA_CONTRACT_TARGET=<test-id>` / 診断メッセージ `[ERROR] <id> is harness-only` が**一意でない**。TC-10 / TC-11 / TC-12 の「for every file」も ID キーでは 2 ファイルを弁別できない。
- **是正案**: test-id を番号ではなく **basename（拡張子なし）** で定義。plan の Contract Design と TC-10 / TC-11 / TC-12 を basename ベースへ是正。

### R-017（元 F-6）CI 実行時間がスイート 2 倍超になる見込み

- **severity**: minor
- **該当**: 実測（sandbox clone @ `516e2f7`）
- **指摘**: フルスイート baseline = **231s / 541 passed, 0 failed**。ta-26 の standalone 単体が **76s**。TC-12 + TC-13 は standalone-capable 15 本を **2 周**するため ta-26 だけで +152s、全体で概算 **+250〜280s（スイート時間 2 倍超）**。exit criteria の「three consecutive full suite runs」と乗算される。
- **是正案**: contract TA の全件ループを既定でフルスイートに載せるか、重量ファイル（ta-26）を opt-in env でスキップするかを plan で決める。CI 時間の見積を Verification Plan に記載。

### R-018（元 F-7）案 C の第一根拠（ta-39 の早期 exit）が現存事例として成立しない

- **severity**: minor
- **該当**: `tests/extras/ta-39-eh3-doc-light.sh:53-61`
- **指摘**: 案 C（trap）の第一根拠は「ta-39 のような早期 `exit 0`」だが、実コードでは `tests/extras/ta-39-eh3-doc-light.sh:54` に **「カウンタは更新しない」** と明記され早期 exit 時点で `fail` は構造上必ず 0。**現存する唯一の早期 exit 事例では failure を落としえない**。全 57 本で列 0-2 の top-level `exit`（末尾スペース付きの grep）は **0 件**。
- **是正案**: 案 C の根拠を「現存事例の是正」ではなく「**将来ファイルへの一般保証**」として書き直す。R-012 が解けない場合、案 D への replan コストは plan が想定するより低い。

### R-019（元 F-8）helper source の `set -eu` 耐性と `register_cleanup` 再定義禁止が未制約

- **severity**: info
- **該当**: `tests/run-tests.sh:11`（`set -eu`）/ `tests/run-tests.sh:35`（`register_cleanup()`）
- **指摘**: helper を extras loop 前に source する際、(a) `set -eu` 下での source-safe 性 (b) helper が `register_cleanup` を**無条件再定義しない**（harness の単一 drain 契約 `tests/run-tests.sh:174` を壊す）の 2 制約が Global Constraints に無い。
- **是正案**: 両制約を Global Constraints へ明記。「helper source 直後に `register_cleanup` が上書きされていない」を TC 追加。

### R-020（元 F-9）extras rc=2 と hook の `exit 2` は意味論が重複する

- **severity**: info
- **該当**: `scripts/hooks/check-plan-hash.sh:95,100,139,286,305` ほか
- **指摘**: 本 repo で `exit 2` は一貫して「hook BLOCK / HARDENING_OVERRIDE」を意味する。extras の rc を機械消費する箇所は `.github/workflows/test.yml:28` と ta-26 の自己再帰だけなので**機械的衝突はなし**だが意味論は重複。
- **是正案**: README 規約に「extras rc の 2 は harness-only 誤実行専用であり hook の BLOCK とは別名前空間」と明記。

## コードベース整合レーンからの AC 候補 / 既存パターン制約

> [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md) §7-bis の V-3 MJ-3 経路。
> コードベース整合レーンが「既存コード構造を見ないと分からない不足」を設計妥当性レーンへ返した項目。
> **指摘（R-NNN）ではなく返送項目**であるため監査表には含めない。

1. **AC 候補（R-012〜R-020 のうち F-2 由来 / 必須）**: 「`ta-26` TC-33 が移行後も**空振りせず**同等以上の検出力を保つこと」を AC に立てる。現 plan の AC / TC には TC-33 の存続条件が 1 つも無く、helper 集約で #914 AC-9 のゲートが無言で失われうる。変異注入で FAIL することの実証まで含めるのが望ましい。
2. **AC 候補（F-4a 由来）**: 「`ta-26` の standalone summary 行の書式が維持されること」。TC-18「ta-26 parity」を「summary が `TA-26 standalone: N passed, M failed` を維持し TC-13 の grep が通ること」へ具体化。
3. **既存パターン制約（F-3 由来）**: `tests/extras/` の慣習は「extras 自己完結（共有 source ファイルを置かない）」であり **#914 の Human 承認付き決定として文書化**されている。`_extra-contract.sh` はこの慣習の**意図的な例外**であることを plan で宣言し Human Approval Boundary に載せる必要がある。
4. **既存パターン制約（F-1 由来）**: `tests/extras/README.md` 規約 2 が「trap に頼らない・親シェルの trap を `trap - EXIT` で消さない」を正本として定めている。案 C は規約の例外導入。**規約 2 に「standalone finalizer trap を消してはならない」という新しい禁止条項を追加する**ことを AC 化しないと、将来ファイルが ta-45 と同じ壊し方を再現する。
5. **AC 候補（F-5 由来）**: test-id の一意性。「全 `ta-*.sh` の test-id が一意であること」を contract TA の検査項目に追加（現状 ta-14 が 2 本あり既に違反）。
6. **スコープ観察（F-6 由来）**: CI 実行時間が 2 倍超になる見込み。Out of Scope / Non-goals に「CI 実行時間の予算」への言及が無い。

## 実測サマリ

> コードベース整合レーンが `origin/main` = `516e2f7` の sandbox clone で採取した一次実測。

- **inventory**: `ta-*.sh` = **57 本**。`ta-*.sh` 以外は `README.md` のみ → `_extra-contract.sh` は glob に一致せず runner の test inventory に混入しない。欠番 ta-01 / ta-02 / ta-03 / ta-48、**重複 ta-14 が 2 本**。
- **shebang**: **0/57**。行 2 は全件 `# Sourced by tests/run-tests.sh …` 系で統一 → capability marker を行 3 付近に置くのは構造的に無問題。既存 marker 類似物（`PG_EXTRA` / `CAPABILITY`）は **0 件**（名前空間衝突なし）。
- **`run-tests.sh`**: `:11` `set -eu` / `:20` 7 env unset / `:26-27` counter 初期化 / `:34-49` `register_cleanup` + `_pg_drain_cleanup` / `:163` `PG_HARNESS_SOURCED=1`（非 export）/ `:165-170` extras loop / `:174` 単一 drain / `:179-181` `fail > 0 → exit 1` → **plan の「集計ロジックは不変」は構造的に成立する**（R-019 の 2 制約を守れば）。
- **共有 helper**: `tests/` 配下に `_extra-contract.sh` 相当の既存共有 helper は**存在しない**（重複定義にはならない）。
- **standalone 実測**: 走査範囲（ta-04〜ta-25）で**全件 rc=0**、`[FAIL]` 行は最大 21 本（ta-09）→ **#921 の問題が全域で再現**。standalone-capable 候補 15 本は全件 rc=0 / `[FAIL]` 0 → TC-13 は実現可能。`pass=0` を自前定義しているのは **4 本のみ**（ta-26 / ta-58 / ta-59 / ta-60）、残り 11 本は未初期化のまま POSIX 算術の未定義=0 に暗黙依存。
- **trap**: top-level `trap ... EXIT` = **5 本**（ta-07 / ta-09 / ta-24 / ta-28 / ta-45）。うち standalone-capable 候補は **ta-45 のみ**。
- **top-level `exit N`（列 0-2）**: **0 件**。
- **フルスイート baseline**: **rc=0 / 231s / 541 passed, 0 failed**。
- **exit code 規約**: `.github/workflows/test.yml:28` の `sh tests/run-tests.sh` が唯一の CI 消費点で rc 0 / 非 0 のみ解釈。**個別 `ta-*.sh` の rc を消費する CI・スクリプトは存在しない** → rc=2 割当に機械的衝突なし。

## 照合済み（指摘なし）

> 監査連続性のため、両レーンが「照合したが問題なし」と判断した項目を省略せず記録する。

- **Hardening Override 非該当**（実測）: `scripts/hooks/check-plan-hash.sh` の `case` 文 9 カテゴリに対し plan Files 表 6 エントリは 1 つも該当しない。`tests/run-tests.sh` は `scripts/hooks/*.sh` にも `bin/plangate` にも一致せず HO 非該当。ただし CI が唯一呼ぶ経路のため plan が R-1 を critical 扱いし TC-01 / TC-14 / TC-15 + M-02 で四重に固定している点は妥当。
- **件数の非ハードコード**: plan `:25` / `:55` / Task 1 完了条件 `:260` / TC-09 / Exit Criteria `:119` / M-06 を確認。設計として守られている。`tests/` 配下・CI・`bin/plangate` に extras 件数のハードコードは検出されず、ta-26 TC-33 も件数非依存の grep ベース。
- **C-1 `PASS conditionally` 2 件の担保**:
  1. `review-self.md:18`「standalone-only signal0 trap。競合監査必須」→ plan `:76` / `:95` / Task 1 `:254` / Replan Triggers `:374` / todo H-03 / 依存グラフが一貫し**担保あり**（ただし検出式の誤りは R-012）。
  2. `review-self.md:19`「harness では trap / counter reset / exit 禁止」→ plan `:147` / Global Constraints `:53` / TC-01 / TC-14 / M-02 で正負両側から固定され**担保あり**。
- **停止条件**: `plan.md:382-389` の 6 項目、`todo.md:127-132` の 6 項目に矛盾なし。high-risk 帯として十分（不足は rollback 側のみ = R-005）。
- **Out of scope の整合**: issue Non-goals / Out of scope の 5 項目すべてを `plan.md:42-48` が継承。
- **#914 との順序依存**: `TASK-0914/handoff.md` §3 V2 候補表に「#921 完了時に AC-6 の判定を exit code ベースへ戻す」行が実在（優先度 High / 関連 Issue #921）→ writeback 対象は実在する正しいターゲット。
- **stdin ハング対策**: plan `:56` / TC-11 / TC-13 の `</dev/null` / todo `:129` / plan `:387` で全経路カバー。
- **cleanup 安全性**: plan `:58` / TC-07 / todo `:130` を確認。pbi-input F-10 も helper 化で構造的に回避。
- **capability marker の実現可能性 / `_extra-contract.sh` の重複性 / glob 混入 / shellcheck CI 不在 / pollution guard 3 本（ta-16 / ta-29 / ta-32）の誤検知なし**（コードベース整合レーン実測）。
- **writeback 対象の追加候補（軽微）**: `TASK-0914/handoff.md` §3 の 2 行目「standalone preamble の共通化（7 env unset のインライン 12 ファイル重複の解消）」も本 PBI で実質解消されるため writeback 対象に含めるのが妥当。

## 監査表（追記専用 / squash・rebase 耐性）

> `status`: `open`（未反映）/ `reflected`（計画本体へ反映済み）/ `rejected`（不採用・理由を notes へ）
> `reflected_in(commit)`: 反映コミットの SHA。反映コミットのメッセージに `Refs: R-NNN` を付ける。

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|----------------------|-------|
| R-001 | reflected | `e908420` | 設計 / major / AC↔TC 写像の二重正本 → plan `### Success Criteria` を削除し test-cases `## Traceability` を単一正本化 |
| R-002 | reflected | `e908420` | 設計 / major / exit 3 意味レイヤー不在（最優先の実害経路）→ plan `### rc 意味レイヤー` 新設 / RC Table に rc=3 追加 / TC-17 を rc=3 へ反転（ta-43・ta-44 を対象化） |
| R-003 | reflected | `e908420` | 設計 / major / 層 0 の 4 本が起点集合から欠落 → plan Context・前提の実測検証・Task 5 / todo T-01・T-05 へ 4 本と 2 系統 footer を明記。件数（53/57）は劣化なしのため不変 |
| R-004 | reflected | `e908420` | 設計 / major / Mode 判定根拠不在・D-5 未裁定 → plan `## Mode判定` 新設（定量 3 軸 + 定性 4 軸 + critical 非引き上げ根拠）。D-5 = スライス分割で確定 |
| R-005 | reflected | `e908420` | 設計 / major / todo に `rollback:` 0 件 → T-01〜T-08 全件に付与。T-04/T-05 → T-03 の revert 依存順を明記。plan C-1 チェックの自己申告乖離も解消 |
| R-006 | reflected | `e908420` | 設計 / major / TC-14 ファイル名ハードコード → TC-14 を runtime `ls tests/extras/ta-*.sh \| tail -1` 解決へ書換。plan Task 6 / todo T-06 も同文言 |
| R-007 | reflected | `e908420` | 設計 / minor / D-2（層 C）裁定 → plan In Scope に「D-2 = (c) 採用」を明記。todo T-04 の対象を 41 本に |
| R-008 | reflected | `e908420` | 設計 / minor / handoff writeback → plan に append-only 規約節を新設（記号アンカー・行番号非記載・対象 2 行） |
| R-009 | reflected | `e908420` | 設計 / minor / AC-5 / AC-6 の機械検査 → TC-19（README grep）追加。AC-6 の handoff CLOSED マーカー grep を Exit Criteria へ |
| R-010 | reflected | `e908420` | 設計 / minor / runner helper source の要否 → plan Task 3 / todo T-03 に bootstrap 単独代替の比較検証項目。Files 表を「要否は Task 3 で確定」に |
| R-011 | reflected | `e908420` | 設計 / info / AC-7 → Verification Plan に pre-fix HEAD 実行行を追加。Mutation Matrix 冒頭に「別物」注記 |
| R-012 | resolved-by-design | `e908420` | 整合 / major / 元 F-1 / 案 D（末尾 explicit finalize）採用により trap を張らないため競合が消滅。検出式の教訓は Replan Triggers 節に保持 |
| R-013 | reflected | `e908420` | 整合 / major / 元 F-2 → plan に「`ta-26` TC-33 の扱い」節を新設し検査対象を helper 側へ差し替え。AC-8 新設 + TC-22 + M-09 で空振り化を禁止 |
| R-014 | reflected | `e908420` | 整合 / major / 元 F-3 → plan に「先行決定の反転」節を新設（#914 §4 引用 + 反転根拠 + glob 非混入の実測対置）。Human Approval Boundary に項目追加 |
| R-015 | reflected | `e908420` | 整合 / major / 元 F-4 → (a) summary 書式維持を Global Constraints + TC-18 + M-11 へ / (b) probe 再帰ガードを Contract Design + TC-23 + M-12 へ |
| R-016 | reflected | `e908420` | 整合 / major / 元 F-5 → test-id を basename 定義へ。TC-10/11/12 を basename ベース化。TC-20（一意性検査）を contract TA へ追加 |
| R-017 | reflected | `e908420` | 整合 / minor / 元 F-6 → Verification Plan に CI 時間見積 + 裁定節（既定でフルスイート・opt-in スキップ不採用・3 連続の読み替え）。Out of Scope に CI 時間予算を追記 |
| R-018 | resolved-by-design | `e908420` | 整合 / minor / 元 F-7 / 案 C 不採用により「案 C の根拠」記述が消滅。実測（top-level `exit N` = 0 件 / ta-39 の fail 構造 0）は plan `## 前提の実測検証` に replan 根拠として保持 |
| R-019 | reflected | `e908420` | 整合 / info / 元 F-8 → Global Constraints に 2 制約（`set -eu` source-safe / `register_cleanup` 非再定義）。TC-21 追加 |
| R-020 | reflected | `e908420` | 整合 / info / 元 F-9 → README 規約項目として plan Task 7 / todo T-07 に明記。TC-19 の grep 対象にも含めた |

> **status 値の追加**（本反映時点）: 上記凡例の `open` / `reflected` / `rejected` に加え、
> **`resolved-by-design`**（設計変更により指摘の前提そのものが消滅した）を用いる。
> `wont-fix`（反映しないと判断）は **0 件**。

## 次ステップ（本ファイル外）

> [`working-context.md`](../../../.claude/rules/working-context.md) `### review-external.md` の確定順序に従う。本ファイルは (1) のみを完了させた状態である。

1. **完了**: review-external に `R-001`〜`R-020` を集約（本ファイル）
2. 計画本体（`plan.md` / `todo.md` / `test-cases.md`）へ **1 回だけ確定反映**（反映コミットに `Refs: R-NNN`）
3. 簡易 C-1 再実行
4. 人間が最終 `approvals/c3.json`（`c3_status=APPROVED`・確定後 plan の `plan_hash`）を発行
5. exec

> 反映時は本監査表の `status` / `reflected_in(commit)` を追記更新する（既存行の削除・書き換えはしない）。

---

# 追補: 別レーン群（4 レーン独立レビュー）由来の固有指摘（R-021〜R-037）

> **追記日**: 2026-08-10 / **追記者**: worker（オーガナイザー委託）
> **本節は追記専用の追補である。上の R-001〜R-020 の記述は 1 文字も変更していない。**
>
> **出典**: 本 PBI の C-2 は **2 系統が独立に実施**された。
>
> | 系統 | レーン構成 | 基点 | 指摘 ID 体系 | 本ファイルでの扱い |
> |---|---|---|---|---|
> | 系統 A（既出・上記） | 2 レーン（設計妥当性 / コードベース整合） | `origin/main` = `516e2f7` | `R-001`〜`R-020` | **正本**（PR #1020 で main へ反映済み） |
> | 系統 B（本追補） | 4 レーン（Lane 1 POSIX shell / Lane 2 test architecture / Lane 3 workflow boundary / Lane 4 maintainability） | `origin/main` = `4448420` | `R-001`〜`R-005` / `R-101`〜`R-113` / `R-201`〜`R-217` / `R-401`〜`R-413`（計 32 件） | **R 番号が系統 A と衝突するため再採番**。本追補で `R-021` 以降へ採番し直す |
>
> **系統 B の元 ID は各項目の `出典` と監査表の `notes` に併記**して追跡可能にしてある。
> 系統 A が既に取り込んでいる指摘（`register_cleanup` の無条件再定義禁止 / test-id の basename 化 /
> `ta-43`・`ta-44` の fail 握り潰し 等）は**重複追記しない**。除外判断は「重複除外表」に全件記録した。

## 追補サマリー

| severity | 件数 | R-NNN |
|----------|-----:|-------|
| critical | 1 | R-021 |
| major | 9 | R-022〜R-030 |
| minor | 5 | R-031〜R-035 |
| info | 2 | R-036, R-037 |
| **合計** | **17** | R-021〜R-037 |

> **判定への影響（重要）**: 上記 R-001〜R-020 のサマリーは `critical = 0` としていたが、
> **本追補の R-021 は critical**（Human 決定 1 で採用した案 D が **CI 実行環境では成立しない**）。
> [`review-principles.md`](../../../.claude/rules/review-principles.md) §4 に従い、
> 本 PBI 全体の C-2 判定は **Human review required（critical ≥ 1）** へ引き上げられる。

## R-021 `|| true` 型の早期脱出 4 件により案 D の末尾 finalize が CI（dash）で到達しない

- **severity**: **critical**
- **出典**: 系統 B Lane 1 `R-101` / `R-107` / `R-108`、Lane 4 `R-405`（Lane 2 `R-202` は対象範囲を誤っていたため不採用）
- **該当**:
  - `tests/extras/ta-45-c3-mode-config.sh:52`
  - `tests/extras/ta-46-ehs-wiring.sh:23`
  - `tests/extras/ta-47-ehs23-wiring.sh:23`
  - `tests/extras/ta-49-bias-export.sh:72`
  - （参考・分岐内のみ）`tests/extras/ta-31-codex-plugin-status.sh:43,56,72,73` — `mktemp` 失敗時にだけ通る経路。`ta-31` は harness-only 想定のため Slice 1 の対象外
  - 対置: `plan.md` `## 前提の実測検証`「早期 `exit 0` を持つ `ta-*.sh` の現存件数 = **3 件**」
- **指摘**: 現行 plan は早期脱出を `return 0 2>/dev/null || exit 0` 型の **3 件**（`ta-39` / `ta-43` / `ta-44`）
  としか列挙していないが、**`return 0 2>/dev/null || true` 型が別に 4 件存在する**。
  この 2 型は**シェル実装で挙動が分かれる**。

  | 型 | 該当 | `/bin/dash`（= CI の `sh`） | `/bin/sh`（macOS = bash 3.2.57） | `/bin/zsh` |
  |---|---|---|---|---|
  | `\|\| exit 0` | `ta-39` / `ta-43` / `ta-44` | 終了 | 終了 | 終了 |
  | `\|\| true` | `ta-45` / `ta-46` / `ta-47` / `ta-49` | **終了** | **継続（本体が走る）** | 終了 |

  `.github/workflows/test.yml:19`（`runs-on: ubuntu-latest`）+ `:28`（`run: sh tests/run-tests.sh`）より
  **CI の `/bin/sh` は dash**。したがって二重の破綻が起きる。

  1. **CI（dash）**: skip 経路で top-level `return 0` が成功しスクリプトが終了するため、
     案 D の**末尾 explicit finalize に到達しない**。contract TA の force-fail probe（rc=1 を要求）が
     当該 4 件で rc=0 を返し **恒常 RED**。plan の Verification Plan
     「Standalone forced fail → all rc1」「Standalone normal → rc0」が**両方とも成立しない**。
  2. **開発機（bash）**: `return` が失敗して skip guard を素通りし、**前提未充足のまま本体が走る**
     （spurious FAIL）。すなわち **ローカル GREEN が CI の正しさを保証しない**。

  4 件はいずれも **層 A（Slice 1 の移行対象 12 本）に含まれる**
  （`pbi-input.md` の層 A 一覧 = `ta-39`/`ta-43`/`ta-44`/`ta-45`/`ta-46`/`ta-47`/`ta-49`/`ta-50`/`ta-51`/`ta-52`/`ta-53` + `ta-40`）。
  よって **Slice 1 の直接スコープ内の未反映 blocker** であり、Slice 2 へ繰り延べられない。
- **一次実測（本追補の作成時に worktree 内で再現）**:

  ```console
  # A) 素の 2 型（printf 'A ' → 脱出行 → printf 'B: still running'）
  /bin/sh   or-true : A B: still running   (rc=0)   ← 継続
  /bin/dash or-true : A                    (rc=0)   ← 終了
  /bin/zsh  or-true : A                    (rc=0)   ← 終了
  /bin/sh   or-exit : A                    (rc=0)   ← 終了
  /bin/dash or-exit : A                    (rc=0)   ← 終了
  /bin/zsh  or-exit : A                    (rc=0)   ← 終了

  # B) ta-45/46/47/49 の skip guard 形 + 案 D の末尾 explicit finalize（fail=1 を立てた最悪ケース）
  /bin/dash : "[SKIP] prerequisite absent"                                  rc=0
              ← FINALIZE REACHED が出ない ＝ 末尾 finalize 到達不能
  /bin/sh   : "[SKIP] prerequisite absent" / "BODY RAN" / "FINALIZE REACHED" rc=1
              ← skip guard を素通りして本体が走る
  ```

- **是正案**:
  1. `plan.md` `## 前提の実測検証` の「早期 `exit 0` … **3 件**」行を、
     **「早期脱出は 2 型 7 件（`|| exit 0` 型 3 件 + `|| true` 型 4 件）」**へ是正する。
     grep 式は `exit 0` ではなく **`return 0 2>/dev/null`** を起点にする（`|| true` を取りこぼさないため）。
  2. Global Constraints に
     **「standalone 経路の脱出手段として `return 0 2>/dev/null || …` を型を問わず禁止する。
     skip 経路も必ず `pg_extra_contract_skip` を経由させる」**を追加する。
  3. Task 5 の置換対象を 3 本 → **7 本**（`ta-39` / `ta-43` / `ta-44` / `ta-45` / `ta-46` / `ta-47` / `ta-49`）へ拡大する。
  4. TC-17（前提未充足 → rc=3）の対象へ `ta-45` / `ta-46` / `ta-47` / `ta-49` を追加し、
     **dash と bash の双方**で実走する。変異 = skip guard を旧イディオムへ戻す →
     **dash 実行で probe が rc=0**、**bash 実行で本体が走る**の両方が FAIL として現れること。
- **関連**: R-022（`sh` 実体の固定）と対で解かないと、片方のシェルでしか検証されない状態が残る。

## R-022 CI とローカルで `sh` の実体が固定されておらず、検証系が環境依存になっている

- **severity**: major
- **出典**: 系統 B Lane 1 `R-101` / decision `D-0921-10`
- **該当**: `.github/workflows/test.yml:19`（`runs-on: ubuntu-latest`）/ `:28`（`run: sh tests/run-tests.sh`）
- **指摘**: CI は `sh` としか書いておらず **shell 実体を固定していない**。
  ubuntu-latest では dash、macOS 開発機では bash 3.2.57 になり、R-021 のとおり
  `return` のセマンティクスが分岐する。「どちらか一方でしか検証していない」状態が構造的に発生し、
  本 PBI が導入する契約（rc 0/1/2/3）そのものが環境で意味を変える。
- **是正案**: contract TA と CI で `sh` 実体を固定する。案は 2 つ。
  (a) CI を dash 明示（`run: dash tests/run-tests.sh` 相当）にする / (b) **dash + bash の matrix 実行**にする。
  Lane 1 の推奨は (b)（(a) 単独では macOS 開発機での素通りを検出できないままになる）。
- **責務分界（重要）**: `.github/workflows/**` は
  [`mode-classification.md`](../../../.claude/rules/mode-classification.md) の **Hardening Override 対象パス**である。
  **AI は適用せず patch 提示に留める**。採否と適用は Human-owned。
  なお本追補は plan の Files 表を変更しない（確定反映は別ステップ）。
- **未確定事項**: matrix 化した場合の CI 時間増（R-026 と乗算される）は未見積り。

## R-023 偽 PASS 3 件（`ta-11` / `ta-32` / `ta-38`）を contract TA が「健全」と太鼓判を押す

- **severity**: major
- **出典**: 系統 B Lane 2 `R-213`（系統 B Phase 1 inventory の新規検出）
- **該当**: `tests/extras/ta-11-*.sh` / `tests/extras/ta-32-*.sh` / `tests/extras/ta-38-*.sh`
  （系統 B 実測: standalone 実行で `[PASS]` 0 件かつ `[FAIL]` 0 件かつ rc=0。証跡 `evidence/baseline/standalone-current.log`）
- **指摘**: この 3 件は **1 件もアサーションを実行していないのに rc=0** を返す。
  本 PBI の contract TA は「rc が契約どおりか」を見るため、**この 3 件を合格させる**。
  すなわち #921 の主題（失敗を隠さない）に対し、**「何も検査していない」という別クラスの隠蔽が
  検査済みの体裁で通過する**。現行 plan にはこの 3 件への言及が一切ない（grep 0 件）。
  根本原因は exit code 伝播ではなく **ROOT 解決**（`//` や `tests/` へ解決してしまい fixture が見つからない）
  であり、これは #914 の後継領域。
- **是正案（2 段構え）**:
  1. **#921 スコープ内（推奨）**: helper の init に **ROOT sentinel 検査**を持たせ、
     `[ -x "$ROOT/bin/plangate" ] && [ -d "$ROOT/schemas" ]` を満たさなければ **fail-closed**。
     件数も allowlist も持たないため「件数を契約値にしない」制約に抵触せず、
     `//` へも `tests/` へも解決した場合の両方が落ちる。
  2. **別 issue**: 3 件自体の修理。`plan.md` Out of Scope「各 extras のテスト内容・期待値の見直し」に
     正面から抵触するため本 PBI では扱わない。
  加えて **harness モードでの偽 PASS は #921 では一切解消しない**ことを handoff に明記する。
- **Human 判断項目**: 上記 1 を #921 スコープに含めるか、2 と併せて別 issue にするか。

## R-024 finalize が harness 経路で非 0 を返すと `set -e` でスイート全体が即死する

- **severity**: major
- **出典**: 系統 B Lane 1 `R-103`
- **該当**: `tests/run-tests.sh:11`（`set -eu`）/ `plan.md` Global Constraints
  「sourceされた extras から `exit` して harness 全体を終了させない」
- **指摘**: 現行 Global Constraints は **`exit` しか禁じていない**。
  `set -e` 下では **source 経路で非 0 を `return` するだけでも**後続の extras が丸ごとスキップされ、
  `_pg_drain_cleanup`（`tests/run-tests.sh:174`）も `Results:` 行も出ない。
  runner は最終的に exit 1 するため、**「テストが赤い」ようにしか見えず途中打ち切りに気づけない**
  （系統 B は合成 harness で sh / dash 同一の挙動を実測）。実装ミス形
  （finalize 末尾が `[ "$fail" -gt 0 ]` のような test で終わる）でも同じ事故になる。
  helper の source 時 source-safe 性は R-019a が既に制約しているが、**finalize 呼出時**は未制約。
- **是正案**: Global Constraints を
  **「source 経路で `exit` も非 0 `return` もしない」**へ拡張し、
  `pg_extra_contract_finalize` は **harness mode では末尾で常に明示 `return 0`**、
  standalone mode でのみ `exit` する、と Helper interface へ明記する。
  TC として「fail>0 の standalone-capable 相当を含む合成 harness を source し、
  **後続ファイルのマーカー行と `Results:` 行が両方出る**」を追加する。

## R-025 bootstrap の `.` 失敗と runner source 行の単独 revert が、いずれもスイート即死を招く

- **severity**: major
- **出典**: 系統 B Lane 1 `R-105` / Lane 4 `R-404`
- **該当**: `tests/run-tests.sh:11`（`set -eu`）/ `plan.md` Task 3（runner への helper source）/ 各 extras の defensive bootstrap
- **指摘**: harness 経路では `$0` = `tests/run-tests.sh` であるため、
  bootstrap が `dirname "$0"` を起点に helper を解決すると **`tests/_extra-contract.sh`（不在）** を指す。
  `set -e` 下で `.` が失敗すると **1 ファイルの失敗ではなく suite 全滅**になり、
  しかも原因が bootstrap にあることが表示から読み取れない。同じ理由で
  **runner の helper source 行だけを revert すると全 suite が即死**する。
  現行 plan の rollback（R-005 で T-01〜T-08 に付与済み）は **タスク単位**であり、
  この **runner ↔ extras 間の適用順序・revert 順序の原子性**を規定していない。
- **是正案**:
  1. bootstrap のアンカーを `$0` ではなく **`${EXTRAS_DIR:-<script dir>}`** にする
     （harness 経路では runner が `EXTRAS_DIR` を持つため正しく解決する）。
  2. plan の Rollback へ **「適用は runner 先行、revert は適用の逆順のみ」**という順序制約を明記する。
  3. 「runner の helper source」と「各 extras の bootstrap 追加」が**同一 commit / 同一 PR で原子的に入る**
     ことを DoD 化する（分離すると中間状態で full suite が全滅する）。
- **補足**: R-010（runner 変更の要否を Task 3 で比較検証）と連動する。
  runner 変更を落とせるなら本指摘の (2)(3) は不要になる。

## R-026 contract TA の per-file timeout が未定義で、`ta-26` は偽 FAIL しうる

- **severity**: major
- **出典**: 系統 B Lane 2 `R-208` / Lane 4 `R-407`
- **該当**: `plan.md` Verification Plan（R-017 反映済みの CI 時間見積 節）
- **指摘**: R-017 の反映で **総量の見積り**（フルスイート baseline 231s / 増加分の裁定）は入ったが、
  **contract TA が各ファイルを実走するループの per-file timeout が未定義**のまま。
  系統 B 実測では `ta-26` 単独が **54〜58 秒**（自己再帰起動 2 回分。ファイル内コメントは「約 13 秒」と
  書かれており drift している）で、**60 秒 timeout では偽 FAIL** する。
  さらに本 repo の環境には **`timeout(1)` が存在しない**ため、素朴に `timeout` を書くと
  コマンド不在で rc=127 になる。
- **是正案**:
  1. per-file timeout を **最低 180s** と明記する。
  2. timeout の実装手段を規定する（`timeout(1)` 不在のため `perl -e 'alarm N; exec @ARGV'` 等）。
  3. **timeout 発火は SKIP ではなく FAIL** とする（SKIP にすると本 PBI が塞ごうとしている
     「静かに通る」クラスを新設することになる）。
  4. `ta-26` のコメント drift（13 秒 → 実測 54 秒）は Slice 2 の対象として handoff へ残す。

## R-027 capability marker の検出に 4 経路の空振りがあり、正規表現仕様が未定義

- **severity**: major
- **出典**: 系統 B Lane 2 `R-205`
- **該当**: `plan.md` Contract Design（capability marker）/ `test-cases.md` TC-09（marker count == 1）
- **指摘**: marker は**コメント行**として置かれるため、系統 B は以下 4 経路の空振りを実測した。
  1. **1 行に 2 つの marker** が書かれると count が 2 になる／書き方次第で 1 に見える
  2. **行末スペース**があると厳格アンカー（`$` 固定）の grep が **0 件**になる
  3. **heredoc の中**に marker 文字列があると誤カウントする
  4. **contract TA 自身**が marker 文字列を持つため自己マッチする
  現行 TC-09 は「marker count が正確に 1」としか書いておらず、**どの正規表現でどの範囲を走査するか**が
  仕様化されていないため、実装者ごとに上記のどれかを踏む。
- **是正案**: marker の**正規表現を仕様として plan に明記**し、
  **探索範囲をファイル先頭 20 行に限定**、カウントが 1 以外なら FAIL とする
  （実測: `ta-*.sh` は 57/57 が shebang を持たず 2 行目が `# Sourced by tests/run-tests.sh …` で統一されているため、
  先頭 20 行への限定は構造的に安全 — 系統 A 実測サマリと整合）。
  contract TA 自身の自己マッチは、既に採用済みの「自己を除外する」規律（C-1 第 4 ラウンド MJ-I）と同じ扱いにする。

## R-028 TC-16 が実 `tests/extras/` に `ta-zz-probe.sh` を作る設計になっている

- **severity**: major
- **出典**: 系統 B Lane 2 `R-210`
- **該当**: `test-cases.md` `### TC-16 New file without contract`
  （"Adding a temporary `ta-zz-probe.sh` without marker/init …"）
- **指摘**: `tests/run-tests.sh:165` は **無条件に全 `ta-*.sh` を source** する。
  TC-16 が実 `tests/extras/` へ `ta-zz-probe.sh` を作る方式だと、
  **中断・異常終了時の残留が以後すべての run を汚染する**（残留ファイルは marker も init も持たないため
  contract TA が恒常 FAIL になり、原因が「前回の中断」であることが判らない）。
- **是正案**: TC-16 を **サンドボックス方式**（`mktemp -d` した repo コピー配下で実施）へ変更し、
  **実 `tests/extras/` への書き込み禁止**を Global Constraints へ明記する。
  TC-17 / M-10 が既に採用している「repo 実コピー sandbox」（`plan.md` `#### TC-17 / M-10 の sandbox 構成手順`）
  と同じ構成を流用できる。

## R-029 probe の合格条件が `rc=1` のみで、他要因の rc と区別できない

- **severity**: major
- **出典**: 系統 B Lane 2 `R-203`（+ `R-204` の rc=2 衝突分）
- **該当**: `test-cases.md` TC-12（差分 assert に強化済み）/ TC-11（rc=2 の assert）
- **指摘**: R-016 / 裁定② の反映で TC-12 は
  **(a) probe なし → rc=0 / (b) probe あり → rc=1** の差分 assert へ強化されたが、
  合格条件は依然 **rc の値だけ**である。
  - **rc=1 側**: 層 0 の 4 本は legacy の `[ "$fail" -eq 0 ] || exit 1` を持つため、
    **finalize が一度も呼ばれなくても他要因で rc=1 になりうる**。
    「finalize に到達し `fail>0` が rc=1 へ写像された」ことを証明できない。
  - **rc=2 側**: shell の**構文エラーも rc=2**（コマンド不在は rc=127）。
    構文を壊されたファイルは harness-only guard が実行されていなくても TC-11 を PASS しうる。
- **是正案**:
  1. TC-12 を **`rc == 1` AND 出力に probe 固有の一意文字列**（例 `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>`）
     を含む、の AND にする。probe message に capability と test-id を載せる。
     （plan の Contract probe 節は「区別可能なメッセージ」までは規定済みだが、**TC 側の assert 条件になっていない**）
  2. TC-11 を **`rc == 2` AND `[ERROR] <basename-id> is harness-only`** の id 込み照合にする
     （現行 TC-11 の "emits standard diagnostic naming that basename" を **合格条件**として明文化する）。
  3. `sh -n` の独立 TC を置き、構文破壊が rc=2 に化けて紛れないようにする
     （`plan.md` の Verification Plan には `sh -n` 実行があるが、**TC としては独立していない**）。

## R-030 案 D における `original rc` の捕捉規約が未定義

- **severity**: major
- **出典**: 系統 B Lane 1 `R-104`
- **該当**: `plan.md` `### Finalize precedence` の precedence 表
  （`present / nonzero / …` → `original rc` を保持する 2 行）
- **指摘**: precedence 表は「元の rc を保持する」ケースを持つが、
  **案 D（末尾で明示呼出）では `$?` は直前の 1 コマンドで容易に失われる**。
  系統 B 実測: `fail=0; false; printf 'summary'; fin "$?"` → `orig=0`（rc 1 が消える）。
  既存 4 件（層 0）は **summary を printf してから** `[ "$fail" -eq 0 ] || exit 1` を実行する形であり、
  この形をそのまま helper 化すると「保持しているつもりで常に 0」になる。
  なお `original rc` を保持する 2 行は、案 C（trap が `$?` を受け取る）でしか自然に成立しない設計だった。
- **是正案**: いずれかを選ぶ。
  - (a) **2 値化**: `fail>0 → 1` / `fail==0 → 0` とし、precedence 表から `original rc` 行を落とす（Lane 1 推奨）
  - (b) **保持する**: 「`pg_extra_contract_finalize` 呼び出しの**直前に他コマンドを挟まない**」を規約化し、
    `tests/extras/README.md` の新規ファイル checklist に入れる。summary 出力は helper 内部で行う
  どちらを採るかで README 規約と Task 5 の置換テンプレートが変わるため、**C-3 前に確定**する。

## R-031 helper が env unset / ROOT 解決を所有すると `ta-26` TC-33 が空洞化する（現行方針との相違点）

- **severity**: minor
- **出典**: 系統 B Lane 4 `R-401`
- **該当**: `plan.md`「`ta-26` TC-33 の扱い」節（R-013 反映済み）
- **指摘**: R-013 の反映で「TC-33 の検査対象を helper 側へ差し替える」方針が確定し、
  さらに「Slice 1 では `ta-26` を触らないため TC-33 は Slice 1 では壊れない」と整理されている。
  系統 B Lane 4 は**これと異なる結論**に到達しており、相違点を記録しておく。
  - TC-33（`ta-26:684-735`）は「各ファイル**自身の** unset 行が harness 7 env を包含すること」を
    **extras 横断で静的走査**する唯一の箇所（`ta-26:712`）である。
  - 検査対象を helper 1 ファイルへ差し替えると、**#914 の「残存 0」という全体性質の検証が消える**。
    「helper の unset 集合が 7 env を包含する」ことは、
    「**全 `ta-*.sh` が helper を通っている**」ことと合わせて初めて等価になる。
  - Lane 4 の代案: **helper は env unset と ROOT 解決を所有しない**（各ファイルの既存 unset ブロックは維持し、
    helper の責務を capability 判定 / counter 初期化 / cleanup registry / finalize / exit code / probe に限定）。
- **是正案**: 現行方針（helper 側へ差し替え）を維持する場合は、
  **「全 `ta-*.sh` が helper bootstrap + init を持つ」ことの検査が TC-33 の代替として等価である**根拠を
  plan に明記する（`test-cases.md` の TC-33 再ターゲット記述は既にこの 2 条件を書いているため、
  **等価性の主張を明示するだけで足りる**可能性が高い）。Slice 2 で層 0 を移行する時点で再評価する。
- **注**: 本項は「main の方針が誤っている」という指摘ではなく、**独立レーンが別解に到達した事実の記録**。

## R-032 `tests/run-tests.sh` のコメントと実 glob が不一致で、将来 helper が混入しうる

- **severity**: minor
- **出典**: 系統 B Lane 3 `R-003`
- **該当**: `tests/run-tests.sh:7` / `:155`（コメント: 「`tests/extras/*.sh` を順次 source」）vs `:165`（実装: `for extra in "$EXTRAS_DIR"/ta-*.sh`）
- **指摘**: 実装は `ta-*.sh` glob なので `_extra-contract.sh` は現状混入しない
  （`plan.md` `## 前提の実測検証` の判定 ✅ は正しい）。
  しかし**コメント 2 箇所が `*.sh` と書いており実装と食い違う**。
  将来この不一致を「コメントが正」と読んで glob を `*.sh` へ「修正」すると、
  **helper が 1 個の extras として source され**、`pg_extra_contract_init` 未呼出のまま runner の集計に混入する。
  本 PBI が導入する helper が、この既存の罠の**引き金**になる。
- **是正案**: 本 PBI のスコープに「`tests/run-tests.sh` の当該コメント 2 箇所を実装（`ta-*.sh`）へ合わせる」を追加する。
  Out of Scope は「集計アルゴリズム変更」であり、コメント是正は抵触しない。
  あわせて `tests/extras/README.md` の新規ファイル規約に
  「`ta-` プレフィクスを持つファイルのみが test として収集される」を明記する。
  検証: `grep -n 'extras/\*\.sh' tests/run-tests.sh` が 0 件。
- **注**: R-010 で「runner 変更を落とせるか」を Task 3 で比較検証することになっているため、
  **runner 変更をゼロにする判断を採る場合はこのコメント是正も落ちる**。その場合は README 側だけで対応する。

## R-033 helper 実装の 3 つの未規定事項（`local` / mode 解決タイミング / 対話シェル source）

- **severity**: minor
- **出典**: 系統 B Lane 1 `R-110` / `R-113` / `R-112`
- **指摘**: Global Constraints は「helper は POSIX `sh` で動作し bash 専用構文を使わない」としか書いておらず、
  以下 3 点が **未規定のまま実装に委ねられている**。いずれも「動いてしまうため検出されない」型。
  1. **`local` は POSIX 外**（`R-110`）。dash / bash / zsh のいずれも受け付けるため
     **どのシェルでも検出されず**、より厳格な `sh` 実装で初めて壊れる。明示禁止が要る。
  2. **mode（harness / standalone）の解決タイミング**（`R-113`）。
     **mode は `pg_extra_contract_init` 呼出時に毎回解決**し、**source 時にキャッシュしない**こと。
     キャッシュすると runner が helper を先に source する設計（Task 3）で mode が固定される。
  3. **対話シェルへ source した場合**（`R-112`）、standalone finalize の `exit` が
     **ユーザのシェルを落とす**。`tests/extras/README.md` に「対話シェルへ source しない」を明記する。
- **是正案**: 上記 3 点を Global Constraints / Helper interface / README 規約へそれぞれ 1 行ずつ追加する。

## R-034 TC-15 の `seven`（env 数）がハードコードされている

- **severity**: minor
- **出典**: 系統 B Lane 2 `R-214`
- **該当**: `test-cases.md` TC-15（"With the **seven** guarded env values pre-set, …"）
- **指摘**: `ta-26` の TC-33 は **まさに件数固定を避けるため** `awk` で `run-tests.sh` から
  動的に env 名を導出している（`ta-26:700-711`）。TC-15 の `seven` はそれに逆行し、
  runner の unset 列が増減したときに**テスト文言だけが stale**になる
  （Global Constraints「file count / ta 番号一覧を正本としてハードコードしない」の精神とも整合しない）。
- **是正案**: TC-15 の記述を「**`run-tests.sh` の unset 列から動的に導出した全 env**」へ書き換え、
  件数を文言から落とす。

## R-035 「発見集合 == runner の source 集合」を保証する TC がない

- **severity**: minor
- **出典**: 系統 B Lane 2 `R-215`（+ `R-216`）
- **指摘**: contract TA は自前の runtime discovery で `ta-*.sh` を列挙するが、
  **その集合が runner が実際に source する集合と一致する保証**がテストされていない。
  片方の glob だけが変わると、contract TA が「全件検査した」と言いながら
  runner が source する一部を見ていない状態になりうる（本 PBI が塞ごうとしている空振りと同型）。
  関連して、`ta-40` は `FIXTURES_DIR:-` を参照しないため **`ta-26` TC-33 の網にそもそも掛からない**
  （`ta-40` が層 A に含まれることは R-003 で反映済みだが、TC-33 側の網羅性は別問題）。
- **是正案**: 「contract TA の discovery 集合 == `tests/run-tests.sh` の extras loop が source する集合」
  を assert する TC を追加する（両者が同じ glob 定義を参照する構造にするのが最も安価）。

## R-036 移行 PR の生存中に marker 無しの新規 `ta-NN` が着地するリスク

- **severity**: info
- **出典**: 系統 B Lane 4 `R-412`
- **指摘**: 系統 B 実測時点で `tests/` に触れる open PR は **#1013 のみ**で、当該 PR は `tests/` を変更していない。
  したがって競合の直接リスクは低い。真のリスクは
  **移行 PR の生存中に marker を持たない新規 `ta-NN` が main へ着地する**こと。
  `tests/extras/` の追加ペース実測: 2026-05 = 21 本 / 06 = 26 本 / 07 = 8 本 / 08（5 日時点）= 3 本。
- **是正案**: 移行 PR は **7 日以内に merge** することを運用目標として plan の Risks へ記載する。
  着地してしまった場合は `_pending_migration`（移行期間 allowlist）に**載っていない**ため
  TC-09 / TC-10 が FAIL する ＝ **検出はされる**（silent leak にはならない）。是正コストのみの問題。

## R-037 移行の作業設計に関する 3 提案（batch 基準 / bootstrap 縮小 / `ta-26` legacy adapter）

- **severity**: info
- **出典**: 系統 B Lane 4 `R-402` / `R-403` / `R-408`
- **指摘・提案**:
  1. **batch 基準（`R-402`）**: 「10〜15 files/batch」はファイル数基準であり、
     系統 B の risk 分布（high 1 / medium 9 / low 47）と無関係。
     **ハザードはファイル数でなく個別に偏在**しているため、batch は risk 単位で切るほうが安全。
     （現行 plan は Human 決定 3 で Slice 1 = 層 A 12 本に確定済みのため、**Slice 2 の分割設計への提案**として残す）
  2. **bootstrap の縮小（`R-403`）**: runner の extras loop に `PG_EXTRA_FILE="$extra"` の 1 行を足し、
     bootstrap を `EXTRAS_DIR` アンカー + marker 単一正本にすると **7 行 → 2 行**へ縮小でき、
     「marker と init の不一致」という故障クラス自体が消える。
     `git diff -U0 | grep '^+' | sort -u` が少数行に収束するため、レビュー量が **O(41) → O(1)** になる。
     ただし runner 変更を増やす方向であり、**R-010（runner 変更を落とせるか）と正面から競合**する。
  3. **`ta-26` の扱い（`R-408`）**: `ta-26` は既に `fail>0 → exit 1` が成立しているため、
     helper へ移行しても **#921 への behavioral gain がゼロ**。
     さらに移行すると TC-13 が「helper の出力フォーマット検証」に変質し、
     **規約を取り締まる側（TC-33 / TC-13）が取り締まられる機構（helper）に依存する循環**が生じる。
     → legacy adapter のまま残す案を Slice 2 の選択肢として保持する。
     （現行 plan は層 0 を Slice 2 へ繰り延べ済みのため、**Slice 2 の判断材料**として記録）

## 重複除外表（系統 B の 32 件のうち、本追補へ採録しなかった 15 件）

> 「main 版（R-001〜R-020 反映後の plan / todo / test-cases）に**既にある**」と判断した根拠を 1 行で記す。
> 実測は `origin/main` = `9f9af94` 時点の `docs/working/TASK-0921/` に対して行った。

| 系統 B の元 ID | 要旨 | 除外根拠（1 行） |
|---|---|---|
| `R-001` / `R-102` | helper の `register_cleanup` が harness の同名関数を上書き | **既出**: 系統 A `R-019` として反映済み。`plan.md` Global Constraints に「helper は `register_cleanup` を無条件再定義しない（R-019b）」が実在 |
| `R-002` | AC-1 の充足方法が「全件伝播」→「伝播 or 拒否」へ再解釈 | **既出**: `plan.md` In Scope の 2 層モデル + `test-cases.md` Traceability の AC-1 行が「層 A 12 本の範囲 / 全 `ta-*.sh`」と Slice 別に明示済み。Human 承認対象であることも Human Approval Boundary に記載済み |
| `R-004` | probe env を runner 冒頭の既存 unset 行へ載せる | **既出・別裁定**: 系統 A の委譲裁定 ① で **internal-only（helper 側で harness mode なら probe を読まない）** を採用し、`plan.md` Questions の「解決済み」表に確定記録済み。runner の unset 列は触らない方針が確定している |
| `R-005` | #530-3 の trap 禁止規約と案 C の関係を明記 | **失効**: Human 決定 1 で案 D（trap を張らない）を採用したため前提消滅。`plan.md` Global Constraints に「README 規約 1–2 に例外を作らない」として反映済み |
| `R-106` | helper は `set -u` clean でなければならない | **既出**: 系統 A `R-019a`。`plan.md` Global Constraints「helper は `set -eu` 下で source-safe」に反映済み |
| `R-107` | early-exit の対象は 8 サイト | **部分採録**: 対象範囲の是正は **R-021 に統合**して採録した。件数の数え方の議論そのものは重複のため個別採録しない |
| `R-109` | standalone 時の `register_cleanup` 定義順序 | **既出の系**: `R-019b` の「standalone mode でのみ未定義時の fallback として定義する」で順序も含めて規定済み |
| `R-111` | `ta-50` の stdin ハング（`</dev/null`） | **既出**: `plan.md` Global Constraints「direct invocation probe は必ず `</dev/null` を付け、ta-50 等の stdin 待ちを防ぐ」が実在 |
| `R-201` | plan 本体が案 C 専用で案 D が未定義 | **解消済み**: Human 決定 1 で案 D 採用、`plan.md` の Approach Comparison / Finalize precedence / Task 5 が案 D 前提へ全面改訂済み |
| `R-202` | 早期 `exit 0` が finalizer を飛ばす | **既出 + 部分採録**: `|| exit 0` 型 3 件は `plan.md` `## 前提の実測検証` に実測付きで反映済み。**対象範囲の誤り（`\|\| true` 型の見落とし）だけ R-021 として採録** |
| `R-204` | `exit 2` が構文エラー rc=2 と衝突 | **部分採録**: id 込み照合の要求は **R-029 に統合**。`sh -n` 自体は `plan.md` Verification Plan に実在するため、独立 TC 化のみ R-029 で扱う |
| `R-206` | marker↔init 一致検査が静的だと `if false` 包囲で回避可能 | **既出**: `test-cases.md` TC-10 に「Comment-only token elsewhere does not satisfy this test」が明記済み。加えて TC-12 の probe 差分が実行ベース検証を担う |
| `R-207` | test-id が一意でない（`ta-14` が 2 本） | **既出**: 系統 A `R-016`。`plan.md` が test-id を basename ベースへ改訂済み、TC-20（一意性）も追加済み |
| `R-209` | contract TA の自己再帰は `harness-only` 宣言が唯一の安全解 | **既出・別解**: `plan.md` が「自己再帰の回避は集合から外すことではなく per-file 実走ループで自分を除外する」形で解決済み（C-1 第 4 ラウンド MJ-I）。安全性は等価 |
| `R-211` | `[FAIL]` が stderr / stdout に混在（`2>&1` 必須） | **既出**: `plan.md` の記録コマンド仕様（`> <log> 2>&1`）/ Task 5 の `t43_fail` は stderr 出力である旨 / Verification Plan の各行に反映済み |
| `R-212` | probe は `[FAIL]` → `fail` の配線を検証しない | **既出の系**: `test-cases.md` TC-16 パターン C（marker + init はあるが末尾 finalize が無い）と M-07 が同じ穴を突いており、TC-12 の probe 差分で検出される |
| `R-214` | `seven` と「ta-39 の後」のハードコード | **部分採録**: 「ta-39 の後」は系統 A `R-006` で解消済み（TC-14 を runtime 解決へ）。**`seven` だけ未解消のため R-034 として採録** |
| `R-216` | `ta-40` が TC-33 の網に掛からない | **部分採録**: `ta-40` が層 A に含まれることは `R-003` で反映済み。TC-33 側の網羅性の論点だけ **R-035 に統合** |
| `R-217` | M-02 / M-06 が案 D で意味を失う | **解消済み**: `test-cases.md` の M-02 は「make the helper act on probe env in harness mode」、M-06 は「hardcode current file count and add probe file」へ書き換え済みで、いずれも案 D で意味を持つ |
| `R-405` | `\|\| true` 型で TC 期待値が apply 適用状態に依存（flaky） | **統合採録**: R-021 の故障モード (2)（bash で本体が走る）と同一原因のため R-021 へ統合 |
| `R-406` | fail 加算後に `exit 0` する経路が実在（`ta-43` / `ta-44`） | **既出**: `plan.md` `## 前提の実測検証`「早期 exit で fail を握り潰す実例があるか」行に記号アンカー付きで反映済み |
| `R-407` | probe の timeout が未定義（`ta-26` 54〜58 秒） | **統合採録**: R-026 へ統合（`R-208` と同一論点） |
| `R-409` | 「RED commit」と「各 commit は full suite を壊さない」の自己矛盾 | **解消済み**: 現行 `todo.md` / `plan.md` は Slice 1 を「helper + contract TA + 層 A 12 本」の単位で設計しており、RED を作らず allowlist で covered set を絞る構造になっている |
| `R-410` | README の追加手順に marker が無くコピペで落ちる | **既出の系**: `plan.md` Task 7 / Files 表が `tests/extras/README.md` の「capability / rc 0-3 / probe / new-file 規約」更新を明示済み。文言レベルの提案は確定反映時に取り込めば足りる |
| `R-411` | README の現行テスト一覧が stale（12 件 vs 実測 57 件） | **明示的に Out of Scope**: `plan.md` Out of Scope に「README の現行テスト一覧ドリフト修正」が明記されている |
| `R-413` | Alternative C（intrinsic predicate による 2 フェーズ） | **明示的に不採用**: `test-cases.md` が「allowlist は **述語で解決しない**（述語だと marker も init も持たない新規ファイルを自動免除してしまい、pbi-input AC-5 の第 2 節に反する）」と理由付きで否定済み。M-13 / M-14 が述語化・allowlist 過大化を変異として殺す |

> 除外 15 件（表の「既出」「解消済み」「明示的に Out of Scope」「明示的に不採用」）+ 統合 6 件
> （`R-107` / `R-202` / `R-204` / `R-214` / `R-216` / `R-405` / `R-407` のうち R-021 / R-026 / R-029 / R-034 / R-035 へ統合）
> = 系統 B の 32 件のうち **本追補で新規採録したのは 17 件（R-021〜R-037）**。

## 追補の監査表（追記専用 / squash・rebase 耐性）

> `status`: `open`（未反映）/ `reflected`（計画本体へ反映済み）/ `rejected`（不採用・理由を notes へ）/
> `resolved-by-design`（設計変更により前提が消滅）
> 本追補は working-context「(1) review-external に R-NNN 集約」までを完了させた状態であり、
> **計画本体（plan / todo / test-cases）は一切変更していない**。したがって全件 `open`。

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|----------------------|-------|
| R-021 | open | — | **critical** / 系統 B Lane 1 `R-101`+`R-107`+`R-108` / Lane 4 `R-405` / `\|\| true` 型 4 件（`ta-45`/`ta-46`/`ta-47`/`ta-49`）のシェル依存早期脱出。CI(dash) で末尾 finalize 到達不能・bash で skip guard 素通り。**Slice 1 スコープ内** |
| R-022 | open | — | major / 系統 B Lane 1 `R-101` / `D-0921-10` / CI の `sh` 実体が未固定。**`.github/workflows/**` は HO 対象のため AI は patch 提示のみ** |
| R-023 | open | — | major / 系統 B Lane 2 `R-213` / 偽 PASS 3 件（`ta-11`/`ta-32`/`ta-38`）を contract TA が合格させる。ROOT sentinel の fail-closed を提案。**Human 判断項目（スコープ内 / 別 issue）** |
| R-024 | open | — | major / 系統 B Lane 1 `R-103` / harness 経路での非 0 `return` が `set -e` でスイート即死。Global Constraints は `exit` しか禁じていない |
| R-025 | open | — | major / 系統 B Lane 1 `R-105` / Lane 4 `R-404` / bootstrap の `.` 失敗と runner source 行の単独 revert が suite 即死。`EXTRAS_DIR` アンカー + 適用/revert の順序制約 |
| R-026 | open | — | major / 系統 B Lane 2 `R-208` / Lane 4 `R-407` / per-file timeout 未定義。`ta-26` 実測 54〜58 秒 / `timeout(1)` 不在 / timeout 発火は SKIP でなく FAIL |
| R-027 | open | — | major / 系統 B Lane 2 `R-205` / marker 検出の空振り 4 経路（1 行 2 marker / 行末スペース / heredoc 内 / 自己マッチ）。正規表現仕様化 + 先頭 20 行限定 |
| R-028 | open | — | major / 系統 B Lane 2 `R-210` / TC-16 が実 `tests/extras/` に `ta-zz-probe.sh` を作る設計。sandbox 化 + 実ディレクトリ書込禁止 |
| R-029 | open | — | major / 系統 B Lane 2 `R-203`+`R-204` / probe 合格条件が rc 値のみ。一意文字列 AND / rc=2 の id 込み照合 / `sh -n` 独立 TC |
| R-030 | open | — | major / 系統 B Lane 1 `R-104` / precedence 表の `original rc` を案 D でどう捕捉するかが未定義。2 値化 or 「finalize 直前にコマンドを挟まない」規約 |
| R-031 | open | — | minor / 系統 B Lane 4 `R-401` / helper が env unset / ROOT 解決を所有すると TC-33 が空洞化。**現行方針との相違点の記録**（等価性の明示を提案） |
| R-032 | open | — | minor / 系統 B Lane 3 `R-003` / `tests/run-tests.sh:7,155` のコメント（`extras/*.sh`）が実装（`ta-*.sh`）と不一致。将来 helper 混入の引き金 |
| R-033 | open | — | minor / 系統 B Lane 1 `R-110`+`R-113`+`R-112` / `local` は POSIX 外 / mode は init 毎回解決（source 時キャッシュ禁止）/ 対話シェル source 禁止を README へ |
| R-034 | open | — | minor / 系統 B Lane 2 `R-214`（`seven` 部分のみ） / TC-15 の env 件数ハードコード。`run-tests.sh` から動的導出へ |
| R-035 | open | — | minor / 系統 B Lane 2 `R-215`+`R-216` / 「contract TA の discovery 集合 == runner の source 集合」を assert する TC が無い |
| R-036 | open | — | info / 系統 B Lane 4 `R-412` / 移行 PR 生存中の marker 無し新規ファイル着地。検出はされる（TC-09/TC-10 FAIL）ため是正コストのみ。7 日以内 merge を推奨 |
| R-037 | open | — | info / 系統 B Lane 4 `R-402`+`R-403`+`R-408` / batch 基準を risk 分布へ / bootstrap 7 行→2 行（`PG_EXTRA_FILE`）/ `ta-26` は legacy adapter。**Slice 2 の判断材料** |

## 系統 B の実測サマリ（証跡は `evidence/` 配下）

> 基点 `origin/main` = `4448420`。系統 A（基点 `516e2f7`）の実測と**別採取**であり、
> 値が食い違う箇所は下表に併記した。

| 項目 | 系統 B 実測 | 系統 A 実測（既出） | 証跡 |
|---|---|---|---|
| `ta-*.sh` 総数 | **57**（`ta-48` 欠番 / `ta-14` 同番 2 本） | 57（同上） | [`evidence/inventory/extras-files.txt`](./evidence/inventory/extras-files.txt) |
| standalone-capable / harness-only | **16 / 41** | 候補 15（層 0 の 4 + 層 A の 12 = 16 と整合） | [`evidence/inventory/extras-inventory.md`](./evidence/inventory/extras-inventory.md) |
| フルスイート baseline | rc=0 / **231 秒** / **539 passed, 0 failed** | rc=0 / 231 秒 / **541 passed**, 0 failed（基点差） | [`evidence/baseline/full-suite.log`](./evidence/baseline/full-suite.log) |
| 構文チェック | 58 ファイル **エラー 0** | — | [`evidence/baseline/syntax.log`](./evidence/baseline/syntax.log) |
| `[FAIL]` を出しながら rc=0 | **35 件 / `[FAIL]` 合計 256 / 伝播 0 件** | 走査範囲（ta-04〜ta-25）で全件 rc=0 | [`evidence/baseline/standalone-current.log`](./evidence/baseline/standalone-current.log) |
| **偽 PASS**（`[PASS]` 0 かつ `[FAIL]` 0 かつ rc=0） | **3 件**（`ta-11` / `ta-32` / `ta-38`）+ `ta-06` / `ta-08` | 未検出（観点外） | 同上（R-023） |
| top-level `trap ... EXIT` | **4 件**（うち standalone-capable は `ta-45`） | **5 件**（`ta-07`/`ta-09`/`ta-24`/`ta-28`/`ta-45`。うち standalone-capable は `ta-45`） | [`evidence/inventory/trap-cleanup-audit.md`](./evidence/inventory/trap-cleanup-audit.md) |
| `ta-26` の standalone 実行時間 | **54〜58 秒**（ファイル内コメントは「約 13 秒」= drift） | 76 秒 | 同上（R-026） |
| `register_cleanup` 使用ファイル | **21 件** | — | 同上 |

> **trap の件数差（4 vs 5）について**: 系統 A は `ta-28` を含めて 5 件、系統 B は 4 件としている。
> **本追補では判定していない**（採取条件の差か走査条件の差かを特定していない）。
> 案 D 採用により trap 競合そのものが論点から外れているため実害はないが、
> **数値としてどちらが正かは未確定**であることを明示しておく。

## 追補の次ステップ（本ファイル外）

1. **完了**: review-external に `R-021`〜`R-037` を集約（本追補）
2. 計画本体（`plan.md` / `todo.md` / `test-cases.md`）へ **1 回だけ確定反映**（反映コミットに `Refs: R-021` 〜）
   — **R-022 の `.github/workflows/**` 部分は AI が適用せず patch 提示に留める**
3. 簡易 C-1 再実行
4. 人間が最終 `approvals/c3.json`（`c3_status=APPROVED`・確定後 plan の `plan_hash`）を発行
5. exec

> **注意**: 本追補時点で C-3 承認済みの `approvals/c3.json` は**存在しない**（`docs/working/TASK-0921/approvals/` 自体が未作成）。
> R-021 が critical であるため、**確定反映前の c3.json 発行は行わない**こと。
