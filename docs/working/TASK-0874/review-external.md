---
task_id: TASK-0874
artifact_type: review-external
schema_version: 1
status: reflected
verdict: WARN
created_by: orchestrator
---

# TASK-0874 外部レビュー結果（C-2）

> レビュー日: 2026-08-02
> 対象: `plan.md` / `todo.md` / `test-cases.md` @ `feat/task-0874-plan` `01ebc4a`（base = `origin/main` = `a4afacb`）
> Mode: **critical** → `mode-classification.md` フェーズ適用マトリクスにより **C-2 = 複数観点**（2 レーン）
> レーン構成（`.claude/rules/review-principles.md` §7-bis の 2 レーン責務契約に準拠）:
>
> - **レーン A: 設計妥当性**（plan / todo / test-cases / pbi-input を読む・実装コードは原則読まない）
> - **レーン B: コードベース整合**（既存パターン該当箇所を 1 エージェントに集約・plan の網羅性判定は行わない）
>
> **本ファイルは追記専用**（`working-context.md` C-2 差分管理規約）。指摘 ID `R-NNN` は**欠番でも振り直さない**。
> 計画本体への反映は **1 回だけ確定**（反映コミットに `Refs: R-NNN`）。

## サマリー

| レーン | critical | major | minor | info | 計 |
|--------|---------|-------|-------|------|---|
| A: 設計妥当性 | 0 | 8 | 3 | 1 | 12 |
| B: コードベース整合 | 0 | 5 | 4 | 1 | 10 |
| **合計** | **0** | **13** | **7** | **2** | **22** |

**判定: WARN**（critical = 0 / major 13 件はすべて反映または C-3 判断へ移送）。
`review-principles.md` §4 の判定基準では major >= 1 は「Human review recommended」であり、
本 PBI は Mode=critical のため**もとより人間 C-3 必須**（判定に変更なし）。

> **`working-context.md` C-3 条件付き降格との関係**: 降格候補条件は
> 「C-1 PASS かつ **C-2 critical/major = 0** かつ `lite_eligible=true`」。
> 本 C-2 は **major 13 件**（反映済み）であり、かつ Mode=critical は `lite_eligible=false`（AC-11）。
> したがって **C-3 は同期・人間必須のまま**（降格対象外）。

## 反映プロトコル（実施順序）

`working-context.md` の規定順序に従い、以下の (1)(2)(3) までを本作業で実施した。
**(4) c3.json の発行は人間（Human-owned）**であり、AI は発行しない。

1. ✅ 本ファイルへ `R-NNN` を集約（追記専用）
2. ✅ plan / todo / test-cases へ **1 回で確定反映**（`Refs: R-NNN`）
3. ✅ 簡易 C-1 再実行 → `review-self.md` に追記（3 ラウンド目）
4. ⏸ 人間が最終 `approvals/c3.json`（`c3_status=APPROVED` / 確定後 plan の `plan_hash`）を発行
5. ⏸ exec

---

## 監査表（追記専用・squash / rebase 耐性）

`status` の値: `reflected`（計画本体へ反映済）/ `rejected`（実測で誤りと判断・反映せず）/
`partial`（一部反映・残りは根拠付きで見送り）/ `deferred-to-C3`（C-3 判断へ移送）。

`reflected_in(commit)` は反映コミット SHA。本表は反映コミット作成後に SHA を確定させる
（コミットメッセージ側に `Refs: R-NNN` を全件列挙してあるため、SHA 未記入でも
`git log --grep='R-001'` で双方向に辿れる）。

| R-NNN | lane | severity | status | reflected_in(commit) | notes |
|-------|------|----------|--------|---------------------|-------|
| R-001 | A | major | reflected | `Refs: R-001` | D3 正規化マッピングの負側 TC 追加（TC-57 / TC-58 / TC-59）+ Edge cases 付け替え + T-16 に対応 TC 付与 |
| R-002 | A | major | partial | `Refs: R-002` | (b) を採用: fixture 6 の Phase 1 vacuity を fixture 表 / U-9 / T-32 に明示。(a) の item schema 定義は #868 の設計に踏み込むため **U-9 の代替案として C-3 へ移送** |
| R-003 | A | major | reflected | `Refs: R-003` | `terminal_state` × フィールド必須/`unavailable` マトリクスを Step 1 に追加。known-unavailable を「Phase 1 固定 3」と「`terminal_state` 依存 N」に分離。D7 の「曖昧化しない」を「stderr に列挙される」へ置換。fx-05 用 TC-58 追加 |
| R-004 | A | major | reflected | `Refs: R-004` | 受理器の署名を `run_evidence_verify.py <ev.json> <task_dir>` に確定（姉妹受理器 `c3prime_verify.py <task_dir> [expected_sha]` と同型の task_dir 束縛）。再検証対象を Step 2 / T-10 / TC-08 に明記。EV 自己完結型（`evidence_hash` 追加 → required 22）は **採らない**（D8 の 21 と versioning policy を維持）ことを Risks に根拠付きで記録 |
| R-005 | A | major | reflected | `Refs: R-005` | `quality_metrics{}` を「**当該 run の events のみから計算できる指標**」に限定（`first_pass` / `rounds`）。corpus 集計値（`decision_counts` / `round_distribution` / `hotl_health` / `first_pass_rate`）は AC-2 を壊すため**格納しない**。供給元表 #18 の記述を是正し TC-60 を追加 |
| R-006 | A | major | reflected | `Refs: R-006` | T-18 の完了条件を **exit 11（partial）+ `unavailable` フィールド名が stderr に列挙**へ是正。U-10 が allowlist 採用なら exit 0 に戻す旨を併記。TC-09 の positive 側（`^_` 許容 → exit 0）も**合成 complete EV でのみ 0**と明記 |
| R-007 | A | major | reflected | `Refs: R-007` | AC 対応表 AC-9 / AC-10 行に「**Phase 1 は契約層のみ**（実フローは #869 / #811 実装後）」を明記。plan に「本 PBI 完了後も **#874 は OPEN**」を明記し C-3 判断事項へ追加。T-42 のコメント文面要件に「close 条件未達」の明記を追加 |
| R-008 | A | major | reflected | `Refs: R-008` | 受理器が schema JSON を**唯一の正**として読み required / allowlist を導出する構造へ是正（Step 2 / T-10）。TC-61（`schema["required"]` == 受理器の必須キー集合）/ TC-62（producer 出力の全キー ⊆ `properties` ∪ `^_`）を追加。Risks の「golden byte 比較で検出」を撤回。`escalation` / `observation` / `cause_hypothesis` を properties に登録する要件を Step 1 に追加 |
| R-009 | A | minor | partial | `Refs: R-009` | **U-7 は plan 確定へ降格**（Phase 1 では配布しない / Phase 2 で判断）。**U-11 は Unknowns に残す**（exit code は契約層の値割当であり、`working-context.md` の「Unknowns に残すべきものは残す」に該当。ただし「**追認想定**（対立案に利点の提示なし）」と明記して C-3 の処理コストを下げた）。未決 **9 → 8 件** |
| R-010 | A | minor | reflected | `Refs: R-010` | producer の**入力ソース allowlist**（`approvals/c3.json` / `delivery/record.jsonl` / `docs/working/ai-loop-runs/*.json` / 注入値 の 4 つのみ）を Step 1 / Step 3 に明記し、TC-63（ソース走査）を追加 |
| R-011 | A | minor | reflected | `Refs: R-011` | U-5 に選択肢 (a) verbatim / (b) owner 除去 / (c) `canonical_hash()` / (d) 省略 と各案の帰結を追加。レーン B 5 の実データ衝突（`comment_url` / `result_ref` / `improvement_refs` の**値**）も U-5 の射程に含めた |
| R-012 | A | info | reflected | `Refs: R-012` | Step 3 に「`evidence_refs` は**注入値または record 由来のみ**（ディスク走査で列挙しない）」を追加（AC-2 決定論の保護） |
| R-C01 | B | major | reflected | `Refs: R-C01` | plan L418 の `- **Verification Automation**:` を **bold なし**へ是正。実測で `plan_package.py` の `re.search(r"Verification Automation:\s*\`([^\`]+)\`")` が NOMATCH → MATCH に転じることを確認 |
| R-C02 | B | major | reflected | `Refs: R-C02` | Files 表のディレクトリ 3 行（`tests/fixtures/run-evidence/` / `plugin/plangate/` / `docs/working/TASK-0874/`）を**末尾 `/` と `**` の両形式併記**へ是正。実測で arbiter 4/4 violation → 0 violation、delivery も全件 True になることを確認 |
| R-C03 | B | major | reflected | `Refs: R-C03` | `.github/workflows/metrics-privacy.yml` が `grep -v '^tests/fixtures/'` で除外することを実測確認。TC-22 を「ta-59 内から `PLANGATE_HOOK_FILES="<10 fixture>" sh scripts/hooks/check-metrics-privacy.sh`（`PLANGATE_HOOK_STRICT=1`）を実行」へ是正し、CI 除外の事実を D5 / Risks に明記 |
| R-C04 | B | major | reflected | `Refs: R-C04` | `_completed_rounds(entries, None) == 0`（例外にならない）を実 record で実測確認。注入値に **`--pr-number`** を追加し、解決不能時は `repair_rounds` を **`unavailable`**（`0` にしない）へ倒す既定を確定。TC-64 を追加 |
| R-C05 | B | major | reflected | `Refs: R-C05` | 実測で `schemas/c3-prime.schema.json` の `patternProperties` は `{"^_": {"type": "string", ...}}`、受理器 `c3prime_verify.py` L96 は非 string を reject。plan D8 / T-5 の `{"^_": {}}` を **`{"^_": {"type": "string"}}`** へ是正し、TC-03 の assert を型まで深くした |
| R-C06 | B | minor | partial | `Refs: R-C06` | 4 件のうち **3 件は実測で確認**（`delivery.py` docstring は L9-10 が正 / `verify_c3()` は L498-505 / `check-metrics-privacy.sh` の `case` は L86-89 / `load_entries()` は L466-472）。**`record_path()` の「実際は L439-440」は誤り** — 実測 L441-442 で plan / test-cases の記述が正しい（下記「指摘が誤りだった項目」参照）。行番号はすべて**記号アンカー**へ置換した |
| R-C07 | B | minor | reflected | `Refs: R-C07` | `bin/plangate` L1010 付近が `if "0" / elif "1" / else` の catch-all であることを実測確認（`delivery.py` L530 は `rc == 10` の厳密比較）。Step 1 の rc 対応表に「`bin/plangate` は 0/1 以外を legacy にフォールバックする」と、新受理器の rc を `_plangate_c3_dispatch` 経路へ流さない制約を追加 |
| R-C08 | B | minor | reflected | `Refs: R-C08` | `ta-54-ai-loop-link-selfcontained.sh` TC-01 が `](\.\./` / `]:[[:space:]]*\.\./` / `<\.\./` を grep し、変換器 `scripts/_ai_loop_link_rewrite.py` の `_LINK_RE` が**インラインリンクのみ**を対象とすることを実測確認。Step 1 のチェックポイントに「契約 doc のリンクはインライン記法のみ」を追加 |
| R-C09 | B | minor | partial | `Refs: R-C09` | (a) **確認**: EH-8 はキー名の grep のみで値を見ない。`{"file": "/var/folders/…"}` は素通り（実測 PASS）→ 全フィールドの**値**に対する絶対パス検査（TC-65）を追加し `evidence_refs` 限定をやめた。(b) **精度補正**: BLOCK されるのは `"key":`（コロン付き）形式のみ。`{"forbidden": ["file_path", "stdout"]}` のような**配列要素は BLOCK されない**（実測 PASS）。したがって「禁止キー一覧を JSON に書けば必ず BLOCK」は不正確 — schema の `properties` に禁止キー名を置く場合のみ危険。この精度で Step 1 / Step 8 に制約を記載 |
| R-C10 | B | info | reflected | `Refs: R-C10` | ① 実測で `schemas/*.schema.json` 28 本中 **27 本**が `https://github.com/s977043/plangate/schemas/<name>` 形式（例外 1 本 = `maintenance.schema.json`）。D1-A の「`git mv` + `$id` 1 行変更」と Step 1 / T-44 の「`$id` を昇格後 URL で先に固定 = `git mv` 1 手」の食い違いを**後者に統一**（`$id` 変更は不要）。② `schemas/c3-prime.schema.json` が `schema_version` を properties にも required にも**持たない**ことを実測確認し、この非対称を契約 doc に書く要件を Step 1 に追加 |

### レーン B → 設計妥当性レーンへの返送論点（`review-principles.md` §7-bis 準拠）

| # | 論点 | 帰属 | 反映先 |
|---|------|------|-------|
| B→A-1 | `pr_number` の注入契約が欠落 | R-C04 に統合 | 注入値の全数と欠落時の既定（fail-closed / `unavailable`）を Step 3 / D2 に明記 |
| B→A-2 | `allowed_paths` 記法が 2 matcher で非対称 | R-C02 に統合 | 本 PBI では**両形式併記**で回避。**記法規約そのものの統一は別 PBI**（handoff の V2 候補へ。TASK-0917 は末尾 `/`・TASK-0914 は `**` と実装が割れている） |
| B→A-3 | T-18 と D7-1 の矛盾 | R-006 と同一 | 重複計上しない |
| B→A-4 | fixture 2 の「実 record 照合」が terminal_state 系をカバーしない | R-001 / R-003 に統合 | 実測で `TASK-0917/evidence/e2e/run/delivery/record.jsonl` は **3 行 = `intent` / `notice` / `receipt`** のみ（`kind=state` も `kind=merge_ready` も無い）ことを確認。fixture 表に「実 record で裏が取れる範囲」と「手書きに留まる範囲」を明示 |
| B→A-5 | AC-6 と AC-11 が実データ上で衝突 | R-011（U-5）へ移送 | 実測で同 record の `notice` は `"comment_url": "https://github.com/s977043/PlanGate/pull/940#issuecomment-…"`、`receipt` は `"result_ref": "adopted:7b229223…\|comment:https://github.com/s977043/PlanGate/pull/940#issuecomment-…"` を保持。TC-51 の厳格適用と AC-11 の `improvement_refs[]` が両立しないため **U-5 の射程を値レベルへ拡張**して C-3 判断へ |
| B→A-6 | `docs/schemas/` は CI 検証経路 0 本だが privacy CI の対象には入る | R-C09(b) に統合 | 「検証されない」と「一切の CI に触れない」の書き分けを Step 1 / D1 に追加 |

---

## 指摘が誤りだった項目（実測で反証・反映せず）

> 委託プロンプトの作業規律「指摘を鵜呑みにしない / この委託プロンプトの記述自体にも誤りがありうる」に基づき、
> 全 22 件を**自分で実コード・実ファイルに当たって**検証した。以下 1 件は実測と一致しなかった。

### R-C06 の 1 項目: `delivery.record_path()` の行番号

- **指摘**: 「plan / test-cases の `delivery.record_path()` L441-442 は誤りで、実際は **L439-440**」
- **実測（`feat/task-0874-plan` `01ebc4a` / `scripts/ai-loop/delivery.py` は本 PBI で不変・`origin/main` `a4afacb` と同一）**:

  ```text
  $ grep -n "def record_path" -A 5 scripts/ai-loop/delivery.py
  441:def record_path(task_dir) -> pathlib.Path:
  442-    return pathlib.Path(task_dir) / "delivery" / "record.jsonl"

  $ sed -n '439,443p' scripts/ai-loop/delivery.py
  # ---------------------------------------------------------------------------
  （空行）
  def record_path(task_dir) -> pathlib.Path:
      return pathlib.Path(task_dir) / "delivery" / "record.jsonl"
  （空行）
  ```

  **L439 は区切りコメント / L440 は空行**であり、関数定義は **L441-442**。
  plan / `test-cases.md` L14 の記述が正しく、指摘のほうが 2 行ずれている。
- **判定**: **rejected**（内容を書き換えない）。ただし R-C06 全体の趣旨
  （行番号は stale 化するため記号アンカーへ置換すべき）は妥当なので、
  `record_path` を含む**全参照を記号アンカー化**する形で反映した。

### R-C09(b) の精度補正（rejected ではなく partial）

- **指摘**: 「`docs/schemas/run-evidence.schema.json` や fixture 7 で禁止キーを列挙すると、
  その JSON 自身が EH-8 の grep に引っかかり CI で BLOCK される」
- **実測**（`PLANGATE_HOOK_FILES` に単一ファイルを渡して EH-8 を実走）:

  | 入力 | 非 strict | `PLANGATE_HOOK_STRICT=1` |
  |------|----------|--------------------------|
  | `{"properties": {"file_path": {"type":"string"}}}` | WARNING（rc=0） | **rc=1（BLOCK）** |
  | `{"forbidden": ["file_path", "stdout"]}` | PASS | PASS |
  | `{"file": "/var/folders/xx/tmpABC/foo.json"}` | PASS | PASS |

  EH-8 の実装は `grep -E "($FORBIDDEN_KEYS)[[:space:]]*:"` であり、`FORBIDDEN_KEYS` は
  `"file_path"|…` と**ダブルクォート込み**。したがって BLOCK されるのは
  **`"file_path":` のようにコロンが後続する JSON キー形式のみ**で、
  **配列要素として書いた文字列は BLOCK されない**。
- **判定**: **partial**。「schema の `properties` に禁止キー名を置くと BLOCK される」は真、
  「禁止キー一覧を JSON に文字列として書くと BLOCK される」は偽。この精度で反映した。

### R-002 / R-009 / R-C06 が partial である理由（まとめ）

| R-NNN | 反映した部分 | 反映しなかった部分と理由 |
|-------|------------|----------------------|
| R-002 | (b) fixture 6 の Phase 1 vacuity の明示（fixture 表 / U-9 / T-32 / DoD コメント要件） | (a) `routing_decisions[]` の item schema 定義。**#868 の設計に踏み込む**（本 PBI Non-goals の隣接領域）ため plan で勝手に決めず **U-9 の代替案として C-3 へ移送** |
| R-009 | U-7 を plan 確定へ降格（未決 9 → 8） | U-11 の降格。exit code の値割当は**契約層の値決定**であり、`working-context.md` の「Unknowns に残すべきものは残す」に該当。ただし「追認想定」と明記して C-3 の処理コストを下げた |
| R-C06 | 4 件の行番号ドリフト + 全参照の記号アンカー化 | `record_path()` の「L439-440」。実測 L441-442 で **指摘が誤り**（上記） |

---

## 前提の再検算（レーン A が事前に照合した数値）

レーン A は「AC 16 / TC 56 / タスク 44 / fixture 10 / #869 のフィールド綴り」がすべて plan の記述と
一致することを確認済みと報告した。**本作業でも独立に再確認**し一致を確認した（C-1 3 ラウンド目の
`review-self.md` に実測コマンドと結果を記録）。C-2 反映後の件数は **TC 56 → 65 / タスク 44（不変）**。

## 未解決のまま C-3 へ持ち越す論点（C-2 が確定しなかったもの）

| Unknown | C-2 が加えた情報 |
|---------|----------------|
| U-5 | **選択肢 4 案と各案の帰結**を追加（R-011）+ 実データ上の衝突面が `repository` だけでなく `comment_url` / `result_ref` / `improvement_refs` の**値**であることを追加（B→A-5） |
| U-9 | fixture 6 が Phase 1 で fixture 4 と**区別不能**である事実を追加（R-002）+ 代替案 (a)「`routing_decisions[]` の item schema を暫定定義する」を追加 |
| U-10 | 変更なし（C-2 は plan 既定を支持も否定もしない） |
| U-11 | 「**追認想定**（対立案に利点の提示なし）」の注記を追加（R-009） |
| U-12 | 変更なし |
| U-1 / U-4 / U-8 | 変更なし |
