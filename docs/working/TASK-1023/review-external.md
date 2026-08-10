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

C2-VERDICT-2: conditional（major 5 / minor 3 / info 1 を 1 回確定反映。plan_hash は再計算が必要。
確定後 plan_hash に対する **c3.json の発行は Human-owned**。AI は発行しない）

---

## 追記 2-a: 上記 2 点の訂正（2026-08-10 / オーガナイザー照合）

> 追記専用のため上の記述は残し、本節で訂正する。

### 訂正 1（major）: 監査母集団の件数を AC の契約値から外した

「追記 2」の R-030 節で **「本節の実測値を正本とする」** と書いたが、この表現は誤りだった。
`docs/working/**/approvals/` は**承認のたびに増える成長ディレクトリ**であり、絶対件数を AC / plan の
契約値に置くと **本 PBI と無関係な承認や PR が AC を壊す時限爆弾**になる（本リポジトリの既往教訓）。

- `pbi-input.md` の **AC-09 から絶対件数を削除**し、区分（(a)/(b)/(c)）と起点の決め方だけを AC に残した。
- 件数は `plan.md` 側で **集計コマンド + 集計単位 + 測定日 + base SHA を併記したスナップショット**として保持し、
  「契約値ではない」と明記した。
- 起点 `2026-04-27` は**リポジトリ初出という性質**で成長しないため AC に残した。

さらに、**同日に 3 者で数値が一致していない**ことが判明した。原因は母集団の変動ではなく**集計単位の差**:

| 測定者 | 集計単位 | 総数 | `< 2026-06-02` |
|---|---|---|---|
| C-2 レビュー本文 | 不明 | — | 約 120 |
| 本ワーカー | 追加イベント（commit×file / `--name-only`）| 163 | 132 |
| 本ワーカー | distinct path 初出 | 88 | 66 |
| オーガナイザー | commit 単位（`--format='%ad'` のみ）| 153 | 126 |

**どの単位でも「母集団の 7 割以上が `< 2026-06-02` に集中する」点は不変**であり、
R-030（起点変更）の根拠は**件数の絶対値ではなく分布の偏り**に依る。次に測る人が同じ混乱をしないよう、
plan.md に単位明記の要求を残した。

### 訂正 2（minor）: 「既発行 c3.json が stale」は事実誤認

「追記 2」末尾および完了報告で「既発行 `approvals/c3.json`（plan `24fcdf9f…`）は stale。**再発行**が必要」と
書いたが、**TASK-1023 に c3.json は存在しない**。以下を実測（2026-08-10 / base `fac3445`）:

| 確認 | コマンド | 結果 |
|---|---|---|
| tracked | `git ls-tree -r --name-only origin/main -- docs/working/TASK-1023` | `.md` 8 件 + `decision-log.jsonl` のみ。`approvals/` **なし** |
| 全 ref の履歴 | `git log --all --oneline -- 'docs/working/TASK-1023/approvals/*'` | **0 件** |
| worktree | `ls -la docs/working/TASK-1023/approvals` | **No such file or directory** |

`24fcdf9f…` は **C-1 / C-2 と PR #1024 本文に記載された plan hash** であって、承認トークンに刻まれた
hash ではない。PR #1024 本文も「Human C-3: 未承認」と明記していた。
したがって必要なのは **c3.json の「初回発行」**であり「再発行」ではない
（前者は「まだ承認していない」、後者は「承認をやり直す」で Human の作業も意味も異なる）。
plan / todo / pbi-input / current-state / INDEX / review-self の該当箇所をすべて訂正した。

> issue #1023 の進捗コメントには「別 worktree に untracked の `c3.json` が存在する」旨の記述があるが、
> **本 worktree からは検証できず git 履歴にも痕跡が無い**。仮に存在しても反映前 plan に対するもので
> 本 plan には使えない（plan_hash mismatch）。実体確認は Human 側で行う。

### 監査表（訂正分）

| R-NNN | status | reflected_in(commit) | notes |
|---|---|---|---|
| R-030 | **re-reflected** | 0352c68 | AC から絶対件数を削除。plan 側にコマンド + 単位 + 測定日付きスナップショットとして保持。3 者の数値差が集計単位差である旨を明記 |
| （訂正）| corrected | 0352c68 | 「既発行 c3.json が stale / 再発行」→「**未承認 / 初回発行**」へ全ファイル訂正（実測 3 点で確認）|

---

## 追記 2-b: 独立 river-review（2026-08-10 / major 3 / minor 4 / info 1）

> 追記専用。上の記述は残し、本節で是正内容を記録する。
> **8 件すべて成立**と判定し反映した（反証なし）。前節「追記 2」で私が書いた
> **closure 4 surface 宣言そのものが M-1 で否定された**。

### M-1（major）: 「settings patch 不要」の判断は誤りだった

前節で「本反映は settings 変更を要求しない」と報告したが、実測すると:

| 実測対象 | 値 |
|---|---|
| `docs/ai/settings-wiring-contract.md` §EH-10 | 「**`PreToolUse(Edit\|Write)` に配線する**」＝契約自体が `Edit\|Write` |
| `.claude/settings.example.json:68,78` | token guard は `Edit\|Write` と `Bash` の **2 matcher のみ** |
| 私が追加した `plan.md` 否定宣言 | 「閉じるのは **4 surface**（MultiEdit 含む）」 |

**配線されていない surface を「閉じた」と宣言していた**。実害は 2 つ:

1. AC-11 / TC-21 / T-09 が **MultiEdit の実 E2E 証跡**を要求するが、hook が発火しないなら取得できず、
   AC-11 の「未取得なら BLOCKED」で **PBI が自分の AC で恒久 BLOCKED**になる
2. `Edit|Write` が MultiEdit にマッチしないなら、**MultiEdit 経由の承認 artifact 書き込みは本 PBI 完了後も無防備** —
   否定宣言に列挙していない **4 つ目の残存経路**

**反映**: 否定宣言を**到達性依存の分岐**へ書き換え / Verification Plan に **MultiEdit 到達性の実測**を追加 /
**G-9**（到達しない場合の (i) AC から外す・(ii) settings patch 提示）を新設 / TC-21b 追加 / T-09 に順序注意を明記。

> **HO 境界の非対称性**（レビュー指摘どおり）: `.claude/settings*.json` は HO 9 カテゴリ内で**適用は Human-owned**、
> 一方 `docs/ai/settings-wiring-contract.md` は **9 カテゴリ外なので AI が書ける**。
> ただし §EH-10 の書き換えは **G-6（採番）と G-9(ii)（配線対象）の両方に依存**するため、
> 未決の Human 判断を先取りしないよう **本反映では行わない**（Out of Scope として plan に明示）。

### M-2（major）: R-030 の反映が AC 文言止まりで TC-19 に届いていなかった

AC-09 は起点・3 区分・集計単位併記を要求するが、**TC-19 は無変更**だった。
旧起点（2026-06-02）で inventory を作っても TC-19 が PASS し V-1 で落ちない
＝ **R-026 で私が批判した「どちらに解釈しても AC が PASS する」構造を、R-030 の反映側で再生産していた**。
AC-09 は本 PBI で唯一「実行時に機械判定されない AC」なので、TC に書かなければ検出力ゼロ。

**反映**: TC-19 の期待結果に (1) 起点 `2026-04-27` (2) (a)(b)(c) 3 区分 (3) 集計単位・測定日・base SHA の併記
を**欠落で FAIL** として追加。

### M-3（major）: `edits[]` の path field 未特定 → 実装が二択になる

`grep -rn 'tool_input.edits\|\.edits\[' scripts/ tests/ docs/` は**本 TASK 以外 0 件**（実測）。
定義 artifact が無いまま実装すると (i) 存在しない field を見て自作 payload にだけ緑（**vacuous AC の再生産**）か、
(ii) 任意文字列マッチに緩めて誤 block、の二択。しかも (ii) では
**本 plan 自身が本文に `docs/working/TASK-1023/approvals/c3.json` を含むため、この plan の MultiEdit 編集が block される**。

**反映**: `edits[]` 評価を**落とし** `tool_input.file_path` のみに限定（理由を plan に明記）。TC-22b(ii) を削除し、
**誤 block 方向の負 TC（TC-22c: 本文に token path 文字列を含む通常ファイル → rc=0）**を追加。
`edits[]` の実 payload が確認できたら再検討（handoff の V2 候補）。

### minor / info

| ID | 反映 |
|---|---|
| m-1 | 変異 **6**（`parsed-safe` から `MultiEdit` 除去 → TC-22a が kill）/ **7**（top-level fallback 除去 → TC-02b が kill）を追加し **5 種 → 7 種**。「新規 TC に対応する変異を持たないものを残さない」を Exit Criteria へ |
| m-2 | G-7 の論点を「TTY 限定」から **「stdin 未供給の手実行全般」**へ訂正（AC-03 により `< /dev/null` でも block）。選択肢に **(c) 既存 `PLANGATE_SKIP_TOKEN_GUARD=1` の文書化のみ（追加実装ゼロ）** を追加 |
| m-3 | Decision Table の TTY 行の根拠を「env 評価が先だから」→**「`[ -t 0 ]` 判定を `cat` より前に置くため」**へ訂正（設計自体の非ハング性は成立） |
| m-4 | 「7 割以上が集中」を根拠から外し、**「起点より前は保護が 0 だった」という時間不変の性質**へ言い換え。比率は 2026-08-10 時点の参考スナップショットと明示 |
| i-1 | `AC-33` → **`R-033`** のタイポ訂正 / `pbi-input` 既存行の「EH-10 を追加する」を**「採番は G-6 の決定に従う」**へ / `INDEX` `current-state` の更新時刻を **UTC 表記に戻し**、記述対象の最後の判断より後の時刻へ |

### 監査表（追記 2-b 分）

| ID | status | reflected_in(commit) | notes |
|---|---|---|---|
| M-1 | reflected | pending | closure を到達性依存へ / 到達性実測ステップ / G-9 / TC-21b / HO 非対称性。契約文書の追随は G-6・G-9 決定後（Out of Scope 宣言） |
| M-2 | reflected | pending | TC-19 に起点・3 区分・集計単位の機械検査を追加 |
| M-3 | reflected | pending | `edits[]` 評価を削除し `file_path` のみに限定 / TC-22b(ii) 削除 / TC-22c 追加 |
| m-1 | reflected | pending | 変異 6・7 を追加（5 種 → 7 種）/ TC-17d・17e |
| m-2 | reflected | pending | G-7 を「stdin 未供給の手実行全般」へ / 選択肢 (c) 追加 |
| m-3 | reflected | pending | TTY 行の非ハング根拠を訂正 |
| m-4 | reflected | pending | 比率を根拠から外し時間不変の性質へ |
| i-1 | reflected | pending | R-033 タイポ / EH-10 前提 / 時刻表記 |
