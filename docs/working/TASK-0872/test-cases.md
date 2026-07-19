# TEST CASES — TASK-0872

> plan: [`plan.md`](./plan.md) / AC は issue #872 verbatim（pbi-input.md 参照）

## 受入基準 → テストケースマッピング

| AC | 内容（要約） | テストケース |
|----|-------------|-------------|
| AC-1 | run は TASK ID 必須 | TC-01（入口 + plan_package 二層 / Refs: R-001） |
| AC-2 | 4 成果物欠落 → AUTO_APPROVED 不可 | TC-02 |
| AC-3 | C-1/C-2 evidence 欠落・FAIL・stale → AUTO_APPROVED 不可 | TC-03（表駆動 6 ケース / Refs: R-002）, TC-04 |
| AC-4 | raw `gates.c1=PASS` 単独では通過不可 | TC-05 |
| AC-5 | A/B が同一 plan_hash / source_sha を見たことを record で確認可 | TC-06（reviewer snapshot 照合 / Refs: R-004） |
| AC-6 | W 不一致・判定不能・未知カテゴリ → fail closed escalate | TC-07 |
| AC-7 | c3-prime を validate と exec preflight が受理 | TC-08a（PR-1 Unit）+ TC-08b（PR-2 E2E / Refs: R-005）+ TC-13（schema-validate CI / Refs: R-006） |
| AC-8 | 1 byte 変更で承認 stale | TC-09（source_sha 変更含む / Refs: R-003） |
| AC-9 | allowed paths 外 / HO 接触 / eligibility 外 → 自動承認不可 | TC-10 |
| AC-10 | LoopSpec 重複手入力なし・派生の再現性 | TC-11（timestamp 固定注入 / Refs: R-010） |
| AC-11 | legacy C-3 human approval 後方互換 | TC-12 |

## 必須テストシナリオ（issue #872）→ テストケース

| シナリオ | テストケース |
|---------|-------------|
| 1. artifact なし → 停止・W 未実行 | TC-02 |
| 2. C-1/C-2 なし → escalate | TC-03 |
| 3. artifact hash mismatch → block | TC-09（block 側）|
| 4. approve/reject → escalate | TC-07 |
| 5. valid Package + approve/approve → c3-prime 生成 | TC-08a（PR-1 Unit / Refs: R-005）|
| 6. c3-prime → validate PASS → preflight PASS | TC-08b（PR-2 E2E）|
| 7. 承認後 Plan 変更 → validate FAIL | TC-09 |
| 8. HO / scope 外 → AUTO_APPROVED 不可 | TC-10 |
| 9. 同一入力 2 回 → decision・派生 LoopSpec 同一 | TC-11 |

## テストケース一覧

### TC-01: run 入口の TASK ID 必須化（AC-1 / 二層検証 / Refs: R-001）

- 前提: PR-2 適用後の `ai-loop-workflow.md` / plan_package.py
- 入力と期待（二層）:
  - **層 1（入口 / E2E）**: TASK ID なしの `run <自由文説明>` → production-compatible run を開始できず **W チェック未実行のまま停止**。`run TASK-XXXX` → 後続（presence 検証）へ進む
  - **層 2（Unit）**: plan_package.py に task_id 未指定 / 形式不正（`^TASK-[0-9]{4}$` 不一致）→ 明示エラーで fail-closed
- 種別: Unit（test_plan_package.py）+ E2E（TC-08b の fixture に入口ケースを含める）

### TC-02: 4 成果物欠落 → presence gate 停止（AC-2 / シナリオ 1）

- 前提: sandbox TASK ディレクトリで pbi-input/plan/todo/test-cases のいずれか 1 つを欠落させる（4 パターン全数）
- 入力: plan_package.py の presence 検証
- 期待: 欠落ファイル名を含む明示的失敗。W チェック入力（plan_package ブロック）が生成されない → arbiter は AUTO_APPROVED を返せない
- 種別: Unit

### TC-03: C-1 / C-2 evidence 異常の表駆動検証（AC-3 / シナリオ 2 / Refs: R-002）

- 前提: 4 成果物あり。**C-1 / C-2 × 欠落 / FAIL / stale の全 6 組合せ**を表駆動でテスト
- 期待: 6 ケースすべてで単独異常でも HUMAN_ESCALATED（AUTO_APPROVED 不可・fail-closed）。どちらか一方が正常でも他方の異常で必ず escalate
- 種別: Unit + Integration

### TC-04: stale 判定根拠の出力検証（AC-3）

- 前提: TC-03 の stale ケース（evidence の hash/mtime が plan.md より古い）
- 期待: escalate 出力に stale 判定根拠（どの evidence がどの基準で stale か）が含まれ、機械追跡可能
- 種別: Unit

### TC-05: raw `gates.c1=PASS` 単独では通過不可（AC-4）

- 前提: `plan_package` ブロックなし・`gates: {c1: "PASS", breakdown: "pass"}` のみの arbiter 入力（現行形式）
- 期待: production run では AUTO_APPROVED にならない（escalate）。既存の非 production 経路の挙動は退行しない
- 種別: Unit（test_arbiter.py）

### TC-06: provenance の reviewer 別 snapshot 照合（AC-5 / Refs: R-004）

- 前提: valid plan_package 入力で A/B verdicts あり
- 期待: provenance JSON の `reviewers.model_a` / `reviewers.model_b` に各 reviewer が観た plan_hash / source_sha / plan_package_hash / 判定 / evidence ref が刻印され、**全 reviewer の hash 同一を record から機械確認できる**。いずれかの snapshot 欠落・hash 不一致入力は block（fail-closed）
- 種別: Unit

### TC-07: W チェック不一致・判定不能・未知カテゴリ → escalate（AC-6 / シナリオ 4）

- 前提: verdicts が approve/reject、判定欠落、未知 reject_category の 3 パターン
- 期待: すべて HUMAN_ESCALATED（fail-closed）。既存挙動の回帰確認を含む
- 種別: Unit（既存 test_arbiter.py の拡張）

### TC-08a: c3-prime record 生成（AC-7 前段 / シナリオ 5 / PR-1 Unit / Refs: R-005）

- 前提: valid Plan Package + approve/approve
- 期待: c3-prime dict/record（approvals/c3.json 互換・契約準拠）が生成される。**PR-1 のマージ前に Unit で検証済みであること**（PR-2 を待たない）
- 種別: Unit（test_arbiter.py / test_plan_package.py）

### TC-08b: c3-prime artifact 受理チェーン（AC-7 / シナリオ 6 / E2E）

- 前提: TC-08a の c3-prime artifact
- 入力: `bin/plangate validate TASK-XXXX` → exec preflight
- 期待: 両方 PASS（exit 0）。`tests/extras/ta-NN-*.sh` + `tests/fixtures/` パターンの単一コマンド E2E として CI 登録（Refs: R-013）
- 種別: E2E（PR-2）

### TC-09: 1 byte 変更・source SHA 変更で stale（AC-8 / シナリオ 3,7 / Refs: R-003）

- 前提: TC-08b の承認済み状態から (a) plan.md を 1 byte 変更 (b) 固定 artifact のいずれかを 1 byte 変更 (c) **source_sha のみが現対象 SHA と不一致になる**
- 期待: (a)(b) `validate` FAIL / hash mismatch は block、(c) **BLOCK（警告降格なし・fail-closed）**。いずれも artifact_hashes / source_sha のどのエントリの不一致かを失敗メッセージに含み、再 C-1/C-2/C-3' を要求
- 種別: E2E + Unit

### TC-10: allowed paths 外・HO 接触・eligibility 外 → 自動承認不可（AC-9 / シナリオ 8）

- 前提: changed_files に allowed_paths 外 / HO パス（例: `bin/plangate`）を含む入力、lite 4 軸不成立の入力
- 期待: AUTO_APPROVED にならない（既存 boundary/scope/lite check の非退行 + plan_package 有りでも優先されない）
- 種別: Unit（既存テストの回帰 + 新規）

### TC-11: LoopSpec 決定論的派生・冪等（AC-10 / シナリオ 9 / Refs: R-010, R-012）

- 前提: 同一 Plan Package。**timestamp は注入パラメータで固定**（arbiter build_provenance の `datetime.now()` 直刻印に注入口を追加）
- 入力: plan_package.py の派生を 2 回実行
- 期待: 派生 LoopSpec・decision・c3-prime が byte 同一。LoopSpec 必須フィールド全数が契約のマッピング表（派生元 or 固定既定値）で埋まり I-4 受理拒否にならない。手入力 LoopSpec との重複がない（派生のみが正）
- 種別: Unit

### TC-12: legacy C-3 human approval 後方互換（AC-11）

- 前提: 既存 `plangate approve` が生成した legacy c3.json（`c3-approval.schema.json` 準拠・approval_kind なし）
- 入力: `bin/plangate validate` / exec preflight / EH-3 hook
- 期待: 従来どおり PASS（PR-2 適用前後で挙動 byte 同一）。既存 shell テスト（tests/run-tests.sh）全 PASS
- 種別: Integration（既存テストの回帰）

### TC-13: schema-validate CI が c3-prime を正しく検証（AC-7 補完 / Refs: R-006）

- 前提: `scripts/schema_mapping.py` の approval_kind 判別 dispatch 適用後
- 入力: (a) c3-prime 形式の approvals/c3.json（approval_kind: c3-prime）(b) legacy c3.json
- 期待: (a) は `c3-prime.schema.json` で検証され green、(b) は従来どおり `c3-approval.schema.json` で検証され green。schema-validate CI が PR で FAIL しない
- 種別: Unit（schema_mapping）+ CI 実測

## エッジケース

- EC-1: artifact が 0 byte（存在するが空）→ presence は通るが integrity で fail-closed
- EC-2: c3-prime JSON に未知フィールド → schema `additionalProperties` 方針に従い reject（`^_` 注釈キーのみ許容）
- EC-3: sha256 の大文字表記・`sha256:` prefix 欠落 → 不一致扱い（正規化しない・fail-closed）
- EC-4: `approval_kind` が未知値（例: `c3-double-prime`）→ validate は受理しない
- EC-5: legacy c3.json と c3-prime が同一 TASK に併存 → 受理優先順を契約で固定（c3-prime-contract.md に明記）し、テストで固定
- EC-6: **確定（Refs: R-003）** — source_sha が検証時点の対象 SHA と不一致 → validate / exec preflight で **BLOCK**（fail-closed 固定・警告降格なし）。TC-09(c) でカバー
