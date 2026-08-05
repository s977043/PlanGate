# PBI INPUT PACKAGE — TASK-0978

> Issue: [#978](https://github.com/s977043/plangate/issues/978) — 「導入先に `ho-paths.md` が無いと plugin 同梱雛形へフォールバックし、fail-closed が発火せず導入先の HO が無保護のまま run が進む」
> 作成: 2026-08-05（**main `a2a02b9e66d5ba928fd06374a158c9b37cdd4250` で行番号・件数・再現をすべて実測**。行番号は目安であり記号アンカー〔関数名・定数名・テスト名〕を正とする）
> 関連: [#906](https://github.com/s977043/plangate/issues/906)（§2 domain-gate 接続）/ [#916](https://github.com/s977043/plangate/issues/916)（共通 escalate-path 評価器）/ [#1005](https://github.com/s977043/plangate/issues/1005)（Reliability Recovery。本 Issue は approval-boundary vertical slice に選定済み）/ [#870](https://github.com/s977043/plangate/issues/870)（EPIC ai-loop vNext）

---

## Context / Why

`scripts/ai-loop/arbiter.py` の HO パターン解決 `_candidate_ho_paths_sources()` は、`--ho-paths` 未指定時に

1. CLI 明示（`--ho-paths`）
2. `CWD/docs/ai/ai-loop/ho-paths.md`（導入先の正本）
3. スクリプト位置基準の `../references/ho-paths.md`（**plugin 同梱の plangate 用雛形**）

を順に探索する。導入先が自分の `ho-paths.md` を配置し忘れると 3 番目にフォールバックし、`patterns` が **plangate 自身の HO 21 パターンで非空**になるため、`arbitrate()` の **priority 0（パターン解決不能 → 全件 `HUMAN_ESCALATED`）という fail-closed が発火しない**。

### 深刻度: `clean` 判定にとどまらず `AUTO_APPROVED` まで到達する

issue 本文は「導入先の HO が無保護のまま run が進む」と記載していたが、issue コメントの独立再現、および**本 pbi-input 作成時に隔離環境で 3 度目の独立再現**を行い、**最終裁定 `AUTO_APPROVED`（exit code 0）まで抜ける**ことを確認した（下記「裏取り結果」#10）。`boundary_check=clean` → priority 6 で `AUTO_APPROVED` に到達するため、帰結は「escalate されない」ではなく「**自動承認される**」である。

現状の防御は `docs/workflows/ai-loop/execution-runbook.md` §0「導入先での開始手順（Phase 1）」項目 1 の**規範のみ**（「未確定のまま run を開始してはならない（規範）」と明記）であり、機械層の担保がない。

---

## 裏取り結果（作成時点 main = `a2a02b9e66d5ba928fd06374a158c9b37cdd4250`）

| # | 調査項目 | 実測方法 | 結果 |
|---|---------|---------|------|
| 1 | `_candidate_ho_paths_sources()` の探索順と各候補の解決条件 | `scripts/ai-loop/arbiter.py` L177-190 を実読 | **確認**。`cli_path` が truthy なら **`[Path(cli_path)]` 1 件のみを返し他候補を一切試さない**（L184-185）。未指定時は `[CWD/docs/ai/ai-loop/ho-paths.md, script_dir.parent/references/ho-paths.md]` の 2 件（定数 `_DEFAULT_HO_PATHS_RELATIVE` L144 / `_BUNDLED_HO_PATHS_RELATIVE` L147）。**候補 ③ の基点は `pathlib.Path(__file__).resolve().parent.parent`＝スクリプト配置の親**であり、CWD にも repo にも依存しない |
| 2 | `resolve_ho_patterns()` の「解決できた」判定 / `parse_ho_paths_table()` が 0 件のときの扱い | `arbiter.py` L193-220 を実読 | **確認**。候補ごとに `is_file()` → `read_text()`（`OSError` / `ValueError`＝不正 UTF-8 は skip して次候補）→ `parse_ho_paths_table()` を実行し、**`patterns` が非空になった最初の候補で return**（L216-217）。ファイルは存在するがパース 0 件なら「不採用・次候補へ」（L218-219）。全候補失敗で `([], None, searched)`。**判定基準は「件数 ≥ 1」だけであり、内容が導入先のものかは一切検査しない** |
| 3 | priority 0 の fail-closed 条件 | `arbitrate()` L942-955 を実読 | **確認**。条件は **`if not ho_patterns:` の 1 つだけ**（L947）。`ho_paths_source` の由来・妥当性は条件に入らない。成立時は `boundary="unresolved"` / `scope_check="unresolved"` / `decision=HUMAN_ESCALATED` で early-return（L948-955）。**patterns が非空である限り priority 0 は構造的に発火しえない** |
| 4 | 雛形の実体 | `ls` + `diff docs/ai/ai-loop/ho-paths.md plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md` + `grep -c '^\| \`' docs/ai/ai-loop/ho-paths.md` | **存在する**（`plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md`・8727 bytes）。パターン数は **21**（正本 `docs/ai/ai-loop/ho-paths.md` と同数）。diff は **冒頭 4 行の追加のみ**（雛形注記 3 行 + 空行）で、**HO 表の中身は plangate 自身の HO 表と完全同一** |
| 5 | `ho_paths_source` の record 記録 | `build_provenance()` L727-728 / L789-790、`arbitrate()` L933-934、`docs/workflows/ai-loop/decision-table.md` L250-251 | **記録済み（#809 で導入）**。arbiter provenance に `ho_paths_source`（解決された**絶対パス文字列**。未解決時 `null`）と `ho_pattern_count`（int）を**全裁定経路で刻む**。ただし記録されるのは**パス文字列のみで「解決元の種別（CLI / 導入先 / 雛形）」は記録されない**。また `grep -c ho_paths_source scripts/ai-loop/{run_evidence,run_evidence_verify,metrics}.py` → **すべて 0**（RunEvidence / metrics には伝播していない）。→ AC-3 は「部分的に既存・種別と RunEvidence が不足」 |
| 6 | 既存の規範層の防御 | `docs/workflows/ai-loop/execution-runbook.md` §0 項目 1（**L13-20**）を実読 | **確認。かつ当該記述は現状「事実に反する安全保証」になっている**（River Review mn-2）。原文（L17-20）は「…未確定のまま run を開始してはならない（規範。`arbiter.py` は `--ho-paths` 明示指定 → CWD → スクリプト位置基準の順で実行時解決し、**未確定**・パース結果 0 件時は全件 human escalate する fail-closed を実装済み — #809）」＝**「未確定」も含めて fail-closed を約束している**。しかし plugin レイアウトでは**未確定でも fail-closed しない**（裏取り #10）。→ **導入先の運用者が「配置し忘れても安全側に倒れる」と誤認できる**（本 issue の Why と同じ被害面）。是正対象として In scope 要素 6 に組み込んだ |
| 7 | plangate 自身の run で雛形が正しい解決元か（案 A で壊してはいけない経路） | 隔離環境で `cd <repo root> && python3 scripts/ai-loop/arbiter.py`、および `cd <repo root> && python3 plugin/.../scripts/arbiter.py` を実行 | **repo root からの self-run では雛形は解決元にならない**（候補 ② `CWD/docs/ai/ai-loop/ho-paths.md` が常に先に一致する）。`.claude/skills/ai-loop-cycle/SKILL.md` L151 の正規呼び出しも `python3 scripts/ai-loop/arbiter.py`（repo root 起点）。→ **「雛形が正しい解決元である plangate self-run」は少なくとも documented な CLI 経路には存在しない**（例外は #8bis のテスト経路） |
| 8 | 配布の実態（雛形が「plangate 用」と区別できる材料） | `scripts/sync-plugin-plangate.sh` L348-361 を実読 + 生成物 L1-4 を確認 | **マーカーは既に存在する**。sync 時に `printf` で **3 行の「雛形注記」ヘッダを前置**してからリンク変換する（L351-353）: `> **雛形注記**: 本ファイルは PlanGate リポジトリでの運用実績を示す配布時の参考例です。` / `> HO（Hardening Override）パス一覧はプロジェクト固有につき、**導入先で確定**してください。` / `> 未確定のパスに触れる変更は、arbiter が安全側 escalate（human escalate）する原則を守ってください。`。**このヘッダは正本 `docs/ai/ai-loop/ho-paths.md` には存在しない**（#4 の diff で確認）。ただし **arbiter はこのヘッダを一切参照していない**（`grep 雛形注記 scripts/ai-loop/arbiter.py` → 0 件）。CI drift 検出は `.github/workflows/sync-plugin-plangate.yml` |
| 8bis | **配布テスト経路では雛形が唯一の解決元になる**（案 A の回帰リスク） | 隔離環境で `cd <repo>/plugin/plangate/skills/ai-loop-cycle && python3 scripts/test_arbiter.py` を実行し、同 CWD で `arbiter.resolve_ho_patterns()` を直接評価 | **247 tests OK**。ただし `resolve_ho_patterns()` の解決元は **`.../ai-loop-cycle/references/ho-paths.md`（count=21）**、探索パス 1 件目（`<skill dir>/docs/ai/ai-loop/ho-paths.md`）は不在。`test_arbiter.py` L22-26 の `_HO_PATHS_CANDIDATES` も「本体 / bundled の 2 通り」を明示的に許容している。→ **雛形解決を無条件に escalate 化すると、配布 skill ディレクトリ起点のテスト実行が壊れる**（AC-5 が指定する repo root 起点 `python3 scripts/ai-loop/test_arbiter.py` は候補 ② を使うため無影響） |
| 9 | テスト baseline | `python3 scripts/ai-loop/test_arbiter.py`（repo root 起点） | **247 tests OK**（main `a2a02b9` 実測。issue AC-5 の調査時点値と一致） |
| 10 | **雛形フォールバックの再現（本 pbi-input 作成時の独立再現）** | `git archive a2a02b9` を scratchpad へ展開 → `ho-paths.md` を持たない空の導入先 CWD から `python3 <repo>/plugin/plangate/skills/ai-loop-cycle/scripts/arbiter.py --input input.json` を実行。入力 = `changed_files=["app/Models/Service.php", ".env"]` / `allowed_paths=["app/**",".env"]` / `lite` 全 true / `verdicts=approve-approve` / `gates={c1:PASS,breakdown:pass}` | **再現**。`class:"no-merge"` で `decision=AUTO_APPROVED` / `priority 6: verdict=approve-approve（合意）` / `boundary_check="clean"` / `scope_check="in_scope"` / `ho_paths_source=<...>/references/ho-paths.md` / `ho_pattern_count=21` / **exit code 0**。`class:"merge"` に変えると priority 3 で `HUMAN_ESCALATED`（exit 2）となるため、**`no-merge` クラスの run が自動承認まで到達する** |
| 11 | **対照実験: repo-checkout レイアウトでは正しく fail-closed する** | 同じ空の導入先 CWD から `python3 <repo>/scripts/ai-loop/arbiter.py` を実行 | **`priority 0: ho-paths unresolved (fail-closed)`（`boundary=unresolved` / exit 2）**。候補 ③ が `<repo>/scripts/references/ho-paths.md` を指し不在になるため。→ **本欠陥は「雛形が scripts/ の隣に同梱される plugin レイアウト固有」** |
| 12 | **対照実験: 雛形を導入先パスへ逐語コピーした場合** | 導入先 CWD に `docs/ai/ai-loop/ho-paths.md` として雛形をコピーし再実行 | **`AUTO_APPROVED`（`ho_paths_source=<downstream>/docs/ai/ai-loop/ho-paths.md`・count=21）**。→ **パス由来だけで判定する案 A はこの誤用を捕捉できず、内容マーカーを見る案 B だけが捕捉できる**（3 案比較の決定的材料） |

| 13 | **導入先が `references/ho-paths.md` を自前で書く運用は「実在するか未確認」ではなく、公式ドキュメントが指示している**（U-4 の解決 / River Review MJ-1） | 3 系統の文書を実読 | **確定**。① `docs/workflows/ai-loop/execution-runbook.md` **L15**「`docs/ai/ai-loop/ho-paths.md`（**plugin 導入先は `references/ho-paths.md`**）の…（略）…導入先固有のパス一覧として定義する」/ ② `plugin/plangate/skills/ai-loop-cycle/SKILL.md` **L295** と `.agents/skills/ai-loop-cycle/SKILL.md` **L295**「`references/ho-paths.md` — HO（Hardening Override）パス一覧（**プロジェクト固有・導入先で確定**）」/ ③ `docs/working/TASK-0809/test-cases.md` **L15** TC-9「bundled 展開先（plugin scripts/ + references/）… test_arbiter が自立 PASS（**`references/ho-paths.md` を解決**）」＝**期待動作として固定済み**。→ **案 A（bundled 相対パスなら fail-closed）は、ドキュメントどおりに自前 `references/ho-paths.md` を書いた導入先を恒常 escalate にする**（R-2 の事故そのもの） |
| 14 | **案 A / A+B の破損件数シミュレーション**（River Review MJ-2 の追試。**本 pbi-input 作成時に独立再現**） | 隔離環境の `a2a02b9` コピーへ最小パッチを当てて 2 系統でテスト実行。案 A = 解決候補が `_BUNDLED_HO_PATHS_RELATIVE` 経由なら skip / 案 B = `read_text()` 済み `content` に雛形マーカー文字列を含むなら skip | **repo root 起点: 案 A / A+B とも 247 OK（回帰を検出できない）。skill dir 起点: 案 A = `FAILED (failures=132, errors=4)` / A+B = `FAILED (failures=132, errors=4)`**。レビュアーの最小シミュレーション値（A=90 / A+B=106）とは実装形の違いで件数が前後するが、**方向（repo root 無傷 / skill dir 大量破損）は一致**。さらに **A+B 下で `resolve_ho_patterns('plugin/.../references/ho-paths.md')`（explicit 明示指定）を評価 → `count=0, source=None`＝fail-closed**。→ **`--ho-paths` 明示注入は A+B では救済にならない**（R-1 の緩和策が無効） |

> 再現に使った作業ディレクトリは scratchpad 配下の一時領域で、報告後に削除済み。実リポジトリの CWD では雛形が解決されないため再現しない（#7 / #11）。

---

## What（Scope）

### In scope

雛形フォールバックと「導入先の境界が定義済み」を**機械的に区別**し、区別できない run を fail-closed に倒す。

#### 3 案の実装可能性比較

| 観点 | **案 A**: 解決元が plugin 同梱雛形なら fail-closed | **案 B**: 雛形マーカーを検出して警告 + escalate | **案 C**: 解決元を record に記録して監査可能にする |
|------|--------------------------------|------------------------------|------------------------------|
| 検出の根拠 | **解決に使った候補のインデックス**（`_BUNDLED_HO_PATHS_RELATIVE` 経由か）。パス由来 | **ファイル内容の雛形マーカー**（sync が前置する「雛形注記」行 / 将来的な機械可読マーカー） | 記録のみ（検出しない） |
| 実装量 | 小。`resolve_ho_patterns()` が **どの候補で解決したかの種別**を返すよう戻り値を拡張 → `arbitrate()` の priority 0 近傍に分岐追加 | **小**。マーカーは `resolve_ho_patterns()` が**既に `read_text()` 済みの `content` への部分一致 1 行**で判定でき、**sync script 側の変更は不要**（裏取り #14 のシミュレーションは arbiter 2 行追加で成立）。機械可読化まで進める場合のみ sync script 変更を伴う | 極小。`ho_paths_source` は**既に記録済み**（裏取り #5）。追加は「種別」と RunEvidence 伝播のみ |
| **#12（雛形の逐語コピー）を捕捉できるか**＝偽陰性 | **No**（パスが導入先なので DOWNSTREAM と判定され auto-approve） | **Yes**（内容にマーカーが残る） | No（監査時に人が気づけるだけ） |
| **導入先の正当な `references/ho-paths.md` を誤って潰さないか**＝偽陽性 | **潰す（致命的）**。公式ドキュメントが `references/ho-paths.md` を導入先の置き場として**明示指示している**（裏取り #13）。ドキュメントどおりに運用した導入先が恒常 escalate になる | 潰さない（導入先が自前で書けばマーカーは無い） | 潰さない |
| **#8bis（配布テストの雛形解決）を壊さないか** | **壊す**（実測: skill ディレクトリ起点で `failures=132, errors=4` / 裏取り #14） | 同左（マーカー付き＝雛形なので同じく escalate 対象。実測も同数） | 壊さない |
| fail-closed 要件（issue Non-goals / #1005 コメント）の充足 | **充足** | **充足**（ただし「警告だけで継続」は #1005 コメントで明示的に不採用。escalate まで行う前提） | **不充足**（機械強制なし） |

**推奨: 案 B（内容マーカー判定）を主軸にし、案 A のパス判定は補助として扱う（B 主軸 + A 補助）。案 C は A/B いずれでも必須の共通要素として全案に内包する。**

> **River Review MJ-1 による改訂**: 当初は「案 A 主軸 + 案 B 併用」としていたが、裏取り #13 で **U-4 が「未確認」ではなく「公式ドキュメントが `references/ho-paths.md` を導入先の置き場として指示している」と確定**したため、**主軸を入れ替えた**。

根拠:

1. **パス由来（案 A）は両方向に外す**。導入先が**ドキュメントどおり** `references/ho-paths.md` に自前定義を書けば**偽陽性**（恒常 escalate / 裏取り #13）、雛形を逐語コピーして導入先パスに置けば**偽陰性**（auto-approve / 裏取り #12）。**パスは「誰が書いた内容か」を表さない**ため、単独では識別軸として成立しない。
2. **内容マーカー（案 B）が唯一「誰が書いたか」に近い識別軸**。雛形にのみ存在し正本には無い（裏取り #4 / #8）。導入先が自前で書けばマーカーは付かず、逐語コピーすればマーカーごと持ち込まれるため、#12 と #13 の両方を正しく分類できる。
3. **#1005 コメントの初回実装境界とは両立する**。同コメントが要求するのは `ResolvedHoPaths{path, source_kind, patterns}` という**構造**と「`BUNDLED_TEMPLATE` なら patterns 非空でも `HUMAN_ESCALATED`」という**挙動**であり、`source_kind` を**どう判定するか**（パス由来か内容由来か）は縛っていない。したがって「`source_kind=BUNDLED_TEMPLATE` の判定をマーカー主軸で行う」は同コメントに適合する。
4. **案 A を完全に捨てるかは plan の判断**。パス判定は「マーカーを消したが中身は雛形のまま」という抜けに対する第 2 の網になりうる一方、裏取り #13 の偽陽性を直接持ち込む。**残すなら「導入先が `references/ho-paths.md` に自前定義を書いた場合を偽陽性にしない条件」を同時に設計する**ことが必須（plan の主要論点）。
5. **案 C は独立案としては Non-goals に抵触する**（規範層の強化にとどまり、issue が「規範では足りない」と述べている主旨に反する）。ただし「解決元を実行時に明示的に記録する」は issue が全案共通で要求しており、かつ現状は**パスのみで種別が無い**（裏取り #5）ため、A/B の実装に必ず含める。

#### 実装に含める要素（3 案共通の必須要素を含む）

1. **解決元の provenance 化**: `resolve_ho_patterns()` が `(patterns, path, searched)` の平坦タプルでなく **source kind を伴う構造**（#1005 コメント案の `ResolvedHoPaths` / `HoPathsSourceKind{EXPLICIT, DOWNSTREAM, BUNDLED_TEMPLATE}` 相当）を返す。既存呼び出し側（`arbitrate()` / テスト）への影響は plan で吸収する。
2. **fail-closed 分岐の追加**: `BUNDLED_TEMPLATE` と判定された解決元で run する場合、`patterns` が非空でも `HUMAN_ESCALATED`。機械判定可能な reason code（例 `HO_BOUNDARY_UNDEFINED`）を付す。
   - **#1005 コメントの限定を落とさないこと**: 原文は「**downstream execution で** `BUNDLED_TEMPLATE` しか解決できない場合」かつ「**PlanGate self-run は bundled template を正当 source として回帰維持**」であり、無条件の escalate ではない。**downstream execution の識別手段は U-5 で確定するまで未定**（`cwd` 名等による暗黙推測は同コメントで禁止）。**限定なしの無条件 escalate は裏取り #8bis / #14 の配布テスト経路を壊す**（実測 `failures=132, errors=4`）ため、plan は「識別手段の確定」と「識別できない場合の扱い」を先に決める。
3. **マーカー検出**（案 B・主軸）: 雛形注記ヘッダを検出したら、パスが導入先であっても `BUNDLED_TEMPLATE` 相当に倒す。実装は `resolve_ho_patterns()` 内の既読 `content` への部分一致で足りる（sync script 変更不要）。
4. **記録**: decision record（arbiter provenance）に source path + **source kind** + reason を刻む。RunEvidence への伝播可否は plan で判断（現状 0 件 = 未伝播 / 裏取り #5）。
5. **plangate self-run の回帰維持**: repo root 起点の self-run（候補 ② 解決）は従来どおり（裏取り #7）。**配布 skill ディレクトリ起点のテスト実行**（裏取り #8bis / #14）の救済策は、以下から plan で選ぶ:
   - **`--ho-paths` による明示注入は救済にならない**（実測 / 裏取り #14）。skill ディレクトリ起点で `test_arbiter.py` L23-27 の `_HO_PATHS_CANDIDATES` が解決する `HO_PATHS_MD` 自体が**マーカー付きの bundled ファイル**であり、B 主軸では explicit 指定でも `count=0, source=None` に倒れる。
   - **採るべき手段**: ① **マーカーを持たない fixture を `tmp_path` に生成して注入**、または ② `boundary_check(ho_patterns=...)` へ**パターンを直接注入**（`arbitrate()` も `ho_paths_path` 経由でなく解決済みパターンを受ける形にできるかを含めて検討）。
   - ③ テスト実行を明示的な例外として扱う案も残るが、「テストだけ通る抜け穴」を作るため plan で妥当性を検証する。
6. **`execution-runbook.md` §0 の保証文言の是正**（mn-2 / 下記「派生する是正対象」参照）。
7. **負側テストの追加**（AC-2）。

#### 派生する是正対象（In scope 要素 6 / River Review mn-2）

`docs/workflows/ai-loop/execution-runbook.md` **L17-20** は「**未確定**・パース結果 0 件時は全件 human escalate する fail-closed を実装済み」と記載しているが、**plugin レイアウトでは「未確定」でも fail-closed しない**（裏取り #10）。この 1 文は現状**事実に反する安全保証**であり、導入先の運用者が「配置し忘れても安全側に倒れる」と誤認できる。

同時に、同 §0 **L15** の「plugin 導入先は `references/ho-paths.md`」という案内は、案 A のパス判定を採るか否かで**扱いが変わる**（裏取り #13）。

- **本 PBI で是正する**（推奨）: 実装の挙動確定と同時に L15 / L17-20 を書き換える。実装と文書が同一 PR で整合する
- **または follow-up issue として切り出す**: その場合も本 pbi-input に記録した以上、**宙に浮かせない**（plan で issue 番号を確定）

### Out of scope

- §2（domain-gate）の評価器接続 — **[#906](https://github.com/s977043/plangate/issues/906)**
- 共通 escalate-path 評価器の実装そのもの — **[#916](https://github.com/s977043/plangate/issues/916)**
- `ho-paths.md` のフォーマット変更（§1/§2 の節構成化）
- リポジトリ同一性を CWD 名等から暗黙推測する仕組みの導入（#1005 コメントで明示的に禁止。explicit execution context が必要になる場合は public contract 追加として replan する）

---

## 受入基準（issue の AC 5 件を 1:1 保持）

| AC | 内容 | 検証方法 |
|----|------|---------|
| **AC-1** | 導入先に `ho-paths.md` が無い状態で arbiter を実行したとき、雛形で素通しにならない（escalate されるか、明示的に検出・記録される） | 裏取り #10 と同一の再現手順（`git archive` した repo + 空の導入先 CWD + plugin レイアウトの `arbiter.py` + `class:"no-merge"` の入力）を実行し、**exit code が 0（AUTO_APPROVED）でないこと**、provenance の `decision` が `HUMAN_ESCALATED` かつ reason code が付くことを確認。**#12 の逐語コピー系も同様に確認**（案 B 併用時） |
| **AC-2** | AC-1 を突く負側テストが追加され、**修正前実装に対して FAIL する**（検出力の実証） | 下記「AC-2 の実現方法」参照 |
| **AC-3** | HO パターンの解決元（CLI / 導入先 / 雛形）が実行時に記録される | provenance JSON に **source kind**（`explicit` / `downstream` / `bundled_template` 相当）が刻まれることを assert。既存の `ho_paths_source`（パス文字列）は後方互換で維持されることも assert（裏取り #5・`decision-table.md` L250-251 の契約） |
| **AC-4** | plangate 自身の run（雛形が正しい解決元であるケース）が従来どおり動作する（回帰なし） | repo root 起点の `python3 scripts/ai-loop/arbiter.py` が従来と同一 decision を返すこと。**さらに合否基準を数値で固定する**: `cd plugin/plangate/skills/ai-loop-cycle && python3 scripts/test_arbiter.py` が **247 + 新規テスト件数で OK**（**repo root 起点だけでは回帰を検出できない**ため必須。実測: 案 A / A+B とも repo root は 247 OK のまま、skill dir 起点のみ `failures=132, errors=4` を検出 / 裏取り #14） |
| **AC-5** | `python3 scripts/ai-loop/test_arbiter.py` が baseline を維持する | exec 開始時に現 main で再実測した値を baseline とする（**本 pbi-input 作成時点 `a2a02b9` で 247 tests OK** を実測済み）。修正後は 247 + 新規テスト件数で OK |

### AC-2（負側テストが修正前実装で FAIL する）の実現方法

「修正前実装で FAIL する」ことを**実証**するには、テストが修正前コードに対して実際に走る必要がある。実現手段を実装可能性順に:

1. **推奨: `resolve_ho_patterns()` / `arbitrate()` を対象とした単体テストを、雛形レイアウトを `tmp_path` 上に再現して書く**
   - `tmpdir/skill/scripts/arbiter.py` 相当の配置は作れないが、**`_candidate_ho_paths_sources()` の基点は `pathlib.Path(__file__)`** なので、テストからは `unittest.mock.patch` で `arbiter._BUNDLED_HO_PATHS_RELATIVE` / `_candidate_ho_paths_sources` を差し替えるか、雛形マーカー付きファイルを `--ho-paths` 相当で渡す形にする。
   - 検出力の実証は **旧実装（`git stash` / 変更前 commit）に同一テストを当てて FAIL を確認**し、その実行ログを evidence に残す（`docs/working/TASK-0978/evidence/test-runs/`）。ユーザー memory の「新規テストは変異注入で検出力を実証」に沿い、**空振りしないこと（旧実装で必ず落ちること）を実測で示す**。
2. **補助: エンドツーエンドの再現テスト**（裏取り #10 の手順をテスト化）
   - `git archive` を伴う重い手順のため単体テストには載せず、`evidence/verification/` に手動再現ログとして残す案も可。plan で自動化可否を判定する。
3. **NG パターン**: 「新実装でのみ通るテスト」を書いて旧実装での FAIL を確認しない運用。AC-2 の要求（検出力の実証）を満たさない。

---

## Mode 判定案

**案: `high-risk`（最低ライン。plan 時に `critical` へ引き上げる可能性あり）**

判定根拠:

- 変更ファイル数見込み: `scripts/ai-loop/arbiter.py` / `scripts/ai-loop/test_arbiter.py` + 契約 doc（`docs/workflows/ai-loop/decision-table.md` 等）+ 配布同期分 → 3〜6 ファイル相当
- 変更種別: **承認境界の判定ロジック変更**（auto-approve 到達可否を直接左右する）→ 定性軸で最上位
- リスク: 高（誤ると「escalate すべき run を auto-approve」または「全 run が escalate して運用停止」の両方向の事故）

### rollout-policy §2 判定基盤 carve-out の扱い（**必ず明記**）

`scripts/ai-loop/**` は [`docs/workflows/ai-loop/rollout-policy.md`](../../workflows/ai-loop/rollout-policy.md) §2 の **判定基盤 carve-out**（L52-57）の ① 強制エンジンコードに該当する。同 L57 が明示するとおり:

- carve-out は **escalate 固定**（本拡張の適用対象から除外）
- ただし **arbiter の `boundary_check` は ho-paths.md の HO 表からのみ touches-HO を導出するため、carve-out パスは現状 `boundary=clean` と機械判定される**（機械層では escalate しない）
- したがって本 carve-out は**規範層**であり、**eligible 判定時に実行者が escalate する責務を負う**（W チェック 2 体が併せて担保）

つまり本 PBI の対象パスは **HO 表そのものには不在なので HO ではない**が、**carve-out 対象である**。ai-loop で本 PBI を回す場合、arbiter は `clean` を返すため、**実行者が規範層の責務として escalate すること**。加えて `docs/workflows/ai-loop/*.md`（② 判定・思想・契約の正本群）に手を入れる場合も同 carve-out に含まれる。

なお、配布派生（`plugin/plangate/skills/ai-loop-cycle/**`）は sync script の生成物であり、正本 carve-out により実質的に保護される（rollout-policy L56）。**配布側を直接編集せず `scripts/sync-plugin-plangate.sh` 経由で再生成する**こと（CI: `.github/workflows/sync-plugin-plangate.yml` が drift を検出）。

---

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|----|-------|------|------|
| R-1 | **無条件 escalate 化で配布テスト経路が壊れる**（裏取り #8bis / #14: skill ディレクトリ起点の 247 tests は雛形が唯一の解決元。実測 `failures=132, errors=4`） | 配布物の自己検証が回らなくなる | **`--ho-paths` 明示注入は救済にならない**（B 主軸では explicit でもマーカーで倒れる / 裏取り #14 実測）。**マーカーを持たない fixture を `tmp_path` に生成して注入**、または `boundary_check(ho_patterns=...)` へのパターン直接注入に置換する。plan で手段を**明示決定**し AC-4 で assert |
| R-2 | 逆方向の事故: 判定が過剰に効き、**正当な導入先 run まで恒常 escalate** になる | 導入先で ai-loop が実質使えなくなる | 導入先が `docs/ai/ai-loop/ho-paths.md` を**自前で書けば**通る経路を必ず残し、テストで固定 |
| R-3 | マーカー（案 B）判定が脆い。導入先が雛形を編集してもマーカー行を残す／消しても中身は雛形のまま | 誤検出・見逃しの両方 | マーカーは「安全側に倒す方向にのみ効かせる」（マーカー有 → escalate。マーカー無は何も保証しない）。パス判定（案 A）と AND でなく OR で合成 |
| R-4 | 既存 provenance 契約（`decision-table.md` L250-251 の `ho_paths_source` / `ho_pattern_count`）との後方互換破壊 | 下流の監査・metrics が壊れる | 既存 2 フィールドは維持し、source kind は**追加フィールド**（additive）とする |
| R-5 | 配布側の直接編集による sync drift | CI 失敗・正本と配布の乖離 | 正本のみ編集 → `scripts/sync-plugin-plangate.sh` で再生成 |

### Unknowns

| ID | 未確定事項 | 解消方法 |
|----|-----------|---------|
| U-1 | **`_BUNDLED_HO_PATHS_RELATIVE` 経由の解決を「常に不正」と断じてよいか** → **断じてはならないことが確定**（裏取り #13: 公式ドキュメントが導入先の置き場として指示 / #8bis: 配布テストが依存）。残る未確定は「**パス判定を補助として残すか、完全にマーカー判定へ寄せるか**」 | plan で決定。パス判定を残すなら裏取り #13 の偽陽性を潰す条件を同時に設計する。判断がつかなければ**マーカー判定のみに寄せる**（偽陽性を作らない側） |
| U-2 | RunEvidence / metrics へ source kind を伝播させるか（現状 `ho_paths_source` すら 0 件 / 裏取り #5） | 本 PBI の初回スコープ（#1005 コメントは「source provenance と downstream fail-closed に限定」）に含めるか plan で判断。含めないなら follow-up issue 化 |
| U-3 | 雛形マーカーを**機械可読形式**（frontmatter 等）へ変えるか、現行の日本語 3 行ヘッダを文字列一致で見るか | 前者は sync script 変更を伴う。Out of scope の「`ho-paths.md` のフォーマット変更」に抵触しないか（変更対象は sync 前置ヘッダであり正本の表形式ではない）を plan で確定 |
| U-4 | ~~導入先がスクリプト隣に自前 `references/ho-paths.md` を置く運用が実在するか~~ **【解決済み・実在する】** | **公式ドキュメントが当該運用を明示指示している**（下記「裏取り #13」）。したがって案 A のパス判定は**導入先で偽陽性を起こす**ことが確定した。→ 3 案の推奨を「マーカー主軸」へ改訂済み。plan では「パス判定を残すなら偽陽性をどう抑えるか」が論点になる |
| U-5 | **explicit execution context（self-run か downstream か）の public contract 追加が必要か** | #1005 コメントは「repository identity を cwd 名等で暗黙推測しない。既存の explicit execution context が無ければ public contract 追加として replan」と指示。現行入力に `production`（Plan-first 入口宣言 / `arbiter.py` L50・L913）はあるが、**これは実行元リポジトリの同一性を表すフィールドではない**（実測）。パス種別判定だけで足りるなら追加不要 |

### Assumptions

| ID | 前提 | 根拠 |
|----|------|------|
| A-1 | 本欠陥は plugin レイアウト（`scripts/` の隣に `references/` が同梱される配置）固有であり、repo-checkout レイアウトでは既に fail-closed する | 裏取り #11 の対照実験で実測 |
| A-2 | 雛形と正本の HO 表は完全同一で、差分は sync が前置する 4 行のみ | 裏取り #4 の `diff` で実測 |
| A-3 | baseline は exec 開始時に現 main で再実測する（本 pbi-input 時点は 247 tests OK / `a2a02b9`） | issue AC-5 の指定どおり |
| A-4 | 本 PBI は `scripts/ai-loop/**` を触るため rollout-policy §2 carve-out に該当し、ai-loop で回す場合は実行者が規範層の責務で escalate する | `rollout-policy.md` L52-57 |

### 実装順序（#906 / #916 との関係）

| PBI | 内容 | 本 PBI との関係 |
|-----|------|---------------|
| **#978（本 PBI）** | ho-paths 解決元の provenance 化 + downstream fail-closed | **#916 / #906 と独立に実装できる**。触る層が異なる（本 PBI = 解決層 `resolve_ho_patterns()` / #916 = 評価層 `(patterns, changed_files) -> (hit, matched)`）。#1005 コメントも初回 PR を「source provenance と downstream fail-closed に限定」と指示 |
| #916 | 共通 escalate-path 評価器（一般形） | 本 PBI が確定する `ResolvedHoPaths` 構造は #916 の評価器へ渡す**入力の出所**になるため、**本 PBI を先行させると #916 が provenance 付き入力を前提に設計できる**（逆順だと #916 実装後に戻り値契約を変えることになる） |
| #906 | §2 domain-gate を #916 の評価器へ接続 | #916 完了が前提（TASK-0906 pbi-input 記載）。本 PBI とは直列依存なし |

**推奨順序: #978 → #916 → #906**（解決層 → 評価層 → 入力ソース追加）。ただし #1005 の start gate（#921 完了・negative-control evidence 2 件以上・implementation WIP < 2・本 Issue 個別 plan の Human C-3）が先行条件である。

---

## Notes from Refinement

- issue コメント（#1005 vertical slice 指定）が **初回実装の推奨境界を具体的なコード形（`HoPathsSourceKind` enum / `ResolvedHoPaths` dataclass）で提示している**。plan はこれを出発点にする。「警告だけで継続する案は fail-closed を満たさないため採用しない」は確定事項として扱う。
- 本 pbi-input の再現（裏取り #10 / #11 / #12）は隔離環境で実施し、作業ディレクトリは削除済み。実リポジトリでは雛形が解決されないため同手順では再現しない。
- **本 pbi-input 作成で新たに判明し issue に未記載の事実**（plan / C-2 で扱うこと）: ① 欠陥は plugin レイアウト固有（#11）/ ② 雛形の逐語コピーは案 A では捕捉できない（#12）/ ③ 配布テスト経路が雛形解決に依存している（#8bis）/ ④ 雛形マーカーは既に sync script が前置している（#8）/ ⑤ `ho_paths_source` はパス文字列としては既に記録済みだが種別が無く RunEvidence へも未伝播（#5）/ ⑥ **公式ドキュメントが `references/ho-paths.md` を導入先の置き場として指示している**（#13）/ ⑦ **`execution-runbook.md` L17-20 の fail-closed 保証文言が現状事実に反する**（#6）。
- **River Review（2026-08-05）の反映**: major 2 件（MJ-1: U-4 は解決済みで案 A は偽陽性を起こす / MJ-2: R-1 の緩和策「`--ho-paths` 明示注入」は B 主軸では機能しない）+ minor 2 件（mn-1: #1005 の「downstream execution で」という限定の欠落 / mn-2: runbook の保証文言）+ info 1 件（AC-4 の合否基準を数値化）を反映。**MJ-1 により 3 案の推奨主軸を「案 A 主軸」→「案 B（内容マーカー）主軸 + 案 A 補助」へ入れ替えた**。MJ-2 の破損件数は本 pbi-input 作成時に**独立に追試**しており（裏取り #14）、レビュアーの最小シミュレーション値（A=90 / A+B=106）とは実装形の差で件数が前後するが**方向は一致**する。

---

## 参照

- `scripts/ai-loop/arbiter.py`（`_candidate_ho_paths_sources` / `resolve_ho_patterns` / `parse_ho_paths_table` / `arbitrate` / `build_provenance`）
- `scripts/ai-loop/test_arbiter.py`（`_HO_PATHS_CANDIDATES` / `test_tc2_candidate_order_cwd_before_bundled` / `test_tc3_fail_closed_when_explicit_path_missing`）
- `scripts/sync-plugin-plangate.sh`（雛形注記ヘッダ前置）
- [`docs/ai/ai-loop/ho-paths.md`](../../ai/ai-loop/ho-paths.md) / `plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md`
- [`docs/workflows/ai-loop/decision-table.md`](../../workflows/ai-loop/decision-table.md) §5（provenance フィールド契約）
- [`docs/workflows/ai-loop/execution-runbook.md`](../../workflows/ai-loop/execution-runbook.md) §0（導入先での開始手順・規範層）
- [`docs/workflows/ai-loop/rollout-policy.md`](../../workflows/ai-loop/rollout-policy.md) §2（判定基盤 carve-out）
- [`docs/working/TASK-0906/pbi-input.md`](../TASK-0906/pbi-input.md)（形式踏襲元・同じ arbiter 領域）
