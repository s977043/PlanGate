# Skip-Decision-Log Batch Acknowledge CLI (#301 / TASK-0110)

> Human オペレーション正本。AI は dry-run + script 整備までを担当、`--apply` は Human が実行。

## 目的

`docs/working/_audit/skip-decision-log.jsonl` の未追認 EH-3_SKIP entry に **acknowledged_by / acknowledged_at を一括追記** する CLI。

CI required "SKIP_REASON 追認" (`scripts/check-skip-acknowledged.sh`) を PASS 状態に到達させ、PR を通せる状態にする。

## 背景 / 実害

本セッション (2026-05-26〜27) で **PR #376 (TASK-0108) と PR #383 (TASK-0117)** で `skip-decision-log.jsonl` が untracked のまま `git add -A` に巻き込まれる事例が複数回発生。

未追認 entry を含む状態でファイルが commit されると、CI "SKIP_REASON 追認" が fail し PR を通せない。本 CLI は構造的解消手段。

## 設計原則 (TASK-0110 C-2 review 反映)

| ID | 内容 |
|----|------|
| R-001 | `--apply` は PR ブランチ上で Human が実行、apply commit を PR 内に含める (CI PASS → merge) |
| R-002 | **raw-line-preserving** (json.loads/dumps しない、既存 key 順・spacing を保持) |
| R-003 | `--acknowledged-by` 必須、commit message に Human 名記録 |
| R-004 | C-3 同期固定 (mode=light でも非同期降格なし) |
| R-005 | dry-run で `event:EH-3_SKIP` 優先スキャン + reason 集計 |
| R-006 | `acknowledged_at` は ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`) |

## 使用フロー (Human オペレーション)

### Step 1: dry-run (AI/Human どちらも可)

```sh
python3 scripts/batch-acknowledge-skip-decisions.py --dry-run
```

出力例:

```text
[batch-ack] dry-run: /path/to/skip-decision-log.jsonl
  valid entries: 148
  EH-3_SKIP unack: 145
  other unack (event != EH-3_SKIP): 3
  parse errors: 0

  EH-3_SKIP reason 分布 (上位 10):
     85  generic-edit
     38  arg-resolve
     22  ...
```

### Step 2: PR ブランチ上で `--apply` (Human オペレーション)

```sh
# 必ず PR ブランチ上で実行 (main 直接編集不可、INC-2026-05-26-001 P-3 / TASK-0115 参照)
git checkout exec/task-XXXX
python3 scripts/batch-acknowledge-skip-decisions.py --apply --acknowledged-by s977043
```

出力例:

```text
[batch-ack] apply 完了: /path/to/skip-decision-log.jsonl
  updated entries: 145
  acknowledged_by: s977043
  acknowledged_at: 2026-05-27T10:00:00Z
  backup: /path/to/skip-decision-log.jsonl.bak
```

### Step 3: PR に commit + CI 確認

```sh
git add docs/working/_audit/skip-decision-log.jsonl
git commit -m "ack(TASK-XXXX): batch acknowledge skip-decision-log (applied by s977043, R-003)"
git push
# GitHub Actions で "SKIP_REASON 追認" が PASS することを確認
```

### Step 4: C-4 承認 → merge

通常の PR フロー (Human merge boundary 維持)。

## 引数

| 引数 | 必須 | 説明 |
|-----|------|------|
| `--dry-run` | (--apply と排他、いずれか必須) | 変更せず検出のみ |
| `--apply` | (同上) | 実際に追記 |
| `--acknowledged-by NAME` | `--apply` 時必須 | Human 名 (例: `s977043`)、空文字 reject |
| `--log PATH` | optional | 対象 jsonl (default: `docs/working/_audit/skip-decision-log.jsonl`) |

## 安全機構

| 機構 | 説明 |
|------|------|
| **raw-line-preserving** | 既存 JSON 構造 / key 順 / spacing を破壊しない (R-002) |
| **atomic RMW + .bak** | tmp file 作成 → `os.replace` で atomic move、`.bak` 保持 |
| **idempotent** | 既 ack 済 entry には触らない (重複適用安全) |
| **event filter** | `EH-3_SKIP` のみ対象、他 event は無視 (R-005) |

## false positive / 異常系

| 状況 | 動作 |
|------|------|
| 空 jsonl | exit 0 (no-op) |
| parse error 行 | スキップ + warning (apply は abort しない、該当行は触らない) |
| `--apply --acknowledged-by ""` | exit 1 (空文字 reject) |
| ファイル不在 | exit 0 (no-op、warning) |

## トラブルシューティング

### Q: `--apply` 後に CI "SKIP_REASON 追認" が fail する

- `grep -cE '"acknowledged_by":null' docs/working/_audit/skip-decision-log.jsonl` で残 unack 確認
- 0 件なら `scripts/check-skip-acknowledged.sh` ローカル実行で原因特定
- > 0 件なら `--dry-run` で再確認

### Q: rollback したい

```sh
mv docs/working/_audit/skip-decision-log.jsonl{.bak,}  # .bak から復元
```

### Q: 適用前の差分を確認したい

```sh
diff docs/working/_audit/skip-decision-log.jsonl{.bak,}
```

## 関連

- Issue: [#301](https://github.com/s977043/plangate/issues/301)
- 既存 CI: [`scripts/check-skip-acknowledged.sh`](../../scripts/check-skip-acknowledged.sh) (CI required "SKIP_REASON 追認")
- INC: [INC-2026-05-26-001](../working/incidents/2026-05-26-empty-commit-direct-push.md) (関連: 誤混入対策)
