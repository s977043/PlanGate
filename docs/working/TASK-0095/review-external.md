# V-3 外部レビュー（Codex）— TASK-0095 / #197

## 結果サマリ
critical: 0 / major: 1 / minor: 2 / info: 4（初回 REQUEST CHANGES → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | telemetry_tags が free-form pattern で metrics-privacy §4（鍵/アカウントID/社内モデル名）を排除できない | provider/generation を**固定 enum** 化（provider:{openai,anthropic,claude_code,codex,unknown} / generation:{gpt-5.5,gpt-5.5-pro,gpt-5-mini,legacy,unknown}）。md に registry 節 + free-form 不可を明記。yaml 値は enum 適合 |
| mn-1 | minor | yaml v2 ブロック挿入位置が次 profile 見出しコメントの後で所属誤認 | 再移行で末尾コメント行をスキップし profile 内末尾に挿入（comment→header→v1→v2 が profile 内に収まることを確認）|
| mn-2 | minor | legacy_or_unknown が escalate なのに max_retries:1 で曖昧 | legacy max_retries:**0** に変更 + md に「on_*: escalate のとき max_retries 非適用」明記 |
| info×4 | info | v1 後方互換 OK / retry 責務分離 OK（#203 前方参照明記必須＝明記済）/ Core Contract 不変 yaml・md 両方 / version enum[1,2]=minor 整合 | 対応不要 |

## 判定
major 1 / minor 2 を全反映。critical 0。回帰: v2 yaml jsonschema valid・
v1 後方互換 valid・telemetry enum 適合・legacy 安全側明確化。
#203(PR#269)/#196(PR#268) は前方参照（依存・推奨マージ順を md に明記）。
