# C-1 SELF REVIEW — TASK-1005

Review date: 2026-08-05

## Verdict

`NEEDS_REVISION_BEFORE_C3`

Plan package の目的・順序・Human boundary・negative-control 契約は具体化できている。ただし、現行 governance 正本の実在パス、既存 lifecycle label との衝突、milestone 9 の Human commitment 6〜8件が未確定である。これらは実装詳細ではなく運用正本へ影響するため、C-3 前に解消する。

## Review Summary

| 観点 | 判定 | 根拠 / Action |
|---|---|---|
| Goal / completion boundary | PASS | Admission contract + RR1 + 2-cycle review。個別fix完了とTASK-1005完了を分離 |
| AC testability | PASS | TC-01〜TC-21へ mapping |
| Sequence / dependencies | PASS | #921 → negative controls >=2 → #978。foundation全件待ちを回避 |
| Human approval boundary | PASS | C-3/C-4/merge/HO/commitmentをHuman-ownedに固定 |
| Security / fail-closed | PASS | #978 bundled fallback を warning-only でなく escalation |
| Test detection power | PASS | 修正前/変異を落とす証拠を必須化 |
| Scope control | PASS | #906/#916、大型構想裁定、bulk mutationを除外 |
| Existing governance alignment | NEEDS_REVISION | issue governance 正本の実在パスと既存状態モデルをT-01で確認 |
| Milestone capacity | NEEDS_REVISION | milestone 9の15件からHumanが6〜8件を確定 |
| Independent C-2 | BLOCKED | 別 reviewer lane 未実施 |

## Strong Points

1. **Root cause を intake volume ではなく admission control 欠如として扱った**
   - finding を殺さず、実行 commitment だけを制御できる
2. **#921 を load-bearing dependency として明示した**
   - failure が exit 0 のままでは後続 mutation evidence が成立しない
3. **基盤整備だけで停止しない vertical slice gate を置いた**
   - #921 + 異なる2 negative controls で #978 を開始可能
4. **priority / lifecycle / milestone / completion class を分離した**
   - 1ラベルで複数の意味を背負わせない
5. **部分完了の見かけ上のcloseを防ぐ contract がある**
   - scope split はHuman decisionとtraceを要求

## Findings

### C1-M1: 現行 issue governance 正本のパス未確定

**Severity**: Major

priority label description は `issue-governance.md` を参照しているが、planning session の path 検索では正本を確定できていない。新規文書を作る前に repository tree / references を再検索し、重複正本を避ける必要がある。

**Required action**:

- exact path を特定
- current state / priority / milestone semantics を抽出
- TASK-1005 が amendment か successor か決定

### C1-M2: Lifecycle label の実装方式未確定

**Severity**: Major

`state:discovered` 等を新設するか、既存 label / milestone / project field を使うか未決定。label新設自体より、排他性とpromotion ownerの enforcement が重要。

**Required action**:

- 既存 labels を inventory
- label案、Issue form field案、文書のみ案を比較
- Human C-3 の decision item にする

### C1-M3: milestone 9 の commitment 未確定

**Severity**: Major

RR1候補は7 + reserve 1まで絞ったが、現在milestone 9に置かれた他Issueを外す判断はHuman-owned。Plan packageは候補提示までに留めている。

**Required action**:

- milestone 9全件を一覧化
- blocker / dependency / HO / plan readinessで比較
- target 6, max 8をHumanが確定

### C1-m1: #991 / #970 のPR単位

**Severity**: Minor

同じ sync script を触る可能性があるが、同一ファイルだけでは統合理由にならない。canonical enumeratorを共有しatomic intermediate stateが必要な場合のみ同PRとする。

### C1-m2: 2-cycle の時間境界

**Severity**: Minor

暦週ではなく delivery cycle と定義したが、cycle start/end event を正本ドキュメントで固定する必要がある。

## AC Mapping Review

- AC-01 / 02: Task 1 + TC-01〜07
- AC-03〜06: Task 2 + TC-08〜14
- AC-07 / 08: Task 1 + TC-15〜17
- AC-09: Task 1 + TC-18
- AC-10: Task 4 + TC-19
- AC-11: Task 3 + TC-20
- AC-12: 全Task constraints + TC-21

未マッピング AC はない。

## Scope Bloat Check

- individual test fixes をTASK-1005へ直接実装しない: PASS
- #978に#906/#916を統合しない: PASS
- 48件一括変更をしない: PASS
- GitHub ruleset / HO applyをAIが行わない: PASS
- metrics automationを先行実装しない: PASS

## C-3 Readiness Actions

- [ ] C1-M1 解消
- [ ] C1-M2 をHuman decision tableへ追加
- [ ] C1-M3 のmilestone candidate一覧作成
- [ ] C-2 independent reviews
- [ ] findingsをplan / todo / test-casesへ反映
- [ ] final verdictを `PASS` または `BLOCKED` へ更新
