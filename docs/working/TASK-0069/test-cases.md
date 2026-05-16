# TASK-0069 テストケース定義

> 生成日: 2026-05-15

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| AC-1: doctor に Hook Wiring セクション + 未配線で FAIL | TC-1 | Integration |
| AC-2: `--fix --dry-run` が非書込（TC-2）/ 非tty + `--yes`無しで安全 abort（TC-E4） | TC-2, TC-E4 | Unit |
| AC-3: `--fix --yes` で配線 + .bak 生成 | TC-3a, TC-3b, TC-3c | Unit |
| AC-4: 既存キー温存（merge-only） | TC-4 | Unit |
| AC-5: 2 回目 no-op（冪等） | TC-5 | Unit |
| AC-6: gh/codex 未導入は案内のみ | TC-6 | Integration |
| AC-7: `doctor --json` に hook-wiring 含む | TC-7 | Integration |
| AC-8: 単体テスト PASS + 既存回帰なし | TC-8 | Integration |

## テストケース一覧

### TC-1: 未配線環境で doctor が FAIL
- **前提条件**: 一時 dir、`.claude/settings.json` なし、`.claude/settings.example.json` あり
- **入力**: `bin/plangate doctor`
- **期待出力**: `=== Hook Enforcement Wiring ===` 出力 + `[FAIL] PlanGate hooks not wired`、exit code 1。判定は example の各 hook を `(event, matcher, type, command)` ブロック単位で照合（command 文字列のみの集合一致では判定しない）
- **種別**: Integration

### TC-2: dry-run は書き換えない
- **前提条件**: 一時 dir、settings.json なし
- **入力**: `plangate doctor --fix --dry-run`
- **期待出力**: 変更計画を stdout 表示。`.claude/settings.json` 非生成・`.bak` 無しに加え、**EH-8 の実行ビット / `.gitignore` / `docs/working/` も一切変更されない**（dry-run は全修復対象に対し非書込）
- **種別**: Unit

### TC-3a: --fix --yes（settings.json 新規作成）
- **前提条件**: 一時 dir、`.claude/settings.json` なし
- **入力**: `plangate doctor --fix --yes`
- **期待出力**: `.claude/settings.json` 生成、example の全 hook ブロックを含む。`.bak` は生成されない（新規作成時は不要）。再 `doctor` が hook-wiring PASS
- **種別**: Unit

### TC-3b: --fix --yes（既存 settings.json + backup ローテート）
- **前提条件**: `.claude/settings.json` が既存。さらに `.claude/settings.json.bak` も既存（過去の backup）
- **入力**: `plangate doctor --fix --yes`
- **期待出力**: 書込前に新規 `.claude/settings.json.bak` 生成。**既存の `.bak` は上書きされず `.claude/settings.json.bak.<epoch>` にローテート退避**される。settings.json は hook ブロック配線済みになり、再 `doctor` が hook-wiring PASS
- **種別**: Unit

### TC-3c: 既存 `.bak.<epoch>` を上書きしない（Codex C-4 major）
- **前提条件**: `.claude/settings.json` 既存、`.claude/settings.json.bak` 既存、now-1/now/now+1 の `.bak.<epoch>` を sentinel 付きで事前配置
- **入力**: `doctor_fix.py --apply`
- **期待出力**: 事前配置した全 `.bak.<epoch>` が sentinel 内容を保持（上書きされない）。旧 `.bak` 内容は衝突回避サフィックス付き別名へ退避。新 `.bak` 生成、`--check` PASS
- **種別**: Unit

### TC-4: 既存キー温存
- **前提条件**: `.claude/settings.json` に `{"permissions":{"allow":["Bash(ls)"]},"hooks":{"SessionStart":[...既存独自...]}}`
- **入力**: `plangate doctor --fix --yes`
- **期待出力**: `permissions.allow` が温存され、既存 `SessionStart` エントリも残存、example の hook が追加マージされる（重複追加なし）
- **種別**: Unit

### TC-5: 冪等
- **前提条件**: TC-3 実行直後の状態
- **入力**: `plangate doctor --fix --yes` を再実行
- **期待出力**: settings.json の内容がバイト一致（no-op）、「already wired」相当メッセージ
- **種別**: Unit

### TC-6: gh/codex 未導入は案内のみ
- **前提条件**: PATH から gh/codex を除外した環境
- **入力**: `plangate doctor --fix --yes`
- **期待出力**: 自動インストールを実行しない。インストール案内文字列を出力。exit code は他修復の成否に従う
- **種別**: Integration

### TC-7: doctor --json --scope hooks に hook-wiring 含む
- **前提条件**: 一時 dir
- **入力**: `bin/plangate doctor --json --scope hooks`
- **期待出力**: JSON に hook-wiring 検査項目（name/ok/level）が含まれる。`bin/plangate doctor --json`（default `--scope v8.6.0`）の出力は従来とバイト一致（無改変）。settings.json の内容値・パス値は出力に含まれない
- **種別**: Integration

### TC-8: 既存テスト回帰なし
- **前提条件**: リポジトリルート
- **入力**: `sh tests/run-tests.sh`
- **期待出力**: 新規 `ta-10-doctor-fix.sh`（`scripts/doctor_fix.py` を一時 dir 隔離で直接叩く単体テスト群: 新規作成/既存マージ/冪等/既存キー非破壊/backup ローテート/dry-run no-write/非tty abort）含め全 PASS、既存 `tests/hooks/run-tests.sh` も PASS
- **種別**: Integration

## エッジケース

### TC-E1: 不正 JSON の settings.json
- **前提条件**: `.claude/settings.json` が壊れた JSON（`{ "permissions": ` で切れている）
- **入力**: `plangate doctor --fix --yes`
- **期待出力**: 上書きせず明示エラー（`settings.json is not valid JSON — aborting, no changes made`）、exit 非0、`.bak` も作らない
- **種別**: Unit

### TC-E2: hooks キーは在るが PlanGate hook が一部のみ
- **前提条件**: settings.json に `hooks.PreToolUse` の一部 hook ブロックのみ存在（二重リスト構造 `hooks.<event>[].hooks[]`）
- **入力**: `plangate doctor --fix --yes`
- **期待出力**: 不足ブロック `(event, matcher, type, command)` のみ追記、同一ブロックは重複させない、配線済みブロックは変更しない、settings.json の二重リスト構造を保持
- **種別**: Unit

### TC-E3: 読み取り専用ディレクトリ
- **前提条件**: `.claude/` を chmod 0500
- **入力**: `plangate doctor --fix --yes`
- **期待出力**: 書込失敗を捕捉し明示エラー、部分書込を残さない、exit 非0
- **種別**: Unit

### TC-E4: 非 tty + `--yes` 無し
- **前提条件**: 一時 dir、settings.json なし、stdin を `/dev/null` にリダイレクト（非 tty）
- **入力**: `plangate doctor --fix </dev/null`
- **期待出力**: プロンプトで hang せず、変更を加えず abort。`run with --yes` 案内を出力、exit 非0、settings.json 未生成
- **種別**: Unit
