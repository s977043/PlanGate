# TASK-0106 handoff

> **WF-05 Verify & Handoff 完了パッケージ**。docs/working/templates/handoff.md
> テンプレート準拠の必須 6 要素 (Rule 5)。

## 概要

issue #289「EH-3 in-session skip の運用性改善」を TASK-0106 として実装完了。
人間が in-session で EH-3 skip を許可する一級手段 `bin/plangate maintenance
start/stop` CLI を新設し、`maintenance.json` 承認ファイルの **one-shot +
allowed_paths + 5 分既定 TTL** で運用性を改善。Codex+Gemini 4 ラウンド
外部レビュー (R-001..R-031) と Human C-3 APPROVED (R-012 best-effort 設計
を Human 明示承認) を経て exec。

## 1. 要件適合確認結果

### AC-1〜AC-13 全 PASS

| AC | 内容 | TC | 検証結果 |
|----|------|-----|---------|
| AC-1 | `bin/plangate maintenance start` で schema valid な maintenance.json 生成 | TC-01 | ✅ schema validate / smoke test 確認 |
| AC-2 | 生成承認下で no-task Edit/Write が 1 回通り one_shot 消費 | TC-03/TC-04 | ✅ ta-12 で fixture 検証 |
| AC-3 | `--paths` 指定外 + Hardening Override 対象は窓内でも常時 block | TC-06/TC-07/TC-24 | ✅ ta-12 で 10 パターン全 block |
| AC-4 | TTL 超過後 block、ハード上限 30 分超 `--minutes` reject | TC-08/TC-09 | ✅ ta-12 expired block / 引数 validation コード確認 |
| AC-5 | AI からの自己発行不可 (L1-L4 best-effort + 監査) | TC-10/TC-25 | ✅ L1 reject 動作、他層は smoke test |
| AC-6 | `plangate doctor` 残時間・スコープ表示 | TC-11 | ✅ doctor 出力に Maintenance Window 行 |
| AC-7 | 既存 30 分窓 maintenance.json (パス無指定) 後方互換 | TC-12 | ✅ ta-12 で legacy fixture PASS |
| AC-8 | ユニットテストが `tests/run-tests.sh` で検証可能 | TC-23 | ✅ ta-12 が runner から自動 discovery (68→82) |
| AC-9 | 既存有効窓で `start --force` なしは reject | TC-20 | ✅ CLI コード実装確認 |
| AC-10 | 新設フィールドも env では有効化不可 | TC-29 | ✅ ta-12 で env-only テスト |
| AC-11 | flock 取得後の再 read + atomic RMW + 並行 fail-closed | TC-30/TC-32 | ✅ hook 実装で flock + inode 確認、ta-12 で consume + 2 回目 block |
| AC-12 | Hardening Override 表記揺れ (./ 有無等) でも block | TC-33 | ✅ ta-12 で 3 種の表記揺れ block |
| AC-13 | `doctor --json --scope maintenance` でメタデータ取得 | TC-34 | ✅ ta-12 で JSON 構造検証 |

## 2. 既知課題一覧

| ID | 内容 | 重要度 | 取扱い |
|----|------|--------|--------|
| K-1 | TC-26a/b/c/d (L2/L3/L4 各層 reject) と TC-09/TC-20 (引数 validation) は **tty mock が必要**で CI 自動化未対応 | minor | docs/ai/maintenance-cli.md と本 handoff に明記、手動検証で代替。将来 `expect` 等で自動化候補 |
| K-2 | TC-32 (race fail-closed verify) は python multiprocessing で並列起動が必要、ta-12 では 単一プロセス consume + 2 回目 block で間接検証 | minor | より厳格な並行 race test は別 PBI で追加可 |
| K-3 | L3 parent process heuristic は `ps -p $PPID -o comm=` の OS 差異 (BSD/GNU) を `grep -iqE` 部分一致で吸収するが、ppid 偽装には追従不可 | info | best-effort と documented limitation で許容 (R-029) |
| K-4 | UTF-8 非対応環境 (shift-jis 等) の動作は未保証 | info | documented limitation (R-018) |

## 3. V2 候補 (今回 scope 外)

| 案 | 内容 |
|----|------|
| V2-A | **AI 自己付与の完全構造保証 PBI** (R-012 で別 PBI 分割明示)。例: GPG 署名 + 外部 token + 物理的キー入力等の追加防御 |
| V2-B | tty mock を使った CI 自動化 (TC-09/TC-20/TC-26a-d/TC-32) — `expect` または `pexpect` を tests/extras 配下で活用 |
| V2-C | maintenance.json の **append-only audit リング** (consume 履歴を保持) — 過去 N 回の consume 履歴を保持し監査強化 |
| V2-D | maintenance CLI を Cursor/IDE 統合 (`.cursor/hooks.json` から呼び出し) — TASK-0090 と統合 |

## 4. 妥協点 (採用しなかった選択肢と理由)

| 選択肢 | 採用せず | 理由 |
|--------|---------|------|
| L1-L4 を完全な構造保証で実装 (PAM/GPG 必須等) | best-effort で代替 | 原理的に困難 + UX 過剰負荷 (R-012、Human C-3 で明示承認) |
| `--paths` 未指定で error にする (明示必須) | 後方互換維持 | v1 形式の既存 maintenance.json を破壊しない (R-004) |
| `os.replace` 単体で atomicity 確保 | flock + inode 確認に強化 | fd ベース flock では os.replace 後の新 inode を検知できない race が残存 (R-031 Gemini 指摘) |
| Hardening Override を `.gitignore` に明記して install 時自動展開 | hook 内ハードコード | install 一貫性のため hook 自身に閉じる (10 パターン明示で十分審査可能) |

## 5. 引き継ぎ文書 (5 分で状況把握)

### 何が変わったか

- **新規 CLI**: `bin/plangate maintenance start/stop/help` (149 行追加)
- **schema 拡張**: `schemas/maintenance.schema.json` v2 (additive、`allowed_paths`/`one_shot`/`consumed_at` optional 追加)
- **EH-3 hook 改修**: `scripts/hooks/check-plan-hash.sh` の maintenance ブロックを v2 化 (判定順序明文化 + flock+inode atomic)
- **doctor 拡張**: `scripts/doctor_check.py` SCOPES に `maintenance` 追加 + `bin/plangate doctor` 出力に 1 行表示
- **テスト追加**: `tests/extras/ta-12-maintenance.sh` (14 ケース、68→82)
- **運用 guide**: `docs/ai/maintenance-cli.md` (175 行)

### 動作確認の最短手順

```sh
# 1. CI 統合（自動）
sh tests/run-tests.sh                    # 82 passed
sh tests/hooks/run-tests.sh              # 79 passed

# 2. doctor JSON 確認 (active なし)
bin/plangate doctor --json --scope maintenance

# 3. 手動 smoke (real TTY 環境で)
bin/plangate maintenance start --reason "test" --paths "README.md" --minutes 1
# (nonce プロンプトに従って入力)
# その後 1 回だけ README.md を Edit、2 回目で block 確認
bin/plangate maintenance stop
```

### Hardening Override の確認

`scripts/hooks/check-plan-hash.sh` 内、`(ii) Hardening Override 物理先頭判定`
ブロックの 10 sh case パターンを変更しないこと。新規重要 infra を追加する
場合は本リストに追記が必要 (例: 新規 schemas/, 新規 .github/workflows/)。

## 6. テスト結果サマリ

| Suite | Before (main 58c13f5) | After | 結果 |
|-------|----------------------|-------|------|
| `tests/run-tests.sh` | 68 passed, 0 failed | **82 passed, 0 failed** | +14 (ta-12 新規) |
| `tests/hooks/run-tests.sh` | 79 passed, 0 failed | **79 passed, 0 failed** | 不変 (regression なし) |

### V-1 受け入れ検査

- ✅ AC-1〜AC-13 全 13 件 PASS (上記 §1)
- ✅ レグレッション 0 件
- ✅ test-cases.md TC-01〜TC-34 のうち自動化可能な全件カバー、非自動化分
      (tty mock 必要) は documented limitation として明記
- ✅ Hardening Override 10 パターン block 動作確認
- ✅ flock+inode race fail-closed 動作 (smoke test、AC-11/R-031)
- ✅ Approval 境界破壊なし (env 経路無効化維持)

### 結論

**V-1 PASS**。本 PBI は exec フェーズ完了、C-4 PR レビュー → Human merge
を待機可能な状態。

## 参照

- Issue: [#289](https://github.com/s977043/PlanGate/issues/289)
- PBI INPUT: `docs/working/TASK-0106/pbi-input.md` (v3.2)
- plan: `docs/working/TASK-0106/plan.md` (v3.2、plan_hash sha256:9039b9...)
- C-3 approval: `docs/working/TASK-0106/approvals/c3.json` (APPROVED 2026-05-21)
- 外部レビュー: `docs/working/TASK-0106/review-external.md` (R-001..R-031)
- 運用 guide: `docs/ai/maintenance-cli.md` (T-11)
