# TASK-1023 Handoff — 承認トークンガードの二重無効化封鎖（EH-13）

> テンプレート: `docs/working/templates/handoff.md` 準拠 / WF-05 必須 6 要素
> branch: `fix/1023-exec`（base `origin/main` = `5e630f9`）/ Mode: `critical` / `lite_eligible=false`
> 作成: 2026-08-10 19:30 UTC（V-1 PASS・V-2 変更なし・V-3 + river-review 反映後）

## 1. 要件適合確認結果（AC ごと）

| AC | 内容（要約） | 判定 | 根拠 |
|---|---|---|---|
| AC-01 | Edit/Write/MultiEdit の token file_path block（exit 2、top-level legacy fallback 含む） | **PASS** | T1023-TC-01/02a/02b/22b（ta-25 全 PASS） |
| AC-02 | env target 有無に関係なく stdin を常時・独立評価（env 時 stdin bypass 封鎖） | **PASS** | T1023-TC-03/04 |
| AC-03 | jq 不在 / malformed / empty / TTY / read error は parse-unknown fail-closed（G-7=(a)） | **PASS** | T1023-TC-05/06a/06b/07/07b/23 |
| AC-04 | 読取専用は通す・normal write は通す・非 TTY CLI は拒否 | **PASS** | T1023-TC-08〜11/22a/22c |
| AC-05 | 代表 write surface の per-surface block | **PASS** | T1023-TC-04/12 +（V-3 追加）TC-25/26 |
| AC-06 | env → `$1` fallback・env 優先・stdin 独立 | **PASS** | T1023-TC-13a/b/13c-file/13c-cmd/14a/b/c（`$1` は実運用 dead code、既知課題 #4） |
| AC-07 | mutation 7 種を実 TC の FAIL で kill | **PASS** | T1023-TC-15〜17e（7/7 kill、baseline/restore 込み） |
| AC-08 | syntax / focused / full suite 全 PASS | **PASS** | T1023-TC-18: syntax=0 / TA-25 standalone 47 passed 0 failed / full suite 577 passed 0 failed（full suite は V-3 反映前の実測。反映後 focused 47/0、full suite 再実行はオーガナイザー T-10） |
| AC-09 | 既存 approval artifact の read-only 監査（起点 2026-04-27・3 区分・単位併記） | **PASS** | T1023-TC-19 = `evidence/verification/approval-audit.md` |
| AC-10 | legacy TC 保持 + standalone rc 伝播 + stdin 未リダイレクト起動ゼロ | **PASS** | T1023-TC-20/24 |
| AC-11 | Hook E2E（configured Claude Code）+ MultiEdit 到達性 | **PASS（条件付き）** | TC-21b 到達性実測済（`evidence/e2e/multiedit-reachability.md` → G-9=(i)）。**TC-21（Edit/Write/Bash の E2E）は T-09 として未実施 = MERGE_READY 前の残条件** |

## 2. 既知課題一覧

1. **間接書込みは構造的射程外（否定宣言）**: `git apply /tmp/x.patch` のように**コマンド文字列に token パスが現れない**間接書込みは、コマンド文字列ヒューリスティックでは原理的に検出できない（V-3 指摘 (a)）。同型: 変数展開（`P=docs/...; cp x "$P"`）、スクリプトファイル経由実行。防御は EH-3 provenance 検証（#420）・CI 差分検査との多層で担う。
2. **引用符内 `>` の誤 block（fail-safe 方向）**: `grep -n ">" <token パス>` のような読取専用コマンドが rc=2 になる（V-3 指摘 (b)）。誤 block は安全側（承認トークンを守る方向）のため本 PBI では修正しない。回避は `PLANGATE_SKIP_TOKEN_GUARD=1`（Human-owned）または引用パターンの変更。
3. **EH-13 配線契約と example の不整合（#928 残存）**: 契約 `settings-wiring-contract.md` は「`PLANGATE_HOOK_FILE` を引数として明示的に渡す」と規定するが、`.claude/settings.example.json` の 2 呼出（L72/L81）は引数なし → `$1` fallback は実行時 dead code。**`.claude/settings.example.json` は HO のため patch 案の提示のみ**（適用は Human-owned）:

   ```diff
   -            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh"
   +            "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh \"${PLANGATE_HOOK_FILE:-}\""
   ```

   （2 箇所。適用時は `scripts/check-settings-wiring.sh` の checks への EH-13 追加＝契約 §EH-13 の項目 2 も併せて実施）
4. TA-25 legacy TC-06（hmac_signature schema）は HO patch 未適用の既知 SKIP（従来どおり）。
5. V-3 追加 TC-25/26/27 は plan 承認後の追加のため **対応 mutation（m-1 相当）を持たない**。ただし TC-26 は実装過程で `-C` オプション未対応の regex に対し実際に FAIL しており（`evidence/test-runs/ta-25-v3-round-red.log`）、検出力は実測で示されている。mutation 化は V2 候補 #2。

## 3. V2 候補（今回 scope 外）

1. **#928**: EH-13 引数配線の契約 drift 解消 + `check-settings-wiring.sh` checks への EH-13 追加（既知課題 3 の恒久化）。
2. V-3 追加 TC-25/26（ed/ex・git 復元系）の mutation 追加（変異 8: ed/ex 行除去 / 変異 9: git 行除去）と kill 実証。
3. 間接書込み（`git apply` / 変数展開）への対策検討: コマンド文字列でなく **効果ベース**（PostToolUse での token ファイル hash 照合、または CI 側 diff 検査の強化）。
4. #760 / #762（EH-10 / EH-11 予約枠）実装時の採番整合の再確認。

## 4. 妥協点（採用しなかった選択肢と理由）

| 妥協点 | 採用しなかった選択肢 | 理由 |
|---|---|---|
| Bash 検出はコマンド文字列ヒューリスティック | 実行トレース / 効果ベース検出 | PreToolUse 時点では実行前で効果を観測できない。多層防御（EH-3 / CI）と併用する前提で許容 |
| MultiEdit は file_path のみ評価（M-3） | `edits[]` 内文字列マッチ | field 定義 artifact ゼロ・任意文字列マッチは本 plan 自身を誤 block（D-011） |
| MultiEdit の E2E 対象外（G-9=(i)） | settings patch で配線追加 | tool 自体が Claude Code 2.1.226 に存在せず到達経路なし。patch は無意味（D-015） |
| git 検出は復元系 4 subcommand 固定 | `git` 全 subcommand block | `git log -- <token>` 等の読取まで誤 block する。write 効果を持つ subcommand に限定（TC-27 で負ケース保証） |
| 引用符内 `>` の誤 block を残置 | 引用符解釈の追加 | shell 引用の完全解釈は複雑化・バグ源。fail-safe 方向のため残置（既知課題 2） |
| stdin 未供給の手実行が exit 2 | 手実行検出で通す | G-7=(a) Human 裁定で fail-closed を許容。escape hatch は `PLANGATE_SKIP_TOKEN_GUARD=1`（Human-owned） |

## 5. 引き継ぎ文書（5 分サマリ）

- **何を直したか**: `scripts/check-approval-token-write.sh`（EH-13）の二重無効化 — (1) block が exit 1 で PreToolUse 契約上 block になっていなかった → exit 2、(2) env target 供給時に stdin 評価がスキップされ Bash 経由が素通り → stdin 常時独立評価、(3) parse 不能時 fail-open → parse-unknown fail-closed（G-7=(a)）。V-3 ラウンドで ed/ex・git 復元系（checkout/restore/checkout-index/update-index）の実測 bypass 2 系統も封鎖。
- **Human 裁定**: G-6=(b)→**EH-13** 採番（EH-10/11 は #760/#762 予約、EH-12 は git-destructive 採番済み）/ G-7=(a) fail-closed 許容 / G-8=(a) 固定 4 種 / G-9=(i) MultiEdit 到達経路なし（decision-log D-013〜D-015）。
- **security closure の宣言**: **Edit / Write / Bash の 3 surface**。MultiEdit・NotebookEdit・MCP write・Codex 経路・間接書込み（`git apply` 型）・bypass 発行元検証は否定宣言側（閉じていない）。
- **残条件（MERGE_READY 前）**: **TC-21 Hook E2E（configured Claude Code / Edit・Write・Bash、T-09）が未実施**。加えて T-08 push / Draft PR 更新、T-10 evidence push + CI/CodeQL 再確認、full suite の V-3 反映後再実行（いずれもオーガナイザー実施）。
- **触ってはいけないもの**: `docs/working/*/approvals/`（AI 書込禁止・本ガードの保護対象そのもの）、`.claude/settings*.json`（HO・patch は既知課題 3 の提示のみ）、plan.md（C-3 承認済み・plan_hash 束縛）。
- **主要ファイル**: guard = `scripts/check-approval-token-write.sh` / テスト = `tests/extras/ta-25-approval-token-guard.sh` / 契約 = `docs/ai/settings-wiring-contract.md` §EH-13・`docs/ai/hook-enforcement.md`・`docs/ai/approval-token-guard.md` / 証跡 = `docs/working/TASK-1023/evidence/`。

## 6. テスト結果サマリ

| 実行 | 結果 | 証跡 |
|---|---|---|
| syntax（`sh -n`） | exit 0 | `evidence/test-runs/syntax.log` |
| TA-25 standalone（V-3 反映後） | **47 passed / 0 failed**（exit 0。TC-06 既知 SKIP 1） | `evidence/test-runs/ta-25-v3-round.log` |
| TA-25 standalone（exec 完了時点） | 44 passed / 0 failed | `evidence/test-runs/ta-25.log` |
| full suite（`tests/run-tests.sh`、V-3 反映前） | **577 passed / 0 failed** | `evidence/test-runs/full-suite.log`（反映後再実行はオーガナイザー T-10） |
| mutation 7 種 | 7/7 kill（実 TC の FAIL で実証） | `evidence/test-runs/mutation.log` |
| RED/GREEN（TDD） | RED 実測 → GREEN | `evidence/test-runs/red-ta25-pre-fix.log` / `green-ta25-post-fix.log` |
| V-3 ラウンド RED（TC-26 が regex 欠陥で FAIL） | 検出力の実測 | `evidence/test-runs/ta-25-v3-round-red.log` |
| MultiEdit 到達性 / artifact 監査 | 実測済 | `evidence/e2e/multiedit-reachability.md` / `evidence/verification/approval-audit.md` |
