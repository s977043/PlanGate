# EXECUTION PLAN — TASK-1061（S-2 / S-3 スライス）

> 対象 issue: [#1061](https://github.com/s977043/plangate/issues/1061)（親 EPIC [#1035](https://github.com/s977043/plangate/issues/1035)）
> 入力: `docs/working/TASK-1061/pbi-input.md`（ブランチ `docs/1061-pbi-input` / 70fee54）
> 本 plan の範囲は pbi-input の **S-2（薄い実行入口 skill）と S-3（OUTCOME 機械検証）に限定**する。
> S-1（hook 実機プローブ）/ S-5（`.claude/skills/` 欠落検出）/ S-6（hook 配線 patch）/ S-7 は **本 plan の Non-goal**。

## Goal

サブエージェント委譲プロトコル（必須 8 要素 / OUTCOME 契約）を **委託の瞬間に使える形**にする。

1. 派遣プロンプトを 8 要素で組み立てるための **薄い実行入口 skill** を追加する（正本を複製しない）
2. 完了報告の **OUTCOME 契約を機械判定**するスクリプトを追加する（`outcome-contract.md` §6 の項目 3・4・5）

## Constraints / Non-goals

### Constraints

- **Hardening Override 9 カテゴリに一切触れない**（`.claude/settings*.json` / `.claude/rules/*.md` / `.claude/commands/*.md` / `.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows/*` / `AGENTS.md` / `CLAUDE.md`）
- 検証ロジックは **`scripts/check-*.sh`（非 HO）** に置く。`scripts/hooks/` に置くと Human 適用待ちで止まる
- **契約本文（8 要素表・OUTCOME 定義）を skill に複製しない**。skill はリンクとチェックリストに徹する（二重正本の防止 / `hybrid-architecture.md` Rule 2）
- `approvals/*.json` を作成しない。PR を作成しない

### Non-goals

- `SubagentStart` / `SubagentStop` の実機プローブと hook 配線 patch（pbi-input S-1 / S-6）
- `.claude/skills/` ↔ `.agents/skills/` の片側欠落検出（pbi-input S-5）
- 8 要素・OUTCOME 契約の**内容**の変更（本 PBI は適用機構であって規約改定ではない）
- 既存 `subagent-dispatch` skill の改名・統廃合（責務が別）
- `outcome-contract.md` §6 の項目 1（成果物の有無）・2（制約違反）の機械判定 — **タスク依存で汎用判定不能**（pbi-input A-3 で P2 送り済み）

## Approach Overview

3 層（CLAUDE.md / Skill / Hook）のうち **Skill 層と、Hook からも手動からも共有できる検証ロジック層**を先に置く。
Hook 層（ハード強制）は未検証の実機プローブに依存するため、本スライスから切り離して後続に残す。

| 層 | 本スライスの成果物 | 強制力 |
|---|---|---|
| Skill（生成側） | `subagent-delegation-brief` SKILL.md × 2 配置 | ソフト |
| 検証ロジック（受領側） | `scripts/check-outcome-contract.sh` | 単体ではソフト。hook / CI から呼べば硬くなる |
| Hook | **本スライス対象外**（後続） | — |

### 配置の根拠

- skills の**正本は `.agents/skills/`**（`scripts/sync-plugin-plangate.sh` L24 の実測。同期先は `plugin/plangate/skills/`）
- `.claude/skills/` は同期経路外。**plugin 経路はリリース済み cache（現行 8.18.0）固定で HEAD が反映されない**ため、頻繁に iterate するガバナンス skill は `.claude/skills/` にも置く必要がある
- 二重配置になるため、**両者の同一性を test で機械検証する**（drift 面積は「薄い入口」に限定して最小化）
- `.claude/skills/` と `scripts/check-*.sh` はどちらも **HO 9 カテゴリ外**（`scripts/hooks/check-plan-hash.sh` の case 文が正本。`skills` / `scripts/check-` の言及 0 件）

### skill 名

**`subagent-delegation-brief`**。既存 3 集合（`.agents/skills` / `.claude/skills` / `plugin/plangate/skills`）で衝突 0 件。
`subagent-dispatch`（ロール分配・依存グラフ）とは責務が別であり、名前を分けて誤呼び出しを防ぐ。
`README.md` §2.3 が `.claude/skills/subagent-delegation/` を不採用とした一方で明記した
「**派遣プロンプト生成の薄い実行入口 skill を additive に追加する余地**」に正確に収める。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|---|---|---|---|---|---|
| S1 | ベースラインのテストスイート実行 | 既存 FAIL 0 の確認 | agent | 低 | 🚩 FAIL があれば即停止 |
| S2 | `tests/extras/ta-63-outcome-contract.sh` を先に書く（RED 確認） | テストファイル | agent | 低 | 🚩 実装前に FAIL することを確認 |
| S3 | `scripts/check-outcome-contract.sh` 実装 | 検証スクリプト | agent | 中 | 🚩 負側 9 ケースが全て非ゼロ exit |
| S4 | `.agents/skills/subagent-delegation-brief/SKILL.md` 作成（正本） | SKILL.md | agent | 低 | 🚩 契約本文を複製していない |
| S5 | `.claude/skills/subagent-delegation-brief/SKILL.md` を同一内容で作成 | SKILL.md | agent | 低 | 🚩 `diff` exit 0 |
| S6 | 全体検証（harness / standalone / 名前衝突 / ドッグフーディング） | 実行ログ | agent | 低 | 🚩 既存 FAIL 数が増えていない |

## Files / Components to Touch

| ファイル | 種別 | HO | 備考 |
|---|---|---|---|
| `.agents/skills/subagent-delegation-brief/SKILL.md` | 新規 | 非 HO | skills の正本側。`sync-plugin-plangate.sh` 経由で `plugin/` へ届く |
| `.claude/skills/subagent-delegation-brief/SKILL.md` | 新規 | 非 HO | HEAD 反映用。上記と byte-identical |
| `scripts/check-outcome-contract.sh` | 新規 | 非 HO | POSIX sh。stdin / ファイル引数の両対応 |
| `tests/extras/ta-63-outcome-contract.sh` | 新規 | 非 HO | `_extra-contract.sh` 準拠の回帰テスト |
| `plugin/plangate/skills/subagent-delegation-brief/SKILL.md` | 新規（**生成物**） | 非 HO | `sh scripts/sync-plugin-plangate.sh` の出力。手書きしない |
| `docs/working/TASK-1061/*` | 新規 | 非 HO | working context（plan / todo / test-cases / review-self / status） |

**上記以外のファイルには触れない。**

> `plugin/plangate/skills/...` は当初の想定外だったが、**必須**である。
> `.github/workflows/sync-plugin-plangate.yml` の `drift-check` job が **PR 時に
> `sh scripts/sync-plugin-plangate.sh` を実行し、`plugin/plangate/` に差分が出たら
> exit 1 で CI を落とす**（実測）。`.agents/skills/` に追加した以上、同期結果の
> コミットは省略できない。生成物であり手書き対象ではない。

> `tests/extras/ta-63-*.sh` は「実装 3 ファイル」に対する検証手段であり、
> `tests/extras/README.md` の規約上テストは同ディレクトリの独立ファイルとしてしか置けない。
> スコープ拡大ではなく **TDD の必然的な随伴物**として扱う（決定は decision-log 相当として status.md に記録）。

## Testing Strategy

### Unit（`scripts/check-outcome-contract.sh` の判定）

| 区分 | 内容 |
|---|---|
| 正例 | 契約準拠の報告 → exit 0 |
| 負例（項目 3） | `Outcome:` 小文字 / `OUTCOME:success`（スペースなし）/ `OUTCOME : success`（コロン前スペース）/ 複数出現 / 最終行でない / OUTCOME 行なし |
| 負例（項目 4） | 要判断事項が優先度なし箇条書き / 要判断事項セクション自体が無い（**別メッセージで区別**） |
| 負例（項目 5） | 「テストは問題ありません」だけで 4 区分の記載なし |

### Integration

- `sh tests/run-tests.sh`（harness 経路）で新規 extras が拾われ PASS
- `sh tests/extras/ta-63-outcome-contract.sh </dev/null`（standalone 経路）で rc=0

### Verification Automation

- `.agents/` と `.claude/` の SKILL.md 同一性を `diff` で test 内検証（drift の機械検出）
- `python3 scripts/check-skill-name-collisions.py` で名前衝突ゼロを確認
- **ドッグフーディング**: 本 PBI の完了報告自身を `check-outcome-contract.sh` に通す

## Risks & Mitigations

| ID | リスク | 緩和 |
|---|---|---|
| R-1 | skill を 2 箇所に置き drift する | 内容を「薄い入口」に限定 + test で `diff` 同一性を固定 |
| R-2 | 検証スクリプトが誤検出し、正当な報告を FAIL にする | 判定は §6 の項目 3・4・5 に限定。判定不能な項目 1・2 は**実装しない**。既知の限界（コードフェンス内の `OUTCOME:` 行を区別しない）を skill と script のコメントに明記 |
| R-3 | skill が呼ばれず脱落が再発する（ソフト強制の限界） | 本スライスでは解消しない。hook 層は後続スライスへ明示的に残す（handoff の妥協点） |
| R-4 | 新規 extras が `_extra-contract.sh` 契約に非準拠で ta-61 を落とす | `tests/extras/README.md`「新規ファイル checklist」7 項目に沿って作成し、harness / standalone 両経路で実行確認 |
| R-5 | 名前が既存 skill と混同される | `description` の「Use when / Do not use when」で `subagent-dispatch` との棲み分けを明示 + 衝突検出スクリプトを実行 |

## Questions / Unknowns

| ID | 未解決 | 扱い |
|---|---|---|
| U-1 | `SubagentStart` / `SubagentStop` の入力スキーマ | **本スライス対象外**。後続で実機プローブ（pbi-input S-1） |
| U-2 | `.claude/skills/` の 15 件欠落が意図的か放置か | **本スライス対象外**（pbi-input S-5） |
| U-3 | 検証スクリプトの出力を JSON 化するか（#230 接続） | 本スライスは人間可読テキストのみ。JSON は V2 候補 |

## Mode 判定

**モード**: `standard`（`lite_eligible = false`）

**判定根拠**:

- 変更ファイル数: 実装 3 + テスト 1 = **4** → 中（standard: 3-5）
- 受入基準数: **5** → 中（standard: 3-5）
- 変更種別: **code**（実行系 shell script を含む。doc-light は適用不可）
- リスク: 中（すべて additive。既存ファイルの変更 0）
- 影響範囲: 新規 skill と新規スクリプトのみ。既存の挙動を変えない
- ロールバック: 容易（4 ファイル削除で完全に戻る）
- **最終判定**: `standard`

**「承認境界周辺の変更 → 最低でも高」の非該当根拠**:

`mode-classification.md` の対象パスは HO 9 カテゴリと**完全一致**で列挙され、同節に
「注: `.claude/skills/` と `scripts/_*.py` は現行 override パターン**外**、本ルールでも追加しない」と
明記されている。本スライスの 4 ファイルはいずれも 9 カテゴリに該当しない（`scripts/check-*.sh` は
`scripts/hooks/*.sh` ではない）。pbi-input が `high-risk` を提案した根拠は
「成果物に `.claude/settings.json` への patch を含む」ことだったが、**本スライスは hook 配線 patch を
Non-goal として除外している**ため、その引き上げ条件は発生しない。また本成果物は承認境界
（C-3 / C-4 / NO MERGE BY AI）を一切変更しない。

**pbi-input（`high-risk` 提案）との差分**: スコープを S-2 / S-3 に縮小し、S-1 / S-5 / S-6 / S-7 と
9 件の AC のうち 4 件を後続へ送ったことによる。スコープが戻れば mode も `high-risk` に戻る。
