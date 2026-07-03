# レビュアー沈黙時のフォールバックとレビュー実施証跡の必須化（正本）

> Issue [#685](https://github.com/s977043/plangate/issues/685)。
> notionnext-blog の直近マージ済み PR 20 件監査で、外部 bot レビュアー
> （gemini-code-assist）の daily quota 切れにより 6 本（30%）が実質
> ノーレビューのままマージされていたことを起点とする。
> 「quota 切れ時は Codex + orchestrator を代替ペアにする」運用方針は
> 既にあったが、代替レビューを実施しても PR 上に痕跡が残らないため、
> 事後監査で「レビューされたのか不明」な状態になっていた。

## 0. 位置づけ（#667 との違い）

| Issue | 扱う軸 | 対象 |
|-------|-------|------|
| [#667](https://github.com/s977043/plangate/issues/667)（review-feedback-loop） | **指摘の還元**（PR で受けた指摘を事前チェックへフィードバックする閉ループ） | `docs/workflows/ai-loop/review-feedback-loop.md` |
| **本 issue（#685）** | **レビューが実施されたことの保証**（レビュアーが応答したか・どの系統が応答したかの証跡） | 本ドキュメント |

両者は独立した軸である。#667 は「指摘の質をどう改善するか」、本 issue は
「そもそもレビューが行われた事実をどう保証し、無レビューマージを構造的に
防ぐか」を扱う。本ドキュメントは #667 のフローを変更しない。

## 1. 既存正本との関係（拡張であり重複ではない）

本仕様は [`external-reviewer-interface.md`](./external-reviewer-interface.md)
§10（外部レビュー実行不可時の記録規約 / #463）を**土台として拡張**する。

| 既存正本（§10 / #463） | 定義済みの範囲 | 本ドキュメントが追加する範囲 |
|------------------------|---------------|------------------------------|
| `review_status: executed / unavailable` の記録 | **1 レビューア**が実行できたか否かの記録形式（理由・代替観点・未充足リスク） | **複数レビュアー系統**にまたがる「gate 通過に必要な最低本数」の定義（§2） |
| `unavailable` 時の verdict（WARN / FAIL） | 単一レビューアの記録が不完全な場合の判定 | 主レビュアー沈黙時に**自動フォールバック**を発火させる手順（§3） |
| — | — | どの系統も応答しない場合の **無レビューマージ構造的禁止**（§4） |

**差分の要点**: §10 は「1 本のレビューが unavailable だったときの記録の書き方」を
定義済みだが、「unavailable だったときに次に何をするか（フォールバック）」と
「複数レビュアーを前提にした gate 通過条件（最低 N 系統）」は未定義だった。
本ドキュメントはこの 2 点を追加する。§10 の `review_status` /
`unavailable_reason` / `alternative_perspective` / `residual_risk` の
フィールド定義・verdict 判定ロジックは**変更せず再利用**する。

[`review-principles.md`](../../.claude/rules/review-principles.md) §7-bis
（C-2 2 レーン責務契約）・§7-ter（実行不可時の記録参照）も不変。本仕様は
HO（Hardening Override）対象パスである `.claude/rules/*.md` を直接編集
しない。既存正本への反映は §5 の適用スクリプトを通し、Human が適用する。

## 2. Gate 通過条件の定義

レビュー gate（C-2 / V-3、および PR 上の C-4 前提となるレビュー実施確認）の
通過条件を以下のように定義する。

```text
ReviewGatePassed =
  ExecutedReviewerCount >= RequiredReviewerCount
  AND EvidenceRecorded(all executed reviewers)
```

- `RequiredReviewerCount`（最低必要系統数 N）は `.plangate-reviewers.yaml`
  （[external-reviewer-interface.md §2](./external-reviewer-interface.md)）の
  設定値に応じて決まる。既定 `N=1`（単一プロバイダ構成との後方互換）。
  複数プロバイダを設定した場合は運用側が `N` を明示できる（後述 §5 の
  適用スクリプトが `.plangate-reviewers.yaml` に `min_reviewers` フィールドの
  追加提案を含む。schema 側の正式追加は別 PBI）。
- `ExecutedReviewerCount` は `review_status: executed` として evidence が
  記録されたレビュアー系統数（§10 の記録形式に従う）。フォールバック経由で
  実施されたレビュー（§3）も `executed` としてカウントする。
- `EvidenceRecorded` は各レビューアについて §10 の必須項目、または
  フォールバック実施時は §3.2 のサマリ記録が存在することを指す。

`ExecutedReviewerCount < RequiredReviewerCount` の場合、gate は **FAIL**
とする（§4 参照）。

## 3. フォールバックパス

### 3.1 発火条件

主レビュアー（`.plangate-reviewers.yaml` の `c2` / `v3` に設定されたプロバイダ）
の呼び出しが以下のいずれかで失敗した場合、フォールバックを発火する。

- quota 超過（レート制限応答・402/429 相当）
- API 不達（タイムアウト・接続エラー）
- CLI 未導入・実行不可（既存 §10 の `unavailable` 条件と同一）

これは §10 の `review_status: unavailable` 判定と同じ検出条件を再利用する
（新しい検出ロジックを追加しない）。

### 3.2 代替レビューア

主レビュアーが沈黙した場合、以下の優先順で代替レビューアへフォールバック
する。

1. `.plangate-reviewers.yaml` に `fallback` として明示設定されたプロバイダ
   （例: Codex）
2. 明示設定がない場合、`orchestrator` エージェント（本リポジトリの
   [`.claude/agents/orchestrator.md`](../../.claude/agents/orchestrator.md)）
   による代替レビュー（既存の「Codex + orchestrator を代替ペアにする」
   運用方針をそのまま踏襲）

代替レビューの実施結果は、**必ず**以下のいずれかに記録する（両方あれば
両方が望ましいが、最低 1 箇所は必須）。

- PR コメント（GitHub 上、`[Fallback Review]` プレフィックス付き）
- `docs/working/TASK-XXXX/review-external.md`（evidence-ledger。§10 の
  記録形式に `fallback_from: <元プロバイダ名>` フィールドを追加）

### 3.3 記録必須項目（フォールバック実施時）

§10 の必須項目に加え、以下を記録する。

| 項目 | 説明 |
|------|------|
| `fallback_from` | 沈黙した主レビュアーのプロバイダ名 |
| `fallback_to` | 実施した代替レビュアーのプロバイダ名 / エージェント名 |
| `fallback_reason` | §10 の `実行不可の理由` と同一（quota 超過等） |
| `fallback_result_location` | PR コメント URL または evidence-ledger パス |

## 4. 無レビューマージの構造的禁止

主レビュアー・フォールバック双方が応答しない場合（`ExecutedReviewerCount = 0`）、
レビュー gate は **FAIL** とし、以下を満たさない限り C-4（PR マージ）へ
進めない。

- FAIL 状態は `review-external.md` のフロントマター `verdict: FAIL` として
  記録する（§10 の既存ルールと同一の判定値を再利用）。
- FAIL の解消は「後追いで最低 1 系統のレビューを実施し evidence を記録する」
  ことでのみ行う。人間の目視確認のみでの gate 通過は認めない（無レビュー
  マージの温床になるため）。
- 緊急時（インシデント対応等）で gate を bypass する場合は、
  [`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
  の Human-owned 承認境界に従い、人間が明示的に bypass 理由を記録した上で
  行う（本仕様が新設する bypass 経路ではなく、既存の C-3/C-4 承認境界の
  枠内で運用する）。

## 5. 既存正本への反映（Human 適用）

本ドキュメントは仕様のみを定義する非 HO ファイルである。以下の既存正本への
反映は [`scripts/apply-reviewer-silence-gate.sh`](../../scripts/apply-reviewer-silence-gate.sh)
が差分を提示し、[`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
に従い **Human が `--apply` で実行**する（AI は dry-run 提示のみ）。

| 反映先 | 反映内容 |
|--------|---------|
| [`review-principles.md`](../../.claude/rules/review-principles.md) | §7-ter への「レビュアー沈黙時のフォールバック（#685）」参照追記 |
| [`gate-checks.md`](./gate-checks.md) | C-3 承認記録の任意フィールドとして `review_gate_passed` の参照追記（本仕様 §2 の定義を指す） |

いずれも **追記のみ**（既存文言の削除・意味変更は行わない）。

## 6. 監査・events 連携（将来拡張）

[external-reviewer-interface.md §3.3 / §10](./external-reviewer-interface.md)
の events 最小フィールドを拡張する形で、将来的に以下を想定する（実装は
本 PBI 範囲外、参照定義のみ）。

```json
{ "review_id": "R-NNN", "lane": "design|codebase|security",
  "review_status": "executed|unavailable|fallback",
  "fallback_from": "<string|null>",
  "fallback_to": "<string|null>",
  "gate_passed": true,
  "executed_reviewer_count": 1,
  "required_reviewer_count": 1 }
```

`review_status` に既存の `executed` / `unavailable` に加え `fallback` を
追加した点が §10 からの唯一の語彙拡張（`fallback` は `executed` の下位分類
として扱ってよく、gate 判定上は `executed` 同等にカウントする、§2 参照）。

## 7. 関連

- Issue [#685](https://github.com/s977043/plangate/issues/685)
- [`external-reviewer-interface.md`](./external-reviewer-interface.md) §10 — 実行不可時の記録規約（正本・本仕様が拡張する土台）
- [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md) §7-bis / §7-ter
- [`docs/workflows/ai-loop/review-feedback-loop.md`](../workflows/ai-loop/review-feedback-loop.md) — 指摘の還元（#667、本仕様とは別軸）
- [`gate-checks.md`](./gate-checks.md) — C-3 承認記録の拡張仕様
- [`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md) — HO 適用は Human-owned
- [`scripts/apply-reviewer-silence-gate.sh`](../../scripts/apply-reviewer-silence-gate.sh) — 適用スクリプト（dry-run 既定・AI 実行禁止）
