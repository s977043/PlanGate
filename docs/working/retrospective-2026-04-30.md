# 振り返り 2026-04-30: doc-audit 2026-04-28（PR #123）

> 対象: PR [#123](https://github.com/s977043/plangate/pull/123) — `docs: 2026-04-28 ドキュメント整備（v8.2 整合性 / Rule 5 遵守 / 索引修正）`
> ブランチ: `docs/audit-2026-04-28`（マージ済み）
> 期間: 2026-04-28〜2026-04-30

## サマリ

v8.2 リリース後のドキュメント整備として **Phase A（読取専用監査）→ Phase B（修正適用）** の二段階アプローチを実施し、9 コミットを 1 PR に集約してマージ完了。CI（Markdown lint / plangate CLI tests）は両方 PASS。

| 区分 | 件数 | 結果 |
|------|------|------|
| Critical | 4 | 全件適用 |
| Major | 4 | 全件適用 |
| Minor | 4 | 2 件適用 / 2 件は監査誤検出により対応不要 |
| Info | 3 | I-3 を方針 A として M-4 に統合 |

## Keep（うまくいったこと）

### K-1. 監査と修正の二段階分離が機能した
Phase A（読取専用、4 並列 Explore agent）で punch list を確定 → ユーザー判断 → Phase B（修正）の流れにより、**着手前に範囲が明確化**され、途中で迷子にならずに済んだ。punch list を `docs/working/_audit/2026-04-28-doc-audit.md` に書き出したことで、修正の根拠が常に参照できた。

### K-2. severity 順のバッチコミットで PR が読みやすくなった
Critical → Major → Minor の順に 9 コミットを切ったことで、レビュー時に「重要度の高い変更から順に確認できる」構造になった。1 バッチ = 1 コミット = 1 punch list ID の対応が PR 本文の表とも一致して分かりやすい。

### K-3. handoff.md の遡及作成テンプレが再現可能だった
完了済 PBI 3 件（TASK-0017/0018/0019）の handoff.md を status.md / PR メタデータから機械的に再構成できた。「**遡及不能な項目は明示的に省略**」という方針も、後続の同様作業で踏襲可能。

## Problem（課題・反省）

### P-1. 監査エージェントに誤検出が含まれた
Phase A の Explore エージェントが以下を誤検出していた:
- m-1: `docs/plangate.md` に「v7 では」表現あり → **実際は該当なし**
- m-2: `.claude/skills/README.md` に setup-team 未掲載 → **実際は掲載済み**
- m-3 重複指摘: `.agents/skills/README.md` のセクション重複 → **実際は重複なし**

**原因**: Explore エージェントが「読み取り範囲」を抜粋的に報告するため、行番号や周辺コンテキストの再確認が不十分だった。

**対策**: 監査結果は punch list 確定前に **手元で grep / read による再検証** を 1 ステップ挟む（次回フロー追加）。

### P-2. M-4 の判断が punch list 提出時点で曖昧だった
「Agent 定義の "PlanGate" 言及 24 件」を Rule 3 / Rule 4 違反扱いするか否かの判断を Phase A では結論づけられず、Phase B 着手前にユーザー判断を仰いだ。

**対策**: 監査エージェントに「**判断保留項目**」を明示的に分類させるプロンプトに改善。今回は方針 A を採用し、`hybrid-architecture.md` に補足として明文化したため、次回以降は誤検出として扱える。

### P-3. gh auth account 切り替えで PR 作成が一度失敗した
作業開始時のアクティブアカウントが `kominem-unilabo` のままで、PR 作成が collaborator 権限エラーで失敗。auto-memory に記録された「GitHub アカウント切り替え」メモで原因即特定し復旧したが、**着手前に `gh auth status` を確認する手順が抜けていた**。

**対策**: メモリ記載通り「plangate 作業開始時に `gh auth switch -u s977043` を必ず実行」する hook 化を検討（別 PBI）。

## Try（次にやること）

### T-1. punch list 検証ステップの自動化
Phase A の punch list 確定前に、各 finding を機械的に再検証する Bash コマンド集を audit 結果ファイル末尾に同梱する（grep / ls / wc -l 等）。手動でも 5 分で再現できる構造にする。

### T-2. handoff 必須化の事前検出スクリプト
Rule 5 違反（完了済 PBI で handoff.md 欠落）を CI で機械検出する。現状は監査時に発覚するため後手対応になっており、事前検出に切り替える。

### T-3. Orchestrator Mode の実運用ケース第一号として EPIC #116 を扱う
EPIC #116「最新実行モデル対応」+ P1 6 件は親子 PBI 構造の自然な candidate。本振り返りと並行して `docs/working/PBI-116/parent-plan-draft.md` の素案作成を進める（別 PR）。

## メトリクス

| 指標 | 値 |
|------|---|
| 計画コミット数（B1〜B11 + audit + PR） | 9 |
| 計画外コミット | 0 |
| 監査誤検出率 | 2/12 = 17%（minor 領域） |
| Phase A 所要時間 | 約 10 分（4 並列 Explore） |
| Phase B 所要時間 | 1 セッション内で完了 |
| CI 通過 | 100%（Markdown lint / plangate CLI tests） |
| C-4 ゲート | APPROVE / 即マージ |

## 関連リンク

- PR: https://github.com/s977043/plangate/pull/123
- 監査結果: [`docs/working/_audit/2026-04-28-doc-audit.md`](_audit/2026-04-28-doc-audit.md)
- 方針 A 整理: `.claude/rules/hybrid-architecture.md` の補足セクション
- handoff 遡及作成例: `docs/working/TASK-0017/handoff.md` ほか 2 件

---

# 振り返り 2026-04-30: PBI-116 EPIC（最新実行モデル対応）完了

> 対象: EPIC [#116](https://github.com/s977043/plangate/issues/116)（CLOSED） / PR #126〜#151（17 PR）
> Milestone: v8.2 中核 EPIC / Mode: high-risk
> 期間: 2026-04-29〜2026-04-30（2 日 / 1 セッション集中）

## サマリ

PlanGate v8.2 milestone の中核として、最新実行モデル（GPT-5.5 以降）の outcome-first 指示設計に対応する **基盤** を整備。Orchestrator Mode の **実運用ケース第一号** として親 PBI（PBI-116）+ 子 PBI 6 件を分解し、4 phase 構成で実行・全件 done に到達。Parent Integration Gate を APPROVED で通過し、EPIC を Close した。

| 指標 | 値 |
|------|---|
| 子 PBI done | **6 / 6** |
| parent-AC PASS | **8 / 8** |
| Open Gap / Release blocker | **0 / 0** |
| マージ PR 総数 | **17 件**（#126〜#151）|
| Codex C-2 統合レビュー回数 | 2 回（Phase 2 統合 / Phase 3）|
| Gemini Code Assist 指摘総数 | ~20 件（全件対応）|
| CI 通過率 | 100% |

## Phase 構成と主要成果物

| Phase | 子 PBI | 成果物 |
|-------|--------|--------|
| Phase 1 | PBI-116-01 | `core-contract.md`（Iron Law 7）/ CLAUDE.md 43→21 / AGENTS.md 61→29 |
| Phase 2 | PBI-116-02 | `model-profiles.yaml`（4 profile）+ schema |
| Phase 2 | PBI-116-04 | `responsibility-boundary.md` / `tool-policy.md` / `hook-enforcement.md` / `structured-outputs.md` + 4 schemas |
| Phase 2 | PBI-116-06 | （Phase 2 統合領域） |
| Phase 3 | PBI-116-03 | `prompt-assembly.md`（4 層）+ `contracts/` × 7 + `adapters/` × 4 |
| Phase 4 | PBI-116-05 | `eval-plan.md` + `eval-cases/` × 8 + `eval-comparison-template.md` |

## Keep（うまくいったこと）

### K-1. Orchestrator Mode 実運用第一号として手応えがあった

親 PBI 分解 → 4 phase 順次/並列 → 統合判定 という Workflow が、仕様通り機能した。`docs/working/PBI-116/` に親 artifact（parent-plan / dependency-graph / parallelization-plan / integration-plan / risk-report）を集約し、`children/*.yaml` で子 PBI を schema 化した構造が、進捗把握と再開時のコンテキスト復旧を容易にした。

### K-2. Phase 2 並行実行 + Codex C-2 統合レビューがコスト効率よく機能した

Phase 2 の 3 子 PBI（02 / 04 / 06）を並行 exec し、C-2 を 1 回の Codex 呼び出しに統合。CONDITIONAL → 同 PR で全 4 件対応の流れにより、**Codex 呼び出し回数を 1/3 に圧縮**しつつ責務隣接性を活かしたレビュー精度を維持できた。

### K-3. Gemini Code Assist の指摘が品質ゲートとして機能した

各 PR で Gemini が medium 指摘を 1〜4 件提示し、全て妥当（schema/グラフ整合性 / shell 構文 / Markdown link 化等）。**人手レビュー前の 1 段目フィルタとして高い signal-to-noise**。特に PR #149 の release blocker 表整合性（`format adherence` の YES/NO 不整合）、PR #151 の YAML/JSON キー名統一は、見落としやすい integrity issue を早期検出。

### K-4. handoff.md 必須化（Rule 5）が EPIC 完了処理を統一化

全 6 子 PBI で `handoff.md` 必須 6 要素を出力。親 handoff.md（9 セクション）への集約も `parent-AC × 子 PBI` マッピング表を中心に機械的に組み立てられた。`approvals/parent-integration.json` の `integration_check_results` も A〜E 構造を踏襲できた。

### K-5. eval-cases 8 観点を Gemini 指摘で 7→8 に拡張できた

当初 7 観点で計画していた eval cases に、Gemini EX 指摘で **latency / cost** を追加。実運用観点で必須の観点が「感覚的に省かれていた」ことに気付かされた。release blocker 該当外（コスト判断は経営判断）として位置付けることで、release flow と整合性を保ちつつ網羅性を高められた。

## Problem（課題・反省）

### P-1. C-2 skip 判断のドキュメント化が後追いになった

Phase 4（PBI-116-05）で C-2 を skip した際、`review-external.md` に skip 理由を記録したが、**事前に skip 判断基準を Spec 化していなかった**。今回は「standard / doc-only / Phase 1〜3 同パターン踏襲」を理由としたが、別ケースでは判断揺れの可能性。skip 基準を `.claude/rules/` に明文化すべき。

### P-2. scope-discipline.md の作成漏れを直前まで検出できなかった

Phase 4 exec 中に 8 観点の eval-cases を一括作成した際、**scope-discipline.md（最重要 release blocker 観点）が漏れた**。verification 段階の `ls | wc -l` で「7 件 vs 期待 8 件」の差分検出により発見・補完したが、もし TC-2 の自動カウント verification を入れていなければ気付かなかった可能性。**ファイル作成時の checklist 自動チェック**を組み込みたい。

### P-3. embedded worktree が誤コミットされた

PR #134 で `.claude/worktrees/agent-*` が誤って commit され、追加コミットで `git rm --cached` 削除。`.gitignore` への追加が抜けていた。worktree 作成時に自動で gitignore チェック / `git status` 警告する仕掛けが欲しい。

### P-4. PR #142 BLOCKED 「head branch is not up to date」で時間ロス

Phase 2 の並行 PR で、後発 PR が main から遅れて BLOCKED に。`gh pr update-branch` で個別に更新する手間が発生。並行 exec 時の **PR rebase 自動化 / merge queue** 検討余地。

### P-5. Auto Mode 中の gh アカウント切替で何度も再認証

`gh auth switch -u s977043` を gh API 呼び出し前に都度実行する必要があり、自動化の妨げに。ローカル `~/.config/gh/hosts.yml` の active_user を session 開始時に固定する shim を作るべき。

## Try（次に試すこと）

### T-1. v8.2 baseline 測定 PBI（次セッション）

本 EPIC で整備した eval framework での **初回 baseline 測定**。比較表テンプレートに 1 行記入し、以降の比較基準を確立する。

### T-2. 実装層 EPIC 4 件の起票

| 候補 | 優先度 | 内容 |
|------|------|------|
| eval runner 実装 | High | reasoning_token / latency / tool call 集計の自動化 |
| Hook enforcement 実装 | High | plan 未承認 block / forbidden_files 違反 block 等のハード強制 |
| Structured Outputs 実 LLM 適用 | High | schema validate CI 統合含む |
| Model Profile 実プロンプト適用 | Medium | adapters/ 定義の実 LLM プロンプトへの組み込み |

### T-3. C-2 skip 判断基準の Spec 化

`.claude/rules/c2-review-policy.md`（仮）を新規作成。`mode × artifact_type × parallel_review_done` のマトリクスで skip 可否を明文化。

### T-4. Gemini Code Assist 指摘パターンの集約

PR #126 〜 #151 で Gemini が指摘した ~20 件のパターンを retrospective に集約し、**事前 self-review checklist に追加**。今回頻出した: schema/handoff キー名整合、release blocker 表整合、shell 構文（git diff dot-dot vs triple-dot）、Markdown link 化。

### T-5. Auto Mode の gh shim

`~/.claude/scripts/gh-pin-account.sh` で session 起動時に active user を固定する仕組み。

## メトリクス

| 指標 | 値 |
|------|---|
| 計画 PR 数 | 17 |
| 計画外 PR | 0 |
| Gemini medium 指摘 | ~20 件（全件対応） |
| BLOCKED → 復旧した PR | 2 件（#142, #144 / `gh pr update-branch`）|
| C-2 Codex 統合レビュー回数 | 2 回（Phase 2 / Phase 3）|
| C-2 skip 判断 | 1 回（Phase 4 / 記録あり）|
| 子 PBI handoff 必須 6 要素 完備率 | 6/6 = 100% |
| parent-AC × child PBI カバレッジ | 8/8 = 100% |
| 統合チェック A〜E PASS | 全 PASS |
| Open Gap / Release blocker | 0 / 0 |
| EPIC 期間 | 2 日（2026-04-29 起票 → 2026-04-30 Close） |

## 関連リンク

- EPIC: [#116](https://github.com/s977043/plangate/issues/116)（CLOSED）
- 親 plan: [`docs/working/PBI-116/parent-plan.md`](PBI-116/parent-plan.md)
- 親 handoff: [`docs/working/PBI-116/handoff.md`](PBI-116/handoff.md)
- 統合計画: [`docs/working/PBI-116/integration-plan.md`](PBI-116/integration-plan.md)
- 承認記録: [`docs/working/PBI-116/approvals/parent-integration.json`](PBI-116/approvals/parent-integration.json)
- 子 PBI handoff: TASK-0039〜TASK-0044
