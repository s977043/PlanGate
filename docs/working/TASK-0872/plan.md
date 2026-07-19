# EXECUTION PLAN — TASK-0872

> Issue: [#872](https://github.com/s977043/plangate/issues/872)（P0）/ Parent EPIC: #870
> 入力: [`pbi-input.md`](./pbi-input.md)（issue verbatim + 2026-07-20 実測調査）
> 作成: 2026-07-20

## Goal

`ai-loop run TASK-XXXX` を Plan-first の唯一の正式入口とし、C-3'（arbiter 裁定）を Plan Package の hash / source SHA / C-1・C-2 evidence へ機械束縛する。C-3' 結果を `bin/plangate validate` / exec preflight が受理できる正式 `approvals/c3.json` 互換 artifact（c3-prime）として発行し、Plan/artifact 変更時は fail-closed で stale 化する。

## Constraints / Non-goals

- **Non-goals**（issue verbatim）: ai-dev plan/exec/verify の再実装 / C-3' eligibility の全 mode 拡大 / C-4・merge 自動化 / C-1・C-2 レビュー品質の再設計（#810 再利用）
- **不変条件**: PlanGate 本番フロー WF-00〜07 不変 / legacy C-3 human approval（既存 `c3-approval.schema.json` + `plangate approve`）は無変更で後方互換（AC-11）/ Phase 1 rollout policy 不変
- **HO 制約**: `schemas/*.schema.json` / `bin/plangate` / `.claude/commands/*.md` / `.github/workflows/*` は AI 編集不可（常時 block）。AI は patch 生成・dry-run まで、適用は Human（TASK-0871 `ho-apply-approval.md` 方式踏襲）
- **#873 並行実装の前提**: c3-prime artifact のフィールド契約（pbi-input の YAML）を Step 0 で先に固定し、`delivery.py`（#873）との共有契約とする

## Approach Overview

### 論点 1: c3-prime artifact の schema — **案 B 採用**

| 案 | 内容 | 評価 |
|----|------|------|
| A: `c3-approval.schema.json` 拡張 | 既存 schema に `approval_kind` / evidence 系フィールドを追加 | ❌ `additionalProperties:false` の既存 schema 変更は legacy c3.json 全件の再検証リスク + AC-11 後方互換の証明コスト大 |
| **B: `c3-prime.schema.json` 新設 + validate/preflight 両対応** | 新 schema を独立追加。`bin/plangate` は `approval_kind` 判別で c3-prime / legacy c3 を両受理 | ✅ legacy 契約 byte 不変で AC-11 が構造的に成立。schema 新設は additive。判別ロジックのみ bin/plangate に追加 |
| C: c3-prime → c3.json 変換 bridge | arbiter 出力を既存 c3.json 形式へ変換して書き込む | ❌ AUTO_APPROVED を `approved_by` 付き human 承認と偽装する形になり監査上不可（issue「手動で c3.json を書き換える運用では close しない」に抵触） |

### 論点 2: Plan Package 検証の実装位置 — **新モジュール `plan_package.py` 採用**

| 案 | 内容 | 評価 |
|----|------|------|
| A: arbiter.py 内へ直接実装 | presence/hash 検証を arbiter に追記 | ❌ arbiter は「入力 JSON のみで決定論裁定」の純関数設計。ファイル I/O を持ち込むと責務混濁・テスト肥大（現 1054 行 + test 2688 行） |
| **B: `scripts/ai-loop/plan_package.py` 新設** | presence / integrity（sha256）/ LoopSpec 決定論的派生 / c3-prime 組み立てを担う独立モジュール。arbiter へは検証済み `plan_package` ブロックを入力として渡す | ✅ arbiter の純関数性維持。#873 `delivery.py` と同型（決定論・fail-closed・単体テスト可能）。冪等（シナリオ 9） |

### 論点 3: plan_hash の計算範囲 — **既存契約不変 + 加算**

既存 4 箇所（c3 schema / approve / validate+preflight / EH-3 hook）の `plan_hash` = **plan.md 単体 sha256** は変更しない。c3-prime では `plan_hash`（plan.md 単体・既存互換）に加え `artifact_hashes`（4 成果物 + C-1/C-2 evidence の個別 sha256）と `plan_package_hash`（artifact_hashes の正規化 JSON の sha256）を**加算**する。AC-8 の stale 判定は artifact_hashes 全体で行う。

### 論点 4: §3.4 `--verify-diff` との位相

本 PBI は plan 束縛（承認時点の固定）が範囲。§3.4 の「宣言 ↔ 実差分整合（`--verify-diff`）」は exec 後の検証であり **#873 / 後続の範囲**。00_concept §3.4 に本 PBI で「plan 束縛は TASK-0872 で実装済み、--verify-diff は未実装のまま Phase 3」と位相を明記する（実装はしない）。

### PR 分割（HO / 非 HO スライス）

- **PR-1（非 HO）**: python 層（plan_package.py / arbiter.py / tests）+ docs（00_concept / loopspec / execution-runbook / decision-table）+ SKILL 2 箇所 + plugin sync
- **PR-2（HO・Human patch 適用）**: `schemas/c3-prime.schema.json` 新設 / `bin/plangate` 両対応 / `.claude/commands/ai-loop-workflow.md` run 入口 TASK 必須化（+ plugin sync）/ CI python テスト + E2E fixture 配線
- 制約: CI drift-check（plugin sync 同一 PR 強制）により、SKILL/command の sync 対は各 PR 内で完結させる（PR-1 = skills 対、PR-2 = commands 対）

## Metrics Evidence（#351 mandatory gate）

- **実数**（2026-07-20 実測・全ファイル実在確認済み。C-2 確定反映後）: 非 HO 14（arbiter.py 1054 行 / test_arbiter.py 2688 行 / plan_package.py+test 新設 2 / schema_mapping.py / sync-plugin-plangate.sh / docs 5 / SKILL ×2 + plugin sync）+ HO 4（c3-prime schema 新設 / bin/plangate 2451 行 / ai-loop-workflow.md ×2）+ 非 HO fixture（tests/extras + tests/fixtures）= **19〜20**（C-2 で +2 / −1: R-006・R-008 追加、test.yml 除外 R-013）
- **AI 見積もり**: 12〜16
- **ratio**: 1.2〜1.7 倍 → **採用**（3 倍未満。Risks に記録。C-2 反映による増分は Replan Trigger 閾値 22 の範囲内）
- **判定**: 変更ファイル数 16+ → 定量 critical 圏。安全側原則により Mode=critical 採用（下記 Mode 判定）

## Work Breakdown (Steps)

1. **Step 0: c3-prime フィールド契約の正本化**（#873 共有契約）
   - Output: `docs/workflows/ai-loop/c3-prime-contract.md`。pbi-input の YAML を required/optional・型・stale 条件付きで確定し、以下を必須で含む:
     - **reviewer snapshot**（Refs: R-004）: `reviewers.model_a/model_b` に各 reviewer が観た `plan_hash` / `source_sha` / `plan_package_hash` / 判定 / evidence ref を必須化し、照合規則（全 reviewer 同一 hash でなければ block = AC-5）を定義
     - **source_sha の stale 規則**（Refs: R-003）: `source_sha != 検証時点の対象 SHA` は validate / exec preflight で **BLOCK**（警告に降格しない fail-closed 固定）。target_sha（arbiter 既存フィールド）との関係も定義（c3-prime では source_sha = W チェック時の target_sha と同一値であることを照合。Refs: R-011）
     - **serialization 制約**（Refs: R-009）: json.dumps indent=2・トップレベルに `"c3_status"` / `"plan_hash"` を含む行は各 1 回のみ（bin/plangate の grep/sed legacy 経路と衝突しない整形）
     - **LoopSpec 派生マッピング表**（Refs: R-012）: LoopSpec 必須フィールド全数 ×（派生元成果物セクション or 固定既定値）の対応表。I-4 fail-closed で受理拒否されない完全マッピングを契約で保証
     - legacy c3.json と c3-prime の併存時の受理優先順（EC-5）
   - Owner: agent / Risk: 低
   - 🚩 チェックポイント: #873 が参照可能な自己完結契約になっているか（delivery.py が読むフィールドの過不足）
2. **Step 1 (PR-1): `scripts/ai-loop/plan_package.py` 新設**
   - Output: presence 検証（4 成果物 + C-1/C-2 evidence）/ artifact_hashes・plan_package_hash 算出 / LoopSpec 決定論的派生 / c3-prime dict 組み立て。全経路 fail-closed・冪等
   - Owner: agent / Risk: 中
   - 🚩: 同一入力 2 回で byte 同一出力（シナリオ 9）
3. **Step 2 (PR-1): arbiter.py 入力契約拡張**
   - Output: `plan_package` ブロック（plan_hash / source_sha / plan_package_hash / c1_evidence_ref / c2_evidence_ref / c1_verdict / c2_severity_summary）を production run で必須化。presence gate 新設（`gates.c1` 文字列は補助入力へ降格 = AC-4）。provenance へ plan_hash / source_sha / plan_package_hash + **reviewer 別 snapshot** 刻印（AC-5 / Refs: R-004）。decision に `approval_kind: c3-prime` 付与。**timestamp 注入パラメータ追加**（既定は now・テストで固定注入。TC-11 の byte 同一冪等に必須。Refs: R-010）
   - Owner: agent / Risk: 中
   - 🚩: 既存 test_arbiter.py 全 PASS（後方互換 — `plan_package` 無し入力は escalate であって crash しない）
4. **Step 3 (PR-1): テスト追加**
   - Output: `test_plan_package.py` 新設 + `test_arbiter.py` 拡張。9 シナリオ中 python 層で閉じる 1,2,3,4,5,8,9 をカバー。**シナリオ 5 は PR-1 の Unit（valid Plan Package + approve/approve → c3-prime dict/record 生成）として必ず PR-1 内で検証**し、PR-2 の受理チェーン E2E（TC-08b）と分離（Refs: R-005）。AC-3 は **C-1/C-2 × 欠落/FAIL/stale の表駆動 6 ケース**でカバー（Refs: R-002）
   - Owner: agent / Risk: 低
   - 🚩: 9 シナリオ ↔ テスト ID の対応表が test-cases.md と一致
5. **Step 4 (PR-1): docs / SKILL 更新**
   - Output: 00_concept §3.4 位相明記・C-3' 束縛定義 / loopspec「Plan Package 派生」節 / execution-runbook 手順改訂 / decision-table presence gate 行追加 / ai-loop-cycle SKILL ×2 + plugin sync / **`scripts/sync-plugin-plangate.sh` の明示列挙へ plan_package.py・test_plan_package.py を追加**（サイレント欠落防止。Refs: R-008）/ **`scripts/schema_mapping.py` を approval_kind 判別で c3-prime.schema.json へ dispatch**（schema-validate CI FAIL 回避。非 HO。Refs: R-006）
   - Owner: agent / Risk: 低
   - 🚩: sync 整合判定 = `sh scripts/sync-plugin-plangate.sh` 実行後 `git diff --quiet -- plugin/plangate/` が空（drift-check と同一判定）+ `.agents` ↔ `plugin` の cmp 一致。`.claude` はリンク書換（`_ai_loop_link_rewrite.py`）により意図的相違が正であり 3-way byte 同一は要求しない（Refs: R-007）
6. **Step 5: 🚩 PR-1 レビュー・マージ（C-4）**
   - Owner: human / Risk: -
7. **Step 6 (PR-2): HO patch 一式の生成**
   - Output: `c3-prime.schema.json` / `bin/plangate` validate+preflight 両対応 / `ai-loop-workflow.md` run 入口 TASK-XXXX 必須化（×2）/ CI 配線（python テスト + E2E fixture）の patch + dry-run 検証ログ
   - Owner: agent（生成・dry-run のみ）/ Risk: 高
   - 🚩: **Human patch 適用ゲート**（ho-apply-approval 方式・AI は適用しない）
8. **Step 7 (PR-2): E2E fixture**
   - Output: 一つのコマンドで実行できる E2E（valid Plan Package → arbiter → c3-prime → validate PASS → preflight PASS、および改変 → FAIL）。シナリオ 6,7 をカバー
   - Owner: agent（fixture 作成）+ human（CI yml 適用）/ Risk: 中
   - 🚩: CI 上で green を確認してから DoD 判定
9. **Step 8: 🚩 PR-2 レビュー・マージ（C-4）+ issue #872 / #870 への evidence link 記録**
   - Owner: human（マージ）+ agent（記録）/ Risk: 低

## Files / Components to Touch

**PR-1（非 HO・14）**: `scripts/ai-loop/plan_package.py`（新設）/ `scripts/ai-loop/test_plan_package.py`（新設）/ `scripts/ai-loop/arbiter.py` / `scripts/ai-loop/test_arbiter.py` / `scripts/schema_mapping.py`（Refs: R-006）/ `scripts/sync-plugin-plangate.sh`（Refs: R-008）/ `docs/workflows/ai-loop/c3-prime-contract.md`（新設）/ `docs/workflows/ai-loop/00_concept.md` / `docs/workflows/ai-loop/loopspec.md` / `docs/workflows/ai-loop/execution-runbook.md` / `docs/workflows/ai-loop/decision-table.md` / `.agents/skills/ai-loop-cycle/SKILL.md` / `.claude/skills/ai-loop-cycle/SKILL.md` / `plugin/plangate/skills/ai-loop-cycle/SKILL.md`（sync）

**PR-2（HO・Human 適用・4 + 非 HO fixture）**: `schemas/c3-prime.schema.json`（新設）/ `bin/plangate` / `.claude/commands/ai-loop-workflow.md` / `plugin/plangate/commands/ai-loop-workflow.md`（sync）/ E2E は **`tests/extras/ta-NN-*.sh` + `tests/fixtures/<name>/` の既存パターン**（run-tests.sh が自動 source するため `.github/workflows/test.yml` の touch 不要 = HO 面積縮小。Refs: R-013）

## Testing Strategy

- Unit: `python3 scripts/ai-loop/test_plan_package.py` / `python3 scripts/ai-loop/test_arbiter.py`（既存 + 新規、決定論・fail-closed・冪等）
- Integration: arbiter → c3-prime artifact → `bin/plangate validate TASK-XXXX` → exec preflight の受理チェーン（sandbox TASK fixture）
- E2E: 単一コマンド fixture（シナリオ 5→6→7 連鎖）を CI 登録
- Edge cases: artifact 0 byte / evidence FAIL 判定文字列 / hash 大文字小文字 / `plan_package` キー欠落 / 未知 `approval_kind` / legacy c3.json との共存
- Verification Automation: `python3 scripts/ai-loop/test_arbiter.py && python3 scripts/ai-loop/test_plan_package.py && sh tests/run-tests.sh && bin/plangate doctor`

## Loop Scope

単一 PBI（TASK-0872）の exec 内: python テスト失敗 → 自己修正の反復、および PR-1/PR-2 の直列進行。複数 PBI（#873/#874）へは跨がない。

## Stop Condition

変更が Files to Touch 内 / Verification Automation 全 PASS / 9 シナリオ対応テスト追加済み / legacy c3 経路の既存テスト無変更 PASS / 残課題（--verify-diff 未実装等）を handoff に明示。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。

## Replan Triggers（機械値）

- 変更ファイル数 > 22（想定 17 + 5）
- 同一検証コマンドの連続失敗 3 回
- 同一ファイルへの修正反復 3 回
- plan 外ディレクトリへの波及 1 件
- AC / Verification コマンドの変更検知時
- HO patch の Human 適用が得られない場合（PR-2 着手不可 → BLOCKED 化）

## Revert Policy

停止時、Scope 外へ波及した変更のみ `git restore -- <path>`（対象パス限定）。ブランケット stash 不使用。

Loop Attempts:（exec 中に追記）

## Risks & Mitigations

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| ファイル数実測 16〜17（見積もり比 1.0〜1.3 倍）で critical 圏 | Metrics Evidence で実測済み。PR 分割で各スライス ≤12 | Replan Trigger（>22）で停止・再分割 |
| HO patch 適用が Human 待ちで停滞 | PR-1 を先行完結させ PR-2 を独立化 | PR-2 を Deferred（BLOCKED: owner=human）で保持 |
| arbiter 入力契約変更で既存 run record / metrics.py と非互換 | 既存 test_arbiter.py 全 PASS + metrics.py は provenance 新フィールドを無視できることを確認 | 新フィールドは additive のみ・required 化は production run 判定内に限定 |
| #873 と契約の手戻り | Step 0 で c3-prime-contract.md を先行確定し #873 に共有 | 契約変更は両 issue 合意 + 本 plan Replan |
| CI drift-check が sync 同一 PR を強制し分割を破る | 分割設計で sync 対を各 PR 内に閉じる（PR-1=skills、PR-2=commands） | drift FAIL 時は当該 PR に sync commit 追加 |
| `bin/plangate` の grep/sed ベース c3 抽出が c3-prime JSON で誤動作 | preflight の python3 strict JSON 経路に寄せる patch 設計 + sandbox 検証 | 判別を `approval_kind` の python3 抽出のみで行い grep 経路は legacy 専用に維持 |

## Questions / Unknowns

- ~~E2E fixture の CI 登録形式~~ → **解消（Refs: R-013）**: `tests/extras/ta-NN-*.sh` + `tests/fixtures/` の既存パターンを採用（run-tests.sh 自動 source・test.yml touch 不要）。TA-30 が展開先 test_arbiter.py を CI 実行済みのため「python テスト完全未配線」の当初認識も訂正
- stale 判定の実装位置は validate（bin/plangate）+ plan_package.py の二重（防御多層）とするが、EH-3 hook への c3-prime 対応は本 PBI では行わない（EH-3 は top-level plan_hash のみ strict JSON 抽出のため c3-prime でも無変更で機能することを C-2 レーン B が実装確認済み・非退行）→ **C-3 で確認**
- C-1 evidence の「FAIL/stale」機械判定の粒度（#810 未実装のため review-self.md の判定行抽出 + mtime/hash 比較の暫定実装）

## Mode判定

**モード**: critical

**判定根拠**:
- 変更ファイル数: 16〜17（実測）→ critical（16+）
- 受入基準数: 11 → critical（11+）
- 変更種別: 承認境界の機械層（schema / bin/plangate / CI）+ HO 4 カテゴリ touch → 最低 high 強制、安全側で critical
- リスク: 承認 artifact の偽装・stale 見逃しは統制破壊に直結 → 極高
- **最終判定**: critical（定量 2 軸が critical。安全側不変条件に従う）
- 参考（C-3 判断材料）: plugin sync の byte-copy 2 件を除くと 14〜15 = high-risk 上限。**high-risk への人間オーバーライドは C-3 で選択可**（その場合 V-4 スキップ。ただし本 plan は critical 前提で V-4 を含む）
- `lite_eligible=false`（critical + HO touch + 新規設計あり — 3 条件すべてで不成立）/ autonomous APPROVE 不可・**人間 C-3 必須**
