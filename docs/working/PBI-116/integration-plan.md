# Integration Plan — PBI-116

> 親 PBI [`parent-plan.md`](./parent-plan.md) の統合チェック計画。
> Parent Integration Gate（`parent:integration_review` → `parent:done`）の合格判定基準。

## 統合チェック項目（合格条件）

### A. Artifact 完備性

- [ ] 全 6 子 PBI の `handoff.md` が `docs/working/TASK-XXXX/handoff.md` に存在
- [ ] 各 handoff.md が必須 6 要素を含む（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果）
- [ ] 各子 PBI が `state: done` に到達

### B. 受入基準カバレッジ

- [ ] `parent-AC-1`〜`parent-AC-8` が、子 PBI YAML の `covers_parent_ac` に少なくとも 1 件含まれる
- [ ] カバレッジマップを `integration-coverage.md` 等に記録

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

### C. 統合動作確認

- [ ] `CLAUDE.md` / `AGENTS.md` の薄型化後も既存 PlanGate ワークフロー（C-3 / C-4 / scope discipline / verification honesty）が機能する
- [ ] Model Profile 切替で reasoning effort / verbosity が phase に応じて切り替わる
- [ ] Prompt assembly 4 層が記述通りに組み立てられる（pseudo-trace でも可）
- [ ] Structured Outputs schema が既存 `schemas/` と互換（schema-validate で確認）
- [ ] eval cases（PBI-116-05）で全子 PBI 成果物が PASS 判定

### D. リグレッションなし

- [ ] 既存 5 mode 分類（ultra-light / light / standard / high-risk / critical）が維持
- [ ] handoff 必須化（Rule 5）が維持
- [ ] AI 運用 4 原則（CLAUDE.md `<law>` セクション）が維持
- [ ] Iron Law 7 項目が `必ず` / `NEVER` 等の hard mandate として保持

### E. ドキュメント整合

- [ ] `docs/ai/project-rules.md` の参照表に新規ドキュメント（core-contract / model-profiles / prompt-assembly / tool-policy / eval-plan）が追加
- [ ] `docs/orchestrator-mode.md` の Spec 範囲を逸脱していない
- [ ] `.claude/rules/hybrid-architecture.md` の Rule 1〜5 違反なし

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
