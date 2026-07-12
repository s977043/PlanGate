# TASK-0780 follow-up: gates を provenance に刻む

> #780 Slice B follow-up（PR #817 本文で明示）。arbiter が plan-quality 判定に使う gates を
> record に刻み、plan-quality escalate の理由を監査・集計可能にする（Trust Ledger 強化）。

## Goal

build_provenance が入力の `gates` を record に刻む（run と同じ additive・省略時はキー省略）。

## 設計（run の刻印パターンを厳密踏襲）

- `gates` が入力にある場合のみ record に `gates` を刻む（run と同じく省略時はキーを刻まない）
- 刻む値は入力の gates をそのまま（dict/非dict どちらも・診断のため生値）
- **POLICY_REF は @v2 据え置き**（gates 刻印は additive provenance・gate 挙動不変。Slice D の run と同じ扱い）
- decision-table.md §5 の provenance フィールド表に gates を追記

## Out of scope

- metrics.py 側の plan-quality 集計（消費側は別 follow-up）
- 判定ロジック（plan_quality_check）・priority 順序の変更

## Testing

- gates 完備入力 → record.gates に刻まれる / gates 非dict → 生値が刻まれる / gates 省略 → gates キー無し
- 全 priority で decision 不変（provenance 追加が裁定を変えない）を差分検証
- POLICY_REF @v2 不変

## Mode

standard（additive・gate 挙動不変・ファイル 3-4）。承認境界非接触。
