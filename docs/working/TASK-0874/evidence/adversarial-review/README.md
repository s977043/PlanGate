# TASK-0874 敵対レビュー（T-38 / T-39）の証跡

> 発行: 2026-08-05 / 対象 code HEAD: `8819c3a`（R1 反映後）
> disposition の正本は [`../../handoff.md`](../../handoff.md) §7（R1 / R2 の 2 表）。
> 本ディレクトリは**レビュー実施の事実と主要指摘の要約**を保全する。

## 実施体制

`.claude/rules/review-principles.md` §7-bis の 2 レーン責務契約に従い、観点を分離した 2 レーンで実施した。両レーンとも worktree に対して**読み取り専用**で動作し、変異注入はスクラッチパッドの複製で行っている。

| ラウンド | レーン | 主眼 | 判定 |
| --- | --- | --- | --- |
| **R1**（T-38） | 実装 | fail-open の残存 / 決定論 / privacy の実効性 / tampered 検出のコードパス / 不変対象 | **条件付き GO**（critical 3 / major 5 / minor 5） |
| **R2**（T-39） | 受入基準 | AC 16 件の実質充足 / fixture の実質 / C-3 決定の反映 / DoD と close 条件 / handoff 6 要素 | **STOP**（major 5 / minor 4） |

`todo.md` T-39 が完了条件として課した「critical・major ゼロ収束」は、両ラウンドの全指摘を反映して達成した（`8819c3a` 時点で critical 0 / major 0）。

## R1（実装レーン）の主要指摘

| ID | severity | 内容 |
| --- | --- | --- |
| C-1 | critical | 受理器が `terminal_state` を一切検証せず、schema の `enum` がどこからも強制されていなかった。非終端 `WAITING_FOR_CHECKS` を持つ EV が **exit 0（complete）で通過**（改竄プローブ 15 件中 13 件が exit 0） |
| C-2 | critical | **変異注入の kill が効いていなかった**。`check_output_privacy` のテストが関数を直接叩くだけで、`build()` 内の唯一の call site を削除しても全テストが緑になる（空振り fixture と同型）。あわせて受理器側に privacy backstop が皆無 |
| C-3 | critical | `to_promotion_provenance` の AC-13 fail-closed が `null` / `""` / `0` / `{}` で破れ、**「promotion 承認済み」と「阻害要因は取得不能」を同時に主張**するレコードが出る。docstring は「明示的に `[]` のときのみ非 BLOCKED」と宣言しており実装と矛盾していた |
| M-1 | major | `scan_input_privacy` が `runs_dir` の全 record を走査するため、**無関係な run の record が 1 件増えるだけで EV の byte が変わる**（AC-2 違反） |
| M-2 | major | `_recheck_bindings` が `c3prime_verify` の後段検証 2 件（verdict 語彙 / reviewer 独立性）を落としており、契約 §6-5 の「検証の総量も減らさない」に違反 |
| M-3 | major | 受理器が `ci_outcomes` / `review_findings` / `quality_metrics` を再導出せず、CI 失敗を success に書き換えた EV が complete で受理される |
| M-4 | major | plugin 同梱の受理器が schema 未同梱で**常に exit 1**（`_fail()` 経由なので「改竄兆候」と区別できない） |
| M-5 | major | schema の `type` / `enum` / `pattern` が 3 層すべてで強制されない（受理器はキー名のみ / CI は `docs/schemas/` 対象外 / jsonschema テストは CI で恒久 skip） |

R1 が「クリーン」と確認した領域: producer 側の中核 fail-open 防御（変異注入 4/4 kill）・決定論の主要経路・`evidence_refs` のディスク走査なし・`quality_metrics` の corpus 汚染なし・schema と producer 出力キーの束縛（24 = 24）・**AC-7 不変 7 ファイル 0 行**（import 時の属性書き換え・monkeypatch も 0 件）。

## R2（受入基準レーン）の主要指摘

| ID | severity | 内容 |
| --- | --- | --- |
| MJ-1 | major | handoff / status / current-state が**自分の HEAD より前を凍結**（T-37 完了済みなのに未了と記載）。次の担当者が未了リストを対外公開する型 |
| MJ-2 | major | handoff の AC-3 だけ**無条件 PASS**（他 AC には「契約層のみ」等の限定語がある）。routing の値カバレッジは実際は 0 |
| MJ-3 | major | AC-12 の drift 検査が **caller opt-in** で、未実施であることが EV に残らない。golden fixture 10 件はすべて未検査で生成されていた |
| MJ-4 | major | C-3 が「**handoff に明記すること**」と指定した U-4 / U-8 / U-9 / U-12 の見直し前提が handoff に 0 件（契約 doc 側は充足） |
| MJ-5 | major | テストに実 corpus 件数（`legacy_count == 25` 等）がハードコードされ、`ai-loop-runs/` に run 記録が 1 件足された時点で**無関係な PR の CI を落とす時限爆弾**になっていた |

R2 が疑って**空振りしていなかった**と確認した点: TC-59 は状態集合を計算して 7 を検証（ハードコード列挙でない）/ TC-08 は形式を保った 1 文字改変を実際に検出 / TC-48 は golden を再生成して byte 比較 / TC-42・43 は恒等式の空振りを避けた設計。**FAIL 判定の AC はゼロ**だった。

## 反映後の実測（統合担当が独立に再実行）

| 検証 | 結果 |
| --- | --- |
| `python3 scripts/ai-loop/test_run_evidence.py` | **89 tests OK / exit 0** |
| `python3 scripts/ai-loop/test_run_evidence_verify.py` | **51 tests OK / exit 0** |
| C-2 の変異注入（`build()` 内の call site を実削除） | **1 件 FAIL**（是正前は全緑 = kill 成立を実証）→ 復元 |
| C-3 の再現 | `null` / `""` / `0` / `{}` すべて **BLOCKED**、明示 `[]` のみ PROMOTED |
| 不変 7 ファイルの 3 ドット diff | **0 行** |
| `plan.md` の 3 ドット diff | **0 行**（`plan_hash` 束縛を維持） |
| `git diff --quiet -- plugin/plangate/` | **clean**（sync drift なし） |
| `approvals/c3.json` の commit 混入 | **なし** |

## 本ラウンドで得た運用知見

- **「変異注入した」だけでは kill の証明にならない**。C-2 は関数の検出力を固定しただけで**配線（call site）を 1 行も守っていなかった**。実装者は「kill 済み」と自己申告していたが、独立再現で survive が確定した。以後、変異注入は「**呼び出し経路を実際に壊して FAIL するか**」まで確認する
- **完了資産は自分自身の commit 前を凍結して stale 化する**（MJ-1）。handoff は発行時点の HEAD を明記する
- **テストに実データの絶対件数を書くと時限爆弾になる**（MJ-5）。成長するディレクトリを入力に取るテストは下限 assert か恒等式で書く
