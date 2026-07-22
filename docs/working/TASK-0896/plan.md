# EXECUTION PLAN — TASK-0896

> Issue: [#896](https://github.com/s977043/plangate/issues/896)（P1 / refactor）/ 関連 EPIC: #870（#873/#874 前の基盤整理）
> 入力: [`pbi-input.md`](./pbi-input.md)（PR #898 でレビュー済み・2026-07-22 実測裏取り）
> 作成: 2026-07-22（main 53879e1 で再実測済み）

## Goal

c3-prime 契約の検証規則（契約定数 / sha256・canonical JSON hash / reviewer snapshot 三つ組照合）を `scripts/ai-loop/c3_contract.py` 単一モジュールへ集約し、arbiter.py / plan_package.py / c3prime_verify.py の 3 消費者が import 参照する構造にする。**機能変更ゼロ・振る舞い不変**（判定結果 = decision / exit code / reject 不変）で、#873 delivery.py / #874 run_evidence.py が最初から共通層を import できる状態を作る。

## Constraints / Non-goals

- **Non-goals**（issue verbatim）: arbiter `plan_package_check`（入力ブロック検証）と c3prime_verify（record 検証）の**全統合**（premature abstraction 回避・共通化は定数 / hash / 三つ組照合の 3 点に限定）/ `c3-prime-contract.md` の規則変更（契約は不変）/ 機能追加・挙動変更
- **不変条件**: 偽造 record 群（test_c3prime_verify の手 mutate 14 系）の reject 不変（AC-7）/ 既存テスト 4 系全 green（AC-4: test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / run-tests 411）/ arbiter は共通層から **I/O なし関数のみ** import（AC-6）
- **非 HO**: 全対象は `scripts/ai-loop/**` + `scripts/sync-plugin-plangate.sh`（scripts/ 直下・hooks でない）。Hardening Override 9 カテゴリに非該当を確認済み
- **exec 経路**: EH-1 が `scripts/` 編集に plan+TASK 文脈を要求 → `PLANGATE_HOOK_TASK=TASK-0896` セッションでメイン直実装が正規（worker 委譲不可）
- **既存の検証強度非対称は保存する**（下記論点 2）: arbiter = snapshot 余剰キー許容（欠落・空値のみ検査）/ c3prime_verify = ちょうど 5 キー strict（#889 R2 medium 由来）。共通化で強度を「揃える」と挙動変更になるため、strictness は引数で保持

## Approach Overview

### 論点 1: 共通層の配置 — **案 A 採用（c3_contract.py 新設）**

| 案 | 内容 | 評価 |
|----|------|------|
| **A: `scripts/ai-loop/c3_contract.py` 新設** | 契約定数（REQUIRED_KEYS 系含む・Refs: R-001）+ I/O なし純関数（`canonical_hash` / `check_snapshot_trio`）+ I/O あり（`sha256_of_file`）を層分離して新設。3 消費者が import | ✅ 「契約の正本」を producer（plan_package）にも consumer（c3prime_verify）にも寄せない中立配置。AC-6 の I/O 層分離が module 構造で表現できる。#873/#874 が最初から import 可能 |
| B: plan_package.py へ集約 | check_evidence 前例の延長で既存 producer に定数・関数を寄せ、新モジュールを作らない | ❌ arbiter が producer モジュールを import する形になり「arbiter は入力 dict のみに依存」の設計と衝突（plan_package はファイル I/O が主責務で、I/O なし関数だけを選んで import する規律が module 境界で保証されない）。契約定数の正本が producer 側に置かれ責務が歪む |
| C: 共通化せず drift 検出テストのみ | 各実装に定数値同一 assert のテストを足し、実装は分散のまま | ❌ issue が共通化を明示要求。drift の検出はできても構造原因（改版時の多重修正）が残り、#873/#874 で消費者が 4〜5 に増える問題を解決しない |

### 論点 2: 三つ組照合の共通化範囲 — **「5 キー整合 + 三つ組一致」のコアのみ・strictness 引数で非対称保存**

| 案 | 内容 | 評価 |
|----|------|------|
| **A: コア共通化 + `strict_keys` 引数** | `check_snapshot_trio(container, reviewers, strict_keys)` が「snapshot 5 キーの存在（strict 時はちょうど 5 キー）/ 空値 / plan_hash・source_sha・plan_package_hash のトップレベル一致」を検査し**理由文字列リスト（空 = OK）**を返す。verdict 語彙・reviewer 独立性・AUTO_APPROVED 整合・**reviewers ちょうど 2 者（model_a/model_b・余剰 reject。Refs: R-005）**は c3prime_verify 固有で残置。呼び出し側の分岐制御（arbiter = tuple 部分成功 / c3prime = 即時 reject）も各自に残す | ✅ 実測した非対称（arbiter L514 = 欠落・空値のみ / c3prime L163 = set 一致 + L165 空値）を挙動不変で保存。**reviewer 集合も同様の意図的非対称（arbiter = 余剰 reviewer 許容 L510 / c3prime = 拒否 L158）= 保存対象**（Refs: R-005）。契約 AC-5 の核心規則（同一 hash を観た）は単一実装になる |
| B: strict へ完全統一 | 両経路とも「ちょうど 5 キー」に統一 | ❌ arbiter 側で今まで通過していた余剰キー付き入力が BLOCKED に変わる = 挙動変更（Non-goal 違反）。受理側だけ strict の現状は #889 R2 の意図的設計 |
| C: 三つ組照合は共通化しない（定数 + hash のみ） | 最小リスク構成 | ❌ AC-3 が「arbiter / c3prime_verify の両経路が同一実装を使う」を明示要求。三つ組照合こそ契約 AC-5 の核心で drift 許容度が最も低い |

### 論点 3: 返り値契約（pbi-input Step 0 確定事項の追認）

共通関数は**理由文字列リスト（空 = OK）を返し、判定・終端制御は呼び出し側**。arbiter はリスト非空なら `integrity_ok=False` + reason = 先頭（既存 tuple 契約へ変換）/ c3prime_verify はリスト非空なら `_fail(先頭)`。既存テストはメッセージ非検証（実測: test_c3prime_verify のメッセージ assert 0 件・test_arbiter は decision / priority 接頭のみで pp_reason 内部文言非 assert）のため、理由文言は共通関数側で単一化してよく、**判定結果ベースで振る舞い不変を確認**する。

**理由リストの順序・文言契約（Refs: R-004）**: 先頭要素が外部（arbiter reason / c3prime stderr）へ出るため、理由リストの**生成順序を検査順（キー集合 → 空値 → 三つ組不一致）で契約固定**し、test_c3_contract.py で順序を assert する。加えて外部可視文言の代表例（snapshot キー不一致 / 三つ組不一致の各 1 本）を回帰テストで固定し、以後の共通層改版で silent に変わらないようにする。

### コミット戦略（refactoring-guidance 準拠・1 コミット 1 種類）

(a) 定数集約 → (b) hash ヘルパー統合 → (c) 三つ組照合コア共通化 → (d) sync 列挙、の 4 コミット。各コミットで 4 系テスト green を維持し、差分検出時は該当コミットのみ局所 revert 可能にする。

## Metrics Evidence（#351 事前メトリクス検証）

| 項目 | AI 見積もり（pbi-input） | 実数 | 比率 | 判定 |
|------|------------------------|------|------|------|
| 変更ファイル数 | 9 | **9**（新設 2: c3_contract.py + test_c3_contract.py / 変更 3: arbiter.py / plan_package.py / c3prime_verify.py / sync 1: sync-plugin-plangate.sh / sync 再生成 2: plugin/.../c3_contract.py + test_c3_contract.py / CI 実行経路 1: tests/extras/ta-55 へ 1 行追記〔Refs: R-010〕。既存 python テスト変更 0 — test_c3prime_verify.py の定数参照はコメントのみ実測） | 1.0 | 採用 |
| AC 件数 | 8 | 8（issue verbatim） | 1.0 | 採用 |
| 重複実在（5 点） | 5 点 | **5 点全実在を行番号で確認**: 定数 = plan_package L27,82-83 + c3prime L28,32-33 / snapshot キー = arbiter L486 + c3prime L34 + plan_package 組み立て側 / file sha256 = plan_package L137 + c3prime L46 / canonical hash 式 = plan_package L148-153 + c3prime L151-152（式・separators まで同一。Refs: R-007） / 三つ組照合 = arbiter L495-528 + c3prime L155-171（**別実装・強度非対称あり**） | 1.0 | 採用 |

**取得コマンド**: `grep -n "VALID_DECISIONS\|SNAPSHOT_KEYS\|def _sha256\|json.dumps" scripts/ai-loop/{arbiter,plan_package,c3prime_verify}.py`（2026-07-22 main 53879e1）

**判定理由**: 比率 1.0（1〜3 倍の範囲内）で採用。c3prime_verify = **承認境界の受理器**touch はセキュリティ関連（mode-classification 例外「セキュリティ関連 → 最低中」+ 定性「受理器の検証強度」）であり、pbi-input 確定の **high-risk を維持**。（C-2 確定反映 R-010 で実数 8→9: ta-55 への CI 実行経路 1 行追記を追加）

**追加実測（sync / bundled）**: bundled 展開先（plugin/plangate/skills/ai-loop-cycle/scripts/）は既に 8 本列挙済み。sync 列挙は copy for リスト（L308）+ delete 保護 case（L318）の **2 箇所**へ c3_contract.py / test_c3_contract.py を追加。ta-30 TC-07 は `>= 2` の下限判定のため**期待値変更不要**（10 本になっても PASS）。ta-30 TC-08（bundled test_arbiter.py 自立実行）は arbiter が c3_contract を import しても同 dir に sync されるため成立 — Step 4 で実測確認。

## Work Breakdown (Steps)

1. **Step 0: ベースライン確立 + API 契約固定**
   - Output: 4 系テスト全 green の実測記録（`evidence/test-runs/step0-baseline.log`: test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / run-tests 411）+ c3_contract.py の公開 API docstring（定数一覧 / `canonical_hash(obj) -> str` / `check_snapshot_trio(container, reviewers, strict_keys) -> list[str]` / `sha256_of_file(path) -> str` の層区分明記）
   - Owner: agent / Risk: 低
   - 🚩 チェックポイント: ベースライン数値が AC-4 の期待値と一致しているか（不一致なら即停止し原因調査 — 別 PBI の回帰を巻き込まない）
   - rollback: 不要（読取・記録のみ）
2. **Step 1: 定数集約（コミット a）**
   - Output: `c3_contract.py` 新設 — 定数は **ARTIFACTS / VALID_DECISIONS / VALID_VERDICTS / SNAPSHOT_KEYS + REQUIRED_KEYS 系（record 用 REQUIRED_KEYS・OPTIONAL_KEYS〔c3prime L36-43〕/ 入力ブロック用 PLAN_PACKAGE_REQUIRED_KEYS〔arbiter L478〕。重複はないが AC-1 verbatim の単一モジュール定義に含める。Refs: R-001）** + 3 消費者の定数 import 置換（arbiter は SNAPSHOT_REQUIRED_KEYS = c3_contract.SNAPSHOT_KEYS の別名参照可・値 byte 同一を assert する移行テスト付き）+ `test_c3_contract.py` 新設（定数値の契約固定テスト）
   - **import 解決の確定（Refs: R-008）**: arbiter.py 本体に sys.path 操作は追加しない — CLI 直実行時は sys.path[0]=script dir で同 dir import が解決し、test 経由は test_arbiter.py L15 の既存 insert で解決する
   - Owner: agent / Risk: 低
   - 🚩: 4 系テスト不変 green + 定数値 byte 同一 assert PASS
   - rollback: `git revert <コミット a>`（単独 revert 可能な独立コミット）
3. **Step 2: hash ヘルパー統合（コミット b）**
   - Output: `sha256_of_file` / `canonical_hash` を c3_contract.py へ追加し、plan_package.py `_sha256_of` L137 / c3prime_verify.py `_sha256` L46 / 両者の canonical JSON hash 式（json.dumps sort_keys + separators）を置換。test_c3_contract.py に境界値テスト追加（空 dict / キー順序非依存 / 1 byte 改変検出）
   - Owner: agent / Risk: 中
   - 🚩: TC-09 系（1 byte 改変検出）+ 冪等テスト不変 PASS
   - rollback: `git revert <コミット b>`
4. **Step 3: 三つ組照合コア共通化（コミット c）**
   - Output: `check_snapshot_trio(container, reviewers, strict_keys)` を c3_contract.py へ追加（理由文字列リスト返却・I/O なし・**生成順序 = 検査順で契約固定 + 代表文言回帰テスト**。Refs: R-004）。arbiter `plan_package_check` は snapshot 検査部をこれで置換し tuple 変換（リスト非空 → `(True, False, 先頭)`）、c3prime_verify は strict_keys=True で呼び `_fail(先頭)`。残置（Refs: R-005/R-006）: c3prime 側 = verdict 語彙・evidence_ref 独立性・AUTO_APPROVED 整合・**reviewers ちょうど 2 者検査（L158）** / arbiter 側 = plan_package 構造検査（PLAN_PACKAGE_REQUIRED_KEYS L503）・**source_sha vs target_sha 照合（L523-527・check_snapshot_trio は target_sha を受けない）**
   - Owner: agent / Risk: 高（承認境界の核心規則）
   - 🚩: snapshot 不一致 → BLOCKED（arbiter）/ reject（c3prime）の判定結果が両経路不変 + 偽造 14 パターン reject 不変 + **非対称保存の負側テスト**（余剰キー付き snapshot: arbiter = 通過 / c3prime = reject を test_c3_contract.py で両側固定）
   - rollback: `git revert <コミット c>`
5. **Step 4: sync 配布整合 + CI 実行経路（コミット d）**
   - Output: sync-plugin-plangate.sh の copy for リスト（L308 付近）+ delete 保護 case（L318 付近）へ c3_contract.py / test_c3_contract.py 追加 → `sh scripts/sync-plugin-plangate.sh` 実行 → plugin 再生成。**tests/extras/ta-55 へ `python3 scripts/ai-loop/test_c3_contract.py` 実行 1 行を追記**（新設テストの CI 実行経路・非 HO。Refs: R-010）
   - **順序制約（Refs: R-009）**: コミット a〜c の途中で sync を実行しない（逆転禁止 — copy リスト未追加のまま新 arbiter.py だけが同期されると bundled 側 c3_contract 欠落で ta-30 TC-08 が FAIL する）
   - Owner: agent / Risk: 低
   - 🚩: sync 2 回目 no-op（`git diff --quiet -- plugin/plangate/`）+ ta-30 実測 PASS（TC-07 scripts >= 2 / TC-08 bundled 自立 / TC-09 up-to-date skip）
   - rollback: `git revert <コミット d>` + sync 再実行
6. **Step 5: 検証総括 + 敵対レビュー**
   - Output: 4 系テスト + run-tests 全 green の最終実測（`evidence/test-runs/`）→ **複数エージェント敵対レビュー 1 ラウンド以上**（受理器 touch のため。観点: 共通化で検証強度が weakening していないか / strict_keys 既定値の fail-open 余地 / import 失敗時の fail-closed）→ disposition 記録（AC-8）
   - Owner: agent / Risk: 中
   - 🚩: 敵対レビューで major 以上が出た場合は是正 → 再レビュー（収束まで）
   - rollback: 指摘是正コミットは各 Step の revert 単位に従う
7. **Step 6: 🚩 PR 作成 → C-4（Human）**
   - Owner: human（マージ）/ Risk: -

## Files / Components to Touch

新設 2: `scripts/ai-loop/c3_contract.py` / `scripts/ai-loop/test_c3_contract.py`
変更 3: `scripts/ai-loop/arbiter.py` / `scripts/ai-loop/plan_package.py` / `scripts/ai-loop/c3prime_verify.py`
sync 1: `scripts/sync-plugin-plangate.sh`
sync 再生成 2: `plugin/plangate/skills/ai-loop-cycle/scripts/c3_contract.py` / 同 `test_c3_contract.py`（+ 既存 8 本の byte 同一維持）
CI 実行経路 1: `tests/extras/ta-55-c3prime-accept.sh`（test_c3_contract.py 実行 1 行追記。Refs: R-010）

## Testing Strategy

- Unit: `python3 scripts/ai-loop/test_c3_contract.py`（新設: 定数契約固定〔REQUIRED_KEYS 系含む〕/ hash 境界値 / trio 理由リスト境界値 + **順序 assert + 代表文言回帰**〔R-004〕/ strict・lenient 非対称の両側固定 / **I/O 封じ純粋性テスト**〔R-003: builtins.open 等を封じて実行〕）+ 既存 3 系不変
- Integration: 既存 test_c3prime_verify.py（偽造 14 パターン = 受理器統合テスト・**残置**、pbi-input Unknowns 確定どおり test_c3_contract へ移さない）+ test_arbiter.py（plan_package_check 経路）
- E2E: ta-30（bundled 自立）+ ta-55（c3-prime 受理チェーン + test_c3_contract 実行追記）+ run-tests 既存 411 全 green（R-010 追記分のテスト数加算は許容・既存期待値の変更はゼロ）
- Edge cases: 余剰キー付き snapshot（非対称の両側）/ 空 reviewers / トップレベル値 None / canonical hash のキー順序非依存 / 1 byte 改変検出
- Verification Automation: `python3 scripts/ai-loop/test_c3_contract.py && python3 scripts/ai-loop/test_arbiter.py && python3 scripts/ai-loop/test_plan_package.py && python3 scripts/ai-loop/test_c3prime_verify.py && sh tests/run-tests.sh`

## Loop Scope

単一 PBI（TASK-0896）の exec 内: 各コミット単位の「置換 → 4 系テスト検証 → 失敗時は該当コミット revert」の反復。#873/#874 へは跨がない。

## Stop Condition

変更が Files to Touch 内 / Verification Automation 全 PASS / AC-1〜8 充足 / 偽造 14 パターン reject 不変の実測記録あり / 敵対レビュー disposition 記録済み。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。

## Replan Triggers

- 変更ファイル数 > 14（= 想定 9 + 5）
- 同一検証コマンドの連続失敗 3 回
- 同一ファイルへの修正反復 3 回
- plan 外ディレクトリへの波及 1 件（`scripts/ai-loop/` / `scripts/sync-plugin-plangate.sh` / `plugin/plangate/skills/ai-loop-cycle/scripts/` / `docs/working/TASK-0896/` 以外）
- 既存テストの期待値変更が必要になった時点（= 振る舞い不変の前提崩壊 → 即 Replan。期待値を書き換えて通すことは禁止）
- AC / Verification コマンドの変更検知時

## Revert Policy

停止時、Scope 外へ波及した変更のみを対象パス限定で `git restore -- <path>`。コミットは 1 コミット 1 種類のため `git revert <sha>` で局所巻き戻し可。ブランケットな `git stash` は使わない。

Loop Attempts:（exec 中に追記）
- attempt: / changed: / verification: / result: / next decision:

## Risks & Mitigations

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 共通化で受理器の検証強度が意図せず変わる | Step 0 ベースライン + 偽造 14 パターン + 411 テストを各コミットで実測。非対称保存の負側テストを新規固定 | 該当コミットを局所 revert |
| 三つ組照合の非対称（arbiter 余剰許容 / c3prime strict）を「統一」してしまう | 論点 2 で strict_keys 引数保存を設計確定。負側テストで両側固定 | strict へ寄った場合 arbiter 既存テストが検出（余剰キー入力の decision 変化） |
| #896 が #873（P0）着手を遅延させる | **C-3 論点 1**（人間確定）: #896 先行 or #873 と並行。並行時の重複は c3prime_verify の import 行のみ | 並行選択時は c3_contract 先行 merge → #873 が rebase |
| ta-30 bundled 自立が import 追加で壊れる | Step 4 で ta-30 実測（消費者側の既存 `sys.path.insert` パターン維持・c3_contract 側に I/O・path 操作を持ち込まない） | import fallback は消費者側 sys.path パターンで担保 |
| メッセージ文言の silent 変化 | 既存テストが decision / exit code のみ検証である実測に基づき、判定結果ベースで不変確認（論点 3）。文言は共通関数由来に単一化されることを PR 説明に明記 | 理由コード enum + 呼び出し側マッピング（V2 候補） |
| 理由リスト先頭要素の外部露出で文言・優先順が silent に変わる | R-004 対応: 生成順序を検査順で契約固定 + test_c3_contract.py で順序 assert + 代表文言回帰テスト | 順序変更が必要になったら契約改版として明示コミット |

## Questions / Unknowns

- ~~check_snapshot_trio の返り値契約~~ → 確定（論点 3・理由文字列リスト）
- ~~test_c3_contract.py の粒度~~ → 確定（純関数境界値のみ・偽造 14 は test_c3prime_verify 残置）
- **C-3 論点 1（人間確定・Open）**: EPIC #870 実装順への位置づけ — (a) #873 前に #896 逐次先行（P0 遅延を許容）or (b) #873 と並行（別セッション・c3_contract 先行 merge で rebase）。pbi-input Notes verbatim のとおり決定権 = 人間
- **C-3 論点 2（Open）**: EPIC #870 本体 issue へ「#873 前提整理として #896」を追記する issue コメントの要否（位置づけ正式化の記録先）

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 9 → high（6-15）
- 受入基準数: 8 → high（6-10）
- 変更種別: 承認境界の受理器（c3prime_verify）touch を含むリファクタ → セキュリティ関連「最低中」を上回る
- リスク: 検証強度の silent 変化リスク → 高
- **最終判定**: high-risk（pbi-input 確定値を維持。Metrics 比率 1.0 = 範囲内で採用）

**lite_eligible**: false（high-risk・承認境界の受理器 touch・新規モジュール設計あり）
**autonomous APPROVE**: 不可（working-context「C-3 Autonomous APPROVE 判定マトリクス」の Mode = high-risk → ❌ 人間 C-3 必須）
