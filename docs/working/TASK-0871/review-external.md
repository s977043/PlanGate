# TASK-0871 外部 AI レビュー結果（C-2・追記専用集約）

> レビュー日: 2026-07-19 / 方式: 2 レーン（review-principles §7-bis）
> レーン1 = 設計妥当性（Codex / 別モデル）: critical 0, major 4, info 1
> レーン2 = コードベース整合: critical 0, major 2, minor 2, info 2
> 本ファイルは追記専用。計画本体への反映は 1 回確定反映（working-context F5-C）。

## 指摘一覧（R-NNN 採番）

### レーン1: 設計妥当性

| ID | severity | 要旨 | 根拠 |
|----|----------|------|------|
| R-001 | info | gh API 不達により issue #871 原文の独立照合が未了。C-3 前に `gh issue view 871` 成功ログの evidence 化を推奨 | レビュー環境の API 不達（起草側は取得済みだが独立証跡がない） |
| R-002 | major | AC-9 の「ai-dev / ai-loop 文書限定・#866 除外」は plan 側の付加解釈であり、TC-09 がこの**未承認スコープ解釈に依存**。C-3 で Human 明示承認 + issue への scope 注記が必要 | issue #871 本文 AC-9 は無限定（C-1 F-3 と同根・依存関係の指摘が追加） |
| R-003 | major | R-002 と同根: #866 別トラック化の**承認結果を issue と evidence 双方に残す規定**が plan / todo にない | 監査連続性（承認が会話内に閉じる） |
| R-004 | major | Stop / Replan の判定値（Human 未承認・不変条件欠落・正本外波及・2 巡超過）に**機械的取得方法・入力元がない**。各トリガに判定コマンド or 証跡パスを固定すべき（例: `approvals/c3.json`、allowlist 差分、review artifact 連番） | plan「Stop Condition / Replan Triggers」欄（C-1 F-1 反映版）の機械値が判定手段レス |
| R-005 | major | markdownlint / link check の**実行コマンド・対象・exit code 0 条件が未固定**。T-09 / TC-10 に明記し、ログ保存先を `evidence/verification/` に固定すべき | T-09 が「link check + markdownlint」の名称のみ |
| R-006 | major | C-3' 標準自動経路の定義が「WF-00〜07 不変」と両立するか未規定。正本に「PlanGate C-3 は常に Human・pre-exec のまま」「C-3' は ai-loop Delivery 後段に限る別経路で PlanGate C-3 を置換しない」を順序図付きで規定し、TC-04 に core-contract / WF 対応表の不変性確認を追加すべき | AC-4 と CLAUDE.md「本番フロー WF-00〜07 不変」の両立条件が正本確定内容に未記載 |

### レーン2: コードベース整合

| ID | severity | 要旨 | 根拠 |
|----|----------|------|------|
| R-007 | major | `.claude/skills/ai-loop-cycle/SKILL.md`（repo ローカル実行版）が `.agents` 版と**別内容で並存**（オーガナイザーが diff 実測確認済み）。L21-22 に「隔離 PoC」等の Phase 1 制限直書きあり。Files to Touch・T-07・付録 B rg のすべてから漏れ。HO 外・AI 編集可。#866 とはファイルが別なので Non-goals 除外を流用しない（扱いは C-3 判断事項に併記） | diff 実測（オーガナイザー） |
| R-008 | major | `docs/ai/ai-loop/concept.md`（L56 に merge-ready 責務表）/ `asset-inventory.md` / `hotl-merge-entry-criteria.md` が plugin 同梱（sync の `_ai_loop_spec_files`）なのに監査対象外。TC-09 / TC-12 の走査範囲と付録 B rg に `docs/ai/ai-loop/` を追加すべき（編集必須でなく「参照化 or 採否理由記録」対象・R-2 の 12 ファイル上限内） | sync スクリプト `_ai_loop_spec_files` 実測 |
| R-009 | minor | sync スクリプト L196 コメント「17 本」が実態 12 本と stale（rollout-policy.md は glob 自動同梱で TC-11 成立構造は妥当）。S7 でコメント数値レス化 or 採否記録。付随 [info]: rollout-policy.md は雛形注記ヘッダなしで導入先へ verbatim 配布される → 配布形態を C-3 論点に | sync スクリプト実測 |
| R-010 | minor | `.claude/skills/pr-watch/SKILL.md` L137 の「merge-ready 判定」が用語衝突しうる → TC-12 残置採否記録の対象に追加 | rg 実測 |
| R-011 | info | HO 判定・Metrics 実測値は plan と一致（**指摘なしの明示記録**・監査連続性） | 再実測一致 |
| R-012 | info | TASK-0822 に handoff 不在。design-philosophy.md §7.1 参照で制約継承済み（対応不要の記録） | 実測 |

### レーン間受け渡し（追加 AC 候補 → 受入基準網羅判定へ取り込み）

1. `.claude/skills/ai-loop-cycle/SKILL.md` にも旧 PoC 表現が残らない、または残置理由が evidence 化されている → **TC-14 として追加**
2. plugin 同梱 spec 層ファイル（`docs/ai/ai-loop/` の sync 対象）の責務・terminal state 記述が新正本と矛盾しない → **TC-15 として追加**

## 監査表（追記専用・squash/rebase 耐性）

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|----------------------|-------|
| R-001 | reflected | 本反映 commit | todo T-01 に `gh issue view 871` 成功ログの evidence 化を追加 |
| R-002 | deferred-to-C3 | 本反映 commit（Q4 強化のみ） | 承認自体は Human。plan Q4 に「TC-09 が本限定に依存」「issue へ scope 注記」を追記 |
| R-003 | reflected | 本反映 commit | H-01 / T-13 に「承認結果を issue コメント + evidence 双方に記録」の規定を追加（承認行為自体は C-3） |
| R-004 | reflected | 本反映 commit | Stop / Replan 全トリガに判定コマンド or 証跡パスを固定 |
| R-005 | reflected | 本反映 commit | T-09 / TC-10 に実行コマンド抽出元・対象・exit 0 条件・ログ保存先を固定 |
| R-006 | reflected | 本反映 commit | plan「正本に確定する内容」に C-3'/WF 不変両立の規定方針（順序図要件含む）を追加、TC-04 を拡張 |
| R-007 | reflected（扱いの最終確定は C-3 併記） | 本反映 commit | Files to Touch / T-07 / 付録 B rg に `.claude/skills/` 版を追加。取り扱い方針は plan Q5 に併記 |
| R-008 | reflected | 本反映 commit | TC-09 / TC-12 走査範囲と付録 B rg に `docs/ai/ai-loop/` を追加 |
| R-009 | 一部 reflected / 配布形態は deferred-to-C3 | 本反映 commit | T-08（S7）にコメント数値レス化 or 採否記録を追加。配布形態は plan Q6 |
| R-010 | reflected | 本反映 commit | TC-12 の残置採否記録対象に pr-watch の用語を追加 |
| R-011 | recorded | —（変更不要） | 指摘なしの明示記録 |
| R-012 | recorded | —（変更不要） | 対応不要の記録 |

status 別件数: reflected=7（うち 1 件は C-3 併記条件付き）/ deferred-to-C3=2（R-002・R-009 の配布形態）/ recorded=2（R-011/R-012）/ 一部 reflected=1（R-009）。
