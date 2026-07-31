# 生 REST / command output を除外した理由

## 経緯

T-35 実走時は、実 REST レスポンスの**形状 drift** を検証する一次証跡として
`raw/gh-calls-*.json` / `raw/spawn-ledger-*.json`（各エントリに `stdout` /
`stderr` を含む）を保存していた。

PR 作成後の CI で **Hook EH-8（metrics privacy / strict）が BLOCK** した:

```text
[Hook EH-8 BLOCK] metrics privacy violation: forbidden fields detected:
  docs/working/TASK-0917/evidence/e2e/raw/gh-calls-1.json:["stderr","stdout"]
  …（計 5 ファイル）
```

## 判断

`docs/ai/metrics-privacy.md` §4 は次を明示している:

| カテゴリ | 扱い |
|---|---|
| **Command output**（env / 認証情報 / 内部データ） | **完全除外（保存しない）** |
| **Provider raw response**（API key / model 内部情報） | **完全除外** |

したがって「フィールド名を変えて保存する」のは**policy の潜脱**であり採らない。
**生出力は削除**し、drift 検証に必要な情報だけを**値を含まない形**で残す。

## 代替として保存したもの

`rest-shape-summary.json` — 各呼び出しの**キー構造と型名のみ**（値はすべて型名へ
置換）。URL 値・SHA 値・本文はいずれも残っていないことを機械確認済み。

形状 drift の検証結果そのものは `findings.md`（F-1〜F-10）に文章で残しており、
**「実 REST の形状が実装の想定と一致した」という結論は再現可能な形で保全**されている。

## 再現したい場合

`README.md` の手順で `harness/driver.py` を実行すると生レスポンスが得られる。
**その出力はコミットしないこと**（EH-8 が再び BLOCK する）。
