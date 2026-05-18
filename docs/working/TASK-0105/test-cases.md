# テストケース — TASK-0105 / #282
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | check-plan-hash.sh が python strict 抽出（sed 廃止）・不正JSON で空 | 構造突合+実行 |
| T2 | AC2 | ta-11: 正常/注入/無/不正JSON 全 shell≡python parity・pass=4 fail=0 | テスト |
| T3 | AC3 | (a)正常 c3+一致 plan→PASS exit0 (b)不正JSON→SKIP exit0 (c)改竄→BLOCK exit1 | 実リポジトリ smoke |
| T4 | AC3 | run-tests.sh 68 passed 0 failed（EH-3 hooks 回帰なし）| テスト |
| T5 | AC4/AC5 | python3 が :108 既出依存・hook-enforcement.md に厳格化=安全側注記 | 構造突合 |
## Edge
- E1: 不正c3+改竄 → SKIP（不正記録を承認境界根拠にしない＝旧 sed は比較続行していた）
- E2: scope=check-plan-hash.sh+ta-11+hook-enforcement.md のみ
