# Keep Rate v1（正本）

> AI が作成・変更した成果物の **残存率**を決定論・軽量に測る正本。
> 「生成された作業」ではなく「採用され、残った作業」を改善対象にする。
> 関連: [#198](https://github.com/s977043/plangate/issues/198)（PBI-HI-004）/
> TASK-0096 / [`metrics.md`](./metrics.md)（PBI-HI-001 接続）/
> [`../../schemas/keep-rate-result.schema.json`](../../schemas/keep-rate-result.schema.json) /
> [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md)

## 1. 目的と原則

eval は scope/approval/AC/verification/format を評価できるが、AI 生成物が
**PR merge 後・後続 PBI でどれだけ残ったか**は測れていない。Keep Rate v1 は
それを軽量に可視化する。

- **advisory のみ**: release blocker としては使わない（#198 Non-goal・
  [responsibility-classes.md](../../.claude/rules/responsibility-classes.md)
  の承認境界は不変）。
- **決定論・軽量**: GitHub 全履歴の完全解析・LLM judge 満足度判定・外部
  分析基盤は行わない（Non-goal）。ローカル git + TASK artifact のみ。
- **算出不能は `unknown`**（0 ではない）。unknown を劣化と誤読しない。

## 2. 4 メトリクス

| Metric | 定義 | v1 算出方法（軽量近似）|
|--------|------|----------------------|
| **Code Keep Rate** | AI が変更したコードが一定後も残る割合 | `git log --all --grep=<TASK>` の commit が触れた *コードファイル*（`docs/working/` 等は除外）のうち HEAD で存続する割合。commit 無し → unknown |
| **Plan Keep Rate** | C-3 承認 plan の todo/方針が handoff まで維持された割合 | `todo.md` の `- [x]` / 全チェック項目比率（plan_hash 一致前提）。todo/c3/handoff 欠 → unknown |
| **Acceptance Keep Rate** | `test-cases.md` の受入条件が V-1/V-4 まで有効だった割合 | `handoff.md` §1 AC 表の PASS / (PASS+FAIL+WARN)。AC 行無し → unknown |
| **Handoff Keep Rate** | `handoff.md` の既知課題/V2/妥協点が後続 PBI で参照された割合 | §3 参照（後続 TASK の plan/handoff/pbi-input が当該 TASK を参照していれば `referenced`+件数。未参照/未算出 → unknown）|

> v1 はすべて **近似**。厳密な行 blame・意味的参照判定は v2 以降（Non-goal）。

## 3. Handoff Keep Rate の定義と算出方針

`handoff.md` の「既知課題 / V2 候補 / 妥協点」が **後続作業に実際に
引き継がれたか**を測る。完全な履歴・意味解析はしない（Non-goal）ため
v1 は以下の軽量方針:

1. 他 `docs/working/TASK-*/`（自身を除く）の `plan.md` / `handoff.md` /
   `pbi-input.md` が当該 `task_id` を **文字列参照**しているか走査。
2. 参照する後続 TASK が 1 件以上 → `value: "referenced"`,
   `referenced_by: <件数>`。
3. 参照ゼロ / 走査不能 → `value: "unknown"`（劣化ではなく「まだ参照が
   観測されていない」。時間経過で再算出する）。
4. 意味的に「V2 候補が実際に着手されたか」までは v1 では判定しない
   （v2 候補: #200 Reporting と連携した参照グラフ。本 PBI Non-goal）。

## 4. 出力

`bin/plangate keep-rate <TASK-XXXX>` で生成:

- `docs/working/TASK-XXXX/keep-rate-result.json`
  （[schema](../../schemas/keep-rate-result.schema.json) 準拠）
- `docs/working/TASK-XXXX/keep-rate-result.md`（人間可読）
- `--no-write` で標準出力のみ

各メトリクスは `{ "value": <0-100 | "unknown" | "referenced">, ... }`。

## 5. metrics（PBI-HI-001）接続方針

- Keep Rate は **独立 artifact**（`keep-rate-result.json`）として保存し、
  [metrics.md](./metrics.md) の events.ndjson とは **別系統**（event schema
  は変更しない＝既存 metrics を破壊しない）。
- `metrics report` 運用時に keep-rate-result.json を **任意の補助入力**
  として併読する方針（集計は #200 Reporting & Retrospective で統合）。
- Privacy: keep-rate-result は file path（リポジトリ相対・公開対象）と
  集計値のみ。message / stack / 個人情報は含めない
  （[metrics-privacy.md](./metrics-privacy.md) §3 準拠）。
- 将来 event 化する場合も additive（本 PBI は接続方針の文書化まで）。

## 6. 運用手順

1. PBI 完了（handoff 発行）後または後続スプリント開始時に実行:
   `sh bin/plangate keep-rate TASK-XXXX`
2. `unknown` は「測定不能/未観測」であり劣化ではない。Code/Plan が低い
   場合のみ retrospective で要因を確認（advisory）。
3. Handoff Keep Rate は時間経過で再算出（後続参照が増えるため）。
4. **ゲート判定に使わない**（C-3/C-4/V-1 の合否に影響させない）。

## 7. Non-goals

- 外部分析基盤の構築 / GitHub 全履歴の完全解析
- LLM judge による満足度判定 / Dynamic Context Engine 実装
- release blocker としての強制利用

## 8. 関連

- [`metrics.md`](./metrics.md) — PBI-HI-001 Metrics v1（別系統・接続方針 §5）
- [`schemas/keep-rate-result.schema.json`](../../schemas/keep-rate-result.schema.json)
- [`metrics-privacy.md`](./metrics-privacy.md) §3 — 公開可否
- [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md) — EPIC #193 / #200 連携
