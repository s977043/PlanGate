# V-3 外部レビュー（Codex）— TASK-0090 / #224

## 結果サマリ
critical: 0 / major: 3 / minor: 3 / info: 1（初回 NOT APPROVE → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | strip-components=2 だと .plangate-plugin/plangate/<kind> に展開され §3/§4 の .plangate-plugin/<kind> 前提と不整合 | strip-components=3 に修正（plangate-<ver>/plugin/plangate の 3 段除去）+ 説明追記 |
| MJ-2 | major | versioning-stability-policy.md が本ブランチに未存在で中核仕様が壊れリンク依存 | 「予定正本（#225/#263・マージ順依存）」明記 + §1 に安定性レベル定義を自己完結内挿 + §4-bis マージ順記録（推奨 #263→本PR） |
| MJ-3 | major | 表は hooks 不可だが注記は rules/hooks を C-3 承認で許容と読め矛盾 | hooks は C-3 承認があっても overlay 不可（settings 適用プロセスで扱う）と分離、C-3 例外は rules のみに限定 |
| mn-1 | minor | §2.3 検証パスが plugin/plangate/.claude-plugin/...（消費側は .plangate-plugin/...）| 検証パスを .plangate-plugin/.claude-plugin/plugin.json に修正 |
| mn-2 | minor | curl|tar の安全性説明不足 | 固定タグ必須 + tar -tz 事前確認 + signature/commit 確認の安全性注記追加 |
| mn-3 | minor | .plangate-version(vX.Y.Z) と plugin.json(0.5.0) の突合ルール未定義 | バージョン 2 軸表を追加（リリースタグ=固定単位/真、plugin 内部版=情報用、CI はタグを真に突合）|
| info | info | archive 内パス自体は整合（strip 値のみ問題）| MJ-1 で解消 |

## 判定
major 3 / minor 3 を全反映。critical 0。回帰 V-1 全 PASS（T1-T6+E1/E2、MJ-1 strip/mn-1 path 確認）。

## C-4 ラウンド: gemini-code-assist（PR #266）
medium 3 件（非ブロッキング）+ main 追従:
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| GM-1 | medium | update 時 tar 再実行で削除済ファイルが残る ghost file | 展開コマンドを `rm -rf .plangate-plugin/* && tar ...` に冪等化、§2.2 に ghost file 非発生を明記 |
| GM-2 | medium | 消費側で切れる相対リンク（responsibility-classes/orchestrator-mode/hybrid-architecture、plugin 非同梱の統制系）| 絶対 GitHub URL（blob/main）へ置換（4 箇所）|
| GM-3 | (派生) | #263 マージ済で「予定正本/未マージ」表現が陳腐化 | main 追従（#263-265 マージ取り込み）+ 表現を「マージ済・main 在席」「解決済」に更新、§4-bis 改題 |

判定: medium のみ（critical/major 0）。全反映。回帰 V-1 全 PASS・shell 構文 OK・0 behind main。
