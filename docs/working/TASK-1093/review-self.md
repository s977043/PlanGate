# C-1 セルフレビュー — TASK-1093 (#1093)

> 実施: 2026-08-15 / mode=**high-risk** → **17 項目**（Plan 7 / ToDo 5 / TestCases 3 + 追加 2）
> 対象: `pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md`（本ブランチ `plan/1093-release-prep-detector`）

## 総合判定: **WARN**（exec 可能。ただし **U-1 / U-2 の Human 判断が C-3 で必須**）

`critical` / `major` 相当の欠陥は無い。**WARN の理由は「AI が単独で決めてはいけない
判断が 2 件残っている」ことのみ**で、これは high-risk・人間 C-3 必須の設計上
正しい残し方である（隠さず Questions / Unknowns に上げている）。

## Plan チェック（7 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | **PASS** | AC-1〜AC-7 が test-cases.md に 1:1 マッピング表で対応。さらに issue の穴 (a)(b)(c)(d) それぞれに **専用の TC** を 1:1 で割り当て（(a)=TC-07/08, (b)=TC-06, (c)=TC-09/10, (d)=TC-01/02/03/14/15） |
| C1-PLAN-02 | Unknowns 処理 | **WARN** | U-1（初期 ack の是非）/ U-2（契約の遡及可否）が**未解決のまま**。ただし **Human 判断事項として明示**し、todo の H-1 に紐付け、exec 開始の依存関係に組み込んでいる（握りつぶしではない）。U-3 は AI 提案あり |
| C1-PLAN-03 | スコープ制御 | **PASS** | Out of scope（個別 apply script の是正 / HO パス / `--apply` 実行 / 承認境界緩和）を Non-goals に明記。Files 表で「触らない」列を持ち、T-15 で `git diff --stat` 0 件を機械確認。他セッション占有域（`ta-65-*` / `check-plan-hash.sh`）も明記 |
| C1-PLAN-04 | テスト戦略 | **PASS** | Unit / Integration / 環境同値 / **Mutation** / Verification Automation / 回帰 baseline の 6 層。とくに **MUT-1〜5 で「call site を壊す」変異**を定義し、空振り fixture を排除する設計 |
| C1-PLAN-05 | Work Breakdown の Output | **PASS** | 全 10 Step に成果物パスを記載。Step 1 は**実測済み**（`evidence/apply-dryrun-matrix.txt`、34/34） |
| C1-PLAN-06 | 依存関係 | **PASS** | H-1(C-3)→T-04 以降 / T-03→T-04（推測で台帳を書かない）/ T-11→T-12（書きっぱなし禁止）/ T-15→T-16 を明記 |
| C1-PLAN-07 | 動作検証の自動化 | **PASS** | `evidence/*.sh` は `<repo_root>` 引数で任意ディレクトリから再実行可能（`measure-apply-dryrun.sh` は既にその形）。TC-10 のみ半自動と**明示** |

## ToDo チェック（5 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TODO-01 | タスク粒度 | **PASS** | Agent 17 / Human 3。high-risk 帯（11-20）に収まる。1 タスク 1 成果物 |
| C1-TODO-02 | depends_on | **PASS** | 全タスクに記載。Human ゲート（H-1）が実装タスクの前段にある |
| C1-TODO-03 | チェックポイント | **PASS** | 全タスクに 🚩。停止条件 SC-1〜SC-4 を plan に定義し、SC-2（ack を増やさない）/ SC-3（スコープ逸脱）は todo の 🚩 に反映 |
| C1-TODO-04 | Iron Law 遵守 | **PASS** | NO MERGE BY AI / `--apply` を AI が実行しない（**sandbox 内でも**）/ HO 非編集 / ack を AI 判断で増やさない、の 4 点を独立節で明記 |
| C1-TODO-05 | 完了条件 | **PASS** | 全実装タスクに `rollback:` を記載（high-risk では必須）。読取のみは「不要」と明記 |

## TestCases チェック（3 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TC-01 | 受入基準との紐付き | **PASS** | AC→TC 表 + 穴→TC 表の 2 枚。構造検査（TC-14/15/16）は AC 外だが再発防止として位置づけを明記 |
| C1-TC-02 | Edge case 網羅 | **PASS** | E-01〜E-08（空行 / 重複 / 列欠落 / symlink / scope 不整合 / ack 不正 / 0 本 / 空白名）。**すべて「曖昧なら `unknown`＝安全側 NG」**に倒している |
| C1-TC-03 | 自動化可否 | **PASS** | TC-10 を除き全件自動。TC-10 は「実機 2 環境の実走」が本質のため半自動と明示（誤魔化していない） |

## 追加チェック（high-risk / リリースプロセス保護帯）

| ID | 観点 | 判定 | 根拠 |
|----|------|------|------|
| C1-EX-01 | HO 判定の正しさ | **PASS** | `scripts/release-prep.sh` / `scripts/apply-registry.tsv` / `tests/extras/*` / `docs/**` は **HO 9 カテゴリ非該当**。正本（`check-plan-hash.sh` の `_override=0` 直後 `case`、本 HEAD で **L94**）を実測確認したうえで、**行番号ではなく記号で参照**している |
| C1-EX-02 | 承認境界を緩めていないか | **PASS** | 変更は **NG を増やす方向のみ**（fail-open→fail-closed）。C-3/C-4/EH-3 に触れない。`ack` は緩和機構だが **Human 発行に限定 + 毎回 WARN 表示**で不可視化しない |

## 実測に基づく検証（推測で書いていないことの証跡）

| 主張 | 実測コマンド | 結果 |
|------|-------------|------|
| apply script は **34 本**（全数） | `ls scripts/apply-*.sh \| wc -l` / matrix 行数 | **34 / 34 一致** |
| `apply-rnnn-c4-extension.sh` は真に未適用（TC-02） | `grep -c 'P-NNN（C-4 段階指摘の追記専用集約 / #689）' .claude/rules/working-context.md` | **0**（未適用を確認） |
| `apply-task-0130-working-context.sh` は真に未適用（TC-03） | `grep -c 'Stop Condition / Resume Condition / Replan Triggers' .claude/rules/working-context.md` | **0**（未適用を確認） |
| `apply-task-0146-ehs23-wiring.sh` は適用済み（TC-06） | `grep -c '# EHS-2 (TASK-0146 / #527)' bin/plangate` | **1**（適用済みを確認） |
| `apply-eh3-ho-always.sh` は本 HEAD で適用済み（TC-04） | `grep -n '_override=0'` / `grep -n 'if \[ -z "$task_id" \]; then'` | **94 < 119**（順序＝適用済み） |
| 実測が repo を汚さない | `git status --porcelain`（34 本 `--dry-run` 実行の前後） | **空**（副作用なし） |

## 指摘事項

| ID | Severity | 内容 | 対応 |
|----|----------|------|------|
| **S-1** | **major → Human 判断へ移送** | 新判定で `pending` が新規可視化され、**リリースが止まりうる**（R-1）。初期 ack を誰がどう決めるかが未確定 | **U-1 として C-3 で Human 判断**。AI は ack を増やさない（SC-2） |
| **S-2** | minor | 台帳（registry）は **apply script と適用済み判定の知識が二重化**する（R-2）。長期的には script 側の `PLANGATE-APPLY-STATUS` へ一本化するのが筋 | cross-check（TC-16）で drift を検知。一本化は **V2 候補**として handoff に記載 |
| **S-3** | minor | AC-1 は issue 文言が「**未適用の全スクリプト**」。全数が真に未適用でないと「全」を主張できない | 「全」の主張は **exec 時に台帳の `pending` 全件を列挙して実証**する。plan 段階で総数を契約値にしない（`feedback_whole_repo_ac_freshness`） |
| **S-4** | info | `apply-task-0134-progress.sh` の引数解析欠落（`--dry-run` がファイル名として解釈される）は Out of scope だが**将来の実害源** | T-16 で別 issue 起票 |
| **S-5** | info | issue 本文は「報告された 7 本」だが本 worktree 実測では **8 本**（環境差 = 穴 (c) の実例） | pbi-input に実測 8 本を明記済み。issue 側の数値は環境依存として扱う |

## exec 開始条件

- [ ] **H-1: 人間 C-3 APPROVE**（mode=high-risk のため **autonomous APPROVE 不可**）
- [ ] **U-1 の判断**（新規可視化 pending の初期 ack の是非）
- [ ] **U-2 の判断**（`--dry-run` 出力契約を既存 34 本へ遡及するか）
- [ ] C-2 外部レビュー実施（high-risk のため必須）
