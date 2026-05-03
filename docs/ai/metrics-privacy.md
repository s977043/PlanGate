# Metrics Privacy and Public Data Policy

> **Status**: v1
> **Review cadence**: Monthly
> **Owner**: Governance / Engineering
> **Related**: [Issue #195 PBI-HI-001 Metrics v1](https://github.com/s977043/plangate/issues/195) / [docs/ai/harness-improvement-roadmap.md](./harness-improvement-roadmap.md)

## 1. 目的

PlanGate の Metrics v1（PBI-HI-001 / #195, v8.6.0）が記録する workflow event / hook violation / model profile / provider / latency / tool count / test result について、**公開してよい情報と公開すべきでない情報を分離**し、redaction / retention / public data policy を確定する。

PlanGate は public repository として運用されるため、metrics log がそのまま公開ストレージや公開リポジトリにコミットされた場合のリスクを **実装前に** 抑える。

## 2. 用語

| 用語 | 意味 |
|------|------|
| **metrics log** | `bin/plangate metrics` (#195) が出力する append-only event log |
| **workflow event** | C-3 / V-1 / C-4 / hook violation / exec / handoff など、workflow 上の節目 |
| **redact** | 機微情報を不可逆な形（hash / placeholder）に置き換えること |
| **sanitize** | 構造を保ったまま機微部分のみ除去すること |

## 3. 保存してよい情報（Allowed）

以下は metrics log に保存してよい。

| カテゴリ | 例 |
|---------|------|
| Workflow event 種別 | `c3.approved`, `v1.passed`, `hook.violation`, `exec.started` |
| Phase / Mode | `plan`, `exec`, `verify`, `light/standard/high-risk/critical` |
| Gate 結果 | `APPROVED`, `REJECTED`, `CONDITIONAL`, `FAIL`, `PASS`, `WARN` |
| Hook 結果（abstract） | hook 名、`pass` / `block` / `warn` の結果のみ |
| Latency | wall-clock 秒数、phase 別経過時間 |
| Cost (hash 化された ID 単位) | model_id, provider, token 数（model_id は固定 enum） |
| Tool call count | tool 名（`Edit`, `Bash`, `Grep` など固定 enum）と回数 |
| Test result（数値のみ） | PASS 数、FAIL 数、SKIP 数 |
| Schema validation 結果 | `ok` / `fail`、件数のみ |
| Plan hash | plan.md の hash 値（内容そのものは保存しない） |
| TASK ID | `TASK-XXXX`（連番のみ、内容含まない）|
| 集計時刻 | UTC timestamp |

## 4. 保存してはいけない情報（Forbidden）

以下は metrics log にそのまま保存しない。redact / sanitize / 完全除外のいずれかを行う。

| カテゴリ | リスク | 扱い |
|---------|-------|------|
| ファイル名・パス | プロジェクト構造の漏洩 | redact（hash）または相対分類のみ |
| Stack trace 全文 | スタック内の path / 変数名 | sanitize（先頭 1 行のみ + error type）|
| Command output | env / 認証情報 / 内部データ | 完全除外（保存しない）|
| Provider raw response | API key / model 内部情報 | 完全除外 |
| プロジェクト固有名・社名・人名 | identifiable info | 完全除外 |
| Issue / PR の本文・コメント | 内部議論の漏洩 | 番号のみ保存、本文は除外 |
| User prompt / system prompt 全文 | 業務情報・社外秘 | 完全除外（hash 化も推奨せず）|
| Repo 内ファイル内容の抜粋 | 業務コード | 完全除外 |
| 外部 URL（社内ホスト含む） | infra 情報の漏洩 | sanitize（domain 単位 hash） |

## 5. 個別データの扱い

### 5.1 File path

```text
ALLOWED: scripts/hooks/*.sh の hook 名（固定 enum）
SANITIZE: docs/working/TASK-0001/handoff.md → docs/working/TASK-XXXX/<file_kind>
FORBIDDEN: 絶対パス (/Users/.../...)、リポジトリ外パス
```

### 5.2 Stack trace

```text
ALLOWED: error_type（例: "TypeError", "ValidationError"）
SANITIZE: トップフレーム 1 行のみ、変数値は除外
FORBIDDEN: 全文保存
```

### 5.3 Command output

```text
FORBIDDEN: 完全除外（stdout/stderr いずれも）
代替: 終了コード（exit_code）と "ok"/"fail" のみ保存
```

### 5.4 Provider metadata

```text
ALLOWED: provider 名（"openai", "anthropic", "claude_code", "codex" 等の固定 enum）
ALLOWED: model_id（固定 enum、例: "claude-opus-4-7"）
FORBIDDEN: API key, raw HTTP request/response, account ID
```

## 6. Redaction / sanitize 方針

### 6.1 Redact

- 不可逆な短い hash（SHA-256 先頭 8 文字など）に置換
- 元値は metrics log には保存しない
- 集計目的で同一性を判定したいフィールド（plan_hash など）にのみ使用

### 6.2 Sanitize

- 構造（key 名）は保ったまま値を `"<redacted>"` または分類済み enum に置換
- 例: `file_path: "<sanitized:docs-working>"`

### 6.3 完全除外

- 該当フィールドそのものを event から除外
- スキーマ上は optional として、prod では emit しない

## 7. Retention policy

| 種別 | 既定 retention |
|------|--------------|
| metrics log（append-only file） | 90 日 |
| 集約 retrospective レポート | 永続（数値・抽象 enum のみで構成）|
| baseline snapshot | 永続（PBI-HI-000 / #194 の baseline）|
| 失敗時の error metrics | 30 日（再現確認用、その後集約に置換）|

90 日経過した metrics log は削除または集約レポートへ統合する。永続保存は **数値と enum のみ** で構成された集約のみとする。

## 8. Public repo / private repo 別運用

| 観点 | Public repo（このリポジトリ） | Private repo（forks 想定）|
|------|---------------------------|-------------------------|
| metrics log の commit | **しない**（local / private artifact のみ）| 可（ただし AC §3 / §4 を遵守）|
| 集約 retrospective | OK（数値・enum のみ）| OK |
| 失敗 error type | OK（type 名のみ）| OK |
| stack trace | sanitize 必須 | sanitize 推奨 |
| user prompt | 保存しない | 保存しない（業務情報の保護）|
| baseline snapshot 公開 | 数値・enum のみで OK | 同左 |

> **重要**: Public repo では `bin/plangate metrics` の出力は `.gitignore` 対象とし、commit されないことを実装側で保証する（PBI-HI-001 / #195 で実装）。

## 9. PBI-HI-001 (#195) との接続

PBI-HI-001 で実装される `schemas/plangate-event.schema.json` は、本ドキュメントの §3 / §4 を満たすこと。

- §3 Allowed のフィールドは `additionalProperties: false` の下で明示的に定義する
- §4 Forbidden は schema 上に **そもそも存在させない**（attribute を生やさない）
- redaction が必要なフィールド（file_path, error_type 等）は schema コメントで sanitize 方針を明記する
- `.gitignore` に metrics log 出力先を追加する
- `bin/plangate metrics` 実装時に本 doc を unit test の参照先とする

矛盾検出時は **本 doc が優先**。schema 側を改訂する。

## 10. 違反検出（将来 hook）

将来的に以下の hook を導入する可能性がある（v8.7+ 候補、本 PBI 範囲外）:

- pre-commit で metrics log が staging に含まれていないか確認
- pre-commit で schema が §3 範囲を逸脱していないか確認
- CI で baseline snapshot に Forbidden カテゴリの値が含まれていないか確認

## 11. Non-goals

- 完全な DLP（Data Loss Prevention）システム
- 外部監査ツール連携（Datadog / Splunk 等）
- 暗号化ストレージの導入
- 外部 DB 連携
- `docs/working/` 全体の公開方針再設計（documentation-management.md §2 で既定済み）

## 12. 関連

- [Issue #195 PBI-HI-001 Metrics v1](https://github.com/s977043/plangate/issues/195)
- [docs/ai/harness-improvement-roadmap.md](./harness-improvement-roadmap.md) §7 Phase 1 Metrics v1
- [docs/ai/issue-governance.md](./issue-governance.md)
- [pages/guides/governance/documentation-management.md](../../pages/guides/governance/documentation-management.md)
