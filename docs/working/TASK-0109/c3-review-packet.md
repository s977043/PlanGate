# TASK-0109 C-3 Review Packet (Human-owned 判定用材料)

> 本ファイルは **C-3 ゲート判定を行う人間** のための参考資料。c3.json 発行は本ファイルに従わず、人間の独自判定で行う。

## 1. Phase 状態

- **Phase**: B 完了 (plan / todo / test-cases / review-self / **review-external (C-2 proactive)** 揃った)
- **Mode**: standard (CX-2 hook 配線部分のみ high-risk 相当)
- **C-1**: PASS (R-001..R-010 確定反映後)
- **C-2 (proactive)**: Codex CONDITIONAL + Gemini CONDITIONAL APPROVE → **R-001..R-010 全て本 PR で 1 回確定反映済**
- **未解決 conditional**: **0 件**
- **CRITICAL 残**: **0 件** (R-005 Gemini CRITICAL `--sandbox read-only` は plan / TC-05c で固定済)

## 2. plan_hash (post-merge 予測値)

```
sha256:5c1e1b439508b981f340924cd15808ee36a9c1eb81552d931c6529304f7afcc2
```

> 上記は `origin/docs/task-0109-c2-reflect:docs/working/TASK-0109/plan.md` の SHA-256。

## 3. CI 結果 (PR #323)

```
Markdown lint            pass   4s
SKIP_REASON 追認         pass   3s
check                    pass   8s
plangate CLI tests       pass   16s
settings wiring drift    pass   6s
```

すべて PASS。merge-ready。

## 4. C-2 proactive レビュー差分要約 (CRITICAL を含む)

| ID | Sev | 反映内容 |
|----|-----|----------|
| R-005 (Gemini) | **CRITICAL** | review 用 `codex exec` に `--sandbox read-only` 必須 → Constraints + T-02 + Risks + TC-05c で固定 |
| R-001 (Codex) | major | CX-2 hook 起動経路未確定 → **T-01 ハードゲート化**、経路確定まで CX-2 凍結 |
| R-002 (Codex) | major | EH-3 は Cursor 翻訳ではなく**新規設計** |
| R-003 (Codex) | major | TC-05 manual のみでは弱い → wrapper deterministic test (codex CLI stub) |
| R-006 (Gemini) | major | `timeout 600` wrap (codex CLI に `--timeout` なし) |
| R-007 (Gemini) | major | `--output-last-message <file>` でクリーン出力 |
| R-008 (Gemini) | major | hook 発火機構確認 (R-001 と統合) |
| R-009 (Gemini) | major | shim symlink `CDPATH= cd -- "$(dirname -- "$0")" && pwd` |
| R-004 (Codex) | minor | README / README_en / docs/index.md を Files + T-09b に追加 |
| R-010 (Gemini) | minor | Role Mapping 表を `docs/rfc/provider-codex.md` に |

## 5. C-3 判定 template (人間が編集して `approvals/c3.json` に発行)

```json
{
  "task_id": "TASK-0109",
  "phase": "C-3",
  "c3_status": "APPROVED",
  "approved_by": "human",
  "approved_at": "2026-05-24T00:00:00Z",
  "plan_hash": "sha256:5c1e1b439508b981f340924cd15808ee36a9c1eb81552d931c6529304f7afcc2",
  "_review_summary": "C-2 proactive (Codex + Gemini) R-001..R-010 を 1 回確定反映済。CRITICAL 1 件 (R-005 --sandbox read-only) は plan/TC-05c で固定。major/未解決 conditional 0。T-01 hard gate により CX-2 hook 経路確定後のみ CX-2 着手。",
  "_schema_reference": "schemas/c3-approval.schema.json"
}
```

## 6. Exec 着手前のチェックリスト (人間)

- [ ] PR #323 を main にマージ
- [ ] マージ後 `git checkout main && git pull`
- [ ] `sha256sum docs/working/TASK-0109/plan.md` で plan_hash 再算出 → 上記値と一致確認
- [ ] `docs/working/TASK-0109/approvals/c3.json` を発行
- [ ] AI に「TASK-0109 exec 開始」を指示

## 7. exec 着手後の Gate 構造 (重要)

```
T-01 (ハードゲート: hook 経路確定) ──┬─→ T-02 (CX-1 CLI wiring)
                                    └─→ [経路確定後のみ] T-03 → T-04 (CX-2 hook 配線)
                                                                  ↓
                                                          T-05 (CX-3 RFC)
                                                                  ↓
                                                       T-06..T-09b (テスト + docs)
                                                                  ↓
                                                          T-10 (handoff + V-1)
```

T-01 で「`codex` CLI native hook なし & `scripts/codex-local.sh` で fan-out 不可能」と判明した場合、CX-2 を本 PBI から外して別 PBI 化することを再 C-3 で人間確認する。

## 8. exec 範囲予告 (参考)

- T-01..T-10 + T-09b / 推定 10-12 ファイル変更
- 主要 touch: bin/plangate, .codex/hooks/ (or scripts/codex-local.sh), tests/extras/, tests/hooks/, docs/rfc/provider-codex.md, README / README_en / docs/index.md
- 既存テスト regression: tests/run-tests.sh 101/0 + tests/hooks/run-tests.sh 79/0 維持
