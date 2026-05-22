# TASK-0107 Manual TC Checklist — `/plangate-setup` 実機対話確認

> **Phase**: V-1 manual 補完（C-4 PR Codex 指摘 R-016/R-017 + Gemini G-R-015 反映後の post-merge）
> **対象**: TC-01 / TC-06 / TC-07 / TC-08 / TC-21 / TC-22（test-cases.md で `manual` 種別が付与された 6 件）
> **理由**: これらは Agent 対話シミュレーションが必要なため、自動化テスト ta-13 では grep / static / mock 検証に留まる。実環境での真の AC PASS は実機 `/plangate-setup` 起動による人間確認を要する
> **記録方針**: 確認完了ごとに `実施日 / 実施者 / 結果 / 補足` 欄を埋める。append-only ではなく上書き可（実機確認は再現性低いため）

---

## 実行方法（共通前提）

```sh
# 1. PlanGate プロジェクトルートで起動
cd /path/to/plangate

# 2. /plangate-setup を Claude Code 内で実行
#    例: スラッシュコマンド `/plangate-setup`
#    または直接 setup-coordinator Agent を呼び出す（実装依存）

# 3. Agent の対話に応答し、各 TC のシナリオを再現
```

---

## TC-01 [AC-1] /plangate-setup で Agent 起動

| 項目 | 値 |
|------|-----|
| シナリオ | プロジェクトルートで `/plangate-setup` を起動 |
| 期待出力 | `setup-coordinator` Agent が起動し、TASK ID 動的解決を実行 |
| 確認ポイント | Agent invocation メッセージ表示、cwd から TASK ID 取得試行 |
| **未実施 / 実施日** | ⬜ 未実施 |
| **実施者** | — |
| **結果**（PASS / FAIL / WARN） | — |
| **補足** | — |

---

## TC-06 [AC-4] FAIL 状態で次 Step に進まない（再検証ループ）

| 項目 | 値 |
|------|-----|
| シナリオ | (1) `bin/plangate doctor --json` で 1 件以上 `ok=false` 状態を作る（例: settings wiring を意図的に削除）/ (2) Agent に「やりました」と報告 / (3) Agent が doctor 再実行で FAIL を再検出するか確認 |
| 期待出力 | Agent が「PASS まで完了しません」相当のメッセージで再提示。次 Step に進まない |
| 確認ポイント | doctor 再実行ループの動作、ユーザー報告を信用しない構造 |
| **未実施 / 実施日** | ⬜ 未実施 |
| **実施者** | — |
| **結果** | — |
| **補足** | — |

---

## TC-07 [AC-4] FAIL → PASS 遷移で次 Step

| 項目 | 値 |
|------|-----|
| シナリオ | (1) TC-06 と同じ FAIL 状態 → (2) Human が実際に settings wiring を適用 / (3) Agent に「やりました」と報告 / (4) doctor 再実行で PASS 確認 |
| 期待出力 | 次 Step に遷移、進捗が status.md に記録される |
| 確認ポイント | PASS 遷移検知、status.md / decision-log.jsonl の append-only 動作 |
| **未実施 / 実施日** | ⬜ 未実施 |
| **実施者** | — |
| **結果** | — |
| **補足** | — |

---

## TC-08 [AC-5] 完了サマリ出力

| 項目 | 値 |
|------|-----|
| シナリオ | 全 doctor check が PASS の状態で `/plangate-setup` を完走させる |
| 期待出力 | `## Setup Summary - YYYY-MM-DD` が `status.md` 末尾に追記。完了項目 / 残項目 / 次のアクション候補（PBI 作成 / `/ai-dev-workflow` 等）の 3 セクション |
| 確認ポイント | サマリのフォーマット、`docs/working/${task_id}/status.md` への正しい書き込み |
| **未実施 / 実施日** | ⬜ 未実施 |
| **実施者** | — |
| **結果** | — |
| **補足** | — |

---

## TC-21 [AC-13] 解消不能 FAIL でフォローアップ PBI 起票誘導

| 項目 | 値 |
|------|-----|
| シナリオ | doctor で解消不能 FAIL を意図的に作る（例: 環境制約で永続的に通らない check）→ Agent に「この FAIL は解消困難」と伝える |
| 期待出力 | Agent が「フォローアップ PBI 起票」「`/ai-dev-workflow <new-task-id> brainstorm`」等の選択肢を提示 |
| 確認ポイント | 脱出経路の対話パス、ユーザーへの誘導メッセージ |
| **未実施 / 実施日** | ⬜ 未実施 |
| **実施者** | — |
| **結果** | — |
| **補足** | — |

---

## TC-22 [AC-13] 承知スキップで status.md に明示記録

| 項目 | 値 |
|------|-----|
| シナリオ | TC-21 と同じ解消不能 FAIL 状態 → Agent の脱出経路選択肢から「承知の上でスキップ」を選択 |
| 期待出力 | `status.md` に `skip (acknowledged): {理由}` が記録される |
| 確認ポイント | skip マーカーの記録フォーマット、理由の明示性 |
| **未実施 / 実施日** | ⬜ 未実施 |
| **実施者** | — |
| **結果** | — |
| **補足** | — |

---

## TC-01 補足エッジケース（EC-01: TASK ID 不明時）

| 項目 | 値 |
|------|-----|
| シナリオ | プロジェクトルート外（例: `/tmp/`）で `/plangate-setup` を起動 |
| 期待出力 | 「Task ID が見つかりません。新規 TASK を作成してください: `/ai-dev-workflow <new-task-id> brainstorm`」または「複数候補から選択」のメッセージ |
| **未実施 / 実施日** | ⬜ 未実施 |
| **結果** | — |

---

## 集計欄

| Status | Count |
|--------|------|
| ✅ PASS | 0 / 7（TC-01 〜 TC-22 + EC-01）|
| ⚠️ WARN | 0 |
| ❌ FAIL | 0 |
| ⬜ 未実施 | 7 |

完了時はこの集計欄を更新し、handoff.md の §6（テスト結果サマリ）に追補すること。

---

## 参照

- [`test-cases.md`](./test-cases.md): TC-01〜TC-22 + EC-01〜EC-04 定義
- [`handoff.md`](./handoff.md): §1 要件適合確認、§2 既知課題、§6 テスト結果サマリ
- [`review-external.md`](./review-external.md): C-2 R5 の Codex 指摘（C-MAJOR-2: manual TC は実機確認待ち）
- [`.claude/agents/setup-coordinator.md`](../../../.claude/agents/setup-coordinator.md): 対話フロー Step 0〜5
- [`.claude/skills/plangate-setup/SKILL.md`](../../../.claude/skills/plangate-setup/SKILL.md): チェックリスト・観点
