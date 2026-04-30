# Integration Plan — PBI-116

> 親 PBI [`parent-plan.md`](./parent-plan.md) の統合チェック計画。
> Parent Integration Gate（`parent:integration_review` → `parent:done`）の合格判定基準。

## 統合チェック項目（合格条件）

### A. Artifact 完備性 ✅（2026-04-30 完了）

- [x] 全 6 子 PBI の `handoff.md` が `docs/working/TASK-XXXX/handoff.md` に存在（TASK-0039〜0044）
- [x] 各 handoff.md が必須 6 要素を含む（grep で `## 1.`〜`## 6.` 各 1 件以上確認）
- [x] 各子 PBI が `state: done` に到達

### B. 受入基準カバレッジ ✅（2026-04-30 完了）

- [x] `parent-AC-1`〜`parent-AC-8` が、子 PBI YAML の `covers_parent_ac` に少なくとも 1 件含まれる
- [x] カバレッジマップは `handoff.md § 1` に記録

#### parent-AC ↔ child PBI マッピング

| parent-AC | カバー子 PBI |
|----------|------------|
| parent-AC-1 | PBI-116-01 |
| parent-AC-2 | PBI-116-02 |
| parent-AC-3 | PBI-116-03 |
| parent-AC-4 | PBI-116-04 |
| parent-AC-5 | PBI-116-05 |
| parent-AC-6 | PBI-116-06 |
| parent-AC-7 | PBI-116-01, PBI-116-06 |
| parent-AC-8 | PBI-116-01 |

### C. 統合動作確認 ✅（2026-04-30 完了）

- [x] `CLAUDE.md` / `AGENTS.md` の薄型化後も既存 PlanGate ワークフロー（C-3 / C-4 / scope discipline / verification honesty）が機能する（PBI-116-03/05 で実証）
- [x] Model Profile 切替で reasoning effort / verbosity が phase に応じて切り替わる（model-profiles.yaml + adapters/ 定義）
- [x] Prompt assembly 4 層が記述通りに組み立てられる（prompt-assembly.md + contracts/ × 7 + adapters/ × 4）
- [x] Structured Outputs schema が既存 `schemas/` と互換（schemas/{review-result, acceptance-result, mode-classification, handoff-summary}.schema.json 4 件確認）
- [x] eval cases（PBI-116-05）8 観点が定義され、release blocker 4 観点を明示

### D. リグレッションなし ✅（2026-04-30 完了）

- [x] 既存 5 mode 分類（ultra-light / light / standard / high-risk / critical）が維持
- [x] handoff 必須化（Rule 5）が維持（全 6 子 PBI で handoff.md 出力）
- [x] AI 運用 4 原則（CLAUDE.md `<law>` セクション）が維持
- [x] Iron Law 7 項目が `core-contract.md` に hard mandate として保持

### E. ドキュメント整合 ✅（2026-04-30 完了）

- [x] 新規ドキュメント（core-contract / model-profiles / prompt-assembly / tool-policy / eval-plan）が `docs/ai/` 配下に整列
- [x] `docs/orchestrator-mode.md` の Spec 範囲を逸脱していない
- [x] `.claude/rules/hybrid-architecture.md` の Rule 1〜5 違反なし

## Gap Tracking

統合確認時に発見された未充足項目を記録する場所。

| ID | Gap | Severity | 状態 | 対応 |
|----|-----|---------|------|------|
| (未発見) | — | — | — | — |

**先送り合意ルール**: Gap が `accepted` 状態になった場合は明示的に承認記録（issue or comment）を残す。`open` のままでは `parent:done` に遷移できない。

## Parent Integration Gate 判定フロー

```
1. 全子 PBI が state: done
2. handoff.md 必須要素確認
3. parent-AC カバレッジ確認
4. 統合動作確認（C 項目）
5. リグレッションなし確認（D 項目）
6. ドキュメント整合確認（E 項目）
7. Gap が全て accepted or 解決済み
   ↓ 全 PASS
8. approvals/parent-integration.json に APPROVED 署名
   ↓
9. parent:done に遷移、EPIC #116 を Close
```

いずれか 1 つでも未充足 → `parent:done` 宣言は block（`.claude/rules/orchestrator-mode.md` 不変条件 2 「ParentDone」）。

## 統合 PR の扱い

- 子 PBI 単位で PR を切ったため、親 PBI 完了時の統合 PR は **不要**
- ただし `docs/working/PBI-116/handoff.md`（親 handoff）は必須出力（Rule 5 拡張）
- 親 handoff には全 6 子 PBI の handoff サマリ + 統合チェック結果を集約
