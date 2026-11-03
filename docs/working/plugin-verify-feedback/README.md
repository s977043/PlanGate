# Plugin verify の適用条件を先に示す

## 対象と受入条件

基準: PlanGate 8.24.0 / `0d8d9468b815ed7068b31b1a5742667d745ad202`。
観測日: 2026-11-03 UTC。入力 ID: `packaged-verify-guidance`（公開製品のみ）。
利用経路: 配布ファイルの静的読解と隔離コピー。モデル: GPT-6 系 Codex ホスト、
厳密なモデル ID / effort は未取得。Plugin ホストでのモデル実行は未試験。

今回の条件:

1. 上流 / hook 非配布の導入先 / 状態不明を、doctor 要求より先に区別する。
2. N/A を PASS としない。上流は降格しない。既存承認・hash 契約は変更しない。
3. 配布ミラーを同期し、独立fixture・回帰検査で説明の適用範囲を確認する。

## 観測と判断

基準版 `skills/ai-dev-verify/SKILL.md` の settings タスクロック節は、最初に
`doctor --check-settings` PASS を要求し、後段で導入先の `N/A（hook 非配布）`
例外を説明する。順に読んだとき、CLI 非配布の導入先で最初の要求の適用範囲が
分かりにくい。これは公開ファイル上の静的観測であり、利用者の誤読率の測定ではない。

**採用**: 同じ節の先頭へ条件表を置く。**保留**: native Codex とコピー方式の
参照解決全体の改訂、hook 配布、承認処理、installer ownership。新しい Gate は作らない。
#1637 の導入README改善と #1636 のinstaller修正を引き継がない。

独立レビューで、正本 `working-context.md` の CLI/タスクロック記述と、このskillの
既存N/A例外に不整合があることを確認した。今回の表を優先規則にはせず、導入先正本優先・
衝突時は未解決/degradeとして完了保留、と追記した。HO正本の変更は本件に含めない。
これは #1144 の解決やCLI不要の全経路保証ではない。

## 再現と回帰

```sh
python3 -m unittest discover -s tests -p test_verify_plugin_guidance.py -v
sh tests/extras/ta-115-project-root-guidance.sh
python3 scripts/check-stale-skill-refs.py
sh scripts/sync-plugin-plangate.sh --dry-run
git diff --check
```

fixtureは公開 `plugin/plangate` のみを一時領域へコピーする。CLI、hook本体が無く、
必要な同梱referencesが有ることを検査する。承認artifact・消費者の設定は作らない。
同じ先頭表の検査は基準版でFAIL、候補版でPASS、表を除いた負例でFAILを確認した。
これは文書の順序回帰の検出であり、モデルが手順を守ることの検証ではない。
既存ta-115から新しい4テストを呼ぶため、Test workflowの既存入口でも実行される。

## 5観点の検証・レビュー

| 回 | 対象 | 結果・修正・再確認 |
| --- | --- | --- |
| 1 要件 | 基準SHA、#1144/#1242/#1637との重複 | doctor要求と後段例外の配置を確認。導入README等は対象外 |
| 2 動作境界 | 配布fixture、上流/下流/不明、承認形式 | 4テスト成功。既存legacy/c3-prime契約は不変。実承認検証は未実行 |
| 3 設計安全 | 独立read-onlyレビュー | 正本不整合を指摘。優先関係と未解決時停止を追記。private入力なし |
| 4 回帰統合 | mirror、参照、既存ta接続 | ta-115: 5 pass、追加4テスト成功。stale参照0。最終全体/CIはPRに記録 |
| 5 最終判定 | 最新head/base、CI、承認、競合 | PRで確認する。実機未検証・正本不整合を保持し、無条件mergeはしない |

これは5回の独立モデルレビューやレビュー品質の保証ではない。独立担当は設計・安全の
静的レビューを担当。正答ラベル、人間による品質評価、誤検知率、見逃し率、役立ち度、
人手時間は未測定。登録/ロード/実モデル実行/自動dispatch/強制の実績は追加しない。

## 次の案件への手順

1. 製品SHAと配布経路、対象工程・安全な入力ID、期待を記録する。
2. 上流/導入先を判別し、正本との衝突や承認不足があれば完了を保留する。
3. Pluginで実行した範囲だけ入力・出力・採否と理由を残す。未実行は未実行とする。
4. 改善前後を同じ条件で比較する。公開feedbackは独立fixtureに限定する。
5. 参照正本または配布条件が変われば表を再確認する。自動定期監視は設けない。
