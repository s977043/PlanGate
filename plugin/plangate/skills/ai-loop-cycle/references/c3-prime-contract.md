# c3-prime Artifact Contract（正本 / TASK-0872）

> **Status**: v1（TASK-0872 T-2 で確定。#872 / #873 / #874 の共有契約）
> 位置づけ: C-3'（arbiter 裁定）の出力 artifact と Plan Package 束縛の**フィールド契約正本**。
> 関連正本: [`00_concept.md`](./00_concept.md)（C-3' の責務定義）/ [`decision-table.md`](./decision-table.md)（3 値 terminal state）/ [`loopspec.md`](./loopspec.md)（LoopSpec 構造）
> 消費者: `scripts/ai-loop/plan_package.py`（生成）/ `scripts/ai-loop/arbiter.py`（provenance 刻印）/ `bin/plangate validate` + exec preflight（受理・PR-2）/ #873 `delivery.py`（読み取り）/ #874 RunEvidence（供給元）

## 1. Plan Package の定義

同一 `docs/working/TASK-XXXX/` 配下の以下 6 要素。**1 つでも欠けると presence gate で fail-closed**（AC-2/AC-3）。

| # | artifact | 検証 |
|---|----------|------|
| 1 | `pbi-input.md` | 存在 + 非空（0 byte は integrity FAIL / EC-1） |
| 2 | `plan.md` | 同上 + sha256 が `plan_hash` の元 |
| 3 | `todo.md` | 同上 |
| 4 | `test-cases.md` | 同上 |
| 5 | C-1 evidence: `review-self.md` | 存在 + 判定行が PASS（FAIL/欠落/stale は escalate） |
| 6 | C-2 evidence: `review-external.md` | 存在（総合判定の抽出可能性。欠落/FAIL/stale は escalate） |

**evidence 判定マーカー（正規定義 / #887 F-1・F-2・F-5）**: C-1 / C-2 evidence の機械判定は、以下の**行頭アンカー付きマーカー行**のみを正とする（自然文の「判定:」表記からの substring 抽出は行わない — 追記による判定反転を構造的に排除）:

```text
C1-VERDICT: PASS plan=sha256:<64hex>     # review-self.md（受理は PASS のみ）
C2-VERDICT: approve plan=sha256:<64hex>  # review-external.md（受理は approve のみ）
```

- マーカーは**行頭一致**（regex: `^C1-VERDICT:` / `^C2-VERDICT:` + 半角空白 1 個）で、ファイル内に**ちょうど 1 回**存在しなければならない。0 回（マーカー未対応の既存 artifact を含む）および 2 回以上（追記・重複 = 曖昧）は **fail-closed**（escalate）
- `plan=` の値は **evidence 作成時点の plan.md の sha256**。検証時の plan.md の sha256 と不一致なら **stale**（escalate）。stale 判定はこの hash 照合のみで行い、**mtime は判定に使わない**（決定論・touch バイパス不可）
- verdict 値はマーカー内の値のみを読む。受理は C-1 = `PASS` / C-2 = `approve` のみ（それ以外・欠落・型違いはすべて escalate）

C-1/C-2 いずれか**単独**の異常でも `AUTO_APPROVED` にならない（AC-3 / R-002）。

## 2. c3-prime artifact フィールド定義

出力先: `docs/working/TASK-XXXX/approvals/c3.json`（legacy c3.json と同一パス・`approval_kind` で判別）。

| フィールド | 必須 | 型 / pattern | 説明 |
|-----------|------|--------------|------|
| `task_id` | ✅ | `^TASK-[0-9]{4}$` | run の必須識別子（AC-1） |
| `approval_kind` | ✅ | 固定 `"c3-prime"` | legacy（キー自体なし）との判別子。未知値は受理拒否（EC-4） |
| `phase` | ✅ | 固定 `"C-3'"` | |
| `decision` | ✅ | `AUTO_APPROVED` \| `HUMAN_ESCALATED` \| `BLOCKED` | decision-table.md の 3 値。**`c3_status` キーは c3-prime に含めない**（§5 serialization）。**decision↔verdicts 整合（#887 F-3）**: `AUTO_APPROVED` は `reviewers.model_a.verdict` と `model_b.verdict` が**両方 `approve` のときのみ**許容。reject を含む record での `AUTO_APPROVED` は生成側で拒否・受理側で BLOCK |
| `source_sha` | ✅ | `^[0-9a-f]{7,40}$` | W チェック時の対象 commit。**arbiter 入力 `target_sha` と同一値であることを生成時に照合**（不一致は生成拒否 / R-011） |
| `plan_hash` | ✅ | `^sha256:[0-9a-f]{64}$` | **plan.md 単体**の sha256（legacy c3-approval / EH-3 と同一契約・変更しない） |
| `plan_package_hash` | ✅ | `^sha256:[0-9a-f]{64}$` | `artifact_hashes` を key 昇順で正規化した JSON（`json.dumps(sort_keys=True, separators=(',',':'))`）の sha256 |
| `artifact_hashes` | ✅ | object（§1 の 6 要素 → `sha256:` 値） | key はファイル名（`pbi-input.md` 等）。6 要素全数必須 |
| `c1_evidence_ref` | ✅ | string | C-1 evidence の相対パス + 判定（例: `review-self.md#PASS`） |
| `c2_evidence_ref` | ✅ | string | C-2 evidence の相対パス + 総合判定 |
| `reviewers` | ✅ | object（§3） | model_a / model_b の per-reviewer snapshot（R-004） |
| `policy_ref` | ✅ | string | arbiter POLICY_REF（例: `auto-approve-lite-clean@v4`） |
| `issued_at` | ✅ | ISO 8601 UTC | 生成側から**注入**（`datetime.now()` 直参照禁止 — 冪等性 / R-010） |
| `issued_by` | ✅ | string | 例: `arbiter-v0.1` |
| `derived_loopspec_hash` | 任意 | `^sha256:[0-9a-f]{64}$` | §6 で派生した LoopSpec 正規化 YAML の sha256（AC-10 再現性検証用） |
| `^_` prefix キー | 任意 | string | 注釈のみ（legacy c3-approval と同慣習）。上記以外の未知キーは受理拒否 |

## 3. reviewer snapshot（R-004 / AC-5）

`reviewers.model_a` / `reviewers.model_b` は**両方必須**で、各々:

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `verdict` | ✅ | `approve` \| `reject` |
| `plan_hash` | ✅ | この reviewer が観た plan_hash |
| `source_sha` | ✅ | この reviewer が観た source_sha |
| `plan_package_hash` | ✅ | この reviewer が観た plan_package_hash |
| `evidence_ref` | ✅ | 判定根拠の参照（record 内 or 外部 ref） |

**照合規則**: model_a / model_b の `plan_hash` / `source_sha` / `plan_package_hash` がトップレベル値と**三つ組全一致**でなければ `BLOCKED`（同一 Plan Package を観ていない = AC-5 違反・fail-closed）。snapshot の欠落も `BLOCKED`。

## 4. stale / 受理規則（AC-7 / AC-8 / AC-9）

受理側（`bin/plangate validate` / exec preflight — PR-2）は `approval_kind` の有無で分岐する:

| 条件 | 判定 |
|------|------|
| `approval_kind` キーなし | **legacy 経路**（c3-approval.schema.json / 既存 grep+python3 検証をそのまま適用・挙動不変 = AC-11） |
| `approval_kind == "c3-prime"` | 本契約で検証（python3 strict JSON のみ。grep/sed 経路は使わない） |
| `approval_kind` がその他の値 | 受理拒否（EC-4） |
| `decision != "AUTO_APPROVED"` | exec 不可（HUMAN_ESCALATED は Human C-3 待ち・BLOCKED は差し戻し） |
| `decision == "AUTO_APPROVED"` だが reviewers の verdict に `reject` を含む | **BLOCK**（decision↔verdicts 不整合 record = 改竄兆候。#887 F-3 の受理側検証） |
| `plan_hash` ≠ 現 plan.md sha256 | FAIL（stale・legacy と同一規則） |
| `artifact_hashes` のいずれか ≠ 現ファイル sha256 | FAIL（stale。**不一致エントリ名を失敗メッセージに含む**） |
| `source_sha` ≠ 検証時点の対象 SHA | **BLOCK（警告に降格しない fail-closed 固定 / R-003）**。再 C-1/C-2/C-3' を要求 |
| 同一 TASK に legacy と c3-prime が併存 | **物理的に不可能**（同一パス `approvals/c3.json` のため）。上書きは `--force` 相当の明示操作のみ（EC-5 の解決） |

EH-3 hook（`check-plan-hash.sh`）は top-level `plan_hash` のみを strict JSON で読むため、c3-prime に対しても**無変更で機能**する（非退行・本契約が plan_hash を legacy と同一義で保持する理由）。

## 5. serialization 制約（R-009 / #887 F-7 是正）

- `json.dumps(indent=2, sort_keys=True)` で整形（arbiter provenance 出力と同形）
- **`"c3_status"` キーを含めない**（legacy grep 経路が c3-prime を誤受理しないための能動的防御。c3-prime の正は `decision`）
- **legacy grep/sed 抽出経路（`bin/plangate` の非アンカー `grep '"plan_hash"'` 等）は c3-prime に対して流用不可**。c3-prime は `plan_hash` がトップレベルと reviewer snapshot 内に複数回出現するため、非アンカー grep は多行マッチして誤動作する。受理側（PR-2）は `approval_kind` 判別後、c3-prime の全フィールドを **python3 strict JSON のみ**で読むこと（§4 と同一規則。旧記述「インデント幅で grep 衝突を回避する」は誤りだったため削除 / F-7）

## 6. LoopSpec 決定論的派生マッピング（AC-10 / R-012）

LoopSpec（[`loopspec.md`](./loopspec.md) §3）の必須フィールド**全数**を以下で機械導出する。導出不能フィールドが 1 つでもあれば派生失敗 = fail-closed（I-4 と整合）。**手入力 LoopSpec との併用は不可**（派生のみが正）。

| LoopSpec フィールド | 派生元 |
|--------------------|--------|
| `loop.name` | 固定規則: `plan-first-` + task_id 小文字（例: `plan-first-task-0872`） |
| `loop.trigger.type` | 固定既定値: `manual` |
| `loop.goal.description` | plan.md `## Goal` 節の本文（見出し直後から次見出しまで） |
| `loop.goal.exit_criteria_ref` | 固定規則: `docs/working/<task_id>/test-cases.md`（AC マッピング表） |
| `loop.context.include` | 固定既定値: `[plan_package, diff, test_results]` |
| `loop.context.exclude` | 固定既定値: `[stale_tool_outputs]` |
| `loop.context.external_sources` | 固定既定値: `[]`（Plan Package は internal 正本由来。外部入力を要する run は本派生の対象外 = Human 設計へ escalate） |
| `loop.scope.allowed_paths` | plan.md `## Files / Components to Touch` 節から抽出したパス列挙（抽出 0 件は派生失敗） |
| `loop.actors.maker` / `checker` | 呼び出し側必須引数（maker == checker は派生失敗 / I-2） |
| `loop.verification.deterministic` | plan.md Testing Strategy `Verification Automation:` 行のコマンドを `&&` 分割した各 cmd（expect_exit 既定 0） |
| `loop.verification.review` | 固定既定値: `[requirements_fit, architecture_consistency]` |
| `loop.stopping_rule.terminal_state_ref` | 固定: `decision-table.md` |
| `loop.stopping_rule.round_limit_ref` | 固定: `execution-runbook.md §2-(7)` |
| `loop.memory.write` | 固定既定値: `[decision_record]` |
| `loop.memory.ref` | 固定: `execution-runbook.md §2-(4)` |
| `loop.escalation.touches_ho` | 固定: `unconditional`（I-1/I-8・上書き不可） |
| `loop.escalation.budget_ref` | 固定: `arbiter-policy.md §7` |

派生結果の正規化 YAML の sha256 を `derived_loopspec_hash` として c3-prime に刻印できる（同一入力 2 回 → 同一 hash = シナリオ 9 の機械検証点）。

## 7. #873（delivery.py）への引き渡し

issue #873 の MERGE_READY 状態機械は c3-prime を**読み取り専用**で消費する。読むフィールド: `task_id` / `decision` / `source_sha` / `plan_hash` / `plan_package_hash`。head SHA 束縛は `source_sha` を基点とし、PR head が `source_sha` の子孫でない場合は #873 側で fail-closed（本契約はフィールド提供まで。遷移規則は #873 の正本で定義）。

**trust boundary（R-018 / #887 F-4）**: arbiter provenance / c3-prime record の `decision` は「その入力に対する裁定」であり、record の実在 artifact への束縛（§4 の hash / source_sha / verdict 整合検証）を**受理側が再実行して初めて信頼できる**。#873 delivery.py および PR-2 受理側は decision 値を無検証で信頼してはならない（fail-closed 再検証が必須）。record が Plan-first 正規経路（`plan_package.py` 経由）で生成されたことの担保は本再検証 + §4 の全規則で構成する。

## 8. バージョニング

本契約の破壊的変更（required 追加・型変更・§6 マッピング変更）は #872 / #873 / #874 の 3 issue 合意 + plan Replan を要する。additive な任意フィールド追加は本ファイルの改版のみでよい（`^_` 注釈キーは自由）。
