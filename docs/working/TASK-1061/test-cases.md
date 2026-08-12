# TEST CASES — TASK-1061（S-2 / S-3 スライス）

> plan: `docs/working/TASK-1061/plan.md`
> 自動化先: `tests/extras/ta-63-outcome-contract.sh`（`_extra-contract.sh` 準拠）

## 受入基準 → テストケース マッピング

| AC | 内容 | 対応 TC |
|---|---|---|
| **AC-1** | `subagent-delegation-brief` SKILL.md が `.agents/skills/` と `.claude/skills/` の両方に存在し、**byte-identical**。frontmatter は `name` / `description` の 2 キーのみ | TC-01 / TC-02 / TC-03 |
| **AC-2** | skill 本文が 8 要素チェックリストを持ち、**要素 4 に却下済み仮説と反証許可の欄**、**要素 7 に OUTCOME 契約への導線**、**成果物形式の欄**、**worktree 派遣の定型**を含む。かつ**契約本文を複製していない**（正本へのリンクで到達） | TC-04 / TC-05 / TC-06 |
| **AC-3** | `scripts/check-outcome-contract.sh` が `outcome-contract.md` §6 の項目 3・4・5 を判定し、契約準拠の報告に対し exit 0 を返す | TC-07 / TC-08 |
| **AC-4** | 負側 9 ケースがすべて非ゼロ exit。かつ「要判断事項が未分類」と「要判断事項セクション自体が無い」を**別メッセージで区別**する | TC-09〜TC-17 |
| **AC-5** | 新規 extras が harness / standalone の両経路で PASS し、既存スイートの FAIL 数を増やさない | TC-18 / TC-19 |

## テストケース一覧

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|---|---|---|---|---|
| TC-01 | — | `.agents/skills/subagent-delegation-brief/SKILL.md` の存在 | ファイルが存在する | 自動 |
| TC-02 | — | `.claude/skills/subagent-delegation-brief/SKILL.md` の存在 | ファイルが存在する | 自動 |
| TC-03 | TC-01/02 | 2 ファイルの `diff` | exit 0（byte-identical） | 自動 |
| TC-04 | TC-01 | SKILL.md 先頭の frontmatter | `---` に囲まれ、キーは `name:` と `description:` の 2 つのみ | 自動 |
| TC-05 | TC-01 | SKILL.md 本文 | 8 要素すべての見出し・`却下済み` / `反証` / `OUTCOME` / `P0` / `worktree` / `成果物` の語を含む | 自動 |
| TC-06 | TC-01 | SKILL.md 本文 | `docs/ai/subagent-delegation/` への相対リンクを含む（正本参照）／ `^OUTCOME: (success` の**判定用正規表現の完全複製を本文に持たない**ことは要素 7 のリンクで代替（複製禁止の主眼は 8 要素表と OUTCOME 定義表） | 自動 |
| TC-07 | — | `sh scripts/check-outcome-contract.sh` の存在・実行可能・`sh -n` | 構文 OK | 自動 |
| TC-08 | TC-07 | **正例**: `OUTCOME: success` が最終行 + `[P0]` 分類あり + `実行済み` あり | exit 0 | 自動 |
| TC-09 | TC-07 | 負例: `Outcome: success`（小文字） | 非ゼロ exit | 自動 |
| TC-10 | TC-07 | 負例: `OUTCOME:success`（スペースなし） | 非ゼロ exit | 自動 |
| TC-11 | TC-07 | 負例: `OUTCOME : success`（コロン前スペース） | 非ゼロ exit | 自動 |
| TC-12 | TC-07 | 負例: `OUTCOME: success` が 2 回出現 | 非ゼロ exit | 自動 |
| TC-13 | TC-07 | 負例: `OUTCOME: success` の後ろに本文が続く（最終行でない） | 非ゼロ exit + `最終行` を含む診断 | 自動 |
| TC-14 | TC-07 | 負例: `OUTCOME` 行が 1 つも無い | 非ゼロ exit | 自動 |
| TC-15 | TC-07 | 負例: 要判断事項が優先度なし箇条書き | 非ゼロ exit + `分類` を含む診断 | 自動 |
| TC-16 | TC-07 | 負例: 要判断事項セクション自体が無い | 非ゼロ exit + TC-15 と**異なる**診断メッセージ | 自動 |
| TC-17 | TC-07 | 負例: 検証状態 4 区分の記載なし（「テストは問題ありません」のみ） | 非ゼロ exit | 自動 |
| TC-18 | — | `sh tests/extras/ta-63-outcome-contract.sh </dev/null` | rc=0 | 自動（手動実行） |
| TC-19 | — | `sh tests/run-tests.sh` | 新規 extras が拾われ、既存 FAIL 数が増えない | 自動（手動実行） |

## エッジケース

| # | ケース | 期待挙動 | 扱い |
|---|---|---|---|
| E-1 | 要判断事項が「なし」と明記されている | **PASS**（分類欄が無いのではなく「無いと明記した」） | TC 化（TC-08 の正例に内包） |
| E-2 | `OUTCOME` 行の後に空行のみが続く | **FAIL**（契約は「OUTCOME 行の後に他の行を続けない」。末尾 grep 前提を守るため fail-closed） | 実装で扱う（診断メッセージで空行と本文を区別）。TC は本文が続く TC-13 で代表 |
| E-3 | 入力が空 | 非ゼロ exit（OUTCOME 行なし） | 実装で扱う |
| E-4 | 引数なし（stdin から読む） | stdin を読む。stdin も空なら E-3 と同じ | 実装で扱う |
| E-5 | 存在しないファイルパスを渡す | 使い方エラー（exit 2 = 契約違反 exit 1 と区別） | 実装で扱う |
| E-6 | 報告本文のコードフェンス内に `OUTCOME:` で始まる行がある | **区別しない**（複数出現として FAIL する）。**既知の限界**として script のコメントと skill に明記し、V2 候補に送る | 非 TC（既知課題） |

## 自動化可否

- TC-01〜TC-17: `tests/extras/ta-63-outcome-contract.sh` で自動化
- TC-18 / TC-19: 実行経路そのものの検証のため手動実行（結果は status.md に記録）

## 検出力の実証（変異注入）

新規テストが「実装を壊したら落ちる」ことを、**call site を壊す 4 変異**で実証する（結果は status.md に記録）。

| 変異 | 内容 | kill されるべき TC |
|---|---|---|
| M1 | 重複判定を `-gt 1` → `-gt 2` に緩める | TC-12 |
| M2 | 最終行チェックを `elif false` で無効化 | TC-13 |
| M3 | 要判断事項セクション欠落の分岐を到達不能にする | TC-16 |
| M4 | 検証状態チェックを常時 PASS にする | TC-17 |
