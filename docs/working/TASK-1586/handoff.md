---
task_id: TASK-1586
artifact_type: handoff
schema_version: 1
status: draft
issued_at: 2026-10-19
issued_at_commit: 5fcdb2e3279aed1cf8a02416d5e48bab5a3b191f
author: qa-reviewer
v1_release: ""
---

# Handoff Package: #1586 保守コスト削減機会の調査

## メタ情報

```yaml
task: TASK-1586
related_issue: https://github.com/s977043/plangate/issues/1586
author: qa-reviewer
issued_at: 2026-10-19
issued_at_commit: 5fcdb2e3279aed1cf8a02416d5e48bab5a3b191f
v1_release: ""
```

本文の数値は `issued_at_commit` 時点の測定値で、CI は 2026-10-08T02:52Z〜10-17 の観測窓で取得した。HEAD の時点とは一致しない。

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| 未使用コードの候補提示 | PASS | report.md §2 #13〜15。静的参照・弱参照を一次照合済み |
| flaky / CI コストの把握 | WARN | 観測窓は 1000 run（API の上限）まで。それ以前の run と billable minutes は未測定 |
| 指示負債の把握 | PASS | report.md §2 #5〜12。主要な 3 点を一次照合済み |
| HITL→HOTL の段階案 | PASS | report.md §5。R（維持）ゲートは変えない前提 |
| HO 適用スクリプト | WARN | 手順と検証は `ho/README.md` に同梱した。スクリプト本体（`.sh` 2 本）は、このセッションでは EH-3（`PLANGATE_SKIP_REASON` 未設定）で `.sh` の書き込みが block されるため未同梱。本体は 2 ラウンドのレビュー（review-external.md R-001〜R-014）と最終試走を完了しており、後続 commit で追加する |

**総合**: `3/5 基準 PASS`（WARN 2）

**FAIL / WARN の扱い**:

- CI の観測窓より前は Unknown として、残存脅威モデルに記載した。
- `--apply` は Human が実行する。
- changes job の if 式が GitHub Actions 上で実際にどう評価されるかは未検証。適用後の最初の PR で確認する。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| Codex 節「EH-1/2/3/6/9 物理発火」と hook-enforcement.md #1078 が矛盾している疑い | major | open（未照合） | Yes（#1592、ユーザー判断 a） |
| skills の写しの乖離（intent-classifier / plangate-setup） | minor | open | No |
| run 38714254251（fix/1496）が 2 attempt とも同じ失敗 | minor | open（branch 側の実バグの可能性） | No |
| c3_status が不明な 1 件、status.md 45 件と c3.json 90 件の件数差 | minor | open（Unknown） | Yes |
| HO 適用スクリプト本体（`.sh`）が未同梱 | minor | open（`PLANGATE_SKIP_REASON` を付けて再起動後に追加） | No |

**Critical 課題の対応**: 該当なし。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue（あれば） |
|--------|------|----------|-----------------|
| Codex 節の事実照合 | ユーザー判断 a により別 issue で扱う | High | #1592 |
| lite.size_ok の機械算出 | HOTL Phase 1 | High | #780 |
| working-context.md の分割検討 | 承認規定を含むため HO 該当 | Medium | — |
| apply-* 41 本の棚卸し | 1 本ずつ適用状態を確認する必要がある | Low | #1593 |
| Test workflow の分割 | test.yml は偽の緑を防ぐため今回は変えない | Medium | #1594 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| ci.yml はトリガーを変えず、changes job で skip を判定する | ci.yml に paths-ignore を付ける | required check の `Markdown lint` を常に発火させるため |
| test.yml は変えない | test.yml も .md のみの変更で skip する | ta-77 などは .md の変更でも落ちうる（偽の緑を防ぐ） |
| 削除は候補の提示までにとどめる | 削除を確定する | 手動での運用や動的参照の有無が Unknown |
| Codex 節は文面をそのまま移す | 移設と同時に文面も直す | 事実関係が未照合（ユーザー判断 a） |

## 5. 引き継ぎ文書

### 概要

#1586 の調査結果を `docs/working/TASK-1586/report.md` にまとめた。

- HO 対象の改善は、Human が実行する HO 適用スクリプトとして用意した。手順は `ho/README.md`、本体は後続 commit で追加する。
- HO 対象のパスと ta-77 台帳は、AI は一切編集していない。
- 計画・issue の作成・push と PR の作成はユーザーが承認済み（2026-10-17）。merge は Human が行う。

### 触れないでほしいファイル

- Interactive Review Browser E2E 関連: #1556 で別系統（`fix/1556-chromium-cold-start`）が作業中
- ta-77 台帳 tsv: AI は書き換えない
- 作業ツリーにある承認トークン c3.json 3 件: 扱いは Human が判断する

### 次に手を入れるなら

- `PLANGATE_SKIP_REASON` を付けて再起動したセッションで、`ho/apply-ci-cost.sh` と `ho/apply-claude-agents-md.sh` を追加する
- Human が C-4 で PR をレビューし、merge する
- Human が `ho/README.md` の手順に沿って、作業ブランチで HO 適用スクリプトを実行する（AI は dry-run も含めて実行しない）
- 別 issue（2026-10-20 起票）: #1592（Codex 節の事実照合、判断 a）・#1593（apply-* の棚卸し）・#1594（Test workflow の分割）。skills の写しの正本決定は既存 #1086 / #1263、HOTL Phase 1 は既存 EPIC #1035（#780 slice C）と重なるため起票していない
- 着手する前に、基準 SHA 以降の変更を再測定する
- 避けること: 削除候補をこの PR で削除すること、test.yml を変えること

### 参照リンク

- 親 PBI: https://github.com/s977043/plangate/issues/1586
- レポート: `docs/working/TASK-1586/report.md`
- レビュー記録: `docs/working/TASK-1586/review-external.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit | 0 | 0 | 0 | — |
| Integration | 0 | 0 | 0 | — |
| E2E | 0 | 0 | 0 | — |

**FAIL / SKIP の詳細**: この PR は repo のコードを変更していないため、テストは追加も変更もしていない。

- 調査は、基準 SHA に対する `git show` / `git grep` の一次照合と、GitHub API による CI 実績の取得で検証した。
- HO 適用スクリプトは使い捨ての sandbox で試走した（4 モード・冪等性・rollback・異常系）。そのうえで ta-71 / ta-74 / ta-77 / ta-81 / ta-32 / ta-13 を実走し、退行はなかった。ta-13 の FAIL 10 件は sandbox の BASE でも同じ件数が出ており、今回の変更とは関係ない。

## 7. Metrics summary（v8.6.0+、任意）

該当なし。
