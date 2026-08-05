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
| 6 | 既存の規範層の防御 | `docs/workflows/ai-loop/execution-runbook.md` §0 項目 1 を実読 | **確認**。「導入先固有のパス一覧として定義する。**未確定のまま run を開始してはならない（規範**。`arbiter.py` は …未確定・パース結果 0 件時は全件 human escalate する fail-closed を実装済み — #809）」。**「パース結果 0 件時」しか fail-closed を約束しておらず、雛形が非空で解決されるケースは規範でも機械層でも塞がれていない**（記述自体は事実として正しいが、本 issue の穴を覆わない） |
| 7 | plangate 自身の run で雛形が正しい解決元か（案 A で壊してはいけない経路） | 隔離環境で `cd <repo root> && python3 scripts/ai-loop/arbiter.py`、および `cd <repo root> && python3 plugin/.../scripts/arbiter.py` を実行 | **repo root からの self-run では雛形は解決元にならない**（候補 ② `CWD/docs/ai/ai-loop/ho-paths.md` が常に先に一致する）。`.claude/skills/ai-loop-cycle/SKILL.md` L151 の正規呼び出しも `python3 scripts/ai-loop/arbiter.py`（repo root 起点）。→ **「雛形が正しい解決元である plangate self-run」は少なくとも documented な CLI 経路には存在しない**（例外は #8bis のテスト経路） |
| 8 | 配布の実態（雛形が「plangate 用」と区別できる材料） | `scripts/sync-plugin-plangate.sh` L348-361 を実読 + 生成物 L1-4 を確認 | **マーカーは既に存在する**。sync 時に `printf` で **3 行の「雛形注記」ヘッダを前置**してからリンク変換する（L351-353）: `> **雛形注記**: 本ファイルは PlanGate リポジトリでの運用実績を示す配布時の参考例です。` / `> HO（Hardening Override）パス一覧はプロジェクト固有につき、**導入先で確定**してください。` / `> 未確定のパスに触れる変更は、arbiter が安全側 escalate（human escalate）する原則を守ってください。`。**このヘッダは正本 `docs/ai/ai-loop/ho-paths.md` には存在しない**（#4 の diff で確認）。ただし **arbiter はこのヘッダを一切参照していない**（`grep 雛形注記 scripts/ai-loop/arbiter.py` → 0 件）。CI drift 検出は `.github/workflows/sync-plugin-plangate.yml` |
| 8bis | **配布テスト経路では雛形が唯一の解決元になる**（案 A の回帰リスク） | 隔離環境で `cd <repo>/plugin/plangate/skills/ai-loop-cycle && python3 scripts/test_arbiter.py` を実行し、同 CWD で `arbiter.resolve_ho_patterns()` を直接評価 | **247 tests OK**。ただし `resolve_ho_patterns()` の解決元は **`.../ai-loop-cycle/references/ho-paths.md`（count=21）**、探索パス 1 件目（`<skill dir>/docs/ai/ai-loop/ho-paths.md`）は不在。`test_arbiter.py` L22-26 の `_HO_PATHS_CANDIDATES` も「本体 / bundled の 2 通り」を明示的に許容している。→ **雛形解決を無条件に escalate 化すると、配布 skill ディレクトリ起点のテスト実行が壊れる**（AC-5 が指定する repo root 起点 `python3 scripts/ai-loop/test_arbiter.py` は候補 ② を使うため無影響） |
| 9 | テスト baseline | `python3 scripts/ai-loop/test_arbiter.py`（repo root 起点） | **247 tests OK**（main `a2a02b9` 実測。issue AC-5 の調査時点値と一致） |
| 10 | **雛形フォールバックの再現（本 pbi-input 作成時の独立再現）** | `git archive a2a02b9` を scratchpad へ展開 → `ho-paths.md` を持たない空の導入先 CWD から `python3 <repo>/plugin/plangate/skills/ai-loop-cycle/scripts/arbiter.py --input input.json` を実行。入力 = `changed_files=["app/Models/Service.php", ".env"]` / `allowed_paths=["app/**",".env"]` / `lite` 全 true / `verdicts=approve-approve` / `gates={c1:PASS,breakdown:pass}` | **再現**。`class:"no-merge"` で `decision=AUTO_APPROVED` / `priority 6: verdict=approve-approve（合意）` / `boundary_check="clean"` / `scope_check="in_scope"` / `ho_paths_source=<...>/references/ho-paths.md` / `ho_pattern_count=21` / **exit code 0**。`class:"merge"` に変えると priority 3 で `HUMAN_ESCALATED`（exit 2）となるため、**`no-merge` クラスの run が自動承認まで到達する** |
| 11 | **対照実験: repo-checkout レイアウトでは正しく fail-closed する** | 同じ空の導入先 CWD から `python3 <repo>/scripts/ai-loop/arbiter.py` を実行 | **`priority 0: ho-paths unresolved (fail-closed)`（`boundary=unresolved` / exit 2）**。候補 ③ が `<repo>/scripts/references/ho-paths.md` を指し不在になるため。→ **本欠陥は「雛形が scripts/ の隣に同梱される plugin レイアウト固有」** |
| 12 | **対照実験: 雛形を導入先パスへ逐語コピーした場合** | 導入先 CWD に `docs/ai/ai-loop/ho-paths.md` として雛形をコピーし再実行 | **`AUTO_APPROVED`（`ho_paths_source=<downstream>/docs/ai/ai-loop/ho-paths.md`・count=21）**。→ **パス由来だけで判定する案 A はこの誤用を捕捉できず、内容マーカーを見る案 B だけが捕捉できる**（3 案比較の決定的材料） |

> 再現に使った作業ディレクトリは scratchpad 配下の一時領域で、報告後に削除済み。実リポジトリの CWD では雛形が解決されないため再現しない（#7 / #11）。

---

## What（Scope）

### In scope

雛形フォールバックと「導入先の境界が定義済み」を**機械的に区別**し、区別できない run を fail-closed に倒す。

#### 3 案の実装可能性比較

| 観点 | **案 A**: 解決元が plugin 同梱雛形なら fail-closed | **案 B**: 雛形マーカーを検出して警告 + escalate | **案 C**: 解決元を record に記録して監査可能にする |
|------|--------------------------------|------------------------------|------------------------------|
| 検出の根拠 | **解決に使った候補のインデックス**（`_BUNDLED_HO_PATHS_RELATIVE` 経由か）。パス由来 | **ファイル内容の雛形マーカー**（sync が前置する「雛形注記」行 / 将来的な機械可読マーカー） | 記録のみ（検出しない） |
| 実装量 | 小。`resolve_ho_patterns()` が **どの候補で解決したかの種別**を返すよう戻り値を拡張 → `arbitrate()` の priority 0 近傍に分岐追加 | 小〜中。マーカー検出関数 + `resolve_ho_patterns()` の種別判定に合流。マーカーの機械可読化を伴うなら sync script 側の変更も必要 | 極小。`ho_paths_source` は**既に記録済み**（裏取り #5）。追加は「種別」と RunEvidence 伝播のみ |
| **#12（雛形の逐語コピー）を捕捉できるか** | **No**（パスが導入先なので DOWNSTREAM と判定され auto-approve） | **Yes**（内容にマーカーが残る） | No（監査時に人が気づけるだけ） |
| **#8bis（配布テストの雛形解決）を壊さないか** | **壊す**（無条件 escalate 化すると skill ディレクトリ起点の 247 tests が影響を受ける） | 同左（マーカー付き＝雛形なので同じく escalate 対象） | 壊さない |
| fail-closed 要件（issue Non-goals / #1005 コメント）の充足 | **充足** | **充足**（ただし「警告だけで継続」は #1005 コメントで明示的に不採用） | **不充足**（機械強制なし） |
| 誤検出リスク | 導入先が意図的にスクリプト隣に自前 `references/ho-paths.md` を置く運用を潰す（実在するか未確認 → U-4） | 導入先が雛形を編集した際にマーカー行だけ消し忘れる／逆にマーカーを消して中身は雛形のまま、の両方向の誤判定 | なし |

**推奨: 案 A を主軸にし、案 B のマーカー検出を第 2 の判定軸として併用する（A + B）。案 C は A/B いずれでも必須の共通要素として全案に内包する。**

根拠:

1. **#1005 コメントの初回実装境界と一致する**。`ResolvedHoPaths{path, source_kind, patterns}` で provenance を返し、`BUNDLED_TEMPLATE` なら patterns が非空でも `HUMAN_ESCALATED`（reason code `HO_BOUNDARY_UNDEFINED` 等）とする指示は案 A の構造そのもの。「警告だけで継続する案は fail-closed を満たさないため採用しない」とも明示されている。
2. **案 A 単独では #12（雛形の逐語コピー）を素通しする**（実測）。導入先の最も起こりやすい誤用は「雛形をコピーしてそのまま置く」であり、これを捕捉しないと本 issue の Why（導入先の HO が無保護）が半分残る。マーカー判定はパス判定と独立に効く。
3. **マーカーは新規発明でなく既存資産**（裏取り #8）。sync script が既に雛形へ 3 行ヘッダを前置している。arbiter がそれを読むだけで案 B の骨格が立つ。機械可読性を上げる場合も、変更対象は **sync が前置するヘッダ**であって正本 `ho-paths.md` の表形式ではないため、Out of scope の「`ho-paths.md` のフォーマット変更（§1/§2 の節構成化）」には抵触しない（→ U-3 で plan 時に確定）。
4. **案 C は独立案としては Non-goals に抵触する**（規範層の強化にとどまり、issue が「規範では足りない」と述べている主旨に反する）。ただし「解決元を実行時に明示的に記録する」は issue が全案共通で要求しており、かつ現状は**パスのみで種別が無い**（裏取り #5）ため、A/B の実装に必ず含める。

#### 実装に含める要素（3 案共通の必須要素を含む）

1. **解決元の provenance 化**: `resolve_ho_patterns()` が `(patterns, path, searched)` の平坦タプルでなく **source kind を伴う構造**（#1005 コメント案の `ResolvedHoPaths` / `HoPathsSourceKind{EXPLICIT, DOWNSTREAM, BUNDLED_TEMPLATE}` 相当）を返す。既存呼び出し側（`arbitrate()` / テスト）への影響は plan で吸収する。
2. **fail-closed 分岐の追加**: `BUNDLED_TEMPLATE` と判定された解決元で run する場合、`patterns` が非空でも `HUMAN_ESCALATED`。機械判定可能な reason code（例 `HO_BOUNDARY_UNDEFINED`）を付す。
3. **マーカー検出**（案 B 併用分）: 雛形注記ヘッダを検出したら、パスが導入先であっても `BUNDLED_TEMPLATE` 相当に倒す。
4. **記録**: decision record（arbiter provenance）に source path + **source kind** + reason を刻む。RunEvidence への伝播可否は plan で判断（現状 0 件 = 未伝播 / 裏取り #5）。
5. **plangate self-run の回帰維持**: repo root 起点の self-run（候補 ② 解決）は従来どおり（裏取り #7）。**配布 skill ディレクトリ起点のテスト実行**（裏取り #8bis）は、テスト側で `--ho-paths` / パターン明示注入へ寄せるか、テスト実行を明示的な例外として扱うかを plan で決める。
6. **負側テストの追加**（AC-2）。

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
| **AC-4** | plangate 自身の run（雛形が正しい解決元であるケース）が従来どおり動作する（回帰なし） | repo root 起点の `python3 scripts/ai-loop/arbiter.py` が従来と同一 decision を返すこと。**加えて裏取り #8bis の「配布 skill ディレクトリ起点のテスト実行」の扱いを明示的に判定**（そのまま通す／テスト側で明示注入へ移行、のいずれかを plan で決め、結果を assert） |
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
| R-1 | **案 A の無条件 escalate 化で配布テスト経路が壊れる**（裏取り #8bis: skill ディレクトリ起点の 247 tests は雛形が唯一の解決元） | 配布物の自己検証が回らなくなる | plan で「テスト実行は `--ho-paths` 明示注入へ移行」または「テストのみ例外」を**明示決定**し AC-4 で assert |
| R-2 | 逆方向の事故: 判定が過剰に効き、**正当な導入先 run まで恒常 escalate** になる | 導入先で ai-loop が実質使えなくなる | 導入先が `docs/ai/ai-loop/ho-paths.md` を**自前で書けば**通る経路を必ず残し、テストで固定 |
| R-3 | マーカー（案 B）判定が脆い。導入先が雛形を編集してもマーカー行を残す／消しても中身は雛形のまま | 誤検出・見逃しの両方 | マーカーは「安全側に倒す方向にのみ効かせる」（マーカー有 → escalate。マーカー無は何も保証しない）。パス判定（案 A）と AND でなく OR で合成 |
| R-4 | 既存 provenance 契約（`decision-table.md` L250-251 の `ho_paths_source` / `ho_pattern_count`）との後方互換破壊 | 下流の監査・metrics が壊れる | 既存 2 フィールドは維持し、source kind は**追加フィールド**（additive）とする |
| R-5 | 配布側の直接編集による sync drift | CI 失敗・正本と配布の乖離 | 正本のみ編集 → `scripts/sync-plugin-plangate.sh` で再生成 |

### Unknowns

| ID | 未確定事項 | 解消方法 |
|----|-----------|---------|
| U-1 | **`_BUNDLED_HO_PATHS_RELATIVE` 経由の解決を「常に不正」と断じてよいか**（裏取り #7 では documented な self-run 経路に存在しないが、#8bis のテスト経路は存在する） | plan で経路を全数列挙して確定。判断がつかなければ**安全側（escalate）** |
| U-2 | RunEvidence / metrics へ source kind を伝播させるか（現状 `ho_paths_source` すら 0 件 / 裏取り #5） | 本 PBI の初回スコープ（#1005 コメントは「source provenance と downstream fail-closed に限定」）に含めるか plan で判断。含めないなら follow-up issue 化 |
| U-3 | 雛形マーカーを**機械可読形式**（frontmatter 等）へ変えるか、現行の日本語 3 行ヘッダを文字列一致で見るか | 前者は sync script 変更を伴う。Out of scope の「`ho-paths.md` のフォーマット変更」に抵触しないか（変更対象は sync 前置ヘッダであり正本の表形式ではない）を plan で確定 |
| U-4 | 導入先がスクリプト隣に自前 `references/ho-paths.md` を置く運用が実在するか | 実在するなら案 A のパス判定は誤検出になる。ドキュメント（SKILL.md / execution-runbook.md）を全数確認して確定。不明なら安全側 |
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
- **本 pbi-input 作成で新たに判明し issue に未記載の事実**（plan / C-2 で扱うこと）: ① 欠陥は plugin レイアウト固有（#11）/ ② 雛形の逐語コピーは案 A では捕捉できない（#12）/ ③ 配布テスト経路が雛形解決に依存している（#8bis）/ ④ 雛形マーカーは既に sync script が前置している（#8）/ ⑤ `ho_paths_source` はパス文字列としては既に記録済みだが種別が無く RunEvidence へも未伝播（#5）。

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
