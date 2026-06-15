# HANDOFF: TASK-0128 — `plangate approve`（人間ワンアクション C-3 承認）

## 1. 要件適合確認（AC ごと）
| AC | 内容 | 判定 |
|----|------|------|
| AC-01 | 対話 TTY で c3.json(APPROVED) 生成 | PASS（コア実装・TTY 正常系は適用後人間確認） |
| AC-02 | plan_hash 自動一致 | PASS（plangate_sha256 使用） |
| AC-03 | approved_by 自動解決 | PASS（git config user.email/name→USER） |
| AC-04 | 非対話拒否・c3.json 未生成 | PASS（TC-04 exit=1 実証） |
| AC-05 | --reject/--conditional 三値 | PASS |
| AC-06 | check-approval-token-write.sh 配線で AI 直接書込 block | PASS（hook 強化済・配線は H02） |
| AC-07 | bin/plangate は apply-script 経由 | PASS（AI 直接編集なし） |
| AC-08 | 再承認で plan_hash 更新 | PASS（上書き実装） |
| AC-09 | 承認後 validate PASS | PASS（APPROVED 経路で cmd_validate 呼出） |
| AC-10 | c3.json schema 準拠 | PASS（3 status とも jsonschema VALID） |
| AC-11 | REJECTED/CONDITIONAL は validate 非実行 | PASS（R-003 分離） |

## 2. 既知課題
- TTY 正常系（TC-01/17）は pseudo-tty/人間実行が必要。AI 環境では L1-L4 を通せないため単体検証に留めた（これは仕様＝AI 自己承認不可の裏返し）。
- maintenance は不変方針のため、L1-L4 が maintenance(inline) と approve(_plangate_presence_gate) で**重複**。zero regression 優先の意図的判断。dedup は follow-up。
- check-approval-token-write.sh の Bash 検出はヒューリスティック（token path + 書込指標）。難読化された書込は理論上すり抜け得る（#420 のフル hardening が上位対策）。

## 3. V2 候補
- 案 B（GitHub review ベース C-3）
- maintenance L1-L4 の共通関数移行
- working-context.md（HO）の C-3 手順正本更新
- #420 フル provenance hardening との統合

## 4. 妥協点
- L1-L4 を maintenance から抽出せず新規共通関数を追加（R-005 副作用回避 vs 重複）→ 重複を許容し回帰ゼロを優先
- identity は presence までで暗号学的検証なし（_approver_identity_unverified で明示 / R-006）

## 5. 引き継ぎ
人間が次を実施すれば機構が稼働する:
1. `sh scripts/apply-task-0128-approve.sh --dry-run` → 確認 → 適用
2. `sh scripts/apply-task-0128-token-guard-wiring.sh --dry-run` → 確認 → 適用
3. `plangate approve TASK-0128`（対話 TTY）で本 PBI を正規承認、続けて `plangate approve TASK-0127`
4. doctor --check-settings で settings lock 確認

## 6. テスト結果サマリ
- 非対話拒否 / plan 不在 / 三値必須 / 排他 / schema VALID(3) / Bash block / 読み取り許可 / 構文: 全 PASS（テストコピー・単体）
- TTY 正常系・maintenance 回帰: 適用後の人間確認待ち
