# PBI INPUT PACKAGE — TASK-0896

> Issue: [#896](https://github.com/s977043/plangate/issues/896)（P1 / enhancement / area:workflow）
> 関連 EPIC: [#870](https://github.com/s977043/plangate/issues/870)（#873/#874 実装前の基盤整理として位置づけ）
> 作成: 2026-07-22（重複を実測裏取り済み・main 3ec2e24）

## Context / Why

c3-prime 契約（#872 で確定・PR #885〜#889/#895 で実装完了）の検証規則が `scripts/ai-loop/` の 3 ファイルに分散実装されている。#873（delivery.py）/#874（run_evidence.py）で同規則の消費者が 4〜5 に増える前に共通層へ集約する（「3 回目に初めて共通化」基準は充足済み）。分散のままだと契約改版時の実装間 drift で**承認境界の検証強度が silent に割れる**。

実測（2026-07-22・main 3ec2e24）:

| 重複 | 箇所 | 多重度 |
|------|------|--------|
| 定数（`VALID_DECISIONS`/`VALID_VERDICTS`/`ARTIFACTS`）| plan_package.py L27,82-83 + c3prime_verify.py L28,32-33 | 2 重 |
| snapshot キー定義 | arbiter.py `SNAPSHOT_REQUIRED_KEYS`(L486) + c3prime_verify.py `SNAPSHOT_KEYS`(L34) + plan_package.py 組み立て側(L294-303) | **3 重** |
| file sha256 ヘルパー | plan_package.py `_sha256_of`(L137) + c3prime_verify.py `_sha256`(L46) | 2 重 |
| canonical JSON hash 式（`json.dumps(sort_keys)` の sha256）| plan_package.py L148-153 + c3prime_verify.py L150-152 | 2 重 |
| **snapshot 三つ組照合（#872 契約 AC-5「reviewer が同一 hash を観た」の核心規則）** | arbiter.py `plan_package_check`(L495) + c3prime_verify.py(L155-171) | 2 重（**別実装**）|

前例: `check_evidence` は既に plan_package.py へ集約済み（c3prime_verify.py L26 が import）— その延長。

## What（Scope）

### In scope

1. **`scripts/ai-loop/c3_contract.py` 新設**（非 HO）: 契約定数（ARTIFACTS / VALID_DECISIONS / VALID_VERDICTS / SNAPSHOT_KEYS / REQUIRED_KEYS 系）+ **I/O なし純関数**（`canonical_hash(dict)` / `check_snapshot_trio(container, reviewers)`）+ **I/O あり**（`sha256_of_file`）を層分離して定義。`test_c3_contract.py` 新設
2. **3 消費者の import 置換**（1 コミット 1 種類・refactoring-guidance 準拠）: (a) 定数 → (b) hash → (c) 三つ組照合 の順で arbiter.py / plan_package.py / c3prime_verify.py を置換
3. **sync 配布整合**: `sync-plugin-plangate.sh` の copy + delete 保護の両列挙へ `c3_contract.py` / `test_c3_contract.py` 追加（R-008 教訓）。ta-30 bundled 展開先の自立 PASS
4. **受理側の敵対レビュー**: c3prime_verify（承認境界の受理器）touch のため複数エージェント敵対レビュー 1 ラウンド以上（#889 教訓: 受理側は 1 ラウンドでは表層しか出ない）

### Out of scope（issue Non-goals verbatim）

- arbiter `plan_package_check`（入力ブロック検証）と c3prime_verify（record 検証）の**全統合**（対象が異なる — premature abstraction 回避。共通化は定数・hash・三つ組照合の 3 点に限定）
- `c3-prime-contract.md` の規則変更（実装集約のみ・契約は不変）
- 機能追加・挙動変更

## 受入基準（issue #896 verbatim・8 項目）

- AC-1: 契約定数（ARTIFACTS / VALID_DECISIONS / VALID_VERDICTS / SNAPSHOT_KEYS / REQUIRED_KEYS 系）が単一モジュール定義で、3 消費者が import 参照する
- AC-2: sha256 / canonical JSON hash が単一実装になる
- AC-3: snapshot 三つ組照合が I/O なし共通純関数になり、arbiter / c3prime_verify の両経路が同一実装を使う
- AC-4: 既存テスト全 green（振る舞い不変: test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / run-tests 411）
- AC-5: sync 列挙（copy + delete 保護）に新モジュールが追加され、sync 2 回目 no-op + ta-30 bundled 自立 PASS
- AC-6: arbiter は `c3_contract` の **I/O あり関数（`sha256_of_file`）を import / call しない**（arbiter は既存どおり ho-paths.md 読取・stdin 読取の自前 I/O は持つが、共通層からは I/O なし関数〔定数・`canonical_hash`・`check_snapshot_trio`〕のみを取り込む）
- AC-7: 偽造 record 群（test_c3prime_verify の手 mutate 系）の reject が不変
- AC-8: 敵対レビュー 1 ラウンド以上の disposition 記録

## 変更順序（refactoring-guidance 準拠・各ステップでグリーン維持）

| Step | 変更 | テスト確認項目 |
|------|------|---------------|
| 0 | ベースライン確立（4 系全 green の記録）+ **共通関数の返り値契約を先に確定**（下記 Unknowns 解決）| test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / run-tests 411 |
| 1 | 定数集約（c3_contract.py 新設・import 置換）| 定数値 byte 同一 assert + 全テスト不変 pass |
| 2 | hash ヘルパー統合（file sha256 + canonical JSON hash）| TC-09 系（1 byte 改変検出）+ 冪等テスト不変 |
| 3 | 三つ組照合の**5 キー整合ロジックのみ**共通純関数化（呼び出し側の分岐制御 = arbiter の tuple 部分成功 / c3prime_verify の即時 reject は各自に残す）| snapshot 不一致→BLOCKED（arbiter）/ reject（c3prime）の**判定結果**が両経路で不変 + 偽造 14 パターン不変。**メッセージ既存テストは decision/exit code のみ検証（実測: test_c3prime_verify のメッセージ assert 0 件）→ 判定結果ベースで振る舞い不変を確認** |
| 4 | sync 列挙 + ta-30 確認 | sync 2 回目 no-op / `git diff --quiet plugin/` / ta-30 pass |
| 5 | 敵対レビュー + disposition | 偽造 record 群 reject 不変の実測 |

## Notes from Refinement

- **非 HO・AI 実装可**: `scripts/ai-loop/**` は HO 対象外（PoC 隔離）。ただし **exec は EH-1 の plan+TASK 文脈要求により `PLANGATE_HOOK_TASK=TASK-0896` 専用セッションでメイン直実装が正規**（worker 委譲不可）
- **arbiter の設計原則維持**: arbiter は自前で ho-paths.md（L209 `read_text`）と stdin（L1179）を読むが、**裁定ロジックは入力 dict のみに依存**する純関数構成。c3_contract は I/O なし関数（定数・canonical_hash・check_snapshot_trio）と I/O あり（sha256_of_file）を層分離し、**arbiter は共通層から I/O なし関数のみ import**（arbiter に新たなファイル読取依存を持ち込まない）
- **bundled 自立の制約**: ta-30 が plugin 展開先での自立実行を検証 → import は同一ディレクトリ前提（`sys.path.insert` の既存パターン踏襲）
- **EPIC #870 への位置づけ（要正式化）**: #896 は EPIC #870 の Child Issues / 実装順序（#871→#872→#873→#874）に**含まれない P1 割込み**。#873（P0）着手前に #896 を挟むと優先度が逆転する。**位置づけの正式化を Step 0 前提**とする — (a) EPIC #870 本体の実装順に「#873 前提整理として #896（P1）」を追記する issue コメント、または (b) #896 を #873 と**並行**（別セッション・別ファイル集合）にして P0 を待たせない、のいずれかを **C-3 で確定**（決定権 = 人間）
- **タイミング**: #873/#874 の exec **前**に共通層を merge できれば delivery.py / run_evidence.py が最初から import できて最効果。ただし #873 は P0 のため、**#896 を P0 の前段ブロッカーにしない**（下記 Risks で遅延を定量化）

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 共通化で検証強度が意図せず変わる（受理器の挙動変化）| Step 0 ベースライン + 偽造 14 パターン + 411 テスト不変を各ステップで実測 | 差分検出時は該当ステップを revert（1 コミット 1 種類のため局所 revert 可）|
| **#896（P1）を #873（P0）の前に置くと P0 着手が遅延**（#896 は high-risk + 敵対レビュー 1 ラウンド以上を含み、完了まで数日規模）| 実装順は **C-3 で人間が確定**（#896 先行 or #873 と並行）。並行を選ぶ場合 c3_contract を先行 merge → 他が rebase | **P0 を待たせない場合は #873 を先行着手し、#896 は #873 exec と別セッションで並行**（触るファイルが重複しないため両立可能。#873=delivery.py 新設 / #896=既存 3 ファイルの import 置換）。逐次固定で P0 を待たせる判断は C-3 で明示承認した場合のみ |
| #873/#874 exec と #896 が同一ファイルを触りコンフリクト | 触る集合を確認: #873=delivery.py 新設（既存非改変）/ #896=arbiter/plan_package/c3prime_verify の import 行 → **重複は c3prime_verify のみ**（#873 が import 再利用する箇所）| c3_contract を先行 merge し #873 が rebase。または #896 完了後に #873 着手 |
| ta-30 bundled 自立が import 追加で壊れる | Step 4 で ta-30 実測 | import fallback（同 dir 探索）を c3_contract 側でなく消費者側の既存 sys.path パターンで担保 |
| **既存テストが decision/exit code のみ検証でメッセージ非検証**（実測: test_c3prime_verify のメッセージ assert 0 件・test_arbiter は decision/priority のみ）→ 共通化で理由文言が silent に変わっても検出されない | 共通関数は**理由文字列リスト**を返し呼び出し側で既存文言を組む契約に確定（Step 0）。判定結果（BLOCKED/reject/exit code）は既存テストが検証済みで不変を担保 | 理由コード enum + 呼び出し側マッピングで文言も固定。メッセージ回帰テストを Step 3 で追加 |

### Unknowns

- ~~`check_snapshot_trio` の返り値契約~~ → **Step 0 で確定（本 pbi で方針固定）**: 共通関数は**理由文字列リスト（空=OK）を返し、判定・終端制御は呼び出し側**（arbiter は tuple 部分成功へ変換 = リスト非空なら integrity_ok=False + reason=先頭 / c3prime_verify はリスト非空なら `_fail(先頭)`）。両呼び出し側の変換コード（各 5〜10 行）を plan の Work Breakdown に Step として計上
- test_c3_contract.py の粒度: **偽造 14 パターンは test_c3prime_verify.py に残置**（受理器の統合テスト）、test_c3_contract.py は**純関数の境界値**（キー欠落・型不一致・空値・三つ組不一致）のみを対象 → plan で最終確認

### Assumptions

- touch 見込み 9 ファイル: 新設 2（c3_contract + test）+ 変更 3（arbiter/plan_package/c3prime_verify）+ test 変更最大 3 + sync 1
- **Mode: high-risk**（定量: 変更ファイル数 9 = 6-15「高」・受入基準数 8 = 6-10「高」。定性: 受理器 touch = セキュリティ関連で「最低中」を上回る）。**人間 C-3 レビュー必須**（mode-classification フェーズ適用マトリクスで high-risk の C-3 は ○=実行）。**autonomous APPROVE 不可**の根拠は working-context.md「C-3 Autonomous APPROVE 判定マトリクス」の `Mode = high-risk → ❌ 不可（人間 C-3 必須）`（mode-classification 側でなくこちらが autonomous 可否の正本）
- 機能変更ゼロ・`refactor:` プレフィックス PR・振る舞い不変
