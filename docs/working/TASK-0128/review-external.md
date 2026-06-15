# External Review -- TASK-0128

> Phase: c2
> Reviewer: codex
> Generated: 2026-06-12T04:58:20Z

**指摘事項**

- **High:** `check-approval-token-write.sh` の扱いが TASK-0123 と衝突/重複しています。既存計画では同スクリプトは承認トークン全般を block する HO 対象として設計済みで、`Bash` も対象に含める前提です（[docs/working/TASK-0123/plan.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0123/plan.md:62)）。TASK-0128 が同名スクリプトを別 apply-script で新規配線すると、TASK-0123 の HMAC/CI/schema 変更との順序・責務が曖昧になります。TASK-0123 を先行適用するのか、TASK-0128 に統合するのかを plan に明記すべきです。

- **High:** 「AI の c3.json 直接書込を block」が `PreToolUse(Edit|Write)` だけでは不十分です。現在の `.claude/settings.json` では `Bash` は delegation guard のみで、承認トークン書込 guard は未配線です（[.claude/settings.json](/Users/user/Documents/GitHub/plangate/.claude/settings.json:13)）。AI は `Bash` で `cat > docs/working/.../approvals/c3.json` のように書けるため、唯一経路化を主張するなら `Bash` matcher と Bash 入力から対象 path を検出するテストが必要です。

- **High:** `--reject` / `--conditional` と「`validate <TASK>` 相当の最終確認」が矛盾します。現行 `validate` は `c3_status = APPROVED` 以外を FAIL にします（[bin/plangate](/Users/user/Documents/GitHub/plangate/bin/plangate:884)）。REJECTED/CONDITIONAL を正常な承認判断として発行するなら、最終確認は `validate` そのものではなく「schema + plan_hash + status 表示」に分ける必要があります。

- **High:** `CONDITIONAL` / `REJECTED` の必須フィールドが plan にありません。schema は `CONDITIONAL` なら `conditions`、`REJECTED` なら `rejection_reason` を必須にしています（[schemas/c3-approval.schema.json](/Users/user/Documents/GitHub/plangate/schemas/c3-approval.schema.json:88)）。CLI 仕様に `--conditions <text>` / `--reason <text>`、または対話入力を含めないと schema 違反の `c3.json` が生成されます。

- **Medium:** L1-L4 共通化の副作用が未整理です。`cmd_maintenance` の L1-L4 は `_maintenance` ディレクトリ作成、`maintenance_start_attempt` 監査イベント、maintenance 固有エラーメッセージを内包しています（[bin/plangate](/Users/user/Documents/GitHub/plangate/bin/plangate:1238)）。そのまま抽出すると `approve` 実行で maintenance 監査ログが混ざるか、不要な `_maintenance` 生成が起きます。共通関数は `context=maintenance|approve` を受け、audit event 名・プロンプト・副作用を分離する設計が必要です。

- **Medium:** `approved_by = git config user.email/name` は「人間 presence」の証明ではありません。git config は AI 実行環境でも読め、任意設定も可能です。L1-L4 は presence、防御であって identity ではないため、`approved_by_source: git-config` や `approver_identity_unverified` のように provenance の限界を明示するか、手入力確認を追加した方が安全です。

- **Medium:** Mode が `high-risk` は低めです。既存 TASK-0123 は承認境界・security hook・HO 横断変更として `critical` 判定です（[docs/working/TASK-0123/plan.md](/Users/user/Documents/GitHub/plangate/docs/working/TASK-0123/plan.md:31)）。TASK-0128 も `bin/plangate`、`.claude/settings.json`、`approvals/c3.json` 発行経路という承認境界の中核を変更するため、少なくとも critical 判定に引き上げるのが整合的です。

- **Medium:** Testing Strategy に schema validation が不足しています。`c3.json` は schema があり、三値 status の条件付き必須フィールドもあるため、`validate-schemas` または対象 schema 直接検証を acceptance に入れるべきです。plan_hash 整合だけでは壊れた `c3.json` を検出できません。

**修正方針**

この plan は採用前に、TASK-0123 との統合方針、`Bash` 経由書込 block、REJECTED/CONDITIONAL の schema 対応、`validate` と approve 結果表示の分離を直すべきです。特に `Edit|Write` だけで「唯一経路化」と書くのは危険です。

---

## R-NNN 監査表（追記専用 / TASK-0076 F5-C）

| R-NNN | severity | 指摘要旨 | status | reflected_in | notes |
|-------|----------|---------|--------|--------------|-------|
| R-001 | High | check-approval-token-write.sh が TASK-0123(#420) と重複/順序曖昧 | reflected | plan.md(Constraints/Approach) | 本PBIは既存scriptの配線のみ・#420 HMAC等は再実装しない |
| R-002 | High | Edit\|Write のみでは Bash 経由 c3.json 書込を防げない | reflected | plan/todo/test-cases | Bash matcher + path検出テスト追加 |
| R-003 | High | --reject/--conditional と validate(APPROVED外FAIL)が矛盾 | reflected | plan(Approach)/test-cases | 最終確認をvalidateから分離 |
| R-004 | High | CONDITIONAL/REJECTED 必須フィールド欠落(schema違反) | reflected | plan/todo/test-cases | --conditions/--reason・schema準拠 |
| R-005 | Med | L1-L4抽出の副作用(_maintenance生成・監査混入) | reflected | plan/todo | context=maintenance\|approve 引数 |
| R-006 | Med | approved_by=git config は presence≠identity | reflected | plan/test-cases | approved_by_source/identity_unverified注記 |
| R-007 | Med | Mode=high-risk低い→critical | reflected | plan(Mode判定) | critical化・V-4追加 |
| R-008 | Med | Testing に schema validation 不足 | reflected | plan/test-cases | acceptance に schema検証 |

反映コミット時メッセージに `Refs: R-001..R-008` を付す。
