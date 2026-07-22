# TEST CASES — TASK-0896

> plan: [`plan.md`](./plan.md) / 受入基準: pbi-input.md（issue #896 verbatim・8 項目）

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| AC-1: 契約定数が単一モジュール定義・3 消費者が import 参照 | TC-1, TC-2 | Unit + 静的検査 |
| AC-2: sha256 / canonical JSON hash が単一実装 | TC-3, TC-4 | Unit + 静的検査 |
| AC-3: 三つ組照合が I/O なし共通純関数・両経路同一実装 | TC-5（I/O 封じ純粋性・順序契約含む）, TC-6, TC-7 | Unit + 静的検査 |
| AC-4: 既存テスト全 green（振る舞い不変） | TC-8 | Integration |
| AC-5: sync 列挙追加・sync 2 回目 no-op・ta-30 自立 PASS | TC-9 | E2E |
| AC-6: arbiter が I/O あり関数を import / call しない | TC-10 | 静的検査 |
| AC-7: 偽造 record 群の reject 不変 | TC-11 | Integration |
| AC-8: 敵対レビュー 1 ラウンド以上の disposition 記録 | TC-12 | 手動（記録検査） |

## テストケース一覧

### TC-1: 契約定数の単一定義と値固定
- 前提条件: コミット a 適用後
- 入力: `python3 scripts/ai-loop/test_c3_contract.py`
- 期待出力: ARTIFACTS（6 要素）/ VALID_DECISIONS（3 値）/ VALID_VERDICTS（2 値）/ SNAPSHOT_KEYS（5 キー）+ **REQUIRED_KEYS 系（record 用 REQUIRED_KEYS・OPTIONAL_KEYS / PLAN_PACKAGE_REQUIRED_KEYS。Refs: R-001）**の値が現行実装と byte 同一で PASS
- 種別: Unit

### TC-2: 3 消費者のローカル定数定義が消えている
- 前提条件: コミット a 適用後
- 入力: `grep -n "^ARTIFACTS = \|^VALID_DECISIONS = \|^VALID_VERDICTS = \|^SNAPSHOT_KEYS = \|^SNAPSHOT_REQUIRED_KEYS = (\|^REQUIRED_KEYS = (\|^OPTIONAL_KEYS = (\|^PLAN_PACKAGE_REQUIRED_KEYS = (" scripts/ai-loop/{arbiter,plan_package,c3prime_verify}.py`
- 期待出力: タプルリテラルの重複定義 0 件（c3_contract からの import / 別名代入のみ）
- 種別: 静的検査

### TC-3: hash ヘルパーの境界値
- 前提条件: コミット b 適用後
- 入力: `canonical_hash({})` / キー順序を変えた同値 dict ×2 / `sha256_of_file` に 1 byte 違いのファイル 2 つ
- 期待出力: 空 dict でも決定論的 / キー順序非依存で同一 hash / 1 byte 改変で hash 相違（TC-09 系の改変検出が成立）
- 種別: Unit

### TC-4: hash 実装の重複が消えている
- 前提条件: コミット b 適用後
- 入力: `grep -n "def _sha256\|hashlib.sha256" scripts/ai-loop/{plan_package,c3prime_verify}.py`
- 期待出力: ローカル hash 実装 0 件（c3_contract 経由のみ）
- 種別: 静的検査

### TC-5: check_snapshot_trio の理由リスト契約（順序 + 純粋性含む）
- 前提条件: コミット c 適用後
- 入力: 正常 snapshot（5 キー・三つ組一致）/ キー欠落 / 空値 / 三つ組不一致（plan_hash・source_sha・plan_package_hash 各不一致）/ reviewers 非 dict / **複合異常（キー集合異常 + 空値 + 三つ組不一致を同時に含む入力）** / **builtins.open・Path.read_bytes を monkeypatch で封じた状態での実行**
- 期待出力: 正常 = 空リスト / 異常 = 非空の理由文字列リスト（例外を投げない）/ **複合異常の理由リストが契約順序（キー集合 → 空値 → 三つ組不一致）で並ぶ（Refs: R-004）** / **I/O 封じ下でも成功 = 純粋性の失敗検証（Refs: R-003）** / **代表文言 2 本（キー不一致・三つ組不一致）が回帰固定と一致**
- 種別: Unit

### TC-6: strict / lenient 非対称の両側固定（Edge・最重要）
- 前提条件: コミット c 適用後
- 入力: 余剰キー付き snapshot（6 キー目を追加）を strict_keys=True / False で照合
- 期待出力: strict=True → 理由リスト非空（c3prime 経路 = reject 維持）/ strict=False → 空リスト（arbiter 経路 = 通過維持）。**#889 R2 由来の非対称が保存されている**
- 種別: Unit

### TC-7: 両経路の判定結果不変
- 前提条件: コミット c 適用後
- 入力: snapshot 不一致入力を arbiter（plan_package_check）と c3prime_verify に投入
- 期待出力: arbiter = `(True, False, reason)` → BLOCKED priority 1.65 / c3prime_verify = exit 非 0 の reject（既存テストの decision / exit code 期待と一致）
- 種別: Integration

### TC-8: 既存 4 系テスト全 green（AC-4）
- 前提条件: 各コミット後 + 最終
- 入力: `python3 scripts/ai-loop/test_arbiter.py && python3 scripts/ai-loop/test_plan_package.py && python3 scripts/ai-loop/test_c3prime_verify.py && sh tests/run-tests.sh`
- 期待出力: test_arbiter 247 / test_plan_package 30 / test_c3prime_verify 12 / run-tests 411 — **期待値変更ゼロ**で全 PASS
- 種別: Integration

### TC-9: sync 配布整合（AC-5）
- 前提条件: コミット d 適用後
- 入力: `sh scripts/sync-plugin-plangate.sh`（2 回）→ `git diff --quiet -- plugin/plangate/` → ta-30 実行 → ta-55 実行
- 期待出力: 1 回目で c3_contract.py / test_c3_contract.py が plugin へ配布・2 回目 no-op（diff 空）/ ta-30 TC-07（scripts >= 2）・TC-08（bundled test_arbiter 自立 PASS）・TC-09（installed:0）PASS / **ta-55 が test_c3_contract.py を実行し PASS（CI 実行経路。Refs: R-010）**
- 種別: E2E

### TC-10: arbiter の I/O なし import 制約（AC-6）
- 前提条件: コミット c 適用後
- 入力: `grep -n "sha256_of_file" scripts/ai-loop/arbiter.py`
- 期待出力: 0 件（arbiter が import / call するのは定数・canonical_hash・check_snapshot_trio のみ）。test_c3_contract.py にも同制約の回帰テスト（arbiter モジュールの属性参照検査）を置く
- 種別: 静的検査

### TC-11: 偽造 record 群 reject 不変（AC-7）
- 前提条件: 最終形
- 入力: `python3 scripts/ai-loop/test_c3prime_verify.py`（手 mutate 偽造系: c3_status 混入 / 未知キー / 必須欠落 / source_sha 不整合 / evidence 偽造 / task_id 非束縛 / reviewer 独立性違反 / AUTO_APPROVED 改竄 ほか 14 パターン）
- 期待出力: 全パターン reject（12 テスト PASS・変更ゼロ）
- 種別: Integration

### TC-12: 敵対レビュー disposition（AC-8）
- 前提条件: T-15 完了
- 入力: `docs/working/TASK-0896/evidence/` の敵対レビュー記録
- 期待出力: 1 ラウンド以上・指摘ごとの採否 + 根拠が記録されている（major 以上は是正済み）
- 種別: 手動（記録検査）

## エッジケース

### TC-E1: reviewers が空 dict / None
- 前提条件: コミット c 適用後
- 入力: `check_snapshot_trio(container, {}, strict_keys=...)` / reviewers=None
- 期待出力: 非空理由リスト（例外でなく fail-closed の理由返却）
- 種別: Unit

### TC-E2: container 側トップレベル値が None / 欠落
- 前提条件: コミット c 適用後
- 入力: container の plan_hash が None のまま snapshot は値あり
- 期待出力: 不一致として非空理由リスト（None == None の偶然一致で通過しない — 両側 None ケースも理由リスト非空か既存挙動と同一かを実装時に既存テストで確認し、挙動を変えない）
- 種別: Unit / Edge

### TC-E3: bundled 展開先での import 自立
- 前提条件: コミット d 適用後
- 入力: ta-30 TC-08（展開先 tmp dir で `python3 test_arbiter.py`）
- 期待出力: 同 dir の c3_contract.py を sys.path 既存パターンで解決し PASS（リポジトリ外で自立）
- 種別: E2E / Edge
