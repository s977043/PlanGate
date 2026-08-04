---
task_id: TASK-0981
artifact_type: review-self
schema_version: 1
status: draft
verdict: PASS
created_by: orchestrator
---

# TASK-0981 セルフレビュー結果（C-1）

> **最新の判定は本ファイル末尾の「[簡易 C-1 再実行（是正後・head `117d10e`）](#簡易-c-1-再実行是正後head-117d10e)」を参照**。以下の初回レビュー（head `2d6a5dd` / 総合 FAIL）は**監査のため原文のまま保持**しており、指摘 6 件はすべて是正済み（最終判定 = **PASS**）。

## 初回レビュー（head `2d6a5dd`）

> レビュー日: 2026-08-05
> 対象: `plan.md` / `todo.md` / `test-cases.md`（ブランチ `docs/981-plan` = `2d6a5dd`）
> 入力の正: `pbi-input.md`（main マージ済み・不変）+ issue #981 コメント（2026-08-04 / Human 確定）
> レビュアー: plan を書いた担当とは別の独立レビュアー
> 判定: **FAIL** — critical=0, major=2, minor=4
> **チェック項目数**: **25 項目**（[`docs/working/templates/review-self.md`](../templates/review-self.md) の `grep -c '^### C1-'` = 25 の実測値。本文中の「7項目」「6項目」「3項目」等の小見出し表記および他所の「17 項目」表記は実体と一致しないため、本レビューは**テンプレートの `### C1-` 見出しを全数走査**して評価した）

## サマリー

| result | 件数 |
|--------|------|
| PASS | 17 |
| WARN | 4 |
| FAIL | 2 |
| N/A | 2 |

合計 25 項目（PASS + WARN + FAIL + N/A）。

### FAIL 2 件の要旨

| ID | 項目 | 要旨 |
|----|------|------|
| **F-1** | C1-PLAN-03 | `## Files / Components to Touch` 節に置かれた「触れないもの（明示）」の backtick パスが `extract_allowed_paths()` に**許可パスとして抽出される**。機械が読む `allowed_paths` は `schemas/**` / `bin/plangate` / `scripts/**` / `.claude/**` / `.github/workflows/**` / `pbi-input.md` を**含み**、plan 本文の Constraint 6・7 と正反対の宣言になる |
| **F-2** | C1-TEST-14 | AC-6 / TC-15 / Stop Condition 5 / RT-5 が「差分は**すべて `.md`**・**9 ファイル**」を判定基準にしているが、本リポジトリの working context は `approvals/c3.json`（**JSON**）/ `decision-log.jsonl` / `INDEX.md` / `current-state.md` を**追跡している**。H-01 で発行する c3.json が同一ブランチに載った時点で TC-15 が FAIL し、Stop Condition 5 / RT-5（exec 停止・ブランチ作り直し）が誤発火する。加えて TC-18 の期待値（`approvals/c3.json not found` が残る）は H-01 → T-01 → T-10 という todo の依存順と矛盾する |

## Plan チェック（#544 Phase1 の AEE 2 項目を含む）

### C1-PLAN-01: 受入基準網羅性

- **result**: PASS
- **category**: plan
- **finding**: AC-1〜AC-6 がすべて Work Breakdown の Step に到達する（AC-1→Step 3 / AC-2・AC-3→Step 4 / AC-4→Step 5 / AC-5→Step 6 / AC-6→Step 9）。pbi-input の AC 6 件と 1:1 で、AC の新設・削除はない。#981 全体 AC 14 項目と PR1 の関係表も pbi-input から引き継がれている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-02: Unknowns処理

- **result**: PASS
- **category**: plan
- **finding**: pbi-input の U-1〜U-8 が全 8 件仕分けされ、未処理が 0 件（PR1 で確定 = U-1 / U-2 / U-3 / U-6 / U-8 の 5 件、PR2 以降へ送る = U-4 / U-5 / U-7 の 3 件）。送る側にも送る理由（U-4 は主体差が #980 未実装期間に検証不能 / U-5 は execution reference 確定が前提 / U-7 は field set 設計が PR2）が付いており「先送り」で終わっていない。pbi-input の記述と矛盾する仕分けは検出されなかった。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御

- **result**: **FAIL**
- **category**: plan
- **finding**: 散文（Constraint 6 / 7・Non-goals・「触れないもの（明示）」）としてのスコープ制御は明確だが、**機械が読む宣言が逆になっている**。`extract_allowed_paths()`（`scripts/ai-loop/plan_package.py` `_PATH_RE` = `` `([^`\s]+/[^`\s]+)` `` を `## Files / Components to Touch` 節に適用）は、同じ節の末尾に置かれた「触れないもの（明示）」行の backtick パスも抽出する。結果、本 plan の `allowed_paths` は **16 件**となり、`schemas/**` / `bin/plangate` / `scripts/**` / `tests/**` / `.claude/**` / `.github/workflows/**`（= Constraint 7 が「含まない」と宣言した HO 対象）と `docs/working/TASK-0981/pbi-input.md`（= Constraint 6 が「改変しない」と宣言した入力）が**許可側**に入る。#981 は `allowed_paths` の抽出契約そのものを棚卸しする PBI であり、その plan 自身が抽出器に対して誤った宣言を出す状態は許容できない。
- **evidence_ref**: 本ファイル §Evidence E-1（再現コマンドと実測出力）
- **impacted_files**: `docs/working/TASK-0981/plan.md`
- **severity**: major
- **suggested_action**: 「触れないもの（明示）」の 1 行を `## Files / Components to Touch` 節の**外**（例: `## Constraints / Non-goals` 直下、または新設の `### 非対象パス` を別 `##` 節として）へ移すか、当該行のパスから backtick を外して抽出対象から外す。移動後に `extract_allowed_paths()` を再実行し、抽出結果が意図した 9〜10 件（変更対象 `.md` のみ）であることを実測で確認する。表本体の `docs/working/TASK-0981/pbi-input.md` も「変更しない」対象なので、表から外すか非 backtick 表記にする。
- **owner**: agent
- **resolved**: false

### C1-PLAN-04: テスト戦略

- **result**: WARN
- **category**: plan
- **finding**: Unit / Integration に相当する層（成果物構造検査・根拠の実測再現・非退行・差分性質・lint・リンク到達性）が具体的なコマンド付きで定義されており、文書のみの PR に対する検証設計として十分具体的である。**懸念は対象ファイル集合の不足**: Files / Components to Touch と TC-15 のファイル数（9）に、[`working-context.md`](../../../.claude/rules/working-context.md) が標準 artifact と定める `INDEX.md` / `current-state.md` / `decision-log.jsonl` が入っていない（既存 TASK-0873 / TASK-0907 はいずれも 3 点とも git 追跡している）。また T-10 / Step 9 は `evidence/verification/` へ実行ログを保存すると書いているのに、その evidence ファイルが Files 表にもファイル数 9 にも算入されていない（本リポジトリでは `docs/working/*/evidence/*` は追跡対象で `.gitignore` されていない）。
- **evidence_ref**: 本ファイル §Evidence E-2
- **impacted_files**: `docs/working/TASK-0981/plan.md`, `docs/working/TASK-0981/test-cases.md`
- **severity**: minor
- **suggested_action**: (1) `INDEX.md` / `current-state.md` / `decision-log.jsonl` / `evidence/verification/*` を Files 表に追加するか、「本 PBI では作成しない」ことを明記して例外扱いにする。(2) TC-15 のファイル数を固定値ではなく「Files 表に列挙したファイルの集合と一致」に変える。
- **owner**: agent
- **resolved**: false

### C1-PLAN-05: Work Breakdown Output

- **result**: PASS
- **category**: plan
- **finding**: Step 1〜9 のすべてに `**Output**` / `**Owner**` / `**Risk**` / 🚩 チェックポイント / `rollback:` が揃っている。Output は成果物パスまたは記録先まで具体化されており（例: Step 2 = `docs/decisions/adr-002-plan-contract-canonical-source.md` の新規作成 + 節構成の指定）、「ADR を書く」のような粒度の粗い記述は残っていない。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-06: 依存関係

- **result**: PASS
- **category**: plan
- **finding**: plan Step 1〜9 と todo T-01〜T-11 の依存が矛盾なく直列化されている（todo 冒頭の依存グラフが H-01 → T-01 → … → T-11 → L-0/V-1/V-3 → H-02 を明示）。同一ファイル（ADR）を編集する T-02〜T-07 を並行不可とする注記、T-04 をブロッキング完了条件とする注記、T-08 を T-04 の後に置く理由（追記内容が D-4 の結論に依存）も明示されている。plan の 9 Step に対し todo が 11 タスク（T-09 = PR2/PR3 スコープ表、T-11 = handoff）に分割されている点も、plan Step 7 後段・Step 9 後段として対応が取れている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-07: 動作検証自動化

- **result**: PASS
- **category**: plan
- **finding**: Verification は実行可能なコマンド粒度まで落ちている（`git diff origin/main --name-only` / `sh tests/run-tests.sh` / `ls scripts/ai-loop/test_*.py` の全件ループ / `bin/plangate validate TASK-0981` / `npx --no-install markdownlint-cli2 ...` / 相対リンクの `test -f`）。TC の自動化可否表で「可」12 件・「半自動」13 件が分離され、半自動の判定規約（該当語の存在だけで PASS にしない・空欄 1 件で FAIL・FAIL 時は evidence 必須）まで規定されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-08-AEE: Stop Condition 記入（#544 Phase1）

- **result**: PASS
- **category**: plan
- **finding**: `## Stop Condition（即停止条件）` に 7 件が記入されている。うち 1 / 4 / 5 / 7 は機械判定可能な閾値（ファイル数 16 以上 / `failed > 0` / `.md` 以外の出現 / 未決 3 件以上）。ただし条件 5 は F-2 の理由で誤発火リスクがある（当該項目で指摘済み）。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-09-AEE: Replan Triggers 機械値（#544 Phase1）

- **result**: PASS
- **category**: plan
- **finding**: RT-1〜RT-6 のすべてが機械値で書かれている（`> 15` / 決定変更の有無 / アンカー喪失 1 件以上 / `failed > 0` または `passed` 不一致 / `.md` 以外 1 件以上 / markdownlint issues `> 0`）。RT-4 は baseline のゆらぎ（初回 513・以降 514）を踏まえ「2 回取得し直して安定値を確認」という再現手順まで書かれており、機械値と運用手順が整合している。
- **evidence_ref**: —
- **impacted_files**: []

## Plan 品質追加チェック（Superpowers 由来 / #581）

### C1-SUP-PLAN-01: No Placeholders Rule

- **result**: PASS
- **category**: plan
- **finding**: `grep -nE "TBD|TODO|後で実装|必要に応じて|いい感じに|適切に|Task N と同様"` を 3 ファイルに実行した結果、ヒットは todo L75 と test-cases L50 の 2 件のみで、いずれも「`TBD` が 0 件であることを検査する」という**検査条件の記述**であり未解決の placeholder ではない。D-1〜D-10 はすべて「決定」欄が埋まっており、「検討中」「PR2 で決める」に逃げた決定は 0 件。
- **evidence_ref**: —
- **impacted_files**: []
- **failure_policy**: high-risk のため重大な曖昧表現は FAIL 判定とする基準を適用。該当なし。

### C1-SUP-PLAN-02: Task Sizing Rules

- **result**: PASS
- **category**: plan
- **finding**: 各タスクに変更対象ファイル・検証コマンド・期待結果・依存関係が具体的に付いており、reviewer が T 単位で approve / reject できる。特に T-04 は「ブロッキング条件」として独立に判定可能な 🚩（配置表の全行充足 + 3 経路 × 4 軸の 12 セル充足）を持つ。責務混在（1 タスクで ADR 全体を書く等）は見られない。
- **evidence_ref**: —
- **impacted_files**: []
- **failure_policy**: high-risk のため Task 単位の検証不能・責務混在・依存不明を FAIL とする基準を適用。該当なし。

## ToDo チェック

### C1-TODO-08: タスク粒度

- **result**: WARN
- **category**: todo
- **finding**: 依存・完了条件の観点では適切に分割されているが、テンプレートの目安「2〜5 分」に対して T-02〜T-07（ADR 本文の執筆 6 タスク）は明らかに超過する見込みで、各タスク内に複数の表・分界表・根拠掲載が含まれる。実害は「途中で中断したときの再開点が粗くなる」ことに留まる（各 🚩 で成果物が確定するため巻き戻しは可能）。
- **evidence_ref**: —
- **impacted_files**: `docs/working/TASK-0981/todo.md`
- **severity**: minor
- **suggested_action**: T-04（PR1 の中核）だけでも「配置表の作成」「3 経路比較表の作成」「Decision 節の断定文」に 3 分割し、中断時の再開点を細かくする。他タスクは現状維持でよい。
- **owner**: agent
- **resolved**: false

### C1-TODO-09: depends_on設定

- **result**: PASS
- **category**: todo
- **finding**: `depends_on:` フィールド形式ではないが、冒頭の依存グラフ（コードブロック）が全タスクの前後関係を一意に表現しており、加えて ⚠️ 注記 3 件で並行不可・ブロッキング・順序理由が補足されている。Human タスク H-01 / H-02 の挿入位置も明示され、Agent ↔ Human の依存が読み取れる。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-10: チェックポイント設定

- **result**: WARN
- **category**: todo
- **finding**: T-01 / T-02 / T-03 / T-04 / T-05 / T-07 / T-08 / T-10 / T-11 には 🚩 チェックポイントがあるが、**T-06（#980 境界の記録）と T-09（PR2 / PR3 スコープ表の反映）には 🚩 が無い**。plan 側では Step 6 に 🚩 が存在するため todo との非対称であり、T-09 は plan に対応 Step が無く（Step 7 の後段扱い）検証条件が未定義のまま残る。
- **evidence_ref**: —
- **impacted_files**: `docs/working/TASK-0981/todo.md`
- **severity**: minor
- **suggested_action**: T-06 に plan Step 6 の 🚩（「非検証」の語の存在 + PR2 への申し送りが決定事項として書かれていること / TC-22）を転記する。T-09 に「PR1 → PR2 → PR3 → #980 → PR4 の順序制約が記載され、U-4 / U-5 / U-7 の送り先が全件明示されている」旨の 🚩 を追加する。
- **owner**: agent
- **resolved**: false

### C1-TODO-11: Iron Law遵守

- **result**: PASS
- **category**: todo
- **finding**: H-01（C-3 ゲート）が T-01 より前に置かれ、承認前の実装着手経路がない。Mode=high-risk により autonomous APPROVE 不可であることが todo 冒頭と H-01 の両方に明記され、`bin/plangate approve TASK-0981` の発行タイミング（確定反映の**後**）と EH-3 の mismatch 検知の関係も注記されている。H-02 に `NO MERGE BY AI` / マージは Human-owned が明記されている。HO 対象パスは変更対象に含まれず、D-6 / D-4 の HO 変更は「patch 提示まで・適用は Human-owned」と一貫している。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-12: 完了条件

- **result**: PASS
- **category**: todo
- **finding**: 各タスクに Output と 🚩（T-06 / T-09 を除く。C1-TODO-10 で指摘済み）があり、末尾に `## 完了条件` として 5 件のチェックリスト（T-01〜T-11 完了 / TC-01〜TC-25 PASS / AC-1〜AC-6 充足 / 差分 9 ファイル / `pbi-input.md` 無変更）が置かれている。ただし 4 件目の「9 ファイル・すべて `.md`」は F-2 の対象。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-RB: rollback（戻し手順）

- **result**: PASS
- **category**: todo
- **finding**: T-01〜T-11 の**全 11 タスクに `rollback:` が記載されている**（T-01 / T-10 は「不要（読み取り・検証のみ）」と明記、T-02 と T-11 は `git rm <path>`、T-03〜T-09 は `git checkout -- <path>`）。plan 側も Step 1〜9 の全 Step に `rollback:` があり、high-risk の必須要件を満たす。戻し先パスが実在の成果物パスと一致していることも確認した。
- **evidence_ref**: —
- **impacted_files**: []

## テストケースチェック

### C1-TEST-13: 受入基準→テストケース網羅性

- **result**: PASS
- **category**: test
- **finding**: AC-1〜AC-6 のすべてに TC が割り当たっている（AC-1→TC-04/05/06、AC-2→TC-07/08、AC-3→TC-09/10、AC-4→TC-11/12、AC-5→TC-22、AC-6→TC-15/16/17/18/25）。未割当の AC は 0 件。逆方向も、PR1 固有の TC（TC-01〜TC-03 / TC-13・14・23・24 / TC-19〜21）が AC 外の完了条件として分類され、宙に浮いた TC が無い。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-14: テストケースの具体性

- **result**: **FAIL**
- **category**: test
- **finding**: 入力・期待値の記述粒度そのものは良好（値レベル・件数・空欄 0 で判定）だが、**AC-6 系 TC の期待値が本リポジトリの実運用と矛盾する**。(1) TC-15 は「差分の**全行が `.md`**・ファイル数は **9**」を期待するが、本リポジトリの working context は `approvals/c3.json`（JSON）・`decision-log.jsonl`・`INDEX.md`・`current-state.md` を git 追跡しており（TASK-0873 で実測）、H-01（`bin/plangate approve TASK-0981`）が発行する c3.json が同一ブランチに載った時点で TC-15 は FAIL する。さらに同じ条件が Stop Condition 5 と RT-5 に入っているため、**「exec を停止し、ブランチを `origin/main` から作り直す」という誤った是正が機械的に誘発される**。(2) TC-18 は T-10 時点で `bin/plangate validate TASK-0981` の FAIL が `approvals/c3.json not found` の 1 件のみに減ることを期待するが、todo の依存順では H-01（c3.json 発行）が T-01 より前であり、T-10 到達時に c3.json は**存在している**はずで、期待値と実行順序が両立しない。
- **evidence_ref**: 本ファイル §Evidence E-3
- **impacted_files**: `docs/working/TASK-0981/test-cases.md`, `docs/working/TASK-0981/plan.md`, `docs/working/TASK-0981/todo.md`
- **severity**: major
- **suggested_action**: (1) TC-15 / AC-6 / Stop Condition 5 / RT-5 の判定条件を「`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/` 配下の変更が 0 件」（= コード非接触の直接判定）に置き換え、`.md` 限定とファイル数固定は撤回する。approvals / decision-log / INDEX / current-state は許容リストとして明示する。(2) TC-18 の前提条件を「C-3 発行**前**に 1 回実行して記録する」（= T-01 より前の baseline 取得）へ移すか、期待値を「FAIL 0 件（c3.json も PASS）」に改める。どちらを採るかを plan の Testing Strategy 側でも一致させる。
- **owner**: agent
- **resolved**: false

### C1-TEST-15: エッジケースの考慮

- **result**: PASS
- **category**: test
- **finding**: EDGE-1〜EDGE-8 が「想定される誤り」「検出方法」「対応」の 3 列付きで列挙されており、いずれも本 PBI 固有の失敗モードに対応している（正本候補が複数残る / 「既存で満たす」に補強が紛れる / 行番号 stale / ADR の配置逸脱 / §8 の破壊的書き換え / sidecar への `plan_hash` コピー / 文書のみなのにテストが落ちる / `pbi-input.md` を直したくなる）。境界値（ファイル数閾値・0 件・空欄）と異常系（baseline のゆらぎ・ブランチ base 取り違え）が含まれる。
- **evidence_ref**: —
- **impacted_files**: []

## B-1/B-2チェック

### C1-B1B2-16: B-1確認質問

- **result**: WARN
- **category**: plan
- **finding**: pbi-input の曖昧点は U-1〜U-8 として構造化され、plan で全件仕分けられているため実質的な解消は行われている。ただし **pbi-input の記述を plan が実質的に変更した箇所について、Human への確認記録が残っていない**。具体的には pbi-input AC-4 が「`plan_revision` は**任意**・監査表示用の連番」と起案していたのに対し、plan D-2 は「`plan_version` / `plan_revision` を**導入しない**（将来導入する場合の唯一の許容形式は `^_plan_revision`）」へ決定を進めている。plan の判断根拠（受理器の未知キー検査で素の `plan_revision` は reject される）は実コードで正しいことを確認したが、pbi-input との差分は C-3 で人間が気づける形にしておくべきである。
- **evidence_ref**: 本ファイル §Evidence E-4
- **impacted_files**: `docs/working/TASK-0981/plan.md`
- **severity**: minor
- **suggested_action**: plan の D-2 行または「受入基準（確定版）」の前書きに「pbi-input AC-4 の起案（任意導入）から『導入しない + `^_` 限定』へ確定した」旨の 1 行を追記し、C-3 の確認対象として可視化する（pbi-input は Constraint 6 により改変しない）。
- **owner**: agent
- **resolved**: false

### C1-B1B2-17: B-2アプローチ比較

- **result**: PASS
- **category**: plan
- **finding**: 主要論点で 2〜3 案の比較と選定理由が明記されている。D-1（正本配置 3 案）/ D-3（execution reference 3 案）/ D-4（schema 機構 3 経路 × HO 接触・構造表現力・CI enforcement・承認 record の不変性の 4 軸）/ D-6（legacy 経路 3 案）/ D-7・D-8・D-9（各 2 案）。不採用理由が「コストが高い」で終わらず構造的理由（1 承認 : N 実行を 1 ファイルで表現できない / 既存 `c3.json` を一斉 invalid 化する / 宣言と実装の二重正本になる）に落ちている点が良い。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SEC-01: 秘密情報 非接触（#578）

- **result**: N/A
- **category**: plan
- **finding**: PR1 の変更対象は `docs/decisions/` / `docs/working/TASK-0981/` / `docs/workflows/ai-loop/c3-prime-contract.md` のみで、`.env` / APIキー / トークン / 個人パス / ローカル設定のいずれにも触れない。秘密情報を扱わない変更のため N/A。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離（#578）

- **result**: PASS
- **category**: plan
- **finding**: スコープ外の発見をその場で直さない方針が複数箇所で明示されている。Constraint 6 +
  Stop Condition 6 + EDGE-8（`pbi-input.md` の誤りは ADR 付表で是正し原本に触れない）、Step 1 の
  「行番号ドリフトがあれば ADR 側の付表で是正」、T-11 の V2 候補 / 妥協点への退避（U-4 / U-5 / U-7・D-9 の 3 要素部分集合案・`run.ndjson` に CI 強制が無いこと）、Replan Trigger RT-3。実装差分（PR2 / PR3）への送り先も明示されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠（#579・is_ui_task 時のみ）

- **result**: N/A
- **category**: plan
- **finding**: 本 PBI は文書のみの変更（ADR + working context artifact + 契約への 1 文追記）で UI 要素を含まない。`is_ui_task` = false のため N/A。
- **evidence_ref**: —
- **impacted_files**: []

## 実質論点の裏取り（依頼された 6 点）

plan の記述をそのまま信じず、すべて実ファイル・実コマンドで確認した。

| # | 論点 | 結果 | 実測根拠 |
|---|------|------|---------|
| 1 | Mode 判定 high-risk の妥当性（HO 非該当だが定量・定性が high） | **正しい** | `scripts/hooks/check-plan-hash.sh` の `_override` case 文（9 カテゴリ: `.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` / `.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows/` の `*.yml` と `*.yaml` / `AGENTS.md` と `CLAUDE.md`）を実読。`docs/decisions/` / `docs/working/` / `docs/workflows/` はいずれも**非該当**。したがって「承認境界周辺 → 最低 high」の機械ルートでは high にならないという plan の記述は正確。定量（9 ファイル→high 帯 6-15 / AC 6 件→high 帯 6-10 / 11 タスク→high 帯 11-20）と定性（新規設計あり・複数レイヤーへ波及）はいずれも high 帯で、最終判定 high-risk は妥当 |
| 2 | rollout-policy §2 carve-out の該当（Step 8 で `docs/workflows/ai-loop/**`） | **正しい** | [`rollout-policy.md`](../../workflows/ai-loop/rollout-policy.md) §2「判定基盤 carve-out（自己改変防止・glob）」② に `docs/workflows/ai-loop/**` が明記され、「escalate 固定」「arbiter の `boundary_check` は ho-paths.md の HO 表からのみ導出するため carve-out パスは **boundary=clean と判定される**」「よって本 carve-out は規範層であり実行者が escalate 責務を負う」と書かれている。plan Constraint 8 / Mode 判定の記述は原文と一致 |
| 3 | U-1〜U-8 の仕分け（PR1 で 5 件 / PR2 以降へ 3 件）が pbi-input と矛盾しないか | **矛盾なし**（1 件だけ実質的な決定の進行あり） | pbi-input の U-1〜U-8 と plan の仕分け表を全件突合。U-1 / U-2 / U-3 / U-6 / U-8 を PR1 確定、U-4 / U-5 / U-7 を後送は pbi-input の記述と整合する。ただし U-6 は「PR1 で方針確定 / 実装は PR2」という 2 段構成で、pbi-input の 2 択（現状維持 or 補強）のうち「補強」を選択している点は決定の進行であって矛盾ではない。**唯一の要注意点**は U-8 隣接の AC-4 で、pbi-input 起案の「`plan_revision` は任意」から plan D-2 の「導入しない」へ進んだ差分（C1-B1B2-16 の WARN で指摘） |
| 4 | D-9 の主張（C-1 marker に `plan_package_hash` は自己参照で不可能） | **正しい** | `scripts/ai-loop/c3_contract.py` の `ARTIFACTS` を実読。6 要素は `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / **`review-self.md`** / **`review-external.md`** であり、`plan_package_hash = canonical_hash(artifact_hashes)` は `review-self.md` の hash に依存する。C-1 marker は `review-self.md` の本文中に書かれるため、そこへ `plan_package_hash` を書けば自分自身の hash に依存する循環になる。「妥協ではなく構造的帰結」という plan の位置付けは妥当。**補足（info）**: 厳密には「C-1 marker に**書き込む**形式では不可能」であり、marker 以外の場所（record 側）での束縛や 3 要素部分集合による束縛は可能。plan もその逃げ道を「3 要素部分集合 = PR3 候補」として残しているため、ADR では「marker 形式での拡張が不可能」と限定して書くとより正確 |
| 5 | AC-6 の検証コマンドに `python3 -m pytest` が残っていないか | **是正済み** | `grep -n "pytest" plan.md todo.md test-cases.md` → **0 件**。`python3 -m pytest` は pbi-input L162 にのみ残る（main マージ済みで Constraint 6 により改変しない）。plan / todo / test-cases はいずれも `sh tests/run-tests.sh` と `ls scripts/ai-loop/test_*.py` の全件を `python3 <path>` で個別実行する形（`unittest` 実装に整合）に置き換わっている。実測でも `ls scripts/ai-loop/test_*.py \| wc -l` = **13** で plan の記述と一致 |
| 6 | テスト baseline の絶対値ハードコード | **していない**（判定基準は同一性） | test-cases TC-16 は「**`failed == 0`** かつ **`passed` が PR 直前に取得した baseline と同一**」を期待値とし、注記で「新規 worktree の初回実行時に 513 passed を 1 度観測」「初回実行に state 依存の TC が 1 件存在するとみられる」「絶対値固定にすると exec 開始直後に無関係な理由で FAIL する」「baseline は exec 開始時にその場で 2 回取得して安定値を採用」と明記。plan AC-6 / Step 9 / todo T-10 / RT-4 も同じ判定基準で一致している。514 は**参考実測値**としてのみ併記されており、ハードコード判定にはなっていない |

### 補足で確認した plan の主張（いずれも実測一致）

| plan の主張 | 実測 |
|---|---|
| `grep -rn "plan_version\|plan_revision" scripts/ schemas/ bin/` = 0 件（D-2 / AC-4 / TC-12 の根拠） | **0 件**（`__pycache__` 除外） |
| `arbiter.py` に `actors` / `maker` / `checker` = 0 件（ギャップ #7 / U-7） | `grep -c` = **0** |
| 受理器の未知キー検査が `^_` を除外（D-2 / D-4(a)） | `c3prime_verify.py` の `unknown = [k for k in data if k not in ALLOWED_KEYS and not k.startswith("_")]` を実読・一致 |
| `RECORD_OPTIONAL_KEYS` は `derived_loopspec_hash` のみ（D-10 の但し書き根拠） | `c3_contract.py` の `RECORD_OPTIONAL_KEYS = ("derived_loopspec_hash",)` を実読・一致 |
| legacy 経路の `if [ -n "$recorded_hash" ]` による無言 skip（D-6） | `bin/plangate` の該当ブロックを実読。`recorded_hash` が空なら hash 突合ブロック全体を素通りし、警告出力が無いことを確認・一致 |
| `schema-validate.yml` の PR トリガに `docs/working/**/*.json` を含む（D-4 の enforcement 軸） | `.github/workflows/schema-validate.yml` の `on.pull_request.paths` に `'docs/working/**/*.json'` を確認・一致 |
| `validate-schemas.py` が `rglob("*.json")`（`.ndjson` が掛からない根拠） | `paths.extend(sorted(base.rglob("*.json")))` を確認・一致 |
| ADR-001 の節構成（Step 2 / TC-01 の根拠） | `docs/decisions/adr-001-approve-out-of-band.md` に `Status` / `Date` / `PBI` / `Decision Makers` メタ + `Context` / `Problem Statement` / `Decision Drivers` / `Considered Options` / `Decision` / `Consequences` / `Related` を確認・一致。`docs/decisions/` の既存 ADR は adr-001 の 1 件のみで、`docs/rfc/` は別系統（provider-*・plangate-decompose 等）である点も一致 |
| `bin/plangate validate` の Required Artifacts 5 点（TC-18 の根拠） | `pbi-input.md plan.md todo.md test-cases.md review-self.md` のループを確認・一致 |

## Evidence

### E-1: `extract_allowed_paths()` の実測（F-1 / C1-PLAN-03）

再現コマンド:

```sh
python3 -c "
import sys; sys.path.insert(0,'scripts/ai-loop')
import plan_package as pp
t=open('docs/working/TASK-0981/plan.md').read()
ap=pp.extract_allowed_paths(t)
print(len(ap))
for p in ap: print(' -',p)
"
```

実測出力（16 件）:

```text
16
 - docs/decisions/adr-002-plan-contract-canonical-source.md
 - docs/working/TASK-0981/plan.md
 - docs/working/TASK-0981/todo.md
 - docs/working/TASK-0981/test-cases.md
 - docs/working/TASK-0981/review-self.md
 - docs/working/TASK-0981/review-external.md
 - docs/working/TASK-0981/status.md
 - docs/working/TASK-0981/handoff.md
 - docs/workflows/ai-loop/c3-prime-contract.md
 - docs/working/TASK-0981/pbi-input.md
 - schemas/**
 - bin/plangate
 - scripts/**
 - tests/**
 - .claude/**
 - .github/workflows/**
```

後半 6 件は plan の「触れないもの（明示）」行、`pbi-input.md` は Files 表の末尾注記（Constraint 6 で「変更しない」対象）に由来する。抽出器は節内の backtick パスを機械的に拾うだけで、否定文脈を解釈しない（`plan_package.py` の `_PATH_RE` + `_extract_section`）。

### E-2: working context 標準 artifact の追跡状況（C1-PLAN-04）

```sh
git ls-files docs/working/TASK-0873/
```

出力に `INDEX.md` / `current-state.md` / `decision-log.jsonl` / `approvals/c3.json` が含まれる。`.gitignore` に `docs/working/*/evidence/` や `approvals/` の除外は無く（`docs/working/_audit/hook-events.log` / `_metrics/events.ndjson` / `TASK-HOOKTEST*/` のみ）、`git ls-files 'docs/working/*/evidence/*'` も追跡ファイルを返す。

### E-3: TC-15 / TC-18 の矛盾（F-2 / C1-TEST-14）

E-2 と同じ実測により、`approvals/c3.json` は `.md` ではなく、かつ git 追跡対象である。todo の依存グラフは `H-01（👤 C-3 ゲート） └→ T-01 …… └→ T-10` であり、H-01 の完了 = `bin/plangate approve TASK-0981` による c3.json 発行が T-10 に先行する。したがって:

- TC-15「全行が `.md`」「ファイル数は 9」→ c3.json を同一ブランチにコミットする限り FAIL
- Stop Condition 5「`.md` 以外が出現したら停止」/ RT-5「ブランチ base を作り直す」→ 正常な承認フローで誤発火
- TC-18「FAIL は `approvals/c3.json not found` の 1 件のみ」→ H-01 完了後は c3.json が存在するため成立しない

### E-4: pbi-input AC-4 と plan D-2 の差分（C1-B1B2-16）

- `pbi-input.md` L160（AC-4 起案）: 「`plan_revision` は**任意**・監査表示用の連番であり実行許可判定に使わない」が明記されていること
- `plan.md` D-2 / AC-4: 「`plan_version` は**新設しない**」+「将来 `plan_revision` を導入する場合の**唯一の許容形式**は `^_plan_revision`（string・注釈キー）」

plan の判断自体は受理器の実装（`c3prime_verify.py` の未知キー検査）と整合しており技術的に正しい。指摘は「pbi-input からの決定の進行が plan 本文で明示されていない」点のみ。

## 総合判定

**FAIL**（critical=0 / major=2 / minor=4）

C-3 へ進む前に **F-1・F-2 の 2 件を修正**すること。いずれも plan / test-cases の**記述の是正のみ**で解消でき、D-1〜D-10 の決定内容・Mode 判定・スコープの変更は不要である。WARN 4 件（C1-PLAN-04 / C1-TODO-08 / C1-TODO-10 / C1-B1B2-16）は同時に反映することを推奨するが、C-3 のブロッカーではない。

修正後は簡易 C-1（本ファイルの C1-PLAN-03 / C1-TEST-14 / 該当 WARN 項目のみ）を再実行し、`extract_allowed_paths()` の再実測結果を evidence として添えること。

> **注**: 本レビューは指摘のみを行い、`plan.md` / `todo.md` / `test-cases.md` / `pbi-input.md` の修正は行っていない（レビュアーと修正者の分離）。

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| — | 自動修正なし（本 C-1 はレビューのみ。修正は plan 担当が行う） | — |

---

## 簡易 C-1 再実行（是正後・head `117d10e`）

> 再実行日: 2026-08-05
> 対象: `origin/docs/981-plan` head **`117d10e`**（前回レビュー時 `2d6a5dd`）
> 範囲: **初回 FAIL 2 件 + WARN 4 件の再評価 + 是正の副作用検査**（全 25 項目の再実行はしない。[`working-context.md`](../../../.claude/rules/working-context.md) C-3 ゲート「1 回確定反映 → 簡易 C-1 再実行」に相当）
> 更新後の判定: **PASS（条件なし）** — critical=0, major=0, minor=1（残存 WARN 1 件・C-3 のブロッカーではない）

### 再評価サマリー

| 項目 | 初回 | 再評価 | 備考 |
|------|------|--------|------|
| C1-PLAN-03（F-1 スコープ制御） | **FAIL** | **PASS** | 抽出結果を実測で再現。違反 0 件 |
| C1-TEST-14（F-2 差分判定基準） | **FAIL** | **PASS** | 判定基準の置換が plan / todo / test-cases の全 6 箇所で一貫。TC-18 の順序矛盾も解消 |
| C1-PLAN-04（標準 artifact の算入） | WARN | **PASS** | B 節新設 + 非算入理由 + 安全側確認（14 でも high-risk 帯）|
| C1-TODO-08（タスク粒度） | WARN | **PASS** | T-04 → T-04a/b/c。plan の「タスク数 13」と TC 前提条件も追随 |
| C1-TODO-10（🚩 の対称性） | WARN | **PASS** | T-06 / T-09 に 🚩 追加、plan Step 7 にも後段 🚩 を追加し plan↔todo が対称 |
| C1-B1B2-16（決定の進行の明示） | WARN | **PASS** | D-1〜D-10 表直後に注記。根拠（受理器の未知キー検査）も併記 |
| （副作用検査）C1-PLAN-01 / C1-PLAN-06 / C1-TEST-13 / D-9 info | — | **PASS** | 新設 2 節と A/B 分割による退行なし |
| （新規・残存）C1-TEST-14 内の TC-20 スコープ | — | **WARN**（minor） | 下記 R-1 |

### C1-PLAN-03: スコープ制御（F-1 再評価）

- **result**: **PASS**（FAIL から解消）
- **finding**: 是正後の `plan.md` に対して `extract_allowed_paths()` を**自分で再実行**し、抽出 **14 件・違反 0 件**を確認した（オーガナイザーの実測と一致）。消えたのは `schemas/**` / `bin/plangate` / `scripts/**` / `tests/**` / `.claude/**` / `.github/workflows/**` / `pbi-input.md` の 7 件。増えたのは B 節の標準 artifact 5 件で、これは Files 表 A + B の集合と一致する意図的な算入である。禁止領域は新設 `## Scope Boundary（変更禁止領域 / allowed_paths 非対象）` へ backtick なしで移され、`_extract_section` の走査範囲（`## Files / Components to Touch` の次 `##` まで）の外にある。
- **リンク記法の罠の確認**: 節冒頭の記載規約に「リンク記法も、両側の backtick に挟まれた URL が誤抽出されるため本節では使わない」が明文化されている。**規約が本文で守られているかを実測で確認**した。B 節の導入文には ``[`working-context.md`](../../../.claude/rules/working-context.md)`` という backtick 入りリンクが 1 件残るが、抽出結果 14 件に URL 由来の混入は無い（`(` / `)` / `http` を含む要素 0 件）。これは `` `working-context.md` `` にスラッシュが無く、かつ閉じ backtick と次の開き backtick の間に空白があるため `_PATH_RE`（`` `([^`\s]+/[^`\s]+)` ``）が成立しないためで、**実害はない**。ただし「backtick 入りリンクを節内に置かない」という規約の文面とは厳密には不一致なので、次に節を編集する担当が同型の記法を安全と誤認しないよう、当該 1 件も非 backtick 化しておくのが望ましい（info・是正必須ではない）。
- **evidence_ref**: 本ファイル §Evidence E-5
- **impacted_files**: []
- **resolved**: true

### C1-TEST-14: テストケースの具体性（F-2 再評価）

- **result**: **PASS**（FAIL から解消）
- **finding**: 判定基準の置換が**関連 6 箇所すべてで一貫**していることを差分で確認した — plan AC-6 / plan Testing Strategy「差分の性質検査」/ plan Step 9 🚩 / plan Stop Condition 5 / plan RT-5 / todo T-10 / todo 完了条件 / test-cases TC-15。いずれも「コード配下（`schemas/` `bin/` `scripts/` `tests/` `.claude/` `.github/`）0 件」+「Files 表 A + B の集合に収まる」の 2 条件になっており、「すべて `.md`」「ファイル数 9」を判定に使う記述は**残存 0 件**（grep 実測）。Stop Condition 5 には「`.md` 以外＝`approvals/c3.json` / `decision-log.jsonl` の出現は正常であり停止条件にしない」が明記され、初回指摘の**誤発火経路が塞がれている**。
- **TC-18 の順序矛盾**: 前提条件が「H-01 は T-01 より前に完了しているため c3.json は既に存在する」へ改められ、期待値が `Result: PASS`（FAIL 0 件）に変更された。**この期待値が実装上到達可能か `bin/plangate` の `cmd_validate` を実読して確認**した: Required Artifacts は `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` の 5 件（`review-external.md` / `handoff.md` は非必須）、C-3 Gate は c3.json 存在 + legacy 経路の `c3_status = APPROVED` + `plan_hash` と現 `plan.md` の一致。T-10 時点で 5 artifact は揃い、承認後に `plan.md` を変更しない限り hash も一致するため、**`Result: PASS` は到達可能**。旧期待値との差替えは妥当。
- **evidence_ref**: 本ファイル §Evidence E-6
- **impacted_files**: []
- **resolved**: true

### C1-PLAN-04: テスト戦略 / 標準 artifact の算入（WARN 再評価）

- **result**: **PASS**（WARN から解消）
- **finding**: `### B. PlanGate 標準 artifact` が新設され、`INDEX.md` / `current-state.md` / `decision-log.jsonl` / `approvals/c3.json` / `evidence/verification/**` の 5 行に「生成主体 / タイミング」「拡張子」が付いた。Mode 判定のファイル数（9）へ算入しない方針と理由（workflow の副産物であり算入すると phase 進行で Mode が揺れる）が書かれ、さらに**「算入した場合でも計 14 で high-risk 帯（6-15）に収まり結論不変」という安全側確認**が併記されている。これは [`mode-classification.md`](../../../.claude/rules/mode-classification.md) の「自動推定の安全側」と整合し、Mode 判定が数え方の解釈に依存しないことを示せている。初回指摘の「evidence が Files 表にもファイル数にも算入されていない」も B 節への収容で解消。
- **impacted_files**: []
- **resolved**: true

### C1-TODO-08: タスク粒度（WARN 再評価）

- **result**: **PASS**（WARN から解消）
- **finding**: T-04 が T-04a（配置表 / D-1・D-3 / AC-2）/ T-04b（3 経路比較表 / D-4 / AC-3）/ T-04c（Decision 節の断定文 / AC-2・ブロッキング）へ 3 分割され、各々に独立した 🚩 と成果物が付いた。**追随が漏れていない**ことを確認: 依存グラフ（T-04a → T-04b → T-04c → T-05/T-06/T-07）、⚠️ 注記（ブロッキングが T-04c へ移動・T-08 は T-04c の後）、共通 `rollback:` の明示、完了条件の「計 13 タスク」、plan Mode 判定の「タスク数 13」、test-cases の前提条件（TC-07→T-04a / TC-09・TC-10→T-04b / TC-08→T-04c）。分割後も 11-20 の high 帯に留まり Mode 判定は不変。
- **impacted_files**: []
- **resolved**: true

### C1-TODO-10: チェックポイント設定（WARN 再評価）

- **result**: **PASS**（WARN から解消）
- **finding**: T-06 に 🚩（「非検証」の語の存在 + 分界表が issue コメント §1 を漏れなく含む + PR2 への申し送りが決定事項として明記 / TC-22）、T-09 に 🚩（PR1 → PR2 → PR3 → #980 Phase 0〜2 → PR4 の順序制約 + U-4 / U-5 / U-7 の送り先全件明示）が追加された。加えて**plan 側 Step 7 にも後段 🚩 が追加**され、初回指摘の「plan には Step 6 の 🚩 があるのに todo T-06 に無い」「T-09 には対応 Step が無く検証条件が未定義」という**非対称が両方向で解消**している。依存グラフ上の 🚩 表記も T-06 / T-09 に付与済み。
- **impacted_files**: []
- **resolved**: true

### C1-B1B2-16: B-1確認質問（WARN 再評価）

- **result**: **PASS**（WARN から解消）
- **finding**: D-1〜D-10 表の直後に「pbi-input からの決定の進行（C-1 C1-B1B2-16 是正 / C-3 の確認対象）」の注記が追加され、(1) pbi-input AC-4 は「`plan_revision` は任意」と**起案**していたこと、(2) D-2 で「PR1 では導入しない」へ**確定**したこと、(3) 根拠（`c3prime_verify.py:73` の未知キー検査により素の `plan_revision` は任意キーでも reject されるため、pbi-input が想定した形は現行契約で成立しない）、(4) pbi-input は Constraint 6 により改変せず本注記で可視化する旨、の 4 点が揃った。根拠は初回レビューで実読済みの受理器コードと一致する。C-3 承認者が差分に気づける位置（決定表の直後）に置かれている点も適切。
- **impacted_files**: []
- **resolved**: true

### 副作用検査（是正が他項目に与えた影響）

| 検査対象 | 結果 | 根拠 |
|---------|------|------|
| **C1-PLAN-01（受入基準網羅）** | **PASS**（退行なし） | AC-1〜AC-6 の Step への到達は不変。AC-6 は判定方法のみが「`.md` 限定 + 9 固定」→「コード非接触 + Files 表 A+B」へ置換され、**AC の意味（既存挙動が不変であることを確認できる）は変わっていない**。test-cases の AC→TC マッピング表も AC-6 の内容説明が追随（TC 割当 TC-15/16/17/18/25 は不変） |
| **C1-PLAN-06（依存関係）** | **PASS**（退行なし） | T-04 の 3 分割で依存が直列化され（T-04a → T-04b → T-04c）、ブロッキング宣言が T-04c へ正しく移動。T-08 の配置理由も「T-04c の後」へ更新済み。plan Step 1〜9 と todo 13 タスクの対応は保たれており、宙に浮いたタスク・逆順の依存は検出されなかった |
| **C1-TEST-13（AC→TC 網羅）** | **PASS**（退行なし） | TC の追加・削除は 0 件（TC-01〜TC-25 のまま）。前提条件の T-04 → T-04a/b/c 差替えのみで、AC 未割当は発生していない |
| **新設 `## Scope Boundary` 節の副作用** | **PASS** | 本節は `## Files / Components to Touch` の**次**に置かれ、`_extract_section` の走査範囲外。禁止パスが backtick なしで書かれているため許可側へ再混入しない（E-5 の抽出結果 14 件で確認）。Constraint 6 / 7 の内容は移動のみで削除されていない |
| **Files 表 A/B 分割の副作用** | **PASS** | A は 9 行のまま（Mode 判定の母数）、B は 5 行の新設。`extract_allowed_paths()` は A + B の 14 件を返し、**exec が実際に生成するファイル集合と一致**する（承認 record・decision-log・evidence を許可側に含む点は、ai-loop 経路で本 plan を使う場合の逸脱誤検出も防ぐ） |
| **D-9 の info 対応** | **PASS** | plan D-9 が「**現行の marker 形式では**原理的に不可能」へ限定表現化され、「marker 以外の束縛（record 側フィールド / 3 要素部分集合 hash）は循環しないため不可能ではなく PR3 候補」が併記された。plan Step 7 の 🚩 と test-cases TC-14 の期待値にも「限定表現であること」「あらゆる方式で不可能と書いていないこと」が反映され、3 ファイルで整合している |
| **markdownlint** | **PASS** | `npx --no-install markdownlint-cli2 "docs/working/TASK-0981/*.md"` = **0 issues**（5 ファイル） |

### 残存 WARN（C-3 承認者の判断材料）

#### R-1: TC-20（相対リンク到達性）の検査対象が A の 9 ファイルに固定されている

- **result**: **WARN**（minor）
- **finding**: TC-20 の入力が「新規・変更した `.md` **9 ファイル**」のままで、B 節で新たに明記された `INDEX.md` / `current-state.md`（いずれも**新規の `.md`** で相対リンクを含みうる）が**リンク到達性の検査対象から外れている**。是正前は B の存在自体が書かれていなかったため潜在的だったが、B が明文化されたことで「検査対象が実際の変更 `.md` 集合より狭い」ことが可視化された。実害は「INDEX.md / current-state.md にリンク切れが混入しても doc 専用 V-1 で検出されない」に留まり、C-3 のブロッカーではない。
- **suggested_action**: TC-20 の入力を「`git diff origin/main --name-only` で得た**変更 `.md` 全件**」に変える（件数を固定しない）。TC-17 が「件数をハードコードせず `ls` の全件をループする」方針を既に採っているため、同じ方針に揃えるだけで済む。
- **owner**: agent
- **resolved**: false
- **C-3 への申し送り**: 本 WARN は exec 中（T-10）に検査対象を広げるだけで吸収でき、plan の決定内容には影響しない。**C-3 を保留する理由にはならない**と判断する。

#### 情報提供（是正不要 / info）

- **I-1**: `## Files / Components to Touch` の B 節導入文に backtick 入り Markdown リンクが 1 件残る。実測では誤抽出は発生していない（E-5）が、同節の記載規約の文面とは厳密には不一致。次に当該節を編集する担当が同型の記法を安全と誤認しないよう、非 backtick 化しておくと規約と実体が完全に一致する。
- **I-2**: TC-18 の「C-3 Gate も PASS」は、legacy 経路で `c3.json` に `plan_hash` が**無い**場合には `[WARN] plan_hash not found` となり failure に計上されないため、`Result: PASS` は成立するが hash 突合は行われない（初回レビューで実読した `bin/plangate` legacy 経路の非対称そのもの。D-6 が PR2 で塞ぐ対象）。`bin/plangate approve` が `plan_hash` を書き込む運用である限り実害はない。

### 更新後の総合判定

**PASS**（critical=0 / major=0 / minor=1）

初回 C-1 の FAIL 2 件（F-1 / F-2）は**いずれも根本原因ごと解消**しており、対症的な文言修正ではなく (a) 抽出器が読む節そのものの構造分離、(b) 判定基準を「コード非接触 + 宣言集合との一致」へ置換、という設計レベルの是正になっている。WARN 4 件もすべて解消し、副作用検査でも退行は検出されなかった。**C-3 ゲートへ進んでよい**。残存 WARN R-1 は exec 中に吸収可能で、承認保留の理由にはならない。

### Evidence（再実行分）

#### E-5: 是正後 `extract_allowed_paths()` の実測（C1-PLAN-03）

再現コマンド（E-1 と同一）:

```sh
python3 -c "
import sys; sys.path.insert(0,'scripts/ai-loop')
import plan_package as pp
t=open('docs/working/TASK-0981/plan.md').read()
ap=pp.extract_allowed_paths(t)
print('count',len(ap))
for p in ap: print(' -',p)
bad=[p for p in ap if p.startswith(('schemas/','bin/','scripts/','tests/','.claude/','.github/')) or p.endswith('pbi-input.md') or 'http' in p or '(' in p or ')' in p]
print('VIOLATIONS:', bad if bad else 'none')
"
```

実測出力:

```text
count 14
 - docs/decisions/adr-002-plan-contract-canonical-source.md
 - docs/working/TASK-0981/plan.md
 - docs/working/TASK-0981/todo.md
 - docs/working/TASK-0981/test-cases.md
 - docs/working/TASK-0981/review-self.md
 - docs/working/TASK-0981/review-external.md
 - docs/working/TASK-0981/status.md
 - docs/working/TASK-0981/handoff.md
 - docs/workflows/ai-loop/c3-prime-contract.md
 - docs/working/TASK-0981/INDEX.md
 - docs/working/TASK-0981/current-state.md
 - docs/working/TASK-0981/decision-log.jsonl
 - docs/working/TASK-0981/approvals/c3.json
 - docs/working/TASK-0981/evidence/verification/**
VIOLATIONS: none
```

初回（`2d6a5dd`）の 16 件から、禁止領域 6 件（`schemas/**` / `bin/plangate` / `scripts/**` / `tests/**` / `.claude/**` / `.github/workflows/**`）と `pbi-input.md` が消え、B 節の標準 artifact 5 件が加わって 14 件。URL 由来の混入（`(` / `)` / `http` を含む要素）は 0 件。

#### E-6: 判定基準置換の網羅性（C1-TEST-14）

```sh
grep -n "すべて \`\.md\`\|全行が \`\.md\`\|\.md\` 以外\|9 ファイル\|ファイル数は\|計 9" \
  docs/working/TASK-0981/plan.md \
  docs/working/TASK-0981/todo.md \
  docs/working/TASK-0981/test-cases.md
```

ヒットはいずれも是正後の正しい文脈のみ:

- 「コード配下 0 件 + Files 表 A + B の集合」に置換済みの判定文（plan Stop Condition 5 / todo 完了条件 / TC-15）
- 「A = 変更対象 **9 ファイル**」という Mode 判定の母数の説明（plan L189 / L297）
- 「`.md` 限定・ファイル数固定にしない理由」を説明する注記（TC-15 注記・許容リスト）
- **例外 1 件** = TC-20 の「`.md` 9 ファイル」（残存 WARN R-1 として指摘）

「全行が `.md`」「ファイル数 9」を**判定条件として**使っている箇所は 0 件。

`bin/plangate` の `cmd_validate` 実読により、TC-18 の新期待値 `Result: PASS` は Required Artifacts 5 件 + C-3 Gate（c3.json 存在 / `c3_status = APPROVED` / `plan_hash` 一致）で構成され、T-10 時点で到達可能であることを確認した。
