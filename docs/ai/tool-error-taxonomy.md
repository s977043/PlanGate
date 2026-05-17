# Tool Error Taxonomy and Recovery Policy（正本）

> PlanGate runtime / tool 実行におけるツール失敗の **分類・severity・回復
> ポリシー・計測** の正本。Model Profile v2 の `retry_strategy` と Metrics v1
> の `tool_error` event に接続する。
> 関連: [#203](https://github.com/s977043/plangate/issues/203)（PBI-HI-010）/
> TASK-0093 / [`core-contract.md`](./core-contract.md) §5 Error taxonomy /
> [`model-profiles.md`](./model-profiles.md) / [`metrics.md`](./metrics.md) /
> [`../../schemas/plangate-event.schema.json`](../../schemas/plangate-event.schema.json) /
> [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md)

## 1. 目的

ツール失敗を「一時的失敗」で片付けず、**分類 → 回復 → 計測** できるように
する。失敗種別ごとに適切な回復方法（retry / 文脈補完 / 停止 / backlog 還流）
が異なるため、category を正規化し recovery policy を固定する。

> 本正本は [core-contract.md](./core-contract.md) §5 の最小 Error taxonomy
> （`delegation_unavailable`）を **一元化**する（core-contract は本正本を
> 参照。重複定義しない）。C-3 / C-4 ゲートは緩和しない（Non-goal）。

## 2. Error categories（一覧）

| Category | 定義 / 例 | severity | classification |
|----------|----------|----------|----------------|
| `edit_patch_failure` | patch が適用できない（hunk 不一致 等）| minor | **retryable** |
| `edit_replace_failure` | string replace 対象が見つからない / 非一意 | minor | **retryable** |
| `test_command_failure` | test / lint / build が失敗 | major | **soft_warning**（実装欠陥なら blocker）|
| `provider_timeout` | provider / CLI が timeout | minor | **retryable** |
| `schema_validation_failure` | artifact / event schema 違反 | major | **release_blocker** |
| `missing_context` | 必要な plan / test-cases / c3.json が無い | major | **release_blocker** |
| `permission_denied` | file / command / connector 権限不足 | major | **soft_warning**（人間判断要）|
| `stale_contract` | stale plan / stale c3 / stale plan_hash | critical | **release_blocker** |
| `delegation_unavailable` | サブエージェント起動不可、または判定不能 | minor | **retryable\***（\*retry ではなく topology fallback: direct-implementer-mode へ自動移行。回数 retry はしない）|
| `unknown_tool_error` | 未分類エラー | major | **soft_warning** → backlog 還流（§5）|

> severity は [review-principles.md](../../.claude/rules/review-principles.md) §3
> の 4 段階に整合。classification は回復戦略の決定軸（§3）。

## 3. Recovery policy（category 別）

| Category | recovery policy |
|----------|-----------------|
| `edit_patch_failure` | 最新内容を再読込し patch 再生成 → 最大 N 回 retry（`retry_strategy`）。N 超過で soft_warning 化し人間へ |
| `edit_replace_failure` | 対象の一意化（文脈拡張）後 retry。非一意が解消不能なら停止し人間確認 |
| `test_command_failure` | 失敗ログを読み原因修正 → 再実行。実装欠陥起因なら fix loop（V-1）へ。回数上限超過は EHS-3 escalation |
| `provider_timeout` | backoff 付き retry（`retry_strategy` の max_retries / backoff）。上限超過で soft_warning、別 provider/profile 検討は人間判断 |
| `schema_validation_failure` | **retry しない**。artifact/event を schema 準拠に修正してから再実行（release blocker）|
| `missing_context` | **retry しない**。plan/test-cases/c3.json を生成・取得（正規フロー）後に再開（release blocker）|
| `permission_denied` | **retry しない**。Human-owned 操作（[responsibility-classes.md](../../.claude/rules/responsibility-classes.md)）。人間へ escalate |
| `stale_contract` | **retry しない**。再承認（c3.json plan_hash 更新）または revert（EH-3）。critical |
| `delegation_unavailable` | exec router が direct-implementer-mode へ自動移行（人間介入不要・正規フロー、core-contract §5）|
| `unknown_tool_error` | 1 回のみ保守的 retry 可。解消しなければ §5 で backlog 還流（分類拡充）|

## 4. release blocker / soft warning / retryable の境界

| classification | 意味 | フロー影響 |
|----------------|------|-----------|
| **retryable** | 自動 retry で回復見込みあり | `retry_strategy` に従い自動再試行。上限超過で soft_warning へ降格 |
| **soft_warning** | 自動回復不可だが即時停止不要 | 記録し継続。人間が後追い確認（handoff 既知課題へ）|
| **release_blocker** | 続行不可・成果物不整合リスク | 即停止。修正後に再開（C-3/C-4 は緩和しない）|

- retryable が `retry_strategy.max_retries` を超過したら **soft_warning** に
  降格して記録（無限 retry 禁止）。
- **軸の区別（重要）**: 本 taxonomy の `release_blocker` は *tool error
  category* の分類。[eval-runner.md](./eval-runner.md) の
  `release_blocker_violations`（[eval-result.schema.json](../../schemas/eval-result.schema.json)
  enum: `scope_discipline`/`approval_discipline`/`verification_honesty`/
  `format_adherence`）は *評価 aspect* の別軸であり、**同一視しない**
  （tool error category 名を eval-result にそのまま入れない）。両者の対応:

  | tool error category（本 §2）| 概念的に対応する eval aspect |
  |------------------------------|----------------------------|
  | `schema_validation_failure` | `format_adherence`（成果物整形・schema 準拠）|
  | `missing_context` | `approval_discipline`（plan/c3 前提欠落）|
  | `stale_contract` | `approval_discipline`（stale c3/plan_hash）|

  対応は *概念マッピング* であり機械的等価ではない（記録は別 event:
  tool_error は events、release_blocker_violations は eval-result）。

## 5. Metrics 記録方針（Metrics v1 接続）

ツール失敗は `tool_error` event として記録する（[metrics.md](./metrics.md)）。
[`schemas/plangate-event.schema.json`](../../schemas/plangate-event.schema.json)
に **additive**（schema_version 1.1）で追加:

- `event: "tool_error"`（enum 追加）
- `tool_error_category`（本 §2 の enum）
- 既存 `tool_name` / `phase` / `mode` を併用

Privacy: [metrics-privacy.md](./metrics-privacy.md) §4 に従い、message /
stack trace / command output は emit しない（category と tool_name のみ）。

```json
{"schema_version":"1.1","ts":"2026-05-17T00:00:00Z","task_id":"TASK-XXXX",
 "event":"tool_error","tool_error_category":"edit_patch_failure",
 "tool_name":"Edit","phase":"D"}
```

## 6. unknown error の backlog 還流（運用）

`unknown_tool_error` は **harness improvement backlog へ戻す**:

1. `tool_error_category=unknown_tool_error` で event 記録（message なし）。
2. handoff.md「既知課題」に「未分類ツールエラー（再現条件の範囲で）」を記載。
3. retrospective / [#200 Reporting](./harness-improvement-roadmap.md) で集計し、
   頻出パターンを §2 の新規 category として **EPIC #193 配下の PBI 化**。
4. 新 category 追加は本正本の改訂（versioning は
   [versioning-stability-policy.md](./versioning-stability-policy.md) §2.1
   enum 追加＝ minor、必須化は major）。

これにより未分類が放置されず分類体系が継続改善される。

## 7. Model Profile v2 接続

各 retryable category の retry は Model Profile の `retry_strategy`
（[model-profiles.md](./model-profiles.md) §retry_strategy 接続）に従う:

- `max_retries`: retryable の自動再試行上限（超過で soft_warning 降格）
- `backoff`: `provider_timeout` 等の待機方針
- profile 未定義時は保守的既定（max_retries=1）。

> retry_strategy の値域・既定の正本は model-profiles.md。本正本は
> 「どの category が retry 対象か」を定義し、回数/待機は profile に委譲。

## 8. Non-goals

- provider runtime の全面実装 / 全 provider のエラー形式対応
- 自動修復の完全実装 / 外部監視システム連携
- C-3 / C-4 ゲートの緩和

## 9. 関連

- [`core-contract.md`](./core-contract.md) §5 — delegation_unavailable 最小定義（本正本へ集約）
- [`model-profiles.md`](./model-profiles.md) — retry_strategy 値域
- [`metrics.md`](./metrics.md) — tool_error event 収集
- [`schemas/plangate-event.schema.json`](../../schemas/plangate-event.schema.json) — event schema（additive 1.1）
- [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md) §3 — severity 4 段階
- [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md) — backlog 還流先
