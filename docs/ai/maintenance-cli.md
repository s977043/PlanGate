# bin/plangate maintenance — In-session Edit Window 運用 guide

> **TASK-0106 / Issue #289** 対応。EH-3 (`scripts/hooks/check-plan-hash.sh`)
> の TASK 非依存 Edit/Write を **人間が in-session で許可する一級手段**。
> AI 自己付与は **多層 best-effort 防御 + 全試行監査ログ** で抑止する
> （完全な構造保証は別 PBI 分割・R-012）。

## 用途

PlanGate の EH-3 は「TASK 文脈を持たない non-plan ファイルの Edit/Write」を
ブロックする承認境界実行正本。**人間が小規模な docs 整合修正等を行うとき**、
この境界をセッション再起動なしで一時的に開く手段。

## 設計原則

- **Human-owned**: AI から CLI 起動できないように多層防御 + 監査
- **AI 自己付与防止は best-effort + 監査**: 完全な構造保証は別 PBI（R-012）
- **承認境界自体は弱めない**: maintenance 窓内でも **Hardening Override
  対象パス**は常時 block

## CLI 使用法

### `plangate maintenance start --reason "<text>" [--paths <glob,..>] [--minutes 1..30] [--force]`

人間が対話 TTY で実行。以下 **4 層 best-effort 防御**を順次チェック:

| 層 | チェック | reject 条件 |
|----|---------|------------|
| L1 | `isatty(stdin)` | 非対話実行 (パイプ/CI 等) |
| L2 | env barrier | `CI` / `CLAUDE_AGENT` / `CURSOR_AGENT` / `PLANGATE_BYPASS_HOOK` が set |
| L3 | parent process heuristic | ppid の comm 名が `claude`/`codex`/`cursor` を含む（`ps -p $PPID -o comm=` + `grep -iqE`）|
| L4 | 対話 nonce | 画面表示の 8-hex を `PLANGATE_MAINT_ACK>` プロンプトで再入力、一致しないと reject |

すべての試行（成功・失敗問わず）は `docs/working/_audit/hook-events.log`
に append される:

```json
{"ts":"2026-05-21T...Z","event":"maintenance_start_attempt","verdict":"ok|reject_L1|reject_L2|reject_L3|reject_L4|reject_arg|reject_existing","ppid":12345,"isatty_stdin":true,"detail":"..."}
```

#### オプション

| Flag | Default | 説明 |
|------|---------|------|
| `--reason` | (required) | 空白のみは reject |
| `--paths` | (empty) | カンマ区切り glob (例 `"README.md,docs/**/*.md"`)。未指定なら Override 対象以外を許可（v1 後方互換） |
| `--minutes` | `5` | TTL 1..30 (hard cap 30) |
| `--force` | (off) | 既存有効窓がある場合に上書き許可 (AC-9) |

#### 例

```sh
# 単発で README.md だけ 10 分許可
plangate maintenance start --reason "fix Provider table typo" --paths "README.md" --minutes 10

# docs ツリー全般 5 分
plangate maintenance start --reason "Changelog sync" --paths "docs/**/*.md"

# 既定 (paths 無指定 = Override 対象以外を許可) で 3 分
plangate maintenance start --reason "small docs fix" --minutes 3
```

### `plangate maintenance stop`

維持窓を即時失効（`maintenance.json` を削除）。

### `plangate maintenance help`

usage を表示。

## EH-3 hook の判定順序

`maintenance.json` 存在時、EH-3 は以下の順序で判定:

```
(i)   target_file 正規化 (./ 除去・絶対パス → repo 相対)            [R-028]
(ii)  Hardening Override 物理先頭判定 (10 パターン → block)         [R-003/R-015]
(iii) maintenance ファイル base validation (TTL 内/approved_by 等)
(iv)  allowed_paths スコープ判定 (未指定なら Override 以外を許可)    [R-004]
(v)   one_shot=true なら flock(LOCK_EX|LOCK_NB) → fstat vs stat で
      inode 比較 → 再 read で consumed_at 未消費確認 → os.replace で
      atomic 書込 → 解放 → SKIP                                      [R-002/R-017/R-027/R-031]
      競合検出/inode 不一致は fail-closed (block)
```

## Hardening Override 対象パス (常時 block)

「防御の防御」: maintenance 窓内でも以下は変更不可。重要 infra への変更は
別承認ルート（PR + Human merge）必須。

- `.claude/rules/*.md`
- `.claude/settings.json` / `.claude/settings.local.json` / `.claude/settings.example.json`
- `.claude/commands/**.md`
- `.claude/agents/**.md`
- `scripts/hooks/*.sh`
- `bin/plangate`
- `schemas/*.schema.json`
- `.github/workflows/*.yml` / `*.yaml`
- `AGENTS.md` / `CLAUDE.md`

## doctor との連携

```sh
plangate doctor                       # 末尾に「Maintenance Window」セクション (1 行)
plangate doctor --json --scope maintenance  # 機械可読 metadata
```

JSON 出力例 (active):

```json
{
  "scope": "maintenance",
  "checks": [{"id":"maintenance.json","level":"info","status":"ok","msg":"active: remaining=04:32 scope=test paths=['README.md']"}],
  "failures": 0,
  "warnings": 0,
  "passed": true,
  "maintenance": {
    "present": true,
    "scope": "test",
    "approved_by": "mine_take",
    "reason": "small docs fix",
    "granted_at": 1779337000,
    "until_epoch": 1779337300,
    "remaining_seconds": 200,
    "remaining_mmss": "03:20",
    "allowed_paths": ["README.md"],
    "one_shot": true,
    "consumed_at": null,
    "active": true
  }
}
```

## Documented Limitations

- **UTF-8 環境前提** (R-018): ファイルパス・reason 文字列は UTF-8 ロケール
  前提。shift-jis 等の非 UTF-8 環境での動作は未保証。
- **L3 parent process heuristic は best-effort** (R-029): macOS BSD ps と
  Linux GNU ps の差異吸収のため `grep -iqE 'claude|codex|cursor'` 部分一致。
  ppid 偽装やエージェント名の変更には追従不可。
- **完全な構造保証は別 PBI** (R-012): 本 PBI は多層 best-effort + 監査で
  AI 自己付与を実用的に抑止するが、原理的に完全防御は不可能。完全保証は
  別 PBI として将来取り組む。

## 監査ログの活用

`docs/working/_audit/hook-events.log` に全 start 試行が記録される。AI
偽装試行を検知するには:

```sh
# 失敗試行のみ抽出
grep -E '"verdict":"reject_' docs/working/_audit/hook-events.log

# 過去 1 時間の reject 集計
python3 -c "
import json, time
cutoff = time.time() - 3600
for line in open('docs/working/_audit/hook-events.log'):
    line = line.strip()
    if not line.startswith('{'): continue
    try: d = json.loads(line)
    except: continue
    if d.get('event','').startswith('maintenance_start') and d.get('verdict','').startswith('reject'):
        print(d['ts'], d['verdict'], d.get('detail',''))
"
```

## 関連

- Issue: [#289](https://github.com/s977043/PlanGate/issues/289) — 元 PBI
- PBI: TASK-0106 (`docs/working/TASK-0106/`)
- 設計: `.claude/rules/responsibility-classes.md` 「対外公開アーティファクト
  publish 責務分界」節 (関連: R-012 best-effort + 別 PBI 分割の方針)
- EH-3 正本: `scripts/hooks/check-plan-hash.sh`
- schema: `schemas/maintenance.schema.json` (v2)
