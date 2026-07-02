# execution-runbook — L2 裁定エンジン PoC 実行手順

> 適用ドメイン: ai-loop-workflow（docs/workflows/ai-loop/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）
> 実装本体: [`scripts/ai-loop/arbiter.py`](../../../scripts/ai-loop/arbiter.py)
> テスト: [`scripts/ai-loop/test_arbiter.py`](../../../scripts/ai-loop/test_arbiter.py)

---

## 1. 目的

`docs/workflows/ai-loop/decision-table.md` / `flow-detect.md` / `lite-criteria.md` /
`docs/ai/ai-loop/ho-paths.md` に定義された flow→detect→escalate 判断ロジックを、
`scripts/ai-loop/arbiter.py`（L2 裁定エンジン PoC）を用いて 1 サイクル実行する
手順を定義する。

**制約（絶対）**: 本エンジンは PlanGate 本番フロー（WF-00〜WF-07・`bin/plangate`・
`scripts/hooks/`）から一切呼ばれない**隔離 PoC**である。W チェック（Model A/B/C/D
の verdict）の**品質そのもの**は L1（本 runbook を実行する呼び出し側）の責務であり、
`arbiter.py`（L2）は入力された verdict を決定論ロジックで裁定するのみで、verdict
自体の正しさを検証しない。

---

## 2. 1 サイクルの手順

### (1) 変更ファイルリスト取得

```sh
git diff --name-only <base>...<head>
```

対象コミット（`target_sha`）の変更ファイル一覧を取得する。

### (2) Model A / Model B による W チェック（サブエージェント 2 体・独立実行）

- **Model A**（順方向・設計妥当性）: 変更が「正しく作られているか」を検証する
  サブエージェントを起動し、`approve` / `reject` の verdict を得る
- **Model B**（逆方向・adversarial）: 変更が「どう壊れるか」を検証する
  サブエージェントを、Model A とは**独立**に起動し、`approve` / `reject` の
  verdict を得る
- Model B が `reject` の場合、reject 理由から `reject_category` を決定論
  マッピング（[`flow-detect.md`](./flow-detect.md) §3.2.1）に照合可能な
  カテゴリ文字列で記録する（`ho_path_contact` / `permission` / `irreversible` /
  `security_break` / `public_api` / `data_integrity` / `migration` /
  `auth_change` / `logic` / `performance` / `test_shortage` / `documentation` /
  `format` / `naming` のいずれか。一致しない場合は分類器側で `critical` 扱いに
  フォールバックされる）
- severity=minor/low の不一致時は Model C（セキュリティ・認証・権限観点）/
  Model D（後方互換・データ整合観点）も同様に独立起動する
  （[`flow-detect.md`](./flow-detect.md) §3.3）

### (3) `arbiter.py` へ入力し裁定を得る

Model A/B（必要なら C/D）の verdict と、boundary/lite/class 判定に必要な
情報を JSON にまとめ、`arbiter.py` へ渡す。

```sh
python3 scripts/ai-loop/arbiter.py --input /path/to/input.json
# または stdin 経由:
echo '{...}' | python3 scripts/ai-loop/arbiter.py
```

入力 JSON のフィールド仕様は [`arbiter.py`](../../../scripts/ai-loop/arbiter.py)
モジュール docstring および [`decision-table.md`](./decision-table.md) §2・§5 を
正本とする。

### (4) decision record を保存

`arbiter.py` の stdout（decision record JSON）を、以下の命名規則で保存する。

> **正本性の注記**（[`decision-table.md`](./decision-table.md) §5 PoC スコープと整合）:
> `AUTO_APPROVED` の record のみが **provenance 刻印**（正本）。
> `HUMAN_ESCALATED` / `BLOCKED` の record は **audit record（暫定）**であり、
> 正式な audit trail の定義は Phase 3 以降で行う。

```text
docs/working/ai-loop-runs/<UTC日時: YYYYMMDDTHHMMSSZ>-<sha7>.json
```

```sh
mkdir -p docs/working/ai-loop-runs
python3 scripts/ai-loop/arbiter.py --input /path/to/input.json \
  > "docs/working/ai-loop-runs/$(date -u +%Y%m%dT%H%M%SZ)-$(git rev-parse --short HEAD).json"
```

保存した decision record は次回以降の監査・L4 学習（[`review-feedback-loop.md`](./review-feedback-loop.md)）
の入力となる。

### (5) exit code に応じた分岐

| exit code | decision | 動作 |
|-----------|----------|------|
| `0` | `AUTO_APPROVED` | 自動承認として扱う。provenance 刻印（正本）を保存して 1 サイクル完了 |
| `2` | `HUMAN_ESCALATED` | **停止して人間へ escalate**。audit record（暫定）の `w_check` / `boundary_check` / `lite_check` を提示し、人間の判断を仰ぐ |
| `3` | `BLOCKED` | ブロックとして扱う。当該変更を採用しない。audit record（暫定）を保存し、理由（stderr の裁定サマリ）を記録する |
| `1` | （入力エラー） | 入力 JSON の不備。stderr の理由メッセージに従い入力を修正して再実行する |

---

## 3. 検証可能性 4 条件への適合

[`orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) §検証可能性
の 4 条件に対する `arbiter.py` の適合状況:

| 条件 | 適合内容 |
|------|---------|
| **冪等性** | 同一入力 JSON に対し `decision` は常に同一（`ProvenanceSchemaTests.test_auto_approve_provenance_fields` で検証。`timestamp` のみ実行毎に変化するが裁定結果には影響しない） |
| **明示的失敗** | 入力エラー（exit code 1）は必ず理由メッセージを stderr に出力する（`[arbiter] 入力エラー: <理由>`） |
| **トレーサビリティ** | boundary 判定で HO パターンに一致した場合、一致パス・パターン・分類を理由サマリ（stderr）に含める |
| **テスト可能性** | `test_arbiter.py`（59 ケース）で decision table 全 priority・severity 全分類・C/D 全パターン・AC-8 安全側・boundary 全パターン・ho-paths.md との drift を機械的に検証可能 |

---

## 4. 制約の明記

- 本エンジンは PlanGate 本番フロー（WF-00〜WF-07・`bin/plangate`・
  `scripts/hooks/`）から一切呼ばれない**隔離 PoC**である
  （[`docs/ai/ai-loop/phase3-impact-report.md`](../../ai/ai-loop/phase3-impact-report.md) §b.1
  トリガー 1 の判断記録を参照）
- W チェック（Model A/B/C/D）の verdict 品質は **L1（本 runbook を実行する
  呼び出し側）の責務**。`arbiter.py`（L2）は入力された verdict の内容が
  正しいかどうかを検証しない（決定論ロジックの適用のみ）
- boundary=touches-HO は W チェック結果・severity 分類・C/D 裁定の**すべて
  をスキップする絶対条件**（[`ho-paths.md`](../../ai/ai-loop/ho-paths.md) 判定ルール）
- provenance の `issued_by` は自己申告であり、署名等の発行元検証機構は
  本 PoC のスコープ外（[`phase3-impact-report.md`](../../ai/ai-loop/phase3-impact-report.md) §d
  リスク 5、issue #420 EH-3 発行元検証と同型の未解決課題）

---

## 5. 関連ドキュメント

- [`docs/workflows/ai-loop/decision-table.md`](./decision-table.md) — Decision table・provenance schema・CB
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — flow→detect→escalate 動作フロー
- [`docs/ai/ai-loop/ho-paths.md`](../../ai/ai-loop/ho-paths.md) — boundary=touches-HO 判定の正本
- [`docs/ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) — Arbiter L0 policy
- [`docs/ai/ai-loop/phase3-impact-report.md`](../../ai/ai-loop/phase3-impact-report.md) — 分離トリガー条件・判断記録
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) — CB-1 事後 reject を L4 学習へ還元する閉ループ
- [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md) — 検証可能性 4 条件の正本
