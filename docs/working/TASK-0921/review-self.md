# C-1 SELF REVIEW — TASK-0921

Review date: 2026-08-05

## Verdict

`NEEDS_REVISION_BEFORE_C3`

`#914` 完了後のscope、2層能力モデル、early exit、negative control、rollbackは具体化した。C-3前にruntime inventoryとtop-level trap競合監査、独立C-2が必要。

## Review Matrix

| View | Verdict | Note |
|---|---|---|
| Issue / pbi alignment | PASS | layer A/B、rc 1/2、harness不変を反映 |
| Dependency | PASS | #914 closedを確認 |
| Testability | PASS | TC-01〜18、M-01〜06 |
| Early exit coverage | PASS conditionally | standalone-only signal0 trap。競合監査必須 |
| Source safety | PASS conditionally | harnessではtrap/counter reset/exit禁止 |
| Dynamic all-file evidence | PASS | capability marker + target force-fail probe |
| Count drift | PASS | runtime inventory、hardcode禁止 |
| Cleanup safety | NEEDS_REVISION | helper移行前に全existing cleanup/trapのinventoryが必要 |
| Broad diff reviewability | NEEDS_REVISION | 10〜15 files/batchとcheckpointはあるが実countで再計画 |
| C-2 independence | BLOCKED | shell/test/workflow lanes未実施 |

## Major Findings

### C1-M1: Trap compatibility is an unverified load-bearing assumption

共有exit trapはearly exitを覆う一方、既存extrasのtop-level trapまたはsubprocess trapと競合する可能性がある。全file inventoryでtop-level `trap ... 0/EXIT` を列挙し、競合0または合成可能を実証するまで案Cを確定しない。

### C1-M2: Helper loading modifies runner boundary

`tests/run-tests.sh`の集計ロジックは変えないが、helper source追加は全extrasの実行前提になる。helper不在・syntax error・unexpected global mutationをRED testし、runnerの変更行をsource1箇所に限定する。

### C1-M3: Probe environment is a new test interface

force-fail probeは全file動的検査に有効だが、通常運用で誤設定された場合にtestが赤になる。fail-safeでありsecurity bypassではないが、internal-only、target必須、README非公開またはtest section限定をC-2で判断する。

## Minor Findings

- capability markerとinit argumentの二重記述はdriftしうる。markerからinitを導出できないshell構造のため、TC-10で一致を強制する設計は妥当
- ta-26移行は最も重いため最後にするが、legacy adapterのまま残す選択肢もC-2で比較すべき
- final rc precedenceはoriginal rcを保持する設計。元rcとfailの両方をsummaryへ記録し、fail情報を失わないこと

## Scope Check

- test content redesign: excluded
- runner subprocess redesign: excluded
- framework dependency: excluded
- README inventory cleanup: excluded
- #994 repair: separate issue

## C-3 Readiness

- [ ] runtime inventory evidence
- [ ] top-level trap / cleanup conflict table
- [ ] current baseline full suite
- [ ] C-2 POSIX shell review
- [ ] C-2 mutation/test architecture review
- [ ] C-2 PlanGate source-boundary review
- [ ] Human choice: shared trap vs explicit finalizer
