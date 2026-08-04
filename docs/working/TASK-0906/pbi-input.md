# PBI INPUT PACKAGE — TASK-0906

> Issue: [#906](https://github.com/s977043/plangate/issues/906)（**label は実測 0 件**。領域は ai-loop / governance 相当）— 「arbiter が導入先 `ho-paths.md` §2（app コード / 共有 Model / 認証等）を自動検知せず、app コード拡張時の §2 ガードが手動運用頼み」
> 作成: 2026-08-04（**main `c474b70` で行番号・記号アンカー・件数をすべて実測**。行番号は目安であり記号アンカー〔関数名・変数名・テスト名〕を正とする）
> **役割分担（Human 指示・確定）**: [#916](https://github.com/s977043/plangate/issues/916) が **一般形の共通 escalate-path 評価器**を実装し、**本 PBI（#906）はその評価器へ「導入先 `ho-paths.md` §2」を入力ソースとして接続する**。**評価器を二重実装しない**。
> 依存: **#916 の完了（評価器 IF の確定）が本 PBI exec の前提**（下記「依存関係」節）

---

## Context / Why

導入先プロジェクト（Laravel / Next.js の実運用リポジトリ）で `ai-loop-workflow` を初めて **docs 以外（app コード）** に拡張して実走した際に観察された盲点（issue 本文より）。

導入先は自身の `ho-paths.md` に、**§1 = HO パス一覧**（`CLAUDE.md` / CI 定義 等）とは別に **§2 = domain-gate パス**（`.env*`・認証ミドルウェア・共有 Model（`Service` / `Category` 等）・`database/migrations/**`・別ドメイン）を列挙している。docs-only 運用では「§2 を ai-loop の対象に入れない」convention（LoopSpec `scope.allowed_paths` を docs に限定）で担保できていたが、[#807](https://github.com/s977043/plangate/issues/807) に沿って **app コードへ拡張**すると §2 の保護が

- LoopSpec `scope.allowed_paths` の宣言（宣言外＝`scope_violation` で escalate）
- W チェック（Model A / B）

の 2 点のみに依存する。**`allowed_paths` の宣言漏れ**があると共有 Model 等への誤変更が escalate されず auto-approve 経路に乗りうる（friction ledger の F-001 / F-004 相当）。

### 実測による裏取り（main `c474b70`）

| # | 主張 | 実測方法 | 結果 |
|---|------|---------|------|
| 1 | issue 本文の「埋め込み `HO_PATTERNS`」は **現行 main では stale** | `grep -c "HO_PATTERNS" scripts/ai-loop/arbiter.py` → **0**。`scripts/ai-loop/test_arbiter.py` L173 に「#809 により HO_PATTERNS ハードコード定数は廃止され、ho-paths.md 本文を（実行時解決する）」と明記 | **ハードコード定数は既に廃止済み**。現行は `resolve_ho_patterns()`（`arbiter.py` L193-220）による**実行時解決**。ただし issue の**結論**（§2 が機械検知されない）は下記 #4 の条件下で成立 |
| 2 | `--ho-paths` の解決経路 | `_candidate_ho_paths_sources()`（`arbiter.py` L177-190）+ `main()` の `--ho-paths` 引数定義（L1141-1146） | **確認**。解決順は (1) CLI `--ho-paths` 明示（指定時は他候補を一切試さない）→ (2) `CWD/docs/ai/ai-loop/ho-paths.md` → (3) スクリプト位置基準 `../references/ho-paths.md`（plugin bundled）。`resolve_ho_patterns()` は全候補失敗・パース 0 件で `patterns=[]` を返し、`arbitrate()` L947-955 の **priority 0 が全件 `HUMAN_ESCALATED`**（fail-closed。fail-open は行わない） |
| 3 | `boundary_check` 相当の判定箇所 | `boundary_check()`（L281-309）→ `matches_ho_pattern()`（L268-278）→ `_ho_pattern_to_regex()`（L223-265・`lru_cache` 付き）。`arbitrate()` からの呼び出しは `_evaluate_signals()`（L841-881）L863 経由、分岐は `priority_table` の `"priority 1"` 行（L1034-1035） | **確認**。1 件でも一致すれば `touches-HO` 即確定。`matched[]` には `{path, pattern, classification}` を記録する（分類文字列は表の第 2 セルをそのまま保持） |
| 4 | **`parse_ho_paths_table()` はセクション単位でなく「ファイル全文」を走査する** | `parse_ho_paths_table()`（L150-174）の実装を読解 — `for line in content.splitlines()` で全行を走査し、判定条件は「行が `\|` 始まり」「セル数 ≥ 4」「第 1 セルがバッククォート付き」「第 2 セルが非空」のみ（**見出し・セクションを一切見ていない**）。**実行して実測**（下記 5 / 6） | **確認（本 PBI の設計を左右する最重要事実）** |
| 5 | 現 main の `ho-paths.md` は §1 / §2 の節構造を**持たない** | `grep -n "^#" docs/ai/ai-loop/ho-paths.md` → **全 8 件**: `# Arbiter — HO（Hardening Override）パス集約リスト`（L1・H1）/ `## touches-HO 判定ルール`（L11）/ `## HO パス一覧`（L22）/ `## 分類定義`（L50）/ `## 判定アルゴリズム（Phase 2 Decision table 向け）`（L66）/ `### パターンマッチの例`（L84）/ `## Arbiter 固有の追加原則`（L104）/ `## 関連ドキュメント`（L125）。**番号付き節（`## 1.` / `## 2.`）は 1 件もない**。plugin 同梱の雛形（`plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md`）も同一構成（先頭に雛形注記 3 行を前置するのみ） | **本リポジトリ側には §2 が存在しない**。issue が言う §1 / §2 は**導入先リポジトリ固有の構成**であり、本リポジトリからは実体を確認できない（→ U-1） |
| 6 | **§2 が「§1 と同一形式のテーブル」で書かれている場合、arbiter は現状すでにそれを HO パターンとして取り込む** | `parse_ho_paths_table()` に §1 + §2 の 2 表を持つサンプルを渡して実行。結果: `[('CLAUDE.md','HO-contract'), ('.env*','domain-gate'), ('app/Models/Service.php','domain-gate')]` → `boundary_check(['app/Models/Service.php'], …)` = **`('touches-HO', [... classification='domain-gate' ...])`** | **確認**。一方 §2 を**箇条書き**で書いたサンプルでは `[('CLAUDE.md','HO-contract')]` のみが取れ、`boundary_check` は **`clean`**。つまり issue の「arbiter は §2 を素通しする」は **§2 の記法に依存する条件付きの事実**であり、無条件には成立しない（→ U-2） |
| 7 | `scope.allowed_paths` の schema と `scope_violation` escalate の実装箇所 | `docs/workflows/ai-loop/loopspec.md` L110（必須・1 件以上・欠落は受理拒否 I-4・glob 表記は ho-paths.md 慣習に従う）/ L24（「**LoopSpec は arbiter.py への入力そのものではない**」）。実装は `check_allowed_paths()`（`arbiter.py` L362-）+ `_evaluate_signals()` L864 + `priority_table` の `"priority 1.5"` 行（L1036-1037・`DECISION_HUMAN_ESCALATED` / `scope_check="scope_violation"`） | **確認**。`allowed_paths` は「一致しなければ逸脱」の**ホワイトリスト**であり、「一致したら escalate」の**ブラックリスト**は現存しない |
| 8 | `escalate_paths` / `deny_paths` は現存しない | `grep -rn "escalate_paths\|deny_paths"` → ヒットは `docs/working/TASK-0916/pbi-input.md` の **3 行**（`:67` / `:85` / `:88`）のみ。`scripts/ai-loop/arbiter.py` = **0 件** / `docs/workflows/ai-loop/loopspec.md` = **0 件** | **確認**（提案 (B) は完全新規フィールドの追加になる） |
| 9 | テスト baseline（2 系統） | `python3 scripts/ai-loop/test_arbiter.py`（**リポジトリルート起点必須**）/ `sh tests/run-tests.sh` | **247 tests OK** / **492 passed, 0 failed**（いずれも main `c474b70` 基点の本ブランチで実測。本ブランチは docs-only 差分のため main 相当） |
| 10 | **R-6（雛形フォールバック）は `clean` にとどまらず `AUTO_APPROVED` まで到達する** | `arbiter.py --input <app コード変更・lite 全 true・verdict approve-approve・class no-merge> --ho-paths plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md` を実行（雛形が ho-paths として解決された状態の等価入力） | **確認**。出力 `decision=AUTO_APPROVED` / `priority 6: verdict=approve-approve（合意）` / `scope_check=in_scope`（→ R-6・#978） |

### #916 の評価器 IF（`docs/working/TASK-0916/pbi-input.md` 実測）

| 項目 | #916 pbi-input の記述（実測） |
|------|------|
| 入力 | **パターン集合を引数で受ける一般形**。AC-5 が「例: `(patterns, changed_files) -> (hit: bool, matched: list)`」を明示し、「**carve-out glob 以外の任意のパターン集合を渡しても同一関数で判定できる**ことをテストで固定する（#906 が『入力ソースを足すだけ』で再利用できる構造の機械的保証）」と規定（L75） |
| 出力 | `(hit: bool, matched: list)` 相当。`arbitrate()` へは `Signals`（`arbiter.py` L820-838）に `carve_out_hit` 相当を追加し、`priority_table` に新規行を挿す **additive 変更**（In scope 1 / L32-33） |
| 呼び出し箇所 | `priority_table`（`arbiter.py` L1033-1062）。挿入位置は **priority 1（touches-HO）の直後**が第一候補（1.x 小数刻みの前例に倣う。L33） |
| `boundary_check()` の扱い | **変更しない**。別関数（`carve_out_check()` 等）として追加（L32・AC-4 で既存 247 テスト維持） |
| 入力ソースの解決 | 機械可読正本 1 箇所を `resolve_ho_patterns()` と**同型**の解決関数で実行時解決し、**解決不能時は fail-closed**（`HUMAN_ESCALATED`）（In scope 2 / L38） |
| (A)/(B) の選択 | #916 は **(A)（機械可読 glob 一覧）を採用**し、**LoopSpec への `scope.escalate_paths` / `deny_paths` 追加は Out of scope（非採用）**（L67 / L85-89。理由: loopspec.md L24 が「LoopSpec は arbiter.py への入力そのものではない」と明記し、変換層が別途必要になるため） |
| #906 との関係 | 「**本 PBI（#916）を先に実装して評価器の骨格を作り、#906 は入力ソースを足す形**にすると、評価器が二重実装にならない」（L120） |

---

## What（Scope）

### In scope

1. **#916 の共通 escalate-path 評価器へ「導入先 `ho-paths.md` §2（domain-gate）」を入力ソースとして接続する**
   - #916 が AC-5 で一般形（`(patterns, changed_files) -> (hit, matched)`）として固定した**同一関数を再利用**する。判定ロジックは新設しない
   - 追加するのは **入力ソースの解決経路**（§2 パターン集合の取得）と、**§1 / §2 の記録上の区別**、および `priority_table` への接続（既存 priority 行の再利用 or 新規行追加は #916 の実装形に従う）
   - **解決層（resolver）の共有可否は未決**（→ U-9）。AC-4 が縛るのは**評価器（マッチング層）の同一性**のみであり、解決関数を #916 の実装と共有するか複製するかは別問題。「評価器は 1 本だが resolver は 3 本（`resolve_ho_patterns()` / #916 carve-out 用 / §2 用）」という構造は Human 指示の趣旨に反しうるため、plan で明示的に決める
2. **§1（HO）と §2（domain-gate）が provenance 上で区別されて記録されること**
   - 現状 `matched[]` は `classification` に表の第 2 セルをそのまま保持する（裏取り #3 / #6）ため、区別の素地はある。`boundary` フィールドは `touches-HO` / `clean` / `unresolved` の 3 値であり、**§2 一致を `touches-HO` と同値で潰すか、別値・別フィールドで表すかは plan の設計判断**（U-3）
3. **負側テストの追加**（`test_arbiter.py`）
   - §2 パターンに一致する `changed_files` で escalate が返ること
   - **`allowed_paths` に §2 パスが含まれていても（＝宣言漏れの結果 `scope_violation` が発火しない状況でも）escalate されること**（issue の中心的な盲点＝宣言漏れ耐性の固定。ここでの「宣言漏れ」は `allowed_paths` の絞り込み漏れ＝§2 パスが in_scope になってしまう事象を指す。AC-2 と同一シナリオ）
   - §2 非該当パスの判定が不変であること（回帰）
4. **導入先 `ho-paths.md` の §2 記法規約の明文化**（U-2 の決定に従い、必要な場合のみ）
   - plugin 同梱の雛形（`plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md`）と `docs/workflows/ai-loop/execution-runbook.md` L14-18（導入先 ho-paths 確定手順）への追記が候補

### Out of scope / Non-goals

- **共通 escalate-path 評価器そのものの実装**（**#916 の担当**。本 PBI は評価器を書かない）
- **#906 側で独自の判定ロジックを新設すること**（Human 指示により明確に禁止。評価器の二重実装を作らない）
- **§1（HO）検知の変更**（`boundary_check()` / `matches_ho_pattern()` / `_ho_pattern_to_regex()` の挙動変更、および `test_clean_path` / `test_docs_ai_ai_loop_excluded` / `test_ho_paths_md_itself` / `test_ho_pattern_drift_against_source_of_truth` のアサーション変更）
- **rollout-policy §5 不変条件の変更**（NO MERGE BY AI / HO 接触＝無条件 escalate / W チェック独立 2 体 / lite AC-8 安全側）
- **#916 の carve-out glob 正本の設計そのもの**（#916 の In scope 2）
- **導入先リポジトリ側の `ho-paths.md` 実体の編集**（導入先リポジトリの作業。本リポジトリは仕様・雛形・評価器の接続のみを提供）
- **`plugin/plangate/skills/ai-loop-cycle/**` 配布派生の独立監視**（既存 sync drift-check が検出。ただし ruleset 実測〔`gh api repos/s977043/plangate/rulesets/14939019`〕で **required status check は `Markdown lint` の 1 本のみ**であり、sync drift-check は必須チェックに未配線 = **merge をブロックしない** — #916 U-5 と同じ論点。無条件の安全根拠として引用しないこと）
  - **⚠️ 例外**: U-2 (c)（専用ファイル新設）を採る場合、**その新正本の plugin 配布は Out of scope にしない**（下記 MJ-2 相当・U-2 参照）。配布されないと導入先で §2 判定が常時 no-op になり、本 PBI が塞ごうとしている silent degradation を再生産する

---

## 依存関係（**#916 に従属**）

| 依存 | 内容 |
|------|------|
| **前提** | **#916 の完了（共通 escalate-path 評価器の IF 確定）**。#916 AC-5 が「パターン集合を引数で受ける一般形」を機械的に固定するため、その関数シグネチャ・`Signals` フィールド名・`priority_table` の挿入位置が確定するまで本 PBI の実装形は決まらない |
| **exec 禁止条件** | **#916 未完のまま本 PBI の exec に入らない**。#916 の実装形（とくに U-1「`ho-paths.md` へ §追加 vs 専用ファイル新設」と、それに伴う `parse_ho_paths_table()` の **section-scoped 化の有無**）が本 PBI のベースラインを直接変える（下記 R-1） |
| **plan は先行可** | pbi-input / plan の起案は #916 と並行してよい。ただし plan の Unknowns には「#916 の確定 IF を待つ」旨を明示し、C-3 は #916 の実装確定後に取る |

---

## 受入基準

> **注記: issue #906 は AC を持たない**（提案 (A)/(B) と影響の記述のみ）。以下は **本 PBI で調査結果に基づき起案**したものであり、issue verbatim ではない。plan / C-3 で最終確定する。
>
> **AC-1〜AC-5 の共通前提条件（MJ-1 反映）**: **導入先自身の `ho-paths.md` が `--ho-paths` 明示指定または CWD（`docs/ai/ai-loop/ho-paths.md`）で解決されていること**。この前提が崩れた場合（＝導入先がファイルを配置し忘れ、plugin 同梱雛形へ静かにフォールバックした場合）、arbiter は §1 も §2 も評価できないまま `AUTO_APPROVED` に到達しうる（裏取り #10 で実測）。この穴は **本 PBI では塞げず、独立 issue [#978](https://github.com/s977043/plangate/issues/978) の担当**（R-6 参照）。AC の検証時は前提充足を明示すること。

- **AC-1**: 導入先 `ho-paths.md` §2 に列挙された glob に一致する `changed_files` を含む入力に対し、arbiter が **escalate（`HUMAN_ESCALATED`）を機械的に返す**。負側テストで固定する
- **AC-2**: **`allowed_paths` の宣言漏れがあっても escalate される**こと。具体的には「§2 パスが `allowed_paths` に**含まれている**（＝`scope_violation` が発火しない）」入力でも AC-1 の escalate が成立することを負側テストで固定する（issue の中心的な盲点。`allowed_paths` はホワイトリストであり §2 保護に使えない — 裏取り #7）
- **AC-3**: **§1（HO）と §2（domain-gate）が provenance 上で区別されて記録される**こと。両方に一致する入力で、どちらの根拠で escalate したかが機械的に判別できる（記録形式は U-3 の決定に従う）
- **AC-4**: **#916 の評価器が再利用されており、#906 側に独立した判定ロジックが存在しない**こと。検証: §2 判定が #916 AC-5 の一般形関数を呼び出していることをコード上で示し、かつ #916 の carve-out 判定と §2 判定が**同一関数**を通ることをテストで固定する（二重実装の機械的排除）
- **AC-5**: **§2 の入力ソースが解決不能な場合の挙動が fail-closed** であること。「§2 節が存在しない導入先」（＝現 main の `ho-paths.md` と同じ構成）で**従来挙動が不変**（§1 のみで判定・回帰なし）であり、かつ「§2 を宣言しているのに解決・パースできない」場合は `HUMAN_ESCALATED` に倒れること。両者を区別してテストで固定する
- **AC-6**: **§1 検知の回帰なし**。既存 247 テスト（`python3 scripts/ai-loop/test_arbiter.py`・リポジトリルート起点）が全 PASS。とくに `test_clean_path` / `test_docs_ai_ai_loop_excluded` / `test_ho_paths_md_itself` / `test_ho_pattern_drift_against_source_of_truth`
- **AC-7**: **rollout-policy §5 不変条件が無傷**であること（差分で確認。§5 に触れていない）
- **AC-8**: 導入先が §2 をどう書けばよいかが**正本 1 箇所に明文化**され、`execution-runbook.md` の導入先 ho-paths 確定手順（L14-18）と plugin 同梱雛形から参照可能であること（U-2 で「記法規約が必要」と決した場合のみ。不要と決した場合はその根拠を decision-log に記録）
- **AC-9**: テスト 2 系統がいずれも green
  - `sh tests/run-tests.sh`（PlanGate 本体 harness。**arbiter のテストは含まれない**）= **492 passed, 0 failed**（main `c474b70` 基点で実測。**exec 開始時に現 main 基点で再実測**して baseline を更新すること）
  - `python3 scripts/ai-loop/test_arbiter.py`（**リポジトリルート起点必須**）= **247 tests OK** + 新規追加分

---

## Notes from Refinement

### 提案 (A) / (B) の推奨: **(A) を推奨**（最終決定は plan / C-3 へ送る）

issue #906 は次の 2 案を挙げている:

- **(A)** arbiter が `--ho-paths` で解決した導入先 `ho-paths.md` の **§2 パターンも escalate トリガーとして評価**する（§1 の HO と §2 の domain-gate を区別しつつ両方を機械検知）
- **(B)** LoopSpec に `scope.escalate_paths`（または `deny_paths`）を追加し、`changed_files` が一致したら escalate（`allowed_paths` の補集合を明示宣言）

**推奨は (A)**。理由（すべて実測に基づく）:

1. **#916 の評価器 IF に整合する**のが (A) である。#916 は同じ 2 案を検討したうえで **(A) を採用**し、**(B)（LoopSpec `escalate_paths` / `deny_paths`）を Out of scope として明示的に非採用**にした（`docs/working/TASK-0916/pbi-input.md` L67 / L85-89）。#906 が (B) を採ると、#916 の「ファイル由来のパターン集合を実行時解決 → 一般形評価器へ渡す」経路とは別に **LoopSpec → arbiter の変換層**が必要になり、Human 指示の「評価器を二重実装しない」に反する構造になる
2. **`loopspec.md` L24 が「LoopSpec は arbiter.py への入力そのものではない」と明記**している（実測）。(B) は arbiter が消費しない宣言物に enforcement を載せる形になり、変換層の分だけ経路が増える
3. **`escalate_paths` / `deny_paths` は loopspec.md・arbiter.py いずれにも現存しない**（裏取り #8・grep 0 件）。新規必須/任意フィールドの追加は loopspec.md §2/§3 の必須フィールド表・記入例・導入先ドキュメントへの追従コストを伴う
4. **(A) は「入力ソースを足すだけ」で #916 の `resolve_ho_patterns()` 同型の解決関数を再利用できる**（`_candidate_ho_paths_sources()` / `resolve_ho_patterns()` L177-220 の構造がそのまま雛形になる）
5. **責務の位置が正しい**。§2 は「このリポジトリでは常に守るべき境界」であり run ごとに変わらない。run 単位の宣言（LoopSpec）ではなく**リポジトリ単位の正本**（ho-paths.md）に置くのが自然で、run ごとの宣言漏れ（issue が問題視している事象そのもの）に強い
   - **⚠️ (A) の弱点（理由 5 の反証・MJ-1）**: **(A) の入力ソースは導入先所有のファイルであり、その正本ファイル自体の欠落は priority 0 で捕捉できない** — 欠落時は plugin 同梱雛形へ静かにフォールバックし（`patterns` が非空になるため fail-closed が発火しない）、全 run が無防備になる。実測で **`decision=AUTO_APPROVED`（priority 6）まで到達**することを確認済み（裏取り #10 / R-6 / [#978](https://github.com/s977043/plangate/issues/978)）。一方 **(B) の LoopSpec `scope.allowed_paths` は `loopspec.md:110` で「必須（1 件以上）・欠落は受理拒否（I-4）」と規定されており、サイレント欠落が構造的に起きない**。この非対称において (B) は (A) より強い
   - **それでも (A) を採る根拠は「#916 との評価器一本化」**（理由 1）である。(A) の上記弱点は #978 で別途塞ぐ前提とし、本 PBI では AC 前提条件として明示する（上記「AC-1〜AC-5 の共通前提条件」）

**(B) を採るべきケース（plan で棄却理由を残す）**: ①run ごとに escalate 対象を変えたい要求が出た場合（現時点で未観測）②#978 が解決されず、正本ファイル欠落のサイレント degradation が受容できないと C-3 で判断された場合（この場合は「(A) + (B) 併用」も選択肢に入る）。

### ⚠️ 「§2 が機械可読な glob 一覧である」前提の成否（本 PBI の最大の論点）

issue は提案 (A) を「`ho-paths.md` 側に §2 を機械可読な glob 一覧で持たせる前提」と書いている。**この前提が現状成立しているかを実測した結果は以下**:

| 観点 | 実測結果 |
|------|---------|
| 本リポジトリ（plangate）の `ho-paths.md` に §2 が存在するか | **存在しない**（裏取り #5）。見出しは `## HO パス一覧` 等のみで §1/§2 の番号節構成を持たない |
| plugin 同梱の導入先向け雛形に §2 の枠があるか | **ない**（裏取り #5）。雛形注記 3 行を前置した本体そのままで、§2 の書き方を導入先に示していない |
| 導入先の `ho-paths.md` の §2 が実際どう書かれているか | **本リポジトリからは確認不能**（別リポジトリ。→ U-1。issue 本文の記述以上の裏取りはできない） |
| §2 がテーブル形式なら arbiter は現状どう振る舞うか | **すでに HO パターンとして取り込み `touches-HO` を返す**（裏取り #6・実行実測）。`parse_ho_paths_table()` は全文走査でセクションを見ないため |
| §2 が箇条書き等なら | **取り込まれず `clean`**（裏取り #6・実行実測）。issue の記述どおりの盲点が成立する |

つまり **issue が報告した盲点は「§2 が表形式で書かれていない」場合に限って成立する**。この事実は本 PBI のスコープを大きく変えうる:

- §2 を表形式に統一するだけで「機械検知される」状態には**到達しうる**が、その状態では **§1 と §2 が同じ `touches-HO` に潰れ**、AC-3（区別記録）を満たさない
- **さらに重要**: #916 の U-1（`docs/working/TASK-0916/pbi-input.md` L163）は「`ho-paths.md` に carve-out 表を追記すると全文走査で HO パターンとして取り込まれてしまうため、案 A を採るなら `parse_ho_paths_table()` の **section-scoped 化**（+ 回帰テスト）が必然」と分析している。**#916 が section-scoped 化を実装した場合、表形式の §2 は逆に取り込まれなくなる**（現在の偶発的な検知が失われる）。これが本 PBI が #916 に従属する最大の技術的理由（→ R-1）

### Mode 判定案（plan で確定）

- **`scripts/ai-loop/**` は rollout-policy §2 の「判定基盤 carve-out」対象**（`docs/workflows/ai-loop/rollout-policy.md` L53「①強制エンジンコード: `scripts/ai-loop/**`」実測）であり、**escalate 固定**とされている
- ただし同 L57 が明記するとおり、これは現状 **規範層**である: 「arbiter（`arbiter.py`）の `boundary_check` は ho-paths.md の HO 表からのみ touches-HO を導出するため、上記 carve-out パスは現状 **boundary=clean と判定される**（機械層では escalate しない）。よって本 carve-out は**規範層**であり、eligible 判定時に**実行者が escalate する責務を負う**（W チェック 2 体が併せて担保）」（末尾の代償コントロール〔W チェック 2 体〕まで含めた完全引用）
- **実測で裏取り済み**: `scripts/ai-loop/**` は `docs/ai/ai-loop/ho-paths.md` の HO 表 21 パターン（実測・全数確認）に**不在** → arbiter は **clean 判定**する。したがって本 PBI を ai-loop で回す場合、**実行者が escalate する責務を負う**（#916 完了後は機械層で escalate 固定になる想定）
- **HO 9 カテゴリ**（`.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` / `.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows/*` / `CLAUDE.md`・`AGENTS.md`）は**非該当**（`scripts/ai-loop/` は `scripts/hooks/` ではない）。ただし §2 記法規約を `docs/ai/ai-loop/ho-paths.md` 側へ書く案を採る場合、**同ファイルは HO-contract として HO 表に登録済み**（`ho-paths.md` L46 実測）のため **Human patch 分離が必須**（前例: `docs/working/TASK-0871/approvals/ho-apply-approval.md` / `docs/working/TASK-0872/patches/`）
- 定量見込み: AI 編集 3〜5（`arbiter.py` / `test_arbiter.py` / §2 正本または雛形 / `execution-runbook.md` / `decision-table.md`）+ sync 自動生成 2〜4（`scripts/sync-plugin-plangate.sh` が `plugin/plangate/skills/ai-loop-cycle/{scripts,references}/` へ同期）→ **6-15 = high 帯**
- 定性: 対象は **arbiter の承認境界判定の分岐そのもの**。`.claude/rules/mode-classification.md` の例外ルール「**承認境界周辺の変更 → 最低でも「高」**」に該当
- **暫定判定: high-risk**（`lite_eligible=false` / C-2 複数観点 + Human C-3 同期。autonomous APPROVE 不可）。**critical 引き上げの検討材料**: 同種の carve-out を散文追加のみで導入した TASK-0907 が Mode=critical であり、#916 も「critical 引き上げを plan で必ず判断する」としている。本 PBI も同基準で plan にて再判定する

### 補足（issue 記載・docs 提案 / 本 PBI では扱いを plan 判断とする）

issue 末尾は「`execution-runbook.md` に、**app コード run は docs-only run と異なりローカル gate（phpunit 等）検証が必須**である旨の注記を追加すると導入先の事故を減らせる」と提案している。本 PBI の主題（§2 の機械検知）とは別軸のため、**同梱するか別 issue に切り出すかを plan で判断**する（同梱するなら AC を 1 本追加）。

---

## Estimation Evidence

### Risks

| ID | Risk | 影響 | 一次緩和 |
|----|------|------|---------|
| **R-1** | **#916 の U-1 決定（`parse_ho_paths_table()` の section-scoped 化）により、現在偶発的に成立している「表形式 §2 の取り込み」が失われる** | 本 PBI が想定するベースラインが #916 のマージ前後で反転する。#916 より先に設計を固めると手戻り | **#916 完了まで exec に入らない**（依存関係節）。plan の前提として #916 U-1 の決定を明示的に参照する |
| **R-2** | **§2 が機械可読でない場合、導入先 `ho-paths.md` のフォーマット変更が必要になり、導入先への影響が出る** | 既に §2 を運用している導入先が、本 PBI のマージで「書き直さないと保護されない」状態になる。移行期間中は保護が空白になりうる（silent degradation） | ①「§2 節が存在しない / 従来記法のまま」なら**従来挙動が不変**（AC-5 前半）にする ②新記法の採用は導入先の opt-in とし、未対応でも既存の §1 判定と `scope_violation` は不変にする ③雛形・runbook に移行手順を明記する（AC-8） |
| **R-3** | §1 と §2 を同一の `touches-HO` に潰すと、監査上「HO 接触」と「domain-gate 接触」が区別できず、rollout-policy §5 の「HO 接触＝無条件 escalate」の意味が薄まる | 不変条件の記述と実挙動がズレる（正本間ドリフト） | AC-3。`boundary` 値の設計（新値追加 / 別フィールド / `classification` のみで区別）を U-3 として plan で決め、`decision-table.md` へ反映する |
| **R-4** | §2 判定を `boundary_check()` に混ぜ込むと既存 247 テストが大量に落ちる | 「挙動を変えた」と誤読され論点が発散する | #916 と同じく **`boundary_check()` は変更せず別関数 + 新 priority 行の additive 変更**にする（AC-6 で固定） |
| **R-5** | §2 が広すぎて導入先の通常の app コード run が常時 escalate になる | 機械強制が形骸化し override 運用に流れる | §2 の内容は**導入先が決める**（本 PBI は評価器接続のみ）。雛形には「クロスリポ影響のある共有資産に限る」旨のガイドを添える（AC-8） |
| **R-6** | **導入先が `ho-paths.md` を配置し忘れた場合、arbiter は plugin 同梱の plangate 用雛形（21 パターン）を解決してしまい、`patterns` が非空のため priority 0（fail-closed）が発火しない** | 導入先の §1 も §2 も保護されないまま、**`boundary=clean` にとどまらず `decision=AUTO_APPROVED`（priority 6）まで到達しうる**（裏取り #10 で実測。雛形 21 パターンに対し `app/Models/Service.php` は `clean` → lite 4 軸 true・verdict approve-approve で priority 6 到達）。**(A) を採る際の最大の弱点**（(A)/(B) 推奨の理由 5 の反証） | **独立 issue [#978](https://github.com/s977043/plangate/issues/978) として起票済み**（本 PBI では塞がない）。本 PBI 側では AC-1〜AC-5 の共通前提条件として「導入先 ho-paths が解決済みであること」を明示する。現状の防御は `execution-runbook.md` L14-18 の**規範**（「未確定のまま run を開始してはならない」）のみ。#978 の解決順序との関係は U-8 で判断 |
| **R-7** | `decision-table.md` と `arbiter.py` の priority が乖離する | 正本間ドリフト | #916 と同じく `decision-table.md` への行追記を In scope に含める（plan で確定） |

### Unknowns

- **U-1**: **導入先 `ho-paths.md` の §2 の実際の記法**（テーブル形式か / 箇条書きか / 列構成）。本リポジトリからは確認不能（裏取り #5）。**#916 完了前に導入先の実ファイルを 1 件でも確認できるか**を plan の最初のタスクにする。確認できない場合は「両記法を受理する」か「新記法を規約化して opt-in にする」かを安全側で決める
- **U-2**: **§2 の記法規約を新設するか、既存テーブル形式に載せるか**。(a) `ho-paths.md` に `## 2. domain-gate パス一覧` 節を規約化し section-scoped パーサで読む / (b) §1 と同じ表に `domain-gate` 分類を混在させ `classification` 値で区別する / (c) 専用ファイルを新設する — の 3 案比較。(b) は現状すでに動く（裏取り #6）が §1/§2 が同一 `boundary` に潰れる。**#916 の U-1 の決定と整合させること**
  - **⚠️ (c) 採用時の必須追加作業（MJ-2）**: 新正本を `docs/ai/ai-loop/` 配下に置く場合、**`scripts/sync-plugin-plangate.sh` の `_ai_loop_spec_files`（L212）へ新ファイル名を追加することを In scope に含める**。同変数は `docs/ai/ai-loop/` 配下を **明示列挙の whitelist**（現在 6 ファイル: `design-philosophy.md` / `arbiter-policy.md` / `concept.md` / `README.md` / `hotl-merge-entry-criteria.md` / `related-specs.md`。L294-297 のループが参照）で同期しており、`docs/workflows/ai-loop/*.md` の glob 同期（L288-292）とは扱いが異なる。**追加し忘れると plugin 経由の導入先へ §2 正本が配布されず、§2 判定が常時 no-op になる**（＝本 PBI が塞ごうとしている silent degradation の再生産）。#916 も同論点を In scope 2（RV-M3）として In scope 化済み。`docs/workflows/ai-loop/` 配下に置く案なら glob 同期のため追加不要 — この配置差も (c) の比較軸に含めること
- **U-3**: **§2 一致時の `boundary` / `scope_check` / provenance の表現**。`touches-HO` と同値にするか、新値（例: `touches-domain-gate`）を足すか、`matched[].classification` のみで区別するか。`decision-table.md` L246-250 の provenance フィールド定義への追記要否を含む
  - **⚠️ 構造的制約（mn-5）**: `priority_table` のループ（`arbiter.py` L1064-1069）は **guard が最初に真になった行で `return` する first-match-return** であり、HO と §2 の両方に一致する入力では **priority 1（touches-HO）で確定し、後段の §2 行は評価されない**。さらに #916 AC-3 は「両方一致時の裁定理由を `priority 1` のままに固定する」ことをテストで要求している。したがって **§2 を priority 1 より後ろに置く限り、AC-3 の「どちらの根拠で escalate したか」の記録は priority 行の戻り値では実現できない** — §2 の provenance は **`Signals`（`arbiter.py` L820-838）や `matched[]` 等、priority 分岐の外側**に記録する必要がある。この制約を前提に設計すること
- **U-4**: **priority の割当**。#916 が挿す新 priority 行を §2 でも共有するか、別 priority 行を足すか。既存は `0, 1, 1.5, 1.6, 1.65, 1.7, 1.9, 1.95, 2, 3, 4, 5, 6`（実測）
- **U-5**: **`POLICY_REF` の改版要否**。#916 は「新規 escalate 分岐の追加＝gate 挙動変更」として `@v4` → `@v5` の改版を確定させている。#906 が #916 の直後に入る場合、さらに改版するか同版に含めるかを plan で決める（`PolicyRefVersionTests` の期待値更新を伴う）
- **U-6**: **CLI 引数の要否**（`--domain-gate-paths` 等）。§2 が `ho-paths.md` 内に同居するなら既存 `--ho-paths` で足りる。別ファイル案（U-2 (c)）を採る場合のみ必要
- **U-7**: **issue 末尾の docs 提案**（app コード run のローカル gate 検証必須の注記）を本 PBI に同梱するか別 issue にするか
- **U-8**: **R-6（雛形フォールバックによる silent `AUTO_APPROVED`）と本 PBI の解決順序**。**issue 起票そのものは [#978](https://github.com/s977043/plangate/issues/978) として完了済み**（本 PBI では実装しない）。残る判断は「#978 の解決を本 PBI の前提条件にするか（＝前提未充足のまま §2 を接続しても導入先が守られないため #978 を先行させるか）」「本 PBI と並行でよいか」
- **U-9**: **解決層（resolver）を #916 と共有するか複製するか**（mn-4）。#916 は In scope 2 で carve-out 用に「`resolve_ho_patterns()` と同型の解決関数」を新設する。#906 がさらに §2 用の第 3 の解決関数を複製するのか、**#916 の解決関数を source 引数で parameterize して共有する**のかが未定義。AC-4 が縛るのは評価器（マッチング層）の同一性のみで解決層は無拘束のため、「評価器は 1 本だが resolver は 3 本」という Human 指示の趣旨に反する構造が exec で採用されうる。**共有（parameterize）を既定案とし、複製を選ぶ場合は根拠を decision-log に残す**方針で plan にて確定する

### Assumptions

- **#916 が先行して完了し、AC-5 の一般形評価器（`(patterns, changed_files) -> (hit, matched)`）が実装される**こと。本 PBI はその関数を再利用する前提で見積もっている
- #916 が `boundary_check()` を変更しない additive 設計（同 In scope 1）を維持すること
- `_ho_pattern_to_regex()` のセグメント意味論（`*` = 1 セグメント内 / `**` = 0 個以上）が §2 glob にもそのまま適用できること（`.env*` / `app/Models/*.php` / `database/migrations/**` はいずれも同記法で表現可能 — 実測で `.env*` の一致を確認済み）
- **導入先自身の `ho-paths.md` が `--ho-paths` 明示指定または CWD（`docs/ai/ai-loop/ho-paths.md`）で解決済みであること**（AC-1〜AC-5 の共通前提条件）。**この前提が崩れると本 PBI の §2 判定は一切機能せず、`AUTO_APPROVED` まで到達しうる**（裏取り #10 実測 / R-6 / [#978](https://github.com/s977043/plangate/issues/978)）。本 PBI はこの前提の充足自体を保証しない
- テスト baseline: `python3 scripts/ai-loop/test_arbiter.py` = **247 OK**（リポジトリルート起点必須）/ `sh tests/run-tests.sh` = **492 passed, 0 failed**（いずれも main `c474b70` 基点で実測）
- rollout-policy §2 の carve-out 定義（`scripts/ai-loop/**` を含む①〜③）が現行のまま維持されること（L52-58 実測）
- 導入先リポジトリ側の `ho-paths.md` 実体の編集は導入先の責務であり、本 PBI は仕様・雛形・評価器接続までを提供する
