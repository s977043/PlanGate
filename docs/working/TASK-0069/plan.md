# TASK-0069 EXECUTION PLAN

> 生成日: 2026-05-15
> PBI: `plangate doctor --fix` — 導入初期環境構築の最終 1 マイル
> Notion: -

## Goal

`bin/plangate doctor` に hook 配線状態の検査と決定論的修復（`--fix`）を追加し、PlanGate 導入者が「hook 強制が効いた状態」へ一発で到達できるようにする。

## Constraints / Non-goals

- POSIX sh（`bin/plangate` は `set -eu`、dash 互換）を維持する。bashism を持ち込まない
- `.claude/settings.json` の書き換えは merge-only・backup 必須・冪等。既存ユーザーキーを破壊しない
- backup は既存 `.claude/settings.json.bak` を上書きしない。既存 `.bak` があれば `.claude/settings.json.bak.<epoch>` にローテート退避してから新規 `.bak` を作成（既存 backup を保全、abort はしない）
- `--fix` は確認ゲートを通す（`--yes` でのみスキップ可）
- **Non-goals**: gh/codex 自動インストール、対話 skill（案 D）、plugin 登録自動化、`plugin/plangate/hooks/` への実体配置

## Approach Overview

1. `cmd_doctor` に hook-wiring 検査セクションを追加（読み取りのみ、`--json` にも反映）
2. `--fix/--dry-run/--yes` 引数を `cmd_doctor` で解釈
3. JSON マージの複雑性は `scripts/doctor_fix.py`（新規 Python）に隔離。`bin/plangate` は薄く呼ぶだけ
4. ドキュメント・テストを追従

## Work Breakdown

### Step 1: hook-wiring 検査ロジック + `--json` scope 設計
- **Output**:
  - 「期待集合 = `.claude/settings.example.json` の各 hook を `(event, matcher, type, command)` の**ブロック単位**で抽出した集合」と確定。`scripts/hooks/` のファイル数とは**独立**（example が正本）
  - `.claude/settings.json` が各期待ブロックを「同一 event 配下に同一 matcher/type/command」で含むかで配線判定（command 文字列のみの集合判定は **不採用** — 別 event/matcher に存在しても誤 PASS するため）
  - `doctor --json` の現行構造（`doctor_check.py --scope v8.6.0` 専用、`scope != v8.6.0` は error、human-readable とは別系統）を踏まえ、hook-wiring を **`doctor_check.py` に新 scope `hooks` を追加**して載せる方針を確定（`--scope v8.6.0` 出力は後方互換維持）
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 期待集合が example のブロック集合と一致し scripts/hooks ファイル数に依存しないか / 新 scope が v8.6.0 出力を壊さないか / `--json --scope hooks` の CLI 経路が cmd_doctor→doctor_check.py で繋がるか

### Step 2: `scripts/doctor_fix.py` 実装（TDD）
- **Output**: 新規 Python。`--check`（配線有無を exit code で返す）/ `--apply`（merge-only + `.bak` 退避。既存 `.bak` があれば `.bak.<epoch>` にローテートしてから新規 `.bak` 作成）/ `--dry-run`（差分のみ stdout）。`json` 標準ライブラリのみ使用
- **Owner**: agent
- **Risk**: 高（settings.json 破壊リスク）
- **🚩 チェックポイント**: 既存キー温存・冪等・backup 生成をテストで先に固定したか

### Step 3: `bin/plangate cmd_doctor` 拡張
- **Output**: `=== Hook Enforcement Wiring ===` セクション + `--fix/--dry-run/--yes` 分岐。`--scope <v>` を解析し `doctor_check.py --scope <v>` に**透過転送**（`--json` 単独時は従来通り `--scope v8.6.0`、Step 4 の新 scope `hooks` はこの経路で到達）。修復は doctor_fix.py / chmod / .gitignore 追記 / mkdir。確認プロンプトは sh。**非 tty かつ `--yes` 無し → 変更せず abort（exit 非0、`run with --yes` 案内）**（`set -eu` 下 `read` の EOF 挙動に注意）。gh/codex 未導入 → 自動インストールせず案内文を出力（既存 doctor の CLI Tools 検査結果は流用せず `--fix` 実行時に案内表示）
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: 確認なし破壊操作が無いか / 非 tty 時 no-write abort か / dash -n / checkbashisms PASS か

### Step 4: `scripts/doctor_check.py` に scope `hooks` 追加
- **Output**: `--scope` に `hooks`（+ 任意で `all`）を追加。`scope != "v8.6.0"` で即 error の現分岐を改修し、`hooks` scope で hook-wiring 検査（name/ok/level、presence・配線真偽のみ。settings 内容/パス値は出さず privacy 維持）を返す。`--scope v8.6.0`（default）の出力は**バイト互換**を維持
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: `--scope v8.6.0` 出力が無改変か / 新 scope が JSON schema（name/ok/level）と整合か

### Step 5: ドキュメント追記
- **Output**: `README.md` インストール節 + `TROUBLESHOOTING.md` に `plangate doctor --fix` 手順
- **Owner**: agent
- **Risk**: 低
- **🚩 チェックポイント**: markdownlint PASS

### Step 6: テスト追加
- **Output**: `tests/extras/ta-10-doctor-fix.sh` を**置くだけ**（`tests/run-tests.sh` の extras loader が `ta-*.sh` を自動 source。本体編集不要 — Issue #170 衝突回避規約）。`pass`/`fail` 変数共有・`set -eu` 下で動く既存 ta-XX 形式に従う。検証: 新規作成/既存マージ/冪等/既存キー非破壊/backup/dry-run no-write/非tty abort
- **Owner**: agent
- **Risk**: 中
- **🚩 チェックポイント**: `tests/run-tests.sh` 本体を編集していないか / 一時 dir 隔離で実 `.claude/` を汚さないか

## Files / Components to Touch

| 種別 | ファイルパス | 変更内容 |
|------|------------|---------|
| 変更 | `bin/plangate` | `cmd_doctor` に検査セクション + `--fix/--dry-run/--yes` + usage 更新 |
| 新規 | `scripts/doctor_fix.py` | settings.json 安全マージ（check/apply/dry-run） |
| 変更 | `scripts/doctor_check.py` | `--json` に hook-wiring 検査追加 |
| 変更 | `README.md` | インストール節に `doctor --fix` 追記 |
| 変更 | `TROUBLESHOOTING.md` | hook 未配線症状と解決手順追記 |
| 新規 | `tests/extras/ta-10-doctor-fix.sh` | doctor_fix 単体テスト |
| （編集不要） | `tests/run-tests.sh` | extras loader が自動 source。**本体編集しない**（Issue #170 規約） |

## Testing Strategy

- **Unit**: `doctor_fix.py` — 一時 dir で settings.json 新規作成 / 既存マージ / 冪等 / 既存キー温存 / backup 生成 / dry-run 非書込
- **Integration**: `bin/plangate doctor` が未配線環境で FAIL、`--fix --yes` 後に PASS。`doctor --json` に項目追加
- **E2E**: クリーン一時リポジトリで `clone 相当 → doctor --fix --yes → doctor` が PASS まで通る手順確認
- **Edge cases**: settings.json が不正 JSON / hooks キーなし / 一部 hook のみ配線済み / 読み取り専用 FS
- **Verification Automation**: `tests/run-tests.sh` 一括 + `dash -n bin/plangate` + `checkbashisms bin/plangate` + `markdownlint`

## Risks & Mitigations

| リスク | 対策 |
|-------|------|
| 既存 `.claude/settings.json` 破壊 | merge-only / 書込前 `.bak` / 冪等 / dry-run / 確認ゲート |
| 配線判定 false positive（command 文字列のみ照合だと別 event/matcher 存在で誤 PASS） | `(event, matcher, type, command)` ブロック単位で照合・マージ。settings.json の二重リスト構造（`hooks.<event>[].hooks[]`）を保持してマージ（TC-E2 で担保） |
| 既存 `.bak` の上書き喪失 | 既存 `.bak` を `.bak.<epoch>` にローテート退避してから新規 `.bak` 作成 |
| sh 互換性崩れ | dash -n + checkbashisms を検証フェーズ必須化 |
| privacy 違反（settings 内容を JSON 出力に漏らす） | doctor_check.py は presence の真偽のみ出力、内容・パス値は出さない |
| EH-8 presence/chmod 検査（既存 v8.6.0 セクション）と責務重複 | hook-wiring は「settings.json への配線有無」のみ担当。ファイル存在/実行ビット検査は既存 v8.6.0 セクションに委ね二重実装しない |
| `doctor --json` 二重構造（human と別系統）放置で検査が片系統のみ | Step 1/4 で doctor_check.py に scope `hooks` 追加と確定。human セクションと JSON 双方に hook-wiring を出す |
| テストが実 `.claude/` を汚染 | `mktemp -d` で隔離、`CLAUDE_PROJECT_DIR` 相当を上書き |

## Questions / Unknowns

- なし（C-2 で `tests/run-tests.sh` 自動 loader・`doctor_check.py` の v8.6.0 専用 scope 構造・`settings.example.json` 正本範囲を確認し plan に反映済み）

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 7 → high-risk
- 受入基準数: 8 → high-risk
- 変更種別: コア CLI 機能追加 + 設定ファイル破壊的書換 → high-risk
- リスク: 高（ユーザー設定損失リスク、緩和策で低減） → high-risk
- **最終判定**: high-risk
