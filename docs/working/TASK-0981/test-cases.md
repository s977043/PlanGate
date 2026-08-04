# テストケース定義 — TASK-0981（#981 PR1）

> Plan: [`plan.md`](./plan.md) / ToDo: [`todo.md`](./todo.md) / 入力: [`pbi-input.md`](./pbi-input.md)
> 基点: main **`73e6a15`**（C-2 R-101 で `7de7baa` から更新）。baseline `sh tests/run-tests.sh` = **524 passed / 0 failed**（C-2 反映時に実測。旧基点では 514）。**判定は絶対値ではなく PR 前後の同一性**で行い、baseline は **exec 開始時に `origin/main` 最新でその場取得**する（下記 TC-16 注記）
> **PR1 は文書のみの変更**（コードを 1 行も変更しない）。したがって全 TC は **成果物の構造検査 / 根拠の実測再現 / 既存 baseline との同一性確認** のいずれかであり、新規のコードテストは追加しない
> 検査対象 ADR: `docs/decisions/adr-002-plan-contract-canonical-source.md`（以下 `<ADR>` と表記）
> **番号空間**: 本ファイルの `TC-NN` / `EDGE-N` は、pbi-input のギャップ `#1`〜`#12` および実行条件 `EC-1`〜`EC-10` とは別空間

## 受入基準 → テストケース マッピング

| AC | 内容 | 対応 TC | 種別 |
|----|------|---------|------|
| **AC-1** | 追加実装対象が「未対応差分」だけに限定されている | TC-04, TC-05, TC-06, **TC-26** | 静的検査（成果物構造） |
| **AC-2** | 正本が 1 つに決まっている | TC-07, TC-08 | 静的検査（成果物構造） |
| **AC-3** | 新規 schema 追加の必要性が説明されている | TC-09, TC-10 | 静的検査（成果物構造） |
| **AC-4** | `plan_version` と hash の役割が決定され、二重正本にならない根拠が記録されている | TC-11, TC-12 | 静的検査 + 実測再現 |
| **AC-5** | #980 との責務境界が記録されている | TC-22 | 静的検査（成果物構造） |
| **AC-6** | 既存挙動が不変であることが確認できる（**コード非接触** + Files 表の集合に収まる + baseline 同一） | TC-15, TC-16, TC-17, TC-18, TC-25 | 回帰 / 差分検査 |
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
- **期待出力**: `docs/decisions/adr-002-plan-contract-canonical-source.md` が存在し、ファイル名が `adr-NNN-<slug>.md` 形式（既存 `adr-001-approve-out-of-band.md` と同形式）。見出しに `Context` / `Problem Statement` / `Decision Drivers` / `Considered Options` / `Decision` / `Consequences` / `Related` が**すべて**含まれる。冒頭メタに `Status` / `Date` / `PBI` / `Decision Makers` が含まれる。**`Status` の値が `Accepted`**（C-2 R-114。ADR-001 の `Proposed` をそのまま踏襲すると PR2 が「まだ決まっていない」と読む余地が残るため）。**`Related` 節に「本 ADR が `adr-002` を占有する / #980 は `adr-003` 以降を使う」の採番予約がある**（C-2 R-107）
- **種別**: 静的検査

#### TC-02: 並行正本の誤読を防ぐ 1 文が本文冒頭に存在する

- **前提条件**: T-02 完了
- **入力**: `<ADR>` 本文の**最初の段落**（メタブロック直後）を読む
- **期待出力**: 「Plan Contract は既存の Plan Package + c3-prime 契約の別名であり、新しい artifact ではない」旨の 1 文が最初の段落に存在する（`grep -n "新しい artifact ではない" <ADR>` が 1 件以上ヒットし、その行が `## Context` より前または Context 節の先頭）
- **種別**: 静的検査
- **根拠**: pbi-input Risks「Plan Contract という新語の導入自体が並行正本の印象を生む」への直接対応

#### TC-03: 決定事項 D-1〜D-10 が漏れなく記録されている

- **前提条件**: T-02〜T-07 完了
- **入力**: `grep -c "^#\{3,4\} D-[0-9]\+" <ADR>`（または決定事項表の行数カウント）+ `<ADR>` の **`Decision` 節のみ**を切り出したテキスト
- **期待出力**: **`D-1`〜`D-10` の 10 件がすべて存在**し、各件に「決定」と「根拠」が付いている。**`Decision` 節**に `TBD` / `TODO` / `検討中` / `後で決める` / `必要に応じて` が **0 件**
- **注記（適用範囲を `Decision` 節に限る理由 / C-2 R-008 是正）**: 旧期待値は「ADR **全体**で 0 件」だったが、T-09 は PR2 / PR3 スコープ表に **U-4 のフィールド詳細 / U-5 / U-7 を未決事項として明示せよ**と要求しており、未決事項を素直に書くと禁止語に触れる。**同一ファイル上で T-04c と T-09 の要求が衝突する**ため、禁止語検査は「決定を断定する節」= `Decision` 節に限定する。PR2 / PR3 スコープ表・Consequences・Related は対象外
- **種別**: 静的検査
- **根拠**: Stop Condition 7（PR1 で確定と宣言した決定が未確定のまま残ったら目的未達）の前段防御

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

#### TC-26: 「未対応」3 項目の PR 割当が全件存在し、要件対応表②が 14 行揃っている

> **C-2 R-001 / R-010 で新設**。旧 TC 群は表①の「過剰（既存充足への割当）」しか検査しておらず、**「欠落（行そのものが落ちる）」を検出できなかった**。表②に至っては AC / TC のいずれからも参照されておらず、**空表でも全 TC が PASS した**。

- **前提条件**: T-03 完了
- **入力**: `<ADR>` の要件対応表①（「未対応」3 項目 = `#8`（Planner / Executor 分離）/ `#9`（execution reference）/ `#10`（revision / resume））および要件対応表②（#981 全体 AC × PR1 で扱う範囲）
- **期待出力**:
  1. 表①の「未対応」3 項目それぞれに **PR 割当欄が非空**で、PR2 / PR3 / PR4 のいずれかが割り当たっている（欠落の抑制 / R-010）
  2. 表②が **#981 全体 AC 14 項目すべてを行として持つ**（`grep -c` で表②のデータ行が 14 行）
  3. 表②の**全 14 行で「PR1 で扱う範囲」列が非空**（空欄・`—` のみ・`検討中` が 0 件 / R-001）
- **種別**: 静的検査（行数は自動 / セルの非空は半自動）
- **根拠**: `pbi-input.md:153` / `:164`（#981 本文の受け入れ条件 14 項目は PR1〜PR4 全体の AC であり、PR1 での扱いを行ごとに宣言する必要がある）

### C. 正本の単一性（AC-2）

#### TC-07: 配置表の全行が埋まっている

- **前提条件**: T-04a 完了
- **入力**: `<ADR>` の「配置表」（情報 × 唯一の正本 × 他の場所での扱い）
- **期待出力**: 表に**最低 6 行**（Plan Package 6 要素の定義 / 実行同一性 / 承認の事実 / 実行主体・実行参照 / `allowed_paths` / merge 禁止）があり、**全行の 3 列すべてが非空**。空欄・`—` のみ・`検討中` が 0 件
- **種別**: 静的検査

#### TC-08: Plan Contract の正本が単一パスで宣言され、コピー不在が根拠付きで示される

- **前提条件**: T-04c 完了
- **入力**: `<ADR>` の Decision 節
- **期待出力**: Plan Contract の契約正本が **`docs/workflows/ai-loop/c3-prime-contract.md` の 1 パスのみ**として宣言されている（複数パスを「正本」と呼んでいない）。かつ「同一情報のコピーが 2 箇所以上に存在しない」旨の宣言と、その根拠が示されている
- **根拠の判定条件（C-2 R-007 是正）**: 旧期待値は「『他の場所での扱い』列が**すべて**『参照のみ / 書かない』」だったが、D-4(b) は `plan_hash` を `run.ndjson` にも刻むため、その行が「刻む」となった瞬間に**判定不能**になっていた。判定条件を以下へ具体化する:
  1. 各行の「唯一の正本」列が**単一パス / 単一 record** を指す（複数を「正本」と呼ぶ行が 0 件）
  2. 非正本側に複製が存在する行（= `run.ndjson` の `plan_hash`）には、**「非正本のトレース複製であり、不一致時は正本が勝つ」「判定・受理に使わない」旨が明記**されている
- **種別**: 静的検査

### D. schema 機構の評価（AC-3）

#### TC-09: 5 経路すべての検討記録が存在する

> **C-2 R-006 / R-102 で 3 → 5 経路へ拡張**。旧 3 経路には「既存 schema への型付き additive」と「`docs/schemas/`（非 HO）配置 → 後日昇格」が欠けており、後者は #874（`73e6a15`）が実績として確立している経路だったため、AC-3 の「新規 schema が必要である」ことの論証が不十分だった。

- **前提条件**: T-04b 完了
- **入力**: `<ADR>` の Considered Options / D-4 節
- **期待出力**: 以下 **5 経路がすべて記載**されている。いずれも「検討しなかった」で済ませていない
  - (a) `approvals/c3.json` の `^_` 注釈キー
  - (b) `run-event.schema.json` の既存未使用プロパティ（`plan_hash` / `agent` / `by`）
  - (c) sidecar + 新規 `schemas/plan-contract.schema.json`
  - **(d) 既存 `schemas/c3-prime.schema.json` へ型付きプロパティを additive 追加**（`RECORD_OPTIONAL_KEYS` と同時更新）
  - **(e) `docs/schemas/plan-contract.schema.json`（非 HO）に置き、後日 `git mv` で `schemas/` へ昇格**
- **種別**: 静的検査
- **根拠**: pbi-input MJ-2 / MJ-3。HO 変更を伴わない経路を見落とすと不要な HO patch を前提に計画してしまう

#### TC-10: 5 経路 × 4 軸の比較表が埋まり、採用 / 不採用の理由が付く

- **前提条件**: T-04b 完了
- **入力**: `<ADR>` の 5 経路比較表
- **期待出力**: 軸が **HO 接触 / 構造表現力 / CI enforcement / 承認 record の不変性** の 4 つ揃い、**5 経路 × 4 軸 = 20 セルすべてが非空**。採用（(c)）/ 併用（(b)）/ 将来枠（(a)）/ **不採用（(d)・(e)）** の判定が明示され、新規 schema が必要な理由（既存 4 経路の限界）が示されている。特に:
  - (d) の不採用理由が「承認 record の不変性を壊す（D-3 と同じ帰属の誤り）」で、**HO 接触量が (c) と同等**であることに触れている
  - (e) の不採用理由が「PR1 は実装を含まないため段階化の利得が無い」「sidecar インスタンスの CI 検証には結局 `schemas/` 昇格が要る（TASK-0874 handoff K-12）」で、**HO 適用回数は減らない**ことに触れている
  - (c) の CI enforcement 欄に「**`scripts/schema_mapping.py` への 1 行登録が唯一の強制点で、忘れると `SKIP` = 沈黙 PASS**」が明記されている（C-2 R-103）
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
- **期待出力**: (1) PR2 の変更範囲が `bin/plangate` legacy 経路の **fail-open 1 点**（`plan_hash` が**記録されていない**ときの無言 skip）に限定されている、(2) 全面強化（evidence marker 再検証・`artifact_hashes` 照合の移植）を採らない理由として「既存 TASK の `c3.json` を一斉 invalid 化し後方互換を壊す」が明記されている、(3) `bin/plangate` が **HO 対象**であり **AI は patch 提示まで**であることが明記されている — の 3 点すべて
- **追加の期待出力（C-2 R-002 / R-106 是正）**:
  4. 塞ぐ対象が「**記録が無いから照合しない**」と書かれている（「記録があるのに照合しない」という**論理が反転した記述になっていない**。記録がある場合は `bin/plangate:2098` で既に mismatch 判定される）
  5. ③ が ② より後方互換に安全である根拠が**実測値で定量化**されている（追跡下の `docs/working/*/approvals/c3.json` の**総数**と `plan_hash` **欠落件数**。C-2 反映時の実測 = 80 件中 1 件（`TASK-0038`）。exec 時に再実測して一致を確認する）
  6. 穴の大きさが**多層防御の層**として書かれている（`plangate approve` の書き込み / `c3-approval.schema.json` の `required` / schema-validate CI / exec preflight の 4 層のうち**最後の 1 層のみが抜けている**。「本番フロー大多数の穴」という過大表現になっていない）
- **種別**: 静的検査 + 実測再現（4. の欠落件数）

#### TC-14: D-9（evidence stale）の「拡張しない」が循環依存を根拠に説明されている

- **前提条件**: T-07 完了
- **入力**: `<ADR>` の D-9 節 + `scripts/ai-loop/c3_contract.py` の `ARTIFACTS` 定義
- **期待出力**: `ARTIFACTS` に `review-self.md` / `review-external.md` が含まれることを根拠に、「C-1 marker（`review-self.md` の内容）に `plan_package_hash` を書き込むと自己参照になるため、**現行の marker 埋め込み方式では原理的に不可能**」と**限定表現**で説明されている（「あらゆる方式で不可能」と書いていない）。「妥協ではなく構造的帰結」と読める。加えて **marker 以外の束縛（record 側フィールド / レビュー対象 3 要素 `plan.md` / `todo.md` / `test-cases.md` の部分集合 hash）は循環しないため可能**であり **PR3 候補**として残されている、と併記されている
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

#### TC-22: 分界表と「非検証 opaque string」の明記、および `agent` / `by` の語彙・所有権の確定

- **前提条件**: T-06 完了
- **入力**: `<ADR>` の #980 境界節
- **期待出力**: 「#981 が担当するもの / #980 が担当するもの」の分界表が存在し（issue コメント §1 の項目を漏れなく含む）、「**PR1〜PR3 の ActorSession ID は非検証の opaque string** であり主体の真正性は #980 まで保証されない」が明記されている。加えて「PR2 で追加する record の説明文にも同旨を残す」が申し送りとして書かれている
- **追加の期待出力（C-2 R-003 / 新規）**: `run-event.schema.json` の `agent` / `by` について以下 4 点がすべて記載されている
  1. **`agent` の語彙定義**（何を入れるか。現行 `bin/plangate:2037` の `PLANGATE_IMPL_AGENT` 由来の**ツール種別**文字列を継続するのか、Executor 主体識別子へ意味を移すのか）
  2. **`by` の語彙定義**（gate イベントの Human / Agent 識別子として何を入れるか）
  3. **writer 所有権**（`plangate_append_ndjson` の 3 呼び出し `bin/plangate:1279` / `:2005` / `:2112` のどれが何を書くか）
  4. 分界表に「**#980 は `agent` / `by` / `plan_hash` に独自語彙を割り当てない**」の行がある
- **根拠（追加分）**: `docs/working/TASK-0980/pbi-input.md:181` が本論点を「**#981 PR1 の ADR で先に確定する。本 PBI は決めない。**」と明示的に委譲しており、同 `:190` は #980 の Non-goal、`:223` の AC-P2(b) は本 ADR を参照して検査する。`schemas/run-event.schema.json:77` が `additionalProperties: false` かつ `^_` の patternProperties も無いため、**1 フィールドに 2 語彙が入ると是正が HO patch になる**
- **種別**: 静的検査
- **根拠**: pbi-input Risks「opaque string を『検証済み主体』と誤読し、職務分離が担保されていないのに担保されたと report する」

### H. 非退行（AC-6）

#### TC-15: コード配下に変更が無く、差分が Files 表の集合に収まる

- **前提条件**: T-01〜T-11 完了
- **入力**: `git diff origin/main --name-only` および `git diff origin/main --stat`
- **期待出力**: (1) **コード配下（`schemas/` / `bin/` / `scripts/` / `tests/` / `.claude/` / `.github/`）で始まる行が 0 件**、(2) 全変更ファイルが plan「Files / Components to Touch」の **A（変更対象 9 ファイル）+ B（PlanGate 標準 artifact）** の集合に収まる（A 外・B 外のファイルが 0 件）
- **種別**: 差分検査
- **注記（`.md` 限定・ファイル数固定にしない理由 / C-1 F-2 是正）**: 本リポジトリの working context は `approvals/c3.json`（**JSON**）/ `decision-log.jsonl` / `INDEX.md` / `current-state.md` / `evidence/**` を **git 追跡している**（TASK-0873 で実測）。H-01（`bin/plangate approve TASK-0981`）が発行する c3.json が同一ブランチに載った時点で「全行が `.md`」「ファイル数 9」は**必ず FAIL** し、同条件を持つ Stop Condition 5 / RT-5（exec 停止・ブランチ作り直し）が**正常な承認フローで誤発火**する。したがって判定は「**コード非接触**」+「**Files 表の集合に収まる**」の 2 条件で行う
- **許容リスト（`.md` 以外だが正常）**: `docs/working/TASK-0981/approvals/c3.json` / `docs/working/TASK-0981/decision-log.jsonl` / `docs/working/TASK-0981/evidence/**`

#### TC-16: 既存テストスイートが baseline と同一

- **前提条件**: T-10 実行時
- **入力**: `sh tests/run-tests.sh`
- **期待出力**: **`failed == 0`** かつ **`passed` が PR 直前に取得した baseline と同一**
- **注記（絶対値をハードコードしない理由 / C-2 R-101 で強化）**: 理由は 2 つある。
  1. **state 依存**: 新規 worktree での初回実行時に **513 passed** を 1 度観測しており、以後は安定していた（`docs/working/_audit/hook-events.log` の有無・本 PR の新規 `.md` の有無いずれとも無関係であることを実測で切り分け済み）。**初回実行に state 依存の TC が 1 件存在する**とみられる。
  2. **基点ドリフト**: 旧基点 `7de7baa` の baseline は **514** だったが、`73e6a15`（#989 = TASK-0874）で **524** に増えた。**main が進むたびに絶対値は変わる**ため、ハードコードすると基点更新のたびに無関係な FAIL が出る。
  したがって判定は「PR 前後で `passed` が同一」+「`failed == 0`」とし、**baseline は exec 開始時（T-01）に `origin/main` 最新を取り込んだ状態でその場で 2 回取得して安定値を採用**する。参考値: `73e6a15` で **524 passed / 0 failed**
- **種別**: 回帰

#### TC-17: ai-loop の Python 単体テストが全 exit 0

- **前提条件**: T-10 実行時
- **入力**: `ls scripts/ai-loop/test_*.py` で列挙した**全件**を `python3 <path>` で個別実行する（**件数をハードコードしない**。新規テスト追加時に検査が空振りするのを防ぐ）
- **期待出力**: 列挙された**全件が exit 0**。参考値: 基点 `73e6a15` で **15 本**（旧基点 `7de7baa` の 13 本 = `test_arbiter` / `test_c3_contract` / `test_c3prime_verify` / `test_check_exec_boundary` / `test_ci_taxonomy` / `test_collector` / `test_delivery` / `test_discovery` / `test_executor` / `test_gh_exec` / `test_metrics` / `test_plan_package` / `test_reconciler` に、#989 で `test_run_evidence` / `test_run_evidence_verify` が追加された）。`unittest` 実装で、CI 上は `tests/extras/ta-55-c3prime-accept.sh` 等を経由して `run-tests.sh` に内包される
- **注記（本数をハードコードしない理由 / C-2 R-101）**: 旧記述は「13 本」を期待値に書いていたが、基点更新で 15 本になった。**本数は `ls` の結果を母数とし、期待値は「列挙された全件が exit 0」**とする（新規テスト追加時に検査が空振りするのも防ぐ）
- **種別**: 回帰

#### TC-18: `bin/plangate validate` が FAIL 0 件になる

- **前提条件**: T-10 実行時。**H-01（C-3 ゲート）は T-01 より前に完了しているため `approvals/c3.json` は既に存在する**
- **入力**: `bin/plangate validate TASK-0981`
- **期待出力**: **`Result: PASS`（FAIL 0 件）**。Required Artifacts の `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` が全 PASS、C-3 Gate も PASS（`plan_hash` が現 `plan.md` と一致 = 承認後に plan を変更していないこと）
- **種別**: 回帰 / 成果物確認
- **注記（C-1 F-2 是正）**: 旧期待値「FAIL は `approvals/c3.json not found` の 1 件のみ」は、todo の依存順（**H-01 → T-01 → … → T-10**）と両立しなかった。参考として、**plan 生成直後（H-01 前）**の実測は「Required Artifacts 5 件中 `pbi-input.md` のみ PASS、計 5 件 FAIL」であり、これは baseline としてのみ扱う

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
| **EDGE-7** | 文書のみの PR なのに `sh tests/run-tests.sh` が失敗する | 前提（PR1 はコードに無影響）が崩れている。ブランチ base の取り違え等 | TC-16（`failed == 0` + PR 前後の `passed` 同一）+ Stop Condition 4 / Replan Trigger RT-4 | main の baseline を再取得し、差分原因が本 PR 由来か切り分ける。コード配下の混入は TC-15 で先に検出される |
| **EDGE-8** | `pbi-input.md` の誤りを見つけて修正したくなる | main マージ済みの確定版を書き換え、C-2 / C-3 の参照基準がぶれる | TC-25（差分 0） | 是正は ADR の付表で行い、`pbi-input.md` には触れない（plan Constraint 6 / Stop Condition 6） |

---

## 自動化可否

| TC | 自動化 | 手段 |
|----|--------|------|
| TC-01, TC-03, TC-04（アンカー有無）, TC-12, TC-15, TC-16, TC-17, TC-18, TC-19, TC-20, TC-21, TC-25, TC-26（行数部分） | **可** | `grep` / `git diff` / 既存テストランナー / markdownlint / リンク到達スクリプト |
| TC-02, TC-05, TC-06, TC-07, TC-08, TC-09, TC-10, TC-11, TC-13, TC-14, TC-22, TC-23, TC-24, TC-26（セル非空部分） | **半自動** | 存在・件数・空欄 0 は `grep` で機械判定し、意味の妥当性（分離記載が実質的か等）は V-1 実施者が表と突合して判定する |

> **半自動 TC の判定規約**: 「該当語が存在する」だけで PASS にしない。V-1 実施者は対象表のセルを**全数**確認し、空欄・`—` のみ・`検討中` が 1 件でもあれば FAIL とする。FAIL 時は evidence を `evidence/verification/` に必須保存する（[`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) evidence 保管ルール）。
