# EXECUTION TODO — TASK-1165 (#1165 / PBI-B)

> Mode: **critical** → 実装タスクは `rollback:` **必須**。
> 順序制約: **H-00 → T-00（plan → C-1 → C-2）→ H-01（C-3 / D-1 / D-4）→ B-1 → B-2 → B-3 → 完了**。
> L-0 / V-1〜V-4 / **PR 作成（commit / push を含む）** は `workflow-conductor` が自動制御する
> ため本 ToDo には含めない。
>
> **実装タスク数**: T-01〜T-15 の **15**（`H-*` と `T-00*` はワークフロー工程であり
> 実装タスクとして数えない。pbi-input の Mode 判定の「タスク数（見込み）」と一致）。
>
> **前提**: 本 PBI は **#1162 が main にマージ済み**であることを前提とする（T-01 で実測確認。
> 未マージなら着手しない＝即停止条件）。これは**技術的な必須依存ではなく**、
> 両 PBI がともに `tests/extras/ta-57-pr-convergence.sh` を改変するための**衝突回避の順序制約**
> （C-01 の是正で B-3 が `delivery.py` に触れなくなり、必須依存は解消された）。

## 👤 Human タスク（起点）

- [ ] **H-00**（**すべての起点** / env 設定）`PLANGATE_HOOK_TASK=TASK-1165` を設定した状態で
  セッションを起動する
  - ⚠️ `PLANGATE_HOOK_TASK` は**セッション起動時に固定**され、**実行中の `export` では効かない**
    （実測）。未設定だと EH-3（`scripts/hooks/check-plan-hash.sh`）が `plan.md` の新規作成を
    **rc=2 で BLOCK** する
  - ⚠️ **AI は自セッションの起動時 env を設定できない**ため本タスクは Owner=human 固定
  - 完了条件: 起動後のセッションで `printenv PLANGATE_HOOK_TASK` が `TASK-1165` を返す
  - depends_on: なし / Owner: **human**

## 🤖 Agent タスク

### T-00: Plan Package の確定（**すべての実装タスクの前**）

- [ ] **T-00a** `plan.md` を生成する
  - 記載必須: Goal / Constraints / Non-goals / Approach / Work Breakdown /
    Files to Touch / Testing Strategy / Risks & Mitigations / Questions / Mode 判定
  - 記載必須（本 PBI 固有）:
    - **AC-04 の運用解釈**（集約対象は**凍結対象外の 7 箇所** / 据え置き 3 箇所と理由 /
      「10/10 集約」と書かない）
    - **AC-06 / AC-07 の運用解釈**（skill ディレクトリ全体コピー / **実行モジュール総数 ≠ 0** /
      時間予算 1,800 秒 / **変更後・baseline のどちらが TIMEOUT でも WARN＝未検証**）
    - **B-1 の判定手段の確定**（`git diff --numstat` の削除カラム 0 / U-03 の実測結果）
    - **U-01: `read_json()` のシグネチャ**（T-02 の一覧に基づく最大公約数）
    - **U-05: `discovery.py` の据え置き判断**（D-3）
    - ⚠️ **B-1 / B-2 の設計案と B-3 のスコープ（7 箇所）は issue #1165 本文・起票者コメントで
      確定済み**（A-02 / A-03 / A-12）。plan で別案へ差し替えない
  - depends_on: **H-00** / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1165/plan.md`（未 commit なら削除）
- [ ] **T-00b** C-1 セルフレビュー（17 項目）を実施し `review-self.md` を出力
  - 🚩 判定が FAIL なら plan を修正して再実行。**PASS / WARN になるまで C-3 へ上げない**
  - depends_on: T-00a / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1165/review-self.md`
- [ ] **T-00c** C-2 外部 AI レビュー（**複数観点** / critical mode で必須）→ `review-external.md`
  - 指摘は `R-NNN` で採番。**指摘ゼロでも「指摘なし」を明示記録**する
  - 実行不可（CLI 未導入 / quota 超過等）の場合は `unavailable` として理由・代替観点・
    未充足リスクを記録する（空欄にしない）
  - 反映は **1 回だけ確定**（反映コミットに `Refs: R-NNN`）→ 簡易 C-1 再実行 →
    その**後**で人間が `c3.json` を発行
  - depends_on: T-00b / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1165/review-external.md`

> **⛔ ここで H-01（C-3 / D-1 / D-4）を通すまで、以降のタスクに着手しない。**
> **D-1 が REJECT なら本 PBI を取り下げる**（B-3 が構造的に実行不能になるため）。

### 準備

- [ ] **T-01** 前提検査 ＋ 変更前 baseline の実測 ＋ **extras 起動 harness の作成**
  - **前提検査（最初に行う）**: `git log origin/main` および
    `git show origin/main:tests/extras/ta-57-pr-convergence.sh | sed -n '620,625p'` で
    **#1162 がマージ済み**（`-ge 57` になっていること）を実測確認する。未マージなら
    **即停止**（R-10。理由は衝突回避であり AC の達成不能ではない）
  - **harness の要件**（sandbox 内に作る。`tests/` 原本には追加しない）:
    1. `pass=0` / `fail=0` を初期化する
    2. **`FIXTURES_DIR="$SBX/tests/fixtures"` を定義**する
       （`ta-57:36` が `$FIXTURES_DIR/../..` で repo root を導出。**`$0` 由来ではない**）
    3. **`register_cleanup()` を定義**する（**実呼び出しは `ta-57:45` のみ**。`:32` と `:667` は
       コメント行。未定義だと `:45` で `command not found` となり以降が壊れる）
    4. 対象スイートを **`.`（source）**で読み込む
    5. 末尾で **`pass` / `fail` の最終値を 1 行で出力**する
       （例: `printf 'HARNESS_SUMMARY pass=%s fail=%s\n' "$pass" "$fail"`）。
       `ta-57` は集計値を自分では出力しないため、**この出力が無いと
       「`pass` / `fail` の集計値が不変」という受理条件（PBIB-03 / 04）を観測できない**
    6. 末尾で `[ "$fail" -eq 0 ] || exit 1`（**判定には使わない**）
  - **baseline 内容**:
    - `ta-57` の TC ごとの PASS / FAIL / WARN 一覧（test-cases P-1 の判定規則で取得。
      **`> log 2>&1` 必須**）＋ `HARNESS_SUMMARY` の `pass` / `fail` 値
    - **plugin 側 baseline（AC-06）**: `plugin/plangate/skills/ai-loop-cycle/` を
      **skill ディレクトリ全体で** `$SBX` へコピーし、その中で `python3 scripts/test_*.py` を
      全実行 → **FAIL モジュール集合**と **実行されたモジュール総数**を記録する
      （⚠️ `scripts/` のみのコピーは不可。`test_arbiter.py` が
      `../references/ho-paths.md` を解決できず追加 FAIL する）
      （⚠️ **総数が 0 なら baseline として無効**。1 本も起動していない状態では
      「FAIL 集合が増えない」が恒真になる。総数 0 なら手順の誤りとして即座に原因を調べる）
    - `sh tests/run-tests.sh` の pass 件数（**timeout 1,800 秒**）
  - ⚠️ **baseline が TIMEOUT（rc=124）した場合**: `TIMEOUT`＝未検証として記録し、
    AC-07 は最終的に **WARN** とする（R-09）
  - 🚩 baseline は**測定日時・ホスト・HEAD SHA とセット**で `evidence/baseline/` に記録し、
    **FAIL モジュールの名指しリストを AC の契約にしない**（実測結果として扱う / U-04）
  - depends_on: H-01 / Owner: agent / rollback: 不要（読取のみ。harness は sandbox 内）
- [ ] **T-02** JSON 読込 **7 箇所**（集約対象）の呼び出し文脈を一覧化（例外型 / メッセージ /
  encoding / 後続の型検査 / fail-closed の有無）
  - 対象: `run_evidence.py:243,357,411` / `run_evidence_verify.py:93,285,418` /
    `discovery.py:182+186`（2 行形式）
  - **除外の再確認**（pbi-input の除外表と一致することを確認するだけ。手を入れない）:
    - **凍結維持のため据え置き（B-3 のスコープ限定 / D-4）**:
      `delivery.py:538,540` / `c3prime_verify.py:56`
    - **採用基準外**: `arbiter.py:1160-1169`（**CLI/stdin 兼用 ＋ 層契約により arbiter は
      I/O 層に触れない**）/ `delivery.py:461`（NDJSON 行）/
      `run_evidence.py:639,658,676`（CLI 引数文字列）/
      `executor.py:448`・`gh_exec.py:670`（subprocess 出力）
  - 🚩 `read_json()` の**シグネチャ**（U-01）と、**寄せられない箇所**（U-02）を先に確定させる。
    無理に統一しない
  - 🚩 **`discovery.py` の据え置き判断（U-05 / D-3）**: plugin 非配布かつ `sys.path` bootstrap
    を持たないため、集約すると**新しい import 経路の新設**を伴う。**据え置きが既定**。
    含める判断をする場合は人間へ上げる
  - depends_on: T-01 / Owner: agent / rollback: 不要（読取のみ）
- [ ] **T-03** `decision-log.jsonl` を初期化し、C-3 で確定した D-1〜D-4 の判断を追記
  - ⚠️ 本 PBI 開始時点で `docs/working/TASK-1165/decision-log.jsonl` は**存在しない**（実測）。
    **初期化と追記を本タスク内で連続実行**する（初期化タスクを別に切らない）
  - 以降の判断（U-01 のシグネチャ / U-02 の据え置き / 変異の空振り）も本ファイルへ append する
  - depends_on: **H-01**（C-3 の判断結果が入力）/ Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1165/decision-log.jsonl`（未 commit なら削除）

### 実装（B-1: TC-14 凍結の射程限定）

- [ ] **T-04**（RED / 前提の実測）現行 TC-14 が **B-3 相当の変更で FAIL する**ことを実証し、
  `git diff --numstat` の出力形を確認
  - 🚩 `$SBX/scripts/ai-loop/c3_contract.py` に後方互換な関数を 1 本足した sandbox で、
    現行 `ta-57` TC-14 が **FAIL** すること（＝これが B-3 を構造的にブロックしている実証）
  - 🚩 sandbox には **HEAD と異なる `main`** を用意する（fixture）。base ref が無い /
    HEAD と同一だと TC-14 は `[WARN]` 経路へ落ち**検証されない**
  - 🚩 **U-03 の実測**: `git diff --numstat "$base" -- <file>` の出力形（`added deleted path`）
    と、rename / mode 変更 / binary で非数値（`-`）が出る条件を確認する
  - ⚠️ sandbox は `mktemp -d` 複製。原本には**書き込まない**（A-04）。終了時に明示削除
  - depends_on: T-01 / Owner: agent
  - rollback: 不要（tmp のみ。原本不変）
- [ ] **T-05**（GREEN / B-1）`ta-57` TC-14 の凍結を**射程を限定した不変条件**へ置換
  - 実装内容（**issue #1165 本文で確定済み。別案へ差し替えない**）:
    - `_t57_ac7_files`（`:568`）から **`c3_contract.py` を外す**（`delivery.py` /
      `c3prime_verify.py` はファイル単位 0 行差分のまま維持）
    - `c3_contract.py` は **`git diff --numstat` の削除カラムが 0**（追加のみ）を検査する
  - ⚠️ **定数単位（`STATES` / `TRANSITIONS` / `PRIORITY_ORDER`）の差分ゼロへ戻すことは禁止**
    （TASK-0917 R-006 の指摘を無効化する退行 / R-01）
  - 🚩 FAIL / PASS メッセージの書式は `t57_fail` / `t57_pass` 経由を維持する
    （判定規則 P-1 が `^ *\[FAIL\] TC-14` / `^ *\[PASS\] TC-14` に依存するため）
  - 🚩 `sh -n tests/extras/ta-57-pr-convergence.sh` 通過
  - depends_on: T-04 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-57-pr-convergence.sh`
- [ ] **T-06**（変異 / AC-02）負側変異 **4 種すべて**を注入し、`ta-57` TC-14 が FAIL する
  ことを実証
  - 4 種: (1) `delivery.py` の `STATES` / `TRANSITIONS` / `PRIORITY_ORDER` の変更
    （**3 定数それぞれで 1 件ずつ**注入する / M-1・M-9・M-10）/
    (2) `delivery.py` の `assess()` への**後方互換な分岐追加** /
    (3) `c3_contract.py` の**既存行の削除・改変** /
    (4) `c3prime_verify.py` の変更（exit code 契約の緩和を含む）
  - 🚩 **(2) が最重要**。TASK-0917 R-006 は「定数単位では後方互換な分岐を足しても鳴らない」
    と指摘してファイル単位へ強化した。**(2) を kill できない案は R-006 の退行であり採用しない**
  - 🚩 各変異について「変異適用 → **`ta-57` TC-14 が FAIL**」→「復元 → **PASS に戻る**」の
    2 点を確認する
  - 🚩 空振り（FAIL しない）なら**即停止して人間判断**（R-01 / R-13）
  - depends_on: T-05 / Owner: agent
  - rollback: 不要（sandbox コピーのみ。原本不変）

### 実装（B-2: `[WARN]` スキップの可視化）

- [ ] **T-07**（GREEN / B-2 + AC-03 検証）`ta-57:600-605` の `[WARN]` ブロックで
  **stdout に `[UNVERIFIED] TC-14 ...` を 1 行**出すようにし、3 環境で検証する
  - ⚠️ **採用案は (a) で確定**（A-03）。(b) 第 3 集計（`tests/run-tests.sh` の改変が必要 =
    Files to Touch 外）/ (c) `PG_STRICT=1` 時のみ FAIL（**既定 run の出力が変わらず AC-03 を
    満たさない**）は採らない
  - ⚠️ 既存の `[WARN]` 4 行（`:601-604` / stderr）は**削除しない**（情報量を減らさない）
  - ⚠️ `tests/run-tests.sh` の 2 値サマリは**改変しない**
  - 🚩 検証環境 1: **base ref 不在**（`origin/main` も `main` も無い shallow な sandbox）
  - 🚩 検証環境 2: **base ref == HEAD**（`main` を HEAD と同一 SHA にした sandbox / fixture）
  - 🚩 いずれの環境でも **stdout に `[UNVERIFIED] TC-14`** が出ること、かつ
    **harness の `HARNESS_SUMMARY` が示す `pass` / `fail` の集計値が変更前後で不変**であること
    （T-01 の harness 要件 5 が観測手段）
  - 🚩 検証環境 3: **base ref ≠ HEAD**（通常）では `[UNVERIFIED]` が**出ない**こと
  - depends_on: T-06 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-57-pr-convergence.sh`

### 実装（B-3: JSON 読込の単一定義化 / 凍結対象外 7 箇所）

- [ ] **T-08** `scripts/ai-loop/c3_contract.py` に `read_json(path)` を追加
  - ⚠️ **新規ファイルを作らない**（`sync-plugin-plangate.sh:428/440` の二重 allowlist に
    載らず plugin 側だけ import エラーになるため）
  - ⚠️ **層区分の docstring（`c3_contract.py:7-14`）を更新**し、`read_json` が
    **I/O あり関数**であることを明記する（arbiter は import / call しない）
  - 🚩 シグネチャは T-02 の一覧から**最大公約数**を採る（U-01）。fail-closed を壊さない
  - 🚩 **純粋な追加**にする（既存行の削除・改変を伴わない）。`c3_contract.py` に既存の
    `json.loads` は無い（実測: `git grep -n 'json\.loads' origin/main --
    scripts/ai-loop/c3_contract.py` = 0 ヒット）ため、削除行 0 は成立する
  - depends_on: T-02, T-07 / Owner: agent
  - rollback: `git checkout -- scripts/ai-loop/c3_contract.py`
- [ ] **T-09** `test_c3_contract.py` を更新（`read_json()` の単体テスト ＋ **層契約 assert の拡張**）
  - 単体テスト: 正常 / 不正 JSON / 不存在 / 権限不可 / 非 UTF-8 / 空 / ディレクトリ
  - 🚩 例外の**型とメッセージ**まで assert する（R-03）
  - 🚩 **AC-05**: `test_arbiter_does_not_touch_io_layer` の assert 対象に **`read_json` を追加**する。
    現行は AST の `node.attr` / `node.id` を **`"sha256_of_file"` とだけ**比較しており、
    **新関数には効かない**（本セッションで一次照合済み）
  - 🚩 AC-05 の実証: **arbiter が `read_json` を参照する変異**を入れて当該テストが FAIL する
    ことを確認する（追加しただけで発火しないと意味がない）
  - depends_on: T-08 / Owner: agent
  - rollback: `git checkout -- scripts/ai-loop/test_c3_contract.py`
- [ ] **T-10** **7 箇所**の呼び出しを**1 箇所ずつ**置換し、そのつど挙動不変を確認
  - 順序: `run_evidence.py`(3) → `run_evidence_verify.py`(3) → `discovery.py`(1, 2 行形式)
  - ⚠️ **`delivery.py`(2) と `c3prime_verify.py`(1) は置換対象に含めない**（B-1 で凍結を
    維持すると決めたファイル。置換すると TC-14 が必ず FAIL する / D-4）。
    **これらのファイルの差分が 0 行であること**を各ステップ後に `git diff --stat` で確認する
  - 🚩 各置換後に当該ファイルのテストを実行し rc=0。例外型・メッセージ・rc の対比表を
    `evidence/b3-behavior-parity/` へ
  - 🚩 **置換箇所数が 0 でないこと**を対比表から確認する（対比表が空でも「挙動同一」は
    形式的に成立してしまうため / test-cases P-1 受理条件 5）
  - ⚠️ `discovery.py:180-191` は `OSError` と `JSONDecodeError` を**別メッセージ**で
    `ValueError` に包み直し、`path.is_file()` 事前検査と `isinstance(data, list)` 事後検査を
    持つ。加えて **plugin 非配布 ＋ `sys.path` bootstrap なし**（U-05）。最後に扱い、
    差異が吸収できなければ**据え置く**（据え置き理由を `decision-log.jsonl` へ）
  - depends_on: T-09 / Owner: agent
  - rollback: `git checkout -- scripts/ai-loop/<該当ファイル>`（1 ファイル単位で戻せる）
- [ ] **T-11**（変異 / AC-04）`read_json()` の**呼び出し箇所**に変異を注入し、既存テストが
  kill することを実証
  - 変異例: 呼び出しを `try/except: pass` で囲む / 引数のパスを別の実在ファイルへ差し替える /
    呼び出しを除去して固定 dict `{}` を返す / 包み直しメッセージ文字列を変更する
  - 🚩 kill されない変異があれば「その挙動は未検証」と正直に記録し、TC を足すか据え置きを判断
  - depends_on: T-10 / Owner: agent
  - rollback: 不要（sandbox コピーのみ）

### 検証

- [ ] **T-12** plugin 同期と **skill ディレクトリ全体コピーでのテスト実行**（AC-06）
  - 手順:
    1. `sh scripts/sync-plugin-plangate.sh --dry-run` で差分を確認 → 同期 → 再度
       `--dry-run` で**差分 0**
    2. plugin 側 `*.py` の basename 集合が `sync-plugin-plangate.sh:428` の `for` 集合と**一致**
       （for/case の集合一致は既存 `ta-57` TC-E8（`:641-665`）が検査するため**再実装しない**）
    3. `plugin/plangate/skills/ai-loop-cycle/` を **skill ディレクトリ全体で** `$SBX` へコピーし、
       その中で `python3 scripts/test_*.py` を全実行
  - ⚠️ **判定は 2 点**: (a) **T-01 baseline の FAIL モジュール集合から増えていない** かつ
    (b) **実行されたモジュール総数が baseline と同数以上**（総数 0 / 大幅減で
    「FAIL 集合が増えない」が恒真になるのを排除する）
  - ⚠️ 「全 PASS」は達成不能（baseline に repo コンテキスト依存の FAIL が含まれる）
  - ⚠️ **plugin 配布 `.py` の件数を契約にしない**（`ls <dir> \| wc -l` は `__pycache__` を含む）。
    配布集合の判定は `--dry-run` 差分 0 と `:428` の for 集合一致で行う
    （実行モジュール**総数**の下限比較は上記 (b) の恒真 PASS 排除のための別目的）
  - ⚠️ **baseline と同一のコピー範囲**（skill ディレクトリ全体）で測る。範囲が違うと
    FAIL 本数が変わり比較にならない（R-06）
  - ⚠️ plugin 側は同期生成物。**直接編集しない**（A-07）
  - depends_on: T-11 / Owner: agent
  - rollback: `git checkout -- plugin/plangate/skills/ai-loop-cycle/`
- [ ] **T-13** 個別スイート → フルスイートの順で実行し AC-07 を確認
  - 個別: T-01 の harness 経由で `ta-57` を実行し、**該当 TC の `[FAIL]` 行が 0 件かつ
    `[PASS]` 行が存在**（rc を判定根拠にしない / `> log 2>&1` 必須）
  - フル: `sh tests/run-tests.sh` を **timeout 1,800 秒**で 1 回実行し、
    **T-01 baseline の pass 件数以上**で exit 0
  - ⚠️ **変更後・baseline のどちらが TIMEOUT（rc=124）でも AC-07 は WARN（未検証）**とし、
    「PASS」と書かない。個別スイート結果で代替判定した旨と未検証範囲を `handoff.md` に明示（R-09）
  - ⚠️ 件数は**下限比較**（絶対値契約にしない）
  - depends_on: T-12 / Owner: agent
  - rollback: 不要（検証のみ）

### 完了

- [ ] **T-14** `handoff.md` を作成（必須 6 要素 + 本 PBI 固有の記録）
  - 必須 6 要素: 要件適合確認（AC-01〜AC-07 ごとに PASS / FAIL / WARN）/ 既知課題 /
    V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果サマリ
  - 本 PBI 固有の記録必須項目:
    1. **`c3_contract.py` は「削除行 0（追加のみ）」へ緩和した**こと、および
       **既存関数内への行追加は通る**という残存リスク（R-02）。
       「凍結が維持されている」とは書かない
    2. **R-006 の「ファイル単位」強化が 3 ファイル中 2 ファイルで温存された**こと
    3. **B-3 のスコープを 7 箇所へ限定したこと**と、**据え置いた 3 箇所を
       「凍結解除時の後続候補」として明記**する（`delivery.py:538` / `delivery.py:540` /
       `c3prime_verify.py:56`。据え置き理由 = B-1 の凍結維持と両立しないため）。
       **「10/10 集約」とは書かない**（R-14）
    4. **`arbiter.py:1169` を据え置いた 2 つの理由**（CLI/stdin 兼用 ＋ 層契約）と、
       `discovery.py` の据え置き可否（U-05 / D-3）の結論
    5. **AC-06 の baseline の測定条件**（skill ディレクトリ全体コピー / 実行モジュール総数 /
       日時・ホスト・HEAD SHA）
    6. **AC-07 が TIMEOUT だった場合の未検証範囲**（R-09）
    7. **変異の空振り**があればその一覧（R-13）
    8. **`[UNVERIFIED]` 行の運用**（CI で拾う方法・将来の集計化は V2）
  - V2 候補: **据え置き 3 箇所の集約（凍結解除が前提）** /
    `sync-plugin-plangate.sh` 二重 allowlist の単一定義化 /
    `[UNVERIFIED]` の第 3 集計化（#1124 と連携）/ `arbiter.py:1169` の扱い /
    `discovery.py` の配布・import 経路の整理
  - depends_on: T-13 / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1165/handoff.md`（未 commit なら削除）
- [ ] **T-15** `status.md` を更新（フェーズ履歴を `YYYY-MM-DD HH:mm` 形式で追記）
  - 記載: C-3 判断結果（D-1〜D-4）/ B-1 / B-2 / B-3 の完了状況 / 計画からの変更点 /
    V 系進捗 / **#1162 との順序制約の充足状況**
  - ⚠️ **`plan.md` は編集しない**（C-3 承認後の編集は `plan_hash` を無効化する）
  - depends_on: T-14 / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1165/status.md`

## 👤 Human タスク（ゲート）

- [ ] **H-01**（C-3 ゲート / exec 前）plan / todo / test-cases / review-self / review-external を
  レビューし三値判断
  - ⚠️ Mode = **critical** のため **autonomous APPROVE 不可**。人間の C-3 が必須
  - **本ゲートで確定すべき論点**:
    - **D-1**: `ta-57` TC-14 の凍結契約を改訂してよいか（**REJECT なら本 PBI を取り下げる**）
    - **D-2**: `c3_contract.py` を「削除行 0（追加のみ）」へ緩和することを許容するか
    - **D-3**: `discovery.py` を集約対象に含めるか（AI 推奨: 据え置き）
    - **D-4**: B-3 のスコープを**凍結対象外 7 箇所**へ限定することを許容するか
      （AI 推奨: 限定する。起票者コメントで確定済み）
  - 承認時は `approvals/c3.json`（`c3_status=APPROVED` ＋ **確定後 plan の `plan_hash`**）を発行
  - ⚠️ **発行は確定反映の後**（先に発行すると後続の plan 編集を EH-3 が mismatch 検知する）
  - depends_on: T-00c / Owner: human
- [ ] **H-02**（C-4 ゲート / PR レビュー）GitHub 上で APPROVE / REQUEST CHANGES / REJECT
  - ⚠️ **merge は Human-owned 固定**（AI は merge しない）
  - depends_on: T-15（PR 作成は workflow-conductor が実施）/ Owner: human

## ⚠️ 依存関係

| 依存 | 内容 |
|------|------|
| **#1162 のマージ → 本 PBI 全体** | **技術的な必須依存ではない**（B-3 のスコープ限定で `test_delivery.py` を触らなくなった）。両者がともに `ta-57-pr-convergence.sh` を改変するため、**衝突回避の順序制約**として維持。T-01 で実測確認する |
| **H-00 → T-00a** | `PLANGATE_HOOK_TASK` はセッション起動時固定。AI は自セッションの env を設定できない |
| **T-00 → H-01** | plan / C-1 / C-2 の確定なしに C-3 は判断できない |
| **D-1 → 本 PBI 全体** | D-1 が REJECT なら B-1 を実施できず、B-3 も構造的に実行不能。**PBI を取り下げる** |
| **D-4 → T-02 / T-10** | 集約対象の範囲（7 箇所）が確定しないと呼び出し文脈の一覧化・置換に着手できない |
| **H-01 → T-01 / T-03** | C-3 APPROVED 前に baseline 取得・decision-log 追記へ進まない |
| **T-04 → T-05 → T-06** | RED（現行 TC-14 が B-3 相当をブロックする実証）→ 置換 → 4 種変異の kill 実証 |
| **B-1（T-05） → B-3（T-08〜）** | 凍結の射程を限定する前に `c3_contract.py` を触ると TC-14 が FAIL する |
| **T-01 → T-07** | `[UNVERIFIED]` 追加時の「集計値不変」は harness の `HARNESS_SUMMARY` 出力でのみ観測できる |
| **T-02 → T-08** | `read_json()` のシグネチャは 7 箇所の文脈一覧なしに決めない |
| **T-08 → T-09** | 層契約 assert の拡張は `read_json` が存在してから |
| **T-11 → T-12** | plugin 同期は本体側の変更が確定してから |
| **T-01 → T-12** | plugin baseline（skill 全体コピー / 実行モジュール総数）なしに AC-06 は判定不能 |
| **Agent → Human（C-4）** | PR 作成後、H-02 の APPROVE なしに merge しない |

## 即停止条件

- **D-1 が C-3 で REJECT** された → B-1 を実施できず B-3 も実行不能。**本 PBI を取り下げ**、
  理由を `handoff.md` と `decision-log.jsonl` に記録して停止する
- **#1162 が main に未マージ**（T-01 の前提検査）→ **即停止**（衝突回避の順序制約）
- **AC-02 の 4 種変異のいずれかが kill されない** → その案を採らず、代替案がなければ
  **即停止して人間判断**（とくに `assess()` への分岐追加 = R-006 の退行検出 / R-01）
- **凍結維持 2 ファイル（`delivery.py` / `c3prime_verify.py`）に差分が入った** →
  **即停止**（B-3 のスコープ逸脱。TC-14 が必ず FAIL する）
- **plugin baseline の実行モジュール総数が 0** → **即停止**（測り方の誤り。この状態の
  AC-06 は恒真 PASS になる）
- HO 対象パス（`.claude/**` / `scripts/hooks/**` / `bin/plangate` / `schemas/**` /
  `.github/workflows/**` / `CLAUDE.md` / `AGENTS.md`）の編集が必要になった → **即停止**
- 外部振る舞い（CLI IF / exit code 契約 / hook 挙動 / schema）を変える必要が生じた →
  **即停止**（A-06）
- 判定規則（P-1）が対象スイートで成立しない（`[PASS]` 行も `[FAIL]` 行も出ない等）→
  **即停止**。判定できない状態で PASS と記録しない
- C-3 承認後に plan の変更が必要になった → **即停止**。plan を書き換えず再承認を仰ぐ
- hook（EH-3 等）に block された → **迂回せず報告して停止**
