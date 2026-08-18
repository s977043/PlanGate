# STATUS — TASK-1109 (#1109)

## モード判定結果

**high-risk** / `lite_eligible=false`（HO 隣接につき強制）/ C-3 は**同期・人間必須**

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-08-18 | B | Plan Package 生成（pbi-input / plan / todo / test-cases） |
| 2026-08-18 | C-1 | セルフレビュー 17 項目 + 追加 2 項目 → **PASS**（WARN 2 / FAIL 0） |
| 2026-08-18 09:00 | C-2 | **未実施**（委譲スコープ外。実施可否は Human 判断） |
| 2026-08-18 09:30 | D (exec) | 実装 + 回帰テスト + 変異注入（M-1/M-2/M-3）を完了。head `c0df5b0` |
| 2026-08-18 11:00 | **V-3（外部レビュー）** | **REJECT**（critical 0 / **major 3** / minor 2 / info 2）。正本 [`review-external.md`](./review-external.md) |
| 2026-08-18 12:30 | **確定反映（1 回）** | `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007`。TC 12 → **17**、変異 3 → **6**（M-A / M-B / M-C 追加） |
| 2026-08-18 13:00 | **簡易 C-1 再実行** | **PASS**（WARN 2）。[`review-self-2.md`](./review-self-2.md) |
| 2026-08-18 13:10 | C-3 | **未実施**。`c3.json` は発行していない（Human-owned） |

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
| テスト | `tests/extras/ta-68-skill-spec-presence.sh`（新規 **17 TC**） |
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
4. **V-3 REJECT を受けて既定 target の設計を反転した**（`Refs: R-001 R-003`）。
   v1「既定 root の不在は violation にしない」→ v2「**宣言した root の不在は violation**」。
   #1086 で `.codex/skills` を外すときは `DEFAULT_TARGETS` の宣言から 1 行削除する。
5. **既定経路（`explicit=False`）の負側 TC を新設**した。テスト専用 env は増やさず、
   script を fixture repo へ複製して `REPO_ROOT` を移す seam を使う（新 API 面ゼロ）。
6. **TC-10 から絶対件数 `ignored=1` を撤去**した（`Refs: R-002`）。同値照合に置換。

## 検証結果

| コマンド | rc |
|---------|---:|
| `sh -n scripts/check-codex-skill-spec.sh` | 0 |
| `sh scripts/check-codex-skill-spec.sh` | **0** |
| `sh scripts/check-codex-skill-spec.sh --target .codex/skills` | 0 |
| `sh scripts/check-codex-skill-spec.sh --target plugin/plangate/skills` | 0 |
| `sh scripts/check-codex-skill-spec.sh --warn-only --target <absent>` | **0** |
| `sh scripts/check-codex-skill-spec.sh --target <absent>` | **1** |
| `sh tests/extras/ta-68-skill-spec-presence.sh </dev/null` | 0（**17 passed, 0 failed**） |
| `ta-30-install-skills.sh`（harness 相当） | 0（9 passed, 0 failed） |
| `PG_T61_NO_RECURSE=1 sh tests/extras/ta-61-extra-contract.sh` | 0（**82 passed, 0 failed**。`ta-68` の契約 3 TC を含む） |
| `sh scripts/sync-plugin-plangate.sh --dry-run` | 0（no changes） |
| `python3 scripts/check-skill-frontmatter.py` | 0（146 件 OK） |
| 変異 M-1 / M-2 / M-3 / M-A / M-B（適用時） | すべて **1**（kill）。復元後は 0 |
| M-C（skills root にファイル 1 枚追加） | **0**（17 passed。時限爆弾なし） |

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
- [ ] **Human 判断（Q-4 / R-005）**: `icon_small` / `icon_large` の**値のパス実在検査**を足すか。
      install 経路では materialize されるが、marketplace 直読み経路の解決可否は**判定不能**
- [ ] **#1086 担当者への申し送り**: `.codex/skills` を untrack する際は
      `scripts/check-codex-skill-spec.sh` の `DEFAULT_TARGETS` 宣言から
      `.codex/skills` の 1 行を削除すること（削除しないと CI が赤になる = 設計どおり）

## 参照ファイル一覧（追補）

- `docs/working/TASK-1109/review-external.md`（V-3 REJECT・R-001〜R-007 と disposition 監査表）
- `docs/working/TASK-1109/review-self-2.md`（簡易 C-1 再実行）

## 参照ファイル一覧

- `docs/working/TASK-1109/{pbi-input,plan,todo,test-cases,review-self}.md`
- `docs/working/TASK-1109/evidence/{before-after.md,mutation/,test-runs/}`
- `docs/working/TASK-1109/patches/0001-drop-warn-only-from-sync-workflow.patch`
