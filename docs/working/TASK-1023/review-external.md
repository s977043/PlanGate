---
task_id: TASK-1023
artifact_type: review-external
schema_version: 1
status: completed
verdict: APPROVE
reviewer_tool: codex-independent-2lane
created_by: codex
---

# TASK-1023 外部AIレビュー結果（C-2）

> 2026-08-09: 設計妥当性・コードベース整合の2独立レーンを実施。初回判定はREJECT。
> 指摘を本ファイルへ集約し、plan/todo/test-casesへ1回確定反映した。更新版は再C-2対象。
> 最終再レビューでは両レーンともAPPROVE（critical=0 / major=0）。

## 外部レビュー実行可否

| 項目 | 内容 |
|---|---|
| 実行状態 | executed（2レーン） |
| 設計妥当性 | REJECT: critical 2 / major 6 / minor 3 / info 1 |
| コードベース整合 | BLOCKED: critical 2 / major 6 / minor 1 / info 2 |
| 最終判定 | APPROVE / Plan hash `24fcdf9f703728f8e8ff4d544ac98628af72b727aeacdb4d2f16a7e86f953de1` |

## 監査表

| R-NNN | status | reflected_in(commit) | notes |
|---|---|---|---|
| R-001 | reflected | pending | Goalをtactical fixへ縮小し#928までC-3'停止 |
| R-002 | reflected | pending | jqなしraw fallbackを撤回、parse-unknownをblock |
| R-003 | reflected | pending | mixed commandは安全側blockと明文化 |
| R-004 | reflected | pending | git履歴/all-refを含む監査母集団 |
| R-005 | reflected | pending | bypassをHuman-owned emergency/test-only化 |
| R-006 | reflected | pending | 非TTY approve/maintenanceとartifact不変TC |
| R-007 | reflected | pending | Hook E2EをMERGE_READY前blocking task化 |
| R-008 | reflected | pending | provenance不明承認の利用停止/再C-3 |
| R-009 | reflected | pending | mutationの単一置換/syntax/baseline/restore |
| R-010 | reflected | pending | legacy TA-25 ID保持、新規ID分離 |
| R-011 | reflected | pending | Modeをcriticalへ引き上げ |
| R-012 | reflected | pending | `$1` fallbackとenv/stdin独立評価 |
| R-013 | reflected | pending | bypass env汚染、standalone偽成功、no-jq fixture |
| R-014 | reflected | pending | settings/Codex未配線を残存P0へ分離 |
| R-015 | reflected | pending | parsed-safeのtool event schemaと型条件 |
| R-016 | reflected | pending | stdin emptyとread errorを別TC化 |
| R-017 | reflected | pending | bypass process env/command文字列/通常caseを分離 |
| R-018 | reflected | pending | #928 AC-1/2へのEH-10追記と再開Human判断 |
| R-019 | reflected | pending | env優先`$1` fallbackとstdin独立評価の矛盾解消 |
| R-020 | reflected | pending | legacy TC-05をvalid normal stdinへmigration |
| R-021 | reflected | pending | Hook E2E evidence push後にCI/review再確認 |
| R-022 | reflected | pending | runtime write surfaceの固定payload |
| R-023 | reflected | pending | stale jq fallback mutationをparse-unknown mutationへ統一 |
| R-024 | reflected | pending | top-level file_pathはlegacy fallbackとして固定 |
| R-025 | reflected | pending | focused verificationへAC-10を追加 |

C2-VERDICT: approve plan=sha256:24fcdf9f703728f8e8ff4d544ac98628af72b727aeacdb4d2f16a7e86f953de1

---

## 追記 2: PR #1024 敵対的レビュー（2026-08-10 / major 5 / minor 3 / info 1）

> 本節は**追記専用**。上記の初回 2 レーン C-2（R-001〜R-025）とその APPROVE 判定は
> 書き換えない。PR #1024 は 2026-08-10T00:03:07Z に merge され、その **13 秒後**
> （00:03:20Z）に敵対的レビューが着弾したため、**指摘が未反映のまま main に入った**。
> 実装は未着手のため、exec 着手前に本節へ集約し 1 回確定反映する。
>
> - レビュー全文: <https://github.com/s977043/PlanGate/pull/1024#pullrequestreview-4892929361>
> - 移送先 issue コメント: <https://github.com/s977043/PlanGate/issues/1023#issuecomment-5234750516>
> - レビューアの前提 3 主張（`exit 1` / env 時 stdin バイパス / matcher が `Edit|Write`・`Bash` のみ）は
>   本 worktree で実物を読んで**全件再現・照合済み**（詳細は各 R の「独立検証」欄）。

### 争点

指摘の中心は**脆弱経路の特定**ではなく**検証設計の検出力**である。
「実環境で必ず通る経路」に AC / TC が無く、このまま実装すると
(a) セッションが壊れる、または (b) 無検出の fail-open が入る。

### 指摘一覧

| R-NNN | severity | 指摘 | 反映方針 |
|---|---|---|---|
| R-026 | major | `parsed-safe` allowlist が `MultiEdit` を落とす。どちらに解釈しても AC が PASS する | plan の `parsed-safe` 定義へ `MultiEdit` を明示追加し、正の TC / 負の TC を両方追加 |
| R-027 | major | TTY / stdin 不在の分類が無い。無条件 `cat` は suite 無限ハング、`[ ! -t 0 ]` ガードは TTY 時全スキップ。どちらに倒れても検出 TC が無い | Input Decision Table に 1 行追加（**block 側で統一**）+ 非ハング TC + 第 4 変異 + legacy TC の stdin 明示 |
| R-028 | major | stdin 評価が env に再従属する変異（`[ -z "$TARGET" ] &&` の再挿入）を kill する TC が無い | TC-13c を `13c-file` / `13c-cmd` へ分割 + 第 5 変異を追加 |
| R-029 | major | mutation TC が実 TC を kill する経路になっていない（`PG_T25_GUARD` がハードコード。#874 と同型） | `PG_T25_GUARD` の env override を実装要件化し、TC-15〜17 の期待結果を「override 下で TC-01 / TC-03 / TC-05 **そのもの**が FAIL」と書き切る |
| R-030 | major | AC-09 の監査母集団の起点 2026-06-02 が誤った事象（ファイル誕生日）から導かれている | 母集団を**全体（リポジトリ初出）**へ改め、保護状態で 3 区分に分けて列挙 |
| R-031 | minor | `$1` fallback が実配線に接続されず dead code | plan / AC-06 に「実行時 dead code・契約↔settings drift は #928 残存」と明記し handoff 必須記載へ |
| R-032 | minor | TC-02 が 2 つの fallback を 1 payload に同居させ、top-level fallback を落としても PASS する | TC-02a / TC-02b へ分割 |
| R-033 | minor | **`EH-10` の ID が正本間で衝突** | **Human C-3 の判断事項として提示**（AI は正本を書き換えない） |
| R-034 | info | AC-11 の E2E が closure の証明範囲を超えて読まれうる | AC-11 に tool surface 単位の negative declaration を併記 |

### 独立検証（本 worktree の実物照合 / base `fac3445`）

| 対象 | 実測 | 判定 |
|---|---|---|
| `scripts/apply-claude-settings.sh:156-169` `matcher_covers()` | `Edit\|Write\|MultiEdit` ⊇ `Edit\|Write` を包含として実装済み | R-026 成立 |
| `.claude/settings.example.json:99` | 別 hook（`_comment_` は「Issue #760 提案 / EH-10 候補」）で `Edit\|Write\|MultiEdit` を使用 | R-026 / R-033 成立 |
| `tests/extras/ta-59-apply-settings-merge.sh:198-218` TC-10 | **fixture が `check-approval-token-write.sh` 自体を `Edit\|Write\|MultiEdit` で配線**して包含関係を固定 | R-026 を**補強**（本ガードが MultiEdit に載る形が既にテストで想定されている） |
| `scripts/check-approval-token-write.sh:52-54` | `cat` は `[ -z "$TARGET" ]` の内側。`[ ! -t 0 ]` ガードは**無い** | R-027 成立（現行が無害なのは TA-25 が env を設定して `cat` に到達しないため） |
| `scripts/hooks/check-plan-hash.sh:56` | `[ -z "$target_file" ] && [ ! -t 0 ]` という既存パターンが実在 | R-027 の「模倣すると TTY 時全スキップ」が現実的 |
| `tests/extras/ta-25-approval-token-guard.sh:9` | `PG_T25_GUARD="$PG_T25_ROOT/scripts/..."` に override 無し | R-029 成立 |
| 同 TC-03 / TC-04 / TC-05 | stdin リダイレクト無し・期待 rc は `1` / `1` / `0` | R-027 / R-029 成立 |
| `.claude/settings.example.json:72,81` | `check-approval-token-write.sh` の呼出は**いずれも引数なし** | R-031 成立 |
| `docs/ai/settings-wiring-contract.md:152` | EH-10 = 承認トークン書込みガード | R-033 成立 |
| `docs/ai/hook-enforcement.md:10-18` | EH-10 / EH-11 は #760 / #762 の「候補」名として**予約済み**とし EH-12 を採番 | R-033 成立（**正本間の矛盾**） |

#### R-030 の母集団を自分で数え直した結果

```sh
git log --all --diff-filter=A --format='C %ad' --date=short --name-only -- '*/approvals/*.json'
```

| 区分 | 実測 |
|---|---|
| 追加イベント（全 ref・重複含む）総数 | **163** |
| うち `< 2026-06-02` | **132** |
| うち `>= 2026-06-02` | **31** |
| distinct path の初出が `< 2026-06-02` | **66** |
| distinct path の初出が `>= 2026-06-02` | **22** |
| 分布の開始日 | **2026-04-27**（以降 04-30 に 16、05-17 に 42、05-18 に 28 等） |

→ 起点を 2026-06-02 に置くと、**distinct 88 件中 66 件（75%）が母集団から落ちる**。
落ちる 66 件は「ガードが存在すらしなかった期間」の artifact であり、
監査目的（どの承認 artifact を信頼してよいか）に対して切り方が逆を向いている。
**R-030 は成立**。

> ⚠️ レビュー本文の概数（「06-02 より前に約 120 件」「04-30 に 12」）は本実測
> （132 / 16）と一致しない。集計単位（追加イベント数 / distinct path 数）か
> ref 範囲の差と見られる。**結論（起点が誤り・除外分の方が高リスク）は不変**の
> ため R-030 は採用し、**数値は本節の実測値を正本**とする。

### 監査表（追記専用）

| R-NNN | status | reflected_in(commit) | notes |
|---|---|---|---|
| R-026 | reflected | 4edf501 | `parsed-safe` に MultiEdit 追加 / TC-22a・22b 新設 / 許容 tool 集合を正本由来に |
| R-027 | reflected | 4edf501 | TTY・stdin 不在を parse-unknown（block）へ統一 / TC-23 非ハング / 第 4 変異 / legacy stdin 明示 |
| R-028 | reflected | 4edf501 | TC-13c を 13c-file / 13c-cmd へ分割 / 第 5 変異（stdin 抽出の env 再従属） |
| R-029 | reflected | 4edf501 | `PG_T25_GUARD` override を実装要件化 / TC-15〜17 を実 TC kill 方式へ書き換え |
| R-030 | reflected | 4edf501 | AC-09 母集団を全体へ / 保護状態 3 区分 / 実測値を plan へ記載 |
| R-031 | reflected | 4edf501 | AC-06 と plan に dead code 明記 / handoff 必須記載を Task 4 へ |
| R-032 | reflected | 4edf501 | TC-02 を TC-02a / TC-02b へ分割 |
| R-033 | **deferred-to-human** | 4edf501（提示のみ） | EH-10 ID 衝突は**正本間の矛盾**。採番の確定は Human C-3 判断事項として plan へ記載。AI は正本を書き換えない |
| R-034 | reflected | 4edf501 | AC-11 に negative declaration（NotebookEdit / MCP write / Codex 経路は対象外）を併記 |

### Human C-3 の判断事項（AI が決めない）

| ID | 論点 | 選択肢 |
|---|---|---|
| **G-6（R-033）** | `EH-10` の採番衝突をどちらへ寄せるか | (a) EH-10 = 承認トークンガードで確定し `hook-enforcement.md` の予約記述を是正 / (b) #760 側の予約を優先し本ガードへ別番号（例 EH-13）を採番 / (c) 本 PBI では確定せず handoff に衝突として記録し別 PBI へ分離 |
| **G-7（R-027 の副作用）** | TTY 起動を block 側で統一すると、**端末から env のみで hook を手実行した場合も `exit 2`** になる | (a) 承認境界では可用性より fail-closed を優先し許容 / (b) 手実行用の明示 opt-in を別途設ける |
| **G-8（R-026 の範囲）** | `parsed-safe` の許容 tool 集合を **どこまで正本から導出するか** | (a) `Edit` / `Write` / `MultiEdit` / `Bash` の固定 4 種 / (b) `settings.example.json` の matcher と `matcher_covers()` の包含規則から機械導出 |

> `.claude/settings*.json` は **Hardening Override 対象**。本 PBI は settings を
> 変更しない（Out of Scope / #928）。settings 側の追随が要る場合も **AI は patch 提示のみ**で、
> 適用は Human-owned。

C2-VERDICT-2: conditional（major 5 / minor 3 / info 1 を 1 回確定反映。plan_hash は再計算が必要で、
既発行 `approvals/c3.json`（plan `24fcdf9f…`）は**本反映により stale となる**。
新 plan_hash に対する **c3.json の再発行は Human-owned**。AI は発行しない）
