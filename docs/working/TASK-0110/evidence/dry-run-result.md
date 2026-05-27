# TASK-0110 dry-run evidence (T-04)

> 実施: 2026-05-27 / Mode: read-only
> 目的: 本リポジトリの実 skip-decision-log.jsonl への --dry-run 実行結果

## 環境

- script: `scripts/batch-acknowledge-skip-decisions.py`
- log: `docs/working/_audit/skip-decision-log.jsonl`

## 実行コマンド

```sh
python3 scripts/batch-acknowledge-skip-decisions.py --dry-run
```

## 出力

```text
[batch-ack] dry-run: /Users/user/Documents/GitHub/plangate/docs/working/_audit/skip-decision-log.jsonl
  valid entries: 2
  EH-3_SKIP unack: 2
  other unack (event != EH-3_SKIP): 0
  parse errors: 0

  EH-3_SKIP reason 分布 (上位 10):
      1  generic-edit
      1  arg-resolve

  sample (先頭 3):
    L1: target=src/foo.ts reason=generic-edit ts=2026-05-27T09:26:33Z
    L2: target=src/bar.ts reason=arg-resolve ts=2026-05-27T09:26:34Z
```

## 解釈

- **EH-3_SKIP unack** 件数が **0** ならば、即時 batch-acknowledge は不要
- 件数 > 0 の場合、reason 分布を確認した上で Human が `--apply --acknowledged-by <name>` 実行
- parse errors > 0 の場合、log 破損の可能性、修正後再 dry-run

## 次のステップ (Human オペレーション、T-05 ガイド参照)

1. dry-run 結果を Human が確認
2. PR ブランチで `python3 scripts/batch-acknowledge-skip-decisions.py --apply --acknowledged-by s977043` 実行
3. 変更を PR に commit ("applied by s977043 (TASK-0110 H-02)" 等)
4. CI "SKIP_REASON 追認" PASS 確認
5. C-4 承認 → merge
