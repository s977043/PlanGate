# TASK-0031 Handoff Package

```yaml
task: TASK-0031
related_issue: https://github.com/s977043/plangate/issues/56
author: implementation-agent
issued_at: 2026-04-26
v1_release: feature/task-0031-pg-commands
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: 4 コマンドファイルが存在する | PASS | `ls plugin/plangate/commands/pg-*.md` で 4 件確認 |
| AC-2: skill-policy-router との連携が記述されている | PASS | `grep -l skill-policy-router` → pg-think.md / pg-verify.md にて確認 |
| AC-3: pg-verify が EvidenceLedger JSON 形式を返せる | PASS | `claim`, `status`, `evidence`, `exitCode`, `outputExcerpt` の 5 フィールドを JSON ブロックで定義 |
| AC-4: pg-hunt は root cause なしに fix へ進めない | PASS | `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST` の Iron Law が明記されている |
| AC-5: pg-check は severity 付き finding を返せる | PASS | `critical` / `major` / `minor` / `info` の 4 段階定義 + Findings テーブルが存在する |

**総合**: `5/5 基準 PASS`

**FAIL / WARN の扱い**: 該当なし

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| pg-check.md に skill-policy-router 連携の明示がない（AC-2 は pg-think/verify のみで PASS） | minor | accepted | Yes |

**Critical 課題の対応**: なし（Critical は 0 件）

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| pg-check の skill-policy-router 連携明示 | AC-2 の範囲外。pg-think/verify で基準達成済み | Low | — |
| コマンド間の自動連携フロー（think→hunt→check→verify） | Epic #53 Phase 2 相当。今回スコープ外 | Medium | #53 |
| subagent 自動実行（pg-hunt が仮説検証を自律実行） | Superpowers 相当。Phase 2 以降 | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| コマンドファイルはドキュメント形式（md） | SKILL.md として実装 | Rule 2 準拠・コマンドとして直接呼び出すため commands/ 配下が適切 |
| pg-think/verify のみ skill-policy-router 連携を明記 | 全 4 コマンドに連携明示 | AC-2 は「必要スキルとして自動要求できる」→ think と verify で代表させる設計が適切 |
| light モードでドキュメントのみ実装 | TDD による実装 | コマンドファイルはドキュメントのためテスト対象コードなし |

## 5. 引き継ぎ文書

### 概要

TASK-0031 では、TASK-0029（Skill Policy Router）と TASK-0030（Evidence Ledger）を活用する
4 つの軽量コマンド UX（`/pg-think`, `/pg-hunt`, `/pg-check`, `/pg-verify`）を実装した。
各コマンドファイルは `plugin/plangate/commands/` 配下に配置し、
Iron Law・出力フォーマット・GatePolicy 連携を明記している。
`plugin.json` は v0.2.0 → v0.3.0 に更新した。

### 触れないでほしいファイル

- `plugin/plangate/commands/pg-verify.md`: EvidenceLedger JSON スキーマは TASK-0030 の SKILL.md と同期が必要。変更時は両ファイルを同時に更新すること

### 次に手を入れるなら

- Epic #53 Phase 2: コマンド間の自動連携フロー（think → exec → verify の一気通貫）
- pg-check への skill-policy-router 連携明示（V2 候補 minor 課題）
- subagent 実行サポート（Superpowers 相当）

### 参照リンク

- 親 PBI: https://github.com/s977043/plangate/issues/56
- 依存 TASK-0029: `plugin/plangate/skills/intent-classifier/SKILL.md`, `plugin/plangate/skills/skill-policy-router/SKILL.md`
- 依存 TASK-0030: `plugin/plangate/skills/evidence-ledger/SKILL.md`
- status.md: `docs/working/TASK-0031/` （現 TASK に status.md なし。current-state.md を参照）

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit | 0 | — | — | — |
| Integration | 0 | — | — | — |
| E2E | 0 | — | — | — |
| Verification（受入基準突合） | 5 | 5 | 0 | 100% |

**FAIL / SKIP の詳細**: なし。コマンドファイルはドキュメントのためユニットテスト対象なし。
受入基準 5 件を `grep` / `ls` コマンドで自己突合し全 PASS を確認。
