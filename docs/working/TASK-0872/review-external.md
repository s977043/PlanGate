# C-2 外部レビュー結果 — TASK-0872（追記専用集約）

> 実施: 2026-07-20 / 2 レーン並列（責務契約: review-principles.md §7-bis）
> レーン A: 設計妥当性（Codex / plan・todo・test-cases・pbi-input のみ読む）→ **reject**（major 5）
> レーン B: コードベース整合（Claude subagent / 既存実装照合）→ **conditional**（major 3・minor 4・info 2）
> オーガナイザー裏取り: R-006 / R-007 / R-008 / R-013 は一次ソース実測で確認済み（2026-07-20）

## 指摘一覧

| ID | lane | severity | 対象 | 指摘（要約） | 採否 |
|----|------|----------|------|-------------|------|
| R-001 | A | major | test-cases TC-01 / todo T-16 | AC-1 のテストが plan_package.py の task_id 未指定に留まり、正式入口（ai-loop-workflow.md）レベルの検証がない。自由文 `run <説明>` が入口を通過しても TC-01 は成功し得る | **採用** |
| R-002 | A | major | test-cases TC-03/TC-04 | AC-3 の C-2 単独の欠落・FAIL・stale ケースが未カバー。C-1/C-2 × 3 異常の表駆動テストが必要 | **採用** |
| R-003 | A | major | pbi-input In scope 9 / plan 論点3 / TC-09 / EC-6 | source SHA 変更の stale 化が契約未確定（EC-6「警告 or fail」は fail-closed と両立しない）。`source_sha != 対象 SHA` を BLOCK と契約固定し E2E 追加 | **採用** |
| R-004 | A | major | plan Step 0/Step 2 / TC-06 | AC-5 を支える reviewer 別 record（model_a/b が観た plan_hash / source_sha の snapshot）の契約が未定義。#873 共有契約の成立条件が判断不能 | **採用** |
| R-005 | A | major | plan Step 3 / TC-08 / todo T-3〜T-13 | シナリオ 5 を PR-1 でカバーと明記しながら対応 TC-08 が PR-2 の E2E。PR-1 に c3-prime 生成 Unit がなく H-2 マージ時点で未検証 | **採用** |
| R-006 | B | major | scripts/schema_mapping.py:21 + schema-validate CI | `"c3.json" → "c3-approval.schema.json"` の無条件マッピングにより、c3-prime を approvals/c3.json に書くと Schema Validate CI が FAIL 確定。Files to Touch に schema_mapping.py が無い | **採用**（L21 実測確認済） |
| R-007 | B | major | plan Step 4 / todo T-12 | 「3 箇所 byte 同一」は現行 sync 設計と矛盾（実測: `.agents`==`plugin`・`.claude` は docs リンク版で意図的相違、`_ai_loop_link_rewrite.py` が書換）。cmp 3-way は必ず FAIL | **採用**（cmp 実測確認済） |
| R-008 | B | major | scripts/sync-plugin-plangate.sh:306 | sync は arbiter/test_arbiter/metrics/test_metrics の明示列挙のみ。plan_package.py は plugin 配布物へ同梱されずサイレント欠落 | **採用**（L306 実測確認済） |
| R-009 | B | minor | bin/plangate:970,981 | validate の grep/sed 抽出対策として、c3-prime 契約に serialization 制約（トップレベル各キー 1 回・json.dumps indent=2）を明記すべき | **採用** |
| R-010 | B | minor | arbiter.py:710 | `build_provenance` は `datetime.now()` 直刻印で注入口なし。TC-11 の byte 同一には timestamp 注入パラメータが必要 | **採用** |
| R-011 | B | minor | arbiter.py:640,703 | 既存 `target_sha` と新設 `source_sha` の意味重複。契約で関係を定義すべき | **採用** |
| R-012 | B | minor | loopspec.md §3 | LoopSpec 必須 15+ フィールドは 4 成果物から機械導出不能なものを含む（I-4 fail-closed で受理拒否）。派生元 or 固定既定値の全数マッピング表が契約に必要 | **採用** |
| R-013 | B | info | tests/run-tests.sh + ta-30:86 | 「CI python テスト未配線」は不正確 — TA-30 TC-08 が展開先 test_arbiter.py を CI 実行済み。E2E は `tests/extras/ta-NN-*.sh` + `tests/fixtures/` パターンなら **test.yml（HO）touch 不要** | **採用**（ta-30 実測確認済。PR-2 の HO 面積縮小） |
| R-014 | B | info | schemas/c3-approval.schema.json | 案 B（新 schema 新設）の根拠は実体と整合、案 C 却下理由も妥当 | 記録のみ |

## 監査表（追記専用・squash/rebase 耐性）

| ID | status | reflected_in(commit) | notes |
|----|--------|---------------------|-------|
| R-001 | reflected | (plan 正式化 PR にて Refs: R-001) | TC-01 を入口レベル + plan_package 二層検証に改訂 |
| R-002 | reflected | (同上 Refs: R-002) | TC-03/04 を C-1/C-2 × 欠落/FAIL/stale の表駆動 6 ケースへ |
| R-003 | reflected | (同上 Refs: R-003) | source_sha 不一致 = BLOCK に契約固定・EC-6 を確定化・TC-09 に source SHA 系追加 |
| R-004 | reflected | (同上 Refs: R-004) | Step 0 契約に reviewer snapshot（per-model plan_hash/source_sha/判定/evidence ref）必須化 |
| R-005 | reflected | (同上 Refs: R-005) | TC-08 を TC-08a（PR-1 Unit）/ TC-08b（PR-2 E2E）に分離・todo T-7/T-9 に反映 |
| R-006 | reflected | (同上 Refs: R-006) | schema_mapping.py（非 HO）を Files to Touch へ追加・TC-13 新設（schema-validate green） |
| R-007 | reflected | (同上 Refs: R-007) | T-12 を「sync 実行 + git diff --quiet plugin/ + agents↔plugin cmp」判定へ修正 |
| R-008 | reflected | (同上 Refs: R-008) | sync-plugin-plangate.sh を Files to Touch へ追加・TA-30 に plan_package テスト追加 |
| R-009 | reflected | (同上 Refs: R-009) | c3-prime-contract.md 要件に serialization 制約を明記 |
| R-010 | reflected | (同上 Refs: R-010) | Step 2 Output に timestamp 注入を明記 |
| R-011 | reflected | (同上 Refs: R-011) | 契約要件に target_sha/source_sha 関係定義を追加 |
| R-012 | reflected | (同上 Refs: R-012) | 契約要件に LoopSpec 必須フィールド全数マッピング表を追加 |
| R-013 | reflected | (同上 Refs: R-013) | E2E は extras パターン第一候補・CI 前提記述修正・Unknown 1 件解消 |
| R-014 | recorded | - | 反映不要（設計裏付けの確認） |

## 敵対的レビュー（PR #886 / 2026-07-20・bot quota 不在の代替 1 本・全指摘実測再現）

> レーン C（敵対的・fail-open/契約乖離/priority 順序/偽装攻撃/metrics 回帰/schema dispatch の 6 観点）→ **approve**（重大 0）

| ID | severity | 対象 | 指摘（要約） | 採否 |
|----|----------|------|-------------|------|
| R-015 | minor | schema_mapping.py + schemas/ | PR-1〜PR-2 窓で c3-prime.schema.json 不在 → validate-schemas が SKIP（latent fail-open。実害ゼロ = c3.json writer 配線未着地） | **採用**（PR-2 で schema 先行着地 + approval_kind==c3-prime かつ schema 不在は SKIP でなく FAIL 化） |
| R-016 | minor | arbiter.py priority 1.6 | production=true + plan_package 欠落 + reject-reject が従来 BLOCKED → HUMAN_ESCALATED に変化（両者とも非承認で安全側・誤設定入力のみ） | 記録のみ（理由文への verdict 併記は過剰と判断・実害小） |
| R-017 | minor | plan_package.py `_PATH_RE` | Files to Touch 抽出が `../../etc/passwd` 等も allowed_paths に拾う（plan.md は C-1/C-2 済み正本のため実害低・ファイル読み取りには不使用） | V2 候補（`..`/URL スキーム除外の sanitize。handoff に記載） |
| R-018 | info | c3-prime-contract.md §7 | #873 delivery.py が arbiter decision を再検証なしに信頼しない旨（trust boundary の fail-closed 担保）を明示すべき | **採用**（PR-2 で §7 に 1 文追記） |

## 複数エージェントレビュー（PR #888 / 2026-07-20・Codex ×2 + Sonnet 独立）

> レーン: Codex A（conditional）/ Codex B（reject・ただし reject 理由は PR-2 スコープの受理側未実装＝本 PR 対象外）/ Sonnet 独立（approve）。分裂の争点は事実問題のためオーガナイザーが全件一次ソースで再現裁定。

| ID | severity | 対象 | 指摘 | 裁定・採否 |
|----|----------|------|------|-----------|
| R-019 | major | plan_package.py build_c3_prime | decision の 3 値 allowlist 検証なし（`decision="unknown"` で record 生成）— 両 Codex 一致 | **採用**（再現 CONFIRMED。`VALID_DECISIONS` allowlist + verdict allowlist + `fullmatch` 化） |
| R-020 | major | patches/c3-prime.schema.json | `AUTO_APPROVED` + reject×2 が schema を通過（cross-field 制約なし）— Codex A | **採用**（再現 CONFIRMED。`allOf`/`if`/`then` で AUTO_APPROVED 時の両 verdict を const:approve に固定） |
| R-021 | major | plan_package.py build_c3_prime | evidence 再読の TOCTOU で `#None` を含む record を返す— Codex B 新規バグ | **採用**（再現 CONFIRMED。再読エラーを fail-closed で raise） |
| R-022 | major | tests/extras/ta-05 | F-8（schema 不在→ERROR）の負経路回帰テストが無い（#887 close 条件未充足）— Codex A | **採用**（ta-05 に c3-prime + schema 未配置 → 非ゼロ終了の回帰テスト追加・実測 PASS） |
| R-023 | minor | plan_package.py `_read_evidence_marker` | プレフィックス一致だが文法外の追記行が fail-closed でない— Codex A | **採用**（プレフィックス行数 == 完全一致数を要求・負側テスト追加） |
| R-024 | major(スコープ外) | bin/plangate | c3-prime の strict JSON 受理分岐が無い（legacy grep で誤動作）— Codex B の reject 理由 | **スコープ外**（PR-2 の T-15 で実装。本 PR は明示的に受理側を含まない。F-8 により未配置窓は fail-closed で安全） |
| R-025 | info(スコープ外) | schemas/c3-prime.schema.json | 未配置で c3-prime は常に schema ERROR— Codex B | **スコープ外**（PR-2 の H-3 Human 適用。patch は patches/ に同梱・cross-field 制約込みで完成） |

Sonnet 独立レーンの approve は上記エッジ（allowlist/cross-field/TOCTOU）を突かなかった検出力差。ただし「テスト fixture が実運用 artifact 形式と整合（#887 F-5 の再発なし）」「契約内部整合に矛盾なし」「legacy 経路非変更を実測」の確証は有用として記録。

## PR #889 受理側の Codex 敵対的レビュー（2026-07-20・reject → 全件是正）

> 受理側（承認境界・セキュリティ critical）に Codex 敵対的レビュー 1 本。全指摘をオーガナイザーが一次ソースで再現裁定。

| ID | severity | 対象 | 指摘 | 再現 | 是正 |
|----|----------|------|------|------|------|
| R-026 | **critical** | c3prime_verify.py | 偽造 record（source_sha 不整合・必須欠落・c3_status 混入・未知キー）を AUTO_APPROVED 受理 | **CONFIRMED**（exit 0） | **是正**: 構造 allowlist + 必須キー + c3_status 拒否 + task_id/phase + evidence/policy/issued 非空 + optional expected_sha 照合（exec で HEAD 強制） |
| R-027 | high | bin/plangate `_plangate_c3_dispatch` | 受理器不在時、`approval_kind=[]`/null/不正 JSON が legacy(10) に委譲され grep が受理 | **CONFIRMED**（rc=10） | **是正**: fallback を「approval_kind キーが物理的に無い場合のみ 10、存在すれば値不問で 1」へ |
| R-028 | high | c3prime_verify.py / exec | TOCTOU: 検証成功〜session_start の窓で artifact 書換余地 | 妥当（ローカル書込レース前提） | **緩和 + 契約明記**: exec preflight が再検証の実点。残余窓は Phase 1 許容・flock 単一 snapshot は V2 候補（契約 §4） |
| R-029 | medium | ta-55 | producer 経由 record のみで受理側偽造耐性を検証していない | 妥当 | **是正**: `test_c3prime_verify.py` 新設（producer 非依存の手 mutate 14 パターン）+ ta-55 に手偽造ケース追加 |
| R-030 | info | bin/plangate `\|\| _c3_rc=$?` | 指摘なし（set -e 安全を確認） | — | 変更不要 |

Codex の critical/high は受理側の実バグで、単独レビューでは見つかっていた（オーガナイザーの sandbox 実適用テストは exit code は見たが偽造耐性は見ていなかった＝受理側の敵対レビューが機能した好例）。

## 指摘なしと明示された観点

- レーン A: スコープ / Non-goals の相互整合、AC・9 シナリオのマッピング網羅性
- レーン B: arbiter 純関数設計・gates.c1 文字列一致・EH-3 非退行・c3-approval schema 前提（いずれも plan の前提と実装一致）
