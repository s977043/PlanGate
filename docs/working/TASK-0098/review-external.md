# V-3 外部レビュー（Codex）— TASK-0098 / #200

## 結果サマリ
critical: 0 / major: 3 / minor: 3 / info: 4（初回 NOT APPROVE → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | v1_first_pass_rate が unknown と 0 を混同（未観測 TASK も分母）| 観測済（bool 記録）のみ分母、未観測は unknown。observed/unknown 件数を JSON+md 出力（rate は known のみ）|
| MJ-2 | major | _in_range が ISO TZ 正規化せず文字列日付のみ（TZ で日付ズレ）| fromisoformat で parse→UTC 日付化、parse 不能時のみ YYYY-MM-DD fallback。両端含む正本明記 |
| MJ-3 | major | doc/template は hook violation 前提だが reporting.py 未集計（正本不整合）| _audit/hook-events.log の VIOLATION を期間集計（ts UTC 日付化・hook 別）、report に追加。doc §3 整合 |
| mn-1 | minor | status.md read_text が OSError 未捕捉（壊れlog で全体落ち）| try/except OSError でガード（他 artifact と一貫） |
| mn-2 | minor | latency が '-' 表示で doc「unknown」と揺れ | TASK 内訳の latency を `unknown` 表示に統一 |
| mn-3 | minor | cmd_report 最小チェックのみで意図不明瞭 | 「--from/--to 必須検証は argparse に委譲」コメント追加 |
| info×4 | info | keep-rate graceful('-')/#272 明記 / advisory 一貫 / bin diff report のみ(keep-rate#198・context#199 非混入) / subprocess 不使用 | 対応不要 |

## 判定
major 3 / minor 3 を全反映。critical 0。回帰: v1 observed/unknown 区別 /
ISO TZ 正規化（+09:00/Z）/ hook violation hook 別集計 / status try /
fix_loop 非日付 / from>to exit2 全 PASS。advisory・承認境界不変。
