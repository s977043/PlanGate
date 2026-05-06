---
task_id: TASK-XXXX
artifact_type: handoff
schema_version: 1
status: final
issued_at: YYYY-MM-DD
author: qa-reviewer
v1_release: ""
---

# Handoff Package テンプレート

> WF-05 Verify & Handoff の**毎回必須出力**。`qa-reviewer` / `orchestrator` が発行。
> 配置先: `docs/working/TASK-XXXX/handoff.md` 固定（1 PBI につき 1 ファイル）
> 命名規約: `handoff.md`（日付サフィックス等は付けない。複数バージョン必要時は git 履歴で管理）

## メタ情報

```yaml
task: TASK-XXXX
related_issue: <issue URL>
author: qa-reviewer
issued_at: YYYY-MM-DD
v1_release: <コミット SHA or タグ>
```

## 1. 要件適合確認結果

`acceptance-review` Skill の出力を統合。

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| <AC-1> | PASS / FAIL / WARN | <テスト結果 / evidence へのリンク> |
| <AC-2> | ... | ... |

**総合**: `<N>/<M> 基準 PASS`
**FAIL / WARN の扱い**: <V1 で許容する理由、V2 候補への移行等>

## 2. 既知課題一覧

`known-issues-log` Skill の出力を統合。V1 でそのままリリースする妥協点 + 発見された bug。

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| <課題 1> | critical / major / minor | open / workaround / accepted | Yes / No |
| <課題 2> | ... | ... | ... |

**Critical 課題の対応**: <Critical が open で残っている場合、リリース可否の判断根拠>

## 3. V2 候補

今回の scope 外として認識した項目。次回チケット・ロードマップに反映。

| V2 候補 | 理由 | 推定優先度 | 関連 Issue（あれば） |
|--------|------|----------|-----------------|
| <項目 1> | <今回対応しない理由> | High / Medium / Low | #<issue> |
| <項目 2> | ... | ... | ... |

## 4. 妥協点

「なぜこの実装を選んだか / 諦めた選択肢」を記述する。設計の意思決定ログ。

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| <実装 1> | <代替案 1> | <制約 / 工数 / リスク> |
| <実装 2> | ... | ... |

## 5. 引き継ぎ文書

次の担当者（再開時の自分 or 別メンバー）が読んで 5 分で状況把握できるサマリ。

### 概要
<1-2 段落で「何をやったか」「現状どうなっているか」>

### 触れないでほしいファイル
- <ファイル 1>: <触れるとリグレッションする理由>

### 次に手を入れるなら
- <推奨される次のステップ>
- <避けるべきアンチパターン>

### 参照リンク
- 親 PBI: <URL>
- design.md: `docs/working/TASK-XXXX/design.md`
- status.md: `docs/working/TASK-XXXX/status.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit | <N> | <N> | <N> | <%> |
| Integration | <N> | <N> | <N> | <%> |
| E2E | <N> | <N> | <N> | — |

**FAIL / SKIP の詳細**: <FAIL の理由、SKIP の根拠>

## 7. Metrics summary（v8.6.0+、任意）

`bin/plangate metrics TASK-XXXX --collect && bin/plangate metrics TASK-XXXX --report --markdown-section` の結果を貼り付ける（v8.6.0 PR7 で `--markdown-section` が追加され、本セクションを直接生成可能）。
opt-in: 取得していない場合は「該当なし」と記載するか節ごと省略してよい。privacy: §3 Allowed のみで構成され、ファイルパス / コマンド出力 / プロンプトは含まれない（[`docs/ai/metrics-privacy.md`](../../ai/metrics-privacy.md)）。

| 観点 | 値 |
|------|-----|
| events | <N> |
| modes | <例: light×1> |
| C-3 | APPROVED=<N> / CONDITIONAL=<N> / REJECTED=<N> |
| V-1 | PASS=<N> / FAIL=<N> / WARN=<N> |
| C-4 | APPROVED=<N> / REQUEST_CHANGES=<N> / REJECTED=<N> |
| hook violations | <N>（種別: <例: EH-2 block ×1>）|
| fix_loop_max | <N> |
| baseline 比較（任意） | <improved / unchanged / regressed + 観点>|

参照: [`docs/ai/metrics.md`](../../ai/metrics.md) / [`docs/ai/eval-baselines/`](../../ai/eval-baselines/)

---

## 使い方

1. このテンプレートを `docs/working/TASK-XXXX/handoff.md` にコピー
2. `qa-reviewer` が 1〜6 を埋める（`acceptance-review` / `known-issues-log` Skill の出力を統合）
3. `orchestrator` が最終発行し、C-4 ゲート（PR レビュー）の前に提出
4. **全 PBI で必須出力**（`.claude/rules/working-context.md` で強制）

## 関連

- Workflow: `docs/workflows/05_verify_and_handoff.md`
- Agent: `.claude/agents/qa-reviewer.md` / `.claude/agents/orchestrator.md`
- Skill: `acceptance-review` / `known-issues-log`
- 既存 status.md / current-state.md との役割分担: `docs/workflows/05_verify_and_handoff.md` 参照

## status.md / current-state.md / handoff.md の役割分担

| ファイル | 役割 | 更新タイミング | 読者 |
|---------|------|-------------|------|
| `status.md` | フェーズ履歴アーカイブ | フェーズ遷移毎 | 未来の担当者、監査 |
| `current-state.md` | 今の状態スナップショット | タスク完了毎 | 現担当者、セッション復旧時 |
| **`handoff.md`** | **完了時の引き継ぎパッケージ** | **TASK 完了時** | **次の担当者、レビュアー** |
