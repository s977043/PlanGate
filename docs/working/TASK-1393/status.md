# TASK-1393 作業ステータス

> 最終更新: 2026-10-21 18:40
> 現在フェーズ: BLOCKED
> モード: high-risk
> 発行時点 SHA (issued_at_commit): 該当なし（完了資産ではない。plan Revision 2.6 の反映コミットは `03bae6aa`）
>
> 現在フェーズの値域は `INDEX.md` と共通（正本: `.claude/rules/working-context.md`）。

## フェーズ履歴

> 2026-10-21 以前の履歴は本ファイル作成前のため、`INDEX.md` / `decision-log.jsonl` / `review-external.md` の記録から転記した（時刻が記録に無いものは記録上の時刻）。

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| 2026-09-28 22:45 | C-3 Gate | APPROVED（Human、Revision 2.5、`approved_at` 2026-09-28T22:45:37Z、`plan_hash` `799c8526…`） |
| 2026-10-08 00:00 | BLOCKED | #1519 で依存再照合（時刻は記録なし）。dependency-reconciliation.md |
| 2026-10-21 14:50 | C-3 待ち | Human 決定 R-081 / R-082 を Revision 2.6 として確定反映、簡易 C-1 PASS（Unknowns WARN）。**既存 c3.json の `plan_hash` は改訂後 plan（`ec2a0db8358c53f089f652f4671e36c5366dbffa4df5dbf9d6a15129d237ec60`）と一致しない＝Human の再発行待ち** |
| 2026-10-21 18:15 | C-3 | C-3 Gate: APPROVED（Revision 2.6, plan_hash ec2a0db8…） |
| 2026-10-21 18:40 | BLOCKED | exec 前依存（#1391/#1392/#1422 owner, PF-2〜PF-8）未解消 |
| 2026-10-22 10:03 | C-3 待ち | Human 決定 PF-5（R-085〜R-088）を Revision 2.7 として確定反映、簡易 C-1 PASS（Unknowns WARN）。**既存 c3.json の `plan_hash`（`ec2a0db8…`）は改訂後 plan（`404c432a60157932cda967b4c3d90c77979c6d00df874a295828bfd8b0af35b3`）と一致しない＝Human の再発行待ち** |

## C-3 Gate: APPROVED

- 承認: Human（`approvals/c3.json`、`approved_at` 2026-10-21T09:15:23Z = JST 18:15、`source` cli）
- 対象: plan Revision 2.6、`plan_hash` `sha256:ec2a0db8358c53f089f652f4671e36c5366dbffa4df5dbf9d6a15129d237ec60`
- C-3 承認は BLOCKED 解消を意味しない。exec 前依存は下記「残タスク」の BLOCKED 行
- 承認後に出た R-083（major）/ R-084（minor）は plan 本体を変えず exec 時要件として扱う（review-external.md）

## 全体構成（PR 一覧）

| PR | ブランチ | 状態 |
|----|---------|------|
| #1407 | （plan / C-2） | MERGED（2026-09-28） |
| 本 draft PR | docs/1393-pf1-ratchet-1422-ruling | OPEN（draft） |

## 残タスク

- [x] Human が Revision 2.6 の c3.json を再発行（2026-10-21 18:15 JST、APPROVED）
- [ ] **BLOCKED** exec 前依存 — blocker: #1391 / #1392 / #1422 の owner 実装、PF-2〜PF-8 未解消 / owner: 各 issue の owner（担当割り当ては Human） / unblock_condition: owner 実装の完了と PF-2〜PF-8 の解消
- [ ] PF-1〜PF-8（PF-1 は ratchet.py / TA-92 を含む）
- [ ] exec 時要件 R-083: ratchet.py で `pr_convergence.scope` を `changed_paths` × `allowed_scope` から導出し、`test_negative_control_failing_on_baseline_is_inconclusive` を RT-04 の名指し回帰にする
- [ ] exec 時要件 R-084: RT-03 の注入方法（fixture フィールド）と `DecisionInputError` → `ERROR` の明示 assert
- [ ] #1422 B-8 / B-13 の語彙決定（#1391 plan の C-3）— blocker: event 未定義 / owner: #1391 / unblock_condition: #1391 plan の C-3

## 計画からの変更点

- Revision 2.6: PF-1 の移行対象に `scripts/ai-loop-v2/ratchet.py` と TA-92 を追加（R-081）。#1422 B 表に凍結列、B-7 retired、B-4/B-5 の INCONCLUSIVE、B-13 の空集合は PASS でない（R-082）。判定規則は不変
- Revision 2.7（PF-5 Human 決定 2026-10-22）: `MAX_DECISION_EVENT_BYTES` を event 全体に一本化し I-11 に `ENVELOPE_OVERHEAD` を追加（R-085）、定数は新設 `scripts/ai-loop-v2/limits.py`（R-086、exec で作成）、仮値 256/16/256・バイト上限は算出切上げ（R-087）、キー名は #1391 の `artifact_ref` / `verdicts` / `failure_fingerprints`（R-088）。PF-5 は合意済み（残: #1395 budget 確定時の `MAX_INPUT_REFS` 検証）

## V 系ステップ進捗

| ステップ | 結果 |
|---------|------|
| L-0 | — |
| V-1 | — |
| V-2 | — |
| V-3 | — |
| V-4 | — |

## 次の作業（Claude Code プロンプト）

`docs/working/TASK-1393/INDEX.md` と本ファイルを読み、exec 前依存（BLOCKED 行）の解消を確認してから、R-083 / R-084 を含めて`dependency-reconciliation.md` の owner/残差に沿って PF-1〜PF-8 を進める。c3.json は作成・編集しない。
