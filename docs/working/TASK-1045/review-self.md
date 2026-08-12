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

---

## 簡易 C-1 再実行（C-2 確定反映後 / 追記専用）

> 実施: plan maker（自己再確認）。**上記 C-1 本体（独立 checker）の記述は一切変更していない**（追記のみ）。
> 対象: W-1〜W-5（C-1）+ R-001〜R-008（C-2）の **1 回確定反映後**の plan / todo / test-cases。
> 位置づけ: [`working-context.md`](../../../.claude/rules/working-context.md) の順序規約
> 「(1) R-NNN 集約 → (2) 1 回確定反映 → **(3) 簡易 C-1** → (4) 人間が c3.json → (5) exec」の (3)。

## 反映の網羅性（機械確認）

| 指摘 | severity | 反映先 | 確認方法と結果 |
|---|---|---|---|
| **R-001** | major | `GC-4-C` 新設 / `SC-4` を 7 ラベル列挙化 / Step 2・Step 3 CP / `A-4` 判定方式 | `grep -o '^### GC-'` に **`GC-4-C` 存在**。`SC-4` 行に **`TC-15pre` / `TC-17post` の明示除外**あり |
| **R-002** | major | `GC-8` 新設 / Step 3 必須実装 3 件 / `T1045-TC-22` / `SC-9` / `R-12` | `GC-8` 存在。`SC-9` は plan・todo 双方に存在。`T1045-TC-22` 定義済 |
| **R-003** | minor | `RT-2` を (a) invoke・source / (b) settings 実配線 の 2 条件へ | `RT-2` 行に **(a)(b) の明記**と「実測では該当なし」 |
| **R-004** | minor | `Q-1` に「失うのは V-4 のみ / 承認境界は不変」 | `Q-1` 行に記載。**マトリクス 13 行を照合し `○ → -` は V-4 の 1 行のみ**と実測表現 |
| **R-005** | minor | `SC-6` に `T1045-TC-07 (1)` を追加 | `SC-6` 行に含有 |
| **R-006** | minor | plan §AC の適用範囲宣言（AC-03 = fd 複製 **+ fd クローズ**） | 新節あり。test-cases の Traceability AC-03 行も同期 |
| **R-007** | minor | `GC-6` に `LC_ALL=C` 固定 / Step 1b 実験条件 | `GC-6` に実測値（UTF-8 で rc=1 / `LC_ALL=C` で rc=0）付きで記載 |
| **R-008** | minor | `R-14` / `A-1` 調査項目 7 / `A-14` handoff 必須記載 | 3 箇所すべてに記載 |
| **i-1** | info | `A-1` 調査項目 6（稼働 settings の実測） | 記載あり |

**未反映（`status` が `reflected` / `acknowledged` 以外）の指摘 = 0 件**
（`review-external.md` の監査表 10 行を `grep -o` で集計: `reflected` 9 / `acknowledged` 1）。

## 機械チェック結果（本再実行で実行したコマンド）

| # | コマンド | 結果 |
|---|---|---|
| S-1 | `npx markdownlint-cli2 "docs/working/TASK-1045/*.md"` | **0 issues in 0 files**（6 ファイル） |
| S-2 | `extract_allowed_paths(plan.md)`（`scripts/ai-loop/plan_package.py`） | **7 パス**。禁止パスの混入なし |
| S-3 | `Verification Automation:` 行の正規表現抽出 | 抽出可（`derive_loopspec()` の fail-closed を回避） |
| S-4 | TC 定義の自数え | **22 件**（`TC-01`〜`TC-22`・欠番なし） |
| S-5 | Traceability の AC 行数 | **13 件**（AC-01〜13） |
| S-6 | `comm` による双方向 orphan 検査（定義集合 ↔ 追跡集合） | **両方向とも差分 0 件**（orphan 0 を機械確認） |
| S-7 | `SC-*` / `RT-*` の plan ↔ todo 突合 | **SC-1〜9 / RT-1〜5 が両文書で一致** |
| S-8 | 旧 TC 範囲表記の掃き残し検査 | plan / todo / test-cases とも **0 件** |

### 本再実行で新たに発見・修正した掃き残し（自己検出）

- **`plan.md` Step 3 のチェックポイントに `T1045-TC-01`〜`07` という旧表記が残存**していた
  （W-3 の反映時に見落とし。C-2 ではどちらのレーンも指摘していない）。
  **`GC-4-A` の 7 件表記へ修正済み**。S-8 で 0 件を再確認。

## 判定サマリ

| 項目 | 結果 |
|---|---|
| C-2 major 2 件（R-001 / R-002） | **反映済み**。いずれも**筆者が独立に実走再現**したうえで反映 |
| C-2 minor 6 件 | **反映済み** |
| 新規に持ち込まれた FAIL | **0 件** |
| 残 WARN | **1 件**（下記 W-6） |

### W-6 [minor] `GC-8` の実装可否は未実証のまま残る

`_wc_n=$(…) || _wc_n="$_wc"` と `command -v sed` 検査は**設計上 fail-closed になる**が、
**guard 本体へ統合した状態での実測は未実施**（実装前のため）。
→ **`UV-2` の範囲内**として扱い、**`T1045-TC-22` + `SC-9`** で exec 時に機械検出する経路を確保済み。
plan の記述としてはこれ以上詰められないため WARN 据え置き。

### C-3 へ引き継ぐ人間判断（前回 H-Q1〜H-Q6 の更新）

| # | 論点 | 状態 |
|---|---|---|
| H-Q1 | Mode `critical` / `high-risk` | **未決（人間判断）**。R-004 反映で「失うのは V-4 のみ」が明示された |
| H-Q2 | `&>` / `&>>` を block 維持か | **未決（人間判断）**。C-2 は「既定のままで良い」と判定 |
| H-Q3 | W-3（focused 群の不一致） | **解消済み**（`GC-4-A` で 7 件に一本化・4 箇所同期） |
| H-Q4 | W-4（ラベル衝突） | **解消済み**（案 A 相当 = `GC-4-B` (a) prefix 引数を採用） |
| H-Q5 | GNU sed の前倒し | **解消済み**（Step 1b / A-1b として実装前に前倒し + `RT-1` 接続） |
| H-Q6 | W-1 / W-5 | **解消済み**（`SC-1〜9` / `RT-1〜5` 新設・A-5/A-6 を 4 分割） |

---

C1-VERDICT-2: WARN plan=sha256:d859a66c2d446b7fce9c862e456db8b5d6aba1bf17fa29e8bc084a7c638e16f2

> 判定内訳: critical=0 / major=0 / minor(WARN)=1（W-6）/ FAIL=0
> **C-2 の major 2 件は反映により解消**。残 WARN は「実装前のため実証不能」に起因するもので、
> いずれも `UV-2` + `T1045-TC-22` + `SC-9` で exec 時に機械検出される。
> **plan は C-3 に諮れる状態**（最終判断は Human-owned）。
>
> 参考ハッシュ（同時対象）:
> todo=sha256:a4944afaf958ac691526d346d51394384ec93f42210ebda14c3dad8a2a9fdc0a
> test-cases=sha256:5167fb90ed56b0ab102086a076e89911a788614b958e723efe6e6fa848c4ac01
> review-external=sha256:9ea1826c187b0fc68d7e760611143613e4b6abc38b42cf39165ae5664931b8a2
> base=`6089e23` / C-1 head=`bd0fa82`
>
> **注意**（`feedback_no_plan_edit_after_c3_approval`）: `c3.json` は
> **上記 `plan_hash` に対して発行**すること。発行後に plan を 1 文字でも編集すると
> EH-3 が mismatch を検知する。

---

## 簡易 C-1 再実行 #2（C-2 Round 2 確定反映後 / 追記専用）

> 実施: plan maker（自己再確認）。**C-1 本体および簡易 C-1 #1 の記述は一切変更していない**（追記のみ）。
> 対象: **R-009〜R-012**（C-2 Round 2）の 1 回確定反映後の plan / todo / test-cases。

### 反映の網羅性（機械確認）

| 指摘 | severity | 反映先 | 確認方法と結果 |
|---|---|---|---|
| **R-009** | major | `GC-8` に「要件 ↔ 検出 TC の対応」表 + 組合せ行列 / `T1045-TC-22b` 新設 / `SC-9` を TC-22 **または** TC-22b へ拡張 / `R-12` 更新 / test-cases:181 の over-claim 解消 / 両 TC に reason 文字列 assert | TC 定義 **23 件**（`TC-22b` 追加）。`SC-9` は plan・todo 双方で「いずれかが FAIL」表現。Exit Criteria が要件別に分離 |
| **R-010** | minor | `GC-8` の 2 に**挿入位置を 1 文で固定** | plan に「`_parse_unknown()` 定義の後（`:81` 以降）・`# --- 1) target:`（`:83`）の直前」と明記。`rc=127` 非 block の失敗様式も記載。todo A-5a にも同記載 |
| **R-011** | minor | `plan.md` `SC-1` に第 2 発火条件 / `todo.md` `RT-2` を (a)(b) へ | `plan` の `SC-1` に「RED ウィンドウ…期待 FAIL 6 件**以外**が FAIL」を追記（**本表が正本**と明記）。`todo` の旧文言「同一判定コードを共有していると判明」は **`grep` で 0 件** |
| **R-012** | info | `A-14` handoff 必須記載へ「`sed` 不在環境での挙動変更」 | 記載あり |

**未反映（`status` が `reflected` / `acknowledged` 以外）の指摘 = 0 件**
（Round 2 監査表 5 行: `reflected` 4 / `acknowledged` 1）。

### 機械チェック結果（本再実行で実行したコマンド）

| # | コマンド | 結果 |
|---|---|---|
| S2-1 | `npx markdownlint-cli2 "docs/working/TASK-1045/*.md"` | **0 issues in 0 files**（7 ファイル。途中 5 件を修正後） |
| S2-2 | `extract_allowed_paths(plan.md)` | **7 パス**・禁止パス混入なし |
| S2-3 | `Verification Automation:` 行の抽出 | 抽出可 |
| S2-4 | TC 定義の自数え | **23 件**（`TC-01`〜`TC-22` + `TC-22b`） |
| S2-5 | Traceability の AC 行数 | **13 件**（AC-01〜13・不変） |
| S2-6 | `comm` による双方向 orphan 検査 | **両方向とも差分 0 件** |
| S2-7 | `diff` による `SC-*` / `RT-*` の plan ↔ todo 突合 | **SC 一致 / RT 一致**（SC-1〜9 / RT-1〜5） |
| S2-8 | `todo` の `RT-2` 旧文言検査 | **0 件**（R-011 解消） |

### 本再実行で新たに発見・修正した掃き残し（自己検出）

1. **`test-cases.md` に旧 4 列テーブルのヘッダが孤立して残存**（`TC-22` を 5 列表へ拡張した際の残骸）。
   markdownlint の `MD058` で検出し削除。
2. **`<u>` タグ 3 件**を強調記法へ置換（`MD033` inline HTML）。
3. **`review-external.md` の Round 2 見出しが `#`**（`MD025` 複数 h1）→ `##` へ修正。

### 判定サマリ

| 項目 | 結果 |
|---|---|
| C-2 Round 2 major 1 件（R-009） | **反映済み**。**筆者が独立に組合せ行列を実走再現**したうえで反映 |
| C-2 Round 2 minor 2 件 + info 1 件 | **反映済み** |
| 新規に持ち込まれた FAIL | **0 件** |
| 残 WARN | **1 件**（W-6 を更新。下記） |

#### W-6（更新）[minor] `GC-8` の実装可否は依然として実装前のため未実証

前回の W-6 は「(i)(ii) の実装可否が未実証」だった。**C-2 Round 2 で
(ii) の実装形と `T1023-TC-05` 非破壊は実走で確認済み**となり、**この部分は解消**。
残るのは **(i) と (ii) を guard 本体へ同時統合した状態の実測**（`UV-2` の範囲）。
**`T1045-TC-22` + `T1045-TC-22b` + `SC-9`** で exec 時に機械検出される経路は確保済み。

#### C-3 へ引き継ぐ人間判断（更新）

| # | 論点 | 状態 |
|---|---|---|
| H-Q1 | Mode `critical` / `high-risk` | **未決（人間判断）**。実施しなくなるのは V-4 のみ |
| H-Q2 | `&>` / `&>>` を block 維持か | **未決（人間判断）**。C-2 は「既定のままで良い」と判定 |
| H-Q3〜H-Q6 | — | **すべて解消済み**（前回の簡易 C-1 で確認） |

---

C1-VERDICT-3: WARN plan=sha256:c7b3bf70b7cab8e372e858cd468518db4ecc4834b2b3b3b81b16c95437153e46

> 判定内訳: critical=0 / major=0 / minor(WARN)=1（W-6 更新版）/ FAIL=0
> **C-2 Round 1 の major 2 件と Round 2 の major 1 件はいずれも反映により解消**。
> 残 WARN は「実装前のため実証不能」に起因し、`UV-2` + `T1045-TC-22` + `TC-22b` + `SC-9`
> で exec 時に機械検出される。**plan は C-3 に諮れる状態**（最終判断は Human-owned）。
>
> 参考ハッシュ（同時対象）:
> todo=sha256:75e7424ff43d5dce34069520de78646f9ee49a65fa1bdaa53bbd1c811a6a43c4
> test-cases=sha256:1dcdd9d5c8dc906deb400f3f19186ce4e61492622cc93c41a6a2fb703667c806
> review-external=sha256:16d760303800807d986250ff6accd6b4876a8fdb73bc225668bb57d0141df69f
> base=`6089e23` / C-2 R1 反映 head=`e3b4a3e`
>
> **`c3.json` は上記 `C1-VERDICT-3` の `plan_hash` に対して発行すること。**

---

## 簡易 C-1 再実行 #3（C-2 Round 3 確定反映後 / 追記専用）

> 実施: plan maker（自己再確認）。**C-1 本体および簡易 C-1 #1 / #2 の記述は一切変更していない**（追記のみ）。
> 対象: **R-013 / INFO-3**（C-2 Round 3）の 1 回確定反映後の plan / todo / test-cases。
> **C-2 Round 3 は両レーンとも `C2-VERDICT: APPROVE`。R-013 が最後の 1 件。**

### 反映の網羅性（機械確認）

| 指摘 | severity | 反映先 | 確認方法と結果 |
|---|---|---|---|
| **R-013** | major | `GC-8` の reason assert 節を「**期待 reason は TC ごとに異なる**」へ改訂 + 実測経路表 / `test-cases.md` の `TC-22`・`TC-22b` 期待結果セル確定 / `todo` A-5a CP 同期 / Exit Criteria 分離 | `plan` / `test-cases` とも **`TC-22` = `sed not available`** / **`TC-22b` = `Bash command writes token path` かつ `parse-unknown` を含まない** で一致。**「両 TC 共通で `sed` 起因」を指示する生きた記述は 0 件**（残存 4 件はすべて**否定文または監査引用**） |
| **INFO-3** | info | `SC-9` 説明欄へ原因切り分けの 1 行 | 「**TC-22 の FAIL は (ii) の診断契約の破壊 / TC-22b の FAIL が真の fail-open**」を追記 |

**未反映（`status` が `reflected` 以外）の指摘 = 0 件**（Round 3 監査表 2 行とも `reflected`）。

### 筆者による独立実走（R-013 の裏取り）

FULL 実装 (i)+(ii)+(iii) のプロトタイプで**実測**（C-2 の主張と完全一致）:

| 入力 | rc | `sed not available` | `writes token path` | `parse-unknown` |
|---|---|---|---|---|
| `TC-22`（`sed` 不在） | 2 | **YES** | no | **YES** |
| `TC-22b`（`sed` 存在するが失敗） | 2 | **no** | **YES** | **no** |

→ **改訂前の `GC-8` に素直に従うと `TC-22b` は必ず FAIL し、`SC-9`（critical / 即停止）を誤発火させる**
ことを自分で確認したうえで反映した。

### 機械チェック結果（本再実行で実行したコマンド）

| # | コマンド | 結果 |
|---|---|---|
| S3-1 | `npx markdownlint-cli2 "docs/working/TASK-1045/*.md"` | **0 issues in 0 files**（7 ファイル。途中 5 件 + 派生 2 件を修正後） |
| S3-2 | `extract_allowed_paths(plan.md)` | **7 パス**・禁止パス混入なし |
| S3-3 | `Verification Automation:` 行の抽出 | 抽出可 |
| S3-4 | TC 定義の自数え | **23 件**（`TC-01`〜`TC-22` + `TC-22b`・不変） |
| S3-5 | Traceability の AC 行数 | **13 件**（AC-01〜13・不変） |
| S3-6 | `comm` による双方向 orphan 検査 | **両方向とも差分 0 件** |
| S3-7 | `diff` による `SC-*` / `RT-*` の plan ↔ todo 突合 | **SC 一致（SC-1〜9）/ RT 一致（RT-1〜5）** |
| S3-8 | **否定語の短形 sweep**（`両 TC 共通` / `起因`） | 生きた指示は **0 件**。残存はすべて否定文・監査引用 |
| S3-9 | **AC ID 軸の横断照合**（`grep -n 'AC-04' plan.md pbi-input.md test-cases.md todo.md` の**全ヒットを読了**） | 矛盾 0。Traceability の `AC-04` = **8 件**が定義側 8 件と一致 |
| S3-10 | HTML / 入れ子強調の残骸検査（`<strong>` / `<br>` / `****`） | 3 ファイルとも **0 件** |

### 本再実行で新たに発見・修正した掃き残し（自己検出）

1. **`test-cases.md` の Exit Criteria に否定済みの記述が残存**
   （「**いずれも stderr の reason 文字列が `sed` 起因である**ことまで assert 済み」）。
   **これは R-013 で否定した内容そのもの**であり、
   **TASK-1044 の教訓（否定語の短形 sweep）を適用して自己検出**した。TC 別の記述へ修正。
2. **inline HTML（`<strong>` / `<br>`）5 件**を markdownlint が検出 → 置換。
   置換で **入れ子強調（`****`）が 2 件**派生したためこれも修正。

### AC ID 軸の横断照合結果（S3-9・全ヒット読了）

- `pbi-input.md` の `AC-04` 関連 5 ヒット: **未編集・本反映と矛盾なし**
- `plan.md` 3 ヒット / `todo.md` 1 ヒット: `AC-04〜07` の集合参照のみ。矛盾なし
- `test-cases.md` 10 ヒット: 定義 8 件（`TC-04` / `12` / `13` / `14` / `15` / `19` / `22` / `22b`）が
  Traceability の **8 件**と一致
- **`TC-08`（AC-10 / `rule=` 検査）との整合も確認**: AC-10 適用後の detail は
  `Bash command writes token path (rule=<id>): <cmd>` となるため、
  **`TC-22b` の `grep 'Bash command writes token path'` は部分一致で成立**し衝突しない

### 判定サマリ

| 項目 | 結果 |
|---|---|
| C-2 Round 3 major 1 件（R-013） | **反映済み**。**筆者が独立に実走再現**したうえで反映 |
| C-2 Round 3 info 1 件（INFO-3） | **反映済み** |
| 新規に持ち込まれた FAIL | **0 件** |
| 残 WARN | **1 件**（W-6。内容は #2 から不変） |

#### W-6（据え置き）[minor] `GC-8` の実装可否は実装前のため未実証

**内容は簡易 C-1 #2 から変更なし**。(i)(ii) を guard 本体へ同時統合した状態の実測は
`UV-2` の範囲であり、**`T1045-TC-22` + `T1045-TC-22b` + `SC-9`** で exec 時に機械検出される。

#### C-3 へ引き継ぐ人間判断（不変）

| # | 論点 | 状態 |
|---|---|---|
| H-Q1 | Mode `critical` / `high-risk` | **未決（人間判断）**。実施しなくなるのは V-4 のみ |
| H-Q2 | `&>` / `&>>` を block 維持か | **未決（人間判断）**。C-2 は「既定のままで良い」と判定 |
| H-Q3〜H-Q6 | — | **すべて解消済み** |

---

C1-VERDICT-4: WARN plan=sha256:744b3c4f0cb05e10dc756e43e89ff263743c571c526838757fc9dee270fe2c7f

> 判定内訳: critical=0 / major=0 / minor(WARN)=1（W-6）/ FAIL=0
> **C-2 Round 1〜3 の major 計 4 件（R-001 / R-002 / R-009 / R-013）はすべて反映により解消**。
> **C-2 Round 3 は両レーンとも `C2-VERDICT: APPROVE`**。
> 残 WARN は「実装前のため実証不能」に起因し、`UV-2` + `T1045-TC-22` + `TC-22b` + `SC-9`
> で exec 時に機械検出される。**plan は Human C-3 へ渡せる状態**。
>
> 参考ハッシュ（同時対象）:
> todo=sha256:620a825ca34f9da85ab51f4b962b32da7d6112334383fdfe1f2ec788abc933fd
> test-cases=sha256:93710dd04f41572283e32ac42e4c01dc85d70f50bf4a0e69a4042af8a27fe9da
> review-external=sha256:0cc7fdf736679b7739052c99a0f7afe3ca1108bc8fd540a99f009ca0cfe7cb94
> base=`6089e23` / C-2 R2 反映 head=`4c4fc53`
>
> **`c3.json` は上記 `C1-VERDICT-4` の `plan_hash` に対して発行すること。**

---

## 簡易 C-1 再実行 #4（River Review / R-014〜R-018 反映後 / 追記専用）

> 実施: plan maker（自己再確認）。**C-1 本体および簡易 C-1 #1〜#3 の記述は一切変更していない**（追記のみ）。
> 対象: **R-014〜R-018**（River Review）の 1 回反映後の todo / test-cases / INDEX / decision-log。
> **River Review の判定は「PR 作成: 可」。R-014 が `plan_hash` を変えずに直せる最後の major。**

### 🔑 `plan_hash` 不変の実測（本ラウンドの最重要確認）

**EH-3（`scripts/hooks/check-plan-hash.sh:89`）の照合対象は `*/plan.md|plan.md)` = `plan.md` 単体**
（**筆者が実測確認**）。本ラウンドは **`plan.md` を 1 文字も編集していない**。

| 検査 | 結果 |
|---|---|
| `shasum -a 256 plan.md` | **`744b3c4f0cb05e10dc756e43e89ff263743c571c526838757fc9dee270fe2c7f`**（`C1-VERDICT-4` と**完全一致**） |
| `git status --porcelain -- docs/working/TASK-1045/plan.md` | **空**（未編集） |

→ **`C1-VERDICT-4` で発行対象とした `plan_hash` は有効なまま。C-3 のやり直し・再ハッシュは不要。**

### 反映の網羅性（機械確認）

| 指摘 | severity | 反映先 | 確認方法と結果 |
|---|---|---|---|
| **R-014** | major | `todo` に **TC 追加の owner 表**を新設（全 23 件）。`A-5a` へ `TC-22` / `TC-22b`、`A-7` へ `TC-07` / `TC-16` / `TC-17` / `TC-18`。`A-5a` / `A-7` の `rollback:` 更新。`A-11` / `A-12` を evidence 専任と明記 | **owner 表 23 件 = 定義 23 件で完全一致。owner 未割当 0 / 定義に無い owner 0**（Python で集合照合） |
| **R-015** | minor | `INDEX.md` 新規作成 / `decision-log.jsonl` 初期化（D-1〜D-9） | 両ファイル作成。**`decision-log.jsonl` は 9 行すべて valid JSON** と実測 |
| **R-016** | minor | `A-5a` の 🚩 へ `LC_ALL=C` の静的検査 | 「`grep -c 'LC_ALL=C' …` が 1 以上**かつ正規化パイプライン行に付いている**」を追記 |
| **R-017** | minor | `test-cases.md` 記法規約へ「`route=` は文書内ラベルで guard 出力ではない」 | 追記済み。**誤 assert すると `SC-9` を誤発火させる**旨も明記 |
| **R-018** | minor | Round 1 集計の訂正 1 行を **River Review 節末尾へ追記**（既存行は書き換えない） | 追記済み（`:17` の minor は **6** が正） |
| **Q-3** | — | `todo` H-1 の裁定項目へ新設（**AI は裁定しない**） | 背景・影響・コストを明記して Human C-3 へ |

**未反映（`status` が `reflected` / `deferred` 以外）の指摘 = 0 件**
（River Review 監査表 6 行: `reflected` 5 / `deferred`（Human 裁定）1）。

### 機械チェック結果（本再実行で実行したコマンド）

| # | コマンド | 結果 |
|---|---|---|
| S4-1 | `npx markdownlint-cli2 "docs/working/TASK-1045/*.md"` | **0 issues in 0 files**（**8 ファイル**。途中 1 件を修正後） |
| S4-2 | `shasum -a 256 plan.md` + `git status -- plan.md` | **`plan_hash` 不変・未編集**（上表） |
| S4-3 | `python3 -c json.loads` で `decision-log.jsonl` を全行検証 | **9 行すべて valid JSON** |
| S4-4 | **owner 表 ↔ TC 定義の集合照合**（Python） | **23 = 23 / 未割当 0 / 余剰 0** |
| S4-5 | `comm` による双方向 orphan 検査 | **両方向とも差分 0 件**（23 = 23） |
| S4-6 | `grep -rn 'route=' docs/ scripts/ tests/ bin/`（TASK-1045 除外） | guard 出力としては **0 hits**（唯一の他ヒットは Python の `subTest(route=label)` で無関係）→ R-017 の前提を裏取り |
| S4-7 | `git ls-tree origin/main docs/working/TASK-1044/` | `INDEX.md` / `decision-log.jsonl` を含むことを確認（R-015 の先例） |
| S4-8 | `grep -n 'plan\.md)' scripts/hooks/check-plan-hash.sh` | **`:89` の case パターン（`*/plan.md` と `plan.md` の 2 分岐）** = 照合対象は plan.md 単体 |

### 本再実行で新たに発見・修正した掃き残し（自己検出）

1. **owner 表の範囲表記 `TC-11`〜`TC-15` が機械照合に乗らず、`TC-12` / `TC-13` / `TC-14` が
   「owner 未割当」と判定された**。**R-014 が問題にしていた「owner の所在が曖昧」そのもの**なので、
   **範囲表記をやめて明示列挙**に変更（再照合で 23 = 23 に一致）。
2. inline HTML（`<b>`）1 件を強調記法へ置換。

### 判定サマリ

| 項目 | 結果 |
|---|---|
| River Review major 1 件（R-014） | **反映済み**。owner 表を機械照合可能な形で新設 |
| River Review minor 4 件（R-015〜R-018） | **反映済み** |
| Human C-3 裁定 1 件（Q-3） | **`todo` H-1 へ委譲**（AI は裁定しない） |
| 新規に持ち込まれた FAIL | **0 件** |
| 残 WARN | **1 件**（W-6。内容は #2 から不変） |

#### C-3 へ引き継ぐ人間判断（Q-3 追加）

| # | 論点 | 状態 |
|---|---|---|
| H-Q1 / Q-1 | Mode `critical` / `high-risk` | **未決**。実施しなくなるのは V-4 のみ |
| H-Q2 / Q-2 | `&>` / `&>>` を block 維持か | **未決**。C-2 は「既定のままで良い」と判定 |
| **Q-3（新設）** | `Files / Components to Touch` に `evidence/` / `decision-log.jsonl` / `current-state.md` を追加して `plan_hash` を取り直すか、現状受容か | **未決**。**追加する場合のみ `plan_hash` 再計算が必要** |

---

C1-VERDICT-5: WARN plan=sha256:744b3c4f0cb05e10dc756e43e89ff263743c571c526838757fc9dee270fe2c7f

> **`plan_hash` は `C1-VERDICT-4` から不変**（`plan.md` を編集していないため）。
> 判定内訳: critical=0 / major=0 / minor(WARN)=1（W-6）/ FAIL=0
> **C-2 Round 1〜3 の major 4 件 + River Review の major 1 件はすべて反映により解消**。
> **plan は Human C-3 へ渡せる状態**（Q-1 / Q-2 / Q-3 の 3 件が裁定待ち）。
>
> 参考ハッシュ（本ラウンドで更新されたもの）:
> todo=sha256:48a2081b52ab5bd60bc0fc9f378ada8047419c0e73ee73351c63762a5d78e2e9
> test-cases=sha256:a3d451a37abddabf794f673e758f5267a6f88015456ff9c21557eb0989bd5541
> review-external=sha256:8d105996063be89b0edac996eca129542431cb4090f0c27762259372ed454978
> base=`6089e23` / C-2 R3 反映 head=`5847e69`
>
> **`c3.json` は上記 `plan_hash`（`744b3c4f…`）に対して発行すること。**

---

## 簡易 C-1 再実行 #5（C-3 裁定 3 件の反映後 / `R-019`）

> 対象: **Human C-3 が下した裁定 3 件（Q-1 / Q-2 / Q-3）の 1 回確定反映**。
> **本ラウンドで初めて `plan.md` を編集したため `plan_hash` が変わる**（#1〜#4 と異なる点）。
> 変更は **`Files / Components to Touch` 3 行追加 + 注記** と **`Questions / Unknowns` への裁定記録**のみ。

### 反映内容と裁定の一致確認

| Q | Human 裁定 | 反映結果 | 一致 |
|---|---|---|---|
| Q-1 | `critical` のまま | `plan.md` の Mode 判定行（`:764`）は `critical` のまま（**未編集**） | ✅ |
| Q-2 | block 維持 | 除外条件は未編集。`&>` / `&>>` は block のまま | ✅ |
| Q-3 | 追加して `plan_hash` を取り直す | Files 節へ 3 行追加 + `plan_hash` 再算出 | ✅ |

**AI は裁定内容を変更していない**（Q-1 / Q-2 は「既定どおり」＝設計変更ゼロ、
記録のみ。Q-3 のみが plan の実変更を伴う）。

### Plan 7 項目（簡易 C-1）

| # | 項目 | 判定 | 根拠（実測） |
|---|---|---|---|
| C1-PLAN-01 | 受入基準の網羅性 | **PASS** | `AC-NN` の一意集合は plan で **10**（`origin/main` 版と**同数・同一**）、`test-cases.md` で **13**。**AC は 1 件も増減していない** |
| C1-PLAN-02 | Unknowns の処理 | **PASS** | `UV-1`〜`UV-4` は未編集で `RT-1` / `RT-5` / `SC-3` / `RT-4` へ接続されたまま。**新たな未決は発生していない**（Q-1〜Q-3 が裁定済みになり**未決 Question は 0 件**） |
| C1-PLAN-03 | スコープ制御 | **PASS** | `git diff --stat` は **3 ファイル**（plan / todo / review-external）。`scripts/` `tests/` `approvals/` および HO 対象パスへの変更は **0 件** |
| C1-PLAN-04 | テスト戦略 | **PASS** | Testing Strategy 節は**未編集**。TC 一意集合 **23 件**で不変 |
| C1-PLAN-05 | Work Breakdown Output | **PASS** | Work Breakdown 節は**未編集**。Step 1 / 1b / 6 / 7 / 8 の Output（evidence 配下）が **`allowed_paths` 内に収まるようになった**＝Output と Files 節の整合が**改善**した |
| C1-PLAN-06 | 依存関係 | **PASS** | `todo.md` の依存記述（`H-1` 必須先行）は未編集。H-1 の内容が「裁定待ち」→「裁定済み + 承認トークン再発行待ち」に更新されただけ |
| C1-PLAN-07 | 動作検証の自動化 | **PASS** | `extract_allowed_paths()` を**実際に import して実走**し 7 → 10 を実測（推測ではない） |

### 機械検査の実測

| 検査 | コマンド | 結果 |
|---|---|---|
| S1 | `extract_allowed_paths(plan.md)` の実走 | **10 パス**（反映前 7） |
| S2 | allowed_paths への HO 9 カテゴリ混入 | **0 件** |
| S3 | plan の `AC-NN` 一意数（base 比較） | **10 → 10（不変）** |
| S4 | `test-cases.md` の TC 一意数 | **23（不変）** |
| S5 | plan の Mode 行 | **`critical`（不変）** |
| S6 | `git diff -U0 -- plan.md` の hunk | **2 hunk・いずれも純追加**（`+593` = Files 節 / `+729` = Questions 節）。**削除行 0** |

### 残 WARN

| ID | 内容 | 状態 |
|---|---|---|
| W-6 | （#2 から不変） | **残置**。本ラウンドで悪化なし |
| **W-7（新規 / info 相当）** | **Q-2 の裁定により `&>/dev/null` 付き読み取りの誤 block が残存する** | **意図的な受容**。`T1045-TC-14 (3)` で固定し、**handoff の既知課題へ記載することが裁定の条件** |

### 新規 FAIL

**0 件。**

---

C1-VERDICT-6: WARN plan=sha256:30261b118da7761f7a78d9090c4fcda9f1d1dbd07af27cbff58ddd436029e681

> **🔑 `plan_hash` は本ラウンドで更新された**
> （`744b3c4f0cb05e10dc756e43e89ff263743c571c526838757fc9dee270fe2c7f`
> → **`30261b118da7761f7a78d9090c4fcda9f1d1dbd07af27cbff58ddd436029e681`**）。
> **`C1-VERDICT-5` までの `plan_hash` は無効**。
> 判定内訳: critical=0 / major=0 / minor(WARN)=2（W-6 / W-7）/ FAIL=0
> **未裁定の Question は 0 件**（Q-1 / Q-2 / Q-3 すべて C-3 で確定）。
>
> **次の 1 手は 👤 Human による承認トークンの再発行**（Human-owned。AI は作成しない）。
> **上記 `C1-VERDICT-6` の `plan_hash` に対して発行すること。**
> 発行後に `plan.md` を 1 文字でも編集すると EH-3 が mismatch を検知する
> （`feedback_no_plan_edit_after_c3_approval`）。
