# Handoff Package — TASK-0032

> WF-05 Verify & Handoff の必須出力。Rule 5 遵守。
> 配置: `docs/working/TASK-0032/handoff.md`

## メタ情報

```yaml
task: TASK-0032
related_issue: https://github.com/s977043/plangate/issues/57
author: implementation-agent（qa-reviewer 実施前）
issued_at: 2026-04-26
v1_release: pending（PR マージ後に更新）
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: high-risk 以上で Design Gate なしに実装へ進めない | PASS | `completion-gate.md` 条件 1 に「Mode が high-risk 以上かつ Design Gate を通過していない場合 → BLOCKED」と明記 |
| AC-2: critical で rollback plan なしに完了できない | PASS | `completion-gate.md` 条件 5 に「critical モードでは rollback plan の存在も必須」、Mode 別適用マトリクスで `critical` 行の Rollback Plan が **必須** |
| AC-3: TDD 必須モードで failing test evidence がない場合にブロック | PASS | `completion-gate.md` 条件 2 に「Mode が high-risk 以上かつ Evidence Ledger に type:"test" の証拠がない場合 → BLOCKED」「failing test (exitCode=1) の記録が必須」と明記 |
| AC-4: Review Gate で critical finding がある場合に Completion Gate が失敗する | PASS | `completion-gate.md` 条件 3 に「severity=critical の finding が 1 件以上ある場合 → BLOCKED（全モード）」と明記。`review-gate.md` との参照関係も記述 |
| AC-5: Evidence Ledger なしに Completion Gate が passed にならない | PASS | `completion-gate.md` 条件 4 に Evidence Ledger の 3 ブロック条件（status failed/unknown、missingEvidence、Ledger 不存在）を明記 |
| AC-6: 軽微修正では Design/TDD/Review を過剰要求しない | PASS | `mode-classification.md` の Gate 適用マトリクスで `ultra-light` / `light` の Design Gate・TDD Gate・Review Gate が `-`（スキップ）になっている |

**総合**: `6/6 基準 PASS`

**FAIL / WARN の扱い**: 全基準 PASS のため該当なし

> 注: acceptance-tester による正式な V-1 検査は PR マージ前に実施予定。本判定は実装エージェントによる自己確認。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| Completion Gate の判定が Markdown 定義のみで CI フックが存在しない | minor | accepted（V2 へ） | Yes |
| `/pg-verify` コマンドの出力形式と completion-gate.md の JSON 形式の同期を手動で維持する必要がある | minor | accepted | Yes |

**Critical 課題の対応**: Critical 課題なし

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue（あれば） |
|--------|------|----------|-----------------|
| CI フック自動化（GitHub Actions / pre-commit フック） | V1 は Markdown 定義のみ。機械的な強制は V2 以降で実装 | High | 未発行 |
| `requiresUserApproval` の三値化（true/false/conditional） | 現在は boolean。`high-risk` では条件付き承認を表現できない | Medium | 未発行 |
| TypeScript / JSON スキーマ実装 | 現在は Markdown 定義のみ。型安全な Gate Policy 定義は V2 以降 | Medium | 未発行 |
| Security Gate の追加 | セキュリティ専門の Gate が存在しない。現在は Review Gate の観点 3 として包含 | Low | 未発行 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| Markdown 定義のみで 4 Gate システムを完成させる | CI フックで機械的にブロック | 工数・複雑度が大きく増加する。V1 は定義を固めることを優先し、自動化は V2 へ先送り |
| Completion Gate を独立ファイルとして定義 | 既存の evidence-ledger.md に統合 | 単一責務の原則（Rule 3 相当）に従い、独立したルールファイルとして管理することで参照しやすくする |
| `full` ラベルは使わず `high-risk` に統一 | 並行して `full` / `high-risk` 両方をサポート | TASK-0029 でリネーム済み。二重定義は混乱を招くため廃止 |

## 5. 引き継ぎ文書

### 概要

TASK-0032 は PlanGate 開発統制 OS の Phase 2 として、4 Gate システム（Design Gate / TDD Gate / Review Gate / Completion Gate）を定義した。Phase A（TASK-0032 の前半: 別ブランチで実装済み）で Design Gate・TDD Gate・Review Gate の個別ルールと Skill を定義し、Phase B（本ブランチ）で Completion Gate による統合と Mode 分類マトリクスへの Gate 適用表追加を完了させた。

現在 `feature/task-0032-gate-system-completion` ブランチに 2 つの Phase A ブランチ（`feature/task-0032-gate-system-design` と `feature/task-0032-gate-system-tdd-review`）をマージし、Phase B の 2 ファイル（`completion-gate.md` / `mode-classification.md` 更新）と Working Context 7 ファイルを追加した状態。PR 作成・C-4 レビュー待ち。

### 触れないでほしいファイル

- `plugin/plangate/rules/design-gate.md`: Phase A の成果物。変更すると completion-gate.md との参照整合が崩れる
- `plugin/plangate/rules/review-gate.md`: Phase A の成果物。Severity 定義と Completion Gate ブロック条件が連携している
- `plugin/plangate/rules/evidence-ledger.md`: TASK-0030 の成果物。Completion Gate の条件 4 の正本として依存している

### 次に手を入れるなら

- CI フック実装（V2）: `.claude/settings.json` の hooks セクションに completion-gate のチェックを追加
- `/pg-verify` コマンドの出力形式を `completion-gate.md` の JSON 形式と同期確認
- `requiresUserApproval` の三値化に対応した GatePolicy 定義の拡張

### 参照リンク

- 親 PBI: [#57](https://github.com/s977043/plangate/issues/57)
- plan.md: `docs/working/TASK-0032/plan.md`
- current-state.md: `docs/working/TASK-0032/current-state.md`
- 関連ルール: `plugin/plangate/rules/completion-gate.md`
- 関連ルール: `plugin/plangate/rules/mode-classification.md`

## 6. テスト結果サマリ

> acceptance-tester による V-1 受け入れ検査は PR マージ前に実施予定。

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| 文書確認（TC-01〜06） | 6 | 6（実装エージェント自己確認） | 0 | 6/6 AC |
| markdownlint | 自動（CI） | pending | — | — |

**FAIL / SKIP の詳細**: markdownlint は PR 後の CI で確認予定。文書確認の 6 件は実装エージェントによる自己確認であり、acceptance-tester による正式な検査は別途実施する。
