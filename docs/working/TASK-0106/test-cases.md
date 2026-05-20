# TASK-0106 テストケース定義

> Source: pbi-input.md (AC) / plan.md (Testing Strategy) / Generated: 2026-05-20

## 受入基準 → テストケース マッピング

| AC | TC IDs |
|----|--------|
| AC-1: `bin/plangate maintenance start --reason "..."` で schema valid な maintenance.json 生成（TTY 要求下） | TC-01, TC-02 |
| AC-2: 生成承認下で no-task の対象 Edit/Write が 1 回通り、その後 one-shot 消費で自動無効化 | TC-03, TC-04, TC-05 |
| AC-3: Hardening Override 対象 + `--paths` 指定外は窓内でも block | TC-06, TC-07, **TC-24** |
| AC-4: TTL 超過後 block、ハード上限超え `--minutes` 拒否（既定 5 分・上限 30 分） | TC-08, TC-09 |
| AC-5: AI から自己発行不可（TTY 要求＋env 無効） | TC-10, **TC-25**, **TC-26** |
| AC-6: `bin/plangate doctor` 表示 + `--json` 構造化 | TC-11, **TC-27** |
| AC-7: 既存 30 分窓（Override 対象パス以外）後方互換 | TC-12 |
| AC-8: ユニットテストが `tests/run-tests.sh` で検証可能 | **TC-23** (R-007) |
| **AC-9**: 既存有効窓で `start --force` なしは reject | **TC-28** (R-005/R-010) |
| **AC-10**: 新設フィールド判定も env では有効化不可 | **TC-29** (R-011) |

## テストケース一覧

### Unit (CLI)

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| TC-01 | clean state | `bin/plangate maintenance start --reason "test"` | `docs/working/_maintenance/maintenance.json` 作成、`reason="test"` `scope` 既定値、`until=granted_at+1800` (30分上限内) | unit |
| TC-02 | TC-01 後 | `bin/plangate validate-schemas` または ad-hoc schema 検証 | maintenance.json が schemas/maintenance.schema.json に validate PASS | unit |

### Unit (hook)

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| TC-03 | maintenance.json (one_shot=true, allowed_paths=["README.md"], TTL 内, consumed_at 未設定) | EH-3 hook 起動 (`PLANGATE_HOOK_FILE=README.md`, task なし) | exit 0 (PASS) かつ maintenance.json の consumed_at が設定される | unit |
| TC-04 | TC-03 後（consumed_at 設定済み） | 同条件で EH-3 再起動 | exit 2 (block, "one-shot consumed") | unit |
| TC-05 | maintenance.json delete (= stop 後) | EH-3 起動 | 通常の no-maintenance block 動作 | unit |
| TC-06 | maintenance.json (allowed_paths=["README.md"]) | `PLANGATE_HOOK_FILE=docs/foo.md` で hook 起動 | exit 2 (block, "path scope violation") | unit |
| TC-07 | maintenance.json (allowed_paths=["**/*.md"], Hardening Override 対象) | `PLANGATE_HOOK_FILE=.claude/rules/responsibility-classes.md` で hook 起動 | exit 2 (block, "Hardening Override") | unit |
| TC-08 | maintenance.json (until = now - 60) | EH-3 起動 | exit 2 (block, "TTL expired") | unit |
| TC-09 | n/a | `bin/plangate maintenance start --minutes 60` | exit 非0 (reject, "max 30 minutes") | unit |
| TC-10 | env のみで maintenance 風変数を set (例: `PLANGATE_MAINTENANCE_REASON=x`)、maintenance.json 不在 | EH-3 起動（no task） | exit 2 (block。env 経路では有効化されない＝AI 自己付与防止) | unit |

### Integration / E2E

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| TC-11 | TC-01 後 | `bin/plangate doctor` | 出力に「maintenance: scope=... remaining=XX:YY paths=...」行が含まれる | integration |
| TC-12 | 既存形式 maintenance.json（30 分窓・パス無指定、allowed_paths なし、one_shot なし） | EH-3 起動（no task、任意 path） | exit 0 (PASS。既存挙動と同じ＝後方互換) | integration |
| TC-13 (E2E) | clean state | `start --paths "README.md" --minutes 5` → README.md Edit → 同じ承認で再 Edit → stop | 1 回目通過、2 回目 block、stop 後完全失効 | e2e |

### Edge cases

- TC-14: `--paths` に複数 glob（`"README.md,docs/*.md"`）→ 個別 path で正しく match
- TC-15: maintenance.json の `until` が `granted_at` より小さい（不正）→ EH-3 が block
- TC-16: consumed_at の atomic 書込中に並行 hook → 後発が必ず block（一方のみ通過）
- TC-17: schema 拡張で additionalProperties:false 維持されている（不正キー入りで validate FAIL）
- **TC-18**: `bin/plangate maintenance start --reason ""` または `--reason "   "`（空白のみ）→ exit 非0（reason 必須・空白拒否）
- **TC-19**: `--paths` 未指定で start → 後方互換どおり「全パス許可」動作（既存 30 分窓と同等）。allowed_paths フィールドは省略され Hardening Override のみ機能
- **TC-20**: 既存有効な maintenance.json がある状態で再度 `maintenance start --reason "x"` (no --force) → exit 非0 "already active maintenance window" reject（R-005/R-010 → AC-9）
- **TC-21**: consumed_at が既に設定された one_shot=true の maintenance.json が残存している状態で `maintenance start` 新規呼び出し → 既存ファイルを atomic に置換（古い consumed_at は引き継がず初期化）
- **TC-22**: non-UTF-8 path (例: shift-jis 環境変数や filesystem encoding 不一致) でのふるまい → documented limitation として「UTF-8 環境を前提」を pbi-input.md / docs/ai/maintenance-cli.md に明記。テストは UTF-8 環境前提で skip 可
- **TC-23 (AC-8)**: `tests/run-tests.sh` 実行で新規 ta-XX-maintenance.sh と既存 hook テストが順次呼び出され全 PASS する（runner 統合確認）（R-007）
- **TC-24 (AC-3)**: Hardening Override 対象パス 10 種（`.claude/rules/*.md`, `.claude/settings*.json`, `.claude/commands/*.md`, `.claude/agents/*.md`, `scripts/hooks/*.sh`, `bin/plangate`, `schemas/*.schema.json`, `.github/workflows/*.yml`, `AGENTS.md`, `CLAUDE.md`）すべて窓内でも block（R-003）
- **TC-25 (AC-5)**: 非対話実行 (stdin が tty でない、CI=true、agent 環境) で `bin/plangate maintenance start` → exit 非0 "interactive TTY required" reject（R-001）
- **TC-26 (AC-5)**: TTY 偽装試行（agent から AI CLI 経由で起動）→ reject + 痕跡 hook-events.log 記録（R-001）
- **TC-27 (AC-6)**: `bin/plangate doctor --json` で `maintenance` キーに `{scope, until_epoch, remaining_seconds, paths, one_shot, consumed_at}` を含む（R-006）
- **TC-28 (AC-9)**: 既存有効窓で `start --force` → atomic 置換、consumed_at 初期化、CLI が再度 TTY 要求（R-005/R-010）
- **TC-29 (AC-10)**: 新設フィールド (allowed_paths/one_shot/consumed_at) も env 経由 (`PLANGATE_MAINT_ONE_SHOT=true` 等) では有効化不可（R-011）
- **TC-30 (R-002 race)**: 並行 hook 2 実行 → 1 つだけ通過、もう片方は競合検出 fail-closed で block。`os.replace` の atomicity verify
- **TC-31 (R-009 strict)**: 新設フィールド読出に不正 JSON 構造（偽プロパティ・不正型）→ strict JSON 抽出で reject（block）

## 自動化可否

全 TC は `tests/run-tests.sh` / `tests/hooks/run-tests.sh` で自動化（fixture maintenance.json + 環境変数で再現）。E2E (TC-13) はテストスクリプト内で in-place 操作。
