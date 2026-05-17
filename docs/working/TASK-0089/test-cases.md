# テストケース — TASK-0089 / #227
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | IF doc に version/reviewers/c2/v3/provider/command/output_mapping 記載 | 構造突合 |
| T2 | AC2 | "river-reviewer Finding → PlanGate" 表 + Severity マッピング表(critical/major/minor/info) | 構造突合 |
| T3 | AC3 | 責務分担表に C-1/C-2/V-1/V-3 行 + PlanGate/river-reviewer 列 | 構造突合 |
| T4 | AC4 | "3 つの導入パターン" に PlanGate だけ/river-reviewer だけ/両方 | 構造突合 |
| T5 | AC5 | schema JSON 妥当 + example が schema validate 通過 | 機械検証 |
| T6 | AC6 | review-principles に external-reviewer-interface 参照あり & §7-bis 契約文言不変 | 構造突合 |
## Edge
- E1: .plangate-reviewers.example.yaml は非有効命名（.example.yaml）
- E2: 未知 severity の安全側 major 丸めが明記
