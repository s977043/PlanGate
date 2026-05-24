# TASK-0108 C-3 Review Packet (Human-owned 判定用材料)

> 本ファイルは **C-3 ゲート判定を行う人間** のための参考資料。c3.json 発行は本ファイルに従わず、人間の独自判定で行う。

## 1. Phase 状態

- **Phase**: B 完了 (plan / todo / test-cases / review-self / **review-external (C-2 proactive)** 揃った)
- **Mode**: standard
- **C-1**: PASS (総合 96 = R-001..R-006 確定反映後)
- **C-2 (proactive)**: Codex CONDITIONAL + Gemini CONDITIONAL APPROVE → **R-001..R-006 全て本 PR で 1 回確定反映済**
- **未解決 conditional**: **0 件**
- **major / critical 残**: **0 件**

## 2. plan_hash (post-merge 予測値)

```
sha256:5b28f765fa725eafd1f3991aab8a41acfd2a830be846f3f22cd21ddf460bb535
```

> 上記は `origin/docs/task-0108-c2-reflect:docs/working/TASK-0108/plan.md` の SHA-256。PR #322 が squash でなく **plan.md に追加変更なしで** merge されれば main 上で同値になる。squash 後 plan.md が改変された場合は再算出が必要。

## 3. CI 結果 (PR #322)

```
Markdown lint            pass   6s
SKIP_REASON 追認         pass   8s
check                    pass   6s
plangate CLI tests       pass   18s
settings wiring drift    pass   6s
```

すべて PASS。merge-ready。

## 4. C-2 proactive レビュー差分要約

| ID | 反映内容 |
|----|----------|
| R-001 (Codex major) | AC-1 / TC に `docs/index.md` 明示追加 (TC-01b 新規) |
| R-002 (Codex major) | TC-08 外部レビュー判定プロトコル固定化 (同一プロンプト / major 0 + 未解決 conditional 0) |
| R-003 (Codex minor) | #7 呼称統合: glossary.md 正本 + workflows/README.md 参照切替 |
| R-004 (Gemini major) | `docs/plangate.md` ABCD アンカー ID 維持 (見出し併記方式) |
| R-005 (Gemini major) | T-04 README 警告 box の markdownlint MD028 対策 (空行にも `> `) |
| R-006 (Gemini minor) | docs/index.md 「最初に読む 3 ページ」純度維持 |

## 5. C-3 判定 template (人間が編集して `approvals/c3.json` に発行)

```json
{
  "task_id": "TASK-0108",
  "phase": "C-3",
  "c3_status": "APPROVED",
  "approved_by": "human",
  "approved_at": "2026-05-24T00:00:00Z",
  "plan_hash": "sha256:5b28f765fa725eafd1f3991aab8a41acfd2a830be846f3f22cd21ddf460bb535",
  "_review_summary": "C-2 proactive (Codex + Gemini) R-001..R-006 を 1 回確定反映済。major/未解決 conditional 0。exec 可。",
  "_schema_reference": "schemas/c3-approval.schema.json"
}
```

**判定の選択肢** (Human の主観で決定):
- **APPROVED**: 上記 template そのまま → `bin/plangate exec` 受理可
- **CONDITIONAL**: `c3_status` を `"CONDITIONAL"` に変更し `"conditions"` 必須記載
- **REJECTED**: `c3_status` を `"REJECTED"` に変更し `"rejection_reason"` 必須記載

## 6. Exec 着手前のチェックリスト (人間)

- [ ] PR #322 を main にマージ
- [ ] マージ後 `git checkout main && git pull` で main を更新
- [ ] `sha256sum docs/working/TASK-0108/plan.md` で plan_hash を再算出 (上記値と一致確認)
- [ ] `docs/working/TASK-0108/approvals/c3.json` を発行
- [ ] AI に「TASK-0108 exec 開始」を指示 → AI は `bin/plangate exec TASK-0108` 経由で実装着手

## 7. exec 範囲予告 (参考)

- T-01..T-11 / 推定 7-10 ファイル変更 (docs only)
- 主要 touch: README.md, README_en.md, docs/index.md, docs/staged-adoption-guide.md, docs/glossary.md, docs/plangate.md, docs/workflows/README.md, docs/ai/project-rules.md
