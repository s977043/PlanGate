---
task_id: TASK-0873
artifact_type: review-external
schema_version: 1
status: final
verdict: conditional
---

# TASK-0873 外部AIレビュー結果（C-2・追記専用集約）

> レビュー日: 2026-07-22 / 2 レーン責務契約（review-principles §7-bis）
> Lane A = 設計妥当性（Codex・plan/todo/test-cases のみ読む）: **reject**（critical 2 / major 6）
> Lane B = コードベース整合（独立 Claude・既存パターン実測）: **approve**（minor 5 / info 3）
> 分裂裁定: オーガナイザーが争点 4 点（priority 3 実在 / priority 7 candidate 表記 / sync references glob / EH-8 拡張子）を一次ソース実測で確認 — 両レーンの事実主張はすべて正。総合 = **CONDITIONAL**（確定反映 1 回 → 簡易 C-1 → Human C-3）

C2-VERDICT: conditional plan=sha256:3f1c81506fdc861a2d5936f41b3a4b33b97fd71bfdbe8694a71b6d486b300046

## 指摘一覧（R-NNN 採番）

| R-NNN | lane | severity | 指摘（要約） | 裁定 |
|-------|------|----------|------------|------|
| R-001 | A-01 | major | TC-03/04 の期待出力に「repair 後 head の全 checks green + required review 再着弾 + 全 disposition 解決」条件が欠落（旧 review のまま候補化する実装でも通る） | **採用** |
| R-002 | A-02 + B-02 | major | Scheduling 判断表 優先度 3（同型指摘の再発 → review-feedback-loop 還元・recurse）が正規化マッピング未定義（両レーン一致検出） | **採用** |
| R-003 | A-03 | major | 優先度 7 は runbook 上 `MERGE_READY` **candidate**（DoD 判定へ進む非終端）で、8 のみが `MERGE_READY`。plan は 7,8 を同一写像しており短絡余地 | **採用** |
| R-004 | A-04 | critical | A-1（snapshot 判定エンジン）は repair 実行側が V1 に不在のまま AC-4 充足を主張。record 手渡し sandbox では「修正・push・再評価」の実走を証明しない | **部分採用**: ta-56 sandbox に最小アクション実行スタブ（要求アクション→commit 生成→snapshot 更新→再投入）を含め repair 反復を実走。実 PR/gh consumer は V2 とし **C-3 論点に追加**（スコープの人間判断） |
| R-005 | A-05 | critical | 冪等キー `head_sha+round+action_kind` は finding/PR/payload を含まず同種複数アクションを誤抑止。record 記録と外部副作用の順序未定義（crash window） | **採用**: stable action ID = canonical action payload の sha256。intent（要求記録）/ receipt（完了記録）の 2 段分離。外部作用の前/後で中断する TC 追加 |
| R-006 | A-06 | major | snapshot の taxonomy/head/ancestry は供給値で偽装拒否の根拠が未定義 | **部分採用**: Phase 1 信頼境界を正本 doc に明文化（c3-prime-contract §4 の脅威モデル境界と同型 — snapshot は信頼済みローカル呼び出し側供給・独立検証不能値は fail-closed escalate・ancestry は根拠フィールド必須で欠落時 escalate）。raw check evidence 束縛は V2 とし **C-3 論点に追加** |
| R-007 | A-07 | major | NO MERGE ソース走査が literal 2 件のみで gh api/GraphQL/subprocess 経由を検出不能 | **採用**: delivery.py を「ネットワーク・プロセス実行なしの純判定器」として契約化し、禁止 import/シンボル走査（subprocess/os.system/urllib/socket/http/gh）テストを TC-18 に拡張 |
| R-008 | A-08 | major | C-3 論点に priority 3 復帰先 / 7-8 分離 / resume 原子性 / snapshot 信頼境界が漏れ | **採用**: C-3 論点を 5 → 8 件に増補 |
| R-009 | B-01 | minor | c3prime_verify の public IF は `main(argv)→int` のみ。**exit 10（legacy 委譲）の扱いが plan 未定義**・失敗理由は stderr 直出力 | **採用**: legacy（exit 10）→ BLOCK（ai-loop Delivery は c3-prime 必須）を明記。stderr は `contextlib.redirect_stderr` で捕捉し record へ |
| R-010 | B-03 | minor | HUMAN_ESCALATED を Delivery 終端に載せると 00_concept §2.3（語彙群区別・再定義禁止）と表現衝突 | **採用**: 正本 doc に「裁定語彙の借用・Delivery terminal（§2.2 3 状態）ではない escalation exit」の整合注記を必須化 |
| R-011 | B-04 | minor | 「#896 との重複は c3prime_verify.py のみ」は二重に不正確（実重複 = sync-plugin-plangate.sh の列挙 2 箇所。c3prime_verify は #873 読取のみ） | **採用**: Risks の記述訂正 |
| R-012 | B-05 | minor | doc↔contract 整合テストを test_delivery.py に置くと bundled 自立（ta-30 規約）でパス破綻。plugin/references/delivery-state-machine.md が自動再生成物として増える（Files to Touch 未算入） | **採用**: 整合テストは ta-56（TC-12）側に限定。Files to Touch に references 再生成物を追記 |
| R-013 | B-06 | info | record 自己 append は既存 ai-loop scripts（read-only + stdout emit）からの逸脱（冪等判定上の必然はあり） | **採用**: 意図的設計である旨を plan / 正本 doc に 1 行明記 |
| R-014 | B-07 | info | `.jsonl` は EH-8 走査対象外（実測 L86-89）— check summary に raw log を埋めると Forbidden 相当が機械検出なしで混入しうる | **採用**: record 契約に「raw log 本文を含めない・evidence_ref 参照のみ」を明記 |
| R-015 | B-08 | info | TC-E3 の「非 git BLOCK」出典は c3prime_verify.py でなく bin/plangate exec preflight（L2052-2061） | **採用**: 出典表記訂正（方針は正） |

## 指摘なし観点（Lane B 実測）

設計規約整合（決定論・fail-closed・stdlib・sys.path 自立）/ ta-55→ta-56 様式成立（ta-56 連番空き）/ merge ガード様式 / record 配置衝突なし / c3-prime-contract §7 との verbatim 整合 — いずれも指摘なし（実測根拠付き）。

## 監査表（追記専用）

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|---------------------|-------|
| R-001 | adopted | (確定反映 commit で記入) | test-cases TC-03/04 |
| R-002 | adopted | 同上 | plan 論点 C + TC 追加 |
| R-003 | adopted | 同上 | plan 論点 C（7=candidate / 8=terminal） |
| R-004 | partially-adopted | 同上 | ta-56 consumer スタブ + C-3 論点 6 |
| R-005 | adopted | 同上 | plan 冪等設計 + TC-E5/E6 |
| R-006 | partially-adopted | 同上 | plan 信頼境界 + C-3 論点 7 |
| R-007 | adopted | 同上 | plan Constraints + TC-18 拡張 |
| R-008 | adopted | 同上 | plan C-3 論点 8 件化 |
| R-009 | adopted | 同上 | plan Approach（exit 10 BLOCK） |
| R-010 | adopted | 同上 | plan Step 1 注記要件 |
| R-011 | adopted | 同上 | plan Risks 訂正 |
| R-012 | adopted | 同上 | plan Testing/Files 訂正 |
| R-013 | adopted | 同上 | plan Approach 1 行 |
| R-014 | adopted | 同上 | plan record 契約 |
| R-015 | adopted | 同上 | test-cases TC-E3 |
