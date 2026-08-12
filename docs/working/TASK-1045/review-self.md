---
task_id: TASK-1045
artifact_type: review-self
schema_version: 1
status: final
verdict: WARN
created_by: independent-c1-reviewer
---

# TASK-1045 セルフレビュー結果（C-1）

> レビュー日: 2026-08-12
> 対象ブランチ: `docs/1045-plan` / head `195db5c` / base `origin/main` = `6089e23`
> 判定: **WARN** — critical=0, major=2, minor=3
> **レビュアーは plan の作成者ではない**（maker から独立した checker）。maker の申告は
> すべて一次ソース（実ファイル・実行結果）で再検証し、確認できなかった項目は「確認不能」と明記する。

## チェック項目の正本と項目数

正本 = [`docs/working/templates/review-self.md`](../templates/review-self.md)。
本レビュアーが**自分で数えた項目数は 25**（テンプレートのサマリ表の `{25}` とも一致）。

| 群 | check_id | 件数 |
|---|---|---:|
| Plan | `C1-PLAN-01`〜`07` | 7 |
| Plan（AEE / #544 Phase1） | `C1-PLAN-08-AEE`, `C1-PLAN-09-AEE` | 2 |
| Plan 品質追加（Superpowers / #581） | `C1-SUP-PLAN-01`, `02` | 2 |
| ToDo | `C1-TODO-08`〜`12`, `C1-TODO-RB` | 6 |
| Test | `C1-TEST-13`〜`15` | 3 |
| B-1/B-2 | `C1-B1B2-16`, `17` | 2 |
| 追加（#578 / #579） | `C1-SEC-01`, `C1-SCOPE-DISC-01`, `C1-UI-01` | 3 |
| **合計** | | **25** |

> `.claude/rules/working-context.md` / `mode-classification.md` は C-1 を「17 項目」と表記するが、
> これは #544 / #581 / #578 / #579 の追加前の記述。**実運用の正本はテンプレート（25 項目）**であり、
> 直近 TASK（1023 / 1036 / 1044）の `review-self.md` も 25 項目系で運用されている。本レビューは 25 項目で行う。

## サマリー

| result | 件数 |
|--------|------|
| **PASS** | **19** |
| **WARN** | **5** |
| **FAIL** | **0** |
| **N/A** | **1**（`C1-UI-01` — non-UI タスク） |
| **合計** | **25** |

---

## 独立検証で実際に実行したコマンド（一次証跡）

| # | コマンド | 結果 | 用途 |
|---|---|---|---|
| V-1 | `sh tests/extras/ta-25-approval-token-guard.sh` | **47 passed / 0 failed / exit 0** | plan A-2 の baseline 申告（47 passed）を **base `6089e23` で実測再現** |
| V-2 | `sed -n '44,56p' scripts/check-approval-token-write.sh` | `48` 行に `printf '%s' "$_wc" \| grep -q '>' && return 0` | 欠陥箇所の実在確認 |
| V-3 | `sed -n '218,228p' tests/extras/ta-25-approval-token-guard.sh` | `222` 行 = `if [ "$PG_T25_FOCUSED" = "0" ]; then` | GC-4(b) の境界行番号の実在確認 |
| V-4 | `sed -n '629,660p' tests/extras/…` | `_t25_mutate` 定義・アンカー一意検査・kill 判定を確認 | GC-4(a) / kill 判定規約の確認 |
| V-5 | `grep -n '_t25_mutate ' tests/extras/…` | 既存 7 呼び出し（`TC-15`〜`TC-17e`） | ラベル生成規則の確認（**W-4 の根拠**） |
| V-6 | `grep -rc 'writes token path' tests/` | **ヒット 0 件**（exit 1） | U-3 の maker 申告を独立再現 |
| V-7 | `grep -rln "grep -q '>'" scripts/ bin/` | **`scripts/check-approval-token-write.sh` の 1 件のみ** | U-6 の maker 申告を独立再現 |
| V-8 | `grep -n 'check-approval-token-write' .claude/settings.example.json` | `72` / `81` 行でスクリプトパスを直接呼ぶ配線 | U-5（再適用不要）の根拠確認 |
| V-9 | `sed -n '168,188p' scripts/ai-loop/plan_package.py` | `extract_allowed_paths()` は `Files / Components to Touch` 節のみ抽出 | plan の「禁止パスを同節外に置く」注記の妥当性確認 |
| V-10 | `grep -n 'Stop Condition\|Replan\|停止条件\|再計画' plan.md todo.md` | **ヒット 0 件**（exit 1） | **W-1 / W-2 の根拠** |
| V-11 | `git diff --stat 6089e23..195db5c` | 3 ファイル / +892。`scripts` / `tests` / `bin` / `.github` / `.claude` の変更 **0** | 禁止パス非接触の確認 |
| V-12 | `shasum -a 256 docs/working/TASK-1045/plan.md` | `fe541d0f…` | 判定対象 plan の同定 |

---

## Plan チェック（7項目 + AEE 2項目）

### C1-PLAN-01: 受入基準網羅性

- **result**: PASS
- **category**: plan
- **finding**: AC-01〜13 の全 13 件が Work Breakdown の Step に写像される（AC-01〜07 → Step 2/3/6、AC-08/09 → Step 5、AC-10 → Step 4、AC-11/13 → Step 8、AC-12 → Step 7）。**未写像の AC は 0 件**（レビュアーが 13 件を個別に追跡）。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-02: Unknowns処理

- **result**: PASS
- **category**: plan
- **finding**: pbi-input の U-1〜U-6 が §未決事項の確定 で全件クローズ。うち U-3 / U-5 / U-6 は**実測根拠付き**で、レビュアーが V-6 / V-8 / V-7 により独立再現できた。未確定を残さず、判断が割れうる 2 点のみ Q-1 / Q-2 として C-3 へ明示的にエスカレーションしている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御

- **result**: PASS
- **category**: plan
- **finding**: Non-goals + GC-7（変更対象の限定）+ 独立節「Files NOT to Touch」の三重でスコープを固定。U-6 で他スクリプトに同種欠陥を検出した場合も **scope に入れず follow-up issue** と明記（スコープクリープの予防）。`plan_package.py` の抽出仕様（V-9）に合わせて禁止パス節を `Files / Components to Touch` の**外**に置いた判断は正しい。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-04: テスト戦略

- **result**: PASS
- **category**: plan
- **finding**: Unit（`PreToolUse` payload の exit code）/ Integration（standalone + `run-tests.sh` source の 2 経路）/ Mutation（2 方向）/ E2E（scope 外の理由付き）が具体。**退行判定を「0 failed かつ pass 数 ≥ baseline」とし、`ta-25` の TC 総数（47）を契約値にしていない**（Testing Strategy §Integration・Exit Criteria）。運用で TC が増減する共有スイートに絶対件数を書かない扱いとして適切。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-05: Work Breakdown Output

- **result**: **WARN**（W-3 / major）
- **category**: plan
- **finding**: 各 Step に Output / Owner / Risk / 🚩 / `rollback:` は揃っている。ただし **新規 TC の focused 群配置について plan.md / test-cases.md / todo.md の 3 文書が食い違う**（詳細は下記 W-3）。これは本 PBI が #874 同型の失敗を防ぐために最重要視している制約そのものであり、exec 実装者が参照文書によって別の配置を選びうる。
- **evidence_ref**: —
- **impacted_files**: [`docs/working/TASK-1045/plan.md`, `docs/working/TASK-1045/test-cases.md`]
- **suggested_action**: focused 群に入れる TC 集合を 1 箇所（test-cases の配置制約表）に正本化し、plan Step 2 / Files 表はそれを参照する形へ揃える
- **owner**: agent（C-3 前の 1 回確定反映で）
- **resolved**: false

### C1-PLAN-06: 依存関係

- **result**: PASS
- **category**: plan
- **finding**: Step 1→8 が線形で矛盾なし。todo 側も A-1〜A-14 に `depends_on` があり、`H-1`（C-3）を A-2 以降の必須先行に置いている。A-1 のみ「読み取り専用ゆえ C-3 前でも可」と明示。
  - **info（指摘ではない）**: A-7（境界 TC 群 `TC-11`〜`15`/`19`）は A-6（GREEN）**の後**に追加される。これらは修正前でも rc=2 が期待値の TC のため TDD 上の実害はないが、RED-first ではない点は認識しておくとよい。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-07: 動作検証自動化

- **result**: PASS
- **category**: plan
- **finding**: `Verification Automation: sh -n scripts/check-approval-token-write.sh && sh tests/extras/ta-25-approval-token-guard.sh && sh tests/run-tests.sh` が単一行で機械実行可能な形で記載（plan `376` 行）。レビュアーは第 2 項を V-1 として実行し 0 failed を確認済み。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-08-AEE: Stop Condition 記入

- **result**: **WARN**（W-1 / minor）
- **category**: plan
- **finding**: **plan.md / todo.md のいずれにも `Stop Condition` に相当する節が存在しない**（V-10: `Stop Condition|Replan|停止条件|再計画` の grep がヒット 0 件）。Step 1 の🚩に「baseline が 0 failed でなければ exec を止めて人間へ」、A-4 に「配置を修正するまで先へ進まない」など**実質的な停止点は散在している**が、明示的な Stop Condition 節として集約されていない。テンプレート規定どおり未記入は WARN（強制は Phase2 / #543）。
- **evidence_ref**: —
- **impacted_files**: [`docs/working/TASK-1045/plan.md`]
- **suggested_action**: 散在する停止点（baseline 非 0 failed / focused 群空振り / 変異の空振り / GC-1 抵触）を `## Stop Condition` として 1 節に集約
- **owner**: agent
- **resolved**: false

### C1-PLAN-09-AEE: Replan Triggers 機械値

- **result**: **WARN**（W-2 / minor、ただし内容的には major 寄り）
- **category**: plan
- **finding**: **`Replan Triggers` 節が存在せず、機械値も 0 件**（V-10）。とりわけ本 PBI で**最も不確実性が高いのは GNU 環境での正規化挙動**である。plan `146-153` 行の feasibility 検証は **maker 自身が「macOS / BSD `sed` + POSIX BRE のみ」と明記しており、GNU sed / Linux CI での実測は未実施**。CI は ubuntu で走るため、この差異は「exec 中に初めて判明し、正規化の設計方針ごと作り直しになる」クラスのリスクである。
  R-5 として Risks 表には登録され、GC-6（GNU 拡張禁止）と Step 8（CI 実行結果を evidence に残す）で緩和されてはいる。しかし **「CI で挙動が割れたらどうするか」＝ replan の発火条件と機械値が無い**ため、割れた場合の扱いが exec 実行者の裁量になる。
- **evidence_ref**: —
- **impacted_files**: [`docs/working/TASK-1045/plan.md`]
- **suggested_action**: 最低限、次の機械値を Replan Triggers に登録する:
  (1) `CI（ubuntu / GNU sed・grep）で ta-25 の failed > 0` → 正規化方式の再設計として replan
  (2) `T1045-TC-01〜06 のいずれかが focused 子プロセスの出力に現れない` → 配置を replan（GC-4(b)）
  (3) `変異 (a)/(b) のいずれかで [FAIL] <kill 対象> が出ない` → 検出力設計の replan
  (4) `_t25_mutate のアンカー grep -c != 1` → アンカー設計の replan
  併せて **GNU sed での正規化プロトタイプ再実行を Step 1 または Step 3 の🚩へ前倒し**すれば、CI まで待たずに割れを検出できる（推奨）
- **owner**: agent
- **resolved**: false

---

## Plan 品質追加チェック（Superpowers 由来 / #581）

### C1-SUP-PLAN-01: No Placeholders Rule

- **result**: PASS
- **category**: plan
- **finding**: `TBD` / `TODO` / `後で実装` / `いい感じに` の実ヒットは 0 件（唯一の grep ヒット `plan.md:391` は「不**適切に**緩む」の部分一致で偽陽性）。除外仕様は「`>&` の直後が数字列 or `-` のときのみ」「`/dev/null` の直後が語境界」「直前が `&` なら除去しない」と**判定条件レベルまで具体化**されており、sed 式そのものは無いが exec が一意に実装できる粒度。ファイルパス・行番号・コマンド・期待 rc がすべて具体値で書かれている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SUP-PLAN-02: Task Sizing Rules

- **result**: PASS
- **category**: plan
- **finding**: 各 Step / Task が独立して検証可能（Step 単位で 🚩 に**機械判定可能な合否条件**がある: `grep -c` == 1 / `[FAIL] <label>` の出力 / rc=2 / 0 failed）。reviewer が Task 単位で approve/reject できる。変更対象ファイル・検証コマンド・期待結果・依存関係も具体。
- **evidence_ref**: —
- **impacted_files**: []

---

## ToDo チェック（6項目）

### C1-TODO-08: タスク粒度

- **result**: **WARN**（W-5 / minor）
- **category**: todo
- **finding**: テンプレート基準「2〜5 分で完了できる粒度」に対し、**A-5（`_strip_nonwrite_redirects()` の新規実装。fd 複製除去 + `/dev/null` 破棄除去を POSIX BRE のみで書く）と A-6（`48` 行の置換 + 一意アンカー 2 種の付与）は明らかに超過**する。分割余地はある（例: A-5 を「fd 複製除去」「`/dev/null` 破棄除去」の 2 タスクに割る）。
  ただし各タスクに機械判定可能な🚩があるため**進捗の可視性は担保**されており、実害は小さい。基準への literal 不適合として WARN に留める。
- **evidence_ref**: —
- **impacted_files**: [`docs/working/TASK-1045/todo.md`]
- **suggested_action**: A-5 を除去規則ごとに 2 分割（任意）
- **owner**: agent
- **resolved**: false

### C1-TODO-09: depends_on設定

- **result**: PASS
- **category**: todo
- **finding**: A-1〜A-14 の全タスクに `depends_on` が記載。A-2 は `A-1, H-1`、A-11/A-12 は `A-10`、A-13 は `A-11, A-12` と分岐・合流も表現されている。冒頭の依存関係ブロックで Agent ↔ Human の順序も図示。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-10: チェックポイント設定

- **result**: PASS
- **category**: todo
- **finding**: 全 14 Agent タスク + 2 Human タスクに 🚩 が設定され、いずれも観測可能な条件（rc 値 / 出力ラベルの存在 / `grep -c` == 1 / 0 failed）で書かれている。A-4 は「1 件でも現れなければ配置を修正するまで先へ進まない」と**停止を明示**。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-11: Iron Law遵守

- **result**: PASS
- **category**: todo
- **finding**: 「**A-2 以降は `approvals/c3.json`（`c3_status=APPROVED`）の発行後にのみ開始する**」「承認 artifact は Human-owned。AI は作成しない」を冒頭で明記（`15-16` 行）。C-3 前に許すのは A-1（読み取り・ファイル変更なし）のみ。`PLANGATE_SKIP_TOKEN_GUARD=1` も Human-owned として人間へ依頼する扱い（R-9）。承認前コード実行・スコープ逸脱の経路は無い。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-12: 完了条件

- **result**: PASS
- **category**: todo
- **finding**: 各タスクの🚩に加え、末尾に 7 項目の「完了条件」チェックリストがある。うち「pass 数 ≥ baseline（**絶対件数を契約値にしない**）」「変更が 3 パスに閉じている」は機械検証可能。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-RB: rollback（戻し手順）

- **result**: PASS
- **category**: todo
- **finding**: Mode = `critical` のため必須。**全実装タスク（A-2/A-3/A-4/A-5/A-6/A-7/A-8/A-9/A-10/A-14）に `rollback:` が具体コマンドで記載**され、読み取り専用タスク（A-1/A-11/A-12/A-13）は `rollback: 不要` と明記。plan Step 3 の rollback には「guard は他ファイルに依存を持たない単体スクリプトのため単独 revert で完全復元可能」と復元可能性の根拠も付いている。欠落 0 件。
- **evidence_ref**: —
- **impacted_files**: []

---

## テストケースチェック（3項目）

### C1-TEST-13: 受入基準→テストケース網羅性

- **result**: PASS
- **category**: test
- **finding**: **レビュアーが maker の申告を鵜呑みにせず自分で数えた結果、13 AC / 20 TC / 双方向 orphan 0 を確認**（下記「AC↔TC 自数え結果」）。maker 申告と一致。
  - **info**: TC-11〜15 / TC-19 は AC-04 / AC-06 に紐づけられているが、AC の literal 文（`echo x > <TOKEN>` → exit 2 等）を**超える境界仕様**（`/dev/nullX` / `&>` / `>&<file>` / 擬似デバイス / リテラル中の `>`）を固定している。これは「AC に無い要求を TC が持つ」形だが、いずれも **GC-1（弱体化禁止）の具体化**であり scope 内。指摘ではなく記録として残す。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-14: テストケースの具体性

- **result**: **WARN**（W-4 / major）
- **category**: test
- **finding**: 入力・期待 rc は値レベルで具体（rc=0 / rc=2）で、kill 判定規約も「実 TC の `[FAIL]` 出力 + 子プロセス rc 非 0。インライン assert の FAIL は kill と認めない」と `ta-25` の既存契約に正しく合わせてある。
  ただし **`T1045-TC-09` / `T1045-TC-10` というラベルは `_t25_mutate` 機構では生成できない**（下記 W-4）。ラベルが実装と一致しないままだと、変異結果を出力から追跡する手順（plan Step 5 / A-9 / A-10 の🚩「実出力を evidence に残す」）が機能しない。
- **evidence_ref**: —
- **impacted_files**: [`docs/working/TASK-1045/test-cases.md`, `docs/working/TASK-1045/plan.md`]
- **suggested_action**: 下記 W-4 の 2 案のいずれかを plan に確定させる
- **owner**: agent
- **resolved**: false

### C1-TEST-15: エッジケースの考慮

- **result**: PASS
- **category**: test
- **finding**: 境界・異常系が濃い。`/dev/nullX`（語境界不成立）/ `/dev/null/../<TOKEN>`（パス細工）/ `&>` `&>>` `&>/dev/null` / `>&<file>` / `/dev/stdout` `/dev/stderr` `/dev/fd/3` / 文字列リテラル中の `>` / `3>&-`（fd クローズ）を個別 TC 化。さらに **Edge Cases 節で「明示的に block 維持＝誤検知として扱わない」ケース（heredoc / 変数展開）を宣言的に固定**しており、GC-2（完全構文解析をしない）の帰結が文書化されている。
- **evidence_ref**: —
- **impacted_files**: []

---

## B-1/B-2チェック（2項目）

### C1-B1B2-16: B-1確認質問

- **result**: PASS
- **category**: plan
- **finding**: pbi-input の曖昧点（U-1〜U-6 / N-2 の Mode 未確定）を plan 側で全件クローズし、**判断が割れうる 2 点だけを Q-1 / Q-2 として C-3 の人間判断へ残した**。曖昧さを黙って埋めず、埋めた根拠（実測 or 安全側）を明示している点が適切。
- **evidence_ref**: —
- **impacted_files**: []

### C1-B1B2-17: B-2アプローチ比較

- **result**: PASS
- **category**: plan
- **finding**: 独立した「案 A / 案 B」表は無いが、**3 つの候補方向が棄却理由付きで比較されている**:
  (1) 完全なシェル構文解析 → GC-2 で棄却（「コストに見合わず、パーサ自体が新たな bypass 面になる」）
  (2) `>` を token path 宛のときだけ block → GC-3 で**❌ 禁止方針として明示棄却**（`T1023-TC-09` が退行 FAIL する。レビュアーが V-1 の出力で当該 TC の実在と PASS を確認）
  (3) 採用案: 非書き込みリダイレクト記法を除去してから残存 `>` を見る 2 段構成
  加えて U-1（擬似デバイスを除外に含めるか）/ U-2（`&>` の扱い）も採用・不採用の理由付きで確定済み。選定理由の明記という要件は満たす。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SEC-01: 秘密情報 非接触（#578）

- **result**: PASS
- **category**: plan
- **finding**: `.env` / APIキー / 個人パスに触れない。承認トークンは**テスト専用フィクスチャ変数 `T25_TOKEN` / `T25_MAINT`（`ta-25` の `72-73` 行、架空 path）**を用い、実 `approvals/` には触れないと test-cases 冒頭で明記。**AI は承認 artifact を作成しない**（責務分界表 / pbi-input A-6 / todo `16` 行）。`PLANGATE_SKIP_TOKEN_GUARD=1` の使用も Human-owned として人間へ依頼する扱い。V-11 で `.claude/` の変更 0 も実測確認済み。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離（#578）

- **result**: PASS
- **category**: plan
- **finding**: U-6（他スクリプトの同種欠陥）について「**万一検出された場合も本 PBI の scope には入れず follow-up issue として起票**」と明記（plan `184` 行 / Step 1 の 3 / A-1 の 3）。U-2 の残存誤検知も「handoff の既知課題に明記し、実害が出たら follow-up issue」（R-11 / A-14）と分離済み。その場で直す設計になっていない。
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠（#579）

- **result**: **N/A**
- **category**: plan
- **finding**: `is_ui_task = false`。変更対象は POSIX sh の hook guard スクリプトとテストスイートのみで、UI 要素を含まない。
- **evidence_ref**: —
- **impacted_files**: []

---

## AC↔TC 自数え結果（maker 申告の独立再検証）

**maker 申告「AC 13 / TC 20 / 双方向 orphan 0」は正しい。** レビュアーが test-cases.md 本文から
TC を直接列挙して数え直した結果:

| 節 | TC | 小計 |
|---|---|---:|
| 誤検知の解消 | TC-01, 02, 03, 20 | 4 |
| 退行防止（focused） | TC-04, 05, 06 | 3 |
| 退行防止（境界・細工） | TC-11, 12, 13, 14, 15, 19 | 6 |
| 併記回避 | TC-07 | 1 |
| ルール識別子 | TC-08 | 1 |
| 変異注入 | TC-09, 10 | 2 |
| 既存スイート・静的検査 | TC-16, 17, 18 | 3 |
| **合計** | | **20** |

- **本文実在 TC = 20**、Traceability 表の件数合計 = 1+1+2+6+1+2+1+1+1+1+1+1+1 = **20**。一致。
- Traceability 表に **AC-01〜13 の 13 行すべてが存在**し、件数 0 の行は無い → **AC→TC orphan = 0**。
- 本文の 20 TC がすべて Traceability 表のいずれかの行に出現する（レビュアーが 1 件ずつ照合）→ **TC→AC orphan = 0**。
- 欠番の確認: TC-01〜TC-20 の連番に**欠番なし**（01〜20 が全出現）。

---

## 重点確認事項への回答

### ① Mode = `critical` は妥当か（Q-1 の扱いを含む）

**結論: 判定・エスカレーションともに妥当。PASS。**

- **ルール適用は literal に正しい**。`mode-classification.md` の判定ロジックは「定量各軸の最大値」「定性各軸の最大値」「両者の高い方」。受入基準 13 件は定量表の「11+ → 超高」に該当し、これが支配して `critical` になる。レビュアーが同ルールを独立に適用しても同じ結果になる。
- **maker が「規模実態（コード 2 ファイル）との乖離」を自己申告し、Q-1 として C-3 へ投げた扱いは適切**。理由は 3 つ:
  1. **安全側に倒れている**。誤って `high-risk` に下げるのではなく、上げたうえで人間に下げる裁量を渡している。`mode-classification.md`「自動推定の安全側」と一貫。
  2. **引き下げても緩まない条件を先に固定している**。「引き下げても `lite_eligible=false` / 同期 C-3 / V-2・V-3 は維持」と明記（plan `477-481` 行 / todo H-1）。**承認境界そのものが緩む経路が無い**。
  3. HO 9 カテゴリ非該当（`scripts/` 直下であり `scripts/hooks/` ではない）を**機械判定として根拠付きで示したうえで**、それでも引き上げる根拠（保護対象が承認境界 / セキュリティ関連 → 最低「中」/ 誤ると review-principles の critical に至る）を別立てで書いている。HO 該当性を曖昧にしたまま Mode を盛っていない。
- **唯一の実コスト**は `critical` が V-4（リリース前チェック）を要求すること。これは Q-1 で人間が判断すればよい範囲であり、C-1 として FAIL/WARN を出す理由にはならない。
- なお pbi-input N-2 は「最終判定は plan.md で行う」としており、plan はそれに応答している（宿題の残し漏れではない）。

### ② 退行防止は effective か（GC-3 / `T1023-TC-09`）

**結論: 正しく拘束されている。PASS。**

- レビュアーが `T1023-TC-09` のフィクスチャを実ファイルで確認: `tests/extras/ta-25-approval-token-guard.sh:83` の `p_bash_mixed` = `cat docs/working/TASK-0001/approvals/c3.json && echo hi > /tmp/other.txt`。**`cp`/`mv`/`tee` を含まないため、`>` 検査が唯一の捕捉経路**であることを独立確認した（V-1 の出力でも当該 TC が PASS していることを確認）。
- plan は GC-3 で **「❌ `>` を token path 宛のときだけ block する」を明示的に禁止方針として列挙**し、✅ 採用方針を「任意のファイル宛リダイレクトは block 維持、fd 複製と `/dev/null` 破棄のみ除外」と書いている。さらに Approach Overview `143-144` 行で「`> /tmp/other.txt` は `/dev/null` でも fd 複製でもないため `>` が残り block が維持される」と**当該 TC を名指しで通ることを説明**している。
- 二重の機械担保もある: (a) AC-11 / `T1045-TC-16` が既存 TC 全 PASS を要求、(b) Step 3 の🚩に `T1023-TC-09` の PASS 維持が明記、(c) todo A-6 の🚩にも同項目。**拘束は十分。**

### ③ focused 群の配置制約は実装可能な粒度か（#874 再発防止）

**結論: 機構理解は正確だが、TC 集合の指定が 3 文書で矛盾。→ W-3（major）。**

機構の理解自体は**実ファイルと完全に一致**しており、この点は高く評価できる:

- `222` 行 `if [ "$PG_T25_FOCUSED" = "0" ]; then` が境界であること（V-3 で実測一致）
- `47` 行 `PG_T25_FOCUSED="${PG_T25_MUTATION_CHILD:-0}"` により mutation 子プロセスで focused になること（V-3 で確認）
- アンカー一意チェックが `_t25_before != "1"` で `[FAIL] … mutation anchor not unique` を出すこと（V-4 で確認）
- kill 判定が `grep -q "\[FAIL\] $_t25_kill" && [ "$_t25_mrc" != "0" ]` の**両方**であること（`ta-25` の `655-657` 行。V-4 で確認）
- A-4 に「`PG_T25_MUTATION_CHILD=1` で子プロセス実行し新 TC のラベルが出力に現れることを目視確認、現れなければ先へ進まない」という**空振り検出の専用タスク**を立てていること

矛盾の実体（**W-3**）は以下:

| 文書 | 箇所 | focused 群に入れると書かれている TC |
|---|---|---|
| plan.md | Step 2 Output（`214-215` 行） | `T1045-TC-01`〜**`TC-07`**（TC-20 の言及なし） |
| plan.md | Files / Components to Touch（`315` 行） | `T1045-TC-01`〜**`TC-08`** |
| test-cases.md | 配置制約表（`33-34` 行） | `TC-01`〜**`TC-06`**（`TC-07`〜`TC-20` は通常群） |
| test-cases.md | 節見出し（`40-47` 行） | 「誤検知の解消（**focused 群**）」の中に **`TC-20` が含まれる** |
| todo.md | A-2 / A-3 | `TC-01`〜`TC-06` + **`TC-20`** |

→ **`TC-07` / `TC-08` / `TC-20` の 3 件について、どこに置くかが文書ごとに違う**。test-cases.md は**自文書内でも矛盾**している（配置制約表は TC-20 を通常群に入れるが、節見出しは focused 群に置いている）。
実害: exec 実装者が plan Step 2 に従うと `TC-07`（併記回避・4 形を回す重い TC）と `TC-08`（stderr メッセージ検査）まで focused 群に入り、**既存 7 変異すべての子プロセスで毎回実行される**。逆に test-cases 配置制約表に従うと `TC-20`（`3>&-`）が通常群に落ち、変異 (a) 下で検証されない。
plan Step 2 の🚩「`T1045-TC-04`〜`07` が PASS」という記述も、`TC-07` が通常群なら RED 段階の focused 実行では観測されない。

### ④ BSD sed のみでの検証（GNU / Linux CI 未実測）

**結論: Risk としては登録済みだが Replan Trigger が無い。→ W-2 に計上（上記 `C1-PLAN-09-AEE`）。**

- plan `146-153` 行は feasibility を **「macOS / BSD `sed` + POSIX BRE のみ」26/26 と自ら限定明記**しており、過大申告はしていない（誠実）。「実装は exec で改めて TDD、本結果は方向の妥当性の裏付けであり実装確定ではない」とも書いている。
- 緩和は R-5（POSIX 範囲厳守 / CI 実行結果を evidence に残す）+ GC-6（GNU 拡張禁止を列挙: `sed` の `\|` `\+` `\b`、`grep -P`）+ Step 8-4 + todo A-13-4 + Exit Criteria「ローカル（BSD）と CI（GNU）双方の実行結果が evidence に残っている」の**5 箇所**に分散配置されており、**「CI で確認する」こと自体は確実に計画されている**。
- 不足は **「割れたときにどうするか」**。Replan Trigger が無いため、CI で failed が出た場合に exec が「その場で正規表現を調整して押し通す」か「設計に戻る」かが未定義。W-2 の suggested_action に機械値案を記載した。
- **推奨**: CI 到達まで待たず、Step 1 または Step 3 の🚩に「GNU sed 相当（Linux コンテナ or `gsed`）でプロトタイプ 26 ケースを再実行」を入れると、RED/GREEN の段階で割れを検出できる。

### ⑤ U-2（`&>` を除外しない）の handoff 必須記載

**結論: 記載義務は複数箇所で拘束されている。PASS。**

- plan U-2: 「**残存誤検知（`&>/dev/null` 付き読み取り）は既知の制約として handoff に明記**し、必要なら follow-up issue」
- plan R-11: 「U-2 の意図的な判断。**既知の制約として handoff に明記**し、実害が出たら follow-up issue」
- test-cases Edge Cases 表: 「`&>/dev/null` 付きの読み取り → **block 維持 = 残存誤検知**（U-2 の意図的判断）／**handoff の既知課題に明記**」
- todo A-14: 内容に「以下を**既知課題として必ず明記**」として第 1 項に列挙
- さらに **Q-2 として C-3 の人間判断へ明示エスカレーション**（plan `406` 行 / todo H-1）。「安全側だが運用頻度によっては後で覆る」という maker の認識も Q-2 の「人間へ問う理由」に書かれている。
- 機械固定も済んでいる（`T1045-TC-14` の 3 形目 `&> /dev/null` → rc=2）。**判断・記録・テストの 3 点が揃っている。**

### ⑥ 絶対件数を契約値にしていないか

**結論: していない。PASS。**

- Testing Strategy §Integration: 「退行判定の契約は **「0 failed」かつ「pass 数が baseline 以上」**。**`ta-25` の TC 総数（起票時 47）は増減するため絶対件数を契約値にしない**」
- Exit Criteria: 「**起票時実測 47 passed / 0 failed は測定環境・base SHA `6089e23` とセットの参考値であり契約ではない**」— **測定環境と base SHA をセットで記録**しており、`feedback_no_absolute_counts_on_growing_dirs` の要求（下限か同値照合 / baseline は測定環境とセット）を満たす。
- plan Step 1 / Step 8 / todo A-13 / 完了条件 のすべてで「pass 数 ≥ baseline」表記に統一されている。
- レビュアーの V-1 実測でも **47 passed / 0 failed** を base `6089e23` で再現でき、baseline の申告値は正しい。

---

## WARN 一覧（severity 付き）

| ID | check_id | severity | 内容 | owner |
|---|---|---|---|---|
| **W-1** | `C1-PLAN-08-AEE` | minor | `Stop Condition` 節が無い（実質的な停止点は散在するが未集約） | agent |
| **W-2** | `C1-PLAN-09-AEE` | minor（内容は major 寄り） | `Replan Triggers` 節・機械値が 0 件。特に **GNU sed / Linux CI で割れた場合の発火条件が未定義**（プロトタイプは BSD sed のみで検証） | agent |
| **W-3** | `C1-PLAN-05` | **major** | **focused 群に入れる TC 集合が plan / test-cases / todo で不一致**（`TC-07` / `TC-08` / `TC-20`）。test-cases は自文書内でも矛盾。#874 再発防止の中核制約そのものが多義的 | agent |
| **W-4** | `C1-TEST-14` | **major** | **`T1045-TC-09` / `T1045-TC-10` は `_t25_mutate` では生成できないラベル**。同機構は `t25_fail "T1023-$_t25_mid …"` と **`T1023-` prefix をハードコード**（`ta-25` の `640` / `644` / `648` / `656` / `658` 行 — 実測）。`mid="TC-09"` を渡すと出力は `T1023-TC-09` となり、**既存の `T1023-TC-09`（mixed token-read + other-write）とラベルが衝突**する（V-1 の出力で当該既存 TC の実在を確認済み） | agent |
| **W-5** | `C1-TODO-08` | minor | A-5 / A-6 がテンプレート基準「2〜5 分」を超過 | agent |

### W-4 の是正案（どちらかを plan に確定させる）

| 案 | 内容 | 影響 |
|---|---|---|
| **案 A（推奨）** | `_t25_mutate` の失敗/成功メッセージを `T1023-` 固定から**引数で受けるラベル**へ変更し、新規変異を `T1045-TC-09` / `T1045-TC-10` として出力する | `ta-25` は本 PBI の変更許可ファイル。既存 7 呼び出しの出力ラベルを変えないよう既定値 `T1023-` を維持する後方互換な変更にできる |
| **案 B** | 機構は触らず、`mid` に `TC-1045-09` 等の衝突しない値を渡し、**plan / test-cases の TC 名を実際の出力ラベル（`T1023-TC-1045-09`）に合わせて書き換える** | 機構変更ゼロだがラベルが読みにくい |

いずれにせよ **plan / test-cases に書かれた TC 名と実出力ラベルを一致させる**ことが必須。
一致していないと、plan Step 5 / A-9 / A-10 の🚩「`[FAIL] T1045-TC-01` が実出力に現れることを evidence に残す」の
**変異側ラベル（`T1023-TC-09` として記録される）が追跡できなくなる**。
なお **kill 対象ラベル**（`T1045-TC-01` / `T1045-TC-04`）は `_t25_kill` 引数として `grep -q "\[FAIL\] $_t25_kill"` に
そのまま使われるため、**kill 判定そのものは W-4 の影響を受けない**（focused 群の新 TC 名が `T1045-TC-01` である限り正しく機能する）。

---

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| — | **なし**（本レビュアーは独立 checker のため plan / todo / test-cases を編集しない。指摘は本ファイルにのみ記載） | — |

---

## 確認不能だった項目

| 項目 | 理由 |
|---|---|
| **CI（ubuntu / GNU sed・grep）での `ta-25` 実行結果** | 本レビューは macOS（darwin 25.6.0）ローカル worktree で実施。GNU 環境が無く、GNU sed でのプロトタイプ再実行も未実施。**W-2 の根拠であると同時に、レビュアー自身もこの軸を検証できていない**ことを明記する |
| **`_strip_nonwrite_redirects()` の実装可否（実コード）** | 本 PBI は plan 段階であり実装は未着手。plan `146-153` 行の feasibility 26/26 は **maker のスクラッチパッド上の主張であり、レビュアーは再実行していない**（`scripts/` を変更しない規律のため）。exec の RED/GREEN で改めて実測されること |
| **新規 TC が実際に focused 子プロセスで実行されるか** | TC が未実装のため事前検証不可。todo A-4 が実行時に検証する設計であることを確認するに留めた |
| **`bin/plangate doctor --check-settings` の PASS 状態** | 本レビュアーの worktree からの実行は settings 実体の状態に依存するため未実行。todo A-14 の🚩で handoff 時に確認される設計であることを確認するに留めた |

---

## 判定

**verdict: WARN**（critical=0 / major=2 / minor=3 / FAIL=0）

### C-3 に出せる状態か

**出せる。ただし `CONDITIONAL` を推奨する。**

- **FAIL は 0 件**。plan の骨格（GC-1〜GC-7 の制約階層 / AC↔TC の双方向 orphan 0 / 2 方向の変異による検出力実証 / rollback 全実装タスク / 絶対件数を契約にしない退行判定 / 承認境界の責務分界）は**C-3 に耐える水準**にある。特に **GC-3（`T1023-TC-09` の退行拘束）と GC-4（focused 群 / #874 同型の空振り防止）は、機構を実ファイルで正しく理解したうえで書かれている**ことをレビュアーが独立確認した。
- 一方 **W-3 / W-4 は「exec 実装者が plan どおりに実装すると詰まる or 曖昧に分岐する」種類の欠陥**であり、放置すると本 PBI が最も避けたい #874 同型の空振りと、変異結果の追跡不能を招く。
- **重要な運用制約**: `feedback_no_plan_edit_after_c3_approval` のとおり、**C-3 承認後の plan 編集は微修正でも `plan_hash` を無効化する**。したがって W-1〜W-5 の反映は **`c3.json` 発行より前**に行わなければならない。

### 推奨する進め方

1. C-2（外部レビュー）を実施し、指摘を `review-external.md` に `R-NNN` として集約する（本 C-1 の W-1〜W-5 も同表に取り込む）
2. **1 回だけ確定反映**（コミットに `Refs: R-NNN`）— 反映対象は W-3（focused 群 TC 集合の正本化）/ W-4（変異ラベルの実装可能化）を必須、W-1 / W-2 / W-5 を推奨
3. 簡易 C-1 再実行（本ファイルに `C1-VERDICT-2` を追記）
4. **人間が `c3.json`（`c3_status=APPROVED` / 確定後 plan の `plan_hash`）を発行** — Human-owned。AI は作成しない
5. exec 開始

### Human C-3 の判断事項一覧

| # | 論点 | plan / C-1 の既定 | 人間に求める判断 |
|---|---|---|---|
| **H-Q1** | **Mode を `critical` のままとするか `high-risk` へ引き下げるか**（plan Q-1） | `critical` | 引き下げる場合も **`lite_eligible=false` / 同期 C-3 / V-2・V-3 の維持**が plan で担保されている。実質差分は **V-4（リリース前チェック）の要否**。C-1 としては「引き上げ判断・エスカレーションともに妥当」と評価する |
| **H-Q2** | **`&>` / `&>>` を block 維持でよいか**（plan Q-2） | block 維持 | `&>/dev/null` 付き読み取りは**残存誤検知として残る**。handoff 既知課題への記載義務・`T1045-TC-14` での機械固定・follow-up issue 経路は整備済み。運用頻度をどう見るかは人間判断 |
| **H-Q3** | **W-3（focused 群 TC 集合の 3 文書不一致）の解消を C-3 の条件とするか** | C-1 は「必須」と評価 | 正本を test-cases の配置制約表に一本化し、`TC-07` / `TC-08` / `TC-20` の配置を確定。**exec 前の確定反映を推奨**（承認後は plan_hash が無効化するため） |
| **H-Q4** | **W-4（`_t25_mutate` のラベル衝突）を案 A（機構をラベル引数化）/ 案 B（TC 名を実出力に合わせる）のどちらで解消するか** | C-1 は案 A を推奨 | 案 A は `ta-25` への追加変更（許可ファイル内・後方互換可）。案 B は機構不変だがラベルが読みにくい |
| **H-Q5** | **W-2（GNU / Linux CI の replan trigger 欠落）に対し、GNU sed でのプロトタイプ再実行を exec の前倒し🚩として要求するか** | C-1 は前倒しを推奨 | 現状の計画では CI（Step 8）到達まで割れが判明しない。前倒しすれば Step 3 で検出できる |
| **H-Q6** | W-1 / W-5（Stop Condition 未集約 / タスク粒度超過）を反映対象に含めるか | C-1 は minor（任意） | いずれも実害は小さい |

---

C1-VERDICT: WARN plan=sha256:fe541d0f3585e6411da3f6d1d65042c5a29156a5f1fb75098e2abdd5b13981dc

> 参考ハッシュ（同時レビュー対象）:
> todo=sha256:5151289f6b9edd983b98cd3afd4bbbab4efcf440306073a5ef4243f1b4573cd1
> test-cases=sha256:7e3597a2e0c7184b1226f76ff8b056ac5fccb24a82a4f89583c4d3a80d0e1298
> base=`6089e23` / head=`195db5c`
