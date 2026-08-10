---
task_id: TASK-1012
artifact_type: review-self
schema_version: 1
status: final
verdict: WARN
created_by: independent-c1-reviewer
---

# TASK-1012 セルフレビュー結果（C-1）

> レビュー日: 2026-08-10
> 対象コミット: `82548375cbaab8f8524f6fee01e961c8f4b7d6d7`（`feat/1012-tc13-skip`）
> 判定: **WARN** — critical=0, major=0, minor=7（FAIL 0）
> **C-3 に出せる状態である**。ただし下記「Human C-3 の判断事項」5 件を承認前に判断すること。

## 本レビューの範囲と独立性（先に明示する）

- **レビュアーは plan の作成者ではない**。plan / todo / test-cases / pbi-input は別のワーカーが作成し、C-2（`review-external.md` R-001〜R-009）と独立 river-review（R-010〜R-014）を経て改訂されている。本 C-1 は maker から独立した checker として実施した。
- **plan は「C-1 を 9 ラウンド実施し計 55 件を反映した」と主張している**（`plan.md:6`）。しかしその記録は plan.md の「改訂 N」記述と各節の脚注にしか存在せず、**`review-self.md` としては 1 度も発行されていない**（本ファイルが初出）。したがって **本 C-1 はラウンド 1〜9 の結論を追認していない**。**改訂 11 相当の最終形（`8254837` 時点の 5 ファイル）に対して新規に実施した**結果のみを記載する。
- **plan / todo / test-cases / pbi-input は本レビューで一切編集していない**（承認前の plan 編集禁止）。指摘は本ファイルに閉じる。

## C-1 チェック項目の正本と項目数（自分で数えて確定させた）

| 正本 | 内容 |
|------|------|
| `docs/working/templates/review-self.md` | **check_id 付きの構造化 schema の正本**（`.claude/commands/ai-dev-workflow.md:227` が「このテンプレートの schema に従う」と指定） |
| `.claude/rules/working-context.md`「review-self.md」節 | 役割定義（Plan 7 / ToDo 5 / TestCases 3 + 判定） |
| `.claude/commands/ai-dev-workflow.md` L200-226 | 17 項目の元定義（Plan 7 / ToDo 5 / TestCases 3 / B-1B-2 2） |

**「17 項目」は歴史的な呼称であり、テンプレート正本の実体は 25 項目である**（数えた結果）:

| 区分 | check_id | 件数 |
|------|----------|------|
| Plan | `C1-PLAN-01`〜`07` + `C1-PLAN-08-AEE` / `09-AEE`（#544 Phase1） | **9** |
| Plan 品質追加（#581） | `C1-SUP-PLAN-01` / `02` | **2** |
| ToDo | `C1-TODO-08`〜`12` + `C1-TODO-RB` | **6** |
| TestCases | `C1-TEST-13`〜`15` | **3** |
| B-1/B-2 | `C1-B1B2-16` / `17` | **2** |
| 追加（#578 / #579） | `C1-SEC-01` / `C1-SCOPE-DISC-01` / `C1-UI-01` | **3** |
| **合計** | | **25** |

Mode = **high-risk** のため、`.claude/rules/mode-classification.md` のフェーズ適用マトリクス上 C-1 は `○`（簡易版ではなく全項目）である。本レビューは **25 項目すべて**を評価した。

## サマリー

| result | 件数 |
|--------|------|
| PASS | 16 |
| WARN | 7 |
| FAIL | 0 |
| N/A | 2 |

## Plan チェック（9 項目）

### C1-PLAN-01: 受入基準網羅性
- **result**: WARN
- **category**: plan
- **finding**: AC-1〜AC-6 は `test-cases.md:45-53` のマッピング表で **全件が TC を持つ**（AC-6 → TC-A6a / TC-A6c / **TC-A6d**）。ただし **AC の正本である `pbi-input.md:77` の AC-6 は「検証は TC-A6a、検出力の実証は TC-A6c」までしか列挙しておらず、改訂 11 で新設された TC-A6d が欠落**している。反映コミット `e22053e` の本文も更新対象を「plan T-04 / todo A-4 / 依存関係図 / 完了条件」と列挙しており **pbi-input を含んでいない**（変異 3 種 → 4 種の追随漏れ 1 箇所）。AC の充足条件そのものは変わらないため実害は小さいが、AC 正本と TC 正本で AC-6 の検証手段の記述が食い違う。
- **evidence_ref**: —（`pbi-input.md:77` / `test-cases.md:52` / `git log -1 e22053e` で照合）
- **impacted_files**: `docs/working/TASK-1012/pbi-input.md`
- **suggested_action**: pbi-input.md AC-6 の検証手段に TC-A6d を追記する（承認後の plan_hash 対象外ファイルだが、C-3 前の是正が望ましい）
- **owner**: agent
- **resolved**: false

### C1-PLAN-02: Unknowns処理
- **result**: PASS
- **category**: plan
- **finding**: `plan.md:330-335` の U-1 / U-2 はいずれも解消手段（T-01 のシンボル越境検査 / T-03 の親カバレッジ不変）に紐付き、放置されていない。pbi-input の Unknowns も同一内容へ同期済み。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御
- **result**: PASS
- **category**: plan
- **finding**: Non-goals が 5 項目、Out of scope が追跡先 issue 付き（#914 / #1009 / #1010 / #1011 / #997）で明示。「触らないファイル」を Files 節ではなく Constraints へ置く判断（`extract_allowed_paths()` が禁止パスを allowed_paths に取り込む問題の回避）も、非 production run では発火しない旨まで含めて記述されており過大主張がない。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-04: テスト戦略
- **result**: PASS
- **category**: plan
- **finding**: Integration（親 / 子 2 系統）/ Regression（フルスイート）/ 静的検査（越境検査・TC-INV）/ 検出力の実証（変異 4 系統）の 4 層。とくに **検査自体の検出力を変異で実証する層が独立して存在する**点は、テスト追加 PBI として妥当な設計。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-05: Work Breakdown Output
- **result**: PASS
- **category**: plan
- **finding**: T-01〜T-06 すべてに Output 列（evidence パス or 差分 or 各文書）と Owner / Risk / 🚩 が埋まっている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-06: 依存関係
- **result**: PASS
- **category**: plan
- **finding**: `todo.md:57-63` の依存グラフは A-1 → A-2 → A-3 → A-4 → A-5 → A-6 の単一直列で矛盾なし。A-5 を A-4 の後に直列化する理由（変異の index 復元と A/B の `cp` 上書きが同一ファイルを奪い合う）も明示。H-0（Human C-3）が A-1 開始前という順序も plan「ゲート運用」節と一致。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-07: 動作検証自動化
- **result**: PASS
- **category**: plan
- **finding**: Verification Automation 行が存在し、**本レビューで実際に抽出コマンドを実行して内容一致を確認**した。抽出結果 = `sh tests/extras/ta-26-plugin-sync.sh </dev/null && PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh </dev/null && sh tests/run-tests.sh`（`plan.md:151` の記載と完全一致・rc=0）。plan が警告する「ラベルを V-A 行より前に literal 表記すると fail-open で誤抽出される」問題は**現時点で再発していない**ことを実測で確認した。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-08-AEE: Stop Condition 記入
- **result**: WARN
- **category**: plan
- **finding**: plan / todo に **plan レベルの「Stop Condition」節が存在しない**（`grep -niE 'stop condition|停止条件' plan.md todo.md` → 0 件）。局所的な停止条件は `test-cases.md:219`「測定は最大 4 往復まで」と AC-5 の WARN ゲートに存在するが、exec 全体の中断条件（例: T-01 で越境が 0 件でなかった場合の扱い、A-4 のいずれかの変異が期待どおり FAIL しなかった場合の扱い）は明文化されていない。**未記入は WARN**（強制は Phase2 / #543）。
- **evidence_ref**: —
- **impacted_files**: []
- **suggested_action**: 「T-01 の越境が 1 件以上」「変異が期待どおり FAIL しない」を exec 中断 → 人間判断のトリガとして明記
- **owner**: agent

### C1-PLAN-09-AEE: Replan Triggers 機械値
- **result**: WARN
- **category**: plan
- **finding**: Replan Triggers の節・機械値がない（同上 grep → 0 件）。**未記入は WARN**。
- **evidence_ref**: —
- **impacted_files**: []

## Plan 品質追加チェック（2 項目）

### C1-SUP-PLAN-01: No Placeholders Rule
- **result**: WARN
- **category**: plan
- **finding**: `TBD` / `TODO` / `適切に` / `必要に応じて` 等の曖昧表現は **0 件**（grep 実測）。しかし **未定義のファイルパスが 1 件残る**: TC-A6a のフェンスは `tc-a6a.sh` という**スクリプトファイルとして実行される前提**で書かれ（`test-cases.md:237-238` の使い方コメント、`test-cases.md:377-378` の TC-A6d 判定コマンド `sh tc-a6a.sh …`）、todo A-3 / A-4 も「TC-A6a を再実行」と指示するが、**このスクリプトをどこへ書き出すかが plan / todo / test-cases のどこにも定義されていない**。これは実害に接続する:
  - todo 完了条件（`todo.md:75`）が「`git status --porcelain` で想定外の untracked が 0 件」を要求しているため、repo 内へ無定義に置くと自分の完了条件と衝突する
  - R-008 で判定用**ログ**の出力先は `evidence/test-runs/` に固定されたが、**実行スクリプト自体の置き場は固定されていない**
  - さらにフェンス内で `F=tests/extras/ta-26-plugin-sync.sh` を**相対パスで固定**しているため、**リポジトリルートを cwd として実行する**という前提が暗黙のまま（明記がない）
- **evidence_ref**: —
- **impacted_files**: `docs/working/TASK-1012/test-cases.md`, `docs/working/TASK-1012/todo.md`
- **suggested_action**: `tc-a6a.sh` の配置先（例: `evidence/verification/tc-a6a.sh` として commit する / repo 外の一時ディレクトリへ書き出す）と cwd 前提を明記する
- **owner**: agent
- **failure_policy**: high-risk では通常 FAIL 相当だが、**判定式そのものは完全で verbatim 実行可能**（本レビューで実証済み）であり欠けているのは配置規約のみのため WARN に留めた

### C1-SUP-PLAN-02: Task Sizing Rules
- **result**: WARN
- **category**: plan
- **finding**: **改訂 10 で撤回した「帯回避」が、AC 軸では撤回されタスク軸では撤回されていない**（非対称）。
  - `plan.md:40`（C-1 R3 の台帳）は、タスクを 11 → 6 に統合した動機を **「タスク数 11 は『高』の帯（11-20）」** と明記している＝**判定基準の側を目的に合わせて操作した記録**。
  - 一方 `plan.md:367-376`（改訂 10）は、AC を 6 → 5 に畳んだ動機が帯回避であったことを理由に **その畳み込みだけを撤回**し AC-6 を独立 AC へ戻した。
  - **同一クラスの帯回避であるタスク統合（11 → 6）は撤回されておらず、撤回しない理由も書かれていない**。Mode は他軸で high-risk に到達するため最終判定は変わらないが、統合の結果として A-1 / A-4 が複合タスクになっている（A-1 = baseline 実測 + 範囲確定 + 越境検査 + V-A 行検証の 4 系統、A-4 = 変異 4 種）。high-risk では Task 単位の approve/reject 粒度が要求される。
- **evidence_ref**: —
- **impacted_files**: `docs/working/TASK-1012/plan.md`, `docs/working/TASK-1012/todo.md`
- **suggested_action**: (a) タスク統合を維持するなら「帯回避が動機だったが、統合後も各 🚩 が独立検証可能であるため維持する」と理由を明記して撤回済み記述との整合を取る、または (b) A-1 / A-4 を分割する。**どちらを採るかは Human C-3 の判断事項**（下記一覧 5）
- **owner**: human

## ToDo チェック（6 項目）

### C1-TODO-08: タスク粒度
- **result**: WARN
- **category**: todo
- **finding**: A-1〜A-6 はいずれも「2〜5 分で完了できる粒度」を満たさない（A-4 単体で変異 4 種 × 適用 / 実行 / 復元 / 再 PASS 確認）。根本原因は C1-SUP-PLAN-02 と同一（11 → 6 の統合）。ただし各タスクに 🚩 と rollback が個別に付いており、進捗把握は可能。
- **evidence_ref**: —
- **impacted_files**: `docs/working/TASK-1012/todo.md`

### C1-TODO-09: depends_on設定
- **result**: PASS
- **category**: todo
- **finding**: `todo.md:31-38` の depends_on 列が全タスクに設定され、依存グラフ（L57-63）と一致。H-0 → A-1、A-6 → PR → H-1 の Human ↔ Agent 依存も明示。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-10: チェックポイント設定
- **result**: PASS
- **category**: todo
- **finding**: A-1〜A-6 すべてに 🚩 列があり、いずれも**機械判定可能な形**（`sh -n` rc / `git diff --cached --stat` に載る / 越境 0 件 / 4 変異すべて期待 FAIL / OPT が index と一致）で書かれている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-11: Iron Law遵守
- **result**: PASS
- **category**: todo
- **finding**: 承認境界の逸脱なし。本レビューで機械確認した:
  - **`git diff --name-only origin/main...8254837` の 5 ファイルすべてが `docs/working/TASK-1012/*.md`** で、`approvals/` も `c3.json` も**含まれない**（rc=0 / 出力 5 行）
  - todo H-0 は「AI は実行不可」と明記され、`bin/plangate` の `_plangate_presence_gate()`（L2294）が `ps -p $PPID` で `claude` / `codex` / `cursor` を reject する実装と一致
  - todo H-0 §d の「c3.json は `cmd_validate` の**前**に書かれる」主張を実装で確認（`bin/plangate:2422` で c3.json を write → `bin/plangate:2443` で `cmd_validate` 呼び出し）。`cmd_validate` の必須 5 点に `review-self.md` が含まれることも確認（`bin/plangate:986`）
  - AI が承認トークンを発行する記述は 4 文書のいずれにも存在しない
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-12: 完了条件
- **result**: PASS
- **category**: todo
- **finding**: `todo.md:69-93` に 8 群の完了条件。とくに (a) `git diff -w HEAD --` の `HEAD` 必須（省くと fail-open）、(b) 判定用ログを repo ルートに残さない、(c) AC-5 が WARN のまま AI 完了扱いにしない、(d) V-2 / V-3 通過、(e) clean tree での CI 相当再実行、が明示されている。L-0 / V-1 / V-2 / V-3 / PR を Agent タスクに並べず完了条件として持つ切り分けも `working-context.md` の todo 規約と整合。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-RB: rollback（戻し手順）
- **result**: PASS
- **category**: todo
- **finding**: Mode = high-risk のため必須。A-1〜A-6 すべてに rollback 列があり、読取のみのタスクは「不要」と明記。**変異復元（`git checkout -- <file>` = index へ）と実装取り消し（`git checkout HEAD -- <file>` = HEAD へ）のセマンティクス分離**が `todo.md:40-49` で表として固定され、A-2 の `git add` 必須化とセットで両立が担保されている。A-5 は `cp /tmp/ta26.opt` による退避コピー復帰。
- **evidence_ref**: —
- **impacted_files**: []

## テストケースチェック（3 項目）

### C1-TEST-13: 受入基準→テストケース網羅性
- **result**: PASS
- **category**: test
- **finding**: `test-cases.md:45-53` で AC-1〜AC-6 + 不変条件がすべて TC を持つ。AC-6 を独立 AC へ戻したことによる**マッピングの食い違いは無い**（本レビューで全 AC / 全 TC を突合）。とくに **TC-A6b を AC-1 側に残す例外**は正しい: 変異②（ゲート B 終端を TC-36 手前へ）で実際に落ちるのは TC-A1b であり、越境検査（AC-6）は落ちない。`_t26_mk_refs_guard_sandbox` の定義が **L527 = ゲート外**であることを実測確認したため、変異②で TC-36 が子でも正常実行され `[PASS] TC-36` が出る＝空振りしないという論拠も成立する。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-14: テストケースの具体性
- **result**: PASS
- **category**: test
- **finding**: 「正しく動作する」のような曖昧判定は 0 件。全 TC が値レベル（`2` / `0` / `TC-30: 1` / `containment_violations=0` / `crossings=0` / `0 failed` / `OPT ≤ BASE × 0.85`）。**本レビューは TC-A6a のフェンスを verbatim 抽出して実行し、test-cases.md:319-326 に記載された 4 行の実測表がすべて再現することを確認した**（下記「実行した検証コマンド」参照）。変異③の実測値（`CROSS _t26_tgt36 (def L721) <- L806` / `crossings=1` / rc=1）も再現。**plan の記述が exec で実際に動くことを、AC-6 の中核検査については実証済み**。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-15: エッジケースの考慮
- **result**: PASS
- **category**: test
- **finding**: E-1〜E-6（`:-0` 既定 / 想定外値の安全側倒し / harness 経由 / TC-13 の 2 本目の子 / シンボル越境 / 将来の TC 追加）を網羅。E-4 は「2 本目の子は TC-A1a/b の入力に含まれない」という**検査の限界を明示**したうえで AC-3 に帰着させており、過大主張がない。TC-A1b の **`grep -c` は 0 件のとき rc=1** という POSIX 挙動の逆転も注記済み（`test-cases.md:97`）。
- **evidence_ref**: —
- **impacted_files**: []

## B-1/B-2チェック（2 項目）

### C1-B1B2-16: B-1確認質問
- **result**: PASS
- **category**: plan
- **finding**: pbi-input の曖昧点は解消されているか、**未解消のものが「Human C-3 の確認事項」として 3 点明示**されている（brainstorm の扱い / exec 並列 / C-2 の充足）。AI が単独で「不要」と確定していない点は `.claude/rules/responsibility-classes.md` の承認境界と整合。
- **evidence_ref**: —
- **impacted_files**: []

### C1-B1B2-17: B-2アプローチ比較
- **result**: WARN
- **category**: plan
- **finding**: **2 案以上の比較が存在しない**。plan は「既存イディオム（L62-68）のミラーであり新規設計を持ち込まない」を単一根拠として単案で進めており、代替案（例: TC-13 の子を軽量 fixture で置き換える / TC-13 自体を軽量化する〔#1011〕/ sync 内の `python3` 多重起動を潰す〔#914 diff 外〕）は **Non-goals / Out of scope に「やらない」としてのみ列挙**され、**「なぜこの案を選んだか」の比較としては提示されていない**。high-risk では選定理由の明記が要求される。なお **これらの代替案は本 PBI の恒久コスト（子プロセスのカバレッジ縮小＝テスト意味論の変更）を伴わない**ため、比較の欠落は C-4 の「カバレッジ縮小を受け入れるか」判断材料の欠落に直結する。
- **evidence_ref**: —
- **impacted_files**: `docs/working/TASK-1012/plan.md`
- **suggested_action**: 「なぜ #1011 / #914 diff 外の最適化ではなく本方式を先に採るか」を 2〜3 行で明記する（実行時間の支配項が TC-13 であるという実測を根拠にできる）
- **owner**: agent

### C1-SEC-01: 秘密情報 非接触
- **result**: N/A
- **category**: plan
- **finding**: `.env` / APIキー / トークン / 個人パス / ローカル設定に触れない。変更対象は `tests/extras/ta-26-plugin-sync.sh` 1 ファイルと working context のみ。秘密情報を扱わない変更のため N/A。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離
- **result**: PASS
- **category**: plan
- **finding**: 発見済みのスコープ外課題がすべて追跡先 issue へ分離済み（#1009 経路2 guard の fail-open / #1010 変異 2 種の通り抜け / #1011 TC-13 連鎖 FAIL / #997 dirty tree での `test_tc45` 誤 FAIL / #914 diff 外の最適化）。その場で直す方針の記述はない。
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠
- **result**: N/A
- **category**: plan
- **finding**: non-UI（シェルスクリプトのテスト構造変更）。
- **evidence_ref**: —
- **impacted_files**: []

## 重点観点への回答（オーガナイザー指定 6 点）

### 1. Mode = high-risk の判定根拠は `mode-classification.md` と整合するか → **整合する**

| 軸 | plan の値 | `mode-classification.md` 定量/定性基準 | 帯 | 照合 |
|----|----------|--------------------------------------|----|------|
| 変更ファイル数 | ≥ 6 | 6-15 = 高 | 高 | ⚠️ 下記注 |
| 受入基準数 | 6 | 6-10 = 高 | 高 | ✅ |
| タスク数 | 6 | 5-10 = 中 | 中 | ✅ |
| 変更種別 | 小機能追加相当 | 中 | 中 | ✅ |
| リスク | 中 | 中 | 中 | ✅ |
| 影響範囲 | 当該ファイルのみ | 「当該ファイルのみ」= **超低** | 超低 | ✅（改訂 2 までの誤りは是正済み） |
| ロールバック | 容易 | 「容易」= 低 | 低 | ✅ |

定量の最大 = 高 / 定性の最大 = 中 → 高い方を採り **high-risk**（判定ロジック 3）。**結論は正しい**。

> ⚠️ **注（info）**: 変更ファイル数の実測は**測定時点で 5**（`git diff --stat origin/main...8254837 -- docs/working/TASK-1012/` を本レビューで実行 → 5 files）。plan は「完了時点で 6 超」という**将来の投影値**で「高」を主張している。厳密には現時点で「高」帯を確定できるのは受入基準数 6 の軸のみ。ただし **受入基準数だけで独立に高へ到達する**ため、**最終判定 high-risk は投影値の当否に依存しない**。安全側（`mode-classification.md`「自動推定の安全側」）とも整合。

`tests/extras/*.sh` が Hardening Override 9 カテゴリ**外**である主張も `scripts/hooks/check-plan-hash.sh:124-134` の case 文を実読して確認（`tests/` はいずれのパターンにも一致しない）。「中 → 高 の差分は 4 行」という主張も `.claude/rules/mode-classification.md:149-163` の表を列単位で数えて確認した（`brainstorm` △→○ / `C-2` -→○ / `exec` TDD→TDD+並列 / `V-2` -→○ の **ちょうど 4 行**。`V-3` は中でも `○`、`V-4` は `critical` のみ）。

### 2. AC-6 独立化による AC ↔ TC ↔ todo の食い違い → **1 件のみ（軽微）**

- test-cases のマッピング表 ✅ / todo 完了条件「AC-1〜AC-6 がすべて PASS」✅ / plan T-03 の 🚩「AC-1〜AC-4 + AC-6」✅（AC-5 は T-05 担当で正しい）/ TC-A6b を AC-1 に残す例外 ✅
- **不一致は `pbi-input.md:77` の AC-6 に TC-A6d が欠落している 1 点のみ**（C1-PLAN-01 参照）

### 3. 「C-2 が不足」という自己申告は過大か過小か → **過大でも過小でもない（安全側で妥当）**

- **`lite_eligible=false` により AC-12（Lite の 1 本枠）が失効した**という推論は正しい。`mode-classification.md`「Lite ゲート構成 vs Standard」で Lite の C-2 = 1 本、Standard = 複数観点。
- **`review-principles.md` §7-bis のコードベース整合レーン未実施**も事実。`review-external.md:16` のメタ表自身が「未実施（設計妥当性レーンに内包された）」と記録している。
- ただし **やや保守側**である点は記録しておく: `review-external.md:58-64` の「指摘ゼロと確認された領域」は行番号・関数定義位置・HO 判定・識別子件数（ゲート A 31 + ゲート B 46 = 77）まで実コードで全数照合しており、§7-bis がコードベース整合レーンに求める「既存パターンとの不整合検出」の実質は相当程度カバーされている。**本レビューでも `identifiers=77` を独立に再現**した。
- **したがって「不足」判定は過大主張ではなく、むしろ AI が自分に厳しい側へ倒した判断**であり、`working-context.md` AC-8 の安全側原則と整合する。**充足/不足の最終判断を Human C-3 に委ねている点も正しい**（AI が「充足」と書き換えていない）。

### 4. 変異 3 種 → 4 種の追随 → **6 箇所中 5 箇所で追随済み・1 箇所漏れ**

| 反映先 | 追随 |
|--------|------|
| `plan.md:131`（T-04） | ✅ ①②③④ |
| `plan.md:149`（Testing Strategy 検出力の実証） | ✅「変異 4 系統」 |
| `todo.md:36`（A-4） | ✅ ①②③④ |
| `todo.md:58`（依存グラフ）/ `todo.md:73`（完了条件） | ✅「変異 4 種」「4 変異」 |
| `test-cases.md:52`（AC-6 マッピング）/ `:365`（TC-A6d）/ `:422`（自動化可否） | ✅ |
| **`pbi-input.md:77`（AC-6 の検証手段）** | ❌ **TC-A6c までで止まっている** |

**加えて `plan.md:202-213`（Risks & Mitigations）に「範囲が広がる側の fail-open」の行が無い**。この failure mode は river-review が **major** と判定した新規リスク（閉じ `fi` のインデント誤りで範囲が次の桁 0 `fi` まで延び、TC-30/33 領域をゲート内と誤認する）であり、緩和策（TC-A6d / (1b) 排他アサーション）は plan 内の別節と test-cases に存在するが、**リスク表には転記されていない**。リスク表は「狭すぎて子で重い TC が残る」（= 逆方向）しか持たない。→ **minor WARN**（C1-PLAN-01 の指摘に含めず、下記「その他の指摘」に記載）。

### 5. 承認境界 → **クリーン**

- `git diff --name-only origin/main...8254837` = 5 ファイル、すべて `docs/working/TASK-1012/*.md`。**`approvals/` も `c3.json` も含まれない**
- AI が承認を発行する記述は 4 文書に存在しない。逆に `plan.md:414-427` は「AI は `approvals/c3.json` を書けない」ことを `scripts/check-approval-token-write.sh` の配線根拠込みで明記している
- 本レビュー自身も `review-self.md` のみを新規作成し、承認トークンを一切作成していない

### 6. plan の記述が exec で実際に動くか（行番号アンカーの鮮度）→ **全件 fresh・中核検査は実行して実証**

`tests/extras/ta-26-plugin-sync.sh`（805 行）に対して実測照合:

| plan/test-cases の主張 | 実測 | 判定 |
|---|---|---|
| 既存ゲート L62-68 / L67 | L64 コメント・L67 `if` | ✅ |
| TC-13 ゲート L293 | L293 `if` | ✅ |
| `_T26_AI_LOOP_REFS_REL` L388 | L388 | ✅ |
| `_t26_mk_ai_loop_guard_sandbox` L394 | L394 | ✅ |
| TC-20 L421 / `_t26_t20` L423 | L421 / L423 | ✅ |
| `_t26_mk_refs_guard_sandbox` L527（ゲート外） | L527 | ✅ |
| TC-26 L558 | L558 | ✅ |
| TC-35 L673 / 参照 L683 | L673 / L683 | ✅ |
| TC-36 L707 / 参照 L713 / `_t26_tgt36` L721 | L707 / L713 / L721 | ✅ |
| TC-30 L732 / TC-33 L743 | L732 / L743 | ✅ |
| ゲート内の参照はすべて 562〜713 | `grep -n _t26_mk_refs_guard_sandbox` → 562,563,579,580,594,595,609,626,627,650,683,713 | ✅ |
| `SIZE_OK_MAX_FILES = 2`（`arbiter.py:421`） | L421 | ✅ |
| `derive_loopspec`（`plan_package.py:188`） | L188 | ✅ |
| `plan_package.py:341` が c3_status を拒否 | `serialize_c3_prime` の raise を確認 | ✅ |
| HO 9 カテゴリ（`check-plan-hash.sh:124-134`） | L124-134 の case 文 = 9 行 | ✅ |
| `bin/plangate` 必須 5 点に `review-self.md` / c3.json は validate の前に write | L986 / L2422 → L2443 | ✅ |

**行番号アンカーの stale は 1 件も検出されなかった。**

> **表記ゆれ（info）**: ゲート B の予定範囲が `plan.md:41` と `test-cases.md:352` で **`558-731`**、それ以外（TC-A6a の使い方・実測表・TC-A6d 判定コマンド）では **`558-730`** と書かれている。実測では L730 が `fi`、L731 は空行なので**どちらでも内包/排他アサーションの結果は変わらない**（実行して確認済み）。実害なしだが 2 箇所の表記を揃えるのが望ましい。

## その他の指摘（check_id に紐付かないもの）

| # | severity | 内容 |
|---|----------|------|
| S-1 | minor | **Risks & Mitigations に「範囲が広がる側の fail-open」行が無い**（重点観点 4 参照）。river-review が major と判定した新規 failure mode がリスク表に転記されていない。緩和策自体は TC-A6d / (1b) として存在するため実害は小さいが、リスク表だけを見る読者はこの経路を知り得ない |
| S-2 | minor | **改訂番号ラベルが `改訂 10` のまま**。plan.md:6 / todo.md:3 / test-cases.md:3 がいずれも「改訂 10」だが、実体は river-review（R-010〜R-014）を `e22053e` で反映した後の**改訂 11 相当**（`grep -rn '改訂 11' docs/working/TASK-1012/` → **0 件**）。承認者が「改訂 10 を承認した」と記録した場合、実際に承認した内容と版番号が食い違う |
| S-3 | minor | **`plan.md:41`（C-1 R3 の台帳）が変異③の注入対象を `_t26_t20` のまま記載**している。この記述は後に C-2 R-002b で `_t26_tgt36` へ変更され、`todo.md:36` は「**`_t26_t20` に戻さない**」と明示的に警告している。台帳行は履歴なので誤りではないが、**注記が無いため台帳だけを参照した実行者が旧仕様を実装しうる**。`plan.md:56`（R-002 行）と `plan.md:149` に経緯があるので追跡は可能 |
| S-4 | info | **「1 回だけ確定反映」が 3 コミットに分かれている**（`16cd2a4` = R-001〜R-009 の R-003 以外 / `8216339` = R-003 / `e22053e` = R-010〜R-014）。`working-context.md`「C-2 指摘の差分管理」は反映を 1 回に限定するが、3 回はそれぞれ**別のレビュー事象**（C-2 / Human C-3 決定 / 独立 river-review）に対応しており、各コミットに `Refs: R-NNN` も付いている（実確認済み）。運用上は妥当。**ただし `c3.json` の `plan_hash` は必ず `8254837` 以降の plan.md に対して発行すること**（現時点で c3.json は未発行なので順序は守られている） |
| S-5 | info | **TC-A6a のシンボル越境検査は「範囲の和集合の外からの参照」だけを越境として数える**。したがって「ゲート A 内で定義 → ゲート B 内から参照」は越境として報告されない。本設計では**子プロセスで両ゲートとも skip されるため実行時の破綻は起きず**、この扱いは正しい。ヘルパー定義（L388 / L394 / L527）がゲート範囲へ飲み込まれるケースも同様に検出されないが、Constraints「ヘルパー定義を移動しない」＋ TC-INV（`git diff -w HEAD --`）で間接的に担保される。**設計上の穴ではないが、検査の意味論として handoff に残す価値がある** |

## 判定

**WARN**（critical=0 / major=0 / minor=7 / FAIL=0）

**C-3 に出せる状態である。**

- **FAIL は 0 件**。AC-6 の中核静的検査（TC-A6a）は verbatim 実行可能で、plan / test-cases が主張する実測値 4 行 + 変異③の 1 行が**すべて本レビューで再現**した。行番号アンカーの stale も 0 件。承認境界の逸脱も 0 件。
- WARN 7 件はいずれも **exec を止める性質のものではない**が、C1-SUP-PLAN-01（`tc-a6a.sh` の配置未定義）と C1-SUP-PLAN-02 / C1-TODO-08（タスク粒度と帯回避の非対称撤回）は **exec 中に実行者が判断を迫られる**ため、承認前に方針を決めるか handoff に送るかを明示すること。
- **本ファイルの発行により `bin/plangate approve TASK-1012` の `cmd_validate` 必須 5 点が揃う**（`pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` = 実在確認済み）。

## Human C-3 の判断事項（承認前に決めること）

| # | 判断事項 | 出所 | AI の立場 |
|---|---------|------|----------|
| **1** | **C-2 不足を許容して APPROVE するか、コードベース整合レーンを 1 本追加してから APPROVE するか** | plan「C-2 の充足判定」/ C-2 R-003 | AI は「不足」と判定済み。**充足と書き換えない**。本 C-1 の評価では「不足判定は安全側で妥当・やや保守的」（重点観点 3） |
| **2** | **brainstorm を「該当なし」として扱ってよいか** | high-risk では `○` 必須。plan は「R-407 で方式確定済みの派生 PBI・新規設計なし」を理由に該当なしとする | AI は単独で確定しない。**ただし本 C-1 は C1-B1B2-17（アプローチ比較なし）を WARN としており、判断 2 と判断 4 は連動する** |
| **3** | **exec を並列化しないことを承認するか** | high-risk では `TDD + 並列`。plan は A-1〜A-6 が全て直列依存であることを理由に非並列とする | 本 C-1 は依存グラフを検証し**並列化の余地が無いことに同意**（C1-PLAN-06 PASS）。意図的逸脱として承認すれば足りる |
| **4** | **アプローチ比較（2 案以上）が無いまま進めてよいか** | 本 C-1 の C1-B1B2-17 = WARN（新規指摘） | 代替案（#1011 / #914 diff 外の最適化）は**本 PBI の恒久コスト＝子プロセスのカバレッジ縮小を伴わない**。「なぜ先にこれを採るか」が未記載のため、C-4 の受け入れ判断材料が 1 つ欠けている |
| **5** | **タスク統合（11 → 6）の帯回避動機を撤回しないままでよいか** | 本 C-1 の C1-SUP-PLAN-02 / C1-TODO-08 = WARN（新規指摘） | 改訂 10 は AC の帯回避のみを撤回し、**同クラスのタスク統合は撤回していない**。Mode 判定の結論は変わらないが、撤回の一貫性として決着が要る |
| （参考） | AC-5 が WARN で確定した場合の「カバレッジ縮小を受け入れるか」は **C-4（H-1）で判断**する設計になっている（C-2 R-004） | todo `H-1` / TC-A5 | この設計自体は妥当。C-3 では「C-4 に委ねる設計でよいか」だけを確認すればよい |

## 実行した検証コマンドと exit code

| # | コマンド | rc | 結果 |
|---|---------|----|------|
| 1 | `git diff --name-only origin/main...82548375` | 0 | 5 ファイル・すべて `docs/working/TASK-1012/*.md`・`approvals/` 無し |
| 2 | `git diff --stat origin/main...82548375 -- docs/working/TASK-1012/` | 0 | 5 files changed, 1249 insertions |
| 3 | `grep -nE '^[[:space:]]*# TC-(20\|25\|26\|30\|33\|35\|36):' tests/extras/ta-26-plugin-sync.sh` | 0 | 421 / 499 / 558 / 673 / 707 / 732 / 743（plan と一致） |
| 4 | `grep -n 'PG_T26_NO_RECURSE' tests/extras/ta-26-plugin-sync.sh` | 0 | 既存ゲート L67 / L293 を確認 |
| 5 | `sed -n '388p;394p;423p;527p;721p' tests/extras/ta-26-plugin-sync.sh` | 0 | 4 つの定義行が plan の主張どおり |
| 6 | `grep -n '_t26_mk_refs_guard_sandbox' …` | 0 | 定義 L527 / 参照 562-713（全 12 箇所） |
| 7 | `sh tc-a6a.sh "421-521" "558-730"`（test-cases.md:234-316 を verbatim 抽出） | **0** | `containment_violations=0` / `identifiers=77 crossings=0` — **test-cases の実測表と完全一致** |
| 8 | `sh tc-a6a.sh "421-521" "558-700"` | **1** | `OUT-OF-RANGE gate B: TC-36 at L707 not in 558-700` — 一致 |
| 9 | `sh tc-a6a.sh "421-521" "558-741"` | **1** | `IN-RANGE gate B: TC-30 at L732 is inside 558-741` — 一致（(1b) 有効） |
| 10 | `sh tc-a6a.sh "421-521" "558-791"` | **1** | `IN-RANGE` 2 件 / `containment_violations=2` — 一致 |
| 11 | 変異③再現（scratchpad の複製へ `: "$_t26_tgt36"` を追記して 7 を再実行） | **1** | `CROSS _t26_tgt36 (def L721) <- L806` / `identifiers=77 crossings=1` — **test-cases.md:328 と完全一致** |
| 12 | `python3 -c` で `Verification Automation:` を `re.search` 抽出 | 0 | plan.md:151 の記載と完全一致（fail-open 未再発） |
| 13 | `sed -n '149,163p' .claude/rules/mode-classification.md` | 0 | 中→高 の差分が **ちょうど 4 行**であることを列単位で確認 |
| 14 | `sed -n '124,134p' scripts/hooks/check-plan-hash.sh` | 0 | HO 9 カテゴリ・`tests/` は非該当 |
| 15 | `grep -n 'SIZE_OK_MAX_FILES' scripts/ai-loop/arbiter.py` | 0 | L421 = 2 |
| 16 | `grep -n 'def derive_loopspec' scripts/ai-loop/plan_package.py` | 0 | L188 |
| 17 | `sed -n '960,1010p' bin/plangate` / `sed -n '2400,2450p' bin/plangate` | 0 | 必須 5 点に `review-self.md` / c3.json は validate の前に write |
| 18 | `grep -niE 'stop condition\|replan\|停止条件\|再計画' plan.md todo.md` | 1 | **0 件**（C1-PLAN-08/09-AEE を WARN とした根拠） |
| 19 | `grep -nE 'TBD\|TODO\|後で実装\|必要に応じて\|適切に\|いい感じ' plan.md todo.md test-cases.md` | 0 | 見出し `# EXECUTION TODO` の 1 件のみ（曖昧表現 0 件） |
| 20 | `grep -rn '改訂 11' docs/working/TASK-1012/` | 1 | **0 件**（S-2 の根拠） |
| 21 | `git log --format='%H%n%B' -3 82548375` | 0 | `Refs: R-NNN` が各反映コミットに付与されていることを確認 |

**変異検証用の複製はスクラッチパッド配下で行い、リポジトリ内のファイルは一切変更していない**（新規作成した `review-self.md` を除く）。

## 確認不能だった項目（推測で埋めていない箇所）

| # | 項目 | 理由 |
|---|------|------|
| 1 | **`sh tests/extras/ta-26-plugin-sync.sh` / `sh tests/run-tests.sh` の実走** | 実行に数十秒〜数分かかり、sandbox 実行を伴うため本レビューでは**実行していない**。したがって TC-A1a / A1b / A1c / A2a / A3 / A4 / A5 の**期待値そのものは未検証**（判定式の構文的妥当性と、test-cases に記載された過去実測の内部整合のみを確認した）。**「ログに対して実行して確認済み」という test-cases の記述を、本レビューは独立に再現していない** |
| 2 | **AC-5 の実行時間短縮（≈40%）の再現性** | 未測定。参考値が TC-35/36 追加前の tree のものである旨は plan に明記されており、その限界表明自体は妥当と評価した |
| 3 | **C-1 ラウンド 1〜9（計 55 件）の各指摘と反映の対応** | `review-self.md` が存在しなかったため**照合不能**。plan の改訂記述と脚注を引用したのみで、**各ラウンドの結論を本 C-1 の判定として採用していない** |
| 4 | **変異①②（条件反転 / ゲート B 終端の縮小）の検出力** | 実装（ゲート A / B）が未適用のため実証不能。C-2 レビュアーが論理的に成立と判定した記録があるが、本 C-1 は**独立に再現していない**。実証は exec 時の A-4 に委ねる |
| 5 | **変異③が「範囲打ち切り時に空振りする」という主張** | `_t26_tgt36`（L721）を含む正常範囲での検出（`crossings=1`）は再現したが、**打ち切られた範囲での空振りは未実行**。ただしこの場合 (1) 内包アサーションが先に `OUT-OF-RANGE` で rc=1 を返すため、二重検出という plan の主張は構造上成立する（コードを読んで確認） |
