# External Review — TASK-0144

> Phase: C-2
> Generated: 2026-06-25

## 指摘 ID テーブル

| R-NNN | レーン | Severity | 状態 | 反映コミット |
|-------|--------|----------|------|------------|
| R-001 | 設計妥当性 | critical | ✅ 反映済み | plan.md C-2反映版（cmd_exec 変更なし・exec 前生成） |
| R-002 | 設計妥当性 | critical | ✅ 反映済み | plan.md C-2反映版（cmd_exec 変更なし） |
| R-003 | コードベース整合 | major | ✅ 反映済み | plan.md Step4（EH-3 SKIP 責務を「通す」のみに限定） |
| R-004 | コードベース整合 | major | ✅ 反映済み | plan.md Step3 / test-cases.md EC（旧 c3.json も valid） |
| R-005 | 設計妥当性 | major | ✅ 反映済み | plan.md Step5 / test-cases.md EC（不正設定で WARN） |
| R-006 | 設計妥当性 | major | ✅ 反映済み | test-cases.md TC-06（schema 検証 TC 追加） |
| R-007 | 設計妥当性 | minor | ✅ 反映済み | plan.md Files テーブル（settings-wiring の HO 表記削除） |
| R-008 | 設計妥当性 | minor | ✅ 反映済み | test-cases.md TC-07（件数固定削除・0 failed のみ） |

---

## Codex レビュー（設計妥当性 + コードベース整合レーン）

> Reviewer: codex
> Generated: 2026-06-25T08:25:27Z

### R-001 [critical] AI 自己承認と Core Contract の衝突

`conversation` モードで "AI が cmd_exec 内で c3.json を自動生成" する設計は、現行 Core Contract の C-3 境界と衝突する。

Core Contract は「C-3 承認前に production code を変更しない」を不可侵としており、現行 `bin/plangate approve` は「AI 自己承認を L1-L4 で封じる」設計になっている（`bin/plangate:2137`）。

**修正案**: conversation モードを「AI 自己承認」ではなく「会話内の人間 APPROVE 発話を機械的に c3.json に転記する経路」として再設計する。exec 前に c3.json が存在し、schema と plan_hash と承認ソースが検証済みである構造にする。

### R-002 [critical] cmd_exec でのゲート自己充足

`cmd_exec` に c3.json 自動生成を入れると、「exec が承認を確認する」から「exec が承認を作る」に変わり C-3 の意味が崩れる。

現行 `cmd_exec` は既存 `approvals/c3.json` の存在と `APPROVED` を先に要求している（`bin/plangate:1914`）。この順序を維持する必要がある。

**修正案**: c3.json 生成は exec より前（人間 APPROVE 発話後）に完了させる。`cmd_exec` は変更不要。

### R-003 [major] EH-3 の c3.json SKIP が広すぎる

`approvals/c3.json + conversation mode → SKIP (exit 0)` は schema 妥当性・c3_status=APPROVED・plan_hash 一致・source=conversation の存在確認を別経路で fail-closed にしない限り、承認ファイルの改変経路になる。

**修正案**: EH-3 SKIP は「Write を通す」役割のみ。中身の検証はアプリ層（AI の c3.json 生成コード）と exec 時の EH-2 に委ねる。ただし SKIP の条件を厳密に定義（`docs/working/TASK-XXXX/approvals/c3.json` pattern に限定）し、plan にその理由を明示する。

### R-004 [major] c3-approval.schema.json の additionalProperties: false

plan は「additionalProperties: false でない場合は安全」としているが、現行 `c3-approval.schema.json` はトップレベルで `additionalProperties: false` である（`schemas/c3-approval.schema.json:124`）。

`source` フィールドを追加する場合、schema への追加は必須。旧 c3.json が通り、新 c3.json も通ることを両方テストに入れる必要がある。

**修正案**: plan の Risk 評価を修正。「additionalProperties: false のため source フィールドの schema 追加は必須」と明記する。

### R-005 [major] .plangate.yml fail-open の問題

ファイルが存在して PyYAML 未導入・構文不正・未知 mode の場合まで `cli` に黙って落とすと、ユーザーは `conversation` を設定したつもりで従来挙動になる。

**修正案**: `.plangate.yml` が存在する場合は「読めない/不正なら doctor WARN/FAIL」を追加する。AC に追加するか、test-cases のエッジケースとして明示する。

### R-006 [major] plangate-config.schema.json の検証コマンド未整備

`schemas/plangate-config.schema.json` を追加しても、現行 schema mapping（`scripts/schema_mapping.py:20`）は JSON artifact のみを扱っており、`.plangate.yml` の検証コマンド・doctor 統合・ta-45 内の明示 validation が plan に記載されていない。

**修正案**: ta-45 に `.plangate.yml` の schema 検証 TC を追加（jsonschema CLI 等で検証）。test-cases.md の TC-06 に検証コマンドを明記する。

### R-007 [minor] docs/ai/settings-wiring-contract.md の HO 表記矛盾

plan の Files テーブルで `docs/ai/settings-wiring-contract.md` に HO ✅ を付けつつ「AI 直接 (doc-light SKIP)」としている。HO なら apply-script 必須のはず。

現行 EH-3 の HO 判定パスは `docs/ai/*.md` を含まず（`check-plan-hash.sh:122`）、doc-light は非 HO `.md` の SKIP（`check-plan-hash.sh:145`）。

**修正案**: Files テーブルの HO カラムから `docs/ai/settings-wiring-contract.md` の ✅ を削除。「AI 直接 (doc-light SKIP)」の方が正確。

### R-008 [minor] テスト件数の固定化

「343 → 349 件想定」は drift しやすい。`sh tests/run-tests.sh` exit 0 と TA-45 の PASS 数に寄せた方が安全。

**修正案**: test-cases.md の TC-07 から件数予測を削除し「0 failed」確認に変更する。

---

## Gemini レビュー

> Reviewer: gemini
> Status: unavailable（IneligibleTierError — CLI 認証エラー）
> Reason: Gemini CLI が `IneligibleTierError` で認証失敗。Antigravity suite への移行が必要。
> 代替観点: R-001〜R-008 は Codex のコードベース整合レーンで代替カバーされている。
> 未充足リスク: Gemini 固有の設計整合視点が未確認。
> verdict: WARN
