# STATUS — TASK-1109 (#1109)

## モード判定結果

**high-risk** / `lite_eligible=false`（HO 隣接につき強制）/ C-3 は**同期・人間必須**

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-18 | B | Plan Package 生成（pbi-input / plan / todo / test-cases） |
| 2026-08-18 | C-1 | セルフレビュー 17 項目 + 追加 2 項目 → **PASS**（WARN 2 / FAIL 0） |
| 2026-08-18 | C-2 | **未実施**（委譲スコープ外。実施可否は Human 判断） |
| 2026-08-18 | C-3 | **未実施**。`c3.json` は発行していない（Human-owned） |
| 2026-08-18 | D (exec) | 実装 + 回帰テスト + 変異注入を完了 |

## C-3 Gate

**未取得**。`approvals/c3.json` は**発行していない**。
mode=high-risk かつ Hardening Override 対象パス（`.github/workflows/*.yml`）への
変更を完了形に含むため、**autonomous APPROVE は不可**（人間 C-3 必須）。

## 全体構成

- ブランチ: `fix/1109-skill-spec-presence-check`
- PR: 未作成

## 変更ファイル一覧

| 分類 | ファイル |
|------|---------|
| 検出器 | `scripts/check-codex-skill-spec.sh` |
| テスト | `tests/extras/ta-68-skill-spec-presence.sh`（新規 12 TC） |
| 配布物（新規 4） | `plugin/plangate/skills/{ai-loop-cycle,breakdown-gate,ref-integrity-scan,subagent-delegation-brief}/agents/openai.yaml` |
| 配布物（修正 1） | `plugin/plangate/skills/diff-audit/agents/openai.yaml` |
| repo skill root（再生成 8） | `.codex/skills/{context-packager,design-gate,evidence-ledger,intent-classifier,pr-decision,skill-creator,skill-policy-router,subagent-dispatch}/agents/openai.yaml` |
| Plan Package / evidence / patch | `docs/working/TASK-1109/**` |

## 計画からの変更点

1. **rc 方針の実装点を 1 箇所に集約した**（plan §5）。初版は python / shell 両方に
   `--warn-only` 分岐があり、**M-2 変異が生き残った**ため設計変更した。
2. **新規 extras を `ta-67` ではなく `ta-68` にした**。`ta-67` は TASK-1093 が予約済み。
3. `.codex/skills` 再生成が SKILL.md 4 件も更新したため、**openai.yaml 以外は revert**し
   スコープ外の報告事項に回した（#1086 領域）。

## 検証結果

| コマンド | rc |
|---------|---:|
| `sh -n scripts/check-codex-skill-spec.sh` | 0 |
| `sh scripts/check-codex-skill-spec.sh` | **0** |
| `sh scripts/check-codex-skill-spec.sh --target .codex/skills` | 0 |
| `sh scripts/check-codex-skill-spec.sh --target plugin/plangate/skills` | 0 |
| `sh scripts/check-codex-skill-spec.sh --warn-only --target <absent>` | **0** |
| `sh scripts/check-codex-skill-spec.sh --target <absent>` | **1** |
| `sh tests/extras/ta-68-skill-spec-presence.sh </dev/null` | 0（12 passed, 0 failed） |
| `ta-30-install-skills.sh`（harness 相当） | 0（9 passed, 0 failed） |
| `sh scripts/sync-plugin-plangate.sh --dry-run` | 0（no changes） |
| `python3 scripts/check-skill-frontmatter.py` | 0（146 件 OK） |

**フルスイート `sh tests/run-tests.sh` は実行していない**（`ta-61` の入れ子再実行で
並走ワーカーが完走できないため。オーケストレータが最後に 1 本走らせる前提）。

## 残タスク

- [ ] **C-3（Human / 同期必須）**
- [ ] PR 作成 → C-4
- [ ] **BLOCKED**: `--warn-only` を workflow から外す
  - `blocker`: HO パス（`.github/workflows/sync-plugin-plangate.yml`）は AI 適用不可
  - `owner`: human
  - `unblock_condition`: 本 PR が merge され、main で `sh scripts/check-codex-skill-spec.sh` が rc=0
  - 適用物: `docs/working/TASK-1109/patches/0001-drop-warn-only-from-sync-workflow.patch`（隔離コピーへの実適用で検証済）
- [ ] **Human 判断（Q-1）**: 配布物 `openai.yaml` の生成を `sync-plugin-plangate.sh` に
      組み込むか（組み込むと手書き英語 description が frontmatter 由来の切り詰めに置換される）

## 参照ファイル一覧

- `docs/working/TASK-1109/{pbi-input,plan,todo,test-cases,review-self}.md`
- `docs/working/TASK-1109/evidence/{before-after.md,mutation/,test-runs/}`
- `docs/working/TASK-1109/patches/0001-drop-warn-only-from-sync-workflow.patch`
