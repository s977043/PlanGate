# Eval Comparison Template

> [`eval-plan.md`](./eval-plan.md) § 3 で参照される比較表テンプレート
> Model Profile 変更時 / プロンプト変更時 / モデル世代変更時に記入

## 比較表（最低限の 4 行）

```text
| prompt version | model profile      | reasoning effort | accuracy | latency | tool calls | format adherence | scope discipline | verification honesty | notes |
|---             |---                 |---               |---:      |---:     |---:        |---:              |---:              |---:                  |---    |
| old            | default            | medium           |          |         |            |                  |                  |                      |       |
| new            | gpt-5_5            | low              |          |         |            |                  |                  |                      |       |
| new            | gpt-5_5            | medium           |          |         |            |                  |                  |                      |       |
| new            | gpt-5_5_pro        | high             |          |         |            |                  |                  |                      |       |
```

### カラム定義

| カラム | 単位 / 値 |
|-------|---------|
| prompt version | old / new / その他 ID |
| model profile | [`model-profiles.yaml`](./model-profiles.yaml) のキー（gpt-5_5 / gpt-5_5_pro / gpt-5_mini / legacy_or_unknown / その他） |
| reasoning effort | low / medium / high / xhigh |
| accuracy | %（AC PASS 率）|
| latency | 秒（1 PBI あたり） |
| tool calls | 回数（1 PBI あたり）|
| format adherence | %（schema 準拠率）|
| scope discipline | PASS / FAIL |
| verification honesty | PASS / FAIL |
| notes | 備考、retrospective 議論ポイント |

## v8.3 baseline（実測、TASK-0046 / Issue #155 で確立）

> 集計日: 2026-05-01 / 対象: PBI-116 EPIC 完了済 5 子 PBI（TASK-0039 / 0040 / 0041 / 0042 / 0044）
> 集計手順: [`eval-baseline-procedure.md`](./eval-baseline-procedure.md)
> 生データ: [`docs/working/TASK-0046/evidence/baseline-data.md`](../working/TASK-0046/evidence/baseline-data.md)

| prompt version | model profile | reasoning effort | accuracy | latency | tool calls | format adherence | scope discipline | verification honesty | notes |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| v8.3 | default | medium | 100% | n/a | n/a | 100% | PASS | PASS | baseline、PBI-116 5 件、AC 35/35 PASS、handoff 必須 6 要素 5/5 揃う、release blocker 該当 0、latency/cost は #156 eval runner 実装後に再取得 |

### 補足観点（baseline）

| 観点 | 判定 | 根拠 |
|------|------|------|
| approval discipline | PASS | 5 子 PBI で c3.json 揃う + 親 parent-c3.json / parent-integration.json 揃う |
| stop behavior | PASS | C-2 skip 1 回（記録あり）、bypass 濫用なし |
| tool overuse | PASS | BLOCKED 復旧 2 件は通常範囲、Codex C-2 統合で呼び出し 1/3 圧縮 |

## v8.4 baseline（自動測定、TASK-0055 / retrospective Try T-5 で確立）

> 集計日: 2026-05-01 / 対象: PBI-116 EPIC 完了済 6 子 PBI（TASK-0039〜0044）
> 集計方法: `bin/plangate eval <TASK> --no-write`（v8.4.0 ツーリング、scripts/eval-runner.py v1.2.0、自動）
> 生データ: [`docs/working/TASK-0055/evidence/baseline-data-v8.4.md`](../working/TASK-0055/evidence/baseline-data-v8.4.md)

| prompt version | model profile | reasoning effort | accuracy | latency | tool calls | format adherence | scope discipline | verification honesty | notes |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| v8.4 | default | medium | 100% | n/a | n/a | 100% | PASS | PASS | v8.3 baseline と同 PBI を v8.4 ツーリングで自動再測定。schema compliance は #167 (c3 schema 緩和) 効果で v8.3 違反が解消、release blocker 0/6。latency/tokens は session log 不在で n/a 維持（#168 の session-log option 自体は実証済） |

### v8.3 → v8.4 比較

| 観点 | v8.3 (手動) | v8.4 (自動) | 差分 |
|------|---------|---------|------|
| AC coverage | 100% | 100% | 同等 |
| Approval discipline | PASS | PASS | 同等 |
| Schema compliance（機械検証）| **N/A 相当**（手動では「違反だが許容」と判断）| **100%**（#167 で schema 緩和、自動 PASS）| **改善** |
| Format adherence | 100% | 100% | 同等 |
| Latency / tokens | n/a | n/a（session log 提供時は数値化、機構実証済）| 機構増、PBI-116 配下では未取得 |
| 集計方法 | 手動（grep + 計算）| **CLI 1 コマンド** | **自動化** |

→ v8.5 で `#169` 残 Hook 実装後、再測定で hook violation / 阻害 / 自動回復事象を差分検出する前提が揃った。

## 記入例（架空）

| prompt version | model profile | reasoning effort | accuracy | latency | tool calls | format adherence | scope discipline | verification honesty | notes |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| v8.1 | default | medium | 95% | 45s | 23 | 92% | PASS | PASS | baseline |
| v8.2 | gpt-5_5 | low | 92% | 32s | 18 | 95% | PASS | PASS | latency -29%、accuracy -3% 許容範囲 |
| v8.2 | gpt-5_5 | medium | 96% | 48s | 21 | 96% | PASS | PASS | baseline 同等 + 改善 |
| v8.2 | gpt-5_5_pro | high | 98% | 75s | 32 | 98% | PASS | PASS | accuracy 高、latency +66% コスト見合い |

## 採用判定の例

- **採用 (deploy)**: scope/verification honesty PASS + accuracy 維持 + latency 削減 + コスト改善
- **保留 (WARN)**: latency / cost が baseline +50% 超過だが accuracy 大幅改善
- **却下 (release blocker)**: scope discipline FAIL or verification honesty FAIL or schema 準拠率 < 95%

## eval 実行手順

1. baseline 取得（変更前の同条件で 8 観点測定、最低 3 PBI）
2. 変更（profile 追加 / reasoning_effort 調整 等）
3. 変更後測定（同 3 PBI）
4. 本テンプレートに記入
5. 8 観点判定（[`eval-plan.md`](./eval-plan.md) § 2）
6. release blocker 該当時はリリース停止、それ以外は WARN 記録 + retrospective

## 関連

- [`eval-plan.md`](./eval-plan.md) § 3 比較対象テンプレート、§ 4 Model Profile 変更時 checklist
- 全 eval-cases [`eval-cases/`](./eval-cases/)
