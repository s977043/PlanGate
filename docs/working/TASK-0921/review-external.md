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
