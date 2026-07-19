# TEST CASES — TASK-0871

> 受入基準は issue #871 の AC 10 項目（pbi-input.md 参照）。
> 検証は doc 検証（機械 rg / link check / sync dry-run）+ 独立レビューで構成。

## AC → TC 対応表

| AC | 内容（要約） | TC |
|----|------------|----|
| AC-1 | 5 責務（PlanGate Core / ai-dev / ai-loop Delivery / ai-loop Evolution / Human）の定義 | TC-01 |
| AC-2 | `ai-dev: Request → PR_CREATED` / `ai-loop: Request → MERGE_READY` / `Human: C-4 → MERGED` の明記 | TC-02 |
| AC-3 | ai-loop が ai-dev の Plan / exec / verify を再実装せず共通利用 | TC-03 |
| AC-4 | C-3 / C-3' の通常経路・escalate 経路・判定主体が矛盾なし | TC-04, TC-13 |
| AC-5 | architecture invariant と rollout eligibility policy の分離 | TC-05 |
| AC-6 | 裁定状態（AUTO_APPROVED 等）と Delivery 状態（MERGE_READY 等）の区別 | TC-06 |
| AC-7 | 内側 Delivery Loop と外側 Evolution Loop の区別 | TC-07 |
| AC-8 | active run の harness 自己変更禁止・改善は別 TASK/PR | TC-08 |
| AC-9 | 正本一覧に同じ責務の複数正本なし（ai-dev / ai-loop アーキ文書に限定。#866 は対象外 — **限定は plan Q4 の C-3 承認が前提**） | TC-09, TC-15 |
| AC-10 | command / ai-loop-cycle / 00_concept / six-stage / adaptive / Core Contract の参照整合 | TC-10, TC-11, TC-12, TC-14 |

> TC-14 / TC-15 は C-2 レーン間受け渡しの追加 AC 候補（review-external.md 参照）を
> 受入基準網羅判定に取り込んだもの（AC-9 / AC-10 の配下として検証）。

## テストケース一覧

| TC | 前提条件 | 入力 / 手順 | 期待出力 | 種別 |
|----|---------|-----------|---------|------|
| TC-01 | S3 完了 | `rg -n "ai-loop Delivery|ai-loop Evolution|PlanGate Core" docs/workflows/ai-loop/00_concept.md` | 正本文書に 5 責務の表が 1 箇所存在し、各行に責務と AI 責務終点がある | 機械 + 目視 |
| TC-02 | S3 完了 | `rg -n "PR_CREATED|MERGE_READY|MERGED" docs/workflows/ai-loop/00_concept.md` | 3 状態すべてに意味と判定主体（ai-dev / ai-loop DoD 判定 / Human C-4）が定義されている | 機械 + 目視 |
| TC-03 | S3 完了 | 正本の共通利用節を確認（`rg -n "再実装" docs/workflows/ai-loop/00_concept.md`） | 「Plan / exec / verify を再実装せず共通利用」が明記 | 目視 |
| TC-04 | S3 完了 | 正本の C-3/C-3' 経路節を確認。working-context.md / decision-table.md の記述と突合。**加えて（C-2 R-006 反映）正本の順序図に「PlanGate C-3 = 常に Human・pre-exec / C-3' = ai-loop Delivery 後段限定の別経路で C-3 を置換しない」が明記されているかを確認し、`docs/ai/core-contract.md` §3（approve-wait = c3.json APPROVED）と WF-00〜07 対応表が本 TASK の diff で不変であることを `git diff` で確認** | C-3' = eligible run の標準自動経路、Human C-3 = escalate 経路、判定主体（arbiter / Human）が矛盾なし。**かつ core-contract の C-3 定義・WF 対応表に変更なし（不変性 PASS）** | 目視 + 機械（git diff） |
| TC-05 | S2/S3 完了 | `ls docs/workflows/ai-loop/rollout-policy.md` + 00_concept 内の Phase 1 制約記述を `rg "Phase 1"` で確認 | rollout-policy.md が存在し、00_concept 側の Phase 1 適用制限は参照のみ（invariant と分離） | 機械 + 目視 |
| TC-06 | S3/S4 完了 | plan 付録 B「同列列挙」rg + adaptive §4 の Stop contract 確認 | 裁定状態群と Delivery 状態群が別語彙群として定義され、同列 terminal state 列挙が解消 or 区別注記付き | 機械 + 目視 |
| TC-07 | S3 完了 | 正本の Loop 構造節を確認 | 内側 Delivery Loop（1 run）と外側 Evolution Loop（completed runs → improvement PR）が別節で定義 | 目視 |
| TC-08 | S3 完了 | `rg -n "harness" docs/workflows/ai-loop/00_concept.md` | active run は開始時 harness を保持し自己変更しない・改善は別 TASK/PR の規則が記載 | 機械 + 目視 |
| TC-09 | S4〜S6 完了・**plan Q4 の C-3 承認済み（未承認なら PASS 判定不可 — R-002）** | ai-dev / ai-loop アーキ・責務定義文書を列挙し、責務・terminal state・decision table の定義（参照でない実定義）の所在を確認。**走査範囲に `docs/ai/ai-loop/` の plugin 同梱 spec 層（concept.md / asset-inventory.md / hotl-merge-entry-criteria.md）を含める（C-2 R-008 反映）** | 各定義の実定義が 1 文書のみ。他は参照（spec 層は参照化 or 採否理由記録）。#866 領域（skills 正本）は判定対象外と明記 | 目視（表で evidence 化） |
| TC-10 | S5〜S7 完了 | AC-10 名指し 6 ファイルの相互参照を確認 + link check 実行 | link check PASS・6 ファイルの記述が正本と矛盾しない | 機械 + 目視 |
| TC-11 | S7 完了 | `sh scripts/sync-plugin-plangate.sh` dry-run | 差分ゼロ（差分ありなら sync 後に再実行しゼロ）。ログを evidence 保存 | 機械 |
| TC-12 | S8 完了 | plan 付録 B の用語監査コマンド全件実行（**走査範囲は `.claude/skills/` と `docs/ai/ai-loop/` を含む改訂版付録 B。`.claude/skills/pr-watch/SKILL.md` L137 の「merge-ready 判定」用語衝突も残置採否記録の対象 — C-2 R-008/R-010 反映**） | 旧定義・矛盾表現の残 = 0、または残す各件に採否理由が evidence にある | 機械 + evidence |
| TC-13 | 全実装完了 | maker と別コンテキストのレビュアーに正本 + 周辺 6 ファイルを渡しレビュー | 責務境界・C-3/C-3'・terminal state の矛盾指摘 0 件（>0 なら FAIL・差し戻し） | 独立レビュー |
| TC-14 | T-07 完了 | `rg -n "独立 PoC\|隔離 PoC\|適用ドメイン（Phase 1）" .claude/skills/ai-loop-cycle/SKILL.md` | 旧 PoC 表現が残らない、または残置理由が evidence 化されている（C-2 レーン間 AC 候補 1 / R-007） | 機械 + evidence |
| TC-15 | S4/S7 完了 | plugin 同梱 spec 層ファイル（sync `_ai_loop_spec_files` 対象の `docs/ai/ai-loop/` 各ファイル）の責務・terminal state 記述を新正本と突合 | 新正本との矛盾 0 件（矛盾は参照化 or 採否理由記録で解消。C-2 レーン間 AC 候補 2 / R-008） | 目視 + evidence |

## エッジケース

| EC | 内容 | 期待挙動 |
|----|------|---------|
| EC-1 | HO 対象ファイル（`.claude/commands/ai-loop-workflow.md`）の diff が Human 未承認のまま残る | T-07 未完了として V-1 を PASS にしない（HO 常時 block と整合） |
| EC-2 | plugin references 側にのみ旧表現が残る（正本更新・sync 漏れ） | TC-11 の dry-run が差分検出 → sync 実行で解消。差分ゼロを最終 evidence に |
| EC-3 | `merge-ready`（小文字）表記が引用・verbatim（ユーザー発言引用等）に残る | 削除しない。TC-12 で「verbatim 引用のため残置」と採否理由を記録 |
| EC-4 | rollout-policy 分離時に安全側不変条件（HO escalate / NO MERGE BY AI / lite AC-8）が欠落 | TC-05 実行時に移設前後で `rg` 突合し欠落ゼロを確認（plan R-4） |
| EC-5 | design-philosophy.md §5 語彙集と新正本の状態語彙定義が二重化 | TC-09 でどちらを実定義とするか確定し、他方を参照化（採否理由 evidence） |
| EC-6 | 外部レビュー実行不可（CLI 不達等） | 「指摘なし」と区別し `unavailable` として理由・代替観点を記録（review-principles §7-ter） |
