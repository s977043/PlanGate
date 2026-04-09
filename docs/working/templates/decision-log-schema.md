# decision-log.jsonl スキーマ定義

## 概要

判断の履歴を append-only で記録し、レビュー・振返り時に「なぜそうなったか」を追跡可能にする。

## ファイル形式

JSON Lines（`.jsonl`）— 1行1エントリ、append-only。

## スキーマ

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| ts | ISO 8601 string | Yes | 判断日時（例: `2026-04-06T14:30:00+09:00`） |
| phase | string | Yes | `brainstorm` / `plan` / `C-1` / `C-2` / `exec` |
| task | string | Yes | タスクID（`T-1` 等）or フェーズ名 |
| type | enum | Yes | `design` / `scope` / `tool` / `risk` / `other` |
| decision | string | Yes | 何を決めたか |
| reason | string | Yes | なぜそう決めたか（コードベース由来の根拠） |
| alternatives | string[] | Yes | 検討した他の選択肢（空配列可） |
| chosen_by | enum | Yes | `agent` / `human` / `auto` |

## 記録タイミング

- 計画変更（小・中・大）発生時
- レビュー指摘対応時
- 設計判断時（ライブラリ選定、パターン選択等）

## サンプル

```jsonl
{"ts":"2026-04-06T14:30:00+09:00","phase":"exec","task":"T-4","type":"design","decision":"正規表現を /[^\\u0020-\\u007E]/|\\s/ に変更","reason":"ESLint no-control-regex ルールに抵触したため","alternatives":["ESLint ルールを無効化","元の正規表現を維持"],"chosen_by":"agent"}
{"ts":"2026-04-06T15:00:00+09:00","phase":"exec","task":"T-8","type":"scope","decision":"IT_RANKING のパス生成未対応を対象外とする","reason":"IT_RANKING に記事データが存在しないため実害なし","alternatives":["IT_RANKING 用の分岐を追加"],"chosen_by":"agent"}
```

## type の使い分け

| type | 説明 | 例 |
|------|------|---|
| design | 実装設計の判断 | 正規表現の変更、メソッド分割方針 |
| scope | スコープの追加・除外 | IT_RANKING を対象外にする |
| tool | ツール・ライブラリの選定 | PHPUnit vs Pest の選択 |
| risk | リスク受容の判断 | N+1 を許容する（404ケースのみ） |
| other | 上記に該当しない判断 | 命名の変更 |
