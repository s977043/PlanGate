# テストケース定義 — TASK-0981（#981 PR1）

> Plan: [`plan.md`](./plan.md) / ToDo: [`todo.md`](./todo.md) / 入力: [`pbi-input.md`](./pbi-input.md)
> 基点: main `7de7baa`。baseline `sh tests/run-tests.sh` = **514 passed / 0 failed**（本ブランチで 4 回連続実測。**判定は絶対値ではなく PR 前後の同一性**で行う — 下記 TC-16 注記）
> **PR1 は文書のみの変更**（コードを 1 行も変更しない）。したがって全 TC は **成果物の構造検査 / 根拠の実測再現 / 既存 baseline との同一性確認** のいずれかであり、新規のコードテストは追加しない
> 検査対象 ADR: `docs/decisions/adr-002-plan-contract-canonical-source.md`（以下 `<ADR>` と表記）
> **番号空間**: 本ファイルの `TC-NN` / `EDGE-N` は、pbi-input のギャップ `#1`〜`#12` および実行条件 `EC-1`〜`EC-10` とは別空間

## 受入基準 → テストケース マッピング

| AC | 内容 | 対応 TC | 種別 |
|----|------|---------|------|
| **AC-1** | 追加実装対象が「未対応差分」だけに限定されている | TC-04, TC-05, TC-06 | 静的検査（成果物構造） |
| **AC-2** | 正本が 1 つに決まっている | TC-07, TC-08 | 静的検査（成果物構造） |
| **AC-3** | 新規 schema 追加の必要性が説明されている | TC-09, TC-10 | 静的検査（成果物構造） |
| **AC-4** | `plan_version` と hash の役割が決定され、二重正本にならない根拠が記録されている | TC-11, TC-12 | 静的検査 + 実測再現 |
| **AC-5** | #980 との責務境界が記録されている | TC-22 | 静的検査（成果物構造） |
| **AC-6** | 既存挙動が不変であることが確認できる | TC-15, TC-16, TC-17, TC-18, TC-25 | 回帰 / 差分検査 |
| （PR1 固有）| ADR が並行正本と誤読されない構造で作られている | TC-01, TC-02, TC-03 | 静的検査 |
| （PR1 固有）| D-6 / D-7 / D-8 / D-9 の 4 判断が根拠付きで記録されている | TC-13, TC-14, TC-23, TC-24 | 静的検査 |
| （PR1 固有・doc V-1）| doc 専用 V-1 の 3 観点（リンク切れ / 正本整合 / 実行例の到達性）| TC-19, TC-20, TC-21 | 静的検査 |

> **「機械的に確認できる形」への落とし込み方針**: 文書の「良さ」ではなく、**存在 / 件数 / 空欄 0 / 実測値の一致**だけを判定する。主観判断（記述が十分か）は C-1 / C-2 / C-3 のレビューに委ね、TC には持ち込まない。

---

## テストケース一覧

### A. ADR の構造（並行正本の誤読防止）

#### TC-01: ADR が既存慣行のパスと節構成で存在する

- **前提条件**: T-02 完了
- **入力**: `ls docs/decisions/` および `<ADR>` の見出し抽出（`grep -n "^#\{1,3\} " <ADR>`）
- **期待出力**: `docs/decisions/adr-002-plan-contract-canonical-source.md` が存在し、ファイル名が `adr-NNN-<slug>.md` 形式（既存 `adr-001-approve-out-of-band.md` と同形式）。見出しに `Context` / `Problem Statement` / `Decision Drivers` / `Considered Options` / `Decision` / `Consequences` / `Related` が**すべて**含まれる。冒頭メタに `Status` / `Date` / `PBI` / `Decision Makers` が含まれる
- **種別**: 静的検査

#### TC-02: 並行正本の誤読を防ぐ 1 文が本文冒頭に存在する

- **前提条件**: T-02 完了
- **入力**: `<ADR>` 本文の**最初の段落**（メタブロック直後）を読む
- **期待出力**: 「Plan Contract は既存の Plan Package + c3-prime 契約の別名であり、新しい artifact ではない」旨の 1 文が最初の段落に存在する（`grep -n "新しい artifact ではない" <ADR>` が 1 件以上ヒットし、その行が `## Context` より前または Context 節の先頭）
- **種別**: 静的検査
- **根拠**: pbi-input Risks「Plan Contract という新語の導入自体が並行正本の印象を生む」への直接対応

#### TC-03: 決定事項 D-1〜D-10 が漏れなく記録されている

- **前提条件**: T-02〜T-07 完了
- **入力**: `grep -c "^#\{3,4\} D-[0-9]\+" <ADR>`（または決定事項表の行数カウント）
- **期待出力**: **`D-1`〜`D-10` の 10 件がすべて存在**し、各件に「決定」と「根拠」が付いている。`TBD` / `TODO` / `検討中` / `後で決める` / `必要に応じて` が **0 件**（`grep -cE "TBD|TODO|検討中|後で決める|必要に応じて" <ADR>` = 0）
- **種別**: 静的検査
- **根拠**: Stop Condition 7（「PR2 で決める」項目が 3 件以上残ったら PR1 の目的未達）の前段防御

### B. 要件対応表（AC-1）

#### TC-04: ギャップ 12 項目のすべてに根拠アンカーが付く

- **前提条件**: T-01 / T-03 完了
- **入力**: `<ADR>` の要件対応表①の全 12 行
- **期待出力**: 全 12 行に「判定（既存で満たす / 一部満たす / 未対応）」と「根拠」が入り、**根拠には関数名または記号アンカーが含まれる**（例: `check_evidence()` / `build_c3_prime()` / `extract_allowed_paths()` / `_plangate_c3_dispatch` / `RECORD_ALLOWED_KEYS` / `ARTIFACTS`）。**行番号のみに依拠する根拠が 0 行**
- **種別**: 静的検査
- **根拠**: pbi-input Risks「ギャップ表の行番号が PR 進行中に stale 化する」

#### TC-05: 「既存で満たす」5 項目に PR2 以降の作業が割り当たっていない

- **前提条件**: T-03 完了
- **入力**: 要件対応表① の `#1`（Plan 本文 hash）/ `#2`（Plan Package hash）/ `#3`（C-1・C-2 束縛）/ `#4`（C-3' approval 束縛）/ `#6`（`allowed_paths` 抽出・宣言検証）の **PR 割当**欄
- **期待出力**: 5 行すべての PR 割当が「**なし（再実装しない）**」相当。PR2 / PR3 / PR4 の記載が **0 件**
- **種別**: 静的検査
- **根拠**: AC-1 の中核。既存資産の再実装 = 二重正本の発生源

#### TC-06: 「一部満たす」3 項目が満たす側 / 満たさない側に分離記載されている

- **前提条件**: T-03 完了
- **入力**: 要件対応表① の `#5`（実行直前再検証）/ `#7`（maker・checker 分離）/ `#11`（Resume 再検証）
- **期待出力**: 3 行それぞれで「満たす側」と「満たさない側」が**別セルまたは明示的な区切り**で分離され、満たさない側にのみ PR2 / PR3 が割り当たっている。特に `#5` は **c3-prime 経路（満たす）/ legacy 経路（満たさない）** の非対称が明記され、legacy 側が PR2 に割り当たっている
- **種別**: 静的検査
- **根拠**: pbi-input MJ-1。「一部」を「既存で満たす」に丸めると legacy 経路が構造的にスコープ外へ落ちる

### C. 正本の単一性（AC-2）

#### TC-07: 配置表の全行が埋まっている

- **前提条件**: T-04 完了
- **入力**: `<ADR>` の「配置表」（情報 × 唯一の正本 × 他の場所での扱い）
- **期待出力**: 表に**最低 6 行**（Plan Package 6 要素の定義 / 実行同一性 / 承認の事実 / 実行主体・実行参照 / `allowed_paths` / merge 禁止）があり、**全行の 3 列すべてが非空**。空欄・`—` のみ・`検討中` が 0 件
- **種別**: 静的検査

#### TC-08: Plan Contract の正本が単一パスで宣言され、コピー不在が根拠付きで示される

- **前提条件**: T-04 完了
- **入力**: `<ADR>` の Decision 節
- **期待出力**: Plan Contract の契約正本が **`docs/workflows/ai-loop/c3-prime-contract.md` の 1 パスのみ**として宣言されている（複数パスを「正本」と呼んでいない）。かつ「同一情報のコピーが 2 箇所以上に存在しない」旨の宣言と、その根拠（配置表の「他の場所での扱い」列がすべて「参照のみ / 書かない」であること）が示されている
- **種別**: 静的検査

### D. schema 機構の評価（AC-3）

#### TC-09: 3 経路すべての検討記録が存在する

- **前提条件**: T-04 完了
- **入力**: `<ADR>` の Considered Options / D-4 節
- **期待出力**: **(a) `approvals/c3.json` の `^_` 注釈キー / (b) `run-event.schema.json` の既存未使用プロパティ（`plan_hash` / `agent` / `by`）/ (c) sidecar + 新規 schema** の 3 経路がすべて記載されている。いずれも「検討しなかった」で済ませていない
- **種別**: 静的検査
- **根拠**: pbi-input MJ-2 / MJ-3。HO 変更を伴わない経路を見落とすと不要な HO patch を前提に計画してしまう

#### TC-10: 3 経路 × 4 軸の比較表が埋まり、採用 / 不採用の理由が付く

- **前提条件**: T-04 完了
- **入力**: `<ADR>` の 3 経路比較表
- **期待出力**: 軸が **HO 接触 / 構造表現力 / CI enforcement / 承認 record の不変性** の 4 つ揃い、**3 経路 × 4 軸 = 12 セルすべてが非空**。採用（(c)）と併用（(b)）と将来枠（(a)）の判定が明示され、新規 schema が必要な理由（既存 3 経路の限界）と、不要にできる代替が併記されている
- **種別**: 静的検査

### E. `plan_version` と hash（AC-4）

#### TC-11: 実行同一性の正本が hash であることが宣言されている

- **前提条件**: T-05 完了
- **入力**: `<ADR>` の D-2 節
- **期待出力**: 「実行同一性の正本 = `plan_hash`（`plan.md` 単体）+ `plan_package_hash`（6 要素の正規化集合）」「`plan_version` は新設しない」「将来 `plan_revision` を導入する場合の唯一の許容形式は `^_plan_revision`（string・注釈キー）であり受理器の判定分岐に使わない」の 3 点がすべて明記されている
- **種別**: 静的検査

#### TC-12: 番号で実行許可を判定する経路が存在しないことを実測で示す

- **前提条件**: T-01 / T-05 完了
- **入力**: `grep -rn "plan_version\|plan_revision" scripts/ schemas/ bin/`（`__pycache__` を除外）
- **期待出力**: **0 件**。この実測結果が `<ADR>` に根拠として掲載され、「番号だけで実行許可を判定する経路が設計上存在しない」ことの裏付けになっている
- **種別**: 実測再現（exec 時に再実行して一致を確認）

### F. 4 判断の根拠（D-6 / D-7 / D-8 / D-9）

#### TC-13: D-6（legacy 経路）の変更範囲が限定され、後方互換の根拠が付く

- **前提条件**: T-07 完了
- **入力**: `<ADR>` の D-6 節
- **期待出力**: (1) PR2 の変更範囲が `bin/plangate` legacy 経路の **fail-open 1 点**（`plan_hash` 不在時の無言 skip）に限定されている、(2) 全面強化（evidence marker 再検証・`artifact_hashes` 照合の移植）を採らない理由として「既存 TASK の `c3.json` を一斉 invalid 化し後方互換を壊す」が明記されている、(3) `bin/plangate` が **HO 対象**であり **AI は patch 提示まで**であることが明記されている — の 3 点すべて
- **種別**: 静的検査

#### TC-14: D-9（evidence stale）の「拡張しない」が循環依存を根拠に説明されている

- **前提条件**: T-07 完了
- **入力**: `<ADR>` の D-9 節 + `scripts/ai-loop/c3_contract.py` の `ARTIFACTS` 定義
- **期待出力**: `ARTIFACTS` に `review-self.md` / `review-external.md` が含まれることを根拠に、「C-1 marker（`review-self.md` の内容）に `plan_package_hash` を書き込むと自己参照になるため**原理的に不可能**」と説明されている。「妥協ではなく構造的帰結」と読める。加えて 3 要素部分集合（`plan.md` / `todo.md` / `test-cases.md`）案が **PR3 候補**として残されている
- **種別**: 静的検査 + 実測再現（`ARTIFACTS` の内容を実ファイルで確認）

#### TC-23: D-7（受理側 presence）の意味範囲が明記され、補強が PR2 に割り当たる

- **前提条件**: T-07 完了
- **入力**: `<ADR>` の D-7 節
- **期待出力**: 「受理側 presence の現在の意味範囲 = artifact が record と **byte 同一**であること。**非空であることではない**」が明記され、0 byte artifact の hash を持つ record を手書きすれば受理される偽造経路が説明されている。補強先が `scripts/ai-loop/c3prime_verify.py`（**HO 対象外**）であることと、PR2 スコープに割り当たっていることが記載されている
- **種別**: 静的検査

#### TC-24: D-8（prohibited_actions）が「宣言しない」判断と理由付きで記録されている

- **前提条件**: T-07 完了
- **入力**: `<ADR>` の D-8 節
- **期待出力**: (1) `prohibited_actions` / `stop_conditions` の宣言フィールドを**新設しない**、(2) 理由 = 実装層（`gh_exec.py` の allowlist 補集合 + `check_exec_boundary.py` の AST 強制）が既に正であり、宣言を足すと「宣言と実装のどちらが正か」という新しい二重正本が生まれる、(3) `gh_exec.py` が自認する「別プロセスからの `gh pr merge` は塞げない」ギャップは**宣言を足しても閉じない**（規範層 + C-4 に残る）— の 3 点すべて。かつ `NO MERGE BY AI` を変更しないことが明記されている
- **種別**: 静的検査

### G. #980 との責務境界（AC-5）

#### TC-22: 分界表と「非検証 opaque string」の明記

- **前提条件**: T-06 完了
- **入力**: `<ADR>` の #980 境界節
- **期待出力**: 「#981 が担当するもの / #980 が担当するもの」の分界表が存在し（issue コメント §1 の項目を漏れなく含む）、「**PR1〜PR3 の ActorSession ID は非検証の opaque string** であり主体の真正性は #980 まで保証されない」が明記されている。加えて「PR2 で追加する record の説明文にも同旨を残す」が申し送りとして書かれている
- **種別**: 静的検査
- **根拠**: pbi-input Risks「opaque string を『検証済み主体』と誤読し、職務分離が担保されていないのに担保されたと report する」

### H. 非退行（AC-6）

#### TC-15: 差分がすべて `.md` である

- **前提条件**: T-01〜T-11 完了
- **入力**: `git diff origin/main --name-only` および `git diff origin/main --stat`
- **期待出力**: **全行が `.md`**。`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/` を含む行が **0 件**。ファイル数は **9**（`docs/decisions/adr-002-*.md` 1 + `docs/working/TASK-0981/{plan,todo,test-cases,review-self,review-external,status,handoff}.md` 7 + `docs/workflows/ai-loop/c3-prime-contract.md` 1）
- **種別**: 差分検査

#### TC-16: 既存テストスイートが baseline と同一

- **前提条件**: T-10 実行時
- **入力**: `sh tests/run-tests.sh`
- **期待出力**: **`failed == 0`** かつ **`passed` が PR 直前に取得した baseline と同一**。main `7de7baa` の実測 baseline は **`514 passed, 0 failed`**（4 回連続で再現）
- **注記（絶対値をハードコードしない理由）**: 新規 worktree での初回実行時に **513 passed** を 1 度観測しており、以後 4 回はいずれも 514（`docs/working/_audit/hook-events.log` の有無・本 PR の新規 `.md` の有無いずれとも無関係であることを実測で切り分け済み）。**初回実行に state 依存の TC が 1 件存在する**とみられるため、絶対値固定にすると exec 開始直後に無関係な理由で FAIL する。判定は「PR 前後で `passed` が同一」+「`failed == 0`」とし、baseline は exec 開始時に**その場で 2 回取得して安定値を採用**する
- **種別**: 回帰

#### TC-17: ai-loop の Python 単体テストが全 exit 0

- **前提条件**: T-10 実行時
- **入力**: `ls scripts/ai-loop/test_*.py` で列挙した**全件**を `python3 <path>` で個別実行する（**件数をハードコードしない**。新規テスト追加時に検査が空振りするのを防ぐ）
- **期待出力**: 列挙された**全件が exit 0**。main `7de7baa` 時点の実測は **13 本 / 13 本 exit 0**（`test_arbiter` / `test_c3_contract` / `test_c3prime_verify` / `test_check_exec_boundary` / `test_ci_taxonomy` / `test_collector` / `test_delivery` / `test_discovery` / `test_executor` / `test_gh_exec` / `test_metrics` / `test_plan_package` / `test_reconciler`）。`unittest` 実装で、CI 上は `tests/extras/ta-55-c3prime-accept.sh` 等を経由して `run-tests.sh` に内包される
- **種別**: 回帰

#### TC-18: `bin/plangate validate` の FAIL が C-3 未発行のみに減る

- **前提条件**: T-10 実行時（C-3 発行**前**の状態で確認）
- **入力**: `bin/plangate validate TASK-0981`
- **期待出力**: Required Artifacts の `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` が **すべて PASS**。FAIL は `approvals/c3.json not found` の **1 件のみ**（PR 作成前の baseline では 5 件 FAIL だったものが 1 件に減る）
- **種別**: 回帰 / 成果物確認

#### TC-25: `pbi-input.md` が変更されていない

- **前提条件**: T-01〜T-11 完了
- **入力**: `git diff origin/main -- docs/working/TASK-0981/pbi-input.md`
- **期待出力**: **空**（差分 0 行）
- **種別**: 差分検査
- **根拠**: plan Constraint 6。main マージ済みの確定版であり、是正は ADR 側の付表で行う

### I. doc 専用 V-1（リンク / 整合 / 到達性）

#### TC-19: markdownlint が 0 issues

- **前提条件**: T-10 実行時
- **入力**: `npx --no-install markdownlint-cli2 "docs/decisions/*.md" "docs/working/TASK-0981/*.md" "docs/workflows/ai-loop/c3-prime-contract.md"`
- **期待出力**: `0 issues`
- **種別**: 静的検査（L-0 / doc V-1）

#### TC-20: 相対リンクがすべて到達可能

- **前提条件**: T-10 実行時
- **入力**: 新規・変更した `.md` 9 ファイルから相対リンク（リンク先が `./` または `../` で始まる Markdown リンク）を抽出し、各リンク先を対象ファイルのディレクトリ基準で `test -f` / `test -d`
- **期待出力**: **未到達 0 件**。アンカー付きリンク（`#section`）はファイル部分のみを検査対象とする
- **種別**: 静的検査（doc V-1: リンク切れ）

#### TC-21: `c3-prime-contract.md` の変更が追記のみ

- **前提条件**: T-08 完了
- **入力**: `git diff origin/main -- docs/workflows/ai-loop/c3-prime-contract.md`
- **期待出力**: **削除行（`-` 始まり）が 0**（ファイルヘッダの `---` を除く）。追加行に「`^_` 注釈キー以外の record フィールド追加は `RECORD_OPTIONAL_KEYS` と `schemas/c3-prime.schema.json` の同時更新を要する」旨が含まれる。既存 §8 の破壊的変更手続き（3 issue 合意 + plan Replan）の記述が**残っている**
- **種別**: 差分検査 + 静的検査（doc V-1: 正本整合）

---

## エッジケース

| # | ケース | 想定される誤り | 検出方法 | 対応 |
|---|--------|--------------|---------|------|
| **EDGE-1** | ADR に正本候補が複数残る（「① を第一候補とするが ③ も可」等） | AC-2 が形式上は満たされたように見えるが、PR2 の実装先が実質未決 | TC-08（正本が**単一パス**であること）+ TC-03（`検討中` が 0 件） | Decision 節では 1 パスに断定する。代替案は Considered Options 節に**不採用**として書く |
| **EDGE-2** | 「既存で満たす」5 項目のどれかに、PR2 の作業が「補強」の名目で紛れ込む | AC-1 が形骸化し、二重正本の再実装が始まる | TC-05（PR 割当欄に PR2/PR3/PR4 が 0 件） | 補強が必要と判明したら判定を「一部満たす」へ格下げし、満たさない側を分離記載してから割り当てる（丸めない） |
| **EDGE-3** | 根拠の行番号が exec 中に stale 化する（他 PR のマージで行がずれる） | 「対象 / 対象外」の判定が反転し PR2 で誤った箇所を触る | TC-04（関数名・記号アンカー併記が全 12 行）+ Replan Trigger RT-3 | 行番号は補助情報とし、関数名・定数名を一次アンカーにする |
| **EDGE-4** | ADR が `docs/rfc/` に置かれる、または `adr-003` 以降に飛ぶ | 既存慣行から外れ、後続が ADR を発見できない | TC-01（パスと命名形式） | `docs/decisions/adr-002-<slug>.md` に固定。既存 ADR は `adr-001` の 1 件のみ（実測） |
| **EDGE-5** | `c3-prime-contract.md` への追記が既存 §8 の破壊的変更手続きを書き換えてしまう | 契約の変更ハードルが無断で下がる（承認境界の実質的な緩和） | TC-21（削除行 0 + 既存記述の残存確認） | 追記のみ。`git diff` で削除行 0 を確認してから次へ進む |
| **EDGE-6** | sidecar 案を採ったのに `plan_hash` を sidecar にもコピーしてしまう | 承認 record と sidecar の 2 箇所に同一情報 = 二重正本 | TC-07 / TC-08（配置表の「他の場所での扱い」が「参照のみ / 書かない」） | sidecar は `approval_ref.path` で `approvals/c3.json` を**参照**するに留める |
| **EDGE-7** | 文書のみの PR なのに `sh tests/run-tests.sh` が失敗する | 前提（PR1 はコードに無影響）が崩れている。ブランチ base の取り違え等 | TC-16（`failed == 0` + PR 前後の `passed` 同一）+ Stop Condition 4 / Replan Trigger RT-4 | main の baseline を再取得し、差分原因が本 PR 由来か切り分ける。`.md` 以外の混入は TC-15 で先に検出される |
| **EDGE-8** | `pbi-input.md` の誤りを見つけて修正したくなる | main マージ済みの確定版を書き換え、C-2 / C-3 の参照基準がぶれる | TC-25（差分 0） | 是正は ADR の付表で行い、`pbi-input.md` には触れない（plan Constraint 6 / Stop Condition 6） |

---

## 自動化可否

| TC | 自動化 | 手段 |
|----|--------|------|
| TC-01, TC-03, TC-04（アンカー有無）, TC-12, TC-15, TC-16, TC-17, TC-18, TC-19, TC-20, TC-21, TC-25 | **可** | `grep` / `git diff` / 既存テストランナー / markdownlint / リンク到達スクリプト |
| TC-02, TC-05, TC-06, TC-07, TC-08, TC-09, TC-10, TC-11, TC-13, TC-14, TC-22, TC-23, TC-24 | **半自動** | 存在・件数・空欄 0 は `grep` で機械判定し、意味の妥当性（分離記載が実質的か等）は V-1 実施者が表と突合して判定する |

> **半自動 TC の判定規約**: 「該当語が存在する」だけで PASS にしない。V-1 実施者は対象表のセルを**全数**確認し、空欄・`—` のみ・`検討中` が 1 件でもあれば FAIL とする。FAIL 時は evidence を `evidence/verification/` に必須保存する（[`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) evidence 保管ルール）。
