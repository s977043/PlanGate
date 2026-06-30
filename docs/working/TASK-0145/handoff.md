---
task_id: TASK-0145
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-06-26
author: qa-reviewer
v1_release: "3011801 (PR#634)"
---

# Handoff Package — TASK-0145 EHS strict 発火配線 増分1（EHS-1）

## メタ情報

```yaml
task: TASK-0145
related_issue: https://github.com/s977043/plangate/issues/527
author: qa-reviewer
issued_at: 2026-06-26
v1_release: "3011801 — feat(#527): TASK-0145 増分1 EHS-1 strict 発火配線（bin/plangate 方式）(PR#634)"
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| EHS-1 apply-script が作成され dry-run が動作する | PASS | `scripts/apply-task-0145-ehs-wiring.sh`（dry-run/--apply 両経路）と `scripts/_apply_task_0145_patches.py`（OSError キャッチ付き）が PR#634 でマージ済み。文字列アンカー方式で行番号非依存のパッチ定義を実現 |
| ta-46 が未適用時 SKIP、適用後 TC-01〜04 PASS する構造になっている | PASS | `tests/extras/ta-46-ehs-wiring.sh` が `grep -q "EHS-1 BLOCK"` による先行 SKIP ガードを持ち、TC-01（発火条件配線）/ TC-02（return 1 block）/ TC-03（既定 normal 非発火）/ TC-04（構文健全性）の 4 ケース定義済み |
| 非 strict（既定 normal）では発火しない（既存挙動不変） | PASS | パッチが `${PLANGATE_VALIDATION_BIAS:-normal}` でデフォルト normal を担保。TC-03 でも検証。bin/plangate 未適用状態（現 main）では該当パス自体が存在しないため既存挙動は完全に不変 |
| HO apply-script（Human 実行）経由での適用経路が整備されている | PASS | `apply-task-0145-ehs-wiring.sh` が HO パス変更のラッパーとして整備済み。dry-run で差分確認後 --apply で適用する 2 ステップ運用を説明コメントに明記 |
| sandbox 適用検証で全 TC PASS 確認済み | PASS | PR#634 コミットメッセージに sandbox 適用検証・全 TC PASS の記録あり（POSIX awk 版 TC-02 も含む） |
| 既存テスト 0 FAIL を維持 | PASS | 適用前 349 passed / 0 failed（ta-46 は未適用 SKIP 計上） |

**総合**: 6/6 基準 PASS

**FAIL / WARN の扱い**: なし。EHS-1 の bin/plangate への実際の適用は Human 実行待ちだが、これは Human-owned 操作であり AC の範囲外。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| EHS-1 の bin/plangate への実際の適用が Human 待ち（`--apply` 未実行） | minor | open / Human-owned | No — 次 Human オペレーションで解消 |
| `validation_bias` の conductor 側 export（profile → env 注入）が未整備 | major | open / workaround（手動 env 注入） | Yes — conductor integration は別タスク |
| EHS-2（handoff 6要素必須化）未実装 | major | open | Yes — 増分2 |
| EHS-3（fix-loop 上限）未実装 | major | open | Yes — 増分3 |
| ta-46 TC-02 が awk 依存（POSIX awk で動作するが jq 等より可読性低い） | minor | accepted | No — POSIX 互換性優先で選択済み |

**Critical 課題の対応**: Critical 課題なし。major 課題はいずれも増分2/3 または Human 操作で解消予定。EHS-1 適用自体は Human が `sh scripts/apply-task-0145-ehs-wiring.sh --apply` を実行することで即時完結する。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------------|
| EHS-2: handoff 6要素必須化（`handoff --verify` 経路に `check-handoff-elements.sh` strict） | 増分分割方針により本 PR スコープ外 | High | #527 |
| EHS-3: fix-loop 上限（`cmd_verify` fix-loop に `check-fix-loop.sh` strict） | 増分分割方針により本 PR スコープ外 | High | #527 |
| conductor 側 `validation_bias` 自動解決（model-profiles.yaml active profile → env 注入） | EHS-1 は env 手動注入方式で担保済みだが、conductor integration で完全自動化が必要 | Medium | #527 |
| `--profile` 直接解決ヘルパー（bin/plangate 単体で profile 解決） | 将来拡張として plan.md に明記済み | Low | #527 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| apply-script（HO パス変数変更）方式 | AI 直接 bin/plangate 編集 | bin/plangate は Hardening Override パス。AI は自己改変ガード対象のため Human 実行スクリプト経由が唯一の合法経路 |
| 文字列アンカー方式のパッチ（行番号非依存） | 行番号ベース sed 置換 | bin/plangate は他 PBI との並行変更で行ズレが起きうる。文字列アンカーによりパッチ衝突を最小化 |
| `${PLANGATE_VALIDATION_BIAS:-normal}` による env 注入 | profile ファイル直接 parse | conductor 側の整備前でも安全側で動作（既定 normal = 非発火）。profile 直接解決は V2 候補へ |
| POSIX awk による TC-02 実装（`grep -A2` を awk に変更） | GNU grep -A 拡張 | Alpine Linux 等 POSIX 準拠環境での CI 互換性確保。C-1 セルフレビューで指摘され改良 |
| OSError キャッチ（`_apply_task_0145_patches.py`） | 例外素通し | FileNotFoundError / PermissionError を明示的に捕捉しエラーメッセージを出力。C-1 で指摘された点を反映 |

## 5. 引き継ぎ文書

### 概要

TASK-0145 増分1では、EPIC #527（EHS strict 発火配線）の最初の増分として EHS-1（V-3 外部レビュー必須化）の apply-script・テストを整備した。`bin/plangate` は Hardening Override パスのため AI 直接編集不可であり、TASK-0143 eh457 と同方式（Human 実行 apply-script）で配線した。PR#634 がマージ済み（main: 3011801）。

現状、`bin/plangate` への EHS-1 パッチ実物は未適用（Human が `sh scripts/apply-task-0145-ehs-wiring.sh --apply` を実行する必要がある）。適用前の ta-46 は SKIP 計上となり CI を割らない設計になっている。`validation_bias=strict` 環境での EHS-1 実際の発火確認は apply 後の Human 手元検証が必要。

### 次に手を入れるなら

- **Human 即時アクション**: `sh scripts/apply-task-0145-ehs-wiring.sh --dry-run` で差分確認後 `--apply` を実行して EHS-1 を bin/plangate に適用する
- **増分2（EHS-3）**: `cmd_verify` の fix-loop に `check-fix-loop.sh` strict 経路を追加する。同様の apply-script + ta-47 構成
- **増分3（EHS-2）**: `handoff --verify` 経路に `check-handoff-elements.sh` strict を追加する
- **conductor 連携**: `validation_bias` を model-profiles.yaml の active profile から conductor が自動 export する仕組みを整備する（現状は手動 env 注入が必要）
- 避けるべきアンチパターン: `bin/plangate` を AI が直接編集すること（HO パス違反）。必ず apply-script 経由で Human が適用する

### 触れないでほしいファイル

- `bin/plangate`: HO パス。AI 直接編集禁止。変更は apply-script 経由で Human が行う
- `tests/extras/ta-46-ehs-wiring.sh`: 未適用 SKIP ガード構造（`grep -q "EHS-1 BLOCK"`）が tc 構造の前提。SKIP 判定ロジックを変更すると未適用 CI で FAIL が発生する

### 参照リンク

- 親 EPIC: https://github.com/s977043/plangate/issues/527
- PR#634: https://github.com/s977043/plangate/pull/634
- plan.md: `docs/working/TASK-0145/plan.md`
- 先行 PBI（EH-4/5/7 CLI 配線）: `docs/working/TASK-0143/handoff.md`
- apply-script: `scripts/apply-task-0145-ehs-wiring.sh`
- パッチ定義: `scripts/_apply_task_0145_patches.py`
- テスト: `tests/extras/ta-46-ehs-wiring.sh`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| run-tests.sh 全体 | 349 | 349 | 0 FAIL / ta-46 SKIP（未適用） | — |
| ta-46 TC-01（発火条件配線） | 1 | sandbox 適用後 PASS | SKIP（未適用時）| — |
| ta-46 TC-02（block return 1） | 1 | sandbox 適用後 PASS | SKIP（未適用時）| — |
| ta-46 TC-03（非 strict 非発火） | 1 | sandbox 適用後 PASS | SKIP（未適用時）| — |
| ta-46 TC-04（構文健全性） | 1 | sandbox 適用後 PASS | SKIP（未適用時）| — |

**FAIL / SKIP の詳細**: ta-46 の 4 TC は `bin/plangate` への EHS-1 パッチ未適用時に SKIP 計上（CI を割らない設計）。sandbox 適用検証では全 4 TC PASS 確認済み（PR#634 コミットメッセージに記録）。FAIL なし。

## 7. Metrics summary

該当なし（metrics collect 未実行）
