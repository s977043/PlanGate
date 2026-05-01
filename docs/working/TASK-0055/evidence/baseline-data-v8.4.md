# v8.4 Baseline 集計データ（自動測定）

> 集計日: 2026-05-01
> 集計方法: `bin/plangate eval <TASK-XXXX> --no-write`（v8.4 ツーリング、scripts/eval-runner.py v1.2.0）
> 対象: PBI-116 EPIC 完了済 6 子 PBI（TASK-0039〜0044）
> 比較対象: v8.3 baseline（手動測定、`docs/working/TASK-0046/evidence/baseline-data.md`）

## 集計コマンド

```sh
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0043 TASK-0044; do
  python3 scripts/eval-runner.py $t --no-write
done
```

## 結果（PBI 別）

| TASK | AC coverage | Approval | Format adherence | Schema compliance | Scope | Honesty | Blocker |
|------|------------|----------|------------------|-------------------|-------|---------|---------|
| TASK-0039 | 100.0% (6/6)  | PASS | PASS (6/6 sections) | 100% (1/1 JSON) | PASS | PASS | 0 |
| TASK-0040 | 100.0% (8/8)  | PASS | PASS (6/6 sections) | 100% (1/1 JSON) | PASS | PASS | 0 |
| TASK-0041 | 100.0% (7/7)  | PASS | PASS (6/6 sections) | 100% (1/1 JSON) | PASS | PASS | 0 |
| TASK-0042 | 100.0% (6/6)  | PASS | PASS (6/6 sections) | 100% (1/1 JSON) | PASS | PASS | 0 |
| TASK-0043 | 100.0% (?/?)  | PASS | PASS (6/6 sections) | 100% (1/1 JSON) | PASS | PASS | 0 |
| TASK-0044 | 100.0% (8/8)  | PASS | PASS (6/6 sections) | 100% (1/1 JSON) | PASS | PASS | 0 |

## 集計（v8.4 baseline）

| 観点 | 値 / 判定 | v8.3 baseline との比較 |
|------|---------|--------------------|
| AC coverage（合計）| **100.0%**（6/6 PBI で 100%）| 同等（v8.3: 35/35 = 100%）|
| Approval discipline | **PASS**（6/6 PBI で c3 APPROVED）| 同等 |
| Format adherence | **100%**（6/6 で handoff 6 要素揃い）| 同等 |
| Schema compliance | **100%**（c3.json schema 緩和の効果で全件 PASS）| **改善**（v8.3 では `_review_summary` 等の non-schema field で fail していた、Issue #167 で解消）|
| Scope discipline | **PASS** | 同等 |
| Verification honesty | **PASS** | 同等 |
| Stop behavior | **PASS** | 同等 |
| Tool overuse | **n/a** | 同等（v2 で codex response_item 解析）|
| Latency / Cost | **n/a**（PBI-116 配下に session log 未保存）| 同等（session log fixture では実測値取得実証済、Issue #168）|

## v8.3 → v8.4 で何が変わったか

| 変更 | 効果 |
|------|------|
| Issue #167（c3 schema 緩和）| schema compliance: PASS→PASS だが、**機械検証時の violation が消えた**（手動測定では「違反だが許容」、v8.4 自動では「PASS」と一貫）|
| Issue #156（eval runner 実装）| 集計が **手動 → CLI 1 コマンド**、再現性 + 自動化 |
| Issue #168（codex log parser）| session log 提供時 **latency / tokens 数値化**（PBI-116 配下では log 不在で n/a 維持）|

## 結論

- **数値変動はない**（PBI 自体は変わっていない）
- **ツーリングの reliability** が実証された：v8.4 自動測定は v8.3 手動測定と一貫した結果
- **schema compliance は v8.4 で違反 0**（#167 効果）
- v8.5 で `#169` 残 Hook 実装が走った後、再測定で latency や hook violation の差分検出が可能になる前提が揃った

## release blocker 該当

**0 件**（全 6 PBI で release blocker 違反なし）。
